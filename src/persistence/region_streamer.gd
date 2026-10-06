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

var _store: RegionStore
var _voxel: Object
## "rx,rz" -> true for every region read and still wanted.
var _resident: Dictionary = {}
## Released regions whose DIRTY chunks could not be dropped yet (their edits exist only in
## memory until a save carries them). Retried on every sync until a save has cleaned them.
var _stranded: Dictionary = {}

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
		var lo := RegionStore.region_of_chunk(chunk - Vector2i.ONE)
		var hi := RegionStore.region_of_chunk(chunk + Vector2i.ONE)
		for rx in range(lo.x, hi.x + 1):
			for rz in range(lo.y, hi.y + 1):
				out[RegionStore.region_key(Vector2i(rx, rz))] = true
	return out

## Make exactly `wanted` ("rx,rz" keys) resident: read the missing ones, release the rest.
## Returns { "loaded": n, "released": n } for the log line and the tests.
func sync(wanted: Dictionary) -> Dictionary:
	var loaded := 0
	var released := 0
	for rkey in wanted:
		if _resident.has(rkey):
			continue
		var chunks := _store.load_region(RegionStore.region_from_key(str(rkey)))
		_voxel.apply_region_chunks(chunks)
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
		for ckey in _voxel.edited_chunk_keys():
			var rk := RegionStore.region_key(RegionStore.region_of_chunk_key(str(ckey)))
			if _stranded.has(rk):
				if not by_region.has(rk):
					by_region[rk] = []
				by_region[rk].append(ckey)
		for rkey in _stranded.keys():
			if wanted.has(rkey):
				_stranded.erase(rkey)   # wanted again: re-read above, and memory won
				continue
			var keys: Array = by_region.get(rkey, [])
			released += _voxel.evict_clean_chunks(keys)
			# Dirty chunks stay (and the region stays stranded) until a save cleans them.
			if still_resident(keys, _voxel) == 0:
				_stranded.erase(rkey)
	return { "loaded": loaded, "released": released }

## How many of `keys` are STILL resident edits (i.e. were dirty and so survived eviction).
static func still_resident(keys: Array, voxel: Object) -> int:
	var edited: Array = voxel.edited_chunk_keys()
	var n := 0
	for k in keys:
		if edited.has(k):
			n += 1
	return n

func resident_regions() -> Array:
	return _resident.keys()

func is_resident(region: Vector2i) -> bool:
	return _resident.has(RegionStore.region_key(region))
