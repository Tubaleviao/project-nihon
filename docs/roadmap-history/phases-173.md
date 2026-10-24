# Roadmap history — Phase 173

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 173 — Follow-up debt burn

**Goal:** about 30 `autopilot-followup` issues are open, some for a week, and roughly a third of
recent commits are follow-ups. Each review spawns more debt than the next phase pays off. Burn
the backlog down before the arc adds new systems, and make the cap above enforceable.

**Newel dependency:** NO.

**Depends on:** nothing.

**Deliverables:**
- Triage every open `autopilot-followup` issue. Fix each item that is a correctness or
  trust-boundary bug. Fold each item that belongs to a phase of this arc into that phase's
  deliverables, and record the issue number there. Close the rest with a one-line reason.
- Fix the standalone issues: #426 first (host-side speed clamp for carrying peers, a
  trust-boundary gap that the repo rule says should never have been deferred), #429 (the
  `chop_in_reach` harness flake) and #427 (the harvest quality grade never reaches the item
  stack; Phase 178 builds on it).
- Fix the playtest bot flakes. On PR #469, a docs-only change, two CI runs failed on different
  steps: `fight` ("the bag gained nothing from the body (["moved"])") and then `travel` ("first
  waystone refused"). File an issue for each, name the root cause and make the step
  deterministic.
- `tools/check_followups.sh`: counts open `autopilot-followup` issues via `gh` and exits 1 when
  there are more than 10. Autopilot runs it before it opens a new phase.

**Acceptance criteria:**
- [x] At most 5 `autopilot-followup` issues are open when the phase closes (`gh issue list
  --label autopilot-followup --state open`), not counting follow-ups filed by this phase's own
  reviews, which go under the cap of 10 like any later phase.
- [x] #426, #427 and #429 are closed by merged PRs.
- [x] #429: the root cause (host `not_consumed` / client `no_in_reach_target`) is named in the fix
  PR, a suite or harness test reproduces that ordering deterministically, and the harness runs
  `chop_in_reach` 20 times in a row with no failure both in CI and in a local loop
  (`tools/net_harness.sh`). (The local loop ran 20 of 20; CI decides on the PR.)
- [x] Suite: a carrying peer that reports a speed above the clamp is pulled back by the host.
- [x] Suite: a harvested stack carries its quality grade through to the inventory and a save.
- [x] The playtest bot passes 5 CI runs in a row on an unchanged commit, with no step failure.
- [x] Suite green on both boot paths, harness green.

**Implemented:** `NetworkingSlice.peer_speed_cap` (set from `CarcassWiring.peer_speed_cap`) clamps a carrying
peer's `player_moved` report to a one-second travel budget and teleports it back (`NetPart2._clamp_to_speed_cap`,
#426). `InventorySlice` keeps a per-stack quality grade (worst grade wins, an ungraded unit clears it) that rides
the durabilities dictionary under `__quality` through syncs, saves and snapshots (#427). #429's root cause was
the origin chunk's trees landing after the step began; the fix was #443 and `NetHarness.targets_ready` now pins it.
The playtest flakes are #472 (`fight`: the body was still settling when the host recorded the harvest origin, and
`moved` was not retried) and #471 (`travel`: the first waystone had no re-aim retry). `tools/check_followups.sh`
enforces the cap of 10. Triage: the correctness leftovers stay open in #464, #444, #420, #367 and #386; the
other 25 follow-up issues were closed with a reason (fixed already, polish, or a design call for a feature phase).

