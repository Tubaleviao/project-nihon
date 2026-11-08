# Roadmap history — Phase 220

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 220 — Enter never jumps ✅ Done

Jump is read from the built-in `ui_accept` action, which Godot binds to Enter, Keypad Enter and
Space, so Enter both opens chat and jumps. Flight's "up" uses the same action.

- Add a `jump` input action bound to Space only (and the gamepad's south button, if a pad is mapped)
  in `project.godot`, and read it for jump and fly-up instead of `ui_accept`. `ui_accept` stays for
  GUI buttons.
- The controls list in the UI (`ui_slice.gd`, the `jump` row) shows the binding from the action map.

**Acceptance criteria**
- A suite test asserts the `jump` action has Space and not Enter or Keypad Enter, and that
  `player_slice.gd` no longer reads `ui_accept`.
- A suite test presses Enter with the character on the floor and no field focused: the chat field
  takes focus and no jump starts. Pressing Space jumps.
