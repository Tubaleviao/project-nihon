# Roadmap history — Phase 203

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 203 — Clans, ownership, durability, writing, chests and tall structures in the fabric ✅ Done

**Goal:** every rule and number of this arc, modelled in the fabric with validators, before any
GDScript. A fabric design PR only, separate from the implementation phases.

**Newel dependency:** NO.

**Depends on:** Phase 198.

**Deliverables:**
- **Clans.** A `Clan` with a player-chosen name (length, allowed characters, unique, moderated as
  chat is), a founder, members, invites and roles. A player is in at most one clan. Members see each
  other's skills. A clan has no hearth. Clan tiers: the score from every building a clan owns,
  wherever it stands, and their material rarity, with the thresholds per tier. A tier gives nothing
  yet.
- **Structures and ownership.** A structure is a connected set of placed blocks, assigned when
  built to its builder (private) or the builder's clan. Only the owner (the player, or any member
  for a clan structure) may place, reshape or take stations on it, anywhere in the world. A
  member's private structure inside their clan's territory (its circles) can also be entered and
  dismantled by any member of that clan. Anyone else may only damage it. Each owner keeps their own
  blocks where two structures touch. The `Settlement` claim fields (`tiers.claimRadius`,
  `decayRadiusPerDay`, `minSeparation`), the hearth, `SettlementRaids`, `SettlementUpkeep`, project
  `effects` and the hearth-site research rule (Phase 140 `materialSource`) are removed.
- **The circle.** One radius per structure from its footprint and height, with a minimum for a
  single block or station and a maximum. Inside it no creature spawns, and inside a clan's circles
  only that clan's members may start a structure (clan or private).
- **Durability and destruction.** A base durability per material, ranked by rarity (a validator: a
  rarer material never has less). Loss rates per weather condition (the Phase 128 weather states),
  per day of age, and per point of damage. A table of destruction methods (tools and weapons now,
  room for more later), each with its damage rate and an offline factor that makes destroying a
  structure whose owners are all offline very slow (for a clan structure: every member offline). A
  destroyer gets nothing from a structure's blocks.
- **Repair.** The owner restores durability by spending a share of the structure's build materials,
  in proportion to the durability restored.
- **Respawning at will.** Any player may kill their own character to respawn at their bed or the
  world spawn, with the normal death rules, so no one can be trapped inside another's structure.
- **Dismantling.** The share of materials returned to the dismantler as a function of durability
  fraction and their building skill: 100% at full durability with a very high skill, 50% at full
  durability with no skill, falling with durability. A validator checks those two points and that
  the share never rises as durability falls.
- **New skills.** Building (the engineering skill dismantling reads), Tailoring (sewing) and
  Lockpicking, each with its XP curve.
- **Work and skills.** A map from each kind of work (each crafting recipe kind, gathering,
  building, dismantling, repairing) to the skill it grows, and the XP per action. Nothing gives a
  clan progress. `SettlementProjects` loses its labour: no `steps`, work units, tools or
  `SITE_RADIUS`. A project is complete once its materials are in.
- **Chests and doors.** `Chest` and `Door` stations with an access mode (`owner`, `clan`,
  `everyone`), set only by their owner. Lock durability and lockpicking difficulty come from the
  material and a technology. A destroyed chest spills its contents for anyone to take.
- **Writing.** A `Book` that teaches one researched technology and a `Blueprint` that teaches one
  structure or station recipe. Only a player who knows the content can write one, at a material
  cost. Reading never consumes it, so it can be read again and lent.
- **Heights and floors.** `WorldSystem.maxHeight` about 8,850 m, and a build ceiling (moved from
  `VoxelConsts.MAX_HEIGHT` into the fabric) above the highest peak plus the tallest structure.
  `Structure.floorHeight` 3 m (24 blocks), `Structure.maxFloors` 163, and a structural class with
  its own `maxFloors` on every buildable material: wood 2, stone 5, concrete 10, higher classes up
  to 163. Material `hardness` mixes a Janka scale (woods) with a Mohs scale (stones, metals), so it
  cannot rank strength: the class is a new field.
- **Shapes.** Measures of how unusual a shape is (overhang reach, unsupported span, height to
  footprint), each with the lowest structural class allowed past each threshold.
- `check_*.js` tools proving each new validator rejects a bad table, each with a CI step.
- The floor and shape limits apply to every structure. Builds that exist when the rules land are
  never collapsed (stable-world rule).
- **Saved settlements.** Each becomes a clan with the same name, members and roles. Its hearth is
  removed (its block returned to the founder) and its stockpile becomes a clan chest.
- The owner's decisions (2026-10-31) are recorded as `decisions.js` entries.

**Acceptance criteria:**
- [x] `npm run validate` and `npm run check-drift` pass. Every new validator has a `check_*.js`
  that rejects a bad table, and CI runs it.
- [x] The fabric has no claim radius; the floor limits wood 2, stone 5 and concrete 10 with a top
  class of 163; dismantling returns 100% and 50% at the two fixed points.
- [x] Every kind of work maps to a skill, and a validator rejects one that does not.
- [x] The fabric has no project labour (`steps`, work units, `SITE_RADIUS`), raids or upkeep.

**As built:**
- New fabric modules: `fabric/gameplay/clan.js` (`Clan`, `ClanTiers`), `structure.js` (`Structure`,
  `StructureDurability`, `SelfRespawn`), `chests.js` (`ChestsAndDoors`), `writing.js` (`Book`,
  `Blueprint`, tagged `writing` → `GameData.WRITINGS`) and `work.js` (`WorkSkills`). Materials carry
  `rarity`, `durability` and `structuralClass` (`fabric/world/materials/structural.js`). The skills
  Building, Tailoring and Lockpicking have XP curves and icons. Five owner decisions of 2026-10-31
  are in `decisions.js`; `SettlementClaimAndDecay` and `SettlementRaidsAndUpkeep` are superseded.
- Validators with `tools/check_clan.js`, `check_structure.js`, `check_work.js`, `check_chests.js`
  and `check_writing.js`, each a CI step; `check_settlement.js` and `check_settlement_loop.js`
  now reject claim fields, labour, effects, raids and upkeep.
- Chests, doors, books and blueprints are rule tables, not items yet: Phases 208 and 209 add the
  placeable stations and items with their placeholders.
- The settlement hearth stays (a `Hearth` item and the `hearthStation`/`hearthItem` fields) until
  Phase 204 migrates settlements to clans. That migration hands each hearth back to its founder as
  an item.
- Runtime holds keep today's behaviour until the runtime phases remove them. Each one is listed in
  the phase that removes it: `SettlementSlice.DEFAULT_RULES` claim values (205),
  `ProjectRules.LABOUR_HOLD` (205, 207), `TechnologySlice.STOCKPILE_RESEARCH_HOLD` (209) and
  `WorldShape.PEAK_HOLD` (211). No world-gen output changed, so `WORLDGEN_VERSION` is unchanged.

