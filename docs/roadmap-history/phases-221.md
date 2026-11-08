# Roadmap history — Phase 221

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 221 — Re-creating a character from the Character window ✅ Done

Found in play: the Character window's "Create character" button (`ui_part_1.gd`, shown while
`CreationRules.is_created` is false for this machine's creation state) opens the creation screen, but
the player is stuck on it, and "Enter the world" is refused with `creation.refuse.already_created`
("This character already exists") whatever the name. So the client believes the character is not
created while the host has it as created, and the screen has no way out after a refusal.

- Find where the client's creation state and the host's diverge (a skipped creation, a state synced
  before the record loaded, or a local listen host reading another player's record) and make the
  button's visibility follow the host's synced state.
- Once a character exists the button is hidden (decided by the owner, 2026-11-06): a character is
  created once and never re-created in place (`already_created` stays the host's rule). Another
  character, starting from scratch, is made from the main menu (Phase 226). Changing hair style or
  colour later is a separate screen gated on crafted items (Deferred).
- The creation screen can always be closed back to the world (a Back button and Esc) when it was
  opened from the Character window, and a host refusal leaves it usable, showing the reason.

**Acceptance criteria**
- A suite test creates a character, syncs the state to a client UI and asserts the Character
  window's create button is hidden.
- A suite test opens the creation screen from the Character window, presses Back and asserts the
  screen is hidden and world input is unfrozen; the same after a host `already_created` refusal.
- A net harness step: a client that skipped creation and one that created both see the button state
  the host's record implies.
