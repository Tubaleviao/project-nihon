# Roadmap history — Phase 190

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 190 — Fast flight III: coarse chunks beyond the near ring ✅ Done

**Goal:** every chunk in the 9×9 window is built at full detail (64×64 tiles of 0.5 m), while the
player reaches only the 3×3 around them. Build the outer rings coarser, so a crossing costs a fraction of
nine full builds and a slow machine keeps up.

**Newel dependency:** NO.

**Depends on:** Phase 189.

**Deliverables:**
- A level of detail per ring: full detail within Chebyshev 1, and coarser render-only meshes (32×32,
  then 16×16 tiles) beyond. A chunk is upgraded when it enters the near ring and downgraded lazily.
- The native builder and the GDScript reference both build the coarse levels, with equal output.
- Seams between levels are closed (skirts or stitched edges), so no gap shows between rings.

**Acceptance criteria:**
- [x] Suite: native and GDScript coarse builds are equal on the fixed chunk set (`native_tests`: `build_coarse_arrays matches …`, both levels, absolute and local, a ring missing a biome).
- [x] Suite: a coarse chunk's mean height matches the full chunk's within a tolerance, and no seam
  between levels leaves a gap (edge heights shared or skirted) (`terrain_lod_tests`: mean within 0.5 m at
  32×32 and 1 m at 16×16 and never below; full|coarse and coarse|coarse seams checked at every tile, and
  the check fails on a min-height mutant).
- [x] Playtest bot (CI): worker ms per crossing at 90 m/s at most a third of Phase 189's (record flight in
  the same run with every chunk full; local median 10.8 vs 116.7 ms).
- [x] Suite green on both boot paths.

**As built:**
- `src/terrain/voxel_coarse.gd` (GDScript reference) and `native/src/native_coarse.cpp` + `coarse_columns` in
  `native_runs.cpp` (native version 7). A cell of `step`×`step` tiles stands at the highest of its tiles'
  natural tops, so coarse ground never dips under the true surface; its edge cells read outside as unknown
  and skirt down to bedrock. A full neighbour's walls cover what is above the coarse side's true edge and the
  skirt covers the rest, so seams close whatever order levels are built in.
- Coarse colours are the cell tile's biome: host rock (iced) and the shown biome's topsoil, dither band
  included. The ore field is not read: its lookups were most of a coarse build, and a vein a few tiles
  across would only flicker in one cell. Veins show after the upgrade.
- Level policy in `near_ring.gd`. Full detail where a body reaches: Chebyshev `REACH_RADIUS` 2 of the
  walking local body (not 1 as planned: Phase 189 keeps collision two rings out for the 60 m reach) and 1
  of a peer. The rest is 32×32 within 2 of the local body, 16×16 beyond. A chunk with an edit, the record
  flight (`set_near_ring_enabled(false)` or `set_lod_enabled(false)`) and a process that draws nothing
  build full. `NearRing.tick` upgrades coarse chunks entering the detail ring (nearest first, the one under
  the body unbudgeted). The coarse mesh stays until the full one lands, and nothing is downgraded in place.
- Deviation: a coarse chunk is not render-only. It carries a conservative collision soup (its own quads),
  parked like a full chunk's and attached only where Phase 189's ring wants collision. A fast flyer has no
  detail ring and stands on its chunk's coarse collision. When it slows, the reach ring is upgraded. With
  the chunk under the flyer upgraded every crossing (the plan), one 24 ms full build per crossing alone was
  about 0.2 of the record, and the gate measured 0.30 locally. A slower runner builds fewer chunks per
  crossing, which pushes that ratio past a third.
- Measuring: workers time their task (`result[2]`), `ChunkManager.worker_usec` sums every reaped build and
  `local_crossings` counts crossings. `tools/check_playtest_budget.py` gates
  `flight.worker_ms_per_crossing` against `record_worker_ms_per_crossing` (`--self-test` covers it).
- `_dispatch_worker_noise_build` moved verbatim into `chunk_part_1.gd` (with a forwarder) so `chunk_manager.gd`
  stays under the 1,500-line cap.
