# Roadmap history — Phases 39–42

Completed phases, archived unchanged from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 39 — Two-client network harness: prove the wire over a real socket ✅ Done

**Goal:** Make the network trust boundary real. Phases 34–38 hardened the client → host
intent path — connection-bound identity, reach and rate guards, owner-scoped syncs,
durable per-player records, host-simulated peer health — and every one of those
guarantees is currently proven at the ROUTING level only: tests call `_route_c2h(sender,
payload)` and read the bus, with the sender id handed in as an argument. No test has ever
put a byte on a socket. This phase adds a harness that boots two real peers over ENet —
the same `NetworkingSlice.host()` / `join()` the game itself uses — drives a full session
lifecycle between them, and asserts on packets the transport actually carried. It closes
the deferral re-stated in Phases 34, 35, 36, 37 and 38.

Deliverable 1 is the one durable fix the harness then proves on a real socket: a peer's
simulated HP is a subtract-only counter that cannot heal, so a peer downed by a creature
stays at zero across reconnects and restarts, and the client handed that zero ends up dead
with no countdown running. The harness's reconnect step is where that fix is observed
end to end.

**Newel dependency:** None. No fabric field changes — `pnpm validate` is clean and
`pnpm check-drift` still reports 543 file(s) matching the manifest.

**Deliverables:**
- `src/persistence/player_registry.gd` — deliverable 1, the durable fix: a peer's
  simulated HP stops being a subtract-only counter. When a resolved hit takes it to zero
  the host writes a respawn deadline onto the same durable record (the Phase 37 deadline
  shape, pruned the way `live_cooldowns` prunes), and the deadline is resolved by a NEW
  PURE RULE — `hp_after_respawn(hp, deadline, now, max_hp)` — that BOTH readers of the
  field call, so a downed peer's recovery does not depend on which one asks. The two
  readers are `get_hp()` (the live read) and `get_player_data()` (the saved copy, which the
  handshake snapshot, the disconnect save and the autosave all go through — and which
  currently reads `hp` raw at `player_registry.gd:627`). A resolution wired into the live
  reader alone leaves the one the reconnect actually uses un-resolved, which is Phase 38's
  lesson in mirror image: a rule that runs on one reader is a reader-dependent rule. No
  write-on-read either: `get_hp()` stays pure and the deadline stays the durable fact. A
  rewrite through `record_simulated_hp` would no-op on exactly the paths where it refuses —
  a non-authoritative machine, the local id, a player with no resident record — while the
  value the read returned claimed full health.
- `src/player/player_slice.gd` — the client-side half of deliverable 1: `set_hp()` starts
  the respawn countdown when the value it applies is zero AND no countdown is already
  running (`_respawn_timer == -1.0`) — it must START one, not restart it, or a repeated
  zero would push the respawn further away on every application and the body would never
  come back. One entry point, so a body handed a zero — by a join snapshot, a forwarded
  hit, or a save restore — can never sit `_alive == false` with no timer running. That
  incidentally closes the same soft-lock in single-player: `_restore_local_player` hands a
  restored record's zero to the same door (`game_root.gd:1246`), so the fix covers the
  local body too rather than only the peer it was found on. **Review pass — two more rules
  on that same door, both about what it owes the callers it already had. (a) A zero applied
  to a LIVE body is announced THROUGH `_die()`, so `player_died` fires: this method used to
  apply the number and start the countdown without ever reaching the death door, so the
  body was dead here with no death announced — while that very countdown announced
  `player_respawned` when it ran out, and `game_root` turns `player_died` into the
  character-death consequence. A respawn with no death behind it is half a pair. A zero
  applied to a body ALREADY down announces nothing, so a re-delivered snapshot cannot
  re-announce a death that already happened. (b) A value that leaves the body UP clears the
  countdown parked on it: `_physics_process` ticks the timer only while `_alive` is false,
  so a leftover sat frozen on a living body and was then REUSED by the next zero instead of
  a fresh one — the body came back early, on the seconds left over from the death it had
  already recovered from. Both are registered as
  `identity: set_hp announces and clears`.**
- `src/tests/net_harness.gd` — the `await`-driven harness runner: a scenario step table
  and a pump loop that yields real frames, so packets can leave and arrive. The existing
  suite cannot host this (see the constraint note below). **Review pass — the runner now
  audits its OWN source before either peer boots (`unawaited_waits` / `_self_audit`): a bare
  `_await_…` call compiles and returns immediately, which is precisely how the twelve missing
  `await`s in this file turned its waits into no-ops, and it is the one defect the
  frame-less suite cannot observe. The runner also ends its process with the run's own verdict
  as the exit code (`get_tree().quit(1 if _failed else 0)`): the driver reads the `fail` line
  too, but a scenario that failed used to exit 0, which is the wrong answer to give the
  cheapest question anyone asks a process.**
- `src/core/game_root.gd` — a `--net-harness <role>` user arg parsed beside `--server` /
  `--client`, and the harness entry point that runs BEFORE the world boot, mirroring the
  existing `should_run_tests` gate.
- `tools/net_harness.sh` — the driver: boots one host process and one client process on
  loopback, waits for a readiness line, runs the scenario, and fails on a missed
  assertion, a deadline overrun, or a non-zero exit. **Review pass — the header claimed "a
  side misses a step, or reports it TWICE" while the reader took `head -n 1` and nothing
  counted: a second line for a step was silently ignored and the step judged on the first.
  The check now exists (`steps_reported`), the dead `steps_of()` was removed, and the
  per-step readers are unambiguously "the first line" because a duplicate can no longer
  reach them. CI pass — on failure the driver now prints both processes' `HARNESS` lines and
  their transport-lifecycle lines into the step output, so a CI failure says which step broke
  without anyone downloading the artifact.**
- `src/core/player_rules.gd` — **review pass**: `MAX_HP` and `RESPAWN_DELAY` move off
  `PlayerSlice` into a neutral module both layers preload, the `skill_tiers.gd` shape. The
  persistence layer used to `preload("…/player_slice.gd")` for those two constants —
  persistence importing presentation, in the wrong direction, for arithmetic neither layer
  owns. The values are unchanged and `PlayerSlice` re-exports both names, so no existing
  reader moved.
- `src/tests/test_suite.gd` — registration of the harness's pure helpers (the step table,
  the log-line format, the convergence predicates) so the synchronous suite still covers
  the harness's own logic, under a `Phase 39` banner.
- `.github/workflows/ci.yml` — a `net-harness` job running the driver on ubuntu-latest,
  alongside `godot-tests`, `server-boot` and `fabric`.
- `README.md` — phase table rows for 36, 37 and 38 (missing since those passes landed)
  and for this phase.

**Acceptance criteria:**
- [x] Two real peers handshake over loopback ENet, and the identity the host binds comes
  from the CONNECTION: a client declaring a `player_id` it does not own is bound to its
  transport-derived id anyway (`handshake`, both sides green). *The un-handshaked-peer
  half stays a routing-level assertion — the client's boot presents its join intent on
  connect, so there is no window to send an intent from before the handshake.*
- [x] The reach guard is exercised with real evidence: a chop intent for a tree the peer
  cannot reach is dropped, and one for a tree inside reach consumes it — the tree's
  position coming from the host's own `TreeSlice`, never the payload (`chop_in_reach`,
  `chop_out_of_reach`).
- [x] The inbound limits hold on a real socket: a packet above `MAX_CLIENT_PACKET_BYTES`
  (8192) is refused without disconnecting the peer as a side effect, and the per-peer
  token bucket throttles a burst without starving the steady stream that follows it
  (`packet_cap` — the host logs the 9067-char drop and the peer stays bound; `rate_bucket`
  — the bucket reads 0 mid-burst and the chop after it is consumed).
- [x] An owner-scoped inventory sync reaches the owner alone: peer A's sync leaves peer
  B's client inventory and the host's own bucket untouched (`inventory_owner`; the host's
  own pack is compared before/after, because a dedicated server boots with its saved
  record restored and is not empty).
- [x] A chunked snapshot completes across real packets (`snapshot_complete` — the world
  snapshot is far larger than `SNAPSHOT_CHUNK_SIZE`, so it genuinely arrives as several
  reliable packets, and the client reassembles them into one world). A client that loses
  its host clears its buffer: asserted on its own `disconnect_all()` teardown in
  `reconnect_alive`; the `NetworkingSlice._on_server_disconnected` path is NOT exercised
  on the wire (see the known simplifications). **What this proves, exactly (review pass):
  that the reassembler works over the TRANSPORT'S delivery on a real socket — several
  chunked packets, one world. It does NOT prove the reassembler tolerates a chunk arriving
  out of order, because a reliable ordered channel cannot deliver one: the ordering this
  step relies on is the transport's, so the step would pass with no ordering logic in the
  reassembler at all. Reordering and loss stay deferred with the emulator (see the note on
  it) rather than being claimed here.**
- [x] A combat round routed at a peer arrives at that peer's own client, and the host's own
  simulated number for that peer survives a real reconnect AS THE HOST'S OWN
  (`peer_damage_floor`, and the same peer in `reconnect_alive`). **Review pass — this
  criterion and the next one are the two halves of one event and used to read as a
  contradiction: "survives unchanged" is about AUTHORITY (nothing the peer declares
  overwrites the host's number, and the floor the host recorded is still the value the
  record holds), not about the value being frozen at zero — the resolution of a deadline
  that has passed is the next criterion's claim, and both are asserted on the same peer in
  the same step.**
- [x] A peer killed before it disconnects reconnects alive and controllable: the host's
  respawn deadline resolves on the read that follows the reconnect — and resolves on BOTH
  readers, since the handshake snapshot reads the saved copy (`get_player_data()`) rather
  than `get_hp()` — and the client's body runs its own countdown rather than sitting dead
  with no timer (`reconnect_alive`, both sides green).
- [x] Deliverable 1 holds on both ends: a peer whose simulated HP reaches zero returns to
  full health after the delay, survives a restart, and answers the same number through the
  live reader and the saved copy; a body handed a zero by `set_hp()` starts its respawn
  countdown, and a repeated zero does not restart it; the new rule is asserted pure and
  alone, beside `simulated_hp_after_hit` and `live_cooldowns`; and the declared value still
  has no path into a record — the respawn deadline is not a second door for it. Each new
  rule is RED-proved first (`identity: the respawn rule is pure`,
  `identity: a downed peer comes back`, `identity: set_hp starts the respawn countdown`,
  and — review pass — `identity: set_hp announces and clears` for the two rules that door
  gained: a live body taken to zero is announced dead, and a value that leaves it up clears
  the countdown rather than leaving it parked). SECOND review pass — two more rules on the
  same field, both registered as `identity: a sliver of health is down`: "down" is a RANGE
  (`PlayerRegistry.is_downed`, `HP_EPSILON`) rather than the exact value `0.0`, because a hit
  that lands a fraction short of cancelling the number leaves a body at ~1e-7 that the old
  `hp > 0.0` WRITER cleared a deadline for while the old `hp != 0.0` READER handed it back as
  health — a body that could never come back; and a restored record keeps its deadline only
  while the body it belongs to is down, so a record arriving already resolved (alive) cannot
  wear a spent deadline for the rest of the world's life. `is_downed` is the one predicate
  both the writer and the reader use.
- [x] A disconnect evicts transport state end to end: the peer's record is evicted, its
  taming mirrors and snapshot buffer are forgotten, and a reconnect re-presents the join
  intent and is re-answered (`disconnect_evicts` — the reconnected peer carries the SAME
  player id, and no dead peer id is still bound).
- [x] The harness runs on both the host-process and the client-process side and is wired
  into CI, while the existing suite stays synchronous and unchanged in cost
  (`tools/net_harness.sh`). **Review pass — NOT independently reproduced, and the reason was
  in this file. The driver was green when the phase was written (`10/10 steps agreed across
  both peers`) and failed four consecutive runs after it, on `rate_bucket`, always with the
  same detail: `burst_not_throttled_or_steady_lost-steady1-min0-now119` — the tree
  `packet_cap` consumed was counted ONCE, the burst HAD emptied the bucket (`min0`), and at
  the deadline the bucket was full again (`now119` of 120), so the limiter was not what
  starved the stream. The note's money was on "the client half never getting its intents onto
  the wire": right about the symptom, wrong about the layer. SECOND review pass — every one
  of the TWELVE `_await_settle` call sites in `src/tests/net_harness.gd` was missing its
  `await`, so each one returned at its first yielded frame and waited NOTHING. The client's
  post-burst chops therefore left in the SAME FRAME as the burst that had just emptied its
  bucket, the host's limiter dropped them, and the step blamed the limiter for the harness's
  own missing wait — the `steady`/`min`/`now` tokens the first pass added are what made the
  mechanism legible. Reproduced on the pristine source before the fix (`rate_bucket` → the
  identical token, 1 run of 1) and green after it (`10/10 steps agreed across both peers`,
  two consecutive runs). A bare coroutine call is now impossible to reintroduce silently:
  `NetHarness.unawaited_waits()` audits the source, `net: harness awaits are not bare` asserts
  the rule in the suite, and `NetHarness._self_audit()` runs it on every boot. CI PASS — the
  job still went red on the CI runner after that, for two reasons a local run could not show:
  the rejoin did not mirror `game_root._boot_client()` (see the implementation note below),
  and a failure printed only the summary. The driver now prints BOTH processes' step lines and
  lifecycle lines into the step output on failure, so the next CI failure is diagnosable
  without downloading the artifact.**
- [x] The suite remains green on both boot paths (`Results: N/N passed (0 failed)`,
  `[Server] listening on port 7777, max_clients 64`), with the new assertion count
  quoted. **Review pass: `Results: 7508/7508 passed (0 failed)` on both boots — the count
  moved from 7499 with the two rules the review pass added to `set_hp()` (five assertions
  RED-proved first, the run before the fix reading `5 failed`). Second review pass:
  `Results: 7522/7522 passed (0 failed)` on both boots — the count moved from 7508 with
  `identity: a sliver of health is down` and `net: harness awaits are not bare` (seven
  assertions RED-proved first, the run with the two policies reverted reading `7 failed`).**

**Implementation notes:**
- **The scenario targets come from the ORIGIN CHUNK, because the two processes' tree
  tables are not identical.** The host streams chunks on a per-frame budget
  (`ChunkManager.DEFAULT_LOADS_PER_FRAME`), so a peer's snapshot carries the chunks loaded
  by the time it joins and the client seeds its trees from exactly that set; the host keeps
  loading afterwards. Comparing targets across the two processes therefore only works for
  chunk (0,0), which both always hold — every comparing step draws its trees from there
  (`_shared_trees()`), and `chop_out_of_reach` is the one step whose details the driver does
  not compare, for the same reason.
- **The two processes are NOT synchronized, so every observation is counted over the whole
  run.** One side's steps mostly send and move on, so its traffic can arrive while the other
  side is still waiting on a 25 s convergence deadline. A per-step observation window opened
  at the start of the observing step MISSED traffic that had already arrived and reported a
  guard failure for a guard that had worked — so `_chop_count()` counts over the run, and
  each in-reach tree is named by exactly one step. **Review pass — the second half of that
  rule, found only once the waits above were real: a TRANSIENT is not a state. With the
  missing `await`s in place the client ran the whole scenario in about a frame, so it was
  always AHEAD of the host and always caught the 5 s death window; with the waits restored it
  lags by seconds, the host forwards the hit on ITS timeline, and the body can be down AND
  ALREADY BACK UP before the observing step opens — so `peer_damage_floor` and
  `reconnect_alive` reported `no_countdown` / `not_recovered` for a peer whose body did
  exactly the right thing. Both steps now take their "it went down" half from a whole-run
  count (`_deaths`, the `_chops` shape; `player_died` is emitted only through the door that
  arms the timer) and assert what the step is actually about: never down with nothing running
  — still waiting the countdown out, or already back at full health.**
- **A rejoin has to mirror `game_root._boot_client()`, not merely call `join()`.** A client's
  join intent is fire-and-forget and `_on_connected_to_server` is the only other thing that
  re-presents it, so a rejoin whose ONE intent went out before the new socket was up (the log
  shows the RPC erroring with "multiplayer peer which is not connected") presented no intent at
  all: the host never bound the peer, while the client's own half still passed because it only
  asserts its local body. Setting `_snapshot_pending = true` after the rejoin arms
  `_tick_client_handshake`, which re-presents the intent every 3 s until the world arrives —
  exactly what `_boot_client()` does for the first join. **CI pass.** `reconnect_alive`'s
  failure detail now also carries the transport state (host: `live`/`same`/`online`/`buf`;
  client: `conn`/`claim`), because `still_down` alone could not say whether the peer never
  rejoined, rejoined as a different player, or rejoined and did not resolve.
- **ENet drops a quiet peer, so the scenario keeps the link alive while it waits.** A step
  that asserts an ABSENCE waits seconds for nothing to happen, and a step whose counterpart
  is busy waits 25 s; without a periodic keepalive the client was disconnected mid-scenario,
  after which every host step reported no bound peer — a dead socket that looked like a
  broken guard. The keepalive is a real `player_state_sync_requested` carrying RENDEZVOUS,
  so it also pins the position the reach guard measures against.
- **A transport id is not an identity, and the reconnect step is where that shows.** ENet
  reassigns peer ids, so `_bound_player_id` (captured at the handshake) is what every step
  means by "the peer"; the peer id is re-resolved after the reconnect, and the step asserts
  the reconnected connection came back under the SAME player id.
- **The harness's own pure half is registered in the suite.** The step table, the log-line
  format and its parser, the convergence verdict and the deterministic target selection are
  asserted on every ordinary boot, because the driver's whole oracle rests on them: if the
  format and the parser disagreed, the driver would compare nothing and every run would look
  green.
- **ENet needs frames; the suite has none.** `TestSuite._run_tests()` is called
  synchronously from `GameRoot._ready()` and there is not a single `await` in its ~7,900
  lines — deliberate, because it runs before any production slice's emissions can leak
  into world state. A harness cannot be added to that runner: an
  `ENetMultiplayerPeer` only delivers when the tree ticks. The harness is therefore its
  own boot mode with its own `await`-driven step loop, and the parts of it that are pure
  (the step table, the assertion formatting, the convergence predicates) are registered
  in the synchronous suite so they are still covered on every boot.
- **Two peers in one process is possible, and still the wrong default.** Godot 4 supports
  a second `MultiplayerAPI` bound to a separate node subtree, so both peers could live in
  one process and the driver could read each side's state directly. The recommended shape
  is nonetheless TWO PROCESSES over loopback, because it drives the production path
  unmodified — the same `--server` / `--client` args the game ships with, the same
  `NetworkingSlice.host()` / `join()`, real ENet peer-id reassignment — so an edit that
  only works in-process is caught here rather than in the wild. The in-process variant
  stays available as a fallback if log-driven comparison proves brittle.
- **The comparison channel is a canonical log line, not shared memory.** Each process
  prints one structured line per completed step (`HARNESS <step> <ok|refused> <detail>`)
  and the driver asserts the host's and the client's lines agree. A text channel is what
  lets the same scenario run against two processes, and it is the only channel that
  survives a role flip.
- **The Phase 19 network emulator is already here, and this is NOT where it earned its
  keep.** `NetworkingSlice` carries `emulate_network`, `emulator_loss_rate`,
  `emulator_jitter_ms` and `emulator_reorder`, and this note used to say the scenario should
  run at least twice — once clean, once through the emulator. **Review pass: it does not,
  and a second pass through that emulator would not have proven what the note promised. The
  emulator drops and reorders packets BEFORE `_send_raw`, inside this process, so nothing it
  does is socket loss: the packet never leaves the machine. A pass through it would test the
  dedup and reassembly rules against an IN-PROCESS queue, which the routing-level suite
  already covers cheaply. Reordering and loss over a real socket stay deferred with the WAN
  validation (Phase 19), and the criterion above says so instead of borrowing confidence
  from this.**
- **Determinism beats coverage.** A wire test that flaps is worse than no wire test: every
  step asserts on convergence (a predicate plus a bounded number of ticks) rather than on
  a fixed frame index, and every step carries a deadline that fails loudly instead of
  hanging CI.

**Known simplifications (deferred):**
- **The bare-`await` audit is a SOURCE check, and it says so when it cannot run.** The
  runner reads its own `res://` file at start-up (a source boot, which is what the driver
  launches) and prints `source-not-on-disk-skipped` when it cannot — never a pass — because
  an audit that did not run is not evidence. What it cannot see is a bare coroutine call in
  another file: the rule is enforced on this runner, not repo-wide.
- **The un-handshaked refusal is still a routing-level assertion.** The harness cannot put
  an intent on the wire before the handshake: the client's boot presents its join intent the
  moment the connection comes up, so there is no window in which a real peer is connected
  and un-handshaked. That half of the identity criterion stays with `_route_c2h`'s unit
  tests.
- **The snapshot buffer's host-loss clear is asserted on the client's own teardown, not on a
  real host loss.** `disconnect_all()` is what the reconnect step exercises; the
  `_on_server_disconnected` path needs the HOST to die mid-snapshot, which this driver does
  not do (the host is the process the driver waits on).
- **Loopback only.** Two processes on one host exercise real ENet framing and the real
  handshake, but not latency, MTU discovery or NAT behaviour. WAN / cross-region testing
  stays deferred from Phase 19.
- **No soak.** The harness runs a scripted session, not a long-lived one: memory growth
  under hours of churn (the Phase 37 eviction classes) is still argued from the eviction
  sites rather than measured.
- **The harness does not replace the routing-level tests.** Those stay: they are cheaper,
  they pin the refusal itself, and they run inside the suite the project already gates on.
- **A peer's death is still not resolved host-side.** Deliverable 1 makes the floor
  recoverable — a downed peer's HP returns to full after the delay instead of freezing at
  zero — but nothing happens TO the peer at zero: no corpse, no loot, no kill credit. The
  death consequence stays deferred past this phase.

---

## Phase 40 — Review pass: the avatar's footing — the voxel surface, walked stairs ✅ Done

**Goal:** The controller stands on the VOXEL columns (collision layer 2, quantised to
`STEP_HEIGHT` 0.125), but everything drawn from it was sampled and placed off the other,
legacy surface — and off the wrong quantity. A review of that seam found the avatar's whole
body offset by the hip height into the ground, the foot sampler reading a heightmap the
body does not collide with, and the controller unable to walk up a single voxel rise: it
stopped dead at the foot of every step. This phase puts the visual avatar exactly where its
collision is, gives the body a step-up so a stair is WALKED rather than blocked, and renames
the foot-IK return value whose name collision caused the first of those bugs.

**Deliverables / verifications:**
- `src/character/character_slice.gd` — `sync_player_avatar` places the avatar's rig root at
  the sampled surface height. The root sits at the FEET (`_make_avatar` places every body
  part at `landmarks["hip_y"]` ABOVE it), so the old
  `maxf(foot_l.y, foot_r.y) - landmarks["hip_y"]` subtracted the LOCAL hip offset from a
  WORLD surface ordinate — read off the landmarks dict, because the foot targets' own world
  hip ordinate used to carry the same key name. The avatar stood ~0.81 below the ground it
  was standing on; RED-proved against the restored expression (`got 1.192500, want
  2.000000`). Registered `character: avatar root Y matches voxel ground`.
- `src/character/skeleton_rig.gd` — `compute_foot_targets` now returns `hip_world_y`. The
  returned value is a WORLD ordinate and `compute_landmarks()` already publishes a LOCAL
  `hip_y` offset, so the two can no longer be confused by name — the collision that produced
  the bug above, made impossible rather than merely fixed.
- `src/core/game_root.gd` — `_sync_player_avatar` samples `_voxel.get_voxel_height_at`
  instead of `_terrain.get_height_at`. The voxel sampler is the same function the collision
  boxes are built from (`_column_height`), so the visual feet track the surface the body
  actually stands on; the raw noise heightmap sat up to a step away from its own collision.
- `src/player/player_slice.gd` — `_build_body` sets `floor_snap_length = STEP_UP_HEIGHT`
  (0.3, i.e. MORE than one quantised step of 0.125): the 0.1 default is shorter than the
  rise the step-up climbs, so the body took the rise and then immediately lost its floor,
  going briefly airborne on every stair.
- `src/player/player_slice.gd` — `_move` climbs a stair: grounded, moving, and touching a
  wall, it asks the pure `resolve_step_up(blocked, xform, horizontal, step_height)` whether
  the rise can be cleared — `test_move` up by one step, then the horizontal cast from up
  there — and takes the risen+advanced position when both are clear. No vertical velocity is
  added and the horizontal velocity is untouched, so it is a walk, not a jump, and a rise
  taller than `STEP_UP_HEIGHT` is left alone. `move_and_slide()` (with the longer
  `floor_snap_length`) then settles the body onto the new surface. Registered
  `player: step-up climbs a rise, not a wall`.
- The findings' ALTERNATIVE to the above — a `SeparationRayShape3D` under the capsule for
  automatic stair climbing — was NOT taken: it is presented as the alternative to the
  `test_move` step-up and the two are mutually exclusive, so implementing both would be two
  mechanisms for one behaviour.
- `src/tests/test_suite.gd` — the two regression tests above, and the suite stays green on
  both boot paths: `Results: 7532/7532 passed (0 failed)` (+10 assertions from 7522).
- `README.md` — the phase table row for this pass.

**Implementation notes:**
- **The synchronous suite has no physics frame — verified, not assumed.** A probe run in the
  suite's own context (a node added under the tree, probed from `_ready()`, project physics =
  Jolt) shows `move_and_slide()`, `is_on_floor()` and `test_move()` all inert: a body dropped
  over a static floor for 200 cascaded calls never registers a collision, reports
  `on_floor = false` and does not move at all. So the findings' two suite tests are split
  deliberately: the root-Y one is a real assertion through `sync_player_avatar`, while the
  stair one asserts the pure DECISION (`resolve_step_up`) against a fake `blocked` Callable
  — the same Callable-injection shape `compute_foot_targets` already uses for terrain
  sampling — and the physics half is exercised in game only. What the suite proves is that a
  one-step rise is advanced through with a rise of exactly one step-up (never more), that a
  taller rise is refused with the body unmoved, and that an unblocked move is not a step-up
  at all.
- **The step-up is a position, never a velocity.** `resolve_step_up` returns a transform and
  the caller assigns it; `_vel` keeps the input's horizontal value and gravity's vertical one,
  which is what keeps the climb a walk. Adding a vertical impulse would have been the
  obvious-looking shortcut and is exactly the "jump" the finding rules out.

## Phase 41 — Deterministic world and volumetric terrain ✅ Done

**Goal:** Every boot generates a different world, and every column is one solid
height with nothing above it. `TerrainSlice._noise.seed = randi()` means the
ground a save was written against cannot be regenerated: a host and a client can
only agree on the world by shipping heightmaps, a reload lands the player on
different hills, and two players who share a seed still get different terrain.
At the same time the terrain is a pure heightfield — one top face per column and
walls down to whatever the neighbour's top is — so anything that should have a
CEILING (a tunnel, a cave, an overhang, a roofed build) either cannot be carved
or renders as a hole, the collision is per-row merged boxes that cannot describe
a span of solid material, `MIN_HEIGHT` (`0.0`) is "bedrock" only in the sense
that mining stops at zero rather than at a depth, the saved edits are a bare
scalar height per tile, and the avatar's footing sampler (Phase 40's
`get_voxel_height_at`) returns the TOP of a column — which under a roof is the
roof itself. This phase makes the seed a persisted fact, turns a column into a
sparse run of solid spans so ceilings exist and collide, gives the ground a real
bedrock depth, and migrates the edit/save format the change invalidates.

**Newel dependency:** None. No fabric field changes — `pnpm validate` is clean
(IR v3.0.0) and `pnpm check-drift` reports 543 file(s) matching the manifest.

**Closes:** item 1.

**Deliverables:**
- `src/terrain/terrain_slice.gd` — the seed is injected
  (`set_world_seed(seed)`) instead of sampled with `randi()`, so the same seed
  plus the existing fixed `BIOME_SEED` reproduce every height. Biome assignment
  is already deterministic per chunk (`get_biome_at_chunk`); heights are the only
  non-determinism, and this closes it. The seed travels on the world save and in
  the join snapshot, so a client regenerates the host's terrain rather than
  receiving heightmaps.
- `src/terrain/voxel_slice.gd` — the column becomes a SPARSE list of solid runs
  (`[{ bottom, top }]`) instead of one top ordinate plus the per-column
  colour-layer accessor it used to be read through. Both of those accessors
  (`_column_color`, `_column_layers`) became dead once the mesher tinted each RUN,
  and the review pass removed them; the suite now asserts the colours off the runs
  it renders. Only
  solid spans are stored, so a plain column is still a single entry and only a
  real tunnel costs a second one.
- `src/terrain/voxel_slice.gd` — the mesher emits a face wherever a neighbour run
  ends above the local run. That is the mirror of the rule it already implements
  ("a face exists where a neighbour is lower") and it is what makes a tunnel roof
  a rendered, ordinary surface rather than a hole. `cull_mode = CULL_DISABLED`
  stays, so the shell is never see-through regardless of winding.
- `src/terrain/voxel_slice.gd` — collision becomes a `ConcavePolygonShape3D`
  built from the same triangle soup the mesher produces, so ceilings and
  overhangs collide. `TERRAIN_COLLISION_LAYER` (2) is unchanged, so the player's
  block ray still targets terrain.
- `src/terrain/voxel_slice.gd` — a real bedrock depth (`BEDROCK_DEPTH` below the
  surface range, replacing `MIN_HEIGHT := 0.0` as the mining floor). Ground gains
  thickness; mining descends one `STEP_HEIGHT` at a time until the floor is
  reached, and `MAX_HEIGHT` (16.0) remains the build cap.
- `src/terrain/voxel_slice.gd` + `src/persistence/persistence_slice.gd` — the
  `_edits`/save migration. An edit was `{"tx,tz": absolute quantised height}`;
  it becomes a typed run edit (add/remove a span), a world save carries a format
  version, and a pre-Phase-41 save loads with its edits present (a scalar height
  becomes the single run from bedrock up to that height).
- `src/core/game_root.gd` — the avatar sampler gains a second mode:
  `sample_support_height_at(world_xz, from_y)` returns the top of the highest run
  at or below `from_y`, and `_sync_player_avatar` uses it, so an avatar inside a
  tunnel stands on the tunnel floor. Phase 40's step-up, its pure
  `resolve_step_up`, and `floor_snap_length = STEP_UP_HEIGHT` are unchanged.

**Acceptance criteria:**
- [x] Two runs with the same seed produce identical heightmaps per chunk (assert
  a `hash()` of the heightmap array — `terrain: the world seed determines the
  terrain` also asserts a different seed differs), and a client's terrain matches
  the host's with no heightmap in the snapshot: the snapshot carries `seed`, and
  the client adopts it and streams its OWN chunks.
- [x] A column can carry two or more solid runs: a chunk with a tunnel emits a
  downward face (a ceiling), and the trimesh collision is built from that same
  soup — `voxel: a tunnel keeps its floor and its roof` asserts the face is in
  `VoxelSlice.collision_faces`. What stops a body through it is exercised in GAME
  only: the suite has no physics frame (ROADMAP §Phase 39).
- [x] Mining a tunnel roof does not remove the tunnel floor; mining at
  `BEDROCK_DEPTH` is refused while mining one `STEP_HEIGHT` above it succeeds
  (`voxel: a tunnel keeps its floor and its roof`, `voxel: mine at bedrock fails`).
  An UP-face hit resolves to the run it actually landed on, so the tunnel FLOOR is
  aimable too (review pass: `voxel: a tunnel floor top face mines the floor`).
- [x] A save written before this phase loads with its edits intact
  (`voxel: a legacy save migrates to run edits`, which applies a version-1 manifest
  — scalar heights plus the placed-material stacks — and reads the edits back), and
  `pnpm check-drift` is clean: `✓ No drift detected (543 file(s) match manifest)`,
  no fabric change. The MIGRATION keeps the placed-material stack in every case,
  including the re-rolled-seed one (review pass: `voxel: a re-rolled legacy save
  keeps its stack`).
- [x] The suite is green on both boot paths: `Results: 7612/7612 passed  (0 failed)`
  on the listen host and the same `7612/7612` on `-- --server` (which also prints
  `[Server] listening on port 7777`), `tools/net_harness.sh` is `10/10 steps agreed`
  on a FRESH world (`XDG_DATA_HOME=$(mktemp -d)`, the CI shape), and
  `character: avatar root Y matches voxel ground` still passes,
  plus the under-a-ceiling case (`voxel: the support sampler honours a ceiling`).
  The review pass added six suite tests for the edit path's edge cases (the
  migration case named above included, plus
  `voxel: the edit log is compacted`, `voxel: an unknown edit op is ignored`,
  `voxel: an edge edit rebuilds the neighbour chunk`, `voxel: unload prunes the
  heightmap to the ring`, `voxel: a snapshot rebuilds only what changed`) and
  turned the seam test into a GEOMETRY assertion.

**Implementation notes:**
- **The seed is the world's identity, so it is persisted, not sampled.** It
  belongs on the WORLD save (`persistence_slice`), not on a player record: two
  players in one world must regenerate the same ground, and a client that cannot
  reproduce the host's terrain is a client whose voxel edits land elsewhere.
- **Sparse runs are what keep a deep world cheap.** Storing "only solid spans"
  means a column surfaced at 2.0 over bedrock at -32.0 is ONE run, not hundreds
  of entries, so the memory cost of a real depth is unchanged and only an actual
  tunnel (two runs) pays a second entry.
- **Trimesh collision replaces the merged boxes deliberately.** The per-row
  run-merge existed because `TILE_SIZE` 0.5 would otherwise emit 4096 boxes per
  chunk; one `ConcavePolygonShape3D` per chunk is smaller than a handful of boxes
  and describes everything the boxes never could. Nothing in this project stands
  a `CharacterBody3D` on terrain via a concave shape directly — the body collides
  with the static shape, which is the supported direction.
- **A save migration is a deliverable, not a nicety.** The load path must be
  tolerant of the old key shape and must never silently drop an edit; a migration
  that "repairs" a world by discarding player work is worse than a refusal.
- **The footing sampler must not be allowed to answer with the roof.** The
  sampler is a function of the body's own Y for exactly this reason; a
  column-top sampler is only correct in a world with no ceilings, which is the
  world this phase ends.
- **`BEDROCK_DEPTH` is `-8.0`, and the world floor slab moved under it.** The
  terrain's surface range is `[0, HEIGHT_SCALE]` = `[0, 5.0]`
  (`TerrainSlice.HEIGHT_SCALE`; `MAX_HEIGHT` 16.0 is the BUILD cap, not the ground),
  so eight units of rock is a real thickness
  rather than a hair: it is 64 `STEP_HEIGHT` steps of descendable ground. The
  dormant `WorldFloor` safety slab was at `y = -0.5` — INSIDE the new ground —
  and would have blocked a player mining below it, so it now sits at
  `BEDROCK_DEPTH - 0.5`: still the thing that catches a body if the terrain ever
  fails, and no longer in the way of the floor the phase adds.
- **The join snapshot carries the seed instead of the heightmaps, so the client
  starts its own chunk streaming.** `_build_snapshot` sends `seed` (the world's
  identity) and the chunk-edit manifest; `_on_world_snapshot_received` adopts the
  seed, applies the edits, then `_chunk_manager.start()` / `refresh()` around the
  position the record restored. Two consequences worth naming: the client's world
  is now its OWN view window rather than whatever the host had loaded, and TREES
  need no placement payload at all — `TreeSlice.spawn_for_chunk` derives them per
  chunk coordinate on both sides, exactly the rule tree seeding already followed
  (only a tree's chopped/standing STATE is replicated). CREATURES are NOT in that
  category and do not need to be: `CreatureSlice.spawn_for_chunk` is
  authoritative-only, so the client places the host's creatures from the snapshot
  (`apply_snapshot_creatures`) as it always did. A client that did NOT stream would
  boot into an empty world with the right seed, which is why the start call lives
  at the end of the snapshot handler, after the player's position.
- **The world record's `version` is a marker, not a gate.** `WORLD_FORMAT_VERSION`
  is 2 and a pre-Phase-41 record simply has no `version` key
  (`LEGACY_WORLD_FORMAT_VERSION`). The load path never branches on it: the
  manifest shape itself is tolerant (`apply_edits` adopts an Array of typed edits
  and MIGRATES a bare number against the tile's natural run), because a migration
  that "repairs" a world by discarding player work is worse than a refusal. The
  version is there so a future shape can be told apart, and so the boot can say
  which world it loaded.
- **A column's runs are replayed from the tile's natural run, so the migration
  needs the ground.** `_base_top_for_tile` answers from the chunk's heightmap when
  it is built and from `TerrainSlice.get_height_at` when it is not — the same
  height by construction, which is what lets a load-time migration run BEFORE
  chunk streaming (the boot order) without guessing. This is also why
  `game_root._load_world_records` adopts the recorded seed first: the migration of
  a legacy edit is measured against the noise field the save was written on.
- **An unknown neighbour is read as EMPTY, so the shell does not depend on the
  order chunks were built.** The mesher used to answer `0.0` for any tile outside
  the chunk and therefore built a full-height wall at every seam and around the
  streamed window; this phase first made it answer `null` (emit no wall), on the
  argument that "the side that HAS the material emits the facing wall". That
  argument does not survive the STREAMING order the same phase leans on
  (`DEFAULT_LOADS_PER_FRAME := 1`, nearest-first): the neighbour a chunk waits for
  is very often built LATER, so a chunk built before its higher neighbour emitted
  nothing at that seam — and nothing rebuilds a chunk when its neighbour arrives,
  which left every such seam (and the window's whole outer edge) see-through
  (measured: 0 seam faces before the neighbour arrives, 128 after a rebuild). It
  now reads an unknown neighbour as an empty list, so the column carrying the
  material always emits the facing wall. That is duplicate-free whichever side is
  built first — the second side subtracts the first and finds nothing left to
  emit — and a wall buried inside ground both sides fill is invisible, so the
  rendered shell is the same set of faces in either order. The streamed window's
  outer edge is therefore a closed cross-section again, as it was before the
  phase.

- **An UP-face hit names the run it LANDED on, not the column's topmost one.** The
  rule is one line away from the wrong answer, and the wrong answer is what the
  phase's own new capability creates: a tunnel FLOOR keeps an exposed top face with
  the roof above it, so "the column's topmost run" resolves a click on the floor to
  the ROOF — mining the floor took the roof's last step and stacking on the floor
  put the block on the roof. `VoxelSlice.runs_topping_at(runs, y)` picks the run
  whose top is the hit plane (half a step of tolerance) and answers `{}` for a y
  that sits on no run boundary — the fallback to the topmost run is the CALLERS'
  (`_mine_span` / `_place_span`), not the helper's, and it is what keeps a
  misaligned y behaving exactly as it did before (the boot demo passes the spawn
  plain's height, not the target tile's). Both ask it.
  Review pass: `voxel: a tunnel floor top face mines the floor`.

**Review pass — the edit path's edges (all landed from the numbered findings list):**
- **A chunk's mesh depends on the columns ACROSS its edge, so an edit rebuilds the
  neighbour chunk too.** A wall face is the difference between a column's runs and
  its neighbour's, so a tile on a chunk boundary is a neighbour column to the next
  chunk's tiles, and editing it changes what THEY emit. Rebuilding only the edited
  tile's own chunk left the neighbour drawing the wall it had: a see-through slot
  where a seam tile was carved open (mine a tunnel into a seam tile and the mouth
  stays blind) and a ghost wall where the difference grew the other way. Nothing
  else rebuilds a chunk when its neighbour changes, so it stayed all session.
  `_rebuild_chunk_at_tile` now rebuilds the tile's own chunk plus the four
  edge-adjacent chunks' — one build in a chunk's interior, at most three at a
  corner, and the mesher's runs memo below is what pays for the extra ones.
- **The edit log is BOUNDED (`MAX_TILE_OPS` 8, `_compact_ops`).** Ops stay an
  append-only log — an edit says what the player DID — but a log with no bound
  grows forever: mine and rebuild the same block and every click adds a replay step
  to every column read (meshing, the collision soup, the footing sampler, the save
  manifest) and to the save itself, and the replay is O(ops) per read. Past the cap
  the list is rewritten as the minimal description of what the column IS (bounded
  by its run count: one remove plus one add per run), and a column that is back to
  its natural self is compacted AWAY. RED: 40 ops after twenty mine/place cycles.
- **The mesher resolves each tile's runs ONCE per chunk build.** Every tile's runs
  were read by the tile itself AND by each of its four neighbours' wall
  subtractions — about six resolutions per column per chunk. The runs are a pure
  function of the tile's heightmap plus its edits, so a per-build memo keyed by
  global tile key (`_column_runs(..., cache)`) is exact and cannot go stale inside
  the build; `vein_deposits` walks the same chunk and passes the same memo.
- **The migration keeps the placed-material stack in EVERY case.** `legacy_edit_ops`
  used to collapse a column whose saved top sat further above the CURRENT base than
  the stack is tall — the re-rolled-seed case, where a version-1 world's ground is
  generated afresh under an edit written against another noise field — into one
  anonymous natural span, which repaints a player's placed blocks as natural
  ground. The natural span is now re-added up to the stack's own base and the
  materials sit on top of it, still theirs.
- **An edit op this version does not understand is DROPPED, never defaulted.**
  `_normalise_ops` keeps only `add` / `remove` and `apply_run_ops` ignores anything
  else: the two kinds are not symmetric (one fills, one carves), so reading an
  unknown kind as `remove` turns a damaged save into silent terrain damage.
- **`apply_edits` is the RE-SCOPE path, so it rebuilds only the chunks whose edits
  CHANGED — and only the ones that are LOADED.** A re-scope snapshot re-sends the
  manifest a client already applied (or one that differs in a chunk or two), and
  rebuilding every held chunk for that is a whole-frame stall per scope change
  (`_ops_equal` compares op lists field by field, since JSON hands back `int` or
  `float` for the same span). A chunk that is not loaded has no mesh to refresh,
  and building it resurrects a node `ChunkManager` has already streamed away and
  will not stream out again.
- **The base heightmaps are bounded by the loaded window plus its one-tile ring.**
  They were kept for the whole session so a streamed-out neighbour could still
  answer with its real runs, which held every chunk the player ever walked past in
  memory. `unload_chunk` now prunes to the window + ring: that is exactly the set a
  VISIBLE chunk can ask a neighbour about, so a loaded chunk still subtracts
  against real runs, while a chunk outside the ring reads as UNKNOWN — the
  documented, order-independent empty-neighbour path. Nothing is lost with the map:
  edits are keyed by TILE, and the natural run comes from the same height function
  the map was sampled from.
- **Dead accessors removed, and the surviving one says what it is.**
  `get_edit_materials` (no caller anywhere), `_column_color` and `_column_layers`
  (both superseded by the mesher's per-run tint, kept alive only by the suite) are
  gone, and their assertions now read the colours off the runs the mesher tints.
  `get_voxel_height_at` STAYS — it is how a column's shape is asserted, and it is
  the read a caller outside a tunnel means — but its docstring now says what it is
  (a column TOP, not the surface under a body's feet) and names the footing read
  production actually uses (`sample_support_height_at`).
- **The seam test asserts GEOMETRY, not a triangle count.** A wall emitted across
  the wrong ordinates has the same count as the right one, which is what the old
  `_faces_on_plane_x` comparison could not tell apart; `_plane_x_spans` compares the
  distinct vertical spans on the seam plane (and that the pair of facing walls is
  still ONE wall, not two).

**Known simplifications (deferred):**
- **No greedy meshing yet.** The mesher still emits one quad per tile; Phase 42
  threads that build and merges the coplanar quads. Deferred deliberately so this
  phase's diff stays about the world's SHAPE.
- **A version-1 world re-rolls its ground once, on the boot that loads it.** A
  pre-Phase-41 world record has no seed — it was generated from `randi()` — so the
  ground cannot be reproduced at all: the boot says so
  (`world record carries no seed (format 1) — adopting the fresh seed …`) and the
  next save pins that seed, so the shift happens once and never again. The saved
  EDITS survive structurally (that is the migration), but a legacy edit's span is
  measured against the new noise field, so it can land on a different hill.
- **No 3D material model.** Runs say where solid material is; which material a
  span yields is still the per-biome table (`BIOME_MATERIALS`), which Phase 43
  replaces with a 3D ore field.
- **No procedural caves.** Tunnels exist only where a player or a build makes
  them; a cave noise function is not this phase's job.
- **The world remains finite** (`WORLD_RADIUS_CHUNKS` 128) and the spawn-plain
  flattening remains a special case inside the height function.
- **One trimesh per chunk, rebuilt whole on every edit.** A `ConcavePolygonShape3D`
  has no spatial split, so mining one tile re-serializes that chunk's whole surface
  (mesh + collision). Phase 42 threads that build and merges the coplanar quads.

---

## Phase 42 — Threaded chunk build and a loading screen ✅ Done

**Goal:** A chunk build is the most expensive thing this game does, and it still
runs on the main thread. `ChunkManager` already time-slices it
(`DEFAULT_LOADS_PER_FRAME := 1`), which SPREADS the stall across frames instead of
removing it: every boundary crossing spends its budget inside the render loop,
the boot's first-ring chunks are built one per frame while the player is already
standing in the world, and the mesher emits one quad per tile (4096 quads per
chunk at `TILE_SIZE` 0.5) because nothing merges coplanar faces. This phase moves
the pure build onto `WorkerThreadPool`, merges the coplanar quads greedily so the
worker is cheap, gates the first ring behind a loading screen so the body is
never placed on ground that does not exist yet, and widens the prefetch so a
chunk is queued further out than it is needed.

**Newel dependency:** None. No fabric field changes — `pnpm validate` is clean
(IR v3.0.0) and `pnpm check-drift` reports 543 file(s) matching the manifest.

**Closes:** item 2.

**Deliverables:**
- `src/terrain/voxel_slice.gd` — a PURE build.
  `build_chunk_arrays(chunk_pos, heightmap, runs) -> Dictionary` returns the
  `ArrayMesh` surface arrays (vertices/normals/colours/indices) and the collision
  vertex arrays, touching no node, no bus and no slice state. `build_chunk()`
  keeps its signature and becomes the consumer: it takes either a map or those
  arrays and does the tree work.
- `src/terrain/voxel_slice.gd` — greedy quad merge inside the pure builder:
  coplanar, same-material quads merge into rectangles over the tile grid (the
  classic greedy meshing pass), cutting the per-chunk vertex count by an order of
  magnitude. The merge key is material/colour, which is exactly the attribute a
  merged quad has to share.
- `src/terrain/chunk_manager.gd` — the build dispatches to
  `WorkerThreadPool.add_task` and polls (`is_task_completed`); results are
  applied on the main thread. The worker owns no mutable slice state.
- `src/terrain/chunk_manager.gd` — a first-ring gate:
  `build_first_ring(center)` / `is_first_ring_ready()` /
  `first_ring_progress() -> float`. The ring is Chebyshev distance 0..1 (9
  chunks) around the centre; the body is not placed until it exists.
- `src/ui/loading_screen.gd` (new) — a CanvasLayer panel with a progress bar,
  shown while the gate is unmet, with world input frozen through the loading
  screen's OWN explicit input-freeze hook — not through
  `UIControl.any_window_open()`. That predicate answers only for the panels the
  UI slice holds (`src/ui/ui_slice.gd:107`) and a loading screen is not one of
  them, so it covers nothing here; `PlayerSlice._input` gates world actions on
  the mouse-capture state (`src/player/player_slice.gd:162`), which the loading
  screen must drive itself while it is up.
- `src/terrain/chunk_manager.gd` — a wider prefetch ring
  (`DEFAULT_PREFETCH_DISTANCE = view_distance + N`): the load ring leads the view
  ring so a crossing never requests a chunk at the moment it becomes needed.

**Acceptance criteria:**
- [x] A chunk build does not run on the main thread: a frame-time probe across a
  boundary crossing shows no single frame carrying the build cost, and the
  builder is asserted directly by the suite as a pure function of its arguments.
  *(Landed: `ChunkManager._dispatch_build` hands `VoxelSlice.build_chunk_arrays` to a
  `WorkerThreadPool` task and `_process` applies the result on the main thread. The
  suite test "chunk: the pure builder is a function of its args" builds one chunk twice
  — the second time with a VoxelSlice carrying an unrelated place material and an edit in
  another chunk — and asserts identical vertices, indices and collision soup. The
  frame-time probe itself was NOT written: what is asserted is that the dispatch happens
  and that the main thread never runs the build, not a measured per-frame millisecond
  figure. **(Second review pass: `PROBE Phase 42 build split` now prints the main-thread
  half of a dispatch — heightmap generation plus column-table resolution — against the pure
  builder the worker runs, so the split is a measured number rather than a claim. A true
  per-FRAME millisecond figure still needs a frame-driven boot, which the synchronous suite
  deliberately is not.)** **(Eighth review pass: the probe ASSERTS the ratio now, and it
  measures the other half of the main thread's work too — the apply path (`_mesh_from_arrays`
  plus the collision `set_faces`) is inside the main-thread total, and three passes are summed
  because the gap is under 2x. Measured: main 130071 us (resolve 126938 + apply 3133) against
  the worker's 235263 us, i.e. 1.81x. The criterion's other half — the builder is a pure
  function of its arguments — was VACUOUSLY tested until this pass: the test built the SAME
  resolved table twice, so its second, differently-stated slice was dead setup. It now resolves
  the chunk from both slices and builds from each.)** **(NINTH review pass: the resolve moved
  OFF the main thread, and the probe asserts an absolute ceiling as well as the ratio. The
  per-pass figures showed the main-thread half at 44900 us per dispatch — 2.7 frames at 60 Hz —
  so the criterion's own headroom was gone even though the ratio passed; `gather_build_input()`
  copies the resolve's inputs and the STATIC `build_runs()` resolves on the worker, which brings
  the main-thread half to 2539 us steady state (generate+gather 1634 us) against a worker half of
  77159 us, and the assertion is now `steady_main < 16667 us` — one dispatch per frame, inside
  one frame. The per-frame millisecond figure this criterion originally wanted is therefore
  answered for the DISPATCH; what still needs a frame-driven boot is the world's whole frame
  budget.)**
- [x] Greedy merge cuts the per-chunk vertex count (quote the before/after
  number), and a tile whose neighbours differ still emits a valid 1×1 quad.
  *(`cell_count` → `quad_count`, measured in the suite's "chunk: greedy merge collapses a
  flat chunk": a flat chunk with no built neighbours goes 4352 faces → 5 quads, and a
  natural noise chunk with its ring built goes 7568 faces → 3760 quads. The vertex win is
  larger than the quad win because the quads are now INDEXED: the natural chunk emits
  15040 vertices where the per-tile mesher emitted 45408 (6 duplicated per quad). The 1×1
  case is asserted on the pure sweep: a lone cell is its own rectangle, a hole splits a
  row, and a row below extends it.)*
- [x] Booting against a fresh `user://` (empty world) shows the loading screen
  and does not place the player body until the first ring's chunks are built.
  *(`_boot_host()` shows the screen and defers the whole host tail to
  `_tick_pending_host_boot()`; the tail runs from `_process` the frame the gate opens.
  Verified against a fresh `XDG_DATA_HOME`: `[World] first ring built (9 chunks) —
  placing the player, 19.66s after boot`. The screen's own visibility is not asserted by
  the suite — it is a node in the tree on both boot paths and has no headless frame to be
  seen in. **(Second review pass: it IS asserted now — `ui: the loading screen shows and
  hides` drives `begin()` / `set_progress()` / `finish()` and asserts the visibility, the
  bar and the `world_input_frozen` emissions directly, which needs no frames. The CLIENT
  path arms the same gate, so the body is no longer placed on unbuilt ground on a join.)**
- [x] No world input resolves while the loading screen shows: an attack, mine,
  chop or place attempted with the screen up is refused. The freeze is the
  loading screen's own hook — `any_window_open()` is not consulted and would
  answer `false`.
  *(`GameBus.world_input_frozen` → `PlayerSlice.set_world_input_frozen`, consulted by the
  single predicate `PlayerSlice.world_input_allowed()` that `_input` now gates every world
  action on. Suite test "player: the loading freeze refuses world input" drives the signal,
  asserts `world_input_allowed()` is false while frozen, and asserts `any_window_open()` is
  false at that moment — i.e. that the window predicate could not have been the gate. A
  headless boot has no mouse capture at all, which is why the freeze is assertable
  separately from the mouse half of the predicate.)*
  **(Second review pass: the freeze holds the BODY too — `PlayerSlice._physics_process`
  skips `_move` while frozen, asserted by `player: the loading freeze holds the body`. It
  has to: a joining client's body exists from the snapshot while its ring is still being
  built, so an input-only freeze left it falling through ground that was not there.)**
- [x] The suite is green on both boot paths, with tests for the pure builder and
  the merge registered in `test_suite.gd`.
  *(`Results: 7663/7663 passed (0 failed)` + `All tests passed ✓` on both
  `--quit` and `--quit --server`; seven new tests registered in the `_run_test` list
  (builder purity, merge counts, merge-never-spans-a-gap, dispatch-then-apply, the
  first-ring gate, the prefetch radius, the loading freeze). **Re-run after the review
  pass: `7682/7682 passed (0 failed)` on both boot paths** — five more tests, one per
  closed finding that is assertable in the suite. **SECOND review pass: `7716/7716 passed
  (0 failed)` on `--quit` and on `--quit --server`, no `SCRIPT ERROR` — seven more tests
  (a rebuild respects the in-flight cap, a queued chunk that leaves range cancels, a
  groundless chunk is re-armed, contents spawn once the ground exists, the build split
  probe, the loading freeze holds the body, the loading screen shows and hides), plus the
  probe that prints the main-thread / worker split.) **THIRD review pass: `7735/7735 passed
  (0 failed)` on `--quit` and on `--quit --server`, no `SCRIPT ERROR` — five more tests (a
  stationary player re-arms a failed chunk, unloading drops a queued rebuild, an edit does
  not re-spawn contents, a drain reads the window once, and a boot quits when its world is
  up).** **FOURTH review pass: `7760/7760 passed (0 failed)` on `--quit` and on
  `--quit --server`, no `SCRIPT ERROR` — six more tests (a failed REBUILD of an already-built
  chunk heals, the stationary throttle suppresses a re-arm, a crossing stamps the self-heal
  clock, the self-heal reads the window once, an idle drain reads no position, and a rig
  dispatch keeps contents per residency).** **FIFTH review pass: `7787/7787 passed (0 failed)`
  on `--quit` and on `--quit --server`, no `SCRIPT ERROR`, and `10/10 steps agreed` from the net
  harness — five more tests (a remote mine credits the actor, a remote place spends the actor's
  own pack, a remote chop credits the actor, a re-scope rebuilds a changed tile's seam, and an
  edit never resurrects an unloaded chunk).** **SIXTH review pass: `7809/7809 passed (0 failed)`
  on `--quit` and on `--quit --server`, no `SCRIPT ERROR` — two more tests (a legacy edit of an
  unknown shape is dropped, an incremental save can delete a chunk), and no test count lost to a
  probe abort in the final run.** **SEVENTH review pass: `7811/7811 passed (0 failed)` on `--quit`
  and on `--quit --server`, no `SCRIPT ERROR`, and `10/10 steps agreed` from the net harness on
  three consecutive fresh-world runs — one more test (the terrain material is one instance), one
  harness hardening (step 4 waits for a distant tree, bounded by `STEP_TIMEOUT_SECS`, instead of
  reporting `no_distant_tree` at whatever instant it arrives), and a doc correction (the quick start
  now says `npm`, which is what CI runs). **EIGHTH review pass: `7833/7833 passed (0 failed)` on
  `--quit` and on `--quit --server`, no `SCRIPT ERROR`, and `10/10 steps agreed` from the net harness
  on a fresh world — three more tests (the kept window is the view ring, apply_edits dispatches a
  rebuild, flush_builds awaits its retries), plus the split probe promoted from a print to an
  assertion (`main-thread half 130071 us` — resolve 126938 + apply 3133 — `against the worker's
  235263 us`, 1.81×).** **NINTH review pass: `7870/7870 passed (0 failed)` on `--quit` and on
  `--quit --server`, no `SCRIPT ERROR`, and `10/10 steps agreed` from the net harness on a fresh
  world — six tests added (or renamed: the kept window is the stream radius, a direct load
  respects the in-flight cap, the gathered payload carries the ring, the group key survives the
  colour band, the biome roll table is prebuilt, the build payload shape is required), the kept
  window widened
  back to the queue radius (`DEFAULT_PREFETCH_DISTANCE` 2 → 1, so a band chunk is no longer built
  and then thrown away), and the RESOLVE moved off the main thread: the dispatch's main-thread
  half measured 44 900 us before and 2 526 us after (generate+gather 1 631 us) against a worker
  half of 77 159 us, with the probe now asserting that half inside ONE 16 667 us frame.** ***
  **TENTH review pass: `7883/7883 passed (0 failed)` on `--quit` and on `--quit --server`, no
  `SCRIPT ERROR` (+13 assertions from a new biome-coverage test and a second, POPULATED-edit-log
  pass in the split probe) — the edit log is now INDEXED BY CHUNK, so a dispatch's gather walks
  only the chunks it can reach instead of string-splitting every edit in the world
  (`generate+gather` with 102 400 world edits: 44 012 us → 5 568 us, the old figure over TWO
  frames), and the probe asserts the frame ceiling on that populated log; the first-ring gate
  recomputes from `_built`, `_biomes_or_lookup` resolves a miss instead of falling back to
  `DEFAULT_BIOME`, and four smaller items (the biome-map/roll-table invariant pinned, the
  heightmap-by-reference asymmetry stated, the roll-table test's static snapshot/restored, and
  the self-heal's dispatch-cost wording corrected).** ***

**Implementation notes:**
- **Godot's threading rule is what makes the split mandatory.** Scene-tree
  mutation, resource saving and `GameBus` emission are main-thread work; the
  worker may only produce plain arrays. The naive trap is
  `add_task` immediately followed by `wait_for_task_completion` in the same
  frame — that is the synchronous build again with extra ceremony. Poll.
- **The gate is about the ground the body will STAND ON, not the whole ring.**
  The view ring is ~49 chunks; the body needs the one beneath it and enough ring
  to not immediately fall off the edge. Chebyshev 0..1 keeps the gate honest
  without making the loading screen a long wait; the rest of the view ring
  streams normally behind it.
- **The worker must not read mutable slice state.** It takes the heightmap, the
  runs and the constants as arguments. A worker reading `_chunks`, `_edits` or
  `_heightmaps` while the main thread mutates them is a race that will present as
  an intermittent visual glitch, which is the most expensive kind of bug to find.
- **The first-ring gate is a boot path, so both boot paths need it.** Host,
  `--server` and single-player take different tails of `_ready()` (Phase 32); a
  gate wired into one of them is a hole in the others.
- **The loading screen's input freeze is its OWN hook, not an inherited gate.**
  `UIControl.any_window_open()` (`src/ui/ui_slice.gd:107`) answers only for the
  panel set the UI slice holds, and the loading screen is not one of them — so
  it cannot see the gate, and the world does not freeze just because a window
  predicate is false. The gate the player's `_input` actually consults is the
  mouse-capture state (`src/player/player_slice.gd:162`), so the loading screen
  must own an explicit freeze hook (its own `GameBus` signal, or a setter the
  boot path calls) and that hook must be wired on BOTH boot paths above. Assume
  no existing gate covers it.
- **A prefetch ring needs an eviction rule too.** Chunks loaded further out
  still unload when they fall outside `view_distance`; what widens is when they
  are QUEUED, not how many stay loaded.
  *(Shipped differently, and the difference is deliberate: the streamed window is
  `view_distance + prefetch_distance` for QUEUEING **and** for retention. A chunk queued
  further out and unloaded the moment it falls outside `view_distance` is a build paid for
  and thrown away, which is the opposite of what the band is for. `view_distance` is now
  the radius that is guaranteed fully streamed; the band beyond it is lead time.
  **Reversed in the eighth review pass — the note's own advice was right and the
  "shipped differently" was the regression: retention is `view_distance` and only the QUEUE
  spans the band, because the retention it bought was 121 resident chunks against the view
  ring's 49, i.e. 2.5x the meshes, trimeshes and population. The band is still lead time —
  a band chunk is built ahead of its need — and it is released on the next crossing unless
  the player moved toward it.)**

**Implementation notes added during the phase (kept here for the next reader):**
- **A worker task may hold no reference to a Node, and must still be AWAITED.** The pure
  builder is a `static` function called through the SCRIPT (`ChunkManager.VoxelBuilder`),
  because a task that outlives the tree would otherwise call into a freed slice —
  measured: `Invalid call. Nonexistent function '_wall_plane' in base 'previously freed'`
  and a `double free or corruption` abort. And `is_task_completed` only reports that the
  work is DONE; the pool holds the task and its result until it is awaited, so a build
  that is polled and never awaited aborts the process at shutdown (measured: exit 134 on
  every boot that streamed one chunk window). `_apply_build_entry` therefore always
  waits — instant on the frame path, because the caller only reaches it for a finished
  task — and `_exit_tree()` reaps whatever is left.
- **`--quit` quits after ONE frame**, so with the build on a worker the ring is not yet
  built and the host tail does not run in that boot. The suite is unaffected (it runs
  earlier in `_ready()`) and the server-boot assertion is unaffected (the listening line
  is printed by `_boot_server()`), but a `--quit` boot no longer proves the body was
  placed: use `--quit-after N`, or read the `[World] first ring built …` line.
- **The `_built` set is separate from `_loaded`.** `chunk_loaded` still means "this chunk
  entered the streamed set" (its build is dispatched at that point); the boot gate reads
  `_built`, which is set only when the mesh exists.
  **(Corrected by the second review pass: entities used to spawn from `load_chunk()` — a
  frame or two BEFORE their chunk's mesh landed — and they now spawn from the apply path,
  with the mesh, so the population is never ahead of its ground.)**

**Review-pass notes (six findings from a post-phase review, all closed in
`fix(terrain): Phase 42 review pass`):**

1. **`_exit_tree` skipped the wait for an already-COMPLETED task** — the exit-134 leak
   this phase's own notes describe, walked back in through a guard. `is_task_completed`
   reports only that the work is DONE; the pool holds the task and its result until it is
   AWAITED. The wait is now unconditional (`wait_for_task_completion` returns immediately
   for a finished task, so dropping the guard costs nothing). **Measured, both
   directions:** with the guard restored, `--quit-after 400` aborts (`exit 134`) and so does
   the suite boot; with the fix, both are `exit 0`.
2. **An edit to an in-flight chunk was LOST.** The edit path gated its rebuild on a cached
   heightmap, and a chunk only gets one when its build LANDS — so an edit that arrived
   while the build was on the worker rebuilt nothing, and the worker's PRE-edit arrays were
   attached on top of it. `ChunkManager.request_rebuild` needs no cached map: it supersedes
   any build already in flight for that chunk (marked `superseded`, still AWAITED, neither
   attached nor re-dispatched) and dispatches a fresh one built from the current columns.
   RED-proved: the attached mesh came back 16036 vertices against the post-edit build's
   16008.
3. **`stop()` abandoned in-flight builds.** `_process` returned before its apply pass while
   streaming was stopped, so a build dispatched a moment earlier was applied by nobody and
   awaited by nobody — no mesh, and the task's result held until shutdown. The apply pass now
   runs whether or not streaming is active; `stop()` ends NEW work only.
4. **A null worker result fell back to a synchronous main-thread build.** `build_chunk` now
   REFUSES an empty result on the worker path (`arrays` empty with a `revision >= 0`) rather
   than quietly rebuilding the whole chunk on the main thread — the stall this phase exists
   to remove, done silently. The manager answers a refusal with a fresh dispatch, bounded by
   `MAX_BUILD_RETRIES := 3` so a permanently failing build reports an error instead of
   spinning. The 2-arg synchronous form is untouched.
5. **Block edits still rebuilt up to three chunks SYNCHRONOUSLY.** `_rebuild_chunk_at_tile`
   now DISPATCHES through `request_rebuild` (`VoxelSlice.chunk_manager`, wired both ways by
   `game_root`) instead of calling `build_chunk` in the frame that placed the block; the
   chunk keeps its old mesh until the new one lands. A slice with NO manager wired (the
   suite, a probe) keeps the synchronous build, and only for a chunk that already holds a
   cached heightmap — which is what the isolated edit tests assert against. The comment that
   claimed Phase 42 had already threaded this path was false, and is corrected.
6. **`_pending_host_boot` had no timeout.** The gate is a worker build, so a stalled ring
   held the boot forever: loading screen up, no player, no UI, nothing logged. `_tick_pending_host_boot`
   now runs the host tail after `FIRST_RING_TIMEOUT := 15.0` regardless and pushes a warning
   naming how many ring chunks were built — the same shape `SNAPSHOT_TIMEOUT` already has on
   the client side. The decision is a pure predicate (`GameRoot.host_boot_may_proceed`) so the
   suite pins it without booting.

**SECOND review-pass notes (a second post-phase review, closed in
`fix(terrain): Phase 42 review pass 2`):**

1. **`request_rebuild` and build RETRIES bypassed `max_builds_in_flight`.** The cap was
   enforced only in `_drain_load_queue`, so a corner edit (three touched chunks) or a burst
   of retries dispatched straight past it. Both now go through a `_rebuild_queue` drained
   under the same cap — delayed a frame, never dropped — and the supersede is unconditional
   so a pre-edit build cannot land while the fresh dispatch waits for a slot.
2. **A queued chunk that left the window was still built, and stayed `_pending`.** It was
   built and immediately unloaded, and — worse — a chunk that left the window and returned
   was silently SKIPPED, because `refresh()` saw the stale `_pending` mark. `_drain_load_queue`
   now drops a chunk outside `stream_radius` and clears the mark with it.
3. **A build that exhausted MAX_BUILD_RETRIES left a hole for the session.** The chunk is now
   marked in `_failed` and re-armed by the next `refresh()` that re-centres the window — a
   fresh retry budget and a fresh dispatch. Keyed on the window MOVING, so a build that fails
   forever costs one dispatch per crossing rather than a per-frame spin.
4. **Creatures and trees spawned before their chunk's ground existed.** With the build on a
   worker, spawning at load time put the population on a chunk whose mesh arrived a frame or
   more later. They now spawn from `_apply_build_entry`, with the mesh (`_spawn_chunk_contents`).
5. **A joining CLIENT never armed the gate.** `_on_world_snapshot_received` placed the body
   from the snapshot and started streaming around it, so for the first frames the body stood
   on a chunk still being built (the gate was host-only). The client now arms the same gate,
   shows the same loading screen, and releases through `_finish_client_boot` when the ring's
   ground exists — under the same timeout rule.
6. **The loading freeze did not hold the BODY.** It gated `_input` only, so a client's body
   (which exists from the snapshot while its ring builds) fell through ground that was not
   there. `PlayerSlice._physics_process` now skips `_move` while frozen — see
   `ui: the loading screen shows and hides` and `player: the loading freeze holds the body`.
7. **`build_first_ring`'s front-queueing was dead code.** `_boot_server` called `refresh()`
   FIRST, which marked every ring chunk `_pending`, so `build_first_ring`'s `wanted` list came
   out empty and nothing was moved to the front. The gate is now armed BEFORE the refresh.
8. **`VoxelSlice._build_terrain_surface` was dead code** — no callers since the pure builder
   landed — and is deleted; the comment that still pointed at it is corrected.
9. **A redundant nested `if not _is_server:`** framed the loading screen inside the minimap's
   own `not _is_server` block. Removed.
10. **`--quit` no longer proved the host boot, and CI had lost the assertion.** A new
    `host-boot` CI job boots `--quit-after 1800` and asserts `[World] first ring built …`
    (and that the boot did NOT get there through the 15 s ring timeout). Verified locally
    against a FRESH `XDG_DATA_HOME`: the line prints 22.5 s after boot, and the boot saves
    36 creatures — the population the fix in (4) now spawns with the ground.
    **(Amended by the third pass: the job no longer ends the boot on a frame count — it
    passes `--quit-after-boot` and the boot quits itself when its tail has run; see note 6
    below.)**

Also landed in the same pass from the same list: the loading screen's own visibility is
asserted by the suite instead of read by hand off a live boot; `TerrainSlice.request_chunk` is
documented as the TEST-ONLY trigger it now is; and `PROBE Phase 42 build split` prints the
main-thread / worker split of one chunk build, so the phase's headline claim leaves a measured
number behind rather than prose.

Two items on that list were NOT closed, deliberately: **the boot timeout still places the
player on ground that may not exist** (it is the deliberate alternative to a hang with the
screen up and nothing logged, it names how many ring chunks were built, and the warning is
what makes the failure visible) and **the prefetch band's retention cost** (121 resident
chunks against 49 is the price of the lead time the band exists for — reducing it is a tuning
decision, not a defect).
**(That second deferral was taken back in the eighth review pass: the retention half IS
closed — the kept window is `view_distance` again and only the QUEUE spans the band — so
only the view ring's 49 hold meshes, trimeshes and population. What remains a tuning
decision is a different question: whether the band should carry spawned population at all,
since a band chunk's contents are now spawned and then released unvisited.)**

**THIRD review-pass notes (a third post-phase review — seven findings, all closed in
`fix(terrain,core,ci,docs): Phase 42 review pass 3`):**

1. **The self-heal never fired for a STATIONARY player.** The re-arm that a chunk whose build
   gave up depends on was keyed on the window MOVING, and `refresh()` returned before reaching
   it whenever the player stayed in the same chunk — which is a dedicated server's entire shape
   (it streams around a fixed origin) and any host player standing still. So a groundless chunk
   stayed a hole for the session in exactly the case the re-arm was written for. The loop is now
   `_self_heal_failed(window_moved)`: a crossing still re-arms immediately, and an unmoved window
   re-arms on a WALL-CLOCK interval (`self_heal_interval`, 5 s), so a permanently failing build
   costs one dispatch per interval rather than a per-frame spin. RED-proved: with the old
   move-only policy, `chunk: a stationary player re-arms a failed chunk` fails five assertions
   (`expected 0, got 3` on the retry budget, no dispatch in flight, hole still there).
2. **A rebuild re-derived the chunk's contents on every block edit.** `_spawn_chunk_contents`
   ran from `_apply_build_entry` for EVERY build, including the rebuild an edit triggers — and
   `CreatureSlice.spawn_for_chunk` walks every creature in the fabric while `TreeSlice`'s walks
   every live tree, on each call, to arrive at a count that cannot have changed. Contents belong
   to a chunk's RESIDENCY, not its build, so they are now spawned once per residency
   (`_contents_spawned`, cleared by `unload_chunk`). RED-proved: `expected 2, got 4` on the spy's
   spawn count after an edit rebuild.
3. **`unload_chunk` cleared a queued rebuild's `_rebuild_pending` mark but left its entry in
   `_rebuild_queue`.** The dedupe reads the MARK, so the next edit for that chunk appended a
   SECOND entry — two dispatches for one chunk under one revision, both attaching.
   `_remove_queued_rebuild` drops entry and mark together. RED-proved: `expected 0, got 1` on
   the queue size after the unload.
4. **The drain resolved the streamed window once per queued chunk.** `_within_stream` re-derived
   `player_chunk()` — a `PlayerSlice.get_position()` call — and the radius for every candidate,
   so draining a view ring paid one per chunk for a single answer. `_drain_load_queue` now reads
   the window ONCE and tests candidates against it (`_within_stream_at`). RED-proved: a
   position-read spy counted 5 reads for a drain that now takes 1.
5. **The client's early return logged a release that never happened.** `_finish_client_boot`
   runs on both the waiting path (which showed the loading screen) and the
   `is_first_ring_ready()` early return in `_on_world_snapshot_received` (which never did), and
   it printed "releasing the player" either way. It now asks the screen (`LoadingScreen.is_active()`)
   and says which of the two actually happened — the ring was already built, so there was nothing
   to release.
6. **The CI host job ended a boot on a FRAME budget.** `--quit-after 1800` counts FRAMES while
   the boot waits on `WorkerThreadPool` time, so a fast headless frame loop could burn the budget
   before the ring's tasks landed and the job would fail for a boot that was working. The boot now
   ends ITSELF the moment its tail has run, behind a new `--quit-after-boot` user arg
   (`should_quit_after_boot`, asserted in the suite), and `--quit-after` is demoted to an outer
   net for a boot that never gets there (raised to 100000). Verified on a fresh `XDG_DATA_HOME`:
   `[World] first ring built (9 chunks) — placing the player, 24.63s after boot` then
   `[World] host boot complete — quitting (--quit-after-boot)`, exit 0, no timeout warning.
7. **One wait accumulator served both boot gates.** `_boot_wait_elapsed` was read by the host
   gate and the client gate's deadlines. The roles are mutually exclusive TODAY, so it is
   harmless — which is the whole point: the day both could be pending, whichever gate ticked
   second would inherit the other's elapsed time and skip its own wait. Split into
   `_host_boot_wait_elapsed` / `_client_boot_wait_elapsed`; structural, so there is no
   behavioural assertion to make (both predicates stay pinned by `host_boot_may_proceed`'s test).

**FOURTH review-pass notes (a fourth post-phase review — TEN findings, all ten real and all
closed in `fix(terrain,core,ci,docs): Phase 42 review pass 4`):**

The reviewer's list was ten items: one Medium (the self-heal) and nine Low. Unlike Phase 39
(13 of 19 wrong) and like Phases 40 and 42's own second and third passes, **every one landed** —
the line numbers were off by a few (the reviewer's checkout), but each named identifier existed
and each claim held. Four of them (2, 7, 10, and the test half of 6) are test/structural/doc
rather than behaviour, which is what a pass over a phase that has already had three of them
should look like.

1. **The self-heal SKIPPED a chunk that was `_built` — i.e. exactly the chunk whose rebuild gave
   up.** `_self_heal_failed`'s guard was `not _built.has(key)`, and `_failed` is set by a build
   that exhausted its retries. For a chunk that failed its FIRST build, `_built` is false, so the
   re-arm worked. For an already-built chunk — an EDIT whose rebuild gave up — `_built` is still
   true (the pre-edit mesh stands in the world), so the sweep jumped over it and the edited block
   stayed invisible for the session. The guard is gone: `_failed` is what says the ground needs
   its build re-armed, whatever `_built` says. RED-proved: `chunk: a failed REBUILD of a
   built chunk is re-armed` (with the old guard, the mark is not cleared and no dispatch follows).
2. **Nothing proved the stationary throttle actually suppresses a re-arm.** The pass-3 test set
   `self_heal_interval = 0.0`, which DISABLES the throttle — it proved the re-arm runs while
   stationary, and the interval itself was untested. `chunk: the stationary throttle suppresses
   a re-arm` now plants the terminal state twice inside a 60 s interval and asserts the second
   sweep refuses (and that the sweep is unthrottled again once the interval is zeroed, so the
   throttle is the only reason). RED-proved: with the throttle turned into an always-false
   condition, `a second re-arm inside the interval is suppressed` fails (`expected 3, got 0` on
   the retry budget it was supposed to leave untouched).
3. **The isolated fast path in `_dispatch_build` spawned a chunk's contents unguarded.** Pass 3
   gave the threaded apply path the `_contents_spawned` residency rule; the rig path (no
   terrain/voxel, which the older tests rely on) still called `_spawn_chunk_contents`
   unconditionally — and an edit reaches it through `request_rebuild`, so the budgets were
   re-derived per block edit there too. RED-proved: `expected 2, got 4` on the spy's spawn count
   after an edit, `expected 4, got 6` after the residency cycles.
4. **`--quit-after-boot` never fired on a DEDICATED SERVER.** The flag's two call sites were the
   two boot TAILS, and a `--server` boot has no tail: `_boot_world`'s server branch returns
   straight after `_boot_server()`. So `--server --quit-after-boot` never quit itself and fell
   through to the engine's `--quit-after` net. `_boot_world` now calls
   `_quit_after_boot_if_asked("server")` at the end of that branch. Verified:
   `--quit-after 100000 -- --server --quit-after-boot` prints
   `[World] server boot complete — quitting (--quit-after-boot)` and exits 0.
5. **The `host-boot` CI job had no `timeout-minutes`.** Its `--quit-after 100000` is a FRAME
   count, so a boot that never reaches its tail would have run to GitHub's 360-minute default
   before the job said anything. `timeout-minutes: 10` (the boot measures ~50 s) fails fast
   instead.
6. **The self-heal sweep re-resolved the window once per groundless key.** `_within_stream`
   re-derived `player_chunk()` and the radius for every key — the same shape pass 3 fixed in the
   drain, missed on the other loop. The sweep now takes the `center` its caller already resolved
   and calls `_within_stream_at`. RED-proved: a position spy counted 5 reads where the sweep now
   takes 1.
7. **`refresh()` carried two consecutive identical `if window_moved:` blocks** — the sentinel
   update and the load/unload diff, split across two `if`s of the same condition. Merged into one
   decision with an early return; structural, so no behavioural assertion (the existing
   streaming tests exercise it).
8. **The drain resolved the player's chunk even with nothing to dispatch.** `_process` calls
   `_drain_load_queue()` every frame and the window read sat above both queue checks, so a
   settled window — the common case — paid a `PlayerSlice.get_position()` per frame for nothing.
   Both queues empty now returns before the read. RED-proved: `expected 0, got 8` on 8 idle
   drains.
9. **A crossing never stamped `_last_self_heal_msec`.** The stamp sat inside the throttled
   branch, so a crossing re-armed immediately and left the clock at its old value (often the -1
   sentinel): the very next frame was unthrottled and re-armed again, and a stationary player's
   interval effectively restarted at the crossing. The clock is stamped whenever the sweep
   proceeds. RED-proved in an isolated boot (the probe on its own, so the assert cannot be
   masked by another finding's inversion): `the frame after a crossing is throttled, not
   unthrottled` was the ONLY failing assertion, `7759/7760 passed (1 failed)`.
10. **Two stale texts.** The give-up `push_error` said the chunk is "re-armed on the next window
    re-centre" and `_apply_build_entry`'s doc said the same — both false since pass 3 added the
    stationary wall-clock re-arm. And `_within_stream`'s doc named itself "the cancellation test
    in `_drain_load_queue`", which now calls `_within_stream_at`. All three corrected (the
    accessor's doc now says what it is for: the single-check form, with the drains and the sweep
    resolving the window once).

**One thing this pass changed about how it proved itself.** Batching all six policy inversions
into ONE boot (the pass-3 recipe) is cheap but not always honest: reverting finding 1's guard
makes findings 2 and 9's asserts pass vacuously (the sweep skips those chunks, so the mark
survives for the wrong reason). The batched boot gave 18 failures; a SECOND boot with findings
2/3/6/8 only gave 8 and put each of their asserts on the board; finding 9 needed a THIRD boot
with its probe alone to show its single failing line. Use the batched boot for a first sweep, but
re-run any finding whose subject is SHARED STATE (a dictionary another finding's policy also
gates) on its own.

**FIFTH review-pass notes (a fifth post-phase review — three findings, all three real and all
closed in `fix(terrain,world,net,test,docs): Phase 42 review pass 5`):**

The list was three items: one Critical (a client's mine/chop/place crediting the HOST's
inventory) and two Medium. It was written against `d2383db` — the Phase 41 review pass, i.e.
BEFORE this phase — so every line reference was stale (the window it cites as
`voxel_slice.gd:435-473` is `_wall_cells` on today's file, while on the reviewer's checkout it is
`mine_block`'s inventory credit). Every claim was re-derived from the source; all three held,
though item 3's real blast radius is narrower than its phrasing implies (see below).

1. **A client's mine, chop or place credited the HOST's inventory — the client got nothing.**
   The host resolves a peer's intent, and every check and mutation on that path went through
   `VoxelSlice.inventory_slice` / `TreeSlice.inventory_slice`, which are the LOCAL player's own
   pack: the material a client mined filled the host's inventory, the axe it swung wore the
   host's, and a block it placed came out of the host's stack. The peer's own client mirrors only
   ITS pack, so it never saw the yield at all — a silent transfer, not a visual desync. It could
   not be fixed inside the slice either: `_route_c2h` deliberately refuses to read an identity
   out of a payload (Phase 36), so the host had no name for the actor to begin with.
   Fix, mirroring the Phase 37 crafting shape: `player_id` rides the three request signals
   (`block_mine_requested`, `block_place_requested`, `tree_chop_requested`), the host's intent
   arms pass `_actor_id(sender)` — the identity bound to the CONNECTION, never a payload claim —
   both slices gained `player_registry` (wired in `game_root`) plus an `inventory_for(actor)`, and
   an action resolved for a remote actor pushes the result on the owner-addressed
   `inventory_synced` that networking already delivers to that peer alone (the mechanism the
   harness's `inventory_owner` step pins). A placement's `material` is the client's claim again,
   so two rules keep it from granting anything: it must be a real `GameData.MATERIALS` key, and
   the debit lands on the actor's own pack — a peer can place only what it actually holds.
   RED-proved: `net: a remote mine credits the actor` (`expected 1, got 0` on the actor's pack,
   `expected 0, got 1` on the host's), `net: a remote chop credits the actor`, and
   `net: a remote place spends the actor's pack` (nothing placed at all while the host's own
   selection was what got spent: `expected 1, got 0`).
2. **An edit could RESURRECT a streamed-out chunk through the synchronous fallback.** The
   manager path has checked `_loaded` since pass 1; a slice with NO manager (the suite, a probe)
   kept the older `if _heightmaps.has(ckey)` guard — and since the Phase 41 pass that map
   deliberately RETAINS the one-tile ring around the loaded window, so an unloaded neighbour that
   a loaded chunk can still ask about answered TRUE. An edit on a chunk edge then rebuilt it,
   resurrecting a node `ChunkManager` had already streamed away and would never stream out again.
   The guard is `_chunks` now: a loaded chunk always holds its cached map (`build_chunk` stores
   it, `_prune_heightmaps` keeps it), which is the rule `request_rebuild` (`_loaded`) and
   `apply_edits` (`_chunks` + `_heightmaps`) already apply on the other paths.
   RED-proved: `voxel: an edit never resurrects an unloaded chunk` (the streamed-out neighbour
   comes back into `_chunks`).
3. **`apply_edits` closed no seam: a re-scope rebuilt the changed tile's own chunk alone.** A
   wall face is the difference against the NEIGHBOUR column (`_wall_cells`), so a changed tile on
   a chunk's EDGE changes the neighbour's mesh too. The Phase 41 pass closed that for
   `_rebuild_chunk_at_tile` — which every LIVE edit path goes through — and left `apply_edits`
   behind; `apply_edits` is the RE-SCOPE path (the join snapshot and every AOI re-scope).
   Worth stating the real blast radius instead of the summary's: on a join the client streams the
   snapshot's chunks AFTER adopting them (`world_snapshot_received` precedes that chunk's
   `chunk_ready` build), so the seam is usually built correctly from the start, and any error
   self-heals when the neighbour restreams — which is why this is Medium, not the see-through
   world the item's phrasing suggests. What the fix closes is the residue: a re-scope that edits
   a chunk the client ALREADY holds next to another held chunk, where the neighbour's old wall
   stands until something else rebuilds it. `_mark_touched_tile` is now the one place a
   tile-level change becomes chunk-level work, so the two paths cannot drift apart again.
   RED-proved: `voxel: a re-scope rebuilds a changed tile's seam` (`and so is the chunk across
   the seam it changed`). The same test pins the OTHER direction — an interior tile still names
   its own chunk only, and a third chunk that reads nothing of the edit is left untouched — so
   the seam closure cannot decay into a blanket neighbour rebuild.

**A fifth pass over a phase's edit path is where the ARITY cost lives.** Three signals gained a
parameter, and here that is never a one-file change: every emitter (`player_slice`'s three
inputs, `tree_slice.chop_tree`'s client forward, `networking_slice`'s two host arms), every
handler (`voxel_slice`'s two, `tree_slice`'s one, `networking_slice._on_tree_chop_requested`),
the plug-contract docstrings of all three slices, and both test drivers (the suite passes the
signal's owning slice by hand; the net harness drives the bus directly). A stale 2-argument
emit or handler is a RUNTIME error in GDScript, not a parse error — and one stale DIRECT call
(`test_suite` invoked `_on_mine_requested()` itself) aborted the whole suite's compile and
printed a green-LOOKING boot with ZERO tests run. Grep each signal before and after, and check
the test COUNT, not just "0 failed".

**SIXTH review-pass notes (a sixth post-phase review — three findings over eight rows; one was
already closed by the fifth pass, two were real and are closed in
`fix(terrain,persistence,test,docs): Phase 42 review pass 6`):**

The list was written against `e975ddd` — the Phase 41 MERGE, i.e. before this phase — and it dates
itself the same way the fifth pass's did: `_rebuild_chunk_at_tile` is cited at
`voxel_slice.gd:1312`, `apply_edits` at `:550` and `_append_edit` at `:1148`, while those three sit
at 1303 / 540 / 1138 on `e975ddd` and at 1712 / 877 / 1505 on HEAD. (The ~10-line residual says the
reviewer's checkout was a commit or two past the merge, not the merge itself; nothing in the list
depended on that.) Every claim was re-derived from the source.

1. **Chunk resurrection in `_rebuild_chunk_at_tile` (rows 1a/1b/1c) — REAL at the revision read,
   and ALREADY CLOSED by the fifth pass (`89c8461`).** The reviewer read the guard as
   `_heightmaps.has(ckey)`, which the Phase 41 ring retention had made TRUE for a streamed-out
   neighbour; the fifth pass replaced it with `_chunks.has(ckey)` and documented the invariant in
   the method's own docstring, and registered `voxel: an edit never resurrects an unloaded chunk`
   — which is exactly the test row 1c asks for, on exactly the case it names (it mines tile 63,
   the edge column of chunk (0,0), with neighbour chunk (1,0) already unloaded). Nothing to land
   here; the reviewer was right about the revision they read.
2. **An incremental save could not express a DELETED chunk (rows 2a/2b) — REAL.** `_append_edit`
   ERASES a tile's op list when it compacts back to the column's natural self (a player who mines
   a block and puts it back), and `get_chunk_manifest` then has no entry for that chunk — while
   dirty tracking is per CHUNK and is cleared only by the save that CONSUMED it, so the chunk is
   still dirty with nothing left to serialize. That combination was expressible nowhere:
   `dirty_chunk_subset` skipped any dirty key the manifest did not carry, and `_merge_world` only
   ever folded entries INTO the record. So the record on disk kept the edits the earlier FULL save
   wrote, and a reload resurrected terrain the player had already put back — on the autosave, not
   just at shutdown. Fix, both halves: `dirty_chunk_subset` carries an EMPTY edit set for a dirty
   key with no manifest entry (the deletion statement, and the reason the marker is checked with
   `is_empty_edit_set`, which requires the `edits` key to be present — a shape this version does
   not understand is folded in, never read as a deletion), and `_merge_world` DELETES the chunk's
   key when it sees one. ROW 2c (force a full save on shutdown instead of an incremental one) is
   **NOT TAKEN**: it leaves the autosave path exactly as broken as it is and pays the full-record
   cost this phase removed.
   RED-proved: `persistence: an incremental save can delete a chunk` (`the incremental payload
   still names the dirty chunk` — and the payload's `0,0` then indexed off the end of the dict,
   aborting the rest of the test).
3. **No type guard on the legacy branch of `apply_edits` (rows 3a/3b) — REAL, one fix, both halves
   of the row.** The legacy half cast every non-Array value with `float()`, and that cast is not a
   refusal — measured on this engine: `float("not-a-height")` → `0.0`, `float(true)` → `1.0`,
   `float({…})` → `SCRIPT ERROR: Invalid call. Nonexistent 'float' constructor`. The first
   migrated a corrupt string into an absolute height AT THE WORLD FLOOR, i.e. carved the column
   away; the last raised on the load path. The migration now admits exactly what a pre-Phase-41
   edit could be — an int, a float, or a numeric string (`_legacy_height_of`, NAN as the "not a
   height" sentinel) — and DROPS anything else with a `push_warning`, which is the policy
   `_normalise_ops` already applies to an op whose kind it cannot read. Row 3b's "matching
   `_normalise_ops`'s drop policy" is therefore the warning-plus-drop it asks for, in one place.
   RED-proved: `voxel: a legacy edit of an unknown shape is dropped` (`an unparsable string no
   longer carves the column to the world floor: expected 2.0, got 0.0` and `and neither does a
   bool: expected 2.0, got 1.0`).

**Batched probes, and where the count lies for the SECOND pass in a row.** Both inversions went
into one boot (the guard back to the raw cast; the subset back to `if manifest.has(k)` plus
`is_empty_edit_set` disabled with an always-false `< 0`). It reported `7797/7802 (5 failed)`: the
five `✗` lines are exact, but the total is 7 SHORT of the green 7809, because the persistence
probe means the payload does not carry `0,0` at all and the next assertion indexes it — an abort,
not a failed assertion. Read the count as well as the `✗` lines, and quote the count you got in the
GREEN run, never the probe's.

**SEVENTH review pass (`fix(terrain,test,docs): Phase 42 review pass 7`):** a seven-row list
(7a/7b/7c the flaky net-harness step, 4a/4b the terrain material, 6a/6b the npm/pnpm split). It
cites no line numbers, so it dates itself only by its content — and that content lands on HEAD:
`_terrain_material()` is the per-call allocation row 4a describes, step 4 is the `no_distant_tree`
row 7a describes, and the `fabric` job really does run `npm ci` with `cache: npm`. Three of the
seven are real, one is the list's own alternative and is not taken, one is already true, and one is
a doc correction.

1. **The flaky net-harness step (7a) — REAL as a RACE, and NOT reproduced in three fresh-world
   runs.** 7c asks for the reproduction first, and it is the right order: `tools/net_harness.sh`
   under a fresh `XDG_DATA_HOME` (which is what CI has and this machine's accumulated `user://`
   does not) reported `10/10 steps agreed across both peers` three times in a row, with the same
   client-side detail (`tree_-1_-2_1`) each time. So the failure recorded in the Phase 39 pass —
   four runs failing on `rate_bucket` — does not stand today, and the step-four failure the list
   names was never seen here at all. What IS real is the race the fix names: the target is drawn
   from THIS side's own tree table, and a freshly-booted client's table is only what its snapshot
   seeded, so a tree beyond `TARGET_BEYOND` may not have arrived when the step reaches it — and the
   step reported `no_distant_tree` at that instant, which fails a correct guard for being early.
   Step 4 now waits for the table to carry one, bounded by `STEP_TIMEOUT_SECS`, and only then
   judges the guard; the wait is re-derived rather than captured, because a GDScript lambda
   snapshots its captures by value. **The fix is therefore hardening, not a reproduced-defect fix**:
   it cannot be RED-proved here, and it is not claimed to be.
2. **Gating the harness on the full streamed window (7b) — NOT TAKEN.** It is the list's own
   alternative to 7a for the same behaviour ("alternatively"), and 7a is the cheaper of the two: it
   changes one step's precondition instead of the whole harness's boot gate. Two mechanisms for one
   job is what the Phase 40 pass refused to do with the `SeparationRayShape3D`.
3. **Material churn per rebuild (4a/4b) — REAL, one field, both halves.** `_terrain_material()`
   minted a fresh `StandardMaterial3D` per call, and `build_chunk` calls it twice (the surface mesh
   and the rare-vein deposit overlay), so every rebuild — an edit, a re-stream, the self-heal —
   allocated two more materials. Both halves of the row are the same change: `_terrain_mat` is built
   once in `_ready()` (and on first use, for an isolated rig that never enters the tree) and the one
   instance is assigned to both `MeshInstance3D`s, which is what makes the churn track the slice
   instead of the streamed rebuild count. RED-proved: `voxel: terrain material is one instance`
   fails its three `is_same` assertions with the old per-call policy
   (`the surface and the deposit overlay share ONE material instance`, `a rebuild reuses the same
   material instance`, `and so does the rebuilt deposit overlay` — `7808/7811 passed (3 failed)`).
4. **The npm/pnpm split (6a/6b) — 6a is ALREADY TRUE, 6b applied to `README.md` only.** `6a`
   ("keep `package-lock.json`; CI's `npm ci` and `cache: npm` depend on it") is the state of the
   repo: the lockfile is tracked, at `lockfileVersion` 3, and carries the `@newel/*` resolutions the
   `fabric` job's `npm ci` installs from. Nothing to land. `6b`'s first alternative — the docs say
   npm — is applied to `README.md` (quick start, the life-cycle diagram, "Adding a new system").
   Two deviations from the row's letter: there is no `CLAUDE.md` in this repo (the agent notes live
   in `AGENTS.md`, which names no package manager at all), and `ROADMAP.md`'s ~30 `pnpm …` mentions
   are left alone — they are the per-phase record of commands that were actually run, and several
   are quoted acceptance criteria, so rewriting them would falsify the log rather than fix a doc.
   `pnpm-lock.yaml` is still tracked beside `package-lock.json`; removing it is the user's call, not
   this pass's (it is a file deletion in a repo where `pnpm` also works).
5. **A note for whoever reads the assertion count:** the suite's total is NOT a fixed number. The
   seventh-pass count moved by −6 in `battle: player rounds route by target id`, whose `hits` array
   is filled by `BattleSlice.resolve_round`'s `randf()` rolls: any earlier test that consumes the
   global RNG stream shifts how many of its 20 rounds land, so the test asserts a different number of
   times (56 vs 62 here). Green either way, and no assertion is lost — but a count quoted in this
   file is a count for the revision and RNG stream it was measured on, not a constant to match.

**EIGHTH review pass (`fix(terrain,test,docs): Phase 42 review pass 8`):** an eight-row table (an
Issue column, a Solution column, a Criticality column) with no line numbers and no `Closes` column —
it dates itself by content, and all of that content lands on HEAD. **All eight rows are real**: the
fourth list in a row with nothing to discard. Two are real as PERFORMANCE and must not move
behaviour (rows 4 and 8), one is real only as a VACUOUS TEST rather than a defect in production code
(row 5), and one is real by its own account — "the criterion has no assertion" is the finding
(row 3). Row 3's second half and rows 4/8 are what makes this pass's proof unusual: three of the
eight cannot be RED-proved at all, because the thing they change is a COST, and a cost that must not
change behaviour has only an equivalence proof and a measured number.

1. **`build_chunk()` resolved the rare-vein deposits on the main thread (row 1) — REAL, the headline
   (High).** `vein_deposits()` walked all 4096 of the chunk's own columns with its OWN memo (a second
   run replay per tile, plus a biome lookup and a material roll) and then emitted every deposit box
   through a `SurfaceTool` — and `build_chunk` called it on the MAIN thread for every build,
   including every build the worker had just finished: the stall the worker exists to remove, paid
   on the main thread immediately after it. Measured on this machine, for a 695-deposit chunk: the
   walk **24 245 us**, the `SurfaceTool` emission **6 531 us** (695 boxes → 25 020 verts), i.e.
   **~30.8 ms of main-thread work per build**, of which the emission is now the worker's and the walk
   is the resolve half's, sharing the mesher's memo (its marginal cost is the **6 791 us/pass** the
   split probe measures). The fix is the row's own: the deposit list is resolved by
   `collect_build_runs`, the pure builder emits the boxes as
   `deposit_vertices/normals/colors/indices`, and `build_chunk` only attaches. The deposits stay a
   SECOND mesh with no collision, which is what keeps "apply only geometry" honest — a deposit is
   decoration the player must not stand on — and `MeshUtil.add_box_arrays` shares `_box_corners` and
   `_box_faces` with `add_box`, so the two authoring paths cannot wind a face differently (the whole
   reason that file exists). RED-proved in the batch: with the resolve returning `"deposits": []`,
   `voxel: rare vein deposits on natural tiles` fails `every deposit reaches the chunk mesh: expected
   25020, got 0`, and `voxel: terrain material is one instance` fails `the chunk carries a surface and
   a deposit overlay: expected 2, got 1`.
2. **`refresh()` kept the PREFETCH band resident (row 2) — REAL, and a Phase 42 regression the row
   dates precisely (High).** Phase 42 had widened `wanted` to `stream_radius()`, so a crossing
   retained 121 chunks (11×11 at the defaults) against the view ring's 49 (7×7): 2.5× the meshes,
   trimeshes, creatures and trees for a band the player may never enter. `wanted` is
   `view_distance` again and the load QUEUE still spans `stream_radius()`. What is traded, plainly:
   a band chunk is still BUILT ahead of its need (that is the prefetch), but it is RELEASED on the
   next crossing that leaves it in the band unless the player moved toward it — build work in
   advance for a view ring's worth of memory, which is the row's intent. RED-proved:
   `chunk: the kept window is the view ring` fails fifteen assertions with `wanted` back at the
   stream radius (`a band chunk beyond the new view ring is released`, plus eleven
   `every resident chunk is inside the view ring (…): expected true, got false`).
3. **The split criterion was printed, never asserted (row 3) — REAL, and the row's own evidence
   (High).** `_test_chunk_build_split_probe` measured both halves and asserted only that the work
   happened (`cell_count > 0`, `worker_us > 0`), so the phase's headline claim — "the build does not
   run on the main thread" — could have been false with the suite green. It now asserts the ratio,
   and the row's second half is implemented too: the measured main-thread half INCLUDES the apply
   path (`_mesh_from_arrays` for the surface and the deposit overlay, and the
   `ConcavePolygonShape3D.set_faces` GDScript still pays to hand the worker's collision to physics).
   Three passes are summed, because the two halves differ by under 2× on this machine and a
   single-shot pair would be a timing coin-flip — **main 130 071 us (resolve 126 938 + apply 3 133),
   worker 235 263 us** on the `--quit` boot, printed by the test for a reviewer to check. The
   assertion is a strict `>` rather than a ratio: the gap is 1.81×, so a ratio tight enough to be
   interesting would be a flake.
4. **`collect_build_runs` redid two per-tile lookups 4356 times (row 4) — REAL, behaviour-preserving
   (Medium-High).** The biome is a per-CHUNK property (`TerrainSlice.get_biome_at_chunk`), so the
   66×66 ring — which spans at most four chunks — was asking the terrain slice 4356 questions to get
   four answers; and `material_for_biome` re-summed the biome's weight table on every call, while
   `_natural_color` re-derived a colour from a handful of possible materials. Both are memoised for
   the pass (`_biome_at_memo`, a material → colour map) and the weight table is built once per biome
   into a `static var` (`_biome_roll_table`, same insertion order, so the roll's tie-breaks are
   unchanged). Measured: the resolve half runs **42 313 us/pass with the memos against 48 971
   us/pass without them** (~14%), all 7833 assertions green both ways — this row has no RED by
   construction, so it is proved by the equivalence and the number.
5. **The purity test was vacuous (row 5) — REAL as a TEST defect (Medium).** `_test_voxel_build_
   arrays_pure` built the SAME resolved table twice (`f(x) == f(x)`) and its second slice `b` — set
   up with a different place material and an edit in another chunk precisely to show that slice state
   cannot reach the build — was dead setup that was never read. It now resolves the chunk from BOTH
   slices and builds from each: the two resolves must agree and the two builds must be identical, so
   a resolve that leaked one slice's state into another's answer goes red, and so does a builder that
   read back into the slice. Like row 4 this has no production defect behind it and cannot be
   RED-proved; it guards against a leak that does not exist today.
6. **`apply_edits` rebuilt touched chunks synchronously (row 6) — REAL (Medium).** The re-scope path
   — a joining client's snapshot, a load — called `build_chunk` for every touched chunk in the frame
   that applied it (up to three chunks of main-thread build work) AND advanced each chunk's revision
   on the main thread, which made an in-flight worker result stale while its task was still the frame
   path's to reap. It goes through `ChunkManager.request_rebuild` now, exactly like
   `_rebuild_chunk_at_tile`, with the synchronous build kept for a slice with no manager wired (the
   suite, a probe). RED-proved: `chunk: apply_edits dispatches a rebuild` fails both
   `the snapshot's rebuild is NOT done in the frame that applied it` and `it went to a worker
   instead: expected 1, got 0`.
7. **`flush_builds()` iterated a snapshot and never awaited its retries (row 7) — REAL (Medium).**
   `_apply_build_entry` can DISPATCH (a refused worker result is re-dispatched), so a task created
   during the pass was invisible to the `_builds.keys()` snapshot taken before it — and this is the
   BLOCKING variant, whose whole contract is that nothing is left in flight behind it. It loops now
   (re-reading the table per round, bounded by `FLUSH_MAX_ROUNDS` so a build that fails forever ends
   up in `_failed` for the self-heal instead of spinning). RED-proved: with the loop cut to one
   round, `chunk: flush_builds awaits its retries` fails `the retry dispatched during the pass is
   awaited by it: expected 0, got 1` and `and the chunk ends up built (0 meshes attached)`.
8. **`_group_cell` formatted a String key per face cell (row 8) — REAL, behaviour-preserving
   (Medium).** Three `%.4f` formattings plus `Color.to_html` per face cell is ~25k throwaway strings
   for one 64×64 chunk, on the build's own budget and again on every edit rebuild. The key is a
   `Vector4i` of the same four values quantised to 1/10000 — exactly the precision `%.4f` kept — with
   the direction as the outer bucket (a fifth component has no axis, and direction must be in the
   key: an "up" face and a "down" face at the same plane and span would otherwise merge into one
   quad, i.e. a missing floor or ceiling). The quantised ints are bounded far inside int32 (a wall
   plane is a multiple of `TILE_SIZE` and bounded by the world extent, a span by
   `BEDROCK_DEPTH..MAX_HEIGHT`, and `to_rgba32()` is an int32 by definition). Proved by EQUIVALENCE,
   not RED: with the string key restored the suite is green AND the merge probe prints the identical
   numbers (`4352 faces -> 5 quads (20 vertices)` for the flat chunk, `7519 faces -> 3544 quads
   (14176 vertices)` for the natural one — the natural figure is SEED-dependent, so the comparison
   is only valid within one boot, which is exactly how it was taken) — the new key groups exactly
   what the old one grouped, so no span merges that did not merge before.

**Batched probes, and what an equivalence probe can and cannot show.** Five inversions went into ONE
boot (the resolve's deposit list emptied; `wanted` back to the stream radius; `apply_edits` back to
the synchronous build via an always-false operand; the flush loop cut to one round; the string key
restored). It reported `7816/7839 passed (23 failed)`, and the `✗` lines are exact for the four
probes' own subjects — with one honest caveat: reverting `apply_edits` also turned
`net: a remote mine credits the actor` and `net: a remote place spends the actor's pack` red
(`expected 1, got 2`), so that probe's blast radius is wider than its own test and those two are NOT
evidence for row 6. The fifth inversion is the equivalence probe and its signal is not a `✗` at all:
the GREEN merge numbers printed unchanged inside a run that was otherwise failing, which is why the
numbers were read rather than the verdict. This pass's red-caused failure total (23) is a superset of
its four subjects and no test aborted (7839 ≈ the green run's 7833 ± RNG), so nothing was lost to a
crash rather than a failed assertion.

**NINTH review pass (`fix(terrain,test,docs): Phase 42 review pass 9`):** an eight-row table (an
Issue column, a Solution column, a Criticality column) with no line numbers and no `Closes`
column. **All eight rows are real** — the fifth list in a row with nothing to discard — and this
is the first pass whose evidence made one of the PHASE'S OWN criteria go red. Rows 3 and 4 ask for
an absolute main-thread budget on the dispatch and for the probe to assert it; measuring it PER
PASS (the probe had averaged three passes, and the one-time costs sat in the first of them) gave
**44 900 us of resolve per dispatch against a 16 667 us frame**: the headline "the build is on a
worker" was true of the BUILD and false of the DISPATCH, which still spent 2.7 frames of
main-thread work per chunk loaded. That pair is therefore the pass's one structural change — the
resolve itself moves to the worker — and the other six rows are the streaming window, the
in-flight cap, and four small defects the table names.

1. **Band chunks were built and then released before use (row 1) — REAL (Critical).** The eighth
   pass had narrowed the KEPT window to `view_distance` while the load QUEUE still spanned
   `stream_radius()`, and everything the queue spans is BUILT — so every crossing built a band of
   chunks and then released them unless the player happened to move toward them (the row measured
   65 redundant worker builds per crossing; at the defaults it is 121 chunks built against 49
   kept). The kept window is the QUEUE window again, so **no chunk is ever unloaded while it still
   lies inside the radius it was queued at**, and the memory the eighth pass was protecting is
   bounded by the radius instead of by a second window: `DEFAULT_PREFETCH_DISTANCE` is **1**, so
   the resident set is 81 chunks (9×9 — the 49-chunk view ring plus a one-chunk lead) against the
   121 that pass was avoiding.
2. **The kept-window test locked that waste in (row 2) — REAL (High).** It asserted that a
   just-built in-radius chunk IS released, i.e. the assertion was the waste. It is now
   `chunk: the kept window is the stream radius` and asserts the row's own invariant — nothing is
   unloaded while it is still inside the queue radius — plus the retention arithmetic as a number:
   a one-chunk crossing releases the seven chunks of the departing edge. (The eighth pass's test
   name `chunk: the kept window is the view ring` is kept in the record above; this pass renamed
   it because the assertion it carried is now the opposite one, and the Phase 42 line quoting it
   is the measurement of that revision, not of today's.)
3. **The main thread still resolved every chunk it dispatched (row 3) — REAL, and the pass's
   structural change (High).** The resolve (`collect_build_runs`: the per-tile run replay, the
   biome and colour resolution and the rare-vein deposits) was the main thread's half of every
   dispatch, and it cost **43 974 us of steady-state work per chunk** — 2.6 frames at 60 Hz, paid
   once per frame while streaming, on the SAME thread the phase had just taken the build off. The
   split moves: `gather_build_input()` copies the plain state the resolve reads on the main thread
   (the chunk's and ring's edited tiles, deep-copied; the ring chunks' heightmaps; the ring chunks'
   biomes) and the STATIC `build_runs()` does all the per-tile work on the worker, which also runs
   `build_chunk_arrays()` — so one dispatch's main-thread half is now the noise generation plus a
   handful of copies. **Measured: 44 900 us → 2 539 us per dispatch (17.7×), of which the
   generate+gather is 1 634 us**, with the worker half at 77 159 us/pass (resolve 42 957 + build
   34 202). `collect_build_runs()` survives as the synchronous wrapper, so the bus path, the
   isolated rigs and the tests keep the same entry point; the resolve's reads became arguments
   (`edits`, `neighbour_heightmaps`, `biomes`), which is what makes it worker-legal, and the
   instance colour helpers became accessors over the static resolved forms (the
   `_within_stream` / `_within_stream_at` shape).
4. **The probe's criterion let a 43 ms frame pass (row 4) — REAL (Medium).** `pure_us > main_us`
   was satisfied by a dispatch whose main-thread half blew the frame, and the three-pass SUM hid
   the steady state behind the first pass's one-time costs. The probe now keeps PER-PASS figures
   and asserts, alongside the ratio, an ABSOLUTE ceiling: one dispatch's main-thread half must fit
   inside one frame (16 667 us). This is the assertion the old criterion could not make — and it
   is the one that was RED before row 3's fix (see the batched probe evidence below).
5. **`load_chunk()` bypassed the in-flight cap (row 5) — REAL (Low-Medium).** Every internal
   caller checked `max_builds_in_flight` before dispatching, but the PUBLIC `load_chunk` called
   `_dispatch_build` outright, so a direct load put the pool over its own cap. The cap is now
   enforced INSIDE `_dispatch_build` (nobody can route around it), the deferral goes to
   `_rebuild_queue` — the chunk is already `_loaded`, so the drain's rebuild branch is exactly the
   path that re-dispatches it — and `request_rebuild`'s and the retry's duplicate checks were
   removed so the rule lives in ONE place. New test:
   `chunk: a direct load respects the in-flight cap`.
6. **The group key's packed colour does not fit int32 (row 6) — REAL as a DOC error (Low).** The
   eighth-pass comment claimed `to_rgba32()` "is an int32 by definition"; it is a packed uint32,
   so opaque white is **4294967295** and the `Vector4i` component reads back as **-1** (the high
   bit kept as the sign; measured on 4.7). The wrap is a BIJECTION — the component reads back as
   `& 0xFFFFFFFF` == the packed value — so two distinct colours cannot collide onto one key and
   the grouping is exactly what the old string key grouped. What was wrong was the comment, and it
   is fixed in both places (the comment and the eighth-pass paragraph above).
   `voxel: the group key survives the colour band` pins the measured values, the round trip, the
   injectivity of two colours sharing their low bits, and the grouping itself.
7. **`_biome_rolls` is worker-reachable mutable class state (row 7) — REAL (Low).** It is a
   `static var` on the script a chunk-build task holds (`ChunkManager.VoxelBuilder`), so the lazy
   fill was a WRITE a worker thread could have raced. Every biome is warmed in `_ready()` now, on
   the main thread, before anything streams — and the worker half never reads it either, because
   the colours arrive resolved in the table it is handed. New test:
   `voxel: the biome roll table is prebuilt` (it clears the static first, so the assertion cannot
   be vacuous).
8. **`build_chunk_arrays` sniffed a "runs" key (row 8) — REAL (Low).** `resolved.get("runs",
   resolved)` meant "does this dictionary happen to hold a key called runs?", silently re-reading a
   bare runs table as a payload. Every caller in the tree passes a `collect_build_runs()` payload
   (the only bare tables were the `{}`-for-natural probes, now `{ "runs": {} }`), so the sniff is
   gone and an absent `runs` key reads as NO resolved columns, i.e. the natural-column fallback.
   New test: `voxel: the build payload shape is required`, which hands the builder a bare table
   that WOULD change the build under the old fallback and requires the two builds to be identical.

**Batched probes, and the one that had to be its own.** Six inversions went into ONE boot (the kept
window narrowed back to `view_distance`; the `_dispatch_build` cap guard disabled with an
always-false operand; the `_ready()` prebuild loop emptied; the "runs" sniff restored; the group
key's colour folded to its low byte; and — for rows 3/4 — the PROBE put back on the pre-fix
measurement, the resolve counted as the main thread's half). It reported `7839/7860 passed
(21 failed)` and every one of the six subjects went red with its own line:
`chunk: the kept window is the stream radius` (`a band chunk still inside the queue radius is NOT
released`, and `expected 7, got 40` released), `chunk: a direct load respects the in-flight cap`
(`expected 1, got 2` builds in flight), `voxel: the biome roll table is prebuilt`
(`expected 5, got 0`), `voxel: the build payload shape is required` (`expected 4352, got 4354`),
`voxel: the group key survives the colour band` (`a second colour is its own group: expected 2,
got 1`), and `chunk: the build split is measured` (`one dispatch's main-thread half fits inside a
frame (48135 us of 16667 us, generate+gather 47243)`) — the row-4 ceiling failing at the old
split, which is the whole reason row 3 was worth doing. Two caveats recorded rather than smoothed
over: disabling the cap guard also reddened `chunk: a rebuild respects the in-flight cap` and
`chunk: unloading drops a queued rebuild` (the same guard is those tests' subject too — the guard
going off moves the pooling they assert on), and the run's failure total (21, total 7860) is a
superset of the six subjects because the RNG-dependent test (`battle: player rounds route by
target id`) asserts a varying number of times per run. No test aborted, and the restored source is
green on both boots.
A SECOND, two-inversion boot proved the gather itself (`chunk: the gathered payload carries the
ring`): with `_gather_neighbour_heightmaps` carrying nothing and `_gather_edits` returning early,
it reported `7862/7868 passed (6 failed)` — the new test's own
`a carried ring chunk resolves its real column`, plus THREE existing tests in its blast radius
(`voxel: a seam wall ignores the build order` `expected [[1.0, 2.0]], got [[-8.0, 2.0]]`,
`voxel: an edge edit rebuilds the neighbour chunk`, `voxel: a tunnel keeps its floor and its
roof`). That collateral is the useful part: the ring's heightmaps and edits are what the seam
geometry is computed FROM, so the gather is load-bearing for the existing voxel tests, not only
for its own.

**TENTH review pass (`fix(terrain,test,docs): Phase 42 review pass 10`):** an eight-row table
(an Issue column, a Solution column, a Criticality column) with no line numbers and no `Closes`
column. **All eight rows are real** — the sixth consecutive list with nothing to discard — and
the list's own framing is right: it is a list of SMALL items, the largest being a per-dispatch
cost the earlier passes kept narrowing but never bounded for a played world.

1. **`_gather_edits` scanned the whole world edit log per dispatch (row 1) — REAL (Medium).**
   The gather iterated EVERY key in `_edits` and `str(key).split(",")`-ed it to test it against
   the chunk window's bounds: one string split per edit in the WORLD, per dispatch, however far
   away those edits were. It now walks `_edits_by_chunk` — the log INDEXED BY CHUNK (`"cx,cz"` →
   `{ "gx,gz": true }`), the read-side counterpart of `_dirty_chunks` — reading only the (≤ 3×3)
   chunks the window spans. The index is kept in step by `_set_edit_ops`, now the ONE place a
   tile's op log is written (`_append_edit` and `apply_edits` both route through it, the latter
   re-deriving the index wholesale). **Measured on a 102 400-edit log with 4 096 in the window:
   the dispatch's generate+gather was 44 012 us (2.6 frames) and is 5 568 us**, because the cost
   is now proportional to the window and not to the world. The four tests that wrote `_edits`
   directly were routed through `_set_edit_ops` so the index cannot drift from the log.
2. **The frame-ceiling assertion ran on a FRESH slice, so it could not see row 1 (row 2) — REAL
   (Medium).** The ninth pass's ceiling measured an empty `_edits`, where the gather returned on
   its first line — so the one cost the index exists to bound was never in the number the ceiling
   checked. `chunk: the build split is measured` now runs a SECOND pass over a POPULATED log (a
   full chunk in the window plus 24 chunks ≈98k edits outside it) and asserts the same
   `steady < 16 667 us` ceiling there; the far chunks are what makes the assertion bite, since
   only the window's are copied. **RED with the old world-scan gather restored: `44 012 us of
   16 667 us` — the row-1 fix is exactly what this assertion pins.**
3. **Worker safety rests on `BIOME_KEYS ⊆ BIOME_MATERIALS`, unpinned, with a false comment (row
   3) — REAL (Low-Medium).** A worker's resolve reaches `material_for_biome`, which silently
   answers `Ferrite` for a biome absent from `BIOME_MATERIALS` — so a canonical biome missing
   from the table mines as the wrong material, and nothing asserted the two sets agree. New test
   `voxel: every canonical biome has a roll table` asserts it over `TerrainSlice.BIOME_KEYS` (the
   set the gathered strings actually come from), each with a non-empty table. The `_ready()`
   comment's claim that "the worker half never even reads it" was FALSE — the worker reads it
   through `run_color` → `natural_color` → `material_for_biome` → `_biome_roll_table` — and is
   rewritten to the real invariant (written on the main thread before any worker exists,
   read-only afterwards).
4. **Heightmaps are gathered by reference while edits are deep-copied, unstated (row 4) — REAL,
   DOC-ONLY (Low).** The asymmetry is deliberate and now stated at `_gather_neighbour_heightmaps`:
   an op list is APPENDED to in place (`ops.append` on the array a worker may be reading), so it
   must be copied; a heightmap array is only ever REPLACED wholesale and never mutated in place,
   so sharing it is safe — with the note that a future in-place write would have to copy here too.
5. **`_biomes_or_lookup` passed an incomplete biome map through (row 5) — REAL (Low).** Its guard
   was "is the map non-empty", so a PARTIALLY populated map — the realistic case — went straight
   through and `biome_of` answered `DEFAULT_BIOME` for the missing chunk, silently tinting a real
   chunk as TemperateForest. It now tests for THIS position's chunk and, on a miss, resolves that
   one chunk from the terrain slice into a COPY of the map, so the caller's is untouched. (The
   pure `biome_of` keeps the `DEFAULT_BIOME` fallback — it is static and has no slice to ask —
   and that answer is now only reachable when there is no terrain slice at all.)
6. **`voxel: the biome roll table is prebuilt` cleared a worker-reachable static mid-suite (row
   6) — REAL (Low).** `_biome_rolls` is process-wide class state a worker reads, and the test
   blanked it and left it blanked. It now SNAPSHOTS the table, clears (which is what makes the
   assertion about `_ready` rather than a leftover), and RESTORES it, asserting it is left full.
7. **`_update_first_ring_progress` only latched true while `unload_chunk` clears `_built` (row 7)
   — REAL (Low).** A one-way latch cannot mirror a set that can lose members, so the gate could
   claim a chunk was built after it had streamed away. It now RECOMPUTES each ring key from
   `_built` (`_first_ring[key] = _built.has(key)`), so the mirror is exact. No boot regressed (the
   ring is armed before the player can move, so a ring chunk never unloads mid-boot).
8. **The self-heal's cost was described as one dispatch per interval (row 8) — REAL, DOC-ONLY
   (Low).** A re-arm clears `_build_attempts` — a FRESH retry budget, which three tests assert —
   so one re-arm is up to `MAX_BUILD_RETRIES` dispatches, not one; the throttle bounds the re-arm
   CADENCE, not the dispatches within one. The row's first option ("don't reset `_build_attempts`
   on a heal re-arm") was **not taken**: the reset is the tested, intended design. Both messages
   (`_failed`'s doc, `_self_heal_failed`'s doc, and the give-up `push_error`) are corrected.

**Known simplifications (deferred):**
- **An edit's mesh lands a frame or two later.** Since the review pass, a mine/place
  DISPATCHES its chunk rebuild (and any seam neighbour's) to the worker instead of building
  it in the frame that applied the edit, so the visual update arrives when that build does.
  The edit LOG is immediate, so everything that reads the world rather than the mesh —
  footing (`sample_support_height_at`), further edits, persistence — is unaffected.
- **A client's own harvest is confirmed by the host, never predicted.** Since the fifth review
  pass the host resolves a peer's mine/chop/place against THAT peer's own pack and pushes the
  result back on the owner-addressed `inventory_synced`, so the peer sees its yield only once the
  round trip lands — there is no client-side prediction of the edit or of the material, for the
  same reason the block's mesh arrives with the host's `block_changed`. The durability a remote
  actor's pick or axe spends is the host's number too, so a client cannot wear its own tools
  locally (only report the wear the host resolved). Making the remote half feel instant again
  means client-side prediction plus reconciliation, which the phase does not carry.
- **No priority job queue or cancellation.** Loads are nearest-first, and a
  chunk that falls out of range while queued is still built (and then unloaded).
  **(Closed in the second review pass for the cancellation half: a queued chunk that leaves
  the window is now DROPPED rather than built, and its `_pending` mark is cleared with it, so
  a chunk that leaves and returns is queued again instead of being skipped. What is still
  deferred: there is no priority ordering beyond nearest-first, and a rebuild cannot jump the
  load queue — it is drained first, but only as a whole band.)**
- **The loading screen is a progress bar, not a world preview** — no panorama, no
  tips, no fade.
- **Entities still spawn on the main thread.** Creatures and trees spawn in the
  frame a chunk lands; this phase threads the TERRAIN build only.
  **(Refined in the second review pass: they spawn from the apply path, i.e. WITH the chunk's
  mesh, rather than at load time a frame or two before it. What is still deferred: the spawn
  itself is still a main-thread call inside that apply pass, and the prefetch band's chunks —
  then 121 resident against the view ring's 49 — spawn their population as eagerly as the near
  ring's; how far out population should exist at all is a tuning decision this pass left open.)**
  **(Closed in the eighth review pass for the WINDOW half: the kept window is `view_distance`
  again, so only the view ring's 49 hold meshes, trimeshes and population; a prefetch-band
  chunk is still built ahead of its need but is released on the next crossing that leaves it in
  the band. What is still deferred: the spawn itself is still a main-thread call inside the
  apply pass, and a band chunk's population is spawned and then released unvisited — whether
  the band should carry population at all remains the tuning decision.)**
  **(NINTH review pass: that window narrowing is REVERTED — it was the build-then-release waste
  this pass's row 1 measures, so the kept window is the queue radius (`stream_radius()`) again
  and a band chunk is released only once it is outside the radius it was queued at. The
  resident set is bounded by the RADIUS instead (`DEFAULT_PREFETCH_DISTANCE` 1 → 81 chunks,
  9×9). What is still deferred is unchanged: the spawn is a main-thread call inside the apply
  pass, and how far out population should exist is still the tuning decision.)**
- **No runtime tuning UI** for `loads_per_frame` / the ring sizes; they stay
  constants (overridable, as today).
