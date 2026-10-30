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
	# A heightmap is a flat Array of floats: a Variant slot per tile, which is what `value_bytes` would sum, but
	# that walk is 4096 GDScript calls on the main thread per attached chunk (about 3 ms on a slow runner).
	var n := approx_bytes(arrays) + heightmap.size() * VARIANT_BYTES
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

## Bytes held by a build result: a Variant slot per value, plus what each value holds (`value_bytes`). Pure.
## Phase 194 (#512) — the collision shapes count too (a `ConcavePolygonShape3D` keeps its own copy of the faces,
## and a split build carries four), and so does every slot of a plain Array (a heightmap row is Variants, not
## packed floats). A lower bound still: Jolt's own mesh of an attached shape is not counted.
static func approx_bytes(arrays: Dictionary) -> int:
	var n := 0
	for k in arrays:
		n += VARIANT_BYTES + value_bytes(arrays[k])
	return n

## A Variant's own slot (Godot 4, 64-bit).
const VARIANT_BYTES := 24

## Bytes `v` holds past its own Variant slot (0 for a scalar). Pure.
static func value_bytes(v: Variant) -> int:
	if v is Dictionary:
		return approx_bytes(v)
	if v is Array:
		var n := 0
		for item in (v as Array):
			n += VARIANT_BYTES + value_bytes(item)
		return n
	if v is ConcavePolygonShape3D:
		return (v as ConcavePolygonShape3D).get_faces().size() * 12
	if v is PackedVector3Array:
		return (v as PackedVector3Array).size() * 12
	if v is PackedColorArray:
		return (v as PackedColorArray).size() * 16
	if v is PackedVector2Array or v is PackedInt64Array or v is PackedFloat64Array:
		return v.size() * 8
	if v is PackedInt32Array or v is PackedFloat32Array:
		return v.size() * 4
	if v is PackedByteArray:
		return (v as PackedByteArray).size()
	return 0
