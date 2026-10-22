# Roadmap history — Phase 168

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 168 — Native `build_runs`

**Newel dependency:** NO.

**Depends on:** Phase 167.

**Deliverables:**
- `build_runs` ported to `NativeChunkBuilder`, routed through the loader.
- If the GDScript reference's output order depends on dictionary iteration, the reference is made
  deterministic first (in the same PR) so parity is defined.

**Acceptance criteria:**
- [x] Suite: native and GDScript `build_runs` give equal output, same order, for the fixed chunk set.
- [x] Suite green on both boot paths, harness green.

**Shipped:** `NativeChunkBuilder.build_runs(chunk_pos, heightmap, input, cfg)` (version 3, `native/src/native_runs.cpp`)
ports the whole resolve: edit replay (`add`/`remove`), the ring's unknown-neighbour rule, the ore field's
value-noise veins and ley gate, biome host rock, polar ice, the biome dither and topsoil, and the vein
deposit markers. `cfg` (`VoxelSlice.native_runs_cfg`, snapshotted once and warmed from `_ready`) carries what
GDScript owns: circumference, material colours, host rocks, surface styles, the ore depth bands and a
callable for `OreField.vein_in_cell` (the per-cell descriptor, which needs the climate biome lookup, stays
GDScript and is memoised per call). `VoxelSlice.build_runs_gd` is the reference and fallback.
Determinism: the reference's output order never came from dictionary iteration (the tile loop fixes it), but
`VoxelRuns.add_span` sorted on `bottom` alone with the engine's unstable `sort_custom`; it now sorts on
(bottom, top, material), so equal-bottom runs resolve the same way in both builders. The suite compares
`==` (bit-exact, tiles in order, deposits in order) on ten chunks in three variants (plain, edited with a
partly mined-out vein set, edited with an unknown east ring).
