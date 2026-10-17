extends "res://src/tests/test_support.gd"
## Phase 140 — settlements at runtime: founding, claims, edits, the stockpile, decay and persistence.

const SettlementSlice := preload("res://src/settlement/settlement_slice.gd")

func register() -> void:
	_run_test("settlement: founding needs a Hearth and free land", _test_settlement_found)
	_run_test("settlement: claims never overlap", _test_settlement_no_overlap)
	_run_test("settlement: an outsider's mine and place are refused", _test_settlement_edit_guard)
	_run_test("settlement: stockpile keeps totals and role limits", _test_settlement_stockpile)
	_run_test("settlement: invite, join, roles and leaving", _test_settlement_membership)
	_run_test("settlement: tiers grow, an abandoned claim decays on the fabric schedule", _test_settlement_decay)
	_run_test("settlement: save and load round-trips, malformed data is dropped", _test_settlement_persistence)
	_run_test("settlement: intents resolve through the bus and refuse the unknown", _test_settlement_intents)
	_run_test("settlement: research draws from the stockpile", _test_settlement_research)
	_run_test("settlement: a client intent binds the connection's player", _test_settlement_wire)
	_run_test("settlement: claims count toward colonization", _test_settlement_colonization)
	_run_test("settlement: edit_blocker is a pure preview, activity is noted after a success", _test_settlement_preview_pure)
	_run_test("settlement: hearth placement needs and consumes its item", _test_settlement_hearth_item)
	_run_test("settlement: far from the origin the hearth keeps its exact position", _test_settlement_exact_far)
	_run_test("settlement: a decaying claim announces its shrinking radius", _test_settlement_decay_push)
	_run_test("settlement: from_data keeps ids unique and defaults last_active to now", _test_settlement_load_ids)

func _rig() -> Dictionary:
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("host")
	for p in ["p1", "p2", "p3"]:
		reg.ensure_player(p)
	var s := SettlementSlice.new()
	s.registry = reg
	add_child(s)
	var now := [1000000.0]
	s.now_sec = func() -> float: return now[0]
	var where := { "p1": Vector2(10.0, 10.0), "p2": Vector2(12.0, 10.0), "p3": Vector2(900.0, 900.0) }
	s.position_of = func(pid: String) -> Variant: return where.get(pid, null)
	return { "reg": reg, "s": s, "now": now, "where": where }

func _free_rig(rig: Dictionary) -> void:
	rig["s"].free()
	rig["reg"].free()

func _give(rig: Dictionary, pid: String, item: String, n: int) -> void:
	assert_true(rig["reg"].get_inventory(pid).add_item(item, n), "%s gets %d %s" % [pid, n, item])

func _found(rig: Dictionary) -> String:
	_give(rig, "p1", "Hearth", 1)
	var s: SettlementSlice = rig["s"]
	assert_eq(s.found("p1", "Oak", Vector2(10.0, 10.0)), "", "p1 founds")
	return "settlement_1"

func _test_settlement_found() -> void:
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	assert_eq(s.found("p1", "Oak", Vector2(10.0, 10.0)), "no_hearth", "no Hearth item: refused")
	assert_eq(s.count(), 0, "nothing was founded")
	_give(rig, "p1", "Hearth", 1)
	assert_eq(s.found("p1", "  ", Vector2(10.0, 10.0)), "bad_args", "a blank name is refused before the item is spent")
	assert_eq(rig["reg"].get_inventory("p1").get_item_count("Hearth"), 1, "the refused founding kept the Hearth")
	assert_eq(s.found("p1", "Oak", Vector2(10.0, 10.0)), "", "a Hearth on free land founds")
	assert_eq(rig["reg"].get_inventory("p1").get_item_count("Hearth"), 0, "the Hearth was consumed")
	assert_eq(s.role_of("p1", "settlement_1"), "founder", "the founder is a member")
	assert_eq(s.get_settlement("settlement_1")["status"], "founded", "a new settlement is founded-tier")
	assert_eq(s.claim_radius("settlement_1"), 24.0, "the founded radius comes from the fabric")
	_give(rig, "p1", "Hearth", 1)
	assert_eq(s.found("p1", "Two", Vector2(5000.0, 0.0)), "already_member", "one settlement per player")
	_free_rig(rig)

func _test_settlement_no_overlap() -> void:
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	_found(rig)
	var sep: float = float(s.rules()["minSeparation"])
	_give(rig, "p2", "Hearth", 1)
	assert_eq(s.found("p2", "Near", Vector2(10.0 + sep - 1.0, 10.0)), "too_close", "a hearth inside the separation is refused")
	assert_eq(rig["reg"].get_inventory("p2").get_item_count("Hearth"), 1, "the refused hearth is kept")
	assert_eq(s.found("p2", "Far", Vector2(10.0 + sep, 10.0)), "", "a hearth at the separation is fine")
	var top: float = float(s.rules()["tiers"]["town"]["claimRadius"])
	assert_true(sep > 2.0 * top, "even two top-tier claims cannot overlap")
	assert_eq(s.claim_at(Vector2(10.0 + sep, 10.0)), "settlement_2", "claim_at names the covering claim")
	_free_rig(rig)

func _test_settlement_edit_guard() -> void:
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	_found(rig)
	assert_eq(s.edit_blocker("p1", Vector2(20.0, 10.0)), "", "the founder builds inside the claim")
	assert_eq(s.edit_blocker("p2", Vector2(20.0, 10.0)), "no_permission", "an outsider is refused inside the claim")
	assert_eq(s.edit_blocker("p2", Vector2(500.0, 500.0)), "", "free land is free")
	# The same guard on the voxel slice: an outsider's mine and place change nothing and spend nothing.
	var v := _make_voxel()
	v.is_authoritative = true
	v.player_registry = rig["reg"]
	v.claim_guard = Callable(s, "edit_blocker")
	_give(rig, "p2", "Ferrite", 3)
	var mined := v.mine_block(Vector3(10.5, 2.0, 10.5), Vector3.UP, "p2")
	assert_false(bool(mined["success"]), "an outsider's mine inside the claim is refused")
	assert_false(v.place_block(Vector3(10.5, 2.0, 10.5), Vector3.UP, "Ferrite", "p2"), "an outsider's place inside the claim is refused")
	assert_eq(rig["reg"].get_inventory("p2").get_item_count("Ferrite"), 3, "a refused place spends nothing")
	var own := v.mine_block(Vector3(10.5, 2.0, 10.5), Vector3.UP, "p1")
	assert_true(bool(own["success"]), "the founder mines the same block")
	_give(rig, "p1", "Ferrite", 1)
	assert_true(v.place_block(Vector3(10.5, 2.0, 10.5), Vector3.UP, "Ferrite", "p1"), "the founder places inside the claim")
	var far := v.mine_block(Vector3(30.5, 2.0, 30.5), Vector3.UP, "p2")
	assert_true(bool(far["success"]), "the outsider mines outside the claim")
	# A station follows the same rule, and a hearth inside the separation is refused.
	var st := StationSlice.new()
	add_child(st)
	st.claim_guard = Callable(s, "edit_blocker")
	st.settlement_slice = s
	assert_true(st.placement_blocker("forge", Vector3(15.5, 2.0, 10.5), "p2") != "", "an outsider's station inside the claim is refused")
	assert_eq(st.placement_blocker("forge", Vector3(15.5, 2.0, 10.5), "p1"), "", "the founder's station is fine")
	assert_true(st.placement_blocker("hearth", Vector3(100.5, 2.0, 10.5), "p2") != "", "a hearth near a settlement is refused")
	assert_true(st.placement_blocker("hearth", Vector3(5000.5, 2.0, 10.5), "p1") != "", "a member's second hearth is refused, so its item is never lost")
	assert_eq(st.placement_item("hearth"), "Hearth", "placing a hearth costs a Hearth")
	assert_true(st.placeable_station_types().has("hearth"), "the hearth is a placeable station type")
	st.free()
	v.free()
	_free_rig(rig)

func _test_settlement_stockpile() -> void:
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	_found(rig)
	s.invite("p1", "p2")
	assert_eq(s.join("p2", "settlement_1"), "", "p2 joins")
	_give(rig, "p1", "AethermiteDust", 300)
	_give(rig, "p2", "AethermiteDust", 5)
	var inv1: Node = rig["reg"].get_inventory("p1")
	_give(rig, "p1", "FerritePick", 1)
	assert_eq(s.deposit("p1", "FerritePick", 1), "durable", "a worn tool is not stored (it would come back new)")
	assert_eq(inv1.get_item_count("FerritePick"), 1, "a refused deposit keeps the tool")
	assert_eq(s.deposit("p1", "AethermiteDust", 120), "", "a deposit lands")
	assert_eq(inv1.get_item_count("AethermiteDust"), 180, "the pack lost what the stockpile gained")
	assert_eq(s.stock_of("settlement_1")["AethermiteDust"], 120, "the stockpile holds it")
	assert_eq(s.deposit("p1", "AethermiteDust", 0), "bad_args", "a zero deposit is refused")
	assert_eq(s.deposit("p1", "Nonsense", 1), "bad_args", "an unknown item is refused")
	assert_eq(s.deposit("p1", "AethermiteDust", 2400), "no_stock", "a deposit beyond the pack is refused whole")
	assert_eq(s.stock_of("settlement_1")["AethermiteDust"], 120, "a refused deposit moves nothing")
	assert_eq(s.withdraw("p2", "AethermiteDust", 51), "over_limit", "a withdraw beyond the member's daily limit is refused")
	assert_eq(s.stock_of("settlement_1")["AethermiteDust"], 120, "a refused withdraw moves nothing")
	assert_eq(s.withdraw("p2", "AethermiteDust", 50), "", "a withdraw within the limit lands")
	assert_eq(s.withdraw("p2", "AethermiteDust", 1), "over_limit", "the limit is per day")
	rig["now"][0] += 86400.0 * 1.5
	s.note_activity("p1")
	assert_eq(s.withdraw("p2", "AethermiteDust", 20), "", "the next day the limit resets")
	assert_eq(rig["reg"].get_inventory("p2").get_item_count("AethermiteDust"), 75, "the member holds what was drawn")
	assert_eq(int(s.stock_of("settlement_1")["AethermiteDust"]) + 75 + inv1.get_item_count("AethermiteDust"), 305 + 0, "item totals are preserved")
	assert_eq(s.withdraw("p1", "AethermiteDust", 50), "", "the founder withdraws with no limit")
	# Capacity: stacks.
	var cap := s.capacity_stacks("settlement_1")
	assert_eq(cap, 20, "founded capacity comes from the fabric")
	_give(rig, "p1", "AethermiteDust", 2000)
	var held := int(s.stock_of("settlement_1").get("AethermiteDust", 0))
	assert_eq(s.deposit("p1", "AethermiteDust", 2000 - held), "", "a deposit up to capacity lands")
	assert_eq(s.deposit("p1", "AethermiteDust", held + 1), "full", "a deposit beyond capacity is refused whole")
	assert_true(s.used_stacks("settlement_1") <= cap, "the stockpile never exceeds its capacity")
	# Not in the claim.
	rig["where"]["p1"] = Vector2(900.0, 900.0)
	assert_eq(s.deposit("p1", "AethermiteDust", 1), "not_in_claim", "a deposit needs the claim")
	assert_eq(s.withdraw("p1", "AethermiteDust", 1), "not_in_claim", "a withdraw needs the claim")
	assert_eq(s.deposit("p3", "AethermiteDust", 1), "not_member", "an outsider cannot deposit")
	_free_rig(rig)

func _test_settlement_membership() -> void:
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	_found(rig)
	assert_eq(s.invite("p2", "p3"), "not_member", "a non-member cannot invite")
	assert_eq(s.join("p2", "settlement_1"), "not_invited", "no invite, no join")
	assert_eq(s.invite("p1", "p2"), "", "the founder invites")
	assert_eq(s.join("p2", "settlement_1"), "", "p2 accepts")
	assert_eq(s.role_of("p2", "settlement_1"), "member", "a joiner is a member")
	assert_eq(s.invite("p2", "p3"), "no_permission", "a member cannot invite")
	assert_eq(s.set_role("p2", "p1", "guest"), "no_permission", "a member cannot demote anyone")
	assert_eq(s.set_role("p1", "p1", "guest"), "founder_locked", "the founder's role is fixed")
	assert_eq(s.set_role("p1", "p2", "founder"), "bad_role", "nobody else becomes founder")
	assert_eq(s.set_role("p1", "p2", "elder"), "", "the founder makes an elder")
	assert_eq(s.invite("p1", "p3"), "", "p3 is invited")
	assert_eq(s.join("p3", "settlement_1"), "", "p3 joins")
	assert_eq(s.set_role("p2", "p3", "elder"), "no_permission", "an elder cannot make elders")
	assert_eq(s.set_role("p2", "p3", "guest"), "", "an elder makes a guest")
	assert_eq(s.edit_blocker("p3", Vector2(15.0, 10.0)), "no_permission", "a guest cannot build in the claim")
	assert_eq(s.withdraw("p3", "Ferrite", 1), "no_permission", "a guest cannot take")
	assert_eq(s.leave("p1"), "founder_locked", "the founder cannot leave")
	assert_eq(s.leave("p3"), "", "a member leaves")
	assert_eq(s.settlement_of("p3"), "", "and belongs nowhere")
	_free_rig(rig)

func _test_settlement_decay() -> void:
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	_found(rig)
	var day := 86400.0
	var t0: float = rig["now"][0]
	rig["now"][0] = t0 + day
	s.tick(rig["now"][0])
	s.invite("p1", "p2")
	s.join("p2", "settlement_1")
	s.invite("p1", "p3")
	s.join("p3", "settlement_1")
	rig["now"][0] = t0 + 4.0 * day
	s.note_activity("p1")
	s.tick(rig["now"][0])
	assert_eq(s.get_settlement("settlement_1")["status"], "growing", "three members and three days grow the settlement")
	assert_eq(s.claim_radius("settlement_1"), 48.0, "the claim grew with the tier")
	assert_eq(s.capacity_stacks("settlement_1"), 60, "so did the stockpile")
	s.leave("p3")
	s.tick(rig["now"][0])
	assert_eq(s.get_settlement("settlement_1")["status"], "growing", "a tier is never lost to a leaver")
	# Abandon: no activity for abandonAfterDays.
	var after: float = rig["now"][0] + float(s.rules()["abandonAfterDays"]) * day
	rig["now"][0] = after
	s.tick(after)
	assert_eq(s.get_settlement("settlement_1")["status"], "abandoned", "no activity for the fabric's days abandons it")
	assert_eq(s.claim_radius("settlement_1"), 48.0, "the claim starts decaying from its radius")
	rig["now"][0] = after + 5.0 * day
	assert_eq(s.claim_radius("settlement_1"), 48.0 - 5.0 * float(s.rules()["decayRadiusPerDay"]), "the claim shrinks by the fabric rate per day")
	assert_eq(s.edit_blocker("p3", Vector2(10.0 + 45.0, 10.0)), "", "decayed land is free to anyone")
	# Return before the claim is gone: reclaim.
	s.note_activity("p1")
	assert_eq(s.get_settlement("settlement_1")["status"], "founded", "a member's return reclaims it")
	# Abandon again and let it decay fully: the land is free and the settlement is gone.
	var again: float = rig["now"][0] + float(s.rules()["abandonAfterDays"]) * day
	rig["now"][0] = again
	s.tick(again)
	assert_eq(s.get_settlement("settlement_1")["status"], "abandoned", "abandoned again")
	rig["now"][0] = again + 100.0 * day
	assert_eq(s.claim_radius("settlement_1"), 0.0, "the claim decays to nothing")
	s.tick(rig["now"][0])
	assert_eq(s.count(), 0, "a fully decayed settlement frees its land")
	assert_eq(s.claim_at(Vector2(10.0, 10.0)), "", "no claim remains")
	_free_rig(rig)

func _test_settlement_persistence() -> void:
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	_found(rig)
	s.invite("p1", "p2")
	s.join("p2", "settlement_1")
	_give(rig, "p1", "AethermiteDust", 40)
	s.deposit("p1", "AethermiteDust", 40)
	var data: Variant = JSON.parse_string(JSON.stringify(s.to_data()))
	var rig2 := _rig()
	var s2: SettlementSlice = rig2["s"]
	s2.from_data(data)
	assert_eq(s2.count(), 1, "the settlement survives a save and load")
	assert_eq(s2.stock_of("settlement_1"), { "AethermiteDust": 40 }, "its stockpile too")
	assert_eq(s2.role_of("p2", "settlement_1"), "member", "and its roles")
	assert_eq(s2.claim_radius("settlement_1"), 24.0, "and its claim")
	assert_eq(s2.found("p3", "Next", Vector2(5000.0, 0.0), false), "", "ids continue after a load")
	assert_true(s2.ids().has("settlement_2"), "a new settlement does not reuse an id")
	s2.from_data({ "settlements": { "x": "junk", "y": { "members": {}, "hx": 1.0, "hz": 1.0 }, "z": { "members": { "a": "boss" }, "hx": INF, "hz": 0.0 } } })
	assert_eq(s2.count(), 0, "malformed entries are dropped")
	s2.from_data("nonsense")
	assert_eq(s2.count(), 0, "a non-dictionary record restores empty")
	s2.from_data({ "settlements": { "ok": { "members": { "a": "boss" }, "hx": 1.0, "hz": 2.0, "status": "weird", "stock": { "Nonsense": 5, "Ferrite": -3 } } } })
	assert_eq(s2.role_of("a", "ok"), "guest", "an unknown saved role falls to guest")
	assert_eq(s2.get_settlement("ok")["status"], "founded", "an unknown saved status falls to founded")
	assert_eq(s2.stock_of("ok"), {}, "unknown and negative stock is dropped")
	_free_rig(rig2)
	_free_rig(rig)

func _test_settlement_intents() -> void:
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	var seen: Array = []
	var cb := func(pid: String, action: String, ok: bool, reason: String) -> void: seen.append([pid, action, ok, reason])
	GameBus.settlement_resolved.connect(cb)
	GameBus.settlement_intent.emit("found", { "name": "Oak" }, "p1")
	assert_eq(seen.back(), ["p1", "found", false, "no_hearth"], "an intent without a Hearth is refused with its code")
	_give(rig, "p1", "Hearth", 1)
	rig["now"][0] += 1.0
	GameBus.settlement_intent.emit("found", { "name": "Oak" }, "p1")
	assert_eq(seen.back(), ["p1", "found", true, ""], "a Hearth founds through the bus")
	GameBus.settlement_intent.emit("invite", { "target": "p2" }, "p1")
	assert_eq(seen.back()[3], "rate_limited", "intents are rate limited per player")
	rig["now"][0] += 1.0
	GameBus.settlement_intent.emit("dance", {}, "p1")
	assert_eq(seen.back()[3], "unknown_action", "an unknown action is refused")
	rig["now"][0] += 1.0
	GameBus.settlement_intent.emit("deposit", { "item": "Ferrite", "qty": "lots" }, "p1")
	assert_eq(seen.back()[3], "bad_args", "a non-numeric quantity is refused")
	rig["now"][0] += 1.0
	GameBus.settlement_intent.emit("found", {}, "")
	assert_eq(seen.back()[0], "host", "an empty actor is the local player")
	s.is_host = false
	var n := seen.size()
	rig["now"][0] += 1.0
	GameBus.settlement_intent.emit("leave", {}, "p2")
	assert_eq(seen.size(), n, "a client slice resolves nothing")
	GameBus.settlement_resolved.disconnect(cb)
	_free_rig(rig)

func _test_settlement_research() -> void:
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	_found(rig)
	var tech := TechnologySlice.new()
	add_child(tech)
	tech.settlement_slice = s
	tech.is_authoritative = true
	var tid := "TechMasterForge"
	var materials: Array = GameData.TECHNOLOGIES[tid].get("tech").get("researchMaterials")
	var item := str(materials[0]["item"])
	var qty := int(materials[0]["quantity"])
	assert_true(GameData.TECHNOLOGIES[tid].get("tech").has("materialSource"), "the fabric names a stockpile material source")
	assert_eq(s.research_stock("p1", item), 0, "an empty stockpile holds nothing for research")
	_give(rig, "p1", item, qty)
	s.deposit("p1", item, qty)
	assert_eq(s.research_stock("p1", item), qty, "research sees the stockpile")
	assert_eq(s.research_stock("p3", item), 0, "an outsider sees nothing")
	rig["where"]["p1"] = Vector2(900.0, 900.0)
	assert_eq(s.research_stock("p1", item), 0, "research needs the claim")
	assert_false(s.consume_research("p1", { item: qty }), "and so does paying for it")
	rig["where"]["p1"] = Vector2(10.0, 10.0)
	assert_false(s.consume_research("p1", { item: qty + 1 }), "paying more than is held is refused whole")
	assert_eq(s.research_stock("p1", item), qty, "a refused payment keeps the stock")
	assert_true(s.consume_research("p1", { item: qty }), "a covered payment is taken")
	assert_eq(s.research_stock("p1", item), 0, "from the stockpile")
	tech.free()
	_free_rig(rig)

func _test_settlement_wire() -> void:
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.set_transport(MemoryTransport.new([9]))
	var seen: Array = []
	var cb := func(action: String, args: Dictionary, pid: String) -> void: seen.append([action, args, pid])
	GameBus.settlement_intent.connect(cb)
	n._route_c2h(9, { "type": "settlement_intent", "action": "found", "args": { "name": "X" }, "player_id": "p2" })
	assert_eq(seen.size(), 0, "an un-handshaked peer's intent is dropped")
	GameBus.settlement_intent.disconnect(cb)
	n.free()
	# Client side: the intent is forwarded, not resolved.
	var c := NetworkingSlice.new()
	add_child(c)
	c._role = NetworkingSlice.Role.CLIENT
	c.set_transport(MemoryTransport.new([1]))
	assert_true(c.has_method("_on_settlement_intent"), "the networking slice forwards settlement intents")
	c._on_settlement_intent("leave", {}, "")
	c.free()

func _test_settlement_colonization() -> void:
	var map := ColonizationMapScript.new()
	assert_eq(map.score(Vector2i(0, 0)), 0.0, "an empty map scores zero")
	map.set_settlements([Vector2i(1, 1), Vector2i(2, 2)])
	assert_eq(map.score(Vector2i(0, 0)), 2.0 * ColonizationMapScript.SETTLEMENT_WEIGHT, "each settlement counts in its region")
	assert_true(map.colonized_regions(ColonizationMapScript.SETTLEMENT_WEIGHT).has(Vector2i(0, 0)), "a settled region is colonized")
	assert_true(map.is_near_colonized(10.0, 10.0, 10.0, ColonizationMapScript.SETTLEMENT_WEIGHT), "new players keep away from it")
	map.set_settlements([])
	assert_eq(map.score(Vector2i(0, 0)), 0.0, "the count is replaced, not accumulated")
	assert_eq(map.to_data()["regions"].size(), 0, "settlements are not persisted on the map")

func _test_settlement_preview_pure() -> void:
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	var now: Array = rig["now"]
	_found(rig)
	var before: Dictionary = s.to_data().duplicate(true)
	now[0] += 5000.0
	assert_eq(s.edit_blocker("p1", Vector2(20.0, 10.0)), "", "the founder may edit")
	assert_eq(s.edit_blocker("p2", Vector2(20.0, 10.0)), "no_permission", "an outsider may not")
	assert_eq(s.to_data(), before, "previews leave last_active and claim state unchanged")
	# A successful edit through the voxel slice notes activity; a refused one does not.
	var v := _make_voxel()
	v.is_authoritative = true
	v.player_registry = rig["reg"]
	v.claim_guard = Callable(s, "edit_blocker")
	v.claim_touch = Callable(s, "note_edit")
	var last := float(s.to_data()["settlements"]["settlement_1"]["last_active"])
	assert_false(bool(v.mine_block(Vector3(10.5, 2.0, 10.5), Vector3.UP, "p2")["success"]), "outsider refused")
	assert_eq(float(s.to_data()["settlements"]["settlement_1"]["last_active"]), last, "a refused edit is not activity")
	assert_true(bool(v.mine_block(Vector3(10.5, 2.0, 10.5), Vector3.UP, "p1")["success"]), "founder mines")
	assert_eq(float(s.to_data()["settlements"]["settlement_1"]["last_active"]), now[0], "a successful edit is activity")
	v.free()
	_free_rig(rig)

func _test_settlement_hearth_item() -> void:
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	var st := StationSlice.new()
	add_child(st)
	st.settlement_slice = s
	var inv: Node = rig["reg"].get_inventory("p1")
	assert_eq(st.try_place_station("hearth", Vector3(10.5, 2.0, 10.5), inv, "p1"), "", "no Hearth item: refused")
	_give(rig, "p1", "Hearth", 1)
	assert_true(st.try_place_station("hearth", Vector3(10.5, 2.0, 10.5), inv, "p1") != "", "with the item the hearth is placed")
	assert_eq(inv.get_item_count("Hearth"), 0, "and one item is removed")
	st.free()
	_free_rig(rig)

func _test_settlement_load_ids() -> void:
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	s.from_data({ "next_id": 1, "settlements": { "settlement_7": { "members": { "p1": "founder" }, "hx": 1.0, "hz": 2.0 } } })
	assert_eq(float(s.to_data()["settlements"]["settlement_7"]["last_active"]), rig["now"][0], "a missing last_active is now")
	assert_eq(int(s.to_data()["next_id"]), 8, "next_id stays above every loaded id")
	_free_rig(rig)

func _test_settlement_exact_far() -> void:
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	_give(rig, "p1", "Hearth", 1)
	var ex := { "chunk": Vector2i(625000, -3), "local": Vector3(12.34, 5.0, 7.89) }
	assert_eq(s.found("p1", "Far", Vector2(2.0e7, -96.0), true, ex), "", "founded far from the origin")
	var back := SettlementSlice.new()
	back.registry = rig["reg"]
	add_child(back)
	back.now_sec = rig["s"].now_sec
	back.from_data(JSON.parse_string(JSON.stringify(s.to_data())))
	var got: Dictionary = back.exact_pos("settlement_1")
	assert_false(got.is_empty(), "the exact record survives save and load")
	assert_eq(got["chunk"], ex["chunk"], "same chunk")
	assert_true((got["local"] as Vector3).distance_to(ex["local"]) < 0.01, "within 1 cm")
	back.free()
	_free_rig(rig)

func _test_settlement_decay_push() -> void:
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	var now: Array = rig["now"]
	_found(rig)
	now[0] += float(s.rules()["abandonAfterDays"]) * SettlementSlice.DAY_SEC + 1.0
	assert_true(s.tick(now[0]), "the claim is abandoned")
	assert_false(s.tick(now[0]), "an unchanged radius is not re-announced")
	now[0] += SettlementSlice.DAY_SEC
	assert_true(s.tick(now[0]), "a day of decay changes the radius and is announced")
	_free_rig(rig)
