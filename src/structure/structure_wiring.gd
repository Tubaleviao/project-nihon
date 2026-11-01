extends "res://src/core/wiring.gd"
## Structure wiring (Phase 205) — hands the host's structure index to the edit paths (voxel mine and place,
## station placement, tree felling), feeds it the clock and the weather, sweeps its wear, and tells a player
## how their `/buildas` or `/repair` went. `root` is the GameRoot that owns the slices.

const StructureSlice := preload("res://src/structure/structure_slice.gd")
const VoxelConsts := preload("res://src/terrain/voxel_consts.gd")

## Seconds between wear sweeps (the clock's hour moves once a real minute).
const TICK_SEC := 1.0

var _elapsed: float = 0.0

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
