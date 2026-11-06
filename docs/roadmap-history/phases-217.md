# Roadmap history — Phase 217

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 217 — Lakes and rivers on unrecorded land (static water, no flow) ✅ Done

**Goal:** fresh water above sea level, the first half of the Deferred "Rivers, lakes and fluid flow"
item. Today the only water is the ocean at `WorldSystem.seaLevel`. This phase generates lakes in
basins and rivers down valleys on unrecorded land only, as static water; flow (a cellular automaton)
stays deferred.

**Newel dependency:** NO.

**Deliverables:**
- Fabric: `WorldSystem` (or a new `Hydrology` entity) parameters for lake frequency, minimum basin
  depth, river source height, river width by catchment and the biomes rivers cannot cross, with a
  validator and `tools/check_hydrology.js`.
- `src/terrain/`: a deterministic hydrology field (per region, from the seed) that marks lake
  surfaces and river beds; world-gen carves beds and fills them with water voxels at the lake/river
  surface height. Rivers run downhill to a lake or the sea and never climb.
- The stable-world rule holds: recorded chunks never change, and a river reaching a recorded chunk
  ends at its edge (the frontier, `src/terrain/frontier.gd`, closes it in its blend). Bump
  `TerrainSlice.WORLDGEN_VERSION`, add the history line, update `_test_worldgen_golden`.
- The player's swim/underwater state and the creature path cost treat fresh water like sea water.
- The distant terrain ring draws lake and river surfaces.

**Acceptance criteria:**
- [x] `npm run validate` and `node tools/check_hydrology.js` pass; the checker rejects each bad fixture.
- [x] Suite: on the pinned seed, a sampled 64×64-chunk area holds at least one lake and one river;
  each river cell's surface is at or below its upstream neighbour's.
- [x] Suite: the hydrology field is deterministic (same seed and region → same cells, twice, and
  on a worker thread).
- [x] Suite: a recorded chunk's voxels are byte-identical before and after the version bump, and no
  water voxel is generated inside a recorded chunk.
- [x] Suite: a player standing in a lake reports the swimming state; a creature path avoids a river
  wider than its crossing limit.
- [x] Suite green on both boot paths, harness green; `--playtest-bot` walk, stream and flight steps
  still pass.

**Built:** `src/terrain/hydrology.gd` (pure, seed-deterministic, cached; fabric fields on `WorldSystem`,
validated by `fabric/world/hydrology.js`, `tools/check_hydrology.js`). Lakes are discs in 512 m cells whose
surface is the lowest of the shape at the centre and eight rim points; rivers trace the shape's steepest
descent in 64 m steps from 1,024 m source cells, their surface the running minimum, widening with catchment,
ending at the sea, a blocked biome or in a pond. The spawn plain (1,500 m) stays dry. `WORLDGEN_VERSION` 12:
a chunk takes part when it has no record or a record of version 12 or later, so earlier records stay dry.
Beds are carved in `heightmap_for` (both paths) and `get_height_at`; `VoxelSlice.fresh_water_mesh_for` draws
the surfaces; `PlayerSlice.water_level_at` and the creature path's `fresh_water` rule treat fresh water as
water; the distant ring draws the flat surface. Rivers do not yet have a width-based crossing limit: a
non-swimmer treats every river as water.

