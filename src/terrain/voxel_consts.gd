extends RefCounted
const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")
const SeamWrap := preload("res://src/terrain/seam_wrap.gd")

## Numeric constants the voxel slice and its extracted modules share (Phase 154). `VoxelSlice` re-exports each under its old name.
const CHUNK_SIZE  := 64        # the authoritative copy lives in TerrainSlice
const TILE_SIZE   := 0.5       # world units per tile (XZ) — half the former 1.0 size
const STEP_HEIGHT := 0.125     # world units per quantised height step (smooth, walkable — no jumps)
const BEDROCK_DEPTH := -96.0   # cannot mine below this — the world's floor
const MAX_HEIGHT    := 640.0   # build cap — cannot place above this
const FALLBACK_TERRAIN_COLOR := Color(0.35, 0.60, 0.28)

## Tile X wrapped into [-C*CHUNK_SIZE/2, C*CHUNK_SIZE/2) where C is the circumference in chunks.
static func canonical_tile(tile: Vector2i) -> Vector2i:
	var w := TerrainSlice.circumference_chunks() * CHUNK_SIZE
	return Vector2i(SeamWrap.wrap_i(tile.x, w), tile.y)

static func tile_key(tile: Vector2i) -> String:
	# Phase 63: canonical across the seam, so an edit east of it is the edit west of it.
	var t := canonical_tile(tile)
	return "%d,%d" % [t.x, t.y]

static func voxel_height(raw_height: float) -> float:
	return floor(raw_height / STEP_HEIGHT) * STEP_HEIGHT
