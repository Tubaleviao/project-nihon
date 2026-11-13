# Roadmap history — Phase 253

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 253 — A green `main`: flaky gates demoted, the stress regression explained ✅ Done

Of the last 40 CI runs on `main` (to 2026-11-12), 18 failed. Seven of the last eight were the
playtest bot's `walk` step failing its gait assertion (`_step_walk`: `left foot ahead 100% of N
frames, 0 lead switches`) while the distance and state checks passed; the clip aliasing with a slow
runner's sample rate has been widened twice already (`WALK_FOOT_MIN_FRAMES`). The latest was the
stress job: largest passing crowd 0 for `lan/cluster`, `lan/cross` and `lan/spread` against a
baseline of 16, and 16 for `lan/pole` against 32, on the merge of Phase 243 (#618), with
`host_tick_p95_ms` the budget missed at 16 bots. A gate that is red half the time stops meaning
anything, and this roadmap's whole method is that gates are the acceptance criteria.

- **Gait check report-only.** The `walk` step keeps its hard checks (distance moved, ground under the
  body, the state machine reaching `RUN`) and writes the gait numbers to the report without failing
  on them, like the chunk pump since Phase 189. A gait regression is caught by a suite test on the
  animation clip instead (the walk clip's foot bones alternate lead within one cycle).
- **The stress regression.** Re-run the stress job on the merge commit of #618 and on its parent. If
  the regression holds, find it (Phase 243 is client-only by `game_root.gd`'s `_is_server` guard, so
  the suspects are the watcher client's frame time, the attach budget of Phase 239, or the runner)
  and fix it in this phase; if it does not, the ladder's rerun rule (`stress: … missed a budget at or
  below the baseline; running it once more`) widens to a best-of-three for the baseline sizes.
- **A flake rule, written down.** `docs/DEVELOPMENT.md` gains the rule: a gate that fails three times
  on `main` without a code change explaining it is demoted to report-only the same day, with an issue
  to make it decisive again. `tools/check_gate_health.sh` reads the last 40 `main` runs through the
  GitHub API and prints the failure count per job; CI runs it on a schedule and fails the scheduled
  run when any job is over 10%, so the trend is visible before it is normal.

**Status (2026-11-12):** the gait is report-only, the clip and verdict tests, `tools/check_gate_health.sh`, the
scheduled `Gate health` workflow, the flake rule and the best-of-three stress rerun are in. The stress
regression was real: the dedicated server attached a smooth chunk's four collision quadrants in one frame
(~17–20 ms of Jolt mesh building); it now staggers them like a client (`NearRing._attach_server_collision`),
cause and numbers in `docs/perf/crowd-baseline.md`.

**Done (2026-11-13):** the stress job was green on `main` five runs in a row after the merge: the pushes of
#623 (`bba750d`) and #624 (`4be4f51`), and three manual dispatches on `4be4f51` (runs 43434916140,
43434928806, 43434941847).

**Acceptance criteria**
- A suite test on the walk step's verdict: a sample set with zero lead switches but the distance and
  states met passes, and the report carries the gait numbers.
- A suite test on the walk clip asserts the feet alternate lead within one cycle.
- The stress job is green on `main` for five consecutive runs after this phase merges, and either the
  fix or the rerun widening is in the PR with the cause written in `docs/perf/crowd-baseline.md`.
- `tools/check_gate_health.sh` exists, a scheduled workflow runs it, and the suite's workflow lint
  passes with the new job.
