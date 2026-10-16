extends RefCounted
## Region store — the world's voxel edits, one file per 32×32-chunk region (Phase 52).
##
## The monolithic `world.json` held every edit and lived fully in RAM; each save read,
## merged and rewrote the whole thing, which is O(total edits). A region file holds the
## edits of one square of chunks:
##
##   `<dir>/r.<rx>.<rz>.json`  →  `{ "version": 2, "chunks": { "cx,cz": { "edits": {...}, "gen": {...} } } }`
##
## Phase 107 — a chunk entry may also carry a `gen` record: what the chunk LOOKED like when it was
## first visited (`v` worldgen version, `f` fingerprint, `b` biome key, `h` the four `WorldShape`
## corner heights), so a later generator change cannot move land players have seen. Version-1
## files hold no `gen` and load unchanged; a save writes version 2.
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
const SaveTxn := preload("res://src/persistence/save_txn.gd")

## Chunks per region side. A region is REGION_SIZE × REGION_SIZE chunks.
const REGION_SIZE := 32
const REGION_FORMAT_VERSION := 2
const TerrainSliceScript := preload("res://src/terrain/terrain_slice.gd")
const WorldShape := preload("res://src/terrain/world_shape.gd")
## Heights of a `gen` record are stored at this resolution (about 7 bytes each as JSON).
const GEN_HEIGHT_STEP := TerrainSliceScript.GEN_HEIGHT_STEP
## Phase 110 — bound on a record's tree budget `t` and on the spawn indices in `x` (indices are < this).
const GEN_TREE_MAX := 64
const FILE_PREFIX := "r."
const FILE_EXT := ".json"

var dir: String = "user://saves/server/regions/"
var atomic_writes: bool = true
## The "cx,cz" keys of the chunks in regions the LAST `write_chunks` could not write (read or
## save failed). A save that failed in one region should put back only those chunks as dirty.
var last_failed_chunk_keys: Array = []
## "rx,rz" -> how many saves in a row failed to stage that region; cleared by a success. A region that
## stays past `MAX_REGION_FAILURES` stops holding back the world record (see `PersistenceSlice`).
var region_failures: Dictionary = {}
## The "rx,rz" keys of the regions the LAST `stage_chunks` failed to stage.
var last_failed_region_keys: Array = []
const MAX_REGION_FAILURES := 5
## The journal of the world save that commits this store's regions with `world.json` (set by the
## persistence slice); a read while either journal exists may fall back to a `.bak`.
var outer_journal: String = ""
## Phase 121 — test hook: `fault.call(step)` returning true fails that write step ("region_tmp",
## "region_rename", "journal", "backup"). Invalid (unset) in production.
var fault: Callable = Callable()
## Phase 89 — malformed-entry warnings already raised by this store, keyed "path|chunk key". Reads
## run on worker threads, so the set is guarded.
var _warned: Dictionary = {}
var _warned_mutex := Mutex.new()

func _init(region_dir: String = "", atomic: bool = true) -> void:
	if not region_dir.is_empty():
		set_dir(region_dir)
	atomic_writes = atomic

## Point the store at another directory in place (Phase 121: holders of the store keep their reference).
func set_dir(region_dir: String) -> void:
	dir = region_dir if region_dir.ends_with("/") else region_dir + "/"

## Where a transaction over this directory records itself.
func journal_path() -> String:
	return dir + "save.journal"

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
		var stored_gen: Variant = (out[ckey] as Dictionary).get("gen", null) if out.get(ckey, null) is Dictionary else null
		if deletions and is_empty_edit_set(entry):
			# The edits compacted away; a recorded `gen` is not an edit and stays.
			var kept_gen: Variant = (entry as Dictionary).get("gen", stored_gen)
			if is_newer_gen(stored_gen) and not is_newer_gen(kept_gen):
				kept_gen = stored_gen   # an older generator's record never replaces a newer one
			if kept_gen is Dictionary:
				out[ckey] = { "gen": kept_gen }
			else:
				out.erase(ckey)
			continue
		if entry is Dictionary and bool((entry as Dictionary).get("merge", false)):
			out[ckey] = overlay_entry(out.get(ckey, null), entry)
			continue
		if entry is Dictionary and (entry as Dictionary).has("gen") and not (entry as Dictionary).has("edits") \
				and out.get(ckey, null) is Dictionary:
			# A gen-only entry sets the record and leaves the stored edits alone. A record a newer
			# generator wrote is not ours to replace (this build never read it, so it cannot know it).
			if is_newer_gen(stored_gen):
				continue
			var with_gen: Dictionary = (out[ckey] as Dictionary).duplicate()
			with_gen["gen"] = entry["gen"]
			out[ckey] = with_gen
			continue
		if entry is Dictionary and stored_gen is Dictionary and not (entry as Dictionary).has("gen"):
			# An edit save replaces the edits, never the generation record beside them.
			var kept: Dictionary = (entry as Dictionary).duplicate()
			kept["gen"] = stored_gen
			out[ckey] = kept
			continue
		if entry is Dictionary and (entry as Dictionary).has("gen") and is_newer_gen(stored_gen):
			# An entry with edits AND an older generator's record: keep the edits, not the older record.
			var kept_newer: Dictionary = (entry as Dictionary).duplicate()
			kept_newer["gen"] = stored_gen
			out[ckey] = kept_newer
			continue
		out[ckey] = entry
	return out

## Phase 91 — the typed op a bare legacy tile height is carried as when a deplete is overlaid on it.
const LEGACY_OP := "legacy"

## The one parser for a legacy tile height: a finite number or a numeric string. NAN means "not a
## legacy height at all" (a non-numeric string, a non-finite number, any other type).
## `VoxelSlice` migrates with it and `overlay_entry` decides whether to carry a bare value with it.
static func legacy_height_of(value: Variant) -> float:
	var h := NAN
	match typeof(value):
		TYPE_INT, TYPE_FLOAT:
			h = float(value)
		TYPE_STRING, TYPE_STRING_NAME:
			var text := str(value)
			if text.is_valid_float():
				h = text.to_float()
	return h if is_finite(h) else NAN

## True for the shapes `legacy_height_of` reads as a height.
static func _is_legacy_height(value: Variant) -> bool:
	return not is_nan(legacy_height_of(value))

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
			if not (old is Array) and _is_legacy_height(old):
				# Phase 91 — a pre-Phase-41 bare height is not an op list; carry it as a typed `legacy`
				# op, first, so `VoxelSlice` still migrates it against the tile's natural run.
				old = [{ "op": LEGACY_OP, "height": legacy_height_of(old) }]
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
	if entry.get("gen", null) is Dictionary:
		result["gen"] = entry["gen"]
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
		# A commit moves the old file to `.bak` just before the new one lands: a read in that gap (from
		# another thread) sees the old file, never "missing". Only while the journal exists; after a
		# finished commit a `.bak` is stale.
		# Phase 138 — the journal is checked FIRST and `path` again after it: a commit that finishes between
		# the two checks has already put the new file back, which is then the one to read.
		var mid_commit: bool = SaveTxn.in_flight(journal_path()) or (outer_journal != "" and SaveTxn.in_flight(outer_journal))
		if FileAccess.file_exists(path):
			pass   # the commit landed while we looked: read the live file
		elif mid_commit and FileAccess.file_exists(path + SaveTxn.BAK_EXT):
			path += SaveTxn.BAK_EXT
		else:
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
				var dropped := _drop_bad_ops(raw[ckey])
				if bool(dropped["changed"]):
					chunks[ckey] = dropped["entry"]
					if warn and _first_warning("%s|%s|ops" % [path, str(ckey)]):
						Diag.warn("RegionStore: %s: dropping malformed op(s) of chunk '%s'" % [path, str(ckey)])
				if raw[ckey].has("gen"):
					var gen := normalize_gen(raw[ckey]["gen"])
					if gen.is_empty() and is_newer_gen(raw[ckey]["gen"]):
						# Phase 114 — a record written by a newer generator is not ours to read, nor to
						# destroy: it rides through a rewrite verbatim, and `ChunkRecords` ignores it.
						chunks[ckey] = (raw[ckey] as Dictionary).duplicate()
					elif gen.is_empty():
						# Phase 107 — a malformed record is dropped; the chunk's edits stay.
						var stripped: Dictionary = (raw[ckey] as Dictionary).duplicate()
						stripped.erase("gen")
						if warn and _first_warning("%s|%s|gen" % [path, str(ckey)]):
							Diag.warn("RegionStore: %s: dropping malformed gen record of chunk '%s'" % [path, str(ckey)])
						if stripped.is_empty():
							chunks.erase(ckey)
						else:
							chunks[ckey] = stripped
					else:
						chunks[ckey] = (raw[ckey] as Dictionary).duplicate()
						chunks[ckey]["gen"] = gen
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
## an op LIST must hold only ops (Dictionaries) — the Phase 91 `legacy` op is one. Pure.
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

## Phase 121 — the kinds of op a tile's list may hold (see `VoxelSlice`), and the check of one op's
## fields: a known kind, finite `bottom`/`top` (add: also a String `material`), a `deplete` with a
## String `vein` and a whole `taken` >= 0, a `legacy` with a finite `height`. Pure.
static func op_valid(op: Variant) -> bool:
	if not (op is Dictionary):
		return false
	var d: Dictionary = op
	match d.get("op", null):
		"add", "remove":
			if not (_is_finite_number(d.get("bottom", null)) and _is_finite_number(d.get("top", null))):
				return false
			return d["op"] == "remove" or d.get("material", "") is String
		"deplete":
			return d.get("vein", null) is String and _is_whole_number(d.get("taken", null)) and int(d["taken"]) >= 0
		LEGACY_OP:
			return _is_finite_number(d.get("height", null))
	return false

static func _is_finite_number(x: Variant) -> bool:
	return (typeof(x) == TYPE_FLOAT or typeof(x) == TYPE_INT) and is_finite(float(x))

## `{ "entry": entry without its malformed ops (a tile left with none is dropped), "changed": whether any
## op went }`; `entry` is the same Dictionary when every op is fine. A bare legacy tile value (not a list)
## is not an op list and is left to `VoxelSlice`.
static func _drop_bad_ops(entry: Dictionary) -> Dictionary:
	var edits: Variant = entry.get("edits", null)
	if not (edits is Dictionary):
		return { "entry": entry, "changed": false }
	var cleaned_edits := {}
	var changed := false
	for tile in edits:
		var ops: Variant = edits[tile]
		if not (ops is Array):
			cleaned_edits[tile] = ops
			continue
		var good: Array = []
		for op in ops:
			if op_valid(op):
				good.append(op)
		if good.size() != (ops as Array).size():
			changed = true
		if not good.is_empty() or (ops as Array).is_empty():
			cleaned_edits[tile] = good
	if not changed:
		return { "entry": entry, "changed": false }
	var out := entry.duplicate()
	out["edits"] = cleaned_edits
	return { "entry": out, "changed": true }

## True for a record whose `v` is a whole number above this build's `WORLDGEN_VERSION`. Pure.
static func is_newer_gen(rec: Variant) -> bool:
	return rec is Dictionary and _is_whole_number((rec as Dictionary).get("v", null)) \
			and int((rec as Dictionary)["v"]) > TerrainSliceScript.WORLDGEN_VERSION

## Phase 107 — a `gen` record cleaned for storage, or `{}` when it is malformed: `v` an integer in
## 1..WORLDGEN_VERSION (a newer one was written by a newer game and is not trusted), `f` a
## non-negative integer, `b` one of `BIOME_KEYS`, `h` four finite heights inside the world's height
## range (rounded to `GEN_HEIGHT_STEP`); optional `t` (tree budget, 0..GEN_TREE_MAX) and `x` (distinct
## cleared tree spawn indices, each below GEN_TREE_MAX; stored sorted) are kept when valid and dropped alone (the ground record stays) when malformed. Pure.
static func normalize_gen(rec: Variant) -> Dictionary:
	if not (rec is Dictionary):
		return {}
	var d: Dictionary = rec
	var v: Variant = d.get("v", null)
	var f: Variant = d.get("f", null)
	var b: Variant = d.get("b", null)
	var h: Variant = d.get("h", null)
	if not _is_whole_number(v) or not _is_whole_number(f):
		return {}
	if int(v) < 1 or int(v) > TerrainSliceScript.WORLDGEN_VERSION or int(f) < 0:
		return {}
	if not (b is String) or not TerrainSliceScript.BIOME_KEYS.has(b):
		return {}
	if not (h is Array) or (h as Array).size() != 4:
		return {}
	var lo := WorldShape.min_height()
	var hi := WorldShape.max_height()
	var heights: Array = []
	for x in h:
		if not (typeof(x) == TYPE_FLOAT or typeof(x) == TYPE_INT):
			return {}
		var fx := float(x)
		if not is_finite(fx) or fx < lo or fx > hi:
			return {}
		heights.append(snappedf(fx, GEN_HEIGHT_STEP))
	var out := { "v": int(v), "f": int(f), "b": b, "h": heights }
	# Phase 110 — the tree budget the chunk was generated with and the spawn indices cleared for good.
	if d.has("t"):
		var t: Variant = d["t"]
		if _is_whole_number(t) and int(t) >= 0 and int(t) <= GEN_TREE_MAX:
			out["t"] = int(t)   # a malformed optional field is dropped alone (Phase 116)
		else:
			_note_malformed_gen("t")
	if d.has("x"):
		var xs: Variant = d["x"]
		if xs is Array:
			# Phase 126 — only a bad entry goes (logged once); the good indices keep their trees cleared.
			var seen := {}
			for i in (xs as Array).slice(0, GEN_TREE_MAX):
				if _is_whole_number(i) and int(i) >= 0 and int(i) < GEN_TREE_MAX:
					seen[int(i)] = true
				else:
					_note_malformed_gen("x")
			if (xs as Array).size() > GEN_TREE_MAX:
				_note_malformed_gen("x")
			if not seen.is_empty():
				var cleared: Array = seen.keys()
				cleared.sort()
				out["x"] = cleared
		else:
			_note_malformed_gen("x")
	return out

## Phase 126 — malformed optional `t` / `x` entries seen so far (a counter the suite reads), and whether
## the one warning has been logged.
static var malformed_gen_entries: int = 0
static var _malformed_gen_logged := false

static func _note_malformed_gen(field: String) -> void:
	malformed_gen_entries += 1
	if not _malformed_gen_logged:
		_malformed_gen_logged = true
		push_warning("RegionStore.normalize_gen: dropped a malformed '%s' entry (further ones are counted, not logged)" % field)

static func _is_whole_number(x: Variant) -> bool:
	if typeof(x) == TYPE_INT:
		return true
	return typeof(x) == TYPE_FLOAT and is_finite(x) and floorf(x) == x and absf(x) < 9.0e15

## True when `entry` is a Dictionary whose `edits` and `materials`, where present, are Dictionaries. Pure.
static func is_valid_chunk_entry(entry: Variant) -> bool:
	return entry is Dictionary and _chunk_entry_valid(entry)

## Write one region's chunk entries (replacing the file). An EMPTY chunk set removes the
## file instead, so a region whose last edit was put back leaves nothing on disk.
func save_region(region: Vector2i, chunks: Dictionary) -> Error:
	var staged := stage_region(region, chunks)
	if staged["err"] != OK:
		return staged["err"]
	if not atomic_writes:
		return OK   # written in place by `stage_region`
	var ops: Array = staged["ops"]
	return SaveTxn.commit(ops, journal_path(), fault, [outer_journal]) as Error

## Phase 121 — write one region's new content to `<path>.tmp` (no change to the live file) and return
## { "err": Error, "ops": [commit op] }. An empty set stages the file's removal. With `atomic_writes`
## off the file is written in place and `ops` is empty.
func stage_region(region: Vector2i, chunks: Dictionary) -> Dictionary:
	var path := path_of(region)
	if chunks.is_empty():
		if not FileAccess.file_exists(path):
			return { "err": OK, "ops": [] }
		if not atomic_writes:
			return { "err": DirAccess.remove_absolute(path), "ops": [] }
		return { "err": OK, "ops": [{ "path": path, "tmp": "", "kind": "region" }] }
	DirAccess.make_dir_recursive_absolute(dir)
	var target := path + SaveTxn.TMP_EXT if atomic_writes else path
	if atomic_writes and fault.is_valid() and bool(fault.call("region_tmp")):
		return { "err": ERR_CANT_CREATE, "ops": [] }
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		var err := FileAccess.get_open_error()
		Diag.error("RegionStore: cannot open %s for write — %s" % [target, error_string(err)])
		return { "err": err, "ops": [] }
	var wrote := file.store_string(JSON.stringify({ "version": REGION_FORMAT_VERSION, "chunks": chunks }))
	file.close()
	if not wrote:
		# A short write (disk full) must not reach the live file: drop the temp and fail the region.
		Diag.error("RegionStore: cannot write %s" % target)
		if atomic_writes:
			DirAccess.remove_absolute(target)
		return { "err": ERR_FILE_CANT_WRITE, "ops": [] }
	if not atomic_writes:
		return { "err": OK, "ops": [] }
	return { "err": OK, "ops": [{ "path": path, "tmp": target, "kind": "region" }] }

## Fold `chunks` (a manifest, possibly incremental) into the regions they belong to and make the result
## live in one transaction (see `SaveTxn`). Returns the first Error, or OK. This is the whole write
## path of a standalone store; the world save uses `stage_chunks` and commits with `world.json`.
func write_chunks(chunks: Dictionary, deletions := true) -> Error:
	var staged := stage_chunks(chunks, deletions)
	var err: Error = staged["err"]
	var ops: Array = staged["ops"]
	if atomic_writes and not ops.is_empty():
		var commit_err := SaveTxn.commit(ops, journal_path(), fault, [outer_journal]) as Error
		if commit_err != OK:
			# Rolled back: nothing of this write is live, so every chunk of it stays dirty.
			last_failed_chunk_keys = chunks.keys()
			return commit_err if err == OK else err
	return err

## Fold `chunks` into the regions they belong to and stage each region's new file (`.tmp`), without
## making anything live. A region that cannot be read or staged is skipped (and its chunk keys land in
## `last_failed_chunk_keys`); the others are staged anyway (Phase 61). Returns { "err": first Error,
## "ops": [commit op] }. With `atomic_writes` off the regions are written in place.
func stage_chunks(chunks: Dictionary, deletions := true, ends_streaks := false) -> Dictionary:
	var grouped := group_manifest(chunks)
	var first_error: Error = OK
	var ops: Array = []
	last_failed_chunk_keys = []
	last_failed_region_keys = []
	# Phase 138 — "in a row": a save that does not carry the region (its chunks are no longer dirty) ends
	# its failure streak, so only consecutive failing saves count toward MAX_REGION_FAILURES. Only the world
	# save passes `ends_streaks`: the generation-record flushes share this store with unrelated batches.
	if ends_streaks:
		for rkey in region_failures.keys():
			if not grouped.has(rkey):
				region_failures.erase(rkey)
	for rkey in grouped:
		var region := region_from_key(str(rkey))
		var read := read_region(region, false)
		if not bool(read["ok"]):
			# Leave the unreadable file alone rather than replace it — and keep saving the rest.
			if first_error == OK:
				first_error = ERR_FILE_CORRUPT
			last_failed_chunk_keys.append_array(grouped[rkey].keys())
			region_failures[rkey] = int(region_failures.get(rkey, 0)) + 1
			last_failed_region_keys.append(rkey)
			continue
		var folded := fold_chunks(read["chunks"], grouped[rkey], deletions)
		# Phase 75 — a malformed entry survives the rewrite unchanged unless this save carries a
		# valid entry (or the deletion marker) for its key.
		var kept: Dictionary = read.get("raw_invalid", {})
		for ckey in kept:
			if not grouped[rkey].has(ckey):
				folded[ckey] = kept[ckey]
		var staged := stage_region(region, folded)
		if staged["err"] != OK:
			last_failed_chunk_keys.append_array(grouped[rkey].keys())
			region_failures[rkey] = int(region_failures.get(rkey, 0)) + 1
			last_failed_region_keys.append(rkey)
			if first_error == OK:
				first_error = staged["err"]
			continue
		region_failures.erase(rkey)
		ops.append_array(staged["ops"])
	return { "err": first_error, "ops": ops }

## True when a region that failed in the last `stage_chunks` has failed `MAX_REGION_FAILURES` saves in a row.
func has_exhausted_region() -> bool:
	for rkey in last_failed_region_keys:
		if int(region_failures.get(rkey, 0)) >= MAX_REGION_FAILURES:
			return true
	return false

## Phase 107 — the stored generation record of `chunk`, or `{}` when it has none.
func get_gen(chunk: Vector2i) -> Dictionary:
	var entry: Variant = load_region(region_of_chunk(chunk)).get("%d,%d" % [chunk.x, chunk.y], null)
	if entry is Dictionary and (entry as Dictionary).get("gen", null) is Dictionary:
		return entry["gen"]
	return {}

## Record `rec` as `chunk`'s generation record, keeping its edits. A malformed record is refused
## (ERR_INVALID_DATA) and nothing is written.
func set_gen(chunk: Vector2i, rec: Dictionary) -> Error:
	var gen := normalize_gen(rec)
	if gen.is_empty():
		return ERR_INVALID_DATA
	return write_chunks({ "%d,%d" % [chunk.x, chunk.y]: { "gen": gen } })

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
