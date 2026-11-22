extends RefCounted
## Phase 229 — skills capped by the gear. Pure rules over the fabric's `GearTiers` world system
## (fabric/gameplay/gear_tiers.js): a combat ability needs an equipped weapon of its tier, and a recipe needs a
## tool and a crafting station of its tier. Empty hands, a weapon of another skill and a missing tool count as
## the floor tier (novice), so a novice ability or recipe needs nothing. Skill XP is untouched here: only use is
## capped, so weaker gear never loses progress.
##
## Refusal reasons are `<refusal key>:<params>` codes (`I18n.reason_text` renders a dotted head as the key):
##   craft.refuse.tool_tier:<tool category>:<tier>    the recipe's tool is below its tier
##   craft.refuse.station_tier:<station type>:<tier>  the station it is made at is below its tier
##   combat.refuse.weapon_tier:<tier>                 the equipped weapon is below the ability's tier
##   combat.refuse.skill_tier:<skill>:<tier>          the skill itself is below the ability's tier

const SkillTiers := preload("res://src/core/skill_tiers.gd")
const GameDataReader := preload("res://src/core/game_data_reader.gd")
const EquipmentRules := preload("res://src/character/equipment_rules.gd")

const SKILL_REFUSAL := "combat.refuse.skill_tier"
const FALLBACK_REFUSALS := {
	"weapon": "combat.refuse.weapon_tier",
	"tool": "craft.refuse.tool_tier",
	"station": "craft.refuse.station_tier",
}

static var _warned_missing := false
static var _cache: Dictionary = {}

## The GearTiers table as plain dictionaries ({} pieces when the table is missing: every check then falls
## back to the floor, which refuses anything above novice).
static func table() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var res: Resource = GameData.WORLD_SYSTEMS.get("GearTiers", null)
	if res == null:
		if not _warned_missing:
			_warned_missing = true
			push_error("[GearTiers] WORLD_SYSTEMS has no GearTiers table: only novice gear tiers resolve")
		return {}
	var out: Dictionary = {}
	for k in ["materialTiers", "stationTools", "abilities", "refusals", "stationTiers", "itemTiers"]:
		var v: Variant = GameDataReader.json_field(res, k, {})
		out[k] = v if v is Dictionary else {}
	out["floor"] = GameDataReader.str_field(res, "floor", "novice")
	_cache = out   # GameData is constant for the process
	return out

static func floor_tier() -> String:
	return str(table().get("floor", "novice"))

static func refusal_key(kind: String) -> String:
	return str((table().get("refusals", {}) as Dictionary).get(kind, FALLBACK_REFUSALS.get(kind, "")))

## Whether `have` reaches `need` (an unknown `need` is never reached; an unknown `have` reaches nothing above it).
static func reaches(have: String, need: String) -> bool:
	return SkillTiers.rank(have if SkillTiers.is_valid_tier(have) else "novice") >= SkillTiers.rank(need)

static func max_tier(a: String, b: String) -> String:
	if not SkillTiers.is_valid_tier(a):
		return b
	if not SkillTiers.is_valid_tier(b):
		return a
	return a if SkillTiers.rank(a) >= SkillTiers.rank(b) else b

# ---------------------------------------------------------------------------
# Items
# ---------------------------------------------------------------------------

## An item's gear tier: its own `tier` field, else the fabric's `itemTiers` row, else its working material's
## tier, else the floor. "" (empty hands) and a non-equipment item are the floor.
static func item_tier(item_key: String) -> String:
	if item_key == "":
		return floor_tier()
	var res: Resource = GameData.ITEMS.get(item_key, null)
	if res != null:
		var own := GameDataReader.str_field(res, "tier", "")
		if SkillTiers.is_valid_tier(own):
			return own
	var t: Dictionary = table()
	var row := str((t.get("itemTiers", {}) as Dictionary).get(item_key, ""))
	if SkillTiers.is_valid_tier(row):
		return row
	var material := str(EquipmentRules.spec_of(item_key).get("material", ""))
	var by_mat := str((t.get("materialTiers", {}) as Dictionary).get(material, ""))
	return by_mat if SkillTiers.is_valid_tier(by_mat) else str(t.get("floor", "novice"))

## The item this machine's player wields (the hotbar UI's view): its held item, else its worn main hand ("" bare).
static func wielded(character_slice: Node) -> String:
	if character_slice == null:
		return ""
	var char_id := str(character_slice.get_player_character())
	if char_id == "":
		return ""
	var held := str(character_slice.held_item_of(char_id))
	return held if held != "" else str(character_slice.get_equipment_set(char_id).get("MainHand", ""))

## The best tier among `items` whose equipment category is `category` (the floor when none is).
static func best_tier_of(category: String, items: Array) -> String:
	var best := floor_tier()
	if category == "":
		return best
	for item in items:
		if EquipmentRules.category_of(str(item)) == category:
			best = max_tier(best, item_tier(str(item)))
	return best

# ---------------------------------------------------------------------------
# Crafting
# ---------------------------------------------------------------------------

## The tier a recipe needs of its tool and station (a recipe with none, or a hand recipe, is the floor).
static func recipe_tier(recipe: Dictionary) -> String:
	var t := str(recipe.get("requiredTier", ""))
	return t if t != "" else floor_tier()

## The equipment category of the tool a recipe made at `station` uses ("" for none: a hand recipe or a station
## whose rule is null).
static func station_tool(station: String) -> String:
	if station == "":
		return ""
	var v: Variant = (table().get("stationTools", {}) as Dictionary).get(station, null)
	return str(v) if v is String else ""

## A station type's tier (the floor for an unknown type).
static func station_tier(station_type: String) -> String:
	var v := str((table().get("stationTiers", {}) as Dictionary).get(station_type, ""))
	return v if SkillTiers.is_valid_tier(v) else floor_tier()

## "" when the gear reaches the recipe's tier, else the first refusal code. `tool_tier` is the crafter's best
## tool of the recipe's tool category; `station_type` is the type the host's own record of the station gives
## ("" when the recipe needs no station).
static func check_recipe(recipe: Dictionary, tool_tier: String, station_type: String) -> String:
	var need := recipe_tier(recipe)
	var station := str(recipe.get("station", ""))
	if station == "" or need == floor_tier():
		return ""
	var tool := station_tool(station)
	if tool != "" and not reaches(tool_tier, need):
		return "%s:%s:%s" % [refusal_key("tool"), tool, need]
	var st := station_type if station_type != "" else station
	if not reaches(station_tier(st), need):
		return "%s:%s:%s" % [refusal_key("station"), st, need]
	return ""

## The tier a gear refusal code says is needed ("" for any other reason): its last `:` part.
static func tier_needed(reason: String) -> String:
	var head := reason.get_slice(":", 0)
	if not (head.begins_with("craft.refuse.") or head.begins_with("combat.refuse.")):
		return ""
	var t := reason.get_slice(":", reason.get_slice_count(":") - 1)
	return t if SkillTiers.is_valid_tier(t) else ""

# ---------------------------------------------------------------------------
# Combat abilities
# ---------------------------------------------------------------------------

## { skill, tier, weapons } for an ability key ({} when no combat skill lists it).
static func ability_spec(ability: String) -> Dictionary:
	var abilities: Dictionary = table().get("abilities", {})
	for skill in abilities:
		var row: Variant = abilities[skill]
		if not (row is Dictionary):
			continue
		var list: Variant = (row as Dictionary).get("abilities", {})
		if list is Dictionary and (list as Dictionary).has(ability):
			var w: Variant = (row as Dictionary).get("weapons", [])
			return { "skill": str(skill), "tier": str(list[ability]), "weapons": w if w is Array else [] }
	return {}

## The abilities a combat skill lists, lowest tier first: [{ ability, tier }].
static func abilities_of(skill: String) -> Array:
	var row: Variant = (table().get("abilities", {}) as Dictionary).get(skill, {})
	var list: Variant = (row as Dictionary).get("abilities", {}) if row is Dictionary else {}
	var out: Array = []
	if not (list is Dictionary):
		return out
	for a in list:
		out.append({ "ability": str(a), "tier": str(list[a]) })
	out.sort_custom(func(x, y): return SkillTiers.rank(str(x["tier"])) < SkillTiers.rank(str(y["tier"])))
	return out

## The tier `weapon` gives an ability: its item tier when it is one of the ability's weapon categories, else
## the floor (empty hands or the wrong weapon).
static func weapon_tier_for(spec: Dictionary, weapon: String) -> String:
	if weapon == "" or not (spec.get("weapons", []) as Array).has(EquipmentRules.category_of(weapon)):
		return floor_tier()
	return item_tier(weapon)

## "" when an ability can be used with `skill_tier` and `weapon`, else a refusal code. An unknown ability is
## `unknown_ability`.
static func check_ability(ability: String, skill_tier: String, weapon: String) -> String:
	var spec := ability_spec(ability)
	if spec.is_empty():
		return "unknown_ability"
	var need := str(spec["tier"])
	if not reaches(skill_tier, need):
		return "%s:%s:%s" % [SKILL_REFUSAL, spec["skill"], need]
	if not reaches(weapon_tier_for(spec, weapon), need):
		return "%s:%s" % [refusal_key("weapon"), need]
	return ""

## The hotbar and skill page projection for a combat skill: one row per ability,
## { ability, tier, available, reason, tier_needed } (tier_needed "" when available).
static func ability_rows(skill: String, skill_tier: String, weapon: String) -> Array:
	var out: Array = []
	for row: Dictionary in abilities_of(skill):
		var reason := check_ability(str(row["ability"]), skill_tier, weapon)
		out.append({ "ability": row["ability"], "tier": row["tier"], "available": reason == "",
			"reason": reason, "tier_needed": "" if reason == "" else str(row["tier"]) })
	return out

## What a hotbar skill box fires: the highest ability of `skill` that the skill tier and `weapon` both reach, else
## the highest the skill tier reaches (so the refusal says which weapon tier is missing), else "".
static func best_usable(skill: String, skill_tier: String, weapon: String) -> String:
	var best := ""
	for row: Dictionary in abilities_of(skill):
		if check_ability(str(row["ability"]), skill_tier, weapon) == "":
			best = str(row["ability"])
	return best if best != "" else best_ability(skill, skill_tier)

## Whether a carried item still works: a durable item with every instance worn out does not (an item the
## inventory does not hold, or one without durability, does).
static func has_wear_left(inv: Object, item: String) -> bool:
	if inv == null or item == "" or not inv.has_method("is_durable") or not inv.is_durable(item):
		return true
	var values: Array = inv.get_durability_values(item)
	if values.is_empty():
		return true
	for v in values:
		if float(v) > 0.0:
			return true
	return false

## The highest ability of `skill` the skill tier reaches, or "".
static func best_ability(skill: String, skill_tier: String) -> String:
	var best := ""
	for row: Dictionary in abilities_of(skill):
		if reaches(skill_tier, str(row["tier"])):
			best = str(row["ability"])
	return best

## Whether `skill` is a combat skill with abilities (a hotbar box for any other skill is not gear-capped).
static func is_combat_skill(skill: String) -> bool:
	return not abilities_of(skill).is_empty()
