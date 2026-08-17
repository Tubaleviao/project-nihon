extends Node
## Technology slice — holds per-player research status and gates recipes behind
## the technology tree (Phase 13). Recipes stay locked until their owning
## technology is researched, making "KnowledgeIsProgression" real, not text.
##
## The fabric is the single source of truth: each technology's structured `tech`
## json field (fabric/gameplay/technology/index.js) carries recipe unlocks,
## prerequisite technologies, research duration (seconds), and the material cost
## consumed on beginResearch. Status lives here per player, seeded "locked" and
## transitioning locked -> researching -> unlocked.
##
## Plug contract (GameBus signals consumed / emitted):
##   IN  : research_requested(tech_id)
##   OUT : research_resolved(result)    { tech_id, success, reason, status }
##         technology_unlocked(tech_id)
##
## Public API:
##   begin_research(tech_id)     -> Dictionary  (validate prereqs + consume materials)
##   complete_research(tech_id)  -> Dictionary  (force-complete research now)
##   is_unlocked(tech_id)        -> bool
##   is_recipe_unlocked(recipe_id)-> bool        (recipe -> owning tech -> status)
##   get_recipe_tech(recipe_id)  -> String
##   get_status(tech_id)         -> String
##   get_statuses()              -> Dictionary
##   apply_statuses(statuses)    -> void        (persistence restore)

const STATE_LOCKED := "locked"
const STATE_RESEARCHING := "researching"
const STATE_UNLOCKED := "unlocked"

## Set by game_root so research can consume material costs from inventory.
var inventory_slice: Node = null

## Runtime technology status: tech key -> state string.
var _status: Dictionary = {}

## Research deadline per tech (ms since epoch) for auto-completion in _process.
var _research_end_at: Dictionary = {}

## Reverse index: recipe key -> owning technology key. Built once in _ready().
var _recipe_tech: Dictionary = {}

func _ready() -> void:
	for tech_key in GameData.TECHNOLOGIES:
		_status[tech_key] = STATE_LOCKED
	_build_recipe_index()
	GameBus.research_requested.connect(_on_research_requested)

func _process(_delta: float) -> void:
	_tick_research()

## Begin researching a technology: validate prerequisites (every `requires` tech
## must be unlocked) and consume the material cost. On success the status moves
## to "researching" and an auto-complete deadline is scheduled. Never throws.
func begin_research(tech_id: String) -> Dictionary:
	if not GameData.TECHNOLOGIES.has(tech_id):
		return _emit(_result(tech_id, false, "unknown_technology", ""))
	var cur := get_status(tech_id)
	if cur == STATE_UNLOCKED:
		return _emit(_result(tech_id, false, "already_unlocked", cur))
	if cur == STATE_RESEARCHING:
		return _emit(_result(tech_id, false, "already_researching", cur))

	var tech := _get_tech_data(tech_id)
	for req in tech.get("requires", []):
		if not is_unlocked(str(req)):
			return _emit(_result(tech_id, false, "prerequisite_locked:%s" % str(req), cur))

	var materials: Array = tech.get("researchMaterials", [])
	if inventory_slice == null or not inventory_slice.has_method("consume_items"):
		return _emit(_result(tech_id, false, "no_inventory", cur))

	# Availability check for a clear reason before consuming.
	for entry in materials:
		var item_id: String = str(entry.get("item", ""))
		var qty: int = int(entry.get("quantity", 1))
		if inventory_slice.get_item_count(item_id) < qty:
			return _emit(_result(tech_id, false, "missing_materials", cur))

	if not inventory_slice.consume_items(_to_counts(materials)):
		return _emit(_result(tech_id, false, "missing_materials", cur))

	_status[tech_id] = STATE_RESEARCHING
	var duration: float = float(tech.get("researchDuration", 0.0))
	if duration > 0.0:
		_research_end_at[tech_id] = Time.get_ticks_msec() + int(duration * 1000.0)
	return _emit(_result(tech_id, true, "", STATE_RESEARCHING))

## Force-complete research now (used by tests and instant research). Only valid
## from the "researching" state. Emits technology_unlocked on success.
func complete_research(tech_id: String) -> Dictionary:
	if not GameData.TECHNOLOGIES.has(tech_id):
		return _emit(_result(tech_id, false, "unknown_technology", ""))
	var cur := get_status(tech_id)
	if cur == STATE_UNLOCKED:
		return _emit(_result(tech_id, false, "already_unlocked", cur))
	if cur != STATE_RESEARCHING:
		return _emit(_result(tech_id, false, "not_researching", cur))
	_status[tech_id] = STATE_UNLOCKED
	_research_end_at.erase(tech_id)
	GameBus.technology_unlocked.emit(tech_id)
	return _emit(_result(tech_id, true, "", STATE_UNLOCKED))

func is_unlocked(tech_id: String) -> bool:
	return get_status(tech_id) == STATE_UNLOCKED

## Whether a recipe is craftable with respect to the technology tree. Fail-closed:
## a recipe that maps to no technology (or an unknown tech) returns false.
func is_recipe_unlocked(recipe_id: String) -> bool:
	var tech_id := get_recipe_tech(recipe_id)
	if tech_id == "":
		return false
	return is_unlocked(tech_id)

## Owning technology key for a recipe, or "" if unmapped.
func get_recipe_tech(recipe_id: String) -> String:
	return str(_recipe_tech.get(recipe_id, ""))

func get_status(tech_id: String) -> String:
	return str(_status.get(tech_id, STATE_LOCKED))

func get_statuses() -> Dictionary:
	return _status.duplicate()

## Return the structured `tech` json field for a technology (or {} if malformed).
## Public so the UI slice can render cost / duration / prerequisite edges.
func get_tech_data(tech_id: String) -> Dictionary:
	return _get_tech_data(tech_id)

## Restore status from a persisted snapshot (ignores unknown tech keys).
func apply_statuses(statuses: Dictionary) -> void:
	for tech_id in statuses:
		if GameData.TECHNOLOGIES.has(tech_id):
			_status[tech_id] = str(statuses[tech_id])
	_research_end_at.clear()
	# The saved snapshot carries only the status string, not the research
	# deadline. Re-schedule auto-completion for any tech restored mid-research so
	# it does not stay stuck in "researching" forever after a reload (the timer
	# restarts from now — elapsed time is not persisted).
	for tech_id in _status:
		if _status[tech_id] == STATE_RESEARCHING:
			var duration: float = float(_get_tech_data(tech_id).get("researchDuration", 0.0))
			if duration > 0.0:
				_research_end_at[tech_id] = Time.get_ticks_msec() + int(duration * 1000.0)

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _on_research_requested(tech_id: String) -> void:
	begin_research(tech_id)

## Auto-complete any research whose deadline has elapsed.
func _tick_research() -> void:
	var now := Time.get_ticks_msec()
	var completed: Array = []
	for tech_id in _research_end_at:
		if now >= int(_research_end_at[tech_id]):
			completed.append(tech_id)
	for tech_id in completed:
		complete_research(tech_id)

## Build the recipe -> technology reverse index from every technology's unlocks.
func _build_recipe_index() -> void:
	for tech_key in GameData.TECHNOLOGIES:
		var tech := _get_tech_data(tech_key)
		for recipe_id in tech.get("unlocks", []):
			_recipe_tech[str(recipe_id)] = tech_key

## Return the structured `tech` json field for a technology, or {} if malformed.
func _get_tech_data(tech_id: String) -> Dictionary:
	var res: Resource = GameData.TECHNOLOGIES.get(tech_id, null)
	if res == null:
		return {}
	var v = res.get("tech")
	if v is Dictionary:
		return v
	if v is String and v != "":
		var parsed = JSON.parse_string(v)
		if parsed is Dictionary:
			return parsed
	return {}

## Collapse a [{ item, quantity }] list into a { item: quantity } map.
func _to_counts(entries: Array) -> Dictionary:
	var counts: Dictionary = {}
	for entry in entries:
		var item_id: String = str(entry.get("item", ""))
		var qty: int = int(entry.get("quantity", 1))
		counts[item_id] = counts.get(item_id, 0) + qty
	return counts

func _result(tech_id: String, success: bool, reason: String, status: String) -> Dictionary:
	return { "tech_id": tech_id, "success": success, "reason": reason, "status": status }

func _emit(result: Dictionary) -> Dictionary:
	GameBus.research_resolved.emit(result)
	return result
