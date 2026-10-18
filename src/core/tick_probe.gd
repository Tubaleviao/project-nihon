extends RefCounted
## Phase 162 — the crowd stress run's cost probe. Off by default: every call is one static bool test,
## so a normal boot pays nothing. The stress recorder (`src/tests/stress_recorder.gd`) turns it on and
## drains it once a frame.
##
## Phases are timed EXCLUSIVELY: a phase that runs inside another (the AOI relay inside an inbound
## packet) is subtracted from its parent, so the phase times of a frame add up to the work measured.
## `begin` and `end` must pair; a function with early returns is wrapped at its call site.
##
## Wire counters are application bytes (the JSON a packet travels as), per peer and per message type,
## in each direction.

static var enabled := false
## When true, each relayed peer position a client receives is logged (`relay_seen`) for the lag join.
static var log_relays := false

static var _times: Dictionary = {}       # phase -> µs since the last take_times()
static var _stack: Array = []            # of [phase, t0_usec, child_usec]
static var _out_peer: Dictionary = {}    # peer -> [bytes, packets]
static var _in_peer: Dictionary = {}     # peer -> [bytes, packets]
static var _out_type: Dictionary = {}    # type -> [bytes, packets]
static var _in_type: Dictionary = {}     # type -> [bytes, packets]
static var _relays: Array = []           # of [peer_id, key, unix_ms]

static func begin(phase: String) -> void:
	if not enabled:
		return
	_stack.append([phase, Time.get_ticks_usec(), 0])

static func end() -> void:
	if not enabled or _stack.is_empty():
		return
	var top: Array = _stack.pop_back()
	var elapsed := Time.get_ticks_usec() - int(top[1])
	_times[top[0]] = int(_times.get(top[0], 0)) + elapsed - int(top[2])
	if not _stack.is_empty():
		_stack[-1][2] = int(_stack[-1][2]) + elapsed

## One packet sent to `peer` (host side) or to the host (client side).
static func count_out(peer: int, type: String, bytes: int) -> void:
	if not enabled:
		return
	_add(_out_peer, peer, bytes)
	_add(_out_type, type, bytes)

## One packet received from `peer`.
static func count_in(peer: int, type: String, bytes: int) -> void:
	if not enabled:
		return
	_add(_in_peer, peer, bytes)
	_add(_in_type, type, bytes)

static func relay_seen(peer_id: int, key: String) -> void:
	if enabled and log_relays:
		_relays.append([peer_id, key, int(Time.get_unix_time_from_system() * 1000.0)])

static func _add(table: Dictionary, key: Variant, bytes: int) -> void:
	var row: Array = table.get(key, [0, 0])
	row[0] = int(row[0]) + bytes
	row[1] = int(row[1]) + 1
	table[key] = row

## The phase times accumulated since the last call (µs), and reset.
static func take_times() -> Dictionary:
	var out := _times
	_times = {}
	return out

## The wire counters accumulated since the last call, and reset:
## `{ out_peer, in_peer, out_type, in_type }`, each key -> [bytes, packets].
static func take_wire() -> Dictionary:
	var out := { "out_peer": _out_peer, "in_peer": _in_peer, "out_type": _out_type, "in_type": _in_type }
	_out_peer = {}
	_in_peer = {}
	_out_type = {}
	_in_type = {}
	return out

static func take_relays() -> Array:
	var out := _relays
	_relays = []
	return out

## Forget everything and switch off (the suite's tests leave no state behind).
static func reset() -> void:
	enabled = false
	log_relays = false
	_times = {}
	_stack = []
	take_wire()
	_relays = []

## The key a relayed or claimed position is matched by: chunk and local position to the centimetre.
static func position_key(exact: Dictionary) -> String:
	var c: Vector2i = exact["chunk"]
	var l: Vector3 = exact["local"]
	return "%d,%d,%d,%d,%d" % [c.x, c.y, roundi(l.x * 100.0), roundi(l.y * 100.0), roundi(l.z * 100.0)]
