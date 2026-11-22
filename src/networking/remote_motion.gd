extends RefCounted
## Phase 294 — the motion of one body this machine does not simulate (another player's avatar, a creature on a
## client). It keeps the host's last states (position, optional yaw, whether the body is in the air, the time the
## state arrived), plays them back `delay_ms()` behind the newest arrival and, every rendered frame (`step`), puts
## the body at that sample:
##
## - between two states it is interpolated; the playback clock only moves forward (it runs a little faster or
##   slower to follow the buffer), so the body never moves back along its path;
## - past the newest state it carries on along the last velocity for at most `extrapolate_ms`, then holds; the
##   state that comes next is reached from where the body stands then (not from the old state), so a late state
##   neither throws the body forward nor pulls it back;
## - a state farther than `teleport_m` from the one before (a respawn, a bed, a portal) snaps the body there once,
##   and playback carries on from it;
## - the body turns toward where it goes (or the sent yaw while it stands) at `turn_rate` rad/s;
## - `speed` (horizontal m/s), `velocity_y` and `airborne` are those of the motion played back, for the
##   locomotion clip (idle / walk / run by the fabric's thresholds; fall from the air flag, or from a steep fast
##   drop when the states carry none).
##
## The numbers come from the fabric's `RemoteMotion` table (`RemoteMotionRules.group`). Positions are in whatever
## frame the caller uses, as long as it is the same for every state (a creature uses an offset from an exact
## anchor so a rebase does not move it). Pure: the caller passes the clock, so the suite can drive it.

## Most states kept; older ones go first (a stalled playback cannot grow the list).
const MAX_STATES := 64
## A playback more than this far behind its target jumps to it (a long hitch, a backgrounded window).
const RESYNC_MS := 1000.0
## The playback clock runs at 1 + error / CATCHUP_MS, clamped to [MIN_RATE, MAX_RATE].
const CATCHUP_MS := 500.0
const MIN_RATE := 0.5
const MAX_RATE := 1.5
## The playback delay follows the measured gap between arrivals times this, when that is above the buffer (a far
## body's states arrive less often).
const GAP_MARGIN := 1.25
## A body whose states carry no air flag (the player relay sends positions only) reads as in the air when it
## drops at least this fast (m/s, `Locomotion.FALL_SPEED`) and more steeply than STEEP_DROP (vertical over
## horizontal speed: steeper than any slope a body walks down), so a walk downhill never plays `fall`.
const FALL_INFER_SPEED := 4.0
const STEEP_DROP := 1.5
## Horizontal m/s under which the body turns to the sent yaw (if any) instead of its movement.
const FACE_SPEED := 0.05

var buffer_ms := 150.0
var send_interval_ms := 100.0
var extrapolate_ms := 100.0
var teleport_m := 30.0
var turn_rate := 10.0

## Drawn state, valid once `has_position`.
var position := Vector3.ZERO
var yaw := 0.0
var speed := 0.0
var velocity_y := 0.0
var airborne := false
var has_position := false
## Teleport snaps taken (the first placement is not one).
var snaps := 0
## True once playback has passed the newest state by `extrapolate_ms`: nothing moves until a new state comes.
var settled := false

## [{ t, pos, yaw, air }], oldest first.
var _states: Array = []
var _play_ms := NAN
var _gap_ms := 0.0
var _snap_pending := false


func _init(params: Dictionary = {}) -> void:
	configure(params)


## Take a `RemoteMotionRules.group(...)` dictionary (missing keys keep the current values).
func configure(params: Dictionary) -> void:
	buffer_ms = float(params.get("bufferMs", buffer_ms))
	send_interval_ms = float(params.get("sendIntervalMs", send_interval_ms))
	extrapolate_ms = float(params.get("extrapolateMaxMs", extrapolate_ms))
	teleport_m = float(params.get("teleportDistanceM", teleport_m))
	turn_rate = float(params.get("turnRateRadPerSec", turn_rate))


## A state from the host arrived at `now_ms`. `state_yaw` is NAN when the host sent none.
func push(now_ms: float, pos: Vector3, state_yaw: float = NAN, air: bool = false) -> void:
	settled = false
	if _states.is_empty():
		if not has_position:
			_snap_pending = true
	else:
		var last: Dictionary = _states[_states.size() - 1]
		if pos.distance_to(last["pos"]) > teleport_m:
			_states.clear()
			_snap_pending = true
			snaps += 1 if has_position else 0
		elif now_ms <= float(last["t"]):
			# Two states in one instant (a burst): the later one stands for both.
			last["pos"] = pos
			last["yaw"] = state_yaw
			last["air"] = air
			return
		else:
			var gap := now_ms - float(last["t"])
			_gap_ms = gap if _gap_ms <= 0.0 else lerpf(_gap_ms, gap, 0.2)
			if has_position and not _snap_pending and not is_nan(_play_ms) and _play_ms > float(last["t"]) and _play_ms < now_ms:
				# Playback already ran past the newest state (carried on, or holding): the next segment starts
				# from the body as drawn, at the time played back.
				_states.append({ "t": _play_ms, "pos": position, "yaw": last["yaw"], "air": last["air"] })
	_states.append({ "t": now_ms, "pos": pos, "yaw": state_yaw, "air": air })
	while _states.size() > MAX_STATES:
		_states.pop_front()


## Milliseconds playback runs behind the newest arrival.
func delay_ms() -> float:
	return maxf(buffer_ms, _gap_ms * GAP_MARGIN)


## The time currently played back (NAN before the first step).
func playback_ms() -> float:
	return _play_ms


## States held (the suite checks the list stays bounded).
func state_count() -> int:
	return _states.size()


## Advance to `now_ms`, `delta` seconds after the last frame, and update the drawn state.
func step(now_ms: float, delta: float) -> void:
	if _states.is_empty():
		return
	if _snap_pending:
		_snap_to(_states[0], now_ms)
		return
	var target := now_ms - delay_ms()
	if is_nan(_play_ms):
		_play_ms = target
	else:
		var err := target - _play_ms
		if err > RESYNC_MS:
			_play_ms = target
		else:
			_play_ms += maxf(delta, 0.0) * 1000.0 * clampf(1.0 + err / CATCHUP_MS, MIN_RATE, MAX_RATE)
	_prune()
	var s := _sample(_play_ms)
	var vel: Vector3 = s["vel"]
	position = s["pos"]
	has_position = true
	speed = Vector2(vel.x, vel.z).length()
	velocity_y = vel.y
	airborne = bool(s["air"]) or (velocity_y <= -FALL_INFER_SPEED and -velocity_y > STEEP_DROP * speed)
	settled = bool(s["settled"])
	var target_yaw := yaw
	if speed >= FACE_SPEED:
		target_yaw = atan2(-vel.x, -vel.z)
	elif not is_nan(float(s["yaw"])):
		target_yaw = float(s["yaw"])
	yaw = rotate_toward(yaw, target_yaw, turn_rate * maxf(delta, 0.0))


## Put the body at `st` (the first state, or the one a teleport landed on) at once. Playback restarts one
## delay behind `now_ms`, no later than the state itself, so the body stands there until its playback reaches it.
func _snap_to(st: Dictionary, now_ms: float) -> void:
	_snap_pending = false
	position = st["pos"]
	has_position = true
	speed = 0.0
	velocity_y = 0.0
	airborne = bool(st["air"])
	if not is_nan(float(st["yaw"])):
		yaw = float(st["yaw"])
	_play_ms = minf(float(st["t"]), now_ms - delay_ms())
	settled = false


## Drop states playback has moved past (one is kept as the start of the current segment).
func _prune() -> void:
	while _states.size() >= 3 and float(_states[1]["t"]) <= _play_ms:
		_states.pop_front()


## The motion at playback time `play`: { pos, vel (m/s), yaw, air, settled }.
func _sample(play: float) -> Dictionary:
	var first: Dictionary = _states[0]
	var last: Dictionary = _states[_states.size() - 1]
	var out := { "pos": first["pos"], "vel": Vector3.ZERO, "yaw": first["yaw"], "air": first["air"], "settled": false }
	if play <= float(first["t"]):
		return out
	if play >= float(last["t"]):
		out["yaw"] = last["yaw"]
		out["air"] = last["air"]
		var over := play - float(last["t"])
		if _states.size() < 2:
			out["pos"] = last["pos"]
			out["settled"] = true
			return out
		var prev: Dictionary = _states[_states.size() - 2]
		var vel_ms: Vector3 = ((last["pos"] as Vector3) - (prev["pos"] as Vector3)) / maxf(float(last["t"]) - float(prev["t"]), 1.0)
		var carried := minf(over, extrapolate_ms)
		out["pos"] = (last["pos"] as Vector3) + vel_ms * carried
		if over < extrapolate_ms:
			out["vel"] = vel_ms * 1000.0
		else:
			out["settled"] = true
		return out
	for i in range(_states.size() - 1):
		var a: Dictionary = _states[i]
		var b: Dictionary = _states[i + 1]
		var ta := float(a["t"])
		var tb := float(b["t"])
		if play >= ta and play <= tb:
			var span := maxf(tb - ta, 0.001)
			var u := (play - ta) / span
			out["pos"] = (a["pos"] as Vector3).lerp(b["pos"], u)
			out["vel"] = ((b["pos"] as Vector3) - (a["pos"] as Vector3)) / span * 1000.0
			out["yaw"] = b["yaw"]
			out["air"] = a["air"]
			return out
	out["pos"] = last["pos"]
	return out
