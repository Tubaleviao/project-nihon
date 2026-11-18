## Phase 269 — Crafting by hand, and at the station

The crafting window lists every recipe, whatever station it needs, as rows of text.

- **The hand window** (the crafting shortcut) lists only recipes with no station: what a player makes
  on the spot.
- **A station window:** the interact input on a placed station opens that station's window, listing
  only its recipes, titled with the station's name. It closes when the player walks out of the
  station's reach. Chests and beds keep their own interactions.
- **Visual:** a grid of recipe cards, each with the output's icon, its localized name (Phase 267) and
  count. Selecting a card shows the inputs as icons with have/need counts (red when short), the work
  time (Phase 259), the skill it trains, and a Craft button with a quantity. Recipes not yet known
  (technology, discovery) are hidden; known ones the player cannot afford are dimmed, not hidden. A
  search field and category tabs (tools, weapons, building, food…) from the recipe's tags.
- The host's station check stays as it is (`crafting_slice.gd`: a matching station within
  `STATION_RADIUS`, else `station_required:<type>`); the window only stops offering what would be
  refused.

**Acceptance criteria**
- Suite tests: the hand window lists exactly the station-less known recipes; a station's window lists
  exactly that station's known recipes; a station recipe requested with no station in reach is refused
  by the host; a card's have/need counts follow the bag; no card shows an entity id.
- Suite test: the station window closes when the player leaves reach.
- Net harness step: a client opens a station, crafts one of its recipes and gets the item; the same
  request away from the station is refused.
- Every new string is in both locales.

**Delivered.** The crafting shortcut's window (the hand window) and a new station window draw the same card grid
(`src/ui/craft_window.gd`): a card per known recipe with the output's icon, its localized name and count, a search
field and category tabs (All, then tools, weapons, armour, building, consumables and materials when a card is in
them). Selecting a card shows its inputs as icons with have/need counts (red when short), the work time, the skill
the recipe's domain trains (`WorkSkills.craft`) and a Craft button with a quantity capped at what the bag pays for;
an unaffordable card is dimmed, an unknown one (technology, discovery, blueprint: `CraftingSlice.is_recipe_known`) is
not listed. The pure half is `src/crafting/craft_catalog.gd` and the UI slice's half `src/ui/ui_crafting.gd`. Plain U
on a placed crafting station (a type some recipe names, nearer than any chest or door within 3 m) emits
`GameBus.station_window_requested`; the window is titled with the station's content name and closes when its station
is gone or the player is past `CraftingSlice.STATION_RADIUS`. Chests, doors and beds keep U. The host's station gate is
unchanged. Two notes: the generated resources do not carry entity tags, so a recipe's tab comes from an optional
`category` in its structured `recipe` field, else from what it makes (tool or harvest class, weapon slot or shape,
other equipment slot, placeable station item or block or building material, potion, else material); and crafting
has no work time in the fabric yet (Phase 259 timed gathering only), so every card reads "Work time: instant" until a
recipe gives `workSeconds`. `crafting_window_tests.gd` holds the suite criteria; the net harness step `station_craft`
crafts planks at a bench a client opened and has the same request refused once the host moves the bench 40 m away.
