extends Node
## Crafting slice — resolves fabric recipes against the player's inventory and
## skill tiers. Recipes are read from GameData.RECIPES (the generated registry);
## each recipe's structured `recipe` json field (fabric/gameplay/recipes/*.js)
## carries inputs (item key + quantity), outputs (item key + quantity), and
## skill guards (skill key + minimum tier). The fabric is the single source of
## truth — this slice never hardcodes recipe content.
##
## Inputs/outputs reference entity keys from GameData.ITEMS or
## GameData.MATERIALS. The inventory treats both uniformly (keys are strings);
## raw material weights resolve to 0 until materials gain a weight model.
##
## Station gating: recipes whose `recipe` json names a `station` field must be
## crafted within STATION_RADIUS of a placed station of that type. The station
## slice (src/world/station_slice.gd) tracks placed stations; this slice reads
## the `station` field and fails with `station_required:<type>` when none is near.
##
## Plug contract (GameBus signals consumed / emitted):
##   IN  : craft_requested(recipe_id)
##   OUT : craft_resolved(result)
##         result: { recipe_id, success, outputs: [{ item, quantity }], reason }
##
## Public API:
##   craft(recipe_id)      -> Dictionary  (resolve immediately, mutating inventory)
##   can_craft(recipe_id)  -> Dictionary  (non-mutating check)
##   get_recipe(recipe_id) -> Dictionary  (structured recipe or {})
##   set_skill / get_skill / get_skills

## Shared skill-tier ordering (novice → master) — see src/core/skill_tiers.gd.
const SkillTiers := preload("res://src/core/skill_tiers.gd")

## Set by game_root so recipes can consume/produce inventory items.
var inventory_slice: Node = null

## Set by game_root so recipes are gated behind the technology tree. When null
## (isolated unit tests) the gate is not applied.
var technology_slice: Node = null

## Set by game_root so recipes are gated behind a nearby crafting station. When
## null (isolated unit tests) the gate is not applied.
var station_slice: Node = null

## Radius (m) within which a recipe's required station must be placed.
const STATION_RADIUS: float = 8.0

## Runtime player skill tiers: skill key → tier name. Seeded from
## GameData.SKILLS at the lowest tier; a progression system raises them later.
var _skill_tiers: Dictionary = {}

func _ready() -> void:
	for skill_key in GameData.SKILLS:
		_skill_tiers[skill_key] = "novice"
	GameBus.craft_requested.connect(_on_craft_requested)

## Resolve a recipe against the inventory and skill tiers, consuming inputs and
## producing outputs on success. Emits craft_resolved. Never throws.
func craft(recipe_id: String) -> Dictionary:
	var recipe := get_recipe(recipe_id)
	if recipe.is_empty():
		return _fail(recipe_id, "unknown_recipe")

	var guard_reason := _check_skill_guards(recipe)
	if guard_reason != "":
		return _fail(recipe_id, guard_reason)

	var tech_reason := _check_tech_gate(recipe_id)
	if tech_reason != "":
		return _fail(recipe_id, tech_reason)

	var station_reason := _check_station_gate(recipe)
	if station_reason != "":
		return _fail(recipe_id, station_reason)

	var inputs: Array = recipe.get("inputs", [])
	var outputs: Array = recipe.get("outputs", [])

	if inventory_slice == null or not inventory_slice.has_method("consume_items"):
		return _fail(recipe_id, "no_inventory")

	# Availability check (inputs present) — consume_items is atomic, but a clear
	# reason beats a silent miss.
	for entry in inputs:
		var item_id: String = str(entry.get("item", ""))
		var qty: int = int(entry.get("quantity", 1))
		if inventory_slice.get_item_count(item_id) < qty:
			return _fail(recipe_id, "missing_inputs")

	# Capacity check (outputs will fit) BEFORE consuming inputs, so a failed
	# craft never leaves the inventory half-consumed.
	if not inventory_slice.can_add_items(_to_counts(outputs)):
		return _fail(recipe_id, "inventory_full")

	# Consume inputs, then produce outputs.
	if not inventory_slice.consume_items(_to_counts(inputs)):
		return _fail(recipe_id, "missing_inputs")

	var produced: Array = []
	for entry in outputs:
		var item_id: String = str(entry.get("item", ""))
		var qty: int = int(entry.get("quantity", 1))
		inventory_slice.add_item(item_id, qty)
		produced.append({ "item": item_id, "quantity": qty })

	return _ok(recipe_id, produced)

## Non-mutating check: returns the same result shape craft() would, with
## success=true only if the recipe would currently succeed. Does NOT emit
## craft_resolved (it is a query, not a craft attempt).
func can_craft(recipe_id: String) -> Dictionary:
	var recipe := get_recipe(recipe_id)
	if recipe.is_empty():
		return _result(recipe_id, false, [], "unknown_recipe")
	var guard_reason := _check_skill_guards(recipe)
	if guard_reason != "":
		return _result(recipe_id, false, [], guard_reason)
	var tech_reason := _check_tech_gate(recipe_id)
	if tech_reason != "":
		return _result(recipe_id, false, [], tech_reason)
	var station_reason := _check_station_gate(recipe)
	if station_reason != "":
		return _result(recipe_id, false, [], station_reason)
	if inventory_slice == null:
		return _result(recipe_id, false, [], "no_inventory")
	for entry in recipe.get("inputs", []):
		var item_id: String = str(entry.get("item", ""))
		var qty: int = int(entry.get("quantity", 1))
		if inventory_slice.get_item_count(item_id) < qty:
			return _result(recipe_id, false, [], "missing_inputs")
	if not inventory_slice.can_add_items(_to_counts(recipe.get("outputs", []))):
		return _result(recipe_id, false, [], "inventory_full")
	return _result(recipe_id, true, recipe.get("outputs", []), "")

## Return the structured recipe data for a recipe key, or {} if unknown/malformed.
func get_recipe(recipe_id: String) -> Dictionary:
	var res: Resource = GameData.RECIPES.get(recipe_id, null)
	if res == null:
		return {}
	var v = res.get("recipe")
	if v is Dictionary:
		return v
	if v is String and v != "":
		var parsed = JSON.parse_string(v)
		if parsed is Dictionary:
			return parsed
	return {}

func set_skill(skill: String, tier: String) -> void:
	_skill_tiers[skill] = tier

func get_skill(skill: String) -> String:
	return str(_skill_tiers.get(skill, "novice"))

func get_skills() -> Dictionary:
	return _skill_tiers.duplicate()

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _on_craft_requested(recipe_id: String) -> void:
	craft(recipe_id)

## Return "" when all skill guards pass, or a `skill_requirement:Skill:tier`
## reason string identifying the first unmet guard.
func _check_skill_guards(recipe: Dictionary) -> String:
	for guard in recipe.get("skillGuards", []):
		var skill: String = str(guard.get("skill", ""))
		var required_tier: String = str(guard.get("tier", "novice"))
		if SkillTiers.rank(get_skill(skill)) < SkillTiers.rank(required_tier):
			return "skill_requirement:%s:%s" % [skill, required_tier]
	return ""

## Return "" when the recipe's owning technology is unlocked (or no technology
## slice is wired — isolated unit tests), or a `technology_locked:<tech>` reason
## string. Fail-closed when a technology slice is present and the recipe is
## unmapped.
func _check_tech_gate(recipe_id: String) -> String:
	if technology_slice == null or not technology_slice.has_method("is_recipe_unlocked"):
		return ""
	if technology_slice.is_recipe_unlocked(recipe_id):
		return ""
	var tech_id := ""
	if technology_slice.has_method("get_recipe_tech"):
		tech_id = str(technology_slice.get_recipe_tech(recipe_id))
	if tech_id != "":
		return "technology_locked:%s" % tech_id
	return "technology_locked"

## Return "" when the recipe's required station (its `station` json field) is
## absent OR a matching station is within STATION_RADIUS of the player, else a
## `station_required:<type>` reason string. Recipes without a station field are
## not gated. When no station slice is wired (isolated unit tests) the gate is
## skipped — mirroring the technology gate's isolated-test behaviour.
func _check_station_gate(recipe: Dictionary) -> String:
	var station: String = str(recipe.get("station", ""))
	if station == "":
		return ""
	if station_slice == null or not station_slice.has_method("station_near_player"):
		return ""
	if station_slice.station_near_player(station, STATION_RADIUS):
		return ""
	return "station_required:%s" % station

## Collapse a [{ item, quantity }] list into a { item: quantity } map, summing
## any duplicate item keys.
func _to_counts(entries: Array) -> Dictionary:
	var counts: Dictionary = {}
	for entry in entries:
		var item_id: String = str(entry.get("item", ""))
		var qty: int = int(entry.get("quantity", 1))
		counts[item_id] = counts.get(item_id, 0) + qty
	return counts

func _result(recipe_id: String, success: bool, outputs: Array, reason: String) -> Dictionary:
	return { "recipe_id": recipe_id, "success": success, "outputs": outputs, "reason": reason }

func _ok(recipe_id: String, outputs: Array) -> Dictionary:
	var result := _result(recipe_id, true, outputs, "")
	GameBus.craft_resolved.emit(result)
	return result

func _fail(recipe_id: String, reason: String) -> Dictionary:
	var result := _result(recipe_id, false, [], reason)
	GameBus.craft_resolved.emit(result)
	return result
