# Roadmap history — Phase 162

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

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
  bytes and packets sent and received per peer per second, ENet link health (round trip, packet loss and throttle: Godot exposes no queue depth), chunks dispatched and
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
- [x] Suite: the report builder computes percentiles, per-phase tick shares and the per-peer byte
  rate correctly from a fixed sample list; the hot-spot ranking orders a fixed set of growth curves
  correctly; the largest passing size is the last size that met every budget.
- [x] Suite: a bot's intents and claims pass the host's validation and rate limits unchanged (the
  same checks a real client's do), and a bot that sends a malformed claim is refused like a client.
- [x] Suite: two runs of a pattern with the same seed give the same bot paths.
- [x] CI: the `stress` job runs every pattern up to 64 bots under `lan`, uploads `report.json` and
  `report.md`, and fails only on a hard failure (crash, a host or watcher frame over 2 s, a bot
  dropped by the host without a reason, an orphaned peer record after `churn`).
- [x] CI: the report names a largest passing size per pattern and at least the top three hot spots.
- [x] Suite green on both boot paths, harness green.

**Implementation notes:**
- One bot is the shipped `NetworkingSlice` in the client role (`src/tests/stress_bot_slice.gd`), under
  its own `SceneMultiplayer` rooted at `bot_<i>`, at the node path a real client has
  (`…/Node/GameRoot/networking_slice`), so every packet is built, sequenced and emulated by the client's
  own code. The bot does not re-emit the host's packets on GameBus (n bots would cost n² handler
  calls); it keeps its identity, its join snapshot's spawn and teleports. Bots join at 20 per second,
  report every 0.5 s at 4.5 m/s (both pinned to `PlayerSlice` by the suite) and leave with a graceful
  ENet disconnect: a forced close sends one unreliable goodbye that a busy host can drop.
- `src/core/tick_probe.gd` is a static, off-by-default probe. Phases are timed exclusively
  (`net_in`, `aoi_relay`, `snapshots`, `window_moves`, `peer_windows`, `creature_ai`,
  `creature_sync`, `chunks`, `save`), and the ENet transport counts JSON bytes per peer and per
  message type. The host tick is timed from the physics step through the network poll to the last
  `_process` (Performance's `TIME_PROCESS` includes the frame-rate limiter's wait); frame gaps use the
  wall clock, because the engine clamps `delta` after a stall.
- The host recorder runs the dedicated server at 60 ticks per second on seed 162, in an emptied
  `user://stress/server/`, with a 256-client cap and every new player placed at one anchor (for
  `pole`, a few chunks short of the fold row, so the crowd walks to it). The watcher is a
  `--net-harness client` boot that runs the shipped client boot. Relay lag is end to end (bot send to
  watcher arrival, joined on the position to the centimetre), which bounds the host-side lag from above.
- The run found a leak: the host kept every departed peer's receive channels (`_recv_seq`,
  `_recv_seen`, seq-gap clocks) and emulated link entries; `_on_peer_disconnected` now drops them.
- The hot-spot ranking projects each phase's ms per tick and each message type's kbit/s per peer to
  200 bots on a least-squares line through the ladder (worst pattern) and ranks by the share of the
  budget it would take.
- The two CI criteria were checked by running the job's own command (`STRESS_MAX=64
  STRESS_PROFILES=lan tools/stress.sh`) locally: 15 runs, no hard failure, a largest passing size for
  each of the five patterns and fifteen ranked hot spots. The job itself runs on main pushes.
- Baseline from that run (one desktop machine, so a reference, not a gate): largest passing size 16
  for `cluster`, `cross` and `spread`, 32 for `pole`, 0 for `churn` (every join costs a full
  snapshot, so churning peers average over 100 kbit/s down). Ranked hot spots: `remote_player_state`
  bytes (+2.0 kbit/s per peer per bot: every peer gets every neighbour's relay), `snapshot_chunk`
  bytes, peer window moves on joins and AOI crossings (+0.12 ms per tick per bot; 64 bots crossing
  the polar fold together stall the host for up to 1.1 s), then the AOI relay fan-out.
- Seen in the runs and left for follow-ups: the `pole` watcher shows no remote avatars and logs no
  relay arrivals at the pole (relay lag there has no samples), and under `churn` the watcher's
  avatar count passes the number of bots (avatars of peers that left are not all freed).
