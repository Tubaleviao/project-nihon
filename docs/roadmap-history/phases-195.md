# Roadmap history — Phase 195

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 195 — Follow-up debt burn III: creature positions and the snapshot path (#444, #464, #493) ✅ Done

**Goal:** Phase 171 moved creatures onto exact positions, but its follow-ups (#464) say the AI
heading, the spatial hash, the fold log and the death fall still use float32 world metres, so a
creature far from the origin steers and folds coarsely. The snapshot follow-ups (#493, #444) contain
two real losses: an entry with a bad position drops its HP and death too, and a dropped send
advances `records_sent`, so the next delta leaves records out.

**Newel dependency:** NO.

**Depends on:** nothing.

**Deliverables:**
- Re-check every item against `main` and close the ones already fixed with a pointer (for
  example #444's `NO_GEOMETRY_ARRAYS` item, removed in #447 but still unticked).
- Creature exact positions (#464): `_step_toward` / `_flee` heading from
  `WorldPos.offset_between`. The death fall stores an exact position or an offset, not a
  scene-frame vector. `fold_contents`, the fold-log replay, the spatial hash and
  `creatures_in_radius` work on `{chunk, local}`. `position` becomes a read-only accessor, and every
  write goes through `_store_pos`.
- Snapshot apply (#493, #464): an entry with no or an implausible position still applies its HP,
  state and death. Every `{chunk, local}` entry, from the wire or from a save, goes through
  `WorldPos.is_plausible_pos`. The legacy-array branch reuses `WorldPos.is_wire` and checks element
  types. `_hold_death_record` takes the validated position.
- Snapshot send (#493, #444): `send_snapshot` stops at the first failed chunk.
  `records_sent[peer_id]` advances only for a send that succeeded. `net_harness.gd` sends through
  `SnapshotWiring.send_snapshot`.
- Relay and AOI (#444): `relay_batch.build` and `flush_relays` / `aoi_recipients` reuse the
  recipient set within a flush instead of rebuilding it per subject.
- Carcasses (#444): a dropped carcass lands at the carrier's host position when the host knows it.
- Distant bands (#444): a finished band mesh is swapped in before the queued one builds, so a fast
  mover cannot starve a band. `make_bands` runs without a rebase driver too.
- Playtest bot (#493, #444): the bot stops writing `_carcasses[cid].position`, and the
  `out_of_range` retry goes. `_harvest_after_kill` shares one deadline across tries.
  `_bands_ready_after` waits only for bands whose origin changed, and `_far_peak_attempt` needs a
  minimum rock/snow share, not any coloured pixel.
- Leftovers: the dead `"harvest": 1.0` entry in `ACTION_DECREMENT` goes.

**Acceptance criteria:**
- [x] #444, #464 and #493 are closed: every item is fixed by a merged PR or closed with a reason (the table
  below; the issues close when the PR merges).
- [x] Suite: a creature at chunk 312,500 steps toward and flees from a target with the same heading,
  within 0.1°, as the same layout at the origin.
- [x] Suite: `creatures_in_radius` finds a creature across a chunk seam at chunk 312,500, and a
  fold-log replay there restores the exact `{chunk, local}`.
- [x] Suite: a snapshot entry with an implausible position still applies HP, state and death. A
  save or wire entry with a huge chunk or a NaN local is rejected.
- [x] Suite: a failed send leaves `records_sent` unchanged and the next delta carries the omitted
  records; `send_snapshot` stops at the first failure.
- [x] Suite (audit): `net_harness.gd` never calls `_networking.send_snapshot`, nothing outside
  `_store_pos` writes a creature's position, and `playtest_bot.gd` never writes `_carcasses`.
- [x] Harness: `creature_far_delta`'s host half asserts the delta reached the client through the
  broadcast and AOI path.
- [ ] Playtest: `fight` and `far_peak` pass 5 runs in a row on an unchanged commit (CI's runs on this PR;
  local runs cannot judge it, they have no Xvfb).
- [x] Suite green on both boot paths, harness green (local: 71,318 of 71,321; the three were two line
  caps, fixed, and `terrain: a new record schedules exactly one ring rebuild`, which fails the same way
  on `main` on this machine; harness 41/41).

**Items and how each was settled:**

| Issue | Item | Outcome |
|---|---|---|
| #464 | `_step_toward` / `_flee` heading from float32 positions | Fixed: the heading is `WorldPos.offset_between` from the creature's `{chunk, local}` to the target's. The AI reads exact targets (`player_exact_targets`, wired to `PeerWiring.player_exact_targets`); a chase stops on the exact gap, and a flight's goal is the creature's exact position plus `FLEE_LEAD`. |
| #464 | death fall `fall_from` is a scene vector | Fixed: stored as an exact position and re-projected each frame (`CreatureVisuals.fall_start`). |
| #464 | `fold_contents` folds float32 metres | Fixed: `TerrainSlice.fold_world_pos_like` on `pos` and `spawn_exact`; held deaths fold their wire `{chunk, local}`. |
| #464 | `position` writable directly | Fixed: `_store_pos` / `_store_spawn` are the only writers (record literals no longer set a position); an audit test holds the slice and the creature, bot and harness files to it. |
| #464 | `creature_far_delta` host half reports success unconditionally | Fixed: the host emits `creature_state_changed`, the networking slice relays it through `broadcast_aoi`, and the step passes only when `aoi_deliveries` counted both packets for the peer. |
| #464 | fold-log replay, spatial hash, `creatures_in_radius` on float metres | Fixed: `ExactSpatialHash` (cells from integer chunk arithmetic, distances from `offset_between`); `_to_local_frame` replays folds on the exact pair; `creatures_in_radius` / `nearest_creature` take an exact position (a Vector3 is still accepted). |
| #464 | `_entry_pos` skips `is_plausible_pos` | Fixed: both forms pass `WorldPos.is_wire` and then `is_plausible_pos`. |
| #493 | an entry with a bad position drops its hp, state and death | Fixed: the fields apply to a known instance in place; a held death is kept with no position (saved without one). |
| #493 | bot rewrites `_carcasses[cid].position`; `out_of_range` retry | Fixed: the bot holds still before the kill so the body lands where it rests, pins chances through `CarcassSlice.pin_entry_chances`, and retries only `damaged` / `moved`. An audit forbids `_carcasses` in the bot. |
| #493 | harness calls `_networking.send_snapshot` | Fixed: both calls go through `SnapshotWiring.send_snapshot` (audited). |
| #493 | legacy-array branch hand-rolls validation | Fixed: `WorldPos.is_wire` (every element a finite number). |
| #493 | `_hold_death_record` recomputes `_entry_pos` | Fixed: it takes the validated position. |
| #493 | `send_snapshot` keeps sending after a drop | Fixed: it returns at the first dropped chunk. |
| #444 | `_bands_ready_after` waits for every band | Already fixed on `main`: it waits only for bands whose origin moved. |
| #444 | `NO_GEOMETRY_ARRAYS` shared dictionary | Already gone (#447). |
| #444 | `_far_peak_attempt` passes on any band pixel | Fixed: `far_peak_passes` needs `FAR_PEAK_MIN_PX` rock/snow pixels and a `FAR_PEAK_MIN_ROCK_SHARE` (10%) share; a run at the pinned seed saw 486 of 904. |
| #444 | `_harvest_after_kill` tries outrun the step timeout | Already fixed on `main`: one deadline across tries. |
| #444 | `records_sent` advances when the snapshot is built | Fixed: the build stages the table and `send_snapshot` commits it only when the snapshot went out whole; a drop leaves it unchanged, so the next delta carries what the dropped one held. |
| #444 | `_drop_in_place` lags the carrier | Fixed: the body goes down at the carrier's host position when it is known and within the leash; past the leash (a teleport) it stays put, so a drop still cannot carry it. |
| #444 | `distant_bands.poll` discards a superseded mesh | Already fixed on `main`: it swaps in, then builds the queued request. |
| #444 | `bands.update` allocates per frame | Already fixed in Phase 194: compared before a request is built. |
| #444 | `relay_batch.build` re-queries held subjects | Fixed: a held report keeps the recipients it was queried with until it is due. |
| #444 | `flush_relays` / `aoi_recipients` rebuild the peer set | Fixed: `Transport.peer_set()` is rebuilt only when the peer list changes, and both use it. |
| #444 | `ACTION_DECREMENT["harvest"]` dead data | Fixed: removed; a harvest wears by the default (the test now asserts that). |
| #444 | `make_bands` only with a rebase driver | Already fixed on `main`. |
