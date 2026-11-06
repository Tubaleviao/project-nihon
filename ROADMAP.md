# Project Nihon — Roadmap

Project Nihon is an open-source sandbox MMORPG where players build a
civilization. This document tracks the design and implementation roadmap.
The game's entire design bible — materials, creatures, skills, items, world
systems — is authored as a Newel fabric and generated into documentation,
runtime assets, and Godot resources.

See `../newel/ROADMAP.md` for the Newel-side changes each phase depends on.

**Human verification is not an acceptance criterion.** A criterion must be decidable by the
automated gates — `pnpm validate`, `pnpm check-drift`, the headless suite on both boot paths,
`tools/net_harness.sh`, CI. A check that needs a person at the keyboard (a playtest, a screenshot
judgement, a visual inspection) is not a criterion: it is filed as a GitHub issue and the phase
proceeds without it, so unpublished human work never parks the roadmap. The phase records the
issue number where the criterion used to be.

**Follow-up debt cap.** No new feature phase starts while more than 10 `autopilot-followup`
issues are open. Burn them down first (fix, fold into the next phase, or close with a reason).

---

## Phase index

Phases 1–218 are done (200 and 201 were aborted). Their specs and acceptance criteria, and the
introductions of the arcs they belonged to, are archived in
[docs/roadmap-history/](docs/roadmap-history/README.md).

### Next: playtest fixes and the game's front door (Phases 219–226)

Filed by the owner on 2026-11-06 after playing `main`. Four are bugs found in play (typing in the
chat box, Enter jumping, re-creating a character, an overfull character window). Three give the game
what every game has and this one does not: a main menu, a pause menu on Esc and an options window.
The last lets a player keep several characters and pick one from the main menu. The bugs come first,
because the menus reuse the keyboard routing Phase 219 fixes.

| Phase | Title | Status |
|---|---|---|
| 219 | A focused text field owns the keyboard: no reversed text, no movement, jumps or hotkeys while typing | Open |
| 220 | Enter never jumps: a `jump` action on Space only | Open |
| 221 | Re-creating a character from the Character window | Open |
| 222 | The Character window fits: fewer rows, the friend code moves to the map | Open |
| 223 | A main menu: play a local world or join a server | Open |
| 224 | The Esc menu: resume, options, exit to main menu, quit | Open |
| 225 | The options window: sound, graphics and game settings | Open |
| 226 | Several characters per player: a new one starts from scratch, chosen in the main menu | Open |

## Phase 219 — A focused text field owns the keyboard

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

## Phase 220 — Enter never jumps

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

## Phase 221 — Re-creating a character from the Character window

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

## Phase 222 — The Character window fits

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

## Phase 223 — A main menu

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
- A suite test boots the root with no args and asserts the main menu is shown and no world is built.
- A suite test creates, lists and deletes a local world in a temp `user://` folder.
- The existing boot checks (`--server`, `--quit-after-boot`, net harness, playtest bot) still pass
  unchanged in CI.
- A net harness step: a client started from the menu's join path with the host's address connects.

## Phase 224 — The Esc menu

Esc today only closes the focused window or field. With nothing open, it does nothing.

- Esc closes, in order: a focused text field, the top open window, then opens a pause menu:
  **Resume**, **Options**, **Exit to main menu**, **Quit game**. Esc again closes the menu.
- On a listen host the world keeps running for connected players (it is an MMO); leaving saves
  first. On a client, exit disconnects cleanly.
- While the menu is open, world input is frozen (Phase 219's rule).

**Acceptance criteria**
- A suite test presses Esc with a window open (it closes, no menu), then again (menu opens), then
  again (menu closes).
- A suite test runs Exit to main menu on a listen host and asserts the save was written and the main
  menu is shown with no world nodes left (no orphans).

## Phase 225 — The options window

Settings exist in scattered places (language since Phase 131, the tutorial switch since Phase 186,
admin-only tools). They get one window, reachable from the main menu and the Esc menu.

- **Sound**: master, music, effects volume (audio buses).
- **Graphics**: window mode, resolution, VSync, view distance (the near/far ring policy), FPS cap.
- **Game**: language, tutorial on/off and reset, mouse sensitivity and invert, controls list.
- Saved to the existing user settings file and applied at once. Language follows the CLAUDE.md
  order: saved preference, then OS locale, then `en`.

**Acceptance criteria**
- A suite test changes each setting, saves, reloads the settings in a fresh object and reads back the
  same values, and asserts the change was applied (bus volume, `TranslationServer` locale, tutorial
  flag).
- A suite test asserts every options label is a key in both `en` and `pt_BR`.

## Phase 226 — Several characters per player

Decided by the owner (2026-11-06): a player cannot re-create a character in place (Phase 221), but
can create other characters from the main menu, and each new one starts from scratch. Today a
player id is one character: the registry, the creation record, inventory, skills, attributes,
research, clan membership and owned structures all key on the player id.

- **Fabric first** (separate PR): a character entity under the player (account), what belongs to the
  character (body, name, inventory, equipment, skills, attributes, research, books learned, clan
  membership, owned structures, spawn bed) and what belongs to the player (friend code, settings,
  admin flag). A character limit per player per server, and whether a deleted character's
  structures fall to its clan or become ownerless.
- **Runtime:** the registry keys character state by character id. The host refuses a new character
  over the limit, and a new character gets no items, skills, research or memberships from the
  player's other characters. Names stay unique per server across all characters (`name_taken`).
- **Main menu:** after choosing a local world or joining a server, a character list (name, body
  preview, last played) with **Play**, **New character** (the creation screen) and **Delete** (with a
  confirmation typed as the character's name). The host sends the list; the client never decides
  which characters exist.
- Existing saves migrate: each player's one character becomes their first character, unchanged.

**Acceptance criteria**
- `npm run validate` and `check-drift` pass with the character entity; a `tools/check_*.js` rejects
  a table that puts inventory or skills on the player instead of the character.
- A suite test creates two characters for one player: the second has an empty inventory, base
  attributes, no skills, no research and no clan, and the first is unchanged.
- A suite test refuses a character over the limit and a name already used by another character on
  the server.
- A suite test loads a pre-Phase-226 save and finds each player's character as their first, with
  the same state.
- A net harness step: a client lists its characters, creates a second, enters with it, reconnects
  and enters with the first.

---

## Deferred (in priority order)

- **Fluid flow** — flowing water (a cellular automaton on dirty chunks only) after Phase 51's
  static sea level, Phase 137's falling sand and Phase 217's static lakes and rivers.
- **Fast travel beyond waystones** — a planet takes about 90 days to walk around. Phase 125 added
  waystones and Phase 216 mounts; roads and boats remain.
- **Physics ragdolls** — Phase 157 animates deaths with a host-chosen landing spot and authored
  clips, so the headless server stays deterministic. A client-only ragdoll blend on top is later
  polish.
- **Localized fabric content** — entity names and descriptions (items, creatures, skills,
  technologies) translated through catalogs generated by Newel (`../newel/ROADMAP.md` Phase 15),
  consumed with the Phase 131 locale settings.
- **Public wiki deployment** — VitePress (or equivalent) static-site deployment and CI-triggered
  wiki regeneration from the fabric (deferred from Phase 9).
- **Voxel techniques from GDVoxelPlayground** — <https://github.com/JorisAR/GDVoxelPlayground>
  (MIT) was evaluated and not adopted wholesale: it ray-marches a fixed 128³ GPU grid, which does
  not fit an unbounded streamed world with a headless server. Worth borrowing later, CPU-side and
  deterministic: **WFC** for ruins, villages and dungeons, and a **brick occupancy map** if meshing
  becomes the bottleneck.
- **Raids** (dropped 2026-10-31, was Phase 200) — a warned, bounded creature attack on a village. Not wanted for now. Its spec is in git history (ROADMAP.md before PR #540).
- **Clan skills** — abilities (such as teleporting every member to one place) for the two or three members who contribute most to a clan. Contribution is to be defined, probably as a share of members' experience given to the clan. Clan tiers (Phase 210) give nothing until then.
- **Changing hair style and colour** (owner, 2026-11-06) — a separate screen, not the creation
  screen, open only to a player who has crafted scissors (style) or dye chemicals (colour), which are
  consumed or worn on use. Needs the items and their recipes in the fabric first.
- **Elder buildings** — buildings only a clan's top contributors can build. To be designed.
- **Settlement against settlement** — Phase 205 lets anyone destroy a structure they do not own. Organized sieges, wars and disputes between clans need governance and fairness rules first.
- **Real cross-region multiplayer run** — Phase 135 emulates WAN profiles in the harness. A run
  between real regions remains.
- **Automatic LOD mesh decimation** — simplified meshes are hand-authored (Phase 23).
- **Dynamic impostor re-bake** — impostor billboards are baked offline. A live re-bake on palette
  change is deferred from Phase 23.
- **Server sharding (last, not before maturity)** — split the authoritative simulation across
  servers by region once one headless server (Phase 27) with spatial hashing (Phase 28) and
  interest management (Phase 29) saturates. No structural change is needed before then. Revisit
  when Brazil-region load approaches one server's ceiling.
