extends RefCounted
## Methods moved verbatim out of `chunk_manager.gd` (Phase 154). `sl` is the owning slice; each moved method keeps a forwarder there.

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

	sl._last_centers = centers
	# ONE radius for WANTED and DESIRED on purpose (ninth review pass): `wanted` — what a
	# crossing retains — is the same radius the queue spans, so no chunk that was queued (and
	# therefore built) is released while it is still inside the window it was built for. See
	# the docstring above for why the two radii were briefly different and why that was a waste.
	var radius = sl.stream_radius()
	var desired: Array = []
	var refs: Dictionary = {}
	for win_center in centers:
		for c in sl._desired_chunks(win_center, radius):
			var ckey = sl._chunk_key(c)
			if not refs.has(ckey):
				desired.append(c)
				refs[ckey] = 0
			refs[ckey] += 1
	sl._chunk_refs = refs
	# Phase 52 — the edits of every region the windows touch are resident BEFORE a chunk is
	# queued, so no build reads a log that is missing its region.
	if sl.region_streamer != null:
		sl._sync_wanted_regions(desired)

	# Queue loads nearest-first. Dispatching is what is bounded per frame; the build
	# itself runs on a worker.
	var to_load: Array = []
	for c in desired:
		var key = sl._chunk_key(c)
		if not sl._loaded.has(key) and not sl._pending.has(key):
			to_load.append(c)
	to_load.sort_custom(func(a, b): return sl._nearest_dist2(centers, a) < sl._nearest_dist2(centers, b))
	for c in to_load:
		sl._pending[sl._chunk_key(c)] = true
		sl._load_queue.append(c)

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
		# Phase 42 review pass 4 — and the CONTENTS obey the same residency rule as the
		# threaded path (`_contents_spawned`): a rig with no terrain/voxel has nothing to
		# build, but an edit still reaches here through `request_rebuild`, and spawning the
		# chunk's budgets on every such call re-derived a population that was already standing
		# there. The rig used to spawn unconditionally because it never had a second call.
		sl._spawn_contents_once(key, chunk_pos)
		sl._update_first_ring_progress()
		return
	# Phase 42 review pass 9 — the in-flight cap is enforced HERE, not only at the call
	# sites. Every internal caller checked it before dispatching, but `load_chunk()` is
	# PUBLIC and dispatched outright: a direct load (a test, a future caller) put the pool
	# over `max_builds_in_flight`. The deferral goes to `_rebuild_queue`, which
	# `_drain_load_queue` drains under this same cap; the chunk is already `_loaded` (both
	# `load_chunk` and `request_rebuild` mark it first), so the drain's rebuild branch is
	# exactly the path that re-dispatches it. Delayed a frame, never dropped.
	if sl._builds.size() >= sl.build_cap():
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
	var gathered: Dictionary = sl.voxel_slice.gather_build_input(chunk_pos, heightmap)
	var revision: int = int(sl.voxel_slice.chunk_revision(chunk_pos))
	var result: Array = [null]
	var task_id = WorkerThreadPool.add_task(
		func(): result[0] = sl.VoxelBuilder.build_chunk_arrays(chunk_pos, heightmap,
			sl.VoxelBuilder.build_runs(chunk_pos, heightmap, gathered), true),
		false, "chunk build %s" % key)
	sl._builds[task_id] = {
		"chunk":     chunk_pos,
		"key":       key,
		"heightmap": heightmap,
		"revision":  revision,
		"result":    result,
	}
