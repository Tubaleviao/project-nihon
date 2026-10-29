# Roadmap history — Phase 185

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 185 — The bed is the spawn point: host-owned, persisted, one per player ✅ Done

**Goal:** today a player always respawns at the original spawn (Phase 66). Placing a bed moves
their spawn point to the bed. The host owns it.

**Newel dependency:** NO.

**Depends on:** Phase 184.

**Deliverables:**
- The host records a `bed` entry on the player record (`{chunk, local}` exact position, Phase 87)
  when that player places a bed. Placing a second bed removes the first one, which drops back as an
  item. `GameRoot.respawn_point_for()` prefers the bed, then the original spawn, then the saved
  position.
- A bed whose block is destroyed, whose chunk is regenerated (Phase 182 `/regen world`), or which is
  removed by someone allowed to build there clears the entry. The owner gets a keyed notice
  (`bed.lost`) and respawns at the original spawn.
- Respawn at a bed whose spot is now blocked picks the nearest free standing cell within a bounded
  radius. If there is none, the original spawn.
- The host validates the placement: the player holds a bed, the target is in reach and allowed by
  settlement build rules, and the space is free. Other players cannot use or claim someone else's
  bed. The intent is rate-limited, and a refusal returns a keyed reason.
- The bed's position syncs to its owner only (`bed_synced`), so the map can mark it. Peers see the
  bed as an ordinary placed station.
- A save from before this phase loads with no bed and the old respawn rule (versioned migration, as
  in Phase 121).

**Acceptance criteria:**
- [x] Suite: with a bed, `respawn_point_for()` returns the bed; without one, the original spawn; a
  pre-185 record loads with no bed and the same respawn point as before.
- [x] Suite: a second bed replaces the first and returns it as an item; a destroyed bed clears the
  entry and emits `bed.lost`; a blocked bed respawns at the nearest free cell.
- [x] Suite: the host refuses a bed placement without a bed in the inventory, out of reach, in a
  settlement the player cannot build in, and a placement on another player's bed, each with its own
  key.
- [x] Harness: a client places a bed over the socket, dies and respawns at the bed; a second client
  never receives the first one's `bed_synced`.
- [x] Every new string is in both catalogs, and the i18n key check passes.
- [x] Suite green on both boot paths, harness green.
