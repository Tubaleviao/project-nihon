extends "res://src/tests/test_support.gd"
## Phase 141 — terrain streaming off the main thread: the static heightmap generator, the seam
## edge strips, the polar shortcuts, the worker-noise build and the fold catch-up.

func register() -> void:
	_run_test("stream: the static generator matches generate_heightmap", _test_stream_static_generator_matches)
	_run_test("stream: a seam strip is the full map's edge and nothing else", _test_stream_seam_strip_is_edge)
	_run_test("stream: the polar row memo and shelf shortcut change no height", _test_stream_polar_shortcuts_exact)
	_run_test("stream: a deferred gather builds the same chunk as a full one", _test_stream_deferred_gather_same_build)
	_run_test("stream: a dispatch generates no map on the main thread", _test_stream_dispatch_no_main_thread_noise)
	_run_test("stream: a restream bursts the build cap until the window is rebuilt", _test_stream_fold_catchup)

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
	return lerpf(h, TerrainSlice.pole_field(seed_v, from_pole, lat >= 0.0, w), t)

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
