extends RefCounted
## Phase 223 — the local worlds the main menu's Play list shows.
##
## Each world is a folder `<base>/<id>/` holding `meta.json` ({name, seed, created, last_played})
## beside the authoritative save the listen-host boot writes there (`world.json`, regions, players):
## the folder IS the `PersistenceSlice.server_save_dir` of that world. The save that every boot used
## before the menu, `user://saves/server/`, is listed too (read-only, never deleted), so an existing
## world is still playable.
##
## Static and path-driven, so the suite runs it against a temp folder.

const PersistenceSlice := preload("res://src/persistence/persistence_slice.gd")

const DEFAULT_BASE := "user://worlds/"
const META_FILE := "meta.json"
const NAME_MAX := 32
## A folder id: what `create` mints. Anything else in the base folder is not a world this menu owns.
const ID_PATTERN := "^[a-z0-9_-]{1,48}$"
## The legacy save's id in a listing (not a valid folder id, so it can never name a folder).
const LEGACY_ID := ":legacy"

## A world name the player typed, trimmed: 1..NAME_MAX characters and no control characters.
## Returns "" when the name is not acceptable.
static func clean_name(raw: String) -> String:
	var s := raw.strip_edges()
	if s.is_empty() or s.length() > NAME_MAX:
		return ""
	for i in s.length():
		if s.unicode_at(i) < 32 or s.unicode_at(i) == 127:
			return ""
	return s

## Seeds are 32-bit signed: the noise seed is, and a value this size round-trips through `meta.json` exactly.
const SEED_MIN := -2147483648
const SEED_MAX := 2147483647

## Phase 238 — the one seed every new world uses: `WorldSystem.worldSeed` in the fabric.
const FALLBACK_SEED := 238

static func fabric_seed() -> int:
	var ws: Variant = GameData.WORLD_SYSTEMS.get("WorldSystem", null)
	if ws == null or ws.get("worldSeed") == null:
		return FALLBACK_SEED
	return int(ws.get("worldSeed"))

## The seed given to a new world: "" → the fabric seed (Phase 238; the New world form has no seed field,
## a typed seed is a dev override for tests and tools); an integer → itself; any other text →
## a stable hash of it (so "nihon" is always the same world). Null when it is too long, or an integer
## outside SEED_MIN..SEED_MAX.
static func parse_seed(raw: String) -> Variant:
	var s := raw.strip_edges()
	if s.length() > 64:
		return null
	if s.is_empty():
		return fabric_seed()
	if s.is_valid_int():
		if s.length() > 11:
			return null   # past any int32, and past what to_int() reads exactly
		var v := s.to_int()
		return v if v >= SEED_MIN and v <= SEED_MAX else null
	return s.hash() & SEED_MAX

static func valid_seed(v: Variant) -> bool:
	return (v is int or v is float) and float(v) == floorf(float(v)) and float(v) >= SEED_MIN and float(v) <= SEED_MAX

static func valid_id(id: String) -> bool:
	return RegEx.create_from_string(ID_PATTERN).search(id) != null and not id.contains("..")

## The folder id for a new world named `world_name`: a slug of its letters, unique in `base`.
static func mint_id(base: String, world_name: String) -> String:
	var slug := ""
	for c in world_name.to_lower():
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			slug += c
		elif not slug.ends_with("-") and slug != "":
			slug += "-"
	slug = slug.trim_suffix("-").left(32)
	if slug == "":
		slug = "world"
	var id := slug
	var n := 2
	while DirAccess.dir_exists_absolute(base.path_join(id)):
		id = "%s-%d" % [slug, n]
		n += 1
	return id

## Create a world folder. Returns {ok, id, dir, seed} or {ok: false, error: <i18n key>}.
static func create(base: String, raw_name: String, raw_seed: String, now: int = -1) -> Dictionary:
	var world_name := clean_name(raw_name)
	if world_name == "":
		return { "ok": false, "error": "menu.world.error_name" }
	var seed_v: Variant = parse_seed(raw_seed)
	if seed_v == null:
		return { "ok": false, "error": "menu.world.error_seed" }
	var id := mint_id(base, world_name)
	var dir := base.path_join(id) + "/"
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		return { "ok": false, "error": "menu.world.error_write" }
	var t := now if now >= 0 else int(Time.get_unix_time_from_system())
	var meta := { "name": world_name, "seed": int(seed_v), "created": t, "last_played": 0 }
	if not _write_meta(dir, meta):
		return { "ok": false, "error": "menu.world.error_write" }
	return { "ok": true, "id": id, "dir": dir, "seed": int(seed_v) }

## Every world in `base`, most recently played first: [{id, dir, name, seed, last_played, legacy}].
## `legacy_dir` (the pre-menu save) is listed when it holds a world record; "" skips it.
static func list(base: String, legacy_dir: String = PersistenceSlice.DEFAULT_SERVER_SAVE_DIR) -> Array:
	var out: Array = []
	for id in DirAccess.get_directories_at(base):
		if not valid_id(id):
			continue
		var dir := base.path_join(id) + "/"
		var meta := _read_json(dir + META_FILE)
		var world_name := clean_name(str(meta.get("name", "")))
		if world_name == "" or not valid_seed(meta.get("seed", null)):
			continue
		out.append({ "id": id, "dir": dir, "name": world_name, "seed": int(meta.get("seed", 0)),
			"last_played": int(meta.get("last_played", 0)), "legacy": false })
	if legacy_dir != "":
		var world := _read_json(legacy_dir + "world.json")
		if not world.is_empty():
			out.append({ "id": LEGACY_ID, "dir": legacy_dir, "name": "", "seed": int(world.get("seed", 0)),
				"last_played": int(world.get("timestamp", 0)), "legacy": true })
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["last_played"]) != int(b["last_played"]):
			return int(a["last_played"]) > int(b["last_played"])
		return str(a["id"]) < str(b["id"]))
	return out

## Delete world `id` and everything under its folder. The legacy save and anything that is not a
## world folder of `base` are refused. Returns true when the folder is gone.
static func delete(base: String, id: String) -> bool:
	if not valid_id(id):
		return false
	var dir := base.path_join(id)
	if not DirAccess.dir_exists_absolute(dir) or not FileAccess.file_exists(dir.path_join(META_FILE)):
		return false
	_remove_tree(dir)
	return not DirAccess.dir_exists_absolute(dir)

## Stamp world `dir` as played now (the legacy save has no meta and is left alone).
static func touch(dir: String, now: int = -1) -> void:
	var meta := _read_json(dir + META_FILE)
	if meta.is_empty():
		return
	meta["last_played"] = now if now >= 0 else int(Time.get_unix_time_from_system())
	_write_meta(dir, meta)

static func _remove_tree(path: String) -> void:
	for sub in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(sub))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)

static func _write_meta(dir: String, meta: Dictionary) -> bool:
	var f := FileAccess.open(dir + META_FILE, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(meta))
	f.close()
	return true

static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()   # not JSON.parse_string: a corrupt file is untrusted input, not an engine error
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var parsed: Variant = json.data
	return parsed if parsed is Dictionary else {}
