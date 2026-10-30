extends "res://src/tests/test_support.gd"
## Phase 141 — terrain streaming off the main thread: the static heightmap generator, the seam
## edge strips, the polar shortcuts, the worker-noise build and the fold catch-up.
## Phase 187 — build priority and the load queue's order at speed.
## Phase 189 — collision and contents only near a body.

const VoxelMesh := preload("res://src/terrain/voxel_mesh.gd")

func register() -> void:
	_run_test("stream: the static generator matches generate_heightmap", _test_stream_static_generator_matches)
	_run_test("stream: a seam strip is the full map's edge and nothing else", _test_stream_seam_strip_is_edge)
	_run_test("stream: the polar row memo and shelf shortcut change no height", _test_stream_polar_shortcuts_exact)
	_run_test("stream: a deferred gather builds the same chunk as a full one", _test_stream_deferred_gather_same_build)
	_run_test("stream: a dispatch generates no map on the main thread", _test_stream_dispatch_no_main_thread_noise)
	_run_test("stream: a frame's pump stops at its time budget and bounds its applies", _test_stream_pump_budget)
	_run_test("stream: the steady build cap defaults to the core count minus one", _test_stream_builds_in_flight_default)
	_run_test("stream: a restream bursts the build cap until the window is rebuilt", _test_stream_fold_catchup)
	_run_test("stream: the local window builds high while moving fast, a peer window low", _test_stream_builds_high_priority)
	_run_test("stream: finished builds attach nearest the body first", _test_stream_apply_nearest_first)
	_run_test("stream: the queue key puts the body's chunk first and favours the heading", _test_stream_queue_priority)
	_run_test("stream: a crossing re-sorts the whole queue around the new centre", _test_stream_queue_resorted_on_move)
	_run_test("near: collision only within a walking body's ring, attached when a chunk enters it", _test_near_collision_ring)
	_run_test("near: parked collision attaches nearest first under the pump budget", _test_near_collision_nearest_first)
	_run_test("near: a chunk off the body's ring takes its collision a quadrant a step", _test_near_collision_staggered)
	_run_test("near: a chunk beside the body lands with a quadrant and takes the rest in one tick", _test_near_collision_neighbour)
	_run_test("near: the quadrant split keeps every collision face, small soups stay whole", _test_collision_parts_split)
	_run_test("near: a fast flying body gets collision under it only, its ring once it slows", _test_near_collision_flying)
	_run_test("near: a peer's ring keeps collision, a dedicated server keeps it everywhere", _test_near_collision_peer_and_server)
	_run_test("near: a fold stand-in keeps its parked collision for the body", _test_near_collision_fold_standin)
	_run_test("near: contents spawn once with the same ids on attach or on slowing down", _test_near_contents_same_ids)
	_run_test("near: deferred contents spawn when the chunk enters the near ring", _test_near_contents_enter_ring)
	_run_test("stream: a fast flyer's lane goes first, the rest by distance from the nearest centre", _test_stream_lane_order)
	_run_test("stream: a lane-sorted queue is re-sorted by distance when the flyer stops", _test_stream_queue_resorted_on_stop)
	_run_test("near: a parked shape lives in one store through build, park, fold and attach", _test_near_parked_one_store)
	_run_test("near: the parked scan is skipped while idle and resumes on a newly parked shape", _test_near_scan_idle_skip)
	_run_test("near: switching the ring off spawns every waiting chunk's contents at once", _test_near_toggle_flushes_waiting)
	_run_test("fold: a creature and a tree keep id, state and place across a pole fold", _test_fold_carries_contents)
	_run_test("fold: the fold image of a position is an involution over a pole and a lap", _test_fold_like_involution)
	_run_test("fold: a client replays two folds on host positions, the log stays minimal", _test_fold_log_replay)
	_run_test("fold: held death records are folded with the window", _test_fold_dead_records)

## Rows a player can reach: the equator, mid latitudes, the ice shelf, the pole's snow field, past
## the pole (the fold slack) and the antimeridian's blend band.
func _stream_probe_chunks() -> Array:
	var pole := TerrainSlice.pole_chunks()
	@warning_ignore("integer_division")
	var east := TerrainSlice.circumference_chunks() / 2 - 2
	return [Vector2i(3, 2), Vector2i(-40, pole * 2 / 3), Vector2i(17, pole * 82 / 90),
		Vector2i(5, pole - 7), Vector2i(-9, -pole + 3), Vector2i(2, pole + 10), Vector2i(east, 4)]

func _test_stream_static_generator_matches() -> void:
	var t := TerrainSlice.new()
	add_child(t)
	t.set_world_seed(4242)
	for c in _stream_probe_chunks():
		var want: Array = t.generate_heightmap(c)
		var got: Array = TerrainSlice.heightmap_for(c, 4242, t.detail_noise_copy())
		assert_true(got == want, "heightmap_for(%s) equals generate_heightmap" % str(c))
	t.free()

func _test_stream_seam_strip_is_edge() -> void:
	var t := TerrainSlice.new()
	add_child(t)
	t.set_world_seed(99)
	var n: int = TerrainSlice.CHUNK_SIZE
	var c := Vector2i(5, TerrainSlice.pole_chunks() - 4)
	var full: Array = t.generate_heightmap(c)
	for side in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1)]:
		var strip: Array = TerrainSlice.heightmap_strip_for(c, side, 99, t.detail_noise_copy())
		assert_eq(strip.size(), full.size(), "strip %s has the full map's shape" % str(side))
		var filled := 0
		var wrong := 0
		var stray := 0
		for tz in n:
			for tx in n:
				var on_edge: bool = (side.x == 0 or tx == (0 if side.x < 0 else n - 1)) \
					and (side.y == 0 or tz == (0 if side.y < 0 else n - 1))
				var v: Variant = strip[tz * n + tx]
				if on_edge:
					filled += 1
					if v == null or float(v) != float(full[tz * n + tx]):
						wrong += 1
				elif v != null:
					stray += 1
		var want_filled := (n if side.x == 0 else 1) * (n if side.y == 0 else 1)
		assert_eq(filled, want_filled, "strip %s covers exactly its edge" % str(side))
		assert_eq(wrong, 0, "strip %s matches the full map on its edge" % str(side))
		assert_eq(stray, 0, "strip %s computes nothing off its edge" % str(side))
	t.free()

func _test_stream_polar_shortcuts_exact() -> void:
	var w := float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS
	var pole_z := float(TerrainSlice.pole_chunks()) * TerrainSlice.CHUNK_METERS
	var sea := WorldShape.sea_level()
	var row := TerrainSlice.new_polar_row()
	var diffs := 0
	var samples := 0
	# Heights straddle the shelf bound (sea + ICE_SHELF_M + ICE_RELIEF_M), rows go from the ice line
	# to past the pole, so both shortcuts and the plain path all run.
	for dz in [-1200000.0, -4000.0, -1000.0, -16.25, 0.0, 3.5, 300.0]:
		var z: float = pole_z + float(dz)
		for i in 40:
			var x := float(i) * 13.5 - 200.0
			var h := sea + float(i % 8) - 2.0
			var plain := _polar_reference(7, h, x, z, w)
			var memo := TerrainSlice.polar_ground(7, h, x, z, w, row)
			samples += 1
			if memo != plain or TerrainSlice.polar_ground(7, h, x, z, w) != plain:
				diffs += 1
	assert_eq(diffs, 0, "polar_ground with and without the memo equals the unoptimised form (%d samples)" % samples)

## The Phase 120 `polar_ground`, before the Phase 141 shortcuts: the reference the fast form must match.
func _polar_reference(seed_v: int, h: float, x: float, z: float, w: float) -> float:
	var row_lat := absf(TerrainSlice.latitude_of(floori(z / TerrainSlice.CHUNK_METERS)))
	if row_lat < TerrainSlice.ICE_SHELF_LAT:
		return h
	var cells := maxi(1, roundi(w / TerrainSlice.ICE_RELIEF_CELL_M))
	var shelf := WorldShape.sea_level() + TerrainSlice.ICE_SHELF_M + TerrainSlice.ICE_RELIEF_M * WorldShape._noise(seed_v, x, z, w, cells, 61)
	h = maxf(h, shelf)
	var lat := TerrainSlice.latitude_at(z)
	var from_pole := (90.0 - absf(lat)) * float(TerrainSlice.pole_chunks()) * TerrainSlice.CHUNK_METERS / 90.0
	if from_pole >= TerrainSlice.POLE_FIELD_OUTER_M:
		return h
	var t := 1.0 - smoothstep(TerrainSlice.POLE_FIELD_INNER_M, TerrainSlice.POLE_FIELD_OUTER_M, from_pole)
	return lerpf(h, TerrainSlice.pole_field(), t)

func _test_stream_deferred_gather_same_build() -> void:
	var t := TerrainSlice.new()
	add_child(t)
	t.set_world_seed(12345)
	var v := VoxelSlice.new()
	v.terrain_slice = t
	add_child(v)
	for c in [Vector2i(7, 1), Vector2i(9, TerrainSlice.pole_chunks() - 3)]:
		var hm: Array = t.generate_heightmap(c)
		var full := VoxelSlice.build_chunk_arrays(c, hm, VoxelSlice.build_runs(c, hm, v.gather_build_input(c, hm)), true)
		v._guess_heightmaps.clear()
		var input: Dictionary = v.gather_build_input_deferred(c)
		assert_eq((input["missing_neighbours"] as Array).size(), 8, "an isolated chunk lists all eight neighbours as missing")
		assert_eq(v._guess_heightmaps.size(), 0, "and the deferred gather generated none of them")
		VoxelSlice.fill_seam_strips(c, input, 12345, t.detail_noise_copy())
		var own := TerrainSlice.heightmap_for(c, 12345, t.detail_noise_copy())
		var fast := VoxelSlice.build_chunk_arrays(c, own, VoxelSlice.build_runs(c, own, input), true)
		assert_true(fast["vertices"] == full["vertices"] and fast["colors"] == full["colors"] \
			and fast["indices"] == full["indices"], "chunk %s: the worker-noise build draws the same mesh" % str(c))
		assert_true(fast["collision"] == full["collision"], "chunk %s: and the same collision" % str(c))
	v.free()
	t.free()

func _test_stream_dispatch_no_main_thread_noise() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var voxel: VoxelSlice = rig["voxel"]
	var terrain: TerrainSlice = rig["terrain"]
	cm.load_chunk(Vector2i(2, 3))
	assert_eq(voxel._guess_heightmaps.size(), 0, "the dispatch generated no neighbour guess on the main thread")
	_wait_for_builds(cm)
	assert_true(cm.is_chunk_built(Vector2i(2, 3)), "the worker-noise build lands")
	assert_true(voxel._heightmaps.get("2,3", []) == terrain.generate_heightmap(Vector2i(2, 3)),
		"and the slice stores the map the worker generated, equal to the generator's")
	cm.free()
	voxel.free()
	terrain.free()
	rig["player"].free()

func _test_stream_pump_budget() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	# A stub clock that advances 1 ms per read, so a step's cost is deterministic.
	var ticks := [0]
	cm.pump_clock_usec = func() -> int:
		var t: int = ticks[0]
		ticks[0] = t + 1000
		return t
	cm.pump_budget_msec = 3
	cm.loads_per_frame = 100
	cm.max_builds_in_flight = 100
	cm.view_distance = 2
	cm.prefetch_distance = 0
	cm.refresh()
	var queued := cm._load_queue.size()
	assert_true(queued > 3, "a window is queued")
	cm.begin_pump()
	cm._drain_load_queue()
	assert_eq(cm._builds.size(), 3, "a frame dispatches until the 3 ms budget is spent, no further")
	assert_eq(cm._load_queue.size(), queued - 3, "the rest stays queued for the next frame")
	assert_true(cm.pump_spent_usec() <= 5000, "and the pump stopped within a step of the budget")
	# Apply: only `applies_per_frame` finished builds land in one frame.
	for task_id in cm._builds.keys():
		while not WorkerThreadPool.is_task_completed(task_id):
			OS.delay_msec(1)   # poll, never wait: waiting would consume the id the pump polls
	cm.applies_per_frame = 2
	cm.pump_budget_msec = 0
	cm.begin_pump()
	cm._apply_finished_builds()
	assert_eq(cm._built.size(), 2, "one frame applies at most applies_per_frame builds")
	cm.flush_builds()
	cm.pump_budget_msec = 0
	_wait_for_builds(cm)
	cm.free()
	rig["voxel"].free()
	rig["terrain"].free()
	rig["player"].free()

func _test_stream_builds_in_flight_default() -> void:
	var cm := ChunkManager.new()
	assert_eq(cm.max_builds_in_flight, maxi(4, OS.get_processor_count() - 1), "the steady cap is every core but one, at least four")
	cm.free()

func _test_stream_fold_catchup() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	cm.view_distance = 1
	cm.prefetch_distance = 0
	cm.max_builds_in_flight = 2
	cm.catchup_builds_in_flight = 6
	cm.refresh()
	_wait_for_builds(cm)
	assert_false(cm.is_catching_up(), "a steady window is not catching up")
	assert_eq(cm.build_cap(), 2, "and builds under the steady cap")
	cm.restream()
	assert_true(cm.is_catching_up(), "a restream starts the catch-up")
	assert_eq(cm.build_cap(), 6, "which raises the cap")
	cm.refresh()
	cm._drain_load_queue()
	assert_eq(cm._builds.size(), mini(cm.catchup_loads_per_frame, 6), "one drain dispatches the catch-up's per-frame count")
	_wait_for_builds(cm)
	cm._drain_load_queue()
	assert_false(cm.is_catching_up(), "the catch-up ends once nothing is queued or in flight")
	assert_eq(cm.build_cap(), 2, "back at the steady cap")
	assert_eq(cm._built.size(), 9, "with the whole window rebuilt")
	cm.free()
	rig["voxel"].free()
	rig["terrain"].free()
	rig["player"].free()


## Phase 145 — a creature and a tree in the window are carried across a fold: same ids, same state, the
## fold's image of their place, and the folded window's own spawn adds and removes nothing.
func _test_fold_carries_contents() -> void:
	var pole := TerrainSlice.pole_chunks()
	var chunk := Vector2i(3, pole + 1)   # past the pole, as a window is a few chunks before the fold
	var cs := CreatureSlice.new()
	add_child(cs)
	cs.spawn_for_chunk(chunk)
	var ts := _make_tree_slice()
	ts._spawn("Oak", "Wood", chunk, 0)
	var iids: Array = cs._instances.keys()
	assert_true(iids.size() > 0, "the chunk holds creatures")
	var iid: String = iids[0]
	cs._instances[iid]["hp"] = 7.0
	cs._instances[iid]["tamed_by"] = "p1"
	var before: Vector3 = cs._instances[iid]["position"]
	var tree_before: Vector3 = ts._trees["tree_%d_%d_0" % [chunk.x, chunk.y]]["position"]
	var count := cs._instances.size()
	var spawned := [0]
	var on_spawn := func(_i, _c, _p): spawned[0] += 1
	GameBus.creature_spawned.connect(on_spawn)

	cs.fold_contents(true, 1)
	ts.fold_contents(true, 1)
	assert_eq(spawned[0], 0, "the fold respawns nothing")

	assert_true(cs._instances.has(iid), "the creature keeps its id")
	assert_eq(cs._instances.size(), count, "and none is despawned")
	assert_eq(float(cs._instances[iid]["hp"]), 7.0, "its hp")
	assert_eq(cs._instances[iid]["tamed_by"], "p1", "and tame stay")
	var after: Vector3 = cs._instances[iid]["position"]
	assert_eq(after, TerrainSlice.fold_world_vec_like(before, true, 1), "its place is the fold's image")
	var folded_chunk := Vector2i(floori(after.x / TerrainSlice.CHUNK_METERS), floori(after.z / TerrainSlice.CHUNK_METERS))
	assert_eq(cs._instances[iid]["chunk"], folded_chunk, "filed under the chunk it now stands in")
	assert_true((cs._by_chunk[folded_chunk] as Array).has(iid), "in the chunk index")
	assert_true(cs.creatures_in_radius(cs._instances[iid]["pos"], 0.5).has(iid), "and in the spatial hash")
	var tid := "tree_%d_%d_0" % [chunk.x, chunk.y]
	assert_true(ts._trees.has(tid), "the tree keeps its id")
	assert_eq(ts._trees[tid]["position"], TerrainSlice.fold_world_vec_like(tree_before, true, 1), "at the fold's image of its place")
	assert_true(ts.index_is_consistent(), "with a consistent index")

	# The folded window's own spawn: nothing is despawned or doubled.
	var tree_count: int = ts._trees.size()
	var tree_chunk: Vector2i = ts._trees[tid]["chunk"]
	ts.spawn_for_chunk(tree_chunk)
	assert_true(ts._trees.has(tid) and ts._trees.size() >= tree_count, "a folded chunk's spawn keeps the carried tree")
	cs.spawn_for_chunk(folded_chunk)
	assert_true(cs._instances.has(iid), "the creature survives its new chunk's spawn")
	var same := 0
	for other in cs._by_chunk[folded_chunk]:
		if cs._instances[other]["creature_id"] == cs._instances[iid]["creature_id"]:
			same += 1
	assert_true(same <= int(GameData.CREATURES[cs._instances[iid]["creature_id"]].get("spawnCount")), "no species exceeds its pack")

	# A carried entity outside the folded window goes.
	assert_eq(cs.prune_carried(func(_c): return true), 0, "a covered window drops nothing")
	assert_true(cs.prune_carried(func(_c): return false) >= 1, "an uncovered chunk's creatures are released")
	assert_eq(cs._instances.size(), 0, "none left")
	assert_true(ts.prune_carried(func(_c): return false) >= 1, "and its trees")
	assert_true(ts.index_is_consistent(), "with a consistent index after the prune")

	GameBus.creature_spawned.disconnect(on_spawn)
	cs.free()
	ts.free()

## Phase 145 — folding twice over the same pole returns the position; a lap fold shifts X only.
func _test_fold_like_involution() -> void:
	var pole_m := float(TerrainSlice.pole_chunks()) * TerrainSlice.CHUNK_METERS
	var p := Vector3(1234.5, 3.0, pole_m + 40.25)
	var once := TerrainSlice.fold_world_vec_like(p, true, 1)
	assert_true(absf(once.z - (pole_m - 40.25)) < 2.0, "a pole fold mirrors Z about the pole edge")
	var back := TerrainSlice.fold_world_vec_like(once, true, 1)
	assert_true(absf(back.x - p.x) < 2.0 or absf(absf(back.x - p.x) - float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS) < 2.0,
		"folding back lands where it started, give or take a lap")
	assert_true(absf(back.z - p.z) < 2.0, "on the same row")
	var lapped := TerrainSlice.fold_world_vec_like(p, false, 1)
	assert_true(absf(lapped.z - p.z) < 2.0 and lapped.y == p.y, "a lap fold leaves Z and Y")

func _test_fold_log_replay() -> void:
	var cs := CreatureSlice.new()
	cs.is_authoritative = false
	add_child(cs)
	var pole_m := float(TerrainSlice.pole_chunks()) * TerrainSlice.CHUNK_METERS
	var host := Vector3(100.5, 5.0, pole_m - 40.0)
	cs.fold_contents(true, 1)
	cs.fold_contents(true, -1)
	assert_eq(cs._fold_log.size(), 2, "two different poles are two entries")
	cs.apply_creature_state("c0", "ForestBoar", "idle", host)
	# Phase 195 — replayed on the exact pair, so it is compared with the exact folds (float32 is a metre out here).
	var host_exact := WorldPos.from_world(host.x, host.y, host.z)
	var want := TerrainSlice.fold_world_pos_like(TerrainSlice.fold_world_pos_like(host_exact, true, 1), true, -1)
	assert_true(WorldPos.offset_between(want, cs.get_instance_pos("c0")).length() < 0.01, "a host position is replayed through both folds, oldest first")
	cs.fold_contents(true, -1)
	assert_eq(cs._fold_log.size(), 1, "crossing the same pole back cancels its entry")
	cs.fold_contents(true, 1)
	assert_true(cs._fold_log.is_empty(), "back in the host's frame, nothing is replayed")
	cs.apply_creature_state("c0", "ForestBoar", "idle", host)
	assert_true(cs.get_instance_position("c0").distance_to(host) < 0.01, "so a host position lands as sent")
	cs.fold_contents(false, 1)
	cs.fold_contents(false, 1)
	assert_eq(cs._fold_log.size(), 1, "lap folds are logged once")
	cs.fold_contents(true, 1)
	assert_eq(cs._fold_log, [[true, 1]], "and absorbed by a pole fold, which wraps too")
	cs.reset_fold_log()
	assert_true(cs._fold_log.is_empty(), "a new session forgets the folds")
	cs.free()

func _test_fold_dead_records() -> void:
	var cs := CreatureSlice.new()
	add_child(cs)
	var pole_m := float(TerrainSlice.pole_chunks()) * TerrainSlice.CHUNK_METERS
	var at := Vector3(100.5, 5.0, pole_m + 40.0)
	var entry := { "state": "dead", "creature_id": "ForestBoar",
		"respawn_at": Time.get_unix_time_from_system() + 600.0, "position": WorldPos.to_wire(at) }
	cs._hold_death_record("d0", entry, CreatureSlice._entry_pos(entry))
	assert_true(cs._dead_state.has("d0"), "the death is held")
	cs.fold_contents(true, 1)
	var got: Vector3 = WorldPos.from_wire(cs._dead_state["d0"]["position"])
	assert_true(got.distance_to(TerrainSlice.fold_world_vec_like(at, true, 1)) < 0.01, "its position is the fold's image")
	cs.free()

## Phase 187 — a low-priority task may use only `low_priority_thread_ratio` of the pool, which held the
## steady stream to three or four threads; the local player's window and a fold's catch-up now build at
## high priority, while a peer's window on a host stays low so the host tick keeps its cores.
func _test_stream_builds_high_priority() -> void:
	var cm := ChunkManager.new()
	var clock := [0]
	cm.pump_clock_usec = func(): return clock[0] * 1000
	cm.view_distance = 2
	cm.prefetch_distance = 0
	assert_false(cm.build_high_priority(Vector2i(0, 0)), "before the first refresh a build is low")
	cm._last_centers = [Vector2i(0, 0), Vector2i(40, 0)]
	assert_false(cm.build_high_priority(Vector2i(0, 0)), "standing still: low")
	clock[0] = 1000
	cm.note_local_crossing()
	clock[0] = 8000
	cm.note_local_crossing()   # a walk: one crossing in 7 s
	assert_false(cm.is_moving_fast(), "a walk is not fast")
	clock[0] = 8400
	cm.note_local_crossing()   # 90 m/s: one crossing in 0.36 s
	assert_true(cm.is_moving_fast(), "a crossing within 2 s of the last is fast")
	assert_true(cm.build_high_priority(Vector2i(0, 0)), "fast: the chunk under the local player is high")
	assert_true(cm.build_high_priority(Vector2i(2, -2)), "fast: the edge of the local window is high")
	assert_false(cm.build_high_priority(Vector2i(3, 0)), "past the local window is low")
	assert_false(cm.build_high_priority(Vector2i(40, 0)), "a peer's window is low")
	clock[0] = 8400 + ChunkManager.FAST_HOLD_MSEC
	assert_false(cm.build_high_priority(Vector2i(0, 0)), "the hold runs out without another crossing")
	cm._catchup = true
	assert_true(cm.build_high_priority(Vector2i(40, 0)), "a fold's catch-up is high everywhere")
	cm.free()
	# Both dispatches live in chunk_part_1.gd since Phase 190 moved the worker-noise one there.
	var src := FileAccess.get_file_as_string("res://src/terrain/chunk_part_1.gd")
	assert_eq(src.count("add_task(job, sl.build_high_priority(chunk_pos)"), 2, "both dispatches ask build_high_priority")
	assert_false(FileAccess.get_file_as_string("res://src/terrain/chunk_manager.gd").contains("add_task("), "chunk_manager.gd adds no task of its own")

## Phase 187 — one over-budget frame attaches one build, so the local player's 3×3 ring attaches first
## (under the body, then its neighbours) and the rest keep dispatch order, so none is starved.
func _test_stream_apply_nearest_first() -> void:
	var cm := ChunkManager.new()
	cm._builds = { 11: { "chunk": Vector2i(7, 0) }, 12: { "chunk": Vector2i(5, 1) }, 13: { "chunk": Vector2i(1, 0) }, 14: { "chunk": Vector2i(4, 0) }, 15: { "chunk": Vector2i(6, 0) } }
	assert_eq(cm._apply_order([11, 12, 13, 14, 15]), [11, 12, 13, 14, 15], "before the first refresh: dispatch order")
	cm._last_centers = [Vector2i(4, 0), Vector2i(1, 0)]
	assert_eq(cm._apply_order([11, 12, 13, 14, 15]), [14, 12, 11, 13, 15], "under the body, its ring, then dispatch order (a peer's centre included)")
	assert_eq(cm._apply_order([11, 15]), [11, 15], "nothing near the body: dispatch order")
	assert_eq(cm._apply_order([12]), [12], "one finished build is itself")
	cm._builds.clear()
	cm.free()

func _test_stream_queue_priority() -> void:
	var centers: Array = [Vector2i(10, 0)]
	var east := Vector2(1, 0)
	var under := ChunkManager.queue_priority(centers, east, Vector2i(10, 0))
	var ahead := ChunkManager.queue_priority(centers, east, Vector2i(11, 0))
	var side := ChunkManager.queue_priority(centers, east, Vector2i(10, 1))
	var behind := ChunkManager.queue_priority(centers, east, Vector2i(9, 0))
	var ahead2 := ChunkManager.queue_priority(centers, east, Vector2i(12, 0))
	assert_true(under < ahead and ahead < side and side < behind, "under, then ahead, then beside, then behind")
	assert_true(behind < ahead2, "the heading never outranks a nearer ring")
	assert_eq(ChunkManager.queue_priority(centers, Vector2.ZERO, Vector2i(12, 1)), 5.0, "standing still: the squared distance")
	assert_eq(ChunkManager.queue_priority([Vector2i(0, 0), Vector2i(20, 0)], Vector2.ZERO, Vector2i(19, 0)), 1.0,
		"the nearest window centre counts")
	assert_eq(ChunkManager.heading_between(Vector2i(0, 0), Vector2i(1, 0), 4), east, "one crossing east")
	assert_eq(ChunkManager.heading_between(Vector2i(0, 0), Vector2i(0, 0), 4), Vector2.ZERO, "no move, no heading")
	assert_eq(ChunkManager.heading_between(Vector2i(0, 0), Vector2i(9, 0), 4), Vector2.ZERO, "a jump past the radius is a teleport")

## Chunks a previous crossing queued used to stay ahead of the new ones, so the chunk under a fast player
## waited behind ground it had already passed.
func _test_stream_queue_resorted_on_move() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var player: PlayerSlice = rig["player"]
	cm.view_distance = 2
	cm.prefetch_distance = 0
	cm.refresh(false)   # queued around (0,0), nothing dispatched
	assert_eq(cm._load_queue[0], Vector2i(0, 0), "the first queue starts under the body")
	player.spawn_at(Vector3(32.0 * 2.0 + 16.0, 40.0, 16.0))   # two chunks east, no drain in between
	cm.refresh(false)
	assert_eq(cm._load_queue[0], Vector2i(2, 0), "after the crossing the queue starts under the body again")
	assert_eq(cm._load_queue[1], Vector2i(3, 0), "then the chunk ahead")
	var center := Vector2i(2, 0)
	var last := -1.0e9
	var sorted := true
	for c: Vector2i in cm._load_queue:
		var k := ChunkManager.queue_priority([center], Vector2(1, 0), c)
		sorted = sorted and k >= last
		last = k
	assert_true(sorted, "the whole queue is in priority order, old entries included")
	rig["cm"].free()
	rig["voxel"].free()
	rig["terrain"].free()
	rig["player"].free()

# ---------------------------------------------------------------------------
# Phase 189 — collision and contents only near a body
# ---------------------------------------------------------------------------

func _free_build_rig(rig: Dictionary) -> void:
	for k in ["cm", "voxel", "terrain", "player", "creature", "tree"]:
		if rig.has(k) and is_instance_valid(rig[k]):
			rig[k].free()

## Build `chunks` through the worker path (the one that gates collision), blocking until they attach.
func _build_chunks(cm: ChunkManager, chunks: Array) -> void:
	for c in chunks:
		cm.load_chunk(c)
	_wait_for_builds(cm)

## Put the rig's player in the middle of `chunk`.
func _stand_in(player: PlayerSlice, chunk: Vector2i) -> void:
	var m := TerrainSlice.CHUNK_METERS
	player.spawn_at(Vector3(float(chunk.x) * m + m * 0.5, 40.0, float(chunk.y) * m + m * 0.5))

## Make the rig's manager see a fast crossing on a stub clock; returns the clock to advance.
func _make_fast(cm: ChunkManager) -> Array:
	var clock := [100000]
	cm.pump_clock_usec = func(): return clock[0] * 1000
	cm.note_local_crossing()
	clock[0] += 300
	cm.note_local_crossing()
	return clock

func _test_near_collision_ring() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	cm.set_lod_enabled(false)   # Phase 190: a far chunk is coarse and has no shape at all; parking is a full chunk's
	var voxel: VoxelSlice = rig["voxel"]
	_build_chunks(cm, [Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 0), Vector2i(3, 0)])
	assert_true(voxel.has_collision(Vector2i(0, 0)), "the chunk under the body has collision")
	assert_true(voxel.has_collision(Vector2i(1, 1)), "a chunk of its ring (Chebyshev 1) has collision")
	# Phase 193 — two out is past the collision ring: the aim ray reads the voxel columns instead.
	assert_false(voxel.has_collision(Vector2i(2, 0)), "a chunk two out has no collision")
	assert_true(voxel.has_parked_collision(Vector2i(2, 0)), "... its shape is parked")
	assert_true(cm.is_chunk_built(Vector2i(3, 0)), "a chunk three out is built")
	assert_false(voxel.has_collision(Vector2i(3, 0)), "... and has no collision shape")
	assert_true(voxel.has_parked_collision(Vector2i(3, 0)), "... its worker shape is kept for later")
	cm._near.tick()
	assert_false(voxel.has_collision(Vector2i(3, 0)), "a tick with the body away attaches nothing")
	_stand_in(rig["player"], Vector2i(2, 0))
	cm._near.tick()
	assert_true(voxel.has_collision(Vector2i(3, 0)), "entering the ring gives it its collision")
	assert_false(voxel.has_parked_collision(Vector2i(3, 0)), "the parked shape is spent")
	cm.unload_chunk(Vector2i(3, 0))
	assert_false(voxel.has_parked_collision(Vector2i(3, 0)), "an unload drops a parked shape")
	_free_build_rig(rig)

func _test_near_collision_nearest_first() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	cm.set_lod_enabled(false)   # Phase 190: a far chunk is coarse and has no shape at all; parking is a full chunk's
	var voxel: VoxelSlice = rig["voxel"]
	# Phase 193 — the collision ring is one out: the nearer chunk is the body's own, the farther its neighbour.
	_build_chunks(cm, [Vector2i(0, 0), Vector2i(3, 0), Vector2i(4, 0)])
	_stand_in(rig["player"], Vector2i(3, 0))
	var clock := [0]
	cm.pump_budget_msec = 4
	cm.pump_clock_usec = func():
		clock[0] += 10000
		return clock[0]
	cm.begin_pump()
	cm._near.tick()
	assert_true(voxel.has_collision(Vector2i(3, 0)), "the nearer parked chunk is attached first")
	assert_false(voxel.has_parked_collision(Vector2i(3, 0)), "the body's own chunk takes every quadrant, budget or not")
	assert_false(voxel.has_collision(Vector2i(4, 0)), "the budget leaves the farther one for a later frame")
	var frames := 0
	while voxel.has_parked_collision(Vector2i(4, 0)) and frames < 8:
		cm.begin_pump()
		cm._near.tick()
		frames += 1
	assert_true(voxel.has_collision(Vector2i(4, 0)), "later frames attach it (%d frames)" % frames)
	assert_false(voxel.has_parked_collision(Vector2i(4, 0)), "with every quadrant")
	_free_build_rig(rig)

func _test_near_collision_flying() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	cm.set_lod_enabled(false)   # Phase 190: a far chunk is coarse and has no shape at all; parking is a full chunk's
	var voxel: VoxelSlice = rig["voxel"]
	var player: PlayerSlice = rig["player"]
	_stand_in(player, Vector2i(3, 0))
	player.flying = true
	var clock := _make_fast(cm)
	assert_true(cm.is_moving_fast(), "the body crosses chunks fast")
	_build_chunks(cm, [Vector2i(3, 0), Vector2i(4, 0)])
	assert_true(voxel.has_collision(Vector2i(3, 0)), "a fast flying body's chunk below has collision")
	assert_false(voxel.has_collision(Vector2i(4, 0)), "its neighbour does not")
	player.flying = false
	assert_true(cm._near.wants_collision(Vector2i(4, 0)), "walking fast, the ring is wanted again")
	player.flying = true
	clock[0] += ChunkManager.FAST_HOLD_MSEC
	assert_false(cm.is_moving_fast(), "the flight slowed down")
	cm._near.tick()
	assert_true(voxel.has_collision(Vector2i(4, 0)), "a slow flyer's ring gets its collision")
	_free_build_rig(rig)

func _test_near_collision_peer_and_server() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var voxel: VoxelSlice = rig["voxel"]
	cm.set_peer_center(7, Vector2i(10, 0), true)
	_build_chunks(cm, [Vector2i(11, 1), Vector2i(13, 0)])
	assert_true(voxel.has_collision(Vector2i(11, 1)), "a chunk in a peer's ring has collision")
	assert_false(voxel.has_collision(Vector2i(13, 0)), "one beyond it does not")
	_free_build_rig(rig)
	var srv := _make_chunk_build_rig()
	srv["voxel"].attach_geometry = false   # a dedicated server: no render mesh, collision kept
	_build_chunks(srv["cm"], [Vector2i(5, 0)])
	assert_true(srv["voxel"].has_collision(Vector2i(5, 0)), "a dedicated server keeps collision everywhere (unchanged)")
	_free_build_rig(srv)

## A build rig with a creature and a tree slice on the manager.
func _make_contents_rig() -> Dictionary:
	var rig := _make_chunk_build_rig()
	var creature := CreatureSlice.new()
	add_child(creature)
	var tree := _make_tree_slice()
	rig["cm"].creature_slice = creature
	rig["cm"].tree_slice = tree
	rig["creature"] = creature
	rig["tree"] = tree
	return rig

## The chunk's creature ids with their positions, and its tree ids with theirs.
func _contents_of(rig: Dictionary, chunk: Vector2i) -> Dictionary:
	var out := {}
	for inst in rig["creature"].get_all_instances():
		if inst["chunk"] == chunk:
			out[str(inst["instance_id"])] = inst["position"]
	for tid in rig["tree"].trees_in_chunk(chunk):
		out[str(tid)] = rig["tree"].get_tree_record(str(tid))["position"]
	return out

func _test_near_contents_same_ids() -> void:
	var far := Vector2i(3, 0)
	var on_attach := _make_contents_rig()
	on_attach["cm"].set_lod_enabled(false)   # Phase 194: a coarse chunk's contents wait for its upgrade; this is the fast rule
	_build_chunks(on_attach["cm"], [far])
	var want := _contents_of(on_attach, far)
	assert_true(want.size() > 0, "the chunk has contents")
	_free_build_rig(on_attach)

	var later := _make_contents_rig()
	var cm: ChunkManager = later["cm"]
	cm.set_lod_enabled(false)
	var clock := _make_fast(cm)
	_build_chunks(cm, [far])
	assert_true(cm.is_chunk_built(far), "built while the player is fast")
	assert_true(cm._near.is_waiting(far), "its contents wait")
	assert_eq(_contents_of(later, far).size(), 0, "nothing spawned on attach")
	cm._near.tick()
	assert_eq(_contents_of(later, far).size(), 0, "still fast and far: nothing spawns")
	clock[0] += ChunkManager.FAST_HOLD_MSEC
	cm._near.tick()
	assert_eq(_contents_of(later, far), want, "on slowing down the same ids spawn at the same places")
	assert_false(cm._near.is_waiting(far), "nothing waits any more")
	cm._near.tick()
	cm.request_rebuild(far)
	_wait_for_builds(cm)
	assert_eq(_contents_of(later, far), want, "a later tick and a rebuild spawn nothing twice")
	_free_build_rig(later)

func _test_near_contents_enter_ring() -> void:
	var rig := _make_contents_rig()
	var cm: ChunkManager = rig["cm"]
	var far := Vector2i(4, 0)
	cm.set_lod_enabled(false)   # Phase 194: the fast rule alone (a coarse chunk also waits for its upgrade)
	_make_fast(cm)
	_build_chunks(cm, [far, Vector2i(1, 0)])
	assert_false(cm._near.is_waiting(Vector2i(1, 0)), "a chunk in the near ring spawns on attach, fast or not")
	assert_true(cm._near.is_waiting(far), "a far chunk waits")
	_stand_in(rig["player"], Vector2i(3, 0))
	cm._near.tick()
	assert_false(cm._near.is_waiting(far), "entering the ring releases it while still fast")
	assert_true(_contents_of(rig, far).size() > 0, "and its contents spawn")
	_free_build_rig(rig)

## A fold carries the chunk roots across as stand-ins; one whose collision was parked must still get it
## when the body lands on it, or the body falls through until the folded chunk rebuilds.
func _test_near_collision_fold_standin() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	cm.set_lod_enabled(false)   # Phase 190: a far chunk is coarse and has no shape at all; parking is a full chunk's
	var voxel: VoxelSlice = rig["voxel"]
	var far := Vector2i(3, 0)
	_build_chunks(cm, [far])
	assert_true(voxel.has_parked_collision(far), "built away from the body: parked")
	var roots: Array = voxel.detach_standins()
	voxel.adopt_standins(roots, Transform3D.IDENTITY)
	assert_true(voxel.has_standin(far), "the root stands in for its own chunk (an identity fold)")
	assert_true(voxel.has_parked_collision(far), "the stand-in carries the parked shape")
	_stand_in(rig["player"], far)
	cm._near.tick()
	assert_false(voxel.has_parked_collision(far), "the body's tick attached it")
	var root: Node3D = voxel._standins[voxel._chunk_key(far)]
	assert_true(root.has_node("Collision"), "the stand-in under the body has its collision")
	_free_build_rig(rig)

## Phase 183 — a parked chunk beyond the local body's ring (since Phase 193, one a peer's ring reached after it
## was built) takes its collision one quadrant a near-ring step; the body's own chunk gets every quadrant at once.
func _test_near_collision_staggered() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	cm.set_lod_enabled(false)
	var voxel: VoxelSlice = rig["voxel"]
	_build_chunks(cm, [Vector2i(0, 0), Vector2i(2, 0)])
	var own: Node = voxel._chunks["0,0"].get_node("Collision")
	assert_true(own.get_child_count() > 1, "the chunk under the body was split (%d quadrants)" % own.get_child_count())
	assert_false(voxel.has_parked_collision(Vector2i(0, 0)), "and has every quadrant at once")
	assert_false(voxel._chunks["2,0"].has_node("Collision"), "two rings out: no collision on landing")
	assert_true(voxel.has_parked_collision(Vector2i(2, 0)), "it is parked")
	cm.set_peer_center(7, Vector2i(3, 0), true)
	cm.pump_budget_msec = 0
	cm.begin_pump()
	cm._near.tick()
	var body: Node = voxel._chunks["2,0"].get_node("Collision")
	assert_eq(body.get_child_count(), 1, "a peer's ring reaches it: one quadrant on the first step")
	var steps := 0
	while voxel.has_parked_collision(Vector2i(2, 0)) and steps < 8:
		var before := body.get_child_count()
		cm.begin_pump()
		cm._near.tick()
		assert_eq(body.get_child_count(), before + 1, "step %d adds one quadrant" % steps)
		steps += 1
	assert_false(voxel.has_parked_collision(Vector2i(2, 0)), "until none is left")
	assert_eq(body.get_child_count(), own.get_child_count(), "on one body, like the near chunk's")
	_free_build_rig(rig)

## Phase 183 — a chunk beside the body lands with one quadrant too (all four at once overran a walk's frame
## by ~6 ms on every chunk line), and the next near-ring tick gives it the rest while the pump budget lasts.
func _test_near_collision_neighbour() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	cm.set_lod_enabled(false)
	var voxel: VoxelSlice = rig["voxel"]
	_build_chunks(cm, [Vector2i(0, 0), Vector2i(1, 0)])
	var own: Node = voxel._chunks["0,0"].get_node("Collision")
	var side: Node = voxel._chunks["1,0"].get_node("Collision")
	assert_true(own.get_child_count() > 1, "the chunk under the body was split (%d quadrants)" % own.get_child_count())
	assert_eq(side.get_child_count(), 1, "beside the body: one quadrant on landing")
	assert_true(voxel.has_parked_collision(Vector2i(1, 0)), "the rest are parked")
	cm.pump_budget_msec = 0   # no time budget: the tick is bounded by what is parked
	cm.begin_pump()
	cm._near.tick()
	assert_false(voxel.has_parked_collision(Vector2i(1, 0)), "one tick attaches every quadrant left")
	assert_eq(side.get_child_count(), own.get_child_count(), "on one body, like the body's own chunk")
	_free_build_rig(rig)

func _test_collision_parts_split() -> void:
	var faces := PackedVector3Array()
	var half := float(VoxelSlice.CHUNK_SIZE) * VoxelSlice.TILE_SIZE * 0.5
	for i in 1200:   # 2,400 triangles across the chunk
		var x := float(i % 40) * 0.8
		var z := float(i / 40) * 1.0
		faces.append_array([Vector3(x, 1, z), Vector3(x + 0.5, 1, z), Vector3(x + 0.5, 1, z + 0.5),
			Vector3(x, 1, z), Vector3(x + 0.5, 1, z + 0.5), Vector3(x, 1, z + 0.5)])
	var parts := VoxelMesh.collision_parts(faces)
	assert_eq(parts.size(), 4, "a big soup is cut in four")
	var all := PackedVector3Array()
	for p in range(parts.size()):
		var f: PackedVector3Array = (parts[p] as ConcavePolygonShape3D).get_faces()
		assert_true((parts[p] as ConcavePolygonShape3D).backface_collision, "part %d collides on both sides" % p)
		for i in range(0, f.size(), 3):
			var q := (2 if f[i].z >= half else 0) + (1 if f[i].x >= half else 0)
			if q != p:
				assert_eq(q, p, "a triangle starting at %s is in its own quadrant" % f[i])
				break
		all.append_array(f)
	assert_eq(_tri_keys(all), _tri_keys(faces), "the parts hold exactly the soup's triangles")
	assert_eq(VoxelMesh.collision_parts(faces.slice(0, 300)), [], "a small soup stays one shape")

static func _tri_keys(faces: PackedVector3Array) -> Array:
	var out: Array = []
	for i in range(0, faces.size(), 3):
		out.append("%s|%s|%s" % [faces[i], faces[i + 1], faces[i + 2]])
	out.sort()
	return out

# ---------------------------------------------------------------------------
# Phase 194 — follow-up debt burn II (#504, #509, #512)
# ---------------------------------------------------------------------------

## #512 — the lane (the body's chunk and the ones ahead of it) first; a diagonal neighbour, the ground behind and a
## peer's own chunks by their distance from the nearest centre, not after the whole lane.
func _test_stream_lane_order() -> void:
	var centers: Array = [Vector2i(10, 0), Vector2i(20, 0)]
	var east := Vector2(1, 0)
	var k := func(c: Vector2i) -> float: return ChunkManager.queue_priority(centers, east, c, true)
	assert_true(k.call(Vector2i(10, 0)) < k.call(Vector2i(11, 0)), "the body's chunk, then the one ahead")
	assert_true(k.call(Vector2i(11, 0)) < k.call(Vector2i(11, 1)), "the lane before the diagonal beside it")
	assert_true(k.call(Vector2i(11, 1)) < k.call(Vector2i(14, 0)), "but a diagonal neighbour before the far lane")
	assert_true(k.call(Vector2i(9, 0)) < k.call(Vector2i(14, 0)), "and the chunk just behind the body too")
	assert_true(k.call(Vector2i(20, 1)) < k.call(Vector2i(14, 0)), "a peer's neighbour by its distance from the peer")
	# PR #529: at one lane chunk per ring, every nearer ring (behind the body too) went first, and a CI runner's
	# 270 m/s flight built none of the ground under the body.
	assert_true(k.call(Vector2i(15, 0)) < k.call(Vector2i(6, 0)), "the lane five ahead before the ground four behind")
	assert_true(k.call(Vector2i(15, 0)) < k.call(Vector2i(13, 4)), "and before a chunk four rings out beside the lane")
	var cm := ChunkManager.new()
	var clock := _make_fast(cm)
	assert_true(cm.is_moving_fast(), "fast")
	cm._last_centers = centers
	cm._builds = { 1: { "chunk": Vector2i(14, 0) }, 2: { "chunk": Vector2i(11, 1) }, 3: { "chunk": Vector2i(20, 0) }, 4: { "chunk": Vector2i(11, 0) } }
	assert_eq(cm._apply_order([1, 2, 3, 4]), [3, 4, 2, 1], "the peer's own chunk, the lane ahead, the diagonal, then the far lane")
	clock[0] += ChunkManager.FAST_HOLD_MSEC
	cm._builds.clear()
	cm.free()

## #512 — a queue sorted for the lane kept that order after the flyer stopped: the ground beside and behind it waited.
func _test_stream_queue_resorted_on_stop() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var player: PlayerSlice = rig["player"]
	cm.view_distance = 2
	cm.prefetch_distance = 0
	cm.refresh(false)
	var clock := _make_fast(cm)
	player.spawn_at(Vector3(32.0 + 16.0, 40.0, 16.0))
	cm.refresh(false)
	assert_true(cm._queue_in_lane, "a fast crossing sorts the queue for the lane")
	clock[0] += ChunkManager.FAST_HOLD_MSEC
	assert_false(cm.is_moving_fast(), "the flyer stopped")
	cm.refresh(false)   # the window did not move
	assert_false(cm._queue_in_lane, "the lane order is dropped")
	assert_eq(cm._load_queue[0], Vector2i(1, 0), "the queue starts under the body")
	var last := -1.0
	var sorted := true
	for c: Vector2i in cm._load_queue:
		var key := ChunkManager.queue_priority([Vector2i(1, 0)], Vector2.ZERO, c)
		sorted = sorted and key >= last
		last = key
	assert_true(sorted, "and runs by distance from it")
	_free_build_rig(rig)

## #504 — a parked shape lived in `_parked_shapes` and on a stand-in's meta at once; now the table is the one store,
## and the meta only carries a shape across a fold.
func _test_near_parked_one_store() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	cm.set_lod_enabled(false)
	var voxel: VoxelSlice = rig["voxel"]
	var far := Vector2i(3, 0)
	var gone := Vector2i(5, 0)
	_build_chunks(cm, [Vector2i(0, 0), far, gone])
	var both := func() -> Array:
		var out: Array = []
		for key in voxel._parked_shapes:
			for node in [voxel._chunks.get(key), voxel._standins.get(key)]:
				if node != null and is_instance_valid(node) and (node as Node3D).has_meta("parked_shape"):
					out.append(key)
		for key in voxel._standins:
			if is_instance_valid(voxel._standins[key]) and (voxel._standins[key] as Node3D).has_meta("parked_shape"):
				out.append(key)
		return out
	assert_true(voxel.has_parked_collision(far) and voxel.has_parked_collision(gone), "built away from the body: parked")
	assert_eq(both.call(), [], "after the build: one store")
	voxel.adopt_standins(voxel.detach_standins(), Transform3D.IDENTITY)
	assert_true(voxel.has_standin(far) and voxel.has_parked_collision(far), "the fold carried the shape to the stand-in's chunk")
	assert_eq(both.call(), [], "after the fold: one store, no meta left")
	voxel.prune_standins(func(c: Vector2i) -> bool: return c != gone)
	assert_false(voxel.has_parked_collision(gone), "a pruned stand-in takes its parked shape with it")
	_stand_in(rig["player"], far)
	cm._near.tick()
	assert_false(voxel.has_parked_collision(far), "the body's tick attached it")
	assert_eq(both.call(), [], "after the attach: one store")
	assert_true((voxel._standins[voxel._chunk_key(far)] as Node3D).has_node("Collision"), "on the stand-in")
	_free_build_rig(rig)

## #504 — the near ring rescanned (and allocated) the parked list every frame; now only when a body moved or a shape
## was parked since a scan that found nothing due.
func _test_near_scan_idle_skip() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	cm.set_lod_enabled(false)
	var voxel: VoxelSlice = rig["voxel"]
	_build_chunks(cm, [Vector2i(0, 0), Vector2i(3, 0)])
	cm._near.tick()
	assert_false(cm._near._idle_scan.is_empty(), "nothing due: the scan's inputs are kept")
	var idle: Array = cm._near._idle_scan
	cm._near.tick()
	assert_eq(cm._near._idle_scan, idle, "an unchanged frame skips the scan")
	_build_chunks(cm, [Vector2i(1, 0)])
	assert_true(voxel.has_parked_collision(Vector2i(1, 0)), "a chunk beside the body parks its other quadrants")
	cm.pump_budget_msec = 0
	cm.begin_pump()
	cm._near.tick()
	assert_false(voxel.has_parked_collision(Vector2i(1, 0)), "the new parked shape is scanned and attached without the body moving")
	_free_build_rig(rig)

## #504 — with the ring switched off every waiting chunk released at once on the next tick, inside the record flight's
## measured window; it is flushed at the toggle now.
func _test_near_toggle_flushes_waiting() -> void:
	var rig := _make_contents_rig()
	var cm: ChunkManager = rig["cm"]
	cm.set_lod_enabled(false)
	var far := Vector2i(4, 0)
	_make_fast(cm)
	_build_chunks(cm, [far])
	assert_true(cm._near.is_waiting(far), "a far chunk waits while the body is fast")
	cm.set_near_ring_enabled(false)
	assert_eq(cm._near.waiting_count(), 0, "the toggle releases every waiting chunk")
	assert_true(cm._contents_spawned.has(cm._chunk_key(far)), "and spawns its contents then")
	cm.set_near_ring_enabled(true)
	_free_build_rig(rig)
