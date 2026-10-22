extends "res://src/tests/test_support.gd"
## Phase 166 — the native chunk builder scaffold: the loader's native / GDScript-fallback decision.
## CI runs the suite twice: once with no binary (`--expect-fallback`) and once with the Linux
## binary built by the `native` job (`--expect-native`). Without either flag the real loader is
## only checked for consistency with what the engine can see.

const NativeBuilder := preload("res://src/terrain/native_builder.gd")

const EXPECT_NATIVE_ARG := "--expect-native"
const EXPECT_FALLBACK_ARG := "--expect-fallback"

func register() -> void:
	_run_test("native: the loader picks native only when the extension loaded and the class exists", _test_native_mode_decision)
	_run_test("native: the real loader matches the build (native present or fallback)",             _test_native_real_loader)
	_run_test("native: only ported functions are routed natively",                                 _test_native_routes_only_ported)
	_run_test("native: heightmap_for matches the GDScript reference on the fixed chunk set",       _test_native_heightmap_parity)
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
		assert_eq(NativeBuilder.version(), 2, "the native class reports its version")
		var b: RefCounted = ClassDB.instantiate(NativeBuilder.CLASS_NAME)
		assert_eq(b.call("functions") as PackedStringArray, PackedStringArray(["heightmap_for"]), "Phase 167 ports heightmap_for")
	if EXPECT_FALLBACK_ARG in args:
		assert_eq(mode, NativeBuilder.MODE_FALLBACK, "no binary: the loader reports the GDScript fallback")
		assert_eq(NativeBuilder.version(), -1, "no native version on the fallback")
	assert_eq(mode == NativeBuilder.MODE_NATIVE, ClassDB.class_exists(NativeBuilder.CLASS_NAME), "native exactly when the class is registered")
	assert_eq(NativeBuilder.use_native("heightmap_for"), mode == NativeBuilder.MODE_NATIVE, "heightmap_for is native exactly when the extension loaded")

func _test_native_routes_only_ported() -> void:
	NativeBuilder.init()
	for fn in ["build_runs", "build_chunk_arrays"]:
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
