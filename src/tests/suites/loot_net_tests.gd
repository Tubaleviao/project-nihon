extends "res://src/tests/test_support.gd"
## Ground pickups across the wire. Before this a pickup lived only on the host: a client never saw one (its
## harvest overflow included) and could neither take nor drop anything. On the host, every peer's bag the
## registry holds also answered the local player's pickup and drop requests.

const GameRoot := preload("res://src/core/game_root.gd")
const LootWiring := preload("res://src/loot/loot_wiring.gd")

const ITEM := "Thornwood"

func register() -> void:
	_run_test("loot net: only the local player's bag answers its own pickup and drop", _test_local_bag_only)
	_run_test("loot net: a client forwards its pickup and drop and changes nothing itself", _test_client_forwards)
	_run_test("loot net: a client's loot slice keeps the host's pickups as views", _test_client_views)
	_run_test("loot net: the host binds pickup and drop intents to the connection", _test_host_binds)
	_run_test("loot net: the host gives a peer a pickup in reach and refuses the rest", _test_host_pickup)
	_run_test("loot net: the host drops from a peer's bag at its reported feet", _test_host_drop)
	_run_test("loot net: a client hears its pickup taken or its bag full", _test_client_pickup_result)

func _bag(owner: String, loot: Node) -> InventorySlice:
	var inv := InventorySlice.new()
	inv.owner_id = owner
	add_child(inv)
	inv.loot_slice = loot
	return inv

func _test_local_bag_only() -> void:
	var loot := LootSlice.new()
	add_child(loot)
	var mine := _bag("", loot)
	var peers := _bag("p5", loot)
	var pid: String = loot.spawn_pickup(ITEM, 2, Vector3(1.0, 0.0, 1.0))
	GameBus.pickup_requested.emit(pid)
	assert_eq(mine.get_item_count(ITEM), 2, "the local player's bag takes the pickup")
	assert_eq(peers.get_item_count(ITEM), 0, "a peer's bag held here does not")
	peers.add_item(ITEM, 3)
	GameBus.item_drop_requested.emit(ITEM, 1, Vector3.ZERO)
	assert_eq(mine.get_item_count(ITEM), 1, "the local drop comes off the local bag")
	assert_eq(peers.get_item_count(ITEM), 3, "and never off a peer's")
	mine.free()
	peers.free()
	loot.free()

func _test_client_forwards() -> void:
	var loot := LootSlice.new()
	add_child(loot)
	loot.is_authoritative = false
	var inv := _bag("", loot)
	inv.is_authoritative = false
	inv.add_item(ITEM, 2)
	loot.apply_view({ "id": "pickup_7", "item_id": ITEM, "quantity": 1, "position": Vector3.ZERO })
	var picks: Array = []
	var drops: Array = []
	var on_pick := func(id: String, who: String) -> void: picks.append([id, who])
	var on_drop := func(item: String, qty: int, at: Vector3, who: String) -> void: drops.append([item, qty, at, who])
	GameBus.pickup_intent.connect(on_pick)
	GameBus.drop_intent.connect(on_drop)
	GameBus.pickup_requested.emit("pickup_7")
	GameBus.item_drop_requested.emit(ITEM, 1, Vector3(4.0, 0.0, 1.0))
	GameBus.pickup_intent.disconnect(on_pick)
	GameBus.drop_intent.disconnect(on_drop)
	assert_eq(picks, [["pickup_7", ""]], "the pickup goes to the host, unnamed")
	assert_eq(drops, [[ITEM, 1, Vector3(4.0, 0.0, 1.0), ""]], "and so does the drop, with the point the UI chose")
	assert_eq(inv.get_item_count(ITEM), 2, "the bag changes only when the host syncs it")
	assert_false(loot.get_pickup("pickup_7").is_empty(), "and the pickup stays until the host withdraws it")
	inv.free()
	loot.free()

func _test_client_views() -> void:
	var loot := LootSlice.new()
	add_child(loot)
	loot.is_authoritative = false
	var removed: Array = []
	var on_removed := func(id: String) -> void: removed.append(id)
	GameBus.loot_removed.connect(on_removed)
	loot.apply_view({ "id": "pickup_3", "item_id": ITEM, "quantity": 4, "position": Vector3(2.0, 1.0, 2.0) })
	loot.apply_view({ "id": "pickup_3", "item_id": ITEM, "quantity": 3, "position": Vector3(2.0, 1.0, 2.0) })
	assert_eq(loot.ids(), ["pickup_3"], "one view per host pickup")
	assert_eq(int(loot.get_pickup("pickup_3")["quantity"]), 3, "updated in place")
	loot.remove_view("pickup_3")
	assert_true(loot.ids().is_empty(), "and withdrawn")
	loot.is_authoritative = true
	var pid: String = loot.spawn_pickup(ITEM, 1, Vector3.ZERO)
	loot.consume_pickup(pid)
	GameBus.loot_removed.disconnect(on_removed)
	assert_eq(removed, [pid], "only the host announces a taken pickup")
	loot.free()

func _test_host_binds() -> void:
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n._player_ids[5] = "p5"
	var picks: Array = []
	var drops: Array = []
	var on_pick := func(id: String, who: String) -> void: picks.append([id, who])
	var on_drop := func(item: String, qty: int, at: Vector3, who: String) -> void: drops.append([item, qty, at, who])
	GameBus.pickup_intent.connect(on_pick)
	GameBus.drop_intent.connect(on_drop)
	n._route_c2h(5, { "type": "pickup_intent", "id": "pickup_1", "player_id": "victim" })
	n._route_c2h(5, { "type": "drop_intent", "id": ITEM, "qty": 3 })
	n._route_c2h(5, { "type": "drop_intent", "id": ITEM, "qty": 2, "off": [1.0, 0.0, -1.0] })
	n._route_c2h(5, { "type": "drop_intent", "id": ITEM, "qty": 1, "off": [INF, 0.0, 0.0] })
	n._route_c2h(5, { "type": "drop_intent", "id": ITEM, "qty": "lots" })
	n._route_c2h(5, { "type": "pickup_intent", "id": 9 })
	var was_quiet := Diag.quiet
	Diag.quiet = true
	n._route_c2h(6, { "type": "pickup_intent", "id": "pickup_1" })
	Diag.quiet = was_quiet
	GameBus.pickup_intent.disconnect(on_pick)
	GameBus.drop_intent.disconnect(on_drop)
	assert_eq(picks, [["pickup_1", "p5"]], "a pickup is the connection's player's, never the payload's name")
	assert_eq(drops, [[ITEM, 3, Vector3.ZERO, "p5"], [ITEM, 2, Vector3(1.0, 0.0, -1.0), "p5"], [ITEM, 1, Vector3.ZERO, "p5"]],
		"and so is a drop, its offset finite or none; malformed ones and un-handshaked peers are dropped")
	n.free()

## A host root: registry (p5 on peer 5, last seen at the origin), networking, a loot slice and the wiring.
func _host_rig() -> Dictionary:
	var root: GameRoot = GameRoot.new()
	root._is_client = false
	var reg := PlayerRegistry.new()
	reg.is_authoritative = true
	add_child(reg)
	reg.set_local_player("host")
	reg.ensure_player("p5")
	reg._peer_ids[5] = "p5"
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.remember_player_state(5, Vector3(0.0, 1.0, 0.0))
	var loot := LootSlice.new()
	add_child(loot)
	root._registry = reg
	root._networking = n
	root._loot = loot
	root._peer_wiring.root = root
	var w: LootWiring = root._loot_wiring
	w.root = root
	return { "root": root, "reg": reg, "n": n, "loot": loot, "w": w }

func _free_host_rig(r: Dictionary) -> void:
	r["loot"].free()
	r["n"].free()
	r["reg"].free()
	r["root"].free()

func _test_host_pickup() -> void:
	var r := _host_rig()
	var loot: Node = r["loot"]
	var w: LootWiring = r["w"]
	var bag: Node = r["reg"].get_inventory("p5")
	var near: String = loot.spawn_pickup(ITEM, 2, Vector3(3.0, 1.0, 0.0))
	var far: String = loot.spawn_pickup(ITEM, 2, Vector3(PlayerSlice.PICKUP_RANGE + LootWiring.PICKUP_REACH_SLACK_M + 5.0, 1.0, 0.0))
	assert_false(w.on_pickup_intent(far, "p5"), "a pickup out of reach of the host's record is refused")
	assert_false(w.on_pickup_intent(near, "p6"), "a player with no connection is refused")
	assert_false(w.on_pickup_intent(near, "host"), "the local player's id is not a peer's intent")
	assert_false(w.on_pickup_intent("pickup_404", "p5"), "an unknown pickup is refused")
	r["reg"].record_simulated_hp("p5", 0.0)
	assert_false(w.on_pickup_intent(near, "p5"), "a downed player cannot take")
	r["reg"].record_simulated_hp("p5", r["reg"].max_hp_of("p5"))
	var wire := MemoryTransport.new([5])
	r["n"].set_transport(wire)
	bag._max_slots = 0
	assert_false(w.on_pickup_intent(near, "p5"), "a full bag takes nothing")
	assert_false(loot.get_pickup(near).is_empty(), "and the pickup stays on the ground")
	assert_eq(_results(wire), [{ "ok": false, "reason": "inventory_full" }], "the peer is told its bag is full")
	bag._max_slots = 30
	assert_false(w.on_pickup_intent(near, "p5"), "a pickup inside the minimum gap is refused")
	w._last_pickup_ms.clear()
	wire.outbox.clear()
	assert_true(w.on_pickup_intent(near, "p5"), "a pickup in reach is taken")
	assert_eq(_results(wire), [{ "ok": true, "item": ITEM, "qty": 2 }], "the peer is told what it took")
	w._on_peer_disconnected(5)
	assert_false(w._last_pickup_ms.has(5), "a departed peer's clocks are dropped")
	assert_eq(bag.get_item_count(ITEM), 2, "into the peer's bag as the host holds it")
	assert_true(loot.get_pickup(near).is_empty(), "and leaves the ground")
	assert_false(w.on_pickup_intent(near, "p5"), "a second take of it finds nothing")
	r["root"]._is_client = true
	assert_false(w.on_pickup_intent(far, "p5"), "a client never resolves a pickup")
	r["root"]._is_client = false
	_free_host_rig(r)

func _test_host_drop() -> void:
	var r := _host_rig()
	var loot: Node = r["loot"]
	var w: LootWiring = r["w"]
	var bag: Node = r["reg"].get_inventory("p5")
	bag.add_item(ITEM, 3)
	assert_false(w.on_drop_intent("NoSuchItem", 1, Vector3.ZERO, "p5"), "nothing held, nothing dropped")
	assert_false(w.on_drop_intent(ITEM, 0, Vector3.ZERO, "p5"), "a zero drop is refused")
	assert_true(w.on_drop_intent(ITEM, 5, Vector3.ZERO, "p5"), "a drop of more than is held drops what is held")
	assert_eq(bag.get_item_count(ITEM), 0, "off the peer's bag")
	assert_eq(loot.ids().size(), 1, "onto one pickup")
	var p: Dictionary = loot.get_pickup(str(loot.ids()[0]))
	assert_eq(int(p["quantity"]), 3, "of the held amount")
	assert_true((p["position"] as Vector3).distance_to(Vector3(0.0, 1.0, 0.0)) < 0.01, "at the host's record of the peer")
	assert_false(w.on_drop_intent(ITEM, 1, Vector3.ZERO, "p6"), "a player with no connection is refused")
	bag.add_item(ITEM, 2)
	assert_false(w.on_drop_intent(ITEM, 1, Vector3(1.0, 0.0, 0.0), "p5"), "a drop inside the minimum gap is refused")
	assert_eq(bag.get_item_count(ITEM), 2, "and takes nothing")
	w._last_drop_ms.clear()
	assert_true(w.on_drop_intent(ITEM, 1, Vector3(1.0, 0.0, 0.0), "p5"), "a drop at a chosen point")
	w._last_drop_ms.clear()
	assert_true(w.on_drop_intent(ITEM, 1, Vector3(100.0, 0.0, 0.0), "p5"), "a drop asked for far away")
	var landed: Array = []
	for id in loot.ids():
		landed.append(snappedf((loot.get_pickup(str(id))["position"] as Vector3).x, 0.01))
	landed.sort()
	assert_eq(landed, [0.0, 1.0, LootWiring.DROP_MAX_OFFSET_M], "lands at the offset from the host's record, clamped")
	_free_host_rig(r)

## The `pickup_result` packets in `wire`'s outbox, without their seq.
func _results(wire) -> Array:
	var out: Array = []
	for o in wire.outbox:
		var pl: Dictionary = (o["payload"] as Dictionary).duplicate()
		if str(pl.get("type", "")) == "pickup_result":
			pl.erase("type")
			pl.erase("seq")
			out.append(pl)
	return out

func _test_client_pickup_result() -> void:
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.CLIENT
	var picked: Array = []
	var full := { "n": 0 }
	var on_picked := func(item: String, qty: int) -> void: picked.append([item, qty])
	var on_full := func() -> void: full["n"] = int(full["n"]) + 1
	GameBus.item_picked_up.connect(on_picked)
	GameBus.inventory_full.connect(on_full)
	n._route_h2c({ "type": "pickup_result", "ok": true, "item": ITEM, "qty": 2 })
	n._route_h2c({ "type": "pickup_result", "ok": true, "item": "NoSuchItem", "qty": 2 })
	n._route_h2c({ "type": "pickup_result", "ok": true, "item": ITEM, "qty": -1 })
	n._route_h2c({ "type": "pickup_result", "ok": false, "reason": "inventory_full" })
	n._route_h2c({ "type": "pickup_result", "ok": false, "reason": "out_of_reach" })
	n._role = NetworkingSlice.Role.HOST
	n._route_h2c({ "type": "pickup_result", "ok": true, "item": ITEM, "qty": 1 })
	GameBus.item_picked_up.disconnect(on_picked)
	GameBus.inventory_full.disconnect(on_full)
	assert_eq(picked, [[ITEM, 2]], "a known item taken is the pickup sound and toast; anything else is dropped")
	assert_eq(int(full["n"]), 1, "a full bag is the full-bag notice")
	n.free()
