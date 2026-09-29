extends Node
## ChunkManager — streams terrain chunks around the player (Phase 17).
##
## Replaces the fixed single-chunk world with a view-distance window: every
## frame (once started) it computes the player's chunk, loads any chunk within
## the streamed radius that isn't loaded yet, and unloads chunks that fell out of
## range. Loading generates the heightmap and spawns the per-chunk creature and
## tree budgets; unloading frees the voxel mesh, despawns non-engaged creatures,
## and drops the chunk's trees.
##
## Phase 42 — the BUILD runs on a worker. Building a chunk (surface mesh + per-column
## collision) is the single most expensive thing this game does, and time-slicing it
## only spread the stall across frames instead of removing it. So a load is now two
## halves: the main thread generates the heightmap and resolves the chunk's column
## table (`VoxelSlice.collect_build_runs`, which is where the mutable slice state is
## read), and a `WorkerThreadPool` task runs the PURE build
## (`VoxelSlice.build_chunk_arrays`) and hands back plain arrays. `_process` POLLS
## the task and applies the result on the main thread — never
## `add_task` + `wait_for_task_completion` in the same frame, which is the
## synchronous build again with extra ceremony.
##
## The phase also gates the BOOT on the first ring: `build_first_ring(center)` marks
## the 9 chunks at Chebyshev 0..1 and queues them ahead of the rest, and
## `is_first_ring_ready()` / `first_ring_progress()` let the boot path hold the
## player body (and its loading screen) until the ground it will stand on EXISTS.
## `load_chunk()` still reports `chunk_loaded` when a chunk enters the streamed set
## (its build is dispatched at that point); "the mesh is there" is `_built`.
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
##   build_first_ring(center)               — arm the boot gate
##   is_first_ring_ready() -> bool
##   first_ring_progress() -> float         — 0..1, drives the loading bar

## Chunk size is owned by TerrainSlice; world_to_chunk() delegates to it.
const DEFAULT_VIEW_DISTANCE := 3       # Chebyshev radius, in chunks

## Phase 42 — the PURE chunk builder, taken as a SCRIPT, not through the wired
## `voxel_slice` node. That matters: the builder's static methods run on a worker,
## and a task that outlives the tree (a boot that quits with builds in flight) would
## otherwise call into a freed node — `Nonexistent function … in base 'previously
## freed'`, and a crash. A static call through this constant touches no node at all,
## and the lambda's captured value keeps the script resource alive for the task.
const VoxelBuilder := preload("res://src/terrain/voxel_slice.gd")

## Phase 42 — how far BEYOND the view ring a chunk is still queued and kept. The
## streamed window is `view_distance + prefetch_distance`: the load ring leads the
## player's heading, so crossing a boundary requests nothing at the moment it becomes
## needed. `view_distance` stays the radius that is guaranteed fully streamed.
const DEFAULT_PREFETCH_DISTANCE := 2

## Phase 42 — the boot gate's radius: Chebyshev 0..1 around the centre, the chunk the
## body stands in plus its eight neighbours. Wider would make the loading screen a
## long wait for ground the player cannot reach in the first second.
const FIRST_RING_RADIUS := 1

## Chunk builds to drain from the load queue each frame. Dispatching is cheap now (the
## build itself is on a worker), so this bounds how many chunks are handed out per
## frame rather than how much main-thread work is done. Overridable for tuning/tests.
const DEFAULT_LOADS_PER_FRAME := 1

## Phase 42 — how many worker builds may be in flight at once. Bounds the memory a
## burst of dispatches can hold (each task holds its heightmap + column table) and
## keeps the pool available for other work; results are applied as they complete.
const DEFAULT_MAX_BUILDS_IN_FLIGHT := 4

## Set by game_root before the slices enter the tree.
var terrain_slice: Node = null
var voxel_slice: Node = null
var player_slice: Node = null
var creature_slice: Node = null
var tree_slice: Node = null

## Chebyshev radius in chunks. Overridable (tests use a small radius).
var view_distance: int = DEFAULT_VIEW_DISTANCE

## How far beyond `view_distance` a chunk is still queued and kept (Phase 42).
var prefetch_distance: int = DEFAULT_PREFETCH_DISTANCE

## Chunk dispatches to process per _process tick (see DEFAULT_LOADS_PER_FRAME).
var loads_per_frame: int = DEFAULT_LOADS_PER_FRAME

## Worker builds allowed in flight at once (see DEFAULT_MAX_BUILDS_IN_FLIGHT).
var max_builds_in_flight: int = DEFAULT_MAX_BUILDS_IN_FLIGHT

var _loaded: Dictionary = {}   # "cx,cz" -> true
## Phase 42 — chunks whose BUILD has landed (mesh + collision attached), as opposed
## to `_loaded`, which only says the chunk was taken into the streamed set. The
## first-ring gate reads THIS: the body may stand on a built chunk, never on a queued
## one.
var _built: Dictionary = {}    # "cx,cz" -> true
var _active: bool = false
var _last_center: Vector2i = Vector2i(-9999, -9999)   # sentinel: no valid center yet

## Chunks queued for loading, ordered nearest-first to the player. Drained a
## bounded number per frame by _drain_load_queue().
var _load_queue: Array = []    # of Vector2i
## Chunks enqueued but not yet built; dedupes against _load_queue so a refresh
## pass never double-queues a chunk already waiting to load.
var _pending: Dictionary = {}  # "cx,cz" -> true

## Phase 42 — worker builds in flight, keyed by WorkerThreadPool task id:
## { chunk, key, heightmap, revision, result }. `result` is a one-slot Array the
## task writes its plain arrays into; the main thread reads it only after
## `is_task_completed()` says the task is done.
var _builds: Dictionary = {}

## Phase 42 — the boot gate. `_first_ring` maps "cx,cz" -> built?, and an EMPTY map
## means the gate was never armed (so `is_first_ring_ready()` answers true for every
## caller that has no boot to hold).
var _first_ring: Dictionary = {}
var _first_ring_center: Vector2i = Vector2i.ZERO

func _process(_delta: float) -> void:
	if not _active:
		return
	_apply_finished_builds()
	_drain_load_queue()
	refresh()

## Begin automatic streaming (driven by _process). The first `refresh()` is what
## centres the window, so the caller places the player before calling it —
## `_boot_host()` reaches it through `_boot_server()` before the spawn and then
## re-centres with a second `refresh()`, while a dedicated server simply streams
## around the player's pre-spawn position (the origin) and never moves it.
func start() -> void:
	_active = true

## Stop automatic streaming (keeps currently loaded chunks).
func stop() -> void:
	_active = false

## One streaming pass: queue missing chunks in range (nearest-first), unload
## chunks out of range. Skips the diff entirely when the player hasn't moved to
## a new chunk since the last call. Loads are NOT built here — they go onto
## _load_queue and are drained a bounded number per frame by _drain_load_queue.
##
## Phase 42 — the queue AND the kept window are `view_distance + prefetch_distance`,
## so the ring that leads the player's heading is already there when the crossing
## happens rather than being requested at that moment.
func refresh() -> void:
	var center := player_chunk()
	if center == _last_center:
		return
	_last_center = center

	var radius := stream_radius()
	var desired := _desired_chunks(center, radius)
	var wanted: Dictionary = {}
	for c in desired:
		if _in_bounds(c):
			wanted[_chunk_key(c)] = true

	# Queue loads nearest-first. Dispatching is what is bounded per frame; the build
	# itself runs on a worker.
	var to_load: Array = []
	for c in desired:
		var key := _chunk_key(c)
		if _in_bounds(c) and not _loaded.has(key) and not _pending.has(key):
			to_load.append(c)
	to_load.sort_custom(func(a, b): return _dist2(center, a) < _dist2(center, b))
	for c in to_load:
		_pending[_chunk_key(c)] = true
		_load_queue.append(c)

	# Unloads are cheap (queue_free only), so they run immediately.
	for key in _loaded.keys():
		if not wanted.has(key):
			unload_chunk(_key_to_chunk(key))

## The Chebyshev radius a chunk is queued and kept within (Phase 42).
func stream_radius() -> int:
	return view_distance + prefetch_distance

## Dispatch up to `loads_per_frame` queued chunks this frame, nearest-first, while
## respecting the in-flight build cap. The build itself runs on a worker.
func _drain_load_queue() -> void:
	var budget := loads_per_frame
	while not _load_queue.is_empty() and budget > 0:
		if _builds.size() >= max_builds_in_flight:
			return   # the pool is busy: leave the rest queued for a later frame
		var chunk: Vector2i = _load_queue.pop_front()
		_pending.erase(_chunk_key(chunk))
		if not _loaded.has(_chunk_key(chunk)):
			load_chunk(chunk)
		budget -= 1

## Take a chunk into the streamed set: spawn its per-chunk creature and tree budgets,
## announce it, and dispatch its terrain build.
##
## Phase 42 — the mesh is no longer produced here. The heightmap is generated and the
## column table resolved on this (main) thread, then `VoxelSlice.build_chunk_arrays`
## runs on a worker and `_apply_finished_builds()` attaches the result once it is
## done. `chunk_loaded` therefore means "this chunk is in the streamed set", and
## `_built` is what says its ground exists.
func load_chunk(chunk_pos: Vector2i) -> void:
	var key := _chunk_key(chunk_pos)
	if _loaded.has(key):
		return
	_loaded[key] = true
	if creature_slice != null and creature_slice.has_method("spawn_for_chunk"):
		creature_slice.spawn_for_chunk(chunk_pos)
	if tree_slice != null and tree_slice.has_method("spawn_for_chunk"):
		tree_slice.spawn_for_chunk(chunk_pos)
	GameBus.chunk_loaded.emit(chunk_pos)
	_dispatch_build(chunk_pos)

## Hand one chunk's build to a worker task. Main-thread work: the heightmap
## generation and the column-table resolution (that is where `_edits`, `_heightmaps`
## and the biome lookup are read). Worker work: the pure build, which returns plain
## arrays. The result is applied later, on the main thread, by
## `_apply_finished_builds()`.
func _dispatch_build(chunk_pos: Vector2i) -> void:
	var key := _chunk_key(chunk_pos)
	# An isolated rig (the suite wires no terrain/voxel) has nothing to build, and the
	# chunk is "built" the moment it is loaded — otherwise a gate would hang forever.
	if terrain_slice == null or voxel_slice == null \
			or not terrain_slice.has_method("generate_heightmap") \
			or not voxel_slice.has_method("build_chunk_arrays"):
		_built[key] = true
		_update_first_ring_progress()
		return
	var heightmap: Array = terrain_slice.generate_heightmap(chunk_pos)
	var runs: Dictionary = voxel_slice.collect_build_runs(chunk_pos, heightmap)
	var revision: int = int(voxel_slice.chunk_revision(chunk_pos))
	var result: Array = [null]
	var task_id := WorkerThreadPool.add_task(
		func(): result[0] = VoxelBuilder.build_chunk_arrays(chunk_pos, heightmap, runs),
		false, "chunk build %s" % key)
	_builds[task_id] = {
		"chunk":     chunk_pos,
		"key":       key,
		"heightmap": heightmap,
		"revision":  revision,
		"result":    result,
	}

## Never leave a worker build running past the tree: at shutdown a task could still
## be producing arrays for a world nobody owns (and on a `--quit` boot that is one
## frame after the dispatch). Waiting here is a bounded block — the tasks are short.
func _exit_tree() -> void:
	for task_id in _builds.keys():
		if not WorkerThreadPool.is_task_completed(task_id):
			WorkerThreadPool.wait_for_task_completion(task_id)
	_builds.clear()

## Attach every worker build that has finished, on the main thread. A result whose
## chunk was streamed back out while it built is dropped, and so is one whose revision
## has moved on (`VoxelSlice.build_chunk` refuses those itself — an edit rebuilt the
## chunk synchronously in the meantime).
func _apply_finished_builds() -> void:
	if _builds.is_empty():
		return
	for task_id in _builds.keys():
		if not WorkerThreadPool.is_task_completed(task_id):
			continue
		_apply_build_entry(task_id)

## Apply every in-flight build NOW, blocking on each task. The frame path polls
## (`_apply_finished_builds`); this is the blocking variant for a caller that has no
## frames to give — a test, or a boot that must not move on until the ground exists.
## Returns how many builds it attached.
func flush_builds() -> int:
	var applied := 0
	for task_id in _builds.keys():
		if _apply_build_entry(task_id):
			applied += 1
	return applied

## Attach one task's arrays and clear it from the in-flight table. Returns false when
## the result was dropped (the chunk streamed back out) — a drop is not a failure, it is
## the reason the table is per-frame.
##
## It WAITS on the task before doing anything with it, and that is not belt-and-braces:
## `is_task_completed` only reports that the work is done, while the pool keeps the task
## — and its result — alive until it is awaited, so a stream of polled-but-never-awaited
## builds accumulates until the pool aborts the process at shutdown (measured: exit 134
## on every boot that streamed one chunk window). On the frame path this call is
## therefore instantaneous, because the caller only reaches here for a finished task.
func _apply_build_entry(task_id: int) -> bool:
	var entry: Dictionary = _builds.get(task_id, {})
	if entry.is_empty():
		return false
	_builds.erase(task_id)
	WorkerThreadPool.wait_for_task_completion(task_id)
	if not _loaded.has(entry["key"]):
		return false   # streamed out while it built: nothing to attach it to
	var result: Array = entry["result"]
	var arrays: Dictionary = {}
	if result[0] is Dictionary:
		arrays = result[0]
	voxel_slice.build_chunk(entry["chunk"], entry["heightmap"], arrays, int(entry["revision"]))
	_built[entry["key"]] = true
	_update_first_ring_progress()
	return true

## Arm the boot gate around `center`: the 9 chunks at Chebyshev 0..1 that the body
## stands in and may immediately step onto. They are queued AHEAD of whatever the
## wider ring already queued, so the gate opens as early as it can.
func build_first_ring(center: Vector2i) -> void:
	_first_ring_center = center
	_first_ring = {}
	var wanted: Array = []
	for c in _desired_chunks(center, FIRST_RING_RADIUS):
		if not _in_bounds(c):
			continue
		var key := _chunk_key(c)
		_first_ring[key] = _built.has(key)
		if not _loaded.has(key) and not _pending.has(key):
			wanted.append(c)
	wanted.sort_custom(func(a, b): return _dist2(center, a) < _dist2(center, b))
	for i in range(wanted.size() - 1, -1, -1):
		_pending[_chunk_key(wanted[i])] = true
		_load_queue.push_front(wanted[i])

## True when every chunk of the armed first ring has been BUILT. An unarmed gate
## answers true: a caller with no boot to hold must never be blocked by it.
func is_first_ring_ready() -> bool:
	if _first_ring.is_empty():
		return true
	for key in _first_ring:
		if not _first_ring[key]:
			return false
	return true

## Fraction of the armed first ring that has been built (1.0 when unarmed).
func first_ring_progress() -> float:
	if _first_ring.is_empty():
		return 1.0
	var done := 0
	for key in _first_ring:
		if _first_ring[key]:
			done += 1
	return float(done) / float(_first_ring.size())

## How many chunks the armed first ring holds (0 when unarmed).
func first_ring_size() -> int:
	return _first_ring.size()

## Re-read the built set into the gate. Called whenever a chunk's build lands.
func _update_first_ring_progress() -> void:
	for key in _first_ring:
		if _built.has(key):
			_first_ring[key] = true

func unload_chunk(chunk_pos: Vector2i) -> void:
	var key := _chunk_key(chunk_pos)
	if not _loaded.has(key):
		return
	_loaded.erase(key)
	_built.erase(key)
	if voxel_slice != null and voxel_slice.has_method("unload_chunk"):
		voxel_slice.unload_chunk(chunk_pos)
	if creature_slice != null and creature_slice.has_method("despawn_for_chunk"):
		creature_slice.despawn_for_chunk(chunk_pos)
	if tree_slice != null and tree_slice.has_method("despawn_for_chunk"):
		tree_slice.despawn_for_chunk(chunk_pos)
	GameBus.chunk_unloaded.emit(chunk_pos)

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

## True when `chunk` is inside the finite world, or when no terrain slice is
## wired (isolated unit tests treat the world as unbounded).
func _in_bounds(chunk: Vector2i) -> bool:
	if terrain_slice != null and terrain_slice.has_method("is_chunk_in_bounds"):
		return terrain_slice.is_chunk_in_bounds(chunk)
	return true

func _chunk_key(chunk_pos: Vector2i) -> String:
	return "%d,%d" % [chunk_pos.x, chunk_pos.y]

func _key_to_chunk(key: String) -> Vector2i:
	var parts: PackedStringArray = str(key).split(",")
	return Vector2i(int(parts[0]), int(parts[1]))
