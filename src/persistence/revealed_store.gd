extends RefCounted
## The minimap's explored set and the player's waypoints, on disk (Phase 111, 117). One file per
## world seed under `user://saves/client/`:
## `{"seed", "runs": [z, x0, len, z, x0, len, ...], "waypoints": [{"name", "chunk", "local"}]}`.
## `runs` lists the chunks OLDEST FIRST, a run being consecutive chunks of one row that were revealed
## one after another, so the oldest-first cap survives a reload and an explored region is still a few
## numbers. The older `rows` form (a row-sorted map, no age) is still read. The set is capped (oldest
## dropped first) and a missing, foreign or corrupt file starts empty. The API speaks `Vector2i`; no
## string key is built per chunk. `save` is static and touches no node, so it can run on a worker
## given an immutable snapshot (`snapshot`).

const Diag := preload("res://src/core/diag.gd")
const WorldPos := preload("res://src/terrain/world_pos.gd")

const MAX_CHUNKS := 50000
const DEBOUNCE_SECONDS := 5.0
## Waypoints a world can hold, and the longest name kept.
const MAX_WAYPOINTS := 16
const MAX_NAME_CHARS := 24

static func path_for(dir: String, seed_v: int) -> String:
	return "%s/revealed_%d.json" % [dir, seed_v]

## Drop the oldest entries (dictionary insertion order, keys are `Vector2i`) until at most `cap_n` remain.
static func cap(revealed: Dictionary, cap_n: int = MAX_CHUNKS) -> void:
	var extra: int = revealed.size() - cap_n
	if extra <= 0:
		return
	for oldest in revealed.keys().slice(0, extra):
		revealed.erase(oldest)

## The chunks of `revealed` oldest first, as a new array: a snapshot the main thread can hand to a
## worker while it keeps changing the live dictionary.
static func snapshot(revealed: Dictionary) -> Array:
	return revealed.keys()

## A waypoint's name as kept: control characters dropped, trimmed, at most MAX_NAME_CHARS; "" when empty.
static func clean_name(text: String) -> String:
	var out := ""
	for i in text.length():
		var code := text.unicode_at(i)
		if code >= 32 and code != 127:
			out += text[i]
	return out.strip_edges().substr(0, MAX_NAME_CHARS)

static func encode(chunks: Array, seed_v: int, waypoints: Array = []) -> String:
	var runs: Array = []
	var cur_z := 0
	var cur_end := 0
	var open := false
	for c in chunks:
		var v: Vector2i = c
		if open and v.y == cur_z and v.x == cur_end + 1:
			runs[runs.size() - 1] += 1
			cur_end = v.x
			continue
		runs.append(v.y)
		runs.append(v.x)
		runs.append(1)
		cur_z = v.y
		cur_end = v.x
		open = true
	var wps: Array = []
	for w in waypoints:
		wps.append({ "name": str(w["name"]), "pos": WorldPos.pos_to_wire(w["pos"]) })
	return JSON.stringify({"seed": seed_v, "runs": runs, "waypoints": wps})

static func _is_num(v: Variant) -> bool:
	return v is float or v is int

## `{ chunks (oldest first), waypoints }` in `text`, or null when it is corrupt or for another seed.
static func decode_all(text: String, seed_v: int) -> Variant:
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return null
	var d: Dictionary = json.data
	if not _is_num(d.get("seed")) or int(d["seed"]) != seed_v:
		return null
	var out: Array = []
	if d.has("runs"):
		var runs = d["runs"]
		if not (runs is Array) or runs.size() % 3 != 0:
			return null
		for i in range(0, runs.size(), 3):
			if not (_is_num(runs[i]) and _is_num(runs[i + 1]) and _is_num(runs[i + 2])):
				return null
			if not _append_run(out, int(runs[i + 1]), int(runs[i]), int(runs[i + 2])):
				return null
	else:   # the Phase 111 form: {"<z>": [x0, len, ...]}, no age
		var rows = d.get("rows")
		if not (rows is Dictionary):
			return null
		for zs in rows:
			var rr = rows[zs]
			if not (zs is String) or not zs.is_valid_int() or not (rr is Array) or rr.size() % 2 != 0:
				return null
			for i in range(0, rr.size(), 2):
				if not (_is_num(rr[i]) and _is_num(rr[i + 1])):
					return null
				if not _append_run(out, int(rr[i]), int(zs), int(rr[i + 1])):
					return null
	return { "chunks": out, "waypoints": _decode_waypoints(d.get("waypoints")) }

static func _append_run(out: Array, x0: int, z: int, n: int) -> bool:
	if n < 0 or n > MAX_CHUNKS or out.size() + n > MAX_CHUNKS:
		return false
	for x in n:
		out.append(Vector2i(x0 + x, z))
	return true

## The waypoints in `raw`: entries with a valid wire position and a name, at most MAX_WAYPOINTS; the rest are skipped.
static func _decode_waypoints(raw: Variant) -> Array:
	var out: Array = []
	if not (raw is Array):
		return out
	for w in raw:
		if out.size() >= MAX_WAYPOINTS:
			break
		if not (w is Dictionary):
			continue
		var pos := WorldPos.pos_from_wire(w.get("pos"))
		var name_s := clean_name(str(w.get("name", "")))
		if pos.is_empty() or name_s == "":
			continue
		out.append({ "name": name_s, "pos": pos })
	return out

## The chunks in `text`, or null when it is corrupt or for another seed.
static func decode(text: String, seed_v: int) -> Variant:
	var got: Variant = decode_all(text, seed_v)
	return null if got == null else got["chunks"]

## Write atomically (tmp file then rename). Safe on a worker thread: it reads only its arguments.
static func save(path: String, chunks: Array, seed_v: int, waypoints: Array = []) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		Diag.warn("[RevealedStore] cannot write %s" % path)
		return false
	f.store_string(encode(chunks, seed_v, waypoints))
	f.close()
	if DirAccess.rename_absolute(tmp, path) != OK:
		DirAccess.remove_absolute(tmp)
		Diag.warn("[RevealedStore] cannot replace %s" % path)
		return false
	return true

## `{ chunks, waypoints }` saved for this seed; both empty (with one warning) when the file is missing or unusable.
static func load_all(path: String, seed_v: int) -> Dictionary:
	if not FileAccess.file_exists(path):
		Diag.warn("[RevealedStore] no explored-map file %s: starting empty" % path)
		return { "chunks": [], "waypoints": [] }
	var got: Variant = decode_all(FileAccess.get_file_as_string(path), seed_v)
	if got == null:
		Diag.warn("[RevealedStore] ignoring unusable explored-map file %s: starting empty" % path)
		return { "chunks": [], "waypoints": [] }
	return got

## The saved chunks for this seed (oldest first); empty (with one warning) when the file is missing or unusable.
static func load_file(path: String, seed_v: int) -> Array:
	return load_all(path, seed_v)["chunks"]
