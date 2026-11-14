## Phase 260 — Stone tools: an axe, a pick and a shovel from wood and stone, no bench

The first pick is a ferrite pick from a forge (Phase 184's `first_tools` chapter), and the axe came
from the starting kit. A newcomer makes simple tools on the spot instead.

- **Fabric (separate PR):** items `Branch` (a stick picked off the ground or from a felled tree) and
  `LooseStone` (a stone picked off the ground or knocked from rock), both stackable and light.
  Tools `StoneAxe`, `StonePick`, `StoneShovel`, plus `StoneKnife` (Phase 160's `knife` harvest tool
  at a low `efficiency`) and `StoneHammer` if building needs one. Each is `Branch` + `LooseStone` in
  small amounts, with **no station**, under a free technology (research cost 0, no prerequisite,
  like `TechBasicCarpentry`) and a novice skill guard. Low durability; their `workSpeed` sits
  between bare hands and the ferrite tools (Phase 259).
- **The shovel** gives a new tool class, `shovel`, that digs soil, sand and gravel fastest;
  `voxel_edit.gd` reads the held shovel like it reads the pick.
- Felling a tree also yields a few branches; mining host rock has a chance to yield a loose stone
  beside its material, so the inputs never run out where there is rock and wood.
- The crafting window lists station-free recipes without a station, as the bed already is
  (Phase 184).

**Acceptance criteria**
- `npm run validate` and `check-drift` pass; a `check_*.js` rejects a stone tool with a station or a
  technology that costs research points.
- Suite tests: each stone tool is craftable with no station from `Branch` and `LooseStone` only, on
  a fresh character's known technologies; the shovel digs soil faster than the pick and the pick
  mines rock faster than the shovel.
- `tutorial_tests.gd` `_first_hour_items`: with an empty starting kit and only loose stones and
  branches, every stone tool is reachable.
- Every new string is in both locales.

**Implementation notes**
- Fabric: items `Branch`, `LooseStone` and `StoneAxe`, `StonePick`, `StoneShovel`, `StoneKnife`
  (`fabric/gameplay/items/primitive.js`, new `shovel`, `stick` and `pebble` shape archetypes); their
  recipes (`recipes/primitive.js`, station `""`, Carpentry novice); `TechStoneTools`, an **innate**
  technology (`tech.innate: true`: no cost, no materials, no prerequisite, no book) seeded unlocked
  for every player by `TechnologySlice`, which a restored snapshot cannot lock. No `StoneHammer`:
  building needs no tool. A `StoneTools` world system names the tools and the input yields
  (`fellBranches` 2, `looseStoneChance` 0.25); `tools/check_stone_tools.js` proves its validator
  rejects a station, a research cost, a prerequisite, materials, a non-innate technology, other
  inputs and a non-novice guard. Stone tools work at speed 0.6 in `WorkTimes`.
- `voxel_edit.gd` reads the natural yield before spending wear: ground the table digs (soil, sand)
  wears a held shovel instead of the pick; natural host rock knocks a loose stone loose when
  `StoneTools.loose_stone_at(tile, bottom)` (a hash of the span's position) says so. A felled tree
  drops its branches beside the wood (`tree_slice.gd`).
- `InventorySlice.find_tool` returns the fastest held tool of a class (`WorkTimes.toolSpeeds`), so a
  forged pick is used as soon as it is in the pack.
- Tests: `stone_tools_tests.gd`, and `tutorial_tests.gd` `_first_hour_items(kit, extra)` reaches
  every stone tool from an empty kit with only loose stones and branches. No new UI strings.
