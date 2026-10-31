# Roadmap history — Phase 200

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 200 — Raids: a warned, bounded attack the village can defend ✅ Done

**Goal:** a settlement worth raiding is attacked by a creature pack from its biome. Members get a
warning, fight at the claim edge, and the palisade and watchtower help. A lost raid costs a capped
share of the stockpile. A raid never starts while no member is online inside the claim.

**Newel dependency:** NO.

**Depends on:** Phases 192, 197 and 198.

**Deliverables:**
- `src/settlement/raid_rules.gd`: pure eligibility (age, value floor, cooldown, a member online in
  the claim), pack choice per biome, and outcome resolution.
- A host raid scheduler that checks eligibility on the settlement tick. A raid sends a keyed
  warning to online members, then spawns the pack at the claim edge, using the existing pack AI with
  the hearth as its goal. Defence effects from completed projects apply.
- Outcome: all raiders killed or driven off is a defended raid, with ordinary loot from the
  bodies. Raiders that reach the hearth take the capped stockpile share and damage unfinished
  projects. The cooldown and the last result are persisted.
- `/raid` admin command (Phase 182) to start a raid on the admin's settlement, for tests and the
  Phase 202 run.
- UI: the warning, a raid marker on the map and minimap, and the result in the settlement panel.

**Acceptance criteria:**
- [x] Suite: `raid_rules` starts no raid with no member online in the claim, before the minimum
  age, under the value floor, or inside the cooldown.
- [x] Suite: a lost raid takes at most the fabric's loss share, and a defended one takes nothing.
- [x] Suite: a palisade or watchtower changes the raid as its fabric effect says.
- [x] Suite: the cooldown and last result survive a save and reload.
- [x] Harness: a `settlement_raid` step. `/raid` warns both clients, the pack spawns at the claim
  edge, the clients kill it, and the raid resolves as defended on both.
- [x] Every new string is in both catalogs, and the i18n key check passes.
- [x] Suite green on both boot paths, harness green, and the stress `cluster` crowd stays at or
  above its baseline with a raid running.
