# Roadmap history — Phase 181

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 181 — Character creation at runtime: a creation screen before the first spawn ✅ Done

**Goal:** a new player creates a character before they enter the world. They pick a name, a
gender, a hair style and a hair colour and see the result live. The host validates everything and
records it.

**Newel dependency:** NO.

**Depends on:** Phases 179 and 180.

**Deliverables:**
- A creation screen shown on first join to a server where the player has no character record,
  before spawn placement (Phase 53). Layout: the hair style grid (icons) on the left with a hair
  colour row under it, the live chibi rig in the centre on a dark backdrop (reusing the Phase 179
  viewport), gender toggles on either side of the rig, and the name field with an "enter the
  world" button at the bottom right. A randomize button picks a gender, hair and colour.
- The screen's skin is art at overlay keys, never baked into the scene. The layout, sizes,
  margins and font sizes live in code. Only pixels come from assets, so the private repo
  (`project-nihon-assets` Phase A20) can replace them without a code change:
  - `textures/ui/creation/backdrop.png.raw`: the dark backdrop behind the rig;
  - `textures/ui/creation/panel.png.raw`: a 9-slice frame for the hair grid, colour row and name
    panel (patch margins fixed in code);
  - `textures/ui/creation/rig_frame.png.raw`: the frame around the rig viewport;
  - `textures/ui/creation/button.png.raw`, `button_hover.png.raw`, `button_pressed.png.raw`: 9-slice
    states for "enter the world", randomize and the gender toggles;
  - `icons/ui/creation/<control>.png.raw`: the randomize and gender toggle icons, drawn by
    `tools/gen_ui_icons.py`.
  The overlay ships bytes, not Godot themes, so the screen loads each PNG through
  `AssetOverlay.load_texture` and builds its `StyleBoxTexture`s in code. It never loads a `.tres`
  theme from the overlay.
- **Public placeholder:** a generator (`tools/gen_ui_skin.py`, or a mode of
  `gen_placeholder.py`) writes every skin key above as flat colour at its final size, with
  `--check` like `gen_ui_icons.py`. The placeholders land in this phase, before any art in the
  private repo.
- A host intent `create_character(name, gender, hair, hair_color)`. The host validates the name
  rule and uniqueness and every option, creates the record, then places the spawn.
  It refuses with a keyed reason that the client renders in its locale. Rate-limited.
- Existing players without a creation record are offered the screen once. Their handle and
  progress are kept. A player who skips it keeps the default appearance and their
  handle as display name. The host records the skip, and the screen stays reachable from the
  character sheet until they create a character.
- The display name shows on the character sheet, in chat and settlement lists, and on a nameplate
  above other players. The friend code stays the handle.
- The appearance recipe syncs to peers in the area of interest, so everyone sees each other's
  character.
- The playtest bot creates a character as its first step.

**Acceptance criteria:**
- [x] Suite: the host accepts a valid creation and refuses each invalid field (name, gender,
  hair style, hair colour) with its own key.
- [x] Harness: `create_character` over the socket. A duplicate name from a second client is
  refused, and the second client sees the first one's appearance and nameplate.
- [x] Suite: a pre-181 save boots, offers creation once and keeps inventory and skills. A skip is
  recorded, is not offered again on the next join, and shows the handle on the nameplate.
- [x] Playtest bot: a `create` step completes before `walk` and saves a screenshot of the screen.
- [x] Suite: every skin and icon key the screen reads has a public placeholder at that key, no
  orphan exists under `textures/ui/creation/` or `icons/ui/creation/`, and the screen builds
  with only the public tree (no `assets.pck`). The skin generator's `--check` passes in CI.
- [x] Every new string is in both catalogs, and the i18n key check passes.
- [x] Suite green on both boot paths, harness green.

**Notes (as built):**
- **Record.** `PlayerRegistry` keeps `creation` (`{ state: none | skipped | created, name, gender, hair, hairColor }`,
  `CreationRules.sanitize_state`) on the player record; a pre-181 record has none and reads `none`, so the screen is
  offered. Uniqueness is decided against a server-wide name index (`player_id -> name`, skeleton -> player) that rides
  the **world** record (`names`), so an offline, evicted player's name stays taken and still displays.
- **Intent.** `character_creation_intent(action, creation, player_id)`: `create` or `skip`. A client sends
  `creation_intent` with the four fields only (capped strings, an int); the host binds it to the connection
  (`_actor_id`), and `PlayerRegistry.create_character` / `skip_creation` refuse with `creation.refuse.<reason>`:
  the Phase 180 field reasons plus `rate_limited` (one try per 500 ms per player, counted in
  `creation_rate_limited`) and `already_created`. A skipped player may create later; a created one cannot create or
  skip again. The owner gets `creation` + `creation_result` on the own-state channel; the listen host's UI gets
  `character_creation_resolved`. A creation gives the fabric's starting kit once (the Novice tunic, worn: the forced
  set reaches the owner through `equipment_revoked`).
- **Placement.** The spawn is still placed at the join (Phase 53), not after the creation: the client needs a position
  to stream its first ring, and the screen covers the world while it loads. The body is held
  (`PlayerSlice.creation_hold`: no keys, no world action) until the player creates or skips.
- **Looks on the wire.** A look is `{ name }` (handle, default body) or `{ name, gender, hair, hairColor }`
  (`CreationRules.look`). It is **pulled**: a client asks (`look_request`) when a peer's avatar appears in its AOI, and
  the host answers only while that peer is inside the requester's AOI (`answer_look_request`); a creation is
  **pushed** once to the peers in range (`player_look_changed`). A pushed pair per (viewer, subject) was the crowd cost
  Phase 163 removed for gear. The client re-checks the choices (`sanitize_look`), rebuilds the avatar in the gender's
  chibi preset with the hair and colour (`CharacterSlice.apply_look`, gear kept) and sets a `Label3D` nameplate.
  A listen host draws no remote players (as before), so nameplates are a client view.
- **Display name.** `PlayerRegistry.display_name`: the created name, else the handle. Chat lines and the join line,
  `/players` (`Name (handle)`), settlement member lists (`names` in the private view) and the character sheet use it;
  the friend code, `/tp` and every command argument stay the handle.
- **Screen.** `src/ui/creation_screen.gd`, on its own canvas layer (40) above the windows. Hair grid (icons
  `icons/hair/<id>`) with the colour row under it, the framed doll (the Phase 179 `Doll`) with a gender toggle each
  side, randomize and skip bottom left, the name and "enter the world" bottom right. Skin keys and sizes are the
  `SKIN` table; the 9-slice margins are constants. `tools/gen_ui_skin.py` reads that table and writes the flat
  placeholders (`--check`, `--out`, CI); `tools/gen_ui_icons.py` draws `icons/ui/creation/randomize` and
  `gender_<gender>`. The character sheet shows a "Create character" button until a character exists.
- **Offer.** `CreationWiring.maybe_offer` shows the screen once per session on a machine with a UI, after its boot,
  while its own state is `none` (a client learns it from the join snapshot's `creation`).
- **Tests.** `creation_runtime_tests.gd` (12 tests); harness step `create_character` (the host's own player is the
  first creator, the client is refused `name_taken` for the case-folded name, sees the host's look and nameplate,
  then creates its own); playtest step `create` (first, screenshot `create.png` of the screen).
