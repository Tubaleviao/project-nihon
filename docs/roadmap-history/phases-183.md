# Roadmap history — Phase 183

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 183 — Playtest process time under 16 ms ✅ Done

**Goal:** Phase 174 gated `walk`, `craft` and `fight` on p95 process time (the scene tree's `_process`
work per frame) and found them at 26, 27 and 18 ms on llvmpipe with the native builder loaded (median of
3 local runs on the pinned seed). Physics is under 1.5 ms, so the cost is main-thread `_process` work,
not the chunk build. Name it and cut it.

**Newel dependency:** NO.

**Depends on:** Phase 174.

**Deliverables:**
- Profile the three steps (per-slice `_process` timing, `Performance` custom monitors) and name the
  top main-thread cost in the PR.
- Fix it, then lower `docs/perf/playtest-budget.json` and the table in `docs/perf/playtest-baseline.md`
  toward the 16 ms target.

**Acceptance criteria:**
- [x] The top main-thread cost per step is named in `docs/perf/playtest-baseline.md`.
- [x] CI playtest: `walk`, `craft` and `fight` median p95 process time is ≤ 16 ms × 1.25.
- [x] Suite green on both boot paths.

**Outcome:** the top cost in all three steps was creature AI: every creature in the window ran its full AI
every frame. Behind it were chunk collision (Jolt builds a chunk's ~11,000-triangle mesh on the main
thread when its body enters the world, ~9 ms) and A* searches that spent their whole expansion cap on
goals outside the search window (~20 ms). The fixes: an AI level of detail for far idle creatures; path
searches that try the straight line first, aim at the window edge and have count, time and patrol caps; a
shared height cache; collision cut into quadrants and attached one per pump step two rings out; a time
budget for distant fill patches. The bot's spawn was not pinned (the spawn search is seeded by the player
id, minted fresh each run), which was most of Phase 174's run-to-run spread; the bot now pins it
(`PlaytestBot.PLAYER_ID`). Median local p95 on the pinned spawn: walk 42.6 → 15.2 ms, craft 20.5 → 11.8 ms,
fight 12.2 → 5.5 ms. The budget is now the 16 ms target for every step. Details:
[docs/perf/playtest-baseline.md](../perf/playtest-baseline.md#process-time-phase-183).
