# Roadmap history — Phase 150

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 150 — Review follow-ups IV: wiring, harness and playtest bot

**Goal:** the test tools are the project's eyes. Their review items (#355, #359, #361, #380)
make them weaker than they look: the playtest bot changes slices directly instead of sending
intents, the WAN profile mutes creature sync, and the wiring audit is brittle. This phase hardens
them.

**Newel dependency:** NO.

**Depends on:** none.

**Deliverables:**
- #359: the playtest bot sends bus intents for place, craft, travel, fight and unlock, like a
  player would. Teleports land on `terrain.get_height_at` + offset, and the frame-time check skips
  the frames right after a teleport. A step's coroutine that crashes fails fast. The bot despawns
  the creature it spawns. `/build/` and `/playtest/` are anchored in `.gitignore`. CI runs a Linux
  export check on PRs.
- #380: find and fix why the player body sat about 20 km below the terrain at the fight step in the
  xvfb run. Remove the orphan section header in `creature_tests.gd`.
- #361: the harness timeout multipliers come from `NetworkingSlice.link_time_scale()`. Under
  `wan_bad`, creature deltas are throttled, not muted. `_drain_emulator` counts dropped packets
  and the harness reports the count.
- #355: `wiring.gd` gets a base `wire()` and a virtual `_connect_all()`. `connect_bus` is
  idempotent. The no-op `pass` handlers are removed. Cross-module calls to `_private` methods
  become public methods. String `Callable`s become method refs. The wiring audit globs its
  directories.

**Acceptance criteria:**
- [x] Suite: a static check finds no direct slice mutation in `playtest_bot.gd` (calls to
  `try_place_station`, `craft`, `begin_research`, … go through the bus).
- [x] Playtest bot: every step passes in CI, and the fight step's player is within 2 m of the terrain
  surface.
- [x] Harness: under `wan_bad`, at least one creature delta reaches the client, and the run report
  shows the dropped-packet count.
- [x] Suite: calling `connect_bus` twice connects each signal once.
- [x] CI: a PR runs the Linux export.
- [x] Every in-scope item of #355, #359, #361 and #380 is ticked on its issue.
- [x] Suite green on both boot paths, harness green.

**Implementation notes:** the bot sends `research_requested`, `craft_requested`, `combat_round_requested`
and `waystone_travel_intent`, and places stations with the player's own B and V keys. Items and research
points it needs are still granted directly (setup, no intent exists). Teleports go through `_teleport_to`
(voxel or generator surface + 2 m) and open a 1.5 s window in which frames are not recorded. A step
that is silent 10 s past its deadline fails with "crashed or hung". The harness driver reads the
profile time scale from `tools/profile_scale.gd` (table in `src/networking/net_profiles.gd`). Under a
bandwidth-capped profile `CreatureSlice.delta_interval` rises to 2 s instead of muting, and the client
fails the run if it saw no creature delta; the `link` line reports `dropped-N` and `creature_deltas-N`.
Items of #355, #359, #361 and #380 outside the deliverables (moving module-only state off `game_root`,
the extended unwire test, the respawn-teleport model reset, template pre-warm, float32 positions,
unmodellable-type cap) stay open on their issues.

---
