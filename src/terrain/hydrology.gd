extends RefCounted
## Phase 217 — static lakes and rivers on unrecorded land (no flow).
##
## A pure, seed-deterministic field read from any thread. Every decision uses the smooth large-scale
## shape (`TerrainSlice.macro_height`: `WorldShape.height`, or the planet bake's since Phase 302), never the detail noise or a heightmap, so the field is the same for every
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
const PlanetBake := preload("res://src/terrain/planet_bake.gd")
const Csg := preload("res://src/terrain/terrain_csg.gd")
const Frontier := preload("res://src/terrain/frontier.gd")

const HYDROLOGY_VERSION := 12   ## the first `TerrainSlice.WORLDGEN_VERSION` with water
## Phase 302 — the first `TerrainSlice.WORLDGEN_VERSION` whose rivers have soft banks (`soft_carve`); a chunk
## recorded earlier keeps the hard edge of `water_at`'s bed, so its ground never changes.
const SOFT_BANK_VERSION := 15
## Phase 232 review — what each generator version changed, so a chunk recorded before it keeps the water it had:
## 16 keeps lakes and rivers off the whole spawn plain (disc and segment extents, not centres and vertices), 17 gives
## lakes their shore (surface clamped under the surrounding ground, levee, pole gap) and 18 makes the river cell an
## exact divisor of the circumference. `tier_of` maps a record's version to how many of them it has (0 to 3).
const LAKE_SPAWN_VERSION := 16
const LAKE_SHORE_VERSION := 17
const RIVER_CELL_VERSION := 18
const NEW_VERSION := 1 << 30   ## the version of land with no record: it takes everything new
const BANK_SLOPE_NUM := 3   ## a soft bank rises 3 mm per 5 mm out from the channel (0.3 m per 0.5 m tile)
const BANK_SLOPE_DEN := 5
const BANK_K_MM := 1000   ## the smooth-union width where the bank meets the natural ground
## How far (m) out from its line a river segment can change the ground: past BANK_SOFT_M the cut rises
## BANK_WALL_SLOPE per metre, so by BANK_REACH_M it stands far above any ground near a river and the
## segment has no effect. Features are gathered with this pad, so every tile sees each segment that can reach it.
const BANK_SOFT_M := 32.0
const BANK_REACH_M := 40.0
const BANK_WALL_SLOPE := 20

const LAKE_CELL_M := 512.0   ## the cell on a pre-238 planet; `lake_cell()` is the one in use
const LAKE_CELL_SMALL_M := 500.0   ## Phase 238: divides the 2,000 km circumference (4,000 cells), so the wrap is exact
const LAKE_RADIUS_MIN := 40.0
const LAKE_RADIUS_MAX := 100.0
const LAKE_MIN_ALTITUDE := 3.0      ## the lake surface lies at least this far above the sea
## Phase 232 — the lake shore. Outside the disc the ground is cut down to a bank line rising LAKE_BANK_NUM / LAKE_BANK_DEN
## per metre from the water (then LAKE_WALL_SLOPE per metre past LAKE_BANK_SOFT_M, so the cut ends at LAKE_REACH_M), and
## raised into a levee: from the water level at the shore up to the freeboard at LAKE_CREST_M out, then back down at
## LAKE_LEVEE_SLOPE per metre. The ground samples that clamp the surface lie on rings out to LAKE_REACH_M.
const LAKE_BANK_NUM := 1
const LAKE_BANK_DEN := 2
const LAKE_BANK_SOFT_M := 20.0
const LAKE_WALL_SLOPE := 20
const LAKE_REACH_M := 32.0
const LAKE_CREST_M := 2.0
const LAKE_LEVEE_SLOPE := 0.25
const LAKE_SHORE_FADE_M := 4.0     ## the shore term fades to nothing over this many metres before LAKE_REACH_M
const LAKE_K_MM := 400              ## the smoothing width of the bowl's and the bank's union with the ground
const LAKE_POLE_GAP_M := 1500.0   ## a lake keeps this far from the fold at a pole
const LAKE_RING_STEPS := 24
const LAKE_RINGS_M: Array = [1.0, 8.0, 16.0, 24.0, 32.0]
const RIVER_CELL_M := 1024.0   ## see `river_cell()`
const RIVER_CELL_SMALL_M := 1000.0   ## Phase 238: 2,000 cells round the small planet

static func _small_planet() -> bool:
	return float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS < WorldShape.SMALL_PLANET_M

static func lake_cell() -> float:
	return LAKE_CELL_SMALL_M if _small_planet() else LAKE_CELL_M

static func river_cell(tier: int = 3) -> float:
	var base := RIVER_CELL_SMALL_M if _small_planet() else RIVER_CELL_M
	if tier < 3:
		return base   # a chunk recorded before worldgen 18 keeps the plain cell (local-trace rivers only)
	# Phase 232 (#573): the cell is made an exact divisor of the circumference (the count rounds w / 1024, so the
	# wrap `posmod(cx, cells)` closes on the lap and a river crossing the X seam continues on the other side).
	var w := float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS
	return w / float(_cells(w, base))
const RIVER_CHANCE := 0.3
const RIVER_STEP_M := 64.0
const RIVER_MAX_STEPS := 60
const RIVER_BED_DEPTH := 1.5
const POND_FACTOR := 2.0            ## a river's terminal pond radius, in river widths
const CACHE_MAX := 4096
const FEATURE_CACHE_MAX := 8192
## Point queries (`surface_at`: the distant ring, swimming) read the features of the BLOCK_M square around
## the point, cached apart from the chunk features: a ring rebuild samples over 8,000 distinct far chunks,
## which cleared the chunk cache every rebuild and cost one ~0.2 ms feature build per sample.
const BLOCK_M := 512.0
const BLOCK_CACHE_MAX := 16384   ## a ring rebuild reads about 3,000 blocks, a moved one about 650 new ones; ~2 KB each, so ~32 MB at most

static var _mutex := Mutex.new()
static var _rivers: Dictionary = {}   # seed → { Vector2i cell → river Dictionary }
static var _features: Dictionary = {}   # seed → { Vector2i chunk → features }
static var _rivers_n := 0
static var _features_n := 0
static var _blocks: Dictionary = {}   # seed → { Vector2i block → features }
static var _blocks_n := 0
static var _gen := 0
static var _lakes: Dictionary = {}   # "seed:cx:cz:lake tier" → lake Dictionary or {}
static var _ease_samplers: Dictionary = {}   # thread id → [seed, FastNoiseLite, corner cache] (guarded by _ease_mutex, each entry used by its own thread)
static var _ease_mutex := Mutex.new()
static var _ease_cache: Dictionary = {}   # "seed:x:z" of a lake → [records revision, [Rect2 of each older recorded chunk near it]]

## Forget cached rivers (the fabric or the seed changed).
static func reset_cache() -> void:
	_mutex.lock()
	_rivers.clear()
	_features.clear()
	_blocks.clear()
	_lakes.clear()
	_rivers_n = 0
	_features_n = 0
	_blocks_n = 0
	_gen += 1
	_mutex.unlock()
	_ease_mutex.lock()
	_ease_cache.clear()
	_ease_samplers.clear()
	_ease_mutex.unlock()

# ---------------------------------------------------------------------------
# Fabric parameters
# ---------------------------------------------------------------------------
static var _warmed := false
static var _lake_freq := 0.35
static var _lake_depth := 4.0
static var _lake_freeboard := 0.5
static var _lake_max_levee := 3.0
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
		_lake_freeboard = _num(ws, "lakeFreeboard", _lake_freeboard)
		_lake_max_levee = _num(ws, "lakeMaxLevee", _lake_max_levee)
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
	return [_lake_freq, _lake_depth, _lake_freeboard, _lake_max_levee, _source_h, _wmin, _wmax, float(_catch), ",".join(PackedStringArray(_blocked))]

# ---------------------------------------------------------------------------
# Eligibility
# ---------------------------------------------------------------------------

## True when chunk `c` may hold water: unrecorded, or recorded by a generator that has hydrology.
static func chunk_active(c: Vector2i) -> bool:
	return record_version(c) >= HYDROLOGY_VERSION

## The generator version chunk `c` was recorded at (`NEW_VERSION` when it has no record).
static func record_version(c: Vector2i) -> int:
	if ChunkRecords.is_empty():
		return NEW_VERSION
	var rec := ChunkRecords.get_record(TerrainSlice.wrap_chunk(c))
	return NEW_VERSION if rec.is_empty() else int(rec.get("v", 0))

## How many of the Phase 232 changes (spawn extents 16, shores 17, river cell 18) land at record version `v`.
static func tier_of(v: int) -> int:
	return int(v >= LAKE_SPAWN_VERSION) + int(v >= LAKE_SHORE_VERSION) + int(v >= RIVER_CELL_VERSION)

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
	return TerrainSlice.macro_height(seed_v, x, z, w)   # Phase 302: the bake's macro height when one is loaded

static func _biome_blocked(seed_v: int, x: float, z: float) -> bool:
	var b := TerrainSlice.generated_biome_for_chunk(Vector2i(floori(x / TerrainSlice.CHUNK_METERS), floori(z / TerrainSlice.CHUNK_METERS)), seed_v)
	return _blocked.has(b)

# ---------------------------------------------------------------------------
# Lakes
# ---------------------------------------------------------------------------

## The lake of cell (cx, cz) as `{ x, z, r, surface, depth, shore }`, or {} when the cell holds none. Pure; cached
## (Phase 232: its surface reads about 120 ground samples).
## `tier` (`tier_of` of the asking chunk's record) picks the legacy lake of a chunk recorded earlier: without it
## (`shore` absent) the lake is the one of worldgen 12 to 15 (tier 0) or 16 (tier 1: the spawn plain by disc).
static func lake_of_cell(seed_v: int, cx: int, cz: int, tier: int = 3) -> Dictionary:
	var lt := mini(tier, 2)
	var key := "%d:%d:%d:%d" % [seed_v, cx, cz, lt]
	_mutex.lock()
	var hit: Variant = _lakes.get(key)
	var gen := _gen
	_mutex.unlock()
	if hit != null:
		return hit
	var built := _build_lake(seed_v, cx, cz, lt)
	_mutex.lock()
	if gen == _gen:
		if _lakes.size() >= CACHE_MAX:
			_lakes.clear()
		_lakes[key] = built
	_mutex.unlock()
	return built

static func _build_lake(seed_v: int, cx: int, cz: int, lt: int) -> Dictionary:
	warm()
	var w := float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS
	var ccx := posmod(cx, _cells(w, lake_cell()))
	if _rand(seed_v, ccx, cz, 1) >= _lake_freq:
		return {}
	var x := (float(cx) + 0.3 + 0.4 * _rand(seed_v, ccx, cz, 2)) * lake_cell()
	var z := (float(cz) + 0.3 + 0.4 * _rand(seed_v, ccx, cz, 3)) * lake_cell()
	var r := LAKE_RADIUS_MIN + (LAKE_RADIUS_MAX - LAKE_RADIUS_MIN) * _rand(seed_v, ccx, cz, 4)
	if Vector2(x - WorldShape.SPAWN_CENTER.x, z - WorldShape.SPAWN_CENTER.y).length() < WorldShape.SPAWN_PLAIN_M + (r if lt >= 1 else 0.0):
		return {}   # the spawn plain stays dry: the whole disc, not only its centre (since worldgen 16)
	if lt < 2:   # worldgen 12 to 16: the surface from the centre and eight rim points, no shore
		var s_old := _shape(seed_v, x, z, w)
		for i in 8:
			var q0 := Vector2.from_angle(TAU * float(i) / 8.0) * r
			s_old = minf(s_old, _shape(seed_v, x + q0.x, z + q0.y, w))
		if s_old < WorldShape.sea_level() + LAKE_MIN_ALTITUDE or s_old > WorldShape.max_height() * 0.5 or _biome_blocked(seed_v, x, z):
			return {}
		return { "x": x, "z": z, "r": r, "surface": s_old, "depth": _lake_depth + 4.0 * _rand(seed_v, ccx, cz, 5) }
	# A lake is placed in unfolded coordinates, so one near a pole would not be the same in the frame beyond it: none within
	# the fold margin and its view (Phase 120's fold is not seen), the shore and bank included.
	if absf(z) + r + LAKE_REACH_M > float(TerrainSlice.pole_chunks()) * TerrainSlice.CHUNK_METERS - LAKE_POLE_GAP_M:
		return {}
	var surface := _shape(seed_v, x, z, w)
	for i in 8:
		var p := Vector2.from_angle(TAU * float(i) / 8.0) * r
		surface = minf(surface, _shape(seed_v, x + p.x, z + p.y, w))
	var surface_old := surface   # the surface a recorded chunk of worldgen 12 to 16 has: the frontier eases to it
	# Phase 232: the ground outside the disc, detail noise and massifs included, never lies below the surface.
	var noise := FastNoiseLite.new()
	TerrainSlice.configure_noise(noise, seed_v)
	var cache := TerrainSlice.new_corner_cache()
	var ring: Array = []   # [distance beyond the shore, ground height]
	for ring_m in LAKE_RINGS_M:
		for i in LAKE_RING_STEPS:
			var q := Vector2.from_angle(TAU * (float(i) + 0.5 * float(int(ring_m) % 2)) / float(LAKE_RING_STEPS)) * (r + float(ring_m))
			var g := TerrainSlice.height_wrapped_in(seed_v, noise, x + q.x, z + q.y, w, cache, [])
			ring.append([float(ring_m), g])
			surface = minf(surface, g)
	if surface < WorldShape.sea_level() + LAKE_MIN_ALTITUDE or surface > WorldShape.max_height() * 0.5:
		return {}
	# The levee the shore needs where the ground sits under it; a lake that would need more than the maximum is dropped.
	for rg in ring:
		if levee_height(surface, float(rg[0])) - float(rg[1]) > _lake_max_levee:
			return {}
	if _biome_blocked(seed_v, x, z):
		return {}
	return { "x": x, "z": z, "r": r, "surface": surface, "depth": _lake_depth + 4.0 * _rand(seed_v, ccx, cz, 5), "shore": true, "s0": surface_old }

## Phase 232 — `f` (features of a chunk or block) with each lake that reaches an older recorded chunk carrying `ease`:
## the rectangles of those chunks within `Frontier.BLEND_CHUNKS` of the lake's reach, each `[Rect2, dry]` (`dry`: recorded
## before hydrology, so it holds no water; otherwise it holds the lake of worldgen 12 to 16, without a shore). Pure per
## call: the caches hold the plain features, so a record changed later takes effect at once. `f` itself when nothing is
## recorded or no lake is near such a chunk.
static func _with_ease(f: Dictionary, seed_v: int) -> Dictionary:
	if f["lakes"].is_empty() or ChunkRecords.is_empty():
		return f
	var out: Array = []
	var changed := false
	for lk in f["lakes"]:
		if not lk.has("shore"):
			out.append(lk)
			continue
		var rects := _older_rects(lk, seed_v)
		if rects.is_empty():
			out.append(lk)
			continue
		var lk2: Dictionary = (lk as Dictionary).duplicate()
		lk2["ease"] = { "rects": rects, "seed": seed_v }
		out.append(lk2)
		changed = true
	if not changed:
		return f
	return { "lakes": out, "segs": f["segs"] }

static func _older_rects(lk: Dictionary, seed_v: int) -> Array:
	var key := "%d:%d:%d" % [seed_v, int(float(lk["x"])), int(float(lk["z"]))]
	var rev := ChunkRecords.revision()
	_ease_mutex.lock()
	var hit: Variant = _ease_cache.get(key)
	_ease_mutex.unlock()
	if hit != null and int(hit[0]) == rev:
		return hit[1]
	var cm := TerrainSlice.CHUNK_METERS
	var radius := int(ceil((float(lk["r"]) + LAKE_REACH_M) / cm)) + Frontier.BLEND_CHUNKS
	var centre := Vector2i(floori(float(lk["x"]) / cm), floori(float(lk["z"]) / cm))
	var rects: Array = []
	for c in ChunkRecords.records_around(centre, radius, TerrainSlice.wrap_chunk):
		var v := int(ChunkRecords.get_record(TerrainSlice.wrap_chunk(c)).get("v", 0))
		if v < LAKE_SHORE_VERSION:   # a chunk of 12 to 16 keeps its shoreless lake, an older one its dry ground
			rects.append([Rect2(float(c.x) * cm, float(c.y) * cm, cm, cm), v < HYDROLOGY_VERSION])
	_ease_mutex.lock()
	if _ease_cache.size() >= CACHE_MAX:
		_ease_cache.clear()
	_ease_cache[key] = [rev, rects]
	_ease_mutex.unlock()
	return rects

## This thread's ground sampler for the ease (a noise and a corner cache of `seed_v`, built once per thread, not per call).
## Each entry is only ever used by the thread that owns it; the map is guarded.
static func _ease_ground(seed_v: int, x: float, z: float) -> float:
	var tid := OS.get_thread_caller_id()
	_ease_mutex.lock()
	var sm: Array = _ease_samplers.get(tid, [])
	if sm.is_empty() or int(sm[0]) != seed_v:
		var noise := FastNoiseLite.new()
		TerrainSlice.configure_noise(noise, seed_v)
		sm = [seed_v, noise, TerrainSlice.new_corner_cache()]
		_ease_samplers[tid] = sm
	_ease_mutex.unlock()
	return TerrainSlice.height_wrapped_in(seed_v, sm[1], x, z, float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS, sm[2], [])

## Phase 232 — lake `lk` as it is at (x, z): beside an older recorded chunk its surface eases to that chunk's water, by
## `Frontier.water_weight` of the distance to its nearest edge point: down to the chunk's ground when it is dry (the water
## ends at a shore, not a cut), or to the surface the chunk's own lake has (worldgen 12 to 16), so the two meet at one level.
## The depth (dry chunk only) and freeboard go with the weight; `w` tells `lake_ground` how much of the shore to carve.
static func _eased(lk: Dictionary, x: float, z: float) -> Dictionary:
	var ease: Variant = lk.get("ease")
	if ease == null:
		return lk
	var best := INF
	var at := Vector2.ZERO
	var dry := true
	for rc in ease["rects"]:
		var rect: Rect2 = rc[0]
		var q := Vector2(clampf(x, rect.position.x, rect.end.x), clampf(z, rect.position.y, rect.end.y))
		var d := q.distance_to(Vector2(x, z))
		if d < best:
			best = d
			at = q
			dry = bool(rc[1])
	var w := Frontier.water_weight(best)
	if w >= 1.0:
		return lk
	var s := float(lk["surface"])
	var out := (lk as Dictionary).duplicate()
	if dry:
		var g := _ease_ground(int(ease["seed"]), at.x, at.y)
		out["surface"] = lerpf(minf(g, s), s, w)
		out["depth"] = float(lk["depth"]) * w
	else:
		out["surface"] = lerpf(float(lk.get("s0", s)), s, w)
	out["fb"] = (_lake_freeboard if _warmed else 0.5) * w
	out["w"] = w
	return out

## Phase 232 — the levee's height (m) at `out` metres beyond a shore whose water is at `surface`: the water level at
## the shore, rising to the freeboard at LAKE_CREST_M, then falling LAKE_LEVEE_SLOPE per metre to the water level again.
static func levee_height(surface: float, out: float, freeboard: float = -1.0) -> float:
	warm()
	var fb := _lake_freeboard if freeboard < 0.0 else freeboard
	if out <= 0.0:
		return surface
	if out < LAKE_CREST_M:
		return surface + fb * out / LAKE_CREST_M
	return surface + maxf(0.0, fb - (out - LAKE_CREST_M) * LAKE_LEVEE_SLOPE)

## Phase 232 — ground `h` (m) at distance `d` (m) from the centre of lake `lk` carved with its bowl, bank and levee, in integer mm
## through `terrain_csg.gd`. Inside the disc the ground is smooth-subtracted down to the bowl (a paraboloid, flat at the shore
## and `depth` under the water at the centre). Outside, the ground is cut to the bank line and the result is smooth-unioned
## up into the levee, so the water always meets a sloping bank. Pure.
static func lake_ground(lk: Dictionary, d: float, h: float) -> float:
	var r := float(lk["r"])
	var s_mm := roundi(float(lk["surface"]) * 1000.0)
	var g := roundi(h * 1000.0)
	if d < r:
		var t := d * d / (r * r)
		var bed := s_mm - roundi(float(lk["depth"]) * (1.0 - t) * 1000.0) - 50
		if not lk.has("shore"):
			return minf(h, float(bed) * 0.001)
		return float(mini(g, Csg.smooth_union(g, bed, LAKE_K_MM))) * 0.001
	if not lk.has("shore"):
		return h
	var out := d - r
	if out >= LAKE_REACH_M:
		return h
	var wt := float(lk.get("w", 1.0))   # Phase 232: less than 1 beside an older recorded chunk, which the shore must not alter
	if wt <= 0.0:
		return h
	var out_mm := roundi(out * 1000.0)
	var soft_mm := roundi(LAKE_BANK_SOFT_M * 1000.0)
	var cut := s_mm - 50 + mini(out_mm, soft_mm) * LAKE_BANK_NUM / LAKE_BANK_DEN + maxi(out_mm - soft_mm, 0) * LAKE_WALL_SLOPE
	var lowered := Csg.smooth_union(g, cut, LAKE_K_MM) if cut - g < LAKE_K_MM else g
	var levee := roundi(levee_height(float(lk["surface"]), out, float(lk.get("fb", -1.0))) * 1000.0)
	var shore := float(Csg.smooth_intersection(lowered, levee, LAKE_K_MM)) * 0.001
	# The shore fades out over the last LAKE_SHORE_FADE_M before LAKE_REACH_M, so the ground meets the untouched ground beyond
	# without a step (the levee's smooth union can lift, and the cut lower, the ground a little right up to the edge).
	wt *= clampf((LAKE_REACH_M - out) / LAKE_SHORE_FADE_M, 0.0, 1.0)
	return shore if wt >= 1.0 else lerpf(h, shore, wt)

# ---------------------------------------------------------------------------
# Rivers
# ---------------------------------------------------------------------------

## The river whose source lies in cell (cx, cz): `{ pts: PackedVector2Array, surf: PackedFloat64Array,
## wid: PackedFloat64Array, pond: Dictionary }`, or {} when the cell has none. Cached; pure.
static func river_of_cell(seed_v: int, cx: int, cz: int, tier: int = 3) -> Dictionary:
	warm()
	var key := Vector3i(cx, cz, tier)
	_mutex.lock()
	var by_seed: Variant = _rivers.get(seed_v)
	if by_seed != null and (by_seed as Dictionary).has(key):
		var hit: Dictionary = (by_seed as Dictionary)[key]
		_mutex.unlock()
		return hit
	var gen := _gen
	_mutex.unlock()
	var river := _trace_river(seed_v, cx, cz, tier)
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

static func _trace_river(seed_v: int, cx: int, cz: int, tier: int) -> Dictionary:
	var w := float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS
	var rcell := river_cell(tier)
	var ccx := posmod(cx, _cells(w, rcell))
	if _rand(seed_v, ccx, cz, 11) >= RIVER_CHANCE:
		return {}
	var p := Vector2((float(cx) + _rand(seed_v, ccx, cz, 12)) * rcell, (float(cz) + _rand(seed_v, ccx, cz, 13)) * rcell)
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
		if _biome_blocked(seed_v, q.x, q.y):
			break
		if tier >= 1:   # worldgen 16: the river's whole reach keeps off the spawn plain, not just its vertices
			if Geometry2D.get_closest_point_to_segment(WorldShape.SPAWN_CENTER, p, q).distance_to(WorldShape.SPAWN_CENTER) < WorldShape.SPAWN_PLAIN_M + _wmax * 0.5:
				break
		elif (q - WorldShape.SPAWN_CENTER).length() < WorldShape.SPAWN_PLAIN_M:
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
	var rv := record_version(chunk)
	if rv < HYDROLOGY_VERSION:
		return { "lakes": [], "segs": [] }
	var tier := tier_of(rv)   # a chunk recorded earlier keeps the lakes and rivers it had (worldgen 16, 17, 18 changes)
	var ckey := Vector3i(chunk.x, chunk.y, tier)
	_mutex.lock()
	var by_seed: Variant = _features.get(seed_v)
	var hit: Variant = (by_seed as Dictionary).get(ckey) if by_seed != null else null
	var gen := _gen
	_mutex.unlock()
	if hit != null:
		return _with_ease(hit, seed_v)
	var built := _build_features(chunk, seed_v, tier)
	_mutex.lock()
	if gen != _gen:   # reset while building: the result may use old parameters, so it is not stored
		_mutex.unlock()
		return _with_ease(built, seed_v)
	if _features_n >= FEATURE_CACHE_MAX:
		_features.clear()
		_features_n = 0
	if not _features.has(seed_v):
		_features[seed_v] = {}
	(_features[seed_v] as Dictionary)[ckey] = built
	_features_n += 1
	_mutex.unlock()
	return _with_ease(built, seed_v)

## The features of block `block` (a BLOCK_M square, `floori(x / BLOCK_M)`), cached. A superset of the features of
## every chunk inside it, in the same order, so `water_at` answers any point in the block as its chunk's features do.
static func block_features(block: Vector2i, seed_v: int, tier: int = 3) -> Dictionary:
	var bkey := Vector3i(block.x, block.y, tier)
	_mutex.lock()
	var by_seed: Variant = _blocks.get(seed_v)
	var hit: Variant = (by_seed as Dictionary).get(bkey) if by_seed != null else null
	var gen := _gen
	_mutex.unlock()
	if hit != null:
		return _with_ease(hit, seed_v)
	var x0 := float(block.x) * BLOCK_M
	var z0 := float(block.y) * BLOCK_M
	var built := _features_in(seed_v, x0, z0, x0 + BLOCK_M, z0 + BLOCK_M, tier)
	_mutex.lock()
	if gen != _gen:   # reset while building (a worker outlived it): the result is returned, not stored
		_mutex.unlock()
		return _with_ease(built, seed_v)
	if _blocks_n >= BLOCK_CACHE_MAX:
		_blocks.clear()
		_blocks_n = 0
	if not _blocks.has(seed_v):
		_blocks[seed_v] = {}
	(_blocks[seed_v] as Dictionary)[bkey] = built
	_blocks_n += 1
	_mutex.unlock()
	return _with_ease(built, seed_v)

static func _build_features(chunk: Vector2i, seed_v: int, tier: int = 3) -> Dictionary:
	var cm := TerrainSlice.CHUNK_METERS
	return _features_in(seed_v, float(chunk.x) * cm, float(chunk.y) * cm, float(chunk.x + 1) * cm, float(chunk.y + 1) * cm, tier)

## The lakes and river segments that reach the rectangle [x0, x1] × [z0, z1], in cell order.
static func _features_in(seed_v: int, x0: float, z0: float, x1: float, z1: float, tier: int = 3) -> Dictionary:
	var out := { "lakes": [], "segs": [] }
	warm()
	var pad := _wmax + LAKE_RADIUS_MAX + LAKE_REACH_M
	# Lakes: the cells whose disc can reach the chunk.
	for cz in range(floori((z0 - pad) / lake_cell()), floori((z1 + pad) / lake_cell()) + 1):
		for cx in range(floori((x0 - pad) / lake_cell()), floori((x1 + pad) / lake_cell()) + 1):
			var lk := lake_of_cell(seed_v, cx, cz, tier)
			if not lk.is_empty() and _disc_touches(lk, x0, z0, x1, z1):
				out["lakes"].append(lk)
	# Phase 245: with a planet bake loaded the rivers are the baked ones, not the local trace.
	var bk: Variant = _baked.get(seed_v)
	if bk != null:
		out["segs"].append_array(baked_segs(bk["bake"], float(bk["cell"]), x0, z0, x1, z1))
		return out
	# Rivers: a river of RIVER_MAX_STEPS steps reaches that far from its source cell.
	var reach := RIVER_STEP_M * float(RIVER_MAX_STEPS) + _wmax + BANK_REACH_M
	var rcell := river_cell(tier)
	var rcx0 := floori((x0 - reach) / rcell)
	var rcx1 := floori((x1 + reach) / rcell)
	var rcz0 := floori((z0 - reach) / rcell)
	var rcz1 := floori((z1 + reach) / rcell)
	for cz in range(rcz0, rcz1 + 1):
		for cx in range(rcx0, rcx1 + 1):
			var rv := river_of_cell(seed_v, cx, cz, tier)
			if rv.is_empty() or float(rv["x1"]) < x0 or float(rv["x0"]) > x1 or float(rv["z1"]) < z0 or float(rv["z0"]) > z1:
				continue
			var pts: PackedVector2Array = rv["pts"]
			var surf: PackedFloat64Array = rv["surf"]
			var wid: PackedFloat64Array = rv["wid"]
			for i in range(pts.size() - 1):
				var a := pts[i]
				var b := pts[i + 1]
				var hw := maxf(wid[i], wid[i + 1]) * 0.5
				var rw := hw + BANK_REACH_M   # Phase 302: a soft bank reaches past the water
				if maxf(a.x, b.x) + rw < x0 or minf(a.x, b.x) - rw > x1 or maxf(a.y, b.y) + rw < z0 or minf(a.y, b.y) - rw > z1:
					continue
				out["segs"].append([a.x, a.y, b.x, b.y, surf[i], surf[i + 1], hw, wid[i] * 0.5])
			var pd: Dictionary = rv["pond"]
			if not pd.is_empty() and _disc_touches(pd, x0, z0, x1, z1):
				out["lakes"].append(pd)
	return out

static var _baked: Dictionary = {}   # seed → { bake: Dictionary, cell: float (m), macro: bool }

## Phase 245 — read this seed's rivers from `bake` (`PlanetBake.bake_planet`), whose cells are `circumference_m / w`
## metres wide, instead of tracing them. Clears every cache. Main thread, before chunks build.
## Phase 302: with `macro` the macro height is the bake's too (`TerrainSlice.macro_height`); a world recorded at
## worldgen 14 keeps the noise macro height under its baked rivers.
static func use_bake(seed_v: int, bake: Dictionary, circumference_m: float, macro: bool = true) -> void:
	_baked[seed_v] = { "bake": bake, "cell": circumference_m / float(int(bake["w"])), "macro": macro }
	reset_cache()

## The bake entry (`{ bake, cell, macro }`) whose macro height this seed's ground reads, or null. Any thread.
static func macro_bake(seed_v: int) -> Variant:
	var bk: Variant = _baked.get(seed_v)
	return bk if bk != null and bool(bk["macro"]) else null

static func clear_bake(seed_v: int) -> void:
	_baked.erase(seed_v)
	reset_cache()

static func clear_all_bakes() -> void:
	_baked.clear()

static func has_bake(seed_v: int) -> bool:
	return _baked.has(seed_v)

## The river segments (`[ax, az, bx, bz, surf_a, surf_b, half_end, half_start]`, as `water_at` reads them) of the baked
## river cells that touch the box: each river cell runs to the cell it drains to, its width from its flow, its surface
## the baked filled height less half a metre. Pure.
static func baked_segs(bake: Dictionary, cell: float, x0: float, z0: float, x1: float, z1: float) -> Array:
	var out := []
	var w: int = bake["w"]
	var h: int = bake["h"]
	var half_h := cell * float(h) * 0.5
	var pad := _wmax * 4.0 + cell
	var river: PackedInt32Array = bake["river"]
	var dir: PackedInt32Array = bake["dir"]
	var flow: PackedInt32Array = bake["flow"]
	var height: PackedInt32Array = bake["height"]
	for cz in range(maxi(floori((z0 + half_h - pad) / cell), 0), mini(floori((z1 + half_h + pad) / cell), h - 1) + 1):
		for cx in range(floori((x0 - pad) / cell), floori((x1 + pad) / cell) + 1):
			var xi := posmod(cx, w)
			var i := cz * w + xi
			var d := dir[i]
			if river[i] == 0 or d < 0:
				continue
			var ax := (float(cx) + 0.5) * cell
			var az := (float(cz) + 0.5) * cell - half_h
			var dxc := (d % w) - xi   # Phase 232: a drain across the X seam is one cell away, not w - 1
			if dxc > w / 2:
				dxc -= w
			elif dxc < -(w / 2):
				dxc += w
			var bx := ax + float(dxc) * cell
			var bz := az + float(d / w - cz) * cell
			var wa := clampf(float(PlanetBake.river_width_mm(flow[i])) * 0.001, _wmin, _wmax * 4.0)
			var wb := clampf(float(PlanetBake.river_width_mm(flow[d])) * 0.001, _wmin, _wmax * 4.0)
			var hw := maxf(wa, wb) * 0.5
			var rw := hw + BANK_REACH_M   # Phase 302: a soft bank reaches past the water
			if maxf(ax, bx) + rw < x0 or minf(ax, bx) - rw > x1 or maxf(az, bz) + rw < z0 or minf(az, bz) - rw > z1:
				continue
			out.append([ax, az, bx, bz, float(height[i]) * 0.001 - 0.5, float(height[d]) * 0.001 - 0.5, hw, wa * 0.5])
	return out

static func _disc_touches(d: Dictionary, x0: float, z0: float, x1: float, z1: float) -> bool:
	var r := float(d["r"]) + (LAKE_REACH_M if d.has("shore") else 0.0)   # a shore reaches past its disc
	return float(d["x"]) + r >= x0 and float(d["x"]) - r <= x1 and float(d["z"]) + r >= z0 and float(d["z"]) - r <= z1

# ---------------------------------------------------------------------------
# Per-point queries
# ---------------------------------------------------------------------------

## `{ "surface": float, "bed": float, "width": float }` for the water at (x, z) (width: the river's there, INF in a lake) given `features`, or {} when dry. The bed
## is the highest the ground may be there; the surface is the water level. Where a lake and a river
## overlap the lower surface wins nothing: the first feature found is used (all are static).
static func water_at(features: Dictionary, x: float, z: float) -> Dictionary:
	for lk0 in features["lakes"]:
		var dx := x - float(lk0["x"])
		var dz := z - float(lk0["z"])
		var r := float(lk0["r"])
		var d2 := dx * dx + dz * dz
		if d2 < r * r:
			var lk := _eased(lk0, x, z)
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
## whose centre lies in water to that water's bed, and (Phase 302) carve the rivers with soft banks. In place;
## returns `hm`.
static func carve(chunk: Vector2i, seed_v: int, hm: Array) -> Array:
	var f := features_for_chunk(chunk, seed_v)
	if f["lakes"].is_empty() and f["segs"].is_empty():
		return hm
	var soft := soft_banks(chunk)
	var ox := float(chunk.x * TerrainSlice.CHUNK_SIZE) * TerrainSlice.TILE_SIZE
	var oz := float(chunk.y * TerrainSlice.CHUNK_SIZE) * TerrainSlice.TILE_SIZE
	for tz in TerrainSlice.CHUNK_SIZE:
		for tx in TerrainSlice.CHUNK_SIZE:
			var cur: Variant = hm[tz * TerrainSlice.CHUNK_SIZE + tx]
			if cur == null:
				continue
			hm[tz * TerrainSlice.CHUNK_SIZE + tx] = _carve_point(f, ox + float(tx) * TerrainSlice.TILE_SIZE, oz + float(tz) * TerrainSlice.TILE_SIZE, float(cur), soft)
	return hm

## The ground height at one point after carving (what `get_height_at` returns).
static func carved_height(seed_v: int, x: float, z: float, h: float) -> float:
	var cm := TerrainSlice.CHUNK_METERS
	var chunk := Vector2i(floori(x / cm), floori(z / cm))
	return _carve_point(features_for_chunk(chunk, seed_v), x, z, h, soft_banks(chunk))

## Phase 302 — true when chunk `c` carves its rivers with soft banks: unrecorded, or recorded at SOFT_BANK_VERSION or later.
static func soft_banks(c: Vector2i) -> bool:
	if ChunkRecords.is_empty():
		return true
	var rec := ChunkRecords.get_record(TerrainSlice.wrap_chunk(c))
	return rec.is_empty() or int(rec.get("v", 0)) >= SOFT_BANK_VERSION

## Ground `h` at (x, z) carved by `f`: a lake lowers it to its bed; a river either the same (`soft` false, the
## hard edge of worldgen 12–14) or by `soft_carve`.
static func _carve_point(f: Dictionary, x: float, z: float, h: float, soft: bool) -> float:
	if not soft:
		var wt := water_at(f, x, z)
		return h if wt.is_empty() else minf(h, float(wt["bed"]))
	var out := h
	for lk0 in f["lakes"]:   # as `water_at`: the first lake holding the point lowers it to its bed
		var lk: Dictionary = lk0
		var dx := x - float(lk["x"])
		var dz := z - float(lk["z"])
		var r := float(lk["r"])
		var d2 := dx * dx + dz * dz
		if lk.has("shore"):
			if d2 < (r + LAKE_REACH_M) * (r + LAKE_REACH_M):   # Phase 232: the bowl, bank and levee
				out = lake_ground(_eased(lk, x, z), sqrt(d2), out)
				break
		elif d2 < r * r:
			out = minf(out, float(lk["surface"]) - float(lk["depth"]) * (1.0 - d2 / (r * r)) - 0.05)
			break
	return soft_carve(f["segs"], x, z, out)

## Phase 302 — ground `h` (m) at (x, z) with every river segment of `segs` subtracted smoothly, in integer mm
## through `terrain_csg.gd`: each segment is a tapered capsule (a disc at the closest point of its line) whose floor lies `min(RIVER_BED_DEPTH, slope × half
## width)` under its water, with banks rising BANK_SLOPE_NUM / BANK_SLOPE_DEN from the floor so they meet the
## water at its edge; the segments' cuts are joined sharply (so a joint between two does not dip) and the result
## is joined to the ground by a smooth union of width BANK_K_MM. Continuous everywhere; a tile
## the carve does not lower keeps its exact height. Pure.
static func soft_carve(segs: Array, x: float, z: float, h: float) -> float:
	if segs.is_empty():
		return h
	var g := roundi(h * 1000.0)
	var cut_all := 0x3FFFFFFFFFFFFFFF
	var reach_mm := roundi(BANK_REACH_M * 1000.0)
	var soft_mm := roundi(BANK_SOFT_M * 1000.0)
	for sg in segs:
		var ax: float = sg[0]
		var az: float = sg[1]
		var abx: float = float(sg[2]) - ax
		var abz: float = float(sg[3]) - az
		var len2 := abx * abx + abz * abz
		var t := clampf(((x - ax) * abx + (z - az) * abz) / len2, 0.0, 1.0) if len2 > 0.0 else 0.0
		var water_mm := roundi(lerpf(float(sg[4]), float(sg[5]), t) * 1000.0)
		var half_mm := roundi(lerpf(float(sg[7]), float(sg[6]), t) * 1000.0)
		var depth_mm := mini(roundi(RIVER_BED_DEPTH * 1000.0), half_mm * BANK_SLOPE_NUM / BANK_SLOPE_DEN)
		var r0 := maxi(half_mm - depth_mm * BANK_SLOPE_DEN / BANK_SLOPE_NUM, 0)
		# The capsule's distance is the disc's at the closest point of the line (`t` above), in mm local to that
		# point, so the integer maths stays small for a segment of any length anywhere on the planet.
		var d := Csg.disc(Vector2i(roundi((x - ax - abx * t) * 1000.0), roundi((z - az - abz * t) * 1000.0)), Vector2i.ZERO, r0)
		if d > reach_mm:
			continue
		var cut := water_mm - depth_mm + maxi(d, 0) * BANK_SLOPE_NUM / BANK_SLOPE_DEN + maxi(d - soft_mm, 0) * BANK_WALL_SLOPE
		cut_all = Csg.union(cut_all, cut)   # sharp between segments, so a joint does not dip below the water
	if cut_all - g >= BANK_K_MM:
		return h
	return float(Csg.smooth_union(g, cut_all, BANK_K_MM)) * 0.001

## The fresh-water surface at (x, z) (metres), or NAN when there is none. Used for swimming, the
## creature path cost and the water mesh.
static func surface_at(seed_v: int, x: float, z: float) -> float:
	var wt := _water_point(seed_v, x, z)
	return NAN if wt.is_empty() else float(wt["surface"])

## `water_at` for one point (`surface_at`, `water_width_at`): its chunk's record gate, then the cached
## features of its BLOCK_M block (#591), so a creature path's width queries cost what swimming's do.
static func _water_point(seed_v: int, x: float, z: float) -> Dictionary:
	var cm := TerrainSlice.CHUNK_METERS
	var rv := record_version(Vector2i(floori(x / cm), floori(z / cm)))
	if rv < HYDROLOGY_VERSION:
		return {}
	return water_at(block_features(Vector2i(floori(x / BLOCK_M), floori(z / BLOCK_M)), seed_v, tier_of(rv)), x, z)

## How wide the fresh water at (x, z) is (metres): a river's width there, INF for a lake or pond, 0 when dry.
## A creature fords a river narrower than its path's `ford_width_m`.
static func water_width_at(seed_v: int, x: float, z: float) -> float:
	var wt := _water_point(seed_v, x, z)
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
