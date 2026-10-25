# Roadmap history — Phase 178

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 178 — Attributes at runtime: host-owned, persisted, feeding the derived stats

**Goal:** make Phase 177 real. The host owns every player's attributes, derives their stats from
the fabric table, persists them, and grows them from skill XP. The client only displays them.

**Newel dependency:** NO.

**Depends on:** Phase 177.

**From Phase 177:** the tables are `GameData.ATTRIBUTES["AttributeSystem"]` (`derivation`, `growth`,
bounds). The formula, every stat id and the growth rule are in
[phases-177.md](docs/roadmap-history/phases-177.md#as-built). `CarcassRules.base_capacity_kg()`
reads the Strength row's base until this phase derives carry capacity per player.
`detectionRadiusMetres` (32 m at base) is new: the minimap draws no creatures or deposits yet.

**Deliverables:**
- `src/character/attribute_rules.gd`: pure functions for deriving stats and applying growth, read
  from `GameData`.
- The host stores attributes on the player record. A save from before this phase loads with base
  10 in everything (versioned migration, as in Phase 121).
- Carry capacity, max HP and regeneration, damage reduction, status-effect rolls, attack interval,
  research gain, gather yield, harvest quality and minimap detection radius read the derived stats.
- `attributes_synced` goes to the owning client only, and peers get only what they need to draw.
  The client sends no attribute values. The host ignores and rate-limits any attempt.
- Skill XP grants feed attribute growth on the host, with the cap enforced.

**Acceptance criteria:**
- [x] Suite: each derived stat equals the fabric formula at the minimum, base and maximum.
- [x] Suite: growth from XP follows the table, has diminishing returns and stops at the cap.
- [x] Suite: a pre-178 save loads with base attributes and the same carry capacity and max HP as
  before.
- [x] Harness: `attributes_synced` reaches the owner over the socket. A client payload carrying
  attribute values is refused and counted.
- [x] Suite green on both boot paths, harness green.

---

### As built

**Rules.** `src/character/attribute_rules.gd` (pure, static): `stat(stat_id, attributes)` is the fabric formula,
`sanitize` bounds a saved or wire table to creation-min..hard-cap, `grow(attributes, growth, category, xp)` feeds
skill-category XP into the weighted attributes (cost `xpPerPoint * (1 + costStep * grown)`, hard cap per attribute,
`totalPointsCap` overall; an attribute that cannot grow banks nothing).

**Record.** `PlayerRegistry` keeps `attributes` (`{ attribute: int }`) and `attribute_growth` (`{ points, xp }`) on
the player record. A pre-178 save has neither key and loads at base 10 (so carry capacity 40 kg and max HP 100,
exactly as before). `grant_skill_xp(player_id, skill, amount)` is the one host door: it adds the XP, grows the
attributes by the skill's category (magic XP is first scaled by `magicXpFactor`) and emits
`GameBus.attributes_synced(player_id, attributes)` when a point was gained. A non-authoritative registry refuses.
Harvesting (Skinning, survival) is the only skill XP source today; the door is ready for the others.

**Skill category fix.** The skill files named their category only in a description, so every generated skill read
as category 0 (combat). Each skill now sets `defaultValue` to its category, and the generated resources carry it.

**Wire.** `attributes_synced` goes to the owner only, on the existing owner-only own-state channel (`attributes`
key), and in the join snapshot's own record. Other peers get nothing: no remote avatar draws an attribute. The
client replaces its display copy (`PlayerSlice.set_attributes`, which also moves `max_hp`). A client packet that
carries `attributes`, `attribute_growth`, `attribute_xp` or is of type `attributes_intent` is refused whole and
counted in `NetworkingSlice.attributes_refused` (warning throttled per peer, the general per-peer token bucket
still applies).

**Consumers (host-side, read from the player's record).**

| Stat | Read by |
|---|---|
| `carryCapacityKg` | `CarcassWiring.capacity_of` → `CarcassRules.capacity_kg(level, base_kg)` for carry, drag and the slowdown |
| `moveSpeedFactor` | `PlayerSlice` walking speed and the carry speed cap (`CarcassWiring.carry_rate`) |
| `maxHp` | `PlayerSlice.max_hp`, `PlayerRegistry.max_hp_of` (peer hits, respawn, admin heal, gesture regen) |
| `hpRegenPerSecond`, `restRegenFactor` | `GestureWiring` rest regeneration |
| `damageReduction`, `dodgeChance`, `statusChanceFactor`, `statusDurationFactor`, `staggerResistChance` | `BattleSlice.resolve_round` against a player target (via `player_stat_fn`) |
| `meleeDamageFactor` | `BattleSlice.resolve_round` for a player attacker |
| `researchGainFactor` | `TechnologySlice.grant_points` |
| `gatherYieldFactor`, `harvestQualityBonus` | `CarcassSlice.resolve_harvest` |
| `magicXpFactor` | `PlayerRegistry.grant_skill_xp` |
| `detectionRadiusMetres` | `PlayerSlice.stat(...)`; the minimap draws no creatures or deposits yet |

**Not wired (no runtime to read them yet).** `attackIntervalFactor` (a player's melee has no cadence), `gatherSpeedFactor`
(mining and chopping are instant), `knockbackDealtFactor` (the player has no knockback), `craftQualityChance` (crafts
have no quality grade). Each is derived and tested as a stat; the system that consumes it is a later phase's job.

**Tests.** `attribute_tests.gd`: the formula at min/base/max of every row, growth (cost, diminishing returns, both
caps, bad input), sanitising, a legacy save, registry growth and persistence, the consumers, and the refused claim.
Harness step `attributes_synced`: the owner's client receives the grown table over the socket and its `max_hp`
follows; a packet claiming attribute values is refused and counted, and the record is unchanged.
