extends "res://src/tests/test_support.gd"
## Phase 140 — settlements at runtime: members, the stockpile and persistence. Phase 205 removed the claim, the
## hearth and decay (structures own what is built: structure_tests.gd).

const SettlementSlice := preload("res://src/settlement/settlement_slice.gd")

func register() -> void:
	_run_test("settlement: founding takes no Hearth and claims no land", _test_settlement_found)
	_run_test("settlement: tiers grow and nothing decays", _test_settlement_tiers_no_decay)
	_run_test("settlement: a saved hearth is removed and handed back to its founder", _test_hearth_returned)
	_run_test("settlement: stockpile keeps totals and role limits", _test_settlement_stockpile)
	_run_test("settlement: invite, join, roles and leaving", _test_settlement_membership)
	_run_test("settlement: save and load round-trips, malformed data is dropped", _test_settlement_persistence)
	_run_test("settlement: intents resolve through the bus and refuse the unknown", _test_settlement_intents)
	_run_test("settlement: research draws from the stockpile", _test_settlement_research)
	_run_test("settlement: a client intent binds the connection's player", _test_settlement_wire)
	_run_test("settlement: a hearth at x ~ 2e7 keeps its exact position through save and load", _test_phase147_hearth_exact)
	_run_test("settlement: invites lapse and can be withdrawn", _test_invite_lapse_uninvite)
	_run_test("settlement: the rate limit is monotonic and forgets a player who left", _test_rate_limit_monotonic)
	_run_test("settlement: the panel keeps its Join buttons while the invites are unchanged", _test_panel_invites_kept)
	_run_test("settlement: loading keeps ids unique and defaults last_active to now", _test_phase147_from_data)
	_run_test("settlement: claims count toward colonization", _test_settlement_colonization)
	_run_test("settlement: a default name is a number the client renders, from a monotonic counter", _test_phase148_default_name)
	_run_test("station: placement refusals are reason codes with catalog text", _test_phase148_placement_codes)
	_run_test("chat: a reconnect inside the cooldown is not announced twice", _test_phase148_join_throttle)

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
	s.mono_sec = func() -> float: return now[0]
	var where := { "p1": Vector2(10.0, 10.0), "p2": Vector2(12.0, 10.0), "p3": Vector2(900.0, 900.0) }
	s.position_of = func(pid: String) -> Variant: return where.get(pid, null)
	return { "reg": reg, "s": s, "now": now, "where": where }

func _free_rig(rig: Dictionary) -> void:
	rig["s"].free()
	rig["reg"].free()

func _give(rig: Dictionary, pid: String, item: String, n: int) -> void:
	assert_true(rig["reg"].get_inventory(pid).add_item(item, n), "%s gets %d %s" % [pid, n, item])

func _found(rig: Dictionary) -> String:
	var s: SettlementSlice = rig["s"]
	assert_eq(s.found("p1", "Oak", Vector2(10.0, 10.0)), "", "p1 founds")
	return "settlement_1"

func _test_settlement_found() -> void:
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	assert_eq(s.found("p1", "  ", Vector2(10.0, 10.0)), "bad_args", "a blank name is refused")
	assert_eq(s.found("p1", "Oak", Vector2(10.0, 10.0)), "", "the host founds with no Hearth item")
	assert_eq(s.role_of("p1", "settlement_1"), "founder", "the founder is a member")
	assert_eq(s.get_settlement("settlement_1")["status"], "founded", "a new settlement is founded-tier")
	assert_eq(s.found("p1", "Two", Vector2(5000.0, 0.0)), "already_member", "one settlement per player")
	assert_eq(s.found("p2", "Near", Vector2(11.0, 10.0)), "", "a second site right beside the first is fine: nothing is claimed")
	for k: String in ["claim_radius", "claim_at", "edit_blocker", "note_edit", "at_research_site", "project_effect", "founding_blocker", "note_activity"]:
		assert_false(s.has_method(k), "no %s since Phase 205" % k)
	for k: String in ["decayRadiusPerDay", "minSeparation"]:
		assert_false(s.rules().has(k), "the rules carry no %s" % k)
	for t: String in SettlementSlice.TIER_ORDER:
		assert_false((s.rules()["tiers"][t] as Dictionary).has("claimRadius"), "%s has no claim radius" % t)
	var seen: Array = []
	var cb := func(pid: String, action: String, ok: bool, reason: String) -> void: seen.append([pid, action, ok, reason])
	GameBus.settlement_resolved.connect(cb)
	GameBus.settlement_intent.emit("found", { "name": "Oak" }, "p3")
	assert_eq(seen.back(), ["p3", "found", false, "unknown_action"], "no intent founds a settlement")
	GameBus.settlement_resolved.disconnect(cb)
	_free_rig(rig)

func _test_settlement_tiers_no_decay() -> void:
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	_found(rig)
	s.invite("p1", "p2")
	s.join("p2", "settlement_1")
	s.invite("p1", "p3")
	s.join("p3", "settlement_1")
	var day := SettlementSlice.DAY_SEC
	rig["now"][0] += 3.0 * day + 1.0
	assert_true(s.tick(rig["now"][0]), "growing is a change")
	assert_eq(s.get_settlement("settlement_1")["status"], "growing", "three members and three days make it growing")
	rig["now"][0] += 400.0 * day
	assert_false(s.tick(rig["now"][0]), "a year with no one there changes nothing")
	assert_eq(s.get_settlement("settlement_1")["status"], "growing", "nothing is abandoned")
	assert_eq(s.count(), 1, "or decays away")
	var data: Dictionary = s.to_data()
	data["settlements"]["settlement_1"]["status"] = "abandoned"
	s.from_data(data)
	assert_eq(s.get_settlement("settlement_1")["status"], "founded", "an abandoned settlement of an older save is founded again")
	_free_rig(rig)

func _test_hearth_returned() -> void:
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	var released: Array = []
	s.release_station = func(sid: String) -> void: released.append(sid)
	var old := { "format": 2, "next_id": 2, "settlements": { "settlement_1": { "name": "Oak", "founder": "p1",
		"members": { "p1": "founder", "p2": "member" }, "hx": 10.0, "hz": 10.0, "hearth_station": "station_7" } } }
	s.from_data(JSON.parse_string(JSON.stringify(old)))
	assert_eq(released, ["station_7"], "the saved hearth station is removed on load")
	assert_eq(s.hearth_returns(), { "p1": 1 }, "its founder is owed a Hearth")
	assert_false(s.get_settlement("settlement_1").has("hearth_station"), "the settlement keeps no hearth")
	var again: Dictionary = JSON.parse_string(JSON.stringify(s.to_data()))
	var s2 := SettlementSlice.new()
	add_child(s2)
	var released2: Array = []
	s2.release_station = func(sid: String) -> void: released2.append(sid)
	s2.from_data(again)
	assert_eq(released2, [], "a re-saved record removes nothing twice")
	assert_eq(s2.hearth_returns(), { "p1": 1 }, "and still owes the Hearth until it is handed over")
	s2.free()
	var inv: Node = rig["reg"].get_inventory("p1")
	s.tick(rig["now"][0])
	assert_eq(inv.get_item_count("Hearth"), 0, "an offline founder is not handed it")
	assert_eq(s.hearth_returns(), { "p1": 1 }, "so it stays owed")
	rig["reg"]._peer_ids[5] = "p1"   # p1 connects
	s.tick(rig["now"][0])
	assert_eq(inv.get_item_count("Hearth"), 1, "once online the founder holds the Hearth")
	assert_true(s.hearth_returns().is_empty(), "and nothing is owed")
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
	# Away from the site.
	rig["where"]["p1"] = Vector2(900.0, 900.0)
	assert_eq(s.deposit("p1", "AethermiteDust", 1), "too_far", "a deposit is made at the site")
	assert_eq(s.withdraw("p1", "AethermiteDust", 1), "too_far", "and so is a withdraw")
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
	assert_eq(s.withdraw("p3", "Ferrite", 1), "no_permission", "a guest cannot take")
	assert_eq(s.leave("p1"), "founder_locked", "the founder cannot leave")
	assert_eq(s.leave("p3"), "", "a member leaves")
	assert_eq(s.settlement_of("p3"), "", "and belongs nowhere")
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
	assert_eq(s2.found("p3", "Next", Vector2(5000.0, 0.0)), "", "ids continue after a load")
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
	_found(rig)
	GameBus.settlement_intent.emit("invite", { "target": "p2" }, "p1")
	assert_eq(seen.back(), ["p1", "invite", true, ""], "an invite resolves through the bus")
	GameBus.settlement_intent.emit("invite", { "target": "p3" }, "p1")
	assert_eq(seen.back()[3], "rate_limited", "intents are rate limited per player")
	rig["now"][0] += 1.0
	GameBus.settlement_intent.emit("dance", {}, "p1")
	assert_eq(seen.back()[3], "unknown_action", "an unknown action is refused")
	rig["now"][0] += 1.0
	GameBus.settlement_intent.emit("deposit", { "item": "Ferrite", "qty": "lots" }, "p1")
	assert_eq(seen.back()[3], "bad_args", "a non-numeric quantity is refused")
	rig["now"][0] += 1.0
	GameBus.settlement_intent.emit("leave", {}, "")
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
	# Phase 203 — the fabric dropped the stockpile source; the runtime holds it until Phase 209.
	assert_false(GameData.TECHNOLOGIES[tid].get("tech").has("materialSource"), "the fabric names no stockpile material source")
	assert_true(TechnologySlice.STOCKPILE_RESEARCH_HOLD.has(tid), "the runtime holds the stockpile source")
	assert_eq(s.research_stock("p1", item), 0, "an empty stockpile holds nothing for research")
	_give(rig, "p1", item, qty)
	s.deposit("p1", item, qty)
	assert_eq(s.research_stock("p1", item), qty, "research sees the stockpile")
	assert_eq(s.research_stock("p3", item), 0, "an outsider sees nothing")
	rig["where"]["p1"] = Vector2(900.0, 900.0)
	assert_eq(s.research_stock("p1", item), 0, "research is drawn at the site")
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


func _test_phase147_hearth_exact() -> void:
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	var far := { "chunk": Vector2i(int(2.0e7 / SettlementSlice.WorldPos.CHUNK_METERS), 5), "local": Vector3(7.3125, 12.5, 0.0625) }
	assert_eq(s.found("p1", "Far", Vector2(2.0e7, 5.0), far), "", "a far site is founded")
	var saved: Dictionary = s.to_data()
	var fresh := SettlementSlice.new()
	add_child(fresh)
	fresh.from_data(saved)
	var back: Dictionary = fresh.site_exact("settlement_1")
	assert_eq(back["chunk"], far["chunk"], "the site chunk survives the save")
	assert_true((back["local"] as Vector3).distance_to(far["local"]) < 0.01, "and its local offset is exact to under 1 cm")
	var want: float = float(far["chunk"].x) * SettlementSlice.WorldPos.CHUNK_METERS + 7.3125
	assert_true(absf(float(fresh.get_settlement("settlement_1")["hx"]) - want) < 0.01, "the site centre is a double, not a float32")
	fresh.free()
	_free_rig(rig)

func _test_phase147_from_data() -> void:
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	s.from_data({ "next_id": 1, "settlements": { "settlement_7": { "name": "Old", "founder": "p1", "members": { "p1": "founder" } } } })
	assert_eq(s.count(), 1, "the entry loads")
	assert_eq(float(s._settlements["settlement_7"]["last_active"]), float(rig["now"][0]), "a missing last_active defaults to now, not 0")
	assert_eq(s.found("p2", "New", Vector2(5000.0, 0.0)), "", "a new settlement is founded")
	assert_true(s.get_settlement("settlement_8").size() > 0 and s.get_settlement("settlement_7")["name"] == "Old", "the new id is above every loaded id")
	_free_rig(rig)

func _test_phase148_default_name() -> void:
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	assert_eq(s.found("p1", "", Vector2(10.0, 10.0)), "bad_args", "a blank manual name is still refused")
	assert_eq(s.found("p1", "", Vector2(10.0, 10.0), {}, true), "", "an auto-named founding is accepted")
	assert_eq(s.found("p3", "", Vector2(900.0, 900.0), {}, true), "", "a second one")
	var claims: Array = s.public_claims()
	assert_eq([claims[0]["name"], claims[0]["name_n"], claims[1]["name_n"]], ["", 1, 2], "stored as a number, no host-locale text")
	TranslationServer.set_locale("pt_BR")
	assert_eq(SettlementSlice.display_name(claims[1]), "Assentamento 2", "the client renders it in its locale")
	TranslationServer.set_locale("en")
	assert_eq(SettlementSlice.display_name(claims[1]), "Settlement 2", "and in English")
	assert_eq(SettlementSlice.display_name({ "name": "Oak", "name_n": 0 }), "Oak", "a typed name is shown as typed")
	# Losing a settlement never frees its number.
	var data: Dictionary = s.to_data()
	(data["settlements"] as Dictionary).erase("settlement_2")
	s.from_data(data)
	assert_eq(s.found("p3", "", Vector2(900.0, 900.0), {}, true), "", "founding again after the loss")
	assert_eq(s.public_claims()[1]["name_n"], 3, "takes the next number, not the freed one")
	_free_rig(rig)

func _test_phase148_placement_codes() -> void:
	var cats: Dictionary = I18nScript.parse_csv("res://locale/ui.csv")["catalog"]
	var st := StationSlice.new()
	add_child(st)
	var codes: Array = [st.placement_blocker("", Vector3.ZERO), st.placement_blocker("no_such_station", Vector3.ZERO)]
	var t: String = str(st.placeable_station_types()[0])
	st.try_place_station(t, Vector3(2.5, 0.0, 2.5), null)
	codes.append(st.placement_blocker(t, Vector3(2.5, 0.0, 2.5)))
	for c in codes:
		var key := "reason." + str(c).split(":")[0]
		assert_true(c != "" and not str(c).contains(" "), "%s is a code, not prose" % c)
		for loc in cats:
			assert_true((cats[loc] as Dictionary).has(key), "%s has %s" % [loc, key])
	st.free()

func _test_phase148_join_throttle() -> void:
	var chat := ChatSlice.new()
	var clock := [0.0]
	chat.join_clock = func() -> float: return clock[0]
	var seen: Array = []
	var cb := func(key: String, _args: Array, _target: String) -> void: seen.append(key)
	GameBus.system_message.connect(cb)
	chat.announce_joined("p1")
	clock[0] = 5.0
	chat.announce_joined("p1")
	chat.announce_joined("p2")
	assert_eq(seen.size(), 2, "p1 once and p2 once inside the cooldown")
	clock[0] = 100.0
	chat.announce_joined("p1")
	assert_eq(seen.size(), 3, "announced again after the cooldown")
	GameBus.system_message.disconnect(cb)
	chat.free()

func _test_invite_lapse_uninvite() -> void:
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	_found(rig)
	assert_eq(s.invite("p1", "p2"), "", "p1 invites p2")
	assert_eq(s.uninvite("p2", "p3"), "not_member", "an outsider withdraws nothing")
	assert_eq(s.uninvite("p1", "p3"), "no_such_invite", "nor is an invite that was never made withdrawn")
	assert_eq(s.uninvite("p1", " p2 "), "", "the founder withdraws the invite, padded name and all")
	assert_eq(s.join("p2", "settlement_1"), "not_invited", "a withdrawn invite cannot be accepted")
	assert_eq(s.invite("p1", "p2"), "", "invited again")
	rig["now"][0] += SettlementSlice.INVITE_TTL_SEC + 1.0
	assert_eq(s.join("p2", "settlement_1"), "not_invited", "an invite past its lifetime lapses")
	assert_eq(s.invite("p1", "p3"), "", "p3 is invited")
	rig["now"][0] += SettlementSlice.INVITE_TTL_SEC + 1.0
	s.tick(rig["now"][0])
	assert_true((s._settlements["settlement_1"]["invites"] as Dictionary).is_empty(), "the tick sweeps lapsed invites, so they cannot fill the list")
	var saved: Dictionary = s.to_data()
	(saved["settlements"]["settlement_1"]["invites"] as Dictionary)["p3"] = true   # a pre-expiry record
	s.from_data(saved)
	assert_eq(s.join("p3", "settlement_1"), "", "a legacy invite loads with a fresh clock")
	_free_rig(rig)

func _test_rate_limit_monotonic() -> void:
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	var mono := [50.0]
	s.mono_sec = func() -> float: return mono[0]
	assert_eq(s._resolve("dance", {}, "p1"), "unknown_action", "the first intent passes the limiter")
	rig["now"][0] -= 3600.0   # the wall clock jumps back an hour
	mono[0] += SettlementSlice.INTENT_INTERVAL + 0.01
	assert_eq(s._resolve("dance", {}, "p1"), "unknown_action", "a wall-clock jump does not lock the player out")
	assert_eq(s._resolve("dance", {}, "p1"), "rate_limited", "while the monotonic clock still limits")
	GameBus.player_left.emit("p1")
	assert_false(s._last_intent.has("p1"), "a player who left is forgotten")
	for i in SettlementSlice.MAX_INTENT_ENTRIES + 10:
		s._last_intent["ghost_%d" % i] = 0.0
	mono[0] += 1.0
	s._resolve("dance", {}, "p2")
	assert_true(s._last_intent.size() < SettlementSlice.MAX_INTENT_ENTRIES, "old entries are swept past the bound")
	_free_rig(rig)

func _test_panel_invites_kept() -> void:
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	var panel = load("res://src/ui/settlement_panel.gd").new()
	panel.settlement_slice = s
	var invites := [{ "id": "settlement_1", "name": "Oak", "name_n": 1 }]
	panel._render_invites(invites)
	var first: Node = panel._invites.get_child(0)
	panel._render_invites(invites.duplicate(true))
	assert_eq(panel._invites.get_child_count(), 1, "one Join button")
	assert_true(panel._invites.get_child(0) == first, "an unchanged refresh keeps the same button")
	panel._render_invites([])
	assert_eq(panel._invites.get_child_count(), 0, "a changed list rebuilds")
	panel.free()
	if is_instance_valid(first):
		first.free()
	_free_rig(rig)
