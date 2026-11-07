# Roadmap history — Phase 223

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 223 — A main menu ✅ Done

The game boots straight into a listen-host world. A player has no way to choose a world or a server.

- With no boot user args, the game opens a main menu: **Play** (local world), **Join server**,
  **Options** (Phase 225, greyed until then), **Quit**. Every boot flag CI uses (`--server`,
  `--client`, `--run-tests`, `--quit-after-boot`, `--playtest-bot`, `--net-harness`, `--friend`)
  skips the menu and behaves as today.
- **Play** lists local worlds saved under `user://` (name, seed, last played), and offers **New
  world** (name, optional seed) and **Delete** (with a confirmation). Choosing one boots the existing
  listen-host path on that save.
- **Join server** takes an address or friend code, remembers recent servers, and boots the existing
  client path. A failed connection returns to the menu with a localized reason.
- All text through `I18n.t()`, keys in `en` and `pt_BR`.

**Acceptance criteria**
- [x] A suite test boots the root with no args and asserts the main menu is shown and no world is built.
- [x] A suite test creates, lists and deletes a local world in a temp `user://` folder.
- [x] The existing boot checks (`--server`, `--quit-after-boot`, net harness, playtest bot) still pass
  unchanged in CI.
- [x] A net harness step: a client started from the menu's join path with the host's address connects.

**Built:** `src/menu/`. `main_menu.gd` is a code-built CanvasLayer: Home (Play, Join server, Options greyed
until Phase 225, Quit), the Play list with New world and a Delete confirmation page, and the Join form (an
address plus an optional friend code) with the recent servers. `local_worlds.gd` keeps each world in a
`user://worlds/<id>/` folder that is the listen host's `server_save_dir`, with `meta.json` holding name,
seed, created and last played; the pre-menu save `user://saves/server/` is listed read-only.
`recent_servers.gd` keeps `user://recent_servers.json`, validated on read and capped at 8. `menu_wiring.gd`
holds `MENU_SKIP_ARGS` (the CI flags plus the stress flags), applies the menu's choice to the root, and
points the save folder and seed at the chosen world before `_boot_world`. `GameRoot._ready` opens the menu
when no boot flag is present and otherwise runs `_build_and_boot()` as before. A join started from the menu
that fails (a `join` error, ENet connection failed, host disconnected, snapshot timeout) emits
`GameRoot.menu_return_requested`, and `main.gd` replaces the root with a fresh one whose menu shows the
localized reason; a `--client` boot keeps its old behaviour. Suite: `src/tests/suites/menu_tests.gd`.
Harness: `menu_join`, where the client re-joins through `MainMenu.join_choice`, `MenuWiring.apply_choice`
and `_boot_client`.
