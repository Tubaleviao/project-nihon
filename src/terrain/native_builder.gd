extends RefCounted
## Phase 166 — the native chunk builder loader. The GDScript builder is the reference and
## stays the default; the optional `NativeChunkBuilder` GDExtension (`native/`) is picked when its
## binary for this platform is present and loads, and the game logs which one is in use.
##
## `use_native(fn)` is the per-function switch later steps route through: Phase 167 `heightmap_for`,
## 168 `build_runs`, 169 `build_chunk_arrays`, 190 `build_coarse_arrays`. A function is routed native only when the extension is
## loaded AND the native class reports it (`functions()`), so this scaffold, which implements none,
## routes nothing and every chunk is still built by GDScript.

const Loader := preload("res://src/core/native_loader.gd")

const EXTENSION_PATH := Loader.EXTENSION_PATH
const CLASS_NAME := "NativeChunkBuilder"
const MODE_NATIVE := "native"
const MODE_FALLBACK := "gdscript"

## User arg that forces the GDScript fallback even with the binary present (CI times both builders).
const NO_NATIVE_ARG := Loader.NO_NATIVE_ARG
## Functions a later step may route natively, in step order.
const FUNCTIONS: Array[String] = ["heightmap_for", "build_runs", "build_chunk_arrays", "build_coarse_arrays"]
## The oldest native builder whose results match this GDScript (see `NativeLoader.REQUIRED`).
const REQUIRED_VERSION: int = Loader.REQUIRED["NativeChunkBuilder"]

static var _logged := false

## The mode for a given availability. Pure, so both outcomes are testable on any build.
static func mode_for(extension_loaded: bool, class_available: bool) -> String:
	return MODE_NATIVE if extension_loaded and class_available else MODE_FALLBACK

static func forced_fallback() -> bool:
	return Loader.forced_fallback()

static func library_present() -> bool:
	return Loader.library_present()

## Load the extension through the shared loader and report the chunk builder's mode. Idempotent; logs once.
static func init() -> String:
	Loader.init()
	var native := Loader.is_native(CLASS_NAME)
	if not _logged:
		_logged = true
		if native:
			print("[Native] chunk builder: native (version %d)" % Loader.version(CLASS_NAME))
		elif Loader.version(CLASS_NAME) >= 0:
			print("[Native] chunk builder: gdscript fallback (native version %d is older than %d; rebuild native/)" % [Loader.version(CLASS_NAME), REQUIRED_VERSION])
		else:
			print("[Native] chunk builder: gdscript fallback (no native extension)")
	return MODE_NATIVE if native else MODE_FALLBACK

static func mode() -> String:
	return init()

static func is_native() -> bool:
	return init() == MODE_NATIVE

## True when `fn` should run in native code: the extension loaded, the class is current and lists `fn`.
static func use_native(fn: String) -> bool:
	if not is_native() or not FUNCTIONS.has(fn):
		return false
	return Loader.use_native(CLASS_NAME, fn)

## The native builder instance for `use_native` callers. Stateless, so any thread may call it.
static func builder() -> RefCounted:
	return Loader.instance(CLASS_NAME)

## Native builder version, or -1 on the fallback.
static func version() -> int:
	return Loader.version(CLASS_NAME) if is_native() else -1

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
	Loader.reset_for_tests()
	_logged = false
