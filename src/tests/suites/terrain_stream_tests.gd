extends "res://src/tests/test_support.gd"
## Phase 141 — terrain streaming off the main thread: the static heightmap generator, the seam
## edge strips, the polar shortcuts, the worker-noise build and the fold catch-up.
## Phase 187 — build priority and the load queue's order at speed.

func register() -> void:
	_run_test("stream: the static generator matches generate_heightmap", _test_stream_static_generator_matches)
	_run_test("stream: a seam strip is the full map's edge and nothing else", _test_stream_seam_strip_is_edge)
	_run_test("stream: the polar row memo and shelf shortcut change no height", _test_stream_polar_shortcuts_exact)
	_run_test("stream: a deferred gather builds the same chunk as a full one", _test_stream_deferred_gather_same_build)
	_run_test("stream: a dispatch generates no map on the main thread", _test_stream_dispatch_no_main_thread_noise)
	_run_test("stream: a frame's pump stops at its time budget and bounds its applies", _test_stream_pump_budget)
	_run_test("stream: the steady build cap defaults to the core count minus one", _test_stream_builds_in_flight_default)
	_run_test("stream: a restream bursts the build cap until the window is rebuilt", _test_stream_fold_catchup)
	_run_test("stream: every chunk build is dispatched at high priority", _test_stream_builds_high_priority)
	_run_test("stream: the queue key puts the body's chunk first and favours the heading", _test_stream_queue_priority)
	_run_test("stream: a crossing re-sorts the whole queue around the new centre", _test_stream_queue_resorted_on_move)
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
	assert_true(cs.creatures_in_radius(after, 0.5).has(iid), "and in the spatial hash")
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
	var want := TerrainSlice.fold_world_vec_like(TerrainSlice.fold_world_vec_like(host, true, 1), true, -1)
	assert_true(cs.get_instance_position("c0").distance_to(want) < 0.01, "a host position is replayed through both folds, oldest first")
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
	cs._hold_death_record("d0", { "state": "dead", "creature_id": "ForestBoar",
		"respawn_at": Time.get_unix_time_from_system() + 600.0, "position": WorldPos.to_wire(at) })
	assert_true(cs._dead_state.has("d0"), "the death is held")
	cs.fold_contents(true, 1)
	var got: Vector3 = WorldPos.from_wire(cs._dead_state["d0"]["position"])
	assert_true(got.distance_to(TerrainSlice.fold_world_vec_like(at, true, 1)) < 0.01, "its position is the fold's image")
	cs.free()

## Phase 187 — a low-priority task may use only `low_priority_thread_ratio` of the pool, which held the
## steady stream to three or four threads; both dispatch paths now pass high priority.
func _test_stream_builds_high_priority() -> void:
	assert_true(ChunkManager.BUILD_HIGH_PRIORITY, "chunk builds run at high priority")
	for path in ["res://src/terrain/chunk_manager.gd", "res://src/terrain/chunk_part_1.gd"]:
		var src := FileAccess.get_file_as_string(path)
		assert_false(src.contains("add_task(job, false") or src.contains("add_task(job, _catchup"),
			"%s dispatches no build at low priority" % path)

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
