extends "res://src/tests/test_support.gd"
## Phase 217 — static lakes and rivers: the field, its determinism, the stable-world rule, swimming and paths.

const Hydrology := preload("res://src/terrain/hydrology.gd")
const ChunkRecords := preload("res://src/terrain/chunk_records.gd")
const FreshWaterMesh := preload("res://src/terrain/fresh_water_mesh.gd")
const ChunkBuildQueue := preload("res://src/terrain/chunk_build_queue.gd")
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
	_run_test("hydrology (Phase 232): no lake disc or river segment overlaps the spawn plain on 20 seeds", _test_spawn_plain_extent)
	_run_test("hydrology (Phase 232): a chunk with no features makes no fresh-water arrays or node", _test_no_features_no_water)
	_run_test("hydrology: carving lowers water tiles to their bed and nothing else", _test_carve)
	_run_test("hydrology: a body in a lake swims", _test_player_swims_in_lake)
	_run_test("hydrology: a non-swimming creature path avoids a river", _test_creature_path_avoids_river)
	_run_test("hydrology: the fresh-water mesh covers exactly the wet tiles", _test_fresh_water_mesh)
	_run_test("hydrology (#573): a reset clears the caches and their counters; a record loaded later dries a cached chunk", _test_cache_reset)
	_run_test("hydrology (#573): a creature fords a narrow river, not a wide one or a lake", _test_ford_width)
	_run_test("hydrology (#573): fresh water in a frozen chunk is ice, like the sea", _test_fresh_water_ice)
	_run_test("hydrology: a streamed build carries its fresh-water arrays from the worker", _test_fresh_water_worker_arrays)
	_run_test("hydrology (Phase 232, #573): the rim of 50 lakes has no ground under its surface and no shore step over 0.5 m", _test_lake_shores)
	_run_test("hydrology (Phase 232, #573): an older recorded chunk beside a lake meets its water with no step over 0.5 m", _test_frontier_water)
	_run_test("hydrology (Phase 232 review): a chunk recorded at 12 to 17 keeps the lake and ground it had; unrecorded land gets the shore", _test_recorded_lake_versions)
	_run_test("hydrology (Phase 232 review): a lake meets an older recorded chunk's water at one level", _test_frontier_legacy_water)
	_run_test("hydrology (Phase 232 review): the spawn extents and the river cell are chosen by the chunk's record version", _test_spawn_and_river_tiers)
	_run_test("hydrology (Phase 232): the freeboard and maximum levee are fabric parameters, and the fingerprint reads them", _test_levee_params)
	_run_test("hydrology: a point query reads its block and agrees with its chunk", _test_surface_at_blocks)

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

func _test_spawn_plain_extent() -> void:
	var c := WorldShape.SPAWN_CENTER
	var bad := 0
	var lakes := 0
	var segs := 0
	var reach := int(ceil((WorldShape.SPAWN_PLAIN_M + 2000.0) / TerrainSlice.CHUNK_METERS))
	for seed_v in range(1, 21):
		var cc := Vector2i(floori(c.x / TerrainSlice.CHUNK_METERS), floori(c.y / TerrainSlice.CHUNK_METERS))
		for dz in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var f := Hydrology.features_for_chunk(cc + Vector2i(dx, dz), seed_v)
				for lk in f["lakes"]:
					lakes += 1
					if Vector2(float(lk["x"]) - c.x, float(lk["z"]) - c.y).length() - float(lk["r"]) < WorldShape.SPAWN_PLAIN_M:
						bad += 1
				for sg in f["segs"]:
					segs += 1
					var d := Geometry2D.get_closest_point_to_segment(c, Vector2(sg[0], sg[1]), Vector2(sg[2], sg[3])).distance_to(c)
					if d < WorldShape.SPAWN_PLAIN_M:
						bad += 1
	assert_eq(bad, 0, "no lake disc or river segment reaches the spawn plain (%d lakes, %d segments seen)" % [lakes, segs])


func _test_no_features_no_water() -> void:
	var dry := Vector2i(0, 0)   # the spawn plain: no feature
	assert_true(Hydrology.features_for_chunk(dry, SEED)["lakes"].is_empty(), "the spawn chunk holds no lake")
	assert_true(FreshWaterMesh.worker_arrays(dry, SEED, false).is_empty(), "no features, no fresh-water arrays")
	assert_true(FreshWaterMesh.mesh_from(FreshWaterMesh.worker_arrays(dry, SEED, false)) == null, "no fresh-water mesh")
	var wet := _wet_chunk()
	assert_false(FreshWaterMesh.worker_arrays(wet, SEED, false).is_empty(), "a wet chunk still builds its water")


func _test_carve() -> void:
	var chunk := _wet_chunk()
	var surf := Hydrology.surfaces_for_chunk(chunk, SEED)
	var hm: Array = []
	hm.resize(4096)
	hm.fill(10000.0)
	Hydrology.carve(chunk, SEED, hm)
	# Phase 302: a river's soft bank also lowers dry tiles within its reach, but never below its water.
	var segs: Array = Hydrology.features_for_chunk(chunk, SEED)["segs"]
	var ox := float(chunk.x) * TerrainSlice.CHUNK_METERS
	var oz := float(chunk.y) * TerrainSlice.CHUNK_METERS
	var ok_dry := true
	var ok_wet := true
	var banks := 0
	for i in 4096:
		if not is_nan(surf[i]):
			ok_wet = ok_wet and float(hm[i]) < surf[i]
			continue
		if float(hm[i]) == 10000.0:
			continue
		var p := Vector2(ox + float(i % 64) * TerrainSlice.TILE_SIZE, oz + float(i / 64) * TerrainSlice.TILE_SIZE)
		var water := INF
		for sg in segs:
			var a := Vector2(sg[0], sg[1])
			var b := Vector2(sg[2], sg[3])
			if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= float(sg[6]) + Hydrology.BANK_REACH_M:
				water = minf(water, minf(float(sg[4]), float(sg[5])))
		ok_dry = ok_dry and float(hm[i]) <= 10000.0 and float(hm[i]) >= water - 0.001
		banks += 1
	assert_true(ok_wet, "a water tile is carved below its surface")
	assert_true(ok_dry, "a dry tile is untouched, or lowered by a river's bank no lower than its water (%d bank tiles)" % banks)

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
	var ts := 0.5
	var wet := func(tile: Vector2i) -> bool:
		return not is_nan(Hydrology.surface_at(SEED, (float(tile.x) + 0.5) * ts, (float(tile.y) + 0.5) * ts))
	# The window's first segment with dry ground just past both banks (Phase 302: the features also list segments
	# whose banks only reach the window, so the first one may run beside another).
	var from_t := Vector2i.ZERO
	var to_t := Vector2i.ZERO
	var found := false
	for sg: Array in _window_features()["segs"]:
		var a := Vector2(sg[0], sg[1])
		var b := Vector2(sg[2], sg[3])
		var mid := (a + b) * 0.5
		var dir := (b - a).normalized()
		var n := Vector2(-dir.y, dir.x)
		var off := float(sg[6]) + 3.0
		from_t = Vector2i(roundi((mid - n * off).x / ts), roundi((mid - n * off).y / ts))
		to_t = Vector2i(roundi((mid + n * off).x / ts), roundi((mid + n * off).y / ts))
		if not is_nan(Hydrology.surface_at(SEED, mid.x, mid.y)) and not bool(wet.call(from_t)) and not bool(wet.call(to_t)):
			found = true
			break
	assert_true(found, "both ends are on dry ground")
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
	assert_eq([Hydrology._features_n, Hydrology._rivers_n, Hydrology._blocks_n], [0, 0, 0], "a reset zeroes every counter")
	assert_true(Hydrology._features.is_empty() and Hydrology._rivers.is_empty() and Hydrology._blocks.is_empty(), "and empties every store")
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
	# The AI hands its paths the slice's width query and the ford width.
	var c := CreatureSlice.new()
	var ai := CreatureAI.new()
	ai.creature_slice = c
	var ai_rules := ai._path_rules_of("")
	assert_true(ai_rules.get("fresh_water") is Callable and (ai_rules["fresh_water"] as Callable).get_method() == &"fresh_water_width",
		"a creature path reads the fresh water's width")
	assert_eq(float(ai_rules.get("ford_width_m", 0.0)), CreatureAI.FORD_WIDTH_M, "and fords under FORD_WIDTH_M")
	var ts := TerrainSlice.TILE_SIZE
	var lake_tile := Vector2i(floori(float(lk["x"]) / ts), floori(float(lk["z"]) / ts))
	assert_eq(c.fresh_water_width(lake_tile), Hydrology.water_width_at(0, (float(lake_tile.x) + 0.5) * ts, (float(lake_tile.y) + 0.5) * ts),
		"the slice's width is Hydrology's at the tile centre")
	ai.free()
	c.free()

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
		ChunkBuildQueue._add_fresh_water(built, chunk, SEED, true)
		out[0] = built)
	WorkerThreadPool.wait_for_task_completion(task)
	var built: Dictionary = out[0]
	assert_true(built.has("fresh_water"), "the worker adds the fresh-water arrays to the build")
	assert_eq((built["fresh_water"] as Array)[Mesh.ARRAY_VERTEX], main_side[Mesh.ARRAY_VERTEX], "the same surface as a main-thread build")
	assert_true(FreshWaterMesh.mesh_from(built["fresh_water"]) != null, "attach only wraps them in a mesh")
	var headless := { "local": true }
	ChunkBuildQueue._add_fresh_water(headless, chunk, SEED, false)
	assert_false(headless.has("fresh_water"), "a build that keeps no render arrays carries none")
	assert_true(FreshWaterMesh.mesh_from([]) == null, "a dry chunk's empty arrays make no mesh")

## The distant ring samples one point in thousands of far chunks per rebuild: `surface_at` answers each from
## the cached features of its BLOCK_M block, the same water its chunk's features give, building one
## feature set per block instead of one per chunk.
func _test_surface_at_blocks() -> void:
	Hydrology.reset_cache()
	var wet := 0
	var cm := TerrainSlice.CHUNK_METERS
	for i in 4096:
		# a 2 km window, every point in another chunk and off the tile grid
		var x := float(WINDOW.x) * cm + float(i % 64) * cm + 0.37 * cm + float(i % 7) * 3.1
		var z := float(WINDOW.y) * cm + float(i / 64) * cm + 0.61 * cm + float(i % 5) * 2.3
		var by_chunk := Hydrology.water_at(Hydrology.features_for_chunk(Vector2i(floori(x / cm), floori(z / cm)), SEED), x, z)
		var s := Hydrology.surface_at(SEED, x, z)
		if by_chunk.is_empty():
			if not is_nan(s):
				assert_true(false, "dry at (%.1f, %.1f) by its chunk, %.2f by its block" % [x, z, s])
				return
		else:
			wet += 1
			if s != float(by_chunk["surface"]):
				assert_eq(s, float(by_chunk["surface"]), "the block's surface at (%.1f, %.1f) is its chunk's" % [x, z])
				return
	assert_true(wet > 0, "the window's samples cross water")
	assert_true(Hydrology._blocks_n <= 25, "4096 chunks of a 2 km window read %d blocks (at most 25)" % Hydrology._blocks_n)
	Hydrology.reset_cache()

## The first `n` lakes (with a shore) on SEED, scanning the lake cells east of the window.
func _shore_lakes(n: int) -> Array:
	var out: Array = []
	var cz := WINDOW.y * 32 / 512 - 4
	while out.size() < n and cz < WINDOW.y * 32 / 512 + 80:
		for cx in range(-4, 80):
			var lk := Hydrology.lake_of_cell(SEED, cx, cz)
			if not lk.is_empty():
				out.append(lk)
				if out.size() >= n:
					break
		cz += 1
	return out

func _test_lake_shores() -> void:
	ChunkRecords.clear()
	var noise := FastNoiseLite.new()
	TerrainSlice.configure_noise(noise, SEED)
	var w := float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS
	var cache := TerrainSlice.new_corner_cache()
	var lakes := _shore_lakes(50)
	assert_eq(lakes.size(), 50, "the pinned seed holds 50 lakes in the scanned cells")
	var worst_step := 0.0
	var under := 0
	for lk in lakes:
		var r := float(lk["r"])
		var surface := float(lk["surface"])
		for i in 16:
			var dir := Vector2.from_angle(TAU * (float(i) + 0.3) / 16.0)
			for out in [0.5, 1.0, 2.0, 4.0, 8.0, 16.0, 24.0, 27.0]:   # past 28 m the shore fades into the plain ground (LAKE_SHORE_FADE_M)
				var p := Vector2(float(lk["x"]), float(lk["z"])) + dir * (r + float(out))
				var g := TerrainSlice.height_wrapped_in(SEED, noise, p.x, p.y, w, cache, [])
				var segs: Array = Hydrology.features_for_chunk(Vector2i(floori(p.x / 32.0), floori(p.y / 32.0)), SEED)["segs"]
				if Hydrology.soft_carve(segs, p.x, p.y, g) != g:
					continue   # a river running into the lake lowers the ground on purpose
				if Hydrology.carved_height(SEED, p.x, p.y, g) < surface - 0.002:
					under += 1
			var pin := Vector2(float(lk["x"]), float(lk["z"])) + dir * (r - 0.25)
			var pout := Vector2(float(lk["x"]), float(lk["z"])) + dir * (r + 0.25)
			var hin := Hydrology.carved_height(SEED, pin.x, pin.y, TerrainSlice.height_wrapped_in(SEED, noise, pin.x, pin.y, w, cache, []))
			var hout := Hydrology.carved_height(SEED, pout.x, pout.y, TerrainSlice.height_wrapped_in(SEED, noise, pout.x, pout.y, w, cache, []))
			worst_step = maxf(worst_step, absf(hout - hin))
	assert_eq(under, 0, "no ground sample outside a lake's disc lies below its surface")
	assert_true(worst_step <= 0.5, "the ground across the waterline steps at most 0.5 m (worst %.3f)" % worst_step)
	# Phase 232 review: no step at the shore's outer edge. Just inside LAKE_REACH_M the carved ground is the plain ground.
	var edge := 0.0
	for lk in lakes:
		for i in 12:
			var dir := Vector2.from_angle(TAU * (float(i) + 0.1) / 12.0)
			var pe := Vector2(float(lk["x"]), float(lk["z"])) + dir * (float(lk["r"]) + Hydrology.LAKE_REACH_M - 0.01)
			var ge := TerrainSlice.height_wrapped_in(SEED, noise, pe.x, pe.y, w, cache, [])
			if Hydrology.soft_carve(Hydrology.features_for_chunk(Vector2i(floori(pe.x / 32.0), floori(pe.y / 32.0)), SEED)["segs"], pe.x, pe.y, ge) != ge:
				continue
			edge = maxf(edge, absf(Hydrology.carved_height(SEED, pe.x, pe.y, ge) - ge))
	assert_true(edge <= 0.01, "the shore ends without a step: carved ground within 0.01 m of the plain ground at the reach (worst %.4f)" % edge)
	# The bed `water_at` reports is an upper bound of the carved ground in the disc (the smooth union only goes lower).
	for lk in lakes.slice(0, 10):
		var f := {"lakes": [lk], "segs": []}
		for i in 12:
			var dir := Vector2.from_angle(TAU * (float(i) + 0.2) / 12.0)
			for fr: float in [0.1, 0.5, 0.9]:
				var pd := Vector2(float(lk["x"]), float(lk["z"])) + dir * float(lk["r"]) * fr
				var gd := TerrainSlice.height_wrapped_in(SEED, noise, pd.x, pd.y, w, cache, [])
				var bed := float(Hydrology.water_at(f, pd.x, pd.y)["bed"])
				assert_true(Hydrology.lake_ground(lk, Vector2(pd.x - float(lk["x"]), pd.y - float(lk["z"])).length(), gd) <= minf(gd, bed) + 0.0011, "the carved ground in the disc is no higher than the bed or the plain ground")

func _test_frontier_water() -> void:
	ChunkRecords.clear()
	var cm := TerrainSlice.CHUNK_METERS
	var noise := FastNoiseLite.new()
	TerrainSlice.configure_noise(noise, SEED)
	var w := float(TerrainSlice.circumference_chunks()) * cm
	var checked := 0
	for lk in _shore_lakes(6):
		ChunkRecords.clear()
		Hydrology.reset_cache()
		var anchor := Vector2i(floori((float(lk["x"]) + 0.8 * float(lk["r"])) / cm), floori(float(lk["z"]) / cm))
		var old := TerrainSlice.generation_record(anchor, SEED)
		old["v"] = Hydrology.HYDROLOGY_VERSION - 1
		var low: Array = []
		for hc in old["h"]:
			low.append(float(hc) - 6.0)   # the recorded ground lies well under the lake's surface
		old["h"] = low
		ChunkRecords.set_record(anchor, old)
		var cache := TerrainSlice.new_corner_cache()
		var x := float(anchor.x) * cm - 0.25
		for tz in 64:
			var z := float(anchor.y) * cm + float(tz) * TerrainSlice.TILE_SIZE
			var surf := Hydrology.surface_at(SEED, x, z)
			if is_nan(surf):
				continue
			checked += 1
			var g := TerrainSlice.height_wrapped_in(SEED, noise, x + 0.5, z, w, cache, [])
			assert_true(surf - g <= 0.5, "the water beside an older recorded chunk is at most 0.5 m above its ground (%.3f over %.3f)" % [surf, g])
	ChunkRecords.clear()
	Hydrology.reset_cache()
	assert_true(checked > 0, "some water meets an older recorded chunk (%d tiles)" % checked)

func _test_levee_params() -> void:
	Hydrology.warm()
	assert_eq(Hydrology._lake_freeboard, 0.5, "the freeboard is the fabric's")
	assert_eq(Hydrology._lake_max_levee, 3.0, "the maximum levee is the fabric's")
	assert_true(Hydrology.fingerprint_fields().has(0.5) and Hydrology.fingerprint_fields().has(3.0), "the world fingerprint reads both")
	assert_eq(Hydrology.levee_height(100.0, 0.0), 100.0, "the levee starts at the water")
	assert_eq(Hydrology.levee_height(100.0, Hydrology.LAKE_CREST_M), 100.5, "and crests a freeboard above it")
	assert_eq(Hydrology.levee_height(100.0, 100.0), 100.0, "and falls back to the water level")


func _record_at(c: Vector2i, v: int) -> void:
	var rec := TerrainSlice.generation_record(c, SEED)
	rec["v"] = v
	ChunkRecords.set_record(c, rec)

func _lake_in(f: Dictionary, lk: Dictionary) -> Dictionary:
	for l in f["lakes"]:
		if is_equal_approx(float(l["x"]), float(lk["x"])) and is_equal_approx(float(l["z"]), float(lk["z"])):
			return l
	return {}

func _test_recorded_lake_versions() -> void:
	var cm := TerrainSlice.CHUNK_METERS
	var noise := FastNoiseLite.new()
	TerrainSlice.configure_noise(noise, SEED)
	var w := float(TerrainSlice.circumference_chunks()) * cm
	var cache := TerrainSlice.new_corner_cache()
	var shore_seen := 0
	var checked := 0
	for lk in _shore_lakes(8):
		var cx := float(lk["x"])
		var cz := float(lk["z"])
		var r := float(lk["r"])
		var centre := Vector2i(floori(cx / cm), floori(cz / cm))
		var edge := Vector2i(floori((cx + r + 8.0) / cm), floori(cz / cm))
		for v in [Hydrology.HYDROLOGY_VERSION, Hydrology.LAKE_SPAWN_VERSION - 1, Hydrology.LAKE_SPAWN_VERSION, Hydrology.LAKE_SHORE_VERSION - 1]:
			ChunkRecords.clear()
			Hydrology.reset_cache()
			_record_at(centre, v)
			_record_at(edge, v)
			for c in [centre, edge]:
				var f := Hydrology.features_for_chunk(c, SEED)
				var l := _lake_in(f, lk)
				assert_true(not l.has("shore"), "a chunk recorded at %d keeps the lake without a shore" % v)
				if not l.is_empty():
					assert_true(is_equal_approx(float(l["surface"]), float(lk["s0"])), "its surface is the one from the centre and eight rim points")
				for tz in range(0, 64, 5):
					for tx in range(0, 64, 5):
						var px := float(c.x) * cm + float(tx) * TerrainSlice.TILE_SIZE
						var pz := float(c.y) * cm + float(tz) * TerrainSlice.TILE_SIZE
						var g := TerrainSlice.height_wrapped_in(SEED, noise, px, pz, w, cache, [])
						var d := Vector2(px - cx, pz - cz).length()
						var want := g if d >= r or l.is_empty() else minf(g, float(l["surface"]) - float(l["depth"]) * (1.0 - d * d / (r * r)) - 0.05)
						want = Hydrology.soft_carve(f["segs"], px, pz, want)
						assert_true(absf(Hydrology.carved_height(SEED, px, pz, g) - want) < 1e-4, "a chunk recorded at %d keeps its legacy ground (d %.1f of r %.1f; %f vs %f)" % [v, d, r, Hydrology.carved_height(SEED, px, pz, g), want])
						checked += 1
		# Recorded at 17, or not recorded: the shore.
		ChunkRecords.clear()
		Hydrology.reset_cache()
		_record_at(edge, Hydrology.LAKE_SHORE_VERSION)
		assert_true(_lake_in(Hydrology.features_for_chunk(edge, SEED), lk).has("shore"), "a chunk recorded at 17 has the shore")
		shore_seen += 1
		ChunkRecords.clear()
		Hydrology.reset_cache()
		var l2 := _lake_in(Hydrology.features_for_chunk(edge, SEED), lk)
		assert_true(l2.has("shore"), "an unrecorded chunk gets the shore")
		var raised := 0
		for tz in range(0, 64, 2):
			for tx in range(0, 64, 2):
				var px2 := float(edge.x) * cm + float(tx) * TerrainSlice.TILE_SIZE
				var pz2 := float(edge.y) * cm + float(tz) * TerrainSlice.TILE_SIZE
				if Vector2(px2 - cx, pz2 - cz).length() <= r:
					continue
				var g2 := TerrainSlice.height_wrapped_in(SEED, noise, px2, pz2, w, cache, [])
				if absf(Hydrology.carved_height(SEED, px2, pz2, g2) - g2) > 0.001:
					raised += 1
		assert_true(raised > 0, "the unrecorded chunk's ground beside the lake is shaped by the shore")
	ChunkRecords.clear()
	Hydrology.reset_cache()
	assert_true(checked > 100 and shore_seen > 0, "ground samples compared with the legacy computation (%d)" % checked)

func _test_frontier_legacy_water() -> void:
	var cm := TerrainSlice.CHUNK_METERS
	var checked := 0
	for lk in _shore_lakes(6):
		for v in [Hydrology.HYDROLOGY_VERSION, 15, 16]:
			ChunkRecords.clear()
			Hydrology.reset_cache()
			var anchor := Vector2i(floori((float(lk["x"]) + 0.8 * float(lk["r"])) / cm), floori(float(lk["z"]) / cm))
			_record_at(anchor, v)
			for tz in 64:
				var z := float(anchor.y) * cm + float(tz) * TerrainSlice.TILE_SIZE
				var inside := Hydrology.surface_at(SEED, float(anchor.x) * cm + 0.25, z)
				var beside := Hydrology.surface_at(SEED, float(anchor.x) * cm - 0.25, z)
				if is_nan(inside) or is_nan(beside):
					continue
				checked += 1
				assert_true(absf(inside - beside) <= 0.05, "the water level meets the recorded chunk's (v%d): %.3f vs %.3f" % [v, inside, beside])
	ChunkRecords.clear()
	Hydrology.reset_cache()
	assert_true(checked > 0, "some recorded water meets unrecorded water (%d tiles)" % checked)

func _test_spawn_and_river_tiers() -> void:
	assert_eq(Hydrology.tier_of(15), 0, "15 has none of the changes")
	assert_eq(Hydrology.tier_of(16), 1, "16 has the spawn extents")
	assert_eq(Hydrology.tier_of(17), 2, "17 has the shore")
	assert_eq(Hydrology.tier_of(18), 3, "18 has the river cell")
	# A lake whose centre is off the spawn plain but whose disc reaches it: the old rule keeps it, the new drops it.
	var c := WorldShape.SPAWN_CENTER
	var legacy_only := 0
	for seed_v in range(1, 41):
		var lc := Hydrology.lake_cell()
		for cz in range(floori((c.y - 1750.0) / lc), floori((c.y + 1750.0) / lc) + 1):
			for cx in range(floori((c.x - 1750.0) / lc), floori((c.x + 1750.0) / lc) + 1):
				var old := Hydrology.lake_of_cell(seed_v, cx, cz, 0)
				if not old.is_empty() and Hydrology.lake_of_cell(seed_v, cx, cz, 1).is_empty():
					legacy_only += 1
					var cm := TerrainSlice.CHUNK_METERS
					var ch := Vector2i(floori(float(old["x"]) / cm), floori(float(old["z"]) / cm))
					ChunkRecords.clear()
					_record_at(ch, 15)
					assert_true(not _lake_in(Hydrology.features_for_chunk(ch, seed_v), old).is_empty(), "a chunk recorded at 15 keeps its lake on the spawn plain's edge")
					_record_at(ch, 16)
					assert_true(_lake_in(Hydrology.features_for_chunk(ch, seed_v), old).is_empty(), "a chunk recorded at 16 does not have it")
					ChunkRecords.clear()
	assert_true(legacy_only > 0, "some lake reaches the plain only by its disc (%d)" % legacy_only)
	# The river cell: an exact divisor of the circumference since 18, the plain cell before.
	TerrainSlice.set_world_circumference(96.5, false)
	assert_true(Hydrology.river_cell(2) != Hydrology.river_cell(3), "a chunk recorded at 17 keeps the plain river cell on a planet that does not divide by it")
	assert_eq(Hydrology.river_cell(2), Hydrology.RIVER_CELL_SMALL_M, "the plain cell")
	var seen := 0
	for i in 60:
		for j in range(-6, 6):
			var rv2 := Hydrology.river_of_cell(SEED, i, j, 2)
			var rv3 := Hydrology.river_of_cell(SEED, i, j, 3)
			if not rv2.is_empty() and not rv3.is_empty():
				seen += int(rv2["pts"][0] != rv3["pts"][0])
	assert_true(seen > 0, "the cell choice moves the traced rivers (%d differ)" % seen)
	TerrainSlice.set_world_circumference(TerrainSlice.DEFAULT_CIRCUMFERENCE_KM, false)
	Hydrology.reset_cache()
