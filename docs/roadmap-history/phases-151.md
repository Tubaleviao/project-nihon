# Roadmap history — Phase 151

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 151 — Item shapes in the fabric

**Goal:** an item today has no description of its form. Equipment carries a placeholder `size`
box, and everything else has nothing, so icons are coloured squares and held items are boxes.
This phase gives every item a shape the generators can build from: an archetype plus the
materials it is made of. It is the fabric half of Phases 152–153 (separate PR, per CLAUDE.md).

**Newel dependency:** NO (a new field on existing entities).

**Depends on:** none.

**Deliverables:**
- `fabric/gameplay/items/shared.js` — an `itemShape({ archetype, parts, scale })` helper. The
  `archetype` comes from a closed list: `pick`, `axe`, `sword`, `longsword`, `bow`, `shield`,
  `helmet`, `chestplate`, `cloak`, `ingot`, `shard`, `dust`, `plank`, `block`, `orb`, `tablet`,
  `potion`, `rations`, `hearth`, `waystone`. `parts` maps each of the archetype's named parts
  (`head`, `handle`, `blade`, `grip`, `body`, …) to a fabric material (`Ferrite`, `Thornwood`,
  `Veilsteel`, …), so the material palette (Phase 22) colours each part. The default comes from the
  item's existing `hasOne` material relations where they exist.
- A `shape` value on all 25 items in `GameData.ITEMS` (including `Hearth` and `Waystone`).
- `validate` rejects an item with no shape, an unknown archetype, a part that is not in its
  archetype, or a material that does not exist.
- Generated `godot/items/*.gd` / `.tres` carry `shape`. `npm run generate` and `check-drift` clean.

**Acceptance criteria:**
- [x] `pnpm validate` passes, and fails on a fixture item with archetype `spaceship` and on one
  whose `parts.blade` names a missing material.
- [x] Every entity tagged `item` has a `shape`. A suite test reads it from `GameData` for each item.
- [x] `check-drift` clean.
