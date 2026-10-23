extends "res://src/tests/test_support.gd"
## Phase 133 — the networking tests, moved unchanged from the old single-file suite.


func register() -> void:
	_run_test("wire: positions travel as chunk + local; old float arrays still read", _test_wire_chunk_local)
	_run_test("wire: one validator for dictionaries and records", _test_one_wire_validator)
	_run_test("wiring: game_root owns no bus connects",       _test_wiring_audit)
	_run_test("wiring: connect_bus is idempotent",            _test_wiring_connect_idempotent)
	_run_test("wiring: unwire leaves no handler behind",      _test_wiring_unwire)
	_run_test("game_root: worldgen stamp wiring on load",     _test_worldgen_stamp_game_root_wiring)
	_run_test("game_root: implausible peer positions dropped",  _test_remote_state_plausibility)
	_run_test("networking: a remote peer's exact position is saved exactly", _test_remote_peer_exact_position)
	_run_test("networking: peer windows and relays use the exact peer position", _test_peer_exact_window_and_relay)
	_run_test("networking: compact per-tick position is exact, small and validated", _test_wire_compact_position)
	_run_test("networking: malformed position warnings are throttled", _test_malformed_position_warning_throttle)
	_run_test("networking: a refused or clamped peer move sends no re-scope", _test_rescope_resent_when_clamped)
	_run_test("networking: first claim is taken and the seam wraps the rate limit", _test_peer_first_claim_and_seam)
	_run_test("networking: equip seq is monotonic and edit signals carry their arity", _test_equip_seq_and_edit_arity)
	_run_test("networking: canonical_world_pos refuses a forged Z and keeps motion", _test_canonical_world_pos_forged_z)
	_run_test("net: broadcasts go through the memory transport",          _test_network_broadcast_uses_memory_transport)
	_run_test("net: test seam follows the boot gate",            _test_network_seam_follows_boot_gate)
	_run_test("net: a scoped apply replaces only its disc",     _test_snapshot_scoped_apply_in_place)
	_run_test("net: within_aoi takes an explicit centre",       _test_net_within_aoi_explicit_center)
	_run_test("boot: a boot quits when its world is up",         _test_quit_after_boot_predicate)
	# Phase 42 fifth review pass — the per-actor harvest, the seam re-scope, the resurrect guard.
	_run_test("net: a remote mine credits the actor",           _test_net_remote_mine_credits_the_actor)
	_run_test("net: a remote place spends the actor's pack",    _test_net_remote_place_spends_the_actor)
	_run_test("net: a remote chop credits the actor",           _test_net_remote_chop_credits_the_actor)
	_run_test("net: client forwards block intent",               _test_net_voxel_client_forwards_intent)
	_run_test("net: apply_block_change applies host edit",       _test_net_voxel_apply_block_change)
	_run_test("net: client does not spawn creatures locally",    _test_net_creature_client_no_local_spawn)
	_run_test("net: creature snapshot round-trips",              _test_net_creature_snapshot_roundtrip)
	_run_test("net: remote player ghost interpolates",           _test_net_player_ghost_interpolation)
	_run_test("net: own peer id does not ghost",                 _test_net_player_ghost_self_filter)
	_run_test("net: creature dirty-track broadcast",             _test_net_creature_dirty_broadcast)
	_run_test("net: creature state position survives the compact wire", _test_net_creature_state_compact_position)
	_run_test("net: inventory replace_contents",                 _test_net_inventory_replace_contents)
	_run_test("net: packets carry per-type monotonic seq",        _test_net_sequence_monotonic)
	_run_test("net: duplicate dropped; reordered-unseen accepted", _test_net_sequence_dedup)
	_run_test("net: emulator queues with monotonic seq",         _test_net_emulator_delivery)
	_run_test("net: emulator drops near loss rate",              _test_net_emulator_loss)
	_run_test("net: emulator jitter centered around zero",       _test_net_emulator_jitter)
	_run_test("net: emulator adds no queue when disabled",       _test_net_emulator_zero_overhead)
	_run_test("net: emulator latency delays delivery",           _test_net_emulator_latency)
	_run_test("net: emulator bandwidth cap bounds a second",     _test_net_emulator_bandwidth)
	_run_test("net: reliable emulation delivers in order",       _test_net_emulator_reliable_in_order)
	_run_test("net: link profiles table and refusal",            _test_net_profiles)
	_run_test("net: jitter buffer interpolates within tolerance", _test_net_jitter_buffer)
	_run_test("net: inventory replace_contents is idempotent",   _test_net_inventory_replace_idempotent)
	_run_test("net: host persists last-known state across disconnect", _test_net_reconnect_last_known_state)
	_run_test("net: emulated loss+reorder — all delivered packets accepted", _test_net_two_peer_loss_reorder)
	_run_test("net: acting identity is the bound connection",    _test_net_peer_party_scopes_identity)
	_run_test("net: social intents bind connection identity",    _test_net_social_intents_bind_connection_identity)
	_run_test("net: trade intents bind connection identity",     _test_net_trade_intents_bind_connection_identity)
	_run_test("net: block edit needs handshake + reach",         _test_net_block_intent_requires_handshake_and_reach)
	_run_test("net: tree chop needs handshake + reach",          _test_net_tree_intent_requires_handshake_and_reach)
	_run_test("net: client packet size is capped",               _test_net_client_packet_size_capped)
	_run_test("net: client packet rate is limited per peer",     _test_net_client_packet_rate_limited)
	_run_test("boot: the automated suite is gated",              _test_boot_suite_is_gated)
	_run_test("net: AOI center defaults to spawn; in_aoi gates", _test_net_aoi_center_and_in_aoi)
	_run_test("net: re-scope snapshot edits hold only AOI chunks", _test_snapshot_edits_scoped_to_aoi)
	_run_test("net: AOI recipients are near peers only",         _test_net_aoi_recipients)
	_run_test("net: AOI region floors to grid cell",             _test_net_aoi_region)
	_run_test("net: player intents bind connection identity",    _test_net_player_intents_bind_connection_identity)
	_run_test("net: own-state push is peer-scoped",              _test_net_own_state_push_is_peer_scoped)
	_run_test("instancing: pool alloc grows and recycles",      _test_multimesh_pool_alloc_recycle)
	_run_test("instancing: headless creature has no visual",    _test_creature_headless_no_visual)
	_run_test("instancing: creatures share one pool",           _test_creature_single_pool)
	_run_test("instancing: headless player has no ghost/broadcast", _test_player_headless_no_ghost_or_broadcast)
	_run_test("peer window: a flood of far claims moves the window at most once", _test_peer_window_rate_limited)
	_run_test("peer window: the interval is measured on the injected clock", _test_peer_window_fake_clock)
	_run_test("peer window: a 20-chunk claim is clamped inside the map and across the seam", _test_peer_window_clamp_cap)
	_run_test("peer window: a seam crossing is a short step, not a planet-wide one", _test_peer_window_clamps_across_seam)
	_run_test("peer window: a host-driven move recentres at once", _test_peer_window_host_driven)
	_run_test("peer window: the host's periodic sync is never a counted refusal", _test_peer_window_host_sync)
	_run_test("peer window: syncs and claims keep separate interval clocks", _test_peer_window_separate_clocks)
	_run_test("peer window: a far host sync is counted apart from refusals", _test_peer_window_sync_far_hops)
	_run_test("peer window: a move into a stored region makes its edits resident", _test_peer_window_move_loads_region_edits)
	_run_test("net: retry re-presents the join intent",           _test_retry_represents_join_intent)
	# Phase 37 review fixes
	_run_test("net: inventory sync is owner-scoped",              _test_inventory_sync_is_owner_scoped)
	_run_test("net: inventory sync is peer-scoped on the wire",   _test_net_inventory_sync_is_peer_scoped)
	_run_test("net: incomplete snapshot is evicted on disconnect", _test_net_incomplete_snapshot_evicted_on_disconnect)
	_run_test("net: a player's damage is routed to their peer",   _test_net_peer_damage_is_peer_scoped)
	_run_test("net: snapshot social keys are one list",           _test_snapshot_social_keys_are_identified)
	_run_test("net: snapshot buffer clears when host is lost",    _test_net_snapshot_buffer_cleared_when_host_lost)
	_run_test("net: harness step table is the driver contract",   _test_net_harness_step_table)
	_run_test("net: harness log line round-trips",                _test_net_harness_line_round_trip)
	_run_test("net: harness verdict treats refusal as a pass",    _test_net_harness_verdict)
	_run_test("net: harness targets are deterministic",           _test_net_harness_target_selection)
	_run_test("net: #429 harness targets arriving late make the step wait, not fail", _test_net_harness_targets_arrive_late)
	_run_test("net: harness awaits are not bare",                 _test_net_harness_bare_await_audit)

func _test_wire_chunk_local() -> void:
	var far := Vector3(1.0e7 + 5.0, 2.0, -70.25)   # a Vector3 is float32: 1 m steps this far out
	var wire := WorldPos.to_wire(far)
	assert_eq(wire["chunk"], [312500, -3], "the chunk index is an exact int on the wire")
	assert_eq(wire["local"], [5.0, 2.0, 25.75], "local is small and exact")
	assert_eq(WorldPos.pos_to_wire(WorldPos.from_world(1.0e7 + 5.125, 2.0, -70.25))["local"], [5.125, 2.0, 25.75],
		"a double-precision position keeps the 0.125 step on the wire")
	var round_trip: Variant = JSON.parse_string(JSON.stringify(wire))
	assert_eq(WorldPos.from_wire(round_trip), far, "the wire form survives a JSON round trip")
	assert_eq(WorldPos.from_wire([1.5, 2.0, 3.5]), Vector3(1.5, 2.0, 3.5), "an old float array is still accepted")
	assert_eq(WorldPos.from_wire("junk", Vector3.ONE), Vector3.ONE, "garbage decodes to the fallback")
	assert_true(WorldPos.is_wire(wire) and WorldPos.is_wire([0, 0, 0]) and not WorldPos.is_wire([0, 0]), "is_wire")
	var c := TerrainSlice.circumference_chunks()
	@warning_ignore("integer_division")
	assert_eq(WorldPos.wire_chunk({"chunk": [c / 2, 4], "local": [0, 0, 0]}), Vector2i(-c / 2, 4), "a wire chunk past the seam is canonical")
	var w := float(c) * TerrainSlice.CHUNK_METERS
	assert_eq(WorldPos.wrap_world(Vector3(w / 2.0 + 3.0, 1.0, 9.0)), Vector3(-w / 2.0 + 3.0, 1.0, 9.0), "X wraps when it crosses the seam")
	var creature := CreatureSlice.new()
	creature.render_visuals = false
	add_child(creature)
	creature.apply_snapshot_creatures([{ "instance_id": "w1", "creature_id": "Wolf", "state": "idle",
		"position": WorldPos.to_wire(far), "hp": 10.0, "respawn_at": -1.0 }])
	var out: Array = creature.get_snapshot_creatures()
	var found := false
	for e in out:
		if e["instance_id"] == "w1":
			found = true
			assert_true(e["position"] is Dictionary and e["position"].has("chunk"), "snapshot creature positions carry {chunk, local}")
	assert_true(found or out.size() == 0, "the creature snapshot round trips")
	creature.free()
	var station := StationSlice.new()
	add_child(station)
	station._insert_station("station_1", "Forge", far)
	var sdata: Array = station.get_station_data()
	assert_true(sdata[0]["position"] is Dictionary, "station positions carry {chunk, local}")
	station.apply_station_data([{ "id": "station_2", "type": "Forge", "position": [1.0, 2.0, 3.0] }])
	assert_true(station.get_station_data().size() == 1, "a legacy float-array station still loads")
	station.free()

func _test_one_wire_validator() -> void:
	var good_dict := {"chunk": [3, -4], "local": [1.0, 2.0, 3.0]}
	assert_true(WorldPos.is_wire(good_dict), "a {chunk, local} dictionary is a wire position")
	assert_true(WorldPos.is_wire({"chunk": [3.0, -4.0], "local": [1, 2, 3]}), "JSON-decoded integer-valued floats pass")
	assert_true(WorldPos.is_wire([1.0, 2.0, 3.0]), "a legacy array is a wire position")
	assert_true(WorldPos.is_wire(WorldPos.to_wire(Vector3(123.0, 4.0, -56.0))), "an encoded position passes")
	assert_false(WorldPos.is_wire({"chunk": [3, -4]}), "a dictionary missing local is refused")
	assert_false(WorldPos.is_wire({"chunk": [1.5, 2], "local": [0, 0, 0]}), "a non-integer chunk is refused")
	assert_false(WorldPos.is_wire({"chunk": [1, 2], "local": [0.0, NAN, 0.0]}), "a NaN component is refused")
	assert_false(WorldPos.is_wire({"chunk": [NAN, 2], "local": [0, 0, 0]}), "a NaN chunk is refused")
	assert_false(WorldPos.is_wire({"chunk": [0, TerrainSlice.pole_chunks() + TerrainSlice.FOLD_MARGIN_CHUNKS + 1], "local": [0, 0, 0]}), "a chunk past the pole and its fold slack is refused")
	assert_false(WorldPos.is_wire({"chunk": [0, 0], "local": [2.0e6, 0, 0]}), "a local beyond a chunk's reach is refused")
	assert_false(WorldPos.is_wire({"chunk": [0, 0, 0], "local": [0, 0, 0]}), "a three-element chunk is refused")
	assert_true(PlayerRegistry.world_pos_of(good_dict)["chunk"] == Vector2i(3, -4), "the registry decodes through the same rule")

## Phase 132 (audit) — `game_root.gd` keeps no `GameBus.<signal>.connect`, stays under 1,200 lines,
## and builds each `*_wiring.gd` module exactly once (listed once in `_wirings`).
func _test_wiring_audit() -> void:
	var src := FileAccess.get_file_as_string("res://src/core/game_root.gd")
	var rx := RegEx.new()
	rx.compile("GameBus\\.\\w+\\.connect")
	assert_true(rx.search(src) == null, "game_root.gd has no GameBus connect outside a wiring module")
	assert_true(src.count("\n") < 1200, "game_root.gd is under 1,200 lines")
	var modules := 0
	for dir_name in DirAccess.get_directories_at("res://src"):
		var dir := "res://src/%s" % dir_name
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with("_wiring.gd") or f == "wiring.gd":
				continue
			modules += 1
			assert_true(src.contains("preload(\"%s/%s\")" % [dir, f]), "%s is preloaded by game_root" % f)
			var cls := f.trim_suffix(".gd").capitalize().replace(" ", "")
			assert_eq(src.count("%s.new()" % cls), 1, "%s is constructed exactly once" % cls)
	var root_script: GDScript = load("res://src/core/game_root.gd")
	var gr: Node = root_script.new()
	assert_eq(gr._wirings.size(), modules, "every wiring module is in the wire list")
	gr.free()

## Phase 150 — `connect_bus` is idempotent: wiring a module twice connects each signal once.
func _test_wiring_connect_idempotent() -> void:
	var root_script: GDScript = load("res://src/core/game_root.gd")
	var gr: Node = root_script.new()
	gr._character = CharacterSlice.new()
	var before := _bus_connection_total()
	var w = gr._combat_wiring
	w.wire(gr)
	var once: int = w.connection_count()
	var on_bus := _bus_connection_total()
	assert_true(once > 0, "the module connects its handlers")
	w.wire(gr)
	assert_eq(w.connection_count(), once, "a second wire adds no connection to the module")
	assert_eq(_bus_connection_total(), on_bus, "a second wire adds no connection to the bus")
	w.unwire()
	assert_eq(_bus_connection_total(), before, "one unwire clears them all")
	gr._character.free()
	gr.free()

## Phase 132 — `unwire` disconnects exactly what `wire` connected, on each boot role, and a freed
## root leaves no handler on the bus.
func _test_wiring_unwire() -> void:
	var root_script: GDScript = load("res://src/core/game_root.gd")
	for role in ["host", "client", "server"]:
		var before := _bus_connection_total()
		var gr: Node = root_script.new()
		gr._is_server = role == "server"
		gr._is_client = role == "client"
		gr._character = CharacterSlice.new()   # the one handler bound to a slice method, not a wiring method
		var connected := 0
		for w in gr._wirings:
			w.wire(gr)
			connected += w.connection_count()
		gr._peer_wiring.wire_colonization()
		gr._peer_wiring.wire_colonization()   # idempotent
		connected += 1
		assert_true(connected > 30, "%s: the modules connect their handlers" % role)
		assert_eq(_bus_connection_total(), before + connected, "%s: every connection is on the bus" % role)
		for w in gr._wirings:
			w.unwire()
			assert_eq(w.connection_count(), 0, "%s: a module holds nothing after unwire" % role)
		assert_eq(_bus_connection_total(), before, "%s: unwire leaves no handler behind" % role)
		gr._character.free()
		gr.free()
	# The production path: GameRoot wires every module in `_ready` and unwires them all from
	# NOTIFICATION_PREDELETE, so freeing a wired root (no manual unwire) must leave the bus as it was.
	for role in ["host", "client", "server"]:
		var before := _bus_connection_total()
		var gr: Node = root_script.new()
		gr._is_server = role == "server"
		gr._is_client = role == "client"
		var ch := CharacterSlice.new()
		gr._character = ch
		for w in gr._wirings:
			w.wire(gr)
		gr._peer_wiring.wire_colonization()
		assert_true(_bus_connection_total() > before, "%s: the wired root holds handlers" % role)
		gr.free()
		assert_eq(_bus_connection_total(), before, "%s: freeing the root unwires every module (PREDELETE)" % role)
		ch.free()

## Phase 71 — the game_root half: loading a record sets the stamp the next save carries and
## raises the bus signal exactly when the record's generator is not the running one.
func _test_worldgen_stamp_game_root_wiring() -> void:
	var root_script: GDScript = load("res://src/core/game_root.gd")
	var gr: Node = root_script.new()
	assert_eq(gr._worldgen_stamp, TerrainSlice.WORLDGEN_VERSION, "a process that loads nothing stamps the running version")
	var seen: Array = []
	var cb := func(recorded: int, running: int) -> void: seen.append([recorded, running])
	GameBus.worldgen_version_mismatch.connect(cb)
	gr._loaded_world = {}
	gr._persistence_wiring.note_worldgen_version()
	assert_true(seen.is_empty(), "a new world raises no mismatch")
	assert_eq(gr._worldgen_stamp, TerrainSlice.WORLDGEN_VERSION, "and takes the running stamp")
	gr._loaded_world = { "worldgenVersion": TerrainSlice.WORLDGEN_VERSION }
	gr._persistence_wiring.note_worldgen_version()
	assert_true(seen.is_empty(), "a matching record raises none")
	gr._loaded_world = { "seed": 7 }
	gr._persistence_wiring.note_worldgen_version()
	assert_true(seen.is_empty(), "an unstamped record raises none")
	assert_eq(gr._worldgen_stamp, TerrainSlice.WORLDGEN_VERSION, "and the next save stamps the running version")
	gr._loaded_world = { "seed": 7, "worldgenVersion": TerrainSlice.WORLDGEN_VERSION - 1 }
	gr._persistence_wiring.note_worldgen_version()
	assert_eq(seen, [[TerrainSlice.WORLDGEN_VERSION - 1, TerrainSlice.WORLDGEN_VERSION]], "an older stamp raises once")
	assert_eq(gr._worldgen_stamp, TerrainSlice.WORLDGEN_VERSION - 1, "and the next save keeps that original stamp")
	GameBus.worldgen_version_mismatch.disconnect(cb)
	gr.free()

## Review of #165 — drop non-finite or absurd positions before any consumer reads them.
func _test_remote_state_plausibility() -> void:
	var root_script: GDScript = load("res://src/core/game_root.gd")
	assert_true(root_script._is_plausible_position(Vector3(10.0, 2.0, -5.0)), "an ordinary position passes")
	assert_true(root_script._is_plausible_position(Vector3(-2.0e7, 0.0, 2.0e7)), "a far planet position passes")
	assert_false(root_script._is_plausible_position(Vector3(NAN, 0.0, 0.0)), "NaN is dropped")
	assert_false(root_script._is_plausible_position(Vector3(0.0, INF, 0.0)), "infinity is dropped")
	assert_false(root_script._is_plausible_position(Vector3(0.0, 0.0, -INF)), "negative infinity is dropped")
	assert_false(root_script._is_plausible_position(Vector3(1.0e9, 0.0, 0.0)), "a coordinate past the planet is dropped")
	var gr: Node = root_script.new()
	gr._is_client = false
	gr._peer_wiring.on_remote_player_state(3, Vector3(NAN, 0.0, 0.0))
	assert_true(gr._peer_aoi_regions.is_empty(), "a rejected claim records no AOI region (and needs no networking slice)")
	gr.free()

## Phase 86 — a peer's report carries `{chunk, local}`; the host keeps it and the fold persists it exactly.
func _test_remote_peer_exact_position() -> void:
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	var chunk := Vector2i(250000, 1000)
	var local := Vector3(12.345, 40.0, 7.891)
	var wire := WorldPos.pos_to_wire({ "chunk": chunk, "local": local })
	n._route_c2h(5, { "type": "player_moved", "position": wire })
	assert_eq(n.get_last_known_exact(5)["chunk"], chunk, "the host holds the exact chunk")
	var reg := PlayerRegistry.new()
	_own(reg)
	var gr: Node = (load("res://src/core/game_root.gd") as GDScript).new()
	gr._networking = n
	gr._registry = reg
	gr._peer_wiring.fold_last_known_state(5, "p5")
	var rec: Dictionary = JSON.parse_string(JSON.stringify(reg.get_record("p5")))
	var reg2 := PlayerRegistry.new()
	_own(reg2)
	reg2.apply_player_data("p5", rec)
	var back: Dictionary = reg2.get_world_pos("p5")
	assert_eq(back["chunk"], chunk, "the saved record reloads in the same chunk")
	assert_true((back["local"] as Vector3).distance_to(local) < 1e-4, "and at the same local, not float32 metres")
	# A malformed report is refused and leaves the previous state alone.
	var was_quiet := Diag.quiet
	Diag.quiet = true
	n._route_c2h(5, { "type": "player_moved", "position": { "chunk": "x", "local": [1, 2] } })
	n._route_c2h(5, { "type": "player_moved" })
	n._route_c2h(5, { "type": "player_moved", "position": { "chunk": [0, 0], "local": [{}, null, "x"] } })
	n._route_c2h(5, { "type": "player_moved", "position": [NAN, 0.0, 0.0] })
	n._route_c2h(5, { "type": "player_moved", "position": { "chunk": [0, 0], "local": [INF, 0.0, 0.0] } })
	Diag.quiet = was_quiet
	assert_eq(n.get_last_known_exact(5)["chunk"], chunk, "a malformed report leaves the exact state")
	assert_true(n.get_last_known_state(5).distance_to(WorldPos.from_wire(wire)) < 1.0, "and the Vector3 state")
	# A legacy array report still records a position, with no exact entry.
	n._route_c2h(6, { "type": "player_moved", "position": [10.0, 2.0, -5.0] })
	assert_eq(n.get_last_known_state(6), Vector3(10.0, 2.0, -5.0), "a legacy report records its Vector3")
	assert_true(n.get_last_known_exact(6).is_empty(), "with no exact position")
	gr._peer_wiring.fold_last_known_state(6, "p6")
	assert_eq(reg.get_world_pos("p6")["chunk"], Vector2i(0, -1), "and the fold falls back to record_position")
	gr.free()
	n.free()

## Phase 97 — near a chunk border far from the origin the float path rounds into the neighbour; the
## window, the relay and the fold all read the exact position instead.
func _test_peer_exact_window_and_relay() -> void:
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.set_transport(MemoryTransport.new([7]))
	var chunk := Vector2i(600000, 3)
	var local := Vector3(31.9, 0.0, 0.1)
	var wire := WorldPos.pos_to_wire({ "chunk": chunk, "local": local })
	n.remember_player_state(7, Vector3(0.0, 0.0, 0.0))
	n._route_c2h(5, { "type": "player_moved", "position": wire })
	var reg := PlayerRegistry.new()
	_own(reg)
	var cm := ChunkManager.new()
	var gr: Node = (load("res://src/core/game_root.gd") as GDScript).new()
	gr._networking = n
	gr._registry = reg
	gr._chunk_manager = cm
	assert_eq(gr._peer_wiring.peer_window_chunk(5), chunk, "the window is centred on the exact chunk")
	# The relay to the other clients carries the exact position. Each relay is asserted on its own: the
	# first (peer 7 remembered at the origin, out of range, so nothing goes out) and the second (peer 7
	# remembered beside the mover, so the exact position does), so one cannot stand in for the other.
	var first := _relays_of_peer(n, 5)
	assert_true(first.is_empty(), "first relay: nothing goes to a peer remembered 600,000 chunks away")
	n.memory_transport().outbox = []
	n.remember_player_state(7, WorldPos.from_wire(wire))
	n._route_c2h(5, { "type": "player_moved", "position": wire })
	var second := _relays_of_peer(n, 5)
	_assert_relay_exact(second, chunk, local, "second relay")
	# An exact position past the pole row is not folded; the record keeps its previous position.
	gr._peer_wiring.fold_last_known_state(5, "p5")
	assert_eq(reg.get_world_pos("p5")["chunk"], chunk, "a sane exact position is folded")
	n._last_known_exact[5] = { "chunk": Vector2i(10, TerrainSlice.pole_chunks() + TerrainSlice.FOLD_MARGIN_CHUNKS + 5), "local": Vector3.ZERO }
	gr._peer_wiring.fold_last_known_state(5, "p5")
	assert_eq(reg.get_world_pos("p5")["chunk"], chunk, "an off-planet exact position leaves the record alone")
	gr._chunk_manager = null
	cm.free()
	gr.free()
	n.free()

## Phase 119 — the compact per-tick form round-trips the exact `{chunk, local}`, is much smaller than the
## dictionary form, and a damaged packet is refused before anything reads a number from it.
func _test_wire_compact_position() -> void:
	@warning_ignore("integer_division")
	var half := TerrainSlice.circumference_chunks() / 2
	for chunk in [Vector2i(1500000, 7), Vector2i(half - 1, -3), Vector2i(-half, 0), Vector2i(0, 0)]:
		var pos := { "chunk": chunk, "local": Vector3(31.875, 12.5, 0.125) }
		var back := WorldPos.pos_from_compact(WorldPos.pos_to_packet_text(pos))
		assert_eq(back.get("chunk"), chunk, "chunk %s round-trips" % chunk)
		assert_eq(back.get("local"), pos["local"], "and so does local")
	var pos2 := { "chunk": Vector2i(1500000, 7), "local": Vector3(31.875, 12.5, 0.125) }
	var compact := var_to_bytes(WorldPos.pos_to_compact(pos2)).size()
	var verbose := var_to_bytes(WorldPos.pos_to_wire(pos2)).size()
	assert_true(float(compact) <= 0.7 * float(verbose), "compact %d bytes vs dictionary %d is at least 30%% smaller" % [compact, verbose])
	var good := WorldPos.pos_to_compact(pos2)
	assert_true(WorldPos.pos_from_compact(good.slice(0, 12)).is_empty(), "a truncated packet is rejected")
	var nan_bytes := good.duplicate()
	nan_bytes.encode_float(12, NAN)
	assert_true(WorldPos.pos_from_compact(nan_bytes).is_empty(), "a non-finite float is rejected")
	var far := good.duplicate()
	far.encode_s32(0, 2000000000)
	assert_true(WorldPos.pos_from_packet({ "pk": Marshalls.raw_to_base64(far) }).is_empty(), "a chunk past the planet is rejected")
	assert_true(WorldPos.pos_from_compact("not base64 !!").is_empty(), "garbage text is rejected")
	# A damaged player_moved is dropped before the state signal (and so any aoi_region) is reached.
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.set_transport(MemoryTransport.new([5]))
	var seen: Array = []
	var cb := func(peer: int, _p: Vector3) -> void: seen.append(peer)
	GameBus.remote_player_state.connect(cb)
	n._route_c2h(5, { "type": "player_moved", "pk": Marshalls.raw_to_base64(good.slice(0, 12)) })
	n._route_c2h(5, { "type": "player_moved", "pk": Marshalls.raw_to_base64(nan_bytes) })
	assert_true(seen.is_empty(), "no consumer saw a damaged position")
	assert_false(n.has_last_known_state(5), "and nothing was remembered")
	var plausible := { "chunk": Vector2i(600000, 7), "local": Vector3(31.875, 12.5, 0.125) }
	n._route_c2h(5, { "type": "player_moved", "pk": WorldPos.pos_to_packet_text(plausible) })
	assert_eq(seen, [5], "a good compact packet goes through")
	assert_eq(n.get_last_known_exact(5).get("chunk"), plausible["chunk"], "with its exact chunk kept")
	GameBus.remote_player_state.disconnect(cb)
	n.free()

## Phase 119 — a hostile peer sends a malformed position per token; the log gets one line per interval.
func _test_malformed_position_warning_throttle() -> void:
	var n := NetworkingSlice.new()
	add_child(n)
	var warned := 0
	for i in 100:
		if n._warn_malformed_position(5, float(i)):
			warned += 1
	assert_eq(warned, 1, "100 malformed packets in one interval warn once")
	assert_true(n._warn_malformed_position(5, NetworkingSlice.MALFORMED_WARN_INTERVAL_MS + 200.0), "and again once the interval ends")
	assert_true(n._warn_malformed_position(6, 1.0), "another peer has its own throttle")
	n.free()

## Phase 119 — a clamped move still re-sends the re-scope snapshot in the same call.
func _test_rescope_resent_when_clamped() -> void:
	var src := GDScript.new()
	src.source_code = "extends \"res://src/persistence/snapshot_wiring.gd\"\nvar built := 0\nfunc _build_snapshot(_p, _o = true, _c = null, _f = null) -> Dictionary:\n\tbuilt += 1\n\treturn { \"stub\": true }\n"
	src.reload()
	var gr: Node = (load("res://src/core/game_root.gd") as GDScript).new()
	var stub = src.new()
	stub.root = gr
	gr._snapshot_wiring = stub
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.set_transport(MemoryTransport.new([5]))
	var reg := PlayerRegistry.new()
	_own(reg)
	reg.resolve_identity(5)
	var cm := ChunkManager.new()
	cm.set_peer_center(5, Vector2i(0, 0), true)
	gr._networking = n
	gr._registry = reg
	gr._chunk_manager = cm
	gr._is_client = false
	gr._peer_wiring.on_remote_player_state(5, Vector3(64.0 * 40.0, 0.0, 0.0))
	gr._peer_wiring.flush_rescopes()   # Phase 163 — crossings are served once a frame
	var sent: Array = n.memory_transport().outbox.filter(func(o): return o["payload"].get("type") == "snapshot_chunk")
	assert_true(sent.is_empty(), "a refused or clamped move builds and sends no snapshot")
	assert_eq(stub.built, 0, "the snapshot builder was not even reached")
	assert_false(gr._peer_aoi_regions.has(5), "and the crossing is forgotten so the window's catch-up retries it")
	n.free()
	cm.free()
	gr.free()

## Phase 119 — the first claim of an uncentred peer is clamped; the X seam is crossed the short way.
func _test_peer_first_claim_and_seam() -> void:
	var cm := ChunkManager.new()
	var t := [0]
	cm.now_msec = func(): return t[0]
	assert_false(cm.set_peer_center(9, Vector2i(1000, 0)), "a client claim for a peer with no center is refused")
	assert_eq(cm.peer_recenter_refused, 1, "and counted")
	assert_true(cm.set_peer_center(9, Vector2i(1000, 0), true), "the host's placement sets the first center")
	assert_eq(cm.peer_center(9), Vector2i(1000, 0), "taken as given (later moves are clamped)")
	@warning_ignore("integer_division")
	var half := TerrainSlice.circumference_chunks() / 2
	cm.set_peer_center(4, Vector2i(half - 2, 0), true)
	t[0] = 10000
	cm.set_peer_center(4, Vector2i(-half + 3, 0))
	assert_eq(cm.peer_center(4), TerrainSlice.wrap_chunk(Vector2i(-half + 3, 0)), "a 5-chunk move across the seam is not clamped")
	t[0] = 20000
	cm.set_peer_center(4, Vector2i(-half + 3 + 40, 0))
	var moved: Vector2i = cm.peer_center(4)
	assert_eq(moved, TerrainSlice.wrap_chunk(Vector2i(-half + 3 + ChunkManager.PEER_RECENTER_MAX_CHUNKS, 0)), "a far move is clamped by the wrapped distance")
	cm.free()

## Phase 119 — a lower equip seq is ignored; block edit signals are emitted with their declared arity and
## the exact aimed point.
func _test_equip_seq_and_edit_arity() -> void:
	var reg := PlayerRegistry.new()
	_own(reg)
	var pid := str(reg.resolve_identity(5))
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.set_transport(MemoryTransport.new([5]))
	n.player_registry = reg
	n.set_player_id(5, pid)
	var intents: Array = []
	var icb := func(_p: String, slot: String, _i: String) -> void: intents.append(slot)
	GameBus.equip_intent.connect(icb)
	n._route_c2h(5, { "type": "equip_intent", "slot": "Chest", "item": "", "seq": 5 })
	n._route_c2h(5, { "type": "equip_intent", "slot": "Head", "item": "", "seq": 3 })
	n._route_c2h(5, { "type": "equip_intent", "slot": "Legs", "item": "", "seq": 6 })
	GameBus.equip_intent.disconnect(icb)
	assert_eq(intents, ["Chest", "Legs"], "the action numbered below one already applied is ignored")
	var mined: Array = []
	var placed: Array = []
	var mcb := func(_pos: Vector3, _n: Vector3, _pl: String, exact: Dictionary) -> void: mined.append(exact)
	var pcb := func(_pos: Vector3, _n: Vector3, _pl: String, _m: String, exact: Dictionary) -> void: placed.append(exact)
	GameBus.block_mine_requested.connect(mcb)
	GameBus.block_place_requested.connect(pcb)
	n.remember_player_state(5, Vector3.ZERO)
	var aimed := { "chunk": Vector2i(0, 0), "local": Vector3(10.5, 3.0, 4.25) }
	n._route_c2h(5, { "type": "block_edit_intent", "action": "mine", "pk": WorldPos.pos_to_packet_text(aimed), "normal": [0, 1, 0] })
	n._route_c2h(5, { "type": "block_edit_intent", "action": "place", "pk": WorldPos.pos_to_packet_text(aimed), "normal": [0, 1, 0], "material": "Stone" })
	GameBus.block_mine_requested.disconnect(mcb)
	GameBus.block_place_requested.disconnect(pcb)
	assert_eq(mined.size(), 1, "the mine signal is emitted")
	assert_eq(placed.size(), 1, "and the place signal")
	if mined.size() == 1:
		assert_eq(mined[0].get("local"), aimed["local"], "carrying the exact aimed point")
	# The client side sends the exact point, not a quantised float position.
	var c := NetworkingSlice.new()
	add_child(c)
	c._role = NetworkingSlice.Role.CLIENT
	c.set_transport(MemoryTransport.new([1]))
	c._on_block_edit_intent("mine", Vector3(10.5, 3.0, 4.25), Vector3.UP, "", { "chunk": Vector2i(600000, 2), "local": Vector3(1.5, 3.0, 4.25) })
	var out: Array = c.memory_transport().outbox
	assert_eq(out.size(), 1, "one intent goes to the host")
	if out.size() == 1:
		assert_eq(WorldPos.pos_from_packet(out[0]["payload"]).get("chunk"), Vector2i(600000, 2), "carrying the exact chunk")
	c.free()
	n.free()

## Phase 119 — a forged Z far past a pole stays on its own side; heading and velocity are kept (and turned
## by a pole crossing).
func _test_canonical_world_pos_forged_z() -> void:
	var pole := TerrainSlice.pole_chunks()
	var forged := PlayerRegistry.canonical_world_pos({ "chunk": Vector2i(3, pole + 5000000), "local": Vector3(1.0, 2.0, 3.0) })
	assert_true(forged["chunk"].y > 0, "a forged +Z does not mirror to the south pole")
	assert_true(forged["chunk"].y <= pole, "and is bounded by the pole row")
	var kept := PlayerRegistry.canonical_world_pos({ "chunk": Vector2i(3, 4), "local": Vector3(1.0, 2.0, 3.0),
		"heading": 1.0, "velocity": Vector3(1, 0, 2) })
	assert_eq(kept.get("heading"), 1.0, "heading survives an ordinary canonicalisation")
	assert_eq(kept.get("velocity"), Vector3(1, 0, 2), "and so does velocity")
	var over := PlayerRegistry.canonical_world_pos({ "chunk": Vector2i(3, pole), "local": Vector3(1.0, 2.0, 3.0),
		"heading": 1.0, "velocity": Vector3(1, 0, 2) })
	assert_eq(over.get("velocity"), Vector3(-1, 0, -2), "a pole crossing turns the velocity")

## Phase 67 — `_broadcast` and `_broadcast_aoi` both fan out through the memory transport only.
func _test_network_broadcast_uses_memory_transport() -> void:
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.set_transport(MemoryTransport.new([4, 5]))
	n._broadcast({ "type": "probe" })
	var got := []
	for m in n.memory_transport().outbox:
		got.append(m["peer_id"])
	got.sort()
	assert_eq(got, [4, 5], "_broadcast reaches exactly the test peers")
	n.memory_transport().outbox.clear()
	n.remember_player_state(4, Vector3.ZERO)
	n.remember_player_state(5, Vector3.ZERO)
	n._broadcast_aoi({ "type": "probe" }, Vector3.ZERO)
	got = []
	for m in n.memory_transport().outbox:
		got.append(m["peer_id"])
	got.sort()
	assert_eq(got, [4, 5], "_broadcast_aoi reaches exactly the test peers in range")
	n.free()

## Phase 67 review — the network test seam follows the boot gate exactly (no private copy of
## the `--run-tests` rule), so a release boot refuses the seam and the suite's boots allow it.
func _test_network_seam_follows_boot_gate() -> void:
	assert_false(NetworkingSlice.transport_injection_allowed_for([], false), "a release boot refuses the test seam")
	assert_true(NetworkingSlice.transport_injection_allowed_for(["--run-tests"], false), "--run-tests allows it")
	assert_false(NetworkingSlice.transport_injection_allowed_for([], true), "a debug build alone does not allow it")
	assert_true(NetworkingSlice.transport_injection_allowed(), "this boot (the suite) allows it")
	# Phase 119 — the injection point itself: allowed here, reports false when refused.
	var n := NetworkingSlice.new()
	add_child(n)
	assert_true(n.set_transport(MemoryTransport.new([1])), "the suite boot may inject a transport")
	assert_eq(n._connected_peers(), [1], "the slice fans out over the injected transport")
	assert_true(n.set_transport(null), "and may take it out again")
	n.free()

## The re-scope path touches only the disc it names: an in-scope edit the host no longer
## lists is dropped, a changed one is replaced, and everything outside is left as it was.
func _test_snapshot_scoped_apply_in_place() -> void:
	var far_key := "%d,%d" % [20 * 64 + 5, 20 * 64 + 5]
	var client := VoxelSlice.new()
	add_child(client)
	client.apply_edits({ "32,32": 1.0, "33,32": 1.0, far_key: 3.0 })
	assert_true(VoxelSlice.chunk_in_radius(Vector2i(0, 0), Vector3.ZERO, 10.0), "the origin chunk is in a small disc")
	assert_false(VoxelSlice.chunk_in_radius(Vector2i(20, 20), Vector3.ZERO, 100.0), "a far chunk is not")
	assert_true(VoxelSlice.chunk_in_radius(Vector2i(1, 0), Vector3(30.0, 0.0, 10.0), 2.5), "a disc reaches a neighbour by its edge")
	assert_false(VoxelSlice.chunk_in_radius(Vector2i(1, 0), Vector3(20.0, 0.0, 10.0), 2.5), "and stops short of it")
	var far_before: Array = (client._edits[far_key] as Array)
	var host := VoxelSlice.new()
	add_child(host)
	host.apply_edits({ "32,32": 2.0 })   # same tile, different edit; "33,32" is gone
	var scoped: Dictionary = host.get_chunk_manifest_in_radius(Vector3.ZERO, 100.0)
	client.apply_scoped_chunk_manifest(scoped, Vector3.ZERO, 100.0)
	assert_false(client._edits.has("33,32"), "an in-scope edit the host dropped is dropped here")
	assert_true(client._edits.has("32,32"), "the in-scope edit the host holds stays")
	assert_true(VoxelSlice._ops_equal(client._edits["32,32"], host._edits["32,32"]), "and takes the host's value")
	assert_true(is_same(client._edits[far_key], far_before), "an out-of-scope op list is the very same object")
	assert_eq(client._edits_by_chunk.size(), 2, "the chunk index tracks the result (near chunk and far chunk)")
	host.free()
	client.free()

func _test_net_within_aoi_explicit_center() -> void:
	var n := NetworkingSlice.new()
	add_child(n)
	n.remember_player_state(2, Vector3.ZERO)
	var pos := Vector3(500.0, 0.0, 0.0)
	assert_false(n.in_aoi(2, pos), "the recorded centre does not reach it")
	assert_true(NetworkingSlice.within_aoi(Vector3(480.0, 0.0, 0.0), pos), "a fresher centre does")
	assert_eq(NetworkingSlice.within_aoi(Vector3.ZERO, Vector3(50.0, 0.0, 0.0)), n.in_aoi(2, Vector3(50.0, 0.0, 0.0)),
		"in_aoi is within_aoi at the recorded centre")
	n.free()

## Phase 42 review pass 3 — the CI host job ended a boot with `--quit-after N`, a FRAME
## budget, for a wait that is measured in WORKER time: a fast headless frame loop can burn
## the budget before the ring's tasks land, and the job then fails for a boot that was
## working. `--quit-after-boot` hands the decision to the boot itself. Static and
## argument-driven, so the rule is pinned without booting (same shape as `should_run_tests`).
func _test_quit_after_boot_predicate() -> void:
	var root_script: GDScript = load("res://src/core/game_root.gd")
	assert_true(root_script.should_quit_after_boot([root_script.QUIT_AFTER_BOOT_ARG]),
		"the flag is read from the user args")
	assert_false(root_script.should_quit_after_boot([]),
		"no flag leaves the exit to the engine's own budget")
	assert_false(root_script.should_quit_after_boot(["--server", "--run-tests"]),
		"and another arg is not it")

## Phase 42 review (fifth pass) — a world edit resolved on the host for a REMOTE peer is
## the PEER's resource. Every check and mutation used to go through
## `VoxelSlice.inventory_slice`, which is the HOST's own pack: a client's mine filled the
## host's inventory while the client — whose own client mirrors only ITS pack — saw
## nothing. The acting identity now rides the request (`_route_c2h` binds it to the
## connection, never to a payload), the resolution goes through `inventory_for(actor)`,
## and the actor's own client is pushed the result on `inventory_synced` (addressed to its
## owner, so networking delivers it to that peer alone — Phase 37).
func _test_net_remote_mine_credits_the_actor() -> void:
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("player_host_1")
	var host_inv := InventorySlice.new()
	add_child(host_inv)
	var peer_pid := "player_7_1_cafe"

	var v := _make_voxel()
	v.is_authoritative = true
	v.inventory_slice = host_inv
	v.player_registry = reg

	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.set_player_id(7, peer_pid)
	n.remember_player_state(7, Vector3.ZERO)

	var mined: Array = []
	var on_mined := func(mined_material: String, _qty: int, _pos: Vector3) -> void:
		mined.append(mined_material)
	GameBus.block_mined.connect(on_mined)
	var synced: Array = []
	var on_synced := func(synced_owner: String, _contents: Dictionary, _durabilities: Dictionary) -> void:
		synced.append(synced_owner)
	GameBus.inventory_synced.connect(on_synced)

	n._route_c2h(7, { "type": "block_edit_intent", "action": "mine",
		"position": [16.0, 2.0, 16.0], "normal": [0, 1, 0] })

	assert_eq(mined.size(), 1, "the mine resolved (handshake + reach both pass)")
	var material := str(mined[0])
	var peer_inv: Node = reg.get_inventory(peer_pid)
	assert_eq(peer_inv.get_item_count(material), 1, "the yield lands in the ACTOR's pack")
	assert_eq(host_inv.get_item_count(material), 0, "and NOT in the host's own pack")
	assert_true(synced.has(peer_pid), "and the actor's own client is pushed the change")

	GameBus.block_mined.disconnect(on_mined)
	GameBus.inventory_synced.disconnect(on_synced)
	v.free()
	n.free()
	reg.free()

## The placement half of the same rule: the block comes out of the ACTOR's pack, and the
## material placed is the one the ACTOR named (not this host's own `_place_material`). A
## material that is not in the fabric's table grants nothing even when the request "holds"
## it — the request is a claim, `GameData.MATERIALS` is the authority.
func _test_net_remote_place_spends_the_actor() -> void:
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("player_host_1")
	var host_inv := InventorySlice.new()
	add_child(host_inv)
	host_inv.add_item("Ferrite", 4)
	var peer_pid := "player_7_1_cafe"

	var v := _make_voxel()
	v.is_authoritative = true
	v.inventory_slice = host_inv
	v.player_registry = reg
	v.set_place_material("Ferrite")   # the HOST's selection — a peer must not inherit it

	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.set_player_id(7, peer_pid)
	n.remember_player_state(7, Vector3.ZERO)

	var peer_inv: Node = reg.get_inventory(peer_pid)
	peer_inv.add_item("Ashite", 2)

	var placed: Array = []
	var on_placed := func(material: String, _pos: Vector3) -> void:
		placed.append(material)
	GameBus.block_placed.connect(on_placed)

	n._route_c2h(7, { "type": "block_edit_intent", "action": "place",
		"position": [24.0, 2.0, 16.0], "normal": [0, 1, 0], "material": "Ashite" })
	assert_eq(placed.size(), 1, "the placement resolved")
	var placed_material := str(placed[0]) if placed.size() > 0 else ""
	assert_eq(placed_material, "Ashite", "the material placed is the one the ACTOR named")
	assert_eq(v.get_voxel_height_at(Vector2(24.25, 16.25)), 2.125, "and the block is really there")
	assert_eq(peer_inv.get_item_count("Ashite"), 1, "spent out of the ACTOR's pack")
	assert_eq(host_inv.get_item_count("Ashite"), 0, "the host's pack never held it")
	assert_eq(host_inv.get_item_count("Ferrite"), 4, "and the host's own selection was not spent")

	# A material the fabric does not know: refused before the debit, so it neither
	# places a ghost block nor costs the actor anything. (Inside chunk "0,0", the only
	# chunk this rig built — an unbuilt chunk answers BEDROCK_DEPTH and would mask it.)
	peer_inv.add_item("NotAMaterial", 1)
	n._route_c2h(7, { "type": "block_edit_intent", "action": "place",
		"position": [20.0, 2.0, 16.0], "normal": [0, 1, 0], "material": "NotAMaterial" })
	assert_eq(placed.size(), 1, "a fabricated material emits no placement")
	assert_eq(v.get_voxel_height_at(Vector2(20.25, 16.25)), 2.0, "and places nothing")
	assert_eq(peer_inv.get_item_count("NotAMaterial"), 1, "and costs the actor nothing")

	GameBus.block_placed.disconnect(on_placed)
	v.free()
	n.free()
	reg.free()

## The chop half: the wood lands in the CHOPPER's pack and the axe that wears is the
## chopper's own (a peer used to wear the host's axe and fill the host's pack).
func _test_net_remote_chop_credits_the_actor() -> void:
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("player_host_1")
	var host_inv := InventorySlice.new()
	add_child(host_inv)
	host_inv.add_item("CarpenterAxe", 1)
	var peer_pid := "player_7_1_cafe"

	var t := TreeSlice.new()
	add_child(t)
	t.is_authoritative = true
	t.inventory_slice = host_inv
	t.player_registry = reg
	t.spawn_for_chunk(Vector2i(0, 0))
	var target: Dictionary = t.get_all_trees()[0]
	var tid: String = str(target["tree_id"])
	var tree_pos: Vector3 = target["position"]

	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.tree_slice = t
	n.set_player_id(7, peer_pid)
	n.remember_player_state(7, tree_pos + Vector3(10.0, 0.0, 0.0))

	var peer_inv: Node = reg.get_inventory(peer_pid)
	peer_inv.add_item("CarpenterAxe", 1)
	var wear_before: float = float(peer_inv.get_durability_data()["CarpenterAxe"][0])

	var synced: Array = []
	var on_synced := func(synced_owner: String, _contents: Dictionary, _durabilities: Dictionary) -> void:
		synced.append(synced_owner)
	GameBus.inventory_synced.connect(on_synced)

	n._route_c2h(7, { "type": "tree_chop_intent", "tree_id": tid })

	assert_eq(str(t.get_tree_record(tid)["state"]), "stump", "the chop resolved on the host")
	assert_eq(peer_inv.get_item_count("Thornwood"), 2, "the wood lands in the CHOPPER's pack")
	assert_eq(host_inv.get_item_count("Thornwood"), 0, "and NOT in the host's")
	assert_true(float(peer_inv.get_durability_data()["CarpenterAxe"][0]) < wear_before,
		"the axe that wore is the CHOPPER's")
	assert_true(synced.has(peer_pid), "and the chopper's own client is pushed the change")

	GameBus.inventory_synced.disconnect(on_synced)
	t.free()
	n.free()
	reg.free()

func _test_net_voxel_client_forwards_intent() -> void:
	# A non-authoritative voxel slice must NOT mutate terrain via mine_block —
	# it forwards a block_edit_intent to the host instead. Invoke the handler
	# directly so the shared bus (and stale slices from other tests) can't
	# interfere with the assertion.
	var v := VoxelSlice.new()
	add_child(v)
	v.is_authoritative = false
	var flat: Array = []
	flat.resize(64 * 64)
	flat.fill(2.0)
	v.build_chunk(Vector2i(0, 0), flat)
	var intent := {}
	GameBus.block_edit_intent.connect(func(action, _pos, _normal, material, _exact):
		intent["action"] = action
		intent["material"] = material
	)
	v._on_mine_requested(Vector3(16.0, 2.0, 16.0), Vector3.UP, "")
	assert_eq(intent.get("action", ""), "mine", "client forwards a mine intent")
	assert_false(v._edits.has("32,32"), "mine_block did not edit this slice directly")
	v.free()

func _test_net_voxel_apply_block_change() -> void:
	# apply_block_change applies a host-authoritative edit without touching
	# inventory or re-emitting block_changed.
	var v := VoxelSlice.new()
	add_child(v)
	var flat: Array = []
	flat.resize(64 * 64)
	flat.fill(2.0)
	v.build_chunk(Vector2i(0, 0), flat)
	var reemit := [0]
	GameBus.block_changed.connect(func(_a, _p, _n, _m): reemit[0] += 1)
	v.apply_block_change("mine", Vector3(16.0, 2.0, 16.0), Vector3.UP, "")
	assert_eq(v.get_voxel_height_at(Vector2(16.0, 16.0)), 1.875, "mine applied (2.0 → 1.875)")
	v.apply_block_change("place", Vector3(16.0, 2.0, 16.0), Vector3.UP, "Ferrite")
	assert_eq(v.get_voxel_height_at(Vector2(16.0, 16.0)), 2.0, "place applied (1.875 → 2.0)")
	assert_eq(reemit[0], 0, "apply_block_change does not re-emit block_changed")
	v.free()

func _test_net_creature_client_no_local_spawn() -> void:
	var c := CreatureSlice.new()
	add_child(c)
	c.is_authoritative = false
	c.spawn_for_chunk(Vector2i(0, 0))
	assert_eq(c.get_all_instances().size(), 0, "client does not spawn locally")
	# But it does apply host state deltas.
	c.apply_creature_state("creature_9", "ForestBoar", "idle", Vector3(1.0, 2.0, 3.0))
	var all := c.get_all_instances()
	assert_eq(all.size(), 1, "client applies a host creature state")
	assert_eq(all[0]["instance_id"], "creature_9", "instance id preserved")
	assert_eq(all[0]["creature_id"], "ForestBoar", "creature id preserved")
	assert_eq(all[0]["state"], "idle", "state preserved")
	# Update path.
	c.apply_creature_state("creature_9", "ForestBoar", "aggressive", Vector3(4.0, 5.0, 6.0))
	assert_eq(c.get_all_instances().size(), 1, "update does not duplicate the instance")
	assert_eq(c.get_all_instances()[0]["state"], "aggressive", "state updated")
	c.free()

func _test_net_creature_snapshot_roundtrip() -> void:
	var host := CreatureSlice.new()
	add_child(host)
	host.spawn_for_chunk(Vector2i(0, 0))
	var snap := host.get_snapshot_creatures()
	assert_true(snap.size() > 0, "host produces a non-empty snapshot")
	var client := CreatureSlice.new()
	add_child(client)
	client.is_authoritative = false
	client.apply_snapshot_creatures(snap)
	assert_eq(client.get_all_instances().size(), snap.size(), "client seeds population from snapshot")
	# creature_id must survive the snapshot round-trip.
	var cfirst: Dictionary = client.get_all_instances()[0]
	var sfirst: Dictionary = snap[0]
	assert_eq(cfirst["creature_id"], sfirst["creature_id"], "creature_id preserved through snapshot")
	host.free()
	client.free()

func _test_net_player_ghost_interpolation() -> void:
	var p := PlayerSlice.new()
	add_child(p)
	assert_eq(p.get_remote_ghost_count(), 0, "no ghosts initially")
	p._on_remote_player_state(2, Vector3(0.0, 0.0, 0.0))
	assert_eq(p.get_remote_ghost_count(), 1, "first remote state spawns a ghost")
	# A second snapshot resets interpolation toward the new target.
	p._on_remote_player_state(2, Vector3(10.0, 0.0, 0.0))
	p._tick_ghosts(0.05)   # half the interp time
	var pos: Vector3 = p._ghosts[2]["pos"]
	assert_true(pos.x > 0.0 and pos.x < 10.0, "ghost interpolates between snapshots")
	p.free()

func _test_net_player_ghost_self_filter() -> void:
	# The local player's own peer id must never spawn a ghost — the host echoes
	# a client's movement back to every peer, including the originator.
	var p := PlayerSlice.new()
	add_child(p)
	p._on_remote_player_state(multiplayer.get_unique_id(), Vector3(1.0, 2.0, 3.0))
	assert_eq(p.get_remote_ghost_count(), 0, "own peer id does not spawn a ghost")
	p.free()

func _test_net_creature_dirty_broadcast() -> void:
	# Unchanged instances are not re-broadcast; only mutated ones are.
	var c := CreatureSlice.new()
	add_child(c)
	c.spawn_for_chunk(Vector2i(0, 0))
	var emissions := []
	GameBus.creature_state_changed.connect(func(iid, _cid, _state, _pos): emissions.append(iid))
	c._broadcast_creature_states()
	assert_true(emissions.size() > 0, "first broadcast ships the population")
	emissions.clear()
	c._broadcast_creature_states()
	assert_eq(emissions.size(), 0, "unchanged creatures are not re-broadcast")
	var first_id: String = c.get_all_instances()[0]["instance_id"]
	c.set_instance_position(first_id, Vector3(50.0, 50.0, 50.0))
	c._broadcast_creature_states()
	assert_eq(emissions.size(), 1, "only the moved creature is re-broadcast")
	assert_eq(emissions[0], first_id, "the dirty instance is the one broadcast")
	c.free()

func _test_net_creature_state_compact_position() -> void:
	# Phase 119 — the sender ships `pk`; the client route must decode it, not read the absent `position`.
	var n := NetworkingSlice.new()
	add_child(n)
	var got := []
	var cb := func(_iid, _cid, _state, pos): got.append(pos)
	GameBus.creature_state_changed.connect(cb)
	var sent := Vector3(123.0, 45.0, -67.0)
	n._route_h2c({
		"type": "creature_state_changed", "instance_id": "c1", "creature_id": "x", "state": "idle",
		"pk": WorldPos.pos_to_packet_text(WorldPos.from_world(sent.x, sent.y, sent.z)),
	})
	n._route_h2c({
		"type": "creature_state_changed", "instance_id": "c2", "creature_id": "x", "state": "idle",
		"position": [1.0, 2.0, 3.0],
	})
	GameBus.creature_state_changed.disconnect(cb)
	assert_eq(got.size(), 2, "both creature packets are routed")
	assert_true(WorldPos.to_scene(got[0], Vector2i.ZERO).distance_to(sent) < 0.01, "the compact creature position decodes to where it was sent")
	assert_eq(WorldPos.to_scene(got[1], Vector2i.ZERO), Vector3(1.0, 2.0, 3.0), "a legacy float-array creature position still decodes")
	n.free()

func _test_net_inventory_replace_contents() -> void:
	var inv := InventorySlice.new()
	add_child(inv)
	inv.add_item("Ferrite", 5)
	inv.replace_contents({ "Ashite": 3, "FerritePick": 2 })
	assert_eq(inv.get_item_count("Ferrite"), 0, "replace clears old items")
	assert_eq(inv.get_item_count("Ashite"), 3, "replace applies host contents")
	assert_eq(inv.get_item_count("FerritePick"), 2, "replace applies a durable item")
	assert_eq(inv.get_durability_values("FerritePick").size(), 2, "durable durability rebuilt to match quantity")
	inv.free()

# ---------------------------------------------------------------------------
# Networking / chaos resilience tests (Phase 19)
# ---------------------------------------------------------------------------

func _test_net_sequence_monotonic() -> void:
	# Each packet type maintains its own counter; two packets of the same type
	# increment together, while a different type starts fresh at 0.
	var n := NetworkingSlice.new()
	add_child(n)
	var p1 := { "type": "player_moved" }
	var p2 := { "type": "player_moved" }
	var p3 := { "type": "block_changed" }
	n._deliver(1, p1)
	n._deliver(1, p2)
	n._deliver(1, p3)
	assert_eq(int(p1["seq"]), 0, "first player_moved gets seq 0")
	assert_eq(int(p2["seq"]), 1, "second player_moved gets seq 1")
	assert_eq(int(p3["seq"]), 0, "block_changed starts its own per-type counter at 0")
	n.free()

func _test_net_sequence_dedup() -> void:
	# In-order and forward-gap packets are accepted. True duplicates (same seq
	# already in the window) are dropped. Out-of-order packets that have NOT been
	# seen before are accepted (delivered late is fine; dropped is not). Each
	# packet type is tracked independently.
	var n := NetworkingSlice.new()
	add_child(n)
	assert_true(n._dedup(1, { "seq": 0, "type": "x" }), "first seq accepted")
	assert_true(n._dedup(1, { "seq": 1, "type": "x" }), "next in-order seq accepted")
	assert_false(n._dedup(1, { "seq": 1, "type": "x" }), "duplicate seq dropped")
	assert_false(n._dedup(1, { "seq": 0, "type": "x" }), "already-seen seq dropped")
	assert_true(n._dedup(1, { "seq": 5, "type": "x" }), "forward gap accepted (logged, not blocking)")
	# Out-of-order but UNSEEN: seq 3 arrives after seq 5 — must be accepted, not dropped.
	assert_true(n._dedup(1, { "seq": 3, "type": "x" }), "out-of-order unseen seq accepted (delivered late)")
	# Cross-type isolation: same seq on a different type has its own counter.
	assert_true(n._dedup(1, { "seq": 0, "type": "y" }), "same seq on a different type accepted independently")
	n.free()

func _test_net_emulator_delivery() -> void:
	# With emulation on but no loss/jitter, every packet is queued and the
	# queue preserves monotonic seq order.
	var n := NetworkingSlice.new()
	add_child(n)
	n.emulate_network = true
	n.emulator_loss_rate = 0.0
	n.emulator_jitter_ms = 0.0
	n._rng.seed = 7
	for i in range(10):
		n._deliver(1, { "type": "x", "i": i })
	assert_eq(n._pending.size(), 10, "all packets queued when no loss and no jitter")
	var seqs: Array = []
	for e in n._pending:
		var parsed = JSON.parse_string(e["payload"])
		seqs.append(int(parsed["seq"]))
	seqs.sort()
	assert_eq(seqs, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], "queued packets carry monotonic seq 0..9")
	n.free()

func _test_net_emulator_loss() -> void:
	# At a 15% loss rate the emulator drops a fraction close to 15% (and the
	# mechanism is deterministic under a seeded RNG).
	var n := NetworkingSlice.new()
	add_child(n)
	n.emulate_network = true
	n.emulator_loss_rate = 15.0
	n._rng.seed = 12345
	var dropped := 0
	var total := 1000
	for _i in range(total):
		if n._should_drop():
			dropped += 1
	var pct := float(dropped) / float(total) * 100.0
	assert_true(pct > 8.0 and pct < 22.0, "loss rate near 15%% (got %.1f%%)" % pct)
	n.free()

func _test_net_emulator_jitter() -> void:
	# Jitter delays are uniformly distributed in [-bound, +bound] with no
	# positive bias. Negative values are delivered immediately by the drain loop.
	var n := NetworkingSlice.new()
	add_child(n)
	n.emulate_network = true
	n.emulator_jitter_ms = 50.0
	n._rng.seed = 99
	for _i in range(200):
		var d: float = n._jitter_delay_ms()
		assert_true(d >= -50.0 and d <= 50.0, "jitter delay within [-50, 50] (got %.1f)" % d)
	n.free()

func _test_net_emulator_zero_overhead() -> void:
	# With emulation disabled (production default), packets go straight out and
	# never enter the delivery queue.
	var n := NetworkingSlice.new()
	add_child(n)
	n._deliver(1, { "type": "x" })
	assert_eq(n._pending.size(), 0, "no packets queued when emulation disabled")
	n.free()

func _test_net_jitter_buffer() -> void:
	# The client jitter buffer replays remote-player snapshots on a fixed
	# playback delay and interpolates between the surrounding snapshots.
	var n := NetworkingSlice.new()
	add_child(n)
	n.jitter_buffer_ms = 100.0
	n._jitter_buffer[1] = [
		{ "at_ms": 0.0,   "position": Vector3(0.0, 0.0, 0.0) },
		{ "at_ms": 50.0,  "position": Vector3(10.0, 0.0, 0.0) },
		{ "at_ms": 100.0, "position": Vector3(20.0, 0.0, 0.0) },
	]
	var a: Vector3 = n._sample_remote_state_at(1, 100.0)
	assert_true(abs(a.x) < 0.001, "playback before first snapshot returns first position")
	var b: Vector3 = n._sample_remote_state_at(1, 150.0)
	assert_true(abs(b.x - 10.0) < 0.001, "playback at middle snapshot returns exact position")
	var c: Vector3 = n._sample_remote_state_at(1, 125.0)
	assert_true(abs(c.x - 5.0) < 0.5, "interpolated between snapshots within tolerance")
	var d: Vector3 = n._sample_remote_state_at(1, 250.0)
	assert_true(abs(d.x - 20.0) < 0.001, "playback past last snapshot returns last position")
	n.free()

func _test_net_inventory_replace_idempotent() -> void:
	# replace_contents must be idempotent: applying the same snapshot twice
	# (e.g. initial join followed by a rejoin) must not duplicate entries.
	var inv := InventorySlice.new()
	add_child(inv)
	inv.add_item("Ferrite", 5)
	var contents: Dictionary = inv.get_contents()
	inv.replace_contents(contents)
	inv.replace_contents(contents)
	assert_eq(inv.get_item_count("Ferrite"), 5, "double replace_contents does not duplicate inventory")
	inv.free()

func _test_net_reconnect_last_known_state() -> void:
	# The host retains a client's last-known position across a disconnect so a
	# rejoining client resumes from it.
	var n := NetworkingSlice.new()
	add_child(n)
	n.remember_player_state(2, Vector3(4.0, 5.0, 6.0))
	assert_eq(n.get_last_known_state(2), Vector3(4.0, 5.0, 6.0), "state remembered")
	# Phase 47 — announcing gear is host-only and needs a connection: offline it is a no-op, not a crash.
	n.announce_equipment_to_aoi(2)
	n.announce_equipment_to_aoi(99)
	n._on_peer_disconnected(2)
	assert_eq(n.get_last_known_state(2), Vector3(4.0, 5.0, 6.0), "last-known state retained across disconnect")
	assert_true(n.get_last_known_states().has(2), "retained state present for snapshot")
	n.free()

func _test_net_two_peer_loss_reorder() -> void:
	# End-to-end emulation: a sender with 10% loss and reorder stages packets;
	# all non-dropped packets must be accepted by the receiver's sliding-window
	# dedup even when delivered in reverse order (worst-case reorder). A second
	# pass must reject every packet as a duplicate (dedup is idempotent).
	var sender := NetworkingSlice.new()
	add_child(sender)
	sender.emulate_network = true
	sender.emulator_loss_rate = 10.0
	sender.emulator_reorder = true
	sender._rng.seed = 1337

	for i in range(30):
		sender._deliver(1, { "type": "player_moved", "i": i })

	# Collect the packets the emulator kept (not lost), in whatever order the
	# reorder step staged them.
	var queued: Array = []
	for entry in sender._pending:
		var parsed = JSON.parse_string(entry["payload"])
		if parsed is Dictionary:
			queued.append(parsed)

	assert_true(queued.size() > 0, "at least some packets survive 10% loss over 30 sent")

	var receiver := NetworkingSlice.new()
	add_child(receiver)

	# Deliver in reverse order — maximum reorder stress.
	var reversed_q := queued.duplicate()
	reversed_q.reverse()
	var accepted := 0
	for pkt in reversed_q:
		if receiver._dedup(1, pkt):
			accepted += 1

	assert_eq(accepted, queued.size(),
		"all %d non-dropped packets accepted despite reverse-order delivery" % queued.size())

	# Second pass: every seq is now in the seen window — all must be rejected.
	var duplicates := 0
	for pkt in queued:
		if receiver._dedup(1, pkt):
			duplicates += 1

	assert_eq(duplicates, 0, "no packet accepted a second time — dedup is idempotent")

	sender.free()
	receiver.free()

func _test_net_peer_party_scopes_identity() -> void:
	# The acting party behind a connection is the identity the host bound to it —
	# whatever a payload names, and nothing at all before the handshake. `party_id_for`
	# keeps answering a transport label for display, but never authorizes anything.
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	assert_eq(n._actor_id(5), "", "an un-handshaked peer has no acting identity")
	assert_eq(n.party_id_for(5), "peer_5", "its diagnostic label falls back to the transport id")
	n.set_player_id(5, "player_5_1_beef")
	assert_eq(n._actor_id(5), "player_5_1_beef", "the bound identity is the acting party")
	n.free()

func _test_net_social_intents_bind_connection_identity() -> void:
	# Market and governance intents carry an identity the host must IGNORE: a client
	# that could name one could sell a victim's goods (the escrow debit empties their
	# inventory), buy into a victim's own listing, or cast a victim's vote — a quorum
	# of one. The connection decides who is acting; un-handshaked peers cannot act.
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	var listed: Array = []
	var bought: Array = []
	var authored: Array = []
	var voted: Array = []
	var superseded: Array = []
	var on_list := func(seller: String, item_id: String, qty: int, price: float) -> void:
		listed.append([seller, item_id, qty, price])
	var on_buy := func(listing_id: String, buyer: String) -> void:
		bought.append([listing_id, buyer])
	var on_submit := func(author: String, title: String, _body: String) -> void:
		authored.append([author, title])
	var on_vote := func(proposal_id: String, voter: String, verdict: String) -> void:
		voted.append([proposal_id, voter, verdict])
	var on_supersede := func(proposal_id: String, replacement_id: String) -> void:
		superseded.append([proposal_id, replacement_id])
	GameBus.market_list_intent.connect(on_list)
	GameBus.market_buy_intent.connect(on_buy)
	GameBus.proposal_submit_intent.connect(on_submit)
	GameBus.proposal_vote_intent.connect(on_vote)
	GameBus.proposal_supersede_intent.connect(on_supersede)

	var spoof := "player_victim_1_deadbeef"
	n._route_c2h(7, { "type": "market_list_intent", "seller": spoof, "item_id": "wolf_fang", "quantity": 2, "price": 5.0 })
	n._route_c2h(7, { "type": "market_buy_intent", "listing_id": "listing_0", "buyer": spoof })
	n._route_c2h(7, { "type": "proposal_submit_intent", "author": spoof, "title": "T", "body": "B" })
	n._route_c2h(7, { "type": "proposal_vote_intent", "proposal_id": "proposal_0", "voter": spoof, "verdict": "for" })
	n._route_c2h(7, { "type": "proposal_supersede_intent", "proposal_id": "proposal_0", "replacement_id": "proposal_1" })
	assert_eq(listed.size(), 0, "an un-handshaked peer cannot list")
	assert_eq(bought.size(), 0, "nor buy")
	assert_eq(authored.size(), 0, "nor author a proposal")
	assert_eq(voted.size(), 0, "nor vote")
	assert_eq(superseded.size(), 0, "nor move the decisions log")

	n.set_player_id(7, "player_7_1_cafe")
	n._route_c2h(7, { "type": "market_list_intent", "seller": spoof, "item_id": "wolf_fang", "quantity": 2, "price": 5.0 })
	n._route_c2h(7, { "type": "market_buy_intent", "listing_id": "listing_0", "buyer": spoof })
	n._route_c2h(7, { "type": "proposal_submit_intent", "author": spoof, "title": "T", "body": "B" })
	n._route_c2h(7, { "type": "proposal_vote_intent", "proposal_id": "proposal_0", "voter": spoof, "verdict": "for" })
	n._route_c2h(7, { "type": "proposal_supersede_intent", "proposal_id": "proposal_0", "replacement_id": "proposal_1" })
	assert_eq(str(listed[0][0]), "player_7_1_cafe", "the seller is the connection's player, not the name")
	assert_eq(str(bought[0][1]), "player_7_1_cafe", "and so is the buyer")
	assert_eq(str(authored[0][0]), "player_7_1_cafe", "and the proposal author")
	assert_eq(str(voted[0][1]), "player_7_1_cafe", "and the voter")
	assert_eq(voted[0][2], "for", "with the verdict it did send")
	assert_eq(superseded.size(), 1, "a bound peer's supersede is re-emitted")

	GameBus.market_list_intent.disconnect(on_list)
	GameBus.market_buy_intent.disconnect(on_buy)
	GameBus.proposal_submit_intent.disconnect(on_submit)
	GameBus.proposal_vote_intent.disconnect(on_vote)
	GameBus.proposal_supersede_intent.disconnect(on_supersede)
	n.free()

func _test_net_trade_intents_bind_connection_identity() -> void:
	# Every trade step acts as the connection's own player: a spoofed accept used to
	# commit the OTHER side's goods. An invite may name a counterparty, but only one
	# the host can resolve to an online player — nobody can be dragged into a session
	# that cannot be answered.
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("player_host_1")
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.player_registry = reg
	var started: Array = []
	var proposed: Array = []
	var accepted: Array = []
	var rejected: Array = []
	var on_start := func(party_a: String, party_b: String) -> void:
		started.append([party_a, party_b])
	var on_propose := func(trade_id: String, party: String, _give: Dictionary, _want: Dictionary) -> void:
		proposed.append([trade_id, party])
	var on_accept := func(trade_id: String, party: String) -> void:
		accepted.append([trade_id, party])
	var on_reject := func(trade_id: String, party: String) -> void:
		rejected.append([trade_id, party])
	GameBus.trade_start_intent.connect(on_start)
	GameBus.trade_propose_intent.connect(on_propose)
	GameBus.trade_accept_intent.connect(on_accept)
	GameBus.trade_reject_intent.connect(on_reject)

	var spoof := "player_victim_1_deadbeef"
	n._route_c2h(7, { "type": "trade_accept_intent", "trade_id": "trade_0", "party": spoof })
	n._route_c2h(7, { "type": "trade_propose_intent", "trade_id": "trade_0", "party": spoof, "give": {}, "want": {} })
	n._route_c2h(7, { "type": "trade_reject_intent", "trade_id": "trade_0", "party": spoof })
	n._route_c2h(7, { "type": "trade_start_intent", "party_a": spoof, "party_b": "player_host_1" })
	assert_eq(accepted.size(), 0, "an un-handshaked peer cannot accept")
	assert_eq(proposed.size(), 0, "nor propose")
	assert_eq(rejected.size(), 0, "nor reject")
	assert_eq(started.size(), 0, "nor open a session")

	n.set_player_id(7, "player_7_1_cafe")
	n._route_c2h(7, { "type": "trade_accept_intent", "trade_id": "trade_0", "party": spoof })
	n._route_c2h(7, { "type": "trade_propose_intent", "trade_id": "trade_0", "party": spoof, "give": {}, "want": {} })
	n._route_c2h(7, { "type": "trade_reject_intent", "trade_id": "trade_0", "party": spoof })
	assert_eq(str(accepted[0][1]), "player_7_1_cafe", "the accepter is the connection's player")
	assert_eq(str(proposed[0][1]), "player_7_1_cafe", "and the proposer")
	assert_eq(str(rejected[0][1]), "player_7_1_cafe", "and the rejecter")

	# Invites: the named counterparty must resolve. Phase 37 — the name is a public
	# HANDLE, which is the only identity a client is ever told, so that is what an
	# invite carries.
	var host_handle: String = reg.public_handle("player_host_1")
	n._route_c2h(7, { "type": "trade_start_intent", "party_a": spoof, "party_b": host_handle })
	assert_eq(started.size(), 1, "an invite to an online player's handle is opened")
	assert_eq(str(started[0][0]), "player_7_1_cafe", "in the sender's own name")
	assert_eq(str(started[0][1]), "player_host_1", "naming the counterparty it resolved")

	# Phase 37 — a RAW PLAYER ID is no longer a name an invite may carry, even a real
	# online player's: answering it turned this into a yes/no oracle for "is that exact
	# id connected", and an id is a bearer token (see resolve_identity). Nothing
	# legitimate still sends one — a client learns ids nowhere (redact_for_client).
	n._route_c2h(7, { "type": "trade_start_intent", "party_a": "player_7_1_cafe", "party_b": "player_host_1" })
	assert_eq(started.size(), 1, "a raw online player id is refused")
	n._route_c2h(7, { "type": "trade_start_intent", "party_a": "player_7_1_cafe", "party_b": "player_nobody_9_0" })
	n._route_c2h(7, { "type": "trade_start_intent", "party_a": "player_7_1_cafe", "party_b": "" })
	n._route_c2h(7, { "type": "trade_start_intent", "party_a": "player_7_1_cafe", "party_b": "player_7_1_cafe" })
	assert_eq(started.size(), 1, "an unresolvable, empty or self counterparty is refused")

	GameBus.trade_start_intent.disconnect(on_start)
	GameBus.trade_propose_intent.disconnect(on_propose)
	GameBus.trade_accept_intent.disconnect(on_accept)
	GameBus.trade_reject_intent.disconnect(on_reject)
	n.free()
	reg.free()

func _test_net_block_intent_requires_handshake_and_reach() -> void:
	# A block edit is the world's state, so it needs a bound identity and a target the
	# host can place relative to where it last saw the peer: without the reach check a
	# client could mine or build anywhere (another player's feet included).
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	var mined: Array = []
	var on_mine := func(pos: Vector3, normal: Vector3, _player_id: String, _exact: Dictionary) -> void:
		mined.append([pos, normal])
	GameBus.block_mine_requested.connect(on_mine)

	var near := Vector3(30.0, 4.0, 0.0)
	var edit := { "type": "block_edit_intent", "action": "mine", "position": [near.x, near.y, near.z], "normal": [0, 1, 0] }
	n._route_c2h(7, edit)
	assert_eq(mined.size(), 0, "an un-handshaked peer cannot edit the world")

	n.set_player_id(7, "player_7_1_cafe")
	n._route_c2h(7, edit)
	assert_eq(mined.size(), 0, "a peer with no recorded position has no reach to check")

	n.remember_player_state(7, Vector3.ZERO)
	n._route_c2h(7, edit)
	assert_eq(mined.size(), 1, "an edit within reach is applied")
	assert_eq(mined[0][0], near, "at the position the client asked for")

	var far := Vector3(2000.0, 4.0, 2000.0)
	n._route_c2h(7, { "type": "block_edit_intent", "action": "place", "position": [far.x, far.y, far.z], "normal": [0, 1, 0] })
	assert_eq(mined.size(), 1, "an edit beyond reach is dropped")

	GameBus.block_mine_requested.disconnect(on_mine)
	n.free()

func _test_net_tree_intent_requires_handshake_and_reach() -> void:
	# The chop intent names only a tree id, so the reach check resolves the tree's own
	# position through the wired TreeSlice — and fails closed when no tree is known.
	var trees := TreeSlice.new()
	add_child(trees)
	trees.spawn_for_chunk(Vector2i(0, 0))
	var all_trees: Array = trees.get_all_trees()
	assert_true(all_trees.size() > 0, "the rig has trees to chop")
	var target: Dictionary = all_trees[0]
	var tree_pos: Vector3 = target["position"]

	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.tree_slice = trees
	var chops: Array = []
	var on_chop := func(tree_id: String, _player_id: String) -> void:
		chops.append(tree_id)
	GameBus.tree_chop_requested.connect(on_chop)

	var intent := { "type": "tree_chop_intent", "tree_id": str(target["tree_id"]) }
	n._route_c2h(7, intent)
	assert_eq(chops.size(), 0, "an un-handshaked peer cannot chop")

	n.set_player_id(7, "player_7_1_cafe")
	n._route_c2h(7, { "type": "tree_chop_intent", "tree_id": "tree_999_999_9" })
	assert_eq(chops.size(), 0, "a tree the host does not have is not chopable")

	n.remember_player_state(7, tree_pos + Vector3(10.0, 0.0, 0.0))
	n._route_c2h(7, intent)
	assert_eq(chops.size(), 1, "a chop within reach is re-emitted for TreeSlice")
	assert_eq(str(chops[0]), str(target["tree_id"]), "for the tree the client named")

	n.remember_player_state(7, tree_pos + Vector3(500.0, 0.0, 500.0))
	n._route_c2h(7, { "type": "tree_chop_intent", "tree_id": str(all_trees[1]["tree_id"]) })
	assert_eq(chops.size(), 1, "a chop beyond reach is dropped")

	GameBus.tree_chop_requested.disconnect(on_chop)
	n.free()
	trees.free()

func _test_net_client_packet_size_capped() -> void:
	# An oversized client packet is dropped before it is parsed: the cap is what keeps
	# one peer from making the authoritative process chew on an arbitrarily large JSON
	# string.
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	# `_rpc_c2h` reads the sender off the multiplayer API, so the rig has to bind the
	# identity to whatever this isolated slice reports as the remote sender.
	var sender := multiplayer.get_remote_sender_id()
	n.set_player_id(sender, "player_7_1_cafe")
	var crafts: Array = []
	var on_craft := func(recipe_id: String, player_id: String) -> void:
		crafts.append([recipe_id, player_id])
	GameBus.craft_intent.connect(on_craft)

	n._rpc_c2h(JSON.stringify({ "type": "craft_intent", "recipe_id": "R" }))
	assert_eq(crafts.size(), 1, "a packet within the cap is routed")
	var filler := "x".repeat(NetworkingSlice.MAX_CLIENT_PACKET_BYTES)
	n._rpc_c2h(JSON.stringify({ "type": "craft_intent", "recipe_id": "R", "filler": filler }))
	assert_eq(crafts.size(), 1, "a packet over the cap is dropped")

	GameBus.craft_intent.disconnect(on_craft)
	n.free()

func _test_net_client_packet_rate_limited() -> void:
	# A per-peer token bucket: a burst is capped, the bucket refills at the sustained
	# rate, and a reconnecting peer starts fresh instead of inheriting the debt.
	var n := NetworkingSlice.new()
	add_child(n)
	var allowed := 0
	for i in range(int(NetworkingSlice.RATE_BUCKET_CAPACITY) + 10):
		if n._allow_packet(3, 0.0):
			allowed += 1
	assert_eq(allowed, int(NetworkingSlice.RATE_BUCKET_CAPACITY), "a burst is capped at the bucket capacity")

	var later := 500.0
	assert_true(n._allow_packet(3, later), "the bucket refills over time")
	var refilled := 0
	for i in range(1000):
		if n._allow_packet(3, later):
			refilled += 1
	assert_eq(refilled, int(NetworkingSlice.RATE_BUCKET_REFILL_PER_SEC * 0.5) - 1,
		"and is then held to the sustained refill rate")

	n.forget_player_id(3)
	assert_true(n._allow_packet(3, later), "a disconnected peer's bucket goes with its transport state")
	n.free()

func _test_boot_suite_is_gated() -> void:
	# The automated suite no longer runs on EVERY boot: a release export that was
	# never asked for it must boot without the 7000-assertion development harness,
	# while a debug build (and an explicit --run-tests) still runs it. Asserted on
	# the pure predicate, so the rule is pinned without booting twice.
	var root_script: GDScript = load("res://src/core/game_root.gd")
	assert_false(root_script.should_run_tests([], false),
		"a release boot without the flag runs no suite")
	assert_false(root_script.should_run_tests(["--server"], false),
		"and neither does a matching --server boot")
	assert_false(root_script.should_run_tests([], true),
		"a debug build does not run the suite unless asked")
	assert_true(root_script.should_run_tests(["--run-tests"], false),
		"and --run-tests asks for it explicitly")
	assert_true(root_script.should_run_tests(["--client", "127.0.0.1", "--run-tests"], true),
		"the flag is independent of the network role")

func _test_net_aoi_center_and_in_aoi() -> void:
	# Interest management (Phase 29): a peer with no reported position falls back
	# to the spawn AOI center, and in_aoi gates on the AOI radius.
	var n := NetworkingSlice.new()
	add_child(n)
	assert_eq(n.get_aoi_center(99), NetworkingSlice.DEFAULT_AOI_CENTER,
		"unknown peer defaults to the spawn AOI center")
	n.remember_player_state(2, Vector3(0.0, 0.0, 0.0))
	assert_true(n.in_aoi(2, Vector3(50.0, 0.0, 0.0)), "position within AOI radius is in AOI")
	assert_false(n.in_aoi(2, Vector3(200.0, 0.0, 0.0)), "position beyond AOI radius is out of AOI")
	n.free()

func _test_snapshot_edits_scoped_to_aoi() -> void:
	var host := VoxelSlice.new()
	add_child(host)
	# Chunk (0,0) is near the origin; chunk (20,20) is ~640 m away.
	host.apply_edits({ "32,32": 1.0, "%d,%d" % [20 * 64 + 5, 20 * 64 + 5]: 3.0 })
	var scoped: Dictionary = host.get_chunk_manifest_in_radius(Vector3.ZERO, NetworkingSlice.EDITS_SCOPE_RADIUS)
	assert_true(scoped.has("0,0"), "AOI manifest holds the chunk in range")
	assert_false(scoped.has("20,20"), "AOI manifest omits the chunk out of range")
	var extent := float(VoxelSlice.CHUNK_SIZE) * VoxelSlice.TILE_SIZE
	var streamed := float(ChunkManager.DEFAULT_VIEW_DISTANCE + ChunkManager.DEFAULT_PREFETCH_DISTANCE) * extent
	assert_true(NetworkingSlice.EDITS_SCOPE_RADIUS >= (streamed + NetworkingSlice.AOI_RADIUS) * sqrt(2.0),
		"edit scope covers the streamed window plus an AOI cell of roaming, on the diagonal")
	assert_eq(host.get_chunk_manifest().size(), 2, "full manifest still holds both")
	# A client that already holds a far edit keeps it across a scoped apply.
	var client := VoxelSlice.new()
	add_child(client)
	client.apply_edits({ "%d,%d" % [20 * 64 + 5, 20 * 64 + 5]: 3.0 })
	client.apply_scoped_chunk_manifest(scoped, Vector3.ZERO, NetworkingSlice.EDITS_SCOPE_RADIUS)
	var held: Dictionary = client.get_chunk_manifest()
	assert_true(held.has("0,0"), "client adopted the in-scope edit")
	assert_true(held.has("20,20"), "client kept its out-of-scope edit")
	host.free()
	client.free()

func _test_net_aoi_recipients() -> void:
	# A delta is delivered only to peers whose AOI contains the entity: a near
	# peer receives it, a far peer does not, and a non-connected peer is never
	# delivered to even when in range.
	var n := NetworkingSlice.new()
	add_child(n)
	n.remember_player_state(2, Vector3(0.0, 0.0, 0.0))        # near
	n.remember_player_state(3, Vector3(5000.0, 0.0, 5000.0))  # far
	var near: Array = n.aoi_recipients(Vector3(10.0, 0.0, 0.0), [2, 3])
	assert_true(near.has(2), "near peer is an AOI recipient")
	assert_false(near.has(3), "far peer is not an AOI recipient")
	var far: Array = n.aoi_recipients(Vector3(5000.0, 0.0, 5000.0), [2, 3])
	assert_true(far.has(3), "far entity reaches the far peer")
	assert_false(far.has(2), "far entity does not reach the near peer")
	assert_false(n.aoi_recipients(Vector3.ZERO, [3]).has(2),
		"peer outside the connected set is excluded even when in range")
	n.free()

func _test_net_aoi_region() -> void:
	# The AOI grid cell floors world position by the AOI radius, negative values
	# included, so a peer crossing a boundary triggers a re-scope.
	var n := NetworkingSlice.new()
	add_child(n)
	assert_eq(n.aoi_region(Vector3.ZERO), Vector2i(0, 0), "origin maps to cell (0,0)")
	assert_eq(n.aoi_region(Vector3(NetworkingSlice.AOI_RADIUS, 0.0, 0.0)), Vector2i(1, 0),
		"exactly AOI_RADIUS crosses into cell (1,0)")
	assert_eq(n.aoi_region(Vector3(-1.0, 0.0, -1.0)), Vector2i(-1, -1),
		"negative positions floor to negative cells")
	n.free()

# ---------------------------------------------------------------------------
# AssetOverlay tests (Phase 21 — asset separation)
# ---------------------------------------------------------------------------

func _test_net_player_intents_bind_connection_identity() -> void:
	# A repair or research intent names no player: the host resolves it for the
	# identity bound to the connection, an un-handshaked peer cannot act at all, and
	# an id inside the payload is ignored (it is a client's word, not evidence).
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	var research: Array = []
	var repair: Array = []
	var on_research := func(tech_id: String, player_id: String) -> void:
		research.append([tech_id, player_id])
	var on_repair := func(item_id: String, player_id: String) -> void:
		repair.append([item_id, player_id])
	GameBus.research_intent.connect(on_research)
	GameBus.repair_intent.connect(on_repair)

	n._route_c2h(7, { "type": "research_intent", "tech_id": "TechBasicSmithing" })
	n._route_c2h(7, { "type": "repair_intent", "item_id": "FerritePick" })
	assert_eq(research.size(), 0, "an un-handshaked peer cannot research")
	assert_eq(repair.size(), 0, "and cannot repair")

	n.set_player_id(7, "player_7_1_deadbeef")
	n._route_c2h(7, { "type": "research_intent", "tech_id": "TechBasicSmithing" })
	n._route_c2h(7, { "type": "repair_intent", "item_id": "FerritePick", "player_id": "player_victim" })
	assert_eq(research.size(), 1, "the bound peer's research is re-emitted")
	assert_eq(str(research[0][1]), "player_7_1_deadbeef", "carrying the connection's identity")
	assert_eq(repair.size(), 1, "and its repair too")
	assert_eq(str(repair[0][1]), "player_7_1_deadbeef", "ignoring the id the payload tried to name")

	GameBus.research_intent.disconnect(on_research)
	GameBus.repair_intent.disconnect(on_repair)
	n.free()

func _test_net_own_state_push_is_peer_scoped() -> void:
	# The host hands a peer its own record slice back after acting on its behalf, and
	# that push is addressed to the peer ALONE — an inventory is private, so it cannot
	# ride a broadcast the way an AOI-scoped world delta can.
	var host := NetworkingSlice.new()
	add_child(host)
	host.emulate_network = true
	host.send_own_state(5, { "inventory": {} })
	assert_eq(host._pending.size(), 0, "a non-host cannot push own-state")
	host._role = NetworkingSlice.Role.HOST
	host.send_own_state(5, {
		"inventory": { "Ferrite": 1 },
		"technology": { "TechBasicSmithing": "unlocked" },
	})
	assert_eq(host._pending.size(), 1, "the host queues exactly one packet")
	var packet: Dictionary = JSON.parse_string(host._pending[0]["payload"])
	assert_eq(str(packet.get("type", "")), "own_state_synced", "of the own_state_synced type")
	assert_eq(int(host._pending[0]["peer_id"]), 5, "addressed to the peer it was given for")

	# The client half: the packet reaches the bus, which game_root applies.
	var client := NetworkingSlice.new()
	add_child(client)
	client._role = NetworkingSlice.Role.CLIENT
	var applied: Array = []
	var on_synced := func(data: Dictionary) -> void:
		applied.append(data)
	GameBus.own_state_synced.connect(on_synced)
	client._route_h2c(packet)
	GameBus.own_state_synced.disconnect(on_synced)
	assert_eq(applied.size(), 1, "the payload reaches own_state_synced")
	assert_eq(int(applied[0].get("inventory", {}).get("Ferrite", 0)), 1,
		"carrying the peer's own inventory")
	host.free()
	client.free()

func _test_multimesh_pool_alloc_recycle() -> void:
	var pool := MultimeshPool.new()
	add_child(pool)
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 1.0, 1.0)
	pool.setup(box, true)
	assert_eq(pool.alloc(), 0, "first alloc is index 0")
	assert_eq(pool.alloc(), 1, "second alloc is index 1")
	assert_eq(pool.alloc(), 2, "third alloc is index 2")
	pool.release(1)
	assert_eq(pool.alloc(), 1, "released index is recycled first")
	for i in range(300):
		pool.alloc()
	assert_true(pool.instance_count() > 300, "pool grew beyond the initial step")
	pool.free()

func _test_creature_headless_no_visual() -> void:
	# A headless server (render_visuals = false) spawns creatures as pure data:
	# no MultiMesh pool is built and each instance carries the -1 sentinel index.
	var c := CreatureSlice.new()
	c.render_visuals = false
	add_child(c)
	c.spawn_for_chunk(Vector2i(0, 0))
	var all := c.get_all_instances()
	assert_true(all.size() > 0, "headless creatures still spawn as data")
	assert_true(c._pool == null, "no pool is built when render_visuals is false")
	assert_eq(int(c._instances[all[0]["instance_id"]]["mi"]), -1, "instance index is the -1 sentinel")
	c.free()

func _test_creature_single_pool() -> void:
	# With rendering on, every creature shares ONE MultiMesh pool (one draw call).
	var c := CreatureSlice.new()
	add_child(c)
	c.spawn_for_chunk(Vector2i(0, 0))
	var all := c.get_all_instances()
	assert_true(all.size() > 1, "enough creatures to exercise the shared pool")
	assert_true(c._pool != null, "a pool is built when rendering")
	var seen := {}
	for inst in all:
		var mi: int = int(c._instances[inst["instance_id"]]["mi"])
		assert_true(mi >= 0, "rendered creature has a valid instance index")
		seen[mi] = true
	assert_eq(seen.size(), all.size(), "instance indices are unique per creature")
	c.free()

# ---------------------------------------------------------------------------
# BattleSlice tests
# ---------------------------------------------------------------------------

func _test_player_headless_no_ghost_or_broadcast() -> void:
	# A headless server (render_visuals = false) has no local player and renders
	# nothing: it must not build a ghost pool for remote players, and it must not
	# broadcast a phantom player at (0,0,0) to clients.
	var p := PlayerSlice.new()
	p.render_visuals = false
	add_child(p)
	p._on_remote_player_state(2, Vector3(1.0, 2.0, 3.0))
	assert_eq(p.get_remote_ghost_count(), 0, "headless server spawns no remote ghost")
	assert_true(p._ghost_pool == null, "headless server builds no ghost pool")
	var emitted := {}
	var cb := func(_payload): emitted["hit"] = true
	GameBus.player_state_changed.connect(cb)
	p._broadcast_state()
	assert_true(not emitted.has("hit"), "headless server does not broadcast a phantom player")
	GameBus.player_state_changed.disconnect(cb)
	p.free()

func _test_peer_window_rate_limited() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	assert_true(cm.set_peer_center(5, Vector2i(2, 2), true), "the first placement lands")
	var moves := 0
	for i in range(100):
		if cm.set_peer_center(5, Vector2i(100000 + i * 156, 100000)):
			moves += 1
	assert_true(moves <= 1, "100 claims 10 km apart within one interval move the window at most once")
	assert_eq(cm.peer_recenter_refused, 100, "every claim was refused or clamped")
	var centre: Vector2i = cm._peer_centers[5]
	assert_true(maxi(absi(centre.x - 2), absi(centre.y - 2)) <= ChunkManager.PEER_RECENTER_MAX_CHUNKS,
		"and the window never travelled farther than the cap")
	cm._peer_last_claim_msec[5] = -1000000
	assert_true(cm.set_peer_center(5, Vector2i(3, 2)), "a near claim after the interval is accepted")
	for k in ["cm", "voxel", "terrain", "player"]:
		rig[k].free()

func _test_peer_window_fake_clock() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var clock := [1000]
	cm.set_clock(func() -> int: return clock[0])
	cm.set_peer_center(5, Vector2i(2, 2), true)
	clock[0] += 100
	assert_false(cm.set_peer_center(5, Vector2i(3, 2)), "a claim 100 ms after the last is refused")
	assert_eq(cm.peer_recenter_refused, 1, "and counted")
	clock[0] = 1000 + int(ChunkManager.PEER_RECENTER_INTERVAL * 1000.0) - 1
	assert_false(cm.set_peer_center(5, Vector2i(3, 2)), "1 ms inside the interval is still refused")
	clock[0] += 2
	assert_true(cm.set_peer_center(5, Vector2i(3, 2)), "one ms past the interval is accepted")
	assert_eq(cm.peer_center(5), Vector2i(3, 2), "and the window moved")
	for k in ["cm", "voxel", "terrain", "player"]:
		rig[k].free()

func _test_peer_window_clamp_cap() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var cap := ChunkManager.PEER_RECENTER_MAX_CHUNKS
	cm.set_clock(func() -> int: return 0)
	cm.set_peer_center(5, Vector2i(10, 10), true)
	cm.set_clock(func() -> int: return 10000)
	assert_true(cm.set_peer_center(5, Vector2i(30, 10)), "a 20-chunk claim moves the window")
	assert_eq(cm.peer_center(5), Vector2i(10 + cap, 10), "but only by the cap")
	assert_eq(cm.peer_recenter_refused, 1, "and is counted")
	var c := TerrainSlice.circumference_chunks()
	cm.set_clock(func() -> int: return 20000)
	cm.set_peer_center(6, Vector2i(c - 2, 10), true)
	cm.set_clock(func() -> int: return 30000)
	assert_true(cm.set_peer_center(6, Vector2i(18, 10)), "a 20-chunk claim across the seam moves the window")
	assert_eq(cm.peer_center(6), Vector2i(posmod(c - 2 + cap, c), 10), "by the cap, the short way round")
	for k in ["cm", "voxel", "terrain", "player"]:
		rig[k].free()

func _test_peer_window_clamps_across_seam() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	@warning_ignore("integer_division")
	var half := TerrainSlice.circumference_chunks() / 2
	cm.set_peer_center(5, Vector2i(half - 1, 0), true)
	cm._peer_last_claim_msec[5] = -1000000
	# One chunk east of the seam is one chunk away, not a planet-width: no clamp, no refusal.
	assert_true(cm.set_peer_center(5, Vector2i(-half, 0)), "a seam crossing moves the window")
	assert_eq(cm.peer_recenter_refused, 0, "a one-chunk seam step is not clamped")
	assert_eq(cm.peer_center(5), Vector2i(-half, 0), "and lands on the wrapped chunk")
	for k in ["cm", "voxel", "terrain", "player"]:
		rig[k].free()

func _test_peer_window_host_driven() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	cm.set_peer_center(5, Vector2i(2, 2), true)
	var far := Vector2i(50000, -40000)
	assert_true(cm.set_peer_center(5, far, true), "a host-driven move is accepted inside the interval")
	assert_eq(cm._peer_centers[5], far, "and lands exactly on the target")
	assert_eq(cm.peer_recenter_refused, 0, "without counting as a refusal")
	for k in ["cm", "voxel", "terrain", "player"]:
		rig[k].free()

func _test_peer_window_host_sync() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var clock := [1000]
	cm.set_clock(func() -> int: return clock[0])
	cm.sync_peer_center(5, Vector2i(2, 2))
	for i in 10:
		clock[0] += 50
		assert_false(cm.sync_peer_center(5, Vector2i(2, 2)), "a peer that has not moved is not re-centred")
	for i in 5:
		clock[0] += 300
		assert_true(cm.sync_peer_center(5, Vector2i(3 + i, 2)), "a tracked move after the interval lands")
	assert_eq(cm.peer_center(5), Vector2i(7, 2), "and the window follows the peer")
	assert_eq(cm.peer_recenter_refused, 0, "none of it counts as a refusal")
	# The tracked position is client-reported: sync is still interval-limited and clamped, silently.
	clock[0] += 50
	assert_false(cm.sync_peer_center(5, Vector2i(8, 2)), "a sync inside the interval defers")
	clock[0] += 300
	assert_true(cm.sync_peer_center(5, Vector2i(7, 500)), "a far hop moves, but clamped")
	assert_eq(cm.peer_center(5), Vector2i(7, 2 + ChunkManager.PEER_RECENTER_MAX_CHUNKS), "to the clamp distance")
	assert_eq(cm.peer_recenter_refused, 0, "deferral and clamp by the sync are not counted")
	# A client claim inside the interval of the last move is still refused and counted once.
	cm.set_peer_center(6, Vector2i(2, 2), true)
	clock[0] += 100
	assert_false(cm.set_peer_center(6, Vector2i(3, 2)), "a client claim inside the interval is refused")
	assert_eq(cm.peer_recenter_refused, 1, "and counted once")
	for k in ["cm", "voxel", "terrain", "player"]:
		rig[k].free()

func _test_peer_window_separate_clocks() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var clock := [1000]
	cm.set_clock(func() -> int: return clock[0])
	cm.sync_peer_center(5, Vector2i(2, 2))
	clock[0] += 1000
	assert_true(cm.sync_peer_center(5, Vector2i(3, 2)), "a sync move lands")
	clock[0] += 100
	assert_true(cm.set_peer_center(5, Vector2i(4, 2)), "a claim 100 ms after a sync is accepted")
	assert_eq(cm.peer_recenter_refused, 0, "and is not counted as a refusal")
	# Two claims 100 ms apart still count exactly one refusal.
	clock[0] += 1000
	assert_true(cm.set_peer_center(5, Vector2i(5, 2)), "a claim after the interval lands")
	clock[0] += 100
	assert_false(cm.set_peer_center(5, Vector2i(6, 2)), "a second claim 100 ms later is refused")
	assert_eq(cm.peer_recenter_refused, 1, "and counted once")
	cm.clear_peer_center(5)
	assert_false(cm._peer_last_claim_msec.has(5), "clearing a peer drops its claim timestamp")
	assert_false(cm._peer_last_sync_msec.has(5), "and its sync timestamp")
	for k in ["cm", "voxel", "terrain", "player"]:
		rig[k].free()

func _test_peer_window_sync_far_hops() -> void:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var clock := [1000]
	cm.set_clock(func() -> int: return clock[0])
	cm.sync_peer_center(5, Vector2i(2, 2))
	clock[0] += 1000
	assert_true(cm.sync_peer_center(5, Vector2i(3, 2)), "a one-chunk sync move lands")
	assert_eq(cm.peer_sync_far_hops, 0, "and is not a far hop")
	clock[0] += 1000
	assert_true(cm.sync_peer_center(5, Vector2i(3, 500)), "a sync past the claim clamp still applies the move")
	assert_eq(cm.peer_center(5), Vector2i(3, 2 + ChunkManager.PEER_RECENTER_MAX_CHUNKS), "up to the clamp")
	assert_eq(cm.peer_sync_far_hops, 1, "and raises the far-hop counter by exactly one")
	assert_eq(cm.peer_recenter_refused, 0, "without touching the refusal counter")
	for k in ["cm", "voxel", "terrain", "player"]:
		rig[k].free()

func _test_peer_window_move_loads_region_edits() -> void:
	var dir := _fresh_region_dir("test_p62_teleport")
	var store: RegionStoreScript = RegionStoreScript.new(dir + "regions/")
	var edit := { "edits": { "%d,0" % (34 * 64): [{ "op": "remove", "bottom": 1.0, "top": 1.0 }] } }
	assert_eq(store.save_region(Vector2i(1, 0), { "34,0": edit }), OK, "region (1,0) holds an edit")
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	var voxel: VoxelSlice = rig["voxel"]
	cm.region_streamer = RegionStreamerScript.new(store, voxel)
	cm.view_distance = 1
	cm.prefetch_distance = 0
	# Chunk 24 (not 28): with the Phase 113 frontier margin a window reads records 4 chunks past its edge.
	cm.set_peer_center(7, Vector2i(24, 0), true)
	cm.refresh(false)
	assert_false(voxel.edited_chunk_keys().has("34,0"), "the edit is not resident before the move")
	cm._peer_last_claim_msec[7] = -1000000
	# The order the re-scope handler uses: recentre, refresh, THEN read the edits for the snapshot.
	assert_true(cm.set_peer_center(7, Vector2i(34, 0)), "the claim is within the cap")
	cm.refresh(false)
	assert_true(voxel.get_edits().has("%d,0" % (34 * 64)), "the edits the re-scope snapshot reads include the stored ones")
	for k in ["cm", "voxel", "terrain", "player"]:
		rig[k].free()

func _test_retry_represents_join_intent() -> void:
	# The client half of the retry: each re-presentation is a real packet with a
	# FRESH seq, so the host's dedup cannot mistake it for a duplicate and drop it.
	var n := NetworkingSlice.new()
	add_child(n)
	n.emulate_network = true
	n.request_handshake()
	assert_eq(n._pending.size(), 0, "a non-client never presents a join intent")
	n._role = NetworkingSlice.Role.CLIENT
	n.request_handshake()
	assert_eq(n._pending.size(), 1, "the client presents a join intent")
	var first: Dictionary = JSON.parse_string(n._pending[0]["payload"])
	assert_eq(str(first.get("type", "")), "join_intent", "and it is a join intent")
	var first_seq := int(first.get("seq", -1))
	n.request_handshake()
	assert_eq(n._pending.size(), 2, "the retry is a real second packet, not a suppressed duplicate")
	var second: Dictionary = JSON.parse_string(n._pending[1]["payload"])
	assert_true(int(second.get("seq", -1)) > first_seq, "with a fresh seq")
	n.free()

## Phase 37 — an inventory sync NAMES its owner, and only that owner's inventory applies
## it. Before this the signal was global and every InventorySlice in the process replaced
## its contents with whatever was synced, so a peer's sync clobbered the host's own pack
## and the demo merchant's stock.
func _test_inventory_sync_is_owner_scoped() -> void:
	var reg := PlayerRegistry.new()
	add_child(reg)
	var local_pid := reg.mint_player_id()
	reg.set_local_player(local_pid)
	var local_inv := InventorySlice.new()
	add_child(local_inv)
	reg.set_inventory(local_pid, local_inv)
	# A registry-CREATED inventory carries its owner (get_inventory stamps it).
	var peer_pid := "player_peer_1"
	var peer_inv: Node = reg.get_inventory(peer_pid)
	var merchant := InventorySlice.new()
	add_child(merchant)
	merchant.owner_id = "merchant"

	local_inv.add_item("Ferrite", 2)
	peer_inv.add_item("Thornwood", 3)
	merchant.add_item("hawk_feather", 5)

	GameBus.inventory_synced.emit(peer_pid, { "Ashite": 7 }, {})
	assert_eq(peer_inv.get_item_count("Ashite"), 7, "the peer's inventory takes its own sync")
	assert_eq(local_inv.get_item_count("Ferrite"), 2, "the local pack is untouched")
	assert_eq(merchant.get_item_count("hawk_feather"), 5, "and so is the merchant's stock")

	# The local bucket answers for this machine's own inventory, under either literal.
	GameBus.inventory_synced.emit("player", { "WolfFang": 1 }, {})
	assert_eq(local_inv.get_item_count("WolfFang"), 1, "a local sync lands on the local pack")
	assert_eq(peer_inv.get_item_count("Ashite"), 7, "and not on a peer's")
	assert_eq(merchant.get_item_count("WolfFang"), 0, "nor on the merchant's")
	GameBus.inventory_synced.emit("", { "Ferrite": 4 }, {})
	assert_eq(local_inv.get_item_count("Ferrite"), 4, "the empty literal means the same thing")

	# The stamp is what the filter reads.
	assert_true(peer_inv.is_owned_by(peer_pid), "a peer's inventory answers to its own id")
	assert_false(peer_inv.is_owned_by("merchant"), "and to nothing else")
	assert_false(peer_inv.is_owned_by(""), "not even the local bucket")
	assert_true(local_inv.is_owned_by(""), "the local pack answers the empty literal")
	assert_true(local_inv.is_owned_by("player"), "and the \"player\" literal")
	assert_false(local_inv.is_owned_by(peer_pid), "but not a peer's id")
	merchant.free()
	local_inv.free()
	reg.free()   # frees the registry-created peer inventory with it

## Phase 37 — and the wire half: an inventory is PRIVATE, so the host sends a sync to
## the OWNER'S peer alone and never broadcasts it (and never falls back to a broadcast
## when it cannot resolve the owner).
func _test_net_inventory_sync_is_peer_scoped() -> void:
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("player_host_1")
	var peer_pid := str(reg.resolve_identity(5))
	var host := NetworkingSlice.new()
	add_child(host)
	host.player_registry = reg
	host.emulate_network = true
	host._role = NetworkingSlice.Role.HOST

	host._on_inventory_synced(peer_pid, { "Ferrite": 1 }, {})
	assert_eq(host._pending.size(), 1, "one packet, for the owner's peer")
	assert_eq(int(host._pending[0]["peer_id"]), 5, "addressed to that peer alone")
	var packet: Dictionary = JSON.parse_string(host._pending[0]["payload"])
	assert_eq(str(packet.get("type", "")), "inventory_synced", "of the inventory_synced type")
	assert_eq(int(packet.get("contents", {}).get("Ferrite", 0)), 1, "carrying the contents")
	assert_false(JSON.stringify(packet).contains(peer_pid), "and no player id — a bearer token stays off the wire")

	# Nobody to send it to: the local bucket (this process's own inventory is already
	# live here), an offline/unknown owner, or an unwired registry. Each FAILS CLOSED.
	host._pending.clear()
	host._on_inventory_synced("", { "Ferrite": 1 }, {})
	host._on_inventory_synced("player", { "Ferrite": 1 }, {})
	host._on_inventory_synced("player_nobody_9_0", { "Ferrite": 1 }, {})
	assert_eq(host._pending.size(), 0, "a local or unresolvable owner is sent nothing")
	host.player_registry = null
	host._on_inventory_synced(peer_pid, { "Ferrite": 1 }, {})
	assert_eq(host._pending.size(), 0, "an unwired registry does not fall back to a broadcast")

	# The client half: the peer-scoped packet reaches the bus as the LOCAL bucket, so
	# only this machine's own inventory applies it.
	var client := NetworkingSlice.new()
	add_child(client)
	client._role = NetworkingSlice.Role.CLIENT
	var seen: Array = []
	var on_sync := func(synced_owner: String, contents: Dictionary, _durabilities: Dictionary) -> void:
		seen.append([synced_owner, contents])
	GameBus.inventory_synced.connect(on_sync)
	client._route_h2c(packet)
	GameBus.inventory_synced.disconnect(on_sync)
	assert_eq(seen.size(), 1, "the client re-emits the sync for its own slices")
	assert_eq(str(seen[0][0]), "", "under the local bucket")
	assert_eq(int((seen[0][1] as Dictionary).get("Ferrite", 0)), 1, "with the synced contents")
	client.free()
	host.free()
	reg.free()

## Phase 37 — a snapshot that lost a chunk can never complete, so its reassembly entry
## used to sit in the buffer for the rest of the session: one leak per lost chunk, on a
## connection that may be long gone. It is transport state, so it goes with the
## connection.
func _test_net_incomplete_snapshot_evicted_on_disconnect() -> void:
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.CLIENT
	n._accumulate_snapshot_chunk({ "snapshot_id": 1, "index": 0, "count": 2, "data": "{\"a\":" })
	assert_eq(n._snapshot_buffer.size(), 1, "a partial snapshot is buffered")
	n.forget_player_id(1)
	assert_eq(n._snapshot_buffer.size(), 0, "the dropped connection's reassembly state goes with it")

	# A complete snapshot still empties its own entry (the pre-existing path).
	n._accumulate_snapshot_chunk({ "snapshot_id": 2, "index": 0, "count": 2, "data": "{\"a\":" })
	n._accumulate_snapshot_chunk({ "snapshot_id": 2, "index": 1, "count": 2, "data": "1}" })
	assert_eq(n._snapshot_buffer.size(), 0, "reassembly is unchanged for a snapshot that completes")
	n.free()

## Phase 37 — the wire half of round routing: the host cannot apply a peer's damage
## (it holds no verifiable HP for that peer), so it sends the round to the peer whose
## body is simulated there; that client applies it to its own PlayerSlice.
func _test_net_peer_damage_is_peer_scoped() -> void:
	var host := NetworkingSlice.new()
	add_child(host)
	host.emulate_network = true
	host.send_player_damaged(5, 12.0, "creature_0_0_ForestBoar_0")
	assert_eq(host._pending.size(), 0, "a non-host cannot send damage")
	host._role = NetworkingSlice.Role.HOST
	host.send_player_damaged(5, 12.0, "creature_0_0_ForestBoar_0")
	assert_eq(host._pending.size(), 1, "the host queues exactly one packet")
	assert_eq(int(host._pending[0]["peer_id"]), 5, "addressed to the peer that was hit")
	var packet: Dictionary = JSON.parse_string(host._pending[0]["payload"])
	assert_eq(str(packet.get("type", "")), "player_damaged", "of the player_damaged type")

	# The client half: the local body absorbs it, under the id the bus has always used.
	var client := NetworkingSlice.new()
	add_child(client)
	client._role = NetworkingSlice.Role.CLIENT
	var hits: Array = []
	var on_damage := func(damage: float, attacker_id: String, target_id: String) -> void:
		hits.append([damage, attacker_id, target_id])
	GameBus.player_damaged.connect(on_damage)
	client._route_h2c(packet)
	GameBus.player_damaged.disconnect(on_damage)
	assert_eq(hits.size(), 1, "the peer's client applies the hit")
	assert_eq(float(hits[0][0]), 12.0, "for the damage the host resolved")
	assert_eq(str(hits[0][1]), "creature_0_0_ForestBoar_0", "attributed to the creature")
	assert_eq(str(hits[0][2]), "player", "addressed to the local body")

	# And a round aimed at ANOTHER player is not this body's to absorb.
	var player := PlayerSlice.new()
	add_child(player)
	assert_true(player._is_local_target("player"), "the local body takes the local rounds")
	assert_true(player._is_local_target(""), "under the resolve_player literal too")
	assert_false(player._is_local_target("player_someone_else_1_x"), "another player's is refused")
	player.free()
	client.free()
	host.free()

## Phase 38 — the snapshot's social/economy blobs travel under the ONE list of
## identity-bearing keys (`IDENTIFIED_STATE_KEYS`), the same list the receiving side walks
## to adopt its own handle. Hardcoded literals in game_root meant a fourth entry in the
## constant would have been adopted by every client while never being redacted on the way
## out: a player id on the wire.
func _test_snapshot_social_keys_are_identified() -> void:
	assert_eq(NetworkingSlice.IDENTIFIED_STATE_KEYS.size(), 3,
		"the list names three identity-bearing blobs")
	for key in ["market", "governance", "trade"]:
		assert_true(NetworkingSlice.IDENTIFIED_STATE_KEYS.has(key),
			"%s is one of them" % key)

	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("player_1000_1_" + "aa".repeat(16))
	var seller := str(reg.resolve_identity(4))
	var n := NetworkingSlice.new()
	add_child(n)
	n.player_registry = reg

	var sessions := {}
	sessions[seller] = { "state": "open" }
	var walked: Dictionary = n.redact_social_state({
		"market":     { "listings": [{ "seller": seller, "price": 3.0 }] },
		"governance": { "proposals": [{ "author": seller }] },
		"trade":      { "sessions": sessions },
		"creatures":  [{ "seller": seller }],
	})
	assert_eq(walked.size(), 3, "only the listed blobs are carried")
	for key in NetworkingSlice.IDENTIFIED_STATE_KEYS:
		assert_true(walked.has(key), "and %s is carried under its wire name" % key)
	assert_false(walked.has("creatures"),
		"a blob the list does not name is dropped, never passed through unredacted")

	var market: Dictionary = walked["market"]
	var listing: Dictionary = (market.get("listings", []) as Array)[0]
	assert_eq(str(listing.get("seller", "")), reg.public_handle(seller),
		"a listing's seller crosses the wire as a public handle")
	var gov: Dictionary = walked["governance"]
	var proposal: Dictionary = (gov.get("proposals", []) as Array)[0]
	assert_eq(str(proposal.get("author", "")), reg.public_handle(seller),
		"so does a proposal's author")
	var trade: Dictionary = walked["trade"]
	assert_true((trade.get("sessions", {}) as Dictionary).has(reg.public_handle(seller)),
		"and a trade party does, even as a dictionary KEY")
	assert_false(JSON.stringify(walked).contains(seller),
		"with no player id left anywhere in the payload")
	n.free()
	reg.free()

## Phase 38 — the snapshot buffer's clear sites were both on the HOST's side of the wire
## (this slice's own teardown, and a PEER disconnecting), so a client that lost its host
## kept a half-reassembled snapshot for the rest of the session. The host it was waiting
## on is gone, and no chunk of that snapshot can still arrive.
func _test_net_snapshot_buffer_cleared_when_host_lost() -> void:
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.CLIENT
	n._accumulate_snapshot_chunk({ "snapshot_id": 1, "index": 0, "count": 2, "data": "{\"a\":" })
	assert_eq(n._snapshot_buffer.size(), 1, "a partial snapshot is buffered")
	n._on_server_disconnected()
	assert_eq(n._snapshot_buffer.size(), 0,
		"losing the host takes the half-reassembled snapshot with it")

	# Role-gated: a host has no server to lose, and its own teardown (`disconnect_all`)
	# already clears the buffer — this must not become a second, weaker clear.
	n._role = NetworkingSlice.Role.HOST
	n._accumulate_snapshot_chunk({ "snapshot_id": 2, "index": 0, "count": 2, "data": "{\"a\":" })
	n._on_server_disconnected()
	assert_eq(n._snapshot_buffer.size(), 1, "a host-role call changes nothing")
	n.free()

## Phase 39 — the step table is the scenario's contract with the driver: the driver
## asserts that BOTH processes reported every step in it, so a step silently dropped from
## one side (a role that no longer runs it after an edit) is caught rather than passing
## on the other side's line alone.
func _test_net_harness_step_table() -> void:
	var steps := NetHarness.steps()
	assert_true(steps.size() >= 10, "the scenario carries a substantial step list")
	var names: Dictionary = {}
	for s in steps:
		assert_true(s is Dictionary, "every entry is a step record")
		assert_true(s.has("name"), "and names itself")
		assert_true(s.has("compare"), "and says whether the driver must compare its details")
		names[str(s.get("name", ""))] = true
	assert_eq(names.size(), steps.size(), "step names are unique — the driver keys on them")
	assert_eq(str(steps[0].get("name", "")), "handshake", "the scenario starts with the handshake")
	assert_eq(str(steps[steps.size() - 1].get("name", "")), "world_regen_synced",
		"and ends with a regenerated world reaching a client (Phase 182)")
	assert_eq(str(steps[steps.size() - 2].get("name", "")), "admin_moves_synced",
		"after the admin moves and heal reaching a client (Phase 182)")
	assert_eq(str(steps[steps.size() - 3].get("name", "")), "carcass_synced",
		"after a worked and carried carcass agreed on across the wire (Phase 161)")
	assert_eq(str(steps[steps.size() - 4].get("name", "")), "gesture_synced",
		"after a seated pose agreed on across the wire (Phase 159)")
	assert_eq(str(steps[steps.size() - 5].get("name", "")), "death_landing_synced",
		"after a killed creature's landing agreed on a client (Phase 157)")
	assert_eq(str(steps[steps.size() - 6].get("name", "")), "peer_attack_animated",
		"after a peer's swing animated on a client (Phase 156)")
	assert_eq(str(steps[steps.size() - 7].get("name", "")), "creature_far_delta",
		"after a far creature delta kept to the centimetre (Phase 171)")
	assert_eq(str(steps[steps.size() - 8].get("name", "")), "fold_carries_creatures",
		"after a creature carried across a client's fold (Phase 145)")
	assert_eq(str(steps[steps.size() - 9].get("name", "")), "frontier_record_synced",
		"after a frontier record reaching the client (Phase 113), after the generation record (Phase 109)")
	assert_eq(str(steps[steps.size() - 10].get("name", "")), "chunk_record_synced", "which follows the generation record")
	assert_eq(str(steps[steps.size() - 11].get("name", "")), "spawn_near_friend", "after the friend-code spawn (Phase 53)")

## Phase 39 — the wire is a text channel between two processes, so the line format and its
## parser are load-bearing: if they disagreed, the driver would silently compare nothing
## and every run would look green.
func _test_net_harness_line_round_trip() -> void:
	var line := NetHarness.format_line("chop_in_reach", "ok", "tree_0_0_1")
	assert_eq(line, "HARNESS chop_in_reach ok tree_0_0_1", "the compiled line is the agreed format")
	var parsed := NetHarness.parse_line(line)
	assert_eq(str(parsed.get("step", "")), "chop_in_reach", "and parses back to its step")
	assert_eq(str(parsed.get("verdict", "")), "ok", "its verdict")
	assert_eq(str(parsed.get("detail", "")), "tree_0_0_1", "and its detail")
	# Noise must not parse: the driver reads the WHOLE process log, which is full of the
	# game's own output, and a false positive there would fake a step.
	assert_true(NetHarness.parse_line("").is_empty(), "an empty line is not a harness line")
	assert_true(NetHarness.parse_line("[Server] listening on port 7777, max_clients 64").is_empty(),
		"nor is a server boot line")
	assert_true(NetHarness.parse_line("HARNESS handshake ok").is_empty(),
		"nor a line missing its detail")
	assert_true(NetHarness.parse_line("harness handshake ok detail").is_empty(),
		"and the tag is case-exact")

## Phase 39 — the convergence verdict. "refused" is a PASS: half the scenario asserts that
## something did NOT happen (an out-of-reach chop, an oversized packet), so a verdict
## function that treated "not seen" as failure would turn the security steps into tests
## that fail whenever they work.
func _test_net_harness_verdict() -> void:
	assert_eq(NetHarness.verdict(true, true), "ok", "an expected event that happened passes")
	assert_eq(NetHarness.verdict(false, false), "refused", "an expected ABSENCE that held passes as a refusal")
	assert_eq(NetHarness.verdict(false, true), "fail", "an expected event that never came fails")
	assert_eq(NetHarness.verdict(true, false), "fail", "and so does an event that should not have happened")
	assert_true(NetHarness.passed("ok"), "ok counts as a pass")
	assert_true(NetHarness.passed("refused"), "and so does refused")
	assert_false(NetHarness.passed("fail"), "while fail does not")

## Phase 39 — the target selection. Both processes pick their scenario trees from their
## OWN table with this rule, so it has to be a pure function of the tree table: any
## dependence on dictionary order would have the two sides naming different trees.
func _test_net_harness_target_selection() -> void:
	var origin := Vector3(16.0, 12.0, 16.0)
	var trees: Array = [
		{ "tree_id": "tree_c", "position": Vector3(20.0, 3.0, 20.0) },   # near
		{ "tree_id": "tree_a", "position": Vector3(30.0, 3.0, 16.0) },   # near
		{ "tree_id": "tree_b", "position": Vector3(5.0, 3.0, 5.0) },     # near
		{ "tree_id": "tree_far", "position": Vector3(200.0, 3.0, 200.0) },
	]
	var picked := NetHarness.in_reach_targets(trees, origin, 20.0, 3)
	assert_eq(picked.size(), 3, "every tree inside the radius is a candidate")
	assert_eq(str(picked[0]), "tree_a", "and they come back sorted by id, not by table order")
	assert_eq(str(picked[2]), "tree_c", "so both processes agree without a side channel")
	assert_eq(NetHarness.in_reach_targets(trees, origin, 20.0, 2).size(), 2,
		"the caller's count caps the list")
	# The out-of-reach half: beyond the radius, and again id-sorted so a small difference
	# between the two sides' view of the world cannot change the answer.
	assert_eq(NetHarness.beyond_reach_target(trees, origin, 70.0), "tree_far",
		"only the far tree is beyond the refusal radius")
	assert_eq(NetHarness.beyond_reach_target(trees, origin, 1000.0), "",
		"and an empty selection is reported as empty, never as the nearest tree")

## #429 — the ordering that flaked `chop_in_reach`: one side's origin-chunk trees land after the step starts
## (the client from the snapshot, the host when its chunk build attaches). A partial table is not ready, so
## the step waits instead of failing `no_in_reach_target` / `not_consumed`; once the set is complete both
## orders of arrival name the same targets.
func _test_net_harness_targets_arrive_late() -> void:
	var o := NetHarness.RENDEZVOUS
	var t1 := { "tree_id": "tree_1", "position": o + Vector3(2, 0, 0) }
	var t2 := { "tree_id": "tree_2", "position": o + Vector3(0, 0, 3) }
	var t3 := { "tree_id": "tree_3", "position": o + Vector3(4, 0, 4) }
	var n := NetHarness.TARGETS_NEEDED
	assert_false(NetHarness.targets_ready([], o, NetHarness.TARGET_REACH, n), "no trees yet: the step must wait")
	assert_false(NetHarness.targets_ready([t3, t1], o, NetHarness.TARGET_REACH, n), "a partial table: the step must wait")
	var early := NetHarness.in_reach_targets([t3, t1, t2], o, NetHarness.TARGET_REACH, n)
	var late := NetHarness.in_reach_targets([t2, t1, t3], o, NetHarness.TARGET_REACH, n)
	assert_true(NetHarness.targets_ready([t3, t1, t2], o, NetHarness.TARGET_REACH, n), "the full set is ready")
	assert_eq(early, late, "arrival order does not change the targets both sides name")

## Phase 39 review pass — the pump's own audit, the ONE class the synchronous suite could
## not otherwise reach, because it has no frames to give and so cannot host the pump.
##
## A coroutine called without `await` compiles, runs, and returns at its first yield: the
## step stops waiting and the scenario reports on a run that did not happen. That is not
## hypothetical — every `_await_settle` call site in the runner was bare, so the rate-limit
## step fired its post-burst chops in the same frame as the burst that had emptied the peer's
## step blamed the LIMITER for its own missing wait. The rule is
## assertable without frames, so it lives as a pure function; the runner also points it at
## its OWN source on every boot (`NetHarness._self_audit`), which is the half this test
## cannot do for it.
func _test_net_harness_bare_await_audit() -> void:
	# The definition is not a call, an awaited call in an expression is fine, and a bare
	# call is the offender — as a LINE NUMBER, so a failure names where to look.
	var mixed := PackedStringArray([
		"func _await_until(p: Callable, t: float) -> bool:",
		"		_await_settle(1.0)",
		"	await _await_until(func(): return true, 1.0)",
		"	var ok: bool = await _await_until(f, 1.0)",
		"",
		"		await _await_settle(ABSENCE_WINDOW_SECS)",
	])
	var flagged := NetHarness.unawaited_waits(mixed)
	assert_eq(flagged.size(), 1, "exactly one line of that sample is a bare coroutine call")
	assert_true(flagged.has("2"), "and it is the bare call, reported by line number")
	var clean := PackedStringArray(["", "await _await_until(f, 1.0)", "await _await_settle(1.0)"])
	assert_true(NetHarness.unawaited_waits(clean).is_empty(), "an awaited file reports nothing")

	# And the file the audit guards, audited. Skipped with a note rather than passed when the
	# source is not on disk (an exported build ships bytecode) — an audit that could not run
	# is not evidence, which is also what `NetHarness._self_audit` says out loud.
	var src := FileAccess.open("res://src/tests/net_harness.gd", FileAccess.READ)
	if src == null:
		return
	var offenders := NetHarness.unawaited_waits(src.get_as_text().split("\n"))
	assert_true(offenders.is_empty(),
		"NetHarness calls a bare coroutine at line(s) %s" % [", ".join(offenders)])

# ---------------------------------------------------------------------------
# Phase 42 — threaded chunk build, greedy merge, the first-ring gate
# ---------------------------------------------------------------------------
#
# The build is dispatched to a WorkerThreadPool task and applied on the main thread,
# and the suite has no frames to give — so these tests drive the manager's pump by
# hand: DRAIN (dispatch), BLOCK on each in-flight task, APPLY. That is exactly what
# `ChunkManager._process` does across frames, with the wait made explicit.

func _test_net_emulator_latency() -> void:
	# Phase 135 — with 200 ms latency a packet is not delivered before 200 ms after it was sent.
	var n := NetworkingSlice.new()
	add_child(n)
	n.emulate_network = true
	n.emulator_latency_ms = 200.0
	n.emulator_retransmit = true
	n.emulator_loss_rate = 30.0
	n._rng.seed = 5
	for _i in range(100):
		assert_true(n._deliver(1, { "type": "x" }), "a lost packet is retransmitted, not dropped")
	assert_eq(n._pending.size(), 100, "every packet is queued, none lost")
	assert_true(n.emulator_retransmits > 0, "some were retransmitted late")
	n.emulator_loss_rate = 0.0
	var sent := 1000.0
	assert_eq(n._schedule_at_ms(sent, 100), sent + 200.0, "delivery time is send + latency")
	for _i in range(50):
		assert_true(n._schedule_at_ms(sent, 100) >= sent + 200.0, "never earlier than the latency")
	n.free()

func _test_net_emulator_reliable_in_order() -> void:
	# ENet's reliable channel is ordered: a packet waiting on a retransmit or a long jitter draw holds
	# every later one. Order-sensitive edits (a mine, then the settle it causes) rely on it.
	var n := NetworkingSlice.new()
	add_child(n)
	n.emulate_network = true
	n.emulator_latency_ms = 200.0
	n.emulator_jitter_ms = 60.0
	n.emulator_retransmit = true
	n.emulator_loss_rate = 30.0
	n._rng.seed = 11
	for _i in range(200):
		n._deliver(1, { "type": "block_changed" })
		n._deliver(2, { "type": "block_changed" })
	assert_true(n.emulator_retransmits > 0, "some packets were retransmitted late")
	var last := { 1: -1.0, 2: -1.0 }
	var ordered := true
	for e in n._pending:
		var pid := int(e["peer_id"])
		ordered = ordered and float(e["at_ms"]) >= float(last[pid])
		last[pid] = float(e["at_ms"])
	assert_true(ordered, "no packet is scheduled before one queued earlier for the same peer")
	n.free()

func _test_net_emulator_bandwidth() -> void:
	# Phase 135 — a 256 kbit/s cap (32,000 B/s) never delivers more than 32 KB in any one-second
	# window, and the excess is delayed rather than dropped.
	var n := NetworkingSlice.new()
	add_child(n)
	n.emulate_network = true
	n.emulator_bandwidth_kbps = 256.0
	var times: Array = []
	for _i in range(100):
		times.append(n._schedule_at_ms(0.0, 1000))  # 100 KB offered at one instant
	assert_eq(times.size(), 100, "no packet dropped by the cap")
	var worst := 0
	for start in times:
		var bytes := 0
		for t in times:
			if t >= start and t < start + 1000.0:
				bytes += 1000
		worst = maxi(worst, bytes)
	assert_true(worst <= 32000, "at most 32 KB delivered in any one-second window (got %d)" % worst)
	assert_true(float(times.back()) >= 3000.0, "100 KB at 32 KB/s takes about 3 s")
	# The delayed packets still arrive: drain at a late time delivers all queued ones.
	n._pending.clear()
	for i in range(5):
		n._pending.append({ "at_ms": float(times[i]), "peer_id": 1, "payload": "{}" })
	n._drain_emulator(float(times[2]))
	assert_eq(n._pending.size(), 2, "only the packets due by then are delivered")
	n.free()

func _test_net_profiles() -> void:
	# Phase 135 — the profile table, the arg parser, and the refusal of an unknown name.
	for name in ["loopback", "lan", "wan_br", "wan_bad"]:
		assert_true(NetworkingSlice.has_profile(name), "%s is defined" % name)
	assert_false(NetworkingSlice.has_profile("wan_worse"), "unknown name is not a profile")
	assert_eq(NetworkingSlice.profile_from_args(["--server"]), "", "no flag, no profile")
	assert_eq(NetworkingSlice.profile_from_args(["--net-profile", "wan_bad"]), "wan_bad", "flag value read")
	assert_eq(NetworkingSlice.profile_from_args(["--net-profile"]), "?", "flag without value is refused")
	assert_false(NetworkingSlice.has_profile(NetworkingSlice.profile_from_args(["--net-profile", "--server"])),
			"flag followed by another flag is refused")
	var n := NetworkingSlice.new()
	add_child(n)
	assert_true(n._apply_profile_arg(["--run-tests"]), "no flag is not a refusal")
	assert_false(n.emulate_network, "no flag leaves the emulator off")
	assert_true(n._apply_profile_arg(["--net-profile", "wan_br"]), "a known profile applies from args")
	assert_eq(n.net_profile, "wan_br", "args select wan_br")
	n.apply_profile("loopback")
	assert_false(n.apply_profile("nope"), "unknown profile refused")
	assert_false(n.emulate_network, "a refused profile changes nothing")
	assert_true(n.apply_profile("wan_bad"), "wan_bad applies")
	assert_true(n.emulate_network, "wan_bad turns the emulator on")
	assert_eq(n.emulator_latency_ms, 200.0, "wan_bad latency 200 ms")
	assert_eq(n.emulator_jitter_ms, 60.0, "wan_bad jitter 60 ms")
	assert_eq(n.emulator_loss_rate, 5.0, "wan_bad loss 5%")
	assert_eq(n.emulator_bandwidth_kbps, 256.0, "wan_bad cap 256 kbit/s")
	assert_true(n.apply_profile("wan_br"), "wan_br applies")
	assert_eq(n.emulator_latency_ms, 60.0, "wan_br latency 60 ms")
	assert_eq(n.emulator_jitter_ms, 15.0, "wan_br jitter 15 ms")
	assert_eq(n.emulator_loss_rate, 1.0, "wan_br loss 1%")
	assert_true(n.apply_profile("loopback"), "loopback applies")
	assert_false(n.emulate_network, "loopback turns the emulator off")
	n.free()
