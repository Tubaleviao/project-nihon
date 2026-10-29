extends RefCounted
## Methods moved verbatim out of `chunk_manager.gd` (Phase 154). `sl` is the owning slice; each moved method keeps a forwarder there.

## A worker task must not hold a Node, so the lambda below names the script constant, not `sl`.
const VoxelBuilder := preload("res://src/terrain/voxel_slice.gd")
const VoxelMesh := preload("res://src/terrain/voxel_mesh.gd")
const VoxelCoarse := preload("res://src/terrain/voxel_coarse.gd")
const TerrainSliceScript := preload("res://src/terrain/terrain_slice.gd")
const SeamWrapScript := preload("res://src/terrain/seam_wrap.gd")

var sl: Node

func _init(slice: Node) -> void:
	sl = slice

## One streaming pass: queue missing chunks in range (nearest-first), unload
## chunks out of range. Skips the diff entirely when the player hasn't moved to
## a new chunk since the last call. Loads are NOT built here — they go onto
## _load_queue and are drained a bounded number per frame by _drain_load_queue.
##
## Phase 42 review pass 8 — the KEPT window and the LOAD window are two different radii.
## The load queue spans `stream_radius()` (`view_distance + prefetch_distance`) so the ring
## that leads the player's heading is ALREADY queued when the crossing happens, and the KEPT
## window was narrowed to `view_distance`: what a crossing retains — a resident mesh, its
## trimesh, its creatures and its trees — was the view ring, not the prefetch band, which
## put 49 resident chunks (7×7) where `stream_radius()` had kept 121 (11×11).
##
## **(NINTH review pass: that narrowing locked a WASTE in, and it is reverted. Everything in
## the load queue is BUILT, so a band chunk was built on the worker and then released on the
## next crossing unless the player happened to move toward it — the row measured 65 redundant
## worker builds per crossing, forever. The kept window is the QUEUE window again
## (`stream_radius()`), so nothing is ever unloaded while it still lies inside the radius it
## was queued at, which is also what `_test_chunk_kept_window_is_stream_radius` now asserts.
## The memory pass 8 was protecting is bounded by the radius instead of by a second window:
## `DEFAULT_PREFETCH_DISTANCE` is 1, so the resident set is 81 chunks (9×9) — the 49-chunk
## view ring plus a one-chunk lead — rather than 121.)**
func refresh(unload_now: bool = true) -> void:
	var center = sl.player_chunk()
	var centers = sl._centers_around(center)
	var window_moved = centers != sl._last_centers
	# Phase 194 (#512) — a queue sorted for a fast flyer's lane is re-sorted by distance once it slows: the lane
	# order put the ground beside and behind a body that has stopped after the whole lane ahead of it.
	if sl._queue_in_lane and not sl.is_moving_fast():
		sl._queue_in_lane = false
		resort_queue(centers)
	# Phase 42 review pass 4 — ONE `window_moved` decision, not two consecutive blocks.
	# The sentinel update and the load/unload diff are the SAME pass; the early return
	# below is what the second block's `if` was really expressing.
	if not window_moved:
		# Nothing to queue or unload — but the self-heal still runs, and it must: a
		# STATIONARY player (a dedicated server's whole shape) is exactly the case a
		# groundless chunk needs re-arming in. See `_self_heal_failed`.
		sl._self_heal_failed(centers, false)
		sl._retry_stranded_regions()
		sl._retry_deferred_records()
		return

	var heading := Vector2.ZERO
	var local_moved: bool = sl._last_centers.is_empty() or sl._last_centers[0] != centers[0]
	if not sl._last_centers.is_empty():
		heading = sl.heading_between(sl._last_centers[0], centers[0], sl.stream_radius())
		if heading != Vector2.ZERO:
			sl.note_local_crossing()
	sl._last_centers = centers
	# ONE radius for WANTED and DESIRED on purpose (ninth review pass): `wanted` — what a
	# crossing retains — is the same radius the queue spans, so no chunk that was queued (and
	# therefore built) is released while it is still inside the window it was built for. See
	# the docstring above for why the two radii were briefly different and why that was a waste.
	var radius = sl.stream_radius()
	var desired: Array = []
	# Phase 163 — counted on the canonical chunk first and keyed once per distinct chunk: crowded
	# windows overlap, and a string key per (window, chunk) was most of a crossing's refresh.
	var counts: Dictionary = {}   # canonical Vector2i -> windows covering it
	var circumference: int = TerrainSliceScript.circumference_chunks()
	for win_center in centers:
		for c in sl._desired_chunks(win_center, radius):
			var canon := Vector2i(SeamWrapScript.wrap_i(c.x, circumference), c.y)
			if not counts.has(canon):
				desired.append(c)
				counts[canon] = 0
			counts[canon] += 1
	var refs: Dictionary = {}
	var desired_keys: Array = []
	for c in desired:
		var canon := Vector2i(SeamWrapScript.wrap_i(c.x, circumference), c.y)
		var ckey := "%d,%d" % [canon.x, canon.y]
		refs[ckey] = counts[canon]
		desired_keys.append(ckey)
	sl._chunk_refs = refs
	# Phase 52 — the edits of every region the windows touch are resident BEFORE a chunk is
	# queued, so no build reads a log that is missing its region.
	if sl.region_streamer != null:
		sl._sync_wanted_regions(desired)

	# Queue loads nearest-first. Dispatching is what is bounded per frame; the build
	# itself runs on a worker.
	# Phase 163 — decorated with the distance once per chunk, not twice per comparison.
	# Phase 187 — when the LOCAL player crossed, the WHOLE queue is re-sorted, not only the new chunks:
	# appended behind what earlier crossings queued, the chunk under a fast player waited behind ground it
	# had already passed. The key also favours the heading (`queue_priority`), so the ring being flown into
	# builds first. A peer-only move keeps the old append: re-ranking a crowd's queue against every centre
	# on each peer crossing cost the host tick (crowd stress, pole pattern: tick p95 7 ms → 40–53 ms).
	var to_load: Array = []
	var lane: bool = local_moved and sl.is_moving_fast()
	for i in desired.size():
		var key: String = desired_keys[i]
		if not sl._loaded.has(key) and not sl._pending.has(key):
			sl._pending[key] = true
			if local_moved:
				sl._load_queue.append(desired[i])
			else:
				to_load.append([sl._nearest_dist2(centers, desired[i]), desired[i]])
	if local_moved:
		for c in sl._load_queue:
			# Phase 191: a chunk the window has left is dropped here, not skipped one by one at the drain (a fast flyer
			# leaves a column behind per crossing, and the dead entries piled up ahead of the ground it needs).
			if refs.has(sl._chunk_key(c)):
				to_load.append([sl.queue_priority(centers, heading, c, lane), c])
			else:
				sl._pending.erase(sl._chunk_key(c))
		sl._load_queue.clear()
	to_load.sort_custom(func(a, b): return a[0] < b[0])
	for entry in to_load:
		sl._load_queue.append(entry[1])
	if local_moved:
		sl._queue_in_lane = lane

	# Phase 49 — a synchronous `refresh()` unloads everything now; the `_process` path
	# (`unload_now == false`) queues the stale chunks and `_drain_unload_queue` releases a
	# bounded number per frame.
	if unload_now:
		for key in sl._loaded.keys():
			if not sl._chunk_refs.has(key):
				sl.unload_chunk(sl._key_to_chunk(key))
		sl._unload_queue.clear()
	else:
		# Farthest first. The distance is computed once per stale chunk (decorate, sort,
		# undecorate) rather than twice per comparison, which parsed two keys per compare.
		var stale: Array = []
		for key in sl._loaded.keys():
			if not sl._chunk_refs.has(key):
				stale.append([sl._nearest_dist2(centers, sl._key_to_chunk(key)), key])
		stale.sort_custom(func(a, b): return a[0] > b[0])
		sl._unload_queue.clear()
		for entry in stale:
			sl._unload_queue.append(entry[1])

	sl._self_heal_failed(centers, true)

## Phase 194 — worker tasks in flight: `_builds` less the cache hits waiting to attach (negative ids).
func worker_builds() -> int:
	var n := 0
	for task_id in sl._builds:
		if task_id >= 0:
			n += 1
	return n

## Chebyshev distance from `chunk` to the nearest of `centers`. Pure.
static func nearest_ring(centers: Array, chunk: Vector2i) -> int:
	var best := 1 << 30
	for c: Vector2i in centers:
		best = mini(best, maxi(absi(chunk.x - c.x), absi(chunk.y - c.y)))
	return best

## Phase 194 — the load queue sorted by distance from the nearest of `centers` (no heading, no lane).
func resort_queue(centers: Array) -> void:
	var keyed: Array = []
	for c in sl._load_queue:
		keyed.append([sl.queue_priority(centers, Vector2.ZERO, c), c])
	keyed.sort_custom(func(a, b): return a[0] < b[0])
	sl._load_queue = keyed.map(func(k): return k[1])

func drain_load_queue() -> void:
	# Phase 42 review pass 4 — a drain with NOTHING queued has nothing to dispatch, so it
	# does not resolve the window at all. `_process` calls this every tick, and the read
	# below is a `PlayerSlice.get_position()` call; the empty case is the common one
	# (a settled window drains nothing until the player crosses a chunk boundary).
	if sl._load_queue.is_empty() and sl._rebuild_queue.is_empty():
		if sl._catchup and sl._builds.is_empty():
			sl._catchup = false   # the folded window is rebuilt: back to the steady cap
		return
	# Phase 191 — a fast flyer needs a column of new chunks per crossing: at one dispatch a frame a slow machine's
	# frame rate caps the stream below the crossing rate, so it gets the catch-up burst too.
	var budget: int = maxi(sl.loads_per_frame, sl.catchup_loads_per_frame) if sl._catchup or sl.is_moving_fast() else sl.loads_per_frame
	# Phase 42 review pass 3 — the streamed window is resolved ONCE for the whole drain. The
	# player's chunk cannot move during it (the position is re-read at the next frame's
	# `refresh()`), and the per-chunk form re-derived it — a slice call — for every
	# candidate, so a drain of a full view ring paid ~49 of them to reach the same answer.
	var centers: Array = sl.window_centers()
	var radius: int = sl.stream_radius()
	var waiting := 0
	while budget > 0:
		if sl._pump_exhausted():
			return   # the frame's main-thread budget is spent: the rest waits for the next one
		if worker_builds() >= sl.build_cap():
			return   # the pool is busy: leave the rest queued for a later frame
		if not sl._rebuild_queue.is_empty():
			var rebuild: Vector2i = sl._rebuild_queue.pop_front()
			var rkey: String = sl._chunk_key(rebuild)
			sl._rebuild_pending.erase(rkey)
			# Streamed out while it waited: nothing to rebuild (it rebuilds from the
			# current edit log when it streams back in).
			if sl._loaded.has(rkey):
				sl._dispatch_build(rebuild)
				sl._pump_steps += 1
				budget -= 1
			continue
		if sl._load_queue.is_empty():
			return
		var chunk: Vector2i = sl._load_queue.pop_front()
		sl._pending.erase(sl._chunk_key(chunk))
		# Phase 42 review — CANCELLATION. A chunk can leave the streamed window while it
		# sits in the queue (the player turned around). Dispatching it anyway built ground
		# nobody wants — and `refresh()` would not re-queue it on the way back in, because
		# its `_pending` mark was still set, so it was silently skipped instead. Dropping
		# it here clears that mark, so a chunk that leaves range and returns is queued
		# again rather than left as a hole.
		if not sl._within_windows(centers, radius, chunk):
			continue
		# Phase 142 — the chunk's regions read on a worker; it waits at the back of the queue
		# until they land (a failed region does not hold it: see `regions_settled`).
		if sl._reads_async() and not sl.region_streamer.regions_settled(chunk, sl.Frontier.BLEND_CHUNKS):
			sl._pending[sl._chunk_key(chunk)] = true
			sl._load_queue.append(chunk)
			waiting += 1
			if waiting > sl._load_queue.size():
				return
			continue
		if not sl._loaded.has(sl._chunk_key(chunk)):
			sl.load_chunk(chunk)
			sl._pump_steps += 1
		budget -= 1

## Hand one chunk's build to a worker task. Main-thread work: the heightmap generation and the
## GATHER of the plain state the resolve reads (`gather_build_input` — that is where `_edits`,
## `_heightmaps` and the biome lookup are read). Worker work: the whole resolve
## (`VoxelSlice.build_runs`) AND the pure build (`build_chunk_arrays`), both of which return plain
## arrays the main thread attaches later, in `_apply_finished_builds()`.
##
## Phase 42 review pass 9 — the resolve moved to the worker (see `gather_build_input` and
## `build_runs`). It used to be the main thread's half of every dispatch, and at ~43 ms per chunk
## it was the stall the phase exists to remove, still being paid on the main thread once per
## frame; what remains there is the noise generation and a handful of copies.
func _dispatch_build(chunk_pos: Vector2i) -> void:
	var key = sl._chunk_key(chunk_pos)
	# An isolated rig (the suite wires no terrain/voxel) has nothing to build, and the
	# chunk is "built" the moment it is loaded — otherwise a gate would hang forever.
	if sl.terrain_slice == null or sl.voxel_slice == null \
			or not sl.terrain_slice.has_method("generate_heightmap") \
			or not sl.voxel_slice.has_method("build_chunk_arrays"):
		sl._built[key] = true
		sl.built_rev += 1
		# Phase 42 review pass 4 — and the CONTENTS obey the same residency rule as the
		# threaded path (`_contents_spawned`): a rig with no terrain/voxel has nothing to
		# build, but an edit still reaches here through `request_rebuild`, and spawning the
		# chunk's budgets on every such call re-derived a population that was already standing
		# there. The rig used to spawn unconditionally because it never had a second call.
		sl._spawn_contents_once(key, chunk_pos)
		sl._update_first_ring_progress()
		return
	# Phase 194 (#512) — a cached chunk needs no worker, so it does not wait for a slot.
	if take_cache_hit(chunk_pos, key):
		return
	# Phase 42 review pass 9 — the in-flight cap is enforced HERE, not only at the call
	# sites. Every internal caller checked it before dispatching, but `load_chunk()` is
	# PUBLIC and dispatched outright: a direct load (a test, a future caller) put the pool
	# over `max_builds_in_flight`. The deferral goes to `_rebuild_queue`, which
	# `_drain_load_queue` drains under this same cap; the chunk is already `_loaded` (both
	# `load_chunk` and `request_rebuild` mark it first), so the drain's rebuild branch is
	# exactly the path that re-dispatches it. Delayed a frame, never dropped.
	if worker_builds() >= sl.build_cap():
		sl._queue_rebuild(chunk_pos)
		return
	# Phase 42 review — SUPERSEDE a build already in flight for this chunk. The caller
	# reaches here for a chunk whose data changed under an in-flight build (see
	# `request_rebuild`), and the older task's arrays describe the terrain BEFORE that
	# change. It cannot simply be erased from `_builds`: the pool keeps a task alive until
	# it is awaited, so it is marked instead and reaped by `_apply_build_entry`, which
	# neither attaches it nor re-dispatches it. Without this the two tasks carry the same
	# revision and BOTH attach, so the mesh could end up the pre-edit one.
	sl._supersede_in_flight(key)
	# This dispatch satisfies any deferred one still waiting in `_rebuild_queue` (an earlier
	# call the cap deferred). Left there, the drain would dispatch the chunk a second time and
	# supersede the build just started — a wasted worker build and a spent retry.
	if sl._rebuild_pending.has(key):
		sl._rebuild_pending.erase(key)
		sl._remove_queued_rebuild(key)
	sl._build_attempts[key] = int(sl._build_attempts.get(key, 0)) + 1
	if sl.terrain_slice.has_method("detail_noise_copy") and sl.voxel_slice.has_method("gather_build_input_deferred"):
		sl._dispatch_worker_noise_build(chunk_pos, key)
		return
	# A neighbour's gather may already have generated this chunk's map (its seam guess);
	# the voxel slice hands that one over instead of recomputing the noise here.
	var heightmap: Array = sl.voxel_slice.take_heightmap_for_build(chunk_pos) \
		if sl.voxel_slice.has_method("take_heightmap_for_build") \
		else sl.terrain_slice.generate_heightmap(chunk_pos)
	# Phase 42 review pass 9 — the RESOLVE runs on the worker too. The main thread only GATHERS the
	# plain state it reads (`gather_build_input`); before this, resolving the chunk's runs, colours
	# and deposits cost ~43 ms of per-tile work on the main thread per dispatch — 2.7 frames at
	# 60 Hz, and the one main-thread cost the earlier passes left behind (measured; see the split
	# probe). The payload is plain data only (heightmap arrays, deep-copied edit lists,
	# chunk-keyed biomes), so the task may hold it.
	# #437 — a dedicated server attaches no geometry: skip the gather and hand back the no-geometry
	# marker instead of resolving and building arrays `build_chunk` would discard.
	var geometry: bool = not sl.skips_geometry()
	var gathered: Dictionary = sl.voxel_slice.gather_build_input(chunk_pos, heightmap) if geometry else {}
	var keep_render: bool = sl.keeps_render()
	var revision: int = int(sl.voxel_slice.chunk_revision(chunk_pos))
	var result: Array = [null]
	var job := func() -> void:
		if not geometry:
			result[0] = VoxelBuilder.no_geometry_arrays()
			return
		result[0] = VoxelMesh.build_worker_arrays(chunk_pos, heightmap,
			VoxelBuilder.build_runs(chunk_pos, heightmap, gathered), keep_render)
	var task_id = WorkerThreadPool.add_task(job, sl.build_high_priority(chunk_pos), "chunk build %s" % key)
	sl._builds[task_id] = {
		"chunk":     chunk_pos,
		"key":       key,
		"heightmap": heightmap,
		"revision":  revision,
		"result":    result,
	}

## Phase 191 — a chunk built moments ago and unchanged since attaches from the cache, with no worker task.
## Phase 194 (#512) — it attaches as a finished build does, not here: it joins `_builds` under a negative id,
## already done, so `_apply_finished_builds` attaches it in `apply_order` under the frame's pacing (a hit
## attached at dispatch skipped both, and waited for a worker slot it never used). True when it was queued.
func take_cache_hit(chunk_pos: Vector2i, key: String) -> bool:
	if sl.skips_geometry() or not sl.keeps_render() or not sl.terrain_slice.has_method("detail_noise_copy"):
		return false
	var lod: int = sl._near.lod_for(chunk_pos)
	var hit: Dictionary = sl._cache.take(key, sl.cache_signature(chunk_pos, lod))
	if hit.is_empty():
		return false
	sl._cache.invalidate(key)   # re-put by the attach (a refused one must not hit again)
	sl._supersede_in_flight(key)
	if sl._rebuild_pending.has(key):
		sl._rebuild_pending.erase(key)
		sl._remove_queued_rebuild(key)
	sl._build_attempts[key] = int(sl._build_attempts.get(key, 0)) + 1
	sl._last_hit_id -= 1
	sl._builds[sl._last_hit_id] = {
		"chunk":     chunk_pos,
		"key":       key,
		"heightmap": hit["heightmap"],
		"revision":  int(sl.voxel_slice.chunk_revision(chunk_pos)),
		"result":    [hit["arrays"], hit["heightmap"], 0],
		"cached":    true,
	}
	return true

## Phase 187 — the finished builds in the order they attach: the local player's 3×3 ring first (the
## chunk under the body before its neighbours), everything else in dispatch order. The attach is the
## main-thread wall (collision alone is ~9 ms a chunk, so an over-budget frame attaches one); in dispatch
## order the chunk under a fast player waited behind ring chunks dispatched before it. Only those nine
## jump the line, so no other build can be starved by a stream of nearer ones (a fold's catch-up).
func apply_order(done: Array) -> Array:
	if done.size() < 2 or sl._last_centers.is_empty():
		return done
	var local: Vector2i = sl._last_centers[0]
	if sl.is_moving_fast():
		return _lane_order(done, sl._last_centers)
	var urgent: Array = []
	var rest: Array = []
	for i in done.size():
		var c: Vector2i = sl._builds[done[i]]["chunk"]
		var d := maxi(absi(c.x - local.x), absi(c.y - local.y))
		if d <= 1:
			urgent.append([d, i, done[i]])
		else:
			rest.append(done[i])
	if urgent.is_empty():
		return done
	urgent.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var out: Array = []
	for u in urgent:
		out.append(u[2])
	return out + rest

## Phase 191 — while the local body flies fast the main-thread attach (one chunk a frame on a slow machine) is the
## wall: a crossing finishes a whole column of chunks and only the one in the body's row matters. Finished builds attach
## lane first (on either axis through the body, nearest first), so the ground ahead of the body lands before the rest
## of the column. Phase 194 (#512): the rest attach by their Chebyshev distance from the nearest window centre (half a
## ring after a lane chunk as far out), so the body's diagonal neighbours and a peer's own chunks no longer wait for the
## whole lane. `centers[0]` is the local body.
func _lane_order(done: Array, centers: Array) -> Array:
	var local: Vector2i = centers[0]
	var keyed: Array = []
	for i in done.size():
		var c: Vector2i = sl._builds[done[i]]["chunk"]
		var ax := absi(c.x - local.x)
		var az := absi(c.y - local.y)
		var k: float = float(nearest_ring(centers, c)) + 0.5
		if mini(ax, az) == 0:
			k = minf(k, float(maxi(ax, az)))   # a lane chunk, unless a peer stands nearer to it
		keyed.append([k, i, done[i]])
	keyed.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	return keyed.map(func(k): return k[2])

## Phase 141 — the dispatch with the NOISE on the worker too. Measured before this: the main thread
## paid 14 ms (equator) to 36 ms (by a pole) for the chunk's own heightmap and up to 8 more maps for
## its unbuilt neighbours' seam guesses (120 ms to 290 ms on a cold window), once per dispatch, i.e.
## a stall of 1 to 18 frames on every frame of a crossing. Now the main thread only gathers (edits,
## known maps, biomes) and copies the noise; the task generates the chunk's map from the static
## generator (`TerrainSlice.heightmap_for`) and only the seam EDGES of the unknown neighbours
## (`VoxelSlice.fill_seam_strips`), then resolves and builds as before. The map comes back in
## `result[1]`, and `_apply_build_entry` stores that one.
##
## Phase 190 — a chunk `NearRing.lod_for` puts beyond the detail ring is built coarse instead
## (`VoxelCoarse`): no seam strips, no full resolve, a small conservative collision shape. Its gather is
## only the biomes. The task's own time comes back in `result[2]` (µs) for the flight step's worker ms per crossing.
func dispatch_worker_noise_build(chunk_pos: Vector2i, key: String) -> void:
	TerrainSliceScript.warm_polar_caches()   # the static caches the generator reads, filled here on the main thread
	var voxel: Node = sl.voxel_slice
	var cached: Array = voxel.take_cached_heightmap(chunk_pos)
	# #437 — a dedicated server attaches no geometry, so its task only generates the map: no gather,
	# no seam strips, no resolve and no mesh/collision/deposit arrays to throw away.
	var geometry: bool = not sl.skips_geometry()
	var keep_render: bool = sl.keeps_render()
	var lod: int = sl._near.lod_for(chunk_pos) if geometry else VoxelCoarse.FULL
	var revision: int = int(voxel.chunk_revision(chunk_pos))
	var gathered: Dictionary = {}
	if lod != VoxelCoarse.FULL:
		gathered = { "biomes": voxel.gather_biomes_for(chunk_pos) }
	elif geometry:
		gathered = voxel.gather_build_input_deferred(chunk_pos)
	var seed_v: int = int(sl.terrain_slice.get_world_seed())
	var noise: FastNoiseLite = sl.terrain_slice.detail_noise_copy()
	var result: Array = [null, cached, 0]
	var job := func() -> void:
		var t0 := Time.get_ticks_usec()
		var hm: Array = cached if not cached.is_empty() else TerrainSliceScript.heightmap_for(chunk_pos, seed_v, noise)
		result[1] = hm
		if not geometry:
			result[0] = VoxelBuilder.no_geometry_arrays()
		elif lod != VoxelCoarse.FULL:
			var coarse := VoxelCoarse.build_coarse_arrays(chunk_pos, hm, gathered, lod, true)
			coarse["shape"] = VoxelMesh.collision_shape(coarse["collision"])
			result[0] = coarse
		else:
			VoxelBuilder.fill_seam_strips(chunk_pos, gathered, seed_v, noise)
			result[0] = VoxelMesh.build_worker_arrays(chunk_pos, hm, VoxelBuilder.build_runs(chunk_pos, hm, gathered), keep_render)
		result[2] = Time.get_ticks_usec() - t0
	# A low-priority task may only use `low_priority_thread_ratio` of the pool (0.3 by default: three or
	# four threads on most machines, which is what really capped the build rate). Phase 141 raised only the
	# catch-up to high priority; Phase 187 does it for the local player's window too, because the steady
	# stream is capped the same way: at 90 m/s (admin flight) 11 builds sat in flight while three ran. A peer's
	# window stays low (`build_high_priority`). `build_cap()` (all cores but one) keeps a worker free.
	var task_id := WorkerThreadPool.add_task(job, sl.build_high_priority(chunk_pos), "chunk build %s" % key)
	sl._builds[task_id] = {
		"chunk":     chunk_pos,
		"key":       key,
		"heightmap": [],
		"revision":  revision,
		"result":    result,
	}
