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
| 144 | A native chunk builder: GDExtension, CI binaries and a GDScript fallback | Merged | split into [Phase 166](#phase-166--native-builder-scaffold-gdextension-loader-fallback-ci-binaries-and-releases)–169 |
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
| 156 | Idle, attack and hit clips for everyone, on every swing | Planned | below |
| 157 | Deaths that read as deaths: a push, a fall and a body that stays | Planned | below |
| 158 | Gestures in the fabric: sit, lie down, wave and friends | Planned | below |
| 159 | Gestures at runtime: a gesture wheel, chat commands and synced poses | Planned | below |
| 160 | Harvesting in the fabric: tools, the Skinning skill, carcass weight and carry | Planned | below |
| 161 | Harvesting at runtime: work the body, carry it home | Planned | below |
| 162 | A crowd walks: a multi-player stress test and a bottleneck report | Planned | below |
| 163 | Crowd performance: fix what the Phase 162 report names | Planned | below |
| 164 | A round horizon: a circular distant ring, planet curvature and haze | Planned | below |
| 165 | Mountains on the horizon: distant bands out to the visibility limit | Planned | below |
| 166 | Native builder scaffold: GDExtension, loader, fallback, CI binaries and releases | Planned | below |
| 167 | Native `heightmap_for` | Planned | below |
| 168 | Native `build_runs` | Planned | below |
| 169 | Native `build_chunk_arrays` and the speed target | Planned | below |
| 170 | A compute-shader heightmap, if the native builder is still the bottleneck | Planned | below |
| 171 | Creatures in exact coordinates: no float32 metres far from the origin | Planned | below |

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
- Attack on every swing: the host's per-hit combat event (today `GameBus.combat_round_resolved`
  carries one result per round, so a per-hit signal such as `combat_hit_resolved` is added to
  `src/core/bus.gd` in this phase) drives the attacker's attack animation for **any** attacker id — the local
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

**Depends on:** Phase 155. Uses Phase 129's knockback helper. Reads `corpseSeconds` from Phase 160
when it has landed; until then the corpse lifetime stays the `CORPSE_SECONDS` constant.

**Deliverables:**
- Host-decided death push: when the host resolves a killing blow it computes a short throw
  (0.5–1.5 m, scaled by the killing hit's damage relative to max HP and by the attacker/target
  size ratio) away from the killer, landing on a walkable spot found by
  `StatusEffects.knockback_target`. The landing position is part of the death event
  (`creature_died` / `player_died` gain `landing: Vector3` — the host value, never the client's).
  The body's authoritative position becomes the landing spot.
  The signature change touches every existing listener, updated in this phase:
  `CreatureSlice._on_creature_died`, `CreatureAI._on_creature_died`, `LootSlice._on_creature_died`,
  `CombatWiring._on_player_died` / `_on_status_player_died`, the emitters in
  `BattleSlice` and `PlayerSlice._die`, and the suite tests that emit either signal.
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

## Phase 164 — A round horizon: a circular distant ring, planet curvature and haze

**Goal:** a playtest showed four "mountains" on the horizon of the flat spawn plain. They are the
corners of the Phase 51 distant ring: it is a square (`RING_FACTOR` × the voxel window, about 1.1 km
half-extent at the default view distance), so its outer edge is about 1.4 times farther at a corner
than at a side, and from eye height the farther edge sits closer to the eye line and reads as a peak.
Past the edge the sky colour (`BG_COLOR`) fills the gap. The world is a planet, so the horizon should
be a level circle where the curved ground drops out of sight, with no mesh edge anywhere in view.
This phase makes the ring round, bends it with the planet and fades the distance into a haze that
matches the sky at the horizon. It changes rendering only: no world-gen output, no collision, no
server work.

**Newel dependency:** NO.

**Depends on:** Phase 51 (distant ring), Phase 63 (scene rebase), Phase 120 (ring build lifecycle).

**Deliverables:**
- `src/terrain/horizon.gd` (new, pure static): planet radius from `circumference_m` (R = C / 2π,
  about 6,366 km), `curvature_drop(d)` = d² / 2R, `horizon_distance(eye_h)` = √(2R·eye_h + eye_h²),
  and `visible_over_horizon(eye_h, target_h, d)` (a target of height h is in view while
  d < horizon_distance(eye_h) + horizon_distance(h)). Used by the ring, the suite and Phase 165.
- `src/terrain/distant_terrain.gd` — the lattice becomes polar: rings of cells whose radial step
  grows with distance from the centre, out to an outer RADIUS (a circle), with the square voxel
  window still cut out exactly as today (clipped strips and skirt kept). The outer radius is at
  least the horizon distance for the camera's eye height, so the silhouette is always the curved
  ground, never the mesh edge. Vertex count stays within today's budget (≤ 1.5 × the current mesh).
- Ring material: a `ShaderMaterial` that lowers each vertex by `curvature_drop` of its horizontal
  distance to the camera (vertex shader, so the ring needs no rebuild when the camera moves), with
  vertex colours as today. The voxel window is not bent: at its edge (≈ 112 m) the drop is ≈ 1 mm.
- `src/core/game_root.gd` — the environment switches from a flat `BG_COLOR` to a sky
  (`ProceduralSkyMaterial` or a small sky shader) whose horizon and ground colours equal the haze
  colour, plus depth fog with aerial perspective so the far ring fades into that colour. The weather
  (`weather_wiring.gd`) keeps driving fog density on top of a clear-weather base, and the day/night
  sun keeps driving the sky and haze colours together so they never disagree.
- `src/player/player_slice.gd` — the camera's `far` is set from the ring's outer radius (with a
  margin) instead of Godot's 4,000 m default.

**Acceptance criteria:**
- [ ] Suite: `horizon.gd` — `curvature_drop` at 1 km, 10 km and 100 km and `horizon_distance` at
  1.7 m, 10 m and 500 m match the closed forms for the default circumference, and the
  `visible_over_horizon` boundary sits where the two distances sum.
- [ ] Suite: a built ring's outer silhouette is a circle: the horizontal distance of every outermost
  vertex from the ring centre is within one outer cell of the radius in every direction (the four
  corners of the old square are gone), and no vertex lies beyond it.
- [ ] Suite: the outer radius is at least `horizon_distance` for the player's eye height at the
  default and the maximum camera distance, and the camera's `far` is at least that radius.
- [ ] Suite: the ring still leaves the voxel window's hole exact (the existing clip and skirt tests
  pass on the polar lattice), carries no collision body, and the vertex count is within budget.
- [ ] Suite: the ring shader's drop equals `curvature_drop` (the shader constant is read from
  `horizon.gd`, not duplicated), and the sky's horizon colour equals the fog colour at noon, dusk
  and night.
- [ ] Playtest bot: a `horizon` step faces open sea from the nearest coast in four headings and
  finds the skyline (the first non-sky row per column) flat to within 2 px across the frame.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 165 — Mountains on the horizon: distant bands out to the visibility limit

**Goal:** a mountain should be seen from far away, as on Earth: a 500 m peak clears the horizon of
a player standing on the plain from about 80 km. Phase 164's ring ends near the eye-height horizon
(a few km), and the large-scale shape already has 400 m ridges (Phase 51, `ridgeAmplitude`), so
anything tall beyond a few km is cut off today. This phase adds coarser bands outside the ring, out
to the distance where the tallest terrain can still clear the horizon, so ranges rise over the
curved ground from far away and stay put as the player walks. Taller and more varied mountains
come in their own world-gen phases; this one makes whatever the shape holds visible from afar.

**Newel dependency:** NO.

**Depends on:** Phase 164.

**Deliverables:**
- `src/terrain/distant_terrain.gd` (or a new `distant_bands.gd` beside it) — nested circular bands
  in the clipmap style: each band's cell is a multiple of the one inside it and it re-centres only
  when the player moves a whole cell of that band, so the far bands rebuild rarely. The outermost
  radius is `horizon_distance(eye_h) + horizon_distance(WorldShape.max_height())` (≈ 85 km at the
  default 512 m), from `horizon.gd`. Bands beyond the near ring sample `WorldShape` only (no detail
  noise) and keep peaks: a band vertex takes the highest shape height in its cell, so a ridge never
  vanishes between two samples.
- Recorded chunks keep winning where they exist (the ring's `ChunkRecords` snapshot is used for the
  near band; far bands read the plain shape, as `DistantTerrain` does today for unrecorded land).
- The bands wrap at the antimeridian and fold over the poles like the ring (`seam_wrap.gd`), and
  every build runs on a worker with the Phase 120 request lifecycle; a band swap never blocks a
  frame.
- Colours: rock and snow by altitude as today, so far ranges read as rock and white caps through
  the Phase 164 haze; the bands use the same curvature shader as the ring.
- Camera `far` follows the outermost radius; depth precision is checked at that range (Godot 4's
  reverse-Z), and the bands sit `RING_DROP` below the ring so the seams between bands never
  z-fight.

**Acceptance criteria:**
- [ ] Suite: the outermost band radius equals the closed form for the default eye height and the
  fabric's `maxHeight`, and changes when `maxHeight` does.
- [ ] Suite: on a fixture shape with a single 500 m peak, the peak's band vertex is within 5 m of
  the peak height at 20 km, 50 km and 80 km, and `visible_over_horizon` agrees with whether the
  vertex, after `curvature_drop`, is above the eye line.
- [ ] Suite: walking one near-band cell rebuilds only the near band; a far band rebuilds only after
  a whole far-band cell; no band build runs on the main thread.
- [ ] Suite: bands across the antimeridian and past a pole match the shape sampled at the wrapped
  position; adjacent bands share their boundary heights (no cracks) to within `RING_DROP`.
- [ ] Suite: the bands carry no collision body, and the total distant vertex count stays within a
  fixed budget at the default view distance.
- [ ] Playtest bot: a `far_peak` step stands 60 km from a known ridge on the default seed and finds
  rock or snow pixels above the skyline in its direction; the step reports frame time and fails over
  the existing hitch limit.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 166 — Native builder scaffold: GDExtension, loader, fallback, CI binaries and releases

**Goal:** a chunk still costs a worker about 200 ms of GDScript (resolve + mesh arrays). Bigger
mountains and a wider view make that worse. This phase moves the per-tile loops to native code
before the world gets taller, without making the public build depend on a native binary.

**Split (decided 2026-10-17).** Phase 144 is split into four steps, each one a whole PR with a
working build: **166** scaffold, loader, fallback, CI binaries and releases; **167** `heightmap_for`;
**168** `build_runs`; **169** `build_chunk_arrays` and the speed target. Each is a full roadmap step
for the review rules: its PR closes every box in its own section. The optional compute-shader
heightmap path is Phase 170.

**Decisions that apply to Phases 166–169:**
- **Noise:** native code calls Godot's own `FastNoiseLite` through `godot-cpp` (a `Ref<FastNoiseLite>`
  configured exactly as the GDScript one). Do not vendor `FastNoiseLite.h`. Using the engine's class
  makes noise bit-exact by construction, so parity failures always point at the ported logic.
- **Binaries:** built by CI for Linux x86_64, Windows x86_64 and macOS universal. They are uploaded
  as workflow artifacts on every run and attached to a GitHub Release when a `v*` tag is pushed.
  Never committed to git or LFS. A platform without a binary runs the GDScript fallback.
- **macOS:** unsigned universal binary plus a macOS export preset. No signing or notarization (that
  needs an Apple developer account; tracked as a human issue if ever wanted).
- **Verification of non-Linux builds is CI's job.** The Windows and macOS binaries are proven by the
  PR's `windows-latest` / `macos-latest` CI jobs, not locally. A run on Linux builds and tests the
  Linux binary locally (`g++` is installed; get SCons with `pipx install scons`), pushes, and
  lets CI decide the other two. "Could not verify Windows/macOS here" is not a reason to skip or
  block: push and read the CI result.

**Newel dependency:** NO.

**Depends on:** Phase 142.

**Deliverables:**
- `native/` — a GDExtension (C++, `godot-cpp` pinned to the Godot 4.7 tag as a git submodule or a
  pinned CI checkout, SConstruct, `.gdextension` file). It exposes a `NativeChunkBuilder` class
  whose methods exist but are not yet used for any real chunk work (a `version()` call is enough).
- The GDScript builder stays the reference. A loader picks the native builder when the extension
  loads and falls back to GDScript otherwise, with one log line saying which is in use. A per-function
  switch lets later steps route one function at a time through native code.
- CI: a matrix job builds the extension on `ubuntu-latest` (Linux x86_64), `windows-latest` (Windows
  x86_64) and `macos-latest` (macOS universal), with a cache for `godot-cpp`. The binaries are
  uploaded as artifacts and bundled into the export builds (Linux, Windows, and a new macOS export
  preset).
- `.github/workflows/release.yml` (or a job in `ci.yml`) creates a GitHub Release on a `v*` tag and
  attaches the three binaries and the export builds.
- `.gitignore` keeps built binaries out of git.

**Acceptance criteria:**
- [ ] CI: the three platform binaries build in the PR's CI run.
- [ ] Suite: with the extension present the loader reports native; with it absent the loader reports
  the GDScript fallback and the game boots. Both paths are tested.
- [ ] CI: an export without the binaries boots on the fallback.
- [ ] A release workflow triggered by `v*` tags exists and passes `actionlint` in CI (pushing a real
  tag is not required).
- [ ] Suite green on both boot paths, harness green.

---

## Phase 167 — Native `heightmap_for`

**Newel dependency:** NO.

**Depends on:** Phase 166.

**Deliverables:**
- `heightmap_for` ported to `NativeChunkBuilder`: climate, shape, ore and biome resolve, using the
  engine's `FastNoiseLite` through `godot-cpp`.
- The loader routes `heightmap_for` to native when the extension is present.

**Acceptance criteria:**
- [ ] Suite: native and GDScript `heightmap_for` give equal results for a fixed set of chunks
  (equator, ice, pole, antimeridian, edited chunk). Skipped with one log line when the extension is
  absent; CI runs it with the extension built.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 168 — Native `build_runs`

**Newel dependency:** NO.

**Depends on:** Phase 167.

**Deliverables:**
- `build_runs` ported to `NativeChunkBuilder`, routed through the loader.
- If the GDScript reference's output order depends on dictionary iteration, the reference is made
  deterministic first (in the same PR) so parity is defined.

**Acceptance criteria:**
- [ ] Suite: native and GDScript `build_runs` give equal output, same order, for the fixed chunk set.
- [ ] Suite green on both boot paths, harness green.

---

## Phase 169 — Native `build_chunk_arrays` and the speed target

**Newel dependency:** NO.

**Depends on:** Phase 168.

**Deliverables:**
- `build_chunk_arrays` (the greedy mesher) ported to `NativeChunkBuilder` with a deterministic output
  order, routed through the loader. The whole chunk build now runs native when the extension loads.
- The playtest bot's `stream` step records the chunk build rate and which builder was used, and CI
  runs the step once per builder on the same commit.

**Acceptance criteria:**
- [ ] Suite: native and GDScript builders give equal arrays for the fixed chunk set; the GDScript
  fallback is used when the extension is absent.
- [ ] Playtest bot (CI): the `stream` step's chunk build rate with the native builder is at least
  double the GDScript fallback's on the same commit (so Phase 142's pump gains are not counted), and
  `report.json` shows no step with a hitch over 50 ms (the bot does not fail on hitches, so this is
  read from the report, not from the exit code).
- [ ] Suite green on both boot paths, harness green.

---


## Phase 170 — A compute-shader heightmap, if the native builder is still the bottleneck

**Goal:** moved out of Phase 144. Measure first; build only if the numbers ask for it.

**Newel dependency:** NO.

**Depends on:** Phase 169, Phase 165.

**Deliverables:**
- A playtest-bot measurement at the largest default view distance (after Phase 165) that reports
  where chunk build time goes with the native builder.
- If `heightmap_for` is still over half of the build time: a compute-shader heightmap path with the
  native builder as fallback. Otherwise: the measurement is recorded in this section and the phase
  closes with no shader.

**Acceptance criteria:**
- [ ] Playtest bot (CI): the measurement is in `report.json`, and this section records the decision.
- [ ] If a shader ships: suite parity with the native `heightmap_for` for the fixed chunk set, and a
  machine without compute support uses the native/GDScript path.
- [ ] Suite green on both boot paths, harness green.

## Phase 171 — Creatures in exact coordinates: no float32 metres far from the origin

**Goal:** creature records (`CreatureSlice._instances`, `_dead_state`, the wire and the save) hold
their position as a float32 world `Vector3`. At x ≈ 2e7 m (half a lap from the origin) a float32 has
about 2 m between values, so a creature's range checks, model placement (`CreatureVisuals`) and AI
steps are metres-coarse there, and a model can jitter. Players, waystones and hearths already use
exact `{chunk, local}` positions; creatures should too. Split out of review follow-ups #380 and #392.

**Newel dependency:** NO.

**Depends on:** Phase 154 (it splits the files this phase touches).

**Deliverables:**
- `CreatureSlice` keeps each instance's position as `{chunk, local}` (`WorldPos`), with the
  `Vector3` world metres derived only near the camera or the player (scene-relative, like
  `WorldPos.to_scene`). `creature_state_changed`, snapshots and the world record carry the exact form;
  a legacy float position still loads.
- `CreatureVisuals.reselect` and `_update_model` place models from camera-relative positions computed
  from the exact form, never from a float32 world `Vector3`.
- `CreatureAI` paths and `creatures_in_radius` / the spatial hash work in the local frame of the chunk
  window, so a step far from the origin is the same size as one near it.
- The fold log (`_fold_log`, Phase 145) folds exact positions.

**Acceptance criteria:**
- [ ] Suite: a creature at x ≈ 2e7 m moved by 0.1 m keeps the 0.1 m in its record, on the wire and
  after save and load.
- [ ] Suite: its model's scene position is within 1 cm of the record, seen from a camera beside it.
- [ ] Suite: a legacy float-position creature record still loads.
- [ ] Harness: a creature delta far from the origin lands within 1 cm on the client.
- [ ] Suite green on both boot paths, harness green.

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
