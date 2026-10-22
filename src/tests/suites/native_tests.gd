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
	_run_test("native: the scaffold routes no function natively",                                  _test_native_routes_nothing)
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
		assert_eq(NativeBuilder.version(), 1, "the native class reports its version")
		var b: RefCounted = ClassDB.instantiate(NativeBuilder.CLASS_NAME)
		assert_eq((b.call("functions") as PackedStringArray).size(), 0, "the scaffold implements no function yet")
	if EXPECT_FALLBACK_ARG in args:
		assert_eq(mode, NativeBuilder.MODE_FALLBACK, "no binary: the loader reports the GDScript fallback")
		assert_eq(NativeBuilder.version(), -1, "no native version on the fallback")
	assert_eq(mode == NativeBuilder.MODE_NATIVE, ClassDB.class_exists(NativeBuilder.CLASS_NAME), "native exactly when the class is registered")
	# The fallback path still builds: the GDScript heightmap is the reference either way.
	assert_false(NativeBuilder.use_native("heightmap_for"), "heightmap_for stays on GDScript in the scaffold")

func _test_native_routes_nothing() -> void:
	for fn in NativeBuilder.FUNCTIONS:
		assert_false(NativeBuilder.use_native(fn), "%s is not routed native yet" % fn)
	assert_false(NativeBuilder.use_native("not_a_function"), "an unknown function is never native")

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
