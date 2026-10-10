extends Node
## Phase 39 — the two-client network harness.
##
## Every guarantee Phases 34–38 landed was proven at the ROUTING level: a test called
## `NetworkingSlice._route_c2h(sender, payload)` with the sender handed in as an
## argument and read the bus. Not one byte ever crossed a socket. This runner is the
## missing half: it drives a REAL ENet session between two processes — the same
## `NetworkingSlice.host()` / `join()` the game itself ships with, the same
## `--server` / `--client` boot roles, real peer-id assignment — and asserts on what the
## transport actually carried.
##
## It cannot live in `TestSuite`. `TestSuite._run_tests()` is called synchronously from
## `GameRoot._ready()` and has not a single `await` in its ~7,900 lines, deliberately, so
## that its bus emissions cannot leak into production world state. An
## `ENetMultiplayerPeer` only delivers when the tree ticks, so a socket-driven scenario
## needs frames — which means its own boot mode and its own `await`-driven pump loop.
## The parts of it that are PURE (the step table, the line format, the convergence
## verdict) ARE registered in the synchronous suite, so they are still covered on every
## boot.
##
## Design notes, all four load-bearing:
##
##   • TWO PROCESSES, not two `MultiplayerAPI`s in one. Running both peers in one process
##     is possible in Godot 4 (a second API bound to a second subtree), and the driver
##     could then read both sides' state directly. It is the wrong default: it bypasses
##     the production boot path, so an edit that only works in-process would pass here and
##     fail in the wild. Two processes over loopback drive the shipped roles unmodified.
##   • THE COMPARISON CHANNEL IS A LOG LINE, because there is no shared memory between the
##     processes. Each side prints one structured line per step
##     (`HARNESS <step> <ok|refused|fail> <detail>`) and `tools/net_harness.sh` asserts the
##     two streams agree. A text channel is what lets the same scenario run under either
##     role, and the only one that survives a role flip.
##   • TARGETS ARE DERIVED, NOT TRANSMITTED. Both sides select their scenario trees from
##     their OWN table with the same rule: sort by tree id. Tree ids and positions are
##     deterministic per chunk (`TreeSlice._deterministic_chunk_position`), so the two
##     tables hold the same entries and the two processes agree on `tree_0_0_1` without a
##     side channel. A side that cannot find the tree the other side named fails loudly
##     (`fail`) instead of quietly asserting nothing.
##   • CONVERGENCE, NOT FRAME COUNTS. Every step waits on a predicate with a bounded
##     number of frames and a wall-clock deadline, and reports `fail` when the deadline
##     passes. A wire test that flaps is worse than no wire test, so nothing here asserts
##     "after N frames".
##
## The runner quits its own process when the scenario ends, which is what makes the
## driver's "did this process exit cleanly" check meaningful.
##
## Public API:
##   run(root, role) -> void                       — drive the scenario, then quit
##   steps() -> Array                              — the step table (static, pure)
##   format_line(step, verdict, detail) -> String  — one log line (static, pure)
##   parse_line(line) -> Dictionary                — the inverse (static, pure)
##   verdict(seen, expect_seen) -> String          — the convergence verdict (static, pure)
##   unawaited_waits(lines) -> PackedStringArray   — the bare-coroutine audit (static, pure)
##
## `run()` audits its OWN source for a bare `_await_…` call before it boots either peer
## (see `unawaited_waits`): that mistake compiles, runs, and turns this scenario's waits
## into no-ops, and the synchronous suite cannot see it because it cannot host a pump.

const PlayerSlice := preload("res://src/player/player_slice.gd")
const EquipmentRules := preload("res://src/character/equipment_rules.gd")
const WorldPos := preload("res://src/terrain/world_pos.gd")

## The id the client presents on its FIRST join, well-formed but owned by nobody: the
## shape `PlayerRegistry.looks_like_player_id` accepts, minted by no registry. The
## host must ignore the claim and bind the connection to its own freshly minted id.
## A literal, not a minted value, so BOTH processes know what was claimed.
const SPOOFED_ID := "player_1_1_00000000000000000000000000000000"

## Where the client tells the host it is standing, so the reach guard has evidence to
## measure against and both sides select the same trees. The world spawn point, a value
## both processes already agree on (see NetworkingSlice.DEFAULT_AOI_CENTER).
const RENDEZVOUS := Vector3(16.0, 12.0, 16.0)

## How far from RENDEZVOUS (measured on the XZ plane, where trees are placed) a tree has
## to be to count as an in-reach target. Comfortably inside
## `NetworkingSlice.MAX_EDIT_REACH` (60) even after the client's body settles, so the
## in-reach steps exercise a pass rather than the guard's boundary.
const TARGET_REACH := 24.0

## How far out an out-of-reach target must be. Beyond `MAX_EDIT_REACH` by a wide margin
## — the point of the step is that the guard refuses, and a target merely near the
## boundary would make the assertion about arithmetic rather than about the guard.
const TARGET_BEYOND := 70.0

## How many in-reach trees the scenario needs, in sorted-tree-id order.
const TARGETS_NEEDED := 3

## Wall-clock budget for one step's convergence predicate.
const STEP_TIMEOUT_SECS := 25.0

## Settle window for the steps that assert an ABSENCE (the out-of-reach chop, the
## oversized packet). Long enough that a packet in flight has landed, short enough that
## the harness stays well inside its deadline.
const ABSENCE_WINDOW_SECS := 3.0

## How long the client stays disconnected in the reconnect step. Has to exceed
## `PlayerRegistry.RESPAWN_DELAY` so the host's deadline has passed by the time it
## reconnects — the whole point of deliverable 1 is that the wait is observably over.
const RECONNECT_WAIT_SECS := 6.0

## An item id the fabric defines, used by the owner-scoped inventory step.
const PROBE_ITEM := "Ferrite"

var _root: Node = null
var _role: String = ""
var _lines: Array = []

## True once any step of this side has reported `fail` — the run's verdict, which `_finish`
## turns into the process exit code (see there).
var _failed: bool = false

## The peer id this process handshook with (0 until step 1 resolves it, and always 1 on the
## client side — the host is ENet peer 1 to its peers). Note that ENet REASSIGNS peer ids,
## so after the reconnect step this id belongs to a connection that no longer exists; see
## `_bound_player_id` and `_rediscover_peer()`.
var _bound_peer: int = 0

## The PLAYER id the handshake bound the peer to — the stable identity behind the
## connection, which is exactly what survives a reconnect. Every step that means "the peer
## the scenario is about" uses THIS, not a peer id: a peer id is transport, and the
## reconnect step replaces it.
var _bound_player_id: String = ""

## Host-side observation of routed chop intents: the guard under test is the reach check
## inside `_route_c2h`, and its pass/fail decision is exactly "did GameBus.tree_chop_requested
## fire". Counted over the whole run (see `_chop_count`).
var _chops: Array = []

# ---------------------------------------------------------------------------
# Pure helpers (registered in TestSuite)
# ---------------------------------------------------------------------------

## The scenario, in order. `compare` marks the steps whose `detail` both processes must
## agree on: it is the driver's oracle, and a step that can only be observed from one
## side says so here rather than claiming an agreement it cannot check. The one
## non-comparing step is `chop_out_of_reach`, and the reason is structural rather than a
## shortcut: the two sides' tree TABLES are not identical — the host streams chunks on a
## per-frame budget (`ChunkManager.DEFAULT_LOADS_PER_FRAME`), so by the time a peer joins
## it holds the chunks loaded SO FAR, and the client seeds its trees from that snapshot —
## so the two processes can disagree about which tree is the farthest. They cannot
## disagree about chunk (0,0), which both always have, and that is why every target the
## scenario must agree on is drawn from there.
static func steps() -> Array:
	return [
		{ "name": "handshake",         "compare": true },
		{ "name": "snapshot_complete", "compare": true },
		{ "name": "chop_in_reach",     "compare": true },
		{ "name": "chop_out_of_reach", "compare": false },
		{ "name": "packet_cap",        "compare": true },
		{ "name": "rate_bucket",       "compare": true },
		{ "name": "clock_synced",      "compare": true },
		{ "name": "inventory_owner",   "compare": true },
		{ "name": "chat_relayed",      "compare": true },
		{ "name": "admin_teleport",    "compare": true },
		{ "name": "non_admin_refused", "compare": true },
		{ "name": "equipment_recorded", "compare": true },
		{ "name": "equipment_delivered", "compare": true },
		{ "name": "peer_damage_floor", "compare": true },
		{ "name": "reconnect_alive",   "compare": true },
		{ "name": "disconnect_evicts", "compare": true },
		{ "name": "far_peers_simulated", "compare": true },
		{ "name": "spawn_near_friend", "compare": true },
	]

## The step names, comma-joined — the payload of the `plan` line the runner prints
## before the scenario. The driver reads the plan out of BOTH logs and derives its
## expectations from it, so the step list lives in ONE place: a step added here is
## expected by the driver automatically, and a step one side stops reporting is caught
## instead of quietly passing on the other side's line.
##
## A step whose details must NOT be compared carries a `*` suffix, so the protocol is
## self-describing: the driver only has to read the plan rather than keep a second list
## of which steps compare.
static func plan_detail() -> String:
	var names: Array = []
	for s in steps():
		names.append(str(s.get("name", "")) + ("" if bool(s.get("compare", true)) else "*"))
	return ",".join(names)

## One structured line per step: the ONLY channel between the two processes, so the
## format is fixed and the driver can parse it with awk. `detail` never contains a space
## (ids and short verdict tokens only), which is what keeps the line three fields wide.
static func format_line(step: String, verdict_text: String, detail: String) -> String:
	return "HARNESS %s %s %s" % [step, verdict_text, detail]

## The inverse of `format_line`. Returns {} for anything that is not a harness line, so
## the driver's parser can be asserted against noise.
static func parse_line(line: String) -> Dictionary:
	var parts: PackedStringArray = line.strip_edges().split(" ", false)
	if parts.size() != 4 or parts[0] != "HARNESS":
		return {}
	return { "step": str(parts[1]), "verdict": str(parts[2]), "detail": str(parts[3]) }

## The convergence verdict for one step: `seen` is whether the event the step is about
## was observed before its deadline, `expect_seen` is what the scenario says should
## happen. A step whose subject is a REFUSAL passes by NOT observing — so "refused" is a
## pass, and treating it as a failure is how a security test quietly stops testing.
static func verdict(seen: bool, expect_seen: bool) -> String:
	if seen == expect_seen:
		return "ok" if expect_seen else "refused"
	return "fail"

## True when a reported verdict counts as a pass for the driver.
static func passed(verdict_text: String) -> bool:
	return verdict_text == "ok" or verdict_text == "refused"

## The one mistake in this file that no wire test can see, and that a bare coroutine turns
## into a FALSE scenario failure: GDScript lets a coroutine be called without `await`, and
## that call then returns immediately — the step runs with no wait at all. Not hypothetical:
## every `_await_settle` call site in this runner was originally bare, so the post-burst
## chops of the rate-limit step left in the SAME frame as the burst that had just emptied
## the peer's token bucket, and the step blamed the limiter for its own missing wait (see
## ROADMAP.md Phase 39, criterion 10, and `_step_rate_bucket`).
##
## Static and pure, and it takes the source as LINES, for one reason: the synchronous suite
## cannot host this runner (it has no frames to yield), but it CAN assert this rule on
## synthetic input — and the runner points the same function at its OWN source at start-up
## (`_self_audit`), so the rule is enforced on every harness boot rather than only in review.
## A line whose stripped form begins with `_await_` is a bare call; the function's own
## `func _await_…` definition cannot match, because it begins with `func`.
static func unawaited_waits(lines: PackedStringArray) -> PackedStringArray:
	var offenders: PackedStringArray = PackedStringArray()
	for i in lines.size():
		if lines[i].strip_edges().begins_with("_await_"):
			offenders.append("%d" % (i + 1))
	return offenders

## Deterministic in-reach targets: every tree within `reach` of `origin` (XZ distance,
## which is where trees actually move in the world), sorted by tree id. `origin` is
## RENDEZVOUS and the tree table is deterministic, so a host and a client with no side
## channel pick the same ids.
static func in_reach_targets(trees: Array, origin: Vector3, reach: float, count: int) -> Array:
	var ids: Array = []
	for t in trees:
		if not (t is Dictionary):
			continue
		var pos: Variant = t.get("position", Vector3.ZERO)
		if pos is Vector3 and _xz_distance(pos as Vector3, origin) <= reach:
			ids.append(str(t.get("tree_id", "")))
	ids.sort()
	while ids.size() > count:
		ids.pop_back()
	return ids

## The first tree beyond `beyond` on the XZ plane — the out-of-reach target. Sorted by
## tree id, so both processes agree without a side channel, and id-sorted rather than
## "farthest" so a few units of difference between the two sides' view of the world
## cannot change the answer.
static func beyond_reach_target(trees: Array, origin: Vector3, beyond: float) -> String:
	var ids: Array = []
	for t in trees:
		if not (t is Dictionary):
			continue
		var pos: Variant = t.get("position", Vector3.ZERO)
		if pos is Vector3 and _xz_distance(pos as Vector3, origin) > beyond:
			ids.append(str(t.get("tree_id", "")))
	ids.sort()
	return str(ids[0]) if ids.size() > 0 else ""

## Horizontal distance — the reach guard measures the full 3D distance, so this is
## deliberately the SMALLER number: a target selected here is inside reach whichever way
## the client's body ends up standing.
static func _xz_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------

## Drive the scenario for `role` ("host" or "client"), then quit this process. `root` is
## the GameRoot: the harness runs from `GameRoot._ready()` with every slice built and
## wired, and boots the ONE boot half its role needs (see the call site) so the
## production boot path is what is under test rather than a harness-only arrangement.
func run(root: Node, role: String) -> void:
	_root = root
	_role = role
	# The chop guard's decision IS the bus signal, so observing it is how this side sees
	# an intent the reach check let through. Connected (not watching a payload) so the
	# observation cannot be faked by the other side: only the host's own router emits it.
	GameBus.tree_chop_requested.connect(_on_chop_requested)
	# Deaths are observed the same way, and for the same reason (see `_deaths`).
	GameBus.player_died.connect(_on_player_died)
	# Chat lines and teleports are observed over the whole run, like deaths (see `_chat_seen`).
	GameBus.chat_posted.connect(_on_chat_posted)
	GameBus.player_teleport.connect(_on_player_teleport)
	print(format_line("ready", "ok", role))
	print(format_line("plan", "ok", plan_detail()))
	if not _self_audit():
		return
	if _role == "host":
		_fresh_save_dir()
		_pin_world_seed()
		if _failed:
			return
		_root._boot_server()
		# Every scenario step stands its peer at RENDEZVOUS (the pinned seed's tree chunk), so a
		# join WITHOUT a friend code is placed there; the friend-code step uses the real placer.
		_root._registry.set_spawn_placer(func(player_id: String, code: String) -> Dictionary:
			if code == "":
				return { "position": RENDEZVOUS, "source": "search", "message": "" }
			return _root._place_new_player(player_id, code))
		# Booting adopts the seed of any world record on disk, which silently replaces the
		# pinned one; a run on the wrong seed would fail for an unrelated reason.
		if int(_root._terrain.get_world_seed()) != _pinned_seed:
			push_error("net-harness: the pinned world seed %d was replaced by a world record (%d)"
					% [_pinned_seed, int(_root._terrain.get_world_seed())])
			_failed = true
			_finish()
			return
	else:
		# The client's own `_broadcast_state()` is switched OFF for the run: it emits
		# `player_state_sync_requested` every 30 physics ticks with wherever the local
		# body happens to be standing, which would fight the ONE position report the
		# scenario needs the host to hold (see `_report_position`). This is the same
		# switch a headless boot uses, and it touches presentation only — the body's
		# liveness and its respawn countdown, which the reconnect step asserts on, are
		# unaffected.
		_root._player.render_visuals = false
		# Mirror `game_root._boot_client()`, with the SPOOFED id in place of the cached
		# one. Deliberately not `_boot_client()`: that reads the persisted identity, and
		# the first join is the one the identity claim is about.
		_root._networking.claimed_player_id = SPOOFED_ID
		var err: Error = _root._networking.join(
			_root._host_address, _root._networking.DEFAULT_PORT)
		_root._snapshot_pending = true
		if err != OK:
			_report("handshake", "fail", "join_failed")
			_finish()
			return
	await _step_handshake()
	await _step_snapshot_complete()
	await _step_chop_in_reach()
	await _step_chop_out_of_reach()
	await _step_packet_cap()
	await _step_rate_bucket()
	await _step_clock_synced()
	await _step_inventory_owner()
	await _step_chat_relayed()
	await _step_admin_teleport()
	await _step_non_admin_refused()
	await _step_equipment_recorded()
	await _step_equipment_delivered()
	await _step_peer_damage_floor()
	await _step_reconnect_alive()
	await _step_disconnect_evicts()
	await _step_far_peers_simulated()
	await _step_spawn_near_friend()
	_finish()

## End this process, with the run's own verdict carried in the exit code.
##
## The harness quits itself (the driver deliberately passes no `--quit`), so the exit code
## is the one thing the driver's process check can read, and it used to mean only "did not
## crash": a scenario whose step reported `fail` still exited 0. The driver also reads the
## `fail` line, so this is a second statement of the same fact rather than the only one —
## but a CI wrapper (or a human) reaches for the exit code FIRST, and a failing scenario
## that reports success there is the wrong answer to give the cheapest question.
func _finish() -> void:
	print(format_line("done", "ok", _role))
	get_tree().quit(1 if _failed else 0)

## Audit this file's own source before either peer boots: no `_await_…` call may be bare
## (see `unawaited_waits`). Returns false — and ends the run with a non-zero exit — when the
## audit fails, because a scenario whose waits are no-ops reports on a run that did not
## happen. Source that is not on disk (an exported build ships bytecode) reports `skipped`:
## an audit that could not run is not a pass, and saying which of the two happened is the
## whole value of running it here rather than trusting the file to stay correct.
func _self_audit() -> bool:
	var src := _own_source_lines()
	if src.is_empty():
		print(format_line("self_audit", "ok", "source-not-on-disk-skipped"))
		return true
	var offenders := unawaited_waits(src)
	if offenders.is_empty():
		print(format_line("self_audit", "ok", "awaits-present"))
		return true
	_report("self_audit", "fail", "bare-await-call-at-" + "-".join(offenders))
	_finish()
	return false

## This runner's own source as lines, or an empty array when it is not readable off disk.
func _own_source_lines() -> PackedStringArray:
	var f := FileAccess.open("res://src/tests/net_harness.gd", FileAccess.READ)
	if f == null:
		return PackedStringArray()
	return f.get_as_text().split("\n")

# ---------------------------------------------------------------------------
# Steps
# ---------------------------------------------------------------------------

## Step 1 — the handshake, and the identity rule with it.
##
## Client: presents an id it does not own; asserts the host bound it to something else.
## Host: binds the connection, and asserts the bound id is NOT the claimed one — the
## acting identity comes from the CONNECTION, never from the payload's claim.
func _step_handshake() -> void:
	if _role == "host":
		var ok: bool = await _await_until(func(): return _discover_peer() != 0, STEP_TIMEOUT_SECS)
		if not ok:
			_report("handshake", "fail", "no_peer_bound")
			return
		var bound := _bound_id()
		_bound_player_id = bound
		_report("handshake", verdict(bound != SPOOFED_ID, true),
			"identity-from-connection" if bound != SPOOFED_ID else bound)
		return
	# The client's counterpart is the host, which is ENet peer 1 to every peer it serves.
	_bound_peer = 1
	# The predicate has to wait for the answer, not merely for a non-empty value: the
	# harness itself wrote SPOOFED_ID into `claimed_player_id` before joining, so
	# "non-empty" was already true and the step would report the CLAIM as though it were
	# the host's answer.
	var assigned_ok: bool = await _await_until(
		func(): return str(_root._networking.claimed_player_id) not in ["", SPOOFED_ID],
		STEP_TIMEOUT_SECS)
	if not assigned_ok:
		_report("handshake", "fail", "no_identity_assigned")
		return
	var assigned := str(_root._networking.claimed_player_id)
	_report("handshake", verdict(assigned != SPOOFED_ID, true),
		"identity-from-connection" if assigned != SPOOFED_ID else assigned)

## Step 2 — the chunked snapshot completes across real packets.
##
## The world snapshot is far larger than `SNAPSHOT_CHUNK_SIZE`, so it genuinely arrives
## as several reliable packets that the CLIENT has to reassemble in order. The host
## proves it sent them; the client proves it consumed them (buffer drained, world
## applied), which is reassembly working with the transport's own ordering rather than a
## test's.
func _step_snapshot_complete() -> void:
	if _role == "host":
		var ok: bool = await _await_until(func(): return _root._networking._next_snapshot_id >= 1, STEP_TIMEOUT_SECS)
		_report("snapshot_complete", verdict(ok, true), "reassembled" if ok else "no_snapshot_sent")
		return
	var ok: bool = await _await_until(
		func(): return not _root._snapshot_pending and _root._networking._snapshot_buffer.is_empty() and not _root._voxel.get_heightmaps().is_empty(),
		STEP_TIMEOUT_SECS)
	_report("snapshot_complete", verdict(ok, true), "reassembled" if ok else "incomplete")

## Step 3 — the reach guard, passing half.
##
## The client reports a position and names a tree inside reach. The tree's position is
## resolved on the HOST, from the host's own TreeSlice — the intent carries an id and
## nothing else — so a pass here means the host measured against its own evidence.
func _step_chop_in_reach() -> void:
	var targets := _targets()
	if targets.is_empty():
		_report("chop_in_reach", "fail", "no_in_reach_target")
		return
	var t := str(targets[0])
	if _role == "host":
		var ok: bool = await _await_until(func(): return _chop_count(t) >= 1, STEP_TIMEOUT_SECS)
		_report("chop_in_reach", verdict(ok, true), t if ok else "not_consumed")
		return
	_report_position()
	await _await_settle(1.0)
	GameBus.tree_chop_requested.emit(t, "")
	await _await_settle(1.5)
	_report("chop_in_reach", "ok", t)

## Step 4 — the reach guard, refusing half: a chop of a tree the peer cannot reach is
## dropped, and nothing else about the peer changes.
func _step_chop_out_of_reach() -> void:
	# Phase 42 review — the target is drawn from THIS side's own tree table, and on a
	# freshly-booted world (CI's, or any first run) the client's table is only what its
	# snapshot seeded: the host streams chunks on a per-frame budget, so a tree beyond
	# `TARGET_BEYOND` may simply not have arrived yet when the scenario reaches this step.
	# Reporting `no_distant_tree` at that instant makes the step a race against the
	# streamer rather than a test of the guard. Wait for the table to carry one, bounded by
	# `STEP_TIMEOUT_SECS`, and only then judge the guard. The await is re-derived rather
	# than captured: a GDScript lambda snapshots its captures by value, so a `t` assigned
	# inside the predicate would not be visible here.
	var found: bool = await _await_until(
		func(): return beyond_reach_target(_trees(), RENDEZVOUS, TARGET_BEYOND) != "",
		STEP_TIMEOUT_SECS)
	var t := beyond_reach_target(_trees(), RENDEZVOUS, TARGET_BEYOND)
	if not found or t == "":
		_report("chop_out_of_reach", "fail", "no_distant_tree")
		return
	if _role == "host":
		await _await_settle(ABSENCE_WINDOW_SECS)
		# A chop that DID land here means the guard let an out-of-reach intent through —
		# so the tree's position is the evidence, and this side reads it from its own
		# TreeSlice rather than from anything the peer said.
		var leaked := _any_beyond_consumed()
		_report("chop_out_of_reach", verdict(leaked, false),
			"none_seen" if not leaked else "consumed_out_of_reach")
		return
	_report_position()
	await _await_settle(0.5)
	GameBus.tree_chop_requested.emit(t, "")
	await _await_settle(1.5)
	_report("chop_out_of_reach", "refused", t)

## Step 5 — the inbound size cap.
##
## The same intent is sent twice, naming two DIFFERENT trees: once padded far past
## `MAX_CLIENT_PACKET_BYTES` (the host must refuse it WITHOUT disconnecting the peer) and
## once at normal size (which must be consumed). Asserting both halves is what separates
## "the cap works" from "everything from this peer is being dropped", and the two trees are
## dedicated to this step so the absence half is exact — `targets[1]` is never named
## anywhere else, so if it was ever consumed the cap leaked.
func _step_packet_cap() -> void:
	var targets := _targets()
	if targets.size() < 3:
		_report("packet_cap", "fail", "no_targets")
		return
	var oversized := str(targets[1])
	var normal := str(targets[2])
	if _role == "host":
		var ok: bool = await _await_until(func(): return _chop_count(normal) >= 1, STEP_TIMEOUT_SECS)
		var over_seen := _chop_count(oversized) > 0
		var alive := _live_bound_id() != ""
		_report("packet_cap", verdict(ok and not over_seen and alive, true),
			normal if (ok and not over_seen and alive) else "oversized_leaked")
		return
	_report_position()
	await _await_settle(1.0)
	# 9000 chars of padding on top of the intent's own JSON: unambiguously over the 8192 cap.
	GameBus.packet_send_requested.emit(1, {
		"type": "tree_chop_intent", "tree_id": oversized, "pad": "x".repeat(9000),
	})
	await _await_settle(1.0)
	GameBus.tree_chop_requested.emit(normal, "")
	await _await_settle(1.5)
	_report("packet_cap", "ok", normal)

## Step 6 — the per-peer token bucket.
##
## A burst of 300 packets in one frame must be throttled (the bucket empties, so most of
## the burst is dropped) and the steady stream that follows must still get through. The host
## reads its OWN bucket for the peer, which is the authoritative statement of what it did
## with the burst; the same tree is chopped AGAIN after the burst, so the second consumption
## is the proof that the peer was neither disconnected nor starved by it.
func _step_rate_bucket() -> void:
	var targets := _targets()
	if targets.size() < 3:
		_report("rate_bucket", "fail", "no_targets")
		return
	var t := str(targets[2])
	if _role == "host":
		_min_tokens = 1.0e9
		var ok: bool = await _await_until(func(): return _steady_check(t), STEP_TIMEOUT_SECS)
		var throttled: bool = _min_tokens < _root._networking.RATE_BUCKET_CAPACITY
		# The live token count is reported alongside the minimum: the minimum says the burst
		# emptied the bucket, and this one says whether the limiter was still the reason the
		# steady stream was missing when the deadline ran out (see the client half).
		var live_tokens: int = int(float(
			_root._networking._rate_buckets.get(_peer_id(), {}).get("tokens", -1.0)))
		_report("rate_bucket", verdict(ok and throttled, true),
			t if (ok and throttled) else "burst_not_throttled_or_steady_lost-steady%d-min%d-now%d" % [
				_chop_count(t), int(_min_tokens), live_tokens])
		return
	_report_position()
	await _await_settle(1.0)
	# The burst rides `player_moved`, NOT an unknown type: the point is the token bucket,
	# which polices the CHANNEL before the payload is parsed (`_allow_packet` runs ahead of
	# `_parse` in `_rpc_c2h`), and an unknown type would have the host emit 300 warnings
	# with stack traces — a log storm that stalls the host's main loop for seconds and
	# gets the peer dropped by ENet's own silence timeout, so the subject of the step would
	# look broken while it was working. RENDEZVOUS in each packet keeps the position the
	# reach guard measures against pinned while the burst is drained.
	#
	# Sent in BATCHES across frames rather than 200 RPCs in one frame: the bucket is what
	# must overflow, and pushing that much through ENet's reliable channel in a single poll
	# killed the connection outright (observed: the host's transport map emptied and every
	# later step reported no bound peer). What is under test is the rate limiter, not
	# ENet's send path, so the burst is spread over frames and still empties the bucket
	# (200 packets against a 120-token capacity).
	for _batch in range(10):
		for _i in range(20):
			GameBus.packet_send_requested.emit(1, {
				"type": "player_moved",
				"position": [RENDEZVOUS.x, RENDEZVOUS.y, RENDEZVOUS.z],
			})
		await get_tree().process_frame
	# Long enough for the burst to clear and the bucket to refill: the step is about the
	# steady stream NOT being starved, so the chop has to arrive after the burst rather
	# than inside it. Sent three times, spaced, and the host needs only ONE of them — the
	# host's frame can still be draining the burst while the first arrives, and the claim
	# under test is "the stream that follows is not starved", not "the very next packet
	# counts".
	await _await_settle(3.0)
	for _i in range(3):
		GameBus.tree_chop_requested.emit(t, "")
		await _await_settle(1.5)
	_report("rate_bucket", "ok", t)

## Step 7 — an owner-scoped inventory sync reaches the owner alone.
##
## The host emits the sync the way its own slices do, naming the peer's player id. It
## must arrive at that peer's client (whose pack is the local bucket there) and must NOT
## touch the host's own bucket — one process holds many per-player inventories on the
## same global bus, which is exactly the Phase 37 clobber this pins.
func _step_inventory_owner() -> void:
	if _role == "host":
		var owner := _bound_id()
		if owner == "":
			# The peer id and the size of the live transport map are in the detail on
			# purpose: "no owner" alone cannot distinguish a scenario bug (asking the wrong
			# peer) from a dead connection (the mapping this peer id belonged to is gone).
			_report("inventory_owner", "fail", "no_owner-peer%d-live%d" % [
				_bound_peer, _root._networking._player_ids.size()])
			return
		# The host's own pack is compared BEFORE and AFTER rather than against zero: a
		# dedicated server boots with the local player's SAVED record restored, so its
		# inventory is not empty and "the item is absent" would fail for reasons that have
		# nothing to do with the sync under test. What the step has to show is that the
		# sync changed the OWNER's pack and left this one alone.
		var before: int = int(_root._inventory.get_contents().get(PROBE_ITEM, 0))
		GameBus.inventory_synced.emit(owner, { PROBE_ITEM: 3 }, {})
		var ok: bool = await _await_until(func(): return true, 1.0)
		var after: int = int(_root._inventory.get_contents().get(PROBE_ITEM, 0))
		_report("inventory_owner", verdict(ok and after == before, true),
			"owner-only" if after == before else "host_bucket_clobbered-%d-to-%d" % [before, after])
		return
	var ok: bool = await _await_until(func(): return _root._inventory.get_contents().has(PROBE_ITEM), STEP_TIMEOUT_SECS)
	_report("inventory_owner", verdict(ok, true), "owner-only" if ok else "sync_never_arrived")

## Every chat line this side saw, whole run: `{ channel, sender, text, target }`.
var _chat_seen: Array = []
## Every teleport this side was handed, whole run: `{ chunk, local }`.
var _teleports_seen: Array = []

func _on_chat_posted(channel: String, sender: String, text: String, target: String) -> void:
	_chat_seen.append({ "channel": channel, "sender": sender, "text": text, "target": target })

func _on_player_teleport(pos: Dictionary) -> void:
	_teleports_seen.append(pos)

func _chat_line(channel: String, needle: String, target: String) -> Dictionary:
	for m in _chat_seen:
		if m["channel"] == channel and m["target"] == target and str(m["text"]).contains(needle):
			return m
	return {}

const CHAT_PROBE := "hello from the harness"

## Step 7c — Phase 101: the client's plain line reaches both roles with the same sanitised text, said
## by the client's handle. The packet carries only text, so no name it claimed can be the sender.
func _step_chat_relayed() -> void:
	if _role == "client":
		_root._chat.submit(CHAT_PROBE + "\u0001!")
	var ok: bool = await _await_until(func(): return not _chat_line("chat", CHAT_PROBE, "").is_empty(), STEP_TIMEOUT_SECS)
	var line := _chat_line("chat", CHAT_PROBE, "")
	var sender := str(line.get("sender", ""))
	var named := sender != "" and sender != SPOOFED_ID and not sender.begins_with("player_")
	if _role == "host":
		named = named and sender == _root._registry.public_handle(_bound_id())
	var same := str(line.get("text", "")) == CHAT_PROBE + "!"
	_report("chat_relayed", verdict(ok and named and same, true),
		"relayed-by-handle" if (ok and named and same) else "not_relayed-ok%d-named%d-same%d" % [int(ok), int(named), int(same)])

## Step 7d — Phase 101: the host runs `/bring <client handle>`; the client's body lands within 1 m of
## the host's, and the host then sees the client's next position report from there.
func _step_admin_teleport() -> void:
	if _role == "host":
		var target := _bound_id()
		var peer := _peer_id()
		var handle: String = _root._registry.public_handle(target)
		var here: Dictionary = _root._player.get_world_pos()
		_root._chat.handle_intent("/bring " + handle, "")
		var ok: bool = await _await_until(func():
			var seen: Dictionary = _root._networking.get_last_known_exact(peer)
			return not seen.is_empty() and seen["chunk"] == here["chunk"] \
				and (seen["local"] as Vector3).distance_to(here["local"]) < 1.0, STEP_TIMEOUT_SECS)
		_report("admin_teleport", verdict(ok, true), "landed-within-1m" if ok else "no_landing")
		return
	var got: bool = await _await_until(func(): return not _teleports_seen.is_empty(), STEP_TIMEOUT_SECS)
	var near := false
	if got:
		var want: Dictionary = _teleports_seen.back()
		var at: Dictionary = _root._player.get_world_pos()
		near = at["chunk"] == want["chunk"] and (at["local"] as Vector3).distance_to(want["local"]) < 1.0
	_report_actual = true
	_report_position()
	await _await_settle(2.5)
	_report_actual = false
	_report_position()
	_report("admin_teleport", verdict(got and near, true), "landed-within-1m" if (got and near) else "no_landing")

## Step 7e — Phase 101: a non-admin's `/give` is refused to that client alone and creates nothing.
func _step_non_admin_refused() -> void:
	if _role == "host":
		var target := _bound_id()
		var inv: Node = _root._registry.get_inventory(target)
		var before: int = inv.get_item_count(PROBE_ITEM) if inv != null else 0
		var ok: bool = await _await_until(func(): return not _chat_line("system", "for admins", target).is_empty(), STEP_TIMEOUT_SECS)
		await _await_settle(1.0)
		var after: int = inv.get_item_count(PROBE_ITEM) if inv != null else 0
		_report("non_admin_refused", verdict(ok and before == after, true),
			"refused-nothing-created" if (ok and before == after) else "not_refused-ok%d-before%d-after%d" % [int(ok), before, after])
		return
	var before: int = int(_root._inventory.get_contents().get(PROBE_ITEM, 0))
	_root._chat.submit("/give %s 5" % PROBE_ITEM)
	var ok: bool = await _await_until(func(): return not _chat_line("system", "for admins", "").is_empty(), STEP_TIMEOUT_SECS)
	await _await_settle(1.0)
	var after: int = int(_root._inventory.get_contents().get(PROBE_ITEM, 0))
	_report("non_admin_refused", verdict(ok and before == after, true),
		"refused-nothing-created" if (ok and before == after) else "not_refused-ok%d-before%d-after%d" % [int(ok), before, after])

## The client re-sends its equipment claim this many times, this far apart, while the host
## grants the item and records the set: 6 x 0.5 s covers a host that is a few seconds slower
## than the client reaches this step.
const EQUIPMENT_RESENDS := 6
const EQUIPMENT_RESEND_GAP := 0.5

## Equippable item the equipment steps use (a fabric key; see `_step_equipment_recorded`).
const EQUIPMENT_FIXTURE_ITEM := "FerriteHelmet"

## Step 7b — a peer's worn set crosses the socket and is recorded by the host, filtered.
##
## The host first puts the item in the peer's bag and syncs it (ownership is the first filter).
## The client sends equip ACTIONS the way the shipped client does (the `equip_intent` bus
## signal, which the networking slice forwards as a packet). Alongside one legitimate action
## it asks for an unknown slot and an unknown item in a real slot: the host must record only
## the legitimate one, under the connection's own player id.
func _step_equipment_recorded() -> void:
	var slot := ""
	var item := ""
	# A pinned fixture keeps the step stable when GameData.ITEMS grows; the sorted scan is
	# only the fallback if the fixture is ever renamed out of the fabric.
	var keys: Array = [EQUIPMENT_FIXTURE_ITEM] + GameData.ITEMS.keys()
	if not GameData.ITEMS.has(EQUIPMENT_FIXTURE_ITEM):
		keys = GameData.ITEMS.keys()
		keys.sort()
	for k in keys:
		var sl := EquipmentRules.slot_of(str(k), GameData.ITEMS)
		if sl != "":
			slot = sl
			item = str(k)
			break
	if item == "":
		_report("equipment_recorded", "fail", "no_equippable_item")
		return
	if _role == "host":
		var owner := _bound_id()
		# A peer can only wear what its own bag holds: grant the item, then tell the owner
		# (the client waits on that sync before it claims the set).
		var bag: Node = _root._registry.get_inventory(owner)
		if bag == null or not bag.add_item(item, 1):
			_report("equipment_recorded", "fail", "grant_failed")
			return
		GameBus.inventory_synced.emit(owner, bag.get_contents(), {})
		var ok: bool = await _await_until(
			func(): return _root._registry.get_equipment(owner) == { slot: item }, STEP_TIMEOUT_SECS)
		_report("equipment_recorded", verdict(ok, true),
			"filtered" if ok else "not_recorded-%s" % str(_root._registry.get_equipment(owner)))
		return
	# The client cannot tell the host's grant from gear its own bag already held (a restored
	# record), so waiting on its own pack is no barrier: a claim sent before the host grants
	# is filtered as unowned. The intent is idempotent, so it is re-sent while the host
	# grants and records, and the host's record is the verdict.
	# Beside the real action: an item in an unknown slot, and an unknown item in a REAL slot
	# (a different one, so it cannot overwrite the claimed slot's key).
	var bad_slot := ""
	for other_slot in EquipmentRules.slots(GameData.ITEMS):
		if other_slot != slot:
			bad_slot = str(other_slot)
			break
	# The client's verdict is that every action actually went out: a counter on the intent
	# signal, not an assumption (the host's record is still the real check). "not_sent" is
	# reachable if the signal is ever rewired or a send is skipped.
	if not GameBus.peer_equipment_synced.is_connected(_note_peer_equipment):
		GameBus.peer_equipment_synced.connect(_note_peer_equipment)
	var sent := [0]
	var count := func(_player: String, _slot: String, _item: String): sent[0] += 1
	GameBus.equip_intent.connect(count)
	for i in EQUIPMENT_RESENDS:
		GameBus.equip_intent.emit("", slot, item)
		GameBus.equip_intent.emit("", "nonexistent_slot", item)
		if bad_slot != "":
			GameBus.equip_intent.emit("", bad_slot, "no_such_item")
		await _await_settle(EQUIPMENT_RESEND_GAP)
	GameBus.equip_intent.disconnect(count)
	var expected_sent: int = EQUIPMENT_RESENDS * (3 if bad_slot != "" else 2)
	var all_sent: bool = sent[0] == expected_sent
	_report("equipment_recorded", verdict(all_sent, true), "filtered" if all_sent else "not_sent-%d" % sent[0])

## Step 7c — the host's own worn set is delivered to a peer inside its AOI.
##
## The listen host has no peer id, so its gear used to be the one set that never left the
## host. The host records a worn set for its own player (holding the item); the
## networking slice must fan it out to the client as `peer_equipment` for the server peer,
## and the client's character slice must hold it. The host's verdict is the delivery
## bookkeeping (the pair was sent), the client's is the set it now holds for peer 1; the
## detail is the same string on both sides.
func _step_equipment_delivered() -> void:
	var slot := ""
	var item := EQUIPMENT_FIXTURE_ITEM
	if GameData.ITEMS.has(item):
		slot = EquipmentRules.slot_of(item, GameData.ITEMS)
	if slot == "":
		_report("equipment_delivered", "fail", "no_equippable_item")
		return
	var want: Dictionary = { slot: item }
	var host_id: int = _root._networking.HOST_PEER_ID
	if _role == "host":
		var local_id: String = _root._registry.local_player_id
		if local_id == "":
			_report("equipment_delivered", "fail", "no_local_player")
			return
		# The host records its own worn set the way its avatar does. It has to HOLD the item:
		# a worn item the bag does not hold is cleared again on the next inventory event, which
		# is how an unowned set would vanish from under this step.
		if not _root._inventory.add_item(item, 1):
			_report("equipment_delivered", "fail", "grant_failed")
			return
		_root._registry.record_equipment(local_id, want)
		var key: String = _root._networking._pair_key(_bound_peer, host_id)
		var ok: bool = await _await_until(
			func(): return _root._networking._equipment_sent.has(key), STEP_TIMEOUT_SECS)
		_report("equipment_delivered", verdict(ok, true), "delivered" if ok else "not_sent-%s" % key)
		return
	# Judged on what ARRIVED, not on what the character slice still holds: the host runs ahead
	# and may drop this connection (the reconnect step) while this side is still finishing the
	# previous step, and a dropped connection forgets the peer's stored set.
	var got: bool = await _await_until(
		func(): return _seen_peer_equipment.get(host_id, {}) == want, STEP_TIMEOUT_SECS)
	_report("equipment_delivered", verdict(got, true),
		"delivered" if got else "not_delivered-%s" % str(_seen_peer_equipment.get(host_id, {})))

## Worn sets this client has been sent for other peers ({ peer_id: set }), noted as they arrive
## (connected at the start of `_step_equipment_recorded`, the step before the delivery one).
var _seen_peer_equipment: Dictionary = {}

func _note_peer_equipment(peer_id: int, worn: Dictionary) -> void:
	_seen_peer_equipment[peer_id] = worn.duplicate()

## Step 8 — a creature's round against the peer, resolved and floored on the HOST.
##
## The host emits the round the way its own combat path does. It must apply the hit to
## its OWN durable simulation of that peer (which reaches zero and parks a respawn
## deadline) and forward it, so the peer's own body starts its countdown instead of
## sitting dead with no timer — the soft-lock deliverable 1 closes.
func _step_peer_damage_floor() -> void:
	if _role == "host":
		var peer := _peer_id()
		var target := _bound_id()
		if peer == 0 or target == "":
			_report("peer_damage_floor", "fail", "no_peer")
			return
		GameBus.player_damaged.emit(PlayerSlice.MAX_HP * 2.0, "creature_harness", target)
		var ok: bool = await _await_until(func(): return _root._registry.get_hp(target) == 0.0, STEP_TIMEOUT_SECS)
		var parked: bool = float(_root._registry.get_record(target).get("respawn_deadline", 0.0)) > 0.0
		_report("peer_damage_floor", verdict(ok and parked, true),
			"floor-applied" if (ok and parked) else "no_floor_or_deadline")
		return
	# The "it went down" half is observed over the WHOLE run, not from a window opened here,
	# and the difference is the whole step: the host emits the hit as soon as ITS timeline
	# reaches this step, which can be several of this side's steps early — this peer's own
	# countdown is only `PlayerRules.RESPAWN_DELAY` long, so a body that took the hit can
	# already be back up by the time this step runs. What the step has to rule out is the
	# soft-lock deliverable 1 closes: a body down here with NO countdown behind it. So: a
	# death was announced (only ever emitted through the door that arms the timer), and the
	# body is EITHER still waiting the timer out OR already back at full health — never down
	# with nothing running. Asserting the transient itself would fail for a body that
	# recovered, which is the outcome the fix exists to produce.
	var died: bool = await _await_until(func(): return _deaths > 0, STEP_TIMEOUT_SECS)
	var waiting: bool = not _root._player._alive and _root._player._respawn_timer > 0.0
	var recovered: bool = _root._player._alive and _root._player.get_hp() == PlayerSlice.MAX_HP
	var good: bool = died and (waiting or recovered)
	_report("peer_damage_floor", verdict(good, true),
		"floor-applied" if good else "no_floor-died%d-down%d-timer%.1f" % [
			int(died), int(not _root._player._alive), _root._player._respawn_timer])

## Step 9 — a peer killed before it disconnects reconnects ALIVE.
##
## The client drops its connection mid-death, waits past the host's respawn deadline, and
## reconnects with the identity it was assigned (a genuine reconnect). The host's
## handshake snapshot reads the SAVED copy of the peer's record — `get_player_data()` —
## so the deadline has to be resolved on THAT reader for the client to come back with a
## working body; the client also proves its own countdown ran.
func _step_reconnect_alive() -> void:
	if _role == "host":
		var target := _bound_id()
		var ok: bool = await _await_until(
			func(): return _root._registry.is_online(target) if target != "" else false,
			STEP_TIMEOUT_SECS)
		var resolved_ok: bool = await _await_until(
			func(): return _root._registry.get_hp(target) == PlayerSlice.MAX_HP, STEP_TIMEOUT_SECS)
		var snapshot_resolved: float = float(_root._registry.get_player_data(target).get("hp", -1.0))
		var good := ok and resolved_ok and snapshot_resolved == PlayerSlice.MAX_HP
		# The failure token says WHICH half of "the peer came back" was missing, because
		# "still_down" alone cannot distinguish the three ways it can be false: the peer
		# never rejoined (`live0`), it rejoined as a DIFFERENT player (`same0`), or it
		# rejoined but its deadline did not resolve on the reader this step reads.
		_report("reconnect_alive", verdict(good, true),
			"alive-after-reconnect" if good else "still_down-live%d-same%d-online%d-buf%d" % [
				int(_live_bound_id() != ""), int(_live_bound_id() == target),
				int(_root._registry.is_online(target)), _root._networking._snapshot_buffer.size()])
		return
	# The "it was down" half is the same whole-run observation as step 8's, for the same
	# reason: the hit is forwarded on the HOST's timeline while this side's own countdown runs
	# on ITS own, so the death can be over before this step opens (see `_deaths`). A counted
	# death is the evidence that the body was handed a zero with a timer; what this step
	# asserts is the state AFTER the reconnect, below.
	var was_down: bool = await _await_until(func(): return _deaths > 0, STEP_TIMEOUT_SECS)
	_root._networking.disconnect_all()
	# Phase 37/38 — the transport state dies with the connection, and the reassembly
	# buffer is the part that leaks: a snapshot that lost a chunk can never complete.
	var buffer_cleared: bool = _root._networking._snapshot_buffer.is_empty()
	await _await_settle(RECONNECT_WAIT_SECS)
	var err: Error = _root._networking.join(_root._host_address, _root._networking.DEFAULT_PORT)
	if err != OK:
		_report("reconnect_alive", "fail", "rejoin_failed")
		return
	# Mirror `game_root._boot_client()` exactly, which the first join in `run()` already did:
	# a client that has just joined is WAITING for its world snapshot, and that flag is what
	# arms the client's own handshake retry (`_tick_client_handshake`). Without it the rejoin
	# got exactly ONE join intent, sent before the new socket was up — the RPC then errors
	# out ("multiplayer peer which is not connected") and there is no second attempt, which is
	# a harness that does not drive the shipped client's boot path after all.
	_root._snapshot_pending = true
	_root._handshake_elapsed = 0.0
	_root._handshake_retries = 0
	_root._networking.request_handshake()
	# The client's own countdown is the half that makes the body CONTROLLABLE again: it
	# must have run out (or be about to) and left the body up, not dead with no timer.
	var alive_ok: bool = await _await_until(
		func(): return _root._player._alive and _root._player.get_hp() == PlayerSlice.MAX_HP,
		STEP_TIMEOUT_SECS)
	var controlling: bool = _root._player._respawn_timer <= 0.0
	var good := was_down and buffer_cleared and alive_ok and controlling
	# The failure token names the TRANSPORT state as well as the body's: `conn` is the
	# MultiplayerPeer's own connection status (2 == CONNECTED, and 0 when there is no peer at
	# all) and `claim` is whether a player id is present, so "the client thinks it is fine but
	# the host never bound it" is distinguishable from "the client never got its socket back
	# at all" — which is the difference between a harness race and a transport one.
	var mp: MultiplayerAPI = _root._networking.multiplayer
	var conn: int = 0
	if mp != null and mp.multiplayer_peer != null:
		conn = int(mp.multiplayer_peer.get_connection_status())
	_report("reconnect_alive", verdict(good, true),
		"alive-after-reconnect" if good else "not_recovered-down%d-buf%d-alive%d-timer%.1f-conn%d-claim%d" % [
			int(was_down), int(buffer_cleared), int(alive_ok), _root._player._respawn_timer,
			conn, int(str(_root._networking.claimed_player_id) != "")])

## Step 10 — a disconnect evicts transport state, and a reconnect is re-answered.
##
## Host side of the same event: the reconnecting peer's record is resident again under
## the SAME player id (a genuine reconnect, not a fresh player), the transport state of
## the connection that died is gone, and the reassembly buffer went with it.
func _step_disconnect_evicts() -> void:
	if _role == "host":
		var target := _bound_id()
		# ENet reassigns peer ids on reconnect, so the connection that died has to be
		# resolved again — but the PLAYER id must NOT move, and a reconnect that came back
		# as a new player is exactly the failure this step exists to catch.
		_rediscover_peer()
		var live := _live_bound_id()
		var ok: bool = await _await_until(
			func(): return _root._registry.is_online(target) and _root._registry.get_record(target).size() > 0,
			STEP_TIMEOUT_SECS)
		var buffer_empty: bool = _root._networking._snapshot_buffer.is_empty()
		var same_identity: bool = live == target
		# The dead connection's peer id must not still be bound: a stale mapping points at a
		# body that no longer exists.
		var ghosts := 0
		for pid in _root._networking._player_ids:
			if int(pid) != _peer_id():
				ghosts += 1
		var good := ok and buffer_empty and same_identity and ghosts == 0
		_report("disconnect_evicts", verdict(good, true),
			"evicted" if good else "stale-transport_state-online%d-buffer%d-same%d-ghosts%d" % [
				int(ok), int(buffer_empty), int(same_identity), ghosts])
		return
	var resumed := str(_root._networking.claimed_player_id)
	var ok: bool = await _await_until(
		func(): return _root._networking.claimed_player_id != "" and _root._snapshot_pending == false,
		STEP_TIMEOUT_SECS)
	_report("disconnect_evicts", verdict(ok and resumed != "", true),
		"evicted" if (ok and resumed != "") else "no_identity")

## Phase 52 — the chunk 100 km from the origin (3,125 chunks of 32 m, east) that the far peer
## stands in, with its Z walked until the biome is land (an ocean chunk spawns no land table).
## Both sides derive it from the same seed, so they agree without a message.
func _far_chunk() -> Vector2i:
	for cx in range(3125, 9000, 25):
		for cz in range(-200, 200, 25):
			var c := Vector2i(cx, cz)
			if str(_root._terrain.get_biome_at_chunk(c)) != "Ocean":
				return c
	return Vector2i(3125, 0)   # all ocean: the step then checks the window, not creatures

## Step 13 (Phase 52) — a peer 100 km from the origin has a live world around it.
##
## The client reports a position 100 km away; the host's per-peer streaming window opens
## around it, loads the chunks there, and the creature simulation spawns into them. The
## client's half is the report (it keeps sending it, because the host re-centres the peer's
## window on the last position it heard); the host's half is the assertion.
func _step_far_peers_simulated() -> void:
	var chunk := _far_chunk()
	var pos := Vector3(float(chunk.x) * 32.0 + 16.0, 40.0, float(chunk.y) * 32.0 + 16.0)
	if _role == "host":
		# Phase 62 — a client's claimed position can no longer teleport its window 100 km (the
		# re-centre is rate-limited and capped per move). A peer only gets there when the HOST
		# places it, as a spawn placement does: the host records where it put the peer and opens
		# the window there, then the client's own reports agree with it.
		# The placement is repeated until the window is there: the client may still be mid-
		# reconnect (new peer id) or sending its earlier near-origin reports when this step starts.
		var place := func() -> void:
			var placed: int = _root._registry.get_peer_id(_bound_id())
			if placed <= 0:
				return
			_root._networking.remember_player_state(placed, pos)
			_root._chunk_manager.set_peer_center(placed, chunk, true)
		var simulated := func() -> bool:
			place.call()
			if not _root._chunk_manager._built.has("%d,%d" % [chunk.x, chunk.y]):
				return false
			# An ocean window has no land creatures to spawn (Phase 51): there the proof is
			# that the window's chunk was loaded and built at all, 100 km from the origin.
			if str(_root._terrain.get_biome_at_chunk(chunk)) == "Ocean":
				return true
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					if (_root._creature._by_chunk.get(chunk + Vector2i(dx, dz), []) as Array).size() > 0:
						return true
			return false
		var ok: bool = await _await_until(simulated, 60.0)
		_report("far_peers_simulated", verdict(ok, true), "far-window-simulated" if ok else "far_window_empty-chunk%s-refs%d-built%d-loaded%d-peers%d-biome%s-online%s-lk%d" % [
			str(chunk), _root._chunk_manager.chunk_ref_count(chunk), int(_root._chunk_manager._built.has("%d,%d" % [chunk.x, chunk.y])),
			int(_root._chunk_manager._loaded.has("%d,%d" % [chunk.x, chunk.y])), _root._chunk_manager.peer_window_count(),
			str(_root._terrain.get_biome_at_chunk(chunk)), str(_root._registry.get_online_player_ids()).replace(" ", ""),
			int(_root._networking.has_last_known_state(_peer_id()))])
		return
	# Re-sent for as long as the host needs to stream the window in (a build per chunk on
	# a worker): the client has no view of the host's verdict, so it sends for a fixed time.
	for _i in range(45):
		GameBus.packet_send_requested.emit(1, {
			"type": "player_moved",
			"position": [pos.x, pos.y, pos.z],
		})
		await _await_settle(1.0)
	_report("far_peers_simulated", "ok", "far-window-simulated")

## A player id bound to some connection that is not `old_id` ("" when none): the identity the
## rejoining client was minted.
func _new_identity(old_id: String) -> String:
	for pid in _root._networking._player_ids:
		var bound := str(_root._networking._player_ids[pid])
		if bound != "" and bound != old_id:
			return bound
	return ""

## Step (Phase 54) — the client's world clock tracks the host's.
##
## The host shortens its tick to 0.5 s (for the rest of the run) and reports once it has sent
## six. The client skews its own clock by 0.5 s, waits for six host samples, and then judges
## its clock against the LAST sample (aged by the real time since it arrived): within a second
## is agreed. The 10-minute drift bound is the suite's simulated `clock: client stays within
## 1 s over 10 minutes`; this step proves the same correction over the real socket.
func _step_clock_synced() -> void:
	const TICKS := 6
	if _role == "host":
		_root.clock_tick_seconds = 0.5
		var base: int = _root.clock_ticks_sent
		var ok: bool = await _await_until(func(): return _root.clock_ticks_sent >= base + TICKS, STEP_TIMEOUT_SECS)
		_report("clock_synced", verdict(ok, true), "synced" if ok else "host_sent_%d" % (_root.clock_ticks_sent - base))
		return
	var clock: RefCounted = _root._clock
	var last := { "days": -1.0, "at": 0 }
	var on_tick := func(days: float) -> void:
		last["days"] = days
		last["at"] = Time.get_ticks_msec()
	GameBus.world_clock_received.connect(on_tick)
	clock.time_days += 0.5 / clock.day_seconds()
	var base_rx: int = _root.clock_ticks_received
	var got: bool = await _await_until(func(): return _root.clock_ticks_received >= base_rx + TICKS, STEP_TIMEOUT_SECS)
	GameBus.world_clock_received.disconnect(on_tick)
	var err_s: float = 1.0e9
	if got and float(last["days"]) >= 0.0:
		var aged: float = float(last["days"]) + float(Time.get_ticks_msec() - int(last["at"])) / 1000.0 / clock.day_seconds()
		err_s = absf(clock.time_days - aged) * clock.day_seconds()
	var good: bool = got and err_s <= 1.0
	_report("clock_synced", verdict(good, true), "synced" if good else "got%d-err%.2fs" % [int(got), err_s])

## Step 14 (Phase 53) — a new player given a friend code spawns beside that friend.
##
## The client drops its connection and rejoins as a NEW player (no claimed id) carrying the
## handle of the identity it just had, which is OFFLINE by now and whose record on disk still
## holds the RENDEZVOUS it was placed at — so the host finds the friend through the disk and
## places the newcomer within the fabric's radius of it. The client's own body arrives within
## the same radius of RENDEZVOUS. Both sides report the same token.
func _step_spawn_near_friend() -> void:
	var friend_pos := Vector2(RENDEZVOUS.x, RENDEZVOUS.z)
	var radius: float = float(_root.SpawnFinder.rule()["friend_radius"]) + 1.0
	if _role == "host":
		var old_id := _bound_player_id
		var ok: bool = await _await_until(func(): return _new_identity(old_id) != "", 60.0)
		if not ok:
			_report("spawn_near_friend", "fail", "no_new_identity")
			return
		var fresh := _new_identity(old_id)
		var arr: Variant = _root._registry.get_record(fresh).get("position", [])
		var d: float = 1.0e12
		if arr is Array and (arr as Array).size() >= 3:
			d = Vector2(float(arr[0]), float(arr[2])).distance_to(friend_pos)
		_report("spawn_near_friend", verdict(d <= radius, true),
			"near-friend" if d <= radius else "placed_%dm_away" % int(d))
		return
	var old_handle := str(_root._networking.claimed_handle)
	_root._networking.disconnect_all()
	await _await_settle(RECONNECT_WAIT_SECS)
	_root._networking.claimed_player_id = ""
	_root._networking.friend_code = old_handle
	if _root._networking.join(_root._host_address, _root._networking.DEFAULT_PORT) != OK:
		_report("spawn_near_friend", "fail", "rejoin_failed")
		return
	_root._snapshot_pending = true
	_root._handshake_elapsed = 0.0
	_root._handshake_retries = 0
	_root._networking.request_handshake()
	var arrived: bool = await _await_until(
		func(): return str(_root._networking.claimed_handle) not in ["", old_handle] and not _root._snapshot_pending,
		STEP_TIMEOUT_SECS * 2.0)
	var body: Vector3 = _root._player.get_position()
	var d: float = Vector2(body.x, body.z).distance_to(friend_pos)
	var good: bool = arrived and d <= radius
	_report("spawn_near_friend", verdict(good, true),
		"near-friend" if good else "not_near-arrived%d-%dm" % [int(arrived), int(d)])

# ---------------------------------------------------------------------------
# Plumbing
# ---------------------------------------------------------------------------

func _on_chop_requested(tree_id: String, _player_id: String) -> void:
	_chops.append(tree_id)

## Deaths this side has announced over the whole run.
##
## The sibling of `_chops`, and it exists for the same class of reason. A step that means
## "the peer took the hit" cannot open a window HERE and wait for the body to be DOWN: the two
## processes are not synchronized (see the class docstring), the host forwards the hit as soon
## as ITS timeline reaches that step — which can be several of this side's steps early — and a
## countdown is only `PlayerRules.RESPAWN_DELAY` long, so the body can be back up, at full
## health, before this side ever looks. Observed over the whole run, the transient is seen
## wherever it happened.
##
## It is also the right evidence for "the countdown ran": `player_died` is emitted ONLY
## through the door that arms it (`PlayerSlice.set_hp` / `_die`), so a counted death is proof
## the body was handed a zero and a timer with it — which is what makes "still waiting, or
## already back" an honest assertion rather than a race with the clock.
var _deaths: int = 0

func _on_player_died(_position: Vector3, _killer_id: String) -> void:
	_deaths += 1

## The lowest token level seen for the peer while the rate-limit step waits. Sampled
## inside the convergence predicate rather than once at the end: the bucket refills at
## `RATE_BUCKET_REFILL_PER_SEC`, so a reading taken after the step has converged says
## nothing about what the burst did — the burst's evidence is the MINIMUM, not the final
## value.
var _min_tokens: float = 1.0e9

func _sample_tokens() -> void:
	var bucket: Dictionary = _root._networking._rate_buckets.get(_peer_id(), {})
	_min_tokens = minf(_min_tokens, float(bucket.get("tokens", _min_tokens)))

## The rate-limit step's convergence predicate: sample the bucket, then ask whether the
## steady chop after the burst got through. Two statements, so it cannot be a lambda body
## (GDScript lambdas are single-expression here).
func _steady_check(tree_id: String) -> bool:
	_sample_tokens()
	return _chop_count(tree_id) >= 2

## How many times a tree chop was CONSUMED over the whole run — the pass/fail decision of
## the reach guard, which is "did GameBus.tree_chop_requested fire".
##
## Counted over the whole run rather than inside a per-step window, because the two
## processes are NOT synchronized: one side's steps mostly send and move on, so its traffic
## can arrive while the other side is still waiting on a 25 s convergence deadline. A
## window that opened at the start of the observing step therefore MISSED traffic that had
## already arrived — the harness reported a guard failure for a guard that had worked.
## Every target is named by exactly one step (see the step bodies), so a whole-run count is
## exact, and the count is what lets one tree prove two different things (a first
## consumption and, after the burst, a second one that was not starved).
func _chop_count(tree_id: String) -> int:
	var n := 0
	for id in _chops:
		if str(id) == tree_id:
			n += 1
	return n

## True when any tree beyond the refusal radius was consumed. Used by the out-of-reach step,
## which cannot compare tree ids across processes but CAN check the host's own far set: an
## intent naming a tree that far away must never be consumed.
func _any_beyond_consumed() -> bool:
	for id in _chops:
		var rec: Dictionary = _root._tree.get_tree_record(str(id))
		if rec.is_empty():
			continue
		var pos: Variant = rec.get("position", Vector3.ZERO)
		if pos is Vector3 and Vector2((pos as Vector3).x, (pos as Vector3).z).distance_to(
				Vector2(RENDEZVOUS.x, RENDEZVOUS.z)) > TARGET_BEYOND:
			return true
	return false

## `await`-driven wait for a predicate, bounded by a wall-clock deadline. Yields real
## frames, which is the ONLY reason this runner exists: an ENet peer delivers nothing
## without them.
func _await_until(predicate: Callable, timeout: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if bool(predicate.call()):
			return true
		_keepalive()
		await get_tree().process_frame
	return bool(predicate.call())

## Burn real frames (delivery, not wall-clock-only) for `secs`.
##
## A coroutine, so EVERY call site must `await` it: called bare it returns at the first
## yielded frame and the step runs with no wait at all, which is how this runner's steps
## once reported on a scenario that never waited (see `unawaited_waits`, which audits the
## source for exactly this, and `_self_audit`, which runs the audit on every boot).
func _await_settle(secs: float) -> void:
	var deadline := Time.get_ticks_msec() + int(secs * 1000.0)
	while Time.get_ticks_msec() < deadline:
		_keepalive()
		await get_tree().process_frame

## Keep the connection alive while this side waits, and re-pin the position the reach guard
## measures against while doing it.
##
## ENet drops a peer that goes quiet (`ENET_PEER_TIMEOUT_LIMIT`), and this scenario is full
## of deliberate waits: a step that asserts an ABSENCE waits seconds for something not to
## happen, and a step whose counterpart is still busy waits on a 25 s convergence deadline.
## Without this the client was disconnected mid-scenario — the run where it happened showed
## `[Networking] disconnected from host` on the client and every later host step reporting
## no bound peer, which looked like a broken guard rather than a dead socket.
##
## Deliberately a REAL game packet (`player_state_sync_requested`, the same signal
## `PlayerSlice._broadcast_state` uses) rather than a harness-only no-op: it needs no
## handshake, it is cheap, it is routed harmlessly, and it re-reports RENDEZVOUS — so the
## reach evidence the guard measures against stays pinned for the whole scenario.
const KEEPALIVE_INTERVAL_SECS := 1.0
var _last_keepalive_ms: float = 0.0

func _keepalive() -> void:
	if _role != "client":
		return
	var now := float(Time.get_ticks_msec())
	if now - _last_keepalive_ms < KEEPALIVE_INTERVAL_SECS * 1000.0:
		return
	_last_keepalive_ms = now
	_report_position()

func _report(step: String, verdict_text: String, detail: String) -> void:
	# A `fail` line is this side's assertion NOT holding, so it also decides the process's
	# exit code (see `_finish`): the log is the cross-process channel, but the exit code is
	# what a process check reads without parsing anything.
	if verdict_text == "fail":
		_failed = true
	var line := format_line(step, verdict_text, str(detail).replace(" ", "_"))
	_lines.append(line)
	print(line)

## The client's position, reported the way the shipped client reports it (the same bus
## signal `PlayerSlice._broadcast_state()` uses), so the host's reach guard measures
## against a real movement packet rather than a harness-only path.
func _report_position() -> void:
	if _report_actual:
		var wp: Dictionary = _root._player.get_world_pos()
		GameBus.player_state_sync_requested.emit({
			"position": WorldPos.to_scene(wp, Vector2i.ZERO), "world_pos": wp,
			"hp": PlayerSlice.MAX_HP, "max_hp": PlayerSlice.MAX_HP,
		})
		return
	GameBus.player_state_sync_requested.emit({
		"position": RENDEZVOUS, "hp": PlayerSlice.MAX_HP, "max_hp": PlayerSlice.MAX_HP,
	})

## True while the client reports where its body REALLY is rather than RENDEZVOUS (the admin
## teleport step, which has to show the host the body at its new spot).
var _report_actual: bool = false

## The host saves into its own directory, emptied before the boot: a world record left by
## any earlier run (or by the dev server) would be adopted by `_boot_server` and replace
## the seed `_pin_world_seed` chose, and a stale player record would leak into the scenario.
const HARNESS_SAVE_DIR := "user://net_harness/server/"

func _fresh_save_dir() -> void:
	# This empties a directory, so refuse anything that is not the harness's own scratch dir
	# under user:// (a future edit pointing the constant at a real save folder must fail loudly).
	if not HARNESS_SAVE_DIR.begins_with("user://net_harness/") or ".." in HARNESS_SAVE_DIR:
		push_error("net-harness: refusing to clear '%s' (not under user://net_harness/)" % HARNESS_SAVE_DIR)
		_failed = true
		return
	_root._persistence.server_save_dir = HARNESS_SAVE_DIR
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(HARNESS_SAVE_DIR))
	var dir := DirAccess.open(HARNESS_SAVE_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		dir.remove(file)

## Trees chunk (0,0) must grow for the scenario to draw its targets from it, with margin
## over `TARGETS_NEEDED` (Phase 44: tree count is a seeded roll, and a clearing has none).
const MIN_ORIGIN_TREES := 5

## The seed `_pin_world_seed` chose; checked again once the world record has been loaded.
var _pinned_seed := 0

## Host side: replace the fresh world's random seed with the first seed whose origin chunk
## is a tree biome with at least `MIN_ORIGIN_TREES` trees. Every target the driver compares
## comes from chunk (0,0), so an unlucky random seed (a clearing, a treeless biome) would
## fail the run for a reason unrelated to the guards under test. The client adopts the
## host's seed from the snapshot, so only the host pins it.
func _pin_world_seed() -> void:
	var terrain: Variant = _root._terrain
	var origin := Vector2i(0, 0)
	for candidate in range(1, 1000):
		terrain.set_world_seed(candidate)
		var biome: String = str(terrain.get_biome_at_chunk(origin))
		if _root._tree.tree_count_for(origin, biome) < MIN_ORIGIN_TREES:
			continue
		# Count alone is not enough: the scenario needs `TARGETS_NEEDED` trees within reach
		# of the rendezvous, so trial-spawn the chunk and look at where the trees stand.
		_root._tree.spawn_for_chunk(origin)
		var usable := _targets().size() >= TARGETS_NEEDED
		_root._tree.despawn_for_chunk(origin)
		if usable:
			_pinned_seed = candidate
			return
	push_error("net-harness: no seed gives chunk (0,0) enough trees")
	_failed = true
	_finish()

func _trees() -> Array:
	var t: Variant = _root._tree
	return t.get_all_trees() if t != null and t.has_method("get_all_trees") else []

## The trees of chunk (0,0) — the ONE chunk both processes are guaranteed to hold. The
## host streams chunks on a per-frame budget, so a joining peer's snapshot carries the
## chunks loaded by then and the client seeds exactly those; the two tables therefore
## agree on the origin chunk and can differ elsewhere (see `steps()`). Every target the
## driver compares is drawn from here.
func _shared_trees() -> Array:
	var out: Array = []
	for t in _trees():
		if t is Dictionary and t.get("chunk", null) == Vector2i(0, 0):
			out.append(t)
	return out

func _targets() -> Array:
	return in_reach_targets(_shared_trees(), RENDEZVOUS, TARGET_REACH, TARGETS_NEEDED)

## The one peer this process is talking to: the host's first bound peer, or the host
## (peer 1) from the client's side.
##
## Learned ONCE, in the handshake, and remembered — rather than re-derived from
## `NetworkingSlice._player_ids` at every step. Re-deriving it asked "who is connected
## right now" on each call, which is a different question from "who did this scenario
## handshake with" and answered it differently the moment anything about the live
## mapping changed.
func _peer_id() -> int:
	return _bound_peer

## The scenario's player id — the identity the handshake bound, which is what every step
## means by "the peer". Stable across the reconnect; see `_bound_player_id`.
func _bound_id() -> String:
	return _bound_player_id if _bound_player_id != "" else _root._networking.get_player_id(_peer_id())

## The identity currently bound to THIS peer id — the transport mapping, "" when that
## connection is gone. Distinct from `_bound_id()` on purpose: "is this peer still
## connected" and "which player is this scenario about" stopped having the same answer the
## moment ENet reassigned the peer id on reconnect.
func _live_bound_id() -> String:
	return _root._networking.get_player_id(_peer_id())

## Host side: find the connection this scenario is about — the one the host has BOUND an
## identity to — and remember it. Discovery happens once, here, so every later step asks
## the same question about the same peer rather than "who is connected right now".
func _discover_peer() -> int:
	if _bound_peer != 0:
		return _bound_peer
	for pid in _root._networking._player_ids:
		if str(_root._networking._player_ids[pid]) != "":
			_bound_peer = int(pid)
			return _bound_peer
	return 0

## Forget the transport id and resolve it again — the reconnect step's replacement for the
## connection that died. The PLAYER id is untouched: a genuine reconnect comes back under
## the same one, and this scenario asserts that it does.
func _rediscover_peer() -> int:
	_bound_peer = 0
	return _discover_peer()
