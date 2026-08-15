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
## Station gating ("forge", "alchemy bench", …) is intentionally NOT enforced
## yet — there is no building system to place stations. The `station` field is
## carried through for documentation and future gating.
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

## Skill tier order — matches the fabric skill state machine
## (fabric/gameplay/skills/shared.js): novice → apprentice → journeyman → expert → master.
const TIER_ORDER: Array = ["novice", "apprentice", "journeyman", "expert", "master"]

## Set by game_root so recipes can consume/produce inventory items.
var inventory_slice: Node = null

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
		if _tier_rank(get_skill(skill)) < _tier_rank(required_tier):
			return "skill_requirement:%s:%s" % [skill, required_tier]
	return ""

func _tier_rank(tier: String) -> int:
	return TIER_ORDER.find(tier)

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
