# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Project Nihon: open-source sandbox MMORPG in Godot 4.7 (GDScript). The game design bible is authored as a [Newel](https://github.com/Tubaleviao/newel) fabric (`fabric/`) and generated into docs and Godot resources. Gameplay code lives in `src/`.

## Commands

Fabric tooling (Node, `npm ci` first):

```bash
npm run validate     # validate fabric/ against schema
npm run generate     # regenerate bible/, wiki/, godot/ from fabric/
npm run check-drift  # fail if newel.ir-snapshot.json is stale (CI runs this)
npm run inspect      # list all entities
```

Godot (CI downloads 4.7-stable to `/tmp/godot/Godot_v4.7-stable_linux.x86_64`). Flags after `--` are **user args** (`OS.get_cmdline_user_args()`); putting them before `--` silently does nothing:

```bash
GODOT=/tmp/godot/Godot_v4.7-stable_linux.x86_64
$GODOT --headless --path . --quit -- --run-tests            # unit suite; CI requires "All tests passed", no "✗", no SCRIPT/Parse/Compile Error
$GODOT --headless --path . --quit -- --server               # dedicated server boot; must log "[Server] listening on port"
$GODOT --headless --path . --quit-after 100000 -- --quit-after-boot   # listen-host boot; must log "[World] first ring built"
GODOT=$GODOT tools/net_harness.sh                           # two-process loopback ENet harness
tools/build_pck.sh                                          # build assets.pck from private assets-prod/ submodule
```

There is no single-test CLI filter: `--run-tests` runs everything (about 7,000 assertions, fast, synchronous, no frames). To iterate on one test, temporarily comment out other `_run_test` lines in `src/tests/test_suite.gd`.

## Architecture

**Fabric-first.** Gameplay systems are modeled in `fabric/` (JS: constitution, gameplay, world) before any GDScript. `npm run generate` emits `.tres`/`.gd` resources into `godot/` (read via the `GameData` autoload), `bible/` and `wiki/`. Never hand-edit `godot/`, `bible/`, `wiki/`, `newel.ir-snapshot.json` or `newel.manifest.json`; change `fabric/` and regenerate.

**Slices + GameBus.** Each system is a node `src/<system>/<system>_slice.gd` that owns its data and exposes pure-function projections for tests/UI. Slices talk through typed signals on the `GameBus` autoload (`src/core/bus.gd`). `src/core/game_root.gd` (~2.6k lines) wires slices together and owns boot paths. Direct slice references are allowed for read-only queries/projections only; every state mutation goes bus intent in, authoritative `*_synced` / `*_resolved` signal out.

**Authority model.** Host/dedicated server is authoritative; clients apply synced state. Boot role is chosen from user args in `game_root.gd` (`--server`, `--client <addr>`, `--net-harness host|client`, `--run-tests`, `--quit-after-boot`, `--friend`). Network input is a trust boundary (many "review pass" phases harden it): validate and rate-limit on the host, scope syncs per owner/peer, bound memory.

**World.** Deterministic, planet-scale voxel terrain (`src/terrain/`: `terrain_slice`, `chunk_manager`, `distant_terrain` ring, `world_pos`/`rebase_driver` for exact positions far from origin, climate/biome/ore fields). Chunks build on worker threads; world-gen is stored per-region (`src/persistence/region_store`, `region_streamer`). Anything that changes world-gen output must bump `TerrainSlice.WORLDGEN_VERSION` and add a line to its history comment.

**Assets.** `assets/` ships public placeholders (`*.raw` files); production art is the private `assets-prod/` git submodule (Git LFS), packed into a gitignored `assets.pck` that `AssetOverlay` autoload layers over placeholders. CI does not check out the submodule.

## Tests

All unit tests are in `src/tests/test_suite.gd` (~16k lines). Rules enforced by the suite itself:
- Each `_test_*` func must be registered with `_run_test("name", fn)`; unregistered ones fail the suite.
- No frames elapse, so tests must `free()` what they create (queue_free results too). The final `_assert_no_orphan_nodes()` fails on leaked nodes.
- Network behavior that needs ticking goes in `src/tests/net_harness.gd` (step list is read from the plan line by `tools/net_harness.sh`, so adding a step extends the check). Avoid bare `await` there; an audit test enforces it.

## Workflow conventions

- Work is organized in numbered phases: `ROADMAP.md` (open) and `docs/roadmap-history/` (done). Acceptance criteria must be decidable by automated gates (validate, check-drift, suite, harness, CI); human-only checks become GitHub issues instead.
- Each new system: fabric, generate, check-drift, slice in `src/`, bus signals in `bus.gd`, wire in `game_root.gd`, tests per acceptance criterion.
- Branches: `feat/<system>`, `fix/<area>`, `docs/<topic>`, `fabric/<topic>`. PR titles: `feat(<system>): <short description>`. Fabric design PRs are separate from implementation PRs. No direct pushes to `main` except regenerated artifacts.
- `AGENTS.md` describes code-review-graph MCP tools; use them to narrow scope, then verify in source.
