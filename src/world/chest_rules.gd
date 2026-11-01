extends RefCounted
## Chest and door rules (Phase 208) — pure reads of the fabric's `ChestsAndDoors` world system (Phase 203) and
## the numbers derived from it: access modes, the station types and their placement items, and a lock's
## difficulty, durability, pick time and tool-break chance. No state: `ChestSlice` holds the chests and doors.

const StructureRules := preload("res://src/structure/structure_rules.gd")

static func rules() -> Dictionary:
	var res: Resource = GameData.WORLD_SYSTEMS.get("ChestsAndDoors", null)
	var r: Variant = res.get("rules") if res != null else null
	return r if r is Dictionary else {}

static func modes() -> Array:
	return rules().get("accessModes", ["owner", "clan", "everyone"])

static func default_mode() -> String:
	return str(rules().get("defaultMode", "owner"))

static func _stations() -> Dictionary:
	var s: Variant = rules().get("stations", {})
	return s if s is Dictionary else {}

## The station types that are chests or doors (`stations` keys), sorted.
static func station_types() -> Array:
	var out: Array = _stations().keys()
	out.sort()
	return out

static func is_lock_type(type: String) -> bool:
	return _stations().has(type)

## A chest holds items; a door does not (a station row with `capacityStacks`).
static func holds_items(type: String) -> bool:
	return int((_stations().get(type, {}) as Dictionary).get("capacityStacks", 0)) > 0

static func capacity_stacks(type: String) -> int:
	return int((_stations().get(type, {}) as Dictionary).get("capacityStacks", 0))

static func spills(type: String) -> bool:
	return bool((_stations().get(type, {}) as Dictionary).get("spillsOnDestroy", false))

## The item one placement of `type` consumes ("" for a type that is not a chest or door).
static func placement_item(type: String) -> String:
	return str((_stations().get(type, {}) as Dictionary).get("placementItem", ""))

static func lock_material(type: String) -> String:
	return str((_stations().get(type, {}) as Dictionary).get("lockMaterial", ""))

static func _locks() -> Dictionary:
	var l: Variant = rules().get("locks", {})
	return l if l is Dictionary else {}

static func tool_type() -> String:
	return str(_locks().get("toolType", "lockpick"))

## The lock technologies from weakest to strongest (`none` first).
static func technologies() -> Array:
	var t: Dictionary = _locks().get("technologies", {})
	var out: Array = t.keys()
	out.sort_custom(func(a: Variant, b: Variant) -> bool: return float(t[a]) < float(t[b]) or (float(t[a]) == float(t[b]) and str(a) < str(b)))
	return out

## The strongest lock technology `is_known(tech) -> bool` says the owner knows, or "none".
static func best_technology(is_known: Callable) -> String:
	var best := "none"
	for tech: String in technologies():
		if tech != "none" and is_known.is_valid() and bool(is_known.call(tech)):
			best = tech
	return best

## `materials[material] × technologies[tech]` (1 for an unknown material or technology).
static func difficulty(material: String, tech: String) -> float:
	var l := _locks()
	var m := float((l.get("materials", {}) as Dictionary).get(material, 1.0))
	var t := float((l.get("technologies", {}) as Dictionary).get(tech, 1.0))
	return maxf(1.0, m) * maxf(1.0, t)

## A lock's durability: the material's durability × `durabilityFactor` × the technology multiplier.
static func lock_durability(material: String, tech: String) -> float:
	var t := float((_locks().get("technologies", {}) as Dictionary).get(tech, 1.0))
	return StructureRules.base_durability(material) * float(_locks().get("durabilityFactor", 1.0)) * maxf(1.0, t)

## Seconds a pick takes: `pickSeconds` × difficulty × (1 − `skillSpeedup` × level / levelCap).
static func pick_seconds(diff: float, level: int, level_cap: int) -> float:
	var l := _locks()
	var skill := clampf(float(level) / float(maxi(1, level_cap)), 0.0, 1.0)
	return float(l.get("pickSeconds", 6.0)) * maxf(1.0, diff) * (1.0 - float(l.get("skillSpeedup", 0.0)) * skill)

## The chance a failed pick breaks the tool: `breakChance` / difficulty, capped at 1.
static func break_chance(diff: float) -> float:
	return clampf(float(_locks().get("breakChance", 0.0)) / maxf(1.0, diff), 0.0, 1.0)
