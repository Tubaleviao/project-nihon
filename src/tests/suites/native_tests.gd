extends "res://src/tests/test_support.gd"
## Phase 166 — the native chunk builder scaffold: the loader's native / GDScript-fallback decision.
## CI runs the suite twice: once with no binary (`--expect-fallback`) and once with the Linux
## binary built by the `native` job (`--expect-native`). Without either flag the real loader is
## only checked for consistency with what the engine can see.

const NativeBuilder := preload("res://src/terrain/native_builder.gd")
const VoxelRuns := preload("res://src/terrain/voxel_runs.gd")
const VoxelMesh := preload("res://src/terrain/voxel_mesh.gd")
const VoxelCoarse := preload("res://src/terrain/voxel_coarse.gd")

const EXPECT_NATIVE_ARG := "--expect-native"
const CHUNK_BUILDER := "NativeChunkBuilder"
const BootWiringScript := preload("res://src/core/boot_wiring.gd")
const WORLD_SHAPE := "NativeWorldShape"
const EXPECT_FALLBACK_ARG := "--expect-fallback"

func register() -> void:
	_run_test("native: the loader picks native only when the extension loaded and the class exists", _test_native_mode_decision)
	_run_test("native: the real loader matches the build (native present or fallback)",             _test_native_real_loader)
	_run_test("native: only ported functions are routed natively",                                 _test_native_routes_only_ported)
	_run_test("native: the general loader routes per class and function",                           _test_native_loader_routing)
	_run_test("native: the shared hash and noise match WorldShape on 10,000 samples",              _test_native_world_shape_parity)
	_run_test("native: heightmap_for matches the GDScript reference on the fixed chunk set",       _test_native_heightmap_parity)
	_run_test("native: heightmap_strip_for matches the GDScript reference on every side and depth (Phase 241 review)", _test_native_heightmap_strip_parity)
	_run_test("native: heightmap_for matches on the 2,000 km planet inside, at and past the continent edge (Phase 238)", _test_native_heightmap_parity_small_planet, true)
	_run_test("native: build_runs matches the GDScript reference on the fixed chunk set",          _test_native_build_runs_parity)
	_run_test("native: build_chunk_arrays matches the GDScript reference on the fixed chunk set",  _test_native_chunk_arrays_parity)
	_run_test("native: a rejected build_chunk_arrays falls back to the GDScript reference",        _test_native_chunk_arrays_rejection_falls_back)
	_run_test("native: build_coarse_arrays matches the GDScript reference on the fixed chunk set", _test_native_coarse_parity)
	_run_test("native: a rejected build_runs falls back to the GDScript reference",                _test_native_build_runs_rejection_falls_back)
	_run_test("native: the build_runs cfg snapshot is filled once across threads",                 _test_native_runs_cfg_single_fill)
	_run_test("native: run edits resolve in a total order",                                     _test_native_run_ops_order)
	_run_test("native: the extension and its build files are in the tree",                         _test_native_files_present)
	_run_test("native: CI times the playtest stream step once per builder",                         _test_native_speed_gate_wired)
	_run_test("native: the build breakdown decides on the heightmap share",                         _test_native_build_breakdown)
	_run_test("native: the release workflow is tag-triggered and builds three platforms",           _test_native_release_workflow)
	_run_test("native: CI flies the flight step on a release export",                              _test_native_release_flight_wired)

## Phase 248 — a stand-in native class for the loader tests: any object with `version()` and `functions()`.
class FakeNative extends RefCounted:
	var v := 1
	var fns := PackedStringArray()
	func _init(p_v: int, p_fns: Array) -> void:
		v = p_v
		fns = PackedStringArray(p_fns)
	func version() -> int:
		return v
	func functions() -> PackedStringArray:
		return fns
	func probe(x: int) -> int:
		return x * 2

## Phase 248 — the general loader routes per class and function: a class below its required version,
## a missing class and a function not in `functions()` each fall back; a current one routes native.
func _test_native_loader_routing() -> void:
	NativeLoaderScript.reset_for_tests()
	NativeLoaderScript.install_for_tests("FakeCurrent", FakeNative.new(3, ["probe"]), 2)
	NativeLoaderScript.install_for_tests("FakeOld", FakeNative.new(1, ["probe"]), 2)
	NativeLoaderScript.install_for_tests("FakeMissing", null, 1)
	assert_true(NativeLoaderScript.use_native("FakeCurrent", "probe"), "a current class routes a listed function native")
	assert_eq(NativeLoaderScript.mode("FakeCurrent"), NativeLoaderScript.MODE_NATIVE, "a current class reports native")
	assert_eq(NativeLoaderScript.version("FakeCurrent"), 3, "a current class reports its version")
	assert_eq(int(NativeLoaderScript.instance("FakeCurrent").call("probe", 4)), 8, "the routed instance is the class's")
	assert_false(NativeLoaderScript.use_native("FakeCurrent", "unlisted"), "a function not in functions() falls back")
	assert_false(NativeLoaderScript.use_native("FakeOld", "probe"), "a class below its required version falls back")
	assert_eq(NativeLoaderScript.mode("FakeOld"), NativeLoaderScript.MODE_FALLBACK, "an old class reports the fallback")
	assert_eq(NativeLoaderScript.version("FakeOld"), -1, "no native version on the fallback")
	assert_true(NativeLoaderScript.instance("FakeOld") == null, "an old class hands out no instance")
	assert_false(NativeLoaderScript.use_native("FakeMissing", "probe"), "a missing class falls back")
	assert_false(NativeLoaderScript.use_native("NeverListed", "probe"), "a class the loader never heard of falls back")
	var old := NativeLoaderScript.resolve(FakeNative.new(1, []), 2)
	assert_true(NativeLoaderScript.log_line("thing", old, 2).contains("gdscript fallback (native version 1 is older than 2"), "an old class logs why it fell back")
	assert_true(NativeLoaderScript.log_line("thing", NativeLoaderScript.resolve(null, 1), 1).contains("gdscript fallback (no native extension)"), "a missing class logs the fallback")
	assert_eq(NativeLoaderScript.log_line("chunk builder", NativeLoaderScript.resolve(FakeNative.new(8, []), 8), 8), "[Native] chunk builder: native (version 8)", "the chunk builder keeps its log line")
	# The shared harness: a routed class is compared, a fallen-back one is skipped.
	assert_eq(assert_native_parity("FakeCurrent", "probe", [[1], [-7], [1 << 40]], func(x: int) -> int: return x * 2), 3, "the harness compares every case of a routed function")
	assert_eq(assert_native_parity("FakeOld", "probe", [[1]], func(x: int) -> int: return x * 2), -1, "the harness skips a function that is not routed")
	NativeLoaderScript.reset_for_tests()
	NativeLoaderScript.init()
	for cls: String in NativeLoaderScript.CLASSES:
		assert_false(NativeLoaderScript.use_native(cls, "probe"), "%s does not route a function it does not list" % cls)

## Phase 248 — the shared seeded hash and noise (`native/src/base/world_hash.h`) are bit-exact with
## `WorldShape._mix` and `WorldShape._noise` on 10,000 seeded samples each, with 64-bit seeds that
## overflow the multiplies and coordinates on both sides of the origin and the wrap.
func _test_native_world_shape_parity() -> void:
	if EXPECT_NATIVE_ARG in OS.get_cmdline_user_args():
		assert_true(NativeLoaderScript.is_native(WORLD_SHAPE), "NativeWorldShape is registered and current in the native run")
	var rng := RandomNumberGenerator.new()
	rng.seed = 248
	var w := float(TerrainSlice.circumference_chunks()) * 32.0
	var cells := [WorldShape.EROSION_CELLS, WorldShape.RIDGE_CELLS, WorldShape.MASSIF_CELLS, 16, 44, 128, 3, 1]
	var mix_cases: Array = []
	var noise_cases: Array = []
	for i in range(10000):
		var seed_v := (rng.randi() << 32) | rng.randi()   # full 64-bit, negative half the time
		mix_cases.append([seed_v, rng.randi_range(-2000000000, 2000000000), (rng.randi() << 32) | rng.randi(), rng.randi_range(0, 100)])
		noise_cases.append([seed_v, rng.randf_range(-1.5 * w, 1.5 * w), rng.randf_range(-0.5 * w, 0.5 * w), w, cells[i % cells.size()], rng.randi_range(0, 100)])
	assert_native_parity(WORLD_SHAPE, "mix", mix_cases, WorldShape._mix)
	assert_native_parity(WORLD_SHAPE, "noise", noise_cases, WorldShape._noise)

func _test_native_mode_decision() -> void:
	assert_eq(NativeBuilder.mode_for(true, true), NativeBuilder.MODE_NATIVE, "loaded and registered: native")
	assert_eq(NativeBuilder.mode_for(false, false), NativeBuilder.MODE_FALLBACK, "no extension: GDScript fallback")
	assert_eq(NativeBuilder.mode_for(true, false), NativeBuilder.MODE_FALLBACK, "loaded but the class is missing: fallback")
	assert_eq(NativeBuilder.mode_for(false, true), NativeBuilder.MODE_FALLBACK, "a failed load never reports native")

func _test_native_real_loader() -> void:
	NativeBuilder.reset_for_tests()
	var args := OS.get_cmdline_user_args()
	var mode := NativeBuilder.init()
	assert_eq(NativeBuilder.init(), mode, "the decision is cached")
	if EXPECT_NATIVE_ARG in args:
		assert_eq(mode, NativeBuilder.MODE_NATIVE, "the binary is present: the loader reports native")
		assert_true(ClassDB.class_exists(NativeBuilder.CLASS_NAME), "NativeChunkBuilder is registered")
		assert_eq(NativeBuilder.version(), NativeBuilder.REQUIRED_VERSION, "the native class reports its version")
		var b: RefCounted = ClassDB.instantiate(NativeBuilder.CLASS_NAME)
		assert_eq(b.call("functions") as PackedStringArray, PackedStringArray(["heightmap_for", "build_runs", "build_chunk_arrays", "build_coarse_arrays", "build_smooth_arrays", "heightmap_strip_for"]), "Phases 167-169, 190, 240 and 241 port heightmap_for, build_runs, build_chunk_arrays, build_coarse_arrays, build_smooth_arrays and heightmap_strip_for")
	if EXPECT_FALLBACK_ARG in args:
		assert_eq(mode, NativeBuilder.MODE_FALLBACK, "no binary: the loader reports the GDScript fallback")
		assert_eq(NativeBuilder.version(), -1, "no native version on the fallback")
	var current := not NativeBuilder.forced_fallback() and ClassDB.class_exists(NativeBuilder.CLASS_NAME) \
		and int(ClassDB.instantiate(NativeBuilder.CLASS_NAME).call("version")) >= NativeBuilder.REQUIRED_VERSION
	assert_eq(mode == NativeBuilder.MODE_NATIVE, current, "native exactly when a current class is registered")
	assert_eq(NativeBuilder.use_native("heightmap_for"), mode == NativeBuilder.MODE_NATIVE, "heightmap_for is native exactly when the extension loaded")

func _test_native_routes_only_ported() -> void:
	NativeBuilder.init()
	assert_eq(NativeBuilder.use_native("build_runs"), NativeBuilder.is_native(), "build_runs is native exactly when the extension loaded")
	assert_eq(NativeBuilder.use_native("build_chunk_arrays"), NativeBuilder.is_native(), "build_chunk_arrays is native exactly when the extension loaded")
	assert_false(NativeBuilder.use_native("not_a_function"), "an unknown function is never native")

## The chunk set the native port is held to: equator, ice shelf, pole snow field, both sides of the
## antimeridian blend band, a far-from-origin chunk, and chunks whose cells carry records.
func _native_parity_chunks() -> Array:
	var c := TerrainSlice.circumference_chunks()
	var pole := TerrainSlice.pole_chunks()
	var ice := int(float(pole) * (TerrainSlice.ICE_SHELF_LAT + 1.0) / 90.0)
	return [
		Vector2i(300, 7),                    # equator, away from the spawn plain
		Vector2i(-1234, -90),                # temperate, far
		Vector2i(40, ice),                   # ice shelf
		Vector2i(-40, -ice),                 # ice shelf, south
		Vector2i(7, pole - 3),               # pole snow field
		Vector2i(c / 2 - 1, 11),             # east of the antimeridian: blend band
		Vector2i(-c / 2, 11),                # west of it
		Vector2i(c / 2 - 5, pole - 2),       # blend band at the pole
		Vector2i(0, 0),                      # spawn plain
		Vector2i(2047, -2047),               # far detail-noise cell
	]

func _test_native_heightmap_parity_small_planet() -> void:
	var seed_v := 238
	var noise := FastNoiseLite.new()
	TerrainSlice.configure_noise(noise, seed_v)
	var cases: Array = []
	for pos in [Vector2i(0, 0), Vector2i(2000, 500), Vector2i(-4000, 2500), Vector2i(3000, 4000), Vector2i(8000, 0), Vector2i(9000, 0), Vector2i(10500, 0), Vector2i(31249, 0), Vector2i(-31250, 2000)]:
		cases.append([pos, seed_v, noise])
	ChunkRecordsScript.clear()
	assert_native_parity(CHUNK_BUILDER, "heightmap_for", cases, TerrainSlice.heightmap_for_gd, TerrainSlice.heightmap_for, "heightmap_for, masked small planet")

func _test_native_heightmap_strip_parity() -> void:
	var seed_v := 777001
	var noise := FastNoiseLite.new()
	TerrainSlice.configure_noise(noise, seed_v)
	var cases: Array = []
	for pos: Vector2i in _native_parity_chunks().slice(0, 4):
		for sz in [-1, 0, 1]:
			for sx in [-1, 0, 1]:
				if sx == 0 and sz == 0:
					continue
				for depth in [1, 2]:
					cases.append([pos, Vector2i(sx, sz), seed_v, noise, depth])
	ChunkRecordsScript.clear()
	assert_native_parity(CHUNK_BUILDER, "heightmap_strip_for", cases, TerrainSlice.heightmap_strip_for_gd, TerrainSlice.heightmap_strip_for, "heightmap_strip_for")

func _test_native_heightmap_parity() -> void:
	var seed_v := 777001
	var noise := FastNoiseLite.new()
	TerrainSlice.configure_noise(noise, seed_v)
	var chunks := _native_parity_chunks()
	var cases: Array = []
	for pos: Vector2i in chunks:
		cases.append([pos, seed_v, noise])
	ChunkRecordsScript.clear()
	if assert_native_parity(CHUNK_BUILDER, "heightmap_for", cases, TerrainSlice.heightmap_for_gd, TerrainSlice.heightmap_for, "heightmap_for, no records") < 0:
		return
	# An edited chunk: records keep their own corner heights, here lifted off the generator's.
	for pos: Vector2i in [chunks[0], chunks[5], chunks[6]]:
		ChunkRecordsScript.set_record(pos, {"b": "TemperateForest", "h": [3.25, 4.5, -2.0, 9.125], "v": TerrainSlice.WORLDGEN_VERSION})
	assert_native_parity(CHUNK_BUILDER, "heightmap_for", cases, TerrainSlice.heightmap_for_gd, TerrainSlice.heightmap_for, "heightmap_for, with records")
	ChunkRecordsScript.clear()
	# Worldgen 9: a highland seed's spawn plain is not 2 m; the native side takes it from the GDScript one.
	var high := 2045165241
	var high_noise := FastNoiseLite.new()
	TerrainSlice.configure_noise(high_noise, high)
	var high_cases: Array = []
	for pos: Vector2i in [Vector2i(0, 0), Vector2i(60, -20), Vector2i(-100, 40)]:   # on the plain, in the ease
		high_cases.append([pos, high, high_noise])
	assert_native_parity(CHUNK_BUILDER, "heightmap_for", high_cases, TerrainSlice.heightmap_for_gd, TerrainSlice.heightmap_for, "heightmap_for, highland spawn plain")

## One build input for `chunk`: the 3x3 ring's heightmaps (the +x column left unknown for the odd
## chunks, so unknown-neighbour reads are covered), their biomes, the seed, edits and a depletion
## record naming real veins found by the first pass.
func _native_runs_input(chunk: Vector2i, seed_v: int, noise: FastNoiseLite, edits: Dictionary, depleted: Dictionary, skip_east: bool) -> Dictionary:
	var neighbours := {}
	var biomes := {}
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var c := Vector2i(chunk.x + dx, chunk.y + dz)
			var key := VoxelSlice._chunk_key(c)
			biomes[key] = TerrainSlice.biome_for_chunk(c, seed_v)
			if (dx != 0 or dz != 0) and not (skip_east and dx == 1):
				neighbours[key] = TerrainSlice.heightmap_for(c, seed_v, noise)
	return {"edits": edits, "neighbour_heightmaps": neighbours, "biomes": biomes, "seed": seed_v, "depleted": depleted}

func _native_runs_edits(chunk: Vector2i) -> Dictionary:
	var gx := chunk.x * 64
	var gz := chunk.y * 64
	var edits := {}
	var top := 40.0
	# A carved tunnel, a stacked placed block, a corner tile on the ring, and an unknown op kind.
	edits[VoxelSlice._tile_key(Vector2i(gx + 5, gz + 5))] = [{"op": "remove", "bottom": -3.0, "top": -2.0}]
	edits[VoxelSlice._tile_key(Vector2i(gx + 6, gz + 5))] = [{"op": "add", "bottom": top, "top": top + 0.25, "material": "Ferrite"}, {"op": "remove", "bottom": -90.0, "top": -80.0}]
	edits[VoxelSlice._tile_key(Vector2i(gx - 1, gz - 1))] = [{"op": "remove", "bottom": -10.0, "top": 30.0}, {"op": "bogus", "bottom": 0.0, "top": 1.0}]
	edits[VoxelSlice._tile_key(Vector2i(gx + 64, gz + 10))] = [{"op": "add", "bottom": -96.0, "top": 5.0, "material": "Voidite"}]
	return edits

func _test_native_build_runs_parity() -> void:
	if not NativeLoaderScript.use_native(CHUNK_BUILDER, "build_runs"):
		print("[Native] %s.build_runs parity skipped: not routed native in this run" % CHUNK_BUILDER)
		return
	var seed_v := 777001
	var noise := FastNoiseLite.new()
	TerrainSlice.configure_noise(noise, seed_v)
	ChunkRecordsScript.clear()
	var cases: Array = []
	for chunk: Vector2i in _native_parity_chunks():
		var hm := TerrainSlice.heightmap_for(chunk, seed_v, noise)
		for variant in range(3):
			# 0 plain, 1 edited + one live vein mined out, 2 edited with an unknown east ring
			var edits := {} if variant == 0 else _native_runs_edits(chunk)
			var depleted := {}
			if variant == 1:
				# Mine out every other vein cell the chunk's ring touches, at the top two depth cells.
				var c0 := int(floor(float(chunk.x * 64 - 1 + OreField.CELL_OFFSET_TILES) / OreField.CELL_TILES))
				var z0 := int(floor(float(chunk.y * 64 - 1 + OreField.CELL_OFFSET_TILES) / OreField.CELL_TILES))
				for cx in range(c0, c0 + 6):
					for cz in range(z0, z0 + 6):
						if (cx + cz) % 2 == 0:
							for cy in range(0, 3):
								depleted["%d,%d,%d" % [cx, cy, cz]] = 99
			var input := _native_runs_input(chunk, seed_v, noise, edits, depleted, variant == 2)
			if variant == 1:
				input["pad"] = 2   # Phase 240: the smooth mesher's two-tile ring
			cases.append([chunk, hm, input])
	# Compared as [tile keys in order, result]: a Dictionary's == ignores its order, the build's does not.
	var seen := {"deposits": 0, "topsoil": 0}
	var reference := func(chunk: Vector2i, hm: Array, input: Dictionary) -> Array:
		var want := VoxelSlice.build_runs_gd(chunk, hm, input)
		seen["deposits"] += (want["deposits"] as Array).size()
		for key in (want["runs"] as Dictionary):
			for entry: Dictionary in want["runs"][key]:
				if entry.has("top_color"):
					seen["topsoil"] += 1
		return [(want["runs"] as Dictionary).keys(), want]
	var routed := func(chunk: Vector2i, hm: Array, input: Dictionary) -> Array:
		var got := VoxelSlice.build_runs(chunk, hm, input)
		return [(got["runs"] as Dictionary).keys(), got]
	assert_native_parity(CHUNK_BUILDER, "build_runs", cases, reference, routed, "build_runs, tiles in order, runs and deposits")
	assert_true(int(seen["deposits"]) > 0, "the fixed chunk set holds vein deposits, so the ore path is compared (%d)" % int(seen["deposits"]))
	assert_true(int(seen["topsoil"]) > 0, "the fixed chunk set holds topsoiled runs, so the topsoil path is compared (%d)" % int(seen["topsoil"]))

## Phase 169 — the native greedy mesher gives the same arrays, in the same order, as the reference:
## resolved runs (plain, edited, unknown east ring), a bare natural-column build, absolute and
## chunk-local vertices.
func _test_native_chunk_arrays_parity() -> void:
	if not NativeLoaderScript.use_native(CHUNK_BUILDER, "build_chunk_arrays"):
		print("[Native] %s.build_chunk_arrays parity skipped: not routed native in this run" % CHUNK_BUILDER)
		return
	var seed_v := 777001
	var noise := FastNoiseLite.new()
	TerrainSlice.configure_noise(noise, seed_v)
	ChunkRecordsScript.clear()
	var cases: Array = []
	for chunk: Vector2i in _native_parity_chunks():
		var hm := TerrainSlice.heightmap_for(chunk, seed_v, noise)
		for variant in range(3):
			var edits := {} if variant == 0 else _native_runs_edits(chunk)
			var input := _native_runs_input(chunk, seed_v, noise, edits, {}, variant == 2)
			var resolved := VoxelSlice.build_runs_gd(chunk, hm, input)
			for local in [false, true]:
				cases.append([chunk, hm, resolved, local])
		cases.append([chunk, hm, {"runs": {}}, false])   # a bare build: every column natural off the heightmap
	var seen := {"quads": 0, "deposits": 0}
	var reference := func(chunk: Vector2i, hm: Array, resolved: Dictionary, local: bool) -> Dictionary:
		var want := VoxelMesh.build_chunk_arrays_gd(chunk, hm, resolved, local)
		if not local:
			seen["quads"] += int(want["quad_count"])
			seen["deposits"] += (want["deposit_vertices"] as PackedVector3Array).size()
		return want
	assert_native_parity(CHUNK_BUILDER, "build_chunk_arrays", cases, reference, VoxelSlice.build_chunk_arrays, "build_chunk_arrays")
	assert_true(int(seen["quads"]) > 0, "the fixed chunk set meshes quads (%d)" % int(seen["quads"]))
	assert_true(int(seen["deposits"]) > 0, "the fixed chunk set meshes vein deposit boxes (%d)" % int(seen["deposits"]))

## Phase 190 — the native coarse build gives the same arrays, in the same order, as the reference: both
## coarse levels, absolute and chunk-local vertices, a full biome and map ring and one missing its east column.
func _test_native_coarse_parity() -> void:
	if not NativeLoaderScript.use_native(CHUNK_BUILDER, "build_coarse_arrays"):
		print("[Native] %s.build_coarse_arrays parity skipped: not routed native in this run" % CHUNK_BUILDER)
		return
	var seed_v := 777001
	var noise := FastNoiseLite.new()
	TerrainSlice.configure_noise(noise, seed_v)
	ChunkRecordsScript.clear()
	var cases: Array = []
	var topsoil := 0
	for chunk: Vector2i in _native_parity_chunks():
		var hm := TerrainSlice.heightmap_for(chunk, seed_v, noise)
		for variant in range(2):
			var input := _native_runs_input(chunk, seed_v, noise, {}, {}, false)
			if variant == 1:
				for dz in range(-1, 2):   # a ring chunk with no biome or map: the blend reads its own, no edge cap
					(input["biomes"] as Dictionary).erase(VoxelSlice._chunk_key(chunk + Vector2i(1, dz)))
					(input["neighbour_heightmaps"] as Dictionary).erase(VoxelSlice._chunk_key(chunk + Vector2i(1, dz)))
			for step: int in VoxelCoarse.STEPS:
				var cols := VoxelCoarse.coarse_columns(chunk, hm, input, step)
				for i in (cols["tops"] as PackedFloat64Array).size():
					if cols["top_colors"][i] != cols["colors"][i]:
						topsoil += 1
				for local in [false, true]:
					cases.append([chunk, hm, input, step, local])
	var seen := {"quads": 0}
	var reference := func(chunk: Vector2i, hm: Array, input: Dictionary, step: int, local: bool) -> Dictionary:
		var want := VoxelCoarse.build_coarse_arrays_gd(chunk, hm, input, step, local)
		seen["quads"] += int(want["quad_count"])
		return want
	assert_native_parity(CHUNK_BUILDER, "build_coarse_arrays", cases, reference, VoxelCoarse.build_coarse_arrays, "build_coarse_arrays")
	assert_true(int(seen["quads"]) > 0, "the fixed chunk set meshes coarse quads (%d)" % int(seen["quads"]))
	assert_true(topsoil > 0, "the fixed chunk set holds topsoiled cells, so the topsoil path is compared (%d)" % topsoil)
	var bad := NativeBuilder.builder().call("build_coarse_arrays", Vector2i(1, 1), [1.0, 2.0], {}, 2, true, VoxelSlice.native_runs_cfg()) as Dictionary
	assert_true(bad.is_empty(), "a malformed heightmap is rejected by the native coarse build")

## A malformed resolve table is rejected by the native mesher (empty result); `VoxelMesh` then runs
## the GDScript reference rather than hand back a result without arrays.
func _test_native_chunk_arrays_rejection_falls_back() -> void:
	NativeBuilder.init()
	if not NativeBuilder.is_native():
		print("[Native] build_chunk_arrays fallback skipped: no native extension in this run")
		return
	var chunk := Vector2i(300, 7)
	var hm: Array = []
	hm.resize(4096)
	hm.fill(3.0)
	# A string "bottom" is unreadable to the native port but still a number to the reference (float("0")).
	var col := [{"bottom": "-96.0", "top": 3.0, "color": Color.RED}]
	var bad := {"runs": {VoxelSlice._tile_key(Vector2i(300 * 64, 7 * 64)): col}}
	var direct := NativeBuilder.builder().call("build_chunk_arrays", chunk, hm, bad, false, VoxelMesh.native_arrays_cfg()) as Dictionary
	assert_true(direct.is_empty(), "the native mesher rejects the malformed table")
	var got := VoxelSlice.build_chunk_arrays(chunk, hm, bad)
	assert_true(got.has("vertices"), "a rejected native build still returns arrays")
	assert_true(got == VoxelMesh.build_chunk_arrays_gd(chunk, hm, bad), "the fallback produced the reference result")

## #452 — a native `build_runs` that rejects its input returns an empty Dictionary; `VoxelSlice.build_runs`
## falls back to the GDScript reference instead of handing the caller a result without `runs`.
func _test_native_build_runs_rejection_falls_back() -> void:
	NativeBuilder.init()
	if not NativeBuilder.is_native():
		print("[Native] build_runs fallback skipped: no native extension in this run")
		return
	var seed_v := 777001
	var noise := FastNoiseLite.new()
	TerrainSlice.configure_noise(noise, seed_v)
	ChunkRecordsScript.clear()
	var chunk := Vector2i(300, 7)
	var hm := TerrainSlice.heightmap_for(chunk, seed_v, noise)
	var input := _native_runs_input(chunk, seed_v, noise, {}, {}, false)
	var good := VoxelSlice.native_runs_cfg()
	var bad := good.duplicate()
	bad["vein_cell"] = Callable()   # the native side fails its vein-callable check
	NativeLoaderScript._memo["build_runs"] = bad
	var got := VoxelSlice.build_runs(chunk, hm, input)
	NativeLoaderScript._memo["build_runs"] = good
	var want := VoxelSlice.build_runs_gd(chunk, hm, input)
	assert_true(got.has("runs"), "a rejected native build still returns runs")
	assert_true(got["runs"] == want["runs"], "the fallback runs are the GDScript reference")

## #452 — the cfg snapshot is filled under a lock: workers that reach it before `_ready` warmed it all
## get the one snapshot instead of racing to build their own.
func _test_native_runs_cfg_single_fill() -> void:
	var saved := VoxelSlice.native_runs_cfg()
	NativeBuilder.forget_memo("build_runs")
	var threads: Array[Thread] = []
	for i in range(4):
		var t := Thread.new()
		t.start(VoxelSlice.native_runs_cfg)
		threads.append(t)
	var results: Array = []
	for t in threads:
		results.append(t.wait_to_finish())
	for cfg in results:
		assert_true(is_same(cfg, results[0]), "every worker gets the same cfg snapshot")
	assert_false((results[0] as Dictionary).is_empty(), "the snapshot is filled")
	assert_true(results[0] == saved, "a refill equals the warmed snapshot")
	assert_true(is_same(VoxelSlice.native_runs_cfg(), results[0]), "later calls get that same snapshot")

## `add_span` merges runs sorted by bottom; with the sort on `bottom` alone a tie fell to the
## (unstable) sort's whim. Two runs that share a bottom now resolve the same whatever their order.
func _test_native_run_ops_order() -> void:
	var a := VoxelRuns.apply_run_ops([], [{"op": "add", "bottom": 1.0, "top": 2.0, "material": "Ferrite"}, {"op": "add", "bottom": 1.0, "top": 1.5, "material": "Soil"}])
	var b := VoxelRuns.apply_run_ops([], [{"op": "add", "bottom": 1.0, "top": 1.5, "material": "Soil"}, {"op": "add", "bottom": 1.0, "top": 2.0, "material": "Ferrite"}])
	assert_true(a == b, "equal-bottom runs resolve to the same list in either insertion order")

func _test_native_files_present() -> void:
	assert_true(FileAccess.file_exists(NativeBuilder.EXTENSION_PATH), "the .gdextension file is committed")
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(NativeBuilder.EXTENSION_PATH), OK, "the .gdextension parses")
	assert_eq(cfg.get_value("configuration", "entry_symbol", ""), "nihon_native_init", "entry symbol")
	for key in ["linux.release.x86_64", "windows.release.x86_64", "macos.release"]:
		assert_true(cfg.has_section_key("libraries", key), "a %s library is declared" % key)

func _test_native_speed_gate_wired() -> void:
	assert_eq(NativeBuilder.NO_NATIVE_ARG, "--no-native", "the fallback switch the speed gate passes")
	assert_true(FileAccess.file_exists("res://tools/check_stream_rate.py") or not FileAccess.file_exists("res://.github/workflows/ci.yml"), "the stream-rate gate script is in the tree")
	var f := FileAccess.open("res://.github/workflows/ci.yml", FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	var live := ""
	for line in text.split("\n"):
		if not line.strip_edges().begins_with("#"):
			live += line + "\n"
	assert_true(live.contains("--playtest-bot --no-native"), "CI runs the playtest bot on the GDScript fallback")
	assert_true(live.contains("check_stream_rate.py playtest/report.json playtest/report-gdscript.json"), "CI checks the native rate against the fallback's")
	assert_true(live.contains("fallback_status"), "CI reads the fallback run's exit status")

func _test_native_build_breakdown() -> void:
	var PB := preload("res://src/tests/playtest_bot.gd")
	var low := PB.build_breakdown({ "heightmap": 2000, "seam": 1000, "runs": 3000, "arrays": 4000 }, 2, 5)
	assert_eq(int(low["window_radius"]), 5, "window radius recorded")
	assert_true(absf(float(low["total_ms"]) - 5.0) < 0.0001, "10 ms over 2 chunks is 5 ms per chunk")
	assert_true(absf(float(low["heightmap_share"]) - 0.2) < 0.0001, "heightmap is 20%")
	assert_eq(low["decision"], "no_shader", "under half: no shader")
	var high := PB.build_breakdown({ "heightmap": 7000, "seam": 1000, "runs": 1000, "arrays": 1000 }, 1, 5)
	assert_eq(high["decision"], "compute_shader", "over half: a shader is justified")
	var empty := PB.build_breakdown({ "heightmap": 0 }, 0, 0)
	assert_eq(empty["decision"], "no_shader", "no time measured: no shader")

func _test_native_release_workflow() -> void:
	var f := FileAccess.open("res://.github/workflows/release.yml", FileAccess.READ)
	if f == null:
		return   # an export does not carry .github; the suite runs from the project tree
	var text := f.get_as_text()
	assert_true(text.contains('tags: ["v*"]'), "the release workflow triggers on v* tags")
	for p in ["linux", "windows", "macos"]:
		assert_true(text.contains("name: " + p), "the release builds the %s binary" % p)
	assert_true(text.contains("gh release create"), "the release workflow creates the GitHub Release")

## Phase 248 — a CI job exports a release build with the release library and plays the `flight` step on it,
## report only, and the baseline doc carries a release column.
func _test_native_release_flight_wired() -> void:
	var f := FileAccess.open("res://.github/workflows/ci.yml", FileAccess.READ)
	if f == null:
		return   # an export does not carry .github; the suite runs from the project tree
	var live := ""
	for line in f.get_as_text().split("\n"):
		if not line.strip_edges().begins_with("#"):
			live += line + "\n"
	var at := live.find("  release-flight:")
	assert_true(at >= 0, "CI has the release-flight job")
	var job := live.substr(at, live.find("\n  build:", at) - at)
	assert_true(job.contains("--export-release \"Linux Playtest\""), "the job exports the Linux Playtest preset as a release build")
	assert_true(job.contains("libnihon_native.linux.template_release.x86_64.so"), "the export carries the release library")
	assert_true(job.contains("--playtest-bot --playtest-no-budget --playtest-only flight"), "the job plays only the flight step, report only")
	assert_true(job.contains("chunk builder: native"), "the job checks the release library loaded")
	assert_true(job.contains("tools/flight_report.py playtest/report.json"), "the job writes the flight numbers to the summary")
	assert_true(FileAccess.file_exists("res://tools/flight_report.py"), "the flight report script is in the tree")
	var presets := ConfigFile.new()
	assert_eq(presets.load("res://export_presets.cfg"), OK, "export_presets.cfg parses")
	var tagged: Array = []
	for section in presets.get_sections():
		if presets.has_section_key(section, "name") and str(presets.get_value(section, "custom_features", "")).split(",").has("playtest"):
			tagged.append(str(presets.get_value(section, "name")))
	assert_eq(tagged, ["Linux Playtest"], "only the Linux Playtest preset carries the playtest feature")
	assert_true(BootWiringScript.playtest_allowed(true, false), "a debug build runs the bot")
	assert_true(BootWiringScript.playtest_allowed(false, true), "a playtest-tagged release build runs the bot")
	assert_false(BootWiringScript.playtest_allowed(false, false), "a shipped release build ignores --playtest-bot")
	var md := FileAccess.get_file_as_string("res://docs/perf/playtest-baseline.md")
	assert_true(md.contains("Release export (template_release)"), "playtest-baseline.md has a release column")
