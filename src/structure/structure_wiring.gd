extends "res://src/core/wiring.gd"
## Structure wiring (Phase 205) — hands the host's structure index to the edit paths (voxel mine and place,
## station placement, tree felling), feeds it the clock and the weather, sweeps its wear, and tells a player
## how their `/buildas` or `/repair` went. `root` is the GameRoot that owns the slices.

const StructureSlice := preload("res://src/structure/structure_slice.gd")
const VoxelConsts := preload("res://src/terrain/voxel_consts.gd")

## Seconds between wear sweeps (the clock's hour moves once a real minute).
const TICK_SEC := 1.0

## Phase 206 — metres round a player whose foreign clan circles their client is sent (station placement asks
## within a few metres; the margin covers a second of walking between sends).
const VIEW_REACH_M := 64.0

var _elapsed: float = 0.0
## Host: pid -> the circle view last sent to that peer (sent again only when it changes).
var _sent_views: Dictionary = {}
## Client: the host's last circle view, `[[x, z, radius], ...]` ground metres.
var _circle_view: Array = []

func make_slice(ctx: GameRoot) -> Node:
	root = ctx
	var slice := StructureSlice.new()
	slice.registry = root._registry
	slice.clans = root._clans
	slice.is_host = not root._is_client
	slice.now_hour = self.now_hour
	slice.weather_at = self.weather_at
	slice.remove_block = root._voxel.remove_structure_block
	if not root._is_client:
		root._voxel.structures = slice
		root._station.structure_guard = slice.build_blocker
		root._tree.structure_guard = slice.edit_blocker
		root._creature.spawn_blocked = slice.spawn_blocked
		root._settlements.build_blocked = func(pid: String, xz: Vector2) -> bool: return slice.foreign_circle_at(pid, xz) != 0
	else:
		# A client holds no index: its placement ghost reads the circles the host sent it.
		root._station.structure_guard = self.view_blocker
	return slice

func _connect_all() -> void:
	connect_bus(GameBus.structure_resolved, _on_resolved)

## The clock's in-game hour, which weather is rolled by.
func now_hour() -> int:
	return root._weather.current_hour() if root._weather != null else 0

## The weather state over `tile` at in-game `hour`.
func weather_at(tile: Vector2i, hour: int) -> String:
	if root._weather == null:
		return "clear"
	return root._weather.weather_at(Vector2i(floori(float(tile.x) / VoxelConsts.CHUNK_SIZE), floori(float(tile.y) / VoxelConsts.CHUNK_SIZE)), hour)

## How a `/buildas` or `/repair` went, as a keyed line to the actor alone (host or peer).
func _on_resolved(player_id: String, action: String, ok: bool, reason: String) -> void:
	if root._is_client or player_id == "":
		return
	var key := ("structure.ok.%s" % action) if ok else ("structure.refused.%s" % reason)
	if ok and action == "build_as":
		key += "." + str(root._structures.build_mode(player_id))
	GameBus.system_message.emit(key, [], player_id)

func tick(delta: float) -> void:
	if root._is_client or root._structures == null:
		return
	_elapsed += delta
	if _elapsed < TICK_SEC:
		return
	_elapsed = 0.0
	root._structures.tick()
	push_circle_views()

## Host: send every remote online player the foreign clan circles near them, when that set changed.
func push_circle_views() -> void:
	if root._networking == null or not root._networking.is_host():
		return
	var online: Dictionary = {}
	for pid: String in root._registry.get_online_player_ids():
		online[pid] = true
		var peer: int = root._registry.get_peer_id(pid)
		if pid == root._registry.local_player_id or peer == 0:
			continue
		var xz: Variant = root._settlement_wiring.player_xz(pid)
		if not (xz is Vector2):
			continue
		var view: Array = root._structures.foreign_circles_near(pid, xz, VIEW_REACH_M)
		if view != _sent_views.get(pid, []):
			_sent_views[pid] = view
			root._networking.send_own_state(peer, { "circle_view": view })
	for pid: String in _sent_views.keys():
		if not online.has(pid):
			_sent_views.erase(pid)

## Client: adopt the host's circle view. Only well-formed, finite entries are kept, at most the host's cap.
func apply_circle_view(data: Dictionary) -> void:
	if not (data.get("circle_view", null) is Array):
		return
	_circle_view.clear()
	for e: Variant in (data["circle_view"] as Array).slice(0, StructureSlice.MAX_VIEW_CIRCLES):
		if e is Array and (e as Array).size() == 3 and (e as Array).all(func(v: Variant) -> bool: return (v is float or v is int) and is_finite(float(v))):
			_circle_view.append([float(e[0]), float(e[1]), float(e[2])])

## Client `structure_guard`: "foreign_circle" when `pos` lies in a circle the host says the player may not
## build in. A hint for the ghost only: the host decides the placement.
func view_blocker(_player_id: String, pos: Vector3) -> String:
	for c: Array in _circle_view:
		if StructureSlice.circle_holds(Vector2(c[0], c[1]), c[2], Vector2(pos.x, pos.z)):
			return "foreign_circle"
	return ""
