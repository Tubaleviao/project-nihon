# Roadmap history — Phase 159

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 159 — Gestures at runtime: a gesture wheel, chat commands and synced poses

**Goal:** play the Phase 158 gestures in game, for the local player and as seen by everyone nearby.

**Newel dependency:** NO.

**Depends on:** Phases 155, 158.

**Deliverables:**
- `src/character/gesture_slice.gd` (new) with `gesture_wiring.gd`: a `gesture_intent(gesture_id)`
  goes to the host, which validates it (known id, the player alive, grounded when `requiresGround`,
  rate-limited like chat) and broadcasts `gesture_synced(player_id, gesture_id)` to the player's
  AOI. A late joiner sees a held pose (sitting players stay seated).
- Cancel rules from the fabric: moving cancels a `cancelOnMove` pose (the stand-up plays as a
  0.3 s transition, not a pop), damage cancels a `cancelOnDamage` pose, death cancels everything.
  Cancellation is decided on the host and synced.
- `restRegen` applies on the host while a pose is held.
- Input: a gesture wheel on a key (default `G`, rebindable) built from the fabric list, and the
  `chatCommand` of each gesture in chat (`/sit`, `/wave`, …) through `ChatCommands`. All labels
  through `tr()`.
- Rig: `RigTree` gets a `Gesture` node (pose loops, one-shots return to locomotion). Sitting on a
  placed station or block edge snaps to its top face (sit height read from the target), otherwise
  sits on the ground.
- Placeholder clips for every gesture on the player rig in `tools/gen_placeholder_glb.py`, keyed in
  the manifest, and matching keys in the private repo (separate PR).

**Acceptance criteria:**
- [x] Suite: a `/sit` from the local player plays `sit` on the rig; a movement intent afterwards
  cancels it and returns to locomotion.
- [x] Suite: the host refuses an unknown gesture id, a gesture from a dead player and gestures over
  the rate limit (trust boundary), and a client cannot cancel another player's pose.
- [x] Suite: a damage event cancels `LieDown` and does not cancel `Wave` if the fabric says so.
- [x] Suite: HP regeneration while `Sit` is held equals the base rate times `restRegen`.
- [x] Harness step `gesture_synced`: a peer's `/sit` is seen seated on the other client, and a
  client that joins afterwards also sees it seated.
- [x] Suite: every gesture in `GameData` has a clip on the placeholder player rig.
- [x] Suite green on both boot paths, harness green.

**Notes (as built):**
- The wheel key defaults to `Q`, not `G`: `G` is the Proposals window and the tame key. It is
  rebindable (`user://settings.json`, `gesture_key`). Hotbar boxes cannot take `Q`.
- `/sit` plays `Sit` when a block edge 0.25–0.75 m above the feet lies 0.6 m ahead (the body is lifted
  onto it), otherwise `SitGround`. Placed stations are not yet read as seats.
- `restRegen` applies to HP only (there is no stamina system yet) while a rest pose is held, at
  `BASE_HP_REGEN_PER_S` times the multiplier. A remote peer's gain is recorded on the host; it is not
  pushed to that peer's HUD.
- Harness step `gesture_synced`: the harness has one client, so the "late joiner" half is the host's join
  handler re-run for that client, which delivers the host body's pose.
- Matching clips in the private art repo are a separate PR.
