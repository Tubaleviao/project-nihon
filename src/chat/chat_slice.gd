extends Node
## Chat slice (Phase 85) — a message box, and the slash commands typed into it.
##
## Plain text is said to everyone. A line starting with `/` is a command: the player commands
## (`/help`, `/players`, `/where`) are open to all; the admin commands (`/say`, `/tp`, `/bring`,
## `/give`, `/kill`, `/weather`, Phase 182's `/time`, `/speed`, `/fly`, `/heal`) are refused for anyone who
## is not an admin. Spelling and argument parsing are
## pure and live in `ChatCommands`; this slice owns the effects and the box.
##
## Authority: the host runs every command. A client forwards the line as a `chat_intent` (see
## NetworkingSlice) and the host binds the speaker to the connection — an identity in the payload is
## never read. An admin is the host's own local player, or a player id listed in `user://admins.json`
## (a JSON array of player ids, read at boot and re-read when it changes on disk). Everything a command does to a remote player goes
## through the existing host → peer doors (`send_teleport`, the `player_damaged` signal, `inventory_synced`).
##
## Plug contract (GameBus signals consumed / emitted):
##   IN  : chat_intent(text, player_id), chat_posted(channel, sender, text, target_id)
##   OUT : chat_posted(...), player_teleport({chunk, local}), player_damaged(...)
##
## Public API:
##   submit(text)                      — the local player says / runs `text`
##   handle_intent(text, player_id)    — host: act on one speaker's line
##   is_admin(player_id) -> bool
##   open_input() / is_typing() / lines() -> Array
const ChatCommands := preload("res://src/core/chat_commands.gd")
const I18n := preload("res://src/core/i18n.gd")
const Diag := preload("res://src/core/diag.gd")
const PlayerRules := preload("res://src/core/player_rules.gd")
const WorldPos := preload("res://src/terrain/world_pos.gd")
const AdminRules := preload("res://src/admin/admin_rules.gd")
const PlayerRegistry := preload("res://src/persistence/player_registry.gd")

const ADMINS_PATH := "user://admins.json"
## Lines kept in the log, and shown at once while the box is closed.
const MAX_LINES := 60
const VISIBLE_LINES := 8
## Seconds a line stays on screen after it arrives, while the input is closed.
const LINE_LIFETIME := 12.0
const KILL_DAMAGE := PlayerRules.MAX_HP * 100.0
## Phase 101 — a per-player token bucket on plain chat (Phase 115: an admin's commands do not spend it): `CHAT_BURST` lines at once, refilling at
## `CHAT_LINES_PER_SEC`. A refused line is dropped and counted; the player hears about it at most
## once per `SLOW_DOWN_NOTICE_SEC`.
const CHAT_BURST := 5
const CHAT_LINES_PER_SEC := 1.0
const SLOW_DOWN_NOTICE_SEC := 5.0
## Buckets kept before fully refilled ones are pruned (see `_prune_buckets`).
const MAX_BUCKETS := 256

const CHANNEL_CHAT := "chat"
const CHANNEL_ANNOUNCE := "announce"
const CHANNEL_SYSTEM := "system"
## Phase 204 — a private message as its recipient sees it ("whisper", the sender's name) and as its sender's
## echo ("whisper_to", the recipient's name).
const CHANNEL_WHISPER := "whisper"
const CHANNEL_WHISPER_TO := "whisper_to"
## Phase 204 — the private-message window: at most `Clan.messages.perMinute` per sender in any minute.
const PRIVATE_WINDOW_SEC := 60.0
const PRIVATE_DEFAULTS := { "maxLength": 280, "perMinute": 10 }
## The sender of a `/say` announcement; the client shows it translated.
const SERVER_SENDER := "Server"

## Set by game_root.
var player_registry: Node = null
var player_slice: Node = null
var inventory_slice: Node = null
## Phase 128 — the host's weather, for the admin `/weather` override.
var weather_slice: Node = null
## Phase 182 — the host's world clock, for `/time` (a `WorldClock`; null in a rig without one).
var world_clock: RefCounted = null
var networking: Node = null
## False on a headless server: no box is built, the slice only runs commands.
var render_visuals: bool = true
var admins_path: String = ADMINS_PATH
## Phase 182 — how often (seconds) the host re-reads the admins file, so an id added or removed mid-session
## takes effect and its client is told (`poll_admins_file`).
const ADMINS_POLL_SEC := 2.0
var _admins_mtime: int = 0
var _admins_polled_at: float = -INF

## Lines refused by the token bucket since boot.
var chat_rate_refused: int = 0
## Seconds clock for the bucket; injectable like `ChunkManager.set_clock`.
var now_sec: Callable = func() -> float: return Time.get_ticks_msec() / 1000.0

var _admins: Dictionary = {}     # player id -> true
## Phase 182 — player id -> { speed: float, fly: bool } for the players an admin changed (`/speed`,
## `/fly`). Session state: a player who leaves is dropped, and comes back walking normally.
var _admin_moves: Dictionary = {}
var _buckets: Dictionary = {}    # player id -> { tokens: float, at: float, notice_at: float }
## Phase 204 — player id -> the times of their private messages inside the last `PRIVATE_WINDOW_SEC`.
var _private_sent: Dictionary = {}
## Private messages refused by their per-minute limit since boot.
var private_rate_refused: int = 0
var _lines: Array = []           # { channel, sender, text, born }
var _layer: CanvasLayer = null
var _log: RichTextLabel = null
var _field: LineEdit = null

func _ready() -> void:
	_load_admins()
	GameBus.chat_intent.connect(_on_chat_intent)
	GameBus.chat_posted.connect(_on_chat_posted)
	GameBus.chat_compose_requested.connect(open_input)
	GameBus.system_message.connect(_on_system_message)
	GameBus.locale_changed.connect(_on_locale_changed)
	GameBus.player_left.connect(_on_player_left)
	GameBus.player_joined.connect(_on_player_joined)
	if render_visuals:
		_build_ui()

func _process(_delta: float) -> void:
	if _log != null:
		_refresh_log()
	if not _is_client() and now_sec.call() - _admins_polled_at >= ADMINS_POLL_SEC:
		poll_admins_file()

## Phase 182 — host: re-read the admins file when it changed on disk. Every online player whose admin
## status flipped is told (a peer by an `admin_status` packet; the local player is always an admin).
## Returns the ids that flipped.
func poll_admins_file() -> Array:
	_admins_polled_at = float(now_sec.call())
	var mtime := FileAccess.get_modified_time(admins_path) if FileAccess.file_exists(admins_path) else 0
	if mtime == _admins_mtime:
		return []
	var online := _online_ids()
	var before := {}
	for pid in online:
		before[pid] = is_admin(pid)
	_load_admins()
	var flipped: Array = []
	for pid in online:
		var now_admin := is_admin(pid)
		if now_admin == bool(before[pid]):
			continue
		flipped.append(pid)
		var peer := _peer_of(pid)
		if not _is_local(pid) and networking != null and peer > 1:
			networking.send_admin(peer, "admin_status", { "admin": now_admin })
	return flipped

func _input(event: InputEvent) -> void:
	if _field == null or not (event is InputEventKey) or not event.pressed:
		return
	if _field.has_focus():
		if event.keycode == KEY_ESCAPE:
			_close_input()
			get_viewport().set_input_as_handled()
		return
	# Enter opens the box; `/` opens it with a slash already typed. Neither fires over another field.
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		open_input()
		get_viewport().set_input_as_handled()
	elif event.unicode == 47:
		open_input("/")
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## True while the input field has the keyboard (world hotkeys must stay quiet).
func is_typing() -> bool:
	return _field != null and _field.has_focus()

func open_input(prefill: String = "") -> void:
	if _field == null:
		return
	_field.text = prefill
	_field.grab_focus()
	_field.caret_column = prefill.length()

## The local player says or runs `text`. `/where` answers here (it only needs this machine's body);
## everything else is an intent for the host.
func submit(text: String) -> void:
	var clean := ChatCommands.sanitize(text)
	if clean == "":
		return
	# Phase 159 — `/sit`, `/wave`, ...: a gesture action for the host, not a chat line.
	var gesture := ChatCommands.gesture_id(clean)
	if gesture != "":
		GameBus.gesture_intent.emit(gesture, "")
		return
	if ChatCommands.is_command(clean):
		var pos: Vector3 = player_slice.get_position() if player_slice != null else Vector3.ZERO
		_add_line(CHANNEL_SYSTEM, "", ChatCommands.run(clean, pos))
		return
	GameBus.chat_intent.emit(clean, "")

func set_clock(c: Callable) -> void:
	now_sec = c

func lines() -> Array:
	return _lines.duplicate()

## An admin is this process's own local player (on a host or offline), or an id in the admins file.
func is_admin(player_id: String) -> bool:
	if player_id == "":
		return false
	if player_registry != null and player_id == player_registry.local_player_id and not _is_client():
		return true
	return _admins.has(player_id)

## Host: act on one speaker's line. `player_id` "" is the local player.
func handle_intent(text: String, player_id: String) -> void:
	var speaker := _resolve_speaker(player_id)
	if speaker == "":
		return
	var clean := ChatCommands.sanitize(text)
	if clean == "":
		return
	# Plain chat and every non-admin command spend a token; an admin's commands are not throttled, except
	# `/say`, which broadcasts to everyone and so is plain chat in all but name.
	var is_cmd := ChatCommands.is_slash(clean)
	var bypass: bool = is_cmd and is_admin(speaker) and str(ChatCommands.parse(clean)["name"]) != "say"
	if not bypass and not _take_token(speaker):
		return
	if not is_cmd:
		_post(CHANNEL_CHAT, _name_of(speaker), clean, "")
		return
	var parsed := ChatCommands.parse(clean)
	var cmd: String = parsed["name"]
	var args: Array = parsed["args"]
	if not ChatCommands.is_known(cmd):
		_reply(speaker, "chat.unknown_command", [cmd])
		return
	if ChatCommands.is_admin_command(cmd) and not is_admin(speaker):
		_reply(speaker, "chat.admin_only", [cmd])
		return
	match cmd:
		"help":
			for key in ChatCommands.help_lines(is_admin(speaker)):
				_reply(speaker, str(key))
		"players":
			_cmd_players(speaker)
		ChatCommands.MSG_NAME:
			_cmd_msg(speaker, args)
		"say":
			_cmd_say(speaker, args)
		"tp":
			_cmd_tp(speaker, args)
		"bring":
			_cmd_bring(speaker, args)
		"give":
			_cmd_give(speaker, args)
		"kill":
			_cmd_kill(speaker, args)
		"weather":
			_cmd_weather(speaker, args)
		"time":
			_cmd_time(speaker, args)
		"speed":
			_cmd_speed(speaker, args)
		"fly":
			_cmd_fly(speaker, args)
		"heal":
			_cmd_heal(speaker, args)
		"regen":
			_cmd_regen(speaker, args)
		_:
			pass

## Spend one token of `speaker`'s bucket (plain chat and non-admin commands). False (and the line is dropped) when it is empty; the
## player is told to slow down at most once per `SLOW_DOWN_NOTICE_SEC`.
func _take_token(speaker: String) -> bool:
	var now: float = now_sec.call()
	if not _buckets.has(speaker):
		_prune_buckets(MAX_BUCKETS - 1)
		_buckets[speaker] = { "tokens": float(CHAT_BURST), "at": now, "notice_at": -INF }
	var b: Dictionary = _buckets[speaker]
	b["tokens"] = minf(float(CHAT_BURST), float(b["tokens"]) + maxf(0.0, now - float(b["at"])) * CHAT_LINES_PER_SEC)
	b["at"] = now
	if float(b["tokens"]) >= 1.0 - 1e-9:
		b["tokens"] = float(b["tokens"]) - 1.0
		return true
	chat_rate_refused += 1
	if now - float(b["notice_at"]) >= SLOW_DOWN_NOTICE_SEC:
		b["notice_at"] = now
		_reply(speaker, "chat.slow_down")
	return false

## Phase 115 — a bucket outlives its player: dropping it on disconnect let a reconnect refill it. Only
## buckets that have refilled completely (idle `CHAT_BURST / CHAT_LINES_PER_SEC` seconds) are pruned,
## and only once `MAX_BUCKETS` are held, so the map stays bounded without forgiving a recent flood.
func _on_player_left(player_id: String) -> void:
	_prune_buckets()
	_admin_moves.erase(player_id)

## Phase 182 — a (re)joining player walks normally, and its client resets its body to match on the identity.
## Dropped on the join too, so a reconnect bound before the old connection's leave is not left stale.
func _on_player_joined(_peer_id: int, player_id: String, _reconnected: bool) -> void:
	_admin_moves.erase(player_id)

func _prune_buckets(limit: int = MAX_BUCKETS) -> void:
	if _buckets.size() <= limit:
		return
	var now: float = now_sec.call()
	var full_after := float(CHAT_BURST) / CHAT_LINES_PER_SEC
	for pid in _buckets.keys():
		if now - float(_buckets[pid]["at"]) >= full_after:
			_buckets.erase(pid)
	# Still over: a burst of distinct speakers inside the refill window. Drop the least recently used,
	# so the map never exceeds `limit` (an evicted speaker restarts with a full bucket).
	while _buckets.size() > limit:
		var oldest := ""
		var oldest_at := INF
		for pid in _buckets:
			if float(_buckets[pid]["at"]) < oldest_at:
				oldest_at = float(_buckets[pid]["at"])
				oldest = str(pid)
		_buckets.erase(oldest)

# ---------------------------------------------------------------------------
# Commands (host)
# ---------------------------------------------------------------------------

func _cmd_players(speaker: String) -> void:
	var ids := _online_ids()
	var names: Array = []
	for pid in ids:
		# Phase 181 — the name, and the handle commands take (the friend code), when they differ.
		var shown := _name_of(str(pid))
		names.append(shown if shown == _handle_of(str(pid)) else "%s (%s)" % [shown, _handle_of(str(pid))])
	_reply(speaker, "chat.players", [ids.size(), ", ".join(names)])

## Phase 204 — the fabric's private-message rules (`Clan.messages`): { maxLength, perMinute }.
static func private_rules() -> Dictionary:
	var src: Resource = GameData.WORLD_SYSTEMS.get("Clan", null)
	var fab: Variant = src.get("rules") if src != null else null
	var out := PRIVATE_DEFAULTS.duplicate()
	if fab is Dictionary and (fab as Dictionary).get("messages", null) is Dictionary:
		for k: String in out:
			if (fab["messages"] as Dictionary).get(k, null) is int or (fab["messages"] as Dictionary).get(k, null) is float:
				out[k] = int(fab["messages"][k])
	return out

## Phase 204 — `/msg <player> <text>`: one private line, relayed by the host to the recipient's peer alone, with
## an echo to the sender. The player is a handle or the display name of someone online (a name of up to three
## words is matched longest first). Limited to `perMinute` per sender.
func _cmd_msg(speaker: String, args: Array) -> void:
	if args.size() < 2:
		_reply(speaker, ChatCommands.USAGE[ChatCommands.MSG_NAME])
		return
	var target := ""
	var used := 0
	for n in range(mini(3, args.size() - 1), 0, -1):
		var words: PackedStringArray = PackedStringArray()
		for i in n:
			words.append(str(args[i]))
		target = _find_named(" ".join(words), speaker)
		if target != "":
			used = n
			break
	if target == "":
		_reply(speaker, "chat.no_player", [str(args[0])])
		return
	if target == speaker:
		_reply(speaker, "chat.msg_self")
		return
	var rest: PackedStringArray = PackedStringArray()
	for i in range(used, args.size()):
		rest.append(str(args[i]))
	var r := private_rules()
	var text := " ".join(rest).left(int(r["maxLength"]))
	if not _take_private(speaker, int(r["perMinute"])):
		_reply(speaker, "chat.msg_slow", [int(r["perMinute"])])
		return
	_post(CHANNEL_WHISPER, _name_of(speaker), text, target)
	_post(CHANNEL_WHISPER_TO, _name_of(target), text, speaker)

## The online player `typed` names: a handle (as `_find_player`), else a display name, case-insensitive.
func _find_named(typed: String, speaker: String) -> String:
	var by_handle := _find_player(typed, speaker)
	if by_handle != "" and _online_ids().has(by_handle):
		return by_handle
	var want := typed.to_lower()
	for pid in _online_ids():
		if _name_of(str(pid)).to_lower() == want:
			return str(pid)
	return ""

## Record one private message for `speaker`; false when they already sent `per_minute` in the last minute.
func _take_private(speaker: String, per_minute: int) -> bool:
	var now: float = now_sec.call()
	var kept: Array = []
	for t in _private_sent.get(speaker, []):
		if now - float(t) < PRIVATE_WINDOW_SEC:
			kept.append(t)
	if kept.size() >= per_minute:
		_private_sent[speaker] = kept
		private_rate_refused += 1
		return false
	kept.append(now)
	_private_sent[speaker] = kept
	if _private_sent.size() > MAX_BUCKETS:
		for pid in _private_sent.keys():
			var times: Array = _private_sent[pid]
			if times.is_empty() or now - float(times[times.size() - 1]) >= PRIVATE_WINDOW_SEC:
				_private_sent.erase(pid)
	return true

func _cmd_say(speaker: String, args: Array) -> void:
	if args.is_empty():
		_reply(speaker, ChatCommands.USAGE["say"])
		return
	var words: PackedStringArray = PackedStringArray()
	for a in args:
		words.append(str(a))
	_post(CHANNEL_ANNOUNCE, SERVER_SENDER, " ".join(words), "")

func _cmd_tp(speaker: String, args: Array) -> void:
	if args.size() == 1:
		var target := _find_player(str(args[0]), speaker)
		if target == "":
			_reply(speaker, "chat.no_player", [args[0]])
			return
		var where := _position_of(target)
		if not where["known"]:
			_reply(speaker, "chat.pos_unknown", [_handle_of(target)])
			return
		if not _teleport(speaker, where["pos"]):
			_unreachable(speaker)
			return
		_reply(speaker, "chat.teleported_to", [_handle_of(target)])
		return
	var p := ChatCommands.parse_position(args)
	if not p["ok"]:
		var err: Dictionary = p["error"]
		_reply(speaker, str(err["key"]), err["args"])
		_reply(speaker, ChatCommands.USAGE["tp"])
		return
	if not _teleport(speaker, p["pos"]):
		_unreachable(speaker)
		return
	_reply(speaker, "chat.teleported_xyz", _coords(p["world"]))

func _cmd_bring(speaker: String, args: Array) -> void:
	if args.size() != 1:
		_reply(speaker, ChatCommands.USAGE["bring"])
		return
	var target := _find_player(str(args[0]), speaker)
	if target == "":
		_reply(speaker, "chat.no_player", [args[0]])
		return
	var here := _position_of(speaker)
	if not here["known"]:
		_reply(speaker, "chat.your_pos_unknown")
		return
	if not _teleport(target, here["pos"]):
		_unreachable(target, speaker)
		return
	_reply(speaker, "chat.brought", [_handle_of(target)])

func _cmd_give(speaker: String, args: Array) -> void:
	if args.is_empty() or args.size() > 3:
		_reply(speaker, ChatCommands.USAGE["give"])
		return
	var item := ChatCommands.match_item(str(args[0]), _known_item_ids())
	if item == "":
		_reply(speaker, "chat.unknown_item", [args[0]])
		return
	var qty := 1
	if args.size() >= 2:
		qty = ChatCommands.parse_quantity(str(args[1]))
		if qty == 0:
			_reply(speaker, "chat.qty_range", [ChatCommands.MAX_GIVE_QUANTITY])
			return
	var target := speaker
	if args.size() == 3:
		target = _find_player(str(args[2]), speaker)
		if target == "":
			_reply(speaker, "chat.no_player", [args[2]])
			return
	var inv := _inventory_of(target)
	if inv == null:
		_reply(speaker, "chat.no_inventory", [_handle_of(target)])
		return
	if not inv.add_item(item, qty):
		_reply(speaker, "chat.cannot_carry", [_handle_of(target), qty, item])
		return
	if not _is_local(target):
		GameBus.inventory_synced.emit(target, inv.get_contents(), inv.get_durability_data())
	_reply(speaker, "chat.gave", [qty, item, _handle_of(target)])
	if target != speaker:
		_reply(target, "chat.admin_gave", [qty, item])

## Phase 128 — `/weather <state> <hours>`: override the weather of the admin's own cell. The slice
## bounds the duration by the fabric's `overrideMaxHours`.
func _cmd_weather(speaker: String, args: Array) -> void:
	if weather_slice == null:
		_reply(speaker, "chat.weather_off")
		return
	if args.size() != 2 or not str(args[1]).is_valid_int():
		_reply(speaker, ChatCommands.USAGE["weather"])
		return
	var state := str(args[0]).to_lower()
	var hours := str(args[1]).to_int()
	var where := _position_of(speaker)
	if not bool(where["known"]):
		_reply(speaker, "chat.weather_where_unknown", [_handle_of(speaker)])
		return
	var pos: Dictionary = where["pos"]
	var chunk: Vector2i = pos["chunk"]
	var cell: Vector2i = weather_slice.cell_of(chunk)
	var why: String = weather_slice.set_override(cell, state, hours)
	match why:
		"":
			print("[Weather] %s set %s for %d h on cell %s" % [_handle_of(speaker), state, hours, cell])
			_reply(speaker, "chat.weather_set", [state, hours])
		"unknown_state":
			_reply(speaker, "chat.weather_unknown", [state, ", ".join(weather_slice.state_ids())])
		"too_long":
			_reply(speaker, "chat.weather_too_long", [weather_slice.override_max_hours()])
		"bad_cell":
			_reply(speaker, "chat.weather_bad_cell")
		"bad_hours":
			_reply(speaker, "chat.weather_bad_hours")
		_:
			_reply(speaker, "chat.weather_fail", [why])

## Phase 182 — `/time <hh:mm | +hours>`: move the world clock forward to that time and tell every client
## (a jump this large snaps a client's clock instead of slewing it).
func _cmd_time(speaker: String, args: Array) -> void:
	if world_clock == null:
		_reply(speaker, "chat.time_off")
		return
	if args.size() != 1:
		_reply(speaker, ChatCommands.USAGE["time"])
		return
	var r := AdminRules.parse_time(str(args[0]), float(world_clock.time_days))
	if not bool(r["ok"]):
		_reply(speaker, str(r["error"]), r["args"])
		_reply(speaker, ChatCommands.USAGE["time"])
		return
	world_clock.time_days = float(r["days"])
	if networking != null and networking.has_method("broadcast_world_clock"):
		networking.broadcast_world_clock(world_clock.time_days)
	var minutes := roundi(fposmod(world_clock.time_days, 1.0) * 1440.0) % 1440
	@warning_ignore("integer_division")
	_reply(speaker, "chat.time_set", ["%02d:%02d" % [minutes / 60, minutes % 60]])

## Phase 182 — `/speed <factor> [player]`: a walking (and flying) speed multiplier.
func _cmd_speed(speaker: String, args: Array) -> void:
	if args.is_empty() or args.size() > 2:
		_reply(speaker, ChatCommands.USAGE["speed"])
		return
	var f := AdminRules.parse_speed(str(args[0]))
	if f < 0.0:
		_reply(speaker, "chat.speed_range", [AdminRules.SPEED_MIN, AdminRules.SPEED_MAX])
		return
	var target := speaker
	if args.size() == 2:
		target = _find_player(str(args[1]), speaker)
		if target == "":
			_reply(speaker, "chat.no_player", [args[1]])
			return
	var moves := admin_moves_of(target)
	if not _send_moves(target, f, bool(moves["fly"])):
		_unreachable(target, speaker)
		return
	_reply(speaker, "chat.speed_set", [_handle_of(target), f])

## Phase 182 — `/fly [player]`: toggle flying (no gravity; Space climbs, Ctrl sinks).
func _cmd_fly(speaker: String, args: Array) -> void:
	if args.size() > 1:
		_reply(speaker, ChatCommands.USAGE["fly"])
		return
	var target := speaker
	if args.size() == 1:
		target = _find_player(str(args[0]), speaker)
		if target == "":
			_reply(speaker, "chat.no_player", [args[0]])
			return
	var moves := admin_moves_of(target)
	var fly := not bool(moves["fly"])
	if not _send_moves(target, float(moves["speed"]), fly):
		_unreachable(target, speaker)
		return
	_reply(speaker, "chat.fly_on" if fly else "chat.fly_off", [_handle_of(target)])

## Phase 182 — `/heal [player]`: back to full health. A downed player is left to respawn: healing is not
## a revive.
func _cmd_heal(speaker: String, args: Array) -> void:
	if args.size() > 1:
		_reply(speaker, ChatCommands.USAGE["heal"])
		return
	var target := speaker
	if args.size() == 1:
		target = _find_player(str(args[0]), speaker)
		if target == "":
			_reply(speaker, "chat.no_player", [args[0]])
			return
	if _is_local(target):
		if player_slice == null:
			_reply(speaker, "chat.no_body")
			return
		if player_slice.has_method("is_alive") and not player_slice.is_alive():
			_reply(speaker, "chat.heal_downed", [_handle_of(target)])
			return
		GameBus.admin_healed.emit()
	else:
		var peer := _peer_of(target)
		if networking == null or peer <= 1:
			_unreachable(target, speaker)
			return
		var hp: float = player_registry.get_hp(target) if player_registry != null else -1.0
		if hp >= 0.0 and PlayerRegistry.is_downed(hp):
			_reply(speaker, "chat.heal_downed", [_handle_of(target)])
			return
		# The peer's client first (it owns the bar), then the host's own simulation of the peer's health
		# (what the next hit is resolved against), so a heal that never left changes neither.
		if not networking.send_admin(peer, "admin_heal"):
			_unreachable(target, speaker)
			return
		player_registry.record_simulated_hp(target, player_registry.max_hp_of(target))
	_reply(speaker, "chat.healed", [_handle_of(target)])

## Phase 182 — `/regen world confirm`: regenerate the terrain (AdminWiring runs it). Without `confirm`
## the admin is told what it does and how to confirm, and nothing happens.
func _cmd_regen(speaker: String, args: Array) -> void:
	if args.is_empty() or str(args[0]).to_lower() != "world":
		_reply(speaker, ChatCommands.USAGE["regen"])
		return
	if args.size() != 2 or str(args[1]).to_lower() != "confirm":
		_reply(speaker, "chat.regen_confirm")
		return
	GameBus.world_regen_requested.emit(speaker)

## Phase 182 — `{ speed, fly }` the host last set for `player_id` (1.0 / false when none).
func admin_moves_of(player_id: String) -> Dictionary:
	return _admin_moves.get(player_id, { "speed": 1.0, "fly": false })

## Record and deliver `target`'s moves: the local body through the bus, a peer through its client.
## False when there was nobody to send them to (the record is left as it was).
func _send_moves(target: String, speed: float, fly: bool) -> bool:
	if _is_local(target):
		GameBus.admin_moves_synced.emit(speed, fly)
	else:
		var peer := _peer_of(target)
		if networking == null or peer <= 1 or not networking.send_admin(peer, "admin_moves", { "speed": speed, "fly": fly }):
			return false
	if is_equal_approx(speed, 1.0) and not fly:
		_admin_moves.erase(target)
	else:
		_admin_moves[target] = { "speed": speed, "fly": fly }
	return true

func _cmd_kill(speaker: String, args: Array) -> void:
	var target := speaker
	if not args.is_empty():
		target = _find_player(str(args[0]), speaker)
		if target == "":
			_reply(speaker, "chat.no_player", [args[0]])
			return
	if _is_local(target):
		if player_slice == null:
			_reply(speaker, "chat.no_body")
			return
		player_slice.take_damage(KILL_DAMAGE, "admin")
	else:
		var peer := _peer_of(target)
		if peer <= 1:
			_unreachable(target, speaker)
			return
		# The host's resolution of a hit on a peer (simulated HP, then the display update) lives
		# behind this signal, the same door a creature's round uses.
		GameBus.player_damaged.emit(KILL_DAMAGE, "admin", target)
	_reply(speaker, "chat.killed", [_handle_of(target)])

# ---------------------------------------------------------------------------
# Helpers (host)
# ---------------------------------------------------------------------------

## Phase 125 — move `target` to the exact `pos` (the door waystone travel shares with `/tp`).
func teleport_player(target: String, pos: Dictionary) -> bool:
	return _teleport(target, pos)

## The one failure line for a teleport that had nobody to move (no networking, an unknown or
## unreachable peer, or a dropped packet), sent to `to` (default: the unreachable player itself).
func _unreachable(player_id: String, to: String = "") -> void:
	_reply(to if to != "" else player_id, "chat.unreachable", [_handle_of(player_id)])

## `pos` is an exact `{chunk, local}` record. True only when the move was applied (local body) or sent
## (a reachable peer); false when there is nobody to move.
func _teleport(target: String, pos: Dictionary) -> bool:
	if _is_local(target):
		GameBus.player_teleport.emit(pos)
		return true
	var peer := _peer_of(target)
	if networking == null or peer <= 1:
		return false
	return networking.send_teleport(peer, pos)

## Where a player is, as an exact `{chunk, local}` record: the local body, or the host's last-known
## exact report for a peer (the float path only when the peer sent nothing exact).
func _position_of(player_id: String) -> Dictionary:
	if _is_local(player_id):
		if player_slice == null:
			return { "known": false, "pos": {} }
		return { "known": true, "pos": player_slice.get_world_pos() }
	var peer := _peer_of(player_id)
	if networking != null and peer > 1 and networking.has_last_known_state(peer):
		var exact: Dictionary = networking.get_last_known_exact(peer)
		if exact.is_empty():
			var v: Vector3 = networking.get_last_known_state(peer)
			exact = WorldPos.from_world(v.x, v.y, v.z)
		return { "known": true, "pos": exact }
	return { "known": false, "pos": {} }

## The online player a typed name means: "me", or a public handle. "" when nobody here has it.
func _find_player(typed: String, speaker: String) -> String:
	if typed.to_lower() == "me":
		return speaker
	if player_registry == null:
		return ""
	var id: String = player_registry.player_id_for_handle(typed)
	if id == "":
		var want := typed.to_lower()
		for pid in _online_ids():
			if _handle_of(str(pid)).to_lower() == want:
				return str(pid)
	return id

func _online_ids() -> Array:
	if player_registry == null:
		return []
	var ids: Array = player_registry.get_online_player_ids()
	var local: String = player_registry.local_player_id
	if local != "" and not ids.has(local) and not _is_client():
		ids = ids.duplicate()
		ids.push_front(local)
	return ids

func _inventory_of(player_id: String) -> Node:
	if _is_local(player_id):
		return inventory_slice
	if player_registry != null:
		return player_registry.get_inventory(player_id)
	return null

func _known_item_ids() -> Array:
	var ids: Array = []
	ids.append_array(GameData.ITEMS.keys())
	ids.append_array(GameData.MATERIALS.keys())
	if inventory_slice != null and "RAW_DROP_WEIGHTS" in inventory_slice:
		ids.append_array(inventory_slice.RAW_DROP_WEIGHTS.keys())
	return ids

func _is_local(player_id: String) -> bool:
	return player_registry != null and player_id == player_registry.local_player_id

func _peer_of(player_id: String) -> int:
	return int(player_registry.get_peer_id(player_id)) if player_registry != null else 0

func _handle_of(player_id: String) -> String:
	return player_registry.public_handle(player_id) if player_registry != null else player_id

## Phase 181 — the name a player is shown by in chat: their created name, else their handle.
func _name_of(player_id: String) -> String:
	if player_registry != null and player_registry.has_method("display_name"):
		return player_registry.display_name(player_id)
	return _handle_of(player_id)

func _is_client() -> bool:
	return networking != null and networking.has_method("is_client") and networking.is_client()

func _resolve_speaker(player_id: String) -> String:
	if player_id != "":
		return player_id
	return player_registry.local_player_id if player_registry != null else ""

## Coordinates travel as numbers (rounded to the 0.1 m the line shows); each client formats them with
## its own locale through `{0:1}` placeholders.
func _coords(world: Array) -> Array:
	return [snappedf(float(world[0]), 0.1), snappedf(float(world[1]), 0.1), snappedf(float(world[2]), 0.1)]

func _post(channel: String, sender: String, text: String, target: String) -> void:
	GameBus.chat_posted.emit(channel, sender, text, target)

## Phase 131 — a system line to one player as key + args; their client renders it in its own locale.
## String args are capped here so the client never has to refuse a handle for its length.
func _reply(player_id: String, key: String, args: Array = []) -> void:
	_say_system(key, args, player_id)

func _say_system(key: String, args: Array, target: String) -> void:
	var clean: Array = []
	for a in args:
		clean.append(str(a).left(I18n.MAX_ARG_LEN) if a is String else a)
	GameBus.system_message.emit(key, clean, target)

## A player reconnecting inside this window (seconds) is not announced again.
const JOIN_ANNOUNCE_COOLDOWN := 60.0
const MAX_JOIN_MEMO := 256
## Test seam: monotonic seconds.
var join_clock: Callable = func() -> float: return Time.get_ticks_msec() / 1000.0
var _last_join_announce: Dictionary = {}   # player id -> join_clock() of the last announcement

## Host: tell everyone `player_id` is here. A flapping connection announces once per cooldown.
func announce_joined(player_id: String) -> void:
	var now: float = float(join_clock.call())
	if _last_join_announce.has(player_id) and now - float(_last_join_announce[player_id]) < JOIN_ANNOUNCE_COOLDOWN:
		return
	if _last_join_announce.size() >= MAX_JOIN_MEMO:
		_last_join_announce.clear()
	_last_join_announce[player_id] = now
	_say_system("chat.player_joined", [_name_of(player_id)], "")

func _load_admins() -> void:
	_admins.clear()
	if not FileAccess.file_exists(admins_path):
		_admins_mtime = 0
		return
	_admins_mtime = FileAccess.get_modified_time(admins_path)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(admins_path))
	if not (parsed is Array):
		Diag.warn("ChatSlice: %s is not a JSON array of player ids — ignored" % admins_path)
		return
	for id in parsed:
		if id is String and id != "":
			_admins[id] = true

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

func _on_chat_intent(text: String, player_id: String) -> void:
	if _is_client():
		return   # the networking slice forwards it; the host acts
	handle_intent(text, player_id)

func _on_chat_posted(channel: String, sender: String, text: String, target_id: String) -> void:
	if target_id != "" and not _is_local(target_id):
		return
	_add_line(channel, sender, text)

func _on_system_message(key: String, args: Array, target_id: String) -> void:
	if target_id != "" and not _is_local(target_id):
		return
	_add_msg(I18n.sanitize_msg(key, args))

func _on_locale_changed(_locale: String) -> void:
	if _field != null:
		_field.placeholder_text = I18n.t("chat.field")
	if _log != null:
		_refresh_log()

# ---------------------------------------------------------------------------
# Box
# ---------------------------------------------------------------------------

## A system line kept as key + args, so a language switch re-renders what is already in the box.
func _add_msg(m: Dictionary) -> void:
	_add_line(CHANNEL_SYSTEM, "", "", m)

func _add_line(channel: String, sender: String, text: String, msg: Dictionary = {}) -> void:
	if text == "" and msg.is_empty():
		return
	_lines.append({ "channel": channel, "sender": sender, "text": text, "msg": msg,
			"born": Time.get_ticks_msec() / 1000.0 })
	while _lines.size() > MAX_LINES:
		_lines.pop_front()
	if _log != null:
		_refresh_log()

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "ChatUI"
	_layer.layer = 11
	add_child(_layer)

	var box := VBoxContainer.new()
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = 12.0
	box.offset_top = -338.0
	box.offset_right = 520.0
	box.offset_bottom = -120.0
	box.alignment = BoxContainer.ALIGNMENT_END
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(box)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.fit_content = true
	_log.scroll_active = false
	_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_log)

	_field = LineEdit.new()
	# Always on screen so the box can be found; Enter, `/` or a click gives it the keyboard.
	_field.placeholder_text = I18n.t("chat.field")
	_field.max_length = ChatCommands.MAX_PRIVATE_LINE_CHARS   # the host caps a plain line to MAX_MESSAGE_CHARS
	_field.focus_exited.connect(_on_field_focus_exited)
	_field.text_submitted.connect(_on_text_submitted)
	box.add_child(_field)

func _on_text_submitted(text: String) -> void:
	submit(text)
	_close_input()

func _close_input() -> void:
	if _field == null:
		return
	_field.text = ""
	_field.release_focus()

func _on_field_focus_exited() -> void:
	_field.text = ""

func _refresh_log() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var open := _field != null and _field.has_focus()
	var shown: Array = []
	for i in range(_lines.size() - 1, -1, -1):
		var line: Dictionary = _lines[i]
		if not open and now - float(line["born"]) > LINE_LIFETIME:
			break
		shown.push_front(line)
		if shown.size() >= VISIBLE_LINES:
			break
	var text := ""
	for line in shown:
		text += _format_line(line) + "\n"
	_log.text = text.strip_edges(false, true)

static func _format_line(line: Dictionary) -> String:
	var msg: Dictionary = line.get("msg", {})
	var body := (I18n.render(msg) if not msg.is_empty() else str(line["text"])).replace("[", "[lb]")
	var is_server: bool = str(line["channel"]) == CHANNEL_ANNOUNCE and str(line["sender"]) == SERVER_SENDER
	var sender := (I18n.t("chat.sender.server") if is_server else str(line["sender"])).replace("[", "[lb]")
	match str(line["channel"]):
		CHANNEL_ANNOUNCE:
			return "[color=#ffcc55][b]%s: %s[/b][/color]" % [sender, body]
		CHANNEL_SYSTEM:
			return "[color=#9fc7ff]%s[/color]" % body
		CHANNEL_WHISPER:
			return "[color=#d9a8ff]%s[/color] %s" % [I18n.t("chat.whisper_from", [str(line["sender"])]).replace("[", "[lb]"), body]
		CHANNEL_WHISPER_TO:
			return "[color=#b59ad6]%s[/color] %s" % [I18n.t("chat.whisper_to", [str(line["sender"])]).replace("[", "[lb]"), body]
	return "[color=#dddddd]%s:[/color] %s" % [sender, body]
