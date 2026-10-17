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
| 147 | Review follow-ups I: trust boundary and far-from-origin precision | Done | [history](docs/roadmap-history/phases-147.md) |
| 148 | Review follow-ups II: i18n leftovers | Done | [history](docs/roadmap-history/phases-148.md) |
| 149 | Review follow-ups III: world, terrain and persistence | Planned | below |
| 150 | Review follow-ups IV: wiring, harness and playtest bot | Planned | below |
| 151 | Item shapes in the fabric | Planned | below |
| 152 | Item models and icons from one generator | Planned | below |
| 153 | Items in the world: equipment, held tools and icons everywhere | Planned | below |
| 154 | Split the biggest slices | Planned | below |
| 155 | Animation tempo: looping clips, stride-matched walk and snappier transitions | Planned | below |
| 156 | Idle, attack and hit clips for everyone, on every swing | Planned | below |
| 157 | Deaths that read as deaths: a push, a fall and a body that stays | Planned | below |
| 158 | Gestures in the fabric: sit, lie down, wave and friends | Planned | below |
| 159 | Gestures at runtime: a gesture wheel, chat commands and synced poses | Planned | below |
| 160 | Harvesting in the fabric: tools, the Skinning skill, carcass weight and carry | Planned | below |
| 161 | Harvesting at runtime: work the body, carry it home | Planned | below |
| 162 | A crowd walks: a multi-player stress test and a bottleneck report | Planned | below |
| 163 | Crowd performance: fix what the Phase 162 report names | Planned | below |

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

## Phase 155 — Animation tempo: looping clips, stride-matched walk and snappier transitions

**Goal:** the game looks slow, and the walk is broken. Holding a move key makes the avatar stretch
its left leg toward the move direction and glide with it held there. The cause is in the clips, not
the input: the runtime glTF import leaves every clip at `Animation.LOOP_NONE` (only `death` is set
explicitly, in `CreatureVisuals`, and nothing sets the others), and `tools/gen_placeholder_glb.py`
keys `walk` and `run` so that both the first and last keys are "left leg forward". So one stride
plays, the clip stops on its last key, and the body slides with the left leg out. The same happens
to `idle`, `run` and `fall`, and to every creature model from Phase 143. This phase fixes the loop,
matches the stride to the ground speed and tightens the timings so movement reads as quick.

**Newel dependency:** NO.

**Depends on:** none.

**Deliverables:**
- One place sets clip loop modes for every rig, player and creature: `RigTree.prepare_library(player)`
  (new), called by `CharacterSlice.attach_rig` and `CreatureVisuals._template`. `idle`, `walk`,
  `run` and `fall` get `LOOP_LINEAR`; `land`, `attack`, `death` and any one-shot clip (Phases
  156–159) get `LOOP_NONE`. The loop table lives in `RigTree` next to `node_for_state`, so a new clip
  must be listed there.
- Stride-matched playback: the locomotion blend space plays at a time scale of
  `ground_speed / clip_stride_m`, where each clip's stride length (metres per cycle) is a constant
  in `RigTree` (and a per-creature value read from the creature model, defaulting by skeleton). Feet
  stop sliding, and a faster character visibly steps faster instead of gliding.
- `RigTree.drive` stops calling `travel()` on every tick when the node has not changed (the
  creature path already does this). Re-travelling to the same node restarts nothing today, but the
  call is per frame per avatar and hides real transition bugs.
- Transition cross-fades: each state machine transition gets an explicit `xfade_time` (locomotion
  0.12 s, into attack 0.05 s, into death 0.08 s, out of land 0.1 s), instead of the engine default
  of 0, which pops between poses.
- Tempo pass: `Locomotion.ATTACK_DURATION` matches the attack clip length (one source: the clip's
  length when a rig is attached, the constant otherwise), `LAND_DURATION` drops to 0.18 s, and the
  creature speed smoothing (`lerpf(..., delta * 8.0)`) is raised so a creature stops and starts
  without a visible lag. The procedural box-body walk (`ANIM_FREQ`) uses the same stride constant
  as the rig, so both paths step at the same rate.
- `tools/gen_placeholder_glb.py`: the `walk`/`run` clips (player and every creature gait) are keyed
  as one closed cycle (the last key equals the first, and the clip length equals that key time), so
  a looped clip has no hitch at the seam. The private repo's `build_player_rig.py` gets the same
  rule (separate PR in `project-nihon-assets`).

**Acceptance criteria:**
- [ ] Suite: after `attach_rig`, the player rig's `idle`, `walk`, `run` and `fall` clips are
  `LOOP_LINEAR` and `land`, `attack` and `death` are `LOOP_NONE`. Same for every creature model in
  `assets/manifest.json`.
- [ ] Suite: a test that advances an `AnimationPlayer` on the `walk` clip by 3 clip lengths (by
  `advance()`, no frames) reads `Leg_L`'s pose at three different phases and gets three different
  rotations (fails today: the clip holds its last key).
- [ ] Suite: every placeholder loop clip's last key equals its first, for every joint
  (`gen_placeholder_glb.py --check` in CI).
- [ ] Suite: at walk speed and at run speed, the blend space time scale times the clip stride equals
  the ground speed within 5%.
- [ ] Suite: `RigTree.drive` called twice with the same state issues one `travel()` (counted with a
  fake playback object).
- [ ] Suite: every transition in `build_tree` has a non-zero `xfade_time`.
- [ ] Playtest bot: the `walk` step records the left and right foot heights over 2 s of held
  movement and asserts each foot spends between 30% and 70% of the time in front of the other
  (fails today: the left foot is in front almost the whole time).
- [ ] Suite green on both boot paths.

---

## Phase 156 — Idle, attack and hit clips for everyone, on every swing

**Goal:** an avatar standing still looks frozen, and an attack shows no motion. The `idle` clip moves
the chest and arms by 2–5°, which is invisible at game distance. The `attack` clip exists, but
`CombatWiring` triggers it only for the local player and only when a combat round is *requested*,
so remote players and creatures never swing, and repeated hits in one round do not swing again. This
phase gives every body a visible idle, a swing on every hit and a flinch when hit.

**Newel dependency:** NO.

**Depends on:** Phase 155.

**Deliverables:**
- Idle: the placeholder `idle` clip becomes a visible breathing and weight-shift loop (chest ±6°,
  hips sway, head turn, about 3 s), plus one or two idle variants (`idle_look`, `idle_stretch`) that
  play once after the body has been idle for 6–12 s (a seeded random from the instance id, so tests
  are deterministic). Creature skeletons get the same treatment: quadruped head bob and tail sway,
  bird preen, serpent coil.
- Attack on every swing: the host's per-hit combat event (`combat_resolved` or the hit event it
  already broadcasts) drives the attacker's attack animation for **any** attacker id — the local
  player, a remote peer's avatar and a creature model. Remote clients get it from the existing
  synced combat result, so no new wire message is needed if the result already carries the attacker;
  otherwise one compact field is added and validated on the host.
- Attack variants by what is held: `attack_unarmed` (punch), `attack_1h` (overhead/side swing,
  alternating), `attack_tool` (the same swing used for mining and gathering, so `mine` and `gather`
  also animate). The variant is picked from the main-hand equipment category; a missing clip falls
  back to `attack` (the existing warn-once rule).
- Hit reaction: `hit` (a short flinch, 0.25 s, additive over locomotion through a OneShot node) on
  `player_damaged` and on creature damage. Knockback and stagger (Phase 129) play a longer `stagger`
  clip.
- Placeholder clips for all of the above in `tools/gen_placeholder_glb.py` (player and every
  creature skeleton), listed in `assets/manifest.json`. The private repo gets matching keys (Placeholder
  rule, separate PR in `project-nihon-assets`).

**Acceptance criteria:**
- [ ] Suite: a creature's hit on the player plays `attack*` on that creature's model and `hit` on
  the player rig (read from the tree's playback / OneShot state after the bus event, no frames).
- [ ] Suite: a remote peer's attack, delivered as the synced combat result, plays an attack clip on
  that peer's avatar on another client (harness step `peer_attack_animated`).
- [ ] Suite: three hits in one round trigger three attack one-shots (fails today: one).
- [ ] Suite: the attack variant follows the main hand: empty → `attack_unarmed`, a sword →
  `attack_1h`, a pick → `attack_tool`; mining a block also triggers `attack_tool`.
- [ ] Suite: the idle variant plays after the seeded delay and never while moving.
- [ ] Suite: every rig in the manifest has `idle`, `hit` and at least one attack clip, and every
  placeholder clip's peak joint rotation is at least 10° (so a clip cannot be "present but
  invisible").
- [ ] Suite green on both boot paths, harness green.

---

## Phase 157 — Deaths that read as deaths: a push, a fall and a body that stays

**Goal:** when a creature or a player dies, it lies down calmly, as if going to sleep. A death should
look like the hit that caused it: the body is thrown back a little from the killer, falls, and
settles. The body should also stay in the world long enough to be harvested (Phase 161), instead of
vanishing after `CORPSE_SECONDS` (8 s).

**Newel dependency:** NO.

**Depends on:** Phase 155. Uses Phase 129's knockback helper.

**Deliverables:**
- Host-decided death push: when the host resolves a killing blow it computes a short throw
  (0.5–1.5 m, scaled by the killing hit's damage relative to max HP and by the attacker/target
  size ratio) away from the killer, landing on a walkable spot found by
  `StatusEffects.knockback_target`. The landing position is part of the death event
  (`creature_died` / `player_died` gain `landing: Vector3` — the host value, never the client's).
  The body's authoritative position becomes the landing spot.
- Client-side fall: the visual body travels from its position to `landing` over about 0.35 s on a
  short arc (no physics ragdoll, so the headless server stays deterministic), while the death clip
  plays. Two or more death variants per skeleton, picked by the hit direction relative to the
  body's facing: `death_back` (thrown backwards), `death_forward` (falls on its face), `death_side`.
  A missing variant falls back to `death`.
- The death clip ends in a pose that lies on the ground (the rig's lowest point at ground height
  within 5 cm), so a corpse does not float or sink.
- Corpse lifetime: creature corpses stay until harvested or until `corpseSeconds` (fabric value,
  Phase 160) elapses, instead of the hard-coded 8 s. Until Phase 161 lands, the old loot drop still
  happens on death, so nothing is lost in between.
- Player death uses the same push and variants. Respawn resets the rig as today.

**Acceptance criteria:**
- [ ] Suite: a killing blow from the west puts the creature's landing spot east of where it stood, at
  a distance in [0.5, 1.5] m, on a walkable tile; a killing blow against a wall lands it short of the
  wall (never inside a solid voxel).
- [ ] Suite: the landing spot is computed on the host only. A client-reported landing in a
  `creature_died`-shaped message is ignored (trust boundary).
- [ ] Suite: a hit from behind the target picks `death_forward`, from the front `death_back`, from
  the side `death_side`.
- [ ] Suite: after the death clip's last key, the lowest bone of every placeholder rig is within
  5 cm of the ground plane.
- [ ] Harness: a creature killed on the host lands at the same `landing` position on the client.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 158 — Gestures in the fabric: sit, lie down, wave and friends

**Goal:** players cannot sit, lie down or make any gesture, so a group of players standing together
looks like mannequins. This phase models gestures in the fabric so the list, their rules and their
animation names have one source. It is the fabric half of Phase 159 (separate PR, per CLAUDE.md).

**Newel dependency:** NO (new entities with existing field types).

**Depends on:** none.

**Deliverables:**
- `fabric/gameplay/gestures.js` (new) — a `Gesture` entity per gesture: `Sit`, `SitGround`,
  `LieDown`, `Wave`, `Point`, `Bow`, `Cheer`, `Shrug`, `Clap`, `Kneel`. Fields: `clip` (rig clip
  name), `kind` (`pose`: held until cancelled, or `oneShot`), `cancelOnMove` and `cancelOnDamage`
  (bool), `requiresGround` (bool), `restRegen` (a multiplier for HP/stamina regeneration while held,
  1.0 for none; sitting and lying give a small bonus, which makes them useful as well as social),
  `chatCommand` (`/sit`, `/lie`, `/wave`, …), and a translation key for its name.
- `validate` rejects a gesture with an unknown `kind`, a duplicate `chatCommand`, or a
  `restRegen` below 1.0.
- Generated `godot/` resources carry the gestures. `npm run generate` and `check-drift` are clean.
- `locale/` catalogs: the gesture names in `en` and `pt_BR`.

**Acceptance criteria:**
- [ ] `pnpm validate` passes, and fails on a fixture gesture with `kind: 'dance-party'` and on two
  gestures sharing `/sit`.
- [ ] Suite: `GameData` lists every gesture with its clip and chat command.
- [ ] Suite: every gesture name key exists in both the `en` and `pt_BR` catalogs.
- [ ] `check-drift` clean.

---

## Phase 159 — Gestures at runtime: a gesture wheel, chat commands and synced poses

**Goal:** play the Phase 158 gestures in game, for the local player and as seen by everyone nearby.

**Newel dependency:** NO.

**Depends on:** Phases 155, 158.

**Deliverables:**
- `src/character/gesture_slice.gd` (new) with `gesture_wiring.gd`: a `gesture_intent(gesture_id)`
  goes to the host, which validates it (known id, the player alive, grounded when `requiresGround`,
  rate-limited like chat) and broadcasts `gesture_synced(player_id, gesture_id)` to the player's
  AOI. A late joiner sees a held pose (sitting players stay seated).
- Cancel rules from the fabric: moving cancels a `cancelOnMove` pose (the stand-up plays as a
  0.3 s transition, not a pop), damage cancels a `cancelOnDamage` pose, death cancels everything.
  Cancellation is decided on the host and synced.
- `restRegen` applies on the host while a pose is held.
- Input: a gesture wheel on a key (default `G`, rebindable) built from the fabric list, and the
  `chatCommand` of each gesture in chat (`/sit`, `/wave`, …) through `ChatCommands`. All labels
  through `tr()`.
- Rig: `RigTree` gets a `Gesture` node (pose loops, one-shots return to locomotion). Sitting on a
  placed station or block edge snaps to its top face (sit height read from the target), otherwise
  sits on the ground.
- Placeholder clips for every gesture on the player rig in `tools/gen_placeholder_glb.py`, keyed in
  the manifest, and matching keys in the private repo (separate PR).

**Acceptance criteria:**
- [ ] Suite: a `/sit` from the local player plays `sit` on the rig; a movement intent afterwards
  cancels it and returns to locomotion.
- [ ] Suite: the host refuses an unknown gesture id, a gesture from a dead player and gestures over
  the rate limit (trust boundary), and a client cannot cancel another player's pose.
- [ ] Suite: a damage event cancels `LieDown` and does not cancel `Wave` if the fabric says so.
- [ ] Suite: HP regeneration while `Sit` is held equals the base rate times `restRegen`.
- [ ] Harness step `gesture_synced`: a peer's `/sit` is seen seated on the other client, and a
  client that joins afterwards also sees it seated.
- [ ] Suite: every gesture in `GameData` has a clip on the placeholder player rig.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 160 — Harvesting in the fabric: tools, the Skinning skill, carcass weight and carry

**Goal:** today a dead creature drops its finished resources at once (`LootSlice._on_creature_died`
rolls the `drops` table). It should be a body that a player works: a skinning knife takes the pelt
and meat, a hammer or bone saw takes the bones, and a better skinner gets more and better material.
A player without the tool can carry the body somewhere else, if it is light enough for them. This
phase models all of that in the fabric. It is the fabric half of Phase 161 (separate PR, per
CLAUDE.md).

**Newel dependency:** NO (new fields and entities with existing types).

**Depends on:** none.

**Deliverables:**
- Harvest tables replace drop tables: each creature's `drops` entry gains a `tool` (a harvest tool
  category: `knife`, `bonetool`, `none` for things picked straight off the body, like feathers) and
  a `skill` (`Skinning` for all of today's creatures). Quantity becomes skill-scaled: `minQty` at
  level 0 rising to `maxQty` at the cap, with `chance` also rising with level. The loot docs and the
  wiki describe the new table.
- Items: `SkinningKnife` and `BoneSaw` (with recipes and technology gates that fit the existing
  tree), each with a `harvestTool` category. Existing tools may also qualify (an axe as a poor
  `bonetool`) through an `efficiency` value below 1.0.
- A `Skinning` skill (new `fabric/gameplay/skills/survival.js`, or in `exploration.js`): levels,
  the XP a harvest grants, and the bonus per level. The skill entity says how level maps to yield and
  quality.
- Resource quality: raw creature materials (`*_hide`, `*_pelt`, `*_meat`, `*_bone`, …) get a
  `quality` grade (`poor`, `common`, `fine`, `prime`) chosen by Skinning level and tool efficiency.
  The grade is item data (an instance property, like durability), not a new item id per grade, so
  recipes keep working. Where a recipe should care about grade, that is a later phase.
- Carcass and carry: each creature gets `carcassMassKg` and `corpseSeconds`. The player gets a
  `carryCapacityKg` (base value in `fabric/gameplay/player.js`). There is no strength attribute yet,
  so capacity is a fixed base plus a bonus from a skill or worn gear (a pack frame or yoke item, to be
  decided in the PR). Carrying a body over half the capacity slows walking. Bodies over the capacity
  can be dragged (slower) or not moved at all (bison, large void creatures), as the fabric says per
  creature.
- `validate` rejects a harvest entry whose tool category no item provides, a creature without
  `carcassMassKg`, and a quality table that does not cover every level.
- Generated resources updated. `npm run generate` and `check-drift` are clean.

**Acceptance criteria:**
- [ ] `pnpm validate` passes, and fails on a fixture harvest entry with `tool: 'spoon'` and on a
  creature without `carcassMassKg`.
- [ ] Suite: `GameData` lists, for each creature, its harvest entries with tool and skill; every
  creature that had a drop table keeps at least the same items.
- [ ] Suite: `SkinningKnife` and `BoneSaw` exist, are craftable and carry their `harvestTool`.
- [ ] Suite: the Skinning yield and quality tables are monotonic in level (a higher level never
  gives less).
- [ ] `check-drift` clean.

---

## Phase 161 — Harvesting at runtime: work the body, carry it home

**Goal:** turn the Phase 160 model into play. A kill leaves a body. The player harvests it with the
right tool, gets yields and quality from their Skinning level, or picks the body up and carries it.

**Newel dependency:** NO.

**Depends on:** Phases 156 (the tool swing), 157 (the body stays), 160.

**Deliverables:**
- `src/loot/carcass_slice.gd` (new) with wiring: on `creature_died` the host creates a carcass
  record (creature type, landing position, the remaining harvest entries, owner/killer, expiry from
  `corpseSeconds`) instead of rolling the drop table. Carcasses are host-owned, synced to the AOI,
  bounded per region (oldest decays first) and saved with the region so a body left at the camp
  survives a restart until it expires.
- Harvest: `harvest_intent(carcass_id)` checked on the host — in range, the player's main hand
  provides a tool category that some remaining entry needs (no tool → only `none` entries). A timed
  action (the `attack_tool` or a `harvest` kneel clip loops while it runs, cancelled by moving or
  damage). On completion the host rolls quantity and quality from the player's Skinning level and
  the tool's efficiency, puts the items in the inventory (or on the ground when full), removes those
  entries from the carcass, uses tool durability, and grants Skinning XP. A carcass with nothing left
  is removed.
- A minimal per-player skill level store for Skinning (host-owned, persisted on the player record).
  If a general skill-progression system lands first, this uses it instead.
- Carry: `carry_intent(carcass_id)` succeeds when `carcassMassKg` is within the player's
  `carryCapacityKg` (or drag rules allow it). While carrying, the body is attached to a back or
  shoulder socket (or dragged behind for drag), the player cannot attack or harvest, walk speed is
  reduced per the fabric, a `carry` locomotion layer plays, and `drop_intent` places the body where
  the player stands. Death drops the body. The host owns the carcass position at all times.
- UI: the carcass shows a prompt with what can be harvested with the current tool and what is
  missing ("needs a knife"), all through `tr()` in `en` and `pt_BR`.
- `LootSlice` keeps spawning world pickups for player-dropped items. Its death path goes away.
- The playtest bot's `fight` step is extended: kill, harvest with a knife, check the inventory.

**Acceptance criteria:**
- [ ] Suite: a kill creates a carcass and no immediate pickups.
- [ ] Suite: harvesting with a knife yields the knife entries only; the bone entries stay until a
  `bonetool` harvests them; with an empty hand only `none` entries come out.
- [ ] Suite: at Skinning 0 and at the cap, the same seeded harvest gives the table's min and max
  quantity and the lowest and highest grade; harvesting grants XP and wears the tool.
- [ ] Suite: the host refuses a harvest out of range, with a tool the player does not hold, on a
  carcass that is already empty, and a carry over capacity (trust boundary).
- [ ] Suite: carrying sets the walk speed multiplier from the fabric, blocks attack and harvest, and
  dropping the carcass places it at the player's position; dying while carrying drops it.
- [ ] Suite: a carcass expires after `corpseSeconds`, and a region saved with a carcass restores it.
- [ ] Harness step `carcass_synced`: a carcass harvested on the host loses those entries on the
  client, and a carried carcass follows the carrier on the other client.
- [ ] Playtest bot: the `fight` step ends with the harvested items in the inventory.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 162 — A crowd walks: a multi-player stress test and a bottleneck report

**Goal:** every multiplayer gate runs one host and one client (Phase 39 harness, Phase 135 WAN
profiles), and the playtest bot (Phase 134) plays alone. Nothing tells us what happens when 16, 64 or
200 players walk around the same world: how long a host tick takes, how many bytes each peer gets,
whether chunk streaming, AOI relays, peer windows or region reads fall behind, or what a client pays to
draw a crowd. This phase adds a stress run that connects many scripted players over real sockets, walks
them in fixed patterns, measures the host and a watching client, and writes a report that ranks the
bottlenecks. The report is the input to Phase 163. Thresholds are a report, not a gate, except for hard
failures.

**Newel dependency:** NO.

**Depends on:** Phase 119, Phase 134, Phase 135, Phase 142.

**Deliverables:**
- `src/tests/stress_bots.gd` (new) — `--stress-bots <n>` user arg boots one headless process that
  opens `n` light bot connections to a host (each its own ENet peer and player identity, no terrain,
  no rendering, no slices beyond what the wire needs). Every bot sends the same movement intents and
  position claims a real client sends, at the client's real rate, and answers what the host expects
  of a client (window claims, acks), so the host cannot tell a bot from a player.
- Walk patterns, seeded and repeatable: `cluster` (all bots inside one AOI around a shared spawn),
  `spread` (bots walk away from spawn in different directions, each streaming its own window),
  `cross` (bots repeatedly cross AOI cells and chunk borders), `pole` (a group walks across a polar
  fold), and `churn` (bots join and leave every few seconds).
- Host metrics, sampled per tick: tick time p50/p95/p99/max split by phase (networking poll, AOI and
  relays, peer windows, creature AI, chunk records and region streaming, save), peers per AOI cell,
  bytes and packets sent and received per peer per second, ENet queue depth, chunks dispatched and
  waiting, region reads, memory and node count.
- Watcher metrics: one full headless client (`--net-harness client` with a `--stress-watch` flag)
  stands inside the crowd and records frame time, remote avatars shown, bytes received, apply time of
  position relays and how far a relayed position lags the host.
- `tools/stress.sh` (new) — boots a dedicated server, the bot process and the watcher; runs each
  pattern at a ladder of crowd sizes (16, 32, 64, 128, 200) under `lan` and `wan_br`; stops a step
  early when the host tick p95 passes a ceiling, and records the size where it happened.
- `stress/report.json` and `stress/report.md` — per pattern and size the metrics above, the largest
  size that met the budgets (host tick p95 ≤ 16 ms, ≤ 64 kbit/s down per peer, watcher frame p95 ≤
  33 ms, relay lag ≤ 250 ms), and a ranked list of the hot spots: the tick phase whose cost grows
  fastest with the crowd and the message types that take the most bytes.
- `.github/workflows/ci.yml` — a `stress` job (main pushes and manual dispatch, not every PR) runs the
  ladder up to 64 and uploads `stress/`; a manual run can pass a bigger ceiling.
- A short note in `README.md` Testing on running the stress test locally.

**Acceptance criteria:**
- [ ] Suite: the report builder computes percentiles, per-phase tick shares and the per-peer byte
  rate correctly from a fixed sample list; the hot-spot ranking orders a fixed set of growth curves
  correctly; the largest passing size is the last size that met every budget.
- [ ] Suite: a bot's intents and claims pass the host's validation and rate limits unchanged (the
  same checks a real client's do), and a bot that sends a malformed claim is refused like a client.
- [ ] Suite: two runs of a pattern with the same seed give the same bot paths.
- [ ] CI: the `stress` job runs every pattern up to 64 bots under `lan`, uploads `report.json` and
  `report.md`, and fails only on a hard failure (crash, a host or watcher frame over 2 s, a bot
  dropped by the host without a reason, an orphaned peer record after `churn`).
- [ ] CI: the report names a largest passing size per pattern and at least the top three hot spots.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 163 — Crowd performance: fix what the Phase 162 report names

**Goal:** make the crowd sizes from Phase 162 cheaper. This phase is written before the measurements,
so its deliverables are the hot spots the Phase 162 report ranks, worked top-down; the candidates below
are what the code suggests today and are dropped or reordered when the report disagrees. The PR body
records the report before and after each fix, so every change is justified by a number.

**Newel dependency:** NO.

**Depends on:** Phase 162.

**Deliverables:**
- A `docs/perf/crowd-baseline.md` page: the Phase 162 report that this phase starts from (sizes, tick
  phases, bytes per message type), committed so later runs have a fixed comparison.
- Fixes for the top hot spots, each with a suite test that pins the cost it removed. Likely candidates:
  - position relays: send only what changed, at a rate that drops with distance inside the AOI, and
    batch every relay for one peer into one packet per tick instead of one per subject;
  - AOI work: update a peer's AOI set when it changes cell, not every tick; keep per-cell subscriber
    lists so a relay does not scan every peer;
  - peer windows and region reads: share the window work for peers that stand in the same chunks,
    so a cluster of players costs closer to one window than to n;
  - creature AI and syncs: tick creatures near players, sleep the rest, and share path searches for
    creatures chasing the same target;
  - the watcher: pool remote avatars, cut their animation and nameplate cost by distance, and apply
    relays in one pass per frame.
- `tools/stress.sh` budgets move into one table, and CI fails when the largest passing size of any
  pattern drops below the size recorded in the baseline.
- `README.md` Testing: the crowd size the host supports today.

**Acceptance criteria:**
- [ ] CI `stress` job: under `lan`, the `cluster` and `cross` patterns meet every budget at 64 bots,
  and no pattern's largest passing size is lower than in the baseline.
- [ ] CI `stress` job: host tick p95 at 64 bots in `cluster` is at most half the baseline's, and
  bytes down per peer in `cluster` at 64 bots is at most 60% of the baseline's.
- [ ] Suite: each fix has a test that proves its saving on a fixed input (relays per tick, AOI
  scans per tick, windows built per tick, creatures ticked per tick), and the existing sync, AOI and
  creature tests stay green.
- [ ] Suite: a relay batch decodes to the same positions as the per-subject relays; a distant peer
  in the AOI still gets a relay at least once per second.
- [ ] Harness green on loopback and under `wan_bad`; suite green on both boot paths.

---

## Deferred (in priority order)

- **Character attributes (strength and friends)** — Phase 160 gives carry capacity a fixed base plus
  gear/skill bonuses because there is no attribute system. A strength attribute that feeds carry
  capacity, drag rules and melee knockback would replace that base.
- **Physics ragdolls** — Phase 157 animates deaths with a host-chosen landing spot and authored
  clips, so the headless server stays deterministic. A client-only ragdoll blend on top of that is a
  later polish.

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
