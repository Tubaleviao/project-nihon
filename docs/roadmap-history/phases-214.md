# Roadmap history — Phase 214

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 214 — Alt window shortcuts: Alt+A attributes, Alt+S skills, Alt+E inventory, Alt+Q equipment, Alt+G clan ✅ Done

**Goal:** today each window opens with a bare letter (`UiSlice._unhandled_input`: I, C, K, H, T, Y,
P, G, M, L, O), and those letters are reserved away from the hotbar (`Hotbar.RESERVED_KEYS`). Every
window shortcut becomes Alt + a letter, and the bare letters are freed.

**Newel dependency:** NO.

**Depends on:** none. Alt+G opens the Settlement window until Phase 204 turns it into the clan
window, and then opens the clan window.

**Deliverables:**
- One table, `UiSlice.WINDOW_SHORTCUTS` (`{window, keycode}`, Alt implied), drives the key handler,
  the window dock's letter chips (`window_dock.gd`), the `?` controls rows and the reserved-key list.
  No window letter is written anywhere else.
- The bindings:

  | Shortcut | Window |
  |---|---|
  | Alt+A | Attributes: the six attributes and the derived stats |
  | Alt+S | Skills |
  | Alt+E | Inventory |
  | Alt+Q | Equipment: the paper doll and the equipment slots |
  | Alt+G | Clan (the guild): Settlement until Phase 204 |
  | Alt+H | Crafting |
  | Alt+T | Technology |
  | Alt+Y | Trade |
  | Alt+P | Market |
  | Alt+V | Proposals (G goes to the clan) |
  | Alt+M | Map |
  | Alt+O | Admin (admins only, as in Phase 182) |

  `?` (controls), Enter and `/` (chat) and ESC (close all) are not window letters and stay as they
  are. A window added later gets an Alt+letter row in the same table.
- The Phase 179 character window is split in two: **Attributes** (attributes and derived stats) and
  **Equipment** (paper doll and slots). Each has its own dock entry, title key and icon (Phase 175
  generator). The playtest bot's `character_sheet` step opens both and keeps its checks.
- Matching uses `keycode` with `alt_pressed` and ignores `unicode`, so macOS Option characters and
  non-US layouts still match. Ctrl or Meta held with Alt does not match. Alt+F4 and Alt+Tab are left
  to the OS.
- Bare-key handlers ignore an event with Alt held: E (equipment visibility) and G (tame) in
  `PlayerSlice`, Q (gesture wheel), R, B, V, and the hotbar's 1–9 and box keys. So Alt+E opens the
  inventory and does not also strip the gear. Typing in a text field still triggers no shortcut.
- `Hotbar.RESERVED_KEYS` drops the window letters that nothing else uses (I, C, K, H, T, Y, P, M,
  L, O), so a hotbar box can take them. A box key is still a bare letter: Alt+letter can never be
  bound to a box.
- The dock chips and the `?` rows show `Alt+A` and so on, with the modifier label from a catalog key
  (`controls.key.alt`). `controls.row12` drops "G is shared with Proposals", and `controls.row13` and
  `controls.row14` are rewritten for the new keys. Tutorial steps that quote a window key (Phase 186)
  read it from the table.

**Acceptance criteria:**
- [x] Suite: each `WINDOW_SHORTCUTS` row opens its window from a synthetic Alt+key event, and a
  second press closes it. The same key without Alt opens no window.
- [x] Suite: Alt+E opens the inventory and emits no `character_equipment_toggle_requested`. Alt+Q
  opens Equipment and not the gesture wheel. Alt+G opens the clan (or Settlement) window and does
  not tame.
- [x] Suite: Ctrl+Alt+A, and an Alt+key with a focused `LineEdit`, open nothing. An Alt+key whose
  `unicode` is an Option character still matches on `keycode`.
- [x] Suite (audit): no window letter is matched outside `WINDOW_SHORTCUTS`. The dock chips and the
  controls rows are built from it, every window in `WINDOW_KEYS` except controls and gestures has
  exactly one row, and no two rows share a key.
- [x] Suite: a hotbar box accepts a freed letter (I, K…) and refuses an Alt+letter.
- [x] Suite: the Attributes window lists every attribute and derived stat, and the Equipment window
  lists every slot.
- [x] Playtest bot: `character_sheet` opens Attributes and Equipment with Alt+A and Alt+Q and passes
  its Phase 179 checks.
- [x] Every new string is in both catalogs, and the i18n key check passes.
- [x] Suite green on both boot paths.

**Implementation notes:** the table lives in `src/ui/window_shortcuts.gd` (`UiSlice.WINDOW_SHORTCUTS` aliases it) so the dock and the hotbar can read it without a circular preload. Settlement keeps Alt+L (it has no row in the spec table and the clan window took Alt+G); the chest window has no hotkey. The window dock's icon generator reads the dock keys, so `attributes` and `equipment` have drawings in `tools/gen_ui_icons.py`. Suite: `src/tests/suites/window_shortcut_tests.gd`.


**Follow-up #558 (Phase 218):** the `FIRST_RING_TIMEOUT` change from 15 s to 60 s in `game_root.gd` rode along with the Phase 214 PR; it is unrelated to window shortcuts (the first-ring wait was too short for CI runners). A key consumed by an Alt shortcut now stays silent for walking until it is released once (`WindowShortcuts.consume` / `walk_held`). The old J key for the clan window is gone; the controls row now says Alt+G opens the clan.
