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

Phases 1–172 are done. Their specs and acceptance criteria are archived in
[docs/roadmap-history/](docs/roadmap-history/README.md).

### Arc: make it look and feel like an RPG (Phases 173–181)

After 172 phases the engine is strong: a deterministic planet, host-authoritative multiplayer,
persistence, crafting, combat, taming and settlements. But it does not yet look or play like an
RPG. Items and windows show letters, the character has no attributes, and a player never creates a
character: they spawn as a handle. This arc pays down the follow-up debt and makes the frame
budget honest. Then it gives the game icons, attributes, a character sheet and character creation.

| Phase | Title | Status | Spec |
|---|---|---|---|
| 173 | Follow-up debt burn | Planned | below |
| 174 | An honest playtest frame budget | Planned | below |
| 175 | UI icons: dock, windows, skills and attributes from one generator | Planned | below |
| 176 | An icon for everything a player can hold | Planned | below |
| 177 | Attributes in the fabric: strength, vitality, resistance, agility, intelligence, perception | Planned | below |
| 178 | Attributes at runtime: host-owned, persisted, feeding the derived stats | Planned | below |
| 179 | The character sheet: a paper doll, attributes and derived stats | Planned | below |
| 180 | Character creation in the fabric: name, appearance and starting attributes | Planned | below |
| 181 | Character creation at runtime: a creation screen before the first spawn | Planned | below |

---

## Phase 173 — Follow-up debt burn

**Goal:** about 30 `autopilot-followup` issues are open, some for a week, and roughly a third of
recent commits are follow-ups. Each review spawns more debt than the next phase pays off. Burn
the backlog down before the arc adds new systems, and make the cap above enforceable.

**Newel dependency:** NO.

**Depends on:** nothing.

**Deliverables:**
- Triage every open `autopilot-followup` issue. Fix each item that is a correctness or
  trust-boundary bug. Fold each item that belongs to a phase of this arc into that phase's
  deliverables, and record the issue number there. Close the rest with a one-line reason.
- Fix the standalone issues: #426 (host-side speed clamp for carrying peers, a trust-boundary
  gap), #429 (the `chop_in_reach` harness flake) and #427 (the harvest quality grade never reaches
  the item stack; Phase 178 builds on it).
- `tools/check_followups.sh`: counts open `autopilot-followup` issues via `gh` and exits 1 when
  there are more than 10. Autopilot runs it before it opens a new phase.

**Acceptance criteria:**
- [ ] At most 5 `autopilot-followup` issues are open when the phase closes (`gh issue list
  --label autopilot-followup --state open`).
- [ ] #426, #427 and #429 are closed by merged PRs. The harness runs `chop_in_reach` 20 times in a
  row with no failure in CI.
- [ ] Suite: a carrying peer that reports a speed above the clamp is pulled back by the host.
- [ ] Suite: a harvested stack carries its quality grade through to the inventory and a save.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 174 — An honest playtest frame budget

**Goal:** the playtest bot reports PASS while `walk`, `craft` and `fight` run at a p50 of about
130 ms per frame, with every frame counted as a hitch. The only failure condition is a frame over
2 s. The per-chunk build is about 138 ms, and 114 ms of that is `arrays`, which is suspicious
after Phase 169 moved it native. Find out what the number measures, then gate on it.

**Newel dependency:** NO.

**Depends on:** nothing.

**Deliverables:**
- The playtest report records the rendering adapter and driver, whether the native chunk builder
  loaded, and each step's frame time split into process, physics and render
  (`Performance` monitors).
- If the run uses the GDScript fallback, fix the CI packaging so the native builder loads.
- A per-step budget table in `docs/perf/playtest-baseline.md`: p95 **process** time (which
  software rendering does not inflate), plus p95 total frame time on a named renderer class.
  `--playtest-bot` exits 1 when a step exceeds its budget.
- If the process time is over budget, profile it and fix the top cost, or file it as the next phase.

**Acceptance criteria:**
- [ ] `playtest/report.json` carries `adapter`, `native_builder` and per-step `process_ms`,
  `physics_ms` and `render_ms` percentiles.
- [ ] CI playtest: the native builder is loaded (`native_builder: true`).
- [ ] CI playtest: `walk`, `craft` and `fight` p95 process time ≤ 16 ms. The bot fails the run
  above budget, and a fixture proves it (an injected 40 ms step fails).
- [ ] Suite green on both boot paths.

---

## Phase 175 — UI icons: dock, windows, skills and attributes from one generator

**Goal:** the window dock shows one letter per button (I, C, K, H, T…), and skills have no
pictures. Draw each window, skill and attribute as a small, readable icon: a bag for the
inventory, a globe for the map, a hammer and anvil for crafting. Use the Phase 152 pattern:
pure-Python, deterministic, and hand-polished later by the private repo over the same keys.

**Newel dependency:** NO.

**Depends on:** Phase 173.

**Deliverables:**
- `tools/gen_ui_icons.py` (new, pure Python, no Blender or GPU). It uses a small vector DSL
  (polygons, circles, arcs, strokes) rasterized at 128×128 and downsampled to 32×32 and 64×64,
  with a palette snap and a 1 px outline. The style follows the icon rules in
  `project-nihon-assets/STYLE.md`. `--check` and `--out DIR` work as in `gen_item_assets.py`.
- Window icons at `assets/icons/ui/window/<key>.png.raw` for every entry in `WindowDock`:
  inventory (bag), character (helmeted bust), skills (open book), crafting (hammer and anvil),
  technology (gear and flask), trade (two hands swapping), market (coin stack), map (globe),
  proposals (scroll and quill), settlement (house with a hearth), controls (keyboard).
- Skill icons at `assets/icons/skills/<Skill>.png.raw` for all 22 skills. Each one combines a
  category frame (combat, crafting, magic, exploration, social) with a symbol for the skill
  (sword, bow, saw, anvil, rune…).
- Attribute icons at `assets/icons/attributes/<Attribute>.png.raw` for the Phase 177 set, plus HUD
  icons for HP and each Phase 129 status effect.
- The dock draws the icon with the shortcut letter as a small corner badge. The tooltip keeps the
  translated name. The skills window and the HUD status row use their icons.
- `assets/manifest.json` and `assets/README.md` list the new keys. The private repo gets a
  matching note (separate PR).

**Acceptance criteria:**
- [ ] Every `WindowDock` entry, every skill in `GameData.SKILLS`, every status effect and HP has an
  icon at its key. No orphan icon exists.
- [ ] Suite: every UI icon is 32×32 or 64×64 RGBA, has transparent corners and more than 40 opaque
  pixels, and no two are byte-identical.
- [ ] Suite: a built dock button carries a texture and a badge with the shortcut letter, and no
  dock button's text is a bare letter.
- [ ] CI: `python3 tools/gen_ui_icons.py --check` passes, and two runs are byte-identical.
- [ ] Suite green on both boot paths.

---

## Phase 176 — An icon for everything a player can hold

**Goal:** all 27 items have icons since Phase 152, but materials (Soil, Thornwood, Ferrite…),
harvest goods (hides, meat, bones, sigils) and carcasses still fall back to `item_glyph`, which
paints their first letter. Every stack a player can hold should have a picture.

**Newel dependency:** NO.

**Depends on:** Phase 175 (shares the rasterizer).

**Deliverables:**
- `gen_item_assets.py` (or `gen_ui_icons.py`) draws an icon for every material from its palette
  and form (block, ore chunk, log, sheaf, pile) and for every harvest and loot output from its
  kind (hide, meat, bone, trophy).
- One source of truth for "every id that can sit in a slot": items, materials, harvest outputs,
  loot outputs and carcasses. The suite and the generator both read it.
- The technology tree and the crafting rows show the icon of what they unlock or produce. The
  market and trade rows show it too.
- The public build never shows the glyph fallback. It remains only as a debug guard.

**Acceptance criteria:**
- [ ] Suite: every holdable id has an icon at its key, and no orphan icon exists.
- [ ] Suite: building the inventory, hotbar, character, crafting, technology, market and trade
  rows for a fixture holding every holdable id never calls `item_glyph`.
- [ ] CI: the generator's `--check` passes, and two runs are byte-identical.
- [ ] Suite green on both boot paths.

---

## Phase 177 — Attributes in the fabric: strength, vitality, resistance, agility, intelligence, perception

**Goal:** the character has no attributes. Carry capacity is a fixed base (Phase 160), HP is a flat
100, and nothing distinguishes one character's body from another's. Model a small attribute set
that feeds systems that already exist. There are no classes and no levels: attributes start from
character creation and grow slowly from use, in keeping with the sandbox constitution.

**Newel dependency:** NO.

**Depends on:** Phase 173.

**Deliverables:**
- `fabric/gameplay/attributes.js` (new): an `AttributeSystem` entity with six attributes and their
  bounds (base 10, creation range 5–18, hard cap 30). Each attribute lists what it feeds:
  - **Strength**: carry capacity (replaces the fixed Phase 160 base), melee damage, knockback
    dealt, mining and chopping speed.
  - **Vitality**: max HP, HP regeneration, rest regeneration (Phase 158 gestures).
  - **Resistance**: damage reduction, status-effect chance and duration (Phase 129), knockdown
    and stagger resistance.
  - **Agility**: movement speed (small), attack interval, chance to avoid a knockdown.
  - **Intelligence**: research point gain (Phase 124), the chance of a quality grade on a craft,
    XP rate for magic skills.
  - **Perception**: gather yield, the harvest quality grade (Phase 161), the radius at which
    creatures and deposits show on the minimap.
- A derivation table: each derived stat as a base plus a per-point slope with a clamp, so a
  20-point gap is noticeable but never a one-shot. The table is data, not code.
- A growth table: skill XP from each skill category feeds weighted attributes (combat → Strength
  and Agility, crafting → Strength and Intelligence, exploration → Perception and Agility…) with
  diminishing returns and a total-points cap. Growth comes from use, not from spending points.
- `PlayerCharacter` gains `attributes` (json) and drops the fixed `carryCapacityKg` default in
  favour of the derivation.
- `tools/check_attributes.js` in the style of `check_combat.js`: bounds are consistent, every
  derived stat it names exists, and the extremes (all 5s, all 30s) stay inside each stat's clamp.
- Display names and descriptions are UI catalog keys (`attr.<id>.name`, `attr.<id>.desc`) in
  `en` and `pt_BR`.

**Acceptance criteria:**
- [ ] `npm run validate`, `npm run check-drift` and `node tools/check_attributes.js` pass.
- [ ] Generated `GameData` exposes the attribute set, the derivation table and the growth table.
- [ ] Every attribute has `en` and `pt_BR` catalog entries, and the i18n key check passes.

---

## Phase 178 — Attributes at runtime: host-owned, persisted, feeding the derived stats

**Goal:** make Phase 177 real. The host owns every player's attributes, derives their stats from
the fabric table, persists them, and grows them from skill XP. The client only displays them.

**Newel dependency:** NO.

**Depends on:** Phase 177.

**Deliverables:**
- `src/character/attribute_rules.gd`: pure functions for deriving stats and applying growth, read
  from `GameData`.
- The host stores attributes on the player record. A save from before this phase loads with base
  10 in everything (versioned migration, as in Phase 121).
- Carry capacity, max HP and regeneration, damage reduction, status-effect rolls, attack interval,
  research gain, gather yield, harvest quality and minimap detection radius read the derived stats.
- `attributes_synced` goes to the owning client only, and peers get only what they need to draw.
  The client sends no attribute values. The host ignores and rate-limits any attempt.
- Skill XP grants feed attribute growth on the host, with the cap enforced.

**Acceptance criteria:**
- [ ] Suite: each derived stat equals the fabric formula at the minimum, base and maximum.
- [ ] Suite: growth from XP follows the table, has diminishing returns and stops at the cap.
- [ ] Suite: a pre-178 save loads with base attributes and the same carry capacity as before.
- [ ] Harness: `attributes_synced` reaches the owner over the socket. A client payload carrying
  attribute values is refused and counted.
- [ ] Suite green on both boot paths, harness green.

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
- An attribute panel: icon, value and a growth bar toward the next point. The tooltip lists what
  the attribute feeds and by how much.
- A derived-stat panel: HP, regeneration, carry, damage, reduction, speed, research gain and yield.
- A short skills summary (the top skills by tier, with skill icons) that links to the skills window.
- A display name above the doll once Phase 181 lands. Until then the handle is shown.
- Every string goes through `I18n.t`. Numbers are formatted for the active locale.

**Acceptance criteria:**
- [ ] Suite: the sheet's projection (`character_sheet_rows()`) lists every equipment slot, all six
  attributes and every derived stat, with values equal to the host's synced numbers.
- [ ] Suite: dropping an item on a slot emits the same equip intent as the context menu.
- [ ] Suite: building the sheet hard-codes no user-facing literal (audit test), and both locales
  render.
- [ ] Playtest bot: a `character_sheet` step opens the window, renders the doll with a non-empty
  viewport and takes a screenshot.
- [ ] Suite green on both boot paths.

---

## Phase 180 — Character creation in the fabric: name, appearance and starting attributes

**Goal:** a player never creates a character. They spawn with a default appearance and are known by
a handle. Model the creation choices so the runtime screen in Phase 181 is generated from data.

**Newel dependency:** NO.

**Depends on:** Phase 177.

**Deliverables:**
- `fabric/gameplay/characters/creation.js` (new): a `CharacterCreation` entity with:
  - name rules: 3–16 characters, Unicode letters plus a single inner space, hyphen or apostrophe,
    unique per server (case- and accent-folded), and a reserved list;
  - appearance options drawn from the existing recipe fields (`appearances.js`): skeleton, body,
    head, eyes, hair, beard, the skin, hair and eye palette ranges, and the proportion bounds (§8);
  - starting attributes: base 10 each and 12 points to distribute within the creation range
    (Phase 177);
  - a starting kit per server rule (none by default; the sandbox gives no class kits).
- Public placeholders for at least three heads, five hair styles and three beards, at the same
  keys the private repo will fill (placeholder rule; `gen_placeholder_glb.py`).
- `tools/check_creation.js`: every option refers to an existing part, palette index or bound, and
  the default recipe is a valid creation.

**Acceptance criteria:**
- [ ] `npm run validate`, `npm run check-drift` and `node tools/check_creation.js` pass.
- [ ] Suite: every appearance option resolves through `AssetOverlay` in the public build.
- [ ] Suite: the name rule accepts and rejects a fixture list, including accents, emoji, a
  reserved word and a case-folded duplicate.

---

## Phase 181 — Character creation at runtime: a creation screen before the first spawn

**Goal:** a new player creates a character before they enter the world. They pick a name, shape
the face and body, choose colours, spend the starting points and see the result live. The host
validates everything and records it.

**Newel dependency:** NO.

**Depends on:** Phases 179 and 180.

**Deliverables:**
- A creation screen shown on first join to a server where the player has no character record,
  before spawn placement (Phase 53). It has a live rig preview (reusing the Phase 179 viewport),
  pickers generated from the `CharacterCreation` options, a randomize button, an attribute point
  spender, and a name field with a live availability check.
- A host intent `create_character(name, recipe, attributes)`. The host validates the name rule
  and uniqueness, every option and the point budget, creates the record, then places the spawn.
  It refuses with a keyed reason that the client renders in its locale. Rate-limited.
- Existing players without a creation record are offered the screen once. Their handle and
  progress are kept.
- The display name shows on the character sheet, in chat and settlement lists, and on a nameplate
  above other players. The friend code stays the handle.
- The appearance recipe syncs to peers in the area of interest, so everyone sees each other's
  character.
- The playtest bot creates a character as its first step.

**Acceptance criteria:**
- [ ] Suite: the host accepts a valid creation and refuses each invalid field (name, option,
  palette index, proportion bound, overspent points) with its own key.
- [ ] Harness: `create_character` over the socket. A duplicate name from a second client is
  refused, and the second client sees the first one's appearance and nameplate.
- [ ] Suite: a pre-181 save boots, offers creation once and keeps inventory and skills.
- [ ] Playtest bot: a `create` step completes before `walk` and saves a screenshot of the screen.
- [ ] Every new string is in both catalogs, and the i18n key check passes.
- [ ] Suite green on both boot paths, harness green.

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
