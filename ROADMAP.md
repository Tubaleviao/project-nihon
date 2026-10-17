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
| 130 | Host authority sweep: status effects, waystones and research points | Done | [history](docs/roadmap-history/phases-130-145.md) |
| 131 | Internationalization: translated UI and keyed host messages | Done | [history](docs/roadmap-history/phases-130-145.md) |
| 132 | One wiring module per system: `game_root` keeps the boot paths | Done | [history](docs/roadmap-history/phases-130-145.md) |
| 133 | The test suite splits by system and runs by filter | Done | [history](docs/roadmap-history/phases-130-145.md) |
| 134 | A bot plays: playtest report and downloadable builds | Done | [history](docs/roadmap-history/phases-130-145.md) |
| 135 | A WAN profile: latency, loss and bandwidth in the two-client harness | Done | [history](docs/roadmap-history/phases-130-145.md) |
| 136 | Creatures walk on the ground and around obstacles | Done | [history](docs/roadmap-history/phases-130-145.md) |
| 137 | Loose ground settles: sand and soil fall when undermined | Done | [history](docs/roadmap-history/phases-130-145.md) |
| 138 | Trees, generation records and persistence cleanup sweep | Done | [history](docs/roadmap-history/phases-130-145.md) |
| 139 | Settlements in the fabric: founding, membership and shared storage | Done | [history](docs/roadmap-history/phases-130-145.md) |
| 140 | Settlements at runtime: a hearth, a claim and a shared stockpile | Done | [history](docs/roadmap-history/phases-130-145.md) |
| 141 | Terrain streaming off the main thread: worker noise, seam strips, polar shortcuts, fold catch-up | Done | [history](docs/roadmap-history/phases-130-145.md) |
| 142 | Terrain build throughput: a time-budgeted pump and worker region reads | Done | [history](docs/roadmap-history/phases-130-145.md) |
| 143 | Creature models: rigged, animated creatures replace the tinted box | Done | [history](docs/roadmap-history/phases-130-145.md) |
| 144 | A native chunk builder: GDExtension, CI binaries and a GDScript fallback | Planned | below |
| 145 | Fold contents: creatures and trees survive a polar fold | Done | [history](docs/roadmap-history/phases-130-145.md) |
| 146 | Roadmap close-out: archive merged phases and keep the index honest | Done | [history](docs/roadmap-history/phases-130-145.md) |
| 147 | Review follow-ups I: trust boundary and far-from-origin precision | Planned | below |
| 148 | Review follow-ups II: i18n leftovers | Planned | below |
| 149 | Review follow-ups III: world, terrain and persistence | Planned | below |
| 150 | Review follow-ups IV: wiring, harness and playtest bot | Planned | below |
| 151 | Item shapes in the fabric | Planned | below |
| 152 | Item models and icons from one generator | Planned | below |
| 153 | Items in the world: equipment, held tools and icons everywhere | Planned | below |
| 154 | Split the biggest slices | Planned | below |

---















## Phase 144 — A native chunk builder: GDExtension, CI binaries and a GDScript fallback

**Goal:** a chunk still costs a worker about 200 ms of GDScript (resolve + mesh arrays). Bigger
mountains and a wider view make that worse. This phase moves the per-tile loops to native code
before the world gets taller, without making the public build depend on a native binary.

**Newel dependency:** NO.

**Depends on:** Phase 142.

**Deliverables:**
- `native/` — a GDExtension (C++, `godot-cpp` pinned to the project's Godot version) porting
  `heightmap_for`, `build_runs` and `build_chunk_arrays`: climate, shape, ore and biome resolve with
  bit-exact `FastNoiseLite` behaviour, and the greedy mesher with a deterministic output order (the
  GDScript reference is changed first if its order depends on dictionary iteration).
- The GDScript builder stays the reference. A loader picks the native builder when the extension
  loads and falls back to GDScript otherwise, with one log line saying which is in use.
- CI builds the extension for Linux x86_64, Windows x86_64 and macOS universal, and attaches the
  binaries to the export builds and releases. Binaries are not committed to git or LFS. A platform
  without a binary runs the GDScript fallback.
- Port order: scaffold + loader + fallback first, then one pure function at a time, each with its
  parity test, so every PR ships a working build.
- Optional, measured first: a compute-shader heightmap path if the native builder is still the
  bottleneck at a larger view distance.

**Acceptance criteria:**
- [ ] Suite: native and GDScript builders give equal arrays for a fixed set of chunks (equator, ice,
  pole, antimeridian, edited chunk); the GDScript fallback is used when the extension is absent.
- [ ] CI: the three platform binaries build, and an export without them boots on the fallback.
- [ ] Playtest bot: the `stream` step's chunk build rate with the native builder is at least double
  the GDScript fallback's on the same commit (so Phase 142's pump gains are not counted), and
  `report.json` shows no step with a hitch over 50 ms (the bot does not fail on hitches, so this is
  read from the report, not from the exit code).
- [ ] Suite green on both boot paths, harness green.

---


## Phase 147 — Review follow-ups I: trust boundary and far-from-origin precision

**Goal:** the open "Follow-ups from PR … review" issues hold items that touch the host's authority
and float32 precision. CLAUDE.md says trust-boundary findings are never deferred. This phase clears
them, so the host decides every rule and stays exact anywhere on the planet.

**Newel dependency:** NO.

**Depends on:** none.

**Deliverables** (each item is first checked against `main`; one already fixed by a later phase is
ticked on its issue with the commit that fixed it):
- #336: `WaystoneSlice.note_exact` is called from the placement path, so `exact_pos` never falls
  back to a float32 position. `MapWindow._stone_under_player` uses the player's exact world
  position. `try_attune` at `MAX_WAYSTONES` refuses before truncating, and sync fires only on a
  change. Refused travel intents are throttled per peer. Placing a station consumes its item
  (`Waystone`, `Hearth`, every station type) on the host; decide and record it as a fabric decision
  that amends `NoTeleportation`.
- #346: the knockback handler guards on `has_last_known_state`. Check that Phase 130's host-side
  hold covers immobilization, and close the item with the test that proves it.
- #374: the hearth position is rebuilt from the player's exact world position (as waystones do).
  `edit_blocker` becomes a pure query, and `_touch` runs only after a successful edit. `from_data`
  keeps `_next_id` above every loaded id and defaults a missing `last_active` to now. A change to the
  decay radius of an abandoned claim is pushed to clients.
- #380: `CreatureVisuals.reselect` and model placement use the creature's exact position (or the
  camera-relative position the terrain uses), not a float32 world `Vector3`. Creatures with no
  usable model do not count toward `max_models`. A respawn teleport does not read as run speed.
- #349: in `note_craft`, the first-craft marker is written after `_earn` grants the points.

**Acceptance criteria:**
- [ ] Suite: a waystone and a hearth placed at x ≈ 2e7 m keep their exact positions through save
  and load (error below 1 cm).
- [ ] Suite: placing any station without its item in the inventory is refused on the host, and a
  successful placement removes one item.
- [ ] Suite: `edit_blocker` called as a preview leaves `last_active` and claim state unchanged.
- [ ] Suite: with `max_models` = 2 and three creatures in range where the nearest has no model key,
  the two modellable creatures both get models.
- [ ] Suite: a creature respawn does not set its clip to `run`.
- [ ] Harness: a modified client that sends `player_moved` while held, and a station-place intent
  without the item, are both refused by the host.
- [ ] Every item of #336, #346, #349 and #374 that is in scope here is ticked on its issue.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 148 — Review follow-ups II: i18n leftovers

**Goal:** the i18n rule in the workspace CLAUDE.md says no hard-coded user-facing strings. Review
issues list several that are still there: settlement refusal strings, raw `reason` codes in the
craft, repair and research rows, the status-effect HUD line, coordinates formatted on the host, and
settlement names rendered in the host's locale. This phase moves all of them to keys and params.

**Newel dependency:** NO (item and creature *names* stay deferred under "Localized fabric content").

**Depends on:** none.

**Deliverables:**
- #374: `StationSlice.placement_blocker` returns reason codes ("inside a settlement claim", "too
  close to a settlement", "already in a settlement" become keys). A settlement's default name is
  stored as key + params and rendered on the client. Its number comes from a monotonic counter.
- #351: every `reason` code a slice can return to the UI has a catalog key in `en` and `pt_BR`.
  `UiSlice` renders the key and never the raw code. `I18n.ensure_loaded` logs one error when the
  catalog is missing or empty and stays unloaded so a later call retries. `fill` supports
  multi-digit placeholders. Chat lines carry numbers as params and the client formats them with
  its locale. Join lines are throttled per peer on reconnect.
- #346: `PlayerSlice.status_line` builds the HUD text from effect keys.
- A suite audit for hard-coded strings: no string literal is passed to a `Label.text`,
  `Button.text`, `tooltip_text` or a chat/notice emit in `src/` outside `I18n`, except entries on an
  explicit allow-list (debug-only overlays).

**Acceptance criteria:**
- [ ] Suite: every reason code returned by `placement_blocker`, the craft, repair and research paths
  and the settlement paths has a key in every locale catalog.
- [ ] Suite: with locale `pt_BR`, a chat line carrying the coordinates 1234.5 renders `1.234,5`; with
  `en`, it renders `1,234.5`.
- [ ] Suite: `fill("{10} {1}", ...)` replaces both placeholders.
- [ ] Suite: the hard-coded-string audit passes and fails on a fixture file that sets
  `label.text = "Hello"`.
- [ ] Suite: catalogs have the same key set (existing check) after the new keys.
- [ ] Every i18n item of #346, #351 and #374 is ticked on its issue.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 149 — Review follow-ups III: world, terrain and persistence

**Goal:** clear the world-side review items: settling sand that is lost on quit, flying creatures
glued to the ground, creatures stuck at the end of a partial path, tree-clear records that can drop
or hit the wrong tree, and persistence edge cases in the save journal and region streaks.

**Newel dependency:** NO.

**Depends on:** none.

**Deliverables:**
- #365: the `_settle` queue (queued and parked columns) is saved with the region and re-queued on
  load. `settle_column` and `moves` share one support walk. The client checks that the material
  is granular in `_apply_settle`.
- #363: a fabric `movement` field on creatures (`ground`, `flying`, `swimming`); flyers are not
  snapped to the surface and keep a hover band above it. `_walk_path` retries a partial path on a
  timer. The harness measures the stored and mirrored positions, not a re-set one.
- #367: tree-clear spots are held by index, not geometry, so a clear never removes a neighbour.
  Spot eviction never drops a persisted clear. `SaveTxn.commit` with `ERR_BUSY` keeps the staged
  ops. The generation fingerprint stamp keeps the original. `ends_streaks` only resets a region that
  was actually written.
- #369: `warm_polar_caches` calls `WorldShape.warm()`. The PR #368 description note about
  `WORLDGEN_VERSION` is corrected on the PR.
- #354: `_airborne` counts only while falling, so a long jump does not snap to the fall pose at
  its apex. The elbow bend follows the forward swing.

**Acceptance criteria:**
- [ ] Suite: undermine a sand column, save and quit before it settles, reload: the column finishes
  settling and nothing floats.
- [ ] Suite: a `flying` creature keeps its hover height across 100 AI ticks. A `ground` creature
  stays on the surface.
- [ ] Suite: a creature at the end of a partial path to a fixed goal retries within the retry
  interval.
- [ ] Suite: clearing one of two trees 0.2 m apart and reloading keeps the other tree.
- [ ] Suite: `ERR_BUSY` from `commit` leaves the staged ops intact for a retry.
- [ ] Suite: a jump that lasts longer than the fall threshold does not enter `fall` before its apex.
- [ ] Every in-scope item of #354, #363, #365, #367 and #369 is ticked on its issue.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 150 — Review follow-ups IV: wiring, harness and playtest bot

**Goal:** the test tools are the project's eyes. Their review items (#355, #359, #361, #380)
make them weaker than they look: the playtest bot changes slices directly instead of sending
intents, the WAN profile mutes creature sync, and the wiring audit is brittle. This phase hardens
them.

**Newel dependency:** NO.

**Depends on:** none.

**Deliverables:**
- #359: the playtest bot sends bus intents for place, craft, travel, fight and unlock, like a
  player would. Teleports land on `terrain.get_height_at` + offset, and the frame-time check skips
  the frames right after a teleport. A step's coroutine that crashes fails fast. The bot despawns
  the creature it spawns. `/build/` and `/playtest/` are anchored in `.gitignore`. CI runs a Linux
  export check on PRs.
- #380: find and fix why the player body sat about 20 km below the terrain at the fight step in the
  xvfb run. Remove the orphan section header in `creature_tests.gd`.
- #361: the harness timeout multipliers come from `NetworkingSlice.link_time_scale()`. Under
  `wan_bad`, creature deltas are throttled, not muted. `_drain_emulator` counts dropped packets
  and the harness reports the count.
- #355: `wiring.gd` gets a base `wire()` and a virtual `_connect_all()`. `connect_bus` is
  idempotent. The no-op `pass` handlers are removed. Cross-module calls to `_private` methods
  become public methods. String `Callable`s become method refs. The wiring audit globs its
  directories.

**Acceptance criteria:**
- [ ] Suite: a static check finds no direct slice mutation in `playtest_bot.gd` (calls to
  `try_place_station`, `craft`, `begin_research`, … go through the bus).
- [ ] Playtest bot: every step passes in CI, and the fight step's player is within 2 m of the terrain
  surface.
- [ ] Harness: under `wan_bad`, at least one creature delta reaches the client, and the run report
  shows the dropped-packet count.
- [ ] Suite: calling `connect_bus` twice connects each signal once.
- [ ] CI: a PR runs the Linux export.
- [ ] Every in-scope item of #355, #359, #361 and #380 is ticked on its issue.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 151 — Item shapes in the fabric

**Goal:** an item today has no description of its form. Equipment carries a placeholder `size`
box, and everything else has nothing, so icons are coloured squares and held items are boxes.
This phase gives every item a shape the generators can build from: an archetype plus the
materials it is made of. It is the fabric half of Phases 152–153 (separate PR, per CLAUDE.md).

**Newel dependency:** NO (a new field on existing entities).

**Depends on:** none.

**Deliverables:**
- `fabric/gameplay/items/shared.js` — an `itemShape({ archetype, parts, scale })` helper. The
  `archetype` comes from a closed list: `pick`, `axe`, `sword`, `longsword`, `bow`, `shield`,
  `helmet`, `chestplate`, `cloak`, `ingot`, `shard`, `dust`, `plank`, `block`, `orb`, `tablet`,
  `potion`, `rations`, `hearth`, `waystone`. `parts` maps each of the archetype's named parts
  (`head`, `handle`, `blade`, `grip`, `body`, …) to a fabric material (`Ferrite`, `Thornwood`,
  `Veilsteel`, …), so the material palette (Phase 22) colours each part. The default comes from the
  item's existing `hasOne` material relations where they exist.
- A `shape` value on all 25 items in `GameData.ITEMS` (including `Hearth` and `Waystone`).
- `validate` rejects an item with no shape, an unknown archetype, a part that is not in its
  archetype, or a material that does not exist.
- Generated `godot/items/*.gd` / `.tres` carry `shape`. `npm run generate` and `check-drift` clean.

**Acceptance criteria:**
- [ ] `pnpm validate` passes, and fails on a fixture item with archetype `spaceship` and on one
  whose `parts.blade` names a missing material.
- [ ] Every entity tagged `item` has a `shape`. A suite test reads it from `GameData` for each item.
- [ ] `check-drift` clean.

---

## Phase 152 — Item models and icons from one generator

**Goal:** turn each item's shape into a low-poly model and a 32×32 icon drawn from that same model,
so the two always match and every item has both. The output replaces today's coloured-square icons
and textured boxes as the **public placeholders**. The private repo's phases A4, A5 and A8
(`project-nihon-assets/ROADMAP.md`) then hand-polish over the same keys with no code change.

The pattern is the one `dumb_engine/tools/make_robot.py` and
`project-nihon-assets/tools/build_player_rig.py` use: every part and material built from code,
nothing hand-placed. But it runs in pure Python like `tools/gen_placeholder_glb.py`, so CI and a
fresh clone need no Blender, GPU or Rust toolchain.

**Newel dependency:** NO.

**Depends on:** Phase 151.

**Deliverables:**
- `tools/gen_item_assets.py` (new) — reads each item's `shape` from the generated item data. For
  each archetype it assembles parametric parts (boxes, bevelled prisms, cylinders, wedges, low-res
  spheres) and gives each part its material's palette colour. It writes:
  - `assets/models/items/<ItemId>.glb.raw` — one closed mesh within the `STYLE.md` held-item budget
    (≤ 300 tris), origin at the grip, with a `grip` node and a `+Z` forward axis that the equipment
    sockets read.
  - `assets/icons/items/<ItemId>.png.raw` — a software render of the same triangles: orthographic
    camera 30° down and 45° around, one sun from the top left with one highlight and one shadow band,
    a transparent background, rendered at 128×128 with a z-buffer, downsampled to 32×32 with a
    palette snap, and a 1 px outline in the darkest palette value of the dominant part.
    This follows the icon rules in `project-nihon-assets/STYLE.md`.
- Output is deterministic: the same fabric gives byte-identical files.
  `assets/models/items/shapes.lock.json` records a hash of each item's shape and palette inputs.
- `tools/gen_placeholder.py` stops writing item icons (`ITEM_IDS` removed), and
  `gen_placeholder_glb.py` stops writing `ITEM_BOXES`. One tool owns item art.
- `assets/manifest.json` lists every item model. `assets/README.md` describes the generator.
- `project-nihon-assets/ROADMAP.md` (separate PR in that repo): A4/A5/A8 note that their
  placeholders and starting renders come from this generator. `icon_rig.blend` can be the same
  camera and light, exported from these parameters.

**Acceptance criteria:**
- [ ] Every item in `GameData.ITEMS` has `models/items/<ItemId>.glb.raw` and
  `icons/items/<ItemId>.png.raw`. No orphan file exists for an id that is not an item.
- [ ] Suite: every item model parses through `AssetOverlay`, has a `grip` node, is at most 300 tris,
  and its AABB fits its archetype's bounds.
- [ ] Suite: every icon is 32×32 RGBA, its corners are transparent, it has more than 40 opaque
  pixels, and no two items share a byte-identical icon.
- [ ] CI (no Blender): `python3 tools/gen_item_assets.py --check` recomputes the shape hashes and
  fails when `shapes.lock.json` is stale, so a fabric shape change without regenerated art fails
  the build.
- [ ] Running the generator twice gives identical bytes (CI runs it into a temp dir and diffs).
- [ ] Suite green on both boot paths.

---

## Phase 153 — Items in the world: equipment, held tools and icons everywhere

**Goal:** even with item models on disk, the game never loads them. `CharacterSlice._attach_equipment`
always builds `_make_box(size, …)`, and a missing icon falls back to a text glyph. This phase draws
every worn and held item with its model, and every item slot with its icon, as Phase 143 did for
creatures.

**Newel dependency:** NO.

**Depends on:** Phase 152.

**Deliverables:**
- `AssetOverlay.item_model_key(id)` → `models/items/<ItemId>.glb.raw`. `CharacterSlice`
  loads it once per item type (cached like `CreatureVisuals._template`, off the main thread for the
  first load) and attaches it at the equipment socket by its `grip` node. RIGID, SKINNED and HYBRID
  modes keep today's socket rules. A missing or broken key keeps the box, with one warning per
  item.
- The equipment palette tint (Phase 22 `_equipment_base_index`, metal/emission channels) applies to
  the model's materials, so Primary/Secondary/Accent still work.
- Sheathed weapons hang from the hip socket using the model's long axis, not the box rotation hack.
- Remote avatars (peer equipment replication, Phase 47) show the same models.
- UI: inventory, hotbar, character window, craft/repair rows and trade windows all use
  `UiSlice.item_icon_key`. The text-glyph fallback stays only for an id with no icon key.
- Impostors and LOD (Phase 23): equipment beyond the model range stays a box or the impostor, so far
  avatars cost the same as today.
- The README GIFs are re-captured once items render (a human check, filed as an issue).

**Acceptance criteria:**
- [ ] Suite: equipping each equippable item attaches a node built from its model (not a `BoxMesh`)
  at the slot's socket, and unequipping frees it.
- [ ] Suite: an item with a missing model key attaches a box and warns once.
- [ ] Suite: a peer's worn item renders as its model on another client (harness step
  `equipment_recorded` extended to assert the model node).
- [ ] Suite: every UI surface that shows an item resolves a texture for each item in
  `GameData.ITEMS`. No glyph fallback is hit.
- [ ] Suite: no item model nodes are built when `render_visuals` is false.
- [ ] Playtest bot: the `craft` step screenshot shows the crafted tool in hand (the bot asserts the
  hand socket holds a model node), and no step reports a new hitch over 50 ms.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 154 — Split the biggest slices

**Goal:** four files hold a large share of the game: `src/terrain/voxel_slice.gd` (~3.3k lines),
`src/networking/networking_slice.gd` (~2.4k), `src/ui/ui_slice.gd` (~1.8k) and
`src/character/character_slice.gd` (~1.8k). They mix several jobs, which makes reviews slow and
merge conflicts common between the autopilot's parallel branches. Phase 132 already did this for
wiring. This phase does the same for the slices, with no change in behaviour.

**Newel dependency:** NO.

**Depends on:** Phases 147–150 (they touch the same files; split after, to avoid conflicts).

**Deliverables:**
- `voxel_slice.gd` → edit/authority, settle, mesh build and persistence modules. The slice stays the
  public facade.
- `networking_slice.gd` → transport/emulator, peer registry, intent validation and AOI/delta modules.
- `ui_slice.gd` → one module per window (inventory, crafting, research, character, map), plus a
  shared `item_rows` helper.
- `character_slice.gd` → equipment, appearance/palette and limb animation modules.
- One PR per slice. Each moves code without changing what it does, and the public API of the
  slice is unchanged.
- A suite size audit: no non-test `.gd` file under `src/` is over 1500 lines, apart from an
  explicit allow-list that this phase empties.

**Acceptance criteria:**
- [ ] The four files are each at most 1500 lines, and the size audit passes with an empty allow-list.
- [ ] The size audit fails on a fixture file over the limit.
- [ ] No test file changes except import paths (a behaviour-preserving split).
- [ ] Suite green on both boot paths, harness green, playtest bot green.

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
