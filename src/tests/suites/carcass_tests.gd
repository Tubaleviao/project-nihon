extends "res://src/tests/test_support.gd"
## Phase 161 — harvesting at runtime: a kill leaves a body, a tool works it, a player carries it.



func register() -> void:
	_run_test("carcass: a kill creates a carcass and no immediate pickups", _test_kill_makes_carcass)
	_run_test("carcass: a knife yields the knife entries only, a bone tool the bone entries, bare hands the none entries", _test_tool_categories)
	_run_test("carcass: Skinning 0 and the cap give the table's min and max quantity and the lowest and highest grade; XP and wear follow", _test_level_scaling)
	_run_test("carcass: the host refuses out of range, no tool, an empty body and a carry over capacity", _test_refusals)
	_run_test("carcass: carrying slows the walk from the fabric, blocks harvest, drop places it and death drops it", _test_carry)
	_run_test("carcass: a body expires after corpseSeconds and a saved world restores it", _test_expiry_and_save)
	_run_test("carcass: a region keeps at most maxCarcassesPerRegion bodies, the oldest decaying first", _test_region_cap)
	_run_test("carcass: the prompt names what the held tools can take and what is missing", _test_prompt)
	_run_test("carcass: a carried body that decays releases its carrier; a refused carry keeps the harvest running", _test_carrier_lost)
	_run_test("carcass: hostile saved data and unknown creatures are dropped", _test_hostile_save)
	_run_test("carcass: a remote peer's harvest pushes its changed bag to that peer", _test_peer_harvest_syncs_bag)
	_run_test("carcass: the host moves a carried body no faster than the slowed walk; an over-speed carrier loses it", _test_carry_speed_host_rule)
	_run_test("carcass: a loaded world keeps the region cap and a worn-out tool is not counted for the prompt", _test_load_cap_and_worn_tool)
	_run_test("carcass: body nodes follow an origin rebase and sit at world position plus the offset", _test_rebase_shifts_bodies)
	_run_test("carcass: a drop puts the body where the host has it, not at a client-reported position", _test_drop_uses_host_position)
	_run_test("carcass: a poor tool scales only its own entries; none entries keep the bare-hand yield", _test_bare_hand_entries_ignore_tool)
	_run_test("carcass: harvesting has its own wear value", _test_harvest_wear_value)


## A host-shaped GameRoot with the carcass slice and wiring, one player "p1" at `at` and a bag.
func _fixture() -> Dictionary:
	var gr: Node = (load("res://src/core/game_root.gd") as GDScript).new()
	gr._registry = PlayerRegistry.new()
	gr._registry.local_player_id = "p1"
	var inv := InventorySlice.new()
	add_child(inv)
	gr._inventory = inv
	gr._registry.set_inventory("p1", inv)
	var loot := LootSlice.new()
	add_child(loot)
	gr._loot = loot
	var sl := CarcassSlice.new()
	add_child(sl)
	gr._carcass = sl
	var at := [Vector3.ZERO]
	gr._carcass_wiring.position_probe = func(_pid: String) -> Vector3: return at[0]
	gr._carcass_wiring.wire(gr)
	return {"gr": gr, "inv": inv, "loot": loot, "sl": sl, "at": at}


func _free_fixture(f: Dictionary) -> void:
	f["gr"]._carcass_wiring.unwire()
	f["sl"].free()
	f["loot"].free()
	f["inv"].free()
	f["gr"]._registry.free()
	f["gr"].free()


func _work(f: Dictionary, cid: String) -> Array:
	var got := []
	var h := func(_p: String, _c: String, reason: String, items: Array) -> void: got.append([reason, items])
	GameBus.harvest_resolved.connect(h)
	GameBus.harvest_intent.emit(cid, "p1")
	f["gr"]._carcass_wiring.tick(CarcassRules.rule_f("harvestSeconds", 4.0) + 0.1)
	GameBus.harvest_resolved.disconnect(h)
	return got


func _items_of(result: Array) -> Array:
	var out := []
	for it: Dictionary in result[0][1]:
		out.append(it["item"])
	return out


func _test_kill_makes_carcass() -> void:
	var f := _fixture()
	GameBus.creature_died.emit("ForestBoar", Vector3(5, 0, 5), "p1", Vector3.ZERO)
	assert_eq(f["sl"].count(), 1, "one body")
	assert_eq(f["loot"].get_pickups_near(Vector3(5, 0, 5), 50.0).size(), 0, "no pickups")
	var c: Dictionary = f["sl"].get_carcass(f["sl"].ids()[0])
	assert_eq(c["creature"], "ForestBoar", "the boar's body")
	assert_eq((c["entries"] as Array).size(), CarcassRules.entries_for("ForestBoar").size(), "all entries remain")
	_free_fixture(f)


func _test_tool_categories() -> void:
	var f := _fixture()
	var cid: String = f["sl"].create_for_death("ForestBoar", Vector3(1, 0, 0), "p1")
	f["at"][0] = Vector3(1, 0, 0)
	# Bare hands: only `none` entries; the boar has none, so nothing can be done.
	var none_only := CarcassRules.entries_for("ForestBoar").filter(func(e): return e["tool"] == "none")
	if none_only.is_empty():
		assert_eq(_work(f, cid)[0][0], "no_tool", "bare hands cannot work a boar")
	f["inv"].add_item("SkinningKnife", 1)
	# Pin the rolls: a fixed level 10 and chance 1 for each entry.
	for e: Dictionary in f["sl"]._carcasses[cid]["entries"]:
		e["chance"] = 1.0
	f["gr"]._registry.add_skill_xp("p1", "Skinning", 100000)
	var r := _work(f, cid)
	assert_eq(r[0][0], "", "the knife harvest succeeds")
	for item in _items_of(r):
		var tool_needed := ""
		for e: Dictionary in CarcassRules.entries_for("ForestBoar"):
			if e["item"] == item:
				tool_needed = e["tool"]
		assert_eq(tool_needed, "knife", "%s came off with the knife" % item)
	var left: Array = f["sl"].get_carcass(cid)["entries"].map(func(e): return e["tool"])
	assert_true(left.has("bonetool") and not left.has("knife"), "the bone entries stay for a bone tool")
	f["inv"].add_item("BoneSaw", 1)
	var r2 := _work(f, cid)
	assert_eq(r2[0][0], "", "the saw harvest succeeds")
	assert_false(f["sl"].has_carcass(cid), "an emptied body is removed")
	_free_fixture(f)


func _test_level_scaling() -> void:
	var s := GameData.SKILLS["Skinning"]
	var cap := int(s.get("levelCap"))
	var entry := {"item": "x", "chance": 1.0, "minQty": 1, "maxQty": 5, "tool": "knife"}
	assert_eq(CarcassRules.quantity(entry, 0, 0.0), 1, "level 0 gives minQty")
	assert_eq(CarcassRules.quantity(entry, cap, 0.0), 5, "the cap gives maxQty")
	assert_eq(CarcassRules.quality(0), "poor", "level 0 is the lowest grade")
	assert_eq(CarcassRules.quality(cap), "prime", "the cap is the highest grade")
	var prev := 0
	for l in cap + 1:
		var q := CarcassRules.quantity(entry, l, 0.0)
		assert_true(q >= prev, "quantity never falls at level %d" % l)
		prev = q
	assert_eq(CarcassRules.effective_level(cap, 0.5), cap / 2, "a poor tool works at half level")
	assert_eq(CarcassRules.level_for_xp(0), 0, "no XP is level 0")
	assert_eq(CarcassRules.level_for_xp(100000000), cap, "lots of XP is the cap")
	# A real harvest: XP is granted and the knife wears.
	var f := _fixture()
	f["inv"].add_item("SkinningKnife", 1)
	var before: float = f["inv"].get_durability("SkinningKnife")
	var cid: String = f["sl"].create_for_death("ForestBoar", Vector3.ZERO, "p1")
	var xp_before: int = f["gr"]._registry.get_skill_xp("p1", "Skinning")
	assert_eq(_work(f, cid)[0][0], "", "harvested")
	assert_eq(f["gr"]._registry.get_skill_xp("p1", "Skinning") - xp_before, int(s.get("xpPerHarvest")), "XP granted")
	assert_true(f["inv"].get_durability("SkinningKnife") < before, "the knife wore")
	_free_fixture(f)


func _test_refusals() -> void:
	var f := _fixture()
	f["inv"].add_item("SkinningKnife", 1)
	var far: String = f["sl"].create_for_death("ForestBoar", Vector3(50, 0, 0), "p1")
	assert_eq(_work(f, far)[0][0], "out_of_range", "out of range")
	f["at"][0] = Vector3(50, 0, 0)
	var bison: String = f["sl"].create_for_death("SteppeBison", Vector3(50, 0, 0), "p1")
	var got := []
	var h := func(_p: String, _c: String, reason: String, _i: Array) -> void: got.append(reason)
	GameBus.harvest_resolved.connect(h)
	GameBus.carry_intent.emit(bison, "p1")
	assert_eq(got, ["too_heavy"], "an immovable body cannot be carried")
	got.clear()
	GameBus.harvest_intent.emit("carcass_999", "p1")
	assert_eq(got, ["unknown_carcass"], "unknown body")
	f["inv"].consume_items({"SkinningKnife": 1})
	GameBus.harvest_intent.emit(far, "p1")
	assert_eq(got[1], "no_tool", "no tool held")
	GameBus.harvest_resolved.disconnect(h)
	f["sl"].get_carcass(far)
	f["sl"]._carcasses[far]["entries"] = []
	assert_eq(f["sl"].check_harvest(far, Vector3(50, 0, 0), "knife", "p1"), "empty", "an empty body")
	_free_fixture(f)


func _test_carry() -> void:
	var f := _fixture()
	var rules := GameData.HARVESTS["HarvestRules"]
	var cap := CarcassRules.capacity_kg(0)
	var heavy := ""
	var light := ""
	for key: String in GameData.CREATURES:
		var m := CarcassRules.mass_of(key)
		if CarcassRules.carry_rule(key) == "carry" and m > cap * float(rules.get("carrySlowAboveFraction")) and heavy == "":
			heavy = key
		if CarcassRules.carry_rule(key) == "carry" and m <= cap * float(rules.get("carrySlowAboveFraction")) and light == "":
			light = key
	var cid: String = f["sl"].create_for_death(heavy, Vector3(1, 0, 0), "p1")
	f["at"][0] = Vector3(1, 0, 0)
	GameBus.carry_intent.emit(cid, "p1")
	assert_eq(f["sl"].carried_by("p1"), cid, "carried")
	assert_eq(f["sl"].speed_multiplier("p1", 0), float(rules.get("carrySlowSpeedMultiplier")), "a heavy body slows the walk")
	var lid: String = f["sl"].create_for_death(light, Vector3(1, 0, 0), "p1")
	assert_eq(f["sl"].check_harvest(lid, Vector3(1, 0, 0), "", "p1"), "carrying", "harvest is blocked while carrying")
	f["at"][0] = Vector3(9, 0, 3)
	f["sl"].follow("p1", Vector3(9, 0, 3))
	GameBus.carcass_drop_intent.emit("p1")
	assert_eq(f["sl"].carried_by("p1"), "", "dropped")
	assert_eq(f["sl"].get_carcass(cid)["position"], Vector3(9, 0, 3), "placed at the player")
	GameBus.carry_intent.emit(cid, "p1")
	var pl := PlayerSlice.new()
	f["gr"]._player = pl
	pl.set_hp(0.0)
	GameBus.player_damaged.emit(5.0, "x", "p1")
	f["gr"]._carcass_wiring.tick(0.01)   # the death check runs once the hit has been applied
	assert_eq(f["sl"].carried_by("p1"), "", "dying drops the body")
	assert_false(pl.carrying, "the carry state is cleared with it")
	pl.free()
	f["gr"]._player = null
	_free_fixture(f)


func _test_expiry_and_save() -> void:
	var f := _fixture()
	var cid: String = f["sl"].create_for_death("ForestBoar", Vector3(3, 0, 4), "p1")
	var data: Dictionary = JSON.parse_string(JSON.stringify(f["sl"].to_data()))
	var g := CarcassSlice.new()
	add_child(g)
	g.from_data(data)
	assert_eq(g.count(), 1, "the saved body is restored")
	assert_eq(g.get_carcass(cid)["position"], Vector3(3, 0, 4), "at the same place")
	g.advance(CarcassRules.corpse_seconds("ForestBoar") + 1.0)
	assert_eq(g.count(), 0, "it expired after corpseSeconds")
	g.free()
	f["sl"].advance(CarcassRules.corpse_seconds("ForestBoar") - 1.0)
	assert_eq(f["sl"].count(), 1, "still there before the time")
	f["sl"].advance(2.0)
	assert_eq(f["sl"].count(), 0, "gone after the time")
	_free_fixture(f)


func _test_region_cap() -> void:
	var f := _fixture()
	var cap := int(GameData.HARVESTS["HarvestRules"].get("maxCarcassesPerRegion"))
	var first := ""
	for i in cap + 3:
		var id: String = f["sl"].create_for_death("ForestBoar", Vector3(float(i), 0, 0), "p1")
		f["sl"]._carcasses[id]["remaining"] = 1000.0 + float(i)
		if first == "":
			first = id
	assert_eq(f["sl"].count(), cap, "the region keeps its cap")
	assert_false(f["sl"].has_carcass(first), "the oldest decayed first")
	_free_fixture(f)


func _test_prompt() -> void:
	var entries := CarcassRules.entries_for("ForestBoar")
	assert_eq(CarcassRules.prompt_for(entries, ["knife"], false)[0], "hud.carcass.harvest", "a knife can work something")
	var none: Array = CarcassRules.prompt_for(entries, [], false)
	assert_eq(none[0], "hud.carcass.needs", "no tool names what is missing")
	assert_eq(none[1], ["tool.knife"], "the knife")
	assert_eq(CarcassRules.prompt_for(entries, [], true)[0], "hud.carcass.carrying", "carrying")
	for key in ["hud.carcass.harvest", "hud.carcass.needs", "hud.carcass.carrying", "hud.carcass.empty", "tool.knife", "tool.bonetool"]:
		assert_true(I18nScript.has_key(key), "%s is in the catalog" % key)


func _test_carrier_lost() -> void:
	var f := _fixture()
	var pl := PlayerSlice.new()
	f["gr"]._player = pl
	var cid: String = f["sl"].create_for_death("ForestBoar", Vector3.ZERO, "p1")
	GameBus.carry_intent.emit(cid, "p1")
	assert_true(pl.carrying, "carrying")
	f["sl"].remove(cid)
	assert_false(pl.carrying, "a body that vanishes releases its carrier")
	assert_eq(pl.carry_speed_factor, 1.0, "speed back to normal")
	f["inv"].add_item("SkinningKnife", 1)
	var other: String = f["sl"].create_for_death("ForestBoar", Vector3(40, 0, 0), "p1")
	var near: String = f["sl"].create_for_death("ForestBoar", Vector3.ZERO, "p1")
	GameBus.harvest_intent.emit(near, "p1")
	GameBus.carry_intent.emit(other, "p1")   # out of range: refused, the harvest goes on
	assert_true(f["gr"]._carcass_wiring._actions.has("p1"), "a refused carry does not cancel the harvest")
	pl.free()
	f["gr"]._player = null
	_free_fixture(f)


func _test_hostile_save() -> void:
	var g := CarcassSlice.new()
	add_child(g)
	g.from_data({"next_id": 5, "carcasses": [
		{"id": "a", "creature": "Nope", "pos": [0, 0, 0], "entries": [], "remaining": 10.0},
		{"id": "b", "creature": "ForestBoar", "pos": [0, 0], "entries": [], "remaining": 10.0},
		{"id": "c", "creature": "ForestBoar", "pos": [0, 0, 0], "entries": [{"item": "diamond"}], "remaining": 10.0},
		{"id": "d", "creature": "ForestBoar", "pos": [0, 0, 0], "entries": [{"item": CarcassRules.entries_for("ForestBoar")[0]["item"]}], "remaining": -3.0},
		{"id": "e", "creature": "ForestBoar", "pos": [0, 0, 0], "entries": [{"item": CarcassRules.entries_for("ForestBoar")[0]["item"]}], "remaining": 99999999.0}]})
	g.from_data({"carcasses": [{"id": "n", "creature": "ForestBoar", "pos": [NAN, 0, 0], "entries": [{"item": CarcassRules.entries_for("ForestBoar")[0]["item"]}], "remaining": 10.0},
		{"id": "s", "creature": "ForestBoar", "pos": ["x", 0, 0], "entries": [{"item": CarcassRules.entries_for("ForestBoar")[0]["item"]}], "remaining": 10.0}]})
	assert_eq(g.count(), 0, "a non-finite or non-numeric position is dropped")
	g.from_data({"next_id": 5, "carcasses": [
		{"id": "a", "creature": "Nope", "pos": [0, 0, 0], "entries": [], "remaining": 10.0},
		{"id": "b", "creature": "ForestBoar", "pos": [0, 0], "entries": [], "remaining": 10.0},
		{"id": "c", "creature": "ForestBoar", "pos": [0, 0, 0], "entries": [{"item": "diamond"}], "remaining": 10.0},
		{"id": "d", "creature": "ForestBoar", "pos": [0, 0, 0], "entries": [{"item": CarcassRules.entries_for("ForestBoar")[0]["item"]}], "remaining": -3.0},
		{"id": "e", "creature": "ForestBoar", "pos": [0, 0, 0], "entries": [{"item": CarcassRules.entries_for("ForestBoar")[0]["item"]}], "remaining": 99999999.0}]})
	assert_eq(g.count(), 1, "only the valid body survives")
	assert_true(g.get_carcass("e")["remaining"] <= CarcassRules.corpse_seconds("ForestBoar"), "remaining time is clamped")
	g.from_data({"next_id": 1, "carcasses": [{"id": "carcass_7", "creature": "ForestBoar", "pos": [0, 0, 0],
		"entries": [{"item": CarcassRules.entries_for("ForestBoar")[0]["item"]}], "remaining": 10.0}]})
	assert_true(int(g.to_data()["next_id"]) >= 8, "the id counter passes every restored id")
	g.from_data("garbage")
	assert_eq(g.count(), 0, "garbage clears")
	g.free()


func _test_load_cap_and_worn_tool() -> void:
	var g := CarcassSlice.new()
	add_child(g)
	var cap := int(CarcassRules.rule_f("maxCarcassesPerRegion", 24.0))
	var item: String = CarcassRules.entries_for("ForestBoar")[0]["item"]
	var list: Array = []
	for i in cap + 10:
		list.append({"id": "c%d" % i, "creature": "ForestBoar", "pos": [0, 0, 0], "entries": [{"item": item}], "remaining": 10.0 + i})
	g.from_data({"carcasses": list})
	assert_eq(g.count(), cap, "a loaded record cannot exceed the per-region cap")
	g.from_data({"carcasses": [{"id": "far", "creature": "ForestBoar", "pos": [2.0e7, 0, 0], "entries": [{"item": item}], "remaining": 10.0}]})
	assert_eq(g.count(), 1, "a far-out body on a planet-scale world survives a reload")
	g.free()
	assert_false(PlayerSlice._has_usable_copy({"SkinningKnife": [0.0]}, "SkinningKnife"), "a fully worn tool is not usable")
	assert_true(PlayerSlice._has_usable_copy({"SkinningKnife": [0.0, 5.0]}, "SkinningKnife"), "one good copy is enough")
	assert_true(PlayerSlice._has_usable_copy({}, "SkinningKnife"), "a non-durable item is usable")


func _test_peer_harvest_syncs_bag() -> void:
	var f := _fixture()
	var net := NetworkingSlice.new()
	add_child(net)
	net.emulate_network = true
	net._role = NetworkingSlice.Role.HOST
	f["gr"]._networking = net
	f["gr"]._registry.ensure_player("p2")
	f["gr"]._registry._peer_ids[7] = "p2"
	var bag := InventorySlice.new()
	add_child(bag)
	f["gr"]._registry.set_inventory("p2", bag)
	bag.add_item("SkinningKnife", 1)
	var cid: String = f["sl"].create_for_death("ForestBoar", Vector3.ZERO, "p1")
	for e: Dictionary in f["sl"]._carcasses[cid]["entries"]:
		e["chance"] = 1.0
	net._pending.clear()
	var got := []
	var h := func(_p: String, _c: String, reason: String, items: Array) -> void: got.append([reason, items])
	GameBus.harvest_resolved.connect(h)
	GameBus.harvest_intent.emit(cid, "p2")
	f["gr"]._carcass_wiring.tick(CarcassRules.rule_f("harvestSeconds", 4.0) + 0.1)
	GameBus.harvest_resolved.disconnect(h)
	assert_eq(got.size(), 1, "the peer's harvest resolved")
	assert_eq(got[0][0] if got.size() > 0 else "?", "", "and succeeded")
	var pushes := []
	for q: Dictionary in net._pending:
		var packet: Dictionary = JSON.parse_string(q["payload"])
		if str(packet.get("type", "")) == "own_state_synced":
			pushes.append([int(q["peer_id"]), packet])
	assert_eq(pushes.size(), 1, "one own-state push")
	if pushes.size() == 1:
		assert_eq(pushes[0][0], 7, "addressed to the harvester's peer")
		var contents: Dictionary = pushes[0][1]["data"].get("inventory", {})
		for it: Dictionary in got[0][1]:
			assert_true(int(contents.get(it["item"], 0)) >= int(it["quantity"]), "the push carries %s" % it["item"])
	f["gr"]._networking = null
	net.free()
	bag.free()
	_free_fixture(f)


func _test_rebase_shifts_bodies() -> void:
	var sl := CarcassSlice.new()
	sl.render_visuals = true
	add_child(sl)
	var a: String = sl.create_for_death("ForestBoar", Vector3(10, 0, 0), "p1")
	var lift := Vector3(0.0, 0.2, 0.0)
	assert_eq((sl._nodes[a] as Node3D).position, Vector3(10, 0, 0) + lift, "no rebase yet: the world position")
	var shift := Vector3(-64, 0, 32)
	sl.shift_scene(shift)
	assert_eq((sl._nodes[a] as Node3D).position, Vector3(10, 0, 0) + shift + lift, "a rebase moves the body node")
	assert_eq(sl.position_of(a), Vector3(10, 0, 0), "the record keeps its world position")
	var b: String = sl.create_for_death("ForestBoar", Vector3(20, 0, 0), "p1")
	assert_eq((sl._nodes[b] as Node3D).position, Vector3(20, 0, 0) + shift + lift, "a body made after the rebase uses the offset")
	sl.free()


func _test_carry_speed_host_rule() -> void:
	var f := _fixture()
	var cw = f["gr"]._carcass_wiring
	var light := ""
	for key: String in GameData.CREATURES:
		if CarcassRules.carry_rule(key) == "carry" and light == "":
			light = key
	var cid: String = f["sl"].create_for_death(light, Vector3.ZERO, "p1")
	f["at"][0] = Vector3.ZERO
	GameBus.carry_intent.emit(cid, "p1")
	assert_eq(f["sl"].carried_by("p1"), cid, "carried")
	var walk: float = PlayerSlice.SPEED * f["sl"].speed_multiplier("p1", cw.level_of("p1"))
	# An honest carrier at its slowed walk, whose reports stall for half a second and then jump.
	var x := 0.0
	for i in 40:
		x += walk * 0.1
		if i < 10 or i >= 15:
			f["at"][0] = Vector3(x, 0, 0)
		cw.tick(0.1)
	for i in 10:
		cw.tick(0.1)
	assert_eq(f["sl"].carried_by("p1"), cid, "an honest carrier keeps the body through a stalled report")
	assert_true(f["sl"].position_of(cid).distance_to(Vector3(x, 0, 0)) < 0.5, "and the body catches up")
	# A carrier reporting twice the walk speed outruns the body and lets go of it.
	var start := x
	for i in 30:
		x += walk * 2.0 * 0.1
		f["at"][0] = Vector3(x, 0, 0)
		cw.tick(0.1)
	assert_eq(f["sl"].carried_by("p1"), "", "an over-speed carrier loses the body")
	var left_at: Vector3 = f["sl"].position_of(cid)
	assert_true(left_at.x > start and left_at.x < x - CarcassRules.rule_f("harvestRangeMetres", 3.0), "the body stays where it got to, behind the carrier")
	_free_fixture(f)


func _test_drop_uses_host_position() -> void:
	var f := _fixture()
	var light := ""
	for key: String in GameData.CREATURES:
		if CarcassRules.carry_rule(key) == "carry" and light == "":
			light = key
	var cid: String = f["sl"].create_for_death(light, Vector3(1, 0, 0), "p1")
	f["at"][0] = Vector3(1, 0, 0)
	GameBus.carry_intent.emit(cid, "p1")
	assert_eq(f["sl"].carried_by("p1"), cid, "carried")
	# The carrier reports a far position and drops before the body could follow it there.
	f["at"][0] = Vector3(500, 0, 500)
	GameBus.carcass_drop_intent.emit("p1")
	assert_eq(f["sl"].carried_by("p1"), "", "dropped")
	assert_eq(f["sl"].position_of(cid), Vector3(1, 0, 0), "the body stays where the host had it")
	_free_fixture(f)


func _test_bare_hand_entries_ignore_tool() -> void:
	var sl := CarcassSlice.new()
	add_child(sl)
	var cap := int(GameData.SKILLS["Skinning"].get("levelCap"))
	var cid: String = sl.create_for_death("ForestBoar", Vector3.ZERO, "p1")
	var item: String = CarcassRules.entries_for("ForestBoar")[0]["item"]
	sl._carcasses[cid]["entries"] = [
		{"item": item, "chance": 1.0, "minQty": 1, "maxQty": 5, "tool": "none"},
		{"item": item, "chance": 1.0, "minQty": 1, "maxQty": 5, "tool": "knife"}]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var got: Array = sl.resolve_harvest(cid, "knife", 0.0, cap, rng)
	assert_eq(got.size(), 2, "both entries rolled")
	if got.size() == 2:
		assert_eq(int(got[0]["quantity"]), 5, "the none entry yields at the full level")
		assert_eq(str(got[0]["quality"]), CarcassRules.quality(cap), "and grades at it")
		assert_eq(int(got[1]["quantity"]), 1, "the knife entry follows the useless knife")
	sl.free()


func _test_harvest_wear_value() -> void:
	assert_true(InventorySlice.ACTION_DECREMENT.has("harvest"), "harvest is listed in ACTION_DECREMENT")
