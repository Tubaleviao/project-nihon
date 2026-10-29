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

Phases 1–184 and 187–193 are done. Their specs and acceptance criteria are archived in
[docs/roadmap-history/](docs/roadmap-history/README.md).

### Arc: make it look and feel like an RPG (Phases 173–181, 183)

After 172 phases the engine is strong: a deterministic planet, host-authoritative multiplayer,
persistence, crafting, combat, taming and settlements. But it does not yet look or play like an
RPG. Items and windows show letters, the character has no attributes, and a player never creates a
character: they spawn as a handle. This arc pays down the follow-up debt and makes the frame
budget honest. Then it gives the game icons, attributes, a character sheet and character creation.

| Phase | Title | Status | Spec |
|---|---|---|---|
| 174 | An honest playtest frame budget | Done | [phases-174.md](docs/roadmap-history/phases-174.md) |
| 175 | UI icons: dock, windows, skills and status from one generator | Done | [phases-175.md](docs/roadmap-history/phases-175.md) |
| 176 | An icon for everything a player can hold | Done | [phases-176.md](docs/roadmap-history/phases-176.md) |
| 177 | Attributes in the fabric: strength, vitality, resistance, agility, intelligence, perception | Done | [phases-177.md](docs/roadmap-history/phases-177.md) |
| 178 | Attributes at runtime: host-owned, persisted, feeding the derived stats | Done | [phases-178.md](docs/roadmap-history/phases-178.md) |
| 179 | The character sheet: a paper doll, attributes and derived stats | Done | [phases-179.md](docs/roadmap-history/phases-179.md) |
| 180 | Character creation in the fabric: name, gender, hair and a chibi art style | Done | [phases-180.md](docs/roadmap-history/phases-180.md) |
| 181 | Character creation at runtime: a creation screen before the first spawn | Done | [phases-181.md](docs/roadmap-history/phases-181.md) |
| 183 | Playtest process time under 16 ms | Done | [phases-183.md](docs/roadmap-history/phases-183.md) |

### Out of arc: admin tools (Phase 182)

Requested during playtesting, and done ahead of the arc: an admin needs to set the weather, the
time of day, a player's speed and health, and to regenerate a world whose recorded terrain is out of
date (for example, a world recorded around the pre-worldgen-9 spawn pit).

| Phase | Title | Status | Spec |
|---|---|---|---|
| 182 | Admin tools: /time, /speed, /fly, /heal, /regen world and an Admin window | Done | [phases-182.md](docs/roadmap-history/phases-182.md) |

### Next, ahead of the arc: fast flight and worldgen fixes (Phases 187–191)

Found while flying with `/fly` and `/speed 10` (90 m/s): the ground fell behind the player, and a
regenerated world was snow almost everywhere. Like Phase 182, this runs ahead of the RPG arc: Phase
179 resumed after Phase 191. Phase 188 comes second because a worldgen bump is cheaper the fewer worlds
have recorded the old plateaus. Phases 189–191 then raise the admin speed cap on a slow machine.

Measured on seed 42 at 90 m/s with the native builder (probe in the Phase 187 PR): chunk builds ran
at low priority, so 11 builds sat in flight while three ran, and the chunk under the body was missing
for seconds at a time. Once builds keep up, the main thread is the next wall. Each attached chunk costs
9.3 ms of collision, 5–6.5 ms of dispatch and bookkeeping, 4.5–12 ms of creature spawns and 1.7 ms of
render mesh, at 27 chunks/s.

| Phase | Title | Status | Spec |
|---|---|---|---|
| 187 | Fast flight I: high-priority builds, a heading-first queue and a flight step | Done | [phases-187.md](docs/roadmap-history/phases-187.md) |
| 188 | Mountain ranges, not plateaus: narrower ridges, a temperature tree line and a low spawn plain | Done | [phases-188.md](docs/roadmap-history/phases-188.md) |
| 189 | Fast flight II: collision and contents only near the body | Done | [phases-189.md](docs/roadmap-history/phases-189.md) |
| 190 | Fast flight III: coarse chunks beyond the near ring | Done | [phases-190.md](docs/roadmap-history/phases-190.md) |
| 191 | Fast flight IV: a recent-chunk cache, no holes, and a /speed cap of 30 on a slow machine | Done | [phases-191.md](docs/roadmap-history/phases-191.md) |

### Out of arc: creature bodies (Phase 192)

Found while playing: creatures walked through each other and through the player. Requested ahead of
the arc, like Phase 182.

| Phase | Title | Status | Spec |
|---|---|---|---|
| 192 | Creature bodies: creatures collide with each other and the player, and squash on contact | Done | [phases-192.md](docs/roadmap-history/phases-192.md) |

### Out of arc: a lighter collision ring (Phase 193)

Found on PR #524: the playtest walk step's median p95 process time reached 21.1 ms (limit 20) on a slow
runner. Profiled locally, the biggest cost in the walk was Jolt taking the collision trimeshes of the 16
chunks two rings out, which only the 60 m aim ray needed.

| Phase | Title | Status | Spec |
|---|---|---|---|
| 193 | A lighter collision ring: a voxel aim ray, collision one ring out, and a dive guard | Done | [phases-193.md](docs/roadmap-history/phases-193.md) |

### Arc: first steps (Phases 184–186)

A new player lands in the world with no guidance except instructions scattered through the UI
(tooltips that say "drag here", a map hint bar, chat and trade prompts). This arc gives them one
guided path for the first hour: move, gather, craft the first tools and stations, build a shelter
with a bed, and kill a first creature. The bed becomes their spawn point. Each tutorial step
appears once, never comes back after it is dismissed, and the whole tutorial can be switched off.
The scattered UI instructions are removed, so the tutorial is the one place that teaches.

| Phase | Title | Status | Spec |
|---|---|---|---|
| 184 | First steps in the fabric: the tutorial steps, the bed and a shelter rule | Done | [phases-184.md](docs/roadmap-history/phases-184.md) |
| 185 | The bed is the spawn point: host-owned, persisted, one per player | Planned | below |
| 186 | The first-steps tutorial at runtime: one-time cards, a toggle, and no other in-UI tutorial | Planned | below |

---

## Phase 185 — The bed is the spawn point: host-owned, persisted, one per player

**Goal:** today a player always respawns at the original spawn (Phase 66). Placing a bed moves
their spawn point to the bed. The host owns it.

**Newel dependency:** NO.

**Depends on:** Phase 184.

**Deliverables:**
- The host records a `bed` entry on the player record (`{chunk, local}` exact position, Phase 87)
  when that player places a bed. Placing a second bed removes the first one, which drops back as an
  item. `GameRoot.respawn_point_for()` prefers the bed, then the original spawn, then the saved
  position.
- A bed whose block is destroyed, whose chunk is regenerated (Phase 182 `/regen world`), or which is
  removed by someone allowed to build there clears the entry. The owner gets a keyed notice
  (`bed.lost`) and respawns at the original spawn.
- Respawn at a bed whose spot is now blocked picks the nearest free standing cell within a bounded
  radius. If there is none, the original spawn.
- The host validates the placement: the player holds a bed, the target is in reach and allowed by
  settlement build rules, and the space is free. Other players cannot use or claim someone else's
  bed. The intent is rate-limited, and a refusal returns a keyed reason.
- The bed's position syncs to its owner only (`bed_synced`), so the map can mark it. Peers see the
  bed as an ordinary placed station.
- A save from before this phase loads with no bed and the old respawn rule (versioned migration, as
  in Phase 121).

**Acceptance criteria:**
- [ ] Suite: with a bed, `respawn_point_for()` returns the bed; without one, the original spawn; a
  pre-185 record loads with no bed and the same respawn point as before.
- [ ] Suite: a second bed replaces the first and returns it as an item; a destroyed bed clears the
  entry and emits `bed.lost`; a blocked bed respawns at the nearest free cell.
- [ ] Suite: the host refuses a bed placement without a bed in the inventory, out of reach, in a
  settlement the player cannot build in, and a placement on another player's bed, each with its own
  key.
- [ ] Harness: a client places a bed over the socket, dies and respawns at the bed; a second client
  never receives the first one's `bed_synced`.
- [ ] Every new string is in both catalogs, and the i18n key check passes.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 186 — The first-steps tutorial at runtime: one-time cards, a toggle, and no other in-UI tutorial

**Goal:** show the Phase 184 steps to a new player as small cards that each appear once and never
come back after they are completed or dismissed. A player who knows the game switches the tutorial
off. Every other teaching text in the UI goes away, so the tutorial is the one place that teaches.

**Newel dependency:** NO.

**Depends on:** Phases 184 and 185.

**Deliverables:**
- `src/tutorial/tutorial_rules.gd`: pure functions over the step table: the next eligible step
  (all `requires` done, not done, not dismissed), whether an event completes the current step, and
  the progress per chapter.
- `src/tutorial/tutorial_slice.gd` + `tutorial_wiring.gd`: listen to the bus events the client
  already gets (movement, `inventory_synced`, crafting and station results, `creature_killed`,
  `bed_synced`, window opens…) and complete steps. The tutorial is client-side only: it sends
  nothing to the host and changes no game state.
- A card in a screen corner that does not block play: chapter, title, body with the player's own
  bound keys, a step counter, **Dismiss** (this step) and **Turn off tutorial**. A completed step
  shows a short check and moves on. At most one card is on screen.
- State in `user://settings.json` (beside the locale, Phase 131): `tutorial.enabled` and the sets
  of done and dismissed step ids. It is per player on this machine, not per world, so joining a new
  server does not replay the tutorial. A done or dismissed step is never shown again.
- A toggle and a **Restart tutorial** button in the `?` panel beside the language button. Turning it
  off hides the card at once and shows nothing until it is turned on again.
- On first launch with existing progress (a pre-186 player), steps whose condition is already true
  (they own a tool, a station, a bed, have a kill…) are marked done silently, so a veteran is not
  taught to walk.
- Remove every other in-UI tutorial. The instructional parts of these strings move into tutorial
  steps, and what stays only names the thing:
  - `hotbar.empty`, `hotbar.more`, and the "middle-click to place" / "press its key to use" tails of
    `hotbar.hint_block` and `hotbar.hint_skill`;
  - the skills window title and the skill tooltip's "drag onto the bottom bar" line
    (`ui.skills_title`, `ui.skill_tip`);
  - the always-on map hint bar (`map.hint`, `map.hint_tip`) and the "right-click to delete" tail of
    `map.delete_hint`;
  - the "click … to …" prompts in the trade window (`trade.none`, `trade.open`);
  - the "Press Enter to chat" chat placeholder (`chat.placeholder`).
  The `?` controls panel stays: it is a key reference, not a tutorial, and the only help left for a
  player who turned the tutorial off. Tooltips that state what a thing is (name, durability,
  quantity) stay.
- The playtest bot runs with the tutorial on and asserts that its existing steps (walk, gather,
  craft, place, fight…) complete the matching tutorial steps.

**Acceptance criteria:**
- [ ] Suite: `tutorial_rules` returns steps in fabric order, respects `requires`, never returns a
  done or dismissed step, and returns nothing when the tutorial is off.
- [ ] Suite: each Phase 184 trigger kind completes its step from a synthetic bus event, and an
  unrelated event completes nothing.
- [ ] Suite: dismissed and done sets survive a save and reload of `user://settings.json` (a fixture
  path); a corrupt or missing file loads as "tutorial on, nothing done".
- [ ] Suite: a fixture player with a tool, a station and a bed starts with those steps marked done.
- [ ] Suite (audit): the removed keys are gone from both catalog columns, and no `locale/ui.csv` key
  outside `tutorial.*` and `controls.*` contains an instruction verb (click, right-click, drag,
  press, hold, scroll, and the `pt_BR` equivalents).
- [ ] Suite (audit): the tutorial slice emits no bus intent and no network message.
- [ ] Playtest bot: a `tutorial` check after `fight` reports the moving, gathering, first-tools,
  first-stations and first-hunt chapters complete and saves a screenshot of a card.
- [ ] Every new string is in both catalogs, and the i18n key check passes.
- [ ] Suite green on both boot paths.

---

## Deferred (in priority order)

- **Next arc: the first settlement loop** — a goal you can describe from the player's side for
  the arc after this one: four friends found a village, specialize, trade and defend it from a
  raid within an hour of play. Derive its phases from that loop (shared projects, roles from
  skills and attributes, raids, settlement upkeep) rather than from engine work.
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
- **Real cross-region multiplayer run** — Phase 135 emulates WAN profiles in the harness. A run
  between real regions remains.
- **Automatic LOD mesh decimation** — simplified meshes are hand-authored (Phase 23).
- **Dynamic impostor re-bake** — impostor billboards are baked offline. A live re-bake on palette
  change is deferred from Phase 23.
- **Server sharding (last, not before maturity)** — split the authoritative simulation across
  servers by region once one headless server (Phase 27) with spatial hashing (Phase 28) and
  interest management (Phase 29) saturates. No structural change is needed before then. Revisit
  when Brazil-region load approaches one server's ceiling.
