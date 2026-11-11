extends RefCounted
## Phase 248 — the one loader for every native class. It loads the GDExtension once, checks each
## class's required version and routes per function: a function runs native only when the extension
## loaded, the class is registered, its `version()` is at least the one this GDScript needs and its
## `functions()` lists the name. Anything else runs the GDScript reference. A new native class adds a
## line to `REQUIRED` and nothing else here; `NativeBuilder` (the chunk builder's wrapper) sits on top.

const EXTENSION_PATH := "res://native/nihon_native.gdextension"

## User arg that forces the GDScript fallback even with the binary present (CI times both builders).
const NO_NATIVE_ARG := "--no-native"

## Class name -> the oldest version whose results match this GDScript. A stale binary would compute
## different values than its peers, so it is not used.
## NativeChunkBuilder: 5 = worldgen 9's spawn plain; 6 = worldgen 10 ridges; 7 = Phase 190 coarse
## builds; 8 = worldgen 11 massifs (Phase 211). NativeShape: 1 = Phase 248 hash and noise.
const REQUIRED := {
	"NativeChunkBuilder": 8,
	"NativeShape": 1,
}

static var _loaded := false
static var _extension_loaded := false
static var _instances: Dictionary = {}   # class name -> instance, only for classes that passed the checks
static var _versions: Dictionary = {}    # class name -> reported version (-1: not registered)

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

## Pure: is a class with this state usable? `version` is -1 for an unregistered class.
static func class_usable(extension_loaded: bool, version: int, required: int) -> bool:
	return extension_loaded and version >= 0 and version >= required

## Pure: does `fn` route native for a class with this state and `functions()` list?
static func routes(usable: bool, functions: PackedStringArray, fn: String) -> bool:
	return usable and functions.has(fn)

## Load the extension if its binary exists and vet every class in `REQUIRED`. Idempotent.
static func init() -> void:
	if _loaded:
		return
	_loaded = true
	if ClassDB.class_exists("NativeChunkBuilder"):
		_extension_loaded = true   # already registered, e.g. through the editor's extension list
	elif library_present():
		var status := GDExtensionManager.load_extension(EXTENSION_PATH)
		_extension_loaded = status == GDExtensionManager.LOAD_STATUS_OK or status == GDExtensionManager.LOAD_STATUS_ALREADY_LOADED
	# `--no-native` forces the fallback even when the class is registered (library_present() checks it too).
	_extension_loaded = _extension_loaded and not forced_fallback()
	for cls: String in REQUIRED:
		_versions[cls] = -1
		if not _extension_loaded or not ClassDB.class_exists(cls):
			continue
		var inst: RefCounted = ClassDB.instantiate(cls)
		_versions[cls] = int(inst.call("version"))
		if class_usable(true, int(_versions[cls]), int(REQUIRED[cls])):
			_instances[cls] = inst

## True when `cls` loaded, is current, and so may be asked for `functions()`.
static func is_native(cls: String) -> bool:
	init()
	return _instances.has(cls)

## The instance of a usable class, or null. Stateless natives, so any thread may call it.
static func instance(cls: String) -> RefCounted:
	init()
	return _instances.get(cls, null)

## The class's reported version, or -1 when it is absent (or the fallback is forced).
static func version(cls: String) -> int:
	init()
	return int(_versions.get(cls, -1))

## True when `fn` of `cls` should run in native code.
static func use_native(cls: String, fn: String) -> bool:
	init()
	if not _instances.has(cls):
		return false
	return (_instances[cls].call("functions") as PackedStringArray).has(fn)

static func reset_for_tests() -> void:
	_loaded = false
	_extension_loaded = false
	_instances = {}
	_versions = {}
