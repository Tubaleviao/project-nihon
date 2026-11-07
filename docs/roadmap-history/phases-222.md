# Roadmap history — Phase 222

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 222 — The Character window fits ✅ Done

The Character window lists every attribute, stat, slot and specialty, and above them the friend
code, the spawn notice, the respawn and build-as buttons. At the default window size it overflows
its own frame.

- Move the friend code (and its Copy button) and the spawn notice to the map window, where the
  player's place in the world already is.
- Keep the attributes and the paper doll in view. What still does not fit goes into a
  `ScrollContainer` (stats and specialty below the attributes), never past the window's edge.
- The respawn and build-as buttons stay, in one row.

**Acceptance criteria**
- A suite test builds the Character window at the default viewport size (1280×720 and the minimum
  supported size) and asserts every child's rect lies inside the window's rect or inside a scroll
  container.
- A suite test asserts the friend code label and Copy button are in the map window and not in the
  Character window. The playtest `character_sheet` step still passes.
