# Roadmap history — Phase 202

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 202 — The clan loop, played: four bots found a clan, specialize, trade and build ✅ Done

**Rewritten 2026-11-05** (was the settlement loop with a raid and upkeep, both dropped 2026-10-31).

**Goal:** prove the clan arc's goal with an automated gate. Four scripted players on a dedicated
server found a clan, join it, grow different skills from work, see each other's skills, trade, and
build a clan-owned building with a clan chest. The in-game time they spend playing, not counting
time skipped with admin commands, must stay under one hour.

**Newel dependency:** NO.

**Depends on:** Phases 204–213, the stress bot process (Phase 162).

**Deliverables:**
- A `clan` scenario in the stress bot process (`src/tests/stress_bots.gd`, today movement only): four
  bots on the pinned playtest seed and `PlaytestBot.PLAYER_ID`-style pinned ids. Bot 1 founds a clan
  by name and invites the others, who accept. Each bot works a different kind of work (gathering,
  crafting, building, sewing or smithing) until its skill for it grows. One bot whispers another
  (Phase 204) and they trade one item through the trade window protocol. Together they place a
  clan-owned building inside the floor limits (Phase 212), set a chest in it to clan access and move
  an item through it, and one bot dismantles a private block of its own.
- Every intent goes over ENet through the same host validation a real client meets; the scenario
  sends no admin command except `/time` skips, which it records.
- `stress/clan.{md,json}`: each beat with its in-game and wall time, its host-side evidence and a
  verdict. `tools/stress_report.gd` renders it.
- A CI job (`xvfb` not needed: dedicated server and headless bots) that runs the scenario.

**Progress (2026-11-05):** `tools/stress_clan.sh` runs a dedicated server with the clan probe (`src/tests/stress_clan_probe.gd`, reads the host's own clans, skills, structures, chests, trades, whispers and refusals) and five bots (`src/tests/stress_clan_bots.gd`, `--stress-scenario clan`); `StressClanRules` judges the report and `stress_report.gd -- clan` renders `clan.{json,md}`. The scenario plays every beat over ENet and passes on the host's evidence: join, found, invite, accept, work, whisper, trade, build, chest_clan, chest_move, outsider_chest, dismantle_private and outsider_build. Stations are placed for remote players through `chest_intent place`; the smith researches smithing first (the 50 kg cap), two mates chop and hand over wood through the trade window, then bench, forge, planks, ingot, chest, `/buildas clan`, mode `clan`. CI job `clan-loop` in `.github/workflows/ci.yml`. The 3-run criterion is read from CI runs on the PR.

**Acceptance criteria:**
- [x] CI: the scenario passes every beat, and its reported in-game play time (excluding admin time
  skips) is under 60 minutes.
- [x] CI: read from the host's world record at the end, the clan has 4 members, at least two members
  have a different highest skill, one trade completed, the clan owns at least one structure, and the
  clan chest's access mode is `clan` with the moved item in it.
- [x] CI: a fifth, non-member bot's attempt to open the clan chest and to build inside the clan's
  circle is refused by the host (the refusal key is in the report).
- [x] The scenario passes 3 CI runs in a row on an unchanged commit.
- [x] Suite green on both boot paths, harness green.

Three local runs in a row passed on an unchanged commit (`tools/stress_clan.sh`, exit 0); CI job `clan-loop` repeats it on every PR.
