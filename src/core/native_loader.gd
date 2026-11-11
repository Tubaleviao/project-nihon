extends RefCounted
## Phase 248 — the general native loader. The GDScript is the reference and the game runs without
## any native code; the optional GDExtension (`native/`) is loaded once, when its binary for this
## platform and build is present, and each class it registers is checked on its own:
##
## - a class the binary does not register (an older build, or no binary at all) falls back;
## - a class older than its required version (`CLASSES`) falls back: a stale binary left in
##   `native/bin` would compute different results than its peers;
## - a function the class does not list in `functions()` falls back.
##
## Callers ask `use_native(class, function)` and call `instance(class)` when it says yes. A new class is
## one line in `CLASSES` (see native/README.md); it needs no new loader.

const EXTENSION_PATH := "res://native/nihon_native.gdextension"
const MODE_NATIVE := "native"
const MODE_FALLBACK := "gdscript"
## User arg that forces the GDScript fallback even with the binary present (CI times both).
const NO_NATIVE_ARG := "--no-native"

## Every native class the game routes: the oldest version whose results match this GDScript, and the
## name its `[Native] <label>: native|gdscript fallback` boot log line uses.
## NativeChunkBuilder: 5 = worldgen 9's spawn plain; 6 = worldgen 10 ridges; 7 = Phase 190 coarse
## builds; 8 = worldgen 11 massifs (Phase 211). NativeWorldShape: 1 = Phase 248 mix and noise.
const CLASSES := {
	"NativeChunkBuilder": {"required": 9, "label": "chunk builder"},
	"NativeWorldShape": {"required": 1, "label": "world shape"},
}

const REASON_NATIVE := ""
const REASON_MISSING := "missing"
const REASON_OLD := "old"
const REASON_FORCED := "forced"

static var _loaded := false
static var _entries: Dictionary = {}   ## class name -> entry (see `resolve`)
static var _init_lock := Mutex.new()

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

## Pure: the routing entry for one class, from the instance the engine gave (null when the class is not
## registered) and the version this GDScript needs. Testable with any object that has `version()` and
## `functions()`.
static func resolve(obj: Object, required: int) -> Dictionary:
	if obj == null:
		return {"native": false, "instance": null, "version": -1, "functions": PackedStringArray(), "reason": REASON_MISSING}
	var v := int(obj.call("version")) if obj.has_method("version") else -1
	if v < required:
		return {"native": false, "instance": null, "version": v, "functions": PackedStringArray(), "reason": REASON_OLD}
	var fns := PackedStringArray(obj.call("functions")) if obj.has_method("functions") else PackedStringArray()
	return {"native": true, "instance": obj, "version": v, "functions": fns, "reason": REASON_NATIVE}

## Load the extension if its binary exists and resolve every class in `CLASSES`. Idempotent and
## thread-safe; boot calls it on the main thread before any worker builds a chunk, and logs once per class.
static func init() -> void:
	if _loaded:
		return
	_init_lock.lock()
	if not _loaded:
		var ext := _load_extension()
		var forced := forced_fallback()
		for cls: String in CLASSES:
			var required := int(CLASSES[cls]["required"])
			var obj: Object = null
			if ext and not forced and ClassDB.class_exists(cls):
				obj = ClassDB.instantiate(cls)
			var entry := resolve(obj, required)
			if forced:
				entry["reason"] = REASON_FORCED
			_entries[cls] = entry
			print(log_line(str(CLASSES[cls]["label"]), entry, required))
		_loaded = true
	_init_lock.unlock()

static func _load_extension() -> bool:
	for cls: String in CLASSES:
		if ClassDB.class_exists(cls):
			return true   # already registered, e.g. through the editor's extension list
	if not library_present():
		return false
	var status := GDExtensionManager.load_extension(EXTENSION_PATH)
	return status == GDExtensionManager.LOAD_STATUS_OK or status == GDExtensionManager.LOAD_STATUS_ALREADY_LOADED

## The boot log line for one class. CI greps the chunk builder's (`[Native] chunk builder: native`).
static func log_line(label: String, entry: Dictionary, required: int) -> String:
	match str(entry["reason"]):
		REASON_NATIVE:
			return "[Native] %s: native (version %d)" % [label, int(entry["version"])]
		REASON_OLD:
			return "[Native] %s: gdscript fallback (native version %d is older than %d; rebuild native/)" % [label, int(entry["version"]), required]
		REASON_FORCED:
			return "[Native] %s: gdscript fallback (%s)" % [label, NO_NATIVE_ARG]
	return "[Native] %s: gdscript fallback (no native extension)" % label

static func _entry(cls: String) -> Dictionary:
	init()
	return _entries.get(cls, {}) as Dictionary

## True when `cls` resolved native.
static func is_native(cls: String) -> bool:
	return bool(_entry(cls).get("native", false))

## `MODE_NATIVE` or `MODE_FALLBACK` for `cls`.
static func mode(cls: String) -> String:
	return MODE_NATIVE if is_native(cls) else MODE_FALLBACK

## True when `fn` of `cls` should run in native code: the class resolved native and lists `fn`.
static func use_native(cls: String, fn: String) -> bool:
	var e := _entry(cls)
	return bool(e.get("native", false)) and (e["functions"] as PackedStringArray).has(fn)

## The native instance of `cls` for `use_native` callers, or null on the fallback. Native classes are
## stateless, so any thread may call it.
static func instance(cls: String) -> Object:
	return _entry(cls).get("instance", null) as Object

## The native version of `cls`, or -1 on the fallback.
static func version(cls: String) -> int:
	var e := _entry(cls)
	return int(e["version"]) if bool(e.get("native", false)) else -1

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

## Test hook: route `cls` through `obj` (null for a missing class) as if the engine had registered it.
## `reset_for_tests()` then `init()` restores the real decision.
static func install_for_tests(cls: String, obj: Object, required: int) -> void:
	init()
	_entries[cls] = resolve(obj, required)

## Test hook: forget every decision so `init()` runs again.
static func reset_for_tests() -> void:
	_init_lock.lock()
	_loaded = false
	_entries = {}
	_init_lock.unlock()
