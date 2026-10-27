extends RefCounted
## Phase 191 — an LRU cache of recently built chunk arrays.
##
## A flyer that turns back streams out and then in again the ground it built seconds ago. Each entry holds
## the worker's result for one chunk (`arrays`, plus the `heightmap` it was built from) under a signature of
## everything the build read: the level of detail, the edit revisions of the chunk and its eight neighbours
## and the chunk's own generation record. A lookup with another signature drops the entry. Bounded twice:
## by entry count and by the approximate bytes of the packed arrays held, whichever is hit first evicts the
## least recently used entry.
##
## Pure data, no nodes: `ChunkManager` owns one (`_cache`), fills it when a build attaches and takes from it
## where it would dispatch a worker.

const DEFAULT_MAX_ENTRIES := 96
const DEFAULT_MAX_BYTES := 192 * 1024 * 1024

var max_entries: int = DEFAULT_MAX_ENTRIES
var max_bytes: int = DEFAULT_MAX_BYTES

## "cx,cz" -> { sig, arrays, heightmap, bytes }. Insertion order is recency: oldest first.
var _entries: Dictionary = {}
var _bytes: int = 0
var hits: int = 0
var misses: int = 0

func size() -> int:
	return _entries.size()

func bytes() -> int:
	return _bytes

func has_entry(key: String) -> bool:
	return _entries.has(key)

## Remember a built chunk. An entry bigger than the whole byte budget is not kept.
func put(key: String, sig: Variant, arrays: Dictionary, heightmap: Array) -> void:
	invalidate(key)
	if arrays.is_empty():
		return
	var n := approx_bytes(arrays) + heightmap.size() * 8
	if n > max_bytes:
		return
	_entries[key] = { "sig": sig, "arrays": arrays, "heightmap": heightmap, "bytes": n }
	_bytes += n
	_evict()

## The entry for `key` when its signature still matches (moved to most recent), else `{}`.
func take(key: String, sig: Variant) -> Dictionary:
	var e: Dictionary = _entries.get(key, {})
	if e.is_empty():
		misses += 1
		return {}
	if e["sig"] != sig:
		invalidate(key)
		misses += 1
		return {}
	_entries.erase(key)
	_entries[key] = e
	hits += 1
	return e

func invalidate(key: String) -> void:
	var e: Dictionary = _entries.get(key, {})
	if e.is_empty():
		return
	_bytes -= int(e["bytes"])
	_entries.erase(key)

func clear() -> void:
	_entries.clear()
	_bytes = 0

func _evict() -> void:
	while not _entries.is_empty() and (_entries.size() > max_entries or _bytes > max_bytes):
		invalidate(str(_entries.keys()[0]))

## Bytes held by the packed arrays of a build result (other values count a small flat cost). Pure.
static func approx_bytes(arrays: Dictionary) -> int:
	var n := 0
	for k in arrays:
		var v: Variant = arrays[k]
		if v is Dictionary:
			n += approx_bytes(v)
		elif v is Array or v is PackedByteArray or v is PackedInt32Array or v is PackedFloat32Array \
				or v is PackedVector2Array or v is PackedVector3Array or v is PackedColorArray:
			n += _packed_bytes(v)
		else:
			n += 16
	return n

static func _packed_bytes(v: Variant) -> int:
	if v is PackedVector3Array:
		return (v as PackedVector3Array).size() * 12
	if v is PackedColorArray:
		return (v as PackedColorArray).size() * 16
	if v is PackedVector2Array:
		return (v as PackedVector2Array).size() * 8
	if v is PackedByteArray:
		return (v as PackedByteArray).size()
	if v is PackedInt32Array:
		return (v as PackedInt32Array).size() * 4
	if v is PackedFloat32Array:
		return (v as PackedFloat32Array).size() * 4
	if v is Array:
		var n := 0
		for item in (v as Array):
			n += _packed_bytes(item) if item is Array else 16
		return n
	return 16
