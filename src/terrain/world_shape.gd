extends RefCounted
## Phase 51 — the planet's large-scale shape: ocean basins, coasts, plains and mountain ranges.
##
## Pure and static (an integer-lattice value noise, no `FastNoiseLite`), so the ore field and the
## climate picker can ask a chunk's height from a worker thread with only the seed, and so the
## shape stays exact at 10,000 km from the origin where a float32 noise would not.
##
## Three fields are combined through the fabric's `heightSpline`:
##   continentalness  thousand-kilometre scale: ocean basin, shelf, coast or inland
##   erosion          flat plains (high) versus rugged land (low)
##   ridges           mountain ranges, strongest on rugged inland ground
## The lattices wrap east-west (their cell counts divide the circumference), so the shape has no
## seam at the antimeridian.

const SeamWrap := preload("res://src/terrain/seam_wrap.gd")
const SEA_LEVEL_DEFAULT := 0.0
const MIN_HEIGHT_DEFAULT := -64.0
const MAX_HEIGHT_DEFAULT := 8850.0
## Phase 211 — the fabric's `buildCeiling`: nothing is placed above it (`VoxelConsts.build_ceiling`).
const BUILD_CEILING_DEFAULT := 9400.0
const OCEAN_SHARE_DEFAULT := 0.65
const RIDGE_AMPLITUDE_DEFAULT := 400.0
## Fallback spline (the fabric's default) for a rig without the generated resources.
const SPLINE_DEFAULT: Array = [[0.0, -64.0], [0.35, -52.0], [0.55, -24.0], [0.64, -2.0], [0.68, 3.0], [0.75, 30.0], [0.88, 90.0], [1.0, 140.0]]

## Lattice cells around the circumference: 16, 44 and 128 (2,500, 909 and 312 km at 40,000 km).
const CONTINENT_CELLS := [16, 44, 128]
const CONTINENT_WEIGHTS := [0.55, 0.3, 0.15]
const EROSION_CELLS := 64
## Phase 188: 1,600 cells (25 km at 40,000 km), with a second octave at 8.3 km. At 320 cells one ridge
## was ~125 km wide, so inland it was a plateau hundreds of kilometres across; now ranges are thin lines
## of peaks with valleys between them.
const RIDGE_CELLS := 1600
## Phase 238: the same cell sizes in metres on the 2,000 km planet (25 km ridges, 31 km massifs), 40 km spawn clearance.
## A planet past SMALL_PLANET_M round (a pre-238 world, 40,000 km) keeps the lattices above.
const RIDGE_CELLS_SMALL := 80
const MASSIF_CELLS_SMALL := 64
const MASSIF_SPAWN_CLEAR_M_SMALL := 40000.0
const SMALL_PLANET_M := 1.0e7

static func ridge_cells(w: float) -> int:
	return RIDGE_CELLS_SMALL if w < SMALL_PLANET_M else RIDGE_CELLS

static func massif_cells(w: float) -> int:
	return MASSIF_CELLS_SMALL if w < SMALL_PLANET_M else MASSIF_CELLS

static func massif_clear_m(w: float) -> float:
	return MASSIF_SPAWN_CLEAR_M_SMALL if w < SMALL_PLANET_M else MASSIF_SPAWN_CLEAR_M
## Exponent on the ridge profile. The two-octave noise clusters near 0.5, so the old square kept most
## rugged inland ground near full ridge height; a high power keeps only the crest lines.
const RIDGE_SHARPNESS := 10.0
## Phase 211 — Earth-scale ranges. A ridge of 8 km with the crest profile above would be a needle (its
## slope near the crest is about 20 × amplitude × the noise gradient), so the height comes from a broad
## massif instead: a 156 km lattice (256 cells) whose high nodes lift rugged inland ground into plateaus
## up to `maxHeight`, with the ridges on top grown to MASSIF_RIDGE_GAIN × `ridgeAmplitude` at the summit.
## Only nodes above MASSIF_FLOOR rise at all, so most land keeps the Phase 188 ranges.
const MASSIF_CELLS := 256
const MASSIF_FLOOR := 0.8
const MASSIF_RIDGE_GAIN := 2.0
## The massifs stay away from the origin as the spawn plain does (some seeds put a summit node on it): none
## within MASSIF_SPAWN_CLEAR_M of the spawn centre, full strength from twice that.
const MASSIF_SPAWN_CLEAR_M := 100000.0
const CONTRAST := 1.9 ## stretches the fbm (which clusters near 0.5) toward the extremes

## Phase 53 retired the 20 m flattened disc in `TerrainSlice`; this large-scale plain stays, so the
## origin region is dry land for every seed (the dev rig and the suite stand on it) and `SpawnFinder`
## places new players by the planet's habitable land, not by this. The height is forced to the plain's height
## (`spawn_plain_height`) within SPAWN_PLAIN_M of the spawn and eases back to the natural shape by SPAWN_EASE_M,
## so the player always starts on dry, flat ground. Worldgen 9: the plain sits at the surrounding land's mean
## level (never below SPAWN_HEIGHT), not always at SPAWN_HEIGHT, so on a highland it is a level plain instead
## of a pit hundreds of metres deep. Phase 188: the plain is capped at SPAWN_PLAIN_MAX, below the lowest
## ground Alpine can claim (its fabric altitude floor), so a first-boot spawn is never on snow.
const SPAWN_CENTER := Vector2(16.0, 16.0)
const SPAWN_HEIGHT := 2.0   ## the lowest the spawn plain lies (dry land just above the default sea)
const SPAWN_PLAIN_MAX := 150.0 ## the highest the spawn plain lies (below the Alpine floor)
const SPAWN_PLAIN_M := 1500.0
const SPAWN_EASE_M := 4000.0

static var _warmed := false
static var _sea := SEA_LEVEL_DEFAULT
static var _min_h := MIN_HEIGHT_DEFAULT
static var _max_h := MAX_HEIGHT_DEFAULT
static var _ocean_share := OCEAN_SHARE_DEFAULT
static var _ridge_amp := RIDGE_AMPLITUDE_DEFAULT
static var _ceiling := BUILD_CEILING_DEFAULT
static var _spline: Array = SPLINE_DEFAULT

## Snapshot the fabric's world entity (idempotent). Main thread only, before any worker exists.
static func warm() -> void:
	if _warmed:
		return
	var ws: Variant = GameData.WORLD_SYSTEMS.get("WorldSystem", null)
	if ws != null:
		_sea = _num(ws, "seaLevel", _sea)
		_min_h = _num(ws, "minHeight", _min_h)
		_max_h = _num(ws, "maxHeight", _max_h)
		_ceiling = _num(ws, "buildCeiling", _ceiling)
		_ocean_share = _num(ws, "oceanShare", _ocean_share)
		_ridge_amp = _num(ws, "ridgeAmplitude", _ridge_amp)
		var cs: Variant = ws.get("continents")
		if cs is Array and not (cs as Array).is_empty():
			_continents = []
			for k in cs:
				_continents.append([float(k["latitude"]), float(k["longitude"]), float(k["radiusKm"]), bool(k["open"])])
		var sp: Variant = ws.get("heightSpline")
		if sp is Array and (sp as Array).size() >= 2:
			_spline = sp
	_warmed = true
	reset_plain_cache()

## Phase 106 — the warmed fabric parameters the shape reads, in a fixed order, for
## `TerrainSlice.worldgen_fingerprint`.
static func fingerprint_fields() -> Array:
	warm()
	return [_sea, _min_h, _max_h, _ocean_share, _ridge_amp, _spline, _continents]

static func _num(res: Variant, field: String, fallback: float) -> float:
	var v: Variant = res.get(field)
	return float(v) if v != null else fallback

static func sea_level() -> float:
	warm()
	return _sea

static func min_height() -> float:
	warm()
	return _min_h

static func max_height() -> float:
	warm()
	return _max_h

## Phase 211 — the highest a placed block may reach (the fabric's `buildCeiling`).
static func build_ceiling() -> float:
	warm()
	return _ceiling

static func ridge_amplitude() -> float:
	warm()
	return _ridge_amp

## The height spline, `[[continentalness, height], ...]`.
static func spline() -> Array:
	warm()
	return _spline

static func ocean_share() -> float:
	warm()
	return _ocean_share

## 64-bit integer mix (wraps), as ClimateField._mix.
static func _mix(seed_v: int, a: int, b: int, salt: int) -> int:
	var h: int = seed_v * 6364136223846793005 + a * 2654435761 + b * 2246822519 + salt * 3266489917
	h = (h ^ (h >> 29)) * -4658895280553007687
	h = h ^ (h >> 32)
	return h & 0x7fffffff

## Smooth value noise in [0, 1]. X has `cells_x` lattice cells around the circumference `w`
## (periodic); Z uses the same cell size and is unbounded.
static func _noise(seed_v: int, x: float, z: float, w: float, cells_x: int, salt: int) -> float:
	var cell := w / float(cells_x)
	var qx := x / cell
	var qz := z / cell
	var ix := floori(qx)
	var iz := floori(qz)
	var fx := qx - ix
	var fz := qz - iz
	fx = fx * fx * (3.0 - 2.0 * fx)
	fz = fz * fz * (3.0 - 2.0 * fz)
	var x0 := posmod(ix, cells_x)
	var x1 := posmod(ix + 1, cells_x)
	var v00 := float(_mix(seed_v, x0, iz, salt) % 10000) / 9999.0
	var v10 := float(_mix(seed_v, x1, iz, salt) % 10000) / 9999.0
	var v01 := float(_mix(seed_v, x0, iz + 1, salt) % 10000) / 9999.0
	var v11 := float(_mix(seed_v, x1, iz + 1, salt) % 10000) / 9999.0
	return lerpf(lerpf(v00, v10, fx), lerpf(v01, v11, fx), fz)

## Phase 238 — the continent mask. Continents are `[latitude, longitude, radiusKm, open]` (fabric
## `WorldSystem.continents`). Only open ones have land: inside one the noise is kept (and lifted to a land
## core so most of the core is dry), eased to the basin over the last fifth of the radius; outside every
## open continent the ground is deep ocean. A closed site is ocean too. A world saved before Phase 238
## has no mask (`set_mask_enabled(false)`).
const CONTINENT_CORE := 0.5      ## fraction of the radius inside which the land core is full strength
const CONTINENT_RIM := 0.8       ## fraction of the radius where the shelf begins to ease to the basin
const CORE_CONTINENTALNESS := 0.74   ## the core's floor: just above the coast (0.64–0.68) on the spline
## A ring of highland between the core and the rim, so the open continent holds inland ranges and summits.
const HIGHLAND_CONTINENTALNESS := 0.97
const DEFAULT_CONTINENTS: Array = [[0.0, 0.0, 300.0, true], [0.0, 180.0, 250.0, false], [55.0, 90.0, 150.0, false]]
static var _continents: Array = DEFAULT_CONTINENTS
static var _mask_on := true

static func set_mask_enabled(on: bool) -> void:
	_mask_on = on

static func mask_enabled() -> bool:
	return _mask_on

## The continent list in the form the mask reads.
static func continents() -> Array:
	warm()
	return _continents

## Distance in metres from (x, z) to the centre of continent `c` on a planet of circumference `w` m: X
## wraps, latitude and longitude are degrees of the circumference (360 degrees round, 90 pole to equator).
static func continent_distance_m(c: Array, x: float, z: float, w: float) -> float:
	var cx := float(c[1]) / 360.0 * w
	var cz := float(c[0]) / 360.0 * w
	var dx := SeamWrap.delta_f(x, cx, w)
	return Vector2(dx, z - cz).length()

## Index of the continent whose disc (radius plus `extra_m`) holds (x, z), or -1.
static func continent_at(x: float, z: float, w: float, extra_m: float = 0.0, open_only: bool = false) -> int:
	warm()
	for i in _continents.size():
		var c: Array = _continents[i]
		if open_only and not bool(c[3]):
			continue
		if continent_distance_m(c, x, z, w) <= float(c[2]) * 1000.0 + extra_m:
			return i
	return -1

## Whether (x, z) lies inside a closed site's disc widened by its rim (the last fifth of the radius).
static func closed_site_at(x: float, z: float, w: float) -> bool:
	warm()
	for c in _continents:
		if bool(c[3]):
			continue
		if continent_distance_m(c, x, z, w) <= float(c[2]) * 1000.0 * (1.0 + (1.0 - CONTINENT_RIM)):
			return true
	return false

## 1 at the heart of an open continent, easing to 0 at its edge; 0 outside every open one.
static func continent_mask(x: float, z: float, w: float) -> float:
	warm()
	var best := 0.0
	for c in _continents:
		if not bool(c[3]):
			continue
		var r := float(c[2]) * 1000.0
		var d := continent_distance_m(c, x, z, w)
		if d >= r:
			continue
		best = maxf(best, 1.0 - smoothstep(r * CONTINENT_RIM, r, d))
	return best

## Continentalness in [0, 1]: 0 deep basin, 1 deep inland.
static func continentalness(seed_v: int, x: float, z: float, w: float) -> float:
	var v := 0.0
	for i in CONTINENT_CELLS.size():
		v += CONTINENT_WEIGHTS[i] * _noise(seed_v, x, z, w, CONTINENT_CELLS[i], 21 + i)
	var c := clampf(0.5 + (v - 0.5) * CONTRAST, 0.0, 1.0)
	if not _mask_on:
		return c
	warm()
	var m := 0.0
	var core := 0.0
	var ring := 0.0
	for k in _continents:
		if not bool(k[3]):
			continue
		var r := float(k[2]) * 1000.0
		var d := continent_distance_m(k, x, z, w)
		if d >= r:
			continue
		m = maxf(m, 1.0 - smoothstep(r * CONTINENT_RIM, r, d))
		core = maxf(core, 1.0 - smoothstep(r * CONTINENT_CORE, r * CONTINENT_RIM, d))
		ring = maxf(ring, smoothstep(r * 0.1, r * 0.25, d) * (1.0 - smoothstep(r * 0.55, r * 0.75, d)))
	if m <= 0.0:
		return 0.0
	return maxf(maxf(c, CORE_CONTINENTALNESS * core), HIGHLAND_CONTINENTALNESS * ring) * m

## Erosion in [0, 1]: 1 flat plains, 0 rugged.
static func erosion(seed_v: int, x: float, z: float, w: float) -> float:
	return _noise(seed_v, x, z, w, EROSION_CELLS, 31)

## Ridge value in [0, 1]: peaks on thin lines where the underlying noise crosses 0.5.
static func ridges(seed_v: int, x: float, z: float, w: float) -> float:
	var n := _noise(seed_v, x, z, w, ridge_cells(w), 41) * 0.7 + _noise(seed_v, x, z, w, ridge_cells(w) * 3, 42) * 0.3
	return pow(1.0 - absf(n * 2.0 - 1.0), RIDGE_SHARPNESS)

## Phase 211 — massif uplift in [0, 1]: 0 below MASSIF_FLOOR, rising to 1 on the lattice's highest nodes.
## The squared smoothstep keeps the flanks long and the summit a plateau, as Earth's great ranges stand.
static func massif(seed_v: int, x: float, z: float, w: float) -> float:
	var s := smoothstep(MASSIF_FLOOR, 1.0, _noise(seed_v, x, z, w, massif_cells(w), 51))
	return s * s

## Metres the massif lifts at full strength: what is left of `maxHeight` above the spline's top and the
## summit ridges, so a ridge crest on a full massif inland meets `maxHeight` exactly.
static func massif_amplitude() -> float:
	warm()
	var top := float(_spline[_spline.size() - 1][1])
	return maxf(_max_h - top - _ridge_amp * MASSIF_RIDGE_GAIN, 0.0)

## Piecewise-linear spline lookup: continentalness -> base height.
static func spline_height(c: float) -> float:
	warm()
	var pts: Array = _spline
	if c <= float(pts[0][0]):
		return float(pts[0][1])
	for i in range(1, pts.size()):
		var x1 := float(pts[i][0])
		if c <= x1:
			var x0 := float(pts[i - 1][0])
			var t := (c - x0) / maxf(x1 - x0, 0.000001)
			return lerpf(float(pts[i - 1][1]), float(pts[i][1]), t)
	return float(pts[pts.size() - 1][1])

## Large-scale terrain height in metres at world (x, z), `w` the circumference in metres. No
## small-scale detail (TerrainSlice adds that); this is what climate and biomes read.
static func height(seed_v: int, x: float, z: float, w: float) -> float:
	var h := natural_height(seed_v, x, z, w)
	# The spawn plain.
	var d := Vector2(x - SPAWN_CENTER.x, z - SPAWN_CENTER.y).length()
	if d < SPAWN_EASE_M:
		h = lerpf(spawn_plain_height(seed_v, w), h, smoothstep(SPAWN_PLAIN_M, SPAWN_EASE_M, d))
	return h

## The shape's height with no spawn plain: the continent spline plus the inland ridges.
static func natural_height(seed_v: int, x: float, z: float, w: float) -> float:
	warm()
	var c := continentalness(seed_v, x, z, w)
	var e := erosion(seed_v, x, z, w)
	var base := spline_height(c)
	# Mountains: strongest well inland, on rugged (low-erosion) ground.
	var inland := smoothstep(0.68, 0.9, c)
	var rugged := 1.0 - smoothstep(0.35, 0.8, e)
	var m := 0.0
	if inland * rugged > 0.0:
		var d := Vector2(x - SPAWN_CENTER.x, z - SPAWN_CENTER.y).length()
		var clear := massif_clear_m(w)
		if d > clear:
			m = massif(seed_v, x, z, w) * smoothstep(clear, clear * 2.0, d)
	var ridge_amp := _ridge_amp * lerpf(1.0, MASSIF_RIDGE_GAIN, m)
	var peaks := (ridges(seed_v, x, z, w) * ridge_amp + m * massif_amplitude()) * inland * rugged
	return clampf(base + peaks, _min_h, _max_h)

## Samples on the SPAWN_EASE_M circle the spawn plain's height is the mean of.
const SPAWN_RIM_SAMPLES := 8

## "seed:circumference" -> spawn plain height; workers read it, so it is guarded. Cleared when the warmed
## parameters change (`warm`, `TerrainSlice.reset_fingerprint_cache`).
static var _plain_cache: Dictionary = {}
static var _plain_mutex := Mutex.new()
## Bumped by every reset, so a plain computed from the old parameters while a reset ran is not stored.
static var _plain_gen := 0

static func reset_plain_cache() -> void:
	_plain_mutex.lock()
	_plain_cache.clear()
	_plain_gen += 1
	_plain_mutex.unlock()

## The spawn plain's height: the mean natural height on the circle where the plain's ease ends, never below
## SPAWN_HEIGHT and never above SPAWN_PLAIN_MAX. So the ease climbs to some of the surrounding land and down to the rest, rather than all of
## it rising from a fixed 2 m. Ground that is low or sea around the spawn gives SPAWN_HEIGHT exactly, as
## before worldgen 9.
static func spawn_plain_height(seed_v: int, w: float) -> float:
	var key := "%d:%s" % [seed_v, str(w)]
	_plain_mutex.lock()
	var hit: Variant = _plain_cache.get(key, null)
	var gen := _plain_gen
	_plain_mutex.unlock()
	if hit != null:
		return float(hit)
	var plain := _spawn_plain_uncached(seed_v, w)
	_plain_mutex.lock()
	if gen == _plain_gen:
		_plain_cache[key] = plain
	_plain_mutex.unlock()
	return plain

static func _spawn_plain_uncached(seed_v: int, w: float) -> float:
	var sum := 0.0
	for i in SPAWN_RIM_SAMPLES:
		var p := SPAWN_CENTER + Vector2.from_angle(TAU * float(i) / float(SPAWN_RIM_SAMPLES)) * SPAWN_EASE_M
		sum += natural_height(seed_v, p.x, p.y, w)
	return clampf(clampf(sum / float(SPAWN_RIM_SAMPLES), SPAWN_HEIGHT, SPAWN_PLAIN_MAX), _min_h, _max_h)

## Height above sea level (negative in the ocean).
static func altitude(seed_v: int, x: float, z: float, w: float) -> float:
	return height(seed_v, x, z, w) - sea_level()

## Phase 211 — where the planet's tallest ranges stand: the massif lattice nodes (a node is a massif's
## summit plateau) with the strongest uplift on rugged inland ground, best first, as
## `[[strength, Vector2(x, z)], ...]`. Rows span pole to pole (z in ±w/4). About 33k nodes, each a few
## lattice lookups, so the suite and the playtest bot can find Earth-scale peaks without a planet scan.
static func massif_summits(seed_v: int, w: float, count: int) -> Array:
	var mc := massif_cells(w)
	var clear := massif_clear_m(w)
	var cell := w / float(mc)
	var rows := int(w * 0.25 / cell)
	var out: Array = []
	for j in range(-rows, rows + 1):
		for i in range(-mc / 2, mc / 2):
			var x := float(i) * cell   # canonical: x in [-w/2, w/2)
			var z := float(j) * cell
			var m := massif(seed_v, x, z, w) * smoothstep(clear, clear * 2.0, Vector2(x - SPAWN_CENTER.x, z - SPAWN_CENTER.y).length())
			if m <= 0.0:
				continue
			var c := continentalness(seed_v, x, z, w)
			var s := m * smoothstep(0.68, 0.9, c) * (1.0 - smoothstep(0.35, 0.8, erosion(seed_v, x, z, w)))
			if s > 0.0:
				out.append([s, Vector2(x, z)])
	out.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	return out.slice(0, count)

## Phase 211 — the highest `height` on a square grid of `step` m out to `radius` m around `centre`, as
## `[height, Vector2(x, z)]`. A summit plateau is wider than a ridge cell, so a 25 km square around a
## summit node holds its crest.
static func highest_near(seed_v: int, centre: Vector2, w: float, radius: float, step: float) -> Array:
	var best := -INF
	var at := centre
	var n := int(radius / step)
	for b in range(-n, n + 1):
		for a in range(-n, n + 1):
			var p := centre + Vector2(a, b) * step
			var h := height(seed_v, p.x, p.y, w)
			if h > best:
				best = h
				at = p
	return [best, at]

## The open continents as `[latitude, longitude, radius in metres]`, for the native shape (it mirrors the mask).
static func open_continents_m() -> Array:
	warm()
	var out: Array = []
	for c in _continents:
		if bool(c[3]):
			out.append([float(c[0]), float(c[1]), float(c[2]) * 1000.0])
	return out

## Replace the continent list (tests and tools; the fabric's list is read by `warm`). Main thread only.
static func set_continents(list: Array) -> void:
	warm()
	_continents = list
	reset_plain_cache()
