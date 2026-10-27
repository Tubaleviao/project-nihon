extends RefCounted
## Phase 166 — the native chunk builder loader. The GDScript builder is the reference and
## stays the default; the optional `NativeChunkBuilder` GDExtension (`native/`) is picked when its
## binary for this platform is present and loads, and the game logs which one is in use.
##
## `use_native(fn)` is the per-function switch later steps route through: Phase 167 `heightmap_for`,
## 168 `build_runs`, 169 `build_chunk_arrays`, 190 `build_coarse_arrays`. A function is routed native only when the extension is
## loaded AND the native class reports it (`functions()`), so this scaffold, which implements none,
## routes nothing and every chunk is still built by GDScript.

const EXTENSION_PATH := "res://native/nihon_native.gdextension"
const CLASS_NAME := "NativeChunkBuilder"
const MODE_NATIVE := "native"
const MODE_FALLBACK := "gdscript"

## User arg that forces the GDScript fallback even with the binary present (CI times both builders).
const NO_NATIVE_ARG := "--no-native"
## Functions a later step may route natively, in step order.
const FUNCTIONS: Array[String] = ["heightmap_for", "build_runs", "build_chunk_arrays", "build_coarse_arrays"]
## The oldest native builder whose results match this GDScript. A stale binary (an older build left in
## `native/bin`) would compute different terrain than its peers, so it is not used. 5 = worldgen 9's spawn plain; 6 = worldgen 10 ridges;
## 7 = Phase 190 coarse builds.
const REQUIRED_VERSION := 7

static var _loaded := false
static var _mode := MODE_FALLBACK
static var _builder: RefCounted = null

## The mode for a given availability. Pure, so both outcomes are testable on any build.
static func mode_for(extension_loaded: bool, class_available: bool) -> String:
	return MODE_NATIVE if extension_loaded and class_available else MODE_FALLBACK

## True when `--no-native` (a user arg) forces the GDScript fallback.
static func forced_fallback() -> bool:
	return NO_NATIVE_ARG in OS.get_cmdline_user_args()

## True when the .gdextension lists a binary for this platform and build that exists on disk.
## Checked first so a checkout without the binaries boots silently on the fallback instead of
## logging an engine error for the missing library.
static func library_present() -> bool:
	if forced_fallback():
		return false
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
	# `--no-native` forces the fallback even when the class is registered (library_present() checks it too).
	_mode = mode_for(ext_loaded and not forced_fallback(), ClassDB.class_exists(CLASS_NAME))
	if _mode == MODE_NATIVE:
		var b: RefCounted = ClassDB.instantiate(CLASS_NAME)
		var v := int(b.call("version"))
		if v < REQUIRED_VERSION:
			_mode = MODE_FALLBACK
			print("[Native] chunk builder: gdscript fallback (native version %d is older than %d; rebuild native/)" % [v, REQUIRED_VERSION])
		else:
			_builder = b
			print("[Native] chunk builder: native (version %d)" % v)
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

## The native builder instance for `use_native` callers. Stateless, so any thread may call it.
static func builder() -> RefCounted:
	return _builder

## Native builder version, or -1 on the fallback.
static func version() -> int:
	return int(_builder.call("version")) if is_native() else -1

static var _memo: Dictionary = {}
static var _memo_lock := Mutex.new()

## The value `make` builds for `key`, built once under a lock (#452): workers that reach a native
## input table before the main thread warmed it share one build instead of racing to fill it.
static func memo(key: String, make: Callable) -> Variant:
	_memo_lock.lock()
	if not _memo.has(key):
		_memo[key] = make.call()
	var value: Variant = _memo[key]
	_memo_lock.unlock()
	return value

## Test hook: drop a memoized value (or all of them) so the next `memo` call builds it again.
static func forget_memo(key: String = "") -> void:
	_memo_lock.lock()
	if key.is_empty():
		_memo.clear()
	else:
		_memo.erase(key)
	_memo_lock.unlock()

## Test hook: forget the cached decision so `init()` runs again.
static func reset_for_tests() -> void:
	_loaded = false
	_mode = MODE_FALLBACK
	_builder = null
