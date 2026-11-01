extends RefCounted
## Structure rules (Phase 205) — pure reads of the fabric's `Structure`, `StructureDurability` and `SelfRespawn`
## world systems (Phase 203) and the numbers derived from them. No state: `StructureSlice` holds the index.

## The structural classes in the fabric's order (`fabric/world/materials/structural.js`): a material's
## `structuralClass` is an index into this list.
const CLASSES := ["earth", "wood", "stone", "concrete", "steel", "composite"]
## Destruction methods the runtime can name today (`StructureDurability.methods`).
const METHODS := ["hand", "pick", "axe", "weapon"]

static func _rules(system: String) -> Dictionary:
	var res: Resource = GameData.WORLD_SYSTEMS.get(system, null)
	var r: Variant = res.get("rules") if res != null else null
	return r if r is Dictionary else {}

static func structure() -> Dictionary:
	return _rules("Structure")

static func durability_rules() -> Dictionary:
	return _rules("StructureDurability")

static func respawn() -> Dictionary:
	return _rules("SelfRespawn")

## A placed block's base durability from its material (0 for an unknown one).
static func base_durability(material: String) -> float:
	var m: Resource = GameData.MATERIALS.get(material, null)
	return maxf(0.0, float(m.get("durability"))) if m != null and m.get("durability") != null else 0.0

static func class_of(material: String) -> String:
	var m: Resource = GameData.MATERIALS.get(material, null)
	var i := int(m.get("structuralClass")) if m != null and m.get("structuralClass") != null else 0
	return CLASSES[i] if i >= 0 and i < CLASSES.size() else CLASSES[0]

## Durability points one hit of `method` takes off a block of `material`: the method's damage times its
## multiplier for the material's class times `loss.perDamage`, divided by the method's `offlineFactor` while
## every owner is offline. An unknown method hits as a bare hand.
static func hit_damage(method: String, material: String, owners_offline: bool) -> float:
	var d := durability_rules()
	var methods: Dictionary = d.get("methods", {})
	var m: Dictionary = methods.get(method, methods.get("hand", {}))
	var mult := float((m.get("classes", {}) as Dictionary).get(class_of(material), 0.0))
	var points := float(m.get("damage", 0.0)) * mult * float((d.get("loss", {}) as Dictionary).get("perDamage", 1.0))
	if owners_offline:
		points /= maxf(1.0, float(m.get("offlineFactor", 1.0)))
	return points

## Wear (a fraction of base durability) `hours` in-game hours of age add, before weather.
static func age_wear(hours: float) -> float:
	return float((durability_rules().get("loss", {}) as Dictionary).get("perDay", 0.0)) * maxf(0.0, hours) / 24.0

## Wear one in-game hour of weather `state` adds on an exposed block.
static func weather_wear(state: String) -> float:
	return float(((durability_rules().get("loss", {}) as Dictionary).get("weather", {}) as Dictionary).get(state, 0.0))

## The share of a block's material dismantling returns, from the durability fraction (0..1) and the
## dismantler's Building level: (atNoSkill + (atTopSkill − atNoSkill) × level / topLevel) × fraction ^ exponent.
static func dismantle_share(fraction: float, level: int) -> float:
	var d: Dictionary = durability_rules().get("dismantle", {})
	var top := maxf(1.0, float(d.get("topLevel", 1)))
	var skill := clampf(float(level) / top, 0.0, 1.0)
	var lo := float(d.get("atNoSkill", 0.5))
	var hi := float(d.get("atTopSkill", 1.0))
	return (lo + (hi - lo) * skill) * pow(clampf(fraction, 0.0, 1.0), float(d.get("durabilityExponent", 1.0)))

static func repair_share() -> float:
	return float((durability_rules().get("repair", {}) as Dictionary).get("share", 0.5))

## The skill dismantling reads (`dismantle.skill`, Building).
static func dismantle_skill() -> String:
	return str((durability_rules().get("dismantle", {}) as Dictionary).get("skill", "Building"))

## A skill level for an XP total: the highest level whose `xpToLevel` threshold the XP reaches, capped.
static func level_for_xp(skill: String, xp: int) -> int:
	var s: Resource = GameData.SKILLS.get(skill, null)
	if s == null:
		return 0
	var table: Array = s.get("xpToLevel")
	var level := 0
	for l in table.size():
		if xp >= int(table[l]):
			level = l
	return mini(level, int(s.get("levelCap")))

## A structure's circle radius in metres from its footprint (m²) and height (m), clamped to the fabric's bounds.
static func circle_radius(footprint_m2: float, height_m: float) -> float:
	var c: Dictionary = structure().get("circle", {})
	var lo := float(c.get("minRadius", 8.0))
	var r := lo + float(c.get("footprintFactor", 1.0)) * sqrt(maxf(0.0, footprint_m2)) + float(c.get("heightFactor", 0.0)) * maxf(0.0, height_m)
	return clampf(r, lo, float(c.get("maxRadius", 128.0)))

static func respawn_cooldown_sec() -> float:
	return float(respawn().get("cooldownSeconds", 60.0))
