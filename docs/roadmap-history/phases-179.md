# Roadmap history — Phase 179

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 179 — The character sheet: a paper doll, attributes and derived stats ✅ Done

**Goal:** today the character window is a text label, a friend code and a grid of slots. Turn it
into an RPG character sheet: the player's own rig in the middle with equipment slots around it,
attributes with icons and tooltips, and the derived stats they produce.

**Newel dependency:** NO.

**Depends on:** Phases 175, 176 and 178.

**Deliverables:**
- A `SubViewport` preview of the local rig, wearing the current equipment and the Phase 123
  character material. It turns on drag and idles with the Phase 156 clip.
- Equipment slots laid out around the doll by body position (head, chest, hands, main hand, off
  hand…), each with the item icon and its durability. Drag and drop equips and unequips through
  the existing bus intents.
- Attribute icons at `assets/icons/attributes/<Attribute>.png.raw` for the Phase 177 set, drawn
  by `tools/gen_ui_icons.py` (Phase 175) and keyed from `GameData`.
- An attribute panel: icon, value and a growth bar toward the next point. The tooltip lists what
  the attribute feeds and by how much.
- A derived-stat panel: HP, regeneration, carry, damage, reduction, speed, research gain and yield.
- A short skills summary (the top skills by tier, with skill icons) that links to the skills window.
- A display name above the doll once Phase 181 lands. Until then the handle is shown.
- Every string goes through `I18n.t`. Numbers are formatted for the active locale.

**Acceptance criteria:**
- [x] Suite: the sheet's projection (`character_sheet_rows()`) lists every equipment slot, all six
  attributes and every derived stat, with values equal to the host's synced numbers.
- [x] Every Phase 177 attribute has an icon at its key, no orphan exists, and
  `python3 tools/gen_ui_icons.py --check` passes.
- [x] Suite: dropping an item on a slot emits the same equip intent as the context menu.
- [x] Suite: building the sheet hard-codes no user-facing literal (audit test), and both locales
  render.
- [x] Playtest bot: a `character_sheet` step opens the window, renders the doll with a non-empty
  viewport and takes a screenshot.
- [x] Suite green on both boot paths.

**Implementation notes:**
- `src/ui/character_sheet.gd`: the projection (`rows()`, exposed as `UiSlice.character_sheet_rows()`), the slot drop rule and the
  widgets. Numbers come from the body's synced attribute table through `AttributeRules`, so they equal the host's.
- Doll: `DollView` (a `SubViewport` with its own world) holds a second body from `CharacterSlice.build_preview`: the avatar's
  appearance on the default rig with the Phase 123 material, wearing the avatar's set, idling on the rig clip, turned by
  dragging. It is rebuilt when the worn set changes. It is built under the viewport and never leaves the tree, because a
  Skeleton3D that leaves the tree drops a PhysicalBoneSimulator3D it never frees.
- Slots sit left (Head, Chest, Cape) and right (MainHand, OffHand and any later slot) of the doll, with the item icon and
  durability. A drop on a slot wears the item through the context menu's equip call; a worn item dragged onto the bag unequips.
- Icons: `tools/gen_ui_icons.py` writes `assets/icons/attributes/<attribute>.png.raw` (round badge + symbol); `--check` covers them.
- Deviation: the growth bar shows the value between the creation minimum and the hard cap. The XP banked toward the next point
  stays on the host (only the attribute table is synced), so a true next-point bar needs a new owner-only sync.
- The window opens at (150, 24) so the wider sheet fits a 1152-px viewport.
- Playtest: the `character_sheet` step (second, after `walk`) opens the window and passes when the preview viewport has
  drawn (a headless run checks that the rig is in the viewport) with six attributes, every slot and the derived stats.

