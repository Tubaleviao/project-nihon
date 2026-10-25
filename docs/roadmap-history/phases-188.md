# Roadmap history — Phase 188

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 188 — Mountain ranges, not plateaus: narrower ridges, a temperature tree line and a low spawn plain ✅ Done

**Goal:** a regenerated world is snow almost everywhere on some seeds, far from the poles and off any
peak. `WorldShape` has `RIDGE_CELLS = 320` cells around a 40,000 km planet, so one ridge is about
125 km wide. Inland, that is a plateau hundreds of kilometres across at 300–500 m. `Alpine` is picked at
any temperature above 250 m, so the whole plateau is snow. The spawn plain is the mean height of its
4 km rim, so it sits on the plateau too. Over a 16 km square around spawn, seeds 42 and 1234 are 100%
Alpine (spawn plains of 297 m and 512 m), and six other seeds are 0%. `/regen world` keeps the seed and
reruns the same generator, so it gives the same snow.

**Newel dependency:** NO (the biome envelopes are fabric data; the change is to their values).

**Depends on:** Phase 51 (climate envelopes), worldgen 9 (spawn plain).

**Deliverables:**
- Ridges become ranges: ridge wavelength in the tens of kilometres, not 125 km. Retune
  `RIDGE_CELLS` (and the second octave), so peaks are thin lines with valleys between them.
- `Alpine` is chosen by temperature (the altitude lapse already cools high ground), not by a fixed
  250 m floor at every latitude. Change the envelope in `fabric/world/biomes/earth.js` and regenerate.
- The spawn plain is capped below the tree line, so a new player never spawns on snow outside the polar
  cap.
- `TerrainSlice.WORLDGEN_VERSION` bump, a history line, and new `_test_worldgen_golden` values.

**Acceptance criteria:**
- [x] Suite: over a 16 km square around spawn, every one of 8 fixed seeds is under 15% Alpine on land,
  and every spawn plain is below the Alpine floor.
- [x] Suite: mountains still exist: on each seed, some land within 100 km of spawn is above 250 m.
- [x] Suite: worldgen golden values updated, and the version history names the change.
- [x] Playtest bot green on the pinned seed (re-check every step, since the pin's world changes).
- [x] `npm run validate` and `npm run check-drift` clean.

**As built:**
- `WorldShape.RIDGE_CELLS` 320 → 1,600 (25 km, second octave 8.3 km), and the crest profile is
  `(1 - |2n - 1|)^RIDGE_SHARPNESS` with sharpness 10 (was a square). Narrowing alone was not enough: the
  two-octave noise clusters near 0.5, so the square kept 85% of the land within 100 km of seed 42's spawn
  above 250 m; with the sharper crest valleys sit at 140–170 m and peaks still reach 512 m. The native
  builder mirrors both (native version 6, `NativeBuilder.REQUIRED_VERSION` 6).
- `Alpine` is `temperature { 0, 0.15 }` above a 200 m floor (`ALPINE_FLOOR`); `Tundra` is the cold ground
  below the floor; every other land biome reaches 1,000 m (was 250 m), so warm high ground keeps its forest
  or grassland. The tree line therefore falls toward the poles; equatorial peaks are rarely snow.
- `WorldShape.SPAWN_PLAIN_MAX` = 150 m caps the spawn plain below the Alpine floor (`SpawnFinder` already
  never picks Alpine).
- Worldgen 10. Seeds 42, 1234 and 2045165241 go from 100% Alpine around spawn to 0.6–1.1% (probe), and
  their plains from 297/512/380 m to 150 m.
- Tests (`terrain_tests.gd`): `worldgen: little Alpine around spawn, plain below the floor` and
  `worldgen: mountain ranges near spawn, with valleys` over `RANGE_SEEDS` (42, 1234, 2045165241, 9, 26, 31,
  57, 132: continental spawns; ocean-spawn seeds have no land in reach to hold a mountain). The range test
  also requires a 150 m drop within 8 km of the highest sample, which fails on the worldgen 9 ridges.
  The pole/peak climate test now reads a 450 m peak at 70 degrees as Alpine and cold ground under the floor
  as Tundra; the plain test uses seed 31 (rim ~114 m) and checks 2045165241 meets the cap.
- Playtest bot green on the pinned seed 42 (far_peak: a 342 m ridge at 60 km).
