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

Phases 1–178 and 182 are done. Their specs and acceptance criteria are archived in
[docs/roadmap-history/](docs/roadmap-history/README.md).

### Arc: make it look and feel like an RPG (Phases 173–181, 183)

After 172 phases the engine is strong: a deterministic planet, host-authoritative multiplayer,
persistence, crafting, combat, taming and settlements. But it does not yet look or play like an
RPG. Items and windows show letters, the character has no attributes, and a player never creates a
character: they spawn as a handle. This arc pays down the follow-up debt and makes the frame
budget honest. Then it gives the game icons, attributes, a character sheet and character creation.

| Phase | Title | Status | Spec |
|---|---|---|---|
| 174 | An honest playtest frame budget | Done | [phases-174.md](docs/roadmap-history/phases-174.md) |
| 175 | UI icons: dock, windows, skills and status from one generator | Done | [phases-175.md](docs/roadmap-history/phases-175.md) |
| 176 | An icon for everything a player can hold | Done | [phases-176.md](docs/roadmap-history/phases-176.md) |
| 177 | Attributes in the fabric: strength, vitality, resistance, agility, intelligence, perception | Done | [phases-177.md](docs/roadmap-history/phases-177.md) |
| 178 | Attributes at runtime: host-owned, persisted, feeding the derived stats | Done | [phases-178.md](docs/roadmap-history/phases-178.md) |
| 179 | The character sheet: a paper doll, attributes and derived stats | Planned | below |
| 180 | Character creation in the fabric: name, appearance and starting attributes | Planned | below |
| 181 | Character creation at runtime: a creation screen before the first spawn | Planned | below |
| 183 | Playtest process time under 16 ms | Planned | below |

### Out of arc: admin tools (Phase 182)

Requested during playtesting, and done ahead of the arc: an admin needs to set the weather, the
time of day, a player's speed and health, and to regenerate a world whose recorded terrain is out of
date (for example, a world recorded around the pre-worldgen-9 spawn pit).

| Phase | Title | Status | Spec |
|---|---|---|---|
| 182 | Admin tools: /time, /speed, /fly, /heal, /regen world and an Admin window | Done | [phases-182.md](docs/roadmap-history/phases-182.md) |

---

## Phase 179 — The character sheet: a paper doll, attributes and derived stats

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
- [ ] Suite: the sheet's projection (`character_sheet_rows()`) lists every equipment slot, all six
  attributes and every derived stat, with values equal to the host's synced numbers.
- [ ] Every Phase 177 attribute has an icon at its key, no orphan exists, and
  `python3 tools/gen_ui_icons.py --check` passes.
- [ ] Suite: dropping an item on a slot emits the same equip intent as the context menu.
- [ ] Suite: building the sheet hard-codes no user-facing literal (audit test), and both locales
  render.
- [ ] Playtest bot: a `character_sheet` step opens the window, renders the doll with a non-empty
  viewport and takes a screenshot.
- [ ] Suite green on both boot paths.

---

## Phase 180 — Character creation in the fabric: name, gender, hair and a chibi art style

**Goal:** a player never creates a character. They spawn with a default appearance and are known by
a handle. Model a small set of creation choices (name, gender, hair style, hair colour) so the
runtime screen in Phase 181 is generated from data, and set the character art style it uses.

**Newel dependency:** NO.

**Depends on:** Phase 177.

**Art direction:** characters are cute, chunky chibi figures in the spirit of Ragnarok Online:
a big head (about a third of the height), large expressive eyes, short limbs, big hands and boots,
and bold, chunky hair that carries most of the identity. They are our own designs, never copies:
no Ragnarok hair styles, outfits, palettes, names or proportions traced from it. Reference for the
mood: a 3D chibi novice in a plain leather outfit, framed alone on a dark, quiet backdrop.

**Deliverables:**
- `fabric/gameplay/characters/creation.js` (new): a `CharacterCreation` entity with:
  - name rules: 3–16 characters, Unicode letters from a single script (no Latin mixed with
    Cyrillic or Greek) plus a single inner space, hyphen or apostrophe, unique per server after
    case folding, accent folding and a confusables skeleton (Unicode TR39), so "Аlice" with a
    Cyrillic А collides with "Alice", and a reserved list;
  - gender: two options (masculine, feminine). Each maps to a fixed body preset in
    `appearances.js` (body, head, eyes, skin colour and chibi proportions), so the player does not
    pick those parts;
  - hair: a list of hair styles per gender and a curated hair colour list (palette indices);
  - a default creation (one gender, hair style and colour) and a starting kit per server rule
    (a plain novice outfit by default; no class kits, the sandbox has none).
  Attributes are not chosen at creation: every character starts at the Phase 177 base values.
- A `chibi` proportion preset in `appearances.js` (large `headScale`, short limbs) used by both
  gender presets, within the §8 bounds (widen the bounds if needed and say so in the bible).
- Public placeholders for both gender bodies, the novice outfit, at least six hair styles per
  gender and the hair colour list, at the same keys the private repo will fill (placeholder rule;
  `gen_placeholder_glb.py`). Each hair style also gets a UI icon (the picker grid shows hair, not
  names), drawn by `tools/gen_ui_icons.py`.
- `tools/check_creation.js`: every gender preset, hair style and colour refers to an existing
  part or palette index, each gender has at least one hair style, and the default is a valid
  creation.

**Acceptance criteria:**
- [ ] `npm run validate`, `npm run check-drift` and `node tools/check_creation.js` pass.
- [ ] Suite: every gender preset and hair option resolves through `AssetOverlay` in the public
  build, and every hair style has an icon.
- [ ] Suite: the name rule accepts and rejects a fixture list, including accents, emoji, a
  reserved word, a case-folded duplicate and a mixed-script or confusable duplicate.
- [ ] Suite: a creation with a hair style from the other gender, an unknown hair style or a hair
  colour outside the list is refused.
- [ ] Suite: the default rig's head-to-height ratio is within the chibi preset range.

---

## Phase 181 — Character creation at runtime: a creation screen before the first spawn

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
- [ ] Suite: the host accepts a valid creation and refuses each invalid field (name, gender,
  hair style, hair colour) with its own key.
- [ ] Harness: `create_character` over the socket. A duplicate name from a second client is
  refused, and the second client sees the first one's appearance and nameplate.
- [ ] Suite: a pre-181 save boots, offers creation once and keeps inventory and skills. A skip is
  recorded, is not offered again on the next join, and shows the handle on the nameplate.
- [ ] Playtest bot: a `create` step completes before `walk` and saves a screenshot of the screen.
- [ ] Every new string is in both catalogs, and the i18n key check passes.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 183 — Playtest process time under 16 ms

**Goal:** Phase 174 gated `walk`, `craft` and `fight` on p95 process time (the scene tree's `_process`
work per frame) and found them at 26, 27 and 18 ms on llvmpipe with the native builder loaded (median of
3 local runs on the pinned seed). Physics is under 1.5 ms, so the cost is main-thread `_process` work,
not the chunk build. Name it and cut it.

**Newel dependency:** NO.

**Depends on:** Phase 174.

**Deliverables:**
- Profile the three steps (per-slice `_process` timing, `Performance` custom monitors) and name the
  top main-thread cost in the PR.
- Fix it, then lower `docs/perf/playtest-budget.json` and the table in `docs/perf/playtest-baseline.md`
  toward the 16 ms target.

**Acceptance criteria:**
- [ ] The top main-thread cost per step is named in `docs/perf/playtest-baseline.md`.
- [ ] CI playtest: `walk`, `craft` and `fight` median p95 process time is ≤ 16 ms × 1.25.
- [ ] Suite green on both boot paths.

---

## Deferred (in priority order)

- **Next arc: the first settlement loop** — a goal you can describe from the player's side for
  the arc after this one: four friends found a village, specialize, trade and defend it from a
  raid within an hour of play. Derive its phases from that loop (shared projects, roles from
  skills and attributes, raids, settlement upkeep) rather than from engine work.
- **Rivers, lakes and fluid flow** — water above sea level and flowing water (a cellular
  automaton on dirty chunks only) after Phase 51's static sea level and Phase 137's falling sand.
- **Fast travel beyond waystones** — a planet takes about 90 days to walk around. Phase 125 added
  waystones; roads, mounts (taming exists) and boats remain.
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
- **Real cross-region multiplayer run** — Phase 135 emulates WAN profiles in the harness. A run
  between real regions remains.
- **Automatic LOD mesh decimation** — simplified meshes are hand-authored (Phase 23).
- **Dynamic impostor re-bake** — impostor billboards are baked offline. A live re-bake on palette
  change is deferred from Phase 23.
- **Server sharding (last, not before maturity)** — split the authoritative simulation across
  servers by region once one headless server (Phase 27) with spatial hashing (Phase 28) and
  interest management (Phase 29) saturates. No structural change is needed before then. Revisit
  when Brazil-region load approaches one server's ceiling.
