extends RefCounted
## Locomotion state machine — characters.md §37 (ROADMAP Phase 20).
##
## Pure, deterministic state machine that maps horizontal speed and vertical
## state onto a locomotion state. Deliberately free of any scene-tree dependency
## so the headless test suite can drive it directly and assert transitions.
##
## The state machine is the "AnimationSet" brain; a real AnimationTree would
## consume `get_state()` plus `get_blend_weight()` (below) to pick and blend
## skeletal clips. Keeping the decision logic here means it is unit-testable
## without a renderer.

enum State {
	IDLE,
	WALK,
	RUN,
	FALL,
	LAND,
	ATTACK,
	DEATH,
	GESTURE,
}

## Horizontal speed (m/s) at or above which the character is walking.
const WALK_SPEED := 0.2
## Horizontal speed (m/s) at or above which the character is running.
const RUN_SPEED := 3.0
## Seconds an attack pose holds before returning to the locomotion state.
const ATTACK_DURATION := 0.5
## Seconds the landing pose holds before returning to the locomotion state.
const LAND_DURATION := 0.18
## Seconds a body must be airborne and moving down before it reads as falling. Walking
## off a block drops the body for a fraction of a second; that is a step, not a fall, so
## the walk/run pose holds through it instead of flashing FALL and then LAND.
const FALL_GRACE := 0.4
## Downward speed (m/s) that reads as falling at once, grace or not: about 0.8 m of free
## fall, more than a step down.
const FALL_SPEED := 4.0

var _state: int = State.IDLE
var _timer: float = 0.0
var _speed: float = 0.0
var _airborne: float = 0.0
## Attack hold time: the attack clip's length once a rig is attached, `ATTACK_DURATION` before.
var attack_duration: float = ATTACK_DURATION
## Bumped on every attack request, so a second swing while one plays restarts the clip instead of
## merging into it; `attack_clip` names the variant the swing plays (see `RigTree.attack_clip_for`).
var swing_serial: int = 0
var attack_clip: String = "attack"
## Phase 157 — the death variant the Death node plays (`death` when the hit had no direction).
var death_clip: String = "death"
## Bumped on every hit taken; `hit_clip` is `hit`, or `stagger` for a knockback.
var hit_serial: int = 0
var hit_clip: String = "hit"
## Idle variants: after `idle_delay` seconds of standing still a variant plays once. The delay and
## the variant come from a generator seeded per body, so a replay and a test see the same ones.
const IDLE_DELAY_MIN := 6.0
const IDLE_DELAY_MAX := 12.0
const IDLE_VARIANTS := ["idle_look", "idle_stretch"]
## Phase 159 — the gesture clip playing and whether it is a held pose; bumped per gesture started.
var gesture_clip: String = ""
var gesture_serial: int = 0
var _gesture_hold: bool = false
var idle_serial: int = 0
var idle_clip: String = ""
var idle_delay: float = IDLE_DELAY_MIN
var _idle_for: float = 0.0
var _idle_rng := RandomNumberGenerator.new()

## Seed the idle-variant generator (the instance id's hash) and draw the first delay.
func seed_idle(seed_value: int) -> void:
	_idle_rng.seed = seed_value
	idle_delay = _idle_rng.randf_range(IDLE_DELAY_MIN, IDLE_DELAY_MAX)
	_idle_for = 0.0

## Advance the machine one tick. `speed` is horizontal speed (m/s), `grounded`
## whether the body is on the floor, `velocity_y` the vertical velocity (m/s,
## negative when falling). Returns the resulting State.
func update(speed: float, grounded: bool, velocity_y: float, delta: float) -> int:
	_speed = speed
	_tick_idle(speed, grounded, delta)

	# Death is terminal: no transition out.
	if _state == State.DEATH:
		return _state

	# Phase 159 — a gesture holds until ended (a pose) or until its clip is over (a one-shot); a hit
	# swing or a death replaces it, and `end_gesture` / moving (decided by the host) ends a pose.
	if _state == State.GESTURE:
		if _gesture_hold:
			return _state
		_timer -= delta
		if _timer > 0.0:
			return _state
		# Phase 196 — the clip is over: leave GESTURE even in the air, where the airborne branch below would
		# otherwise keep the state it found until the body falls.
		_set_state(_ground_state(speed))

	# Attack and land are timed one-shots — hold them until their timer elapses,
	# then fall through into normal locomotion.
	if _state == State.ATTACK or _state == State.LAND:
		_timer -= delta
		if _timer > 0.0:
			return _state

	# Airborne: falling only while moving downward, and only once the drop lasts
	# longer than a step down (FALL_GRACE) or is fast (FALL_SPEED). Rising (a jump)
	# keeps the previous ground state so a hop does not flicker to FALL.
	if not grounded:
		# Only the time spent descending counts: a long jump must not enter FALL at its apex.
		if velocity_y < -0.1:
			_airborne += delta
		else:
			_airborne = 0.0
		if is_falling(_airborne, velocity_y):
			_set_state(State.FALL)
		return _state
	_airborne = 0.0

	# Just landed from a fall: play a brief LAND pose.
	if _state == State.FALL:
		_set_state(State.LAND)
		_timer = LAND_DURATION
		return _state

	_set_state(_ground_state(speed))
	return _state

## Count standing-still time and fire a variant once it passes the delay. Any movement, jump or
## non-idle state restarts the count, so a variant never starts on a body that is moving.
func _tick_idle(speed: float, grounded: bool, delta: float) -> void:
	if _state != State.IDLE or speed >= WALK_SPEED or not grounded:
		_idle_for = 0.0
		return
	_idle_for += delta
	if _idle_for >= idle_delay:
		_idle_for = 0.0
		idle_clip = IDLE_VARIANTS[_idle_rng.randi() % IDLE_VARIANTS.size()]
		idle_serial += 1
		idle_delay = _idle_rng.randf_range(IDLE_DELAY_MIN, IDLE_DELAY_MAX)

## True when a body airborne for `airborne` seconds at vertical velocity `velocity_y`
## is falling rather than stepping down a block.
static func is_falling(airborne: float, velocity_y: float) -> bool:
	if velocity_y >= -0.1:
		return false
	return airborne >= FALL_GRACE or velocity_y <= -FALL_SPEED

## Locomotion state for a grounded body at `speed`.
func _ground_state(speed: float) -> int:
	if speed < WALK_SPEED:
		return State.IDLE
	if speed < RUN_SPEED:
		return State.WALK
	return State.RUN

## Request the attack pose (ignored while dead).
func trigger_attack(clip: String = "attack", duration: float = -1.0) -> void:
	if _state == State.DEATH:
		return
	_set_state(State.ATTACK)
	_timer = duration if duration > 0.0 else attack_duration
	attack_clip = clip
	swing_serial += 1

## Phase 159 — start a gesture: a held pose (`hold`) stays until `end_gesture`, a one-shot lasts
## `duration` seconds and returns to locomotion. Bumps `gesture_serial` so a repeat restarts the clip.
## Ignored while dead.
func trigger_gesture(clip: String, hold: bool, duration: float = 1.0) -> void:
	if _state == State.DEATH:
		return
	_set_state(State.GESTURE)
	gesture_clip = clip
	_gesture_hold = hold
	_timer = duration
	gesture_serial += 1

## Phase 159 — leave a gesture for locomotion (the stand-up). A no-op outside one.
func end_gesture() -> void:
	if _state != State.GESTURE:
		return
	_gesture_hold = false
	_timer = 0.0
	_set_state(_ground_state(_speed))

func is_gesturing() -> bool:
	return _state == State.GESTURE

func is_gesture_held() -> bool:
	return _state == State.GESTURE and _gesture_hold

## Request the hit flinch (a stagger for a knockback). Plays over whatever the body is doing, so the
## state does not change; ignored while dead.
func trigger_hit(stagger: bool = false) -> void:
	if _state == State.DEATH:
		return
	hit_clip = "stagger" if stagger else "hit"
	hit_serial += 1

## Request the death pose. Terminal until reset().
func trigger_death(clip: String = "death") -> void:
	death_clip = clip
	_set_state(State.DEATH)
	_timer = 0.0

## Reset to idle (used by respawn / appearance swap).
func reset() -> void:
	_set_state(State.IDLE)
	_timer = 0.0
	_airborne = 0.0

func get_speed() -> float:
	return _speed

func get_state() -> int:
	return _state

func state_name() -> String:
	return State.keys()[_state]

## 0..1 continuous "locomotion amount" for cross-fading the idle → walk → run
## clips. 0 = full idle, 1 = full run, with the walk band interpolating between
## them. Reported from the speed of the last update() call; see blend_curve()
## for the exact mapping.
func get_blend_weight() -> float:
	return blend_curve(_speed)

## Documented blend curve: maps horizontal speed (m/s) to a 0..1 locomotion
## blend weight, replacing the old per-state magic constants (WALK → 0, RUN → 1).
##
##   speed <= WALK_SPEED             → 0.0  (full idle clip)
##   WALK_SPEED < speed < RUN_SPEED  → linear 0..1 ramp (walk-band cross-fade)
##   speed >= RUN_SPEED              → 1.0  (full run clip)
##
## Piecewise-linear in speed so the transition is smooth and predictable. A
## future AnimationTree consumes this directly to drive its BlendSpace1D, so the
## curve lives here (not in the renderer) and stays unit-testable headless.
static func blend_curve(speed: float) -> float:
	if speed <= WALK_SPEED:
		return 0.0
	if speed >= RUN_SPEED:
		return 1.0
	return (speed - WALK_SPEED) / (RUN_SPEED - WALK_SPEED)

func _set_state(s: int) -> void:
	_state = s
