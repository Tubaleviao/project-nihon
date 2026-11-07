extends "res://src/tests/test_support.gd"
## Phase 217 — static lakes and rivers: the field, its determinism, the stable-world rule, swimming and paths.

const Hydrology := preload("res://src/terrain/hydrology.gd")
const ChunkRecords := preload("res://src/terrain/chunk_records.gd")
const FreshWaterMesh := preload("res://src/terrain/fresh_water_mesh.gd")
const ChunkPart1 := preload("res://src/terrain/chunk_part_1.gd")
const CreaturePath := preload("res://src/creature/creature_path.gd")
const SEED := 42
## A pinned 64×64-chunk window (2 km square) on seed 42 that holds both a lake and a river.
const WINDOW := Vector2i(0, -256)

func register() -> void:
	_run_test("hydrology: a pinned window holds a lake and a river", _test_window_has_water)
	_run_test("hydrology: a river never climbs and widens downstream", _test_river_downhill)
	_run_test("hydrology: the field is deterministic, also on a worker thread", _test_deterministic)
	_run_test("hydrology: a chunk recorded by an older generator gets no water", _test_recorded_chunk_dry)
	_run_test("hydrology: the spawn plain stays dry", _test_spawn_dry)
	_run_test("hydrology: carving lowers water tiles to their bed and nothing else", _test_carve)
	_run_test("hydrology: a body in a lake swims", _test_player_swims_in_lake)
	_run_test("hydrology: a non-swimming creature path avoids a river", _test_creature_path_avoids_river)
	_run_test("hydrology: the fresh-water mesh covers exactly the wet tiles", _test_fresh_water_mesh)
	_run_test("hydrology (#573): a reset clears the caches and their counters; a record loaded later dries a cached chunk", _test_cache_reset)
	_run_test("hydrology (#573): a creature fords a narrow river, not a wide one or a lake", _test_ford_width)
	_run_test("hydrology (#573): fresh water in a frozen chunk is ice, like the sea", _test_fresh_water_ice)
	_run_test("hydrology: a streamed build carries its fresh-water arrays from the worker", _test_fresh_water_worker_arrays)

func _window_features() -> Dictionary:
	var lakes := []
	var segs := []
	for cz in 64:
		for cx in 64:
			var f := Hydrology.features_for_chunk(Vector2i(WINDOW.x + cx, WINDOW.y + cz), SEED)
			lakes.append_array(f["lakes"])
			segs.append_array(f["segs"])
	return { "lakes": lakes, "segs": segs }

func _test_window_has_water() -> void:
	var f := _window_features()
	assert_true(f["lakes"].size() >= 1, "the window holds a lake")
	assert_true(f["segs"].size() >= 1, "the window holds a river")

## Every river of the cells around the window: surfaces never rise downstream, widths never narrow.
func _test_river_downhill() -> void:
	var cm := 32.0
	var checked := 0
	for cz in range(floori(WINDOW.y * cm / 1024.0) - 2, floori((WINDOW.y + 64) * cm / 1024.0) + 3):
		for cx in range(floori(WINDOW.x * cm / 1024.0) - 2, floori((WINDOW.x + 64) * cm / 1024.0) + 3):
			var rv := Hydrology.river_of_cell(SEED, cx, cz)
			if rv.is_empty():
				continue
			checked += 1
			var surf: PackedFloat64Array = rv["surf"]
			var wid: PackedFloat64Array = rv["wid"]
			for i in range(1, surf.size()):
				assert_true(surf[i] <= surf[i - 1] + 1e-9, "river cell %d is at or below its upstream neighbour" % i)
				assert_true(wid[i] >= wid[i - 1] - 1e-9, "river cell %d is no narrower than upstream" % i)
	assert_true(checked >= 1, "at least one river was checked")

func _test_deterministic() -> void:
	var chunk := Vector2i(WINDOW.x + 5, WINDOW.y + 5)
	var a := Hydrology.surfaces_for_chunk(chunk, SEED)
	var fa := _window_features()
	Hydrology.reset_cache()
	var b := Hydrology.surfaces_for_chunk(chunk, SEED)
	var fb := _window_features()
	assert_eq(str(fa), str(fb), "the same features twice")
	assert_eq(a.to_byte_array(), b.to_byte_array(), "the same surfaces twice")
	Hydrology.reset_cache()
	var out := { "f": null }
	var t := Thread.new()
	t.start(func() -> void: out["f"] = _window_features())
	t.wait_to_finish()
	assert_eq(str(out["f"]), str(fa), "a worker thread computes the same field")

## First chunk of the window with fresh water in it.
func _wet_chunk() -> Vector2i:
	for cz in 64:
		for cx in 64:
			var c := Vector2i(WINDOW.x + cx, WINDOW.y + cz)
			var s := Hydrology.surfaces_for_chunk(c, SEED)
			for v in s:
				if not is_nan(v):
					return c
	return Vector2i.ZERO

func _test_recorded_chunk_dry() -> void:
	var chunk := _wet_chunk()
	var wet := Hydrology.surfaces_for_chunk(chunk, SEED)
	var tiles := 0
	for v in wet:
		tiles += 0 if is_nan(v) else 1
	assert_true(tiles > 0, "the chunk is wet before it is recorded")
	var hm: Array = []
	hm.resize(4096)
	hm.fill(500.0)
	var plain := hm.duplicate()
	ChunkRecords.clear()
	var old := TerrainSlice.generation_record(chunk, SEED)
	old["v"] = Hydrology.HYDROLOGY_VERSION - 1
	ChunkRecords.set_record(chunk, old)
	for v in Hydrology.surfaces_for_chunk(chunk, SEED):
		assert_true(is_nan(v), "no water voxel in a chunk recorded before hydrology")
	Hydrology.carve(chunk, SEED, hm)
	assert_eq(hm, plain, "the ground of a recorded chunk is byte-identical after carving")
	# A record written by this generator keeps its water.
	var cur := TerrainSlice.generation_record(chunk, SEED)
	ChunkRecords.set_record(chunk, cur)
	assert_eq(Hydrology.surfaces_for_chunk(chunk, SEED).to_byte_array(), wet.to_byte_array(), "a current record keeps its lake")
	ChunkRecords.clear()

func _test_spawn_dry() -> void:
	for cz in range(-8, 8):
		for cx in range(-8, 8):
			for v in Hydrology.surfaces_for_chunk(Vector2i(cx, cz), SEED):
				assert_true(is_nan(v), "no fresh water on the spawn plain")

func _test_carve() -> void:
	var chunk := _wet_chunk()
	var surf := Hydrology.surfaces_for_chunk(chunk, SEED)
	var hm: Array = []
	hm.resize(4096)
	hm.fill(10000.0)
	Hydrology.carve(chunk, SEED, hm)
	for i in 4096:
		if is_nan(surf[i]):
			assert_eq(hm[i], 10000.0, "a dry tile is untouched")
		else:
			assert_true(float(hm[i]) < surf[i], "a water tile is carved below its surface")

func _first_lake() -> Dictionary:
	return _window_features()["lakes"][0]

func _test_player_swims_in_lake() -> void:
	var lk := _first_lake()
	var level := Hydrology.surface_at(SEED, lk["x"], lk["z"])
	assert_false(is_nan(level), "the lake centre is water")
	var bed := Hydrology.carved_height(SEED, lk["x"], lk["z"], 1.0e6)
	assert_true(PlayerSlice.is_swimming(bed, level), "a body over the lake bed swims")
	var terrain := TerrainSlice.new()
	terrain.set_world_seed(SEED)
	var player := PlayerSlice.new()
	player.terrain_slice = terrain
	assert_eq(Hydrology.level_for(terrain, lk["x"], lk["z"]), level, "the player floats on the lake's level, not the sea's")
	assert_eq(Hydrology.level_for(terrain, WorldShape.SPAWN_CENTER.x, WorldShape.SPAWN_CENTER.y), WorldShape.sea_level(), "dry land reads the sea level")
	player.free()
	terrain.free()

func _test_creature_path_avoids_river() -> void:
	var sg: Array = _window_features()["segs"][0]
	var a := Vector2(sg[0], sg[1])
	var b := Vector2(sg[2], sg[3])
	var mid := (a + b) * 0.5
	var dir := (b - a).normalized()
	var n := Vector2(-dir.y, dir.x)
	var ts := 0.5
	var off := float(sg[6]) + 3.0
	var from_t := Vector2i(roundi((mid - n * off).x / ts), roundi((mid - n * off).y / ts))
	var to_t := Vector2i(roundi((mid + n * off).x / ts), roundi((mid + n * off).y / ts))
	var wet := func(tile: Vector2i) -> bool:
		return not is_nan(Hydrology.surface_at(SEED, (float(tile.x) + 0.5) * ts, (float(tile.y) + 0.5) * ts))
	assert_false(bool(wet.call(from_t)) or bool(wet.call(to_t)), "both ends are on dry ground")
	var rules := { "max_step": 100.0, "can_swim": false, "radius": 60, "sea_level": -1000.0, "lap_tiles": 0, "fresh_water": wet }
	var flat := func(_t: Vector2i) -> float: return 10.0
	var info := CreaturePath.search(from_t, to_t, rules, flat)
	for t in info["path"]:
		assert_false(bool(wet.call(t)), "a path tile is never in the river")
	var swim := rules.duplicate()
	swim["can_swim"] = true
	var s := CreaturePath.search(from_t, to_t, swim, flat)
	assert_true(s["reached"], "a swimmer crosses the same river")

func _test_fresh_water_mesh() -> void:
	var chunk := _wet_chunk()
	var surf := Hydrology.surfaces_for_chunk(chunk, SEED)
	var mesh := FreshWaterMesh.mesh_for(chunk, surf, true)
	assert_true(mesh != null, "a wet chunk has a fresh-water mesh")
	var wet := 0
	for v in surf:
		wet += 0 if is_nan(v) else 1
	var area := 0.0
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for i in range(0, verts.size(), 4):
		area += (verts[i + 1].x - verts[i].x) * (verts[i + 3].z - verts[i].z)
	assert_true(absf(area - float(wet) * 0.25) < 1e-6, "the mesh area is the wet tiles' area")
	var dry := PackedFloat64Array()
	dry.resize(4096)
	dry.fill(NAN)
	assert_true(FreshWaterMesh.mesh_for(chunk, dry, true) == null, "a dry chunk has none")
	mesh = null

func _test_cache_reset() -> void:
	var chunk := _wet_chunk()
	var wet := Hydrology.surfaces_for_chunk(chunk, SEED)
	assert_true(Hydrology._features_n > 0 and Hydrology._rivers_n > 0, "reading a chunk fills both caches")
	Hydrology.reset_cache()
	assert_eq([Hydrology._features_n, Hydrology._rivers_n], [0, 0], "a reset zeroes both counters")
	assert_true(Hydrology._features.is_empty() and Hydrology._rivers.is_empty(), "and empties both stores")
	assert_eq(Hydrology.surfaces_for_chunk(chunk, SEED).to_byte_array(), wet.to_byte_array(), "the field rebuilds the same")
	# The feature cache now holds this chunk; a record from before hydrology still dries it at once.
	ChunkRecords.clear()
	var old := TerrainSlice.generation_record(chunk, SEED)
	old["v"] = Hydrology.HYDROLOGY_VERSION - 1
	ChunkRecords.set_record(chunk, old)
	assert_true(Hydrology.features_for_chunk(chunk, SEED)["lakes"].is_empty() and Hydrology.features_for_chunk(chunk, SEED)["segs"].is_empty(),
		"a cached chunk recorded later by an older generator has no features")
	ChunkRecords.clear()
	assert_eq(Hydrology.surfaces_for_chunk(chunk, SEED).to_byte_array(), wet.to_byte_array(), "and its water returns with the record gone")

func _test_ford_width() -> void:
	assert_false(CreaturePath.blocks_water(0.0, 6.0), "dry ground never blocks")
	assert_false(CreaturePath.blocks_water(4.0, 6.0), "a 4 m stream is forded")
	assert_true(CreaturePath.blocks_water(12.0, 6.0), "a 12 m river blocks")
	assert_true(CreaturePath.blocks_water(INF, 6.0), "a lake blocks")
	assert_true(CreaturePath.blocks_water(4.0, 0.0), "with no ford width every river blocks")
	assert_true(CreaturePath.blocks_water(true, 6.0) and not CreaturePath.blocks_water(false, 6.0), "a bool water test still works")
	var sg: Array = _window_features()["segs"][0]
	var mid := Vector2((float(sg[0]) + float(sg[2])) * 0.5, (float(sg[1]) + float(sg[3])) * 0.5)
	var width := Hydrology.water_width_at(SEED, mid.x, mid.y)
	assert_true(width > 0.0 and width < INF, "a river point reports its width (%.1f m)" % width)
	var lk: Dictionary = _window_features()["lakes"][0]
	assert_eq(Hydrology.water_width_at(SEED, float(lk["x"]), float(lk["z"])), INF, "a lake centre reports no ford")
	assert_eq(Hydrology.water_width_at(SEED, WorldShape.SPAWN_CENTER.x, WorldShape.SPAWN_CENTER.y), 0.0, "dry land reports 0")
	# A path across a band of shallow water 4 m wide: forded with a 6 m ford, refused without one.
	var band := func(tile: Vector2i) -> float: return 4.0 if tile.x >= 5 and tile.x <= 12 else 0.0
	var flat := func(_t: Vector2i) -> float: return 10.0
	var rules := { "max_step": 100.0, "can_swim": false, "radius": 30, "sea_level": -1000.0, "lap_tiles": 0, "fresh_water": band, "ford_width_m": 6.0 }
	assert_true(CreaturePath.search(Vector2i(0, 0), Vector2i(20, 0), rules, flat)["reached"], "a creature fords the stream")
	rules["ford_width_m"] = 0.0
	rules["radius"] = 12
	assert_false(CreaturePath.search(Vector2i(0, 0), Vector2i(20, 0), rules, flat)["reached"], "without a ford it cannot cross")
	assert_eq(CreatureAI.FORD_WIDTH_M, 6.0, "creatures ford rivers under 6 m")

func _test_fresh_water_ice() -> void:
	var src := FileAccess.get_file_as_string("res://src/terrain/voxel_build.gd")
	var at := src.find("fresh_inst.material_override")
	assert_true(at >= 0 and src.substr(at, 120).contains("_ice_material() if s.is_frozen_chunk(chunk_pos)"),
		"the fresh-water surface takes the ice material in a frozen chunk, like the sea")

func _test_fresh_water_worker_arrays() -> void:
	var chunk := _wet_chunk()
	var main_side := FreshWaterMesh.arrays_for(chunk, Hydrology.surfaces_for_chunk(chunk, SEED), true)
	var out: Array = [null]
	var task := WorkerThreadPool.add_task(func() -> void:
		var built := { "local": true }
		ChunkPart1._add_fresh_water(built, chunk, SEED, true)
		out[0] = built)
	WorkerThreadPool.wait_for_task_completion(task)
	var built: Dictionary = out[0]
	assert_true(built.has("fresh_water"), "the worker adds the fresh-water arrays to the build")
	assert_eq((built["fresh_water"] as Array)[Mesh.ARRAY_VERTEX], main_side[Mesh.ARRAY_VERTEX], "the same surface as a main-thread build")
	assert_true(FreshWaterMesh.mesh_from(built["fresh_water"]) != null, "attach only wraps them in a mesh")
	var headless := { "local": true }
	ChunkPart1._add_fresh_water(headless, chunk, SEED, false)
	assert_false(headless.has("fresh_water"), "a build that keeps no render arrays carries none")
	assert_true(FreshWaterMesh.mesh_from([]) == null, "a dry chunk's empty arrays make no mesh")
