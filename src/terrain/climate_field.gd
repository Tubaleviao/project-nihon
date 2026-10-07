extends RefCounted
## Phase 49 — world-seeded biome REGIONS. Pure and static so worker threads (the ore field)
## can ask it without a terrain-slice reference.
##
## The retired `biome_for_chunk` hash reduced modulo 5 to `(cx - cz) mod 5`, so the biome
## changed on every axis-aligned chunk crossing in diagonal stripes, identically in every
## world. Here the plane is cut into jittered Voronoi cells `CELL_CHUNKS` chunks wide; each
## cell hashes (with the seed) to one biome, so a biome is a region hundreds of metres
## across and two seeds lay the regions out differently.

const CELL_CHUNKS := 8
const JITTER := 0.8 ## fraction of a cell a feature point may wander from the cell centre

## 64-bit integer mix (wraps); `salt` separates independent draws from one cell.
static func _mix(seed_v: int, a: int, b: int, salt: int) -> int:
	var h: int = seed_v * 6364136223846793005 + a * 2654435761 + b * 2246822519 + salt * 3266489917
	h = (h ^ (h >> 29)) * -4658895280553007687
	h = h ^ (h >> 32)
	return h & 0x7fffffff

## Every lattice draw reduces the hash to `[0, 1)` the same way, so no site mixes two scales.
const LATTICE_MOD := 10000
static func _lattice(seed_v: int, a: int, b: int, salt: int) -> float:
	return float(_mix(seed_v, a, b, salt) % LATTICE_MOD) / float(LATTICE_MOD)

## Feature point of cell (ix, iz), in chunk units.
static func _feature_point(seed_v: int, ix: int, iz: int) -> Vector2:
	var jx := _lattice(seed_v, ix, iz, 1) - 0.5
	var jz := _lattice(seed_v, ix, iz, 2) - 0.5
	return Vector2((ix + 0.5 + jx * JITTER) * CELL_CHUNKS, (iz + 0.5 + jz * JITTER) * CELL_CHUNKS)

## Climate wavelength, in chunks: temperature and moisture drift over about this distance, so
## a biome is a region several hundred metres across.
const CLIMATE_CHUNKS := 12.0
const CONTRAST := 1.6 ## stretches the value noise (which clusters near 0.5) toward the extremes

## Smooth value noise in [0, 1] at `p` (chunk units); `salt` separates temperature from moisture.
static func _value_noise(seed_v: int, p: Vector2, salt: int) -> float:
	var q := p / CLIMATE_CHUNKS
	var ix := floori(q.x)
	var iz := floori(q.y)
	var fx := q.x - ix
	var fz := q.y - iz
	fx = fx * fx * (3.0 - 2.0 * fx)
	fz = fz * fz * (3.0 - 2.0 * fz)
	var v00 := _lattice(seed_v, ix, iz, salt)
	var v10 := _lattice(seed_v, ix + 1, iz, salt)
	var v01 := _lattice(seed_v, ix, iz + 1, salt)
	var v11 := _lattice(seed_v, ix + 1, iz + 1, salt)
	return lerpf(lerpf(v00, v10, fx), lerpf(v01, v11, fx), fz)

## Temperature drop per metre of altitude, in normalised units: a 1,200 m peak is a whole unit colder.
const LAPSE_PER_M := 1.0 / 1200.0
## Normalised temperature at the equator at sea level; it falls with the cosine of latitude to 0 at the pole.
const EQUATOR_TEMPERATURE := 0.8
const CLIMATE_NOISE := 0.4 ## amplitude of the regional noise around the latitude and altitude baseline

## Phase 51 — temperature that follows the planet: warm at the equator, cold at the poles
## (`lat_deg`), and falling with altitude above sea level (`altitude_m`), plus regional noise.
static func temperature_at(seed_v: int, p: Vector2, lat_deg: float, altitude_m: float) -> float:
	var lat_cos := cos(deg_to_rad(clampf(absf(lat_deg), 0.0, 90.0)))
	var base := EQUATOR_TEMPERATURE * lat_cos
	# The regional noise fades toward the poles, so the polar cap is cold everywhere.
	var noise := (_value_noise(seed_v, p, 11) - 0.5) * CONTRAST * CLIMATE_NOISE * lat_cos
	return clampf(base + noise - maxf(altitude_m, 0.0) * LAPSE_PER_M, 0.0, 1.0)

## World-seeded moisture in [0, 1] at a point in chunk units (0 driest).
static func moisture(seed_v: int, p: Vector2) -> float:
	return clampf(0.5 + (_value_noise(seed_v, p, 12) - 0.5) * CONTRAST, 0.0, 1.0)

## Envelope model: each fabric biome declares a temperature range, a moisture range and
## optionally an altitude range and a `rarity`. A chunk's (temperature, moisture, altitude) is
## matched to the biome whose envelope it sits inside (or nearest to); a rare biome is only
## eligible inside its niche cells (see `niche_value`). A biome with no climate envelope never
## wins, and when no biome has one the Voronoi fallback picks.
##
## biome key -> [temp_min, temp_max, moist_min, moist_max, alt_min, alt_max, rarity], snapshotted
## from the fabric biome resources by `warm()` on the MAIN thread (TerrainSlice and OreField warm
## it from `_ready`, before any worker exists) and read-only afterwards, like OreField's band
## table. The ore field asks `biome_for_chunk` from a chunk-build worker, so the lookup reads
## this plain data rather than Resource properties, and costs a few float compares per biome.
static var _envelopes: Dictionary = {}
static var _warmed := false

## Fill the envelope table from `GameData.BIOMES` (idempotent). Main thread only.
static func warm() -> void:
	if _warmed:
		return
	for key in GameData.BIOMES:
		var env := _envelope_of(GameData.BIOMES[key])
		if not env.is_empty():
			_envelopes[str(key)] = env
	_warmed = not _envelopes.is_empty()

## [temp_min, temp_max, moist_min, moist_max, alt_min, alt_max, rarity] of a biome resource, or []
## without a climate envelope. A biome with no altitude envelope fits any height; no rarity is 1.
## (Phase 51 added the last three.)
static func _envelope_of(biome: Variant) -> Array:
	if biome == null:
		return []
	var te: Variant = biome.get("temperature")
	var me: Variant = biome.get("moisture")
	if not (te is Dictionary) or not (me is Dictionary) or (te as Dictionary).is_empty() or (me as Dictionary).is_empty():
		return []
	var al: Variant = biome.get("altitude")
	var amin := -100000.0
	var amax := 100000.0
	if al is Dictionary and not (al as Dictionary).is_empty():
		amin = float((al as Dictionary).get("min", amin))
		amax = float((al as Dictionary).get("max", amax))
	var rar: Variant = biome.get("rarity")
	var tmap := te as Dictionary
	var mmap := me as Dictionary
	return [float(tmap.get("min", 0.0)), float(tmap.get("max", 1.0)),
		float(mmap.get("min", 0.0)), float(mmap.get("max", 1.0)), amin, amax,
		float(rar) if rar != null else 1.0]

## Metres of altitude that weigh as much as one whole unit of temperature or moisture gap.
const ALTITUDE_GAP_M := 10.0
## Width of a niche cell, in chunks: a rare biome is eligible in a whole cell or none of it.
const NICHE_CELL_CHUNKS := 10

## Niche features are this many niche cells across, so a rare biome's niche is a blob several
## cells wide rather than one white-noise cell.
const NICHE_FEATURE_CELLS := 3

## Stable per-biome salt: a hash of the biome KEY, so adding or reordering biomes never moves
## another biome's niche.
static func niche_salt(key: String) -> int:
	return int(key.hash() & 0x7fffffff)

## Quantiles (0, 1/128, ..., 1) of the raw smooth niche noise. The noise clusters around 0.5, so
## `niche_value` maps it through this table to a uniform draw; that keeps a rare biome's covered
## share equal to its `rarity`.
const _NICHE_QUANTILES: Array = [
	.0005, 0.0602, 0.0843, 0.1028, 0.1185, 0.1327, 0.1454, 0.1572, 0.1679, 0.1778,
	0.1874, 0.1962, 0.2048, 0.2134, 0.2213, 0.2293, 0.2370, 0.2445, 0.2516, 0.2586,
	0.2653, 0.2718, 0.2783, 0.2848, 0.2911, 0.2973, 0.3035, 0.3096, 0.3155, 0.3212,
	0.3271, 0.3328, 0.3384, 0.3440, 0.3496, 0.3552, 0.3606, 0.3659, 0.3712, 0.3765,
	0.3819, 0.3871, 0.3925, 0.3978, 0.4030, 0.4081, 0.4132, 0.4182, 0.4234, 0.4285,
	0.4335, 0.4386, 0.4436, 0.4485, 0.4533, 0.4582, 0.4630, 0.4679, 0.4728, 0.4778,
	0.4828, 0.4875, 0.4924, 0.4972, 0.5022, 0.5071, 0.5120, 0.5168, 0.5217, 0.5264,
	0.5312, 0.5361, 0.5410, 0.5460, 0.5509, 0.5560, 0.5608, 0.5659, 0.5708, 0.5757,
	0.5808, 0.5858, 0.5909, 0.5959, 0.6011, 0.6062, 0.6113, 0.6164, 0.6216, 0.6269,
	0.6322, 0.6374, 0.6430, 0.6485, 0.6540, 0.6597, 0.6654, 0.6710, 0.6768, 0.6825,
	0.6883, 0.6944, 0.7004, 0.7064, 0.7128, 0.7190, 0.7255, 0.7321, 0.7388, 0.7456,
	0.7528, 0.7602, 0.7676, 0.7753, 0.7833, 0.7914, 0.7997, 0.8085, 0.8173, 0.8269,
	0.8373, 0.8479, 0.8592, 0.8713, 0.8855, 0.9006, 0.9184, 0.9419, 0.9995,
]

## Smooth, low-frequency niche draw, uniform in [0, 1], at chunk-unit point `p`; `salt` is
## `niche_salt(biome key)`, so two rare biomes do not claim the same ground.
static func niche_value(seed_v: int, p: Vector2, salt: int) -> float:
	var q := p / float(NICHE_CELL_CHUNKS * NICHE_FEATURE_CELLS)
	var ix := floori(q.x)
	var iz := floori(q.y)
	var fx := q.x - ix
	var fz := q.y - iz
	fx = fx * fx * (3.0 - 2.0 * fx)
	fz = fz * fz * (3.0 - 2.0 * fz)
	var s := 100 + salt
	var raw := lerpf(lerpf(_lattice(seed_v, ix, iz, s), _lattice(seed_v, ix + 1, iz, s), fx),
		lerpf(_lattice(seed_v, ix, iz + 1, s), _lattice(seed_v, ix + 1, iz + 1, s), fx), fz)
	var last := _NICHE_QUANTILES.size() - 1
	var idx := clampi(_NICHE_QUANTILES.bsearch(raw), 1, last)
	var lo: float = _NICHE_QUANTILES[idx - 1]
	var hi: float = _NICHE_QUANTILES[idx]
	var t := 0.0 if hi <= lo else clampf((raw - lo) / (hi - lo), 0.0, 1.0)
	return minf((float(idx - 1) + t) / float(last), 0.9999)

## How far (t, m, altitude) lies outside an envelope; 0 inside it. `.y` is 0 for a rare (niche)
## biome and 1 for a common one, so where both fit a niche wins; `.z` is the distance to the
## envelope's centre, which breaks the remaining ties.
static func _envelope_gap(t: float, m: float, alt: float, env: Array, niche: float = 0.0) -> Vector3:
	if env.is_empty():
		return Vector3(INF, INF, INF)
	var rarity: float = env[6] if env.size() > 6 else 1.0
	if rarity < 1.0 and niche >= rarity:
		return Vector3(INF, INF, INF)   # a rare biome outside its niche
	var amin: float = env[4] if env.size() > 4 else -100000.0
	var amax: float = env[5] if env.size() > 5 else 100000.0
	var gap := maxf(maxf(env[0] - t, t - env[1]), 0.0) + maxf(maxf(env[2] - m, m - env[3]), 0.0) \
		+ maxf(maxf(amin - alt, alt - amax), 0.0) / ALTITUDE_GAP_M
	var centre := absf(t - (env[0] + env[1]) * 0.5) + absf(m - (env[2] + env[3]) * 0.5)
	return Vector3(gap, 0.0 if rarity < 1.0 else 1.0, centre)

static func _pick(t: float, m: float, alt: float, keys: Array, envs: Dictionary, niche: Variant, per_biome_niche: bool, seed_v: int = 0, p: Vector2 = Vector2.ZERO) -> String:
	var best := ""
	var best_g := Vector3(INF, INF, INF)
	for key in keys:
		var nv: float = niche_value(seed_v, p, niche_salt(str(key))) if per_biome_niche else float(niche)
		var g := _envelope_gap(t, m, alt, envs.get(str(key), []), nv)
		if g.x < best_g.x or (g.x == best_g.x and (g.y < best_g.y or (g.y == best_g.y and g.z < best_g.z))):
			best_g = g
			best = str(key)
	return best

## Biome key for a chunk, read at its centre. Climate envelopes from the fabric choose it when
## the biome resources are loaded; an isolated rig without them falls back to Voronoi cells.
##
## Phase 51 — `lat_deg` (the chunk's latitude) and `altitude_m` (its large-scale height above sea
## level) feed the temperature and the altitude envelope; the defaults are the equator at 50 m.
static func biome_for_chunk(seed_v: int, chunk_pos: Vector2i, keys: Array, lat_deg: float = 0.0, altitude_m: float = 50.0) -> String:
	if keys.is_empty():
		return ""   # also guards the `% keys.size()` below
	# The 3x3 cell search below is exact only while a feature point stays within ~0.8 of a
	# cell of its centre; a larger JITTER could put the true nearest point one ring further out.
	assert(JITTER <= 0.8, "ClimateField.JITTER too large for the 3x3 nearest-point search")
	if not _warmed and OS.get_thread_caller_id() == OS.get_main_thread_id():
		warm()   # an isolated main-thread caller that never warmed it; a worker never writes the table
	var p := Vector2(chunk_pos.x + 0.5, chunk_pos.y + 0.5)
	var picked := _pick(temperature_at(seed_v, p, lat_deg, altitude_m), moisture(seed_v, p), altitude_m, keys, _envelopes, 0.0, true, seed_v, p)
	if picked != "":
		return picked
	return _voronoi_biome(seed_v, chunk_pos, keys)

const FALLBACK_BIOMES: Array = ["TemperateForest", "TemperateGrassland", "VolcanicBadlands", "TwilightGrove", "VoidRift"]

## Voronoi fallback: the cell whose feature point is nearest the chunk centre owns it.
static func _voronoi_biome(seed_v: int, chunk_pos: Vector2i, keys: Array) -> String:
	if keys.is_empty():
		return ""
	# Only the original land biomes: never Ocean, Beach or Alpine, which need altitude to be right.
	var pool: Array = keys.filter(func(k): return FALLBACK_BIOMES.has(str(k)))
	if pool.is_empty():
		pool = keys   # an isolated rig with its own key set
	var p := Vector2(chunk_pos.x + 0.5, chunk_pos.y + 0.5)
	var cx := floori(p.x / CELL_CHUNKS)
	var cz := floori(p.y / CELL_CHUNKS)
	var best_d := INF
	var bx := cx
	var bz := cz
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var d := _feature_point(seed_v, cx + dx, cz + dz).distance_squared_to(p)
			if d < best_d:
				best_d = d
				bx = cx + dx
				bz = cz + dz
	return str(pool[_mix(seed_v, bx, bz, 3) % pool.size()])
