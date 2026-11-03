# Roadmap history — Phase 212

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 212 — Floors and structural limits at runtime, and the materials above stone ✅ Done

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
- [x] Suite: a third wood floor, a sixth stone floor and an eleventh concrete floor are refused, and
  the top class stops at floor 163.
- [x] Suite: an overhang past a class's threshold is refused for that class and allowed for the
  next one.
- [x] Suite: a finished project's doorway is open on every course it should be, and its blocks sit
  at their layout heights over uneven ground.
- [x] `npm run validate` passes, and every class up to 163 floors has a craftable material.
- [x] Suite (audit): no structural value is read from a client message.
- [x] Every new string is in both catalogs, and the i18n key check passes.
- [x] Suite green on both boot paths, harness green.

**Shipped:**
- `src/structure/structure_limits.gd` (beside the Phase 205 `structure_rules.gd`; the repo keeps a system's
  files in `src/<system>/`, so it is not under `src/building/`): pure reads of `Structure.classes` and
  `Structure.shapes`. Each indexed block keeps three numbers, set once when it is placed: `base` (the bottom of
  the ground its load comes down to), `reach` (blocks sideways from the nearest column) and `carry` (the weakest
  class among it and everything holding it up). `StructureSlice.plan_place` derives them from the block under it,
  then the ground (the host's own runs, `supported`), then a ceiling or the side neighbour nearest a column.
  A placement costs a few dictionary lookups plus a span walk capped at the last threshold (257 blocks), so a
  163-floor tower is never rescanned. A block's floor is `(bottom − base) / 3 m + 1`.
- Refusals: `too_many_floors`, `overhang_too_far`, `span_too_long`, `too_slender` (appended to
  `StructureSlice.REASONS`, with lines in both catalogs). Slenderness is height over √(columns × tile²). It is
  checked only on a block that raises a structure past one floor, so a wall, fence or post a floor high is no
  tower.
- Saves: a cell saves `base`, `reach` and `carry` (format 3). A cell from an older save stands on its own
  ground (`existingBuilds: kept`). A loaded base is clamped to the block's own bottom, and a loaded carry to the
  block's own class.
- Fabric: `Concrete` (concrete class, common, 300), `Steel` (steel, uncommon, 340) and `Leyframe` (composite,
  epic, 1000) in `fabric/world/materials/built.js`. Recipes output the materials themselves, because placing
  spends a material: `RecipeCement` (Ashite → the `Cement` item) and `RecipeConcrete` at a masonry bench,
  `RecipeSteel` (ferrite ingots) at a master forge, and `RecipeLeyframe` (steel and raw Aethermite, which is
  ley-gated) at an arcane forge. Technologies `TechConcrete`, `TechSteel` and `TechLeyframe` unlock them, with a
  book each. The structure validator now requires every class past stone to have a material made by an unlocked
  recipe, and every recipe for the top class to reach a ley-gated material (`tools/check_structure.js`). The new
  materials have voxel tints, holdable icons and gather families (stone, metal, metal).
- Projects: `places.floors` replaces `places.blocks`, and must not exceed what its block's class carries
  (validated). The palisade, storehouse and workshop are one 3 m floor; the watchtower is two. `layout_cells`
  gives a course per block and leaves a doorway 3 tiles wide and 16 blocks (2 m) high.
  `VoxelSlice.place_structure_blocks` places the whole project in one pass: each block sits `dy` blocks above its
  column's surface as it was before the batch, is synced as a side fill at that height, and each touched chunk is
  rebuilt once.
- Tests: `src/tests/suites/structure_limits_tests.gd`.
