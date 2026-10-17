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

---

## Phase index

| Phase | Title | Status | Spec |
|---|---|---|---|
| 1 | Constitution fabric | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 2 | Materials and world primitives | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 3 | Skills and professions | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 4 | Items, recipes, and technology tree | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 5 | Creatures and combat systems | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 6 | `generator-bible` integration | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 7 | Character system specification | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 8 | `generator-godot` integration | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 9 | Public wiki | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 10 | Vertical slices: playable game loop | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 11 | Crafting slice | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 12 | Voxel mining and building | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 13 | Technology unlock gates | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 14 | Player UI: inventory, technology tree, crafting | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 15 | Creature AI and behavior | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 16 | Station-gated crafting and tool durability | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 17 | Chunk streaming and world expansion | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 18 | Multiplayer world sync (core) | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 19 | Multiplayer chaos resilience | Done | [history](docs/roadmap-history/phases-01-19.md) |
| 20 | Skeleton rig and animation | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 21 | Asset separation and public placeholders | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 22 | Material and palette pipeline | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 23 | LOD and composition simplification | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 24 | Social systems and player economy | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 25 | Tool and equipment repair | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 26 | Client-side rendering instancing | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 27 | Headless data-oriented server | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 28 | Spatial hashing | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 29 | Interest management (area of interest) | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 30 | Pack and herd behavior | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 31 | Trees and resource appearance | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 32 | One authoritative boot path | Done | [history](docs/roadmap-history/phases-20-32.md) |
| 33 | Player identity and server-side persistence | Done | [history](docs/roadmap-history/phases-33-38.md) |
| 34 | Per-player repair and research | Done | [history](docs/roadmap-history/phases-33-38.md) |
| 35 | Creature taming | Done | [history](docs/roadmap-history/phases-33-38.md) |
| 36 | Review pass: the network trust boundary, gated boots, per-player progression | Done | [history](docs/roadmap-history/phases-33-38.md) |
| 37 | Review pass: owner-scoped syncs, durable cooldowns, bounded memory, routed rounds | Done | [history](docs/roadmap-history/phases-33-38.md) |
| 38 | Review pass: host-simulated peer health, one key list, the missing clear, an in-place prune | Done | [history](docs/roadmap-history/phases-33-38.md) |
| 39 | Two-client network harness: prove the wire over a real socket | Done | [history](docs/roadmap-history/phases-39-42.md) |
| 40 | Review pass: the avatar's footing — the voxel surface, walked stairs | Done | [history](docs/roadmap-history/phases-39-42.md) |
| 41 | Deterministic world and volumetric terrain | Done | [history](docs/roadmap-history/phases-39-42.md) |
| 42 | Threaded chunk build and a loading screen | Done | [history](docs/roadmap-history/phases-39-42.md) |
| 43 | Natural resource distribution | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 44 | Spawn scarcity | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 45 | Asset pipeline for meshes and animation | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 46 | UI shell | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 47 | Character window | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 48 | Review pass: the equipment trust boundary | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 49 | Zone crossing and natural ground | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 50 | Planet coordinates | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 51 | Continents, oceans and mountains | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 52 | Region storage and per-player server streaming | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 53 | Spawn placement and friend codes | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 54 | World clock, day and night, seasons | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 55 | Two-client harness: equipment delivery over the socket | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 56 | Station placement follow-ups | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 57 | Spawn determinism and cost follow-ups | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 58 | UI layout file robustness | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 59 | Wire the Phase 45 rig into the game | Done | [history](docs/roadmap-history/phases-43-59.md) |
| 60 | Host-authoritative equip | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 61 | Region storage correctness | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 62 | Peer streaming window limits | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 63 | Planet coordinates wiring | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 64 | Biome blend consistency | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 65 | World clock and season follow-ups | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 66 | Spawn point and colonization follow-ups | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 67 | Network test seam cleanup | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 68 | Distant terrain off the main thread | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 69 | Neighbour seam rebuilds that match the edits | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 70 | Equip intent ordering and refusal cost | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 71 | World-generation version stamp | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 72 | Stable, low-frequency rare-biome niches | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 73 | Swimming and the distant ring follow the real ground | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 74 | Minimap redraw cost and first-apply layout clamp | Done | [history](docs/roadmap-history/phases-60-74.md) |
| 75 | Region edits survive eviction and malformed neighbours | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 76 | Niche field wraps the planet and is calibrated by a test | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 77 | One detail-noise formula and the ring's strip helper | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 78 | Exact player position far from the origin | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 79 | Deterministic peer-window rate limit and a production ref-count reader | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 80 | Rebase in the physics step and explicit shift sets | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 81 | Pole-aware tile biome and a mined-tile biome memo | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 82 | Honest peer-window refusal count and a thread-safe warning counter | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 83 | Distant-ring teardown that does not stall | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 84 | The suite exits with no leaked objects | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 85 | Peer claims and host syncs keep separate interval clocks | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 86 | Remote peers' positions stay exact far from the origin | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 87 | Exact spawn and respawn points | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 88 | The distant ring survives a reparent and its abort is proven | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 89 | A malformed region entry warns once per session | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 90 | One scene-origin source and one wire-position validator | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 91 | A legacy tile height survives a depletion overlay | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 92 | The shown-biome memo follows the terrain slice and one pole-ring rule | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 93 | Host-sync window moves are counted and a clock swap resets the throttles | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 94 | A test eviction helper and a bounded UI retire list | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 95 | Free pointer, right-click look, chat box and admin commands | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 96 | A detached ring rebuild does not orphan its worker | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 97 | Peer windows and position relays use the exact peer position | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 98 | An exact first-boot spawn and a public canonical helper | Done | [history](docs/roadmap-history/phases-75-98.md) |
| 99 | Housekeeping sweep: legacy tiles, roadmap/README hygiene and review leftovers | Done | [history](docs/roadmap-history/phases-99-129.md) |
| 100 | Follow-up issue backlog triage | Done | [history](docs/roadmap-history/phases-99-129.md) |
| 101 | Chat and admin commands are host-authoritative, exact and proven on the wire | Done | [history](docs/roadmap-history/phases-99-129.md) |
| 102 | An admin `/kill` lands on the host's simulated peer health | Merged | [Phase 101](docs/roadmap-history/phases-99-129.md#phase-101--chat-and-admin-commands-are-host-authoritative-exact-and-proven-on-the-wire) |
| 103 | Teleports carry the exact position and stay on the planet | Merged | [Phase 101](docs/roadmap-history/phases-99-129.md#phase-101--chat-and-admin-commands-are-host-authoritative-exact-and-proven-on-the-wire) |
| 104 | Two-client harness: chat and admin teleport over the socket | Merged | [Phase 101](docs/roadmap-history/phases-99-129.md#phase-101--chat-and-admin-commands-are-host-authoritative-exact-and-proven-on-the-wire) |
| 105 | Archive Phases 75–95 into the roadmap history | Merged | [Phase 99](docs/roadmap-history/phases-99-129.md#phase-99--housekeeping-sweep-legacy-tiles-roadmapreadme-hygiene-and-review-leftovers) |
| 106 | A world stamp that covers fabric parameters, and golden generator values | Done | [history](docs/roadmap-history/phases-99-129.md) |
| 107 | A per-chunk generation record in the region store | Done | [history](docs/roadmap-history/phases-99-129.md) |
| 108 | Terrain reads and writes the generation record on the host | Done | [history](docs/roadmap-history/phases-99-129.md) |
| 109 | Generation records reach clients, scoped and validated | Done | [history](docs/roadmap-history/phases-99-129.md) |
| 110 | Trees are pinned per chunk and cleared where players build | Done | [history](docs/roadmap-history/phases-99-129.md) |
| 111 | A full-map window: zoom from the minimap out to a whole planet | Done | [history](docs/roadmap-history/phases-99-129.md) |
| 112 | A biome adjacency table in the fabric and an offline scan | Done | [history](docs/roadmap-history/phases-99-129.md) |
| 113 | Frontier generation: a new generator version meets recorded land | Done | [history](docs/roadmap-history/phases-99-129.md) |
| 114 | Generation record and frontier cleanup sweep | Done | [history](docs/roadmap-history/phases-99-129.md) |
| 115 | Chat, admin and test-tooling cleanup sweep | Done | [history](docs/roadmap-history/phases-99-129.md) |
| 116 | Tree clears follow chunks onto clients | Done | [history](docs/roadmap-history/phases-99-129.md) |
| 117 | Map waypoints, HUD toasts and an explored set that scales | Done | [history](docs/roadmap-history/phases-99-129.md) |
| 118 | Void bursts, the survivor flag and the VoidTouched unlock | Done | [history](docs/roadmap-history/phases-99-129.md) |
| 119 | An injected network transport and a compact per-tick wire form | Done | [history](docs/roadmap-history/phases-99-129.md) |
| 120 | The distant ring draws recorded land | Done | [history](docs/roadmap-history/phases-99-129.md) |
| 121 | Crash-consistent saves | Done | [history](docs/roadmap-history/phases-99-129.md) |
| 122 | Far terrain without mirroring and one scene-offset helper | Done | [history](docs/roadmap-history/phases-99-129.md) |
| 123 | The player rig wears the character material and body masks | Done | [history](docs/roadmap-history/phases-99-129.md) |
| 124 | Research points: the fabric's `researchCost` is enforced | Done | [history](docs/roadmap-history/phases-99-129.md) |
| 125 | Waystones: a first fast-travel network | Done | [history](docs/roadmap-history/phases-99-129.md) |
| 126 | Tree clears the host keeps, and one seam-wrap module | Done | [history](docs/roadmap-history/phases-99-129.md) |
| 127 | Terrain streaming, generation records and persistence cleanup sweep | Done | [history](docs/roadmap-history/phases-99-129.md) |
| 128 | Weather: the fabric's `WeatherSystem` runs on the host | Done | [history](docs/roadmap-history/phases-99-129.md) |
| 129 | Combat status effects: burn, paralysis, knockback, knockdown and stagger | Done | [history](docs/roadmap-history/phases-99-129.md) |
| 130 | Host authority sweep: status effects, waystones and research points | In review | below |
| 131 | Internationalization: translated UI and keyed host messages | In review | below |
| 132 | One wiring module per system: `game_root` keeps the boot paths | In review | below |
| 133 | The test suite splits by system and runs by filter | In review | below |
| 134 | A bot plays: playtest report and downloadable builds | In review | below |
| 135 | A WAN profile: latency, loss and bandwidth in the two-client harness | In review | below |
| 136 | Creatures walk on the ground and around obstacles | In review | below |
| 137 | Loose ground settles: sand and soil fall when undermined | In review | below |
| 138 | Trees, generation records and persistence cleanup sweep | In review | below |
| 139 | Settlements in the fabric: founding, membership and shared storage | In review | below |
| 140 | Settlements at runtime: a hearth, a claim and a shared stockpile | In review | below |
| 141 | Terrain streaming off the main thread: worker noise, seam strips, polar shortcuts, fold catch-up | In review | below |
| 142 | Terrain build throughput: a time-budgeted pump and a native chunk builder | Planned | below |
| 143 | Creature models: rigged, animated creatures replace the tinted box | In review | below |

---

## Phase 130 — Host authority sweep: status effects, waystones and research points

**Goal:** three review follow-up issues hold trust-boundary gaps that were filed as Low. Phase 129
enforces paralysis only on the paralyzed peer's own client (`PlayerSlice.held_speed`): the host
accepts `player_moved` from a held peer, so a modified client walks while paralyzed, and a
knockback on a peer with no reported state teleports it toward the origin. Waystones place without
consuming the `Waystone` item, reuse a removed station id after reload and answer every refused
intent. Research points are uncapped and farmable by gathering or crafting one unit at a time. The
host must decide all of these itself. This phase fixes every item of the three issues in one PR.

**Newel dependency:** NO.

**Closes:** #334, #336, #346.

**Depends on:** Phase 124, Phase 125, Phase 129.

**Deliverables:**
- `src/core/game_root.gd` / `src/networking/networking_slice.gd` — the host refuses (or clamps to
  the held position) `player_moved` from a peer that is paralyzed or knocked down, using the host's
  own status-effect state; `_on_knockback_requested` skips a peer without `has_last_known_state`.
- `src/battle/status_effects.gd` — `from_data` restores each stacked instance's own end time.
- `src/world/waystone_slice.gd`, `src/world/station_slice.gd` — station placement consumes the
  station's item when the fabric names one (policy recorded in the fabric); the station id counter
  is persisted; refused travel replies are throttled per peer; `try_attune` refuses early when full;
  far-from-origin stones and the map's "stone under player" check use exact `WorldPos`.
- `fabric/constitution/decisions.js` — a decision that amends `NoTeleportation` for waystones.
- `src/technology/technology_slice.gd`, `src/crafting/crafting_slice.gd`, `src/terrain/voxel_slice.gd`
  — research points have an upper bound and a per-window earn cap from the fabric, gather and craft
  points scale by quantity, points and first-craft markers live in their own record fields, and one
  technology sync is sent per action.
- Every other item of the three issues fixed, or confirmed fixed with the file or test that proves
  it, in a table in the PR body.

**Acceptance criteria:**
- [x] Harness: a `paralysis_holds` step paralyzes the client's player on the host, the client sends
  moves anyway (bypassing `held_speed`), and the host's recorded position for that peer does not move.
- [x] Suite: knockback on a peer with no reported state leaves its position unchanged; two stacked
  effects with different end times round-trip through save/load with their own end times.
- [x] Suite: placing a waystone without the item is refused; with it, the item is consumed; a
  removed trailing station id is not reused after a registry save/load.
- [x] Suite: research points never exceed the fabric cap; 100 one-unit gathers inside one window earn
  no more than the window cap; one craft sends one technology sync.
- [x] `npm run validate` and `npm run check-drift` green; every issue under **Closes:** is closed by
  the merge, each item accounted for in the PR table.
- [x] Suite green on both boot paths, harness green (CI run on the PR: suite, server boot, listen-host boot, harness all green).

---

## Phase 131 — Internationalization: translated UI and keyed host messages

**Goal:** translation support is mandatory for every project (workspace rule). Today every
player-facing string in `src/` is a hard-coded English literal, and the host sends rendered text
(chat system lines, admin replies, toasts) to clients. This phase routes all UI text through Godot's
`TranslationServer` with English and Brazilian Portuguese catalogs, lets the player switch language
at runtime, and changes host-originated messages to a key plus arguments so each client renders
them in its own locale. Adding a language afterwards is data-only (a new catalog file). It runs
before the remaining feature phases so the count of hard-coded strings stops growing.

**Newel dependency:** NO. Localized fabric content (item, creature, skill names) follows in a later
phase once Newel can emit translation catalogs (see Deferred).

**Closes:** #344.

**Depends on:** none.

**Deliverables:**
- `locale/ui.csv` (new) — Godot CSV translation catalog with `en` and `pt_BR` columns and stable
  snake-case keys (`hud.health`, `inventory.title`, `chat.system.player_joined`, ...);
  `project.godot` registers the imported translations and sets the fallback locale to `en`.
- `src/ui/`, `src/core/`, HUD, inventory, technology tree, crafting, map, chat and admin UIs — every
  player-facing literal becomes `tr("key")` (or `tr_n` for plurals, `String.format` placeholders for
  arguments); no concatenated sentences. This includes the weather label and `/weather` replies
  (#344) and `PlayerSlice.status_line`.
- `src/core/locale_settings.gd` (new) — chosen locale persisted in user settings, picked from saved
  preference → OS locale → `en`; `GameBus.locale_changed` re-renders open UI without a restart; a
  language selector in the settings/pause menu.
- Wire: host-originated chat/system/admin/toast messages carry `{key, args}` instead of text; the
  client validates the key against its catalog (unknown key → generic fallback line, never raw
  input) and bounds `args` count and length like other network input.
- Number and date formatting through one helper that follows the active locale.

**Implementation notes:** the CSV is parsed at runtime by `src/core/i18n.gd` (`I18n.t(key, args)`, positional
`{0}` placeholders) and registered with the `TranslationServer`, instead of going through the editor import,
because CI and the headless suite never run an import; `export_presets.cfg` ships `locale/*`. Static controls bind
their key with `UiSlice._set_tr` so `GameBus.locale_changed` re-applies them. Fabric content names (items,
creatures, skills) and slice-supplied `reason` codes stay untranslated until the fabric phase (see Deferred).

**Acceptance criteria:**
- [x] Suite: `en` and `pt_BR` columns of every catalog have the same key set and no empty cells.
- [x] Suite (audit): no string literal is assigned to `.text`, `.tooltip_text`, `.title` or
  `.placeholder_text` in `src/` outside `tr()`; an allow-list file covers non-translatable cases
  (numbers, debug overlays) and each entry carries a reason.
- [x] Suite: switching locale emits `locale_changed` and the HUD/inventory projections return
  pt-BR text; the choice survives a settings save/load round trip; an unsupported OS locale falls
  back to `en`.
- [x] Suite: a host system message serializes as key + args; a client renders it per locale; an
  unknown key, too many args or an oversize arg is refused with the fallback line.
- [x] Harness: a two-process run with host `en` and client `pt_BR` shows the joined-player chat
  line in Portuguese on the client.
- [x] Suite green on both boot paths, `npm run check-drift` green (CI run on the PR).

---

## Phase 132 — One wiring module per system: `game_root` keeps the boot paths

**Goal:** `src/core/game_root.gd` is 3,100 lines and 130 functions, and every phase adds to it
because the workflow says "wire in `game_root.gd`". Most of it is per-system glue: bus handlers that
call one slice, sync fan-out, snapshot apply. This phase moves that glue next to the system it
serves, so `game_root` only builds slices, picks the boot role and hands each wiring module the
references it needs. Behaviour does not change.

**Newel dependency:** NO.

**Depends on:** none.

**Deliverables:**
- `src/<system>/<system>_wiring.gd` (new, one per system with glue today: terrain, trees, waystones,
  weather, combat/status effects, technology, crafting, chat/admin, persistence, networking sync,
  ...) — a `RefCounted` with `wire(ctx)` that connects that system's `GameBus` handlers and
  `unwire()` that disconnects them; `ctx` carries the slices and the boot role.
- `src/core/game_root.gd` — builds slices, constructs each wiring module in a fixed order, owns boot
  paths and the tick; no system-specific bus handler is left in it.
- `CLAUDE.md` and README "Adding a new system" — step 4 points at the system's wiring module instead
  of `game_root.gd`.

**Acceptance criteria:**
- [x] `wc -l src/core/game_root.gd` is under 1,200.
- [x] Suite (audit): `game_root.gd` contains no `GameBus.<signal>.connect` outside the wiring-module
  list, and every `*_wiring.gd` is constructed exactly once on each boot path.
- [x] Suite: wiring then unwiring a root on each boot role (and the late colonization connect) leaves no connected handler behind
  (`unwire` disconnects everything `wire` connected) and no orphan nodes.
- [x] Suite green on both boot paths with the same assertion count as before the move (no test
  removed), harness green, `--server` and `--quit-after-boot` boots log their ready lines.

---

## Phase 133 — The test suite splits by system and runs by filter

**Goal:** all unit tests live in `src/tests/test_suite.gd` (22,000 lines, ~800 registered tests).
It is the largest file in the repo, slow to navigate, and there is no way to run one test: the
documented workaround is commenting out `_run_test` lines. This phase splits the suite into one
file per system behind the same runner and adds a `--test-filter` user arg, keeping every existing
rule (registration audit, orphan check). It also clears #331, whose items are test-suite and rig
material leftovers.

**Newel dependency:** NO.

**Closes:** #331.

**Depends on:** none.

**Deliverables:**
- `src/tests/suites/<system>_tests.gd` (new) — the existing tests moved by system, unchanged in
  body; shared helpers in `src/tests/test_support.gd`.
- `src/tests/test_suite.gd` — becomes the runner: loads every suite file, keeps the
  unregistered-test audit (now across all suite files) and the final orphan check.
- `--test-filter=<substring>` user arg (after `--`) — runs only tests whose registered name contains
  the substring; the audits still run; the result line names the filter.
- `CLAUDE.md` — the "no single-test filter" paragraph is replaced by the filter usage.
- Every item of #331 fixed (rig material per-palette cache and shared material helper, every mesh
  asserted, build-split probe bounds), or confirmed fixed in the PR table.

**Acceptance criteria:**
- [x] No suite file is over 3,000 lines; the full run reports the same number of registered tests
  and assertions as before the split.
- [x] Suite: an unregistered `_test_*` in any suite file fails the run; `--test-filter=worldgen`
  runs only matching tests and still runs the audits; a filter matching nothing fails loudly.
- [x] CI runs the full suite exactly as before (no filter).
- [x] Every item of #331 accounted for in the PR table; suite green on both boot paths, harness
  green.

---

## Phase 134 — A bot plays: playtest report and downloadable builds

**Goal:** 129 phases in, nothing measures how the game feels to play. The two human-verification
issues (#133, #134) have been open since 2026-10-05, and every gate is a headless unit or
socket test. This phase adds a scripted bot that plays a real rendered session: it walks 20
chunks, mines, gathers, crafts, places a station, fights a creature and travels by waystone, while
recording frame times and screenshots. CI publishes the report and a Linux and Windows build on
every main push, so a human playtest is one download away. Perf thresholds start loose and are a
report, not a gate, except for hard failures.

**Newel dependency:** NO.

**Depends on:** Phase 125, Phase 129.

**Deliverables:**
- `src/tests/playtest_bot.gd` (new) — `--playtest-bot` user arg boots a listen host with rendering,
  runs a fixed step list (walk, mine, gather, craft, place, fight, travel) through the same intents
  a player's input sends, and fails a step that does not reach its expected state within a timeout.
- Frame-time capture per step: p50/p95/p99/max, hitch count (> 50 ms), chunk-build counts, written
  to `playtest/report.json` and a `report.md` summary; a screenshot per step to `playtest/*.png`.
- `.github/workflows/ci.yml` — a `playtest` job runs the bot under `xvfb-run` with Mesa software
  rendering and uploads `playtest/` as an artifact; a `build` job on `main` exports the `Linux` and
  `Windows Desktop` presets (placeholders only) and uploads them.
- #133 and #134 updated with a link to the artifact and the remaining human-only checks.

**Acceptance criteria:**
- [ ] CI: the playtest job passes, every bot step reaches its expected state, and the artifact holds
  `report.json`, `report.md` and one screenshot per step.
- [x] Suite: the report builder computes percentiles and hitch counts correctly from a fixed list of
  frame times; a step timeout marks the step and the run failed.
- [ ] CI: the job fails on a hard failure (crash, step timeout, any frame over 2 s) and not on
  slower-than-target percentiles.
- [ ] CI on `main`: the Linux and Windows exports succeed and are uploaded.

---

## Phase 135 — A WAN profile: latency, loss and bandwidth in the two-client harness

**Goal:** every multiplayer check runs on loopback (deferred list: "WAN / cross-region multiplayer
testing"). The Phase 19 emulator covers jitter, loss and reordering, but has no base latency or
bandwidth cap and the harness never turns it on. This phase adds both, defines named profiles
(`lan`, `wan_br` ≈ 60 ms ± 15 ms, 1% loss; `wan_bad` ≈ 200 ms ± 60 ms, 5% loss, 256 kbit/s) and runs the
full harness step list under `wan_bad` in CI, so a sync that only works without delay fails a gate.

**Newel dependency:** NO.

**Depends on:** Phase 19, Phase 119.

**Deliverables:**
- `src/networking/networking_slice.gd` — emulator gains `emulator_latency_ms` and
  `emulator_bandwidth_kbps` (bytes queued per second, excess delayed, never dropped silently);
  profiles defined in one table; `--net-profile <name>` user arg on host and client.
- `tools/net_harness.sh` — `NET_PROFILE` env var passed to both processes; step timeouts scale with
  the profile's round-trip time.
- `.github/workflows/ci.yml` — the harness job runs once on loopback and once under `wan_bad`.
- A short note in `README.md` Testing on running the harness under a profile.

**Acceptance criteria:**
- [x] Suite: with 200 ms latency a packet is delivered no earlier than 200 ms after send; a
  bandwidth cap of 256 kbit/s never delivers more than 32 KB in any one-second window; an unknown
  profile name is refused at boot.
- [x] CI: every harness step passes under `wan_bad`; the harness log records the profile in use.
- [x] Harness green on loopback, suite green on both boot paths.

---

## Phase 136 — Creatures walk on the ground and around obstacles

**Goal:** `CreatureAI._move_instance` steps a creature in a straight 3D line toward its target; the
ground height is read only at spawn, so a chasing creature floats over valleys, sinks into hills and
walks through placed walls and stations. The deferred list asks for path-finding (deferred from
Phase 15). A baked `NavigationAgent3D` mesh does not fit a streamed voxel world with a headless server,
so this phase gives creatures a host-side, bounded grid path over the voxel columns: each step follows
the walkable surface, a step taller than the creature can climb or deep water is routed around, and the
cost per tick is capped.

**Newel dependency:** NO.

**Depends on:** Phase 15, Phase 40, Phase 78.

**Deliverables:**
- `fabric/world/creatures/shared.js` — per-creature `maxStepMetres`, `canSwim`, `pathRadiusTiles` (with
  defaults and validators); regenerated.
- `src/creature/creature_path.gd` (new) — `find_path(from_tile, to_tile, rules, surface) -> Array` A*
  over tiles within `pathRadiusTiles`, a step allowed when the height difference ≤ `maxStepMetres` and
  the tile is not water unless `canSwim`; works on exact `WorldPos` tiles across the X wrap; returns a
  partial path toward the closest reached tile when the goal is unreachable; a node-expansion cap.
- `src/creature/creature_ai.gd` — chase, flee, patrol and companion follow move along the path; every
  step sets Y from the voxel surface (`VoxelSlice` column top, not the generator height, so mined pits
  and placed blocks count); a path is recomputed when the target moves more than two tiles or the next
  tile's column changed (`block_changed`); a per-tick budget of path searches shared by all creatures,
  overflow waits for the next tick in a round-robin queue.
- `src/creature/creature_slice.gd` — a creature in an unloaded chunk freezes instead of moving on
  generator heights; `set_instance_position` keeps the visual transform on the surface.
- `src/tests/net_harness.gd` — the existing creature-sync step asserts the client's creature Y equals
  the host's surface height.

**Acceptance criteria:**
- [x] `npm run validate` and `npm run check-drift` green; a negative `maxStepMetres` fails validation.
- [x] Suite: a creature chasing a player across a valley stays within 0.1 m of the surface at every
  step; a 3 m placed wall between them is walked around, not through.
- [x] Suite: a non-swimming creature never enters a water tile; a goal on an island returns a partial
  path ending at the nearest shore tile.
- [x] Suite: a search in a fully walled pocket stops at the expansion cap; with 200 creatures chasing
  at once, path searches per tick never exceed the budget and every creature has moved within
  `ceil(200 / budget)` ticks.
- [x] Suite: a chase across the X wrap at chunk X = 1,500,000 takes the short way round.
- [x] Harness green with the creature-height assertion; suite green on both boot paths.

---

## Phase 137 — Loose ground settles: sand and soil fall when undermined

**Goal:** the deferred list keeps a cellular automaton for loose materials (from the GDVoxelPlayground
evaluation). Today a player can mine out the ground under a beach and leave the sand hanging, or build
a floating sand pillar. This phase marks granular materials in the fabric and runs a host-side settling
pass on dirty columns only: a granular span with air below falls to the first support, the result goes
through the existing authoritative voxel edit path (persisted in the region store, synced to clients),
and the pass is bounded per tick so a large collapse spreads over several ticks.

**Newel dependency:** NO.

**Depends on:** Phase 12, Phase 52, Phase 116, Phase 121.

**Deliverables:**
- `fabric/world/materials/` — a `granular` boolean on materials (`Sand`, `Soil`, `Snow` true; rock,
  ores and metals false), with a validator that every biome `surfaceMaterial` declares it; regenerated.
- `src/terrain/settle.gd` (new) — a pure `settle_column(spans, granular) -> spans` that drops each
  unsupported granular span onto the next solid span below, keeping material and total volume; a
  `SettleQueue` of dirty columns (from `block_changed` on the host: the edited column and its four
  neighbours), processed in a deterministic order with a per-tick column budget.
- `src/terrain/voxel_slice.gd` — on the host, a settled column is written through the same edit path as
  a mine or place (region store, `block_changed`, client sync), marked as a settle edit so it grants no
  item and costs no material; clients never settle on their own.
- `src/terrain/voxel_slice.gd` / `chunk_manager.gd` — neighbour seam rebuilds follow settled columns;
  a settle in an unloaded neighbour chunk is queued until the chunk loads, not dropped.
- `src/world/tree_slice.gd` — a tree whose ground falls more than `CLEAR_DEPTH_M` is cleared through
  the Phase 116 path.
- Generated (unedited) terrain is not settled: only edited columns enter the queue, so world-gen output
  and `WORLDGEN_VERSION` are unchanged.

**Acceptance criteria:**
- [x] `npm run validate` and `npm run check-drift` green; a biome whose `surfaceMaterial` lacks
  `granular` fails validation.
- [x] Suite: `settle_column` keeps per-material volume; a sand span over air lands on the first solid
  span; a rock span over air does not move; settling an already-settled column is a no-op.
- [x] Suite: mining the stone under a 5-block sand stack on the host leaves no granular span over air
  after the queue drains; the result survives a region save/load and the worldgen golden values are
  unchanged.
- [x] Suite: a 1,000-column collapse never processes more than the per-tick budget and finishes within
  `ceil(1000 / budget)` ticks; a settle in an unloaded neighbour applies when that chunk loads.
- [x] Suite: a client's local edit enqueues nothing; a settle edit grants no item.
- [x] Harness: a `sand_settles` step mines under sand on the host and proves the client's column
  matches the host's after sync.
- [x] Suite green on both boot paths, harness green.

---

## Phase 138 — Trees, generation records and persistence cleanup sweep

**Goal:** four review follow-up issues collect leftovers in tree clears, generation records and
region persistence: unpinned host clears that do not survive a restart, ghost trees on clients,
`_cleared_local` eviction that drops state silently, seam-wrap arithmetic still copied outside
`seam_wrap.gd`, a fingerprint notice that fires on every load, and save-escalation counters that are
not "in a row". This phase resolves every item of the four issues in one PR.

**Newel dependency:** NO.

**Closes:** #294, #295, #338, #342.

**Depends on:** Phase 126, Phase 127.

**Deliverables:**
- `src/world/tree_slice.gd`, `src/persistence/region_store.gd`, `src/terrain/` (seam wrap, chunk
  records, chunk manager), `src/persistence/` (save escalation, save txn), `fabric/world/biomes` —
  every item of each issue fixed.
- Seam-wrap arithmetic lives only in `src/terrain/seam_wrap.gd`.
- The PR body has one `Closes #n` line per issue and a table: issue item → fixed here (with the file
  or test that proves it) / resolved by Phase N.

**Acceptance criteria:**
- [x] Suite: a host clear in a chunk whose record cannot be pinned survives a host save/restart; a
  client returning to an unrecorded cleared chunk sees no ghost tree.
- [x] Suite (audit): no seam-wrap modulo on chunk X outside `seam_wrap.gd`.
- [x] Suite: the worldgen fingerprint notice fires once per old world, not on every load.
- [x] `npm run validate`: a biome whose tree density can exceed `GEN_TREE_MAX` fails.
- [x] Every issue under **Closes:** is closed by the merge, each item accounted for in the PR table.
- [x] Suite green on both boot paths, harness green.

---

## Phase 139 — Settlements in the fabric: founding, membership and shared storage

**Goal:** the constitution promises a civilization built by players, and the fabric already refers
to "the player's settlement" and "settlement storage" in technology rules, guild formation in the
governance system and market stalls "at a settlement location". None of these has an entity behind
it, so the game has no shared place players build together and no reason to cooperate beyond
trading. This phase designs settlements in the fabric only (a separate PR from the runtime, per the
workflow): how one is founded, who belongs, what land it claims, what it stores together and how its
rules are changed through the existing proposal system.

**Newel dependency:** NO (if a needed field type is missing, file it on Newel and use the closest
existing type).

**Depends on:** Phase 24.

**Deliverables:**
- `fabric/gameplay/settlement.js` (new) — `Settlement` entity (name, founder, members with roles,
  hearth station, claim radius by tier, created/last-active), a `Hearth` station and recipe, a
  shared `Stockpile` container, a state machine (`founded → growing → town → abandoned`) with the
  thresholds, and the rules: who can build or take inside a claim, how claims grow, decay when
  abandoned, and that claims never cover another settlement's land.
- `fabric/gameplay/technology/index.js` — "settlement storage" and "in the player's settlement" rules
  reference `Stockpile` and `Hearth` instead of prose.
- `fabric/gameplay/economy.js` — guilds tied to settlements (a guild may hold one settlement),
  settlement rule changes go through `GovernanceSystem` proposals.
- `fabric/constitution/decisions.js` — a proposed decision recording the claim and decay rules.
- Regenerated `godot/`, `bible/`, `wiki/`.

**Acceptance criteria:**
- [x] `npm run validate` and `npm run check-drift` green.
- [x] Validation rejects a claim radius that shrinks with tier, a stockpile without capacity, and a
  state-machine threshold out of order.
- [x] `grep -rn "settlement storage\|player's settlement" fabric` finds no rule that is prose only.
- [x] The generated bible has a Settlement page linking Hearth, Stockpile and the governance rules.

---

## Phase 140 — Settlements at runtime: a hearth, a claim and a shared stockpile

**Goal:** implement the Phase 139 design on the host. A player with the `Hearth` places it to found
a settlement; the host records the claim, invites and roles, and enforces build and take rules
inside it; members share a stockpile; the technology rules that need settlement storage read it; the
colonization map counts settlements; and the map shows claim borders. This is the first system whose
point is that players need each other.

**Newel dependency:** NO.

**Depends on:** Phase 130, Phase 131, Phase 135, Phase 139.

**Deliverables:**
- `src/settlement/settlement_slice.gd` (new) and its wiring module — founding, invites, roles,
  leaving, abandonment decay; persisted in the world record; scoped syncs to members and to peers in
  range.
- `src/terrain/voxel_slice.gd`, `src/world/station_slice.gd` — host refuses a mine, place or station
  inside another settlement's claim unless the player's role allows it.
- `src/inventory/` — a stockpile container with host-authoritative deposit and withdraw, rate-limited
  and validated like other intents.
- `src/technology/technology_slice.gd` — settlement-storage research rules read the stockpile.
- `src/ui/` — found/invite/roles panel and claim borders on the map, all text through `tr()`.
- `src/tests/net_harness.gd` — a `settlement` step: the host player founds a settlement, the client
  joins and deposits, and an outsider's edit inside the claim is refused.

**Acceptance criteria:**
- [x] Suite: founding needs a `Hearth` item and free land; a claim never overlaps another; an
  outsider's mine or place inside a claim is refused by the host.
- [x] Suite: stockpile deposit/withdraw keeps item totals; a withdraw beyond a role's limit is
  refused; the settlement survives a save/load.
- [x] Suite: an abandoned settlement's claim decays on the fabric schedule.
- [x] Harness: the `settlement` step passes on loopback and under the Phase 135 `wan_bad` profile.
- [x] Suite green on both boot paths, harness green, every new string in both locale catalogs.

---

## Phase 141 — Terrain streaming off the main thread

**Goal:** a playtest showed stutter, frozen animations and lag while walking, worst near the poles.
Measured per chunk dispatch, the main thread generated the chunk's heightmap (14 ms at the equator,
36 ms by a pole) and up to eight full neighbour maps for the seam guesses (120 ms to 290 ms on a cold
window), so every dispatch of a crossing stalled 1 to 18 frames. A pole fold re-streamed the whole
window and paid that 81 times. This phase moves all of that noise to the chunk worker, generates only
the seam edges the ring reads, makes the polar math cheaper without changing a height, and bursts the
rebuild after a fold.

**Newel dependency:** NO.

**Depends on:** Phase 42, Phase 49, Phase 91, Phase 120, Phase 134.

**Deliverables:**
- `src/terrain/terrain_slice.gd` — a static generator (`heightmap_for`, `heightmap_strip_for`,
  `height_wrapped_in`, `raw_height_in`, `shape_cached`) that needs no node and takes the task's own
  noise copy (`detail_noise_copy`); `polar_ground` skips the shelf noise on ground above the shelf's
  highest point and memoises the per-row pole field (`new_polar_row`). World-gen output is unchanged, so
  `WORLDGEN_VERSION` is not bumped.
- `src/terrain/voxel_slice.gd` — `gather_build_input_deferred` lists unknown neighbours instead of
  generating them; `fill_seam_strips` gives each one, on the worker, the one-tile edge the ring reads.
- `src/terrain/chunk_manager.gd` — the dispatch generates the map, the strips, the runs and the arrays
  on the worker and applies the map it hands back; after a `restream` (a fold) the cap rises to all
  cores but one, more chunks dispatch per frame and the tasks run at high priority until the window is
  rebuilt.
- `src/tests/playtest_bot.gd` — a `pole` step: stand past the north pole, step over the fold line, and
  report the frames until the folded window is rebuilt.

**Acceptance criteria:**
- [x] Suite: `heightmap_for` equals `generate_heightmap` on the equator, mid latitudes, the ice shelf,
  the pole's snow field, past the pole and the antimeridian band.
- [x] Suite: a seam strip equals the full map on its edge and computes nothing else.
- [x] Suite: `polar_ground` with the shortcuts equals the unoptimised form; worldgen golden values
  unchanged.
- [x] Suite: a deferred gather plus seam strips builds the same mesh and collision as the full gather;
  a dispatch generates no map on the main thread.
- [x] Suite: a restream raises the build cap and the catch-up ends once nothing is queued or in flight.
- [x] Playtest bot passes with the `pole` step.
- [x] Suite green on both boot paths, harness green.

---

## Phase 142 — Terrain build throughput: a time-budgeted pump and a native chunk builder

**Goal:** Phase 141 took the stall off the main thread, but a chunk still costs a worker about 200 ms
of GDScript (resolve + mesh arrays), the steady pump dispatches one chunk per frame with four low
priority tasks in flight, and every window crossing reads its regions from disk on the main thread.
Bigger mountains (taller walls, more faces) and a wider view would make all of these worse. This phase
makes the build rate scale with the machine and moves the per-tile loops to native code, before the
world gets taller.

**Newel dependency:** NO.

**Depends on:** Phase 141.

**Deliverables:**
- `src/terrain/chunk_manager.gd` — the steady pump is budgeted by main-thread time (a few ms per
  frame for dispatch + apply), not by a count; `max_builds_in_flight` defaults to the core count minus
  one, and the apply pass is bounded per frame so a burst of finished builds cannot bunch into one
  frame.
- A native chunk builder (GDExtension, C++) for `heightmap_for`, `build_runs` and
  `build_chunk_arrays`, with the GDScript builder kept as the reference: the suite builds the same
  chunks through both and compares arrays, and the game falls back to GDScript when the extension is
  missing (the public build must stay playable without a native binary for every platform).
- `src/persistence/region_streamer.gd` — region reads for a window move go to a worker; a chunk waits
  for its regions as it does today, without blocking the frame.
- Fold contents: creatures and trees in the window survive a fold instead of being despawned and
  respawned with the rebuild.
- Optional, measured first: a compute-shader heightmap path if the native builder is still the
  bottleneck at a larger view distance.

**Acceptance criteria:**
- [ ] Suite: native and GDScript builders give equal arrays for a fixed set of chunks (equator, ice,
  pole, antimeridian, edited chunk); the GDScript fallback is used when the extension is absent.
- [ ] Suite: a frame's pump never spends over its time budget on dispatch + apply in a stubbed clock.
- [ ] Playtest bot: the `stream` step's chunk build rate at least doubles against the Phase 141 report,
  and no step reports a hitch over 50 ms.
- [ ] Suite: a region read for a window move never runs on the main thread.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 143 — Creature models: rigged, animated creatures replace the tinted box

**Goal:** every creature in the world is drawn as one tinted `BoxMesh` in a shared MultiMesh
(`CreatureSlice._build_pool`), so the public build and the README GIFs show coloured boxes for
wolves, boars and hawks. Ten rigged placeholder models already ship at
`assets/models/creatures/<Entity>.glb.raw` (skinned box rigs on the fabric skeletons, with idle,
walk, run, fall, land, attack and death clips), and `AssetOverlay.creature_model_key` names the
key, but nothing attaches them. This phase attaches a model to each creature near the camera,
drives its clips from the creature's AI and combat state, and keeps the box pool for far creatures
and for any creature without a model. It is the game-repo side of `project-nihon-assets` phases A6
(first quadruped) and A7 (creature roster): their real meshes then drop in through `assets-prod/`
with no code change.

**Newel dependency:** NO.

**Depends on:** none (the placeholder rigs exist; A6/A7 art can land before or after).

**Deliverables:**
- Fabric (separate PR, first): a `skeleton` field on the creature entity naming its family
  (`QuadrupedSkeleton`, `BirdSkeleton`, `SerpentSkeleton`, `HumanoidSkeleton`) and a value on all
  ten creatures, replacing the family assumption written in `assets/README.md`. `npm run
  generate` and `check-drift` clean.
- `src/creature/creature_visuals.gd` (new) — loads `AssetOverlay.creature_model_key(id)` through
  `load_rig_scene` once per creature type and instances it per creature, reconciling the model's
  -Z forward with the fabric `restPose` +Z head. A creature whose key is absent or fails to parse
  keeps its box, with one warning per type.
- `src/creature/creature_slice.gd` — creatures within `MODEL_RANGE_M` of the camera get a model and
  leave the box pool; beyond it, or past `MAX_MODELS`, they stay in the pool. The swap uses
  hysteresis so a creature at the edge does not flicker. Facing follows the movement direction.
  `render_visuals = false` (dedicated server, suite) builds neither.
- Animation: a small state map from each creature state-machine state (`aggressive`, `fleeing`, `dead`, ...) and
  its movement speed to the seven shared clip names, played through `RigTree` as the avatar
  does. Death plays once and holds until despawn. Clients drive clips from the synced state, so the
  wire is unchanged.
- `tools/gen_placeholder_glb.py` — placeholders stay the contract (same bones and clips per
  family). Body texture and masks are bound through the character shader as the avatar's are
  (`textures/creatures/<Entity>{,_color_mask,_channel}.png.raw`).
- `assets/README.md` — the creature section describes the attached models, not a planned attach.
- The README GIFs (`docs/media/creatures.gif`, `docs/media/walk.gif`) are re-captured once models
  render. Judging how they look is a human check, so it is filed as an issue, not a criterion.

**Acceptance criteria:**
- [x] Fabric: every creature names a `skeleton`, and `validate` rejects a creature with an unknown
  family. Generated `.tres` files carry the field.
- [x] Suite: for every creature in `GameData.CREATURES`, the public model parses, its `Skeleton3D`
  bones match the fabric skeleton of its family, and its `AnimationPlayer` has all seven clips.
- [x] Suite: a creature inside `MODEL_RANGE_M` has a model and no pool instance; outside, a pool
  instance and no model; crossing the range edge within the hysteresis band does not swap.
- [x] Suite: a creature with a missing model key renders through the pool and warns once per type.
- [x] Suite: the state-to-clip map covers every creature state, and a dead creature's clip is
  `death` and does not loop.
- [x] Suite: `MAX_MODELS` is respected with many creatures in range (the nearest get models).
- [x] Suite: no model nodes are built when `render_visuals` is false. The dedicated server boot stays
  clean.
- [x] Playtest bot: the `fight` step's screenshot is taken with the target creature drawn as a model
  (the bot asserts the creature has a model node), and no step reports a new hitch over 50 ms.
- [x] Suite green on both boot paths, harness green.

---

## Deferred (in priority order)

- **Localized fabric content** — entity names and descriptions (items, creatures, skills,
  technologies) translated through catalogs generated by Newel (`../newel/ROADMAP.md` Phase 15),
  consumed with the Phase 131 locale settings.

- **Server sharding (final, not before maturity)** — split the authoritative
  simulation across multiple servers by region / spatial partition so total
  population exceeds one process. Deferred to LAST: it is a horizontal-scaling
  concern that only pays off once a single headless server (Phase 27) plus
  spatial hashing (Phase 28) and interest management (Phase 29) are already
  saturating. No structural change is required *before* the game matures to
  make sharding possible — the Phase 27 sim/visual split and the Phase 28
  hash are the prerequisites, and both are already planned ahead of it. Revisit
  when Brazil-region load approaches one server's ceiling.

- **Rivers, lakes and fluid flow** — water above sea level and flowing water
  (the cellular-automaton idea from the GDVoxelPlayground evaluation) follow
  Phase 51's static sea level. **(falling sand and soil planned: Phase 137; water remains.)**
- **Fast travel** — a planet takes about 90 days to walk around. Some form of
  travel network (roads, boats, waystones) is needed once players spread out
  (after Phase 53). **(Phase 125 added waystones; roads and boats remain.)**
- **Voxel techniques from GDVoxelPlayground (evaluated, not adopted wholesale)** —
  <https://github.com/JorisAR/GDVoxelPlayground> (MIT) ray-marches a FIXED 128³
  voxel grid on the GPU via `RenderingDevice` compute. It does not fit Nihon,
  which has an unbounded streamed world, a headless server with no
  `RenderingDevice`, seed-deterministic CPU terrain, sparse-run columns with
  trimesh collision, and per-edit authority and persistence. Three techniques
  are worth borrowing later, each CPU-side and deterministic:
  - a **cellular automaton** for sand, water and lava, run on dirty chunks
    only;
  - **WFC** for ruins, villages and dungeons;
  - a **brick occupancy map** if meshing becomes the bottleneck.

- **Public wiki deployment** — VitePress (or equivalent) static-site deployment
  and CI-triggered wiki regeneration from the fabric (deferred from Phase 9).
- **Research cost points** — the abstract `researchCost` points field is modelled
  in the fabric but not enforced at runtime (deferred from Phase 13). **(closed: Phase 124 — `begin_research` spends `researchCost` from a host-owned balance earned by the `ResearchPointRule` table.)**
- **`VoidTouched` special-case unlock** — the void-burst survivor unlock trigger
  is defined in the fabric but not wired to any runtime event (deferred from
  Phase 13). **(closed: Phase 118 — a refining craft can burst, survivors get
  `voidBurstSurvivor`, and `ProfessionSlice` unlocks `VoidTouched`.)**
- **Station placement UI** — **(closed: placement is grid-snapped to 1 m cells and
  refuses overlap via `StationSlice.try_place_station`; N toggles a translucent
  green/red preview ghost and V places at the aimed top face or the player's feet.
  A full build-mode menu remains out of scope.)**
- **NavigationAgent3D path-finding** — creature movement currently uses direct
  kinematic stepping; replacing it with nav-mesh baked from voxel terrain and
  `NavigationAgent3D` per-instance requires the chunk-streaming world from
  Phase 17 to produce stable nav-mesh regions (deferred from Phase 15).
  **(planned: Phase 136 replaces it with a host-side grid path over voxel columns.)**
- **WAN / cross-region multiplayer testing** — all Phase 18–19 multiplayer
  validation is loopback or LAN (deferred from Phase 19). **(planned: Phase 135 runs the harness
  under emulated WAN profiles; a real cross-region run remains.)**
- **Automatic LOD mesh decimation** — simplified meshes are hand-authored;
  runtime decimation deferred from Phase 23.
- **Dynamic impostor re-bake** — impostor billboards are offline-baked; live
  palette-change re-bake deferred from Phase 23.
- **Peer damage over the wire** — a creature aggros and chases a remote peer, but
  the host opens no combat round against it: damage to a peer belongs to that
  peer's own client, and the host has no simulation of a peer's HP to hit or
  persist. Needs a host → client damage event plus per-peer HP ownership on the
  peer's side (deferred from Phase 36). **(delivered in Phase 37: the round is routed
  by target id, `player_damaged` carries the target, and the host sends the hit to the
  peer's own client. What remains is making a peer's HP authoritative rather than
  client-owned.)** **(closed in Phase 38: the host simulates the peer's HP itself and
  persists it on the peer's record. `player_damaged` stays a display update — a client
  that ignores it now diverges from the host's number instead of owning it.)**
- **Peer equipment replication** — **(closed in Phase 47: the host records each
  peer's worn set and the bare-hands rule reads it; late joiners are announced to
  their AOI, and the two-client harness step `equipment_recorded` proves the
  intent over a real socket.)**
