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

**Notes (as built):**
- `src/ui/character_sheet.gd` holds the pure projections (`attribute_rows`, `stat_rows`, `skill_rows`) and the `Doll`
  viewport control; `UiSlice.character_sheet_rows()` joins them with the slot rows.
- The doll builds its own copy of the rig in a `SubViewport` with its own 3D world. It idles on a slow turn
  and turns on drag; it does not play the Phase 156 clip (that clip is bound to a world instance).
- Growth bars: the host now sends `attribute_growth` with the attribute table (join snapshot and own-state), and the
  bar moves when a point is gained or the owner's state is next synced, not on every XP tick.
- Dragging an equipped item off its slot and releasing it anywhere else unequips it.
- The display name above the doll is the handle until Phase 181.

