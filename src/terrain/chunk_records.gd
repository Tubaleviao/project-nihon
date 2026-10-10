extends RefCounted
## Phase 108 — the generation records of the chunks this process knows (see `RegionStore.normalize_gen`).
##
## A static table `"cx,cz" -> { v, f, b, h }` guarded by a mutex: the main thread writes it (a region
## read by `RegionStreamer`, a fresh record from `ChunkManager`), and chunk-build and ore workers
## read it through `TerrainSlice.biome_for_chunk`, so a recorded chunk answers the same on every
## thread. `revision()` bumps on every change so a per-thread corner cache can tell its cell went stale.
## Keys are canonical chunks (`TerrainSlice.wrap_chunk`).

static var _table: Dictionary = {}
static var _mutex := Mutex.new()
static var _revision := 0

static func key_of(chunk: Vector2i) -> String:
	return "%d,%d" % [chunk.x, chunk.y]

## True when no chunk is recorded (the common case on a fresh world and on a client).
static func is_empty() -> bool:
	_mutex.lock()
	var e := _table.is_empty()
	_mutex.unlock()
	return e

static func size() -> int:
	_mutex.lock()
	var n := _table.size()
	_mutex.unlock()
	return n

static func revision() -> int:
	return _revision

## The record of `chunk`, or `{}`. The returned Dictionary is shared: treat it as read-only.
static func get_record(chunk: Vector2i) -> Dictionary:
	var k := key_of(chunk)
	_mutex.lock()
	var rec: Dictionary = _table.get(k, {})
	_mutex.unlock()
	return rec

static func has_record(chunk: Vector2i) -> bool:
	return not get_record(chunk).is_empty()

## Store a record (already normalised, `RegionStore.normalize_gen`). Returns true when it changed the table.
static func set_record(chunk: Vector2i, rec: Dictionary) -> bool:
	if rec.is_empty():
		return false
	var k := key_of(chunk)
	_mutex.lock()
	var changed: bool = _table.get(k, {}) != rec
	if changed:
		_table[k] = rec
		_revision += 1
	_mutex.unlock()
	return changed

static func erase_record(chunk: Vector2i) -> void:
	_mutex.lock()
	if _table.erase(key_of(chunk)):
		_revision += 1
	_mutex.unlock()

static func clear() -> void:
	_mutex.lock()
	if not _table.is_empty():
		_revision += 1
	_table.clear()
	_mutex.unlock()

## Adopt every `gen` of a region's chunk entries ("cx,cz" -> entry). Returns how many were adopted.
static func adopt_region(chunks: Dictionary) -> int:
	var n := 0
	_mutex.lock()
	for ckey in chunks:
		var entry: Variant = chunks[ckey]
		if entry is Dictionary and (entry as Dictionary).get("gen", null) is Dictionary:
			if _table.get(str(ckey), {}) != entry["gen"]:
				_table[str(ckey)] = entry["gen"]
				_revision += 1
			n += 1
	_mutex.unlock()
	return n
