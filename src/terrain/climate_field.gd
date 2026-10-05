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

## Feature point of cell (ix, iz), in chunk units.
static func _feature_point(seed_v: int, ix: int, iz: int) -> Vector2:
	var jx := float(_mix(seed_v, ix, iz, 1) % 10000) / 10000.0 - 0.5
	var jz := float(_mix(seed_v, ix, iz, 2) % 10000) / 10000.0 - 0.5
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
	var v00 := float(_mix(seed_v, ix, iz, salt) % 10000) / 9999.0
	var v10 := float(_mix(seed_v, ix + 1, iz, salt) % 10000) / 9999.0
	var v01 := float(_mix(seed_v, ix, iz + 1, salt) % 10000) / 9999.0
	var v11 := float(_mix(seed_v, ix + 1, iz + 1, salt) % 10000) / 9999.0
	return lerpf(lerpf(v00, v10, fx), lerpf(v01, v11, fx), fz)

## World-seeded temperature in [0, 1] at a point in chunk units (0 coldest). Planar for now;
## Phase 51 makes it follow latitude and altitude.
static func temperature(seed_v: int, p: Vector2) -> float:
	return clampf(0.5 + (_value_noise(seed_v, p, 11) - 0.5) * CONTRAST, 0.0, 1.0)

## World-seeded moisture in [0, 1] at a point in chunk units (0 driest).
static func moisture(seed_v: int, p: Vector2) -> float:
	return clampf(0.5 + (_value_noise(seed_v, p, 12) - 0.5) * CONTRAST, 0.0, 1.0)

## biome key -> [temp_min, temp_max, moist_min, moist_max], snapshotted from the fabric biome
## resources by `warm()` on the MAIN thread (OreField.warm calls it from VoxelSlice._ready,
## before any worker exists) and read-only afterwards, like OreField's band table. The ore
## field asks `biome_for_chunk` from a chunk-build worker, so the lookup reads this plain
## data rather than Resource properties, and costs a few float compares per biome.
static var _envelopes: Dictionary = {}
static var _warmed := false

## Fill the envelope table from `GameData.BIOMES` (idempotent). Main thread only.
static func warm() -> void:
	if _warmed:
		return
	_warmed = true
	for key in GameData.BIOMES:
		var env := _envelope_of(GameData.BIOMES[key])
		if not env.is_empty():
			_envelopes[str(key)] = env

## [temp_min, temp_max, moist_min, moist_max] of a biome resource, or [] without an envelope.
static func _envelope_of(biome: Variant) -> Array:
	if biome == null:
		return []
	var te: Variant = biome.get("temperature")
	var me: Variant = biome.get("moisture")
	if not (te is Dictionary) or not (me is Dictionary) or (te as Dictionary).is_empty() or (me as Dictionary).is_empty():
		return []
	return [float(te["min"]), float(te["max"]), float(me["min"]), float(me["max"])]

## How far (t, m) lies outside an envelope; 0 inside it. `.y` is the distance to the envelope's
## centre, which breaks ties between overlapping envelopes.
static func _envelope_gap(t: float, m: float, env: Array) -> Vector2:
	if env.is_empty():
		return Vector2(INF, INF)
	var gap := maxf(maxf(env[0] - t, t - env[1]), 0.0) + maxf(maxf(env[2] - m, m - env[3]), 0.0)
	var centre := absf(t - (env[0] + env[1]) * 0.5) + absf(m - (env[2] + env[3]) * 0.5)
	return Vector2(gap, centre)

## The biome whose fabric climate envelope fits (temperature, moisture): the smallest gap to its
## envelope, then the nearest envelope centre. "" when no biome carries an envelope.
static func biome_for_climate(t: float, m: float, keys: Array, biomes: Dictionary) -> String:
	var envs: Dictionary = {}
	for key in keys:
		envs[str(key)] = _envelope_of(biomes.get(key, null))
	return _pick(t, m, keys, envs)

static func _pick(t: float, m: float, keys: Array, envs: Dictionary) -> String:
	var best := ""
	var best_g := Vector2(INF, INF)
	for key in keys:
		var g := _envelope_gap(t, m, envs.get(str(key), []))
		if g.x < best_g.x or (g.x == best_g.x and g.y < best_g.y):
			best_g = g
			best = str(key)
	return best

## Biome key for a chunk, read at its centre. Climate envelopes from the fabric choose it when
## the biome resources are loaded; an isolated rig without them falls back to Voronoi cells.
static func biome_for_chunk(seed_v: int, chunk_pos: Vector2i, keys: Array) -> String:
	if keys.is_empty():
		return ""   # also guards the `% keys.size()` below
	# The 3x3 cell search below is exact only while a feature point stays within ~0.8 of a
	# cell of its centre; a larger JITTER could put the true nearest point one ring further out.
	assert(JITTER <= 0.8, "ClimateField.JITTER too large for the 3x3 nearest-point search")
	if not _warmed:
		warm()   # an isolated caller that never warmed it: a main-thread call
	var p := Vector2(chunk_pos.x + 0.5, chunk_pos.y + 0.5)
	var picked := _pick(temperature(seed_v, p), moisture(seed_v, p), keys, _envelopes)
	if picked != "":
		return picked
	return _voronoi_biome(seed_v, chunk_pos, keys)

## Voronoi fallback: the cell whose feature point is nearest the chunk centre owns it.
static func _voronoi_biome(seed_v: int, chunk_pos: Vector2i, keys: Array) -> String:
	if keys.is_empty():
		return ""
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
	return str(keys[_mix(seed_v, bx, bz, 3) % keys.size()])
