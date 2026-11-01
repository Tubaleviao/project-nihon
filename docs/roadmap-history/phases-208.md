# Roadmap history — Phase 208

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 208 — Chests and doors: owner, clan or everyone, and locks that can be broken or picked ✅ Done

**Goal:** a player keeps things in a chest, and a house behind a door, that only they, their clan or
everyone can open. A locked chest or door can still be broken open or picked, harder for better ones.

**Newel dependency:** NO.

**Depends on:** Phases 204 and 205.

**Deliverables:**
- The `Chest` and `Door` stations, a chest's inventory and both access modes on the host. Only the
  owner changes a mode. The host checks every open, take, put and pass against it. A clan member may
  open the doors of another member's private house inside the clan's territory (Phase 205).
- Destroying a chest spills its contents for anyone to take. Lockpicking is a timed action with the Lockpicking skill
  and a tool against the chest's difficulty. Success opens it once, failure can break the tool, and
  the owner is told.
- UI: the chest window, the access-mode setting for the owner, and the lockpicking progress.
- Phase 204 hold: a migrated settlement's stockpile becomes a clan chest with the same contents
  (`Clan.migration.stockpile`); until then it stays in the settlement record.
- Door and chest placeholders in `assets/` (placeholder rule).

**Acceptance criteria:**
- [x] Suite: an owner-only chest refuses a clan member, a clan chest refuses an outsider, and an
  everyone chest opens for anyone. A non-owner cannot change the mode. Doors follow the same rules.
- [x] Suite: a harder chest takes longer to pick and to destroy, and a destroyed chest spills
  everything it held.
- [x] Suite: a picked lock grants the `WorkSkills.lockpick` row to the picker, and `lockpick` is gone
  from `WorkSkills.UNWIRED`.
- [x] Harness: a client's take from a chest it may not open is refused, and the chest is unchanged
  on both peers.
- [x] Every new string is in both catalogs, and the i18n key check passes.
- [x] Suite green on both boot paths, harness green.

**Shipped:**
- Fabric: the `Chest` and `Door` items (station-tagged, carpentry recipes with no station, unlocked by Basic
  Carpentry) and the `Lockpick` tool (`toolType: 'lockpick'`, forge recipe, Basic Smithing).
  `ChestsAndDoors.stations` rows name their `placementItem` and `lockMaterial`, and `locks.toolType` names the
  tool; `tools/check_chests.js` covers the new checks. Placeholder models, icons and texture sheets for all three.
- `src/world/chest_rules.gd` (pure reads), `chest_slice.gd` (the host's chests and doors by station id: owner
  private or clan from the placer's build mode, access mode, items, lock technology and durability) and
  `chest_wiring.gd` (placement attribution, a client's placement through a `place` intent, results as keyed
  system lines, the open chest's view pushed to its player, save and load).
- Access: owner (any member for a clan's), `clan`, `everyone`; a door also lets in whoever
  `StructureSlice.may_enter` lets into the structure under it. Only an owner sets the mode.
- U uses the nearest chest or door, Shift+U picks its lock, Ctrl+U hits it; the host finds which one from
  its own view of the player. A pick takes `pickSeconds × difficulty`, shortened by Lockpicking level, is
  cancelled by moving, and a failure breaks the lockpick with `breakChance / difficulty`; the owner is told
  either way. A finished pick lets the picker in until they close it or walk away and grants the
  `WorkSkills.lockpick` row. A hit is the held pick, axe or hand (from the host's pack) against the lock's
  durability; at zero the station goes and a chest spills everything where it stood.
- A chest keeps stackable things only (like the stockpile: wear would be lost) up to `capacityStacks` stacks.
- World format 5 (`chests`). A record without it turns each migrated settlement's stockpile into a clan chest
  at its hearth (`Clan.migration.stockpile`); a settlement with no hearth position keeps its stock.
- Not done: a closed door does not block movement yet (stations have no collision); the door is an access
  check and a window for its owner.
