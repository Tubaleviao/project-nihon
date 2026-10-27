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

Phases 1–179, 182 and 187–191 are done. Their specs and acceptance criteria are archived in
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
| 180 | Character creation in the fabric: name, appearance and starting attributes | Planned | below |
| 181 | Character creation at runtime: a creation screen before the first spawn | Planned | below |
| 183 | Playtest process time under 16 ms | Planned | below |

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

### Arc: first steps (Phases 184–186)

A new player lands in the world with no guidance except instructions scattered through the UI
(tooltips that say "drag here", a map hint bar, chat and trade prompts). This arc gives them one
guided path for the first hour: move, gather, craft the first tools and stations, build a shelter
with a bed, and kill a first creature. The bed becomes their spawn point. Each tutorial step
appears once, never comes back after it is dismissed, and the whole tutorial can be switched off.
The scattered UI instructions are removed, so the tutorial is the one place that teaches.

| Phase | Title | Status | Spec |
|---|---|---|---|
| 184 | First steps in the fabric: the tutorial steps, the bed and a shelter rule | Planned | below |
| 185 | The bed is the spawn point: host-owned, persisted, one per player | Planned | below |
| 186 | The first-steps tutorial at runtime: one-time cards, a toggle, and no other in-UI tutorial | Planned | below |

---

## Phase 180 — Character creation in the fabric: name, gender, hair and a chibi art style

**Goal:** a player never creates a character. They spawn with a default appearance and are known by
a handle. Model a small set of creation choices (name, gender, hair style, hair colour) so the
runtime screen in Phase 181 is generated from data, and set the character art style it uses.

**Newel dependency:** NO.

**Depends on:** Phase 177.

**Art direction:** characters are cute, chunky chibi figures in the spirit of Ragnarok Online:
a big head (about a third of the height), large expressive eyes, short limbs, big hands and boots,
and bold, chunky hair that carries most of the identity. They are our own designs, never copies:
no Ragnarok hair styles, outfits, palettes, names or proportions traced from it. Reference for the
mood: a 3D chibi novice in a plain leather outfit, framed alone on a dark, quiet backdrop.

**Deliverables:**
- `fabric/gameplay/characters/creation.js` (new): a `CharacterCreation` entity with:
  - name rules: 3–16 characters, Unicode letters from a single script (no Latin mixed with
    Cyrillic or Greek) plus a single inner space, hyphen or apostrophe, unique per server after
    case folding, accent folding and a confusables skeleton (Unicode TR39), so "Аlice" with a
    Cyrillic А collides with "Alice", and a reserved list;
  - gender: two options (masculine, feminine). Each maps to a fixed body preset in
    `appearances.js` (body, head, eyes, skin colour and chibi proportions), so the player does not
    pick those parts;
  - hair: a list of hair styles per gender and a curated hair colour list (palette indices);
  - a default creation (one gender, hair style and colour) and a starting kit per server rule
    (a plain novice outfit by default; no class kits, the sandbox has none).
  Attributes are not chosen at creation: every character starts at the Phase 177 base values.
- A `chibi` proportion preset in `appearances.js` (large `headScale`, short limbs) used by both
  gender presets, within the §8 bounds (widen the bounds if needed and say so in the bible).
- Public placeholders for both gender bodies, the novice outfit, at least six hair styles per
  gender and the hair colour list, at the same keys the private repo will fill (placeholder rule;
  `gen_placeholder_glb.py`). Each hair style also gets a UI icon (the picker grid shows hair, not
  names), drawn by `tools/gen_ui_icons.py`.
- `tools/check_creation.js`: every gender preset, hair style and colour refers to an existing
  part or palette index, each gender has at least one hair style, and the default is a valid
  creation.

**Acceptance criteria:**
- [ ] `npm run validate`, `npm run check-drift` and `node tools/check_creation.js` pass.
- [ ] Suite: every gender preset and hair option resolves through `AssetOverlay` in the public
  build, and every hair style has an icon.
- [ ] Suite: the name rule accepts and rejects a fixture list, including accents, emoji, a
  reserved word, a case-folded duplicate and a mixed-script or confusable duplicate.
- [ ] Suite: a creation with a hair style from the other gender, an unknown hair style or a hair
  colour outside the list is refused.
- [ ] Suite: the default rig's head-to-height ratio is within the chibi preset range.

---

## Phase 181 — Character creation at runtime: a creation screen before the first spawn

**Goal:** a new player creates a character before they enter the world. They pick a name, a
gender, a hair style and a hair colour and see the result live. The host validates everything and
records it.

**Newel dependency:** NO.

**Depends on:** Phases 179 and 180.

**Deliverables:**
- A creation screen shown on first join to a server where the player has no character record,
  before spawn placement (Phase 53). Layout: the hair style grid (icons) on the left with a hair
  colour row under it, the live chibi rig in the centre on a dark backdrop (reusing the Phase 179
  viewport), gender toggles on either side of the rig, and the name field with an "enter the
  world" button at the bottom right. A randomize button picks a gender, hair and colour.
- The screen's skin is art at overlay keys, never baked into the scene. The layout, sizes,
  margins and font sizes live in code. Only pixels come from assets, so the private repo
  (`project-nihon-assets` Phase A20) can replace them without a code change:
  - `textures/ui/creation/backdrop.png.raw`: the dark backdrop behind the rig;
  - `textures/ui/creation/panel.png.raw`: a 9-slice frame for the hair grid, colour row and name
    panel (patch margins fixed in code);
  - `textures/ui/creation/rig_frame.png.raw`: the frame around the rig viewport;
  - `textures/ui/creation/button.png.raw`, `button_hover.png.raw`, `button_pressed.png.raw`: 9-slice
    states for "enter the world", randomize and the gender toggles;
  - `icons/ui/creation/<control>.png.raw`: the randomize and gender toggle icons, drawn by
    `tools/gen_ui_icons.py`.
  The overlay ships bytes, not Godot themes, so the screen loads each PNG through
  `AssetOverlay.load_texture` and builds its `StyleBoxTexture`s in code. It never loads a `.tres`
  theme from the overlay.
- **Public placeholder:** a generator (`tools/gen_ui_skin.py`, or a mode of
  `gen_placeholder.py`) writes every skin key above as flat colour at its final size, with
  `--check` like `gen_ui_icons.py`. The placeholders land in this phase, before any art in the
  private repo.
- A host intent `create_character(name, gender, hair, hair_color)`. The host validates the name
  rule and uniqueness and every option, creates the record, then places the spawn.
  It refuses with a keyed reason that the client renders in its locale. Rate-limited.
- Existing players without a creation record are offered the screen once. Their handle and
  progress are kept. A player who skips it keeps the default appearance and their
  handle as display name. The host records the skip, and the screen stays reachable from the
  character sheet until they create a character.
- The display name shows on the character sheet, in chat and settlement lists, and on a nameplate
  above other players. The friend code stays the handle.
- The appearance recipe syncs to peers in the area of interest, so everyone sees each other's
  character.
- The playtest bot creates a character as its first step.

**Acceptance criteria:**
- [ ] Suite: the host accepts a valid creation and refuses each invalid field (name, gender,
  hair style, hair colour) with its own key.
- [ ] Harness: `create_character` over the socket. A duplicate name from a second client is
  refused, and the second client sees the first one's appearance and nameplate.
- [ ] Suite: a pre-181 save boots, offers creation once and keeps inventory and skills. A skip is
  recorded, is not offered again on the next join, and shows the handle on the nameplate.
- [ ] Playtest bot: a `create` step completes before `walk` and saves a screenshot of the screen.
- [ ] Suite: every skin and icon key the screen reads has a public placeholder at that key, no
  orphan exists under `textures/ui/creation/` or `icons/ui/creation/`, and the screen builds
  with only the public tree (no `assets.pck`). The skin generator's `--check` passes in CI.
- [ ] Every new string is in both catalogs, and the i18n key check passes.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 183 — Playtest process time under 16 ms

**Goal:** Phase 174 gated `walk`, `craft` and `fight` on p95 process time (the scene tree's `_process`
work per frame) and found them at 26, 27 and 18 ms on llvmpipe with the native builder loaded (median of
3 local runs on the pinned seed). Physics is under 1.5 ms, so the cost is main-thread `_process` work,
not the chunk build. Name it and cut it.

**Newel dependency:** NO.

**Depends on:** Phase 174.

**Deliverables:**
- Profile the three steps (per-slice `_process` timing, `Performance` custom monitors) and name the
  top main-thread cost in the PR.
- Fix it, then lower `docs/perf/playtest-budget.json` and the table in `docs/perf/playtest-baseline.md`
  toward the 16 ms target.

**Acceptance criteria:**
- [ ] The top main-thread cost per step is named in `docs/perf/playtest-baseline.md`.
- [ ] CI playtest: `walk`, `craft` and `fight` median p95 process time is ≤ 16 ms × 1.25.
- [ ] Suite green on both boot paths.

---

## Phase 184 — First steps in the fabric: the tutorial steps, the bed and a shelter rule

**Goal:** model the first-steps tutorial and the bed as data, so Phase 185 and Phase 186 read
everything from `GameData` and adding or reordering a step is a fabric change, not a code change.

**Newel dependency:** NO.

**Depends on:** none (Phase 131 i18n and the existing crafting, station and combat tables).

**Deliverables:**
- `fabric/gameplay/tutorial.js` (new): a `Tutorial` entity with an ordered list of steps. Each step
  has an `id`, a `chapter`, a title key and a body key (`tutorial.<id>.title` / `.body`), the input
  actions it names (read from the input map at runtime, so a rebind shows the player's own key),
  an optional `requires` (step ids that must be done first) and a `completion` trigger. A trigger is
  one of a closed set of event kinds the client already receives: `moved_metres`, `camera_turned`,
  `jumped`, `item_gathered(item|tag, count)`, `item_crafted(item|tag)`, `station_placed(type)`,
  `window_opened(window)`, `hotbar_bound`, `item_equipped(slot)`, `creature_killed(tag)`,
  `carcass_harvested`, `bed_placed`, `shelter_complete`, `respawned`, `waystone_discovered`,
  `skill_tier_up`. The steps:
  - **Moving:** walk (WASD), jump, look around (hold right mouse), zoom; open the `?` controls
    reference.
  - **Gathering:** pick up loose stones and sticks, chop a tree, mine a block; open the inventory;
    put something on the bottom bar and use it by its key.
  - **First tools:** open crafting, craft a first tool (axe or pick from the existing early
    recipes), equip it, see durability on the tooltip and that a better tool gathers faster.
  - **First stations:** place a first station (B · V), craft one recipe that needs it.
  - **Shelter:** place blocks to make a roofed space, craft and place a bed inside it. The card
    explains that the bed is now the spawn point.
  - **First hunt:** equip a weapon, kill a first creature, harvest or haul its carcass, cook or eat.
  - **Staying alive** (added): health and regeneration, night and weather danger, what happens on
    death and that you come back at your bed.
  - **Finding your way** (added): the map and minimap, waypoints, the first waystone.
  - **Growing** (added): skills grow by use (the skills window), the first tier-up, the character
    sheet once Phase 179 lands.
  - **Other people** (added): chat and `/help`, trading, and a pointer to settlements and the
    Hearth once the player has a shelter.
- A `Bed` item and recipe in `fabric/gameplay/items/` and `recipes/` (early materials: planks and
  fibre or hide, no station needed, so a bed is reachable in the first hour). It is placeable
  through the station placement path as station type `bed`, with a shape (`shape.js`) and an icon at
  `assets/icons/items/Bed.png.raw` (Phase 176 generator). One bed per player.
- A shelter rule in the fabric: a bed is sheltered when a solid block lies within N metres straight
  above it and at least K of the 4 sides are closed within M metres (N, K and M in the table). It is
  one pure rule, read by both the host (Phase 185) and the tutorial trigger (Phase 186).
- Both catalogs gain every `tutorial.*` key and the bed keys.
- `tools/check_tutorial.js`: every step id is unique, every `requires` names an earlier step (no
  cycles), every trigger kind is in the closed set and names an existing item, tag, station type or
  window, and every key exists in both catalog columns. CI runs it.

**Acceptance criteria:**
- [ ] `npm run validate`, `npm run check-drift` and `node tools/check_tutorial.js` pass, and the
  checker rejects a fixture with a duplicate id, a forward `requires`, an unknown trigger kind and a
  missing catalog key.
- [ ] Suite: `GameData` exposes the steps in order, and every step's completion trigger resolves to
  a known item, tag, station type or window.
- [ ] Suite: the bed recipe is craftable from items an early recipe or a gather table yields (no
  dependency on a station or technology the first hour cannot reach).
- [ ] Suite: the shelter rule accepts a roofed fixture and refuses an open one and a roof-only one.
- [ ] Every new key is in both catalogs, and the i18n key check passes.

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
