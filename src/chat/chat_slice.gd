extends Node
## Chat slice (Phase 85) — a message box, and the slash commands typed into it.
##
## Plain text is said to everyone. A line starting with `/` is a command: the player commands
## (`/help`, `/players`, `/where`) are open to all; the admin commands (`/say`, `/tp`, `/bring`,
## `/give`, `/kill`) are refused for anyone who is not an admin. Spelling and argument parsing are
## pure and live in `ChatCommands`; this slice owns the effects and the box.
##
## Authority: the host runs every command. A client forwards the line as a `chat_intent` (see
## NetworkingSlice) and the host binds the speaker to the connection — an identity in the payload is
## never read. An admin is the host's own local player, or a player id listed in `user://admins.json`
## (a JSON array of player ids, read once at boot). Everything a command does to a remote player goes
## through the existing host → peer doors (`send_teleport`, `send_player_damaged`, `inventory_synced`).
##
## Plug contract (GameBus signals consumed / emitted):
##   IN  : chat_intent(text, player_id), chat_posted(channel, sender, text, target_id)
##   OUT : chat_posted(...), player_teleport(position), player_damaged(...)
##
## Public API:
##   submit(text)                      — the local player says / runs `text`
##   handle_intent(text, player_id)    — host: act on one speaker's line
##   is_admin(player_id) -> bool
##   open_input() / is_typing() / lines() -> Array
const ChatCommands := preload("res://src/core/chat_commands.gd")
const Diag := preload("res://src/core/diag.gd")
const PlayerRules := preload("res://src/core/player_rules.gd")

const ADMINS_PATH := "user://admins.json"
## Lines kept in the log, and shown at once while the box is closed.
const MAX_LINES := 60
const VISIBLE_LINES := 8
## Seconds a line stays on screen after it arrives, while the input is closed.
const LINE_LIFETIME := 12.0
const KILL_DAMAGE := PlayerRules.MAX_HP * 100.0

const CHANNEL_CHAT := "chat"
const CHANNEL_ANNOUNCE := "announce"
const CHANNEL_SYSTEM := "system"

## Set by game_root.
var player_registry: Node = null
var player_slice: Node = null
var inventory_slice: Node = null
var networking: Node = null
## False on a headless server: no box is built, the slice only runs commands.
var render_visuals: bool = true
var admins_path: String = ADMINS_PATH

var _admins: Dictionary = {}     # player id -> true
var _lines: Array = []           # { channel, sender, text, born }
var _layer: CanvasLayer = null
var _log: RichTextLabel = null
var _field: LineEdit = null

func _ready() -> void:
	_load_admins()
	GameBus.chat_intent.connect(_on_chat_intent)
	GameBus.chat_posted.connect(_on_chat_posted)
	if render_visuals:
		_build_ui()

func _process(_delta: float) -> void:
	if _log != null:
		_refresh_log()

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
	_field.visible = true
	_field.text = prefill
	_field.grab_focus()
	_field.caret_column = prefill.length()

## The local player says or runs `text`. `/where` answers here (it only needs this machine's body);
## everything else is an intent for the host.
func submit(text: String) -> void:
	var clean := ChatCommands.sanitize(text)
	if clean == "":
		return
	if ChatCommands.is_command(clean):
		var pos: Vector3 = player_slice.get_position() if player_slice != null else Vector3.ZERO
		_add_line(CHANNEL_SYSTEM, "", ChatCommands.run(clean, pos))
		return
	GameBus.chat_intent.emit(clean, "")

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
	if not ChatCommands.is_slash(clean):
		_post(CHANNEL_CHAT, _handle_of(speaker), clean, "")
		return
	var parsed := ChatCommands.parse(clean)
	var cmd: String = parsed["name"]
	var args: Array = parsed["args"]
	if not ChatCommands.is_known(cmd):
		_reply(speaker, "Unknown command '/%s'. Try /help." % cmd)
		return
	if ChatCommands.is_admin_command(cmd) and not is_admin(speaker):
		_reply(speaker, "/%s is for admins." % cmd)
		return
	match cmd:
		"help":
			for line in ChatCommands.help_lines(is_admin(speaker)):
				_reply(speaker, str(line))
		"players":
			_cmd_players(speaker)
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
		_:
			pass

# ---------------------------------------------------------------------------
# Commands (host)
# ---------------------------------------------------------------------------

func _cmd_players(speaker: String) -> void:
	var ids := _online_ids()
	var names: Array = []
	for pid in ids:
		names.append(_handle_of(str(pid)))
	_reply(speaker, "%d online: %s" % [ids.size(), ", ".join(names)])

func _cmd_say(speaker: String, args: Array) -> void:
	if args.is_empty():
		_reply(speaker, ChatCommands.USAGE["say"])
		return
	var words: PackedStringArray = PackedStringArray()
	for a in args:
		words.append(str(a))
	_post(CHANNEL_ANNOUNCE, "Server", " ".join(words), "")

func _cmd_tp(speaker: String, args: Array) -> void:
	if args.size() == 1:
		var target := _find_player(str(args[0]), speaker)
		if target == "":
			_reply(speaker, "No player '%s' online." % args[0])
			return
		var where := _position_of(target)
		if not where["known"]:
			_reply(speaker, "Position of %s is unknown." % _handle_of(target))
			return
		_teleport(speaker, where["pos"])
		_reply(speaker, "Teleported to %s." % _handle_of(target))
		return
	var p := ChatCommands.parse_position(args)
	if not p["ok"]:
		_reply(speaker, "%s  (%s)" % [p["error"], ChatCommands.USAGE["tp"]])
		return
	_teleport(speaker, p["pos"])
	_reply(speaker, "Teleported to %s." % _fmt(p["pos"]))

func _cmd_bring(speaker: String, args: Array) -> void:
	if args.size() != 1:
		_reply(speaker, ChatCommands.USAGE["bring"])
		return
	var target := _find_player(str(args[0]), speaker)
	if target == "":
		_reply(speaker, "No player '%s' online." % args[0])
		return
	var here := _position_of(speaker)
	if not here["known"]:
		_reply(speaker, "Your position is unknown.")
		return
	_teleport(target, here["pos"])
	_reply(speaker, "Brought %s to you." % _handle_of(target))

func _cmd_give(speaker: String, args: Array) -> void:
	if args.is_empty() or args.size() > 3:
		_reply(speaker, ChatCommands.USAGE["give"])
		return
	var item := ChatCommands.match_item(str(args[0]), _known_item_ids())
	if item == "":
		_reply(speaker, "Unknown item '%s'." % args[0])
		return
	var qty := 1
	if args.size() >= 2:
		qty = ChatCommands.parse_quantity(str(args[1]))
		if qty == 0:
			_reply(speaker, "Quantity must be 1–%d." % ChatCommands.MAX_GIVE_QUANTITY)
			return
	var target := speaker
	if args.size() == 3:
		target = _find_player(str(args[2]), speaker)
		if target == "":
			_reply(speaker, "No player '%s' online." % args[2])
			return
	var inv := _inventory_of(target)
	if inv == null:
		_reply(speaker, "%s has no inventory here." % _handle_of(target))
		return
	if not inv.add_item(item, qty):
		_reply(speaker, "%s cannot carry %d × %s." % [_handle_of(target), qty, item])
		return
	if not _is_local(target):
		GameBus.inventory_synced.emit(target, inv.get_contents(), inv.get_durability_data())
	_reply(speaker, "Gave %d × %s to %s." % [qty, item, _handle_of(target)])
	if target != speaker:
		_reply(target, "An admin gave you %d × %s." % [qty, item])

func _cmd_kill(speaker: String, args: Array) -> void:
	var target := speaker
	if not args.is_empty():
		target = _find_player(str(args[0]), speaker)
		if target == "":
			_reply(speaker, "No player '%s' online." % args[0])
			return
	if _is_local(target):
		if player_slice == null:
			_reply(speaker, "No body to kill here.")
			return
		player_slice.take_damage(KILL_DAMAGE, "admin")
	else:
		var peer := _peer_of(target)
		if networking == null or peer <= 1:
			_reply(speaker, "%s is not reachable." % _handle_of(target))
			return
		networking.send_player_damaged(peer, KILL_DAMAGE, "admin")
	_reply(speaker, "Killed %s." % _handle_of(target))

# ---------------------------------------------------------------------------
# Helpers (host)
# ---------------------------------------------------------------------------

func _teleport(target: String, pos: Vector3) -> void:
	if _is_local(target):
		GameBus.player_teleport.emit(pos)
		return
	var peer := _peer_of(target)
	if networking != null and peer > 1:
		networking.send_teleport(peer, pos)

## Where a player is: the local body, or the host's last-known state for a peer.
func _position_of(player_id: String) -> Dictionary:
	if _is_local(player_id):
		if player_slice == null:
			return { "known": false, "pos": Vector3.ZERO }
		return { "known": true, "pos": player_slice.get_position() }
	var peer := _peer_of(player_id)
	if networking != null and peer > 1 and networking.has_last_known_state(peer):
		return { "known": true, "pos": networking.get_last_known_state(peer) }
	return { "known": false, "pos": Vector3.ZERO }

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

func _is_client() -> bool:
	return networking != null and networking.has_method("is_client") and networking.is_client()

func _resolve_speaker(player_id: String) -> String:
	if player_id != "":
		return player_id
	return player_registry.local_player_id if player_registry != null else ""

func _fmt(pos: Vector3) -> String:
	return "%.1f, %.1f, %.1f" % [pos.x, pos.y, pos.z]

func _post(channel: String, sender: String, text: String, target: String) -> void:
	GameBus.chat_posted.emit(channel, sender, text, target)

func _reply(player_id: String, text: String) -> void:
	_post(CHANNEL_SYSTEM, "", text, player_id)

func _load_admins() -> void:
	_admins.clear()
	if not FileAccess.file_exists(admins_path):
		return
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

# ---------------------------------------------------------------------------
# Box
# ---------------------------------------------------------------------------

func _add_line(channel: String, sender: String, text: String) -> void:
	if text == "":
		return
	_lines.append({ "channel": channel, "sender": sender, "text": text,
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
	box.offset_top = -270.0
	box.offset_right = 520.0
	box.offset_bottom = -52.0
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
	_field.placeholder_text = "Say something, or /help"
	_field.max_length = ChatCommands.MAX_MESSAGE_CHARS
	_field.visible = false
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
	_field.visible = false

func _refresh_log() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var open := _field != null and _field.visible
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
	var body := str(line["text"]).replace("[", "[lb]")
	var sender := str(line["sender"]).replace("[", "[lb]")
	match str(line["channel"]):
		CHANNEL_ANNOUNCE:
			return "[color=#ffcc55][b]%s: %s[/b][/color]" % [sender, body]
		CHANNEL_SYSTEM:
			return "[color=#9fc7ff]%s[/color]" % body
	return "[color=#dddddd]%s:[/color] %s" % [sender, body]
