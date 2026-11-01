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

Phases 1–199 and 203–207 are done. Their specs and acceptance criteria, and the introductions of
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

**Changed 2026-10-31 (Phases 203–213):** the owner replaced settlements' claim area with clans and owned structures, and dropped raids. Phase 200 (raids) moved to Deferred, and Phase 201 (upkeep) and project labour are removed. Phase 202 (the loop played, which plays a raid and upkeep) is on hold until it is rewritten as a clan loop after Phase 213. Phase 199 shipped (#539) with a specialty labour bonus, which Phase 207 removes with project labour: specialties then follow from skills alone, which Phase 207 grows from work.

| Phase | Title | Status | Spec |
|---|---|---|---|
| 197 | The settlement loop in the fabric: projects, specialties, raids and upkeep | Done | [phases-197.md](docs/roadmap-history/phases-197.md) |
| 198 | Settlement projects at runtime: a village builds together | Done | [phases-198.md](docs/roadmap-history/phases-198.md) |
| 199 | Specialties at runtime: what each member is good at | Done | [phases-199.md](docs/roadmap-history/phases-199.md) |
| 200 | Raids: a warned, bounded attack the village can defend | Aborted | Deferred |
| 201 | Upkeep: a village that has to keep going | Aborted | — |
| 202 | The settlement loop, played: four bots found, specialize, trade and defend a village | On hold | below |

### Arc: clans, owned buildings, an Earth-scale world and buildings that stand up (Phases 203–213)

The goal, from the player's side: **you found or join a clan, see what everyone in it is good at
and ask them for help; what you build is yours or your clan's for as long as it stands; anyone can
break it, but only with effort; and it can be as tall as Earth's buildings on mountains as tall as
Earth's, as far as its materials allow.**

Decided by the owner (2026-10-31), replacing the hearth claim of Phases 139–140:
- **Clans.** A player founds a clan by choosing its name and invites other players. A clan has any
  number of members, and a player belongs to at most one clan. Every member sees every other
  member's skills, so they can find the best sewer in the clan and message them to ask for a
  favour. Clans have tiers from every building they own, wherever it stands, and how rare those
  buildings' materials are. A tier gives nothing yet. A clan has no hearth: it can have many
  settlements or cities, which are simply where its buildings stand.
- **Ownership.** When a player builds something, they assign it to their clan or keep it private.
  Only its owner (the player, or the clan's members) can edit it, wherever it stands. A member's
  private house inside their clan's territory stays theirs to edit, but any member of that clan may
  enter or dismantle it. Anyone else can only destroy a building by force. It stays its owner's
  until it is dismantled or someone else destroys it. The owner can repair it with part of the
  materials it took to build. Owners of touching buildings keep their own blocks.
- **No claim area.** Two areas remain, both a circle around each building, larger for a larger
  building. No creature spawns inside it, and inside a clan's circles no one but that clan's
  members may build. Destroying the building removes both.
- **Durability and destruction.** Each material has a durability, higher for rarer materials. A
  block's durability falls with weather, time and damage taken, and how hard it is to destroy
  depends on it and on the destruction method. Destroying a building while its owners are offline is
  allowed but very difficult. A destroyer gets nothing from a building, but a destroyed chest spills
  its contents to anyone. Dismantling returns materials by durability and skill: everything at full
  durability with a very high building skill, half at full durability with no skill, and less as
  durability falls.
- **A way out.** Any player can kill their own character to respawn elsewhere, so another player
  cannot trap them inside a structure.
- **Every building** follows the floor and shape limits, not only clan projects.
- **Research is per player** and is shared only by writing: books and blueprints.
- **Skills grow from work.** Crafting, gathering, building and dismantling grow the worker's own
  skill for that kind of work (sewing makes you a better sewer). Nothing a member does is progress
  for a clan. Clan projects have no labour: a project is complete once its materials are in.
- **Chests** have an access mode set by their owner: owner only, clan or everyone. A locked chest can
  be destroyed or lockpicked, depending on its material and technology. Doors work the same way.
- **Raids are not wanted now** (Phase 200, see Deferred). Upkeep (Phase 201) is removed.
  Clan skills for the top contributors and buildings only elders can build come later.
- **Heights:** peaks to about 8,850 m (Everest is 8,849 m) and buildings up to 163 floors. Floor
  limits depend on the material: wood 2, stone 5, concrete 10, and higher classes up to 163.
  Unusual shapes need rarer materials.

Today the tallest terrain is 512 m (`WorldSystem.maxHeight`), nothing can be placed above 640 m
(`VoxelConsts.MAX_HEIGHT`), and a finished settlement project is a wall two blocks (0.25 m) high.
There are no clans (a settlement's members and roles are the nearest thing), no private messages,
no chests or doors, no books or blueprints, no way for a player to respawn at will (`/kill` is an
admin command), and no building, sewing or lockpicking skill (the 22 skills include Carpentry and
Smithing). Phase 203 models all of it in the fabric before any runtime phase starts.

| Phase | Title | Status | Spec |
|---|---|---|---|
| 203 | Clans, ownership, durability, writing, chests and tall structures in the fabric | Done | [phases-203.md](docs/roadmap-history/phases-203.md) |
| 204 | Clans: a name, invites, one clan each, and every member's skills in view | Done | [phases-204.md](docs/roadmap-history/phases-204.md) |
| 205 | Owned structures instead of claims: private or clan, durability, dismantling and destruction | Done | [phases-205.md](docs/roadmap-history/phases-205.md) |
| 206 | The circle around every building: no spawns, no foreign building | Done | [phases-206.md](docs/roadmap-history/phases-206.md) |
| 207 | Skills grow from work, and clan projects without labour | Done | [phases-207.md](docs/roadmap-history/phases-207.md) |
| 208 | Chests and doors: owner, clan or everyone, and locks that can be broken or picked | Planned | below |
| 209 | Books and blueprints: research shared by writing | Planned | below |
| 210 | Clan tiers from buildings and material rarity | Planned | below |
| 211 | Earth-scale mountains: peaks to about 8,850 m on unrecorded land | Planned | below |
| 212 | Floors and structural limits at runtime, and the materials above stone | Planned | below |
| 213 | A clan's tower on a mountain: the arc, played | Planned | below |

### Out of arc: Alt window shortcuts (Phase 214)

Requested by the owner: window shortcuts should feel like an MMORPG's. Every window opens with Alt
plus a letter, so the bare letters go back to movement, combat and the hotbar. It touches no clan
system, so it can run before, between or after the clan arc's phases.

| Phase | Title | Status | Spec |
|---|---|---|---|
| 214 | Alt window shortcuts: Alt+A attributes, Alt+S skills, Alt+E inventory, Alt+Q equipment, Alt+G clan | Planned | below |

---

## Phase 202 — The settlement loop, played: four bots found, specialize, trade and defend a village

**On hold:** it plays a raid and upkeep, which are dropped. It will be rewritten as a clan loop (found a clan, specialize, trade, build) after Phase 213.

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

## Phase 208 — Chests and doors: owner, clan or everyone, and locks that can be broken or picked

**Goal:** a player keeps things in a chest, and a house behind a door, that only they, their clan or
everyone can open. A locked chest or door can still be broken open or picked, harder for better ones.

**Newel dependency:** NO.

**Depends on:** Phases 204 and 205.

**Deliverables:**
- The `Chest` and `Door` stations, a chest's inventory and both access modes on the host. Only the
  owner changes a mode. The host checks every open, take, put and pass against it. A clan member may
  open the doors of another member's private house inside the clan's territory (Phase 205).
- Destroying a chest spills its contents for anyone to take. Lockpicking is a timed action with the Lockpicking skill
  and a tool against the chest's difficulty. Success opens it once, failure can break the tool, and
  the owner is told.
- UI: the chest window, the access-mode setting for the owner, and the lockpicking progress.
- Phase 204 hold: a migrated settlement's stockpile becomes a clan chest with the same contents
  (`Clan.migration.stockpile`); until then it stays in the settlement record.
- Door and chest placeholders in `assets/` (placeholder rule).

**Acceptance criteria:**
- [ ] Suite: an owner-only chest refuses a clan member, a clan chest refuses an outsider, and an
  everyone chest opens for anyone. A non-owner cannot change the mode. Doors follow the same rules.
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
  the fabric's material cost. Reading teaches it and keeps the item, so it can be read again
  or lent.
- Research materials come from the researcher's own pack. The Phase 140 settlement stockpile source
  Phase 203 removed `materialSource` from the fabric; `TechnologySlice.STOCKPILE_RESEARCH_HOLD`
  keeps TechMasterForge on the stockpile until this phase. The rules are `GameData.WRITINGS`
  (`Book`, `Blueprint`).
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
- The clan score from the structure index (every clan building wherever it stands, and its
  material rarity), recomputed incrementally when a clan structure is built, loses blocks or is destroyed.
- Tier changes are synced to members with a keyed notice. A tier gives nothing yet (clan skills
  come later, see Deferred).
- UI: the clan's tier and score on the roster.

**Acceptance criteria:**
- [ ] Suite: adding a stone building raises a clan's score more than a wood one, wherever it stands,
  and crossing a threshold changes its tier once.
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
  Phase 203 set the fabric's `maxHeight` to 8,850 m and `buildCeiling` to 9,400 m;
  `WorldShape.PEAK_HOLD` keeps the generator at 512 m until this phase removes it.
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
  dismantles a fresh block for half its material, kills its character to respawn, and flies to an 8 km peak, screenshotting the
  tower and the peak.

**Acceptance criteria:**
- [ ] Playtest: the step passes, with the wood refusal at floor 3 and a 50% return, and
  walk/craft/fight stay within budget.
- [ ] Playtest: no creature spawns inside any building's circle during the session.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 214 — Alt window shortcuts: Alt+A attributes, Alt+S skills, Alt+E inventory, Alt+Q equipment, Alt+G clan

**Goal:** today each window opens with a bare letter (`UiSlice._unhandled_input`: I, C, K, H, T, Y,
P, G, M, L, O), and those letters are reserved away from the hotbar (`Hotbar.RESERVED_KEYS`). Every
window shortcut becomes Alt + a letter, and the bare letters are freed.

**Newel dependency:** NO.

**Depends on:** none. Alt+G opens the Settlement window until Phase 204 turns it into the clan
window, and then opens the clan window.

**Deliverables:**
- One table, `UiSlice.WINDOW_SHORTCUTS` (`{window, keycode}`, Alt implied), drives the key handler,
  the window dock's letter chips (`window_dock.gd`), the `?` controls rows and the reserved-key list.
  No window letter is written anywhere else.
- The bindings:

  | Shortcut | Window |
  |---|---|
  | Alt+A | Attributes: the six attributes and the derived stats |
  | Alt+S | Skills |
  | Alt+E | Inventory |
  | Alt+Q | Equipment: the paper doll and the equipment slots |
  | Alt+G | Clan (the guild): Settlement until Phase 204 |
  | Alt+H | Crafting |
  | Alt+T | Technology |
  | Alt+Y | Trade |
  | Alt+P | Market |
  | Alt+V | Proposals (G goes to the clan) |
  | Alt+M | Map |
  | Alt+O | Admin (admins only, as in Phase 182) |

  `?` (controls), Enter and `/` (chat) and ESC (close all) are not window letters and stay as they
  are. A window added later gets an Alt+letter row in the same table.
- The Phase 179 character window is split in two: **Attributes** (attributes and derived stats) and
  **Equipment** (paper doll and slots). Each has its own dock entry, title key and icon (Phase 175
  generator). The playtest bot's `character_sheet` step opens both and keeps its checks.
- Matching uses `keycode` with `alt_pressed` and ignores `unicode`, so macOS Option characters and
  non-US layouts still match. Ctrl or Meta held with Alt does not match. Alt+F4 and Alt+Tab are left
  to the OS.
- Bare-key handlers ignore an event with Alt held: E (equipment visibility) and G (tame) in
  `PlayerSlice`, Q (gesture wheel), R, B, V, and the hotbar's 1–9 and box keys. So Alt+E opens the
  inventory and does not also strip the gear. Typing in a text field still triggers no shortcut.
- `Hotbar.RESERVED_KEYS` drops the window letters that nothing else uses (I, C, K, H, T, Y, P, M,
  L, O), so a hotbar box can take them. A box key is still a bare letter: Alt+letter can never be
  bound to a box.
- The dock chips and the `?` rows show `Alt+A` and so on, with the modifier label from a catalog key
  (`controls.key.alt`). `controls.row12` drops "G is shared with Proposals", and `controls.row13` and
  `controls.row14` are rewritten for the new keys. Tutorial steps that quote a window key (Phase 186)
  read it from the table.

**Acceptance criteria:**
- [ ] Suite: each `WINDOW_SHORTCUTS` row opens its window from a synthetic Alt+key event, and a
  second press closes it. The same key without Alt opens no window.
- [ ] Suite: Alt+E opens the inventory and emits no `character_equipment_toggle_requested`. Alt+Q
  opens Equipment and not the gesture wheel. Alt+G opens the clan (or Settlement) window and does
  not tame.
- [ ] Suite: Ctrl+Alt+A, and an Alt+key with a focused `LineEdit`, open nothing. An Alt+key whose
  `unicode` is an Option character still matches on `keycode`.
- [ ] Suite (audit): no window letter is matched outside `WINDOW_SHORTCUTS`. The dock chips and the
  controls rows are built from it, every window in `WINDOW_KEYS` except controls and gestures has
  exactly one row, and no two rows share a key.
- [ ] Suite: a hotbar box accepts a freed letter (I, K…) and refuses an Alt+letter.
- [ ] Suite: the Attributes window lists every attribute and derived stat, and the Equipment window
  lists every slot.
- [ ] Playtest bot: `character_sheet` opens Attributes and Equipment with Alt+A and Alt+Q and passes
  its Phase 179 checks.
- [ ] Every new string is in both catalogs, and the i18n key check passes.
- [ ] Suite green on both boot paths.

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
- **Clan skills** — abilities (such as teleporting every member to one place) for the two or three members who contribute most to a clan. Contribution is to be defined, probably as a share of members' experience given to the clan. Clan tiers (Phase 210) give nothing until then.
- **Elder buildings** — buildings only a clan's top contributors can build. To be designed.
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
