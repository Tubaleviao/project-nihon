# Roadmap history — Phase 240

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 240 — Smooth natural ground ✅ Done

Natural ground is meshed as stepped columns: each 0.5 m tile's runs become flat tops and vertical
walls at 0.125 m steps (`voxel_mesh.gd`). The runs already carry overhangs, caves and a material per
run. Placed blocks are runs too, with a non-empty material and an entry in the structure index.

- A surface-nets mesher in GDScript as the reference (`src/terrain/voxel_smooth.gd`), pure and safe on
  a worker, like `voxel_mesh.gd`. The density is sampled on a 0.5 m grid (tiles in XZ, 0.5 m in Y)
  from the resolved runs. A vertex's height on a column top comes from the run's exact top, so the
  ground stands where the runs say it does (±0.125 m), not on the grid.
- **Normals from the density** (Phase 249, ported from godot_voxel's Transvoxel, MIT notice in the
  file and a row in `native/THIRD_PARTY.md`): each cell corner's normal is the central-difference
  gradient of the density, interpolated to the vertex, not the average of the triangles. The chunk is
  sampled with one cell of padding below and two above on X and Z, so both chunks at a border compute
  the same normals and the shading has no seam. If the closure test fails on a one-tile tunnel or a
  thin overhang (surface nets give one vertex where a cell holds two sheets) and splitting that cell
  does not fix it, the mesher becomes Lengyel's Transvoxel regular cells, credited as his licence asks
  (see `docs/research/godot-voxel.md`).
- **Natural runs only.** A placed block (a run with a structure entry) is still meshed by the block
  mesher, in the same chunk, so walls, floors and roofs stay square. Where natural ground meets a
  placed block, the smooth surface stops at the block's faces with no gap.
- **Collision** is the same triangles (one shape per chunk, as today). On smooth slopes the body walks
  by `floor_max_angle`. The step-up probe stays for placed blocks. The dive guard and buried-lift
  rescue keep reading the runs, which have not changed.
- **Edits** still change 0.5 m cells. A mined pit shows rounded edges.
- Behind a project setting (`terrain/smooth_mesh`, on by default) until Phase 241. The block mesher
  stays for placed blocks and for tests.
- No world-gen change: runs, records and saves are untouched, so `WORLDGEN_VERSION` stays.

**Acceptance criteria**
- Suite tests on the mesher: a flat column gives a flat surface at the run's top. A 45° ramp of runs
  gives normals within 5° of the ramp. An overhang and a one-tile tunnel give a closed surface (every
  edge shared by exactly two triangles inside the chunk). Two neighbouring chunks share their border
  vertices exactly (no crack).
- A suite test: on 1,000 random natural tiles of the pinned seed, the mesh height above the tile's
  centre is within 0.125 m of the column's top run.
- A suite test builds a chunk with a 3×3 placed wall on natural ground: the wall's faces are the block
  mesher's, axis-aligned, and the ground around it is smooth.
- A suite test walks a body up a 30° natural slope with no step-up lift, and onto a placed block with
  one.
- The playtest walk, mine, place and tower steps pass.

**Outcome**
- `src/terrain/voxel_smooth.gd`: surface nets over the natural runs. The density is sampled at tile
  centres (so a one-tile tunnel or wall keeps a sample of its own) and is the clamped signed vertical
  distance to the column's nearest boundary, with a run's bottom counted inside and its top outside, so
  any 0.5 m slab or gap holds a sample wherever it sits. A quad across a vertical edge is a fan around
  a vertex at the column's centre and the run's exact top, so the ground stands exactly on the runs.
  Normals are the corner gradients interpolated to the vertex (godot_voxel's Transvoxel method, MIT
  notice in the file, row in `native/THIRD_PARTY.md`). No cell split or Transvoxel fallback was needed:
  the tunnel and overhang closure test passed.
- Placed runs (a material) are air to the density and meshed by `VoxelMesh.build_chunk_arrays_gd(...,
  placed_only = true)`: their walls subtract only placed neighbours and hang 0.5 m into natural ground
  under them, so no gap shows under a block's face.
- `build_runs` (GDScript and native) resolves a two-tile ring when the gathered input carries `pad` 2,
  which `VoxelMesh.terrain_pad()` sets while the smooth mesher is on.
- The step-up climbs only placed blocks on smooth ground (`src/player/step_up_gate.gd`); slopes are
  walked by `floor_max_angle`.
- Pulled forward from Phase 241: the native port (`NativeChunkBuilder.build_smooth_arrays`, native
  version 10) with an exact parity test on 24 chunks. The GDScript mesher took about 165 ms a chunk
  against the native block mesher's 8; the native one takes about 13.
- Behind `terrain/smooth_mesh` (on in `project.godot`). `VoxelMesh.build_chunk_arrays` stays the block
  mesher for the suite's seam and parity tests; the game builds through `build_terrain_arrays`.

