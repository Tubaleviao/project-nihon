extends "res://src/tests/test_support.gd"
## Phase 196 — follow-up debt burn IV: waystones (#336), gestures (#420), the player registry and the look
## request limit (#522), and the minimap's boot seed.

const GestureRules := preload("res://src/character/gesture_rules.gd")
const GestureSlice := preload("res://src/character/gesture_slice.gd")
const CreationRules := preload("res://src/character/creation_rules.gd")

const VALID := { "name": "Akira", "gender": "feminine", "hair": "hair_f_bob", "hairColor": 129 }


func register() -> void:
	_run_test("p196: a peer over its look_request limit is refused, and the limit refills", _test_look_limit)
	_run_test("p196: refused travel intents from one peer get at most one reply a second", _test_waystone_reply_throttle)
	_run_test("p196: a far waystone (chunk 600,000) keeps its exact position and a reload never reuses an id", _test_waystone_far_and_ids)
	_run_test("p196: placing a waystone without the Waystone item is refused with a keyed reason", _test_waystone_needs_item)
	_run_test("p196: the attune radius has a vertical bound of one chunk height", _test_waystone_vertical_bound)
	_run_test("p196: a jump ends a Sit pose, and an airborne refusal spends no token", _test_jump_ends_pose)
	_run_test("p196: a swing at empty air ends a held pose on the host", _test_empty_swing_cancels)
	_run_test("p196: the host resolves Sit once and every viewer shows its lift", _test_host_resolves_seat)
	_run_test("p196: a pose that ended out of AOI is sent as stood-up on re-entry, never replayed", _test_ended_pose_not_replayed)
	_run_test("p196: a disconnect forgets the peer's pose and replay pairs", _test_disconnect_forgets)
	_run_test("p196: a refused gesture gets a keyed notice, once a second", _test_gesture_refusal_notice)
	_run_test("p196: resting regen heals a remote peer's own client", _test_remote_rest_heal)
	_run_test("p196: an expired one-shot leaves the gesture state in the air", _test_oneshot_ends_airborne)
	_run_test("p196: a loaded record never takes a name skeleton another player holds", _test_loaded_name_taken)
	_run_test("p196: a starting-kit item that does not fit lands on the ground", _test_kit_overflow_drops)
	_run_test("p196: the minimap never saves a client's throwaway boot seed", _test_minimap_boot_seed)
	_run_test("p196: every new string is in both catalogs", _test_catalog)


func _test_look_limit() -> void:
	var reg := PlayerRegistry.new()
	reg.is_authoritative = true
	var viewer := reg.resolve_identity(4, "")
	var subject := reg.resolve_identity(6, "")
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.player_registry = reg
	n.set_player_id(4, viewer)
	n.set_player_id(6, subject)
	n.set_transport(MemoryTransport.new([4, 6]))
	n.remember_player_state(4, Vector3(0, 10, 0))
	n.remember_player_state(6, Vector3(10, 10, 0))
	var answered := 0
	for i in 100:
		if n.answer_look_request(4, 6, 1000.0):
			answered += 1
	assert_eq(answered, int(n._m1.LOOK_BUCKET_CAPACITY), "a burst is answered, the rest of a flood is refused")
	assert_true(n.look_requests_refused >= 100 - answered, "and counted refused")
	assert_true(n.answer_look_request(4, 6, 1000.0 + 1000.0), "a second later the limit has refilled")
	assert_true(n.answer_look_request(6, 4, 1000.0), "another peer's budget is its own")
	n.forget_player_id(4)
	assert_false(n._m1._look_buckets.has(4), "the budget goes with the peer")
	n.free()
	reg.free()


func _test_waystone_reply_throttle() -> void:
	var rig := _waystone_rig()
	var way: WaystoneSlice = rig["way"]
	var now: Array = rig["now"]
	rig["reg"].is_authoritative = true
	var a: String = rig["stations"].place_station("waystone", Vector3(0.5, 1.0, 0.5))
	var replies: Array = []
	var on_res := func(_pid: String, ok: bool, _reason: String) -> void: replies.append(ok)
	GameBus.waystone_travel_resolved.connect(on_res)
	var was_quiet := Diag.quiet
	Diag.quiet = true
	for i in 30:   # 3 s of refused intents, ten a second
		way._on_travel_intent(a, "station_99", "p1")
		now[0] += 0.1
	Diag.quiet = was_quiet
	GameBus.waystone_travel_resolved.disconnect(on_res)
	assert_true(replies.size() >= 2 and replies.size() <= 3, "30 refusals over 3 s earn one reply a second, got %d" % replies.size())
	_free_waystone_rig(rig)


func _test_waystone_far_and_ids() -> void:
	var rig := _waystone_rig()
	var way: WaystoneSlice = rig["way"]
	var st: StationSlice = rig["stations"]
	var reg: PlayerRegistry = rig["reg"]
	reg.is_authoritative = true
	# The roadmap's chunk 1,500,000 is past one lap (1,250,000 chunks at 40,000 km), so no body stands there;
	# 600,000 is the farthest a player gets from the origin (near the antipode), where float32 is coarsest.
	var far := { "chunk": Vector2i(600000, -3), "local": Vector3(7.3125, 12.5, 0.0625) }
	var first := st.place_station("waystone", Vector3(0.5, 1.0, 0.5))
	var last := st.place_station("waystone", Vector3(40.5, 1.0, 0.5))
	way.note_exact(first, far)
	reg.record_waystones("p1", [first, last])
	# Save, remove the highest-numbered stone, save again (the world record), reload into fresh slices.
	st.remove_station(last)
	var stations := st.get_station_data()
	var next := st.next_id()
	var exact := way.exact_data()
	var players := reg.get_player_data("p1")
	var st2 := StationSlice.new()
	add_child(st2)
	st2.apply_station_data(stations)
	st2.restore_next_id(next)
	var way2 := WaystoneSlice.new()
	way2.station_slice = st2
	way2.registry = reg
	add_child(way2)
	way2.apply_exact_data(exact)
	reg.apply_player_data("p1", players)
	var back := way2.exact_pos(first)
	assert_eq(back["chunk"], far["chunk"], "the far stone keeps its chunk through a reload")
	assert_true((back["local"] as Vector3).distance_to(far["local"]) < 0.01, "and its local offset to under 1 cm")
	var fresh := st2.place_station("waystone", Vector3(80.5, 1.0, 0.5))
	assert_true(fresh != last, "the next stone gets a fresh id, not the removed %s" % last)
	assert_false(way2.attuned("p1").has(fresh), "and no old attunement binds to it")
	assert_true(way2.attuned("p1").has(first), "the standing stone stays attuned")
	way2.free()
	st2.free()
	_free_waystone_rig(rig)


func _test_waystone_needs_item() -> void:
	var rig := _waystone_rig()
	var st: StationSlice = rig["stations"]
	var inv: Node = rig["reg"].get_inventory("p1")
	var why := st.place_refusal("waystone", Vector3(0.5, 1.0, 0.5), inv)
	assert_eq(why, "no_placement_item:Waystone", "no Waystone item: refused with a keyed reason")
	assert_true(I18nScript.has_key("reason.no_placement_item"), "the reason has a catalog line")
	assert_true(I18nScript.reason_text(why).contains("Waystone"), "naming the item")
	assert_eq(st.try_place_station("waystone", Vector3(0.5, 1.0, 0.5), inv), "", "and nothing is placed")
	assert_true(inv.add_item("Waystone", 1), "stock a stone")
	assert_eq(st.place_refusal("waystone", Vector3(0.5, 1.0, 0.5), inv), "", "with the item there is no refusal")
	assert_eq(st.place_refusal("forge", Vector3(9.5, 1.0, 9.5)), "", "a forge needs no item")
	_free_waystone_rig(rig)


func _test_waystone_vertical_bound() -> void:
	var rig := _waystone_rig()
	var way: WaystoneSlice = rig["way"]
	var where: Dictionary = rig["where"]
	rig["reg"].is_authoritative = true
	var a: String = rig["stations"].place_station("waystone", Vector3(0.5, 1.0, 0.5))
	where["p1"] = WorldPos.from_world(0.5, 1.0 + WorldPos.CHUNK_METERS + 5.0, 0.5)
	assert_eq(way.try_attune("p1", a), "too_far", "a body more than a chunk height above the stone is not at it")
	where["p1"] = WorldPos.from_world(0.5, 1.0 + 3.0, 0.5)
	assert_eq(way.try_attune("p1", a), "", "a body a few metres up still is")
	_free_waystone_rig(rig)


## A host-shaped GameRoot: registry, gesture slice and wiring, the host's avatar, a networking host with peers 2
## (a viewer) and 3 (a player who gestures), both bound and reporting positions.
func _host() -> Dictionary:
	var gr: Node = (load("res://src/core/game_root.gd") as GDScript).new()
	var ch := CharacterSlice.new()
	add_child(ch)
	gr._character = ch
	var reg := PlayerRegistry.new()
	reg.is_authoritative = true
	reg.local_player_id = "p1"
	gr._registry = reg
	var p2 := reg.resolve_identity(2, "")
	var p3 := reg.resolve_identity(3, "")
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.player_registry = reg
	n.set_player_id(2, p2)
	n.set_player_id(3, p3)
	var wire := MemoryTransport.new([2, 3])
	n.set_transport(wire)
	n.remember_player_state(2, Vector3(4, 10, 0))
	n.remember_player_state(3, Vector3(0, 10, 0))
	gr._networking = n
	var sl := GestureSlice.new()
	var now := [0.0]
	sl.clock = func() -> float: return now[0]
	add_child(sl)
	gr._gesture = sl
	gr._gesture_wiring.wire(gr)
	return { "gr": gr, "ch": ch, "reg": reg, "n": n, "wire": wire, "sl": sl, "now": now, "p2": p2, "p3": p3 }


func _free_host(h: Dictionary) -> void:
	h["gr"]._gesture_wiring.unwire()
	h["sl"].free()
	h["n"].free()
	h["ch"].free()
	h["reg"].free()
	h["gr"].free()


func _gesture_packets(wire: MemoryTransport, to_peer: int) -> Array:
	return wire.outbox.filter(func(o): return int(o["peer_id"]) == to_peer and str(o["payload"].get("type", "")) == "gesture") \
		.map(func(o): return o["payload"])


func _test_jump_ends_pose() -> void:
	var sl := GestureSlice.new()
	var now := [0.0]
	sl.clock = func() -> float: return now[0]
	add_child(sl)
	assert_eq(sl.request("p1", "Sit", true, true, Vector3(0, 10, 0)), "", "sit")
	sl.note_position("p1", Vector3(0.05, 10.2, 0))
	assert_eq(sl.held_id("p1"), "Sit", "settling on the spot keeps the pose")
	sl.note_position("p1", Vector3(0.05, 11.3, 0))
	assert_eq(sl.held_id("p1"), "", "a jump ends it")
	now[0] += 100.0
	for i in 10:
		assert_eq(sl.request("p2", "Sit", true, false, Vector3.ZERO), GestureSlice.REFUSE_AIRBORNE, "airborne: refused")
	var ok := 0
	for i in int(GestureRules.RATE_CAPACITY):
		if sl.request("p2", "Wave", true, true, Vector3.ZERO) == "":
			ok += 1
	assert_eq(ok, int(GestureRules.RATE_CAPACITY), "the airborne refusals spent no token")
	sl.free()


func _test_empty_swing_cancels() -> void:
	# The body: an empty-air swing in a pose sends the body's own stand-up intent.
	var ps := PlayerSlice.new()
	var creatures := CreatureSlice.new()
	ps.creature_slice = creatures
	var seen: Array = []
	var on_intent := func(g: String, p: String) -> void: seen.append([g, p])
	GameBus.gesture_intent.connect(on_intent)
	ps._try_attack()
	assert_eq(seen.size(), 0, "a swing out of a pose sends nothing")
	ps.in_pose = true
	ps._try_attack()
	GameBus.gesture_intent.disconnect(on_intent)
	assert_eq(seen, [["", ""]], "a swing at empty air in a pose asks to stand up")
	ps.free()
	creatures.free()
	# The host: that intent ends the held pose (a remote peer's is bound to its connection the same way).
	var h := _host()
	assert_eq(h["sl"].request("p1", "SitGround", true, true, Vector3.ZERO), "", "the host sits")
	GameBus.gesture_intent.emit("", "")
	assert_eq(h["sl"].held_id("p1"), "", "the swing's stand-up ends it on the host")
	assert_eq(h["sl"].request(h["p3"], "SitGround", true, true, Vector3.ZERO), "", "a peer sits")
	GameBus.gesture_intent.emit("", h["p3"])
	assert_eq(h["sl"].held_id(h["p3"]), "", "and its stand-up ends its own pose")
	_free_host(h)


func _test_host_resolves_seat() -> void:
	var h := _host()
	var wiring = h["gr"]._gesture_wiring
	wiring.seat_probe = func(_iid: String) -> float: return 0.45
	h["wire"].outbox.clear()
	GameBus.gesture_intent.emit("Sit", h["p3"])
	assert_eq(h["sl"].held_id(h["p3"]), "Sit", "a seat in front: the host keeps Sit")
	assert_true(absf(h["sl"].lift_of(h["p3"]) - 0.45) < 0.0001, "with the lift it measured")
	var got := _gesture_packets(h["wire"], 2)
	assert_eq(got.size(), 1, "the viewer is told once")
	assert_eq(str(got[0]["g"]), "Sit", "the pose")
	assert_true(absf(float(got[0].get("l", -1.0)) - 0.45) < 0.0001, "and the host's lift")
	GameBus.gesture_intent.emit("", h["p3"])
	h["now"][0] += 10.0
	wiring.seat_probe = func(_iid: String) -> float: return -1.0
	h["wire"].outbox.clear()
	GameBus.gesture_intent.emit("Sit", h["p3"])
	assert_eq(h["sl"].held_id(h["p3"]), "SitGround", "no seat: the host decides SitGround")
	got = _gesture_packets(h["wire"], 2)
	assert_eq(str(got[0]["g"]), "SitGround", "and that is what the viewers get")
	assert_false(got[0].has("l"), "with no lift")
	# The listen host shows the client's pose on its own avatar of that client.
	var other: String = h["ch"].create_character("TravellerHuman", Vector3(3, 0, 0))
	assert_true(h["ch"].attach_rig(other, "models/player_rig.glb.raw"), "the peer's avatar gets a rig")
	h["ch"].bind_peer_character(3, other)
	wiring.tick(0.1)
	assert_eq(h["ch"]._m2.gesture_clip_of(other), "sit_ground", "the listen host poses its view of the client")
	h["ch"].remove_character(other)
	_free_host(h)
	# A viewer applies the host's lift, not its own probe: two viewers with different probes agree.
	for probe in [0.6, -1.0]:
		var c := _host()
		c["gr"]._is_client = true
		c["gr"]._gesture_wiring.seat_probe = func(_iid: String) -> float: return probe
		var av: String = c["ch"].create_character("TravellerHuman", Vector3(3, 0, 0))
		assert_true(c["ch"].attach_rig(av, "models/player_rig.glb.raw"), "a viewer's avatar of the sitter")
		c["ch"].bind_peer_character(7, av)
		GameBus.peer_gesture_synced.emit(7, "Sit", 0.3)
		assert_eq(c["ch"]._m2.gesture_clip_of(av), "sit", "the viewer (probe %s) plays the host's Sit" % str(probe))
		assert_true(absf(float(c["ch"]._instances[av]["seat_lift"]) - 0.3) < 0.0001, "at the host's lift")
		c["gr"]._is_client = false
		c["ch"].remove_character(av)
		_free_host(c)
	# The wire: a lift out of the seat range or not a number is clamped or dropped on the client.
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.CLIENT
	var lifts: Array = []
	var on_g := func(_p: int, _g: String, l: float) -> void: lifts.append(l)
	GameBus.peer_gesture_synced.connect(on_g)
	n._route_h2c({ "type": "gesture", "peer_id": 7, "g": "Sit", "l": 99.0 })
	n._route_h2c({ "type": "gesture", "peer_id": 7, "g": "Sit", "l": NAN })
	n._route_h2c({ "type": "gesture", "peer_id": 7, "g": "Sit", "l": "high" })
	n._route_h2c({ "type": "gesture", "peer_id": 7, "g": "Sit" })
	GameBus.peer_gesture_synced.disconnect(on_g)
	assert_eq(lifts, [GestureRules.SEAT_MAX_RISE, -1.0, -1.0, -1.0], "a wild lift is clamped, a non-number means none")
	n.free()


func _test_ended_pose_not_replayed() -> void:
	var h := _host()
	var wiring = h["gr"]._gesture_wiring
	var n: NetworkingSlice = h["n"]
	assert_eq(h["sl"].request(h["p3"], "SitGround", true, true, Vector3(0, 10, 0)), "", "peer 3 sits")
	wiring._replay_to_entrants()
	# The viewer walks away; peer 3 stands up while it is gone; the viewer comes back.
	n.remember_player_state(2, Vector3(NetworkingSlice.AOI_RADIUS * 3.0, 10, 0))
	wiring._replay_to_entrants()
	h["sl"].request(h["p3"], "", true, true, Vector3.ZERO)
	n.remember_player_state(2, Vector3(4, 10, 0))
	h["wire"].outbox.clear()
	wiring._replay_to_entrants()
	var got := _gesture_packets(h["wire"], 2)
	assert_eq(got.size(), 1, "the returning viewer is told once")
	assert_eq(str(got[0]["g"]), "", "that the pose ended (not the old pose)")
	assert_eq(int(got[0]["peer_id"]), 3, "for peer 3")
	h["wire"].outbox.clear()
	n.remember_player_state(2, Vector3(NetworkingSlice.AOI_RADIUS * 3.0, 10, 0))
	wiring._replay_to_entrants()
	n.remember_player_state(2, Vector3(4, 10, 0))
	wiring._replay_to_entrants()
	assert_eq(_gesture_packets(h["wire"], 2).size(), 0, "a standing player is not replayed again")
	# A pose still held is replayed on re-entry, as before.
	h["now"][0] += 10.0
	h["sl"].request(h["p3"], "LieDown", true, true, Vector3(0, 10, 0))
	n.remember_player_state(2, Vector3(NetworkingSlice.AOI_RADIUS * 3.0, 10, 0))
	wiring._replay_to_entrants()
	n.remember_player_state(2, Vector3(4, 10, 0))
	h["wire"].outbox.clear()
	wiring._replay_to_entrants()
	got = _gesture_packets(h["wire"], 2)
	assert_eq(got.size(), 1, "a held pose is replayed on re-entry")
	assert_eq(str(got[0]["g"]), "LieDown", "the pose itself")
	_free_host(h)


func _test_disconnect_forgets() -> void:
	var h := _host()
	var wiring = h["gr"]._gesture_wiring
	h["sl"].request(h["p3"], "SitGround", true, true, Vector3(0, 10, 0))
	wiring._replay_to_entrants()
	assert_true(wiring._told.has("2:3"), "the viewer was told peer 3's pose")
	assert_true(wiring._remote_poses.has(3), "and the listen host keeps the pose for its avatar of peer 3")
	wiring._forget_peer(3)
	assert_false(wiring._remote_poses.has(3), "a disconnect forgets the avatar's pose")
	assert_false(wiring._told.has("2:3"), "and every pair naming the peer")
	assert_false(wiring._entered.has("2:3"), "in both tables")
	_free_host(h)


func _test_gesture_refusal_notice() -> void:
	var h := _host()
	var lines: Array = []
	var on_msg := func(key: String, _args: Array, target: String) -> void: lines.append([key, target])
	GameBus.system_message.connect(on_msg)
	GameBus.gesture_intent.emit("Dance", h["p3"])
	GameBus.gesture_intent.emit("Dance", h["p3"])
	GameBus.system_message.disconnect(on_msg)
	assert_eq(lines.size(), 1, "a refused gesture gets one notice, then a second's quiet")
	assert_eq(lines[0], ["hud.gesture.refused.unknown", h["p3"]], "keyed, to the player who asked")
	for why in [GestureSlice.REFUSE_UNKNOWN, GestureSlice.REFUSE_DEAD, GestureSlice.REFUSE_AIRBORNE, GestureSlice.REFUSE_RATE]:
		assert_true(I18nScript.has_key("hud.gesture.refused." + why), "%s has a catalog line" % why)
	_free_host(h)


func _test_remote_rest_heal() -> void:
	var h := _host()
	var reg: PlayerRegistry = h["reg"]
	var ceiling := reg.max_hp_of(h["p3"])
	reg.record_simulated_hp(h["p3"], ceiling * 0.5)
	h["wire"].outbox.clear()
	h["gr"]._gesture_wiring._regen(h["p3"], 5.0)
	var heals: Array = h["wire"].outbox.filter(func(o): return str(o["payload"].get("type", "")) == "player_healed")
	assert_eq(heals.size(), 1, "the resting peer's client is sent the heal")
	assert_eq(int(heals[0]["peer_id"]), 3, "only that peer")
	assert_true(absf(float(heals[0]["payload"]["amount"]) - 5.0) < 0.001, "the amount the host applied")
	_free_host(h)
	# The client side: a sane amount is applied to the own body, anything else is dropped.
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.CLIENT
	var got: Array = []
	var on_heal := func(a: float) -> void: got.append(a)
	GameBus.player_rest_healed.connect(on_heal)
	n._route_h2c({ "type": "player_healed", "amount": 5.0 })
	n._route_h2c({ "type": "player_healed", "amount": -3.0 })
	n._route_h2c({ "type": "player_healed", "amount": INF })
	n._route_h2c({ "type": "player_healed", "amount": 1.0e9 })
	GameBus.player_rest_healed.disconnect(on_heal)
	assert_eq(got, [5.0, 1000.0], "a heal is positive, finite and bounded")
	n.free()


func _test_oneshot_ends_airborne() -> void:
	var loco := Locomotion.new()
	loco.trigger_gesture("wave", false, 0.5)
	loco.update(0.0, true, 0.0, 0.2)
	assert_true(loco.is_gesturing(), "the wave plays")
	loco.update(0.0, false, 3.0, 0.4)   # the clip runs out while the body rises (not falling)
	assert_false(loco.is_gesturing(), "an expired one-shot leaves the gesture state in the air")


func _test_loaded_name_taken() -> void:
	var reg := PlayerRegistry.new()
	reg.is_authoritative = true
	var holder := reg.mint_player_id()
	reg.ensure_player(holder)
	assert_eq(reg.create_character(holder, VALID, 1000), "", "the holder creates Akira")
	var thief := reg.mint_player_id()
	reg.ensure_player(thief)
	var forged := reg.get_player_data(holder).duplicate(true)
	forged["player_id"] = thief
	reg.apply_player_data(thief, forged)
	assert_eq(str(reg._taken.get(CreationRules.skeleton("Akira"), "")), holder, "the hand-edited record does not take the skeleton")
	var round := PlayerRegistry.new()
	round.is_authoritative = true
	round.apply_player_data(holder, reg.get_player_data(holder))
	assert_eq(str(round._taken.get(CreationRules.skeleton("Akira"), "")), holder, "the holder's own record reloads its name")
	round.free()
	reg.free()


func _test_kit_overflow_drops() -> void:
	var reg := PlayerRegistry.new()
	reg.is_authoritative = true
	var pid := reg.mint_player_id()
	reg.ensure_player(pid)
	var inv: Node = reg.get_inventory(pid)
	inv._max_slots = 0   # a bag with no room: nothing the kit holds fits
	inv._max_weight = 0.0
	var dropped: Array = []
	reg.set_ground_dropper(func(p: String, item: String, qty: int) -> void: dropped.append([p, item, qty]))
	var was_quiet := Diag.quiet
	Diag.quiet = true
	assert_eq(reg.create_character(pid, VALID, 1000), "", "the character is created with a full bag")
	Diag.quiet = was_quiet
	assert_false(dropped.is_empty(), "the kit items that do not fit are handed to the ground")
	assert_eq(str(dropped[0][0]), pid, "at that player's feet")
	# The game's dropper: a pickup on the ground at a remote player's reported position.
	var gr: Node = (load("res://src/core/game_root.gd") as GDScript).new()
	gr._registry = reg
	var loot := LootSlice.new()
	add_child(loot)
	gr._loot = loot
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	gr._networking = n
	var remote := reg.resolve_identity(5, "")
	n.remember_player_state(5, Vector3(12, 30, -4))
	gr._persistence_wiring.root = gr
	Diag.quiet = true
	gr._persistence_wiring._drop_at_feet(remote, str(dropped[0][1]), int(dropped[0][2]))
	Diag.quiet = was_quiet
	assert_eq(loot.get_pickups_near(Vector3(12, 30, -4), 2.0).size(), 1, "the item lands on the ground at the player's feet")
	loot.free()
	n.free()
	gr.free()
	reg.free()


func _test_minimap_boot_seed() -> void:
	var dir := "user://test_p196_boot_seed"
	var terrain := TerrainSlice.new()
	var boot_seed := terrain.get_world_seed()
	var boot_path: String = _RevealedStore.path_for(dir, boot_seed)
	DirAccess.remove_absolute(boot_path)
	var m := Minimap.new()
	m.terrain_slice = terrain
	m.revealed_dir = dir
	m.set_player_pos(Vector2(40.0, 40.0))
	m._tick_revealed_store(0.0)
	m._tick_revealed_store(Minimap.SEED_SETTLE_SECONDS)
	m.set_player_pos(Vector2(440.0, 40.0))
	m._tick_revealed_store(_RevealedStore.DEBOUNCE_SECONDS + 1.0)
	m.finish_save()
	assert_false(FileAccess.file_exists(boot_path), "the boot seed's set is not saved while it is a throwaway")
	terrain.set_world_seed(boot_seed + 77)   # the host's snapshot names the real world
	m._tick_revealed_store(0.0)
	m._tick_revealed_store(Minimap.SEED_SETTLE_SECONDS)
	m.finish_save()
	assert_false(FileAccess.file_exists(boot_path), "nor written when the real seed replaces it")
	m.set_player_pos(Vector2(840.0, 40.0))
	m._tick_revealed_store(_RevealedStore.DEBOUNCE_SECONDS + 1.0)
	m.finish_save()
	var real_path: String = _RevealedStore.path_for(dir, boot_seed + 77)
	assert_true(FileAccess.file_exists(real_path), "the adopted seed's set is saved as before")
	m.free()
	terrain.free()
	DirAccess.remove_absolute(real_path)


func _test_catalog() -> void:
	for key in ["reason.no_placement_item", "controls.gesture_key.rebind", "controls.gesture_key.waiting", "hud.gesture.refused.unknown",
			"hud.gesture.refused.dead", "hud.gesture.refused.airborne", "hud.gesture.refused.rate"]:
		assert_true(I18nScript.has_key(key), "%s is in the catalog" % key)
	assert_true(I18nScript.t("win.gestures", ["J"]).contains("J"), "the window title names the bound key")
