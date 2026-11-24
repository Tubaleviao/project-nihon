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

Four entry points; the first two are deliberately separate:

```bash
# 1. The unit suite. Runs synchronously on boot — no frames, no sockets — so it is fast
#    and its GameBus emissions cannot leak into world state. About 26,000 assertions.
#    Add --test-filter=<substring> after `--` to run only matching tests while iterating
#    (the registration and orphan audits still run; a filter that matches nothing fails).
/tmp/godot/Godot_v4.7-stable_linux.x86_64 --headless --path . --quit -- --run-tests

# 2. The two-client network harness (Phase 39). Boots one host process and one client
#    process on loopback, drives a scripted session over real ENet, and asserts the two
#    sides' log lines agree. Needs a Godot 4.7 binary:
GODOT=/tmp/godot/Godot_v4.7-stable_linux.x86_64 tools/net_harness.sh
#    Phase 297: NET_HARNESS_ADDRESS=::1 runs it over IPv6 loopback (CI runs both), and
#    NET_HARNESS_PORT moves it off 7777 (and the status port off 7778), e.g. beside a live server.

# 2b. The server-list harness (Phase 298). A registry, two `--public` dedicated servers ("Alpha" and
#    "Beta") and a client that opens the main menu's Public servers tab, on loopback: the list must
#    show both with players and ping, Alpha (stopped by the driver) must leave it within 100 s, and
#    the client then joins Beta from it. About 3 minutes. REGISTRY_HARNESS_ADDRESS=::1 runs it on
#    IPv6; REGISTRY_HARNESS_PORT (default 7720) is the base of the six ports it uses.
GODOT=/tmp/godot/Godot_v4.7-stable_linux.x86_64 tools/registry_harness.sh

# 3. The same harness under a link profile (Phase 135): lan, wan_br (60 ms ± 15 ms, 1% loss)
#    or wan_bad (200 ms ± 60 ms, 5% loss, 256 kbit/s). NET_PROFILE is passed to both
#    processes as `--net-profile`; step timeouts scale with the profile's round trip. An
#    unknown profile name is refused at boot (exit 2). Under a bandwidth cap the harness
#    host mutes creature position deltas, which alone exceed 256 kbit/s per client.
NET_PROFILE=wan_bad GODOT=/tmp/godot/Godot_v4.7-stable_linux.x86_64 tools/net_harness.sh

# 4. The crowd stress run (Phase 162). A dedicated server, one watching client and a bot
#    process with n light clients, per walk pattern (cluster, spread, cross, pole, churn) and
#    crowd size (16, 32, 64, 128, 200), under each link profile. Writes stress/report.json and
#    stress/report.md: the largest crowd that met every budget per pattern, and the ranked hot
#    spots. Exits 1 only on a hard failure (crash, a frame over 2 s, a bot dropped without a
#    reason, a peer record left behind). The default ladder (up to 64 bots, 15 runs) takes a while and a full one (to 200) longer; narrow it with
#    STRESS_MAX, STRESS_PATTERNS, STRESS_PROFILES and STRESS_SECONDS:
STRESS_MAX=32 STRESS_PATTERNS="cluster churn" STRESS_PROFILES=lan \
  GODOT=/tmp/godot/Godot_v4.7-stable_linux.x86_64 tools/stress.sh
```

The stress run's three roles are user args too: `--server --stress-host <out.json>` (the host
recorder), `--net-harness client --stress-watch <out.json>` (the watcher, which runs the shipped
client boot instead of the harness scenario) and `--stress-bots <n>` (the bot process, debug builds
only). `tools/stress.sh` wires them together with a "steady" file (the bots have all joined; the host
and the watcher sample only while it exists) and a "stop" file. The host recorder empties and uses
`user://stress/server/`, never a real save. The watcher, like the harness client, writes the cached
client identity.

**Split mode (Phase 250).** To measure the server without the bots stealing its CPU, run it on one
machine and the bots on another: `STRESS_ROLE=server tools/stress.sh` on the server (UDP 7777 and TCP
7778 open), then `STRESS_ROLE=bots STRESS_SERVER=<addr> tools/stress.sh` on the bots' machine, which
drives the ladder and builds the report (with a Machines table for both). The "steady" and "stop"
handshake and the host and watcher reports cross a TCP side channel (`tools/stress_ctl.py`).
`STRESS_LOOPBACK_SPLIT=1` runs both roles on one machine, as CI does. Numbers: [docs/perf/server-ceiling.md](perf/server-ceiling.md).

`--run-tests` and `--net-harness <host|client>` are **user args**, so they go after the
`--` separator. The harness cannot live in the suite — an `ENetMultiplayerPeer` only
delivers when the tree ticks, and the suite has no frames to give it — so it is its own
boot mode; the purely computational half of it (the step table, the log-line format and
parser, the convergence verdict, the target selection) is still registered in the suite
and covered on every boot.

## Hosting: ports, IPv6 and LAN discovery

Phase 297. A listen host and a dedicated server take these user args (after `--`):

| Flag | Default | Meaning |
|---|---|---|
| `--port <n>` | 7777 | The game port (UDP, ENet). |
| `--bind <addr>` | `*` | The address to listen on. `*` is one dual-stack socket (IPv4 and IPv6; IPv4 alone where the OS has no IPv6). |
| `--status-port <n>` | game port + 1 | The UDP status port that LAN discovery and the Join screen's ping ask. `0` turns it off. |
| `--world-name <text>` | the menu world's name | What the status answer calls a dedicated server's world. |

A player types `host`, `host:port`, `1.2.3.4:port`, `[2001:db8::1]:port` or a bare `2001:db8::1` (no port) on the
Join screen or after `--client` (one rule, `src/networking/net_address.gd`). A host name with both IPv6 and IPv4
addresses is raced on the status query (IPv6 first, IPv4 250 ms later, Happy Eyeballs). A host behind IPv4 CGNAT can
be reached on its IPv6 address with a firewall rule for the game port and the status port, without a port forward.

The status answer and the join handshake carry `ServerStatus.PROTOCOL_VERSION`; bump it when an old client would
misbehave against a new host (or the reverse). A client and a host of different versions refuse each other with a
`menu.join.fail_protocol_*` reason.

## The public server list: registries

Phase 298. A registry is the same build started with `--registry [port]` (default TCP 7700, dual-stack): a headless
process that keeps a table of public servers in memory and answers list queries. Every message is a length-prefixed
JSON frame with a size cap (`src/networking/registry_wire.gd`).

| Flag | On | Meaning |
|---|---|---|
| `--registry [port]` | a registry | Run as a registry and nothing else. |
| `--public` | a dedicated server | Announce this server to the registries every 30 s (a listen host: "Show in server list" on the Play page). Needs the status port. |
| `--registries <a,b>` | any | The registries to use, overriding the player's saved list and `config/registries.json`. |
| `--region <tag>` | a dedicated server | `sa`, `na`, `eu`, `af`, `as` or `oc`; shown translated in the list. |
| `--save-dir user://…/` | a dedicated server | Its own save folder (two servers on one machine). |

A heartbeat goes over TCP, so its source address cannot be spoofed, and once over each address family the registry
resolves to. The registry takes the server's IP from the connection, never from the heartbeat, and lists the entry
only once that IP answers a status query on the heartbeat's status port. An entry that misses three heartbeats is
dropped (about 90 s). Per address: at most 4 servers and 8 heartbeats per 30 s; at most 64 open connections, 4 per
address. A community runs its own registry and lists it in `config/registries.json` (the seed for a new install) or
in the Join screen's Public servers tab (saved under `registries` in `user://settings.json`). An empty list means no
public list. Clients query each listed server's status port themselves for the ping, players and version they show,
and cache the last list in `user://server_list.json`.

## Admin commands

The host runs every chat command and checks who typed it. An admin is the host's own local
player, or a player id listed in `user://admins.json` (a JSON array of ids). The host re-reads the
file when it changes, so adding or removing an id takes effect mid-session. `/help` lists the
commands a player may use.

| Command | Effect |
|---|---|
| `/tp <x> <y> <z>` · `/tp <player>` · `/bring <player>` | Teleport |
| `/give <item> [quantity] [player]` | Create items |
| `/kill [player]` | Kill a player |
| `/say <message>` | Global announcement |
| `/weather <state> <hours>` | Override the weather of your cell |
| `/time <hh:mm>` · `/time +<hours>` | Move the host clock forward (never back) |
| `/speed <0.1–30> [player]` | Walking speed multiplier for the session |
| `/fly [player]` | Toggle flying (Space climbs, Ctrl sinks) |
| `/heal [player]` | Fill a live player's health (does not revive) |
| `/regen world confirm` | Regenerate the terrain from the current generator |

The Admin window (**O**, a dock box shown only to admins) types the same commands, so it adds no
authority of its own. `/regen world` keeps players, inventories and stations. It moves the save's
regions folder aside to `regions.regen-<unix time>` as a backup (move it back by hand to undo),
empties the host's memory of the old ground and tells every client to drop its copy.

## Branching strategy

| Branch prefix | Purpose |
|---|---|
| `feat/<system>` | New phase implementation |
| `fix/<area>` | Bug fix in an existing slice |
| `docs/<topic>` | Roadmap, wiki, or bible updates |
| `fabric/<topic>` | Fabric-only changes (no GDScript) |

`main` is the stable branch. All work goes through pull requests; direct pushes to `main` are not permitted except for generated artifact updates (`bible/`, `wiki/`, `godot/`).

## CI and perf workflows

Pull requests run `ci.yml`: the gates whose verdict does not depend on how fast the runner is (the suite,
fabric and drift checks, the boots, the loopback harness, the exports, and the playtest bot with
`--playtest-timing-report-only`, which reports the flight coverage and the revisit worker share instead of
failing on them). The loopback harness gets a 480 s deadline and one retry: a real bug fails both runs.

`perf.yml` holds the machine-speed gates: the playtest's 3-run budget median, the native-vs-fallback stream
rate and the slow-machine flight, the crowd stress ladder, the clan loop, the wan_bad and wan_br harness
runs and the release-build flight. It runs on every push to `main`, nightly, by hand (the stress inputs
are there), and on a pull request labelled `perf`. Label a PR that touches the host's hot path
(`src/networking`, `src/terrain`, `src/persistence`, `src/world`, `src/core`, the stress or playtest
tooling) so a regression fails the PR and not `main` after the merge.

## Git hooks

Run `tools/install_hooks.sh` once per clone (it sets `core.hooksPath` to `.githooks`, which worktrees
share). The pre-commit hook runs `tools/check_uids.sh` on what is staged, so a new `.gd` or `.gdshader`
without its `.uid` sidecar fails at commit time instead of in CI (the most frequent CI failure in
November 2026). Generate missing sidecars with `godot --headless --path . --import` and stage them.

## Flaky gates

A gate that fails three times on `main` with no code change that explains it is demoted to report-only
the same day (its numbers still go in the report), and an issue is opened to make it decisive again.
A gate that is red half the time stops meaning anything. `tools/check_gate_health.sh` prints the
failure count per job over the last 40 `main` runs of `ci.yml` (`GATE_WORKFLOW=perf.yml` for the perf
workflow); the scheduled `Gate health` workflow checks both daily and fails when any job is over 10%.
A gate whose verdict is a machine-speed number belongs in `perf.yml`, not on the pull-request path.

The playtest `walk` step is the worked example (Phase 253): its distance, ground and state checks are
decisive, its gait numbers are report-only, and the clip itself is pinned by a suite test
(`animation: the walk clip's feet alternate lead within one cycle`).

## Releasing

A release is a `v*` tag on `main`; `.github/workflows/release.yml` does the rest. The version lives in one
place, `application/config/version` in `project.godot` (the main menu shows it in a corner).

1. Bump `config/version` in `project.godot` (`major.minor.patch`).
2. Add a `## v<version>` entry at the top of `CHANGELOG.md`: what shipped, a paragraph per arc. CI fails
   (`tools/check_changelog.sh`) while the version has no entry, and the entry becomes the release notes.
3. Merge through a pull request as usual. A PR that touches something a release depends on (`release.yml`,
   `export_presets.cfg`, `project.godot`, `CHANGELOG.md`, the changelog, assets-pin and export-playtest scripts, the playtest
   bot, `native/`; the list is the workflow's `pull_request.paths`) runs the release workflow as a dry run; any branch can run one by hand
   (`gh workflow run Release --ref <branch>`).
   A dry run builds, exports, plays the bot and uploads the packages as an artifact, but publishes nothing.
4. Tag the merge commit and push the tag: `git tag v<version> <sha> && git push origin v<version>`. The
   workflow refuses a tag that does not match the project version, in its first job, before any build. It
   also refuses a tag whose `assets-prod` pointer is not the private assets repo's `main` HEAD
   (`tools/check_assets_pin.sh`, reading that repo with the `ASSETS_DEPLOY_KEY` secret, the private half of
   a read-only SSH deploy key on it), because players' `assets.pck` is built from the release's pin: bump
   the pointer in an `assets-prod:` pull request first. Run `tools/check_assets_pin.sh` before tagging to check.
5. Watch the run (`gh run watch`). It builds the native library on three platforms, exports Linux, Windows
   and macOS, plays the bot's `create`, `walk` and `mine` steps on the Linux export under xvfb, and only
   then creates the GitHub Release with six assets (three games, three native libraries).
6. Smoke-test each download on its platform: it starts, the menu shows the new version, a new world loads.
   File what breaks as an issue against the release.

## Design decisions

Major design decisions follow the community governance process described in the `CommunityOwnsTheFuture` constitution principle. Proposals are tracked as fabric entities in `fabric/constitution/decisions.js` with a state machine (`proposed → accepted → superseded`). Significant decisions must be ratified by contributor consensus before implementation begins.

