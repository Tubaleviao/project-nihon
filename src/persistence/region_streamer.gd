extends RefCounted
## Region streamer — keeps resident exactly the regions the streamed windows touch (Phase 52).
##
## `ChunkManager` hands it the set of chunks its windows want; the streamer reads the
## regions those chunks (plus a one-chunk margin, for the neighbour guess) fall in and
## adds their edits to the voxel log, and releases the edits of regions no window needs
## any more. A server with a thousand edited regions on disk therefore holds only the
## ones around its players.
##
## Region reads are synchronous file reads on the calling (main) thread: a region file is
## the edits of one 32×32-chunk square, and a window crosses into a new region rarely.
const RegionStore := preload("res://src/persistence/region_store.gd")
const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")

var _store: RegionStore
var _voxel: Object
## "rx,rz" -> true for every region read and still wanted.
var _resident: Dictionary = {}
## Released regions whose DIRTY chunks could not be dropped yet (their edits exist only in
## memory until a save carries them). Retried on every sync until a save has cleaned them.
var _stranded: Dictionary = {}

## Failed reads back off: "rx,rz" -> { "until": msec before which the read is not retried,
## "delay": the current backoff }. A region that cannot be read (a corrupt or unreadable file)
## would otherwise log an error and hit the disk on every sync. A successful read forgets it.
var _backoff: Dictionary = {}
const BACKOFF_START_MSEC := 1000
const BACKOFF_MAX_MSEC := 60000
## The clock the backoff reads; a test swaps it for a deterministic one.
var _now: Callable = Time.get_ticks_msec

func _init(store: RegionStore, voxel: Object) -> void:
	_store = store
	_voxel = voxel

## The "rx,rz" keys of every region touched by `chunks` (Vector2i) or any chunk adjacent to
## one. Pure.
static func regions_for_chunks(chunks: Array) -> Dictionary:
	var out: Dictionary = {}
	for c in chunks:
		var chunk: Vector2i = c
		out[RegionStore.region_key(RegionStore.region_of_chunk(chunk))] = true
		# The margin matters only on a region's edge: a chunk there is rebuilt against its
		# neighbour's real edits, which live in the next region.
		# Neighbours are wrapped in X like every chunk key, so a seam chunk's margin is the
		# region on the far side of the seam.
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var n := TerrainSlice.wrap_chunk(chunk + Vector2i(dx, dz))
				out[RegionStore.region_key(RegionStore.region_of_chunk(n))] = true
	return out

## Make exactly `wanted` ("rx,rz" keys) resident: read the missing ones, release the rest.
## Returns { "loaded": n, "released": n } for the log line and the tests.
func sync(wanted: Dictionary) -> Dictionary:
	var loaded := 0
	var released := 0
	var failed := 0
	for rkey in wanted:
		if _resident.has(rkey):
			continue
		var now: int = _now.call()
		if _backoff.has(rkey) and now < int(_backoff[rkey]["until"]):
			failed += 1   # still backing off: no read, no log line
			continue
		var read := _store.read_region(RegionStore.region_from_key(str(rkey)))
		if not bool(read["ok"]):
			# Not resident: a later sync (the next window move) retries the read once the backoff
			# has elapsed, instead of treating the region as loaded.
			var delay := mini(int(_backoff.get(rkey, { "delay": BACKOFF_START_MSEC / 2 })["delay"]) * 2, BACKOFF_MAX_MSEC)
			_backoff[rkey] = { "until": now + delay, "delay": delay }
			failed += 1
			continue
		_backoff.erase(rkey)
		_voxel.apply_region_chunks(read["chunks"])
		_resident[rkey] = true
		loaded += 1
	for rkey in _resident.keys():
		if not wanted.has(rkey):
			_stranded[rkey] = true
			_resident.erase(rkey)
	# Release every unwanted region's CLEAN chunks. The chunk list is read off the voxel
	# log (not remembered from the file): an edit made after the region was read, in a
	# region that had no file yet, is just as resident.
	if not _stranded.is_empty():
		var by_region: Dictionary = {}
		var edited_keys: Array = _voxel.edited_chunk_keys()   # once per sync
		for ckey in edited_keys:
			var rk := RegionStore.region_key(RegionStore.region_of_chunk_key(str(ckey)))
			if _stranded.has(rk):
				if not by_region.has(rk):
					by_region[rk] = []
				by_region[rk].append(ckey)
		var evicted_from: Array = []
		for rkey in _stranded.keys():
			if wanted.has(rkey):
				_stranded.erase(rkey)   # wanted again: re-read above, and memory won
				continue
			released += _voxel.evict_clean_chunks(by_region.get(rkey, []))
			evicted_from.append(rkey)
		# Dirty chunks stay (and their region stays stranded) until a save cleans them.
		var edited := {}
		for ckey in _voxel.edited_chunk_keys():
			edited[ckey] = true
		for rkey in evicted_from:
			var left := false
			for ckey in by_region.get(rkey, []):
				if edited.has(ckey):
					left = true
					break
			if not left:
				_stranded.erase(rkey)
	return { "loaded": loaded, "released": released, "failed": failed }

## Retry the stranded regions without a window move: a save may have cleaned their dirty
## chunks since. Cheap when nothing is stranded. Returns how many chunks were released.
func release_stranded() -> int:
	if _stranded.is_empty():
		return 0
	return int(sync(_resident.duplicate())["released"])

## True while a failed region read is being backed off.
func is_backing_off(region: Vector2i) -> bool:
	var rkey := RegionStore.region_key(region)
	return _backoff.has(rkey) and int(_now.call()) < int(_backoff[rkey]["until"])

func has_stranded() -> bool:
	return not _stranded.is_empty()

func resident_regions() -> Array:
	return _resident.keys()

func is_resident(region: Vector2i) -> bool:
	return _resident.has(RegionStore.region_key(region))
