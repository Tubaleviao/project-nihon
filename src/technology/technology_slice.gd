extends Node
## Technology slice — holds PER-PLAYER research status and gates recipes behind
## the technology tree (Phase 13; per-player since Phase 34). Recipes stay locked
## until their owning technology is researched, making "KnowledgeIsProgression"
## real, not text.
##
## The fabric is the single source of truth: each technology's structured `tech`
## json field (fabric/gameplay/technology/index.js) carries recipe unlocks,
## prerequisite technologies, research duration (seconds), and the material cost
## consumed on beginResearch. Status lives here per player, seeded "locked" and
## transitioning locked -> researching -> unlocked.
##
## Why per-player (Phase 34): one process-wide status dictionary made a single
## client's research unlock the technology for EVERY player on the host, and the
## material cost came off the host's own inventory — a peer could spend the host's
## materials and hand the whole server a free technology tree. Status is now keyed
## on the server-issued player_id (the same key the record and the inventory use),
## and materials are consumed from `inventory_for(player_id)`.
##
## Plug contract (GameBus signals consumed / emitted):
##   IN  : research_requested(tech_id)
##         research_intent(tech_id, player_id)    — Phase 34: who is researching
##   OUT : research_resolved(result)    { tech_id, success, reason, status, player_id }
##         technology_unlocked(tech_id, player_id)
##         research_intent(tech_id, "")           — client forwards to the host
##
## Public API (every call takes an optional `player_id`; "" means THIS machine's
## local player — see `resolve_player`):
##   begin_research(tech_id, player_id := "")     -> Dictionary  (validate + consume)
##   complete_research(tech_id, player_id := "")  -> Dictionary  (force-complete)
##   is_unlocked(tech_id, player_id := "")        -> bool
##   is_recipe_unlocked(recipe_id, player_id := "") -> bool
##   get_recipe_tech(recipe_id)                   -> String
##   get_status(tech_id, player_id := "")         -> String
##   get_statuses(player_id := "")                -> Dictionary
##   apply_statuses(statuses, player_id := "")    -> void   (persistence restore)
##   inventory_for(player_id)                     -> Node

const STATE_LOCKED := "locked"
const STATE_RESEARCHING := "researching"
const STATE_UNLOCKED := "unlocked"

## Set by game_root so research can consume material costs from inventory. The
## fallback inventory when no per-player registry is wired (isolated unit tests)
## or when no player id resolves.
var inventory_slice: Node = null

## Set by game_root: the PlayerRegistry, which owns one inventory per player.
## When wired, `inventory_for(player_id)` resolves the researcher's own inventory.
var player_registry: Node = null

## Authority mode: true on the host / single-player (this slice resolves the
## research), false on a client (it forwards the intent to the host, which is the
## only machine that owns the player records and their inventories).
var is_authoritative: bool = true

## player_id -> { tech key -> state string }. Created lazily per player.
var _status: Dictionary = {}

## player_id -> { tech key -> wall-clock deadline (Unix seconds) } for
## auto-completion in _process.
var _research_end_at: Dictionary = {}

## Reverse index: recipe key -> owning technology key. Built once in _ready().
var _recipe_tech: Dictionary = {}

func _ready() -> void:
	_build_recipe_index()
	GameBus.research_requested.connect(_on_research_requested)
	GameBus.research_intent.connect(_on_research_intent)

func _process(_delta: float) -> void:
	_tick_research()

# ---------------------------------------------------------------------------
# Player resolution
# ---------------------------------------------------------------------------

## The player a call is about: the id it was given, or THIS machine's local player
## when the caller passed "" (the default every existing call site uses). On a
## client — and in an isolated unit test with no registry — the local id is "" and
## that single bucket IS the machine's own player.
func resolve_player(player_id: String) -> String:
	if player_id != "":
		return player_id
	return local_player_id()

## The local player's id on this machine, or "" when no registry is wired.
func local_player_id() -> String:
	if player_registry != null and "local_player_id" in player_registry:
		return str(player_registry.local_player_id)
	return ""

## The inventory a research by `player_id` resolves against: that player's own
## inventory from the registry when one is wired, else the slice's fallback.
func inventory_for(player_id: String) -> Node:
	if player_id != "" and player_registry != null and player_registry.has_method("get_inventory"):
		return player_registry.get_inventory(player_id)
	return inventory_slice

## The status dictionary for `player_id`, seeded "locked" for every technology the
## fabric knows. Lazy: a player who has never researched costs nothing until
## something asks for their status.
func _status_for(player_id: String) -> Dictionary:
	if not _status.has(player_id):
		var seeded: Dictionary = {}
		for tech_key in GameData.TECHNOLOGIES:
			seeded[tech_key] = STATE_LOCKED
		_status[player_id] = seeded
	return _status[player_id]

## The wall-clock deadlines for `player_id`, created on first use.
func _deadlines_for(player_id: String) -> Dictionary:
	if not _research_end_at.has(player_id):
		_research_end_at[player_id] = {}
	return _research_end_at[player_id]

# ---------------------------------------------------------------------------
# Research
# ---------------------------------------------------------------------------

## Begin researching a technology for `player_id`: validate prerequisites (every
## `requires` tech must be unlocked FOR THAT PLAYER) and consume the material cost
## from that player's own inventory. On success the status moves to "researching"
## and an auto-complete deadline is scheduled. Never throws.
func begin_research(tech_id: String, player_id: String = "") -> Dictionary:
	var pid := resolve_player(player_id)
	if not GameData.TECHNOLOGIES.has(tech_id):
		return _emit(_result(tech_id, false, "unknown_technology", "", pid))
	var cur := get_status(tech_id, pid)
	if cur == STATE_UNLOCKED:
		return _emit(_result(tech_id, false, "already_unlocked", cur, pid))
	if cur == STATE_RESEARCHING:
		return _emit(_result(tech_id, false, "already_researching", cur, pid))

	var tech := _get_tech_data(tech_id)
	for req in tech.get("requires", []):
		if not is_unlocked(str(req), pid):
			return _emit(_result(tech_id, false, "prerequisite_locked:%s" % str(req), cur, pid))

	var materials: Array = tech.get("researchMaterials", [])
	var inventory := inventory_for(pid)
	if inventory == null or not inventory.has_method("consume_items"):
		return _emit(_result(tech_id, false, "no_inventory", cur, pid))

	# Availability check for a clear reason before consuming.
	for entry in materials:
		var item_id: String = str(entry.get("item", ""))
		var qty: int = int(entry.get("quantity", 1))
		if inventory.get_item_count(item_id) < qty:
			return _emit(_result(tech_id, false, "missing_materials", cur, pid))

	if not inventory.consume_items(_to_counts(materials)):
		return _emit(_result(tech_id, false, "missing_materials", cur, pid))

	_status_for(pid)[tech_id] = STATE_RESEARCHING
	var duration: float = float(tech.get("researchDuration", 0.0))
	if duration > 0.0:
		# Wall-clock seconds, not `Time.get_ticks_msec()`: the deadline is compared
		# against a Unix epoch like every other deadline in the project (Phase 24
		# market listings, Phase 31 trees, Phase 33 respawns). A process-uptime
		# deadline is only meaningful inside the process that scheduled it, which
		# is exactly the kind of value that breaks the moment anything persists it.
		_deadlines_for(pid)[tech_id] = Time.get_unix_time_from_system() + duration
	return _emit(_result(tech_id, true, "", STATE_RESEARCHING, pid))

## Force-complete research now (used by tests and instant research). Only valid
## from the "researching" state. Emits technology_unlocked on success.
func complete_research(tech_id: String, player_id: String = "") -> Dictionary:
	var pid := resolve_player(player_id)
	if not GameData.TECHNOLOGIES.has(tech_id):
		return _emit(_result(tech_id, false, "unknown_technology", "", pid))
	var cur := get_status(tech_id, pid)
	if cur == STATE_UNLOCKED:
		return _emit(_result(tech_id, false, "already_unlocked", cur, pid))
	if cur != STATE_RESEARCHING:
		return _emit(_result(tech_id, false, "not_researching", cur, pid))
	_status_for(pid)[tech_id] = STATE_UNLOCKED
	if _research_end_at.has(pid):
		_research_end_at[pid].erase(tech_id)
	GameBus.technology_unlocked.emit(tech_id, pid)
	return _emit(_result(tech_id, true, "", STATE_UNLOCKED, pid))

func is_unlocked(tech_id: String, player_id: String = "") -> bool:
	return get_status(tech_id, player_id) == STATE_UNLOCKED

## Whether a recipe is craftable FOR THIS PLAYER with respect to the technology
## tree. Fail-closed: a recipe that maps to no technology (or an unknown tech)
## returns false.
func is_recipe_unlocked(recipe_id: String, player_id: String = "") -> bool:
	var tech_id := get_recipe_tech(recipe_id)
	if tech_id == "":
		return false
	return is_unlocked(tech_id, player_id)

## Owning technology key for a recipe, or "" if unmapped. Fabric-derived, so it is
## the same for every player.
func get_recipe_tech(recipe_id: String) -> String:
	return str(_recipe_tech.get(recipe_id, ""))

func get_status(tech_id: String, player_id: String = "") -> String:
	return str(_status_for(resolve_player(player_id)).get(tech_id, STATE_LOCKED))

func get_statuses(player_id: String = "") -> Dictionary:
	return _status_for(resolve_player(player_id)).duplicate()

## Return the structured `tech` json field for a technology (or {} if malformed).
## Public so the UI slice can render cost / duration / prerequisite edges.
func get_tech_data(tech_id: String) -> Dictionary:
	return _get_tech_data(tech_id)

## Restore one player's status from a persisted snapshot (ignores unknown tech
## keys). The saved snapshot carries only the status string, not the research
## deadline, so a tech restored mid-research has its timer restarted from now.
func apply_statuses(statuses: Dictionary, player_id: String = "") -> void:
	var pid := resolve_player(player_id)
	var bucket := _status_for(pid)
	for tech_id in statuses:
		if GameData.TECHNOLOGIES.has(tech_id):
			bucket[tech_id] = str(statuses[tech_id])
	_research_end_at[pid] = {}
	# Re-schedule auto-completion for any tech restored mid-research so it does not
	# stay stuck in "researching" forever after a reload (elapsed time is not
	# persisted).
	for tech_id in bucket:
		if bucket[tech_id] == STATE_RESEARCHING:
			var duration: float = float(_get_tech_data(tech_id).get("researchDuration", 0.0))
			if duration > 0.0:
				_deadlines_for(pid)[tech_id] = Time.get_unix_time_from_system() + duration

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

## Host-local research request (the UI or any host-side system): resolved against
## the local player's own inventory. A CLIENT does not resolve research at all — it
## owns no records, so it forwards an intent to the host, which is the only machine
## that can mutate a player's persisted tree.
func _on_research_requested(tech_id: String) -> void:
	if not is_authoritative:
		GameBus.research_intent.emit(tech_id, "")
		return
	begin_research(tech_id, local_player_id())

## A research intent carrying a researcher. On the host this is the resolved path
## (the networking slice re-emits an inbound intent with the identity it bound to
## that connection). On a client the same signal is the OUTBOUND one — networking
## forwards it and this slice must not also resolve it locally.
func _on_research_intent(tech_id: String, player_id: String) -> void:
	if not is_authoritative:
		return
	begin_research(tech_id, player_id if player_id != "" else local_player_id())

## Auto-complete any research whose deadline has elapsed. Deadlines are wall-clock
## Unix seconds, so they are compared against the same clock they were set from.
##
## A CLIENT does not tick at all. `apply_statuses` re-arms a deadline for any status
## restored mid-research (see above), and on a client that timer must not fire: the
## host owns completion and pushes the finished status back through
## `own_state_synced`. Without this guard the client unlocks the technology on its own
## clock — a status the host never granted, and the "a client never resolves a repair
## or research locally" rule broken.
func _tick_research() -> void:
	if not is_authoritative:
		return
	var now := Time.get_unix_time_from_system()
	var due: Array = []
	for pid in _research_end_at:
		for tech_id in _research_end_at[pid]:
			if now >= float(_research_end_at[pid][tech_id]):
				due.append([str(pid), str(tech_id)])
	for entry in due:
		complete_research(str(entry[1]), str(entry[0]))

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

func _result(tech_id: String, success: bool, reason: String, status: String, player_id: String) -> Dictionary:
	return { "tech_id": tech_id, "success": success, "reason": reason, "status": status, "player_id": player_id }

func _emit(result: Dictionary) -> Dictionary:
	GameBus.research_resolved.emit(result)
	return result
