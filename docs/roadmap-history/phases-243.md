# Roadmap history — Phase 243

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 243 — Level of detail past the window ✅ Done

Past the 9×9 window, the distant ring (Phases 51, 164) and the bands (Phase 165) draw only
`WorldShape`, with no detail noise, records or edits. A flyer sees the near ground pop in, and the far
ground does not match it.

- **LOD rings** between the window and the distant ring: rings of chunks meshed with the smooth mesher
  on a downsampled density (4×, 8×, 16× cells), in the clipmap style of Phase 165. Each ring's cell
  doubles, so the cost per ring stays about flat. They use the same heights the full chunks use (detail
  noise, records, and edits summarised to the cell). The distant ring's hole grows to the outer LOD
  ring.
- **Ring boxes** (Phase 249, ported from godot_voxel's clipbox streaming, MIT notice in the file and a
  row in `native/THIRD_PARTY.md`): a pure policy gives each ring a box of its own chunks around the
  viewer, rounded outwards to even coordinates so the next ring's grid holds it exactly, and grown to
  at least the finer ring's box halved and padded by one chunk, so a ring never borders one two levels
  away. Ring k reaches `(ring-0 distance >> k) + ring-n distance` of its own chunks, and the outer ring
  stretches to the view distance.
- **No pop:** a chunk changing level cross-fades (`visibility_range` fade, dithered) instead of
  swapping in one frame. The same fade applies to the window's coarse-to-full upgrade.
- **Haze hides the edge:** the clear-weather fog density is derived from the outer LOD radius, so the
  last LOD ring is mostly hazed. Weather still thickens it (Phase 128).
- **Render only** (no collision), and nothing on the headless server.
- The view-distance option (Phase 225) sets how many LOD rings a client draws.

**Acceptance criteria**
- A suite test builds an LOD-ring chunk and the full chunk at the same place: heights agree within the
  ring's cell size, and an edited tile's summary shows in the LOD mesh.
- A suite test: rings nest with no overlap and no gap, and the ring border has a skirt.
- A suite test on the haze function: fog reaches at least 90% at the outer LOD radius on clear weather.
- The playtest `horizon` and `far_peak` steps pass. The `flight` step meets its budgets.

**Implementation notes**
- Policy: `src/terrain/lod_ring_policy.gd` (pure, the clipbox port with its MIT notice). Level k ≥ 1 draws
  chunks of `32·2^k` m, each `CELLS` = 16 columns a side, so cells are 4, 8, 16, 32, 64 m. Every box is
  rounded out to even coordinates of its level, grown to the finer box halved and padded by one chunk,
  and made square (the shorter side grows by the even difference) so the distant ring's square hole
  fits it. Level 0 is the 9×9 window (`WINDOW_RADIUS` 4). Ring k ≥ 2 skips whole chunks inside box k−1.
  Ring 1 draws every chunk of box 1, and its material's `lod_hole` uniform (the window in scene metres,
  edges included) discards the part under the window in the terrain shaders, so the ring-1 set does not
  follow the window's chunk-by-chunk moves. A plan is kept while every level still has one chunk of
  slack (`still_holds`), so a viewer pacing over a chunk border does not re-plan (the first playtest
  run churned at a border and never completed a set).
- Build: `src/terrain/voxel_lod.gd`. Each cell stands at `DistantTerrain.ground_at` at its middle (the
  shape or the chunk's record from a `ChunkRecords` snapshot, the detail noise, the polar ice and the
  lake surfaces), quantised like a full chunk's columns. An edited tile the client holds raises its cell
  to the tile's top. The columns are meshed by the coarse path of the surface-nets mesher with a cell
  count of its own (`VoxelSmooth.mesh_lod_columns`), skirted to bedrock on every edge, with no collision.
  Terrain weights are per vertex (`TerrainWeights.apply_at`, the biome blend at the vertex's own place,
  no wetness). Biomes are read only for the level-0 chunks a cell or a vertex lies in. A ring sits a
  quarter of its cell below the ground, so the finer level's skirts always close the crack between
  levels from above. GDScript only, on a worker: about 20–25 ms a chunk at levels 1–3 and 75 ms at
  level 5.
- Node: `src/terrain/lod_terrain.gd`, created beside `DistantTerrain` on every non-server role (never on
  the headless server), with its own rebase and fold reset. It builds at most 2 chunks at once, inner
  rings and nearest chunks first, and attaches through `ChunkSurface`. It starts nothing while the window
  still has chunks to load or build (`LodTerrain.follow`). After a move, the old set keeps drawing
  until the new one is complete, then the two cross-fade. The distant ring's hole is the outer box of
  the set drawn now (`rebuild(..., hole)`). The ring's square grows to `LOD_HOLE_MARGIN` (1.25) times the hole only when the hole needs it, so its polar rings and the bands keep their shape. Until the first set is complete it stays the window, so the
  ground in between never shows the sky.
- Fade: `src/terrain/lod_fade.gd`, an `instance uniform float lod_fade` in the high terrain shader,
  dithered by interleaved gradient noise. 0..1 fades in and 2..3 fades out, and the two patterns are
  complementary at the same progress. The window's coarse-to-full upgrade hands its old surface to the
  same fade (`VoxelBuild.lod_fade`). The low shader (the Compatibility renderer's default, and CI's
  opengl3 playtest) declares no instance uniform, so it swaps at once. A time-driven dither replaces the
  spec's `visibility_range` fade, because a distance range cannot follow a box-shaped level boundary.
- Haze: `WeatherWiring.haze_density_for(rings)` is `−ln(0.1) / outer radius`, so clear fog is 90% at
  the outer LOD radius. Weather multiplies it as before. With no rings it falls back to the old
  `HAZE_DENSITY`. The horizon test's "rain leaves 2 km in view" became "1 km" (a 20% share): with 5
  rings the clear haze is about 3.7× the old one.
- Setting: `nihon/graphics/lod_rings` (default 5, so the outer radius is 4,096 m; 0 turns the rings off).
  Phase 225 puts it in the options window as the view distance.
- Tests (`lod_rings_tests.gd`): heights against the full chunks (mean error within the cell, at levels 1
  and 2), an edited tile's tower, the boxes (even, square, the neighbouring rule, reach), nesting with
  every point drawn exactly once, skirts to bedrock and weights on every vertex, the haze at the outer
  radius for 1–6 rings, the cross-fade, and the node's queue and holes.
- Playtest: the LOD chunks are also drawn on their own render layer (`LodTerrain.RENDER_LAYER`, 1 << 18).
  `far_peak` keeps its ring and ring+bands captures, and counts the ring's holes on a third capture that
  includes the LOD rings. The bot does not wait for the LOD set: the distant ring keeps the window's hole
  until a set is complete, so no hole shows either way. An early version waited, the bot idled minutes at
  the vantage, and the capture lost the ridge.
- `ChunkSurface` clears its RIDs on `PREDELETE`. A surface freed while still in the tree gets `EXIT_TREE`
  after that and used to call the RenderingServer on a freed instance (an error per freed LOD chunk).
