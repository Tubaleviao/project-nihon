extends RefCounted
## Spawn roll — the pure, seeded half of population scarcity (Phase 44).
##
## Before this phase every chunk of a biome carried the same creature count and the same
## tree count: no chunk was empty, nothing clustered, and the population was a constant.
## Population is now a PRODUCT of a per-chunk chance, a smooth density field and (for
## creatures, host-only) a global cap. This file owns the first two — everything that is a
## function of (world seed, chunk, salt) and nothing else.
##
## Pure and static: no node, no bus, no `randi()`. The roll comes from an integer hash of
## the seed and the chunk coordinate, so the same (seed, chunk) always gives the same
## pack centre and size and the host's decision can be re-derived rather than trusted.
## Only the host spawns creatures today (`spawn_for_chunk` returns on a non-authoritative
## peer); a client path would reuse these rolls. The cap is NOT here: it is a host-only
## quantity.
##
## Public API (all static):
##   unit(seed, chunk, salt) -> float                 a hash roll in [0, 1)
##   density(seed, chunk, amplitude) -> float         a smooth multiplier in
##                                                    [1 - amplitude, 1 + amplitude]
##   pack_size(seed, chunk, salt, count, chance, amplitude) -> int
##                                                    0 = the chunk rolls no spawn

## Density-noise lattice spacing, in chunks: the multiplier varies smoothly over ~this
## many chunks, so packs thicken and thin across the world instead of flickering per chunk.
const DENSITY_CELL := 4

static func _mix(seed: int, a: int, b: int, salt: int) -> int:
	var h: int = seed * 374761393 + a * 668265263 + b * 2147483647 + salt * 1274126177
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return h & 0x7fffffff

## A hash roll in [0, 1) for (seed, chunk, salt).
static func unit(seed: int, chunk: Vector2i, salt: String) -> float:
	return float(_mix(seed, chunk.x, chunk.y, salt.hash())) / 2147483648.0

## Smooth value noise in [0, 1) over the chunk plane (bilinear, smoothstep-eased).
static func _noise(seed: int, chunk: Vector2i) -> float:
	var fx: float = float(chunk.x) / float(DENSITY_CELL)
	var fz: float = float(chunk.y) / float(DENSITY_CELL)
	var x0: int = int(floor(fx))
	var z0: int = int(floor(fz))
	var tx: float = smoothstep(0.0, 1.0, fx - float(x0))
	var tz: float = smoothstep(0.0, 1.0, fz - float(z0))
	var a: float = unit(seed, Vector2i(x0, z0), "density")
	var b: float = unit(seed, Vector2i(x0 + 1, z0), "density")
	var c: float = unit(seed, Vector2i(x0, z0 + 1), "density")
	var d: float = unit(seed, Vector2i(x0 + 1, z0 + 1), "density")
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)

## The density multiplier at `chunk`: 1.0 on average, swinging by +/- `amplitude`
## (clamped to 0..1) across the world. Amplitude 0 is a flat 1.0.
static func density(seed: int, chunk: Vector2i, amplitude: float) -> float:
	var amp: float = clampf(amplitude, 0.0, 1.0)
	if amp == 0.0:
		return 1.0
	return 1.0 + amp * (_noise(seed, chunk) * 2.0 - 1.0)

## Pack size for one species at one chunk: 0 when the seeded chance roll fails, else
## `count` scaled by the density multiplier (at least 1). The chance is itself scaled by
## the multiplier, so a dense region both rolls a pack more often and grows it larger.
static func pack_size(seed: int, chunk: Vector2i, salt: String, count: int,
		chance: float, amplitude: float) -> int:
	if count <= 0:
		return 0
	var mult: float = density(seed, chunk, amplitude)
	if unit(seed, chunk, salt + "#roll") >= clampf(chance * mult, 0.0, 1.0):
		return 0
	return maxi(1, int(round(float(count) * mult)))
