extends RefCounted
## Phase 193 — the dive guard: pure reads of the voxel column under a body, so a fast dive can neither carry
## the feet through ground whose collision has not landed (`descent_room`) nor leave them inside it
## (`buried_lift`). Since Phase 189 a fast flyer keeps collision only on the chunk under it, and a step at
## 90 m/s is 1.5 m: the column is the ground truth the mesh and the collision are built from.
##
## Public API:
##   descent_room(feet_y, runs) -> float — static: how far the feet may drop this step
##   buried_lift(feet_y, runs) -> float  — static: where buried feet belong, else feet_y

const VoxelConsts := preload("res://src/terrain/voxel_consts.gd")

## Feet within this of a run's top stand on it; deeper than `BURIED_MARGIN` they are inside it.
const STAND_EPS := 0.05
const BURIED_MARGIN := 0.25   # two height steps: a body pressed into the ground by less is the physics' to settle

## Phase 193 — how far feet at `feet_y` may drop before they reach the ground under them: the distance down to
## the highest run top at or below them, or to the bedrock floor. Pure.
static func descent_room(feet_y: float, runs: Array) -> float:
	var ground := VoxelConsts.BEDROCK_DEPTH
	for run in runs:
		var top := float(run["top"])
		if top <= feet_y + STAND_EPS and top > ground:
			ground = top
	return maxf(feet_y - ground, 0.0)

## Phase 193 — where feet at `feet_y` belong when they are inside a solid run (deeper than `BURIED_MARGIN`
## below its top): that run's top. Else `feet_y` itself. Pure.
static func buried_lift(feet_y: float, runs: Array) -> float:
	for run in runs:
		var top := float(run["top"])
		if float(run["bottom"]) < feet_y and feet_y < top - BURIED_MARGIN:
			return top
	return feet_y
