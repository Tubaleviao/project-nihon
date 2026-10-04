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

## How far (t, m) lies outside a biome's fabric climate envelope; 0 inside it. Ties between
## overlapping envelopes go to the one whose centre is nearer (the caller adds that).
static func _envelope_gap(t: float, m: float, biome: Variant) -> Vector2:
	var te: Dictionary = biome.get("temperature") if biome != null and biome.get("temperature") != null else {}
	var me: Dictionary = biome.get("moisture") if biome != null and biome.get("moisture") != null else {}
	if te.is_empty() or me.is_empty():
		return Vector2(INF, INF)
	var tl := float(te["min"])
	var th := float(te["max"])
	var ml := float(me["min"])
	var mh := float(me["max"])
	var gap := maxf(maxf(tl - t, t - th), 0.0) + maxf(maxf(ml - m, m - mh), 0.0)
	var centre := absf(t - (tl + th) * 0.5) + absf(m - (ml + mh) * 0.5)
	return Vector2(gap, centre)

## The biome whose fabric climate envelope fits (temperature, moisture): the smallest gap to its
## envelope, then the nearest envelope centre. "" when no biome carries an envelope.
static func biome_for_climate(t: float, m: float, keys: Array, biomes: Dictionary) -> String:
	var best := ""
	var best_g := Vector2(INF, INF)
	for key in keys:
		var g := _envelope_gap(t, m, biomes.get(key, null))
		if g.x < best_g.x or (g.x == best_g.x and g.y < best_g.y):
			best_g = g
			best = str(key)
	return best

## Biome key for a chunk, read at its centre. Climate envelopes from the fabric choose it when
## the biome resources are loaded; an isolated rig without them falls back to Voronoi cells.
static func biome_for_chunk(seed_v: int, chunk_pos: Vector2i, keys: Array) -> String:
	if keys.is_empty():
		return ""
	var p := Vector2(chunk_pos.x + 0.5, chunk_pos.y + 0.5)
	var picked := biome_for_climate(temperature(seed_v, p), moisture(seed_v, p), keys, GameData.BIOMES)
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
