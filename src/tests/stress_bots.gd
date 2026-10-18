extends Node
## Phase 162 — `--stress-bots <n>`: this process is a crowd, not a game. It opens `n` light bot
## connections to a host, each its own ENet peer and player identity (a `StressBotSlice`, the shipped
## networking slice in the client role, under its own `SceneMultiplayer`), walks them in one of the
## seeded patterns of `StressRules`, and writes what it saw to `--stress-out` for the report.
##
## Each bot lives in its own subtree, `bot_<i>/Node/GameRoot/networking_slice`, with a custom
## multiplayer rooted at `bot_<i>`: the node path the host's RPCs name is then the same one a real
## client has (`/root/Node/GameRoot/networking_slice`), so the host cannot tell a bot from a player.
## There is no terrain, no rendering and no other slice in this process.
##
## Timeline: bots join at `JOIN_PER_SECOND` (a real crowd trickles in; a 200-peer burst in one frame
## measures the burst, not the crowd), and once every bot has joined — or `STEADY_DEADLINE_S` passed —
## the process creates the `--stress-steady` file the host and the watcher sample under. After
## `--stress-seconds` of steady state it removes the file, disconnects every bot, writes its report and
## quits. Under `churn` bots leave and rejoin (with the identity they were given) on the pattern's clock.
##
## Args (user args, after `--`): `--stress-bots <n>` `--stress-pattern <name>` `--stress-seed <int>`
## `--stress-seconds <s>` `--stress-out <path>` `--stress-steady <path>` `--stress-addr <host>`.

const StressRules := preload("res://src/tests/stress_rules.gd")
const StressBotSlice := preload("res://src/tests/stress_bot_slice.gd")
const WorldPos := preload("res://src/terrain/world_pos.gd")
const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")
const NetworkingSlice := preload("res://src/networking/networking_slice.gd")
const Diag := preload("res://src/core/diag.gd")

const ARG := "--stress-bots"
const JOIN_PER_SECOND := 20.0
const STEADY_DEADLINE_S := 30.0
## A bot that has no join snapshot this long after connecting failed its handshake.
const JOIN_TIMEOUT_S := 30.0
## Re-present the join intent this often while the snapshot is missing (the client's own retry).
const HANDSHAKE_RETRY_S := 3.0
const MAX_HANDSHAKE_RETRIES := 3
## How long the bots wait for the host to acknowledge their graceful disconnects at the end.
const GOODBYE_WAIT_S := 20.0
## Frames to keep pumping after the last disconnect, so the goodbyes leave the socket.
const DRAIN_FRAMES := 30

var n := 0
var pattern := "cluster"
var run_seed := 1
var seconds := 20.0
var out_path := ""
var steady_path := ""
var address := "127.0.0.1"

## One entry per bot: { holder, slice, index, online, leaving, joined_once, connect_s, walk_s,
## next_send_s, retries, anchor, failed }.
var _bots: Array = []
var _clock_s := 0.0
var _steady_s := -1.0
var _done := false
## send key "<peer>|<position key>" -> unix ms, for the relay-lag join.
var _sends: Dictionary = {}
var _dropped_unexpected := 0
var _dropped_detail: Array = []
var _join_failures := 0
var _reconnects := 0
var _reports := 0

static func requested(args: Array) -> bool:
	return args.has(ARG)

static func arg_value(args: Array, name: String, fallback: String) -> String:
	var i := args.find(name)
	if i < 0 or i + 1 >= args.size() or str(args[i + 1]).begins_with("--"):
		return fallback
	return str(args[i + 1])

func _ready() -> void:
	var args := Array(OS.get_cmdline_user_args())
	n = int(arg_value(args, ARG, "0"))
	pattern = arg_value(args, "--stress-pattern", "cluster")
	run_seed = int(arg_value(args, "--stress-seed", "1"))
	seconds = float(arg_value(args, "--stress-seconds", "20"))
	out_path = arg_value(args, "--stress-out", "")
	steady_path = arg_value(args, "--stress-steady", "")
	address = arg_value(args, "--stress-addr", "127.0.0.1")
	if n <= 0 or not StressRules.is_pattern(pattern):
		push_error("stress-bots: need --stress-bots <n> > 0 and a --stress-pattern in %s" % [StressRules.PATTERNS])
		get_tree().quit(2)
		return
	if steady_path != "":
		DirAccess.remove_absolute(steady_path)
	# Every bot logs what a client logs (a seq gap on a per-type counter the host shares across peers,
	# say); n bots make that n lines, so they print as plain lines without engine backtraces.
	Diag.quiet = true
	print("[Stress] bots: %d, pattern %s, seed %d, %.0f s steady, host %s" % [n, pattern, run_seed, seconds, address])
	for i in range(n):
		_bots.append(_make_bot(i))

func _make_bot(i: int) -> Dictionary:
	var holder := Node.new()
	holder.name = "bot_%d" % i
	add_child(holder)
	get_tree().set_multiplayer(SceneMultiplayer.new(), holder.get_path())
	var game := Node.new()
	game.name = "Node"
	holder.add_child(game)
	var root := Node.new()
	root.name = "GameRoot"
	game.add_child(root)
	var slice: Node = StressBotSlice.new()
	slice.name = "networking_slice"
	root.add_child(slice)
	var bot := {
		"holder": holder, "slice": slice, "index": i, "online": false, "leaving": false,
		"joined_once": false, "connect_s": -1.0, "walk_s": -1.0, "next_send_s": 0.0, "retries": 0,
		"anchor": {}, "failed": false, "due_s": float(i) / JOIN_PER_SECOND,
	}
	holder.multiplayer.server_disconnected.connect(_on_dropped.bind(bot))
	return bot

func _on_dropped(bot: Dictionary) -> void:
	if bot["leaving"]:
		# The host acknowledged our goodbye: now the transport state can go.
		bot["leaving"] = false
		(bot["slice"] as Node).disconnect_all.call_deferred()
		return
	if _done:
		return
	bot["online"] = false
	bot["failed"] = true
	_dropped_unexpected += 1
	_dropped_detail.append("bot %d at %.1f s" % [int(bot["index"]), _clock_s])

func _process(delta: float) -> void:
	if _done:
		return
	_clock_s += delta
	var all_joined := true
	for bot in _bots:
		_tick_bot(bot)
		if not bot["joined_once"] and not bot["failed"]:
			all_joined = false
	if _steady_s < 0.0 and (all_joined or _clock_s >= STEADY_DEADLINE_S):
		_steady_s = _clock_s
		if steady_path != "":
			FileAccess.open(steady_path, FileAccess.WRITE).store_string("steady\n")
		print("[Stress] steady: %d/%d bots joined at %.1f s" % [_joined_count(), n, _clock_s])
	if _steady_s >= 0.0 and _clock_s - _steady_s >= seconds:
		_finish()

func _leaving_count() -> int:
	var c := 0
	for bot in _bots:
		if bot["leaving"]:
			c += 1
	return c

func _joined_count() -> int:
	var c := 0
	for bot in _bots:
		if bot["joined_once"]:
			c += 1
	return c

## The bot's clock: seconds since it first walked (the pattern's `t`).
func _tick_bot(bot: Dictionary) -> void:
	if bot["failed"] or _clock_s < float(bot["due_s"]):
		return
	var slice: Node = bot["slice"]
	var t_pattern := _clock_s - float(bot["due_s"])
	var want_online := StressRules.online_at(pattern, run_seed, int(bot["index"]), t_pattern)
	if want_online and not bot["online"]:
		_connect(bot)
	elif not want_online and bot["online"]:
		_leave(bot)
		return
	if not bot["online"]:
		return
	if not slice.snapshot_done:
		var waited := _clock_s - float(bot["connect_s"])
		if waited > JOIN_TIMEOUT_S:
			bot["failed"] = true
			_join_failures += 1
			_leave(bot)
		elif waited > HANDSHAKE_RETRY_S * float(int(bot["retries"]) + 1) and int(bot["retries"]) < MAX_HANDSHAKE_RETRIES:
			bot["retries"] = int(bot["retries"]) + 1
			slice.request_handshake()
		return
	if not bot["joined_once"]:
		bot["joined_once"] = true
	if (bot["anchor"] as Dictionary).is_empty():
		bot["anchor"] = _anchor_for(slice.spawn)
		bot["walk_s"] = t_pattern
		bot["next_send_s"] = _clock_s + StressRules.SEND_INTERVAL * _phase(int(bot["index"]))
	if not (slice.teleported as Dictionary).is_empty():
		bot["anchor"] = slice.teleported
		bot["walk_s"] = t_pattern
		slice.teleported = {}
	if _clock_s < float(bot["next_send_s"]):
		return
	bot["next_send_s"] = float(bot["next_send_s"]) + StressRules.SEND_INTERVAL
	var pos := _position(bot, t_pattern)
	var key: String = slice.report(pos)
	_sends["%d|%s" % [slice.multiplayer.get_unique_id(), key]] = int(Time.get_unix_time_from_system() * 1000.0)
	_reports += 1

## Spread each bot's report over the interval, so n bots do not all report in one frame.
func _phase(index: int) -> float:
	return fposmod(float(index) * 0.618034, 1.0)

func _connect(bot: Dictionary) -> void:
	var slice: Node = bot["slice"]
	if bot["joined_once"]:
		_reconnects += 1
	bot["leaving"] = false
	bot["retries"] = 0
	bot["connect_s"] = _clock_s
	bot["anchor"] = {}
	var err: Error = slice.connect_to(address, NetworkingSlice.DEFAULT_PORT)
	if err != OK:
		bot["failed"] = true
		_join_failures += 1
		return
	bot["online"] = true

func _leave(bot: Dictionary) -> void:
	bot["leaving"] = true
	bot["online"] = false
	(bot["slice"] as Node).leave()

## Where a bot's pattern is anchored: its join spawn, or for `pole` a point on the same meridian a few
## chunks short of the polar fold row.
func _anchor_for(spawn: Dictionary) -> Dictionary:
	var at: Dictionary = spawn if not spawn.is_empty() else WorldPos.from_world(16.0, 0.0, 16.0)
	if pattern != "pole":
		return at
	var row := TerrainSlice.pole_chunks() + TerrainSlice.FOLD_MARGIN_CHUNKS - StressRules.POLE_START_CHUNKS
	return { "chunk": Vector2i((at["chunk"] as Vector2i).x, row), "local": Vector3(16.0, TerrainSlice.pole_field() + 1.0, 0.0) }

## The bot's position `t` seconds into the pattern: the anchor plus the pattern's offset, folded back
## onto the planet the way a walking client folds itself (`TerrainSlice.fold_world_pos`).
func _position(bot: Dictionary, t_pattern: float) -> Dictionary:
	var anchor: Dictionary = bot["anchor"]
	var off := StressRules.bot_offset(pattern, run_seed, int(bot["index"]), t_pattern - float(bot["walk_s"]))
	var local: Vector3 = anchor["local"]
	var raw := WorldPos.normalized({ "chunk": anchor["chunk"], "local": Vector3(local.x + off.x, local.y, local.z + off.y) })
	return TerrainSlice.fold_world_pos(raw)["pos"]

func _finish() -> void:
	_done = true
	if steady_path != "":
		DirAccess.remove_absolute(steady_path)
	for bot in _bots:
		if bot["online"]:
			_leave(bot)
	# Wait for the host to acknowledge every goodbye (or GOODBYE_WAIT_S), then a few frames more.
	var deadline := Time.get_ticks_msec() + int(GOODBYE_WAIT_S * 1000.0)
	while _leaving_count() > 0 and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var unacknowledged := _leaving_count()
	for bot in _bots:
		(bot["slice"] as Node).disconnect_all()
	for i in range(DRAIN_FRAMES):
		await get_tree().process_frame
	var report := {
		"role": "bots",
		"n": n,
		"pattern": pattern,
		"seed": run_seed,
		"seconds": seconds,
		"joined": _joined_count(),
		"join_failures": _join_failures,
		"dropped_unexpected": _dropped_unexpected,
		"dropped_detail": _dropped_detail,
		"reconnects": _reconnects,
		"goodbyes_unacknowledged": unacknowledged,
		"reports": _reports,
		"sends": _sends,
	}
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(report))
			f.close()
	print("[Stress] bots done: %d joined, %d join failures, %d dropped, %d reconnects, %d reports" % [
		_joined_count(), _join_failures, _dropped_unexpected, _reconnects, _reports])
	get_tree().quit(0)
