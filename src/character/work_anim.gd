extends RefCounted
## Phase 281 — work you can see: the pure half. Which rig clip a kind of work plays, loop or once, and when in the
## clip the strike lands, all read from the fabric `WorkClips` world system (`GameData.WORLD_SYSTEMS["WorkClips"]`).

const FALLBACK := "attack_tool"
const DEFAULT_IMPACT := 0.4

static func _res() -> Resource:
	return GameData.WORLD_SYSTEMS.get("WorkClips", null)

static func _clips() -> Dictionary:
	var res := _res()
	var v: Variant = res.get("clips") if res != null else null
	return v if v is Dictionary else {}

## True for a kind of work the table names.
static func has_kind(kind: String) -> bool:
	return _clips().has(kind)

## The clip the table names for `kind` ("" for an unknown kind).
static func clip_of(kind: String) -> String:
	return str((_clips().get(kind, {}) as Dictionary).get("clip", ""))

## "loop" (a hold: one strike per cycle), "once" (a single action) or "" for an unknown kind.
static func mode_of(kind: String) -> String:
	return str((_clips().get(kind, {}) as Dictionary).get("mode", ""))

static func is_loop(kind: String) -> bool:
	return mode_of(kind) == "loop"

## Fraction of the clip at which the strike lands.
static func impact_of(kind: String) -> float:
	return float((_clips().get(kind, {}) as Dictionary).get("impact", DEFAULT_IMPACT))

## The clip a rig plays for `kind`: the table's when the rig has it (`clip_lengths` keys), else `attack_tool`.
static func resolve(kind: String, clip_lengths: Dictionary) -> String:
	var clip := clip_of(kind)
	if clip != "" and clip_lengths.has(clip):
		return clip
	return FALLBACK

## Seconds into a clip of `length` at which the strike lands.
static func impact_time(kind: String, length: float) -> float:
	return length * impact_of(kind)
