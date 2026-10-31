extends "res://src/tests/test_support.gd"
## Phase 200 — settlement raids: the pure rules (eligibility, packs, losses, defence) and the raid record.

const SettlementSlice := preload("res://src/settlement/settlement_slice.gd")
const RaidRules := preload("res://src/settlement/raid_rules.gd")

func register() -> void:
	_run_test("raid rules: no raid without a member online, before the age, under the value floor or in the cooldown", _test_eligibility)
	_run_test("raid rules: a pack comes from the biome's rows within their counts", _test_pack)
	_run_test("raid: a lost raid takes at most the loss share, a defended one nothing, defence scales it down", _test_losses)
	_run_test("raid: the cooldown and last result survive a save and reload, a pre-200 world loads as never raided", _test_persistence)
	_run_test("raid director: warning, pack, defended and lost, forced starts, never with nobody online", _test_director)
	_run_test("raid director: a spawned pack is judged — all dead defended, one at the hearth lost", _test_director_field)
	_run_test("raid: raiders are creatures that die for good and leave with the raid", _test_raider_creatures)
	_run_test("raid: every refusal and result has catalog text", _test_strings)

func _ready_info() -> Dictionary:
	return { "age_sec": 3600.0, "tier": "growing", "stock_stacks": 0, "since_last_sec": 1.0e12, "active": false,
		"online_in_claim": 1, "biome": "TemperateForest" }

func _test_eligibility() -> void:
	assert_eq(RaidRules.start_blocker(_ready_info()), "", "a grown, old, watched village may be raided")
	var i := _ready_info()
	i["online_in_claim"] = 0
	assert_eq(RaidRules.start_blocker(i), "no_member_online", "nobody online inside the claim")
	i = _ready_info()
	i["age_sec"] = 29.0 * 60.0
	assert_eq(RaidRules.start_blocker(i), "too_young", "before the minimum age")
	i = _ready_info()
	i["tier"] = "founded"
	assert_eq(RaidRules.start_blocker(i), "not_worth_raiding", "founded tier and a small stockpile")
	i["stock_stacks"] = 10
	assert_eq(RaidRules.start_blocker(i), "", "ten stacks make a founded village worth raiding")
	i = _ready_info()
	i["since_last_sec"] = 5.0 * 3600.0
	assert_eq(RaidRules.start_blocker(i), "cooldown", "inside the cooldown")
	i["since_last_sec"] = 6.0 * 3600.0
	assert_eq(RaidRules.start_blocker(i), "", "cooldown over")
	i = _ready_info()
	i["active"] = true
	assert_eq(RaidRules.start_blocker(i), "raid_active", "one raid at a time")
	i = _ready_info()
	i["biome"] = "Ocean"
	assert_eq(RaidRules.start_blocker(i), "no_pack", "a biome with no row is never raided")

func _test_pack() -> void:
	var lowest := RaidRules.pack_for("TemperateForest", [0.0, 0.0])
	assert_eq(lowest, [{ "creature": "GraywolfPack", "count": 3 }, { "creature": "ForestBoar", "count": 1 }], "rolls at 0: the minimums")
	var highest := RaidRules.pack_for("TemperateForest", [0.999, 0.999])
	assert_eq(highest, [{ "creature": "GraywolfPack", "count": 5 }, { "creature": "ForestBoar", "count": 2 }], "rolls near 1: the maximums")
	assert_eq(RaidRules.pack_for("Ocean", [0.5]), [], "no row, no pack")
	for biome: String in RaidRules.table()["packs"]:
		for row: Dictionary in RaidRules.table()["packs"][biome]:
			assert_true(GameData.CREATURES.has(str(row["creature"])), "%s is a creature" % row["creature"])

func _rig() -> Dictionary:
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("host")
	reg.ensure_player("p1")
	var s := SettlementSlice.new()
	s.registry = reg
	add_child(s)
	var now := [1000000.0]
	s.now_sec = func() -> float: return now[0]
	s.mono_sec = func() -> float: return now[0]
	s.position_of = func(_pid: String) -> Variant: return Vector2(10.0, 10.0)
	s.place_structure = func(_id: String, _key: String, _site: Dictionary) -> void: pass
	assert_true(reg.get_inventory("p1").add_item("Hearth", 1), "hearth")
	assert_eq(s.found("p1", "Oak", Vector2(10.0, 10.0)), "", "founded")
	return { "reg": reg, "s": s, "now": now }

func _free_rig(rig: Dictionary) -> void:
	rig["s"].free()
	rig["reg"].free()

func _test_losses() -> void:
	var stock := { "ThornwoodPlank": 100, "FerriteIngot": 3 }
	assert_eq(RaidRules.losses(true, stock, 0.0), { "stock": {}, "project_damage": 0.0 }, "a defended raid takes nothing")
	var lost := RaidRules.losses(false, stock, 0.0)
	assert_eq(lost["stock"], { "ThornwoodPlank": 20 }, "at most 20%, rounded down per item")
	assert_eq(lost["project_damage"], 0.25, "the project damage share")
	var guarded := RaidRules.losses(false, stock, 0.5)
	assert_eq(guarded["stock"], { "ThornwoodPlank": 10 }, "a palisade and watchtower (0.5) halve it")
	assert_eq(RaidRules.losses(false, stock, 5.0)["stock"], { "ThornwoodPlank": 5 }, "defence is capped at 0.75")
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	s._settlements["settlement_1"]["stock"] = { "ThornwoodPlank": 100 }
	assert_eq(s.start_project("p1", "palisade"), "", "palisade started")
	s.projects_of("settlement_1")
	s._settlements["settlement_1"]["projects"]["palisade"]["work"] = 40.0
	var out := s.end_raid("settlement_1", false)
	assert_eq(out["stock"], { "ThornwoodPlank": 20 }, "the slice takes the capped share")
	assert_eq(s.stock_of("settlement_1")["ThornwoodPlank"], 80, "and the stockpile shrinks by it")
	assert_eq(float(s.projects_of("settlement_1")["palisade"]["work"]), 30.0, "an unfinished project loses a quarter of its labour")
	var kept := s.end_raid("settlement_1", true)
	assert_eq(kept["stock"], {}, "a defended raid takes nothing from the slice")
	assert_eq(s.stock_of("settlement_1")["ThornwoodPlank"], 80, "stockpile untouched")
	_free_rig(rig)

func _test_persistence() -> void:
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	assert_eq(s.raid_record("settlement_1"), { "last_end": 0.0, "last_result": "" }, "never raided")
	var out := s.end_raid("settlement_1", false)
	assert_eq(out["result"], "lost", "a lost raid")
	var data := s.to_data()
	var again := SettlementSlice.new()
	add_child(again)
	again.from_data(data)
	assert_eq(again.raid_record("settlement_1"), { "last_end": 1000000.0, "last_result": "lost" }, "the cooldown clock and result survive")
	again.free()
	var legacy := s.to_data()
	legacy["format"] = 2
	var old := SettlementSlice.new()
	add_child(old)
	old.from_data(legacy)
	assert_eq(old.raid_record("settlement_1"), { "last_end": 0.0, "last_result": "" }, "a pre-200 record loads as never raided")
	old.free()
	assert_eq(s.end_raid("nowhere", true), {}, "no such settlement")
	_free_rig(rig)

func _test_strings() -> void:
	for code: String in RaidRules.REASONS:
		assert_true(I18nScript.has_key("settlement.raid.refused." + code), "refusal %s has catalog text" % code)
	for k in ["settlement.raid.warning", "settlement.raid.result.defended", "settlement.raid.result.lost"]:
		assert_true(I18nScript.has_key(k), "%s is in the catalog" % k)

const RaidDirector := preload("res://src/settlement/raid_director.gd")
var _events: Array = []

func _on_warned(id: String, seconds: int) -> void:
	_events.append(["warned", id, seconds])

func _on_spawn(id: String, pack: Array, _edge: Vector2) -> void:
	_events.append(["spawn", id, pack])

func _on_resolved(id: String, result: String, _lost: Dictionary, _damage: float) -> void:
	_events.append(["resolved", id, result])

func _test_director() -> void:
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	var now: Array = rig["now"]
	var d := RaidDirector.new()
	d.slice = s
	d.online_ids = func() -> Array: return ["p1"]
	d.biome_at = func(_xz: Vector2) -> String: return "TemperateForest"
	_events.clear()
	GameBus.raid_warned.connect(_on_warned)
	GameBus.raid_pack_spawn.connect(_on_spawn)
	GameBus.raid_resolved.connect(_on_resolved)
	var t0: float = now[0]
	assert_eq(d.start("settlement_1", t0), "too_young", "a fresh village is not raided")
	assert_eq(d.start("settlement_1", t0), "too_young", "still not")
	d.tick(t0)
	assert_true(_events.is_empty(), "the tick starts nothing")
	assert_eq(d.start("settlement_1", t0, true), "", "the admin command skips age, value and cooldown")
	assert_eq(_events[0], ["warned", "settlement_1", 120], "the warning carries the fabric seconds")
	assert_eq(d.start("settlement_1", t0, true), "raid_active", "one raid at a time")
	d.tick(t0 + 119.0)
	assert_eq(_events.size(), 1, "no pack before the warning ends")
	d.tick(t0 + 121.0)
	assert_eq(_events[1][0], "spawn", "the pack spawns after the warning")
	assert_eq(d.phase_of("settlement_1"), "fighting", "fighting")
	d.cleared("settlement_1")
	assert_eq(_events[2], ["resolved", "settlement_1", "defended"], "cleared: defended")
	assert_false(d.active("settlement_1"), "the raid is over")
	assert_eq(d.start("settlement_1", t0 + 130.0, true), "", "forced starts ignore the cooldown")
	d.tick(t0 + 130.0 + 121.0)
	d.tick(t0 + 130.0 + 121.0 + 601.0)
	assert_eq(_events[-1], ["resolved", "settlement_1", "lost"], "an unrepelled raid is lost when its time runs out")
	d.online_ids = func() -> Array: return []
	assert_eq(d.start("settlement_1", t0 + 5000.0, true), "no_member_online", "even forced, never with no member online")
	GameBus.raid_warned.disconnect(_on_warned)
	GameBus.raid_pack_spawn.disconnect(_on_spawn)
	GameBus.raid_resolved.disconnect(_on_resolved)
	_free_rig(rig)

func _test_director_field() -> void:
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	var t0: float = rig["now"][0]
	var field := { "raiders": [], "removed": [] }
	var d := RaidDirector.new()
	d.slice = s
	d.online_ids = func() -> Array: return ["p1"]
	d.biome_at = func(_xz: Vector2) -> String: return "TemperateForest"
	d.spawn_raider = func(c: String, xz: Vector2, _goal: Vector2, _rid: String, n: int) -> String:
		field["raiders"].append({ "id": "r%d" % n, "alive": true, "xz": xz, "c": c })
		return "r%d" % n
	d.raiders_of = func(_rid: String) -> Array: return field["raiders"]
	d.remove_raiders = func(rid: String) -> void: field["removed"].append(rid)
	assert_eq(d.start("settlement_1", t0, true), "", "forced start")
	d.tick(t0 + 121.0)
	var n: int = field["raiders"].size()
	assert_true(n >= 4 and n <= 7, "the temperate forest pack is 4 to 7 raiders (%d)" % n)
	var edge: Vector2 = d.raid_of("settlement_1")["edge"]
	assert_true(edge.distance_to(s.hearth_xz("settlement_1")) <= s.claim_radius("settlement_1") + 0.01, "they spawn on the claim edge")
	d.tick(t0 + 130.0)
	assert_true(d.active("settlement_1"), "raiders alive and far: the fight goes on")
	for r: Dictionary in field["raiders"]:
		r["alive"] = false
	d.tick(t0 + 140.0)
	assert_false(d.active("settlement_1"), "all dead: over")
	assert_eq(s.raid_record("settlement_1")["last_result"], "defended", "defended")
	assert_eq(field["removed"], ["settlement_1"], "the raiders were removed")
	# A raider at the hearth loses it.
	field["raiders"].clear()
	assert_eq(d.start("settlement_1", t0 + 200.0, true), "", "again")
	d.tick(t0 + 330.0)
	field["raiders"][0]["xz"] = s.hearth_xz("settlement_1") + Vector2(1.0, 0.0)
	d.tick(t0 + 340.0)
	assert_eq(s.raid_record("settlement_1")["last_result"], "lost", "a raider at the hearth: lost")
	_free_rig(rig)

func _test_raider_creatures() -> void:
	var c := CreatureSlice.new()
	add_child(c)
	var iid := c.spawn_raider("GraywolfPack", Vector2(120.0, -40.0), Vector2(0.0, 0.0), "settlement_1", 0)
	assert_true(iid != "", "a raider spawned")
	var list := c.raiders_of("settlement_1")
	assert_eq(list.size(), 1, "one raider listed")
	assert_true(bool(list[0]["alive"]), "alive")
	assert_true((list[0]["xz"] as Vector2).distance_to(Vector2(120.0, -40.0)) < 1.0, "at the edge point")
	GameBus.creature_died.emit(iid, Vector3.ZERO, "p1", Vector3.ZERO)
	assert_false(bool(c.raiders_of("settlement_1")[0]["alive"]), "killed")
	assert_true(c._suppresses_respawn(c._instances[iid]), "a dead raider never respawns")
	assert_eq(c.raiders_of("other").size(), 0, "other raids have none")
	c.remove_raiders("settlement_1")
	assert_eq(c.raiders_of("settlement_1").size(), 0, "removed when the raid ends")
	c.free()
