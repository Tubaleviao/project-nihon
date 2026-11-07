extends RefCounted
## Phase 217 — static lakes and rivers on unrecorded land (no flow).
##
## A pure, seed-deterministic field read from any thread. Every decision uses the smooth large-scale
## shape (`WorldShape.height`), never the detail noise or a heightmap, so the field is the same for every
## chunk, whatever has loaded.
##
##   lake   one candidate per 512 m cell: a disc of radius 40–100 m whose surface is the lowest of the
##          shape at its centre and eight rim points, with a bowl carved at least `lakeMinDepth` below it.
##   river  one candidate per 1,024 m source cell where the shape is at least `riverSourceHeight`: it
##          follows the shape's steepest descent in 64 m steps, its surface the running minimum of the
##          shape (so it never climbs), widening with catchment, ending at the sea, at a blocked biome,
##          or in a pond where the descent stops.
##
## A chunk takes part only when it has no generation record or its record is from this hydrology
## (`HYDROLOGY_VERSION` or later): chunks recorded earlier never gain water or a bed.
const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")
const WorldShape := preload("res://src/terrain/world_shape.gd")
const ChunkRecords := preload("res://src/terrain/chunk_records.gd")

const HYDROLOGY_VERSION := 12   ## the first `TerrainSlice.WORLDGEN_VERSION` with water

const LAKE_CELL_M := 512.0
const LAKE_RADIUS_MIN := 40.0
const LAKE_RADIUS_MAX := 100.0
const LAKE_MIN_ALTITUDE := 3.0      ## the lake surface lies at least this far above the sea
const RIVER_CELL_M := 1024.0
const RIVER_CHANCE := 0.3
const RIVER_STEP_M := 64.0
const RIVER_MAX_STEPS := 60
const RIVER_BED_DEPTH := 1.5
const POND_FACTOR := 2.0            ## a river's terminal pond radius, in river widths
const CACHE_MAX := 4096
const FEATURE_CACHE_MAX := 8192   ## the distant ring samples hundreds of chunks per rebuild

static var _mutex := Mutex.new()
static var _rivers: Dictionary = {}   # seed → { Vector2i cell → river Dictionary }
static var _features: Dictionary = {}   # seed → { Vector2i chunk → features }
static var _rivers_n := 0
static var _features_n := 0
static var _gen := 0

## Forget cached rivers (the fabric or the seed changed).
static func reset_cache() -> void:
	_mutex.lock()
	_rivers.clear()
	_features.clear()
	_rivers_n = 0
	_features_n = 0
	_gen += 1
	_mutex.unlock()

# ---------------------------------------------------------------------------
# Fabric parameters
# ---------------------------------------------------------------------------
static var _warmed := false
static var _lake_freq := 0.35
static var _lake_depth := 4.0
static var _source_h := 60.0
static var _wmin := 4.0
static var _wmax := 16.0
static var _catch := 60
static var _blocked: Array = ["Desert", "Alpine", "VoidRift", "VolcanicBadlands", "Ocean"]

## Snapshot the fabric's hydrology fields (idempotent). Main thread, before any worker exists.
static func warm() -> void:
	if _warmed:
		return
	var ws: Variant = GameData.WORLD_SYSTEMS.get("WorldSystem", null)
	if ws != null:
		_lake_freq = _num(ws, "lakeFrequency", _lake_freq)
		_lake_depth = _num(ws, "lakeMinDepth", _lake_depth)
		_source_h = _num(ws, "riverSourceHeight", _source_h)
		_wmin = _num(ws, "riverWidthMin", _wmin)
		_wmax = _num(ws, "riverWidthMax", _wmax)
		_catch = maxi(1, int(_num(ws, "riverCatchmentSteps", float(_catch))))
		var bl: Variant = ws.get("riverBlockedBiomes")
		if bl is Array:
			_blocked = bl
	_warmed = true

static func _num(res: Variant, field: String, fallback: float) -> float:
	var v: Variant = res.get(field)
	return float(v) if v != null else fallback

## The parameters in a fixed order, for `TerrainSlice.worldgen_fingerprint`.
static func fingerprint_fields() -> Array:
	warm()
	return [_lake_freq, _lake_depth, _source_h, _wmin, _wmax, float(_catch), ",".join(PackedStringArray(_blocked))]

# ---------------------------------------------------------------------------
# Eligibility
# ---------------------------------------------------------------------------

## True when chunk `c` may hold water: unrecorded, or recorded by a generator that has hydrology.
static func chunk_active(c: Vector2i) -> bool:
	if ChunkRecords.is_empty():
		return true
	var rec := ChunkRecords.get_record(TerrainSlice.wrap_chunk(c))
	return rec.is_empty() or int(rec.get("v", 0)) >= HYDROLOGY_VERSION

# ---------------------------------------------------------------------------
# Hash
# ---------------------------------------------------------------------------
static func _mix(a: int) -> int:
	a = (a ^ (a >> 30)) * -4658895280553007687
	a = (a ^ (a >> 27)) * -7723592293110705685
	return a ^ (a >> 31)

## A unit float in [0, 1) from the seed, a cell and a salt.
static func _rand(seed_v: int, cx: int, cz: int, salt: int) -> float:
	var h := _mix(seed_v + salt * -7046029254386353131)
	h = _mix(h ^ (cx * 7146057691288625177))
	h = _mix(h ^ (cz * 1983613069789375825))
	return float(h & 0xFFFFFF) / 16777216.0

static func _cells(w: float, cell_m: float) -> int:
	return maxi(1, int(round(w / cell_m)))

static func _shape(seed_v: int, x: float, z: float, w: float) -> float:
	return WorldShape.height(seed_v, x, z, w)

static func _biome_blocked(seed_v: int, x: float, z: float) -> bool:
	var b := TerrainSlice.generated_biome_for_chunk(Vector2i(floori(x / TerrainSlice.CHUNK_METERS), floori(z / TerrainSlice.CHUNK_METERS)), seed_v)
	return _blocked.has(b)

# ---------------------------------------------------------------------------
# Lakes
# ---------------------------------------------------------------------------

## The lake of cell (cx, cz) as `{ x, z, r, surface, depth }`, or {} when the cell holds none. Pure.
static func lake_of_cell(seed_v: int, cx: int, cz: int) -> Dictionary:
	warm()
	var w := float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS
	var ccx := posmod(cx, _cells(w, LAKE_CELL_M))
	if _rand(seed_v, ccx, cz, 1) >= _lake_freq:
		return {}
	var x := (float(cx) + 0.3 + 0.4 * _rand(seed_v, ccx, cz, 2)) * LAKE_CELL_M
	var z := (float(cz) + 0.3 + 0.4 * _rand(seed_v, ccx, cz, 3)) * LAKE_CELL_M
	var r := LAKE_RADIUS_MIN + (LAKE_RADIUS_MAX - LAKE_RADIUS_MIN) * _rand(seed_v, ccx, cz, 4)
	if Vector2(x - WorldShape.SPAWN_CENTER.x, z - WorldShape.SPAWN_CENTER.y).length() < WorldShape.SPAWN_PLAIN_M:
		return {}   # the spawn plain stays dry
	var surface := _shape(seed_v, x, z, w)
	for i in 8:
		var p := Vector2.from_angle(TAU * float(i) / 8.0) * r
		surface = minf(surface, _shape(seed_v, x + p.x, z + p.y, w))
	if surface < WorldShape.sea_level() + LAKE_MIN_ALTITUDE or surface > WorldShape.max_height() * 0.5:
		return {}
	if _biome_blocked(seed_v, x, z):
		return {}
	return { "x": x, "z": z, "r": r, "surface": surface, "depth": _lake_depth + 4.0 * _rand(seed_v, ccx, cz, 5) }

# ---------------------------------------------------------------------------
# Rivers
# ---------------------------------------------------------------------------

## The river whose source lies in cell (cx, cz): `{ pts: PackedVector2Array, surf: PackedFloat64Array,
## wid: PackedFloat64Array, pond: Dictionary }`, or {} when the cell has none. Cached; pure.
static func river_of_cell(seed_v: int, cx: int, cz: int) -> Dictionary:
	warm()
	var key := Vector2i(cx, cz)
	_mutex.lock()
	var by_seed: Variant = _rivers.get(seed_v)
	if by_seed != null and (by_seed as Dictionary).has(key):
		var hit: Dictionary = (by_seed as Dictionary)[key]
		_mutex.unlock()
		return hit
	var gen := _gen
	_mutex.unlock()
	var river := _trace_river(seed_v, cx, cz)
	_mutex.lock()
	if gen == _gen:
		if _rivers_n >= CACHE_MAX:
			_rivers.clear()
			_rivers_n = 0
		if not _rivers.has(seed_v):
			_rivers[seed_v] = {}
		(_rivers[seed_v] as Dictionary)[key] = river
		_rivers_n += 1
	_mutex.unlock()
	return river

static func _trace_river(seed_v: int, cx: int, cz: int) -> Dictionary:
	var w := float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS
	var ccx := posmod(cx, _cells(w, RIVER_CELL_M))
	if _rand(seed_v, ccx, cz, 11) >= RIVER_CHANCE:
		return {}
	var p := Vector2((float(cx) + _rand(seed_v, ccx, cz, 12)) * RIVER_CELL_M, (float(cz) + _rand(seed_v, ccx, cz, 13)) * RIVER_CELL_M)
	var h := _shape(seed_v, p.x, p.y, w)
	if h < _source_h or h > WorldShape.max_height() * 0.5 or (p - WorldShape.SPAWN_CENTER).length() < WorldShape.SPAWN_PLAIN_M or _biome_blocked(seed_v, p.x, p.y):
		return {}
	var sea := WorldShape.sea_level()
	var pts := PackedVector2Array([p])
	var surf := PackedFloat64Array([h - 0.5])
	var wid := PackedFloat64Array([_wmin])
	var pond := {}
	var dir := Vector2.ZERO
	for i in range(1, RIVER_MAX_STEPS + 1):
		var e := RIVER_STEP_M * 0.5
		var gx := _shape(seed_v, p.x + e, p.y, w) - _shape(seed_v, p.x - e, p.y, w)
		var gz := _shape(seed_v, p.x, p.y + e, w) - _shape(seed_v, p.x, p.y - e, w)
		var g := Vector2(gx, gz)
		if g.length() < 0.001:
			pond = _pond_at(p, surf[surf.size() - 1], wid[wid.size() - 1])
			break
		# Steepest descent with a little inertia, so the course bends instead of zig-zagging.
		var d := (-g.normalized() + dir * 0.5).normalized()
		var q := p + d * RIVER_STEP_M
		var hq := _shape(seed_v, q.x, q.y, w)
		var last := surf[surf.size() - 1]
		if hq > last + 0.5:   # the descent would climb: the river ends in a pond here
			pond = _pond_at(p, last, wid[wid.size() - 1])
			break
		if _biome_blocked(seed_v, q.x, q.y) or (q - WorldShape.SPAWN_CENTER).length() < WorldShape.SPAWN_PLAIN_M:
			break
		dir = d
		p = q
		pts.append(p)
		surf.append(minf(last, hq - 0.5))
		wid.append(lerpf(_wmin, _wmax, clampf(float(i) / float(_catch), 0.0, 1.0)))
		if hq <= sea:   # reached the sea
			break
	if pts.size() < 2:
		return {}
	var lo := pts[0]
	var hi := pts[0]
	for q in pts:
		lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
		hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	var pad := _wmax * 0.5 + (float(pond["r"]) if not pond.is_empty() else 0.0)
	return { "pts": pts, "surf": surf, "wid": wid, "pond": pond, "x0": lo.x - pad, "z0": lo.y - pad, "x1": hi.x + pad, "z1": hi.y + pad }

static func _pond_at(p: Vector2, surface: float, width: float) -> Dictionary:
	return { "x": p.x, "z": p.y, "r": width * POND_FACTOR, "surface": surface, "depth": 2.0 }

# ---------------------------------------------------------------------------
# Chunk features
# ---------------------------------------------------------------------------

## The water features that can touch chunk `chunk`: `{ "lakes": [lake, ...], "segs": [[ax, az, bx, bz, sa, sb, half_width], ...] }`
## (ponds count as lakes). Empty when the chunk may not hold water (recorded by an older generator).
## The cache holds only the seed's pure features; `chunk_active` is read on every call before it, so a
## record loaded or replaced later (ChunkRecords) takes effect at once without a reset.
static func features_for_chunk(chunk: Vector2i, seed_v: int) -> Dictionary:
	if not chunk_active(chunk):
		return { "lakes": [], "segs": [] }
	_mutex.lock()
	var by_seed: Variant = _features.get(seed_v)
	var hit: Variant = (by_seed as Dictionary).get(chunk) if by_seed != null else null
	var gen := _gen
	_mutex.unlock()
	if hit != null:
		return hit
	var built := _build_features(chunk, seed_v)
	_mutex.lock()
	if gen != _gen:   # reset while building: the result may use old parameters, so it is not stored
		_mutex.unlock()
		return built
	if _features_n >= FEATURE_CACHE_MAX:
		_features.clear()
		_features_n = 0
	if not _features.has(seed_v):
		_features[seed_v] = {}
	(_features[seed_v] as Dictionary)[chunk] = built
	_features_n += 1
	_mutex.unlock()
	return built

static func _build_features(chunk: Vector2i, seed_v: int) -> Dictionary:
	var out := { "lakes": [], "segs": [] }
	warm()
	var cm := TerrainSlice.CHUNK_METERS
	var w := float(TerrainSlice.circumference_chunks()) * cm
	var x0 := float(chunk.x) * cm
	var z0 := float(chunk.y) * cm
	var x1 := x0 + cm
	var z1 := z0 + cm
	var pad := _wmax + LAKE_RADIUS_MAX
	# Lakes: the cells whose disc can reach the chunk.
	for cz in range(floori((z0 - pad) / LAKE_CELL_M), floori((z1 + pad) / LAKE_CELL_M) + 1):
		for cx in range(floori((x0 - pad) / LAKE_CELL_M), floori((x1 + pad) / LAKE_CELL_M) + 1):
			var lk := lake_of_cell(seed_v, cx, cz)
			if not lk.is_empty() and _disc_touches(lk, x0, z0, x1, z1):
				out["lakes"].append(lk)
	# Rivers: a river of RIVER_MAX_STEPS steps reaches that far from its source cell.
	var reach := RIVER_STEP_M * float(RIVER_MAX_STEPS) + _wmax
	var rcx0 := floori((x0 - reach) / RIVER_CELL_M)
	var rcx1 := floori((x1 + reach) / RIVER_CELL_M)
	var rcz0 := floori((z0 - reach) / RIVER_CELL_M)
	var rcz1 := floori((z1 + reach) / RIVER_CELL_M)
	for cz in range(rcz0, rcz1 + 1):
		for cx in range(rcx0, rcx1 + 1):
			var rv := river_of_cell(seed_v, cx, cz)
			if rv.is_empty() or float(rv["x1"]) < x0 or float(rv["x0"]) > x1 or float(rv["z1"]) < z0 or float(rv["z0"]) > z1:
				continue
			var pts: PackedVector2Array = rv["pts"]
			var surf: PackedFloat64Array = rv["surf"]
			var wid: PackedFloat64Array = rv["wid"]
			for i in range(pts.size() - 1):
				var a := pts[i]
				var b := pts[i + 1]
				var hw := maxf(wid[i], wid[i + 1]) * 0.5
				if maxf(a.x, b.x) + hw < x0 or minf(a.x, b.x) - hw > x1 or maxf(a.y, b.y) + hw < z0 or minf(a.y, b.y) - hw > z1:
					continue
				out["segs"].append([a.x, a.y, b.x, b.y, surf[i], surf[i + 1], hw, wid[i] * 0.5])
			var pd: Dictionary = rv["pond"]
			if not pd.is_empty() and _disc_touches(pd, x0, z0, x1, z1):
				out["lakes"].append(pd)
	return out

static func _disc_touches(d: Dictionary, x0: float, z0: float, x1: float, z1: float) -> bool:
	var r := float(d["r"])
	return float(d["x"]) + r >= x0 and float(d["x"]) - r <= x1 and float(d["z"]) + r >= z0 and float(d["z"]) - r <= z1

# ---------------------------------------------------------------------------
# Per-point queries
# ---------------------------------------------------------------------------

## `{ "surface": float, "bed": float }` for the water at (x, z) given `features`, or {} when dry. The bed
## is the highest the ground may be there; the surface is the water level. Where a lake and a river
## overlap the lower surface wins nothing: the first feature found is used (all are static).
static func water_at(features: Dictionary, x: float, z: float) -> Dictionary:
	for lk in features["lakes"]:
		var dx := x - float(lk["x"])
		var dz := z - float(lk["z"])
		var r := float(lk["r"])
		var d2 := dx * dx + dz * dz
		if d2 < r * r:
			var t := d2 / (r * r)
			var s := float(lk["surface"])
			return { "surface": s, "bed": s - float(lk["depth"]) * (1.0 - t) - 0.05, "width": INF }
	for sg in features["segs"]:
		var ax: float = sg[0]
		var az: float = sg[1]
		var abx: float = sg[2] - ax
		var abz: float = sg[3] - az
		var len2 := abx * abx + abz * abz
		var t := clampf(((x - ax) * abx + (z - az) * abz) / len2, 0.0, 1.0) if len2 > 0.0 else 0.0
		var px := ax + abx * t - x
		var pz := az + abz * t - z
		var half := lerpf(float(sg[7]), float(sg[6]), t)
		var d := sqrt(px * px + pz * pz)
		if d < half:
			var s := lerpf(float(sg[4]), float(sg[5]), t)
			var f := d / half
			return { "surface": s, "bed": s - RIVER_BED_DEPTH * (1.0 - f * f) - 0.05, "width": 2.0 * half }
	return {}

## Lower every tile of `hm` (a chunk heightmap, indexed `tz * CHUNK_SIZE + tx`; null tiles are skipped)
## whose centre lies in water to that water's bed. In place; returns `hm`.
static func carve(chunk: Vector2i, seed_v: int, hm: Array) -> Array:
	var f := features_for_chunk(chunk, seed_v)
	if f["lakes"].is_empty() and f["segs"].is_empty():
		return hm
	var ox := float(chunk.x * TerrainSlice.CHUNK_SIZE) * TerrainSlice.TILE_SIZE
	var oz := float(chunk.y * TerrainSlice.CHUNK_SIZE) * TerrainSlice.TILE_SIZE
	for tz in TerrainSlice.CHUNK_SIZE:
		for tx in TerrainSlice.CHUNK_SIZE:
			var cur: Variant = hm[tz * TerrainSlice.CHUNK_SIZE + tx]
			if cur == null:
				continue
			var wt := water_at(f, ox + float(tx) * TerrainSlice.TILE_SIZE, oz + float(tz) * TerrainSlice.TILE_SIZE)
			if not wt.is_empty():
				hm[tz * TerrainSlice.CHUNK_SIZE + tx] = minf(float(cur), float(wt["bed"]))
	return hm

## The ground height at one point after carving (what `get_height_at` returns).
static func carved_height(seed_v: int, x: float, z: float, h: float) -> float:
	var cm := TerrainSlice.CHUNK_METERS
	var f := features_for_chunk(Vector2i(floori(x / cm), floori(z / cm)), seed_v)
	var wt := water_at(f, x, z)
	return h if wt.is_empty() else minf(h, float(wt["bed"]))

## The fresh-water surface at (x, z) (metres), or NAN when there is none. Used for swimming, the
## creature path cost and the water mesh.
static func surface_at(seed_v: int, x: float, z: float) -> float:
	var cm := TerrainSlice.CHUNK_METERS
	var f := features_for_chunk(Vector2i(floori(x / cm), floori(z / cm)), seed_v)
	var wt := water_at(f, x, z)
	return NAN if wt.is_empty() else float(wt["surface"])

## How wide the fresh water at (x, z) is (metres): a river's width there, INF for a lake or pond, 0 when dry.
## A creature fords a river narrower than its path's `ford_width_m`.
static func water_width_at(seed_v: int, x: float, z: float) -> float:
	var cm := TerrainSlice.CHUNK_METERS
	var wt := water_at(features_for_chunk(Vector2i(floori(x / cm), floori(z / cm)), seed_v), x, z)
	return 0.0 if wt.is_empty() else float(wt["width"])

## The level a body floats on at (x, z): the fresh-water surface where there is one, else the sea.
static func water_level(seed_v: int, x: float, z: float) -> float:
	var fresh := surface_at(seed_v, x, z)
	return WorldShape.sea_level() if is_nan(fresh) else fresh

## `water_level` for the world a `terrain_slice` generates (the biome seed without one).
static func level_for(terrain_slice: Object, x: float, z: float) -> float:
	var seed_v: int = int(terrain_slice.get_world_seed()) if terrain_slice != null and terrain_slice.has_method("get_world_seed") else TerrainSlice.BIOME_SEED
	return water_level(seed_v, x, z)

## Per-tile water surface of a chunk: a flat array (indexed like a heightmap) of the fresh-water
## surface or NAN, for the mesh and the distant ring.
static func surfaces_for_chunk(chunk: Vector2i, seed_v: int) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(TerrainSlice.CHUNK_SIZE * TerrainSlice.CHUNK_SIZE)
	out.fill(NAN)
	var f := features_for_chunk(chunk, seed_v)
	if f["lakes"].is_empty() and f["segs"].is_empty():
		return out
	var ox := float(chunk.x * TerrainSlice.CHUNK_SIZE) * TerrainSlice.TILE_SIZE
	var oz := float(chunk.y * TerrainSlice.CHUNK_SIZE) * TerrainSlice.TILE_SIZE
	for tz in TerrainSlice.CHUNK_SIZE:
		for tx in TerrainSlice.CHUNK_SIZE:
			var wt := water_at(f, ox + float(tx) * TerrainSlice.TILE_SIZE, oz + float(tz) * TerrainSlice.TILE_SIZE)
			if not wt.is_empty():
				out[tz * TerrainSlice.CHUNK_SIZE + tx] = float(wt["surface"])
	return out
