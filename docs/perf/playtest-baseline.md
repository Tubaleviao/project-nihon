# Playtest frame budget (Phase 174)

`--playtest-bot` records, per step, the frame time split into **process**, **physics** and **render**
and writes the rendering adapter, driver and whether the native chunk builder loaded
(`native_builder`) into `playtest/report.json`:

- **process**: the scene tree's `_process` work of the frame, timed from the first `_process`
  callback (the bot's, at the lowest `process_priority`) to the last (its `FrameEnd` child, at the
  highest). Timers, tweens and deferred calls flushed after the last node are not in it.
- **physics**: the `_physics_process` work of the physics ticks that ran before that frame, bracketed
  the same way (0 when no tick ran).
- **render**: the root viewport's measured render time, CPU + GPU.

`Performance.TIME_PROCESS` is not used: Godot publishes the **maximum** process time of the last
second, once a second (`main/main.cpp`, `process_max`), so a per-frame sample of it is the worst frame
of the last second. Before this was found, the gate read walk at 205 ms (local) and 309 / 473 ms (CI)
"p95 process", above the 93 ms p95 wall frame, and it failed CI on noise.

The gate is the **p95 process time**, not the wall frame time: CI renders with llvmpipe (software), which
inflates the frame but not the process time. The source of truth is `docs/perf/playtest-budget.json`;
the table below mirrors it (a suite test checks they agree).

- The bot exits 1 when a step's p95 process time is over `budget × 1.25`.
- CI runs the bot 3 times with `--playtest-no-budget` and `tools/check_playtest_budget.py` gates the
  **median** of the three p95s against the same `budget × 1.25`, so one noisy run on a shared runner
  does not fail an unrelated PR. It also fails when `native_builder` is not `true`.
- Fixture: an injected 40 ms step fails the gate (`_test_playtest_budget_gate`).

## Budget table

Target for every step: p95 process time ≤ 16 ms. The budgets below are the current gate, set from
measured runs (llvmpipe, `opengl3`, native builder loaded), not the target.

| Step | Budget p95 process (ms) | Target (ms) | Measured p95 process (ms) |
|---|---|---|---|
| walk | 40 | 16 | 27.3 (CI) / 25.6 (local) |
| craft | 45 | 16 | 22.6 (CI) / 27.1 (local) |
| fight | 35 | 16 | 7.5 (CI) / 18.0 (local) |

"Measured" is the median of three runs, on CI (GitHub runner, llvmpipe, the gate run of 2026-10-24 on
ca6e87c) and on the local box (2026-10-24), both on the pinned `PlaytestBot.WORLD_SEED` (#480). Local
per-run p95: walk 29.0 / 25.6 / 23.3, craft 30.9 / 27.1 / 22.5, fight 21.3 / 18.0 / 10.4. On this metric
the runner is no slower than the local box. The budgets leave about 1.5× over the slower of the two,
because fight varies about 2× from run to run.

p95 wall frame time on the same runs (llvmpipe): walk 95 ms, craft 120 ms, fight 104 ms. It is recorded
here and not gated: process is now about a quarter of the wall frame, so most of the frame is
rendering (software) and engine work outside the scene tree's callbacks.

A local run needs a current native library: when `native/src` is newer than `native/bin`, the bot runs
the GDScript fallback (the log says `native version N is older than M; rebuild native/`) and its
numbers are not comparable. Rebuild with `scons platform=linux target=template_debug` in `native/`.

## Flight: main thread per attached chunk (Phase 189)

The `flight` step records the chunk manager's main-thread time (TickProbe `chunks` and the `chunk_*` phases
nested in it) per chunk attached after the warm-up, in `flight.main_ms_per_attach`. It flies a second time
over the same ground with the near ring off (the Phase 187 behaviour: collision and contents on every
attach) and records that as `flight.record_ms_per_attach`. Both flights also record the phases the near
ring removes, collision bodies and contents (`chunk_attach_collision` + `chunk_contents`), as
`flight.near_ms_per_attach` and `flight.record_near_ms_per_attach`, plus every chunk phase per attached
chunk (`phases_ms_per_attach`, `record_phases_ms_per_attach`). `tools/check_playtest_budget.py` fails when
the median near-ring cost over the three CI runs is above half the median of the record's. The whole pump
is report-only: mesh upload and dispatch are not the near ring's to cut, and their share varies by machine
(a 2-core llvmpipe runner pays ~4 ms more per chunk on both flights). The record is measured in the same
run, so the gate holds on any machine.

## Flight: worker ms per crossing (Phase 190)

Each flight also records the worker time of every build reaped after the warm-up
(`ChunkManager.worker_usec`, timed inside the task) per local chunk crossing, as
`flight.worker_ms_per_crossing` and, for the record flight (near ring off, so every chunk is built at full
detail: the Phase 189 load), `flight.record_worker_ms_per_crossing`. `tools/check_playtest_budget.py` fails
when the median over the three CI runs is above a third of the record's median. Local run (native, 3 runs,
seed pinned): 10.8 ms against 116.7 ms (0.09). The stream is dispatch-bound at 90 m/s (about 4.5 builds
per crossing on both flights), so the ratio is close to a coarse build's cost over a full one's: about
1–2 ms (heightmap 0.6 ms) against 24 ms.

## Findings

- The GDScript fallback is not in use: the report says `native_builder: true` with the native library
  loaded, and CI now fails when it does not.
- Physics is under 1.5 ms p95 in every gated step.
- All three gated steps are over the 16 ms target (p50 walk 18–23 ms, craft 9–17 ms, fight 8–15 ms);
  the follow-up phase in `ROADMAP.md` profiles the main-thread work and brings them under it.
