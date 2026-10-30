# Roadmap history — Phase 197

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 197 — The settlement loop in the fabric: projects, specialties, raids and upkeep ✅ Done

**Goal:** design the four missing parts of the settlement loop in the fabric only, a separate PR
from the runtime as the workflow requires: projects a village builds together, a specialty for
each member, raids it defends against and upkeep it pays. Each part is a rule table that Phases
198–201 read from `GameData`.

**Newel dependency:** NO (if a needed field type is missing, file it on Newel and use the closest
existing type).

**Depends on:** Phases 139, 177 and 184.

**Deliverables:**
- `fabric/gameplay/settlement.js`:
  - `projects`: settlement structures (for example a palisade, a watchtower, a workshop and a
    storehouse). Each one lists its materials (existing item keys), its labour in work units, a
    minimum tier and its effects from a closed set: stockpile capacity, raid defence, crafting
    speed inside the claim, upkeep relief. A structure is placed as blocks and stations in the
    claim when it completes.
  - `tiers` gain a second path: `growing` is also reached with `minMembers` and a number of
    completed projects, so four players can grow a village in its first hour. `town` keeps its
    day threshold.
  - `specialties`: for example woodworker, smith, hunter, builder and forager. Each one is scored
    from existing skill and attribute ids. A member's specialty is their best score above a floor,
    and it gives bonus labour on matching project steps.
  - `raids`: when a raid can start (minimum settlement age, a tier or stockpile-value floor, a
    cooldown), which creature packs come (per biome, existing creatures only), the warning time,
    what is at stake (a capped share of the stockpile and damage to unfinished projects), and
    offline protection: no raid starts unless a member is online inside the claim.
  - `upkeep`: a daily cost per tier taken from the stockpile. Unpaid upkeep suspends project
    effects until it is paid. It never shrinks the claim, which still follows the activity-based
    abandonment rule.
- `fabric/constitution/decisions.js`: a proposed decision recording raid fairness (warning,
  offline protection, loss cap) and the upkeep rule.
- Tutorial: one optional "your first village" chapter (found, start a project, contribute) in the
  Phase 184 step table, if it fits without new trigger kinds.
- `tools/check_settlement_loop.js` and a CI step, like the other validators.
- Regenerated `godot/`, `bible/`, `wiki/`.

**Acceptance criteria:**
- [x] `npm run validate` and `npm run check-drift` green.
- [x] `node tools/check_settlement_loop.js` passes and proves the validator rejects: a project with
  no materials or an unknown item, an effect outside the closed set, a specialty that names an
  unknown skill or attribute, a raid loss share above 1 or with no warning time, a raid table
  without offline protection, and upkeep that falls as the tier rises.
- [x] The generated bible has pages for projects, specialties, raids and upkeep, linked from the
  Settlement page.
- [x] CI runs the new check.

**Outcome:**
- `fabric/gameplay/settlement.js` holds four new rule tables, one world system each so the runtime reads
  them as `GameData.WORLD_SYSTEMS["SettlementProjects" | "SettlementSpecialties" | "SettlementRaids" |
  "SettlementUpkeep"].rules`:
  - projects: palisade, storehouse, workshop (places a carpentry bench and a forge) and watchtower
    (growing tier). Labour is ordered steps, each tagged with the specialty that earns bonus labour on
    it; one work unit is `workSecondsPerUnit` seconds at the site. Effects come from the closed set
    `stockpileCapacity`, `raidDefence`, `craftSpeed`, `upkeepRelief`. `places` gives the block, block
    count, layout (`ring`, `tower`, `hall`, `shed`) and stations placed on completion.
  - `tiers.growing.minProjects: 2`: growing is reached by `minMembers` and either `minDays` or two
    completed projects. The validator refuses `minProjects` on `town`.
  - specialties: woodworker, smith, hunter, builder, forager. Score = Σ weight × skill tier rank
    (novice 0 .. master 4) + Σ weight × attribute points above the base; floor 2, ties to the
    earlier row, bonus labour +50%. Every specialty must match at least one project step.
  - raids: 30 min minimum age, `growing` tier or 10 stockpile stacks, 6 h cooldown, 120 s warning,
    600 s duration, offline protection, loss caps (20% of the stockpile, 25% of unfinished labour),
    raid defence capped at 75%. Packs for the five biomes that have creatures, each checked against
    the creature's own biome; other biomes are never raided.
  - upkeep: every 24 h, per tier, never falling per item as the tier rises; `shrinksClaim: false`.
- `SettlementRaidsAndUpkeep` (proposed decision) records raid fairness and the upkeep rule.
- Tutorial: the "your first village" chapter needs two new trigger kinds (only founding fits
  `station_placed`), so it is folded into Phase 198.
- `tools/check_settlement_loop.js` (and its CI step) proves every rejection in the criteria, plus a
  pack from another biome, an unknown creature, step specialty, station or tier, upkeep that shrinks
  the claim and a town tier reached by projects.
