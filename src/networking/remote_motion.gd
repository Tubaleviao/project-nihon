extends RefCounted
## Phase 294 — the motion of one body this machine does not simulate (another player's avatar, a creature on a
## client). It keeps the host's last states (position, optional yaw, whether the body is in the air, the time the
## state arrived), plays them back `delay_ms()` behind the newest arrival and, every rendered frame (`step`), puts
## the body at that sample:
##
## - between two states it is interpolated; the playback clock only moves forward (it runs a little faster or
##   slower to follow the buffer), so the body never moves back along its path;
## - past the newest state it carries on along the last velocity for at most `extrapolate_ms`, then holds; when
##   no state comes for a further `delay_ms()` (the body stopped and the host sends nothing new) it eases back to
##   the newest state;
## - the carried distance is a correction, never motion: when the next state comes, playback goes on from the
##   newest state toward it and the gap between where the body was drawn and that path eases out over a few
##   frames (`_offset`), so a late state neither throws the body forward nor pulls it back, and a stop followed
##   by a keepalive at the same spot never turns the body round;
## - a state farther than `teleport_m` from the one before (a respawn, a bed, a portal) snaps the body there once,
##   and playback carries on from it;
## - the body turns toward where it goes (or the sent yaw while it stands) at `turn_rate` rad/s;
## - `speed` (horizontal m/s), `velocity_y` and `airborne` are those of the host's motion as played back (the
##   segment between two host states times the playback rate), for the locomotion clip (idle / walk / run by the
##   fabric's thresholds; fall from the air flag, or from a steep fast drop when the states carry none).
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
## The playback delay follows the measured gap between moving arrivals times this, when that is above the buffer
## (a far body's states arrive less often). A pause is not a gap: only a gap between two states that each moved
## the body counts, and none longer than MAX_GAP_SAMPLE_MS (a keepalive, an idle creature the host stopped sending).
const GAP_MARGIN := 1.25
const MAX_GAP_SAMPLE_MS := 1000.0
## Metres under which two states are the same spot (a keepalive).
## Least spacing of two states on the playback clock, as a share of the send interval.
const MIN_SPACING := 1.0
const SAME_SPOT_M := 0.001
## The correction offset eases out at this rate (1/s), and at least OFFSET_MIN_SPEED m/s.
const OFFSET_RATE := 5.0
const OFFSET_MIN_SPEED := 0.2
## ...and never faster than this (m/s): a gap of metres (a resync after a stall) eases out over about a second.
const OFFSET_MAX_SPEED := 4.0
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
## True once playback has passed the newest state by `extrapolate_ms`: the host's motion is over until a new
## state comes (the body may still be easing back or turning; see `at_rest`).
var settled := false

## [{ t, pos, yaw, air }], oldest first: host states only (the anchor `push` adds when playback ran past the
## newest state is that state again, re-timed).
var _states: Array = []
var _play_ms := NAN
var _rate := 1.0
var _gap_ms := 0.0
var _snap_pending := false
## Drawn position minus the played-back host path; eased to zero every frame.
var _offset := Vector3.ZERO
var _yaw_target := 0.0
## True once the carried distance past the newest state has been handed to the offset to ease out.
var _back_started := false
## Set when playback jumped to its target (`RESYNC_MS`): the next sample's gap to the drawn body becomes the offset.
var resync_pending := false
## `_sample` output (fields, not a Dictionary: this runs per body per frame).
var _s_pos := Vector3.ZERO
var _s_vel := Vector3.ZERO
var _s_yaw := NAN
var _s_air := false
var _s_over := 0.0


func _init(params: Dictionary = {}) -> void:
	configure(params)


## Take a `RemoteMotionRules.group(...)` dictionary (missing keys keep the current values).
func configure(params: Dictionary) -> void:
	buffer_ms = float(params.get("bufferMs", buffer_ms))
	send_interval_ms = float(params.get("sendIntervalMs", send_interval_ms))
	extrapolate_ms = float(params.get("extrapolateMaxMs", extrapolate_ms))
	teleport_m = float(params.get("teleportDistanceM", teleport_m))
	turn_rate = float(params.get("turnRateRadPerSec", turn_rate))


## A state from the host arrived at `now_ms`. `state_yaw` is NAN when the host sent none. A non-finite position
## is dropped (one would poison the drawn position and yaw for good).
func push(now_ms: float, pos: Vector3, state_yaw: float = NAN, air: bool = false) -> void:
	if not pos.is_finite() or is_nan(now_ms):
		return
	settled = false
	var moved := false
	var arrived_ms := now_ms
	if _states.is_empty():
		if not has_position:
			_snap_pending = true
	else:
		var last: Dictionary = _states[_states.size() - 1]
		var lpos: Vector3 = last["pos"]
		if pos.distance_to(lpos) > teleport_m:
			_states.clear()
			_snap_pending = true
			_offset = Vector3.ZERO
			snaps += 1 if has_position else 0
		else:
			# A burst (a stalled link delivering its backlog at once) must not become a run of states a
			# millisecond apart, which would play back at hundreds of m/s: states sit at least MIN_SPACING of the
			# send interval apart on the playback clock, so the backlog plays out at about the pace it was sent.
			arrived_ms = now_ms
			now_ms = maxf(now_ms, float(last["t"]) + send_interval_ms * MIN_SPACING)
			if arrived_ms <= float(last.get("arr", last["t"])):
				arrived_ms = float(last.get("arr", last["t"])) + 0.001
			var gap := now_ms - float(last["t"])
			moved = pos.distance_to(lpos) > SAME_SPOT_M
			if moved and bool(last.get("moved", false)) and gap <= MAX_GAP_SAMPLE_MS:
				_gap_ms = gap if _gap_ms <= 0.0 else lerpf(_gap_ms, gap, 0.2)
			if has_position and not _snap_pending and not is_nan(_play_ms) and _play_ms > float(last["t"]) and _play_ms < now_ms:
				# Playback already ran past the newest state: go on from that state, re-timed to now, and keep
				# the body where it is drawn through the offset (which eases out).
				_offset = position - lpos
				_s_pos = lpos   # the base the next frame's travel is measured from
				_back_started = false
				_states.append({ "t": _play_ms, "pos": lpos, "yaw": last["yaw"], "air": last["air"], "moved": false })
	_states.append({ "t": now_ms, "pos": pos, "yaw": state_yaw, "air": air, "moved": moved, "arr": arrived_ms })
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


## True when nothing will move or turn the body until a new state comes.
func at_rest() -> bool:
	return settled and _offset == Vector3.ZERO and is_equal_approx(yaw, _yaw_target)


## Advance to `now_ms`, `delta` seconds after the last frame, and update the drawn state.
func step(now_ms: float, delta: float) -> void:
	if _states.is_empty():
		return
	if _snap_pending:
		_snap_to(_states[0], now_ms)
		return
	delta = maxf(delta, 0.0)
	var target := now_ms - delay_ms()
	if is_nan(_play_ms):
		_play_ms = target
		_rate = 1.0
	else:
		var err := target - _play_ms
		if err > RESYNC_MS:
			_play_ms = target
			_rate = 1.0
			resync_pending = true
		else:
			_rate = clampf(1.0 + err / CATCHUP_MS, MIN_RATE, MAX_RATE)
			_play_ms += delta * 1000.0 * _rate
	_prune()
	var base_was := _s_pos
	_sample(_play_ms)
	if resync_pending:
		# A long stall (a congested link delivers a second of states at once) moved playback far ahead: the
		# drawn body stays where it is and the gap eases out like any late state's, instead of stepping in one frame.
		resync_pending = false
		if has_position and (position - _s_pos).length() <= teleport_m:
			_offset = position - _s_pos
			base_was = _s_pos   # the jump is not travel: it must not let the ease swallow half of it in one frame
	_ease_offset(delta, (_s_pos - base_was).length() if _s_vel != Vector3.ZERO else -1.0)
	position = _s_pos + _offset
	has_position = true
	speed = Vector2(_s_vel.x, _s_vel.z).length() * _rate
	velocity_y = _s_vel.y * _rate
	airborne = _s_air or (velocity_y <= -FALL_INFER_SPEED and -velocity_y > STEEP_DROP * speed)
	settled = _s_over >= extrapolate_ms
	if speed >= FACE_SPEED:
		_yaw_target = atan2(-_s_vel.x, -_s_vel.z)
	elif not is_nan(_s_yaw):
		_yaw_target = _s_yaw
	yaw = wrapf(rotate_toward(yaw, _yaw_target, turn_rate * delta), -PI, PI)
	if is_equal_approx(angle_difference(yaw, _yaw_target), 0.0):
		yaw = _yaw_target


## Put the body at `st` (the first state, or the one a teleport landed on) at once. Playback restarts one
## delay behind `now_ms`, no later than the state itself, so the body stands there until its playback reaches it.
func _snap_to(st: Dictionary, now_ms: float) -> void:
	_snap_pending = false
	_offset = Vector3.ZERO
	_back_started = false
	position = st["pos"]
	_s_pos = position
	has_position = true
	speed = 0.0
	velocity_y = 0.0
	airborne = bool(st["air"])
	if not is_nan(float(st["yaw"])):
		yaw = wrapf(float(st["yaw"]), -PI, PI)
		_yaw_target = yaw
	_play_ms = minf(float(st["t"]), now_ms - delay_ms())
	settled = false


## Ease the correction offset toward zero. `travel` is how far the played-back body moved this frame (negative when
## it stands): while it moves the ease takes at most half of that, so the drawn body never steps back along its path.
func _ease_offset(delta: float, travel: float) -> void:
	var off := _offset.length()
	if off == 0.0:
		return
	var take := minf(maxf(OFFSET_RATE * off, OFFSET_MIN_SPEED), OFFSET_MAX_SPEED) * delta
	if travel >= 0.0:
		take = minf(take, 0.5 * travel)
	_offset = Vector3.ZERO if take >= off else _offset * (1.0 - take / off)


## Drop states playback has moved past (one is kept as the start of the current segment).
func _prune() -> void:
	while _states.size() >= 3 and float(_states[1]["t"]) <= _play_ms:
		_states.pop_front()


## The host's motion at playback time `play`, into the `_s_*` fields: position, velocity (m/s), sent yaw, air
## flag and how far past the newest state playback is (ms, 0 inside the states).
func _sample(play: float) -> void:
	var first: Dictionary = _states[0]
	var last: Dictionary = _states[_states.size() - 1]
	_s_vel = Vector3.ZERO
	_s_over = 0.0
	if play <= float(first["t"]):
		_s_pos = first["pos"]
		_s_yaw = first["yaw"]
		_s_air = first["air"]
		return
	if play >= float(last["t"]):
		_s_yaw = last["yaw"]
		_s_air = last["air"]
		_s_over = play - float(last["t"])
		var lpos: Vector3 = last["pos"]
		_s_pos = lpos
		if _states.size() < 2:
			_s_over = INF
			return
		var prev: Dictionary = _states[_states.size() - 2]
		var vel_ms: Vector3 = (lpos - (prev["pos"] as Vector3)) / maxf(float(last["t"]) - float(prev["t"]), 1.0)
		if _s_over < extrapolate_ms:
			_s_pos = lpos + vel_ms * _s_over
			_s_vel = vel_ms * 1000.0
		elif _s_over < extrapolate_ms + delay_ms():
			_s_pos = lpos + vel_ms * extrapolate_ms   # carried, holding: the next state may only be late
		elif vel_ms != Vector3.ZERO and not _back_started:
			# No state for a further delay: the body stopped. Ease back to the newest state.
			_back_started = true
			_offset += vel_ms * extrapolate_ms
		return
	for i in range(_states.size() - 1):
		var a: Dictionary = _states[i]
		var b: Dictionary = _states[i + 1]
		var ta := float(a["t"])
		var tb := float(b["t"])
		if play >= ta and play <= tb:
			var span := maxf(tb - ta, 0.001)
			_s_pos = (a["pos"] as Vector3).lerp(b["pos"], (play - ta) / span)
			_s_vel = ((b["pos"] as Vector3) - (a["pos"] as Vector3)) / span * 1000.0
			_s_yaw = b["yaw"]
			_s_air = a["air"]
			_back_started = false
			return
	_s_pos = last["pos"]
