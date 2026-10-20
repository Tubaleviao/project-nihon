# Roadmap history — Phase 161

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 161 — Harvesting at runtime: work the body, carry it home

**Goal:** turn the Phase 160 model into play. A kill leaves a body. The player harvests it with the
right tool, gets yields and quality from their Skinning level, or picks the body up and carries it.

**Newel dependency:** NO.

**Depends on:** Phases 156 (the tool swing), 157 (the body stays), 160.

**Deliverables:**
- `src/loot/carcass_slice.gd` (new) with wiring: on `creature_died` the host creates a carcass
  record (creature type, landing position, the remaining harvest entries, owner/killer, expiry from
  `corpseSeconds`) instead of rolling the drop table. Carcasses are host-owned, synced to the AOI,
  bounded per region (oldest decays first) and saved with the region so a body left at the camp
  survives a restart until it expires.
- Harvest: `harvest_intent(carcass_id)` checked on the host — in range, the player's main hand
  provides a tool category that some remaining entry needs (no tool → only `none` entries). A timed
  action (the `attack_tool` or a `harvest` kneel clip loops while it runs, cancelled by moving or
  damage). On completion the host rolls quantity and quality from the player's Skinning level and
  the tool's efficiency, puts the items in the inventory (or on the ground when full), removes those
  entries from the carcass, uses tool durability, and grants Skinning XP. A carcass with nothing left
  is removed.
- A minimal per-player skill level store for Skinning (host-owned, persisted on the player record).
  If a general skill-progression system lands first, this uses it instead.
- Carry: `carry_intent(carcass_id)` succeeds when `carcassMassKg` is within the player's
  `carryCapacityKg` (or drag rules allow it). While carrying, the body is attached to a back or
  shoulder socket (or dragged behind for drag), the player cannot attack or harvest, walk speed is
  reduced per the fabric, a `carry` locomotion layer plays, and `drop_intent` places the body where
  the player stands. Death drops the body. The host owns the carcass position at all times.
- UI: the carcass shows a prompt with what can be harvested with the current tool and what is
  missing ("needs a knife"), all through `tr()` in `en` and `pt_BR`.
- `LootSlice` keeps spawning world pickups for player-dropped items. Its death path goes away.
- The playtest bot's `fight` step is extended: kill, harvest with a knife, check the inventory.

**Acceptance criteria:**
- [x] Suite: a kill creates a carcass and no immediate pickups.
- [x] Suite: harvesting with a knife yields the knife entries only; the bone entries stay until a
  `bonetool` harvests them; with an empty hand only `none` entries come out.
- [x] Suite: at Skinning 0 and at the cap, the same seeded harvest gives the table's min and max
  quantity and the lowest and highest grade; harvesting grants XP and wears the tool.
- [x] Suite: the host refuses a harvest out of range, with a tool the player does not hold, on a
  carcass that is already empty, and a carry over capacity (trust boundary).
- [x] Suite: carrying sets the walk speed multiplier from the fabric, blocks attack and harvest, and
  dropping the carcass places it at the player's position; dying while carrying drops it.
- [x] Suite: a carcass expires after `corpseSeconds`, and a region saved with a carcass restores it.
- [x] Harness step `carcass_synced`: a carcass harvested on the host loses those entries on the
  client, and a carried carcass follows the carrier on the other client.
- [x] Playtest bot: the `fight` step ends with the harvested items in the inventory.
- [x] Suite green on both boot paths, harness green.

**As built:** carcasses persist in the world record (`carcasses`, with each body's remaining time) rather than
in the per-region voxel files; the per-region cap is enforced by region key. The harvest tool is the worn
`MainHand` item or else the best held item providing the category (the knife and saw have no equipment slot).
The grade is rolled and reported in the `harvest_resolved` result; storing it as an inventory instance
property is left to the later phase that makes recipes care about grade.
The kneel/harvest clip, the `carry` locomotion layer and the back/shoulder socket need art and rig work and are
not built: a harvest shows only its prompt and result message, and a carried body is a placeholder box that
follows the carrier. Progress feedback for remote clients (`harvest_started` is host-only) goes with them.
