# What to reuse from Zylann's godot_voxel (Phase 249)

Reviewed: [Zylann/godot_voxel](https://github.com/Zylann/godot_voxel) at commit
`dfb0f81c7fd766f68d78715b2138f4e336cd9737` (2026-11-07), MIT licence, © 2016-2024 Marc Gilleron.
Read on 2026-11-11 against this repository at `c8c2f02` (Phase 238 merged, Phase 239 merged).

## Summary

| Part | Touches | Verdict |
|---|---|---|
| Transvoxel regular cells (marching cubes, Lengyel's tables) | 240, 241 | **Skip** as the mesher; Phase 240 keeps surface nets. Fallback if 240's closure tests fail on thin features. |
| Transvoxel corner-gradient normals and sample padding | 240, 241 | **Port the algorithm** in Phase 240 |
| Transvoxel transition cells (LOD seams) | 241, 243 | **Skip**: skirts and a cross-fade instead |
| LOD octree streaming | 243 | **Skip** |
| Clipbox LOD streaming: even-aligned boxes and the neighbouring rule | 243 | **Port the algorithm** in Phase 243 |
| LOD fading (`u_lod_fade`) | 243 | Already the plan; no code to take |
| Streaming and task scheduling (priority bands, cancellation, time-spread runner) | 239 | **Skip**: Phase 239 already covers it |
| Region files (sector table) and block compression | 244 | **Port the algorithm** (sector table) in Phase 244; compression from Godot, not LZ4 |
| Instancer (emission from mesh triangles, per-block seeding, persistence) | 247 | **Port the algorithm** (emission on the built mesh) in Phase 247 |
| SDF edit tools, mesh SDF, raycast, floating chunks | — | **Skip** |
| The engine as a whole (module or GDExtension) | all | **Skip** |

No code is adopted in this phase, so no third-party file enters the repository and no native class
changes. Four algorithms are ported later, each in the phase that builds the feature; those phases'
specs in `ROADMAP.md` now name what they take. A ported file carries the MIT notice and gets a row in
`native/THIRD_PARTY.md` (created by this phase with the reviewed commit).

## Why not the engine as a whole

- **Two editions, neither fits as is.** The module edition needs a custom Godot build; this project
  ships on the official 4.7 binary. The GDExtension edition runs on official Godot 4.4.1 or later, but
  its own docs call it less tested than the module, and its builds come from CI artifacts.
- **Another data model.** Its terrain stores voxels in `VoxelBuffer` channels (SDF, type, indices,
  weights) on cubic blocks. This project's truth is the run-based column model (`voxel_runs.gd`), the
  stable-world records (`ChunkRecords`, `frontier.gd`) and typed run edits validated by the host. Using
  the engine would mean converting runs to its buffers every build and keeping two sources of truth.
- **Another scheduler.** `VoxelEngine` runs its own thread pool. Phase 239 sizes the
  `WorkerThreadPool` cap by the queue; a second pool would fight that budget.
- **The parity rule.** Every native function here has a GDScript reference with a bit-exact parity
  test. Taking C++ from godot_voxel still needs that reference written, so the saving is in the design,
  not the typing. That is why the useful verdicts below are "port the algorithm".

## Transvoxel (`meshers/transvoxel/`)

**What it does.** Marching cubes over a signed distance field on a cubic block, using Eric Lengyel's
modified tables (no ambiguous-case holes, at most 5 triangles per cell). On blocks that border a
lower-detail neighbour it also builds *transition cells*, a thin strip of half-resolution cells that
stitches the two levels with no crack. Each border vertex carries a secondary position and border
masks; the vertex shader moves border vertices to make room for the transition strip only when a
neighbour is coarser (`u_transition_mask`), so a block need not be remeshed when its neighbour
changes level. Normals come from the SDF gradient at the cell corners (central differences,
`get_corner_gradient`), interpolated along the edge like the position. The block is sampled with one
voxel of padding below and two above (`MIN_PADDING`, `MAX_PADDING`) so the gradient and the
neighbouring cells are available at the border. Up to 4 materials per vertex (`MIXEL4` / `SINGLE_S4`)
are packed into custom attributes.

**Fit.**
- Deterministic and worker-safe: yes (pure function of the sampled block).
- Runs: works on any density, so it would run on the 0.5 m density Phase 240 samples from runs.
- Godot 4.7 / GDExtension / headless: the algorithm has no engine dependency.
- The tables are Lengyel's (1,081 lines), free to use with a credit line in the source.

**Verdicts.**
- **Regular cells as the mesher: skip.** Phase 240 needs the ground at the run's exact top
  (±0.125 m) and placed blocks cut out square. Surface nets put one vertex per cell, so pinning a
  vertex to the run top, downsampling for coarse chunks (Phase 241) and LOD rings (Phase 243) are
  direct, and the GDScript reference stays short with no 1,000-line tables to keep in parity.
  Marching cubes would put the same top height on vertical edges, but needs the tables in both
  GDScript and C++, makes about twice the triangles, and its strength (transition cells) is not used
  here (next point). **Fallback:** surface nets can make a non-manifold edge where one cell holds two
  sheets (a one-tile tunnel or a thin overhang). If Phase 240's closure test fails on those and a cell
  split does not fix it, switch the mesher to Lengyel's regular cells, credited as his licence asks.
- **Corner-gradient normals and padding: port the algorithm** (Phase 240). Normals from the density
  gradient, not from the triangles, are the same on both sides of a chunk border when both chunks
  sample the same density, so the shading has no seam without reading the neighbour's mesh. The block
  is sampled with one cell of padding below and two above on each axis that crosses a chunk, which
  also gives the surface-nets vertex its neighbouring cells.
- **Transition cells: skip.** They need the block's six neighbours to be either the same level or one
  level coarser at all times (the octree's 2:1 rule), the finer neighbour's samples on the shared face,
  a per-block uniform updated when any neighbour changes level, and the secondary-position attribute in
  every vertex. This project's chunks are full-height columns with four side neighbours, coarse chunks
  already use edge skirts (Phase 190) and the LOD rings are render-only, faded and hazed (Phase 243).
  Skirts cost nothing when a neighbour changes level. Revisit only if the skirts show from the air.
- **Material packing:** Phase 242 already specifies four ids and four weights per vertex
  (`CUSTOM0`/`CUSTOM1`), which matches `SINGLE_S4`. Nothing to take: the weights there come from
  biome, slope, altitude and wetness, not from voxels.

## LOD streaming (`terrain/variable_lod/`)

**What it does.** Two strategies decide which block of which level of detail exists around each
viewer. The *octree* one (older) keeps an octree per large region and splits nodes by distance. The
*clipbox* one (the default now) gives each level a box of blocks around the viewer:
`get_base_box_in_chunks` snaps the viewer's range to that level's block grid and rounds the box
outwards to even block coordinates; `get_minimal_box_for_parent_lod` halves the child box, pads it by
one block and rounds it to even again, and `enforce_neighboring_rule` grows the parent box to at least
that. So every level's box is aligned to the next level's grid (no partial parent block, no gap) and at
least one block of each level separates the levels on either side (no level n−1 touching n+1). Level 0
has its own distance; level k uses `(lod0_distance >> k) + lodn_distance`, and the last level stretches
to the view distance. All levels load in parallel; a level's mesh is shown when its box contains it and
the finer level has not covered it yet. `u_lod_fade` cross-fades a block when its level changes.

**Fit.** Pure integer box arithmetic, deterministic, independent of the data model. In this project
the boxes are 2D (chunks are full-height columns), render-only and client-only.

**Verdicts.**
- **Octree streaming: skip.** The engine itself moved to clipbox, and a planet surface with column
  chunks has no use for a vertical subdivision.
- **Clipbox: port the algorithm** (Phase 243). Phase 165's bands already nest square annuli on the
  world lattice; the LOD rings take the two rules the bands do not state for voxel rings: each ring's
  box is rounded outwards to even chunk coordinates of its own level (so the next ring's grid holds it
  exactly), and is grown to at least the finer ring's box halved and padded by one chunk (the
  neighbouring rule, so a ring never borders one two levels away). The distance per level follows the
  same formula, with the outer ring stretched to the view distance (Phase 225's option). Written as a
  pure GDScript policy with the MIT notice, like `chunk_stream_policy.gd`.
- **LOD fading:** the cross-fade Phase 243 asks for is the same idea (`visibility_range` fade,
  dithered). No code to take.
- **Detail rendering (`engine/detail_rendering/`, not in the phase's list):** bakes normal maps from
  the generator at higher resolution for far, coarse blocks. Skipped for now: it needs the generator on
  the GPU or many CPU samples per far block, and Phase 243 hides the far rings in haze. Worth a look if
  far ground looks flat after Phase 242.

## Streaming and task scheduling (`engine/`, `util/tasks/`)

**What it does.** One thread pool runs every task (generate, load, save, mesh). A task's priority is a
32-bit value of four 8-bit bands (`TaskPriority`), re-evaluated by a dependency object
(`priority_dependency`) as the viewer moves, so a block's priority follows its current distance and
level. A block that leaves the viewer's range sets a shared cancellation token, and the task drops
itself when it starts. Main-thread work (uploading meshes, physics shapes) goes through
`TimeSpreadTaskRunner` with a time budget per frame, and `ProgressiveTaskRunner` ramps the number of
tasks started per frame.

**Fit.** Deterministic enough; the scheduler is C++ engine code with its own pool.

**Verdict: skip.** Phase 239 has shipped the same ideas in this project's terms:
`chunk_stream_policy.gd` orders and leads the queue by distance and speed, the queue lives on the main
thread and is rebuilt on every refresh (so a chunk that leaves the window is never dispatched), the
worker cap adapts within [2, cores − 1], and `apply_finished_builds` stops at `ATTACH_BUDGET_MS` except
for the chunk under the body. Builds in flight are bounded by that cap, so a cancellation token would
save at most one build per worker. Nothing left to take.

## Region files and block compression (`streams/region/`, `streams/compressed_data.*`)

**What it does.** One binary file per region of blocks. The header holds the format (block size,
region size, channel depths, a 512-byte sector size) and a table with one 32-bit entry per block: a
24-bit sector index and an 8-bit sector count. Blocks are serialized, compressed (LZ4) and stored at
sector boundaries. A block that grows past its sectors is removed and appended at the end, and the
following blocks are shifted down so the file stays compact; one that shrinks frees sectors the same
way. A missing table entry means "not stored". A SQLite stream does the same per block in a database.

**Fit.** The format is independent of voxel content and safe on a worker (one file, one owner). This
project's `region_store.gd` stores edits and generation records as one JSON file per 32×32-chunk
region, and Phase 191's `chunk_cache.gd` keeps built arrays in memory only.

**Verdict: port the algorithm** (Phase 244). The disk cache holds up to 1,024 chunks per region; one
file per chunk means thousands of small files and a directory scan, and the JSON region file would be
rewritten whole per chunk. Phase 244 stores each cache layer as one binary file per region with a
sector table (24-bit index, 8-bit count, a fixed sector size), entries compressed with Godot's
`PackedByteArray.compress(FileAccess.COMPRESSION_ZSTD)` instead of LZ4 (no third-party compressor to
vendor, and it is the same on every platform). The key Phase 244 already specifies (worldgen version,
fingerprint, edit revision, mesher version) goes in each entry's own header, so a stale key is read as
a miss without touching the table. The authoritative `region_store` JSON files are not changed.

## Instancing (`terrain/instancing/`)

**What it does.** `VoxelInstancer` places grass, rocks and trees per mesh block. Its generator emits
candidate points from the block's built mesh (from vertices, from faces weighted by area, or one per
triangle), seeded by the block position, then filters them by density noise, slope and height and
offsets them along the normal. Items are listed in a library with a LOD level each, so grass exists
only on the finest blocks and trees on coarser ones; MultiMesh per block per item. Instances are
regenerated on every visit, except *persistent* items in edited blocks, which are saved.

**Fit.** Deterministic (block-seeded). Client-only rendering is possible. Emission depends on the mesh,
which here is a deterministic function of runs and seed.

**Verdict: port the algorithm** (Phase 247). The point that matters: placement reads the drawn
surface. With smooth ground (Phase 240) the drawn surface may sit up to 0.125 m from the run top, so a
tuft placed at the run height floats or sinks. Phase 247 keeps its pure (seed, tile) choice of whether
and what grows, and takes the height and normal from the chunk's built mesh at that point (the
triangle under the tile's jittered position), so cover sits on the ground the player sees. Grass
exists only on full-detail chunks (the library's per-item LOD), bushes also on the coarse ones. No
persistence: edits are runs, and a rebuilt chunk re-emits from its new mesh, which removes cover from
mined or built tiles.

## SDF edit tools (`edition/`)

**What it does.** `VoxelTool` edits the SDF: spheres, boxes, smooth add/remove, paths, painting
textures, mesh-to-SDF baking (`mesh_sdf`), raycasts, and splitting off floating chunks as rigid bodies.

**Fit.** All of it assumes density storage. Edits here are typed run edits on 0.5 m cells, validated
and rate-limited by the host (the trust boundary), replayed by `voxel_runs.gd`; `voxel_ray.gd` already
raycasts the runs.

**Verdict: skip.** A sphere brush is a run-edit shape the host would have to validate, which is game
design (fabric) work, not something to take from an engine. Floating chunks would need a run-level
connectivity pass and a physics object model the game does not have.

## Generators (`generators/`, not in the phase's list)

The graph generator (and its GPU path) compiles node graphs to fast native code. Skipped: world-gen
here is `WorldShape` and the fabric's tables, with a GDScript reference and native parity, and the
stable-world rule needs `WORLDGEN_VERSION` control the graph does not have.
