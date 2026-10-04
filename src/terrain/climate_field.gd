class_name ClimateField
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

## Biome key for a chunk: the cell whose feature point is nearest the chunk centre owns it.
static func biome_for_chunk(seed_v: int, chunk_pos: Vector2i, keys: Array) -> String:
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
