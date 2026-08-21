extends Node
## ChunkManager — streams terrain chunks around the player (Phase 17).
##
## Replaces the fixed single-chunk world with a view-distance window: every
## frame (once started) it computes the player's chunk, loads any chunk within
## `view_distance` that isn't loaded yet, and unloads chunks that fell out of
## range. Loading requests the heightmap from TerrainSlice (VoxelSlice builds the
## mesh on chunk_ready) and spawns the per-chunk creature budget; unloading frees
## the voxel mesh and despawns non-engaged creatures.
##
## Plug contract (GameBus signals emitted):
##   OUT : chunk_loaded(chunk_pos), chunk_unloaded(chunk_pos)
##
## Public API:
##   start() / stop()                       — enable/disable automatic streaming
##   refresh()                              — run one synchronous load/unload pass
##   player_chunk() -> Vector2i             — chunk under the player
##   load_chunk(pos) / unload_chunk(pos)    — explicit load/unload
##   get_loaded_chunks() -> Array           — [{ chunk, biome }, ...]

## Chunk size is owned by TerrainSlice; world_to_chunk() delegates to it.
const DEFAULT_VIEW_DISTANCE := 3       # Chebyshev radius, in chunks

## Set by game_root before the slices enter the tree.
var terrain_slice: Node = null
var voxel_slice: Node = null
var player_slice: Node = null
var creature_slice: Node = null

## Chebyshev radius in chunks. Overridable (tests use a small radius).
var view_distance: int = DEFAULT_VIEW_DISTANCE

var _loaded: Dictionary = {}   # "cx,cz" -> true
var _active: bool = false
var _last_center: Vector2i = Vector2i(-9999, -9999)   # sentinel: no valid center yet

func _process(_delta: float) -> void:
	if not _active:
		return
	refresh()

## Begin automatic streaming (driven by _process). Call after the player has
## been placed so the initial window is centred on the actual spawn.
func start() -> void:
	_active = true

## Stop automatic streaming (keeps currently loaded chunks).
func stop() -> void:
	_active = false

## One streaming pass: load missing chunks in range, unload chunks out of range.
## Skips the diff entirely when the player hasn't moved to a new chunk since the
## last call. Each load/unload is deferred to the end of the frame so the loop
## doesn't block rendering.
func refresh() -> void:
	var center := player_chunk()
	if center == _last_center:
		return
	_last_center = center

	var desired := _desired_chunks(center, view_distance)
	var wanted: Dictionary = {}
	for c in desired:
		wanted[_chunk_key(c)] = true
	for key in wanted:
		if not _loaded.has(key):
			call_deferred("load_chunk", _key_to_chunk(key))
	for key in _loaded.keys():
		if not wanted.has(key):
			call_deferred("unload_chunk", _key_to_chunk(key))

func load_chunk(chunk_pos: Vector2i) -> void:
	var key := _chunk_key(chunk_pos)
	if _loaded.has(key):
		return
	_loaded[key] = true
	if terrain_slice != null and terrain_slice.has_method("request_chunk"):
		terrain_slice.request_chunk(chunk_pos)
	if creature_slice != null and creature_slice.has_method("spawn_for_chunk"):
		creature_slice.spawn_for_chunk(chunk_pos)
	GameBus.chunk_loaded.emit(chunk_pos)
	print("ChunkManager: loaded chunk %s" % chunk_pos)

func unload_chunk(chunk_pos: Vector2i) -> void:
	var key := _chunk_key(chunk_pos)
	if not _loaded.has(key):
		return
	_loaded.erase(key)
	if voxel_slice != null and voxel_slice.has_method("unload_chunk"):
		voxel_slice.unload_chunk(chunk_pos)
	if creature_slice != null and creature_slice.has_method("despawn_for_chunk"):
		creature_slice.despawn_for_chunk(chunk_pos)
	GameBus.chunk_unloaded.emit(chunk_pos)
	print("ChunkManager: unloaded chunk %s" % chunk_pos)

## Chunk coordinate under the player's current XZ position.
func player_chunk() -> Vector2i:
	if player_slice != null and player_slice.has_method("get_position"):
		var p: Vector3 = player_slice.get_position()
		return world_to_chunk(Vector2(p.x, p.z))
	return Vector2i.ZERO

func world_to_chunk(world_pos: Vector2) -> Vector2i:
	if terrain_slice != null and terrain_slice.has_method("world_to_chunk"):
		return terrain_slice.world_to_chunk(world_pos)
	return Vector2i(floori(world_pos.x / 32), floori(world_pos.y / 32))

## Loaded chunks with their biome, for the minimap and introspection.
func get_loaded_chunks() -> Array:
	var out: Array = []
	for key in _loaded:
		var pos := _key_to_chunk(key)
		var biome := ""
		if terrain_slice != null and terrain_slice.has_method("get_biome_at_chunk"):
			biome = str(terrain_slice.get_biome_at_chunk(pos))
		out.append({ "chunk": pos, "biome": biome })
	return out

## The set of chunk coordinates within Chebyshev distance `radius` of `center`.
func _desired_chunks(center: Vector2i, radius: int) -> Array:
	var out: Array = []
	for dx in range(-radius, radius + 1):
		for dz in range(-radius, radius + 1):
			out.append(center + Vector2i(dx, dz))
	return out

func _chunk_key(chunk_pos: Vector2i) -> String:
	return "%d,%d" % [chunk_pos.x, chunk_pos.y]

func _key_to_chunk(key: String) -> Vector2i:
	var parts: PackedStringArray = str(key).split(",")
	return Vector2i(int(parts[0]), int(parts[1]))
