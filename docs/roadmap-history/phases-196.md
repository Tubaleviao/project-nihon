# Roadmap history — Phase 196

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 196 — Follow-up debt burn IV: waystones, gestures, trees and the player registry (#336, #367, #420, #522) ✅ Done

**Goal:** the last four follow-up issues are the oldest, and several of their items wait on a
design decision. This phase makes those decisions (below) so the items can close. It also fixes
the network trust-boundary items, which the repo rule says should never have been deferred.

**Newel dependency:** NO.

**Depends on:** nothing.

**Decisions** (open to review on this roadmap PR):
- A vertical rise (a jump or a drop) above a small threshold ends a `cancelOnMove` pose, like
  horizontal movement does (#420).
- The host decides Sit versus SitGround once, from its own support probe, and syncs the result.
  Viewers stop probing (#420).
- Resting regen on the host heals the remote peer's own client through a host-to-client HP update,
  not only the host's mirror (#420).
- Placing any station consumes its item, as founding with a `Hearth` already does, so a waystone
  needs the `Waystone` item (#336). The fabric records this, and an amending decision squares
  waystones with `NoTeleportation`. Both go in a separate fabric PR ahead of the runtime fix.
- A waystone's attune and depart radius stays a ground distance plus a vertical bound of one chunk
  height (#336).

**Deliverables:**
- Re-check every item against `main` and close the ones already fixed with a pointer.
- Trust boundary first: a per-peer limit on `look_request` (#522), a per-peer throttle on waystone
  refusal replies, and an early reject when the attunement list is full (#336). The player registry
  checks a loaded record's name skeleton against `_taken` (#522).
- Waystones (#336): the exact position is recorded and persisted at placement. The map's
  stone-under-player check uses the player's exact `get_world_pos()`. The station id counter is
  persisted, so a reload never reuses a removed id. The waystone position fallback uses
  `get_last_known_state` and updates on teleport. The duplicated `waystones` handling becomes one
  helper. The sweep caches ids and prefilters by chunk distance. The harness derives station ids,
  and the minimap does not save the boot seed's revealed set.
- Gestures (#420): the decisions above. Also: poses are cleared on peer disconnect and prune, and
  an ended pose is sent as "" on AOI re-entry. A swing at empty air cancels a held pose. The wheel
  key is reserved, bindable and read from the binding in its strings. The hotkey ignores echo and
  modifiers and marks the event handled. A refused gesture gets a keyed notice. The rate token is
  spent after the ground check. The listen host shows a remote client's gesture. Seat lift uses
  `sample_support_height_at`, stand-up does not pop for a frame, and `gesture_wiring` uses a public
  `CharacterSlice` API instead of `_peer_characters` / `_m2`.
- Trees and persistence (#367): held tree spots are applied or forgotten when their chunk's record
  appears. The original generation fingerprint is kept when the stamp is updated. The deferred-record
  stamp is cleared on unload. The seam-wrap audit bans `posmod`/`fposmod` outside `seam_wrap.gd` on
  wrap-like lines. The harness logs a missing `tree_cleared` target clearly, and
  `_capture_spare_target` retries instead of failing on one slow probe.
- Player registry (#522): a starting-kit item that does not fit the bag drops at the player's
  feet, with a log line.

**Acceptance criteria:**
- [x] #336, #367, #420 and #522 are closed: every item is fixed by a merged PR or closed with a
  reason (the table below; the issues close when the PR merges).
- [x] At most 3 `autopilot-followup` issues are open when the phase closes, not counting
  follow-ups filed by the reviews of Phases 194–196 (only #531, from Phase 195's review, stays open).
- [x] Suite: a peer over its `look_request` limit is refused, and repeated refused travel intents
  from one peer get at most one reply per second.
- [x] Suite: a far waystone keeps its exact position through a save and a reload (at chunk 600,000:
  chunk 1,500,000 is past one lap of a 40,000 km planet, 1,250,000 chunks, so no body stands there and
  the save's wire check rejects it). Removing the highest-numbered station and reloading gives the next station a fresh id,
  and no old attunement binds to it.
- [x] Suite: placing a waystone without the `Waystone` item is refused with a keyed reason.
- [x] Suite: a jump ends a Sit pose; a swing at empty air ends a held pose on the host; a pose
  that ended while the viewer was out of AOI is not replayed on re-entry.
- [x] Harness: a resting remote client's own HP rises, and both viewers show the same seat lift
  for one pose (`gesture_synced`: the host's probe reports a 0.4 m seat).
- [x] Suite: a loaded record whose name skeleton is taken does not take it from its holder, and a
  starting-kit item that does not fit lands on the ground.
- [x] Suite: a tree spot held for an unrecorded chunk is applied when the chunk's record appears
  (already on `main`: `tree clears: a held spot applies when the chunk is recorded…`).
- [ ] Harness: `chop_in_reach` and the tree-clearing step pass 20 runs in a row (passed in every local
  run of this phase, but not 20 in a row; left to CI's runs).
- [x] Every new string is in both catalogs, and the i18n key check passes.
- [x] Suite green on both boot paths, harness green (local: every test but `terrain: a new record
  schedules exactly one ring rebuild`, which fails the same way on `main` on this machine).

**Items and how each was settled:**

| Issue | Item | Outcome |
|---|---|---|
| #336 | `note_exact` never called outside tests | Already fixed on `main`: `WaystoneWiring._on_station_placed_exact` records it at placement; saved as `waystone_exact`. |
| #336 | `MapWindow._stone_under_player` floats | Already fixed on `main`: it uses the player's `get_world_pos()`. |
| #336 | `NoTeleportation` vs waystones | Already in the fabric: `WaystonesAmendNoTeleportation` (Phase 130), so no separate fabric PR was needed. |
| #336 | `try_place_station` consumes no item | Consumption was already on `main` (`placementItem`). Fixed now: the refusal has a keyed reason, `StationSlice.place_refusal` → `no_placement_item:<item>` (`reason.no_placement_item`), shown on the build label. |
| #336 | `distance_m` ignores height | Fixed: `WaystoneSlice.at_stone` adds a vertical bound of one chunk height (`VERTICAL_BOUND_M` = 32 m) to attune, sweep and travel; the radius stays a ground distance. |
| #336 | harness hard-codes `station_0`/`station_1` | Already fixed on `main`: the client half orders the synced attunement list. |
| #336 | every refused intent is answered | Fixed: one refusal reply per `REPLY_INTERVAL` (1 s) per player (was 0.5 s). |
| #336 | `try_attune` at `MAX_WAYSTONES` | Already fixed on `main` (early `full`); the full and already-attuned checks now also run before the distance. |
| #336 | `_waystone_player_pos` stale or legacy | Already fixed on `main`: `get_expected_exact` (teleport target for 3 s), then `get_last_known_state`. |
| #336 | `_next_id` reused after reload | Already fixed on `main`: `station_next_id` is persisted. |
| #336 | minimap saves the boot seed's set | Fixed: `TerrainSlice.seed_adopted` (set by `set_world_seed` and the host's fresh-seed path); the minimap never writes a set whose seed was never adopted. |
| #336 | waystone result handling duplicated | Already fixed on `main`: `WaystoneWiring.apply_own_view`. |
| #336 | sweep O(players × stones) | Fixed: stone positions cached per sweep (already), and a stone more than one chunk away is skipped on two integer compares before any distance. |
| #367 | held tree spots released only at the next spawn | Already fixed on `main`: `ChunkManager._record_generation` calls `TreeSlice.on_chunk_recorded`. |
| #367 | harness `tree_cleared` missing target | Already fixed on `main`: "tree_cleared target not received" is logged. |
| #367 | seam-wrap audit only matches a few names | Already fixed on `main`: the audit matches posmod/fposmod by shape (a halving on the line) in every `src/` file but `seam_wrap.gd`. |
| #367 | fingerprint stamp overwrite | Already fixed on `main`: `worldgenFingerprintHistory` keeps the original. |
| #367 | `_deferred_since` not cleared on unload | Already fixed on `main`: `unload_chunk` erases it. |
| #367 | `_capture_spare_target` fails on one slow probe | Already fixed on `main`: it waits one more round. |
| #420 | rest regen never reaches the remote client | Fixed: the host sends `player_healed` (bounded, finite, positive) to the resting peer; its client applies it (`player_rest_healed`). |
| #420 | a jump does not end a pose | Fixed: `GestureRules.moved` also ends a `cancelOnMove` pose on a rise or drop over `RISE_CANCEL_M` (0.5 m); the old pin is replaced. |
| #420 | stale poses after AOI exit, prune or id reuse | Fixed: `peer_disconnected` forgets the peer's pose and every replay pair; the host remembers what each viewer was told and sends "" on re-entry for a pose that ended meanwhile (a held pose is still replayed). |
| #420 | each viewer decides Sit vs SitGround | Fixed: the host resolves it once from its own probe (its avatar, or the reported position on a dedicated server), keeps the lift with the pose and sends it (`l`, clamped on the client); viewers use the host's lift. |
| #420 | expired one-shot stays GESTURE in the air | Fixed: `Locomotion.update` leaves GESTURE as soon as the clip is over. |
| #420 | wheel key not reserved, no `set_key` caller, "Q" in strings | Fixed: `Hotbar.gesture_key` is reserved; the Gestures window has a rebind button (next key, Esc cancels); `win.gestures` takes the key as `{0}` and `chat.usage.gestures` no longer names a key (the host cannot know a client's binding). |
| #420 | `_replay_to_entrants` every frame | Fixed: every `REPLAY_INTERVAL` (0.25 s). |
| #420 | token spent before the ground check; silent refusals | Fixed: the ground check comes first; a refusal sends `hud.gesture.refused.<reason>` to the player, at most once a second. |
| #420 | wiring reaches into `CharacterSlice` privates | Fixed: `trigger_gesture`, `end_gesture`, `advance_gesture`, `peer_character_ids`, `character_forward` on `CharacterSlice`. |
| #420 | a swing at empty air keeps the pose | Fixed: `PlayerSlice._try_attack` with no target sends the body's own stand-up intent while `in_pose`; a stand-up needs no position evidence on the host. |
| #420 | hotkey ignores echo and modifiers, not handled | Fixed: `GesturePanel.handle_key` (bare press only), and the event is marked handled. |
| #420 | listen host does not show a client's gesture | Fixed: the host poses its own avatar of that client (the client path, shared). |
| #420 | `_seat_lift` uses the column top | Fixed: `sample_support_height_at` from just above the highest seat. |
| #420 | one-frame pop on stand-up | Fixed: `apply_seat_lift` runs after the locomotion step. The other half of the item ("a one-shot freezes locomotion while moving") is closed by design: a one-shot is a short clip the body plays out. |
| #522 | loaded record steals a name skeleton | Fixed: `apply_player_data` indexes the name only when the skeleton is free or already the player's. |
| #522 | starting-kit item skipped silently | Fixed: it is handed to the registry's ground dropper, which logs and spawns a pickup at the player's feet (local body or last reported position). |
| #522 | no per-peer `look_request` cap | Fixed: a per-peer token bucket (32 burst, 4/s) in front of `answer_look_request`, dropped with the peer. |
