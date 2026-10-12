extends RefCounted
## Tile pyramid for the Map window. A tile at (face, level, i, j) is 2^level finest tiles on a side
## of one cube face (`MapMath`) and holds the biome of its centre chunk — a pure function of (seed,
## WORLDGEN_VERSION, tile), so the cache key carries all of them. Requests are answered coarse level
## first; the cache is bounded and drops its oldest tile first. The window takes batches with `take`
## and computes them on a worker thread; the suite drives the same path synchronously with `pump`.

const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")
const MapMath := preload("res://src/ui/map_math.gd")

const CACHE_MAX := 20000
## The stale list never outgrows this: past it the oldest entries go (a refresh that never finishes cannot grow it).
const STALE_MAX := 20000

var seed_v: int = 0
var version: int = TerrainSlice.WORLDGEN_VERSION
var _cache: Dictionary = {}                 # key -> biome (insertion order = age)
var _pending: Dictionary = {}               # level -> { key: Vector4i(face, level, i, j) }
var _inflight: Dictionary = {}              # key -> true, taken but not yet stored
var _stale: Dictionary = {}                 # tiles from before the last `invalidate`, shown until redone (bounded by STALE_MAX, oldest first)
## Bumps whenever cached results stop being valid; a batch computed under an older one is dropped.
var generation: int = 0

func key_of(f: int, level: int, i: int, j: int) -> String:
	return MapMath.tile_key(seed_v, version, f, level, i, j)

func size() -> int:
	return _cache.size()

func has_tile(f: int, level: int, i: int, j: int) -> bool:
	return _cache.has(key_of(f, level, i, j))

## The cached biome of a tile, "" when it is not computed yet.
func get_tile(f: int, level: int, i: int, j: int) -> String:
	return str(_cache.get(key_of(f, level, i, j), ""))

## The finest computed tile covering this one: the tile itself, else its nearest coarser ancestor.
func best_biome(f: int, level: int, i: int, j: int) -> String:
	var l := level
	var x := i
	var z := j
	var top := MapMath.max_level()
	while l <= top:
		var k := key_of(f, l, x, z)
		if _cache.has(k):
			return str(_cache[k])
		if not _stale.is_empty() and _stale.has(k):
			return str(_stale[k])
		l += 1
		x >>= 1
		z >>= 1
	return ""

## Queue a tile unless it is cached, queued or being computed.
func request(f: int, level: int, i: int, j: int) -> void:
	var k := key_of(f, level, i, j)
	if _cache.has(k) or _inflight.has(k):
		return
	if not _pending.has(level):
		_pending[level] = {}
	_pending[level][k] = Vector4i(f, level, i, j)

func pending_count() -> int:
	var n := 0
	for l in _pending:
		n += _pending[l].size()
	return n

func clear_pending() -> void:
	_pending.clear()

## Drop queued tiles outside `view` (Vector2i(face, level) -> Rect2i of tile coordinates); queued
## tiles inside it stay.
func retain_pending(view: Dictionary) -> void:
	for l in _pending.keys():
		var q: Dictionary = _pending[l]
		for k in q.keys():
			var t: Vector4i = q[k]
			var fl := Vector2i(t.x, t.y)
			if not view.has(fl) or not (view[fl] as Rect2i).has_point(Vector2i(t.z, t.w)):
				q.erase(k)
		if q.is_empty():
			_pending.erase(l)

## Up to `n` queued tiles, the coarsest level first.
func take(n: int) -> Array:
	var out: Array = []
	var levels: Array = _pending.keys()
	levels.sort()
	levels.reverse()
	for l in levels:
		var q: Dictionary = _pending[l]
		for k in q.keys():
			if out.size() >= n:
				return out
			out.append(q[k])
			_inflight[k] = true
			q.erase(k)
		if q.is_empty():
			_pending.erase(l)
	return out

## The biome of a tile. Pure and static: safe on a worker thread.
static func sample(seed_in: int, f: int, level: int, i: int, j: int) -> String:
	return TerrainSlice.biome_for_chunk(MapMath.tile_center_chunk(f, level, i, j), seed_in)

## Compute a taken batch -> [[Vector4i, biome]]. Static, for a worker.
static func compute(seed_in: int, batch: Array) -> Array:
	var out: Array = []
	for t in batch:
		out.append([t, sample(seed_in, t.x, t.y, t.z, t.w)])
	return out

## Store a computed batch (main thread), oldest tiles dropped past CACHE_MAX.
func store(results: Array) -> void:
	for r in results:
		var t: Vector4i = r[0]
		var k := key_of(t.x, t.y, t.z, t.w)
		_inflight.erase(k)
		_cache.erase(k)   # re-insert as the newest
		_cache[k] = r[1]
		_stale.erase(k)
	while _cache.size() > CACHE_MAX:
		for oldest in _cache:
			_cache.erase(oldest)
			break

## Synchronous: take and compute `n` tiles.
func pump(n: int) -> int:
	var batch := take(n)
	store(compute(seed_v, batch))
	return batch.size()

## Adopt another world: nothing cached for the old one is reused.
func reset(new_seed: int) -> void:
	seed_v = new_seed
	generation += 1
	_cache.clear()
	_stale.clear()
	_pending.clear()
	_inflight.clear()

## Same world, but what was sampled may have changed (a generation record arrived): recompute every
## tile, drawing the old answers meanwhile so the picture does not blank out.
func invalidate() -> void:
	generation += 1
	_stale.merge(_cache, true)   # keep what an earlier, unfinished refresh still shows
	_cap_stale()
	_cache = {}
	_pending.clear()
	_inflight.clear()

## Drop the oldest stale tiles until at most STALE_MAX remain.
func _cap_stale() -> void:
	var extra: int = _stale.size() - STALE_MAX
	if extra > 0:
		for k in _stale.keys().slice(0, extra):
			_stale.erase(k)

func stale_count() -> int:
	return _stale.size()
