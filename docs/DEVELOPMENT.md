# Development

How Project Nihon is built, tested and shipped. For the player-facing overview see the [README](../README.md).

Project Nihon follows a **fabric-first** discipline: every gameplay system is defined in the Newel fabric before it is implemented in GDScript. The flow is:

```
fabric/ (design)  →  npm run generate  →  godot/  (Godot resources)
                                    →  bible/  (design bible)
                                    →  wiki/   (player wiki)
```

## Phases and slices

Each roadmap phase ships as one or more **slices** — self-contained GDScript nodes that communicate primarily through `GameBus` typed signals. A slice owns its data and exposes pure-function projections for the test suite and the UI layer.

Slices do **not** hold each other by default. The bus carries every *event* and *intent*; `game_root` wires a small, curated set of cross-slice references only where a signal cannot carry the context — a slice needs to **query** another slice's data (e.g. `creature_slice`, `inventory_slice`, `terrain_slice` to resolve an entity or read counts), and the UI slice holds references to the data slices to render their projections and drive player actions. The invariant is that these references are for **read-only queries and projections**: every state *mutation* still flows through the bus (an intent signal in, an authoritative `*_synced` / `*_resolved` signal out), never through a direct method call that mutates another slice's state.

**Wire positions.** Every position that crosses the network (`player_moved`, stations, snapshot players, placement) is a `{chunk, local}` dictionary checked by `WorldPos.is_wire`: exactly two integer-valued chunk coordinates (X within one lap of the world, Z between the poles plus fold slack) and three finite local metres. A malformed position is dropped, never clamped.

## Adding a new system

1. **Model it in the fabric** — add entities, fields, state machines, and behaviors in `fabric/`. Run `npm run validate` before touching any GDScript.
2. **Generate** — run `npm run generate` to emit updated `.tres` resources into `godot/` and regenerate `bible/` and `wiki/`.
3. **Check drift** — run `npm run check-drift` to confirm the IR snapshot is up-to-date before importing in Godot.
4. **Implement the slice** — add `src/<system>/<system>_slice.gd`; build it in `src/core/game_root.gd` and put its bus handlers in `src/<system>/<system>_wiring.gd` (add the module to `_wirings`); add bus signals in `src/core/bus.gd`.
5. **Write tests** — extend the matching `src/tests/suites/<system>_tests.gd` (register each test in its `register()`; new files go in `SUITES` in `src/tests/test_suite.gd`) with at least one test per acceptance criterion before marking the phase done.
   A phase that changes world-generation output (heights, biome placement, climate, continents) also bumps `TerrainSlice.WORLDGEN_VERSION` and adds a line to its history comment, so older saves are flagged on load.
6. **Open a PR** — phases ship as pull requests; titles follow `feat(<system>): <short description>`. PRs for design changes to the fabric are separate from implementation PRs.

## Testing

Two entry points, deliberately separate:

```bash
# 1. The unit suite. Runs synchronously on boot — no frames, no sockets — so it is fast
#    and its GameBus emissions cannot leak into world state. 7,000+ assertions.
/tmp/godot/Godot_v4.7-stable_linux.x86_64 --headless --path . --quit -- --run-tests

# 2. The two-client network harness (Phase 39). Boots one host process and one client
#    process on loopback, drives a scripted session over real ENet, and asserts the two
#    sides' log lines agree. Needs a Godot 4.7 binary:
GODOT=/tmp/godot/Godot_v4.7-stable_linux.x86_64 tools/net_harness.sh

# 3. The same harness under a link profile (Phase 135): lan, wan_br (60 ms ± 15 ms, 1% loss)
#    or wan_bad (200 ms ± 60 ms, 5% loss, 256 kbit/s). NET_PROFILE is passed to both
#    processes as `--net-profile`; step timeouts scale with the profile's round trip. An
#    unknown profile name is refused at boot (exit 2). Under a bandwidth cap the harness
#    host mutes creature position deltas, which alone exceed 256 kbit/s per client.
NET_PROFILE=wan_bad GODOT=/tmp/godot/Godot_v4.7-stable_linux.x86_64 tools/net_harness.sh
```

`--run-tests` and `--net-harness <host|client>` are **user args**, so they go after the
`--` separator. The harness cannot live in the suite — an `ENetMultiplayerPeer` only
delivers when the tree ticks, and the suite has no frames to give it — so it is its own
boot mode; the purely computational half of it (the step table, the log-line format and
parser, the convergence verdict, the target selection) is still registered in the suite
and covered on every boot.

## Branching strategy

| Branch prefix | Purpose |
|---|---|
| `feat/<system>` | New phase implementation |
| `fix/<area>` | Bug fix in an existing slice |
| `docs/<topic>` | Roadmap, wiki, or bible updates |
| `fabric/<topic>` | Fabric-only changes (no GDScript) |

`main` is the stable branch. All work goes through pull requests; direct pushes to `main` are not permitted except for generated artifact updates (`bible/`, `wiki/`, `godot/`).

## Design decisions

Major design decisions follow the community governance process described in the `CommunityOwnsTheFuture` constitution principle. Proposals are tracked as fabric entities in `fabric/constitution/decisions.js` with a state machine (`proposed → accepted → superseded`). Significant decisions must be ratified by contributor consensus before implementation begins.

