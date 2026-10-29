extends RefCounted
## Bed rule (Phase 185) — pure helpers for where a bed lets a body stand again. The world is read through
## `runs_at: Callable(Vector2i) -> Array` of `{ bottom, top }` runs (the column model, as `ShelterRule`),
## so a test hands in a fixture and the host its voxels.

const VoxelConsts := preload("res://src/terrain/voxel_consts.gd")

## A body needs this much free height above its feet (m).
const CLEARANCE := 1.8
## How far a blocked bed looks for a free standing cell: tiles around it, and metres of height.
const SEARCH_TILES := 6
const SEARCH_HEIGHT := 3.0
const EPS := 0.001
## Ground that rises less than this above a body's feet is a lip it steps over, not a wall.
const LIP := 0.25

## The fabric bed table, or {} with no fabric.
static func rules() -> Dictionary:
	var res: Resource = GameData.WORLD_SYSTEMS.get("BedSpawn", null)
	if res == null or not (res.get("rules") is Dictionary):
		return {}
	return res.get("rules")

static func tile_of(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / VoxelConsts.TILE_SIZE), floori(pos.z / VoxelConsts.TILE_SIZE))

## True when a body standing with its feet at `pos` overlaps solid material.
static func blocked(pos: Vector3, runs_at: Callable) -> bool:
	for run in runs_at.call(tile_of(pos)):
		if float(run["bottom"]) < pos.y + CLEARANCE - EPS and float(run["top"]) > pos.y + LIP:
			return true
	return false

## The offset from a blocked `pos` to the nearest free standing cell, or null when none lies within
## SEARCH_TILES / SEARCH_HEIGHT. A free `pos` returns Vector3.ZERO. Ground is a run's top with
## CLEARANCE of air above it; nearer tiles win, then the smaller height change.
static func nearest_free(pos: Vector3, runs_at: Callable) -> Variant:
	if not blocked(pos, runs_at):
		return Vector3.ZERO
	var origin := tile_of(pos)
	var best: Variant = null
	var best_score := INF
	for dx in range(-SEARCH_TILES, SEARCH_TILES + 1):
		for dz in range(-SEARCH_TILES, SEARCH_TILES + 1):
			var tile := origin + Vector2i(dx, dz)
			var centre := Vector3((tile.x + 0.5) * VoxelConsts.TILE_SIZE, pos.y, (tile.y + 0.5) * VoxelConsts.TILE_SIZE)
			for run in runs_at.call(tile):
				var top := float(run["top"])
				if absf(top - pos.y) > SEARCH_HEIGHT:
					continue
				var cand := Vector3(centre.x, top, centre.z)
				if blocked(cand, runs_at):
					continue
				var score := Vector2(cand.x - pos.x, cand.z - pos.z).length() + absf(top - pos.y) * 0.01
				if score < best_score:
					best_score = score
					best = cand - pos
	return best
