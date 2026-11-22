extends RefCounted
## Phase 287 — attack combos: the pure half. Which clip a swing plays, the damage multiplier and impact time of
## its step, read from the fabric's `CombatCombos` world system. Repeated swings inside the chain's window step
## through the weapon class's variants; a pause past the window, or another weapon class, restarts at the first.

const GameDataReader := preload("res://src/core/game_data_reader.gd")
const EquipmentRules := preload("res://src/character/equipment_rules.gd")

const FALLBACK_CLIP := "attack"

static func _res() -> Resource:
	return GameData.WORLD_SYSTEMS.get("CombatCombos", null)

static func _chains() -> Dictionary:
	var res := _res()
	var v: Variant = res.get("chains") if res != null else null
	return v if v is Dictionary else {}

## "unarmed", "tool", "two_hand" or "one_hand" for a main-hand item: its equipment category's chain (Phase 296:
## `Equipment.categories[..].clipFamily`), one-handed for a held item that is not equipment.
static func weapon_class(item_key: String, items: Dictionary) -> String:
	return EquipmentRules.clip_family(item_key, items)

static func chain(weapon: String) -> Dictionary:
	var c: Variant = _chains().get(weapon, null)
	return c if c is Dictionary else {}

## The step the next swing takes. `last_step` is the previous swing's step (-1 for none), `last_weapon` its class,
## `elapsed` the seconds since it started. Inside the window the chain advances (and wraps); otherwise it restarts.
static func next_step(weapon: String, last_weapon: String, last_step: int, elapsed: float) -> int:
	var c := chain(weapon)
	var n: int = (c.get("clips", []) as Array).size()
	if n == 0 or last_step < 0 or last_weapon != weapon or elapsed > float(c.get("windowSeconds", 0.0)):
		return 0
	return (last_step + 1) % n

## Length in seconds of each attack clip on the placeholder rig (`tools/gen_placeholder_glb.py`). A host that draws no
## body for a peer times that peer's swing from this; a body that is drawn reports its own rig's real lengths.
const PLACEHOLDER_LENGTHS := {
	"attack": 0.5, "attack_unarmed": 0.4, "attack_unarmed_2": 0.4, "attack_1h": 0.5, "attack_1h_2": 0.5,
	"attack_1h_3": 0.6, "attack_2h": 0.6, "attack_2h_2": 0.65, "attack_tool": 0.5,
}

static func placeholder_length(weapon: String, step: int) -> float:
	return float(PLACEHOLDER_LENGTHS.get(clip_for(weapon, step), 0.5))

## The clip of a step: the table's, else (the rig lacks the variant) the chain's base clip, else `attack`.
## `available` is a Dictionary or an Array of the rig's clip names; null means "assume everything exists".
static func clip_for(weapon: String, step: int, available: Variant = null) -> String:
	var clips: Array = chain(weapon).get("clips", [])
	if clips.is_empty():
		return FALLBACK_CLIP
	var want := str(clips[clampi(step, 0, clips.size() - 1)])
	if available == null or want in available:
		return want
	return str(clips[0]) if str(clips[0]) in available else FALLBACK_CLIP

static func damage_multiplier(weapon: String, step: int) -> float:
	var m: Array = chain(weapon).get("damageMultipliers", [])
	return float(m[clampi(step, 0, m.size() - 1)]) if not m.is_empty() else 1.0

## Seconds into a clip of `clip_length` at which the blow lands (the table's `impact` share of it).
static func impact_seconds(weapon: String, step: int, clip_length: float) -> float:
	var t: Array = chain(weapon).get("impact", [])
	return float(t[clampi(step, 0, t.size() - 1)]) * clip_length if not t.is_empty() else clip_length * 0.5
