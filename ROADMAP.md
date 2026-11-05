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

Phases 1–199 and 203–214 are done. Phases 202 and 215–218 are open. Their specs and acceptance criteria, and the introductions of
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

**Changed 2026-11-05:** Phase 213 is done, so Phase 202 is rewritten below as the clan loop (a clan, skills from work, a trade, an owned building and a shared chest) instead of a raid and upkeep.

**Changed 2026-10-31 (Phases 203–213):** the owner replaced settlements' claim area with clans and owned structures, and dropped raids. Phase 200 (raids) moved to Deferred, and Phase 201 (upkeep) and project labour are removed. Phase 202 (the loop played, which plays a raid and upkeep) is on hold until it is rewritten as a clan loop after Phase 213. Phase 199 shipped (#539) with a specialty labour bonus, which Phase 207 removes with project labour: specialties then follow from skills alone, which Phase 207 grows from work.

| Phase | Title | Status | Spec |
|---|---|---|---|
| 197 | The settlement loop in the fabric: projects, specialties, raids and upkeep | Done | [phases-197.md](docs/roadmap-history/phases-197.md) |
| 198 | Settlement projects at runtime: a village builds together | Done | [phases-198.md](docs/roadmap-history/phases-198.md) |
| 199 | Specialties at runtime: what each member is good at | Done | [phases-199.md](docs/roadmap-history/phases-199.md) |
| 200 | Raids: a warned, bounded attack the village can defend | Aborted | Deferred |
| 201 | Upkeep: a village that has to keep going | Aborted | — |
| 202 | The clan loop, played: four bots found a clan, specialize, trade and build | Planned | below |

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
| 208 | Chests and doors: owner, clan or everyone, and locks that can be broken or picked | Done | [phases-208.md](docs/roadmap-history/phases-208.md) |
| 209 | Books and blueprints: research shared by writing | Done | [phases-209.md](docs/roadmap-history/phases-209.md) |
| 210 | Clan tiers from buildings and material rarity | Done | [phases-210.md](docs/roadmap-history/phases-210.md) |
| 211 | Earth-scale mountains: peaks to about 8,850 m on unrecorded land | Done | [phases-211.md](docs/roadmap-history/phases-211.md) |
| 212 | Floors and structural limits at runtime, and the materials above stone | Done | [phases-212.md](docs/roadmap-history/phases-212.md) |
| 213 | A clan's tower on a mountain: the arc, played | Done | [phases-213.md](docs/roadmap-history/phases-213.md) |

### Out of arc: Alt window shortcuts (Phase 214)

Requested by the owner: window shortcuts should feel like an MMORPG's. Every window opens with Alt
plus a letter, so the bare letters go back to movement, combat and the hotbar. It touches no clan
system, so it can run before, between or after the clan arc's phases.

| Phase | Title | Status | Spec |
|---|---|---|---|
| 214 | Alt window shortcuts: Alt+A attributes, Alt+S skills, Alt+E inventory, Alt+Q equipment, Alt+G clan | Done | [phases-214.md](docs/roadmap-history/phases-214.md) |


### Next batch (Phases 215–218)

Added 2026-11-05 after Phase 214. One step is owner-filed work (#559), two take the top of the
Deferred list (fast travel, rivers and lakes) as far as they go without a design decision, and one
burns down the four open `autopilot-followup` issues. Phase 202 (above) is the fifth.

| Phase | Title | Status | Spec |
|---|---|---|---|
| 215 | Chibi body sheets: public placeholders, the colour mask bound to skin, and the novice outfit region (#559) | Planned | below |
| 216 | Mounts: ride a tamed creature | Planned | below |
| 217 | Lakes and rivers on unrecorded land (static water, no flow) | Planned | below |
| 218 | Follow-up cleanup sweep: exact creature positions, the spatial hash, relay and window shortcuts | Planned | below |

---

## Phase 202 — The clan loop, played: four bots found a clan, specialize, trade and build

**Rewritten 2026-11-05** (was the settlement loop with a raid and upkeep, both dropped 2026-10-31).

**Goal:** prove the clan arc's goal with an automated gate. Four scripted players on a dedicated
server found a clan, join it, grow different skills from work, see each other's skills, trade, and
build a clan-owned building with a clan chest. The in-game time they spend playing, not counting
time skipped with admin commands, must stay under one hour.

**Progress (2026-11-05, not done):** `tools/clan_scenario.sh` boots a dedicated server and five bots
(`--stress-bots 5 --stress-scenario clan`); `src/tests/clan_scenario.gd` plays found, invite and join,
a mining `work` beat (all four gain Building from the ground under their feet, so the different-skills check is still unmet: Smithing and Carpentry need ore and trees, whose ids a bot without terrain cannot name), roster with skills, whisper and the outsider's refused join over ENet and judges each from what the host
sent back. The pure rules, report and verdict are in `src/tests/clan_scenario_rules.gd` (suite-tested).
Still to do: the work, trade, build, chest and dismantle beats (a bot starts with an empty pack, so it
must mine, chop, smelt and craft its way to a Chest and blocks through the host's own checks), the
outsider's chest and build refusals, the host-side world record for the `checks`, the CI job and the
3-run check.

**Newel dependency:** NO.

**Depends on:** Phases 204–213, the stress bot process (Phase 162).

**Deliverables:**
- A `clan` scenario in the stress bot process (`src/tests/stress_bots.gd`, today movement only): four
  bots on the pinned playtest seed and `PlaytestBot.PLAYER_ID`-style pinned ids. Bot 1 founds a clan
  by name and invites the others, who accept. Each bot works a different kind of work (gathering,
  crafting, building, sewing or smithing) until its skill for it grows. One bot whispers another
  (Phase 204) and they trade one item through the trade window protocol. Together they place a
  clan-owned building inside the floor limits (Phase 212), set a chest in it to clan access and move
  an item through it, and one bot dismantles a private block of its own.
- Every intent goes over ENet through the same host validation a real client meets; the scenario
  sends no admin command except `/time` skips, which it records.
- `stress/clan.{md,json}`: each beat with its in-game and wall time, its host-side evidence and a
  verdict. `tools/stress_report.gd` renders it.
- A CI job (`xvfb` not needed: dedicated server and headless bots) that runs the scenario.

**Acceptance criteria:**
- [ ] CI: the scenario passes every beat, and its reported in-game play time (excluding admin time
  skips) is under 60 minutes.
- [ ] CI: read from the host's world record at the end, the clan has 4 members, at least two members
  have a different highest skill, one trade completed, the clan owns at least one structure, and the
  clan chest's access mode is `clan` with the moved item in it.
- [ ] CI: a fifth, non-member bot's attempt to open the clan chest and to build inside the clan's
  circle is refused by the host (the refusal key is in the report).
- [ ] The scenario passes 3 CI runs in a row on an unchanged commit.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 215 — Chibi body sheets: public placeholders, the colour mask bound to skin, and the novice outfit region

**Closes:** #559.

**Goal:** the private art repo can ship the chibi bodies' texture sheets. Today
`models/characters/bodies/chibi_body_{m,f}.glb.raw` exist in `assets/`, but their sheets do not, so
the placeholder rule forbids the art repo from adding them, and the game binds only the old
`textures/characters/player*` sheets to every rig.

**Newel dependency:** NO.

**Deliverables:**
- `tools/gen_placeholder.py` makes `assets/textures/characters/bodies/chibi_body_{m,f}.png.raw`,
  `chibi_body_{m,f}_color_mask.png.raw` and `chibi_body_{m,f}_channel.png.raw` (64×64; mask R/G/B =
  Primary/Secondary/Accent, channel R/G/B = Metal/Emission/Wear, as the `player*` sheets), listed under
  `textures` in `assets/manifest.json`.
- `CharacterSlice` picks the sheet set by the rig's body key (the gender's chibi body), falling back to
  the `player*` sheets for any body without its own, and binds them through
  `CharacterMaterial.bind_rig_textures`. Skin colour from the look is driven through the mask's skin
  channel, not a separate material.
- The novice outfit occupies a documented UV region of the sheet (`assets/README.md` and the
  characters bible section), so the art repo paints it in place.

**Acceptance criteria:**
- [ ] Suite: every new key exists in `assets/`, is in `assets/manifest.json`, is 64×64 and decodes;
  the placeholder-rule audit passes.
- [ ] Suite: a male and a female look bind their own body's `detail_tex`, `color_mask_tex` and
  `channel_tex`; a body key with no sheets binds the `player*` sheets.
- [ ] Suite: changing a look's skin colour changes the material parameter the mask's skin channel
  reads, on both genders.
- [ ] Suite green on both boot paths, harness green; the `--playtest-bot` character_sheet and create
  steps still pass.

---

## Phase 216 — Mounts: ride a tamed creature

**Goal:** the first fast travel beyond waystones (Deferred: "Fast travel beyond waystones"). A
player who has tamed a mountable creature can mount it, travel faster than on foot, and dismount.
Taming (`src/creature/taming_slice.gd`) already binds a creature to its tamer as a companion.

**Newel dependency:** NO.

**Deliverables:**
- Fabric: a `mount` field on creatures (speed factor, stamina or none, which terrain it can cross,
  rider offset), set on at least one existing tameable creature; a validator with
  `tools/check_mounts.js` proving it rejects bad tables (speed factor ≤ 1, mount on a non-tameable
  creature), and a CI step. Separate fabric PR, as the convention asks.
- Runtime: mount and dismount intents on `GameBus`, validated on the host (the creature is the
  player's own tamed companion, within reach, alive, not already ridden). While mounted the player's
  movement speed is the mount's factor times the walking speed, the companion follows the rider's
  exact position (Phase 171 `{chunk, local}`), and the host rejects movement faster than the mount
  allows. Damage to the mount or its death dismounts the rider; logging out dismounts and leaves the
  companion beside the player.
- A Mount/Dismount entry in the gesture or companion UI and a key binding, with `en` and `pt_BR`
  strings in `locale/ui.csv`.
- A `mount` step in `--playtest-bot`, after `travel`: tame, mount, ride 200 m, dismount.

**Acceptance criteria:**
- [ ] `npm run validate` and `node tools/check_mounts.js` pass; the checker rejects each bad fixture.
- [ ] Suite: mounting someone else's companion, a wild creature, a dead one or one out of reach is
  refused with a key; a valid mount succeeds and is synced to other peers.
- [ ] Suite: a mounted player's accepted speed is the mount factor times walking speed, and a client
  reporting more is clamped by the host.
- [ ] Suite: the mount's death and the rider's logout each dismount; no orphan nodes.
- [ ] Harness: a client mounts on the host, a second client sees the rider on the mount, the rider
  dismounts.
- [ ] Playtest: the `mount` step passes and its mounted average speed is at least the fabric factor
  × walking speed × 0.9.
- [ ] Suite green on both boot paths, harness green; locale key-parity test passes.

---

## Phase 217 — Lakes and rivers on unrecorded land (static water, no flow)

**Goal:** fresh water above sea level, the first half of the Deferred "Rivers, lakes and fluid flow"
item. Today the only water is the ocean at `WorldSystem.seaLevel`. This phase generates lakes in
basins and rivers down valleys on unrecorded land only, as static water; flow (a cellular automaton)
stays deferred.

**Newel dependency:** NO.

**Deliverables:**
- Fabric: `WorldSystem` (or a new `Hydrology` entity) parameters for lake frequency, minimum basin
  depth, river source height, river width by catchment and the biomes rivers cannot cross, with a
  validator and `tools/check_hydrology.js`.
- `src/terrain/`: a deterministic hydrology field (per region, from the seed) that marks lake
  surfaces and river beds; world-gen carves beds and fills them with water voxels at the lake/river
  surface height. Rivers run downhill to a lake or the sea and never climb.
- The stable-world rule holds: recorded chunks never change, and a river reaching a recorded chunk
  ends at its edge (the frontier, `src/terrain/frontier.gd`, closes it in its blend). Bump
  `TerrainSlice.WORLDGEN_VERSION`, add the history line, update `_test_worldgen_golden`.
- The player's swim/underwater state and the creature path cost treat fresh water like sea water.
- The distant terrain ring draws lake and river surfaces.

**Acceptance criteria:**
- [ ] `npm run validate` and `node tools/check_hydrology.js` pass; the checker rejects each bad fixture.
- [ ] Suite: on the pinned seed, a sampled 64×64-chunk area holds at least one lake and one river;
  each river cell's surface is at or below its upstream neighbour's.
- [ ] Suite: the hydrology field is deterministic (same seed and region → same cells, twice, and
  on a worker thread).
- [ ] Suite: a recorded chunk's voxels are byte-identical before and after the version bump, and no
  water voxel is generated inside a recorded chunk.
- [ ] Suite: a player standing in a lake reports the swimming state; a creature path avoids a river
  wider than its crossing limit.
- [ ] Suite green on both boot paths, harness green; `--playtest-bot` walk, stream and flight steps
  still pass.

---

## Phase 218 — Follow-up cleanup sweep: exact creature positions, the spatial hash, relay and window shortcuts

**Closes:** #531, #537, #542, #558.

**Goal:** burn down every open `autopilot-followup` issue. Each item is fixed, or closed with a
one-line reason when the code it names is gone (for example #542's raider code, removed with raids,
and #537's settlement claim check, removed by Phase 205). Re-check each item against `main` first.

**Newel dependency:** NO.

**Deliverables:**
- #531: relay batch held-entry recipients refreshed; snapshot re-scope retried when dropped;
  `transport.peer_set` cached and read-only, test counters moved off the production base and out of
  `broadcast_aoi`; `ExactSpatialHash` and `SpatialHash` share a base; `creature_ai` passes the exact
  target into `_tick_instance` and steers patrol and companion targets from exact positions; carcass
  comment fixed; `creature_slice` position parameters typed and the `_exact_of` duplicates merged;
  playtest harvest step pins the carcass and retries `out_of_range`.
- #537: `ExactSpatialHash` copies stored position dicts and its header describes the cell-local
  snapshot; a randomized brute-force test of `query_radius` against `WorldPos.offset_between`; a test
  for `separate_bodies`' cross-chunk branch; the project footprint item fixed or closed.
- #542: raider reach judging fixed with exact positions, or closed if no raider code remains.
- #558: `FIRST_RING_TIMEOUT` change recorded in the Phase 214 history; window shortcuts stop walking
  when Alt is released while the letter is held, with an AltGr case tested; the controls rows note
  that Alt+G replaced J for the clan window.

**Acceptance criteria:**
- [ ] #531: every item fixed or closed with a reason; suite tests cover the relay hold, the re-scope
  retry and exact patrol steering.
- [ ] #537: the randomized `query_radius` test (Z edge, corner, negative chunks, same-cell update)
  and the cross-chunk separation test pass.
- [ ] #542: fixed with a test, or closed with the reason recorded in the issue.
- [ ] #558: a test releases Alt before the letter and asserts no walk resumes; an AltGr event opens
  no window.
- [ ] All four issues closed; `tools/check_followups.sh` reports 0 open from this batch.
- [ ] Suite green on both boot paths, harness green.

---

## Deferred (in priority order)

- **Fluid flow** — flowing water (a cellular automaton on dirty chunks only) after Phase 51's
  static sea level, Phase 137's falling sand and Phase 217's static lakes and rivers.
- **Fast travel beyond waystones** — a planet takes about 90 days to walk around. Phase 125 added
  waystones and Phase 216 mounts; roads and boats remain.
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
