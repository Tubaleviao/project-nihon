# Roadmap history — Phase 160

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 160 — Harvesting in the fabric: tools, the Skinning skill, carcass weight and carry

**Goal:** today a dead creature drops its finished resources at once (`LootSlice._on_creature_died`
rolls the `drops` table). It should be a body that a player works: a skinning knife takes the pelt
and meat, a hammer or bone saw takes the bones, and a better skinner gets more and better material.
A player without the tool can carry the body somewhere else, if it is light enough for them. This
phase models all of that in the fabric. It is the fabric half of Phase 161 (separate PR, per
CLAUDE.md).

**Newel dependency:** NO (new fields and entities with existing types).

**Depends on:** none.

**Deliverables:**
- Harvest tables replace drop tables: each creature's `drops` entry gains a `tool` (a harvest tool
  category: `knife`, `bonetool`, `none` for things picked straight off the body, like feathers) and
  a `skill` (`Skinning` for all of today's creatures). Quantity becomes skill-scaled: `minQty` at
  level 0 rising to `maxQty` at the cap, with `chance` also rising with level. The loot docs and the
  wiki describe the new table.
- Items: `SkinningKnife` and `BoneSaw` (with recipes and technology gates that fit the existing
  tree), each with a `harvestTool` category. Existing tools may also qualify (an axe as a poor
  `bonetool`) through an `efficiency` value below 1.0.
- A `Skinning` skill (new `fabric/gameplay/skills/survival.js`, or in `exploration.js`): levels,
  the XP a harvest grants, and the bonus per level. The skill entity says how level maps to yield and
  quality.
- Resource quality: raw creature materials (`*_hide`, `*_pelt`, `*_meat`, `*_bone`, …) get a
  `quality` grade (`poor`, `common`, `fine`, `prime`) chosen by Skinning level and tool efficiency.
  The grade is item data (an instance property, like durability), not a new item id per grade, so
  recipes keep working. Where a recipe should care about grade, that is a later phase.
- Carcass and carry: each creature gets `carcassMassKg` and `corpseSeconds`. The player gets a
  `carryCapacityKg` (base value in `fabric/gameplay/player.js`). There is no strength attribute yet,
  so capacity is a fixed base plus a bonus from a skill or worn gear (a pack frame or yoke item, to be
  decided in the PR). Carrying a body over half the capacity slows walking. Bodies over the capacity
  can be dragged (slower) or not moved at all (bison, large void creatures), as the fabric says per
  creature.
- `validate` rejects a harvest entry whose tool category no item provides, a creature without
  `carcassMassKg`, and a quality table that does not cover every level.
- Generated resources updated. `npm run generate` and `check-drift` are clean.

**Acceptance criteria:**
- [x] `pnpm validate` passes, and fails on a fixture harvest entry with `tool: 'spoon'` and on a
  creature without `carcassMassKg`.
- [x] Suite: `GameData` lists, for each creature, its harvest entries with tool and skill; every
  creature that had a drop table keeps at least the same items.
- [x] Suite: `SkinningKnife` and `BoneSaw` exist, are craftable and carry their `harvestTool`.
- [x] Suite: the Skinning yield and quality tables are monotonic in level (a higher level never
  gives less).
- [x] `check-drift` clean.

**Decisions made in the PR:**
- Harvest tables stay in each creature's `drops` field (the runtime already reads it); every entry gains
  `tool` and `skill`. Rules and curves live in `fabric/gameplay/harvest.js`; `Skinning` is in
  `fabric/gameplay/skills/survival.js`.
- Skinning has levels 0..10. Yield, chance, quality and XP are tables indexed by level; effective level
  is `floor(level * tool efficiency)`. The CarpenterAxe is a 0.5-efficiency `bonetool`.
- Carry capacity is a fixed base (`PlayerCharacter.carryCapacityKg` = 40) plus
  `HarvestRules.carryBonusPerSkinningLevelKg` per Skinning level. No pack-frame item yet.
- Each creature has a `carryRule`: `carry` (within the base capacity), `drag` (up to capacity times
  `dragCapacityFactor`) or `immovable`; `validate` checks the mass fits the rule.
- `SkinningKnife` and `BoneSaw` reuse the `sword` archetype at a smaller scale and are unlocked by
  `TechBasicSmithing`.
- `node tools/check_harvest.js` (CI) proves the validator rejects a bad tool, a missing carcass mass,
  and tables that skip or fall with a level.

