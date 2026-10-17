# Roadmap history — Phase 147

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 147 — Review follow-ups I: trust boundary and far-from-origin precision

**Goal:** the open "Follow-ups from PR … review" issues hold items that touch the host's authority
and float32 precision. CLAUDE.md says trust-boundary findings are never deferred. This phase clears
them, so the host decides every rule and stays exact anywhere on the planet.

**Newel dependency:** NO.

**Depends on:** none.

**Deliverables** (each item is first checked against `main`; one already fixed by a later phase is
ticked on its issue with the commit that fixed it):
- #336: `WaystoneSlice.note_exact` is called from the placement path, so `exact_pos` never falls
  back to a float32 position. `MapWindow._stone_under_player` uses the player's exact world
  position. `try_attune` at `MAX_WAYSTONES` refuses before truncating, and sync fires only on a
  change. Refused travel intents are throttled per peer. Placing a station consumes its item
  (`Waystone`, `Hearth`, every station type) on the host; decide and record it as a fabric decision
  that amends `NoTeleportation`.
- #346: the knockback handler guards on `has_last_known_state`. Check that Phase 130's host-side
  hold covers immobilization, and close the item with the test that proves it.
- #374: the hearth position is rebuilt from the player's exact world position (as waystones do).
  `edit_blocker` becomes a pure query, and `_touch` runs only after a successful edit. `from_data`
  keeps `_next_id` above every loaded id and defaults a missing `last_active` to now. A change to the
  decay radius of an abandoned claim is pushed to clients.
- #380: `CreatureVisuals.reselect` and model placement use the creature's exact position (or the
  camera-relative position the terrain uses), not a float32 world `Vector3`. Creatures with no
  usable model do not count toward `max_models`. A respawn teleport does not read as run speed.
- #349: in `note_craft`, the first-craft marker is written after `_earn` grants the points.

**Status:** done. Notes: most #336/#346/#374/#380 items were already on `main` from Phases 125/130 (waystone `note_exact`, placement items, knockback guard, held-peer drop); this phase added the hearth exact position, pure `edit_blocker` + `note_edit`, `from_data` fixes, decay-radius push, the `max_models` and respawn-clip fixes, the first-craft marker order and the harness step `station_needs_item`. Workshop stations (forge, benches) stay free by decision (see `WaystonesAmendNoTeleportation`). Creature positions remain float32 `Vector3` by slice design.

**Acceptance criteria:**
- [x] Suite: a waystone and a hearth placed at x ≈ 2e7 m keep their exact positions through save
  and load (error below 1 cm).
- [x] Suite: placing any station without its item in the inventory is refused on the host, and a
  successful placement removes one item.
- [x] Suite: `edit_blocker` called as a preview leaves `last_active` and claim state unchanged.
- [x] Suite: with `max_models` = 2 and three creatures in range where the nearest has no model key,
  the two modellable creatures both get models.
- [x] Suite: a creature respawn does not set its clip to `run`.
- [x] Harness: a modified client that sends `player_moved` while held, and a station-place intent
  without the item, are both refused by the host.
- [x] Every item of #336, #346, #349 and #374 that is in scope here is ticked on its issue.
- [x] Suite green on both boot paths, harness green.

---

