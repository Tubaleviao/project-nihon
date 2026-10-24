# Roadmap history — Phase 174

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 174 — An honest playtest frame budget

**Goal:** the playtest bot reports PASS while `walk`, `craft` and `fight` run at a p50 of about
130 ms per frame, with every frame counted as a hitch. The only failure condition is a frame over
2 s. The per-chunk build is about 138 ms, and 114 ms of that is `arrays`, which is suspicious
after Phase 169 moved it native. Find out what the number measures, then gate on it.

**Newel dependency:** NO.

**Depends on:** nothing.

**Deliverables:**
- The playtest report records the rendering adapter and driver, whether the native chunk builder
  loaded, and each step's frame time split into process, physics and render
  (`Performance` monitors).
- If the run uses the GDScript fallback, fix the CI packaging so the native builder loads.
- A per-step budget table in `docs/perf/playtest-baseline.md`: p95 **process** time (which
  software rendering does not inflate), plus p95 total frame time on a named renderer class.
  `--playtest-bot` exits 1 when a step exceeds its budget.
- If the process time is over budget, profile it and fix the top cost, or file it as the next phase.

**Acceptance criteria:**
- [x] `playtest/report.json` carries `adapter`, `native_builder` and per-step `process_ms`,
  `physics_ms` and `render_ms` percentiles.
- [x] CI playtest: the native builder is loaded (`native_builder: true`).
- [x] CI playtest: `walk`, `craft` and `fight` p95 process time is within the budget table. The
  gate takes the median of 3 runs and allows 25% headroom over the budget, so a noisy shared
  runner does not fail unrelated PRs. The bot fails the run above that, and a fixture proves it
  (an injected 40 ms step fails).
- [x] The budget table's target is p95 process time ≤ 16 ms. If a step is over it when the phase
  closes, a follow-up phase that names the top cost is in the index.
- [x] Suite green on both boot paths.
