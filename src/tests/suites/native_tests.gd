extends "res://src/tests/test_support.gd"
## Phase 166 — the native chunk builder scaffold: the loader's native / GDScript-fallback decision.
## CI runs the suite twice: once with no binary (`--expect-fallback`) and once with the Linux
## binary built by the `native` job (`--expect-native`). Without either flag the real loader is
## only checked for consistency with what the engine can see.

const NativeBuilder := preload("res://src/terrain/native_builder.gd")
const VoxelRuns := preload("res://src/terrain/voxel_runs.gd")

const EXPECT_NATIVE_ARG := "--expect-native"
const EXPECT_FALLBACK_ARG := "--expect-fallback"

func register() -> void:
	_run_test("native: the loader picks native only when the extension loaded and the class exists", _test_native_mode_decision)
	_run_test("native: the real loader matches the build (native present or fallback)",             _test_native_real_loader)
	_run_test("native: only ported functions are routed natively",                                 _test_native_routes_only_ported)
	_run_test("native: heightmap_for matches the GDScript reference on the fixed chunk set",       _test_native_heightmap_parity)
	_run_test("native: build_runs matches the GDScript reference on the fixed chunk set",          _test_native_build_runs_parity)
	_run_test("native: run edits resolve in a total order",                                       _test_native_run_ops_order)
	_run_test("native: the extension and its build files are in the tree",                         _test_native_files_present)
	_run_test("native: the release workflow is tag-triggered and builds three platforms",           _test_native_release_workflow)

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
		assert_eq(NativeBuilder.version(), 3, "the native class reports its version")
		var b: RefCounted = ClassDB.instantiate(NativeBuilder.CLASS_NAME)
		assert_eq(b.call("functions") as PackedStringArray, PackedStringArray(["heightmap_for", "build_runs"]), "Phases 167-168 port heightmap_for and build_runs")
	if EXPECT_FALLBACK_ARG in args:
		assert_eq(mode, NativeBuilder.MODE_FALLBACK, "no binary: the loader reports the GDScript fallback")
		assert_eq(NativeBuilder.version(), -1, "no native version on the fallback")
	assert_eq(mode == NativeBuilder.MODE_NATIVE, ClassDB.class_exists(NativeBuilder.CLASS_NAME), "native exactly when the class is registered")
	assert_eq(NativeBuilder.use_native("heightmap_for"), mode == NativeBuilder.MODE_NATIVE, "heightmap_for is native exactly when the extension loaded")

func _test_native_routes_only_ported() -> void:
	NativeBuilder.init()
	assert_eq(NativeBuilder.use_native("build_runs"), NativeBuilder.is_native(), "build_runs is native exactly when the extension loaded")
	for fn in ["build_chunk_arrays"]:
		assert_false(NativeBuilder.use_native(fn), "%s is not ported yet" % fn)
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

func _test_native_heightmap_parity() -> void:
	NativeBuilder.init()
	if not NativeBuilder.is_native():
		print("[Native] heightmap parity skipped: no native extension in this run")
		return
	var seed_v := 777001
	var noise := FastNoiseLite.new()
	TerrainSlice.configure_noise(noise, seed_v)
	var chunks := _native_parity_chunks()
	var c := TerrainSlice.circumference_chunks()
	ChunkRecordsScript.clear()
	for round_i in range(2):
		if round_i == 1:
			# An edited chunk: records keep their own corner heights, here lifted off the generator's.
			for pos: Vector2i in [chunks[0], chunks[5], chunks[6]]:
				ChunkRecordsScript.set_record(pos, {"b": "TemperateForest", "h": [3.25, 4.5, -2.0, 9.125], "v": TerrainSlice.WORLDGEN_VERSION})
		for pos: Vector2i in chunks:
			var want := TerrainSlice.heightmap_for_gd(pos, seed_v, noise)
			var got := TerrainSlice.heightmap_for(pos, seed_v, noise)
			assert_eq(got.size(), want.size(), "native heightmap_for %s has the same size (records %d)" % [str(pos), round_i])
			assert_true(got == want, "native heightmap_for %s equals the GDScript reference (records %d)" % [str(pos), round_i])
	ChunkRecordsScript.clear()

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
	NativeBuilder.init()
	if not NativeBuilder.is_native():
		print("[Native] build_runs parity skipped: no native extension in this run")
		return
	var seed_v := 777001
	var noise := FastNoiseLite.new()
	TerrainSlice.configure_noise(noise, seed_v)
	ChunkRecordsScript.clear()
	var deposits_seen := 0
	var vein_colours := 0
	var topsoil := 0
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
			var want := VoxelSlice.build_runs_gd(chunk, hm, input)
			var got := VoxelSlice.build_runs(chunk, hm, input)
			assert_eq((got["runs"] as Dictionary).keys(), (want["runs"] as Dictionary).keys(), "native build_runs %s v%d has the same tiles in the same order" % [str(chunk), variant])
			assert_true(got["runs"] == want["runs"], "native build_runs %s v%d runs equal the GDScript reference" % [str(chunk), variant])
			assert_true(got["deposits"] == want["deposits"], "native build_runs %s v%d deposits equal the reference, same order" % [str(chunk), variant])
			deposits_seen += (want["deposits"] as Array).size()
			for key in (want["runs"] as Dictionary):
				for entry: Dictionary in want["runs"][key]:
					if entry.has("top_color"):
						topsoil += 1
	assert_true(deposits_seen > 0, "the fixed chunk set holds vein deposits, so the ore path is compared (%d)" % deposits_seen)
	assert_true(topsoil > 0, "the fixed chunk set holds topsoiled runs, so the topsoil path is compared (%d)" % topsoil)

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

func _test_native_release_workflow() -> void:
	var f := FileAccess.open("res://.github/workflows/release.yml", FileAccess.READ)
	if f == null:
		return   # an export does not carry .github; the suite runs from the project tree
	var text := f.get_as_text()
	assert_true(text.contains('tags: ["v*"]'), "the release workflow triggers on v* tags")
	for p in ["linux", "windows", "macos"]:
		assert_true(text.contains("name: " + p), "the release builds the %s binary" % p)
	assert_true(text.contains("gh release create"), "the release workflow creates the GitHub Release")
