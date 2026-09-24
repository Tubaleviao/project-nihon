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
##         craft_intent(recipe_id, player_id)   — Phase 33: who is crafting
##         repair_requested(item_id)
##         repair_intent(item_id, player_id)    — Phase 34: who is repairing
##   OUT : craft_resolved(result)
##         result: { recipe_id, success, outputs: [{ item, quantity }], reason,
##                   player_id }
##         craft_intent(recipe_id, "")          — client forwards to the host
##         repair_resolved(result)              — { item_id, success, reason,
##                                                 player_id }
##         repair_intent(item_id, "")           — client forwards to the host
##
## Public API:
##   craft(recipe_id, player_id := "") -> Dictionary
##   can_craft(recipe_id, player_id := "") -> Dictionary
##   get_recipe(recipe_id) -> Dictionary  (structured recipe or {})
##   repair(item_id, player_id := "") -> Dictionary
##   can_repair(item_id, spec := {}, player_id := "") -> Dictionary
##   inventory_for(player_id) -> Node
##   set_skill / get_skill / get_skills
##
## Crafting is PER-PLAYER (Phase 33): each player owns an inventory that is
## persisted with their record, so a recipe must be resolved against the crafter's
## own inventory rather than a single host-scoped one — otherwise a remote peer's
## crafts (and the materials they consume) would land on the host's inventory and
## be persisted against the host's record. `player_id` selects the inventory;
## "" (the default, and every isolated unit test) falls back to `inventory_slice`.
##
## REPAIR is per-player for exactly the same reason (Phase 34): it consumes a
## durable item's repair materials and restores that item's durability, both of
## which live in the player's own inventory. It used to read `inventory_slice`
## directly, so a remote peer's repair either did nothing (no intent existed) or
## spent the host's materials on the host's tool.

## Shared skill-tier ordering (novice → master) — see src/core/skill_tiers.gd.
const SkillTiers := preload("res://src/core/skill_tiers.gd")

## Set by game_root so recipes can consume/produce inventory items. The fallback
## inventory when no per-player registry is wired (isolated unit tests) or when no
## player id is given.
var inventory_slice: Node = null

## Set by game_root: the PlayerRegistry, which owns one inventory per player. When
## wired, `inventory_for(player_id)` resolves the crafter's own inventory.
var player_registry: Node = null

## Authority mode: true on the host / single-player (this slice resolves the craft),
## false on a client (it forwards a craft intent to the host instead, which is the
## only machine that owns the player records).
var is_authoritative: bool = true

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
	GameBus.craft_intent.connect(_on_craft_intent)
	GameBus.repair_requested.connect(_on_repair_requested)
	GameBus.repair_intent.connect(_on_repair_intent)

## The inventory a craft by `player_id` resolves against: that player's own
## inventory from the registry when one is wired, else the slice's fallback.
func inventory_for(player_id: String) -> Node:
	if player_id != "" and player_registry != null and player_registry.has_method("get_inventory"):
		return player_registry.get_inventory(player_id)
	return inventory_slice

## Resolve a recipe against the crafter's inventory and skill tiers, consuming
## inputs and producing outputs on success. Emits craft_resolved. Never throws.
func craft(recipe_id: String, player_id: String = "") -> Dictionary:
	var pid := _resolve_player(player_id)
	var recipe := get_recipe(recipe_id)
	if recipe.is_empty():
		return _fail(recipe_id, "unknown_recipe", pid)

	var guard_reason := _check_skill_guards(recipe)
	if guard_reason != "":
		return _fail(recipe_id, guard_reason, pid)

	var tech_reason := _check_tech_gate(recipe_id, pid)
	if tech_reason != "":
		return _fail(recipe_id, tech_reason, pid)

	var station_reason := _check_station_gate(recipe)
	if station_reason != "":
		return _fail(recipe_id, station_reason, pid)

	var inputs: Array = recipe.get("inputs", [])
	var outputs: Array = recipe.get("outputs", [])

	var inventory := inventory_for(pid)
	if inventory == null or not inventory.has_method("consume_items"):
		return _fail(recipe_id, "no_inventory", pid)

	# Availability check (inputs present) — consume_items is atomic, but a clear
	# reason beats a silent miss.
	for entry in inputs:
		var item_id: String = str(entry.get("item", ""))
		var qty: int = int(entry.get("quantity", 1))
		if inventory.get_item_count(item_id) < qty:
			return _fail(recipe_id, "missing_inputs", pid)

	# Capacity check (outputs will fit) BEFORE consuming inputs, so a failed
	# craft never leaves the inventory half-consumed.
	if not inventory.can_add_items(_to_counts(outputs)):
		return _fail(recipe_id, "inventory_full", pid)

	# Consume inputs, then produce outputs.
	if not inventory.consume_items(_to_counts(inputs)):
		return _fail(recipe_id, "missing_inputs", pid)

	var produced: Array = []
	for entry in outputs:
		var item_id: String = str(entry.get("item", ""))
		var qty: int = int(entry.get("quantity", 1))
		inventory.add_item(item_id, qty)
		produced.append({ "item": item_id, "quantity": qty })

	return _ok(recipe_id, produced, pid)

## Non-mutating check: returns the same result shape craft() would, with
## success=true only if the recipe would currently succeed. Does NOT emit
## craft_resolved (it is a query, not a craft attempt).
func can_craft(recipe_id: String, player_id: String = "") -> Dictionary:
	var pid := _resolve_player(player_id)
	var recipe := get_recipe(recipe_id)
	if recipe.is_empty():
		return _result(recipe_id, false, [], "unknown_recipe", pid)
	var guard_reason := _check_skill_guards(recipe)
	if guard_reason != "":
		return _result(recipe_id, false, [], guard_reason, pid)
	var tech_reason := _check_tech_gate(recipe_id, pid)
	if tech_reason != "":
		return _result(recipe_id, false, [], tech_reason, pid)
	var station_reason := _check_station_gate(recipe)
	if station_reason != "":
		return _result(recipe_id, false, [], station_reason, pid)
	var inventory := inventory_for(pid)
	if inventory == null:
		return _result(recipe_id, false, [], "no_inventory", pid)
	for entry in recipe.get("inputs", []):
		var item_id: String = str(entry.get("item", ""))
		var qty: int = int(entry.get("quantity", 1))
		if inventory.get_item_count(item_id) < qty:
			return _result(recipe_id, false, [], "missing_inputs", pid)
	if not inventory.can_add_items(_to_counts(recipe.get("outputs", []))):
		return _result(recipe_id, false, [], "inventory_full", pid)
	return _result(recipe_id, true, recipe.get("outputs", []), "", pid)

## Return the structured recipe data for a recipe key, or {} if unknown/malformed.
func get_recipe(recipe_id: String) -> Dictionary:
	return _structured_field(GameData.RECIPES, recipe_id, "recipe")

## Set a skill's tier. Returns true when applied, false when `tier` is not a
## known tier (in which case the skill keeps its previous tier).
func set_skill(skill: String, tier: String) -> bool:
	if not SkillTiers.is_valid_tier(tier):
		push_warning("CraftingSlice: ignoring unknown skill tier '%s' for '%s'" % [tier, skill])
		return false
	_skill_tiers[skill] = tier
	return true

func get_skill(skill: String) -> String:
	return str(_skill_tiers.get(skill, "novice"))

func get_skills() -> Dictionary:
	return _skill_tiers.duplicate()

## Return the structured repair spec for a durable item, or {} when the item has
## no repair field (stackable materials, or items whose repair references
## unmodelled entities such as the VoiditeEdge "refined voidite shard"). Reads
## GameData.ITEMS[key].repair — the fabric's single source of truth. Shape:
## { station, materials: [{item, quantity}], skillGuards: [{skill, tier}] }.
func get_repair_spec(item_id: String) -> Dictionary:
	return _structured_field(GameData.ITEMS, item_id, "repair")

## Repair a held durable item: validate guards, consume the repair materials, and
## restore the item to pristine (full durability). Emits repair_resolved.
##
## Phase 34 — resolved against the REPAIRING player's own inventory: the materials
## come off their stack and their tool's durability is what is restored, so a
## remote peer's repair can never spend or fix the host's. `player_id` selects the
## inventory; "" (the default, and every isolated unit test) means this machine's
## local player.
func repair(item_id: String, player_id: String = "") -> Dictionary:
	var result := _resolve_repair(item_id, true, get_repair_spec(item_id), player_id)
	GameBus.repair_resolved.emit(result)
	return result

## Non-mutating repair check: the same result shape repair() would produce, with
## success=true only if the repair would currently succeed. Does NOT emit
## repair_resolved (a query, not a repair attempt). Accepts an already-loaded
## `spec` so callers that have already fetched it (e.g. repair_rows) don't pay a
## second deep-copy.
func can_repair(item_id: String, spec: Dictionary = {}, player_id: String = "") -> Dictionary:
	if spec.is_empty():
		spec = get_repair_spec(item_id)
	return _resolve_repair(item_id, false, spec, player_id)

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

## Host-local craft request (the UI or any host-side system): resolved against the
## local player's own inventory. A CLIENT does not resolve crafts at all — it owns no
## records, so it forwards a craft intent to the host, which is the only machine that
## can mutate a persisted inventory.
func _on_craft_requested(recipe_id: String) -> void:
	if not is_authoritative:
		GameBus.craft_intent.emit(recipe_id, "")
		return
	craft(recipe_id, local_player_id())

## A craft intent carrying a crafter. On the host this is the resolved path (the
## networking slice re-emits an inbound intent with the identity it bound to that
## connection). On a client the same signal is the OUTBOUND one — networking forwards
## it and this slice must not also resolve it locally.
func _on_craft_intent(recipe_id: String, player_id: String) -> void:
	if not is_authoritative:
		return
	craft(recipe_id, player_id if player_id != "" else local_player_id())

## The local player's id on this machine, or "" when no registry is wired (isolated
## unit tests, where the fallback inventory_slice is the only inventory anyway).
func local_player_id() -> String:
	if player_registry != null and "local_player_id" in player_registry:
		return str(player_registry.local_player_id)
	return ""

## The player a call is about: the id it was given, or THIS machine's local player
## when the caller passed "" (the default every pre-Phase-34 call site uses). The
## same rule TechnologySlice applies, so the two slices cannot disagree about who
## "me" is.
func _resolve_player(player_id: String) -> String:
	if player_id != "":
		return player_id
	return local_player_id()

## Host-local repair request (the UI or any host-side system): resolved against the
## local player's own inventory. A CLIENT does not repair at all — a repair mutates
## a persisted inventory, so it forwards an intent to the host (Phase 34).
func _on_repair_requested(item_id: String) -> void:
	if not is_authoritative:
		GameBus.repair_intent.emit(item_id, "")
		return
	repair(item_id, local_player_id())

## A repair intent carrying a repairer. On the host this is the resolved path (the
## networking slice re-emits an inbound intent with the identity it bound to that
## connection). On a client the same signal is the OUTBOUND one — networking
## forwards it and this slice must not also repair locally.
func _on_repair_intent(item_id: String, player_id: String) -> void:
	if not is_authoritative:
		return
	repair(item_id, player_id if player_id != "" else local_player_id())

## Resolve a repair attempt (or check) for `player_id` against the item's fabric
## repair spec. When `mutate` is false, only the guards + material availability are
## checked (no consumption, no durability change). When true, materials are consumed
## atomically and the item is restored — both on THAT PLAYER'S inventory.
## Reasons mirror the craft pipeline: not_repairable / no_inventory / no_item /
## already_pristine / skill_requirement:<skill>:<tier> / station_required:<type> /
## missing_inputs.
func _resolve_repair(item_id: String, mutate: bool, spec: Dictionary, player_id: String = "") -> Dictionary:
	var pid := _resolve_player(player_id)
	if spec.is_empty():
		return _repair_result(item_id, false, "not_repairable", pid)
	var inventory := inventory_for(pid)
	if inventory == null or not inventory.has_method("consume_items"):
		return _repair_result(item_id, false, "no_inventory", pid)
	if not inventory.has_method("repair_item"):
		return _repair_result(item_id, false, "no_inventory", pid)
	if inventory.get_item_count(item_id) <= 0:
		return _repair_result(item_id, false, "no_item", pid)
	if inventory.has_method("is_durable") and not inventory.is_durable(item_id):
		return _repair_result(item_id, false, "not_repairable", pid)
	# Reject a pristine item (nothing to restore). Tiers are read from the
	# inventory's condition model (fabric DURABILITY_STATES), not a hardcoded
	# "pristine" literal.
	var tiers := _condition_tiers_to_restore(item_id, inventory)
	if tiers < 0:
		return _repair_result(item_id, false, "not_repairable", pid)
	if tiers == 0:
		return _repair_result(item_id, false, "already_pristine", pid)
	var guard_reason := _check_skill_guards(spec)
	if guard_reason != "":
		return _repair_result(item_id, false, guard_reason, pid)
	var station_reason := _check_station_gate(spec)
	if station_reason != "":
		return _repair_result(item_id, false, station_reason, pid)
	# Material cost scales with the number of condition tiers restored. Durability
	# is per item key (a stack shares one value), so there is no per-unit
	# multiplier.
	var materials: Array = spec.get("materials", [])
	var scaled: Array = []
	for entry in materials:
		var mat_id: String = str(entry.get("item", ""))
		var qty: int = int(entry.get("quantity", 1)) * tiers
		scaled.append({ "item": mat_id, "quantity": qty })
	for entry in scaled:
		var mat_id: String = str(entry.get("item", ""))
		var qty: int = int(entry.get("quantity", 1))
		if inventory.get_item_count(mat_id) < qty:
			return _repair_result(item_id, false, "missing_inputs", pid)
	var counts := _to_counts(scaled)
	if mutate:
		if not inventory.consume_items(counts):
			return _repair_result(item_id, false, "missing_inputs", pid)
		if not inventory.repair_item(item_id):
			# Roll back the consumed materials so a failed repair never leaves
			# the inventory short-changed.
			_refund(counts, inventory)
			return _repair_result(item_id, false, "not_repairable", pid)
	return _repair_result(item_id, true, "", pid)

## Number of condition tiers a repair must restore to reach pristine
## (0 = already pristine). Returns -1 when the inventory cannot report condition
## tiers (no `condition_tiers_below_pristine` method). Reads the inventory the
## repair resolves against, never a fixed one.
func _condition_tiers_to_restore(item_id: String, inventory: Node) -> int:
	if inventory != null and inventory.has_method("condition_tiers_below_pristine"):
		return int(inventory.condition_tiers_below_pristine(item_id))
	return -1

## Reverse a consume: put each consumed material back. Used to roll back a
## repair whose repair_item() call failed.
func _refund(counts: Dictionary, inventory: Node) -> void:
	if inventory == null:
		return
	for item_id in counts:
		if not inventory.add_item(str(item_id), int(counts[item_id])):
			push_warning("CraftingSlice: refund of '%s' failed — inventory may be inconsistent" % item_id)

## The repair result shape. `player_id` rides along so the host knows WHOSE record
## to fold the outcome into and whose client to sync (Phase 34).
func _repair_result(item_id: String, success: bool, reason: String, player_id: String = "") -> Dictionary:
	return { "item_id": item_id, "success": success, "reason": reason, "player_id": player_id }

## Return a deep-copied structured Dictionary field (a `json` fabric field such
## as a recipe or repair spec) from a registry, or {} when the entry or field is
## absent. `json` fields are generated as Dictionaries, so there is no
## JSON-string fallback to parse; the copy is deep because both recipes and
## repair specs carry nested `materials`/`skillGuards` containers.
func _structured_field(registry: Dictionary, key: String, field: String) -> Dictionary:
	var res: Resource = registry.get(key, null)
	if res == null:
		return {}
	var v = res.get(field)
	if v is Dictionary:
		return v.duplicate(true)
	return {}

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
## The gate is asked about `player_id` (Phase 34): the technology tree is
## per-player, so "unlocked" is only ever true for the player who researched it.
func _check_tech_gate(recipe_id: String, player_id: String = "") -> String:
	if technology_slice == null or not technology_slice.has_method("is_recipe_unlocked"):
		return ""
	if technology_slice.is_recipe_unlocked(recipe_id, player_id):
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

func _result(recipe_id: String, success: bool, outputs: Array, reason: String, player_id: String = "") -> Dictionary:
	return { "recipe_id": recipe_id, "success": success, "outputs": outputs, "reason": reason, "player_id": player_id }

func _ok(recipe_id: String, outputs: Array, player_id: String = "") -> Dictionary:
	var result := _result(recipe_id, true, outputs, "", player_id)
	GameBus.craft_resolved.emit(result)
	return result

func _fail(recipe_id: String, reason: String, player_id: String = "") -> Dictionary:
	var result := _result(recipe_id, false, [], reason, player_id)
	GameBus.craft_resolved.emit(result)
	return result
