extends RefCounted
## Phase 64 — the one dither rule for a biome border. Pure and static, so the voxel surface, the
## yield and the minimap all draw the same band from the same hash and the same falloff.
##
## Within `band` tiles of a chunk border a tile may wear the biome across that border: the chance
## is `MAX_CHANCE` at the border and falls linearly to zero at the band's inner edge, and a
## coordinate hash (no RNG, no thread state) decides, so every caller agrees on every tile.

const MAX_CHANCE := 0.5

## Deterministic roll in [0, 1) for the tile (gx, gz).
static func roll(gx: int, gz: int) -> float:
	return float(((gx * 73856093) ^ (gz * 19349663)) & 0xffff) / 65536.0

## Chance that a tile `d` tiles from the border wears the neighbour's biome, for a band `band` wide.
static func chance(d: float, band: float) -> float:
	if d >= band or band <= 0.0:
		return 0.0
	return MAX_CHANCE * (1.0 - maxf(d, 0.0) / band)

## True when tile (gx, gz), `d` tiles from the border, wears the neighbour's biome.
static func wears_neighbour(gx: int, gz: int, d: float, band: float) -> bool:
	return roll(gx, gz) < chance(d, band)
