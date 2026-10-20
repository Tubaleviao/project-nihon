extends "res://src/tests/test_support.gd"
## Phase 163 — crowd performance: each fix the Phase 162 report asked for, with the cost it removed
## pinned on a fixed input (relays per tick, AOI cells probed per query, window refreshes per frame).

const RelayBatch := preload("res://src/networking/relay_batch.gd")
const StressRules := preload("res://src/tests/stress_rules.gd")
const RegionStreamer := preload("res://src/persistence/region_streamer.gd")

func register() -> void:
	_run_test("crowd: the relay rule — near every report, far and unchanged thinned", _test_crowd_relay_due_rule)
	_run_test("crowd: one relay packet per peer per tick, never echoed to the mover", _test_crowd_relay_one_packet_per_peer)
	_run_test("crowd: the frame loop flushes relays at most every FLUSH_MS", _test_crowd_relay_paced_flush)
	_run_test("crowd: a relay batch decodes to the per-subject positions", _test_crowd_relay_batch_decodes)
	_run_test("crowd: a malformed relay batch is refused whole", _test_crowd_relay_batch_malformed)
	_run_test("crowd: a distant peer in the AOI still hears once a second", _test_crowd_relay_distant_once_per_second)
	_run_test("crowd: a big batch splits at the packet cap", _test_crowd_relay_batch_split)
	_run_test("crowd: a departed peer leaves no relay state", _test_crowd_relay_forget)
	_run_test("crowd: an AOI query probes a 3x3 block of cells", _test_crowd_aoi_query_cells)
	_run_test("crowd: n crossings in one frame cost one window refresh", _test_crowd_rescopes_one_refresh)
	_run_test("crowd: a re-scope sends only the records the peer does not hold", _test_crowd_rescope_record_delta)
	_run_test("crowd: the stress report fails a series below the baseline", _test_crowd_baseline_gate)
	_run_test("crowd: the faster region lookup names the same regions", _test_crowd_regions_for_chunks_same)

func _test_crowd_relay_due_rule() -> void:
	var near := RelayBatch.NEAR_RADIUS - 1.0
	var far := RelayBatch.NEAR_RADIUS + 30.0
	assert_true(RelayBatch.due(far, true, INF), "a pair's first relay always goes out")
	assert_true(RelayBatch.due(near, true, 1.0), "a near neighbour gets every report")
	assert_false(RelayBatch.due(far, true, 500.0), "a far neighbour skips a report 0.5 s after the last")
	assert_true(RelayBatch.due(far, true, RelayBatch.FAR_GAP_MS), "and gets the next")
	assert_false(RelayBatch.due(near, false, 500.0), "an unchanged position is not resent")
	assert_true(RelayBatch.due(far, false, RelayBatch.KEEPALIVE_MS), "until the keepalive")

func _host(peers: Array) -> NetworkingSlice:
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.set_transport(MemoryTransport.new(peers))
	return n

func _report(n: NetworkingSlice, peer: int, pos: Vector3) -> void:
	n.remember_player_state(peer, pos)
	n._route_c2h(peer, { "type": "player_moved", "pk": WorldPos.pos_to_packet_text(WorldPos.from_world(pos.x, pos.y, pos.z)) })

func _test_crowd_relay_one_packet_per_peer() -> void:
	var peers := [2, 3, 4, 5, 6, 7, 8, 9]
	var n := _host(peers)
	for i in peers.size():
		_report(n, int(peers[i]), Vector3(float(i), 0.0, 0.0))
	assert_true(n.memory_transport().outbox.is_empty(), "a report is queued, not sent on arrival")
	var sent := n.flush_relays()
	# Before Phase 163: one packet per (recipient, subject) pair, the mover included: 8 x 8 = 64.
	assert_eq(sent, peers.size(), "one packet per peer for the whole tick (8, not 64)")
	assert_eq(n._relays.relays, peers.size() * (peers.size() - 1), "each peer hears every other peer once")
	for o in n.memory_transport().outbox:
		assert_eq(str(o["payload"]["type"]), RelayBatch.PACKET_TYPE, "every packet is a batch")
		for e in RelayBatch.decode(o["payload"]):
			assert_true(int(e[0]) != int(o["peer_id"]), "no peer is sent its own position")
	assert_eq(n.flush_relays(), 0, "a tick with no reports sends nothing")
	n.free()

func _test_crowd_relay_paced_flush() -> void:
	var n := _host([2, 3])
	n.remember_player_state(3, Vector3(2.0, 0.0, 0.0))
	_report(n, 2, Vector3(1.0, 0.0, 0.0))
	assert_eq(n.flush_relays(true), 1, "the first paced flush sends")
	_report(n, 3, Vector3(2.0, 0.0, 0.0))
	assert_eq(n.flush_relays(true), 0, "a paced flush inside FLUSH_MS of the last waits")
	assert_true(n._relays.has_pending(), "and keeps the report for the next one")
	n._relays.flushed_ms -= RelayBatch.FLUSH_MS
	assert_eq(n.flush_relays(true), 1, "once FLUSH_MS has passed it sends")
	assert_true(RelayBatch.FLUSH_MS <= 100.0, "a report waits at most 100 ms (the relay lag budget is 250 ms)")
	n.free()

func _test_crowd_relay_batch_decodes() -> void:
	var n := _host([2, 3, 4])
	var spots := { 3: { "chunk": Vector2i(600000, 3), "local": Vector3(31.9, 2.5, 0.1) },
		4: { "chunk": Vector2i(600000, 3), "local": Vector3(12.0, 1.0, 4.0) } }
	n.remember_player_state(2, WorldPos.to_scene(spots[3], Vector2i.ZERO))
	for p in spots:
		n.remember_player_state(int(p), WorldPos.to_scene(spots[p], Vector2i.ZERO))
		n._route_c2h(int(p), { "type": "player_moved", "pk": WorldPos.pos_to_packet_text(spots[p]) })
	for p in spots:
		var relayed := _relays_of_peer(n, int(p)).filter(func(o): return int(o["peer_id"]) == 2)
		assert_eq(relayed.size(), 1, "peer 2 hears subject %d once" % int(p))
		_assert_relay_exact(relayed, spots[p]["chunk"], spots[p]["local"], "subject %d" % int(p))
	# The client applies a batch through the same path as a single relay.
	var seen := []
	var cb := func(pid: int, pos: Vector3) -> void: seen.append([pid, pos])
	GameBus.remote_player_state.connect(cb)
	var client := NetworkingSlice.new()
	add_child(client)
	client._role = NetworkingSlice.Role.CLIENT
	for o in n.memory_transport().outbox:
		if int(o["peer_id"]) == 2:
			client._route_h2c(o["payload"])
	GameBus.remote_player_state.disconnect(cb)
	assert_eq(seen.size(), 2, "both subjects reach the bus")
	for s in seen:
		var want: Vector3 = WorldPos.to_scene(spots[int(s[0])], Vector2i.ZERO)
		assert_true((s[1] as Vector3).distance_to(want) < 1e-3, "subject %d lands where the single relay put it" % int(s[0]))
	client.free()
	n.free()

func _test_crowd_relay_batch_malformed() -> void:
	var pk := WorldPos.pos_to_packet_text(WorldPos.from_world(1.0, 2.0, 3.0))
	assert_eq(RelayBatch.decode({ "s": [3, pk] }).size(), 1, "a good entry decodes")
	assert_eq(RelayBatch.decode({ "s": [3.0, pk] }).size(), 1, "a JSON number id decodes")
	for bad in [null, "x", [3], [3, pk, 4], [3.5, pk], [-1, pk], [0, pk], ["3", pk], [3, 7], [3, "a".repeat(RelayBatch.PK_MAX + 1)]]:
		assert_true(RelayBatch.decode({ "s": bad }).is_empty(), "refused: %s" % str(bad).left(40))
	var long := []
	for i in RelayBatch.BATCH_MAX + 1:
		long.append_array([i + 1, pk])
	assert_true(RelayBatch.decode({ "s": long }).is_empty(), "more subjects than the cap are refused")
	var seen := [0]
	var cb := func(_pid: int, _pos: Vector3) -> void: seen[0] += 1
	GameBus.remote_player_state.connect(cb)
	var client := NetworkingSlice.new()
	add_child(client)
	client._role = NetworkingSlice.Role.CLIENT
	client._route_h2c({ "type": RelayBatch.PACKET_TYPE, "s": [3, pk, -4, pk] })
	GameBus.remote_player_state.disconnect(cb)
	assert_eq(seen[0], 0, "one bad entry drops the whole batch on the client")
	client.free()

func _test_crowd_relay_distant_once_per_second() -> void:
	var b := RelayBatch.new()
	var connected := { 2: true }
	var subject_at := [Vector3(80.0, 0.0, 0.0)]
	var recipients := func(_pos: Vector3) -> Array: return [2]
	var center := func(_peer: int) -> Vector3: return Vector3.ZERO
	var sent_at: Array = []
	# A moving subject 80 m away (inside the 96 m AOI), reporting every 0.5 s for 10 s.
	for k in 21:
		var now := float(k) * 500.0
		subject_at[0] += Vector3(0.0, 0.0, 2.25)
		b.offer(3, "pk%d" % k, subject_at[0])
		if not (b.build(now, connected, recipients, center) as Dictionary).is_empty():
			sent_at.append(now)
	var max_gap := 0.0
	for i in range(1, sent_at.size()):
		max_gap = maxf(max_gap, float(sent_at[i]) - float(sent_at[i - 1]))
	assert_true(max_gap <= 1000.0, "never more than a second between relays (max gap %.0f ms)" % max_gap)
	assert_eq(sent_at.size(), 11, "half the reports reach the far peer (11 of 21)")
	# The same subject standing still: only the keepalive goes out.
	var idle := RelayBatch.new()
	var idle_sent := 0
	for k in 21:
		idle.offer(3, "same", subject_at[0])
		if not (idle.build(float(k) * 500.0, connected, recipients, center) as Dictionary).is_empty():
			idle_sent += 1
	assert_eq(idle_sent, 11, "an idle subject is refreshed once a second, not every report")
	# A last move held back by the far gap (a death push: the body stops reporting) still goes out.
	var last := RelayBatch.new()
	last.offer(3, "before", subject_at[0])
	last.build(0.0, connected, recipients, center)
	last.offer(3, "pushed", subject_at[0])
	assert_true((last.build(200.0, connected, recipients, center) as Dictionary).is_empty(), "inside FAR_GAP_MS the move waits")
	assert_true(last.has_pending(), "and stays queued")
	var late: Dictionary = last.build(RelayBatch.FAR_GAP_MS, connected, recipients, center)
	assert_eq(late.get(2, []), [3, "pushed"], "it goes out once due, with no new report")
	assert_false(last.has_pending(), "and is then cleared")

func _test_crowd_relay_batch_split() -> void:
	var flat := []
	for i in RelayBatch.BATCH_MAX + 3:
		flat.append_array([i + 1, "p"])
	var packets := RelayBatch.packets(flat)
	assert_eq(packets.size(), 2, "one subject past the cap starts a second packet")
	assert_eq((packets[0]["s"] as Array).size(), RelayBatch.BATCH_MAX * 2, "the first packet is full")
	assert_eq(RelayBatch.decode(packets[0]).size() + RelayBatch.decode(packets[1]).size(), RelayBatch.BATCH_MAX + 3,
		"and both decode, nothing lost")

func _test_crowd_relay_forget() -> void:
	var n := _host([2, 3, 4])
	for p in [2, 3, 4]:
		_report(n, p, Vector3(float(p), 0.0, 0.0))
	n.flush_relays()
	assert_eq(n._relays.pair_count(), 6, "three peers remember six pairs")
	_report(n, 3, Vector3(9.0, 0.0, 0.0))
	n._on_peer_disconnected(3)
	assert_eq(n._relays.pair_count(), 2, "a departed peer is forgotten as recipient and as subject")
	assert_false(n._relays.has_pending(), "and its queued report is dropped, so no avatar of it is sent")
	n._on_peer_disconnected(2)
	n._on_peer_disconnected(4)
	assert_eq(n._relays.pair_count(), 0, "nothing is left once everyone left")
	n.free()

func _test_crowd_aoi_query_cells() -> void:
	var n := _host([2])
	assert_eq(n._peer_spatial.cell_size, NetworkingSlice.AOI_RADIUS, "peer cells are one AOI radius wide")
	n.remember_player_state(2, Vector3(10.0, 0.0, 10.0))
	var before: int = n._peer_spatial.probes
	n.aoi_recipients(Vector3(50.0, 0.0, 50.0), [2])
	var probed: int = n._peer_spatial.probes - before
	assert_true(probed <= 9, "one AOI query probes at most 3x3 cells (%d)" % probed)
	var old := SpatialHash.new()   # the 8 m cells the hash had before Phase 163
	old.insert(2, Vector3(10.0, 0.0, 10.0))
	old.query_radius(Vector3(50.0, 0.0, 50.0), NetworkingSlice.AOI_RADIUS)
	assert_true(old.probes >= 600, "the old 8 m cells probed %d cells for the same query" % old.probes)
	assert_eq(n.aoi_recipients(Vector3(50.0, 0.0, 50.0), [2]), [2], "and the answer is the same")
	n.free()

func _test_crowd_rescopes_one_refresh() -> void:
	var src := GDScript.new()
	src.source_code = "extends \"res://src/persistence/snapshot_wiring.gd\"\nvar built := 0\nfunc build_snapshot(_p, _o = true, _c = null, _f = null) -> Dictionary:\n\tbuilt += 1\n\treturn { \"stub\": true }\n"
	src.reload()
	var gr: Node = (load("res://src/core/game_root.gd") as GDScript).new()
	var stub = src.new()
	stub.root = gr
	gr._snapshot_wiring = stub
	var peers := [2, 3, 4, 5, 6, 7, 8, 9]
	var n := _host(peers)
	var reg := PlayerRegistry.new()
	_own(reg)
	var cm := ChunkManager.new()
	var t := [0]
	cm.now_msec = func(): return t[0]
	for p in peers:
		reg.resolve_identity(p)
		cm.set_peer_center(p, Vector2i(0, 0), true)
	gr._networking = n
	gr._registry = reg
	gr._chunk_manager = cm
	gr._is_client = false
	t[0] = 10000
	# Eight peers cross into the next AOI cell in the same frame.
	for p in peers:
		gr._peer_wiring.on_remote_player_state(p, Vector3(100.0, 0.0, 10.0 + float(p)))
	assert_eq(gr._peer_wiring.rescope_refreshes, 0, "nothing is refreshed while the frame's reports arrive")
	assert_eq(gr._peer_wiring.flush_rescopes(), peers.size(), "every crossing gets its snapshot")
	# Before Phase 163 each crossing refreshed the windows itself: eight refreshes for this frame.
	assert_eq(gr._peer_wiring.rescope_refreshes, 1, "one window refresh for eight crossings")
	assert_eq(stub.built, peers.size(), "one snapshot per crossing")
	for p in peers:
		assert_eq(cm.peer_center(p), Vector2i(3, 0), "peer %d's window moved before its snapshot" % p)
	assert_eq(gr._peer_wiring.flush_rescopes(), 0, "a frame with no crossings does nothing")
	gr._chunk_manager = null
	cm.free()
	gr.free()
	n.free()

func _test_crowd_rescope_record_delta() -> void:
	ChunkRecordsScript.clear()
	for x in 4:
		ChunkRecordsScript.set_record(Vector2i(x, 0), _sync_record(Vector2i(x, 0)))
	var gr: Node = load("res://src/core/game_root.gd").new()
	var cm := ChunkManager.new()
	gr._chunk_manager = cm
	var sw = gr._snapshot_wiring
	var join := {}
	sw.add_generation_records(join, 9, Vector3.ZERO)
	assert_eq((join.get("gen_records", {}) as Dictionary).size(), 4, "a join carries every record in the window")
	var again := {}
	sw.add_generation_records(again, 9, Vector3.ZERO, true)
	# Before Phase 163 every re-scope carried all four again.
	assert_false(again.has("gen_records"), "a re-scope over the same window carries none of them")
	assert_true(again.has("gen_scope"), "but still names its scope")
	ChunkRecordsScript.set_record(Vector2i(2, 0), _sync_record(Vector2i(2, 0), "TemperateForest"))
	ChunkRecordsScript.set_record(Vector2i(-1, 0), _sync_record(Vector2i(-1, 0)))
	var changed := {}
	sw.add_generation_records(changed, 9, Vector3.ZERO, true)
	assert_eq((changed.get("gen_records", {}) as Dictionary).keys().size(), 2, "a changed record and a new one go out")
	assert_true((changed["gen_records"] as Dictionary).has(ChunkRecordsScript.key_of(Vector2i(2, 0))), "the changed one")
	assert_true((changed["gen_records"] as Dictionary).has(ChunkRecordsScript.key_of(Vector2i(-1, 0))), "the new one")
	var other := {}
	sw.add_generation_records(other, 10, Vector3.ZERO, true)
	assert_eq((other.get("gen_records", {}) as Dictionary).size(), 5, "another peer has its own table")
	var rejoin := {}
	sw.add_generation_records(rejoin, 9, Vector3.ZERO)
	assert_eq((rejoin.get("gen_records", {}) as Dictionary).size(), 5, "a join starts afresh")
	sw.records_sent.erase(9)
	sw.records_sent.erase(10)
	cm.free()
	gr.free()
	ChunkRecordsScript.clear()

func _test_crowd_baseline_gate() -> void:
	var at := func(n: int) -> Dictionary: return { "largest_passing": n }
	var ok := { "lan/cluster": at.call(32), "lan/cross": at.call(16), "lan/spread": at.call(64), "lan/pole": at.call(32), "lan/churn": at.call(0) }
	assert_true(StressRules.baseline_regressions(ok, 64).is_empty(), "meeting or beating every baseline size passes")
	var worse := ok.duplicate()
	worse["lan/pole"] = at.call(16)
	var regs := StressRules.baseline_regressions(worse, 64)
	assert_eq(regs.size(), 1, "one series below its baseline is one regression")
	assert_true(str(regs[0]).begins_with("lan/pole"), "and it is named")
	assert_true(StressRules.baseline_regressions(worse, 16).is_empty(), "a baseline above the run's ceiling is not judged")
	assert_true(StressRules.baseline_regressions({ "wan_br/pole": at.call(0) }, 64).is_empty(), "a series without a baseline is not judged")
	var md := StressRules.report_markdown(StressRules.build_report([], { "max": "64" }))
	assert_true(md.contains("## Baseline"), "the report has a baseline section")
	assert_eq(StressRules.BASELINE_LARGEST.size(), StressRules.PATTERNS.size(), "every pattern has a lan baseline")

## The Phase 121 rule, written out per chunk and per neighbour as it was before Phase 163 keyed the
## regions once each: every region of a chunk and, near an edge, of the corners of its margin square.
func _regions_reference(chunks: Array, margin: int, recorded_margin: int) -> Dictionary:
	var out := {}
	for c in chunks:
		var chunk: Vector2i = c
		out[RegionStoreScript.region_key(RegionStoreScript.region_of_chunk(chunk))] = true
		var reach := recorded_margin if ChunkRecordsScript.has_record(TerrainSlice.wrap_chunk(chunk)) else margin
		if not RegionStreamer._near_region_edge(chunk, reach):
			continue
		for dx in [-reach, 0, reach]:
			for dz in [-reach, 0, reach]:
				var n := TerrainSlice.wrap_chunk(chunk + Vector2i(dx, dz))
				out[RegionStoreScript.region_key(RegionStoreScript.region_of_chunk(n))] = true
	return out

func _test_crowd_regions_for_chunks_same() -> void:
	ChunkRecordsScript.clear()
	@warning_ignore("integer_division")
	var half := TerrainSlice.circumference_chunks() / 2
	var centers := [Vector2i(0, 0), Vector2i(30, 31), Vector2i(-33, -1), Vector2i(half - 2, 5), Vector2i(-half + 1, 64)]
	for x in range(-2, 3):
		ChunkRecordsScript.set_record(Vector2i(30 + x, 31), _sync_record(Vector2i(30 + x, 31)))
	for center in centers:
		var chunks: Array = []
		for dx in range(-5, 6):
			for dz in range(-5, 6):
				chunks.append(center + Vector2i(dx, dz))
		var got := RegionStreamer.regions_for_chunks(chunks, 4, 1)
		var want := _regions_reference(chunks, 4, 1)
		var gk := got.keys()
		var wk := want.keys()
		gk.sort()
		wk.sort()
		assert_eq(gk, wk, "the window around %s touches the same regions" % str(center))
	ChunkRecordsScript.clear()
