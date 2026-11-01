extends Node
## Bed slice (Phase 185) — the bed is a player's spawn point, and the host owns it.
##
## A bed is a station of the fabric's `BedSpawn.stationType`. The host records the owner's bed on the
## player record (`BedStore.set_bed`, an exact `{chunk, local}` plus the station that draws it);
## placing a second one removes the first, which drops back as an item. A bed whose station or support
## is gone is cleared and its owner told with a keyed notice.
##
## Plug contract (GameBus):
##   IN  : bed_place_intent(offset, player_id)          a peer asks to place its bed at `offset` from its body
##   OUT : bed_resolved(player_id, ok, key)              a catalog key (bed.placed, bed.lost, bed.refuse_*)
##         bed_synced(player_id, bed)                    the owner's bed `{chunk, local}`, `{}` when cleared
##
## Wiring supplies `station_slice`, `registry`, `position_of(player_id) -> {chunk, local}` (empty when the
## host does not know where the body is), `runs_at` and `now_fn` (seconds).

const WorldPos := preload("res://src/terrain/world_pos.gd")
const BedStore := preload("res://src/world/bed_store.gd")
const BedRule := preload("res://src/world/bed_rule.gd")

## A placement must be this close to the placer's body (m).
const PLACE_REACH := 6.0
## A peer may send a bed intent this often (s).
const MIN_INTERVAL := 0.5

var station_slice: Node = null
var registry: Node = null
var position_of: Callable = Callable()
var runs_at: Callable = Callable()
var now_fn: Callable = Callable()

var _last_intent: Dictionary = {}   ## player id -> seconds of the last intent
var _placing_for: String = ""       ## player id while a remote placement is emitting station_placed

func _ready() -> void:
	GameBus.bed_place_intent.connect(_on_intent)

func _exit_tree() -> void:
	if GameBus.bed_place_intent.is_connected(_on_intent):
		GameBus.bed_place_intent.disconnect(_on_intent)

func _now() -> float:
	return float(now_fn.call()) if now_fn.is_valid() else Time.get_ticks_msec() / 1000.0

func station_type() -> String:
	return str(BedRule.rules().get("stationType", ""))

func placement_item() -> String:
	return str(BedRule.rules().get("placementItem", ""))

## The player a `station_placed` of a bed belongs to right now: the remote placer while one is being
## placed, else "" (the wiring falls back to the local player).
func placing_for() -> String:
	return _placing_for

## The host's refusal key for a placement of `pid` at `offset`, or "" when it may go ahead.
func refusal(pid: String, offset: Vector3) -> String:
	var t := station_type()
	if t == "" or station_slice == null or registry == null:
		return "bed.refuse_blocked"
	var now := _now()
	if _last_intent.has(pid) and now - float(_last_intent[pid]) < MIN_INTERVAL:
		return "bed.refuse_rate"
	_last_intent[pid] = now
	if not offset.is_finite() or offset.length() > PLACE_REACH:
		return "bed.refuse_far"
	var here: Dictionary = position_of.call(pid) if position_of.is_valid() else {}
	if here.is_empty():
		return "bed.refuse_far"
	var inv: Node = registry.get_inventory(pid)
	if inv == null or int(inv.get_item_count(placement_item())) < 1:
		return "bed.refuse_no_item"
	var target := _world_target(here, offset)
	var why: String = station_slice.placement_blocker(t, station_slice.snap_to_grid(target), pid)
	if why == "not_owner":
		return "bed.refuse_structure"
	if why.begins_with("too_close_station:"):
		var other: String = BedStore.owner_of_station(registry, why.get_slice(":", 1))
		if other != "" and other != pid:
			return "bed.refuse_not_yours"
		return "bed.refuse_occupied"
	if why != "":
		return "bed.refuse_blocked"
	if runs_at.is_valid() and BedRule.blocked(station_slice.snap_to_grid(target), runs_at):
		return "bed.refuse_blocked"
	return ""

## The float world position of an exact `here` plus `offset` (only the placement's local frame is exact).
static func _world_target(here: Dictionary, offset: Vector3) -> Vector3:
	var chunk: Vector2i = here["chunk"]
	var local: Vector3 = here["local"]
	return Vector3(chunk.x * WorldPos.CHUNK_METERS + local.x, local.y, chunk.y * WorldPos.CHUNK_METERS + local.z) + offset

func _on_intent(offset: Vector3, player_id: String) -> void:
	if registry == null or not registry.is_authoritative or player_id == "":
		return
	var why := refusal(player_id, offset)
	if why != "":
		GameBus.bed_resolved.emit(player_id, false, why)
		return
	var here: Dictionary = position_of.call(player_id)
	var target: Vector3 = station_slice.snap_to_grid(_world_target(here, offset))
	var inv: Node = registry.get_inventory(player_id)
	if not inv.consume_items({ placement_item(): 1 }):
		GameBus.bed_resolved.emit(player_id, false, "bed.refuse_no_item")
		return
	_placing_for = player_id
	var id: String = station_slice.place_station(station_type(), target)
	_placing_for = ""
	if id == "":
		inv.add_item(placement_item(), 1)
		GameBus.bed_resolved.emit(player_id, false, "bed.refuse_blocked")

## Make the station `station_id` at exact `exact` the bed of `pid`. An older bed is removed and its item
## returned to the owner. Emits bed_synced and the `placed` notice.
func claim(pid: String, station_id: String, exact: Dictionary) -> void:
	if registry == null or pid == "":
		return
	var old: String = BedStore.station_of(registry, pid)
	if old != "" and old != station_id and BedStore.of(registry, pid) != null:
		_drop_station(old)
		var inv: Node = registry.get_inventory(pid)
		if inv != null:
			inv.add_item(placement_item(), 1)
	BedStore.set_bed(registry, pid, exact, station_id)
	GameBus.bed_synced.emit(pid, BedStore.of(registry, pid))
	GameBus.bed_resolved.emit(pid, true, str(BedRule.rules().get("notices", {}).get("placed", "bed.placed")))

func _drop_station(station_id: String) -> void:
	if station_slice != null and station_slice.get_station(station_id).size() > 0:
		station_slice.remove_station(station_id)

## Forget `pid`'s bed and tell the owner (`lost` notice) when `notify`.
func clear(pid: String, notify: bool = true) -> void:
	if registry == null or BedStore.of(registry, pid) == null:
		return
	BedStore.clear(registry, pid)
	GameBus.bed_synced.emit(pid, {})
	if notify:
		GameBus.bed_resolved.emit(pid, false, str(BedRule.rules().get("notices", {}).get("lost", "bed.lost")))

## A station went away: its owner's bed goes with it.
func on_station_removed(station_id: String) -> void:
	var owner: String = BedStore.owner_of_station(registry, station_id) if registry != null else ""
	if owner != "":
		clear(owner)

## A block changed: every bed whose support is now gone is cleared. `world_pos` is the edit's centre.
func on_block_changed(world_pos: Vector3) -> void:
	if registry == null or not runs_at.is_valid() or station_slice == null:
		return
	for pid in registry.get_player_ids():
		var id: String = BedStore.station_of(registry, str(pid))
		if id == "":
			continue
		var st: Dictionary = station_slice.get_station(id)
		if st.is_empty():
			continue
		var p: Vector3 = st["position"]
		if Vector2(p.x - world_pos.x, p.z - world_pos.z).length() > 2.0:
			continue
		if not supported(p, runs_at):
			clear(str(pid))

## True when a run in the bed's column holds the bed up (its top within a block of the bed's height).
static func supported(bed: Vector3, runs_at_fn: Callable) -> bool:
	for run in runs_at_fn.call(BedRule.tile_of(bed)):
		if float(run["top"]) >= bed.y - 0.6 and float(run["bottom"]) <= bed.y + 0.1:
			return true
	return false

## Every bed is gone (the world was regenerated): clear them all.
func clear_all() -> void:
	if registry == null:
		return
	for pid in registry.get_player_ids():
		clear(str(pid))
