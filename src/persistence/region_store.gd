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

## Fold `incoming` chunk entries over `base`. An incoming entry that is an EMPTY edit set
## (`{ "edits": {} }`) deletes the chunk — the incremental save's way of saying a chunk's
## edits compacted away; `deletions` false stores every entry verbatim (a full save or a
## migration never carries the marker). Pure.
static func fold_chunks(base: Dictionary, incoming: Dictionary, deletions := true) -> Dictionary:
	var out := base.duplicate()   # shallow: an entry is replaced or erased wholesale, never edited in place
	for ckey in incoming:
		var entry: Variant = incoming[ckey]
		if deletions and entry is Dictionary and (entry as Dictionary).has("edits") \
				and (entry as Dictionary)["edits"] is Dictionary and ((entry as Dictionary)["edits"] as Dictionary).is_empty():
			out.erase(ckey)
			continue
		out[ckey] = entry
	return out

# ---------------------------------------------------------------------------
# Files
# ---------------------------------------------------------------------------

func path_of(region: Vector2i) -> String:
	return dir + file_name(region)

func has_region(region: Vector2i) -> bool:
	return FileAccess.file_exists(path_of(region))

## The chunk entries a region file holds, or an empty dict when absent / unreadable.
func load_region(region: Vector2i) -> Dictionary:
	var path := path_of(region)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		Diag.error("RegionStore: cannot open %s for read — %s" % [path, error_string(FileAccess.get_open_error())])
		return {}
	var text := file.get_as_text()
	file.close()
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary):
		Diag.error("RegionStore: %s contains invalid JSON" % path)
		return {}
	var chunks: Variant = (data as Dictionary).get("chunks", {})
	return chunks if chunks is Dictionary else {}

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
## the first Error, or OK. This is the whole write path of a world save.
func write_chunks(chunks: Dictionary, deletions := true) -> Error:
	var grouped := group_manifest(chunks)
	for rkey in grouped:
		var region := region_from_key(str(rkey))
		var folded := fold_chunks(load_region(region), grouped[rkey], deletions)
		var err := save_region(region, folded)
		if err != OK:
			return err
	return OK

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
## files. Folds over what is already on disk, so re-running after a crash is harmless.
func migrate_manifest(chunks: Dictionary) -> Error:
	return write_chunks(chunks, false)
