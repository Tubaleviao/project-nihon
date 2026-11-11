extends RefCounted
## Phase 166 — the native chunk builder's routing, now a thin view of the general loader
## (`src/core/native_loader.gd`, Phase 248) for the `NativeChunkBuilder` class. The GDScript builder is
## the reference; the native class is used when the extension loaded, the class is current and it
## lists the function. Boot logs `[Native] chunk builder: native|gdscript fallback`.
##
## Routed functions: Phase 167 `heightmap_for`, 168 `build_runs`, 169 `build_chunk_arrays`,
## 190 `build_coarse_arrays`.

const NativeLoader := preload("res://src/core/native_loader.gd")

const EXTENSION_PATH := NativeLoader.EXTENSION_PATH
const CLASS_NAME := "NativeChunkBuilder"
const MODE_NATIVE := NativeLoader.MODE_NATIVE
const MODE_FALLBACK := NativeLoader.MODE_FALLBACK
const NO_NATIVE_ARG := NativeLoader.NO_NATIVE_ARG
## Functions the game may route natively, in step order.
const FUNCTIONS: Array[String] = ["heightmap_for", "build_runs", "build_chunk_arrays", "build_coarse_arrays"]
## The oldest native builder whose results match this GDScript (history in `NativeLoader.CLASSES`).
const REQUIRED_VERSION: int = NativeLoader.CLASSES["NativeChunkBuilder"]["required"]

## The mode for a given availability. Pure, so both outcomes are testable on any build.
static func mode_for(extension_loaded: bool, class_available: bool) -> String:
	return MODE_NATIVE if extension_loaded and class_available else MODE_FALLBACK

static func forced_fallback() -> bool:
	return NativeLoader.forced_fallback()

static func library_present() -> bool:
	return NativeLoader.library_present()

## Load the extension (once) and report the chunk builder's mode.
static func init() -> String:
	NativeLoader.init()
	return NativeLoader.mode(CLASS_NAME)

static func mode() -> String:
	return init()

static func is_native() -> bool:
	return NativeLoader.is_native(CLASS_NAME)

## True when `fn` should run in native code.
static func use_native(fn: String) -> bool:
	return FUNCTIONS.has(fn) and NativeLoader.use_native(CLASS_NAME, fn)

## The native builder instance for `use_native` callers. Stateless, so any thread may call it.
static func builder() -> Object:
	return NativeLoader.instance(CLASS_NAME)

## Native builder version, or -1 on the fallback.
static func version() -> int:
	return NativeLoader.version(CLASS_NAME)

static func memo(key: String, make: Callable) -> Variant:
	return NativeLoader.memo(key, make)

static func forget_memo(key: String = "") -> void:
	NativeLoader.forget_memo(key)

## Test hook: forget the cached decision so `init()` runs again.
static func reset_for_tests() -> void:
	NativeLoader.reset_for_tests()
