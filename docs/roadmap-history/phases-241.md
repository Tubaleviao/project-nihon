# Roadmap history — Phase 241

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 241 — The native smooth mesher, and coarse chunks built smooth ✅ Done

- The native port of `voxel_smooth.gd` (`build_smooth_arrays`, native version 10) landed with Phase 240,
  because the GDScript mesher alone (about 165 ms a chunk) could not hold CI's stream-rate and
  slow-machine flight gates. Phase 240's parity test covers 24 chunks; this phase widens it to 50.
- Coarse builds (Phase 190, `voxel_coarse.gd`) run the same mesher on a downsampled density (2× and
  4× cells), with the edge skirts kept.
- Remove the `terrain/smooth_mesh` setting: smooth is the only natural-ground mesher.

**Acceptance criteria**
- A native parity suite test (as in `native_tests.gd`): GDScript and native give identical vertex,
  normal and index arrays for 50 chunks of the pinned seed, including edited chunks and chunks with
  placed blocks.
- A suite test: a coarse chunk next to a full one leaves no visible gap (the skirt covers the border
  height difference).
- The playtest `flight` and `stream` steps meet their budgets with the native mesher (worker ms per
  crossing no worse than the Phase 190 floor).

**Outcome**
- One surface-nets mesher for every natural-ground build. `VoxelSmooth._Mesher` (and the native
  `Smooth` class) take a step: the grid has `64 / step` columns a side, `0.5 × step` m apart, levels
  `0.5 × step` m apart and the density clamp scaled with them. A full build is step 1 and is unchanged
  (the 50-chunk parity holds against the same reference).
- Coarse builds (`VoxelCoarse.build_coarse_arrays`, native `build_coarse_arrays`) keep Phase 190's
  columns (a cell's highest tile, its biome colours) and mesh them with
  `VoxelSmooth.mesh_coarse_columns` / native `mesh_coarse_columns`, in place of the greedy column
  mesher. The padding repeats the edge columns, so the ground runs flat to the chunk's edge plane.
- Conservative coarse ground (review fix): the coarse mesher pins each shared vertex to its cell corner,
  as high as the tallest of the four cells round it, at every level. A cell's ground is then a fan from
  its own top up to its corners, never under any of its tiles, so a body on coarse collision is never
  inside the true ground when the chunk upgrades (plain surface nets averaged the corners and dipped up to
  several metres under a cliff-edge tile). A cliff's upright quads collapse onto the corners and are
  dropped. The edge-plane bookkeeping is kept for coarse builds only.
- Skirts: every triangle edge lying along an edge plane drops a quad from the edge to bedrock, facing
  out. The edge's ends stand on corners as high as the tallest column round them, so a full neighbour's
  ground at the plane is never above the skirt and no fin rises above the ground.
- `terrain/smooth_mesh`, `VoxelSmooth.enabled()` and `set_enabled()` are gone. The block mesher stays
  for placed blocks and for the suite's wall-plane tests, which call `VoxelMesh.build_chunk_arrays`
  directly.
- Native version 12 (required by the loader).
- Review pass (PR #613): a full chunk east or south of a coarse one owns no wall on that edge, and its
  smooth border vertex blends its first tile with the coarse side's, so it could stand above the coarse
  corner and leave a slit under its edge. The coarse build now gathers the ring's maps (known ones by
  reference, one-tile seam strips on the worker for the rest) and `VoxelCoarse.edge_tops` caps every
  corner on the edge plane at the neighbours' edge tiles beside it. A coarse cell has one vertex for all
  levels and no side quads (they had no area), so `quad_count` and `skirt_quads` count only quads with
  triangles, and `_tri` lost its per-triangle position check. `VoxelMesh.terrain_pad()` is pure again;
  `VoxelSlice._ready` warms `VoxelSmooth` itself. New test `lod: a coarse skirt reaches a smooth full
  neighbour's border ground` (fails without the cap).
- Tests: `smooth ground: native parity` covers 50 builds (25 land chunks of the pinned seed, each
  plain and with a tunnel, a pit and placed blocks). The Phase 190 coarse tests were rewritten for
  triangle meshes: the height over every tile centre (none under that tile's true top, the mean none over
  0.5 / 1.0 m above it, no hole), and the seam closure for full | coarse 32, coarse 32 | full,
  full | coarse 16 and coarse 32 | coarse 16 on four probe seams.
- Measured locally (xvfb playtest with budgets, exit 0): `stream` 38.7 chunks/s with the native
  builder; `flight` at 270 m/s had the ground under the body built in 100% of 42 samples, and the
  worker spent 16 ms per crossing against 71 ms with coarse chunks off (the Phase 190 floor is a
  third, 23.7 ms). CI gates the median of three runs.
- CI fix (playtest flight gate): the review's coarse seam strips were sampled in GDScript, eight per
  coarse chunk, and pushed the flight step's worker time to 21.5 ms per crossing on CI, over the
  21.1 ms floor (locally 29.7 ms against 25.4 ms). `TerrainSlice.heightmap_strip_for` now runs in C++
  (`NativeChunkBuilder.heightmap_strip_for`, native version 13; the GDScript body stays as
  `heightmap_strip_for_gd`, the reference). New test `native: heightmap_strip_for matches the GDScript
  reference on every side and depth`. Measured locally, three flight-only runs: worker 21.8 ms per
  crossing against a 23.7 ms floor.
