extends RefCounted
## Phase 298 — which registries a client asks for the public list and a public host announces itself to.
##
## Order: `--registries a,b` on the command line (the harness, a server operator) → the player's list under
## `registries` in `user://settings.json` (set from the Join screen's Public servers tab; other keys are never
## touched) → the repository's seed, `res://config/registries.json`. Every entry must pass
## `RegistryWire.parse_registry`; anything else is dropped. An empty list means no public list.

const RegistryWire := preload("res://src/networking/registry_wire.gd")
const RegistryClient := preload("res://src/networking/registry_client.gd")

const SEED_PATH := "res://config/registries.json"
const ARG := "--registries"
const KEY := "registries"

static var settings_path: String = "user://settings.json"

## Only well-formed addresses, without duplicates, at most RegistryClient.MAX_REGISTRIES.
static func clean(raw: Variant) -> Array:
	var out: Array = []
	if not (raw is Array):
		return out
	for e in raw:
		if not (e is String):
			continue
		var s := (e as String).strip_edges()
		if bool(RegistryWire.parse_registry(s)["ok"]) and not out.has(s):
			out.append(s)
		if out.size() >= RegistryClient.MAX_REGISTRIES:
			break
	return out

## "a, b ,c" → ["a", "b", "c"] (the Join screen's field and `--registries`).
static func from_text(text: String) -> Array:
	return clean(Array(text.split(",", false)))

static func to_text(list: Array) -> String:
	return ", ".join(PackedStringArray(list))

static func seed_list(path: String = SEED_PATH) -> Array:
	var data := _read_json(path)
	return clean(data.get(KEY, []))

## The player's saved list, or null when they never set one (the seed applies).
static func saved(path: String = "") -> Variant:
	var data := _read_json(path if path != "" else settings_path)
	return clean(data[KEY]) if data.has(KEY) else null

## The list in effect for this process.
static func current(args: Array = Array(OS.get_cmdline_user_args())) -> Array:
	var i := args.find(ARG)
	if i >= 0 and i + 1 < args.size():
		return from_text(str(args[i + 1]))
	var s: Variant = saved()
	return s if s is Array else seed_list()

## Save the player's list (cleaned). Returns what was saved.
static func save(list: Array, path: String = "") -> Array:
	var p := path if path != "" else settings_path
	var data := _read_json(p)
	var kept := clean(list)
	data[KEY] = kept
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()
	return kept

static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not (json.data is Dictionary):
		return {}
	return json.data
