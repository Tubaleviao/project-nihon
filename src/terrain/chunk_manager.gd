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
## Loading is time-sliced. Building a chunk (noise + surface mesh + per-column
## collision) is the single most expensive thing this game does on the main
## thread, and crossing a chunk boundary previously fired every new chunk's
## build in the same frame — a multi-millisecond stall that froze movement.
## Chunks are now queued (nearest-first) and drained a bounded number per frame,
## so the build cost is spread across several frames and never blocks the render
## loop. The `view_distance` buffer (3 chunks) gives enough lead time that a
## chunk is almost always ready before the player reaches it.
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

## Chunk builds to drain from the load queue each frame. Keeping this small
## (1–2) spreads the per-chunk mesh + collision build over several frames so no
## single frame stalls. Overridable for tuning/tests.
const DEFAULT_LOADS_PER_FRAME := 2

## Set by game_root before the slices enter the tree.
var terrain_slice: Node = null
var voxel_slice: Node = null
var player_slice: Node = null
var creature_slice: Node = null

## Chebyshev radius in chunks. Overridable (tests use a small radius).
var view_distance: int = DEFAULT_VIEW_DISTANCE

## Chunk builds to process per _process tick (see DEFAULT_LOADS_PER_FRAME).
var loads_per_frame: int = DEFAULT_LOADS_PER_FRAME

var _loaded: Dictionary = {}   # "cx,cz" -> true
var _active: bool = false
var _last_center: Vector2i = Vector2i(-9999, -9999)   # sentinel: no valid center yet

## Chunks queued for loading, ordered nearest-first to the player. Drained a
## bounded number per frame by _drain_load_queue().
var _load_queue: Array = []    # of Vector2i
## Chunks enqueued but not yet built; dedupes against _load_queue so a refresh
## pass never double-queues a chunk already waiting to load.
var _pending: Dictionary = {}  # "cx,cz" -> true

func _process(_delta: float) -> void:
	if not _active:
		return
	_drain_load_queue()
	refresh()

## Begin automatic streaming (driven by _process). Call after the player has
## been placed so the initial window is centred on the actual spawn.
func start() -> void:
	_active = true

## Stop automatic streaming (keeps currently loaded chunks).
func stop() -> void:
	_active = false

## One streaming pass: queue missing chunks in range (nearest-first), unload
## chunks out of range. Skips the diff entirely when the player hasn't moved to
## a new chunk since the last call. Loads are NOT built here — they go onto
## _load_queue and are drained a bounded number per frame by _drain_load_queue.
func refresh() -> void:
	var center := player_chunk()
	if center == _last_center:
		return
	_last_center = center

	var desired := _desired_chunks(center, view_distance)
	var wanted: Dictionary = {}
	for c in desired:
		wanted[_chunk_key(c)] = true

	# Queue loads nearest-first. Building a chunk is expensive, so spreading the
	# new-ring load across frames (instead of call_deferring them all to the same
	# frame end) is what removes the boundary-crossing freeze.
	var to_load: Array = []
	for c in desired:
		var key := _chunk_key(c)
		if not _loaded.has(key) and not _pending.has(key):
			to_load.append(c)
	to_load.sort_custom(func(a, b): return _dist2(center, a) < _dist2(center, b))
	for c in to_load:
		_pending[_chunk_key(c)] = true
		_load_queue.append(c)

	# Unloads are cheap (queue_free only), so they run immediately.
	for key in _loaded.keys():
		if not wanted.has(key):
			unload_chunk(_key_to_chunk(key))

## Build up to `loads_per_frame` queued chunks this frame, nearest-first.
func _drain_load_queue() -> void:
	var budget := loads_per_frame
	while not _load_queue.is_empty() and budget > 0:
		var chunk: Vector2i = _load_queue.pop_front()
		_pending.erase(_chunk_key(chunk))
		if not _loaded.has(_chunk_key(chunk)):
			load_chunk(chunk)
		budget -= 1

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

## Squared Chebyshev-ish distance from `center` to `chunk` — used only for
## ordering the load queue so the chunk nearest the player builds first.
func _dist2(center: Vector2i, chunk: Vector2i) -> int:
	var dx := chunk.x - center.x
	var dz := chunk.y - center.y
	return dx * dx + dz * dz

func _chunk_key(chunk_pos: Vector2i) -> String:
	return "%d,%d" % [chunk_pos.x, chunk_pos.y]

func _key_to_chunk(key: String) -> Vector2i:
	var parts: PackedStringArray = str(key).split(",")
	return Vector2i(int(parts[0]), int(parts[1]))
