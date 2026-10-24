# Roadmap history — Phase 177

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 177 — Attributes in the fabric: strength, vitality, resistance, agility, intelligence, perception

**Goal:** the character has no attributes. Carry capacity is a fixed base (Phase 160), HP is a flat
100, and nothing distinguishes one character's body from another's. Model a small attribute set
that feeds systems that already exist. There are no classes and no levels: attributes start from
character creation and grow slowly from use, in keeping with the sandbox constitution.

**Newel dependency:** NO.

**Depends on:** Phase 173.

**Deliverables:**
- `fabric/gameplay/attributes.js` (new): an `AttributeSystem` entity with six attributes and their
  bounds (base 10, creation range 5–18, hard cap 30). Each attribute lists what it feeds:
  - **Strength**: carry capacity (replaces the fixed Phase 160 base), melee damage, knockback
    dealt, mining and chopping speed.
  - **Vitality**: max HP, HP regeneration, rest regeneration (Phase 158 gestures).
  - **Resistance**: damage reduction, status-effect chance and duration (Phase 129), knockdown
    and stagger resistance.
  - **Agility**: movement speed (small), attack interval, dodge chance against a melee hit.
    Knockdown and stagger belong to Resistance alone.
  - **Intelligence**: research point gain (Phase 124), the chance of a quality grade on a craft,
    XP rate for magic skills.
  - **Perception**: gather yield, the harvest quality grade (Phase 161), the radius at which
    creatures and deposits show on the minimap.
- A derivation table: each derived stat as a base plus a per-point slope with a clamp, so a
  20-point gap is noticeable but never a one-shot. The table is data, not code. At base 10 in
  every attribute, each derived stat equals today's constant (`BASE_CARRY_CAPACITY_KG` 40 kg,
  `PlayerRules.MAX_HP` 100, and so on), so existing characters do not change on migration.
- A growth table: skill XP from each skill category feeds weighted attributes (combat → Strength
  and Agility, crafting → Strength and Intelligence, exploration → Perception and Agility,
  survival → Vitality and Perception, magic → Intelligence and Resistance, social → Perception)
  with diminishing returns and a total-points cap. Every category in the skill enum has a row.
  Growth comes from use, not from spending points.
- `PlayerCharacter` gains `attributes` (json) and drops the fixed `carryCapacityKg` default in
  favour of the derivation. `HarvestRules` in `fabric/gameplay/harvest.js` stops reading
  `defaults(PlayerCharacter).carryCapacityKg` and takes its base from the derivation at base 10.
- `tools/check_attributes.js` in the style of `check_combat.js`: bounds are consistent, every
  derived stat it names exists, the extremes (all 5s, all 30s) stay inside each stat's clamp,
  base 10 reproduces today's constants, and every skill category has a growth row.
- Display names and descriptions are UI catalog keys (`attr.<id>.name`, `attr.<id>.desc`) in
  `en` and `pt_BR`.

**Acceptance criteria:**
- [x] `npm run validate`, `npm run check-drift`, `node tools/check_attributes.js` and the
  harvest check pass.
- [x] Generated `GameData` exposes the attribute set, the derivation table and the growth table.
- [x] Every attribute has `en` and `pt_BR` catalog entries, and the i18n key check passes.

---

### As built

**Where it lives.** `GameData.ATTRIBUTES["AttributeSystem"]` (tag `attribute`), fields `attributes`
(ids in display order), `base`, `creationMin`, `creationMax`, `hardCap`, `derivation` and `growth`.
`fabric/index.js` runs `validateAttributes` at load, so a bad table fails `npm run validate`.

**Formula.** For a stat fed by attribute value `v`, with `d = v - base`:
`stat = clamp(statBase + (d < 0 ? perPointBelow : perPoint) * d, min, max)`. `perPointBelow` is
`perPoint` unless set; 0 means a low attribute cannot push a stat below today's number (a chance
that is 0 today never goes negative). Each row has a `kind`: `amount` (absolute, in `unit`),
`factor` (multiplies today's number; 1 at base), `chance` (added probability; 0 at base) or `bonus`
(added to a level; 0 at base).

| Attribute | Derived stat | Kind | At 10 | Per point | At 5 | At 30 | Clamp |
|---|---|---|---|---|---|---|---|
| Strength | `carryCapacityKg` | amount (kg) | 40 | +2 | 30 | 80 | 25–85 |
| Strength | `meleeDamageFactor` | factor | 1 | +0.02 | 0.9 | 1.4 | 0.85–1.45 |
| Strength | `knockbackDealtFactor` | factor | 1 | +0.02 | 0.9 | 1.4 | 0.85–1.45 |
| Strength | `gatherSpeedFactor` (mining, chopping) | factor | 1 | +0.015 | 0.925 | 1.3 | 0.9–1.35 |
| Vitality | `maxHp` | amount (hp) | 100 | +5 | 75 | 200 | 70–210 |
| Vitality | `hpRegenPerSecond` | amount (hp/s) | 0.25 | +0.0125 | 0.1875 | 0.5 | 0.18–0.55 |
| Vitality | `restRegenFactor` (gesture `restRegen`) | factor | 1 | +0.02 | 0.9 | 1.4 | 0.85–1.45 |
| Resistance | `damageReduction` | chance | 0 | +0.01 | −0.05 | 0.2 | −0.06–0.22 |
| Resistance | `statusChanceFactor` | factor | 1 | −0.015 | 1.075 | 0.7 | 0.65–1.1 |
| Resistance | `statusDurationFactor` | factor | 1 | −0.015 | 1.075 | 0.7 | 0.65–1.1 |
| Resistance | `staggerResistChance` (knockdown, stagger) | chance | 0 | +0.01 (0 below) | 0 | 0.2 | 0–0.22 |
| Agility | `moveSpeedFactor` | factor | 1 | +0.005 | 0.975 | 1.1 | 0.97–1.12 |
| Agility | `attackIntervalFactor` | factor | 1 | −0.01 | 1.05 | 0.8 | 0.78–1.06 |
| Agility | `dodgeChance` (melee) | chance | 0 | +0.005 (0 below) | 0 | 0.1 | 0–0.12 |
| Intelligence | `researchGainFactor` | factor | 1 | +0.025 | 0.875 | 1.5 | 0.85–1.55 |
| Intelligence | `craftQualityChance` | chance | 0 | +0.01 (0 below) | 0 | 0.2 | 0–0.22 |
| Intelligence | `magicXpFactor` | factor | 1 | +0.02 | 0.9 | 1.4 | 0.85–1.45 |
| Perception | `gatherYieldFactor` | factor | 1 | +0.015 | 0.925 | 1.3 | 0.9–1.35 |
| Perception | `harvestQualityBonus` (Skinning levels) | bonus | 0 | +0.1 | −0.5 | 2 | −0.6–2.2 |
| Perception | `detectionRadiusMetres` | amount (m) | 32 | +1.6 | 24 | 64 | 24–68 |

`detectionRadiusMetres` has no constant to reproduce: the minimap draws no creatures or deposits
today, so 32 m is the new baseline Phase 178 introduces.

**Growth.** `xpPerPoint` 600, `costStep` 0.25, `totalPointsCap` 40. XP in a skill category is split
over its weighted attributes (weights sum to 1). An attribute that has grown `g` points needs
`xpPerPoint * (1 + costStep * g)` weighted XP for its next point. Growth stops at `hardCap` per
attribute and at `totalPointsCap` across all six.

| Category | Weights |
|---|---|
| combat | Strength 0.5, Agility 0.5 |
| crafting | Strength 0.5, Intelligence 0.5 |
| exploration | Perception 0.5, Agility 0.5 |
| survival | Vitality 0.5, Perception 0.5 |
| magic | Intelligence 0.5, Resistance 0.5 |
| social | Perception 1.0 |

**The checks.** `attributeProblems` (shared by `fabric/index.js` and `tools/check_attributes.js`)
rejects: bounds out of order; a stat naming an unknown attribute or an unknown kind; a zero slope or
a below-base slope of the opposite sign; a factor whose base is not 1, a chance or bonus whose base is
not 0, an amount whose base is not today's constant; the creation minimum or the hard cap leaving a
stat's clamp unclamped; a clamp beyond the one-shot limits (factors 0.5–2, chances −0.25–0.5,
amounts 0.5–2.5× today); a stat the hard cap moves by under 5 %; an attribute that feeds nothing; a
missing, extra or unweighted growth row; no diminishing returns; and a total cap the hard cap cannot
hold. The tool also proves every attribute and derived stat has a non-empty `en` and `pt_BR` entry.

**Catalog keys.** `attr.<id>.name` and `attr.<id>.desc` for the six attributes, and `stat.<id>` for
every derived stat (used by the Phase 179 sheet).

**Runtime touch.** `PlayerCharacter.carryCapacityKg` is gone, so `CarcassRules.capacity_kg` now reads
its base from `CarcassRules.base_capacity_kg()` (the Strength row's `base`; every character is at base
until Phase 178). Nothing else at runtime reads attributes yet.

**Tests.** `src/tests/suites/attribute_tests.gd`: the tables in `GameData`, coverage (every attribute
feeds a stat, every skill category has a growth row), base 10 equals `PlayerRules.MAX_HP`,
`GestureRules.BASE_HP_REGEN_PER_S` and the carcass carry base, the player's default attributes, and
the catalog entries in every locale.
