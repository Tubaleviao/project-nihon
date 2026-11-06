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

Phases 1–199 and 202–218 are done. Their specs and acceptance criteria, and the introductions of
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
| 202 | The clan loop, played: four bots found a clan, specialize, trade and build | Done | [phases-202.md](docs/roadmap-history/phases-202.md) |

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
burns down the four open `autopilot-followup` issues. Phase 202 is done.

| Phase | Title | Status | Spec |
|---|---|---|---|
| 215 | Chibi body sheets: public placeholders, the colour mask bound to skin, and the novice outfit region (#559) | Done | [phases-215.md](docs/roadmap-history/phases-215.md) |
| 216 | Mounts: ride a tamed creature | Done | [phases-216.md](docs/roadmap-history/phases-216.md) |
| 217 | Lakes and rivers on unrecorded land (static water, no flow) | Done | [phases-217.md](docs/roadmap-history/phases-217.md) |
| 218 | Follow-up cleanup sweep: exact creature positions, the spatial hash, relay and window shortcuts | Done | [phases-218.md](docs/roadmap-history/phases-218.md) |

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
