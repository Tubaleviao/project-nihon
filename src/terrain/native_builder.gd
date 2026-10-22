extends RefCounted
## Phase 166 — the native chunk builder loader. The GDScript builder is the reference and
## stays the default; the optional `NativeChunkBuilder` GDExtension (`native/`) is picked when its
## binary for this platform is present and loads, and the game logs which one is in use.
##
## `use_native(fn)` is the per-function switch later steps route through: Phase 167 `heightmap_for`,
## 168 `build_runs`, 169 `build_chunk_arrays`. A function is routed native only when the extension is
## loaded AND the native class reports it (`functions()`), so this scaffold, which implements none,
## routes nothing and every chunk is still built by GDScript.

const EXTENSION_PATH := "res://native/nihon_native.gdextension"
const CLASS_NAME := "NativeChunkBuilder"
const MODE_NATIVE := "native"
const MODE_FALLBACK := "gdscript"
## Functions a later step may route natively, in step order.
const FUNCTIONS: Array[String] = ["heightmap_for", "build_runs", "build_chunk_arrays"]

static var _loaded := false
static var _mode := MODE_FALLBACK
static var _builder: RefCounted = null

## The mode for a given availability. Pure, so both outcomes are testable on any build.
static func mode_for(extension_loaded: bool, class_available: bool) -> String:
	return MODE_NATIVE if extension_loaded and class_available else MODE_FALLBACK

## True when the .gdextension lists a binary for this platform and build that exists on disk.
## Checked first so a checkout without the binaries boots silently on the fallback instead of
## logging an engine error for the missing library.
static func library_present() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(EXTENSION_PATH) != OK:
		return false
	var platform := OS.get_name().to_lower()
	var build := "debug" if OS.is_debug_build() else "release"
	for key in cfg.get_section_keys("libraries"):
		var parts := key.split(".")
		if parts.size() >= 2 and parts[0] == platform and parts[1] == build and FileAccess.file_exists(str(cfg.get_value("libraries", key))):
			return true
	return false

## Load the extension if its binary exists and report the mode. Idempotent; logs once.
static func init() -> String:
	if _loaded:
		return _mode
	_loaded = true
	var ext_loaded := false
	if ClassDB.class_exists(CLASS_NAME):
		ext_loaded = true   # already registered, e.g. through the editor's extension list
	elif library_present():
		var status := GDExtensionManager.load_extension(EXTENSION_PATH)
		ext_loaded = status == GDExtensionManager.LOAD_STATUS_OK or status == GDExtensionManager.LOAD_STATUS_ALREADY_LOADED
	_mode = mode_for(ext_loaded, ClassDB.class_exists(CLASS_NAME))
	if _mode == MODE_NATIVE:
		_builder = ClassDB.instantiate(CLASS_NAME)
		print("[Native] chunk builder: native (version %d)" % int(_builder.call("version")))
	else:
		print("[Native] chunk builder: gdscript fallback (no native extension)")
	return _mode

static func mode() -> String:
	return init()

static func is_native() -> bool:
	return init() == MODE_NATIVE

## True when `fn` should run in native code. False for everything until a step ports it.
static func use_native(fn: String) -> bool:
	if not is_native() or not FUNCTIONS.has(fn):
		return false
	return (_builder.call("functions") as PackedStringArray).has(fn)

## Native builder version, or -1 on the fallback.
static func version() -> int:
	return int(_builder.call("version")) if is_native() else -1

## Test hook: forget the cached decision so `init()` runs again.
static func reset_for_tests() -> void:
	_loaded = false
	_mode = MODE_FALLBACK
	_builder = null
