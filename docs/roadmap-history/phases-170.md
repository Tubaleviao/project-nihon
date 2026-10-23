# Roadmap history — Phase 170

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 170 — A compute-shader heightmap, if the native builder is still the bottleneck

**Goal:** moved out of Phase 144. Measure first; build only if the numbers ask for it.

**Newel dependency:** NO.

**Depends on:** Phase 169, Phase 165.

**Deliverables:**
- A playtest-bot measurement at the largest default view distance (after Phase 165) that reports
  where chunk build time goes with the native builder.
- If `heightmap_for` is still over half of the build time: a compute-shader heightmap path with the
  native builder as fallback. Otherwise: the measurement is recorded in this section and the phase
  closes with no shader.

**Acceptance criteria:**
- [x] Playtest bot (CI): the measurement is in `report.json`, and this section records the decision.
- [x] If a shader (not applicable: no shader shipped, see the decision) ships: suite parity with the native `heightmap_for` for the fixed chunk set, and a
  machine without compute support uses the native/GDScript path.
- [x] Suite green on both boot paths, harness green.

**Decision: no shader.** The playtest bot's `stream` step now writes `build_breakdown` into
`report.json` (per-chunk milliseconds of `heightmap_for`, seam strips, `build_runs` and
`build_chunk_arrays`, the heightmap share, the streamed window radius and the decision), prints it in
`report.md`, and `tools/check_stream_rate.py` fails CI when the native run lacks it. A shader is
justified only when `heightmap_for` is over `PlaytestBot.SHADER_SHARE_LIMIT` (50%) of the build. First
measurement (native builder, window radius 4 = default view 3 + prefetch 1, 24 chunks): heightmap
0.76 ms, seam 2.3 ms, runs 22.0 ms, arrays 14.5 ms, total 39.6 ms per chunk; heightmap is 2% of the
build, so the phase closes with no compute shader. The remaining cost is `build_runs` and the mesher.
