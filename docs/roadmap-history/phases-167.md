# Roadmap history — Phase 167

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 167 — Native `heightmap_for`

**Newel dependency:** NO.

**Depends on:** Phase 166.

**Deliverables:**
- `heightmap_for` ported to `NativeChunkBuilder`: climate, shape, ore and biome resolve, using the
  engine's `FastNoiseLite` through `godot-cpp`.
- The loader routes `heightmap_for` to native when the extension is present.

**Acceptance criteria:**
- [x] Suite: native and GDScript `heightmap_for` give equal results for a fixed set of chunks
  (equator, ice, pole, antimeridian, edited chunk). Skipped with one log line when the extension is
  absent; CI runs it with the extension built.
- [x] Suite green on both boot paths, harness green.

**Shipped:** `NativeChunkBuilder.heightmap_for(pos, seed, noise, cfg)` (version 2) ports the tile loop:
`WorldShape` height (continentalness, erosion, ridges, spline, spawn plain), the hashed-cell detail
noise through the engine's `FastNoiseLite`, the antimeridian blend and the polar ice and snow field.
`heightmap_for` itself never reads climate, ore or biome tables (those are `build_runs` / biome
resolve territory), so there is nothing of them to port here. `TerrainSlice.heightmap_for` routes
native when `NativeBuilder.use_native("heightmap_for")`; `heightmap_for_gd` stays the reference and
the fallback. Recorded cells keep their stored corner heights: the GDScript side resolves the
(at most two) records a chunk reads and passes them in `cfg.records`. The suite compares results with
`==` (bit-exact) on ten chunks, with and without records. `heightmap_strip_for` and the distant ring
stay on GDScript.

