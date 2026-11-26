extends RefCounted
## Phase 245 — a baked river carved into the ground: the height at a point drops by a channel profile around the
## river's polyline, deepest on the centreline and easing out over `bank` (smoothstep), so a river runs in a channel
## with soft banks at any detail-noise height. Integer fixed point (`TerrainCsg.ONE` a metre), same bytes everywhere.
## The distance to the river is `TerrainCsg.polyline` (a chain of capsules of radius `half_width`).

const TerrainCsg := preload("res://src/terrain/terrain_csg.gd")

## Channel depth for a river carrying `flow` cells: grows with the root of the flow, capped.
static func depth_for_flow(flow: int, per_root: int, max_depth: int) -> int:
	return mini(TerrainCsg.isqrt(maxi(flow, 0)) * per_root, max_depth)

## Half width for `flow`: the same root law, so a river is wider downstream.
static func half_width_for_flow(flow: int, per_root: int) -> int:
	return TerrainCsg.isqrt(maxi(flow, 0)) * per_root

## How much of `depth` is cut at signed distance `d` from the river's edge (<= 0 inside, the full depth).
static func cut_at(d: int, depth: int, bank: int) -> int:
	if d <= 0:
		return depth
	if d >= bank:
		return 0
	var u := (d << TerrainCsg.SHIFT) / bank                                  # Q10 in (0, 1)
	var s := (u * u * ((3 << TerrainCsg.SHIFT) - 2 * u)) >> (2 * TerrainCsg.SHIFT)   # smoothstep, Q10
	return (depth * (TerrainCsg.ONE - s)) >> TerrainCsg.SHIFT

## The ground height at (px, pz) after the river along `pts` is cut into `ground`.
static func carve(ground: int, px: int, pz: int, pts: Array, half_width: int, depth: int, bank: int) -> int:
	return ground - cut_at(TerrainCsg.polyline(px, pz, pts, half_width), depth, bank)
