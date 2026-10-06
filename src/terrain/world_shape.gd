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

const SEA_LEVEL_DEFAULT := 0.0
const MIN_HEIGHT_DEFAULT := -64.0
const MAX_HEIGHT_DEFAULT := 512.0
const OCEAN_SHARE_DEFAULT := 0.65
const RIDGE_AMPLITUDE_DEFAULT := 400.0
## Fallback spline (the fabric's default) for a rig without the generated resources.
const SPLINE_DEFAULT: Array = [[0.0, -64.0], [0.35, -52.0], [0.55, -24.0], [0.64, -2.0], [0.68, 3.0], [0.75, 30.0], [0.88, 90.0], [1.0, 140.0]]

## Lattice cells around the circumference: 16, 44 and 128 (2,500, 909 and 312 km at 40,000 km).
const CONTINENT_CELLS := [16, 44, 128]
const CONTINENT_WEIGHTS := [0.55, 0.3, 0.15]
const EROSION_CELLS := 64
const RIDGE_CELLS := 320
const CONTRAST := 1.9 ## stretches the fbm (which clusters near 0.5) toward the extremes

## Phase 53 retired the 20 m flattened disc in `TerrainSlice`; this large-scale plain stays, so the
## origin region is dry land for every seed (the dev rig and the suite stand on it) and `SpawnFinder`
## places new players by the planet's habitable land, not by this. The height is forced to SPAWN_HEIGHT within SPAWN_PLAIN_M of the spawn and
## eases back to the natural shape by SPAWN_EASE_M, so the player always starts on dry, flat ground.
const SPAWN_CENTER := Vector2(16.0, 16.0)
const SPAWN_HEIGHT := 2.0
const SPAWN_PLAIN_M := 1500.0
const SPAWN_EASE_M := 4000.0

static var _warmed := false
static var _sea := SEA_LEVEL_DEFAULT
static var _min_h := MIN_HEIGHT_DEFAULT
static var _max_h := MAX_HEIGHT_DEFAULT
static var _ocean_share := OCEAN_SHARE_DEFAULT
static var _ridge_amp := RIDGE_AMPLITUDE_DEFAULT
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
		_ocean_share = _num(ws, "oceanShare", _ocean_share)
		_ridge_amp = _num(ws, "ridgeAmplitude", _ridge_amp)
		var sp: Variant = ws.get("heightSpline")
		if sp is Array and (sp as Array).size() >= 2:
			_spline = sp
	_warmed = true

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

## Continentalness in [0, 1]: 0 deep basin, 1 deep inland.
static func continentalness(seed_v: int, x: float, z: float, w: float) -> float:
	var v := 0.0
	for i in CONTINENT_CELLS.size():
		v += CONTINENT_WEIGHTS[i] * _noise(seed_v, x, z, w, CONTINENT_CELLS[i], 21 + i)
	return clampf(0.5 + (v - 0.5) * CONTRAST, 0.0, 1.0)

## Erosion in [0, 1]: 1 flat plains, 0 rugged.
static func erosion(seed_v: int, x: float, z: float, w: float) -> float:
	return _noise(seed_v, x, z, w, EROSION_CELLS, 31)

## Ridge value in [0, 1]: peaks on thin lines where the underlying noise crosses 0.5.
static func ridges(seed_v: int, x: float, z: float, w: float) -> float:
	var n := _noise(seed_v, x, z, w, RIDGE_CELLS, 41) * 0.7 + _noise(seed_v, x, z, w, RIDGE_CELLS * 3, 42) * 0.3
	var r := 1.0 - absf(n * 2.0 - 1.0)
	return r * r

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
	warm()
	var c := continentalness(seed_v, x, z, w)
	var e := erosion(seed_v, x, z, w)
	var base := spline_height(c)
	# Mountains: strongest well inland, on rugged (low-erosion) ground.
	var inland := smoothstep(0.68, 0.9, c)
	var rugged := 1.0 - smoothstep(0.35, 0.8, e)
	var peaks := ridges(seed_v, x, z, w) * _ridge_amp * inland * rugged
	var h := clampf(base + peaks, _min_h, _max_h)
	# The spawn plain.
	var d := Vector2(x - SPAWN_CENTER.x, z - SPAWN_CENTER.y).length()
	if d < SPAWN_EASE_M:
		h = lerpf(SPAWN_HEIGHT, h, smoothstep(SPAWN_PLAIN_M, SPAWN_EASE_M, d))
	return h

## Height above sea level (negative in the ocean).
static func altitude(seed_v: int, x: float, z: float, w: float) -> float:
	return height(seed_v, x, z, w) - sea_level()
