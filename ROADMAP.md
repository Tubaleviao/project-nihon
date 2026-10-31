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

Phases 1–198 are done. Their specs and acceptance criteria, and the introductions of
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
| 198 | Settlement projects at runtime: a village builds together | Done | [phases-198.md](docs/roadmap-history/phases-198.md) |
| 199 | Specialties at runtime: what each member is good at | Planned | below |
| 200 | Raids: a warned, bounded attack the village can defend | Planned | below |
| 201 | Upkeep: a village that has to keep going | Planned | below |
| 202 | The settlement loop, played: four bots found, specialize, trade and defend a village | Planned | below |

### Arc: an Earth-scale world and buildings that stand up (Phases 203–208)

The goal, from the player's side: **mountains as tall as Earth's, and buildings as tall as Earth's,
where what you can build depends on what you build it with.** Today the tallest terrain is 512 m
(`WorldSystem.maxHeight`), nothing can be placed above 640 m (`VoxelConsts.MAX_HEIGHT`), and a
finished settlement project is a wall two blocks (0.25 m) high. This arc raises the peaks to about
8,850 m, adds floors (3 m each) with a per-material limit (wood 2, stone 5, concrete 10, up to 163
for the best composites), makes unusual shapes need rarer materials, and changes what a claim
protects: non-members cannot edit a claimed structure but can destroy it, and the land around
structures stays free of creature spawns, more of it the bigger the structure.

Decided by the owner (2026-10-31): peak height on Earth's scale, the 163-floor ceiling, the
per-material floor limits, shape-dependent materials, and protection from edits but not from destruction, with
spawn suppression scaled by structure size. Open questions each phase must settle in its fabric are
listed in Phase 203.

| Phase | Title | Status | Spec |
|---|---|---|---|
| 203 | Tall world and structures in the fabric: heights, floors, materials, shapes and claims | Planned | below |
| 204 | Earth-scale mountains: peaks to about 8,850 m on unrecorded land | Planned | below |
| 205 | Floors and structural limits at runtime: what a material can hold up | Planned | below |
| 206 | Building materials: concrete, steel and composites | Planned | below |
| 207 | Claimed structures: protected from edits, open to destruction, free of spawns | Planned | below |
| 208 | A tower on a mountain: the arc, played | Planned | below |

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

## Phase 203 — Tall world and structures in the fabric: heights, floors, materials, shapes and claims

**Goal:** every number and rule this arc needs, modelled in the fabric with validators, before any
GDScript. A fabric design PR only, separate from the implementation phases.

**Newel dependency:** NO.

**Depends on:** Phase 198.

**Deliverables:**
- `WorldSystem`: `maxHeight` about 8,850 m (Everest is 8,849 m) and a build ceiling above the
  highest peak plus the tallest structure. The ceiling moves from `VoxelConsts.MAX_HEIGHT` into the
  fabric. Vertical precision is checked in the spec: the voxel mesh group key stores y × 10⁴ in an
  int32 (good to about 214 km), and float32 keeps 0.125 m steps exact far past 10 km.
- `Structure` rules: `floorHeight` (3 m, 24 blocks), `maxFloors` 163, and a structural class on
  every buildable material with its own `maxFloors`: wood 2, stone 5, concrete 10, and higher
  classes (steel, composites) up to 163. Material `hardness` today mixes a Janka scale (woods) and a
  Mohs scale (stones, metals), so it cannot rank strength. The class is a new field, and a validator
  rejects a buildable material without one.
- A shape rule: a few measures of how unusual a shape is (overhang reach, unsupported span, height
  to footprint), each with the lowest structural class allowed past each threshold, so the more
  unusual the shape, the rarer the material. Validators: the thresholds increase, and the class
  required never drops as a measure grows.
- Claim rules: what a non-member may do to a claimed structure (no placing, reshaping or taking
  stations; damaging and destroying allowed, with block durability from the structural class), and
  the spawn-free radius around a structure as a function of its footprint and height.
- `check_*.js` tools proving each new validator rejects a bad table, each with a CI step.
- Open questions, settled in this phase's fabric `decisions.js` entries:
  1. Does the settlement claim (hearth radius by tier, Phase 139) stay as the village boundary,
     with structure protection and spawn suppression added on top, or is it replaced by the union
     of structure footprints? Today it blocks every non-member edit inside it, bare ground
     included, and also gates raids, labour and research.
  2. Does destroying a claimed block drop its material, a share of it, or nothing?
  3. Do Phase 200 raids still spawn inside the spawn-free area (they must reach the village)?
  4. Destroying another settlement's structures is a form of settlement against settlement, which
     the Deferred list holds back until governance and fairness rules exist. Which limits apply
     (offline protection as for raids, a damage rate cap)?
  5. Do the limits apply to every player build or only to settlement projects? Builds that exist
     when the rules land are never collapsed (stable-world rule).

**Acceptance criteria:**
- [ ] `npm run validate` and `npm run check-drift` pass. Every new validator has a `check_*.js`
  that rejects a bad table, and CI runs it.
- [ ] The fabric has the floor limits wood 2, stone 5, concrete 10 and a top class of 163, and a
  validator fails if any class exceeds `Structure.maxFloors`.
- [ ] The five open questions each have a recorded decision.

---

## Phase 204 — Earth-scale mountains: peaks to about 8,850 m on unrecorded land

**Goal:** the generator makes mountain ranges as tall as Earth's, and the client draws, streams and
collides with them.

**Newel dependency:** NO.

**Depends on:** Phase 203.

**Deliverables:**
- The ridge and height fields reach the new `maxHeight`, and the build ceiling is read from the
  fabric. `TerrainSlice.WORLDGEN_VERSION` is bumped with a history line, and the golden values are
  updated.
- Stable-world rule: recorded chunks keep their heights. New peaks rise only on unrecorded land, and
  `frontier.gd` eases them in beside recorded land over `BLEND_CHUNKS`. The spec states how far from
  recorded land the full height is reached.
- The distant ring, the horizon bands (Phase 165), the camera far plane and coarse chunks (Phase 190)
  draw an 8 km peak without holes or popping. The climate fields cool with altitude where they do
  not already.

**Acceptance criteria:**
- [ ] Suite: on the pinned seed, the generator's highest sampled surface is within 5% of
  `maxHeight`, and no surface exceeds it.
- [ ] Suite: a recorded chunk's heights are unchanged across the version bump.
- [ ] Suite: a placement at the build ceiling succeeds and one above it is refused.
- [ ] Playtest: `far_peak` reaches a peak above 8,000 m, its screenshot has no holes in the terrain,
  and walk/craft/fight stay within budget.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 205 — Floors and structural limits at runtime: what a material can hold up

**Goal:** the host refuses a build that its material cannot hold up: too many floors, or a shape too
unusual for that class. Settlement projects become real buildings with floors.

**Newel dependency:** NO.

**Depends on:** Phases 203 and 204.

**Deliverables:**
- `src/building/structure_rules.gd`: pure functions over a connected set of placed blocks. Floors
  above ground, the weakest structural class carrying each block, and the shape measures from
  Phase 203. They are bounded and incremental, so a 163-floor tower is not rescanned on every
  placement.
- The host refuses a placement that breaks a limit, with a localized reason. A client never reports
  structural state.
- Project layouts get real heights: a wood shed is one 3 m floor. Each block is placed at its exact
  height, `dy` included (the doorway stays open above the second course; Phase 198 dropped every
  block on its column's top). A project's blocks go out in batched edits and rebuilds, not one
  chunk rebuild per block.

**Acceptance criteria:**
- [ ] Suite: a third wood floor, a sixth stone floor and an eleventh concrete floor are refused, and
  the top class stops at floor 163.
- [ ] Suite: an overhang past a class's threshold is refused for that class and allowed for the
  next one.
- [ ] Suite: a finished project's doorway is open on every course it is meant to be, and its blocks
  sit at their layout heights over uneven ground.
- [ ] Suite (audit): no structural value is read from a client message.
- [ ] Every new string is in both catalogs, and the i18n key check passes.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 206 — Building materials: concrete, steel and composites

**Goal:** the materials above stone exist and can be made, so every structural class has something
to build with, and the rarer classes cost more.

**Newel dependency:** NO.

**Depends on:** Phase 205.

**Deliverables:**
- Fabric materials, items, recipes and technologies for concrete, steel and at least one composite,
  each with its structural class. Inputs come from existing deposits and metals, and the top class
  needs a ley-gated ingredient.
- Block placeholders in `assets/` for every new block (placeholder rule).

**Acceptance criteria:**
- [ ] `npm run validate` and `npm run check-drift` pass, and every structural class up to 163
  floors has at least one craftable material.
- [ ] Suite: each new material can be crafted from gathered inputs along its recipe chain.
- [ ] Suite: a ten-floor concrete building is allowed, and an eleventh floor is refused.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 207 — Claimed structures: protected from edits, open to destruction, free of spawns

**Goal:** a non-member cannot change a settlement's structure but can break it down, and creatures
do not spawn around structures, over a larger area for a larger structure.

**Newel dependency:** NO.

**Depends on:** Phases 203 and 205.

**Deliverables:**
- The host tracks each claimed structure's blocks and footprint. A non-member's place, reshape or
  station edit on it is refused. Their damage wears its blocks down at the class durability rate,
  and a destroyed block resolves as Phase 203 decided. Members are told when their structure is
  being damaged.
- The spawn-free area (union of structure radii, plus the hearth claim if Phase 203 keeps it) is
  read by the creature spawner. Raids follow Phase 203's decision.
- Whatever Phase 203 decided about the hearth claim is applied, and `edit_blocker` is changed to
  match.

**Acceptance criteria:**
- [ ] Suite: a non-member's placement on a claimed structure is refused, and their damage destroys
  a block after the class durability.
- [ ] Suite: no creature spawns inside a structure's spawn-free radius over a simulated day, and a
  bigger structure has a bigger radius.
- [ ] Harness: a client's damage to the host's settlement structure reaches both peers, and the
  client's placement on it is refused.
- [ ] Suite (audit): no claim or durability value is read from a client message.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 208 — A tower on a mountain: the arc, played

**Goal:** prove the arc with the playtest bot: a tall building near a high peak, the limits it hit
and a spawn-free village.

**Newel dependency:** NO.

**Depends on:** Phases 204–207.

**Deliverables:**
- A `tower` playtest step: the bot builds past the wood floor limit (refused), switches to a higher
  class and builds on. It flies to an 8 km peak and screenshots both.

**Acceptance criteria:**
- [ ] Playtest: the step passes, with the wood refusal at floor 3, and walk/craft/fight stay within
  budget.
- [ ] Playtest: no creature spawns inside the village's spawn-free area during the session.
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
