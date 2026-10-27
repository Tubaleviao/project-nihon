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

Each fabric validator has a `tools/check_*.js` that proves it rejects bad tables (`node tools/check_attributes.js`, `check_harvest.js`, `check_combat.js`…); CI runs them all, so a new validator gets one and a CI step.

Godot (CI downloads 4.7-stable to `/tmp/godot/Godot_v4.7-stable_linux.x86_64`). Flags after `--` are **user args** (`OS.get_cmdline_user_args()`); putting them before `--` silently does nothing:

```bash
GODOT=/tmp/godot/Godot_v4.7-stable_linux.x86_64
$GODOT --headless --path . --quit -- --run-tests            # unit suite; CI requires "All tests passed", no "✗", no SCRIPT/Parse/Compile Error
$GODOT --headless --path . --quit -- --server               # dedicated server boot; must log "[Server] listening on port"
$GODOT --headless --path . --quit-after 100000 -- --quit-after-boot   # listen-host boot; must log "[World] first ring built"
GODOT=$GODOT tools/net_harness.sh                           # two-process loopback ENet harness
tools/build_pck.sh                                          # build assets.pck from private assets-prod/ submodule
```

`--run-tests` runs everything (about 26,000 assertions, synchronous, no frames). To iterate, add `--test-filter=<substring>` after `--`: only tests whose registered name contains the substring (case-insensitive) run, the registration/orphan audits still run, and a filter that matches nothing fails the run. CI runs the full suite with no filter.

```bash
$GODOT --headless --path . --quit -- --run-tests --test-filter=worldgen
```

Playtest bot (Phase 134): `--playtest-bot` boots a rendered listen host and plays walk, stream, flight (Phase 187: 90 m/s, ground under the body built in ≥ 90% of samples with the native builder; Phase 189: collision and contents ms per attached chunk at most half of a record flight flown with the near ring off; the whole chunk pump is report-only; Phase 190: worker ms per crossing at most a third of the record's), mine, gather, craft, character_sheet (Phase 179: the Character window lists every attribute and slot, the doll renders a non-blank viewport), place, fight, travel, horizon, far_peak and pole, writing `playtest/report.{json,md}` and a PNG per step. Needs a display (CI uses `xvfb-run`); under `--headless` it runs but skips screenshots. Exits 1 on a step failure, a frame over 2 s, or a gated step's p95 process time over its budget × 1.25 (Phase 174: `docs/perf/playtest-budget.json`, table in `docs/perf/playtest-baseline.md`; `--playtest-no-budget` reports only, and CI gates the median of 3 runs with `tools/check_playtest_budget.py`). It plays its own emptied save (`user://playtest/server/`) on the pinned `PlaytestBot.WORLD_SEED` so verdicts do not depend on a random world; `--playtest-seed <n>` tries another seed (re-check every step if you change the pin, or a worldgen bump breaks it).

```bash
$GODOT --headless --path . -- --playtest-bot
```

## Architecture

**Fabric-first.** Gameplay systems are modeled in `fabric/` (JS: constitution, gameplay, world) before any GDScript. `npm run generate` emits `.tres`/`.gd` resources into `godot/` (read via the `GameData` autoload), `bible/` and `wiki/`. Never hand-edit `godot/`, `bible/`, `wiki/`, `newel.ir-snapshot.json` or `newel.manifest.json`; change `fabric/` and regenerate.

**Slices + GameBus.** Each system is a node `src/<system>/<system>_slice.gd` that owns its data and exposes pure-function projections for tests/UI. Slices talk through typed signals on the `GameBus` autoload (`src/core/bus.gd`). `src/core/game_root.gd` (~1.2k lines) builds the slices, picks the boot role and owns the boot paths and tick; each system's bus handlers and glue live in `src/<system>/<system>_wiring.gd` (`wire(ctx)` / `unwire()`, base `src/core/wiring.gd`). Direct slice references are allowed for read-only queries/projections only; every state mutation goes bus intent in, authoritative `*_synced` / `*_resolved` signal out.

**Authority model.** Host/dedicated server is authoritative; clients apply synced state. Boot role is chosen from user args in `game_root.gd` (`--server`, `--client <addr>`, `--net-harness host|client`, `--run-tests`, `--quit-after-boot`, `--friend`). Network input is a trust boundary (many "review pass" phases harden it): validate and rate-limit on the host, scope syncs per owner/peer, bound memory.

**World.** Deterministic, planet-scale voxel terrain (`src/terrain/`: `terrain_slice`, `chunk_manager`, `distant_terrain` ring, `world_pos`/`rebase_driver` for exact positions far from origin, climate/biome/ore fields). Chunks build on worker threads; beyond the reach ring they are built coarse (Phase 190, `src/terrain/voxel_coarse.gd`: 32×32 or 16×16 cells, edge skirts, policy in `near_ring.gd`); world-gen is stored per-region (`src/persistence/region_store`, `region_streamer`). Anything that changes world-gen output, in code or in `WorldSystem` or biome envelopes, must bump `TerrainSlice.WORLDGEN_VERSION`, add a line to its history comment and update the golden values in the suite (`_test_worldgen_golden`); `TerrainSlice.worldgen_fingerprint()` flags fabric-parameter drift in saved worlds.

**Stable-world rule.** A recorded chunk (`ChunkRecords`, region store `gen`) never changes: its biome and corner heights come from the record, not the generator. A generator version affects only unrecorded land, and an unrecorded chunk beside recorded land is generated by `src/terrain/frontier.gd` (corners shared with a record reuse it exactly, others ease into the new generator over `BLEND_CHUNKS`; a biome forbidden beside a recorded neighbour becomes its `transition`) and then recorded by the host, so the choice is made once. The frontier record depends on which neighbours were recorded when the chunk loaded (fill order): two hosts with different load histories can record different frontier chunks, and the zero-forbidden-pair guarantee holds for the records present at that time, so a host must not be merged with another host's world. A chunk whose neighbouring region failed to read is not recorded until the region reads. `DistantTerrain` still draws far unrecorded chunks from the plain generator.

**Assets.** `assets/` ships public placeholders (`*.raw` files); production art is the private `assets-prod/` git submodule (Git LFS), packed into a gitignored `assets.pck` that `AssetOverlay` autoload layers over placeholders. CI does not check out the submodule. **Placeholder rule:** the public game must build and be fully playable without the submodule. Every key in `assets-prod/` needs a placeholder at the same key in `assets/` (same clips, bones, image size), added first or with the art. See `assets/README.md`.

## Tests

Unit tests live in `src/tests/suites/<system>_tests.gd` (one file per system, none over 3,000 lines), each extending `src/tests/test_support.gd` (shared fixtures, helpers, assertions) and listing its tests in `register()`. `src/tests/test_suite.gd` is the runner: its `SUITES` list names every suite file (a new `*_tests.gd` must be added there). Rules enforced by the suite itself:
- Each `_test_*` func must be registered with `_run_test("name", fn)`; unregistered ones fail the suite.
- No frames elapse, so tests must `free()` what they create (queue_free results too). The final `_assert_no_orphan_nodes()` fails on leaked nodes.
- Network behavior that needs ticking goes in `src/tests/net_harness.gd` (step list is read from the plan line by `tools/net_harness.sh`, so adding a step extends the check). Avoid bare `await` there; an audit test enforces it.

## Workflow conventions

- Work is organized in numbered phases: `ROADMAP.md` (open) and `docs/roadmap-history/` (done). Acceptance criteria must be decidable by automated gates (validate, check-drift, suite, harness, CI); human-only checks become GitHub issues instead.
- Each new system: fabric, generate, check-drift, slice in `src/`, bus signals in `bus.gd`, handlers in the system's `<system>_wiring.gd` (constructed once in `game_root.gd`'s wiring list), tests per acceptance criterion.
- Branches: `feat/<system>`, `fix/<area>`, `docs/<topic>`, `fabric/<topic>`. PR titles: `feat(<system>): <short description>`. Fabric design PRs are separate from implementation PRs. No direct pushes to `main` except regenerated artifacts.
- Trust boundary: a review finding where the host relies on the client to enforce a rule, trusts client-reported state it could check, or accepts unvalidated network input is fixed in the same PR, never deferred to a follow-up issue.
- i18n (Phase 131, done): every player-facing string goes through `I18n.t()` with keys in both the `en` and `pt_BR` columns of `locale/ui.csv`; hosts send keys + params, never prose.
- Follow-up debt cap: no new feature phase starts while more than 10 `autopilot-followup` issues are open (see `ROADMAP.md`).
- `AGENTS.md` describes code-review-graph MCP tools; use them to narrow scope, then verify in source.
