extends RefCounted
## Pure carcass rules (Phase 161): what a body can still give, what a tool can take, how a Skinning level
## scales a harvest, and what a body weighs against a carrier's capacity. Everything is read from the
## fabric (`GameData.CREATURES`, `SKILLS["Skinning"]`, `HARVESTS["HarvestRules"]`, item `harvestTool`); no
## number lives here.

const SKILL := "Skinning"
const CARRY_RULES := ["carry", "drag", "immovable"]

static func rules() -> Resource:
	return GameData.HARVESTS.get("HarvestRules", null)

static func rule_f(key: String, fallback: float) -> float:
	var r: Resource = rules()
	return float(r.get(key)) if r != null else fallback

static func skill() -> Resource:
	return GameData.SKILLS.get(SKILL, null)

## A creature's harvest entries as `[{ item, chance, minQty, maxQty, tool, skill }]` (empty when unknown).
static func entries_for(creature_key: String) -> Array:
	var res: Resource = GameData.CREATURES.get(creature_key, null)
	if res == null:
		return []
	var drops = res.get("drops")
	if drops is String and drops != "":
		drops = JSON.parse_string(drops)
	var out: Array = []
	if drops is Array:
		for e in drops:
			if e is Dictionary and str(e.get("item", "")) != "":
				out.append((e as Dictionary).duplicate())
	return out

static func mass_of(creature_key: String) -> float:
	var res: Resource = GameData.CREATURES.get(creature_key, null)
	return float(res.get("carcassMassKg")) if res != null else 0.0

static func corpse_seconds(creature_key: String) -> float:
	var res: Resource = GameData.CREATURES.get(creature_key, null)
	return float(res.get("corpseSeconds")) if res != null else 0.0

## "carry", "drag" or "immovable" (enum fields load as the value's index).
static func carry_rule(creature_key: String) -> String:
	var res: Resource = GameData.CREATURES.get(creature_key, null)
	if res == null:
		return "immovable"
	var i := int(res.get("carryRule"))
	return CARRY_RULES[i] if i >= 0 and i < CARRY_RULES.size() else "immovable"

## Skinning level for an XP total: the highest level whose threshold the XP reaches.
static func level_for_xp(xp: int) -> int:
	var s: Resource = skill()
	if s == null:
		return 0
	var table: Array = s.get("xpToLevel")
	var level := 0
	for l in table.size():
		if xp >= int(table[l]):
			level = l
	return mini(level, int(s.get("levelCap")))

## The level a tool of `efficiency` works at: floor(level * efficiency).
static func effective_level(level: int, efficiency: float) -> int:
	return clampi(int(floor(float(level) * clampf(efficiency, 0.0, 1.0))), 0, int(skill().get("levelCap")))

## The harvest category an item provides and how well: `{ tool, efficiency }`, or `{}` for a non-tool.
static func tool_of(item_id: String) -> Dictionary:
	var res: Resource = GameData.ITEMS.get(item_id, null)
	if res == null:
		return {}
	var t = res.get("harvestTool")
	if t == null or str(t) == "":
		return {}
	return { "tool": str(t), "efficiency": float(res.get("efficiency")) }

## Whether `category` can work an entry needing `entry_tool` (`none` entries need no tool at all).
static func entry_workable(entry: Dictionary, category: String) -> bool:
	var need := str(entry.get("tool", "none"))
	return need == "none" or need == category

## Quantity for one entry at an effective level: `minQty` at level 0 rising to `maxQty` at the cap along
## the yield curve. `roll` in [0, 1) is the chance roll (the entry's chance plus the level's bonus); a
## failed roll gives 0.
static func quantity(entry: Dictionary, eff_level: int, roll: float) -> int:
	var s: Resource = skill()
	var chance_c: Array = s.get("chanceCurve")
	var yield_c: Array = s.get("yieldCurve")
	var l := clampi(eff_level, 0, chance_c.size() - 1)
	if roll >= minf(1.0, float(entry.get("chance", 0.0)) + float(chance_c[l])):
		return 0
	var lo := int(entry.get("minQty", 1))
	var hi := int(entry.get("maxQty", lo))
	return lo + int(round(float(hi - lo) * float(yield_c[l])))

static func quality(eff_level: int) -> String:
	var q: Array = skill().get("qualityCurve")
	return str(q[clampi(eff_level, 0, q.size() - 1)])

## Carry capacity in kg: the base from the player entity plus the Skinning bonus.
static func capacity_kg(level: int) -> float:
	var base := float(GameData.PLAYERS["PlayerCharacter"].get("carryCapacityKg"))
	return base + rule_f("carryBonusPerSkinningLevelKg", 0.0) * float(level)

## "carry", "drag" or "none" for a body of `mass` kg under `rule` against `capacity`.
static func carry_mode(rule: String, mass: float, capacity: float) -> String:
	if rule == "immovable":
		return "none"
	if mass <= capacity:
		return "carry"
	if rule == "drag" and mass <= capacity * rule_f("dragCapacityFactor", 1.0):
		return "drag"
	return "none"

## Walk speed multiplier while holding a body in `mode`.
static func speed_multiplier(mode: String, mass: float, capacity: float) -> float:
	if mode == "drag":
		return rule_f("dragSpeedMultiplier", 1.0)
	if mode == "carry" and mass > capacity * rule_f("carrySlowAboveFraction", 1.0):
		return rule_f("carrySlowSpeedMultiplier", 1.0)
	return 1.0

## The prompt for a body: `[key, args]` for I18n. `held` lists the harvest categories the viewer holds.
## Entries a held category can work are named; if none can, the first missing category is named instead.
static func prompt_for(entries: Array, held: Array, carrying: bool) -> Array:
	if carrying:
		return ["hud.carcass.carrying", []]
	var can: Array = []
	var missing := ""
	for e in entries:
		var need := str(e.get("tool", "none"))
		if need == "none" or held.has(need):
			can.append(str(e["item"]))
		elif missing == "":
			missing = need
	if not can.is_empty():
		return ["hud.carcass.harvest", [", ".join(can)]]
	if missing != "":
		return ["hud.carcass.needs", ["tool." + missing]]
	return ["hud.carcass.empty", []]
