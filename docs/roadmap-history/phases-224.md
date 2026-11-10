# Roadmap history — Phase 224

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 224 — The Esc menu ✅ Done

Esc today only closes the focused window or field. With nothing open, it does nothing.

- Esc closes, in order: a focused text field, the top open window, then opens a pause menu:
  **Resume**, **Options**, **Exit to main menu**, **Quit game**. Esc again closes the menu.
- On a listen host the world keeps running for connected players (it is an MMO); leaving saves
  first. On a client, exit disconnects cleanly.
- While the menu is open, world input is frozen (Phase 219's rule).

**Acceptance criteria**
- [x] A suite test presses Esc with a window open (it closes, no menu), then again (menu opens), then
  again (menu closes).
- [x] A suite test runs Exit to main menu on a listen host and asserts the save was written and the main
  menu is shown with no world nodes left (no orphans).
- [x] #599 (swap-back): the root swap in `main.gd` (`_back_to_menu`) that Exit to main menu reuses
  moves into a testable static, and a suite test drives it with a stub root (old root freed, a fresh
  `GameRoot` with the notice).
- [x] #599 (address rule): `RecentServers.valid_address` and `BootWiring._valid_host_address` are one
  function; a suite test feeds both paths the same addresses.
- [x] #599 (explored map): a local world's revealed map is keyed by its world folder; a suite test
  creates two local worlds with the same seed and finds separate explored maps.
- [x] #599 (menu join): a net harness step boots a client from a real main menu (no `--net-harness`
  role) through `MenuWiring.start` and joins the host.

**Closes:** #599

**Built:** `src/ui/pause_menu.gd` (code-built: a dimmed backdrop that swallows clicks, Resume, Options greyed
until Phase 225 like the main menu's, Exit to main menu, Quit game; no button takes the keyboard, so Space or
Enter never press Resume). `UiSlice` builds it on first open on its own layer (45, above the creation screen);
Esc's order lives in `ui_part_2.gd`: a focused field is left first (Phase 219), then the window opened last
that is still open closes (`_open_order`), then the menu opens, and Esc closes it. While it is up `UiSlice`
swallows every other key and `PlayerSlice.pause_hold` stops movement, jump, world actions and mouse-look (the
same hold as the creation screen's). The tree is never paused. The choices go out as local bus intents
(`exit_to_menu_requested`, `quit_game_requested`, plus `pause_menu_toggled`), handled by `MenuWiring`:
`GameRoot.save_before_leave()` (the explored map, blocking, then `save_everything` + `flush_save`; a client
writes no records) is shared by Exit, Quit and the window close.

#599: the root swap moved from `main.gd` to `src/menu/root_swap.gd` (`spawn_root`, `back_to_menu`); a returning
root boots with no args, so a `--client` launch that exits to the menu does not rejoin. `BootWiring.client_address`
calls `RecentServers.valid_address` (the `--client` rule gains the 253-character limit). A menu world keeps its
explored map in its own folder (`MenuWiring.revealed_dir_for`); the pre-menu save keeps `user://saves/client`.
The harness's `menu_join` client now spawns a third process with `--menu-join <host>` (not a skip flag): it opens
the real main menu, joins through `MenuWiring.start`, prints `[Menu] joined from the main menu` and exits 0.

Tests: `src/tests/suites/pause_menu_tests.gd` (10 tests, including a listen host booted from the menu on a temp
world, Exit, the world record on disk and a fresh root holding only the main menu). The controls row for Esc
now reads "Close the top window, else open the menu".
