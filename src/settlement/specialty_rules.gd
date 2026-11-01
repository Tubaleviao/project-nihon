extends RefCounted
## Settlement specialty rules (Phase 199, designed in Phase 197) — the pure half: a member's score per
## specialty from their skill tiers and attributes and the specialty they get (Phase 207 removed the labour
## bonus: a specialty follows from skills and gives nothing on a project). The
## settlement slice reads the host's own skill and attribute records and calls these with plain data.
## Rules come from the fabric's `SettlementSpecialties` world system.

const SkillTiers := preload("res://src/core/skill_tiers.gd")
const AttributeRules := preload("res://src/character/attribute_rules.gd")

## `{ floor, specialties {key: {skills, attributes}} }` (empty specialties when the fabric has none).
static func table() -> Dictionary:
	var res: Resource = GameData.WORLD_SYSTEMS.get("SettlementSpecialties", null)
	var r: Variant = res.get("rules") if res != null else null
	if r is Dictionary and (r as Dictionary).get("specialties", null) is Dictionary:
		return r
	return { "floor": 2, "specialties": {} }

## The score of one specialty definition: weight × tier rank over its skills (`tiers` is { skill: tier },
## a skill with no tier counts as novice = 0) plus weight × attribute points above the base.
static func score(def: Dictionary, tiers: Dictionary, attributes: Dictionary) -> float:
	var n := 0.0
	var skills: Dictionary = def.get("skills", {})
	for skill: String in skills:
		var tier := str(tiers.get(skill, "novice"))
		n += float(skills[skill]) * minf(float(SkillTiers.rank(tier)), float(SkillTiers.TIER_ORDER.size() - 1))
	var attrs: Dictionary = def.get("attributes", {})
	for a: String in attrs:
		n += float(attrs[a]) * maxf(0.0, float(attributes.get(a, AttributeRules.base())) - float(AttributeRules.base()))
	return n

## The specialty key of a member, or "": the best score at or above the floor; a tie goes to the earlier
## row of the fabric table.
static func specialty_for(tiers: Dictionary, attributes: Dictionary, tbl: Dictionary = {}) -> String:
	var t: Dictionary = tbl if not tbl.is_empty() else table()
	var best := ""
	var best_score := float(t.get("floor", 2)) - 0.0005
	for key: String in t.get("specialties", {}):
		var sc := score(t["specialties"][key], tiers, attributes)
		if sc > best_score + 0.0001:
			best = key
			best_score = sc
	return best
