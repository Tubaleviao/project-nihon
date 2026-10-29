extends RefCounted
## Shelter rule (Phase 184) — whether a bed stands in a roofed room. One pure rule, read by the host
## (Phase 185) and by the tutorial's `shelter_complete` trigger (Phase 186). The numbers are the
## fabric's `BedSpawn.rules.shelter`:
##   - roof: a solid run in the bed's own tile starts above the bed and at most `roofWithinMetres`
##     above it;
##   - sides: at least `minClosedSides` of the four sides (±x, ±z) are closed. Walking out from the
##     bed's tile on a side, some tile within `sideReachMetres` is solid at `wallCheckMetres` above the
##     bed (a wall at chest height: a one-step lip does not close a side, a hillside does).
##
## The world is read through `runs_at: Callable(Vector2i) -> Array` of `{ bottom, top }` runs (the
## column model, `VoxelSlice.get_runs_at_tile`), so a test hands in a fixture and the host its voxels.

const VoxelConsts := preload("res://src/terrain/voxel_consts.gd")

const SIDES: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Heights within this of the bed count as the bed's own floor, not a roof.
const EPS := 0.001

## The fabric shelter table, or {} with no fabric.
static func rules() -> Dictionary:
	var res: Resource = GameData.WORLD_SYSTEMS.get("BedSpawn", null)
	if res == null or not (res.get("rules") is Dictionary):
		return {}
	var shelter = (res.get("rules") as Dictionary).get("shelter", {})
	return shelter if shelter is Dictionary else {}

## The tile a world position stands in.
static func tile_of(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / VoxelConsts.TILE_SIZE), floori(pos.z / VoxelConsts.TILE_SIZE))

## True when a bed at `bed` (its floor height in y) is sheltered under `shelter` (rules() by default).
static func is_sheltered(bed: Vector3, runs_at: Callable, shelter: Dictionary = {}) -> bool:
	var r := shelter if not shelter.is_empty() else rules()
	if r.is_empty():
		return false
	return has_roof(bed, runs_at, r) and closed_sides(bed, runs_at, r) >= int(r.get("minClosedSides", 4))

## A solid run in the bed's tile that starts above the bed and within roofWithinMetres of it.
static func has_roof(bed: Vector3, runs_at: Callable, r: Dictionary) -> bool:
	var reach := float(r.get("roofWithinMetres", 0.0))
	for run in runs_at.call(tile_of(bed)):
		var bottom := float(run["bottom"])
		if bottom > bed.y + EPS and bottom <= bed.y + reach + EPS:
			return true
	return false

## How many of the four sides are closed (0..4).
static func closed_sides(bed: Vector3, runs_at: Callable, r: Dictionary) -> int:
	var origin := tile_of(bed)
	var steps := maxi(1, ceili(float(r.get("sideReachMetres", 0.0)) / VoxelConsts.TILE_SIZE - EPS))
	var wall_y := bed.y + float(r.get("wallCheckMetres", 0.0))
	var closed := 0
	for dir in SIDES:
		for i in range(1, steps + 1):
			if _solid_at(runs_at.call(origin + dir * i), wall_y):
				closed += 1
				break
	return closed

static func _solid_at(runs: Array, y: float) -> bool:
	for run in runs:
		if float(run["bottom"]) <= y and float(run["top"]) >= y:
			return true
	return false
