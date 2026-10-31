# Roadmap history — Phase 198

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 198 — Settlement projects at runtime: a village builds together ✅ Done

**Goal:** members start a project, bring materials and work on it, and when it completes the
structure appears in the claim and its effect applies. This is the first thing a village does
together after the hearth.

**Newel dependency:** NO.

**Depends on:** Phases 140 and 197.

**Deliverables:**
- `src/settlement/project_rules.gd`: pure functions for what a project still needs, whether a
  contribution is valid, and the completion check.
- Host-owned project state per settlement in the settlement slice, persisted in the world record,
  with a versioned migration (a pre-198 settlement loads with no projects).
- Intents: `project_start` (roles with `invite`), `project_contribute` (materials from the
  contributor's bag or from the stockpile, within their `withdrawLimit`) and labour (working at the
  project site with a tool, on the existing harvest-style timer). Each intent is validated,
  rate-limited and refused with a keyed reason.
- Completion places the structure's blocks and stations inside the claim, through the stable-world
  edit path, and applies its effects. Tier promotion reads the completed-project path from
  Phase 197.
- Syncs scoped to members, plus the finished structure as ordinary world edits for peers in range.
- UI: a project board in the settlement panel, with needed and given materials, labour and who
  contributed. All text goes through `I18n.t()`.
- Net harness: a `settlement_project` step. The host starts a project, the client contributes
  materials and labour, the project completes, and an outsider's contribution is refused.

- Tutorial (from Phase 197): the optional "your first village" chapter (found, start a project,
  contribute). Only the founding step fits the Phase 184 trigger kinds (`station_placed` with type
  `hearth`); starting and contributing need two new kinds, `project_started` and
  `project_contributed`, which this phase's bus events can complete.

**Acceptance criteria:**
- [x] Suite: `project_rules` accepts a valid contribution and refuses an unknown item, too much of
  an item, a non-member, and a stockpile withdrawal over the role's limit, each with its own key.
- [x] Suite: a completed project places its structure, applies its effect (for example the
  storehouse raises `capacity_stacks`) and counts toward the `growing` tier.
- [x] Suite: project state survives a save and reload, and a pre-198 world loads with no projects.
- [x] Harness: the `settlement_project` step passes over the socket.
- [x] Every new string is in both catalogs, and the i18n key check passes.
- [x] Suite green on both boot paths, harness green.

**Outcome:**
- `src/settlement/project_rules.gd` holds the pure half: materials needed and remaining, the labour step a
  work total falls in, `contribution_blocker` (`unknown_project`, `bad_args`, `project_done`,
  `unknown_item`, `too_much`), `stock_draw_blocker` (`over_limit` past the role's `withdrawLimit`, none for
  the founder), `start_blocker` (`project_exists`: each structure once per village; `tier_too_low`;
  `too_many_projects`: three under way at most), completion, effect totals and the structure's cells
  (courses of the layout's outline stacked to exactly `places.blocks`, a doorway in all but the tower).
- The settlement slice keeps `projects` per settlement (`{ key, by, started, site, given, work, status,
  done_at, contributors }`). Its record gained `format: 2`; a record without it (pre-198) loads with no
  projects, and saved projects are checked (unknown keys and items dropped, counts clamped).
- Intents `project_start` (roles with `invite`, site inside the claim), `project_give` (from the pack or,
  as `from: "stock"`, from the stockpile within the daily `withdrawLimit`) and `project_work`. The wire
  keeps 16 characters of an action, so the names are short and a test checks every action fits.
  Labour is a beat the client sends every second while "Work here" is held: the host credits the time
  since the actor's last beat (at most `LABOUR_GAP_SEC` 2.5 s, a longer gap restarts the clock), within
  `SITE_RADIUS` 8 m of the site, with a tool in the main hand or the pack (tools take no equipment slot;
  carcass harvesting reads them the same way). Specialty bonus labour is the `labour_bonus` hook,
  1.0 until Phase 199.
- Completion places the structure through a new host build path, `VoxelSlice.place_structure_block(exact,
  material)`: the same edit record and `block_changed` AOI sync as a placement, no pack debit and no claim
  guard. `places.block` names an item, so the block's material is the item's body material (AshiteBlock
  builds Ashite). Stations are placed with `StationSlice.place_station`; like every host-placed station
  they reach clients in the world snapshot.
- Effects: `stockpileCapacity` adds to `capacity_stacks`, `raidDefence` and `upkeepRelief` are read by
  `project_effect(id, kind)` for Phases 200–201. `craftSpeed` is recorded but has nothing to speed yet:
  crafting is instant (no craft timer exists).
- `tier_for` reaches a tier with `minProjects` (growing) by members and either days or completed projects,
  and a completion runs the tier check at once.
- The members' view carries each project (needed, given, labour, step, contributors); the settlement
  window has a project board (picker, start, give from pack or stockpile, a held "Work here").
- Tutorial: the `first_village` chapter (found a village, start a project, build together) with the new
  trigger kinds `project_started` and `project_contributed`, completed from the local player's accepted
  intents.
- Net harness: the `settlement_project` step.
