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
| 144 | A native chunk builder: GDExtension, CI binaries and a GDScript fallback | Merged | split into [Phase 166](docs/roadmap-history/phases-166.md)–169 |
| 145 | Fold contents: creatures and trees survive a polar fold | Done | [history](docs/roadmap-history/phases-130-145.md) |
| 146 | Roadmap close-out: archive merged phases and keep the index honest | Done | [history](docs/roadmap-history/phases-130-145.md) |
| 147 | Review follow-ups I: trust boundary and far-from-origin precision | Done | [history](docs/roadmap-history/phases-147.md) |
| 148 | Review follow-ups II: i18n leftovers | Done | [history](docs/roadmap-history/phases-148.md) |
| 149 | Review follow-ups III: world, terrain and persistence | Done | [history](docs/roadmap-history/phases-149.md) |
| 150 | Review follow-ups IV: wiring, harness and playtest bot | Done | [history](docs/roadmap-history/phases-150.md) |
| 151 | Item shapes in the fabric | Done | [history](docs/roadmap-history/phases-151.md) |
| 152 | Item models and icons from one generator | Done | [history](docs/roadmap-history/phases-152.md) |
| 153 | Items in the world: equipment, held tools and icons everywhere | Done | [history](docs/roadmap-history/phases-153.md) |
| 154 | Split the biggest slices | Done | [history](docs/roadmap-history/phases-154.md) |
| 155 | Animation tempo: looping clips, stride-matched walk and snappier transitions | Done | [history](docs/roadmap-history/phases-155.md) |
| 156 | Idle, attack and hit clips for everyone, on every swing | Done | [history](docs/roadmap-history/phases-156.md) |
| 157 | Deaths that read as deaths: a push, a fall and a body that stays | Done | [history](docs/roadmap-history/phases-157.md) |
| 158 | Gestures in the fabric: sit, lie down, wave and friends | Done | [history](docs/roadmap-history/phases-158.md) |
| 159 | Gestures at runtime: a gesture wheel, chat commands and synced poses | Done | [history](docs/roadmap-history/phases-159.md) |
| 160 | Harvesting in the fabric: tools, the Skinning skill, carcass weight and carry | Done | [history](docs/roadmap-history/phases-160.md) |
| 161 | Harvesting at runtime: work the body, carry it home | Done | [history](docs/roadmap-history/phases-161.md) |
| 162 | A crowd walks: a multi-player stress test and a bottleneck report | Done | [history](docs/roadmap-history/phases-162.md) |
| 163 | Crowd performance: fix what the Phase 162 report names | Done | [history](docs/roadmap-history/phases-163.md) |
| 164 | A round horizon: a circular distant ring, planet curvature and haze | Done | [history](docs/roadmap-history/phases-164.md) |
| 165 | Mountains on the horizon: distant bands out to the visibility limit | Done | [history](docs/roadmap-history/phases-165.md) |
| 166 | Native builder scaffold: GDExtension, loader, fallback, CI binaries and releases | Done | [history](docs/roadmap-history/phases-166.md) |
| 167 | Native `heightmap_for` | Done | [history](docs/roadmap-history/phases-167.md) |
| 168 | Native `build_runs` | Done | [history](docs/roadmap-history/phases-168.md) |
| 169 | Native `build_chunk_arrays` and the speed target | Done | [history](docs/roadmap-history/phases-169.md) |
| 170 | A compute-shader heightmap, if the native builder is still the bottleneck | Done | [history](docs/roadmap-history/phases-170.md) |
| 171 | Creatures in exact coordinates: no float32 metres far from the origin | Done | [history](docs/roadmap-history/phases-171.md) |
| 172 | Host chunk attach off the main thread | Done | [history](docs/roadmap-history/phases-172.md) |

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
