# Playtest frame budget (Phase 174)

`--playtest-bot` records, per step, the frame time split into **process**, **physics** and **render**
(`Performance.TIME_PROCESS`, `TIME_PHYSICS_PROCESS` and the root viewport's measured render time,
CPU + GPU) and writes the rendering adapter, driver and whether the native chunk builder loaded
(`native_builder`) into `playtest/report.json`.

The gate is the **p95 process time**, not the wall frame time: CI renders with llvmpipe (software), which
inflates the frame but not the process time. The source of truth is `docs/perf/playtest-budget.json`;
the table below mirrors it (a suite test checks they agree).

- The bot exits 1 when a step's p95 process time is over `budget × 1.25`.
- CI runs the bot 3 times with `--playtest-no-budget` and `tools/check_playtest_budget.py` gates the
  **median** of the three p95s against the same `budget × 1.25`, so one noisy run on a shared runner
  does not fail an unrelated PR. It also fails when `native_builder` is not `true`.
- Fixture: an injected 40 ms step fails the gate (`_test_playtest_budget_gate`).

## Budget table

Target for every step: p95 process time ≤ 16 ms. The budgets below are the current gate, set from the
first measured run (llvmpipe, `opengl3`, native builder loaded, 2026-10-23), not the target.

| Step | Budget p95 process (ms) | Target (ms) | Measured p95 process (ms) |
|---|---|---|---|
| walk | 150 | 16 | 145 |
| craft | 200 | 16 | 193 |
| fight | 190 | 16 | 177 |

## Findings

- The GDScript fallback is not in use: the report says `native_builder: true` with the native library
  loaded, and CI now fails when it does not.
- Process time is about 75–80% of the wall frame (p50 104 ms of 83–137 ms in `walk`), physics is
  under 6 ms, and the measured render time is not what makes the frame long. The cost sits in the
  main-thread `_process` work, so the "114 ms arrays" number from the stream step is a worker build,
  not a frame cost. All three gated steps are over the 16 ms target; the follow-up phase in
  `ROADMAP.md` profiles the main-thread work and brings them under it.
