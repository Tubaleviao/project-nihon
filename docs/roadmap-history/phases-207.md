# Roadmap history — Phase 207

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 207 — Skills grow from work, and clan projects without labour ✅ Done

**Goal:** crafting, gathering, building, dismantling and repairing grow the worker's own skill for
that kind of work. Clan projects finish when their materials are in, with no labour stage.

**Newel dependency:** NO.

**Depends on:** Phases 203 and 204.

**Deliverables:**
- Each kind of work calls `player_registry.grant_skill_xp` for the skill Phase 203 maps it to.
  Today only skinning a carcass grants XP (`carcass_wiring.gd`); crafting records skill tiers but
  no XP. Phase 199's specialties then follow from those skills, and the clan roster (Phase 204)
  shows them.
- Project labour is removed from the runtime: the labour clock (`LABOUR_GAP_SEC`), `SITE_RADIUS`,
  the tool-in-hand check, work steps and Phase 199's specialty labour bonus (`SettlementSlice.labour_bonus`,
  `bonusLabour`). A project completes on its last contribution. Saved projects with work in progress
  complete if their materials are in.
- Phase 203 hold to remove with it: `ProjectRules.LABOUR_HOLD` keeps the labour steps,
  `workSecondsPerUnit` and effects the fabric dropped, and `SpecialtyRules` falls back to a 0.5
  `bonusLabour` the fabric no longer has. The fabric's `WorkSkills` table maps every kind of work
  to its skill and XP, and the `tailoring` craft domain has no recipe yet: add a sewing recipe.
- Project completion stops counting toward a tier (`minProjects`).

**Acceptance criteria:**
- [x] Suite: crafting a sewing recipe adds Tailoring XP to the crafter and to no one else, and each
  kind of work grants its mapped skill.
- [x] Suite: a project completes on the contribution that brings in its last material, and no
  labour code remains.
- [x] Suite: completing a project changes no clan-level value except the project itself.
- [x] Suite (audit): no XP amount is read from a client message.
- [x] Suite green on both boot paths, harness green.

**Shipped:**
- `src/character/work_skills.gd` reads the fabric's `WorkSkills` table; the host grants XP where work
  succeeds: crafting (`CraftingSlice.craft`, by recipe domain), a natural block mined into the pack and a
  felled tree (by the material's family, from the new `WorkSkills.families`), each placed block, each
  dismantled block (not a destroyed one), a structure repair, and skinning (now the `carcass` row). Only
  `work_skills.gd` calls `grant_skill_xp`, and a suite audit enforces it.
- Sewing: `RecipeNoviceTunic` (`tailoring` domain, two Duskfiber at a carpentry bench, Tailoring novice).
- Project labour removed (rules, slice, wiring, board, the `project_work` intent, its catalog text); the
  settlement tick completes a saved project whose materials are in. `Settlement.tiers.*.minProjects` now
  fails validation (`tools/check_settlement_loop.js`).
- Not wired: foraging (no runtime forage action exists yet) and lockpicking (Phase 208 adds locks). Both
  are listed in `WorkSkills.UNWIRED`; the suite fails on any other row without a grant site and on an
  UNWIRED row that gained one.

**Review pass (PR #549):**
- Skill tiers follow the work: `WorkSkills.tiers` (fabric) is the cumulative XP per tier (100, 400, 1200,
  3000); a grant that crosses one records the tier and emits `skill_tier_recorded` (specialty, clan roster
  and, new, profession unlocks recompute). A tier is never lowered.
- No place-and-dismantle loop: each structure block records its placer (structure save format 2; a
  format-1 cell loads with none). Its own placer taking it apart again is an undo: the build XP comes back
  off and no dismantle XP is granted.
- Work grants defer their `attributes_synced` unless an attribute gained a point; the host flushes one per
  player each second (`PeerWiring.ATTR_SYNC_SEC`), not one network message and specialty recompute per block.
- Gather XP is per unit banked (a vein slice of 4, a felled tree's 2 planks).
- The pre-207 project fix runs once per load (the projects are queued and placed on the next tick); the tick
  scans no project.
- `Skinning.xpPerHarvest` is gone: the WorkSkills `carcass` row is the only Skinning XP number.
- `_credit` became `_credit_items`; `ProjectRules.completed_count` is removed.

