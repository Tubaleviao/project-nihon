extends RefCounted
## Phase 159 — pure rules for gestures (sit, lie down, wave and friends). The fabric (`GameData.GESTURES`)
## owns the list and each gesture's flags; this module reads them and holds the numbers the runtime adds.

const GameDataReader := preload("res://src/core/game_data_reader.gd")

## Gesture `kind` as the generated resources store it.
const KIND_POSE := 0
const KIND_ONE_SHOT := 1

## Longest gesture id a packet may carry.
const MAX_ID_CHARS := 32
## Per-player token bucket (a gesture costs one token): a burst of three, then one every two seconds.
const RATE_CAPACITY := 3.0
const RATE_REFILL_PER_S := 0.5
## Horizontal metres a body may drift from where a pose began before the pose counts as "moved".
const MOVE_CANCEL_M := 0.35
## The seat a sit can snap to: its top face this far above the feet (a block edge or a station).
const SEAT_MIN_RISE := 0.25
const SEAT_MAX_RISE := 0.75
## Baseline HP a living body regains per second; a held pose multiplies it by its `restRegen`.
const BASE_HP_REGEN_PER_S := 0.25

## The gesture resource for `id`, or null when the fabric lists none (an unknown or oversize id).
static func find(id: String, table: Dictionary):
	if id == "" or id.length() > MAX_ID_CHARS:
		return null
	return table.get(id, null)

static func is_pose(res: Resource) -> bool:
	return GameDataReader.int_field(res, "kind", KIND_POSE) == KIND_POSE

static func clip_of(res: Resource) -> String:
	return GameDataReader.str_field(res, "clip", "")

static func flag(res: Resource, key: String) -> bool:
	return bool(res.get(key)) if res != null else false

static func rest_regen(res: Resource) -> float:
	return maxf(GameDataReader.float_field(res, "restRegen", 1.0), 1.0)

## The gesture id a `/command` line names (`"/sit"`, `"/Wave extra"`), or "" for none.
static func id_for_command(text: String, table: Dictionary) -> String:
	var word := text.strip_edges().split(" ", false)
	if word.is_empty():
		return ""
	var typed: String = word[0].to_lower()
	for id in table:
		if GameDataReader.str_field(table[id], "chatCommand", "") == typed:
			return str(id)
	return ""

## The chat command of every gesture, sorted: for `/help` and the wheel.
static func commands(table: Dictionary) -> Array:
	var out: Array = []
	for id in table:
		out.append(GameDataReader.str_field(table[id], "chatCommand", ""))
	out.sort()
	return out

## Gesture ids in a stable order, for the wheel.
static func ids(table: Dictionary) -> Array:
	var out: Array = table.keys()
	out.sort()
	return out

## One token-bucket step: `{ tokens, t }` -> `{ ok, state }`. `now` is seconds from any monotonic clock.
static func take_token(state: Dictionary, now: float) -> Dictionary:
	var tokens := RATE_CAPACITY if state.is_empty() else minf(RATE_CAPACITY, float(state["tokens"]) + (now - float(state["t"])) * RATE_REFILL_PER_S)
	if tokens < 1.0:
		return { "ok": false, "state": { "tokens": tokens, "t": now } }
	return { "ok": true, "state": { "tokens": tokens - 1.0, "t": now } }

## True when a body at `now` has drifted from `origin` far enough to end a pose (horizontal distance).
static func moved(origin: Vector3, now: Vector3) -> bool:
	return Vector2(now.x - origin.x, now.z - origin.z).length() > MOVE_CANCEL_M

## The height to lift a sitting body onto a seat whose top face is `seat_top_y`, standing with feet at
## `feet_y`: the rise when it is a seat height (a block edge or a station), else -1.0 (sit on the ground).
static func seat_lift(feet_y: float, seat_top_y: float) -> float:
	var rise := seat_top_y - feet_y
	return rise if rise >= SEAT_MIN_RISE and rise <= SEAT_MAX_RISE else -1.0

## HP regained over `delta` seconds at `multiplier` (1.0 when no pose is held).
## `base_rate` is the body's Vitality-derived HP/s (Phase 178); it defaults to the base-10 constant.
static func regen_amount(multiplier: float, delta: float, base_rate: float = BASE_HP_REGEN_PER_S) -> float:
	return base_rate * maxf(multiplier, 1.0) * maxf(delta, 0.0)

## Keys of `visible` (viewer/subject pairs in range now) that were not in `before`: the pairs that just
## entered range and need the held pose replayed.
static func new_pairs(visible: Dictionary, before: Dictionary) -> Array:
	var out: Array = []
	for key in visible:
		if not before.has(key):
			out.append(key)
	return out
