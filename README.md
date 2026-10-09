# Project Nihon

An open-source sandbox MMORPG where players build a civilization. The world is persistent, expands over time, and evolves entirely through player interaction — no scripted quests, no scripted economies, no pay-to-win.

The entire game design bible — materials, skills, creatures, items, world systems — is authored as a [Newel](https://github.com/Tubaleviao/newel) fabric and generated into documentation, runtime assets, and Godot resources.

---

## Quick start

```bash
npm ci            # or `npm install` to resolve the lockfile fresh
npm run validate  # validate the fabric against the schema
npm run inspect   # list all entities by name
npm run generate  # generate the design bible into bible/
```

---

## Roadmap

| Phase | Title | Status |
|-------|-------|--------|
| 1 | Constitution fabric | Done |
| 2 | Materials and world primitives | Done |
| 3 | Skills and professions | Done |
| 4 | Items, recipes, and technology tree | Done |
| 5 | Creatures and combat systems | Done |
| 6 | `generator-bible` integration | Done |
| 7 | Character system specification | Done |
| 8 | `generator-godot` integration | Done |
| 9 | Public wiki | Done |
| 10 | Vertical slices: playable game loop | Done |
| 11 | Crafting slice | Done |
| 12 | Voxel mining and building | Done |
| 13 | Technology unlock gates | Done |
| 14 | Player UI: inventory, technology tree, crafting | Done |
| 15 | Creature AI and behavior | Done |
| 16 | Station-gated crafting and tool durability | Done |
| 17 | Chunk streaming and world expansion | Done |
| 18 | Multiplayer world sync (core) | Done |
| 19 | Multiplayer chaos resilience | Done |
| 20 | Skeleton rig and animation | Done |
| 21 | Asset separation and public placeholders | Done |
| 22 | Material and palette pipeline | Done |
| 23 | LOD and composition simplification | Done |
| 24 | Social systems and player economy | Done |
| 25 | Tool and equipment repair | Done |
| 26 | Client-side rendering instancing | Done |
| 27 | Headless data-oriented server | Done |
| 28 | Spatial hashing | Done |
| 29 | Interest management (area of interest) | Done |
| 30 | Pack and herd behavior | Done |
| 31 | Trees and resource appearance | Done |
| 32 | One authoritative boot path | Done |
| 33 | Player identity and server-side persistence | Done |
| 34 | Per-player repair and research | Done |
| 35 | Creature taming | Done |
| 36 | Review pass: the network trust boundary, gated boots, per-player progression | Done |
| 37 | Review pass: owner-scoped syncs, durable cooldowns, bounded memory, routed rounds | Done |
| 38 | Review pass: host-simulated peer health, one key list, the missing clear, an in-place prune | Done |
| 39 | Two-client network harness: prove the wire over a real socket | Done |
| 40 | Review pass: the avatar's footing — the voxel surface, walked stairs | Done |
| 41 | Deterministic world and volumetric terrain | Done |
| 42 | Threaded chunk build and a loading screen | Done |
| 43 | Natural resource distribution | Done |
| 44 | Spawn scarcity | Done |
| 45 | Asset pipeline for meshes and animation | Done |
| 46 | UI shell | Done |
| 47 | Character window | Done |
| 48 | Review pass: the equipment trust boundary | Done |
| 49 | Zone crossing and natural ground | Done |
| 50 | Planet coordinates | Done |
| 51 | Continents, oceans and mountains | Done |
| 52 | Region storage and per-player server streaming | Done |
| 53 | Spawn placement and friend codes | Done |
| 54 | World clock, day and night, seasons | Done |
| 55 | Two-client harness: equipment delivery over the socket | Done |
| 56 | Station placement follow-ups | Done |
| 57 | Spawn determinism and cost follow-ups | Done |
| 58 | UI layout file robustness | Done |
| 59 | Wire the Phase 45 rig into the game | Done |
| 60 | Host-authoritative equip | Done |
| 61 | Region storage correctness | Done |
| 62 | Peer streaming window limits | Done |
| 63 | Planet coordinates wiring | Done |
| 64 | Biome blend consistency | Done |
| 65 | World clock and season follow-ups | Done |
| 66 | Spawn point and colonization follow-ups | Done |
| 67 | Network test seam cleanup | Done |
| 68 | Distant terrain off the main thread | Done |
| 69 | Neighbour seam rebuilds that match the edits | Done |
| 70 | Equip intent ordering and refusal cost | Done |
| 71 | World-generation version stamp | Done |
| 72 | Stable, low-frequency rare-biome niches | Done |
| 73 | Swimming and the distant ring follow the real ground | Done |
| 74 | Minimap redraw cost and first-apply layout clamp | Done |
| 75 | Region edits survive eviction and malformed neighbours | Done |
| 76 | Niche field wraps the planet and is calibrated by a test | Done |
| 77 | One detail-noise formula and the ring's strip helper | Done |
| 78 | Exact player position far from the origin | Done |
| 79 | Deterministic peer-window rate limit and a production ref-count reader | Planned |
| 80 | Rebase in the physics step and explicit shift sets | Planned |
| 81 | Pole-aware tile biome and a mined-tile biome memo | Done |
| 82 | Honest peer-window refusal count and a thread-safe warning counter | Planned |
| 83 | Distant-ring teardown that does not stall | Planned |
| 84 | The suite exits with no leaked objects | Planned |

See [ROADMAP.md](ROADMAP.md) for open phases and deferred work. Completed phases are archived in [docs/roadmap-history/](docs/roadmap-history/README.md) with their full spec and acceptance criteria.

Production art lives in a private `assets-prod/` git submodule (Git LFS); the
public repo ships placeholders. See [assets/README.md](assets/README.md).

---

## Development life-cycle

Project Nihon follows a **fabric-first** discipline: every gameplay system is defined in the Newel fabric before it is implemented in GDScript. The flow is:

```
fabric/ (design)  →  npm run generate  →  godot/  (Godot resources)
                                    →  bible/  (design bible)
                                    →  wiki/   (player wiki)
```

### Phases and slices

Each roadmap phase ships as one or more **slices** — self-contained GDScript nodes that communicate primarily through `GameBus` typed signals. A slice owns its data and exposes pure-function projections for the test suite and the UI layer.

Slices do **not** hold each other by default. The bus carries every *event* and *intent*; `game_root` wires a small, curated set of cross-slice references only where a signal cannot carry the context — a slice needs to **query** another slice's data (e.g. `creature_slice`, `inventory_slice`, `terrain_slice` to resolve an entity or read counts), and the UI slice holds references to the data slices to render their projections and drive player actions. The invariant is that these references are for **read-only queries and projections**: every state *mutation* still flows through the bus (an intent signal in, an authoritative `*_synced` / `*_resolved` signal out), never through a direct method call that mutates another slice's state.

### Adding a new system

1. **Model it in the fabric** — add entities, fields, state machines, and behaviors in `fabric/`. Run `npm run validate` before touching any GDScript.
2. **Generate** — run `npm run generate` to emit updated `.tres` resources into `godot/` and regenerate `bible/` and `wiki/`.
3. **Check drift** — run `npm run check-drift` to confirm the IR snapshot is up-to-date before importing in Godot.
4. **Implement the slice** — add `src/<system>/<system>_slice.gd`; wire it in `src/core/game_root.gd`; add bus signals in `src/core/bus.gd`.
5. **Write tests** — extend `src/tests/test_suite.gd` with at least one test per acceptance criterion before marking the phase done.
   A phase that changes world-generation output (heights, biome placement, climate, continents) also bumps `TerrainSlice.WORLDGEN_VERSION` and adds a line to its history comment, so older saves are flagged on load.
6. **Open a PR** — phases ship as pull requests; titles follow `feat(<system>): <short description>`. PRs for design changes to the fabric are separate from implementation PRs.

### Testing

Two entry points, deliberately separate:

```bash
# 1. The unit suite. Runs synchronously on boot — no frames, no sockets — so it is fast
#    and its GameBus emissions cannot leak into world state. 7,000+ assertions.
/tmp/godot/Godot_v4.7-stable_linux.x86_64 --headless --path . --quit -- --run-tests

# 2. The two-client network harness (Phase 39). Boots one host process and one client
#    process on loopback, drives a scripted session over real ENet, and asserts the two
#    sides' log lines agree. Needs a Godot 4.7 binary:
GODOT=/tmp/godot/Godot_v4.7-stable_linux.x86_64 tools/net_harness.sh
```

`--run-tests` and `--net-harness <host|client>` are **user args**, so they go after the
`--` separator. The harness cannot live in the suite — an `ENetMultiplayerPeer` only
delivers when the tree ticks, and the suite has no frames to give it — so it is its own
boot mode; the purely computational half of it (the step table, the log-line format and
parser, the convergence verdict, the target selection) is still registered in the suite
and covered on every boot.

### Branching strategy

| Branch prefix | Purpose |
|---|---|
| `feat/<system>` | New phase implementation |
| `fix/<area>` | Bug fix in an existing slice |
| `docs/<topic>` | Roadmap, wiki, or bible updates |
| `fabric/<topic>` | Fabric-only changes (no GDScript) |

`main` is the stable branch. All work goes through pull requests; direct pushes to `main` are not permitted except for generated artifact updates (`bible/`, `wiki/`, `godot/`).

### Design decisions

Major design decisions follow the community governance process described in the `CommunityOwnsTheFuture` constitution principle. Proposals are tracked as fabric entities in `fabric/constitution/decisions.js` with a state machine (`proposed → accepted → superseded`). Significant decisions must be ratified by contributor consensus before implementation begins.

---

## Contributing

Major design decisions follow the community governance process described in the `CommunityOwnsTheFuture` principle — propose publicly, ratify by contributor consensus. See the constitution fabric for the full set of principles and current decisions.
