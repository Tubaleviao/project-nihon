extends Node
## Phase 162 — the measuring half of the crowd stress run, in two roles:
##
##   • `--stress-host <out.json>` on a `--server` boot: a dedicated server in a fresh save directory
##     on a pinned world seed, with every new player placed at one anchor (so the bots, which spawn
##     where the host puts them, and the watcher stand in the same crowd). Per tick it records the
##     tick time and its split by phase (`TickProbe`), bytes and packets per peer and per message
##     type, peers per AOI cell, ENet link health (round trip, packet loss, throttle), chunk builds and waits, region reads, memory and
##     node count. When the stop file appears it waits for every peer to leave, counts the per-peer
##     records the host still holds (an orphan is a hard failure) and writes the report.
##   • `--stress-watch <out.json>` on a `--net-harness client` boot: a full client that joins the
##     host through the shipped client boot and stands inside the crowd, recording its frame time, the
##     remote avatars it shows, bytes received, the cost of applying position relays, and each relay's
##     arrival time (joined with the bots' send times for the relay lag).
##
## Both sample only while the bots' `--stress-steady` file exists (every bot has joined), so the join
## ramp and the leave tail are not in the numbers. Both run at 60 frames per second: a server ticks at
## its tick rate, and an uncapped headless loop would report thousands of empty frames.

const TickProbe := preload("res://src/core/tick_probe.gd")
const WorldPos := preload("res://src/terrain/world_pos.gd")
const WorldShape := preload("res://src/terrain/world_shape.gd")
const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")
const StressRules := preload("res://src/tests/stress_rules.gd")

const HOST_ARG := "--stress-host"
const WATCH_ARG := "--stress-watch"
## The stress host's own save directory, emptied before the boot (never a real save).
const SAVE_DIR := "user://stress/server/"
## The world seed every stress run uses, so runs on different commits are comparable.
const WORLD_SEED := 162
## The stress host's connection cap: the top of the ladder plus the watcher, with room to spare.
const MAX_CLIENTS := 256
## Frames per second both roles run at.
const TICK_RATE := 60
## A host frame this slow (ms) keeps its phase split in the report: the SLOW_FRAMES_KEPT slowest.
const SLOW_FRAME_MS := 8.0
const SLOW_FRAMES_KEPT := 200
## How long the host waits for the last peer to leave after the stop file, and then settles (s).
const LEAVE_WAIT_S := 45.0
const SETTLE_S := 1.0

var role := ""
var out_path := ""
var steady_path := ""
var stop_path := ""
var _root: Node = null

## Start of the current frame's work (µs), or -1 before it.
var _frame_t0 := -1
var _last_frame_us := -1
var _sampling := false
var _window_s := 0.0
var _tick_ms: Array = []
var _frame_ms: Array = []
var _gap_max_ms := 0.0
var _phase_us: Dictionary = {}
## The slowest frames' phase split: [[work_ms, { phase: µs }], ...] for frames over SLOW_FRAME_MS.
var _slow_frames: Array = []
var _wire := { "out_peer": {}, "in_peer": {}, "out_type": {}, "in_type": {} }
var _peer_seconds: Dictionary = {}
var _peers_max := 0
var _cell_peers_max := 0
var _rtt: Array = []
var _loss: Array = []
var _throttle_min := 100000.0
var _rtt_clock := 0.0
var _chunks_in_flight_max := 0
var _chunks_waiting_max := 0
var _region_reads_start := -1
var _memory_mb_max := 0.0
var _nodes_max := 0
var _avatars_max := 0
var _avatar_sum := 0.0
var _relays: Array = []
var _ready_printed := false
var _stopping := false
var _stop_clock := 0.0
var _empty_since := -1.0

static func role_from_args(args: Array) -> String:
	if args.has(HOST_ARG):
		return "host"
	if args.has(WATCH_ARG):
		return "watch"
	return ""

static func _arg(args: Array, name: String) -> String:
	var i := args.find(name)
	return str(args[i + 1]) if i >= 0 and i + 1 < args.size() and not str(args[i + 1]).begins_with("--") else ""

## Before the world boot: a host gets its own emptied save directory and the pinned seed.
static func prepare(root: Node) -> void:
	if role_from_args(Array(OS.get_cmdline_user_args())) != "host" or not root._is_server:
		return
	root._persistence.server_save_dir = SAVE_DIR
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	_clear_dir(SAVE_DIR)
	root._terrain.set_world_seed(WORLD_SEED)
	root._boot_wiring.max_clients = MAX_CLIENTS

static func _clear_dir(path: String) -> void:
	if not path.begins_with("user://stress/") or ".." in path:
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_clear_dir(path.path_join(sub))
		dir.remove(sub)
	for file in dir.get_files():
		dir.remove(file)

## After the world boot: attach the recorder for this boot's role (none for a normal boot).
static func attach(root: Node) -> void:
	var args := Array(OS.get_cmdline_user_args())
	var r := role_from_args(args)
	if r == "" or (r == "host" and not root._is_server) or (r == "watch" and not root._is_client):
		return
	var rec: Node = (load("res://src/tests/stress_recorder.gd") as GDScript).new()
	rec.name = "StressRecorder"
	rec.role = r
	rec.out_path = _arg(args, HOST_ARG if r == "host" else WATCH_ARG)
	rec.steady_path = _arg(args, "--stress-steady")
	rec.stop_path = _arg(args, "--stress-stop")
	rec._root = root
	root.add_child(rec)

func _ready() -> void:
	Engine.max_fps = TICK_RATE
	# The tick is timed from the start of the physics step (which precedes the network poll and the
	# process pass) to this node's `_process`, which runs after every other node's.
	process_priority = 1_000_000
	get_tree().physics_frame.connect(_mark_frame_start)
	get_tree().process_frame.connect(_mark_frame_start)
	TickProbe.reset()
	TickProbe.enabled = true
	TickProbe.log_relays = role == "watch"
	if role == "host":
		var anchor := _anchor()
		_root._registry.set_spawn_placer(func(_player_id: String, _code: String) -> Dictionary:
			return { "position": anchor, "source": "search", "message": "" })
		print("[Stress] host recorder: seed %d, anchor %s" % [int(_root._terrain.get_world_seed()), anchor])

## Where every new player is placed: the world spawn point, a metre above the ground or the sea. For
## the `pole` pattern it is where the bots start their walk, a few chunks short of the polar fold (see
## `StressBots._anchor_for`), so the crowd walks to the fold instead of every bot claiming a
## ten-thousand-kilometre jump at once, and the watcher stands in that crowd.
func _anchor() -> Vector3:
	if _arg(Array(OS.get_cmdline_user_args()), "--stress-pattern") == "pole":
		var row := TerrainSlice.pole_chunks() + TerrainSlice.FOLD_MARGIN_CHUNKS - StressRules.POLE_START_CHUNKS
		return Vector3(16.0, TerrainSlice.pole_field() + 1.0, float(row) * TerrainSlice.CHUNK_METERS)
	var xz := WorldShape.SPAWN_CENTER
	var ground: float = maxf(float(_root._terrain.get_height_at(xz)), WorldShape.sea_level())
	return Vector3(xz.x, ground + 1.0, xz.y)

func _mark_frame_start() -> void:
	if _frame_t0 < 0:
		_frame_t0 = Time.get_ticks_usec()

## This frame's work so far (ms): physics step, network poll and every node's process pass.
func _take_frame_work_ms() -> float:
	var ms := float(Time.get_ticks_usec() - _frame_t0) / 1000.0 if _frame_t0 >= 0 else 0.0
	_frame_t0 = -1
	return ms

func _process(delta: float) -> void:
	var work_ms := _take_frame_work_ms()
	# The frame's wall time, from this node's last pass: the engine clamps `delta` after a long stall,
	# which would hide exactly the frame the hard-failure check is for.
	var now_us := Time.get_ticks_usec()
	var wall_ms := float(now_us - _last_frame_us) / 1000.0 if _last_frame_us >= 0 else delta * 1000.0
	_last_frame_us = now_us
	if role == "watch" and not _ready_printed and bool(_root._client_boot_done):
		_ready_printed = true
		print("[Stress] watcher ready")
	if _stopping:
		_tick_stop(delta)
		return
	var steady := steady_path != "" and FileAccess.file_exists(steady_path)
	if steady and not _sampling:
		_sampling = true
		TickProbe.take_times()
		TickProbe.take_wire()
		TickProbe.take_relays()
	if steady:
		_sample(delta, work_ms, wall_ms)
	else:
		_sampling = false
		TickProbe.take_times()
		TickProbe.take_wire()
		TickProbe.take_relays()
	if stop_path != "" and FileAccess.file_exists(stop_path):
		_begin_stop()

func _sample(delta: float, work_ms: float, wall_ms: float) -> void:
	_window_s += delta
	_gap_max_ms = maxf(_gap_max_ms, wall_ms)
	var times := TickProbe.take_times()
	_merge_times(times)
	if work_ms >= SLOW_FRAME_MS:
		_keep_slow_frame(work_ms, times)
	_merge_wire(TickProbe.take_wire())
	_memory_mb_max = maxf(_memory_mb_max, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
	_nodes_max = maxi(_nodes_max, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	if role == "host":
		_sample_host(delta, work_ms)
	else:
		_sample_watch(delta, wall_ms)

## Keep the SLOW_FRAMES_KEPT slowest frames (the list is unordered; the fastest kept one is replaced).
func _keep_slow_frame(work_ms: float, times: Dictionary) -> void:
	if _slow_frames.size() < SLOW_FRAMES_KEPT:
		_slow_frames.append([work_ms, times])
		return
	var lo := 0
	for i in range(1, _slow_frames.size()):
		if float(_slow_frames[i][0]) < float(_slow_frames[lo][0]):
			lo = i
	if work_ms > float(_slow_frames[lo][0]):
		_slow_frames[lo] = [work_ms, times]

func _merge_times(times: Dictionary) -> void:
	for k in times:
		_phase_us[k] = int(_phase_us.get(k, 0)) + int(times[k])

func _merge_wire(w: Dictionary) -> void:
	for table in w:
		var into: Dictionary = _wire[table]
		for key in w[table]:
			var row: Array = into.get(key, [0, 0])
			var add: Array = w[table][key]
			into[key] = [int(row[0]) + int(add[0]), int(row[1]) + int(add[1])]

func _sample_host(delta: float, work_ms: float) -> void:
	_tick_ms.append(work_ms)
	var net: Node = _root._networking
	var peers: Array = net.connected_peers()
	_peers_max = maxi(_peers_max, peers.size())
	var cells := {}
	for p in peers:
		_peer_seconds[int(p)] = float(_peer_seconds.get(int(p), 0.0)) + delta
		var cell: Vector2i = net.aoi_region(net.get_aoi_center(int(p)))
		cells[cell] = int(cells.get(cell, 0)) + 1
	for c in cells:
		_cell_peers_max = maxi(_cell_peers_max, int(cells[c]))
	var cm: Node = _root._chunk_manager
	_chunks_in_flight_max = maxi(_chunks_in_flight_max, cm._builds.size())
	_chunks_waiting_max = maxi(_chunks_waiting_max, cm._load_queue.size())
	if cm.region_streamer != null and _region_reads_start < 0:
		_region_reads_start = int(cm.region_streamer.reads_started)
	_rtt_clock += delta
	if _rtt_clock >= 1.0:
		_rtt_clock = 0.0
		var mp: MultiplayerPeer = _root.multiplayer.multiplayer_peer
		if mp is ENetMultiplayerPeer:
			for p in peers:
				var pp: ENetPacketPeer = (mp as ENetMultiplayerPeer).get_peer(int(p))
				if pp != null:
					_rtt.append(pp.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
					_loss.append(pp.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS))
					_throttle_min = minf(_throttle_min, pp.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE))

func _sample_watch(_delta: float, wall_ms: float) -> void:
	_frame_ms.append(wall_ms)
	var avatars: int = (_root._peer_wiring._remote_avatars as Dictionary).size()
	_avatars_max = maxi(_avatars_max, avatars)
	_avatar_sum += float(avatars)
	_relays.append_array(TickProbe.take_relays())

func _begin_stop() -> void:
	_stopping = true
	_sampling = false
	_stop_clock = 0.0
	if role == "watch":
		# Leave the host properly, so its peer record goes now and not at an ENet timeout.
		_root._networking.disconnect_all()

## The host waits for every peer to leave (the bots already have; the watcher is leaving), lets the
## disconnect handlers run, then counts what it still holds per peer. The watcher just lets its
## goodbye leave the socket.
func _tick_stop(delta: float) -> void:
	_stop_clock += delta
	if role == "watch":
		if _stop_clock >= SETTLE_S:
			_write(_watch_report())
		return
	var connected: int = (_root._networking.connected_peers() as Array).size()
	if connected == 0 and _empty_since < 0.0:
		_empty_since = _stop_clock
	if (_empty_since >= 0.0 and _stop_clock - _empty_since >= SETTLE_S) or _stop_clock >= LEAVE_WAIT_S:
		_write(_host_report(connected))

func _host_report(connected: int) -> Dictionary:
	var net: Node = _root._networking
	var cm: Node = _root._chunk_manager
	var reads := 0
	if cm.region_streamer != null:
		reads = int(cm.region_streamer.reads_started) - maxi(_region_reads_start, 0)
	var args := Array(OS.get_cmdline_user_args())
	return {
		"role": "host",
		"profile": str(net.net_profile) if str(net.net_profile) != "" else "loopback",
		"window_s": _window_s,
		"tick_ms": _tick_ms,
		"frame_gap_max_ms": _gap_max_ms,
		"phase_us": _phase_us,
		"slow_frames": _slow_frames,
		"out_peer": _keyed(_wire["out_peer"]),
		"in_peer": _keyed(_wire["in_peer"]),
		"out_type": _wire["out_type"],
		"in_type": _wire["in_type"],
		"peer_seconds": _keyed(_peer_seconds),
		"peers_max": _peers_max,
		"aoi_cell_peers_max": _cell_peers_max,
		"rtt_ms_p95": StressRules.percentile(_rtt, 95.0),
		"enet_loss_p95": StressRules.percentile(_loss, 95.0),
		"enet_throttle_min": _throttle_min,
		"chunks_in_flight_max": _chunks_in_flight_max,
		"chunks_waiting_max": _chunks_waiting_max,
		"region_reads": reads,
		"memory_mb_max": _memory_mb_max,
		"nodes_max": _nodes_max,
		"connected_at_end": connected,
		"orphans": orphans(_root) if connected == 0 else { "peers_still_connected": connected },
		"pattern": _arg(args, "--stress-pattern"),
	}

## Per-peer records a host still holds when no peer is connected: each count should be zero. The
## last-known positions are NOT here — they are kept on purpose for a reconnect and age out on a TTL.
static func orphans(root: Node) -> Dictionary:
	var net: Node = root._networking
	return {
		"player_ids": (net._player_ids as Dictionary).size(),
		"rate_buckets": (net._rate_buckets as Dictionary).size(),
		"equipment_pairs": (net._equipment_sent as Dictionary).size(),
		"equipment_eval_positions": (net._equipment_eval_positions as Dictionary).size(),
		"recv_seq_channels": (net._recv_seq as Dictionary).size() + (net._recv_seen as Dictionary).size(),
		"emulated_links": (net._link_free_at_ms as Dictionary).size() + (net._ordered_at_ms as Dictionary).size(),
		"bound_peers": (root._registry.get_peer_ids() as Array).size(),
		"peer_windows": int(root._chunk_manager.peer_window_count()),
		"aoi_regions": (root._peer_aoi_regions as Dictionary).size(),
		"records_clocks": (root._peer_records_msec as Dictionary).size(),
	}

func _watch_report() -> Dictionary:
	var in_type: Dictionary = _wire["in_type"]
	var relay_row: Array = in_type.get("remote_player_state", [0, 0])
	var batch_row: Array = in_type.get("remote_player_states", [0, 0])   # Phase 163: one packet per tick
	relay_row = [int(relay_row[0]) + int(batch_row[0]), int(relay_row[1]) + int(batch_row[1])]
	var in_bytes := 0
	for k in _wire["in_peer"]:
		in_bytes += int((_wire["in_peer"][k] as Array)[0])
	return {
		"role": "watch",
		"window_s": _window_s,
		"frame_ms": _frame_ms,
		"frame_gap_max_ms": _gap_max_ms,
		"avatars_max": _avatars_max,
		"avatars_mean": _avatar_sum / maxf(1.0, float(_frame_ms.size())),
		"bytes_in": in_bytes,
		"in_type": in_type,
		"relays": int(relay_row[1]),
		"relay_apply_us": int(_phase_us.get("relay_apply", 0)),
		"phase_us": _phase_us,
		"relay_seen": _relays,
	}

## JSON object keys are strings: peer ids are written as such.
static func _keyed(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[str(k)] = d[k]
	return out

func _write(report: Dictionary) -> void:
	set_process(false)
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(report))
			f.close()
	print("[Stress] %s report written: %s" % [role, out_path])
	TickProbe.reset()
	get_tree().quit(0)
