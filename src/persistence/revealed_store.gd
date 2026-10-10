extends RefCounted
## The minimap's explored set, on disk (Phase 111). One file per world seed under
## `user://saves/client/`: `{"seed", "rows": {"<cz>": [x0, len, x0, len, ...]}}` — runs of
## consecutive chunks per row, so an explored region is a few numbers per row. The set is
## capped (oldest dropped first) and a missing, foreign or corrupt file starts empty.

const Diag := preload("res://src/core/diag.gd")

const MAX_CHUNKS := 50000
const DEBOUNCE_SECONDS := 5.0

static func path_for(dir: String, seed_v: int) -> String:
	return "%s/revealed_%d.json" % [dir, seed_v]

## Drop the oldest entries (dictionary insertion order) until at most `cap` remain.
static func cap(revealed: Dictionary, cap_n: int = MAX_CHUNKS) -> void:
	while revealed.size() > cap_n:
		for oldest in revealed:
			revealed.erase(oldest)
			break

static func encode(chunks: Array, seed_v: int) -> String:
	var rows: Dictionary = {}
	for c in chunks:
		var v: Vector2i = c
		if not rows.has(v.y):
			rows[v.y] = []
		rows[v.y].append(v.x)
	var out_rows: Dictionary = {}
	for z in rows:
		var xs: Array = rows[z]
		xs.sort()
		var runs: Array = []
		var start: int = xs[0]
		var prev: int = start
		for i in range(1, xs.size()):
			var x: int = xs[i]
			if x == prev:
				continue
			if x != prev + 1:
				runs.append(start)
				runs.append(prev - start + 1)
				start = x
			prev = x
		runs.append(start)
		runs.append(prev - start + 1)
		out_rows[str(z)] = runs
	return JSON.stringify({"seed": seed_v, "rows": out_rows})

## The chunks in `text`, or null when it is corrupt or for another seed.
static func decode(text: String, seed_v: int) -> Variant:
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return null
	var d: Dictionary = json.data
	if not (d.get("seed") is float or d.get("seed") is int) or int(d["seed"]) != seed_v:
		return null
	var rows = d.get("rows")
	if not (rows is Dictionary):
		return null
	var out: Array = []
	for zs in rows:
		var runs = rows[zs]
		if not (zs is String) or not zs.is_valid_int() or not (runs is Array) or runs.size() % 2 != 0:
			return null
		var z := int(zs)
		for i in range(0, runs.size(), 2):
			if not (runs[i] is float or runs[i] is int) or not (runs[i + 1] is float or runs[i + 1] is int):
				return null
			var x0 := int(runs[i])
			var n := int(runs[i + 1])
			if n < 0 or n > MAX_CHUNKS or out.size() + n > MAX_CHUNKS:
				return null
			for x in n:
				out.append(Vector2i(x0 + x, z))
	return out

static func save(path: String, chunks: Array, seed_v: int) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		Diag.warn("[RevealedStore] cannot write %s" % path)
		return false
	f.store_string(encode(chunks, seed_v))
	f.close()
	return DirAccess.rename_absolute(tmp, path) == OK

## The saved chunks for this seed; empty (with one warning) when the file is missing or unusable.
static func load_file(path: String, seed_v: int) -> Array:
	if not FileAccess.file_exists(path):
		Diag.warn("[RevealedStore] no explored-map file %s: starting empty" % path)
		return []
	var got = decode(FileAccess.get_file_as_string(path), seed_v)
	if got == null:
		Diag.warn("[RevealedStore] ignoring unusable explored-map file %s: starting empty" % path)
		return []
	return got
