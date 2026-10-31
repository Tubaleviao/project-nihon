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

**Changed 2026-10-31 (Phases 203–213):** the owner replaced settlements' claim area with clans and owned structures, and dropped raids. Phase 200 moved to Deferred. Phase 201 (upkeep) and Phase 202 (the loop played, which plays a raid and upkeep) are on hold until Phase 203 decides what a settlement is without a claim. Phase 199 stays: specialties follow from skills, which Phase 207 grows from labour.

| Phase | Title | Status | Spec |
|---|---|---|---|
| 197 | The settlement loop in the fabric: projects, specialties, raids and upkeep | Done | [phases-197.md](docs/roadmap-history/phases-197.md) |
| 198 | Settlement projects at runtime: a village builds together | Done | [phases-198.md](docs/roadmap-history/phases-198.md) |
| 199 | Specialties at runtime: what each member is good at | Planned | below |
| 200 | Raids: a warned, bounded attack the village can defend | Dropped (2026-10-31) | Deferred |
| 201 | Upkeep: a village that has to keep going | On hold: Phase 203 | below |
| 202 | The settlement loop, played: four bots found, specialize, trade and defend a village | On hold: Phase 203 | below |

### Arc: clans, owned buildings, an Earth-scale world and buildings that stand up (Phases 203–213)

The goal, from the player's side: **you found or join a clan, see what everyone in it is good at
and ask them for help; what you build is yours or your clan's for as long as it stands; anyone can
break it, but only with effort; and it can be as tall as Earth's buildings on mountains as tall as
Earth's, as far as its materials allow.**

Decided by the owner (2026-10-31), replacing the hearth claim of Phases 139–140:
- **Clans.** A player founds a clan by choosing its name and invites other players. A clan has any
  number of members, and a player belongs to at most one clan. Every member sees every other
  member's skills, so they can find the best sewer in the clan and message them to ask for a
  favour. Clans have tiers from the buildings they own and how rare those buildings' materials are.
- **Ownership.** When a player builds something, they assign it to their clan or keep it private.
  Only its owner (the player, or the clan's members) can edit it, wherever it stands. Anyone else
  can only destroy it by force. It stays its owner's until the owner dismantles it or someone else
  destroys it.
- **No claim area.** Two areas remain, both a circle around each building, larger for a larger
  building. No creature spawns inside it, and no one may build a private building or another clan's
  building inside a clan building's circle. Destroying the building removes both.
- **Durability.** Each material has a durability, higher for rarer materials. A block's durability
  falls with weather, time and damage taken, and how hard it is to destroy depends on it.
  Dismantling returns materials by durability and skill: everything at full durability with a very
  high building skill, half at full durability with no skill, and less as durability falls.
- **Research is per player** and is shared only by writing: books and blueprints.
- **Labour is personal experience.** Each labour type grows the worker's own skill (sewing makes you
  a better sewer). It is not progress for a clan.
- **Chests** have an access mode set by their owner: owner only, clan or everyone. A locked chest can
  be destroyed or lockpicked, depending on its material and technology.
- **Raids are not wanted now** (Phase 200 is dropped, see Deferred).
- **Heights:** peaks to about 8,850 m (Everest is 8,849 m) and buildings up to 163 floors. Floor
  limits depend on the material: wood 2, stone 5, concrete 10, and higher classes up to 163.
  Unusual shapes need rarer materials.

Today the tallest terrain is 512 m (`WorldSystem.maxHeight`), nothing can be placed above 640 m
(`VoxelConsts.MAX_HEIGHT`), and a finished settlement project is a wall two blocks (0.25 m) high.
There are no clans (a settlement's members and roles are the nearest thing), no private messages,
no chests, no books or blueprints, and no building, sewing or lockpicking skill (the 22 skills
include Carpentry and Smithing). Phase 203 settles the open questions in the fabric before any
runtime phase starts.

| Phase | Title | Status | Spec |
|---|---|---|---|
| 203 | Clans, ownership, durability, writing, chests and tall structures in the fabric | Planned | below |
| 204 | Clans: a name, invites, one clan each, and every member's skills in view | Planned | below |
| 205 | Owned structures instead of claims: private or clan, durability, dismantling and destruction | Planned | below |
| 206 | The circle around every building: no spawns, no foreign building | Planned | below |
| 207 | Labour as personal experience | Planned | below |
| 208 | Chests: owner, clan or everyone, and locks that can be broken or picked | Planned | below |
| 209 | Books and blueprints: research shared by writing | Planned | below |
| 210 | Clan tiers from buildings and material rarity | Planned | below |
| 211 | Earth-scale mountains: peaks to about 8,850 m on unrecorded land | Planned | below |
| 212 | Floors and structural limits at runtime, and the materials above stone | Planned | below |
| 213 | A clan's tower on a mountain: the arc, played | Planned | below |

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

## Phase 201 — Upkeep: a village that has to keep going

**On hold** until Phase 203 decides what a settlement is without a claim, and whether project effects still exist.

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

**On hold** until Phase 203 decides what a settlement is without a claim (this phase plays a raid and upkeep).

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

## Phase 203 — Clans, ownership, durability, writing, chests and tall structures in the fabric

**Goal:** every rule and number of this arc, modelled in the fabric with validators, before any
GDScript. A fabric design PR only, separate from the implementation phases.

**Newel dependency:** NO.

**Depends on:** Phase 198.

**Deliverables:**
- **Clans.** A `Clan` with a player-chosen name (length, allowed characters, unique, moderated as
  chat is), a founder, members, invites and roles. A player is in at most one clan. Members see each
  other's skills. Clan tiers: the score from the buildings a clan owns and their material rarity,
  and the thresholds per tier.
- **Structures and ownership.** A structure is a connected set of placed blocks, assigned when
  built to its builder (private) or the builder's clan. Only the owner (the player, or any member
  for a clan structure) may place, reshape or take stations on it, anywhere in the world. Anyone
  else may only damage it. The `Settlement` claim fields (`tiers.claimRadius`, `decayRadiusPerDay`,
  `minSeparation`) and the hearth-site research rule (Phase 140 `materialSource`) are removed.
- **The circle.** One radius per structure from its footprint and height, with a minimum for a
  single block or station and a maximum. Inside it no creature spawns, and inside a clan
  structure's circle no one may start a private structure or another clan's structure.
- **Durability.** A base durability per material, ranked by rarity (a validator: a rarer material
  never has less). Loss rates per weather condition (the Phase 128 weather states), per day of age, and
  per point of damage. A repair rule, if any (open question 4).
- **Dismantling.** The share of materials returned as a function of durability fraction and the
  dismantler's building skill: 100% at full durability with a very high skill, 50% at full
  durability with no skill, falling with durability. A validator checks those two points and that
  the share never rises as durability falls.
- **New skills.** Building (the engineering skill dismantling reads), Tailoring (sewing) and
  Lockpicking, each with its XP curve.
- **Labour.** A map from each labour type (each project step's work kind, and crafting kinds) to
  the skill it grows, and the XP per labour beat. Labour gives a clan nothing but the finished thing.
- **Chests.** A `Chest` station with an access mode (`owner`, `clan`, `everyone`), set only by its
  owner. Lock durability and lockpicking difficulty come from its material and a technology.
- **Writing.** A `Book` that teaches one researched technology and a `Blueprint` that teaches one
  structure or station recipe. Only a player who knows the content can write one, at a material
  cost, and reading it consumes it or not (decided here).
- **Heights and floors.** `WorldSystem.maxHeight` about 8,850 m, and a build ceiling (moved from
  `VoxelConsts.MAX_HEIGHT` into the fabric) above the highest peak plus the tallest structure.
  `Structure.floorHeight` 3 m (24 blocks), `Structure.maxFloors` 163, and a structural class with
  its own `maxFloors` on every buildable material: wood 2, stone 5, concrete 10, higher classes up
  to 163. Material `hardness` mixes a Janka scale (woods) with a Mohs scale (stones, metals), so it
  cannot rank strength: the class is a new field.
- **Shapes.** Measures of how unusual a shape is (overhang reach, unsupported span, height to
  footprint), each with the lowest structural class allowed past each threshold.
- `check_*.js` tools proving each new validator rejects a bad table, each with a CI step.
- Open questions, each settled as a `decisions.js` entry:
  1. **Building near your own clan.** Default: a clan member may build a private structure inside
     their own clan's circles. Only outsiders' private structures and other clans' structures are
     refused there.
  2. **Clan tiers.** Do all of a clan's buildings count, or only those near each other (a town)?
     What does a tier give?
  3. **Forced destruction.** What does the destroyer get back: the dismantling share with their own
     skill, a smaller share, or nothing? Is it allowed while the owner (and, for a clan structure,
     every member) is offline?
  4. **Repair.** Can an owner restore lost durability, and at what cost?
  5. **Settlements.** Default: an existing settlement becomes a clan with the same name, members
     and roles. Its hearth becomes an ordinary clan building, and its stockpile a clan chest.
     Settlement projects become clan projects. Phase 201 (upkeep) stays on hold until project
     effects are decided here.
  6. **Touching structures.** Default: each player's or clan's blocks stay theirs when built
     against another owner's structure, so a wall can have two owners side by side.
  7. Do the floor and shape limits apply to every build or only to clan projects? Builds that exist
     when the rules land are never collapsed (stable-world rule).
  8. Labour still counts only within `SITE_RADIUS` (8 m) of its project, so you work on a building
     where it stands. Kept unless decided otherwise.

**Acceptance criteria:**
- [ ] `npm run validate` and `npm run check-drift` pass. Every new validator has a `check_*.js`
  that rejects a bad table, and CI runs it.
- [ ] The fabric has no claim radius; the floor limits wood 2, stone 5 and concrete 10 with a top
  class of 163; dismantling returns 100% and 50% at the two fixed points.
- [ ] Every labour type maps to a skill, and a validator rejects one that does not.
- [ ] The eight open questions each have a recorded decision.

---

## Phase 204 — Clans: a name, invites, one clan each, and every member's skills in view

**Goal:** players found and join clans, see what each member is good at, and message the one they
need.

**Newel dependency:** NO.

**Depends on:** Phase 203.

**Deliverables:**
- `src/clan/clan_slice.gd` and its wiring: found (name), invite, accept, leave, kick, roles. One
  clan per player, enforced on the host. Names are validated, unique and moderated.
- Existing settlements migrate to clans as Phase 203 decided (a data-format bump).
- The clan roster: every member's skills, sortable by skill, so "who sews best" is one click. The
  host sends a member's skills only to their own clan's peers, and stops when they leave.
- Private messages: from the roster (and a chat command) to one player. The host relays them only
  to the recipient, rate-limits them, and hosts send keys and params for any system text.

**Acceptance criteria:**
- [ ] Suite: founding a second clan, or accepting an invite while in a clan, is refused. A duplicate
  or invalid name is refused.
- [ ] Suite: a migrated settlement is a clan with the same name, members and roles.
- [ ] Harness: a clan member's peer receives another member's skills, and an outsider's peer never
  does (checked on the wire). A member who leaves stops receiving them.
- [ ] Harness: a private message reaches only its recipient.
- [ ] Every new string is in both catalogs, and the i18n key check passes.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 205 — Owned structures instead of claims: private or clan, durability, dismantling and destruction

**Goal:** the host knows who owns each structure and enforces it everywhere. A structure wears with
weather and time, comes apart with effort, and gives back what its condition and its dismantler's
skill allow. The hearth claim is gone.

**Newel dependency:** NO.

**Depends on:** Phase 204.

**Deliverables:**
- A host-side structure index: block to structure, structure to owner (player or clan), kept as
  blocks are placed, joined or destroyed, saved with the world, bounded in memory. The builder
  picks private or clan when placing.
- `edit_blocker` on the voxel, station and tree guards checks the structure under the edit, not a
  claim. A non-owner's damage lowers durability, and a block at zero is destroyed.
- Durability per block: base from its material, lowered by weather, age and damage. Age and weather
  loss is computed from timestamps when a block is read or ticked, not by touching every block
  every frame, and days with the server down count once on boot.
- Dismantling by the owner returns the Phase 203 share. Forced destruction resolves as Phase 203
  decided. The owner (and online clan members) are told when a structure is damaged or destroyed.
- The claim code is removed: `claim_radius`, `claim_at`, tier radii, `at_research_site` and claim
  decay.

**Acceptance criteria:**
- [ ] Suite: a private structure's owner can edit it far from any hearth, and a clan member cannot.
  A clan structure can be edited by any member and by no outsider.
- [ ] Suite: an outsider's damage destroys a block once its durability is gone, and a rarer
  material takes more damage.
- [ ] Suite: dismantling at full durability returns 50% with no building skill and 100% with a very
  high one, and less after a simulated year of rain.
- [ ] Suite: ownership is unchanged by anything but dismantling or destruction.
- [ ] Harness: a client's damage to the host's structure reaches both peers, and its placement on it
  is refused.
- [ ] Suite (audit): no owner, clan, durability or skill value is read from a client message.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 206 — The circle around every building: no spawns, no foreign building

**Goal:** creatures never spawn near a building, and no one builds their own or another clan's
structure inside a clan building's circle. A bigger building has a bigger circle, and destroying it
lifts both effects.

**Newel dependency:** NO.

**Depends on:** Phase 205.

**Deliverables:**
- A spatial lookup over the structure index's circles, so a dense town does not slow spawning or
  placement checks.
- The creature spawner skips points inside any circle. Creatures that walk in are not removed.
- The host refuses a new structure inside another clan's circle, or a private one by an outsider,
  as Phase 203 decided. A circle shrinks as its structure loses blocks and goes when it is
  destroyed.

**Acceptance criteria:**
- [ ] Suite: over a simulated day, no creature spawns inside any circle, and spawns continue
  outside.
- [ ] Suite: an outsider's private structure inside a clan building's circle is refused, and the
  same placement succeeds once that building is destroyed.
- [ ] Suite: a larger structure has a larger circle, between the fabric's minimum and maximum.
- [ ] Playtest: walk/craft/fight stay within budget with a village of structures near spawn.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 207 — Labour as personal experience

**Goal:** working on a project or a craft grows the worker's own skill for that kind of work. A clan
gains nothing from labour except the finished thing.

**Newel dependency:** NO.

**Depends on:** Phases 203 and 204.

**Deliverables:**
- Each labour beat calls `player_registry.add_skill_xp` for the skill Phase 203 maps it to. Phase
  199's specialties then follow from those skills, and the clan roster (Phase 204) shows them.
- Project completion stops counting toward a tier (`minProjects`).

**Acceptance criteria:**
- [ ] Suite: a labour beat on a sewing step adds Tailoring XP to that worker and to no one else.
- [ ] Suite: completing a project changes no clan-level value except the project itself.
- [ ] Suite (audit): no XP amount is read from a client message.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 208 — Chests: owner, clan or everyone, and locks that can be broken or picked

**Goal:** a player keeps things in a chest that only they, their clan or everyone can open. A locked
chest can still be broken open or picked, harder for better chests.

**Newel dependency:** NO.

**Depends on:** Phases 204 and 205.

**Deliverables:**
- The `Chest` station, its inventory and access mode on the host. Only the owner changes the mode.
  The host checks every open, take and put against it.
- Destroying a chest spills its contents. Lockpicking is a timed action with the Lockpicking skill
  and a tool against the chest's difficulty. Success opens it once, failure can break the tool, and
  the owner is told.
- UI: the chest window, the access-mode setting for the owner, and the lockpicking progress.

**Acceptance criteria:**
- [ ] Suite: an owner-only chest refuses a clan member, a clan chest refuses an outsider, and an
  everyone chest opens for anyone. A non-owner cannot change the mode.
- [ ] Suite: a harder chest takes longer to pick and to destroy, and a destroyed chest spills
  everything it held.
- [ ] Harness: a client's take from a chest it may not open is refused, and the chest is unchanged
  on both peers.
- [ ] Every new string is in both catalogs, and the i18n key check passes.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 209 — Books and blueprints: research shared by writing

**Goal:** a technology is learnt by researching it or by reading a book about it. A structure or
station is learnt from a blueprint. Nothing is shared through a clan.

**Newel dependency:** NO.

**Depends on:** Phase 203.

**Deliverables:**
- Writing: a player who knows a technology or recipe writes a book or blueprint at a station, with
  the fabric's material cost. Reading teaches it as Phase 203 decided (the item is consumed or
  kept).
- Research materials come from the researcher's own pack. The Phase 140 settlement stockpile source
  is removed.

**Acceptance criteria:**
- [ ] Suite: a player who reads a book unlocks its technology, and one who has not read it is
  unchanged. Writing about a technology the writer does not know is refused.
- [ ] Suite: a blueprint teaches its recipe, and no research reads a shared stockpile.
- [ ] Harness: a book handed to a client teaches the client, not the host's player.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 210 — Clan tiers from buildings and material rarity

**Goal:** a clan rises in tier by owning more buildings of rarer materials, and falls when they are
dismantled or destroyed.

**Newel dependency:** NO.

**Depends on:** Phases 205 and 206.

**Deliverables:**
- The clan score from the structure index (count and material rarity, counted as Phase 203
  decided), recomputed incrementally when a clan structure is built, loses blocks or is destroyed.
- Tier changes are synced to members with a keyed notice, and whatever a tier gives (Phase 203)
  is applied.
- UI: the clan's tier and score on the roster.

**Acceptance criteria:**
- [ ] Suite: adding a stone building raises a clan's score more than a wood one, and crossing a
  threshold changes its tier once.
- [ ] Suite: destroying the building that held a clan above a threshold drops its tier.
- [ ] Suite (audit): no score or tier is read from a client message.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 211 — Earth-scale mountains: peaks to about 8,850 m on unrecorded land

**Goal:** the generator makes mountain ranges as tall as Earth's, and the client draws, streams and
collides with them.

**Newel dependency:** NO.

**Depends on:** Phase 203.

**Deliverables:**
- The ridge and height fields reach the new `maxHeight`, and the build ceiling is read from the
  fabric. `TerrainSlice.WORLDGEN_VERSION` is bumped with a history line, and the golden values are
  updated. Vertical precision is checked: the voxel mesh group key stores y × 10⁴ in an int32 (good
  to about 214 km), and float32 keeps 0.125 m steps exact far past 10 km.
- Stable-world rule: recorded chunks keep their heights. New peaks rise only on unrecorded land,
  eased in by `frontier.gd` beside recorded land. Existing worlds keep their 512 m mountains where
  players have been.
- The distant ring, the horizon bands (Phase 165), the camera far plane and coarse chunks (Phase
  190) draw an 8 km peak without holes or popping. The climate cools with altitude where it does
  not already.

**Acceptance criteria:**
- [ ] Suite: on the pinned seed, the highest sampled surface is within 5% of `maxHeight`, and none
  exceeds it.
- [ ] Suite: a recorded chunk's heights are unchanged across the version bump.
- [ ] Suite: a placement at the build ceiling succeeds and one above it is refused.
- [ ] Playtest: `far_peak` reaches a peak above 8,000 m with no holes in its screenshot, and
  walk/craft/fight stay within budget.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 212 — Floors and structural limits at runtime, and the materials above stone

**Goal:** the host refuses a build its material cannot hold up: too many floors, or a shape too
unusual for its class. Concrete, steel and composites exist, so every class has something to build
with. Clan projects become real buildings with floors.

**Newel dependency:** NO.

**Depends on:** Phases 205 and 211.

**Deliverables:**
- `src/building/structure_rules.gd`: pure, incremental functions over the Phase 205 structure
  index. Floors above ground, the weakest class carrying each block, and the shape measures. A
  163-floor tower is not rescanned on every placement.
- The host refuses a placement that breaks a limit, with a localized reason.
- Fabric materials, items, recipes and technologies for concrete, steel and at least one composite,
  with their durability and class, and block placeholders in `assets/` (placeholder rule). The top
  class needs a ley-gated ingredient.
- Project layouts get real heights: a wood shed is one 3 m floor. Each block is placed at its exact
  height, `dy` included (Phase 198 drops every block on its column's top, which closes a doorway
  above the second course). A project's blocks go out in batched edits and rebuilds.

**Acceptance criteria:**
- [ ] Suite: a third wood floor, a sixth stone floor and an eleventh concrete floor are refused, and
  the top class stops at floor 163.
- [ ] Suite: an overhang past a class's threshold is refused for that class and allowed for the
  next one.
- [ ] Suite: a finished project's doorway is open on every course it should be, and its blocks sit
  at their layout heights over uneven ground.
- [ ] `npm run validate` passes, and every class up to 163 floors has a craftable material.
- [ ] Suite (audit): no structural value is read from a client message.
- [ ] Every new string is in both catalogs, and the i18n key check passes.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 213 — A clan's tower on a mountain: the arc, played

**Goal:** prove the arc with the playtest bot.

**Newel dependency:** NO.

**Depends on:** Phases 206–212.

**Deliverables:**
- A `tower` playtest step: the bot founds a clan, builds a clan structure past the wood floor limit
  (refused), switches to a higher class and builds on, sets a chest to owner-only, reads a book,
  dismantles a fresh block for half its material, and flies to an 8 km peak, screenshotting the
  tower and the peak.

**Acceptance criteria:**
- [ ] Playtest: the step passes, with the wood refusal at floor 3 and a 50% return, and
  walk/craft/fight stay within budget.
- [ ] Playtest: no creature spawns inside any building's circle during the session.
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
- **Raids** (dropped 2026-10-31, was Phase 200) — a warned, bounded creature attack on a village. Not wanted for now. Its spec is in git history (ROADMAP.md before PR #540).
- **Settlement against settlement** — Phase 205 lets anyone destroy a structure they do not own. Organized sieges, wars and disputes between clans need governance and fairness rules first.
- **Real cross-region multiplayer run** — Phase 135 emulates WAN profiles in the harness. A run
  between real regions remains.
- **Automatic LOD mesh decimation** — simplified meshes are hand-authored (Phase 23).
- **Dynamic impostor re-bake** — impostor billboards are baked offline. A live re-bake on palette
  change is deferred from Phase 23.
- **Server sharding (last, not before maturity)** — split the authoritative simulation across
  servers by region once one headless server (Phase 27) with spatial hashing (Phase 28) and
  interest management (Phase 29) saturates. No structural change is needed before then. Revisit
  when Brazil-region load approaches one server's ceiling.
