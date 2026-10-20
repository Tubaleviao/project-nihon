extends "res://src/tests/test_support.gd"
## Phase 162 — the crowd stress run: the report builder, the walk patterns, the bots' packets against
## the host's checks, the tick probe and the per-peer state a disconnect has to drop.

const StressRules := preload("res://src/tests/stress_rules.gd")
const StressBotSlice := preload("res://src/tests/stress_bot_slice.gd")
const StressRecorder := preload("res://src/tests/stress_recorder.gd")
const StressBots := preload("res://src/tests/stress_bots.gd")
const TickProbe := preload("res://src/core/tick_probe.gd")

func register() -> void:
	_run_test("stress: percentiles, phase shares and per-peer rates from fixed samples", _test_stress_report_statistics)
	_run_test("stress: hot spots rank a fixed set of growth curves", _test_stress_hot_spot_ranking)
	_run_test("stress: the largest passing size is the last size that met every budget", _test_stress_largest_passing)
	_run_test("stress: hard failures name a crash, a long frame, a drop and an orphan", _test_stress_hard_failures)
	_run_test("stress: relay lag joins sends and arrivals; the report names sizes and hot spots", _test_stress_lag_and_report)
	_run_test("stress: the same seed walks the same paths", _test_stress_paths_deterministic)
	_run_test("stress: patterns walk where they say", _test_stress_pattern_shapes)
	_run_test("stress: a bot walks and reports like a player", _test_stress_mirrored_constants)
	_run_test("stress: a bot's claims pass the host's checks; a malformed one is refused", _test_stress_bot_claims_validated)
	_run_test("stress: tick probe phases are exclusive and its counters reset", _test_stress_tick_probe)
	_run_test("stress: a disconnect drops the peer's receive channels", _test_stress_disconnect_drops_channels)
	_run_test("stress: the stress args are parsed", _test_stress_args)
	_run_test("relay: the interval drops with distance and a held report is released", _test_relay_scheduler_intervals)
	_run_test("relay: a still player is told again only on the heartbeat; a leaver is forgotten", _test_relay_scheduler_heartbeat)
	_run_test("relay: one packet per recipient per tick, not one per subject", _test_relay_batch_per_tick)
	_run_test("relay: a batch decodes to the same positions as per-subject relays", _test_relay_batch_decodes)
	_run_test("relay: a distant peer in the AOI still gets a relay at least once per second", _test_relay_far_once_per_second)

func _test_stress_report_statistics() -> void:
	var samples := [4.0, 1.0, 3.0, 2.0, 5.0]
	assert_eq(StressRules.percentile(samples, 50.0), 3.0, "the median of 1..5 is 3")
	assert_eq(StressRules.percentile(samples, 0.0), 1.0, "p0 is the minimum")
	assert_eq(StressRules.percentile(samples, 100.0), 5.0, "p100 is the maximum")
	assert_true(is_equal_approx(StressRules.percentile(samples, 95.0), 4.8), "p95 interpolates between ranks (4.8)")
	assert_eq(StressRules.percentile([], 95.0), 0.0, "an empty list is 0")
	assert_eq(samples, [4.0, 1.0, 3.0, 2.0, 5.0], "the input is not reordered")
	var shares := StressRules.phase_shares({ "net_in": 250, "chunks": 750 })
	assert_true(is_equal_approx(float(shares["net_in"]), 0.25) and is_equal_approx(float(shares["chunks"]), 0.75),
		"phase shares are each phase over the summed phase time")
	assert_eq(StressRules.phase_shares({ "net_in": 0 })["net_in"], 0.0, "no time at all is a zero share, not a NaN")
	# 10 s connected, 80,000 bytes -> 64 kbit/s; a peer seen for half a second is skipped.
	var kbps := StressRules.peer_kbps({ "7": [80000, 20], "9": [1000, 1] }, { "7": 10.0, "9": 0.5 })
	assert_true(is_equal_approx(float(kbps["7"]), 64.0), "bytes over connected seconds give kbit/s per peer")
	assert_false(kbps.has("9"), "a peer connected under a second has no rate")
	var by_type := StressRules.type_kbps({ "remote_player_state": [40000, 400] }, { "7": 5.0, "8": 5.0 })
	assert_true(is_equal_approx(float(by_type["remote_player_state"]), 32.0), "a type's rate is per connected peer-second")
	var row := StressRules.run_row({ "tick_ms": [1.0, 2.0, 3.0, 4.0], "phase_us": { "chunks": 4000 } }, {}, { "n": 16 })
	assert_true(is_equal_approx(float(row["phase_ms_per_tick"]["chunks"]), 1.0), "phase time is averaged per host tick")
	assert_eq(int(row["size"]), 16, "the crowd size is the bots' n")

func _test_stress_hot_spot_ranking() -> void:
	# A flat 4 ms phase, one growing 0.05 ms per bot from 0, and a tiny flat one; a message type growing
	# 0.2 kbit/s per bot. At 200 bots: growing phase 10 ms (62.5% of 16), flat 4 ms (25%), message 40
	# kbit/s (62.5% of 64) — the tie is broken by name, the flat costs follow.
	var phases := {
		"chunks": [[[16, 4.0], [32, 4.0], [64, 4.0]]],
		"aoi_relay": [[[16, 0.8], [32, 1.6], [64, 3.2]], [[16, 0.1], [32, 0.1]]],
		"save": [[[16, 0.01], [64, 0.01]]],
	}
	var messages := { "remote_player_state": [[[16, 3.2], [32, 6.4], [64, 12.8]]] }
	var ranked := StressRules.rank_hot_spots(phases, messages, 200)
	var names: Array = ranked.map(func(h: Dictionary) -> String: return str(h["name"]))
	assert_eq(names, ["aoi_relay", "remote_player_state", "chunks", "save"], "ranked by projected budget share")
	assert_true(is_equal_approx(float(ranked[0]["growth_per_bot"]), 0.05), "the growth is the fitted slope of the worst series")
	assert_true(is_equal_approx(float(ranked[0]["projected"]), 10.0), "projected to the top of the ladder")
	assert_true(is_equal_approx(float(ranked[1]["projected"]), 40.0), "a message type is projected the same way")
	assert_eq(str(ranked[0]["kind"]), "phase", "a phase is labelled as one")
	assert_eq(str(ranked[1]["kind"]), "message", "and a message type as one")
	var line := StressRules.fit_line([[1, 3.0], [2, 5.0], [3, 7.0]])
	assert_true(is_equal_approx(line.x, 2.0) and is_equal_approx(line.y, 1.0), "the least-squares line of y = 2x + 1")
	assert_eq(StressRules.slope([[5, 1.0]]), 0.0, "one point has no slope")

func _row(size: int, tick: float, kbps: float, frame: float, lag: float) -> Dictionary:
	return { "size": size, "host_tick_p95_ms": tick, "down_kbps_per_peer": kbps, "watch_frame_p95_ms": frame, "relay_lag_ms": lag }

func _test_stress_largest_passing() -> void:
	var rows := [_row(16, 5.0, 20.0, 16.7, 40.0), _row(32, 9.0, 40.0, 17.0, 60.0), _row(64, 15.9, 63.0, 30.0, 200.0),
		_row(128, 25.0, 90.0, 40.0, 300.0)]
	assert_eq(StressRules.largest_passing(rows), 64, "the last size meeting every budget")
	rows[2]["relay_lag_ms"] = 251.0
	assert_eq(StressRules.largest_passing(rows), 32, "one budget missed is a miss")
	assert_eq(StressRules.largest_passing([_row(16, 17.0, 1.0, 1.0, 1.0)]), 0, "no passing size is 0")
	var crashed := _row(64, 1.0, 1.0, 1.0, 1.0)
	crashed["hard_failures"] = ["host: no report (crashed or never finished)"]
	assert_eq(StressRules.largest_passing([_row(16, 5.0, 20.0, 16.7, 40.0), crashed]), 16, "a run with a hard failure never passes")
	var met := StressRules.budgets_met(_row(16, 16.0, 64.0, 33.0, 250.0))
	for k in StressRules.BUDGETS:
		assert_true(bool(met[k]), "a value equal to its budget meets it (%s)" % k)
	var report := StressRules.build_report([
		{ "profile": "lan", "pattern": "cluster", "size": 32, "host_tick_p95_ms": 60.0, "down_kbps_per_peer": 1.0, "watch_frame_p95_ms": 1.0, "relay_lag_ms": 1.0 },
		{ "profile": "lan", "pattern": "cluster", "size": 16, "host_tick_p95_ms": 1.0, "down_kbps_per_peer": 1.0, "watch_frame_p95_ms": 1.0, "relay_lag_ms": 1.0 },
	])
	var s: Dictionary = report["series"]["lan/cluster"]
	assert_eq(int(s["largest_passing"]), 16, "the report's series carry their largest passing size")
	assert_eq(int(s["ladder_stopped_at"]), 32, "and the size whose tick p95 passed the ladder ceiling")
	assert_eq(int(s["runs"][0]["size"]), 16, "runs are listed by size")

func _test_stress_hard_failures() -> void:
	var host := { "frame_gap_max_ms": 10.0, "orphans": { "player_ids": 0 } }
	var watch := { "frame_gap_max_ms": 20.0 }
	var bots := { "dropped_unexpected": 0, "join_failures": 0 }
	assert_true(StressRules.hard_failures(host, watch, bots).is_empty(), "a clean run has no hard failure")
	assert_eq(StressRules.hard_failures({}, watch, bots).size(), 1, "a missing host report (a crash) is one")
	assert_eq(StressRules.hard_failures(host, { "frame_gap_max_ms": 2100.0 }, bots).size(), 1, "a watcher frame over 2 s is one")
	assert_eq(StressRules.hard_failures({ "frame_gap_max_ms": 2001.0 }, watch, bots).size(), 1, "a host frame over 2 s is one")
	assert_eq(StressRules.hard_failures(host, watch, { "dropped_unexpected": 2 }).size(), 1, "a bot dropped without a reason is one")
	var orphaned := StressRules.hard_failures({ "orphans": { "player_ids": 0, "recv_seq_channels": 3 } }, watch, bots)
	assert_eq(orphaned.size(), 1, "an orphaned peer record is one")
	assert_true(str(orphaned[0]).contains("recv_seq_channels"), "and names the record")
	var report := StressRules.build_report([{ "profile": "lan", "pattern": "churn", "size": 16, "hard_failures": ["x"] }])
	assert_eq((report["hard_failures"] as Array).size(), 1, "the report collects every run's hard failures")

func _test_stress_lag_and_report() -> void:
	var sends := { "5|1,2,3,4,5": 1000, "6|1,2,3,4,5": 1100 }
	var seen := [[5, "1,2,3,4,5", 1040], [6, "1,2,3,4,5", 1400], [7, "9,9,9,9,9", 2000]]
	assert_eq(StressRules.relay_lags(sends, seen), [40.0, 300.0], "lag is arrival minus send; an unmatched arrival is skipped")
	var rows := [
		StressRules.run_row({ "tick_ms": [2.0, 3.0], "phase_us": { "aoi_relay": 2000 }, "out_type": { "remote_player_state": [1000, 10] },
			"peer_seconds": { "5": 2.0 }, "out_peer": { "5": [1000, 10] }, "pattern": "cluster", "profile": "lan" },
			{ "frame_ms": [16.7], "relay_seen": [seen[0]] }, { "n": 16, "sends": sends }),
	]
	var report := StressRules.build_report(rows, { "seconds": "20" })
	var md := StressRules.report_markdown(report)
	assert_true(md.contains("| lan/cluster | 16 |"), "the markdown names the series and its largest passing size")
	assert_true(md.contains("AOI relays and equipment pairs"), "and its hot spots by label")
	assert_true(md.contains("## Hard failures") and md.contains("None."), "and says when nothing failed hard")
	assert_true((report["hot_spots"] as Array).size() >= 3, "the report ranks at least three hot spots")

func _test_stress_paths_deterministic() -> void:
	for pattern in StressRules.PATTERNS:
		var a: Array = []
		var b: Array = []
		for bot in range(4):
			for t in [0.0, 1.5, 7.25, 30.0]:
				a.append(StressRules.bot_offset(pattern, 7, bot, t))
				b.append(StressRules.bot_offset(pattern, 7, bot, t))
		assert_eq(a, b, "%s: the same seed gives the same path" % pattern)
	var differ := false
	for bot in range(4):
		if StressRules.bot_offset("cluster", 7, bot, 5.0) != StressRules.bot_offset("cluster", 8, bot, 5.0):
			differ = true
	assert_true(differ, "a different seed walks different paths")
	var on_a: Array = []
	var on_b: Array = []
	for i in range(60):
		on_a.append(StressRules.online_at("churn", 3, 2, float(i) * 0.5))
		on_b.append(StressRules.online_at("churn", 3, 2, float(i) * 0.5))
	assert_eq(on_a, on_b, "the churn schedule is seeded too")
	assert_true(on_a.has(true) and on_a.has(false), "and a churning bot both joins and leaves within 30 s")
	assert_true(StressRules.online_at("cluster", 3, 2, 0.0), "other patterns are always online")

func _test_stress_pattern_shapes() -> void:
	var step := StressRules.WALK_SPEED * StressRules.SEND_INTERVAL
	for bot in range(6):
		var prev := StressRules.bot_offset("cluster", 1, bot, 0.0)
		for i in range(1, 80):
			var p := StressRules.bot_offset("cluster", 1, bot, float(i) * StressRules.SEND_INTERVAL)
			assert_true(p.length() <= StressRules.CLUSTER_RADIUS + 0.001, "cluster stays inside its disc")
			assert_true(p.distance_to(prev) <= step + 0.001, "and moves no faster than a walk")
			prev = p
	var far := StressRules.bot_offset("spread", 1, 3, 60.0)
	assert_true(far.length() > NetworkingSlice.AOI_RADIUS * 2.0, "spread walks out of the spawn's AOI within a minute")
	var xs: Array = []
	for i in range(200):   # 100 s of walking: more than one lap of the line
		var c := StressRules.bot_offset("cross", 1, 0, float(i) * 0.5)
		xs.append(c.x)
	assert_true(xs.min() < -NetworkingSlice.AOI_RADIUS * 0.5 and xs.max() > NetworkingSlice.AOI_RADIUS * 0.5,
		"cross paces a line longer than an AOI cell, through the anchor")
	var pole_t := float(StressRules.POLE_START_CHUNKS + 1) * TerrainSlice.CHUNK_METERS / StressRules.WALK_SPEED
	assert_true(StressRules.bot_offset("pole", 1, 0, pole_t).y > float(StressRules.POLE_START_CHUNKS) * TerrainSlice.CHUNK_METERS,
		"pole walks north past the fold row")

func _test_stress_mirrored_constants() -> void:
	assert_eq(StressRules.WALK_SPEED, PlayerSlice.SPEED, "a bot walks at the player's speed")
	assert_true(is_equal_approx(StressRules.SEND_INTERVAL, float(PlayerSlice.SYNC_INTERVAL) / float(Engine.physics_ticks_per_second)),
		"and reports as often as a client")
	assert_eq(StressRules.LADDER, [16, 32, 64, 128, 200], "the ladder is the roadmap's")
	var script_text := FileAccess.get_file_as_string("res://tools/stress.sh")
	assert_true(script_text.contains('LADDER="%s"' % " ".join(StressRules.LADDER.map(func(n): return str(n)))),
		"tools/stress.sh climbs the same ladder")
	assert_true(script_text.contains('PATTERNS="${STRESS_PATTERNS:-%s}"' % " ".join(StressRules.PATTERNS)),
		"and runs the same patterns")
	assert_true(StressRecorder.MAX_CLIENTS > StressRules.LADDER[StressRules.LADDER.size() - 1],
		"the stress host takes the top of the ladder plus a watcher")

func _test_stress_bot_claims_validated() -> void:
	var host := NetworkingSlice.new()
	add_child(host)
	host._role = NetworkingSlice.Role.HOST
	var bot: Node = StressBotSlice.new()
	add_child(bot)
	bot._role = NetworkingSlice.Role.CLIENT
	bot.set_transport(MemoryTransport.new([1]))
	var client := NetworkingSlice.new()
	add_child(client)
	client._role = NetworkingSlice.Role.CLIENT
	client.set_transport(MemoryTransport.new([1]))
	var exact := { "chunk": Vector2i(250000, 12), "local": Vector3(3.5, 7.25, 30.125) }
	var key: String = bot.report(exact)
	client._on_player_state_sync_requested({ "position": WorldPos.to_scene(exact, Vector2i.ZERO), "world_pos": exact,
		"hp": PlayerSlice.MAX_HP, "max_hp": PlayerSlice.MAX_HP })
	var sent: Array = bot.memory_transport().outbox
	var real: Array = client.memory_transport().outbox
	assert_eq(sent.size(), 1, "a bot's report is one packet to the host")
	if sent.size() == 1 and real.size() == 1:
		assert_eq(sent[0]["payload"], real[0]["payload"], "byte for byte the packet a player's client sends")
		assert_eq(int(sent[0]["peer_id"]), 1, "addressed to the host")
		assert_true(JSON.stringify(sent[0]["payload"]).length() <= NetworkingSlice.MAX_CLIENT_PACKET_BYTES, "under the client packet cap")
		# The host's inbound checks: the rate bucket over two minutes of reports, then the route.
		var allowed := 0
		for i in range(240):
			if host._allow_packet(5, float(i) * StressRules.SEND_INTERVAL * 1000.0):
				allowed += 1
		assert_eq(allowed, 240, "two minutes of reports at a client's rate never empty the rate bucket")
		host._route_c2h(5, sent[0]["payload"])
		assert_eq(host.get_last_known_exact(5).get("chunk"), exact["chunk"], "the host records the bot's exact position")
		assert_eq(TickProbe.position_key(host.get_last_known_exact(5)), key, "under the key the watcher's lag join uses")
		var bad: Dictionary = (sent[0]["payload"] as Dictionary).duplicate()
		bad["pk"] = "not a position"
		var was_quiet := Diag.quiet
		Diag.quiet = true
		var warned := Diag.warn_count()
		host._route_c2h(6, bad)
		Diag.quiet = was_quiet
		assert_false(host.has_last_known_state(6), "a malformed claim is refused like a client's")
		assert_eq(Diag.warn_count(), warned + 1, "with the client's one warning")
	# The host's answers a bot keeps: its identity and the spawn in its join snapshot.
	bot._route_h2c({ "type": "identity_assigned", "player_id": "p_1", "handle": "h_1" })
	var snap := JSON.stringify({ "player": { "position": WorldPos.pos_to_wire(exact) } })
	bot._route_h2c({ "type": "snapshot_chunk", "snapshot_id": 4, "index": 1, "count": 2, "data": snap.substr(10) })
	assert_false(bot.snapshot_done, "half a snapshot is not a join")
	bot._route_h2c({ "type": "snapshot_chunk", "snapshot_id": 4, "index": 0, "count": 2, "data": snap.substr(0, 10) })
	assert_true(bot.joined and bot.snapshot_done, "the identity and the whole join snapshot complete the join")
	assert_eq(bot.claimed_player_id, "p_1", "a reconnect claims the identity it was given")
	assert_eq(bot.spawn.get("chunk"), exact["chunk"], "and the bot walks from the spawn the host chose")
	bot.free()
	client.free()
	host.free()

func _test_stress_tick_probe() -> void:
	TickProbe.reset()
	TickProbe.begin("off")
	TickProbe.end()
	TickProbe.count_out(3, "x", 10)
	assert_true(TickProbe.take_times().is_empty() and (TickProbe.take_wire()["out_peer"] as Dictionary).is_empty(),
		"a disabled probe records nothing")
	TickProbe.enabled = true
	TickProbe.begin("outer")
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < 2000:
		pass
	TickProbe.begin("inner")
	t0 = Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < 3000:
		pass
	TickProbe.end()
	TickProbe.end()
	var times := TickProbe.take_times()
	assert_true(int(times.get("inner", 0)) >= 3000, "the inner phase holds its own time")
	assert_true(int(times.get("outer", 0)) >= 2000 and int(times.get("outer", 0)) < 3000 + 2000,
		"the outer phase excludes the inner one")
	assert_true(TickProbe.take_times().is_empty(), "taking the times resets them")
	TickProbe.count_out(3, "remote_player_state", 40)
	TickProbe.count_out(3, "remote_player_state", 60)
	TickProbe.count_in(3, "player_moved", 30)
	var wire := TickProbe.take_wire()
	assert_eq(wire["out_peer"][3], [100, 2], "bytes and packets per peer")
	assert_eq(wire["out_type"]["remote_player_state"], [100, 2], "and per message type")
	assert_eq(wire["in_type"]["player_moved"], [30, 1], "inbound counted apart")
	assert_true((TickProbe.take_wire()["out_peer"] as Dictionary).is_empty(), "taking the counters resets them")
	TickProbe.relay_seen(4, "k")
	assert_true(TickProbe.take_relays().is_empty(), "relays are logged only for a watcher")
	TickProbe.reset()
	assert_false(TickProbe.enabled, "reset switches the probe off")

func _test_stress_disconnect_drops_channels() -> void:
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.set_transport(MemoryTransport.new([5, 6]))
	for peer in [5, 6]:
		n._dedup(peer, { "type": "player_moved", "seq": 0 })
		n._dedup(peer, { "type": "chat_intent", "seq": 0 })
	n._link_free_at_ms[5] = 10.0
	n._ordered_at_ms[5] = 10.0
	n._on_peer_disconnected(5)
	for table in [n._recv_seq, n._recv_seen]:
		for key in table:
			assert_false(str(key).begins_with("5:"), "the departed peer's receive channel %s is dropped" % key)
	assert_eq((n._recv_seq as Dictionary).size(), 2, "the other peer's channels stay")
	assert_false(n._link_free_at_ms.has(5) or n._ordered_at_ms.has(5), "and so is its emulated link")
	n.free()

func _test_stress_args() -> void:
	var args := ["--stress-bots", "32", "--stress-pattern", "cross", "--stress-seed"]
	assert_true(StressBots.requested(args), "--stress-bots asks for the bot process")
	assert_false(StressBots.requested(["--server"]), "a server boot does not")
	assert_eq(StressBots.arg_value(args, "--stress-bots", "0"), "32", "the crowd size is read")
	assert_eq(StressBots.arg_value(args, "--stress-pattern", "cluster"), "cross", "and the pattern")
	assert_eq(StressBots.arg_value(args, "--stress-seed", "1"), "1", "a flag with no value keeps the default")
	assert_eq(StressRecorder.role_from_args(["--server", "--stress-host", "h.json"]), "host", "--stress-host is the host recorder")
	assert_eq(StressRecorder.role_from_args(["--net-harness", "client", "--stress-watch", "w.json"]), "watch", "--stress-watch the watcher")
	assert_eq(StressRecorder.role_from_args(["--server"]), "", "and a normal boot records nothing")
	for p in StressRules.PATTERNS:
		assert_true(StressRules.is_pattern(p), "%s is a pattern" % p)
	assert_false(StressRules.is_pattern("stampede"), "an unknown pattern is refused")

const RelayScheduler := preload("res://src/networking/relay_scheduler.gd")

func _relay_host(peers: Array) -> NetworkingSlice:
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.set_transport(MemoryTransport.new(peers))
	return n

func _test_relay_scheduler_intervals() -> void:
	var r := RelayScheduler.new()
	assert_true(r.offer(2, 1, "a", 10.0, 0.0), "the first report always goes out")
	assert_true(r.offer(2, 1, "b", 10.0, 1.0), "a near neighbour gets every changed report")
	assert_true(r.offer(3, 1, "a", 90.0, 0.0), "a far neighbour's first report goes out")
	assert_false(r.offer(3, 1, "b", 90.0, 100.0), "a far neighbour's next report inside the interval is held")
	assert_false(r.offer(3, 1, "c", 90.0, 200.0), "and a newer one replaces it")
	assert_true(r.release_due(500.0).is_empty(), "nothing is released before the interval is over")
	var due := r.release_due(RelayScheduler.FAR_MS + 1.0)
	assert_eq(due, [[3, 1, "c"]], "the latest held report is released once the interval is over")
	assert_true(r.release_due(RelayScheduler.FAR_MS * 3.0).is_empty(), "and only once")
	assert_true(RelayScheduler.interval_ms(10.0) < RelayScheduler.interval_ms(40.0) and RelayScheduler.interval_ms(40.0) < RelayScheduler.interval_ms(90.0), "the interval grows with distance")

func _test_relay_scheduler_heartbeat() -> void:
	var r := RelayScheduler.new()
	assert_true(r.offer(2, 1, "a", 10.0, 0.0), "first")
	assert_false(r.offer(2, 1, "a", 10.0, 500.0), "an unchanged position is not sent again")
	assert_true(r.offer(2, 1, "a", 10.0, RelayScheduler.HEARTBEAT_MS), "but a heartbeat tells the neighbour it is still there")
	assert_eq(r.pair_count(), 1, "one pair held")
	r.forget(1)
	assert_eq(r.pair_count(), 0, "a peer that left is forgotten as a subject")
	r.offer(2, 1, "a", 10.0, 0.0)
	r.forget(2)
	assert_eq(r.pair_count(), 0, "and as a recipient")

func _test_relay_batch_per_tick() -> void:
	var n := _relay_host([2, 3, 4, 5, 6])
	for pid in [2, 3, 4, 5, 6]:
		n.remember_player_state(pid, Vector3(float(pid), 0.0, 0.0))
	# Five subjects each report once in one tick; each of five recipients is within range of all of them.
	for pid in [2, 3, 4, 5, 6]:
		n._m2._on_remote_player_state(pid, Vector3(float(pid) + 0.5, 0.0, 0.0))
	assert_true(n.memory_transport().outbox.is_empty(), "nothing is sent before the tick's flush")
	n._m2.flush_relays()
	var outbox: Array = n.memory_transport().outbox
	assert_eq(outbox.size(), 5, "one packet per recipient (was one per recipient per subject: 25)")
	assert_eq(n.relay_packets_sent, 5, "counted")
	assert_eq(n.relay_entries_sent, 25, "carrying every relay")
	n._m2.flush_relays()
	assert_eq(n.memory_transport().outbox.size(), 5, "an empty tick sends nothing")
	n.free()

func _test_relay_batch_decodes() -> void:
	var host := _relay_host([2, 3])
	host.remember_player_state(2, Vector3(1.0, 0.0, 1.0))
	host.remember_player_state(3, Vector3(2.0, 0.0, 2.0))
	var truth := { 2: Vector3(1.25, 3.0, 1.5), 3: Vector3(2.5, 4.0, 2.75) }
	for pid in truth:
		host._m2._on_remote_player_state(pid, truth[pid])
	host._m2.flush_relays()
	var client := NetworkingSlice.new()
	add_child(client)
	client._role = NetworkingSlice.Role.CLIENT
	var got := {}
	var cb := func(pid: int, pos: Vector3): got[pid] = pos
	GameBus.remote_player_state.connect(cb)
	for o in host.memory_transport().outbox:
		if int(o["peer_id"]) == 2:
			assert_eq(o["payload"]["type"], "remote_player_states", "sent as a batch")
			client._m3._route_h2c(JSON.parse_string(JSON.stringify(o["payload"])))
	GameBus.remote_player_state.disconnect(cb)
	assert_eq(got.size(), 2, "both subjects arrive from the one packet")
	for pid in truth:
		assert_true((got[pid] as Vector3).distance_to(truth[pid]) < 0.01, "peer %d decodes to the position a per-subject relay carries" % pid)
	client._m3._route_h2c({ "type": "remote_player_states", "s": "junk" })
	client._m3._route_h2c({ "type": "remote_player_states", "s": [[1], 5, [1, "x", 3]] })
	host.free()
	client.free()

func _test_relay_far_once_per_second() -> void:
	var n := _relay_host([2, 3])
	n.remember_player_state(2, Vector3(0.0, 0.0, 0.0))
	n.remember_player_state(3, Vector3(80.0, 0.0, 0.0))
	var times := []
	var t := 0.0
	# Peer 2 walks at 4.5 m/s and reports every 0.1 s; peer 3 stands 80 m away. Count what peer 3 is sent.
	for i in 40:
		t += 100.0
		var pos := Vector3(0.45 * i, 0.0, 0.0)
		n.remember_player_state(2, pos)
		var pk := WorldPos.pos_to_packet_text(WorldPos.from_world(pos.x, pos.y, pos.z))
		if n._relay_scheduler.offer(3, 2, pk, 80.0 - pos.x, t):
			times.append(t)
		for r in n._relay_scheduler.release_due(t):
			times.append(t)
	assert_true(times.size() >= 4, "a walker is relayed to a distant peer at least once per second over four seconds")
	assert_true(times.size() < 40, "and far fewer than the 40 reports it made")
	for i in range(1, times.size()):
		assert_true(times[i] - times[i - 1] <= 1000.0, "no gap over a second")
	n.free()
