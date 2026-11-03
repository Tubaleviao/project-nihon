# Roadmap history — Phase 211

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 211 — Earth-scale mountains: peaks to about 8,850 m on unrecorded land ✅ Done

**Goal:** the generator makes mountain ranges as tall as Earth's, and the client draws, streams and
collides with them.

**Newel dependency:** NO.

**Depends on:** Phase 203.

**Deliverables:**
- The ridge and height fields reach the new `maxHeight`, and the build ceiling is read from the
  Phase 203 set the fabric's `maxHeight` to 8,850 m and `buildCeiling` to 9,400 m;
  `WorldShape.PEAK_HOLD` keeps the generator at 512 m until this phase removes it.
  fabric. `TerrainSlice.WORLDGEN_VERSION` is bumped with a history line, and the golden values are
  updated. Vertical precision is checked: the voxel mesh group key stores y × 10⁴ in an int32 (good
  to about 214 km), and float32 keeps 0.125 m steps exact far past 10 km.
- Stable-world rule: recorded chunks keep their heights. New peaks rise only on unrecorded land,
  eased in by `frontier.gd` beside recorded land. Existing worlds keep their 512 m mountains where
  players have been.
- The distant ring, the horizon bands (Phase 165), the camera far plane and coarse chunks (Phase
  190) draw an 8 km peak without holes or popping. The climate cools with altitude where it does
  not already.

**Acceptance criteria:**
- [x] Suite: on the pinned seed, the highest sampled surface is within 5% of `maxHeight`, and none
  exceeds it.
- [x] Suite: a recorded chunk's heights are unchanged across the version bump.
- [x] Suite: a placement at the build ceiling succeeds and one above it is refused.
- [x] Playtest: `far_peak` reaches a peak above 8,000 m with no holes in its screenshot, and
  walk/craft/fight stay within budget.
- [x] Suite green on both boot paths, harness green.

**Shipped:**
- `WorldShape` no longer holds the fabric's `maxHeight` at 512 m (`PEAK_HOLD` is gone). Height now comes
  from broad massifs (`WorldShape.massif`): a 156 km lattice (256 cells) whose nodes above `MASSIF_FLOOR`
  0.8 lift rugged inland ground into plateaus. The uplift is `massif_amplitude()`, what is left of
  `maxHeight` above the spline's top and the summit ridges. Ridges grow to `MASSIF_RIDGE_GAIN` (2×)
  `ridgeAmplitude` on a full massif, so a crest there meets `maxHeight` exactly. An 8 km ridge with the
  Phase 188 crest profile would have been a needle; a summit's 2 km flank on the pinned seed is a 0.35
  slope. No massif rises within 100 km of the spawn centre (full strength from 200 km), so the origin stays
  lowland for every seed, as the spawn plain does. The climate already cooled with altitude
  (`LAPSE_PER_M`), so massifs are Alpine.
- `TerrainSlice.WORLDGEN_VERSION` is 11, with a history line and golden values on a summit. The native
  builder mirrors the massif (`native_chunk_builder.cpp`, `massif_amplitude` passed in the config,
  version 8, and `NativeBuilder.REQUIRED_VERSION` 8).
- Stable-world rule: a chunk recorded by a worldgen-10 world on what is now a summit keeps its recorded
  corners and biome. Only unrecorded land rises.
- The build ceiling is the fabric's `buildCeiling` (9,400 m): `WorldShape.build_ceiling()`,
  `VoxelConsts.build_ceiling()` and `VoxelSlice.build_ceiling()`, read by placement and settling
  (`voxel_edit.gd`). `VoxelConsts.MAX_HEIGHT` is its 9,400 m fallback. The face-group key is y × 10⁴ in an
  int32, 9.4e7 at the ceiling.
- The horizon bands reach 340 km (the horizon of an 8,850 m peak), which takes five bands:
  `DistantBands.VERTEX_BUDGET` is 160,000 (129,720 at the default view). The camera's far plane follows
  them as before. At most `MAX_RUNNING_BUILDS` (2) band builds hold workers at once, round-robin from the band
  after the last one started (inner bands first at boot). With all five started together, the harness
  client's first ring went unbuilt for 15 s (`snapshot_complete` incomplete) on a small machine. A band also takes each shape
  sample once: a vertex's 3 × 3 samples lie on a half-cell lattice its neighbours share, so a band costs
  about 4 samples a vertex instead of 9, with the same heights (2.6 s instead of 5.0 s for one band here).
  Five bands now cost less than the three did.
- `WorldShape.massif_summits` (the strongest summit nodes on the planet) and `highest_near` (the crest
  around one). The playtest's `far_peak` uses them instead of searching the 2,000 km around the body: it
  finds a crest of at least 8,000 m and stands on lowland (under 2,000 m) 150 km from it. A new
  `PlaytestBot.hole_pixels` counts key-colour pixels between the frame's skyline and the ring's, and the
  step needs none. Locally it passed on try 1: a ridge of 8,723 m at 150 km, 7,476 rock/snow pixels, 0 holes.
- Suite: `Phase 211:` tests in `terrain_tests.gd` (peaks within 5% of `maxHeight` and never above it, and
  the recorded chunk), the build-ceiling placement in `voxel_tests.gd`, and the hole reader and 340 km
  radius in `bands_tests.gd`.
