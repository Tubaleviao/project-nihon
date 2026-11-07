# Roadmap history — Phase 219

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 219 — A focused text field owns the keyboard ✅ Done

Found in play: clicking the chat bar puts the caret at the start of the field, and a word typed there
comes out reversed (each letter is inserted before the last, so the caret is being reset to column 0
after every keystroke). While the field has focus, W/A/S/D still move the character and Space still
jumps, because movement and jump are polled with `Input.is_action_pressed` /
`Input.is_key_pressed` in `player_slice.gd`, which ignores GUI focus.

- Find what resets the caret (something writing `_field.text` or `caret_column` while typing, or a
  refresh rebuilding the field) and stop it. A click places the caret where clicked, as in any
  `LineEdit`.
- One rule for every text field (chat, clan, chest, settlement, map rename, market, proposal,
  creation name): while a `LineEdit` or `TextEdit` has focus, no world input reaches the game:
  movement, jump, fly up/down, hotbar keys, window shortcuts and mouse-look stay quiet. The player
  slice asks one query (for example `UiSlice.is_typing()`) instead of each slice checking its own
  field. Esc still leaves the field.
- Movement already held when the field takes focus stops (no character walking off while you type).

**Acceptance criteria**
- A suite test types "hello" into the chat field through `InputEventKey` events after a click at
  column 0 and reads back `hello`, caret at column 5.
- A suite test focuses each text field above in turn and feeds W, A, S, D, Space, a hotbar digit and
  Alt+A: the player's wish direction stays zero, no jump starts, no hotbar slot or window changes.
- With no field focused, the same keys still move, jump and open windows (no regression).

**Done:** the reversed text came from the chat's `text_changed` handler setting `max_length` on every
keystroke; `LineEdit.set_max_length` re-sets the text and puts the caret at column 0, and the signal
arrives after the key, so each letter landed before the last. The limit is now set only when it
changes, with the caret put back. `UiSlice.is_typing()` (`src/ui/text_focus.gd`) is the one query:
the player slice's `wish_direction()`, `jump_requested()`, fly keys, mouse-look and
`world_input_allowed()`, the UI's hotbar and window shortcuts and the minimap zoom keys all ask it.
A field taking focus marks the held movement keys consumed, so they stay quiet until released once.
Tests: `src/tests/suites/text_focus_tests.gd`.
