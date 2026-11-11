extends RefCounted
## Phase 240 — on smooth ground a natural slope is walked by `floor_max_angle`, and one too steep is a
## wall, so the step-up only climbs a PLACED block: the column just ahead must hold a placed run whose
## top is a step above the feet.

const VoxelRay := preload("res://src/terrain/voxel_ray.gd")
## The capsule's radius: the column read is the one just past the body's front.
const BODY_RADIUS := 0.25

## May the body at `pos` (scene), walking along `dir`, take the step-up? `voxel` answers
## `get_runs_at_tile`; `offset` is the scene offset (world = scene - offset).
static func allowed(voxel: Node, pos: Vector3, dir: Vector3, offset: Vector3, feet: float, step: float) -> bool:
	if voxel == null or not voxel.has_method("get_runs_at_tile"):
		return true
	# The column along `dir` and, for a diagonal push, the one along each axis component too: walking
	# into a block's face at an angle puts the `dir` point in the diagonal tile beside it.
	var reach := BODY_RADIUS + VoxelRay.TILE * 0.5
	var seen: Dictionary = {}
	for d in [Vector3(dir.x, 0.0, dir.z), Vector3(dir.x, 0.0, 0.0), Vector3(0.0, 0.0, dir.z)]:
		if d.length_squared() < 0.0001:
			continue
		var tile: Vector2i = VoxelRay.tile_of(pos + d.normalized() * reach, offset)
		if seen.has(tile):
			continue
		seen[tile] = true
		if placed_step(voxel.get_runs_at_tile(tile), feet, step):
			return true
	return false

## Pure: does `runs` (the column ahead) hold a placed run (a material) whose top is above `feet` by at
## most `step`?
static func placed_step(runs: Array, feet: float, step: float) -> bool:
	for run in runs:
		if str(run.get("material", "")) == "":
			continue
		var rise := float(run["top"]) - feet
		if rise > 0.001 and rise <= step + 0.001:
			return true
	return false
