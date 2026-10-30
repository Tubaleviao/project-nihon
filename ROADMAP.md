# Project Nihon — Roadmap

Project Nihon is an open-source sandbox MMORPG where players build a
civilization. This document tracks the design and implementation roadmap.
The game's entire design bible — materials, creatures, skills, items, world
systems — is authored as a Newel fabric and generated into documentation,
runtime assets, and Godot resources.

See `../newel/ROADMAP.md` for the Newel-side changes each phase depends on.

**Human verification is not an acceptance criterion.** A criterion must be decidable by the
automated gates — `pnpm validate`, `pnpm check-drift`, the headless suite on both boot paths,
`tools/net_harness.sh`, CI. A check that needs a person at the keyboard (a playtest, a screenshot
judgement, a visual inspection) is not a criterion: it is filed as a GitHub issue and the phase
proceeds without it, so unpublished human work never parks the roadmap. The phase records the
issue number where the criterion used to be.

**Follow-up debt cap.** No new feature phase starts while more than 10 `autopilot-followup`
issues are open. Burn them down first (fix, fold into the next phase, or close with a reason).

---

## Phase index

Phases 1–197 are done. Their specs and acceptance criteria, and the introductions of
the arcs they belonged to, are archived in [docs/roadmap-history/](docs/roadmap-history/README.md).

### Next: follow-up debt burn II (Phases 194–196)

Ten `autopilot-followup` issues are open, which is the cap: the next review that files one blocks
every new feature phase. Together they hold about 90 items, and the oldest (#336) is two weeks old.
They fall into three areas, and each phase below burns one area down before the settlement arc adds
new systems. As in Phase 173, an item is fixed, folded into a later phase (with the issue number
recorded there), or closed with a one-line reason. Many terrain items predate Phase 193's collision
rework and may no longer apply. Each phase re-checks its items against `main` first.

| Phase | Title | Status | Spec |
|---|---|---|---|
| 194 | Follow-up debt burn II: terrain streaming and the near ring (#504, #509, #512) | Done | [phases-194.md](docs/roadmap-history/phases-194.md) |
| 195 | Follow-up debt burn III: creature positions and the snapshot path (#444, #464, #493) | Done | [phases-195.md](docs/roadmap-history/phases-195.md) |
| 196 | Follow-up debt burn IV: waystones, gestures, trees and the player registry (#336, #367, #420, #522) | Done | [phases-196.md](docs/roadmap-history/phases-196.md) |

### Arc: the first settlement loop (Phases 197–202)

The goal, from the player's side: **four friends found a village, specialize, trade and defend it
from a raid within an hour of play.** Most of the parts exist. Phases 139–140 added the hearth, the
claim, roles and a shared stockpile. Phase 24 added trade, Phases 177–178 attributes, and Phase 185
a bed to come back to. But once the hearth is down, a village has nothing to do together, nothing
to defend and nothing to spend. Its tiers also need 3 and 14 days, so nothing changes in the first
hour. This arc gives a village shared projects, a specialty for each member, raids to defend
against and upkeep to pay. Its last phase proves the loop with four bots on a dedicated server.
Raids come from creatures only. Settlement-against-settlement conflict stays deferred.

| Phase | Title | Status | Spec |
|---|---|---|---|
| 197 | The settlement loop in the fabric: projects, specialties, raids and upkeep | Done | [phases-197.md](docs/roadmap-history/phases-197.md) |
| 198 | Settlement projects at runtime: a village builds together | Planned | below |
| 199 | Specialties at runtime: what each member is good at | Planned | below |
| 200 | Raids: a warned, bounded attack the village can defend | Planned | below |
| 201 | Upkeep: a village that has to keep going | Planned | below |
| 202 | The settlement loop, played: four bots found, specialize, trade and defend a village | Planned | below |

---

## Phase 198 — Settlement projects at runtime: a village builds together

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
- [ ] Suite: `project_rules` accepts a valid contribution and refuses an unknown item, too much of
  an item, a non-member, and a stockpile withdrawal over the role's limit, each with its own key.
- [ ] Suite: a completed project places its structure, applies its effect (for example the
  storehouse raises `capacity_stacks`) and counts toward the `growing` tier.
- [ ] Suite: project state survives a save and reload, and a pre-198 world loads with no projects.
- [ ] Harness: the `settlement_project` step passes over the socket.
- [ ] Every new string is in both catalogs, and the i18n key check passes.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 199 — Specialties at runtime: what each member is good at

**Goal:** each member gets a specialty from their skills and attributes. It shows on the roster
and makes their labour count for more on the project steps that match it, so a village gains from
members who do different things.

**Newel dependency:** NO.

**Depends on:** Phases 178 and 198.

**Deliverables:**
- `src/settlement/specialty_rules.gd`: pure scoring from the skill and attribute tables, ties
  broken in fabric order, and no specialty below the floor.
- The host recomputes a member's specialty when their skills or attributes change and syncs it to
  the settlement's members. Nothing is client-reported: the host reads its own skill and attribute
  records.
- Labour on a matching project step gets the fabric bonus.
- UI: the specialty on the roster and on the character sheet (Phase 179), with an icon from the
  Phase 175 generator.

**Acceptance criteria:**
- [ ] Suite: fixture players with a high carpentry skill, a high combat skill and only base values
  get woodworker, hunter and no specialty; a tie resolves in fabric order.
- [ ] Suite: a skill gain that changes the best score changes the specialty and emits one sync.
- [ ] Suite: a matching specialty's labour adds the bonus, and a non-matching one adds the base.
- [ ] Suite (audit): no specialty value is read from a client message.
- [ ] Every new string is in both catalogs, and the i18n key check passes.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 200 — Raids: a warned, bounded attack the village can defend

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
- [ ] Suite: `raid_rules` starts no raid with no member online in the claim, before the minimum
  age, under the value floor, or inside the cooldown.
- [ ] Suite: a lost raid takes at most the fabric's loss share, and a defended one takes nothing.
- [ ] Suite: a palisade or watchtower changes the raid as its fabric effect says.
- [ ] Suite: the cooldown and last result survive a save and reload.
- [ ] Harness: a `settlement_raid` step. `/raid` warns both clients, the pack spawns at the claim
  edge, the clients kill it, and the raid resolves as defended on both.
- [ ] Every new string is in both catalogs, and the i18n key check passes.
- [ ] Suite green on both boot paths, harness green, and the stress `cluster` crowd stays at or
  above its baseline with a raid running.

---

## Phase 201 — Upkeep: a village that has to keep going

**Goal:** a settlement pays a daily upkeep from its stockpile. Paying keeps its project effects
on. Missing a payment suspends them, with a notice, until the stockpile can pay again. A village
then has a reason to keep gathering and trading after its first build.

**Newel dependency:** NO.

**Depends on:** Phases 197 and 198.

**Deliverables:**
- Upkeep is charged on the host's day tick (Phase 182's `/time` advances it). It takes the tier's
  cost from the stockpile and records paid or unpaid.
- Unpaid upkeep suspends project effects, with a keyed notice to members. The next tick that can
  pay restores them. Upkeep never shrinks the claim, and abandonment still follows activity.
- Days that pass with the server down are charged at most once on boot, so a server that was off
  for a week does not drain a stockpile.
- UI: the next upkeep, its cost and whether the stockpile covers it, in the settlement panel.

**Acceptance criteria:**
- [ ] Suite: a day tick with enough stock pays and keeps effects on. One without suspends them and
  emits the notice, and a later paid tick restores them.
- [ ] Suite: unpaid upkeep never changes the claim radius.
- [ ] Suite: a boot after several days of downtime charges at most one day.
- [ ] Every new string is in both catalogs, and the i18n key check passes.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 202 — The settlement loop, played: four bots found, specialize, trade and defend a village

**Goal:** prove the arc's goal with an automated gate. Four scripted players on a dedicated server
found a village, join it, take different specialties, trade, complete a project, defend a raid and
pay upkeep. The in-game time they spend playing, not counting time skipped with admin commands,
must stay under one hour.

**Newel dependency:** NO.

**Depends on:** Phases 198–201.

**Deliverables:**
- A `settlement` scenario in the stress bot process (Phase 162): four bots on the pinned playtest
  seed. One founds and the others join. Each grows a different skill toward a specialty, they trade
  one item through the trade window protocol and complete a storehouse or palisade. A `/raid` is
  defended, and `/time` advances a day so upkeep is paid.
- `stress/settlement.{md,json}`: each loop beat with its in-game and wall time, and a verdict.
- A CI job that runs the scenario.

**Acceptance criteria:**
- [ ] CI: the scenario passes every beat, and its reported in-game play time (excluding admin time
  skips) is under 60 minutes.
- [ ] CI: the four bots end with at least two different specialties, one completed project, one
  defended raid and one paid upkeep, as read from the host's world record.
- [ ] The scenario passes 3 CI runs in a row on an unchanged commit.
- [ ] Suite green on both boot paths, harness green.

---

## Deferred (in priority order)

- **Rivers, lakes and fluid flow** — water above sea level and flowing water (a cellular
  automaton on dirty chunks only) after Phase 51's static sea level and Phase 137's falling sand.
- **Fast travel beyond waystones** — a planet takes about 90 days to walk around. Phase 125 added
  waystones; roads, mounts (taming exists) and boats remain.
- **Physics ragdolls** — Phase 157 animates deaths with a host-chosen landing spot and authored
  clips, so the headless server stays deterministic. A client-only ragdoll blend on top is later
  polish.
- **Localized fabric content** — entity names and descriptions (items, creatures, skills,
  technologies) translated through catalogs generated by Newel (`../newel/ROADMAP.md` Phase 15),
  consumed with the Phase 131 locale settings.
- **Public wiki deployment** — VitePress (or equivalent) static-site deployment and CI-triggered
  wiki regeneration from the fabric (deferred from Phase 9).
- **Voxel techniques from GDVoxelPlayground** — <https://github.com/JorisAR/GDVoxelPlayground>
  (MIT) was evaluated and not adopted wholesale: it ray-marches a fixed 128³ GPU grid, which does
  not fit an unbounded streamed world with a headless server. Worth borrowing later, CPU-side and
  deterministic: **WFC** for ruins, villages and dungeons, and a **brick occupancy map** if meshing
  becomes the bottleneck.
- **Settlement against settlement** — Phase 200 raids come from creatures only. Raids, sieges and
  claim disputes between player settlements need the governance and fairness rules first.
- **Real cross-region multiplayer run** — Phase 135 emulates WAN profiles in the harness. A run
  between real regions remains.
- **Automatic LOD mesh decimation** — simplified meshes are hand-authored (Phase 23).
- **Dynamic impostor re-bake** — impostor billboards are baked offline. A live re-bake on palette
  change is deferred from Phase 23.
- **Server sharding (last, not before maturity)** — split the authoritative simulation across
  servers by region once one headless server (Phase 27) with spatial hashing (Phase 28) and
  interest management (Phase 29) saturates. No structural change is needed before then. Revisit
  when Brazil-region load approaches one server's ceiling.
