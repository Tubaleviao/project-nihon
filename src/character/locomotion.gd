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
}

## Horizontal speed (m/s) at or above which the character is walking.
const WALK_SPEED := 0.2
## Horizontal speed (m/s) at or above which the character is running.
const RUN_SPEED := 3.0
## Seconds an attack pose holds before returning to the locomotion state.
const ATTACK_DURATION := 0.5
## Seconds the landing pose holds before returning to the locomotion state.
const LAND_DURATION := 0.25

var _state: int = State.IDLE
var _timer: float = 0.0
var _speed: float = 0.0

## Advance the machine one tick. `speed` is horizontal speed (m/s), `grounded`
## whether the body is on the floor, `velocity_y` the vertical velocity (m/s,
## negative when falling). Returns the resulting State.
func update(speed: float, grounded: bool, velocity_y: float, delta: float) -> int:
	_speed = speed

	# Death is terminal: no transition out.
	if _state == State.DEATH:
		return _state

	# Attack and land are timed one-shots — hold them until their timer elapses,
	# then fall through into normal locomotion.
	if _state == State.ATTACK or _state == State.LAND:
		_timer -= delta
		if _timer > 0.0:
			return _state

	# Airborne: falling only while moving downward. Rising (a jump) keeps the
	# previous ground state so a hop does not flicker to FALL.
	if not grounded:
		if velocity_y < -0.1:
			_set_state(State.FALL)
		return _state

	# Just landed from a fall: play a brief LAND pose.
	if _state == State.FALL:
		_set_state(State.LAND)
		_timer = LAND_DURATION
		return _state

	_set_state(_ground_state(speed))
	return _state

## Locomotion state for a grounded body at `speed`.
func _ground_state(speed: float) -> int:
	if speed < WALK_SPEED:
		return State.IDLE
	if speed < RUN_SPEED:
		return State.WALK
	return State.RUN

## Request the attack pose (ignored while dead).
func trigger_attack() -> void:
	if _state == State.DEATH:
		return
	_set_state(State.ATTACK)
	_timer = ATTACK_DURATION

## Request the death pose. Terminal until reset().
func trigger_death() -> void:
	_set_state(State.DEATH)
	_timer = 0.0

## Reset to idle (used by respawn / appearance swap).
func reset() -> void:
	_set_state(State.IDLE)
	_timer = 0.0

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
