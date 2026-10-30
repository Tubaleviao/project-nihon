extends Node
## Phase 159 — host-side state for gestures: which pose each player holds, the rules that start and
## cancel one, and the rate limit. Authoritative on the host / dedicated server only; a client asks with
## `gesture_intent` and renders `gesture_synced`. The slice emits a bus signal for each accepted start and
## each cancel (`gesture_id` "" = stand up); `GestureWiring` carries it to the avatars and the wire.

const GestureRules := preload("res://src/character/gesture_rules.gd")

## Refusal reasons returned by `request` ("" = accepted).
const REFUSE_UNKNOWN := "unknown"
const REFUSE_DEAD := "dead"
const REFUSE_AIRBORNE := "airborne"
const REFUSE_RATE := "rate"

## The fabric table; the suite swaps it.
var gestures: Dictionary = GameData.GESTURES
## `() -> float` seconds for the rate limit; the suite injects a fake clock.
var clock: Callable = Callable()

## player id -> { "id": gesture id, "origin": Vector3, "lift": float } for the poses currently held (`lift`:
## the seat rise the host resolved for a Sit, Phase 196; -1 when it resolved none).
var _held: Dictionary = {}
var _buckets: Dictionary = {}
var rate_refused: int = 0
var unknown_refused: int = 0

func _now() -> float:
	return float(clock.call()) if clock.is_valid() else float(Time.get_ticks_msec()) / 1000.0

## Start `gesture_id` for `player_id` (already bound to the connection by the caller). `alive`, `grounded`
## and `position` are the host's own evidence. An empty id stands the player up (their own pose only: the
## id a caller passes is the connection's, never a name from a payload). `lift` is the seat rise the host
## resolved for the pose (-1: none, the avatars decide). Returns "" or a refusal reason.
func request(player_id: String, gesture_id: String, alive: bool, grounded: bool, position: Vector3, lift: float = -1.0) -> String:
	if player_id == "":
		return REFUSE_UNKNOWN
	if gesture_id == "":
		cancel(player_id)
		return ""
	var res: Resource = GestureRules.find(gesture_id, gestures)
	if res == null:
		unknown_refused += 1
		return REFUSE_UNKNOWN
	if not alive:
		return REFUSE_DEAD
	# Phase 196 — the ground check first: a refused airborne attempt does not spend a token.
	if GestureRules.flag(res, "requiresGround") and not grounded:
		return REFUSE_AIRBORNE
	var step := GestureRules.take_token(_buckets.get(player_id, {}), _now())
	_buckets[player_id] = step["state"]
	if not step["ok"]:
		rate_refused += 1
		return REFUSE_RATE
	if GestureRules.is_pose(res):
		_held[player_id] = { "id": gesture_id, "origin": position, "lift": lift }
	else:
		_held.erase(player_id)   # a one-shot replaces a pose: the body plays it and returns to locomotion
	GameBus.gesture_synced.emit(player_id, gesture_id)
	return ""

## End `player_id`'s pose (and tell everyone). A no-op when none is held.
func cancel(player_id: String) -> void:
	if _held.erase(player_id):
		GameBus.gesture_synced.emit(player_id, "")

## The host saw `player_id` at `position`: a `cancelOnMove` pose ends once the body drifts off its spot.
func note_position(player_id: String, position: Vector3) -> void:
	var held: Dictionary = _held.get(player_id, {})
	if held.is_empty():
		return
	var res: Resource = gestures.get(held["id"], null)
	if GestureRules.flag(res, "cancelOnMove") and GestureRules.moved(held["origin"], position):
		cancel(player_id)

## `player_id` took damage: a `cancelOnDamage` pose ends.
func note_damage(player_id: String) -> void:
	var held: Dictionary = _held.get(player_id, {})
	if not held.is_empty() and GestureRules.flag(gestures.get(held["id"], null), "cancelOnDamage"):
		cancel(player_id)

## `player_id` swung at something (a hit or a mining swing): the body leaves its pose for the swing.
func note_action(player_id: String) -> void:
	cancel(player_id)

## `player_id` died: every gesture ends.
func note_death(player_id: String) -> void:
	cancel(player_id)

## A player left: forget their pose and bucket (no signal; nobody is left to show it to).
func forget(player_id: String) -> void:
	_held.erase(player_id)
	_buckets.erase(player_id)

func held_id(player_id: String) -> String:
	return str(_held.get(player_id, {}).get("id", ""))

## Phase 196 — the seat rise the host resolved for `player_id`'s held pose, -1 when none.
func lift_of(player_id: String) -> float:
	return float(_held.get(player_id, {}).get("lift", -1.0))

## Every held pose as player id -> gesture id.
func held_poses() -> Dictionary:
	var out := {}
	for pid in _held:
		out[pid] = _held[pid]["id"]
	return out

## The regeneration multiplier of the pose `player_id` holds (1.0 when none).
func regen_multiplier(player_id: String) -> float:
	var id := held_id(player_id)
	return GestureRules.rest_regen(gestures[id]) if id != "" and gestures.has(id) else 1.0
