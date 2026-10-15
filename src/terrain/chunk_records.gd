extends RefCounted

const SeamWrap := preload("res://src/terrain/seam_wrap.gd")
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
static var _content_revision := 0

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

## Bumps when a record's ground (`b`, `h`) changes: what a per-thread corner cache and the map read.
static func revision() -> int:
	return _revision

## Bumps on every change, including a tree-only one (`t`, `x`): what the tree resync reads.
static func content_revision() -> int:
	return _content_revision

## True when `a` and `b` agree on the ground (`v`, `b`, `h`); the tree fields may differ.
static func _same_ground(a: Dictionary, b: Dictionary) -> bool:
	return a.get("b", null) == b.get("b", null) and a.get("h", null) == b.get("h", null) and a.get("v", null) == b.get("v", null)

## The recorded chunks within Chebyshev `radius` of `chunk` (unwrapped chunk -> record) in one locked
## pass; `{}` without touching the lock more than once when nothing is recorded.
static func records_around(chunk: Vector2i, radius: int, wrap: Callable) -> Dictionary:
	var out: Dictionary = {}
	_mutex.lock()
	if not _table.is_empty():
		for dz in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var c := chunk + Vector2i(dx, dz)
				var rec: Dictionary = _table.get(key_of(wrap.call(c)), {})
				if not rec.is_empty():
					out[c] = rec
	_mutex.unlock()
	return out

## Phase 120 — an immutable snapshot of the records within Chebyshev `radius` of `center`, measured the
## short way round a world of `circumference` chunks: canonical chunk -> `{ b, h }` (copies, so a later
## table change never reaches a reader). One locked pass, over whichever is smaller: the window's area
## or the table, so the cost never grows with a long-lived world.
static func snapshot_near(center: Vector2i, radius: int, circumference: int) -> Dictionary:
	var out: Dictionary = {}
	_mutex.lock()
	var side := 2 * radius + 1
	if side * side <= _table.size():
		for dz in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var c := center + Vector2i(dx, dz)
				if circumference > 0:
					c.x = SeamWrap.wrap_i(c.x, circumference)   # canonical, as wrap_chunk
				var rec: Dictionary = _table.get(key_of(c), {})
				if not rec.is_empty():
					out[c] = { "b": str(rec["b"]), "h": (rec["h"] as Array).duplicate() }
	else:
		for k in _table:
			var parts: PackedStringArray = str(k).split(",")
			var cx := int(parts[0])
			var cz := int(parts[1])
			var dx := absi(cx - center.x)
			if circumference > 0:
				dx = mini(dx % circumference, circumference - dx % circumference)
			if maxi(dx, absi(cz - center.y)) <= radius:
				var rec: Dictionary = _table[k]
				out[Vector2i(cx, cz)] = { "b": str(rec["b"]), "h": (rec["h"] as Array).duplicate() }
	_mutex.unlock()
	return out

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
	var old: Dictionary = _table.get(k, {})
	var changed: bool = old != rec
	if changed:
		_table[k] = rec
		_content_revision += 1
		if not _same_ground(old, rec):
			_revision += 1
	_mutex.unlock()
	return changed

static func erase_record(chunk: Vector2i) -> void:
	_mutex.lock()
	if _table.erase(key_of(chunk)):
		_revision += 1
		_content_revision += 1
	_mutex.unlock()

static func clear() -> void:
	_mutex.lock()
	if not _table.is_empty():
		_revision += 1
		_content_revision += 1
	_table.clear()
	_mutex.unlock()

## Drop every record farther than Chebyshev `radius` from `center`, measured the short way round a
## world of `circumference` chunks. Returns how many went.
static func erase_outside(center: Vector2i, radius: int, circumference: int) -> int:
	var gone := 0
	_mutex.lock()
	for k in _table.keys():
		var parts: PackedStringArray = str(k).split(",")
		var dx := absi(int(parts[0]) - center.x)
		if circumference > 0:
			dx = mini(dx % circumference, circumference - dx % circumference)
		if maxi(dx, absi(int(parts[1]) - center.y)) > radius:
			_table.erase(k)
			gone += 1
	if gone > 0:
		_revision += 1
		_content_revision += 1
	_mutex.unlock()
	return gone

## Adopt every `gen` of a region's chunk entries ("cx,cz" -> entry). Returns how many were adopted;
## `changed`, when given, collects the "cx,cz" keys whose table entry was replaced or added.
static func adopt_region(chunks: Dictionary, changed: Array = []) -> int:
	var n := 0
	_mutex.lock()
	for ckey in chunks:
		var entry: Variant = chunks[ckey]
		if entry is Dictionary and (entry as Dictionary).get("gen", null) is Dictionary:
			if _table.get(str(ckey), {}) != entry["gen"]:
				var old: Dictionary = _table.get(str(ckey), {})
				_table[str(ckey)] = entry["gen"]
				_content_revision += 1
				if not _same_ground(old, entry["gen"]):
					_revision += 1
				changed.append(str(ckey))
			n += 1
	_mutex.unlock()
	return n
