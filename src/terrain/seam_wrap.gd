extends RefCounted
## Phase 126 — the one implementation of "wrap round the world seam". The world is a sphere whose X axis
## closes on itself after `lap` units; every canonical position, shortest distance and lap size goes
## through here so no module keeps its own copy. Pure, static and free of other modules (no preloads), so
## `TerrainSlice` and `VoxelSlice` can use it without a cycle.

## `v` wrapped into [-lap/2, lap/2) (integer units: chunks or tiles).
static func wrap_i(v: int, lap: int) -> int:
	return posmod(v + lap / 2, lap) - lap / 2

## `v` wrapped into [-lap/2, lap/2) (float units: metres).
static func wrap_f(v: float, lap: float) -> float:
	return fposmod(v + lap * 0.5, lap) - lap * 0.5

## The shortest signed distance `a - b` round a lap (integers).
static func delta(a: int, b: int, lap: int) -> int:
	return wrap_i(a - b, lap)

## The shortest signed distance `a - b` round a lap (floats).
static func delta_f(a: float, b: float, lap: float) -> float:
	return wrap_f(a - b, lap)

## Tiles in one lap of the world: `circumference_chunks` chunks of `chunk_size` tiles.
static func world_tiles(circumference_chunks: int, chunk_size: int) -> int:
	return circumference_chunks * maxi(chunk_size, 1)

## Metres in one lap of the world.
static func world_metres(circumference_chunks: int, chunk_size: int, tile_size: float) -> float:
	return float(world_tiles(circumference_chunks, chunk_size)) * tile_size
