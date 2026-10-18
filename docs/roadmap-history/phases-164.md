# Roadmap history — Phase 164

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 164 — A round horizon: a circular distant ring, planet curvature and haze

**Goal:** a playtest showed four "mountains" on the horizon of the flat spawn plain. They are the
corners of the Phase 51 distant ring: it is a square (`RING_FACTOR` × the voxel window, about 1.1 km
half-extent at the default view distance), so its outer edge is about 1.4 times farther at a corner
than at a side, and from eye height the farther edge sits closer to the eye line and reads as a peak.
Past the edge the sky colour (`BG_COLOR`) fills the gap. The world is a planet, so the horizon should
be a level circle where the curved ground drops out of sight, with no mesh edge anywhere in view.
This phase makes the ring round, bends it with the planet and fades the distance into a haze that
matches the sky at the horizon. It changes rendering only: no world-gen output, no collision, no
server work.

**Newel dependency:** NO.

**Depends on:** Phase 51 (distant ring), Phase 63 (scene rebase), Phase 120 (ring build lifecycle).

**Deliverables:**
- `src/terrain/horizon.gd` (new, pure static): planet radius from `circumference_m` (R = C / 2π,
  about 6,366 km), `curvature_drop(d)` = d² / 2R, `horizon_distance(eye_h)` = √(2R·eye_h + eye_h²),
  and `visible_over_horizon(eye_h, target_h, d)` (a target of height h is in view while
  d < horizon_distance(eye_h) + horizon_distance(h)). Used by the ring, the suite and Phase 165.
- `src/terrain/distant_terrain.gd` — the lattice becomes polar: rings of cells whose radial step
  grows with distance from the centre, out to an outer RADIUS (a circle), with the square voxel
  window still cut out exactly as today (clipped strips and skirt kept). The outer radius is at
  least the horizon distance for the camera's eye height, so the silhouette is always the curved
  ground, never the mesh edge. Vertex count stays within today's budget (≤ 1.5 × the current mesh).
- Ring material: a `ShaderMaterial` that lowers each vertex by `curvature_drop` of its horizontal
  distance to the camera (vertex shader, so the ring needs no rebuild when the camera moves), with
  vertex colours as today. The voxel window is not bent: at its edge (≈ 112 m) the drop is ≈ 1 mm.
- `src/core/game_root.gd` — the environment switches from a flat `BG_COLOR` to a sky
  (`ProceduralSkyMaterial` or a small sky shader) whose horizon and ground colours equal the haze
  colour, plus depth fog with aerial perspective so the far ring fades into that colour. The weather
  (`weather_wiring.gd`) keeps driving fog density on top of a clear-weather base, and the day/night
  sun keeps driving the sky and haze colours together so they never disagree.
- `src/player/player_slice.gd` — the camera's `far` is set from the ring's outer radius (with a
  margin) instead of Godot's 4,000 m default.

**Acceptance criteria:**
- [x] Suite: `horizon.gd` — `curvature_drop` at 1 km, 10 km and 100 km and `horizon_distance` at
  1.7 m, 10 m and 500 m match the closed forms for the default circumference, and the
  `visible_over_horizon` boundary sits where the two distances sum.
- [x] Suite: a built ring's outer silhouette is a circle: the horizontal distance of every outermost
  vertex from the ring centre is within one outer cell of the radius in every direction (the four
  corners of the old square are gone), and no vertex lies beyond it.
- [x] Suite: the outer radius is at least `horizon_distance` for the player's eye height at the
  default and the maximum camera distance, and the camera's `far` is at least that radius.
- [x] Suite: the ring still leaves the voxel window's hole exact (the existing clip and skirt tests
  pass on the polar lattice), carries no collision body, and the vertex count is within budget.
- [x] Suite: the ring shader's drop equals `curvature_drop` (the shader constant is read from
  `horizon.gd`, not duplicated), and the sky's horizon colour equals the fog colour at noon, dusk
  and night.
- [x] Playtest bot: a `horizon` step faces open sea from the nearest coast in four headings and
  finds the skyline (the first non-sky row per column) flat to within 2 px across the frame.
- [x] Suite green on both boot paths, harness green.

**Implementation notes:**
- The square lattice of Phase 51 is kept unchanged as the inner part (its vertices, clipped strips
  and skirt hash exactly as before); the polar part is appended around it. Its ring 0 is the square's
  own boundary row (corners included, same heights), and every polar ring has a vertex on each ray
  through a boundary vertex, so the two meet without a crack and no cell cuts a square corner.
- Polar vertices are shared between cells (smooth normals), so 36 rings out to ≈ 20 km cost
  37 × 256 vertices: the fixture ring is 29,380 vertices against a budget of 29,862.
- The outer radius is `max(1.1 × horizon_distance(EYE_HEIGHT_MAX = 26 m), 1.25 × corner)`; the
  camera's eye peaks at ≈ 25.2 m (24 m zoom at −75° pitch, plus the 2 m pivot).
- Recorded chunks are snapshotted for the square only (as before); polar cells beyond it read the
  plain shape, as `DistantTerrain` already does for unrecorded land.
- The playtest `horizon` step searches outward from the body for land from which nothing rises
  above the sea horizon across the four headings' frames, then draws only the ring
  (`RING_RENDER_LAYER`) over a key colour and reads the first non-key row per column.
