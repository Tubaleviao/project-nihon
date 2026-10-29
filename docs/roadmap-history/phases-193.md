# Roadmap history — Phase 193

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 193 — A lighter collision ring: a voxel aim ray, collision one ring out, and a dive guard ✅ Done

**Goal:** the playtest walk step failed the process-time gate on PR #524 (median p95 21.1 ms, limit 20)
on a slow runner. A profiled local run (`--playtest-profile`) put `chunk_attach_collision` first in the
walk: 3.0 ms a frame on average, 4.4 ms over the worst frames. A walking body kept terrain collision
two rings out (`REACH_RADIUS`, 5×5 chunks), but the first ring is only 3×3, so the other 16 chunks'
collision landed during the walk, and Jolt builds each trimesh's tree on the main thread when its
shape joins a body. Nothing but the 60 m aim, mine and build ray used the ring two out.

**Newel dependency:** NO.

**Depends on:** Phase 183 (staggered collision), Phase 189 (near ring).

**Deliverables:**
- `src/terrain/voxel_ray.gd`: a ray walked through the voxel columns (2D DDA over the 0.5 m tiles) that
  hits the same faces the collision would: tops, undersides and side faces, edits included. A tile the
  ray stays above is rejected on its column top without reading its runs. Positions are in doubles from
  the scene position and the scene offset, so it hits the right tile 5,000 km from the origin.
- `PlayerSlice._update_aim` reads the block target through `VoxelRay` (`_terrain_ray`); the pickup and
  tree rays and the camera clearance ray stay on physics.
- `NearRing.COLLISION_RADIUS` 1: a walking body keeps collision on its chunk and the eight around it.
  Full detail stays at `REACH_RADIUS` 2.
- `src/player/dive_guard.gd`: a step never drops the feet below the highest run top under them
  (`descent_room`), and feet that end more than `BURIED_MARGIN` inside a run go back onto its top
  (`buried_lift`). `PlayerSlice._move` applies both around `move_and_slide`.
- `VoxelSlice.column_top_at_tile` (was `_column_top_at_tile`) answers an unedited tile off the
  heightmap without allocating its runs.

**Acceptance criteria:**
- [x] Suite: the voxel ray lands on a top, a slanted top, a wall's side face (both directions and along
  Z), an overhang's underside; a ray starting inside a run hits the next face; out of range, straight
  up and no direction miss; it hits the right tile 5,393,152 m from the origin; a tile the ray stays above
  never reads its runs; on a built chunk it lands on the column top and on a placed block.
- [x] Suite: `descent_room` and `buried_lift` on a flat column, a cave with a ledge and a dug-out column.
- [x] Suite: near-ring tests updated: a chunk two out has its collision parked; the body's own chunk takes
  every quadrant regardless of the budget; a peer's ring still takes a parked chunk a quadrant a step.
- [x] Suite green (63,286 assertions); playtest bot PASS on all steps.

**Measured** (local, 3 runs each, main and branch interleaved, `tools/check_playtest_budget.py`):

| Step | main median p95 | Phase 193 median p95 |
|---|---|---|
| walk | 15.4 ms | 12.6 ms |
| craft | 12.2 ms | 10.7 ms |
| fight | 5.6 ms | 5.2 ms |

Flight is unchanged: a fast flyer already kept collision only under the body (Phase 189).

**Implementation notes:**
- A ray that starts inside a run skips that run, as a physics ray does not report the shape it starts in.
- Fast flight keeps radius 0 (Phase 189). The dive guard covers the case the ring does not: a dive onto a
  chunk whose collision has not landed, or a step that tunnels through a thin trimesh.
