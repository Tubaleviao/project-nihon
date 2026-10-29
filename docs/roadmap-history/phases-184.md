# Roadmap history — Phase 184

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 184 — First steps in the fabric: the tutorial steps, the bed and a shelter rule ✅ Done

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
- [x] `npm run validate`, `npm run check-drift` and `node tools/check_tutorial.js` pass, and the
  checker rejects a fixture with a duplicate id, a forward `requires`, an unknown trigger kind and a
  missing catalog key.
- [x] Suite: `GameData` exposes the steps in order, and every step's completion trigger resolves to
  a known item, tag, station type or window.
- [x] Suite: the bed recipe is craftable from items an early recipe or a gather table yields (no
  dependency on a station or technology the first hour cannot reach).
- [x] Suite: the shelter rule accepts a roofed fixture and refuses an open one and a roof-only one.
- [x] Every new key is in both catalogs, and the i18n key check passes.

**Outcome:** `fabric/gameplay/tutorial.js` holds 32 steps in 10 chapters (`GameData.TUTORIALS["Tutorial"]`),
the closed trigger set, the input actions (now the `action` id of each `?` controls row) and the window
keys. `fabric/gameplay/bed.js` holds `BedSpawn` (`GameData.WORLD_SYSTEMS`): station type `bed`, placement
item `Bed`, one per player, the `bed.placed` / `bed.lost` notices and the shelter rule (roof within 3 m,
3 of 4 sides closed within 2 m at 1 m wall height), applied by `src/world/shelter_rule.gd`. The `Bed`
item (new `bed` shape archetype, model and icon from `tools/gen_item_assets.py`) and `RecipeBed` (six
planks, no station, Basic Carpentry) are in `items/furniture.js` and `recipes/carpentry.js`; `StationSlice`
places a bed for one `Bed`. `tools/check_tutorial.js` (CI) and `src/tests/suites/tutorial_tests.gd` cover
the criteria. Changes from the plan, found while modelling:
- **A starting axe.** Trees are the only wood source and need an axe, and every axe recipe needs wood
  (and Duskfiber, which grows only in the Twilight Grove), so a new player could never reach planks, a
  station or a bed. `CharacterCreation.startingKit` now gives a `CarpenterAxe`; the first-hour suite
  test computes reachability from the kit, what bare hands mine and the axe chops in a spawn biome, and
  the free technologies and stations.
- **No loose stones or sticks** exist, so Gathering is dig (bare hands), chop, inventory and the bottom
  bar.
- **First stations before first tools.** Every tool recipe needs a station, so the bench and its planks
  come first, then the forge and a pick.
- **Two more trigger kinds:** `technology_researched` (planks and the pick are locked behind Basic
  Carpentry and Basic Smithing) and `chat_sent` (chat is not a window).
- **The bed has no hide or fibre.** Hide needs a forged knife, and fibre a Twilight Grove trip; six planks
  keep the bed in the first hour.
- **Input actions are ids, not an input map.** The game reads keys directly (there is no rebinding), so a
  step names an action id and the card shows the key from the matching `?` controls row.
