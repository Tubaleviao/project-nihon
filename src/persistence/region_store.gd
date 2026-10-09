extends RefCounted
## Region store — the world's voxel edits, one file per 32×32-chunk region (Phase 52).
##
## The monolithic `world.json` held every edit and lived fully in RAM; each save read,
## merged and rewrote the whole thing, which is O(total edits). A region file holds the
## edits of one square of chunks:
##
##   `<dir>/r.<rx>.<rz>.json`  →  `{ "version": 1, "chunks": { "cx,cz": { "edits": {...} } } }`
##
## so a save touches exactly the regions that contain a dirty chunk, and a boot loads
## only the regions near a player. `world.json` keeps the global state (seed, stations,
## creatures, the local player id) and no chunks.
##
## The interface is `load_region` / `save_region` / `list_dirty` (plus `list_regions`),
## deliberately free of any node or signal, so a database backend can replace the files
## without touching a caller, and so it is safe to run on the save worker thread.
##
## Pure helpers (`region_of_chunk`, `region_of_chunk_key`, `group_manifest`,
## `fold_chunks`, `file_name`) are static and are what the tests pin.
const Diag := preload("res://src/core/diag.gd")

## Chunks per region side. A region is REGION_SIZE × REGION_SIZE chunks.
const REGION_SIZE := 32
const REGION_FORMAT_VERSION := 1
const FILE_PREFIX := "r."
const FILE_EXT := ".json"

var dir: String = "user://saves/server/regions/"
var atomic_writes: bool = true
## The "cx,cz" keys of the chunks in regions the LAST `write_chunks` could not write (read or
## save failed). A save that failed in one region should put back only those chunks as dirty.
var last_failed_chunk_keys: Array = []
## Phase 89 — malformed-entry warnings already raised by this store, keyed "path|chunk key". Reads
## run on worker threads, so the set is guarded.
var _warned: Dictionary = {}
var _warned_mutex := Mutex.new()

func _init(region_dir: String = "", atomic: bool = true) -> void:
	if not region_dir.is_empty():
		dir = region_dir if region_dir.ends_with("/") else region_dir + "/"
	atomic_writes = atomic

# ---------------------------------------------------------------------------
# Pure helpers
# ---------------------------------------------------------------------------

## The region a chunk belongs to. Floor division, so negative chunks land in negative
## regions (chunk -1 is in region -1, not region 0).
static func region_of_chunk(chunk: Vector2i) -> Vector2i:
	return Vector2i(floori(float(chunk.x) / float(REGION_SIZE)), floori(float(chunk.y) / float(REGION_SIZE)))

## The region of a "cx,cz" chunk key.
static func region_of_chunk_key(ckey: String) -> Vector2i:
	var parts: PackedStringArray = ckey.split(",")
	if parts.size() != 2:
		return Vector2i.ZERO
	return region_of_chunk(Vector2i(int(parts[0]), int(parts[1])))

static func region_key(region: Vector2i) -> String:
	return "%d,%d" % [region.x, region.y]

static func region_from_key(rkey: String) -> Vector2i:
	var parts: PackedStringArray = rkey.split(",")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))

## The file name of region `region`: `r.<rx>.<rz>.json`.
static func file_name(region: Vector2i) -> String:
	return "%s%d.%d%s" % [FILE_PREFIX, region.x, region.y, FILE_EXT]

## Parse a region file name back into its coordinate; `ok` is false for anything that is
## not a region file.
static func region_from_file_name(name: String) -> Dictionary:
	if not name.begins_with(FILE_PREFIX) or not name.ends_with(FILE_EXT):
		return { "ok": false, "region": Vector2i.ZERO }
	var core := name.substr(FILE_PREFIX.length(), name.length() - FILE_PREFIX.length() - FILE_EXT.length())
	# "-1.-2" splits on "." into ["-1", "-2"]; both halves must be integers.
	var parts: PackedStringArray = core.split(".")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return { "ok": false, "region": Vector2i.ZERO }
	return { "ok": true, "region": Vector2i(int(parts[0]), int(parts[1])) }

## Group a chunk manifest ({ "cx,cz": entry }) by region: { "rx,rz": { "cx,cz": entry } }.
static func group_manifest(chunks: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for ckey in chunks:
		if str(ckey).split(",").size() != 2:
			Diag.warn("RegionStore: skipping malformed chunk key '%s'" % str(ckey))
			continue
		var rkey := region_key(region_of_chunk_key(str(ckey)))
		if not out.has(rkey):
			out[rkey] = {}
		out[rkey][ckey] = chunks[ckey]
	return out

## Every region a set of "cx,cz" chunk keys touches, as sorted "rx,rz" keys.
static func regions_of_chunk_keys(chunk_keys: Array) -> Array:
	var seen: Dictionary = {}
	for ckey in chunk_keys:
		seen[region_key(region_of_chunk_key(str(ckey)))] = true
	var out: Array = seen.keys()
	out.sort()
	return out

## True when `entry` is the deletion marker `{ "edits": {} }` (the `edits` key present and an
## empty Dictionary; any other shape is folded in, never read as a deletion). Pure.
static func is_empty_edit_set(entry: Variant) -> bool:
	if not (entry is Dictionary):
		return false
	var edits: Variant = (entry as Dictionary).get("edits", null)
	return edits is Dictionary and (edits as Dictionary).is_empty()

## Fold `incoming` chunk entries over `base`. An incoming entry that is an EMPTY edit set
## (`{ "edits": {} }`) deletes the chunk — the incremental save's way of saying a chunk's
## edits compacted away; `deletions` false stores every entry verbatim (a full save or a
## migration never carries the marker). Pure.
##
## Phase 75 — an incoming entry flagged `"merge": true` (a chunk whose resident edits are only
## the vein depletions written while it was evicted) is OVERLAID on the stored entry: per tile,
## the stored ops stay, minus any op the entry repeats and any `deplete` of a vein the entry
## depletes, followed by the entry's ops. The flag is never stored.
static func fold_chunks(base: Dictionary, incoming: Dictionary, deletions := true) -> Dictionary:
	var out := base.duplicate()   # shallow: an entry is replaced or erased wholesale, never edited in place
	for ckey in incoming:
		var entry: Variant = incoming[ckey]
		if deletions and is_empty_edit_set(entry):
			out.erase(ckey)
			continue
		if entry is Dictionary and bool((entry as Dictionary).get("merge", false)):
			out[ckey] = overlay_entry(out.get(ckey, null), entry)
			continue
		out[ckey] = entry
	return out

## `entry` laid over `stored` (a chunk entry or null), without the `merge` flag. Pure.
static func overlay_entry(stored: Variant, entry: Dictionary) -> Dictionary:
	var result: Dictionary = (stored as Dictionary).duplicate(true) if stored is Dictionary else {}
	var edits: Dictionary = result.get("edits", {}) if result.get("edits", {}) is Dictionary else {}
	var incoming_edits: Variant = entry.get("edits", {})
	if incoming_edits is Dictionary:
		for tile in incoming_edits:
			var ops_in: Array = incoming_edits[tile] if incoming_edits[tile] is Array else []
			var depleted: Dictionary = {}
			for op in ops_in:
				if op is Dictionary and str(op.get("op", "")) == "deplete":
					depleted[str(op.get("vein", ""))] = true
			var merged: Array = []
			var old: Variant = edits.get(tile, [])
			var stored_taken: Dictionary = {}
			if old is Array:
				for op in old:
					if ops_in.has(op):
						continue
					if op is Dictionary and str(op.get("op", "")) == "deplete" and depleted.has(str(op.get("vein", ""))):
						# A vein the entry depletes: the larger count wins, the stored one may be ahead.
						var vid := str(op.get("vein", ""))
						stored_taken[vid] = maxi(int(stored_taken.get(vid, 0)), int(op.get("taken", 0)))
						continue
					merged.append(op)
			for op in ops_in:
				if op is Dictionary and str(op.get("op", "")) == "deplete" and stored_taken.has(str(op.get("vein", ""))):
					var lifted: Dictionary = (op as Dictionary).duplicate()
					lifted["taken"] = maxi(int(lifted.get("taken", 0)), int(stored_taken[str(op.get("vein", ""))]))
					merged.append(lifted)
				else:
					merged.append(op)
			edits[tile] = merged
	result["edits"] = edits
	var materials: Variant = entry.get("materials", null)
	if materials is Dictionary:
		var mats: Dictionary = result.get("materials", {}) if result.get("materials", {}) is Dictionary else {}
		mats.merge(materials, true)
		result["materials"] = mats
	return result

# ---------------------------------------------------------------------------
# Files
# ---------------------------------------------------------------------------

func path_of(region: Vector2i) -> String:
	return dir + file_name(region)

func has_region(region: Vector2i) -> bool:
	return FileAccess.file_exists(path_of(region))

## The chunk entries a region file holds, or an empty dict when absent / unreadable.
func load_region(region: Vector2i) -> Dictionary:
	return read_region(region)["chunks"]

## Like `load_region`, but `ok` is false when the file EXISTS and could not be read or
## parsed. A writer must not fold into the empty base of an unreadable file: that would
## replace it and lose every chunk it held. Malformed chunk entries are NOT in `chunks`; they are
## returned in `raw_invalid` ({ "cx,cz": raw value }) so a rewrite of the region keeps them. `warn`
## false is the save path's quiet re-read: the warning belongs to the read that surfaced the entry.
func read_region(region: Vector2i, warn := true) -> Dictionary:
	var path := path_of(region)
	if not FileAccess.file_exists(path):
		return { "ok": true, "chunks": {}, "raw_invalid": {} }
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		Diag.error("RegionStore: cannot open %s for read — %s" % [path, error_string(FileAccess.get_open_error())])
		return { "ok": false, "chunks": {} }
	var text := file.get_as_text()
	file.close()
	# JSON.new().parse() reports through its return code; parse_string() also logs an engine error.
	var json := JSON.new()
	var data: Variant = json.data if json.parse(text) == OK else null
	if not (data is Dictionary):
		Diag.error("RegionStore: %s contains invalid JSON" % path)
		return { "ok": false, "chunks": {} }
	var raw: Variant = (data as Dictionary).get("chunks", {})
	var chunks := {}
	var raw_invalid := {}
	if raw is Dictionary:
		for ckey in raw:
			if raw[ckey] is Dictionary and _chunk_entry_valid(raw[ckey]):
				chunks[ckey] = raw[ckey]
			else:
				# Phase 75 — not handed to a caller as an edit, but kept so a rewrite can put it back.
				raw_invalid[ckey] = raw[ckey]
				if warn and _first_warning("%s|%s" % [path, str(ckey)]):
					Diag.warn("RegionStore: %s: skipping malformed chunk entry '%s'" % [path, str(ckey)])
	return { "ok": true, "chunks": chunks, "raw_invalid": raw_invalid }

## Phase 89 — true the first time `key` is seen since construction or `reset_warnings`.
func _first_warning(key: String) -> bool:
	_warned_mutex.lock()
	var first := not _warned.has(key)
	_warned[key] = true
	_warned_mutex.unlock()
	return first

## Forget which malformed entries were warned about, so the next read of each warns again (tests,
## and a switch to another world).
func reset_warnings() -> void:
	_warned_mutex.lock()
	_warned.clear()
	_warned_mutex.unlock()

## Phase 61 — a chunk entry's `edits`, when present, must be a Dictionary (tile key → op list)
## and its `materials`, when present, a Dictionary. Only the container types are checked: the
## tile's value is left to `VoxelSlice` to migrate (legacy entries carry bare numbers), except that
## an op LIST must hold only ops (Dictionaries). Pure.
static func _chunk_entry_valid(entry: Dictionary) -> bool:
	if entry.has("edits"):
		if not (entry["edits"] is Dictionary):
			return false
		for tile_key in entry["edits"]:
			var ops: Variant = entry["edits"][tile_key]
			if ops is Array:
				for op in ops:
					if not (op is Dictionary):
						return false
	if entry.has("materials") and not (entry["materials"] is Dictionary):
		return false
	return true

## True when `entry` is a Dictionary whose `edits` and `materials`, where present, are Dictionaries. Pure.
static func is_valid_chunk_entry(entry: Variant) -> bool:
	return entry is Dictionary and _chunk_entry_valid(entry)

## Write one region's chunk entries (replacing the file). An EMPTY chunk set removes the
## file instead, so a region whose last edit was put back leaves nothing on disk.
func save_region(region: Vector2i, chunks: Dictionary) -> Error:
	var path := path_of(region)
	if chunks.is_empty():
		if FileAccess.file_exists(path):
			return DirAccess.remove_absolute(path)
		return OK
	DirAccess.make_dir_recursive_absolute(dir)
	var target := path + ".tmp" if atomic_writes else path
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		var err := FileAccess.get_open_error()
		Diag.error("RegionStore: cannot open %s for write — %s" % [target, error_string(err)])
		return err
	file.store_string(JSON.stringify({ "version": REGION_FORMAT_VERSION, "chunks": chunks }))
	file.close()
	if atomic_writes:
		var rename_err := DirAccess.rename_absolute(target, path)
		if rename_err != OK:
			Diag.error("RegionStore: rename %s → %s failed — %s" % [target, path, error_string(rename_err)])
			return rename_err
	return OK

## Fold `chunks` (a manifest, possibly incremental) into the regions they belong to. Each
## affected region is read, folded and rewritten; no other region file is touched. Returns
## the first Error, or OK — a region that fails does not stop the others from being written
## (Phase 61). This is the whole write path of a world save.
func write_chunks(chunks: Dictionary, deletions := true) -> Error:
	var grouped := group_manifest(chunks)
	var first_error: Error = OK
	last_failed_chunk_keys = []
	for rkey in grouped:
		var region := region_from_key(str(rkey))
		var read := read_region(region, false)
		if not bool(read["ok"]):
			# Leave the unreadable file alone rather than replace it — and keep saving the rest.
			if first_error == OK:
				first_error = ERR_FILE_CORRUPT
			last_failed_chunk_keys.append_array(grouped[rkey].keys())
			continue
		var folded := fold_chunks(read["chunks"], grouped[rkey], deletions)
		# Phase 75 — a malformed entry survives the rewrite unchanged unless this save carries a
		# valid entry (or the deletion marker) for its key.
		var kept: Dictionary = read.get("raw_invalid", {})
		for ckey in kept:
			if not grouped[rkey].has(ckey):
				folded[ckey] = kept[ckey]
		var err := save_region(region, folded)
		if err != OK:
			last_failed_chunk_keys.append_array(grouped[rkey].keys())
			if first_error == OK:
				first_error = err
	return first_error

## The regions that must be rewritten for a set of dirty "cx,cz" chunk keys.
func list_dirty(dirty_chunk_keys: Array) -> Array:
	var out: Array = []
	for rkey in regions_of_chunk_keys(dirty_chunk_keys):
		out.append(region_from_key(str(rkey)))
	return out

## Every region that has a file on disk.
func list_regions() -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		var parsed := region_from_file_name(f)
		if bool(parsed["ok"]):
			out.append(parsed["region"])
	return out

## Split a monolithic chunk manifest (a Phase 51 `world.json`'s "chunks") into region
## files. A chunk a region file already holds WINS over the monolith's copy: the file is
## either an earlier run of this same migration (identical data) or newer saves written
## after a migration whose `world.json` rewrite failed, and the stale monolith must never
## overwrite those. Re-running after a crash is therefore harmless.
func migrate_manifest(chunks: Dictionary) -> Error:
	var grouped := group_manifest(chunks)
	for rkey in grouped:
		var region := region_from_key(str(rkey))
		var read := read_region(region, false)
		if not bool(read["ok"]):
			return ERR_FILE_CORRUPT
		var base: Dictionary = read["chunks"]
		var kept: Dictionary = read.get("raw_invalid", {})
		var missing := {}
		for ckey in grouped[rkey]:
			if not base.has(ckey):
				missing[ckey] = grouped[rkey][ckey]
		if missing.is_empty():
			continue
		var folded := fold_chunks(base, missing, false)
		for ckey in kept:
			if not missing.has(ckey):
				folded[ckey] = kept[ckey]
		var err := save_region(region, folded)
		if err != OK:
			return err
	return OK
