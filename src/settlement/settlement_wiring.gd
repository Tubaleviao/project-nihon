extends "res://src/core/wiring.gd"
## Settlement wiring (Phase 140) — founding at a placed hearth, the host tick, and per-peer view syncs.
## `root` is the GameRoot that owns the slices.

const SettlementSlice := preload("res://src/settlement/settlement_slice.gd")
const I18n := preload("res://src/core/i18n.gd")
const WorldPos := preload("res://src/terrain/world_pos.gd")
const ProjectRules := preload("res://src/settlement/project_rules.gd")
const RaidDirector := preload("res://src/settlement/raid_director.gd")

## Seconds between host sweeps (grow, abandon, decay, activity, view pushes).
const TICK_SEC := 0.5

var _elapsed: float = 0.0
var _dirty: bool = true
var _online: Array = []
var _ui_bound: bool = false
## Phase 200 — the host raid scheduler (null on a client).
var raids: RaidDirector = null

## Build the slice and hand it the host-side guards (mine, place, station placement, research).
func make_slice(ctx: GameRoot) -> Node:
	root = ctx
	var slice := SettlementSlice.new()
	slice.registry = root._registry
	slice.position_of = self.player_xz
	slice.is_host = not root._is_client
	slice.tool_in_hand = self.tool_in_hand
	slice.place_structure = self.place_structure
	root._voxel.claim_guard = slice.edit_blocker
	if not root._is_client:
		root._voxel.claim_activity = slice.note_edit
	root._station.claim_guard = slice.edit_blocker
	slice.release_station = root._station.remove_station
	if not root._is_client:
		raids = RaidDirector.new()
		raids.slice = slice
		raids.online_ids = func() -> Array: return root._registry.get_online_player_ids()
		raids.spawn_raider = func(c: String, xz: Vector2, goal: Vector2, rid: String, n: int) -> String: return root._creature.spawn_raider(c, xz, goal, rid, n)
		raids.raiders_of = func(rid: String) -> Array: return root._creature.raiders_of(rid)
		raids.remove_raiders = func(rid: String) -> void: root._creature.remove_raiders(rid)
		raids.biome_at = func(xz: Vector2) -> String: return str(root._terrain.get_biome_at(xz)) if root._terrain != null else ""
	root._tree.claim_guard = slice.edit_blocker
	root._station.settlement_slice = slice
	root._technology.settlement_slice = slice
	return slice

## The windows are built after the slices: bind them on the first frame they exist.
func _bind_ui() -> void:
	var ui: Node = root._ui
	if _ui_bound or ui == null or ui.map_window == null or ui.settlement_panel == null:
		return
	_ui_bound = true
	ui.map_window.settlement_slice = root._settlements
	ui.settlement_slice = root._settlements
	ui.settlement_panel.settlement_slice = root._settlements

func _connect_all() -> void:
	connect_bus(GameBus.settlements_changed, _on_changed)
	connect_bus(GameBus.settlement_resolved, _on_resolved)
	connect_bus(GameBus.station_placed, _on_station_placed)
	connect_bus(GameBus.attributes_synced, _on_attributes_synced)
	connect_bus(GameBus.raid_requested, _on_raid_requested)
	connect_bus(GameBus.skill_tier_recorded, _on_skill_tier_recorded)

## Phase 200 — `/raid` (an admin, checked by the chat): start a raid on the admin's settlement now.
func _on_raid_requested(player_id: String) -> void:
	if root._is_client or raids == null:
		return
	var id: String = root._settlements.settlement_of(player_id)
	if id == "":
		GameBus.system_message.emit("chat.raid_none", [], player_id)
		return
	var why := raids.start(id, float(root._settlements.now_sec.call()), true)
	if why != "":
		GameBus.system_message.emit("settlement.raid.refused." + why, [], player_id)

## Phase 199 — the host's own records changed: recompute that player's specialty (never from a message).
func _on_attributes_synced(player_id: String, _attributes: Dictionary) -> void:
	if not root._is_client and root._settlements != null and root._settlements.settlement_of(player_id) != "":
		root._settlements.refresh_specialty(player_id)

func _on_skill_tier_recorded(player_id: String, _skill: String, _tier: String) -> void:
	_on_attributes_synced(player_id, {})

func _on_changed() -> void:
	_dirty = true

## A hearth placed by the local player (host or listen host) founds a settlement there. The placement
## already took the Hearth item and `StationSlice` refused an occupied spot, so this only records it.
func _on_station_placed(station_id: String, type: String, position: Vector3) -> void:
	if root._is_client or root._settlements == null or type != str(root._settlements.rules()["hearthStation"]):
		return
	var pid: String = root._registry.local_player_id
	# The exact hearth position: the placer's exact position plus the small offset to the hearth, never the
	# float32 `Vector3` (as the waystone does).
	var exact: Dictionary = {}
	if root._player != null:
		var here: Dictionary = root._player.get_world_pos()
		exact = WorldPos.normalized({
			"chunk": here["chunk"],
			"local": (here["local"] as Vector3) + (position - root._player.get_position()),
		})
	var why: String = root._settlements.found(pid, "", Vector2(position.x, position.z), false, exact, true)
	if why != "" and root._station != null:
		root._station.remove_station(station_id)
	elif why == "":
		root._settlements.note_hearth_station(root._settlements.settlement_of(pid), station_id)

## Tell the actor's peer how its intent went; the local player reads the bus directly.
func _on_resolved(player_id: String, action: String, ok: bool, reason: String) -> void:
	if root._is_client or player_id == "" or player_id == root._registry.local_player_id:
		return
	var peer: int = root._registry.get_peer_id(player_id)
	if peer != 0:
		root._networking.send_own_state(peer, { "settlement_result": { "action": action, "ok": ok, "reason": reason } })

## Host tick: advance lifecycle, mark activity, push views when something changed.
func tick(delta: float) -> void:
	_bind_ui()
	if root._is_client or root._settlements == null:
		return
	_elapsed += delta
	if _elapsed < TICK_SEC:
		return
	_elapsed = 0.0
	var online: Array = root._registry.get_online_player_ids()
	online.sort()
	if online != _online:   # a player who just connected has no view yet
		_online = online
		_dirty = true
	for pid: String in online:
		root._settlements.note_activity(pid)
	root._settlements.tick(float(root._settlements.now_sec.call()))
	if raids != null:
		raids.tick(float(root._settlements.now_sec.call()))
	if _dirty:
		_dirty = false
		_count_colonization()
		push_views()

## Send every online peer its own view (public claims plus its settlement's private part); the local
## player's view is applied in place.
func push_views() -> void:
	for pid: String in root._registry.get_online_player_ids():
		var view: Dictionary = root._settlements.private_view(pid)
		if pid == root._registry.local_player_id:
			root._settlements.apply_view(view)
			continue
		var peer: int = root._registry.get_peer_id(pid)
		if peer != 0 and root._networking != null and root._networking.is_host():
			root._networking.send_own_state(peer, { "settlement_view": view })

## Phase 198 — whether the player has a tool to work with: in the main hand, or in the pack (tools take no
## equipment slot; carcass harvesting reads them the same way).
func tool_in_hand(player_id: String) -> bool:
	if ProjectRules.is_tool_item(str(root._registry.get_equipment(player_id).get("MainHand", ""))):
		return true
	var inv: Node = root._inventory if player_id == root._registry.local_player_id else root._registry.get_inventory(player_id)
	if inv == null or not inv.has_method("get_contents"):
		return false
	for item: Variant in (inv.get_contents() as Dictionary):
		if ProjectRules.is_tool_item(str(item)) and inv.get_item_count(str(item)) > 0:
			return true
	return false

## Phase 198 — place a finished project's structure at `site` ({x, z} ground metres, doubles): its blocks
## through the voxel edit path (recorded like any edit and synced to peers in range as `block_changed`),
## then its stations on the ground inside it.
func place_structure(_id: String, key: String, site: Dictionary) -> void:
	var places: Dictionary = ProjectRules.def_of(key).get("places", {})
	var mat := ProjectRules.block_material(str(places.get("block", "")))
	var tile := float(root._voxel.TILE_SIZE)
	var x0 := float(site["x"])
	var z0 := float(site["z"])
	if mat != "":
		for c: Vector3i in ProjectRules.layout_cells(str(places.get("layout", "shed")), int(places.get("blocks", 0))):
			root._voxel.place_structure_block(_exact_at(x0 + (float(c.x) + 0.5) * tile, z0 + (float(c.z) + 0.5) * tile), mat)
	var stations: Array = places.get("stations", [])
	var offsets := ProjectRules.station_offsets(stations.size())
	for i in stations.size():
		var x := x0 + float(offsets[i].x) * tile
		var z := z0 + float(offsets[i].y) * tile
		root._station.place_station(str(stations[i]), Vector3(x, root._voxel.get_voxel_height_at(Vector2(x, z)), z))

static func _exact_at(x: float, z: float) -> Dictionary:
	var cx := floori(x / WorldPos.CHUNK_METERS)
	var cz := floori(z / WorldPos.CHUNK_METERS)
	return { "chunk": Vector2i(cx, cz), "local": Vector3(x - float(cx) * WorldPos.CHUNK_METERS, 0.0, z - float(cz) * WorldPos.CHUNK_METERS) }

## Where the host believes a player stands, as ground metres (null when unknown).
func player_xz(player_id: String) -> Variant:
	if player_id == root._registry.local_player_id and root._player != null:
		return SettlementSlice.xz_of_exact(root._player.get_world_pos())
	var peer: int = root._registry.get_peer_id(player_id)
	if peer != 0:
		var pos: Dictionary = root._networking.get_expected_exact(peer)
		if not pos.is_empty():
			return SettlementSlice.xz_of_exact(pos)
	return null

## Phase 140 — every settlement counts toward its region's colonization score.
func _count_colonization() -> void:
	var chunks: Array = []
	for id: String in root._settlements.ids():
		var s: Dictionary = root._settlements.get_settlement(id)
		chunks.append(Vector2i(floori(float(s["hx"]) / SettlementSlice.WorldPos.CHUNK_METERS), floori(float(s["hz"]) / SettlementSlice.WorldPos.CHUNK_METERS)))
	root._colonization.set_settlements(chunks)
