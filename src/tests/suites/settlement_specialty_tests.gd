extends "res://src/tests/test_support.gd"
## Phase 199 — settlement specialties at runtime: the scoring rules, the host recompute and its single sync,
## the roster, the character sheet row and the catalog (Phase 207 removed the labour bonus).

const SettlementSlice := preload("res://src/settlement/settlement_slice.gd")
const SpecialtyRules := preload("res://src/settlement/specialty_rules.gd")
const CharacterSheet := preload("res://src/ui/character_sheet.gd")

var _changes: Array = []

func register() -> void:
	_run_test("specialty rules: carpentry, combat and base values give woodworker, hunter and none; ties go in fabric order", _test_rules)
	_run_test("specialty: a skill gain that changes the best score changes the specialty and emits one sync", _test_recompute)
	_run_test("specialty: the roster, the sheet row and the catalog", _test_views)
	_run_test("specialty (audit): no specialty value is read from a client message", _test_audit)

func _rig() -> Dictionary:
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("host")
	for p in ["p1", "p2"]:
		reg.ensure_player(p)
	var s := SettlementSlice.new()
	s.registry = reg
	add_child(s)
	var now := [1000000.0]
	s.now_sec = func() -> float: return now[0]
	s.mono_sec = func() -> float: return now[0]
	s.position_of = func(_pid: String) -> Variant: return Vector2(10.0, 10.0)
	s.place_structure = func(_id: String, _key: String, _site: Dictionary) -> void: pass
	return { "reg": reg, "s": s, "now": now }

func _free_rig(rig: Dictionary) -> void:
	rig["s"].free()
	rig["reg"].free()

func _on_changed(pid: String, specialty: String) -> void:
	_changes.append([pid, specialty])

func _test_rules() -> void:
	var tbl := SpecialtyRules.table()
	assert_eq((tbl["specialties"] as Dictionary).keys(), ["woodworker", "smith", "hunter", "builder", "forager"], "the fabric order")
	var base := {}
	assert_eq(SpecialtyRules.specialty_for({}, base), "", "only base values: no specialty")
	assert_eq(SpecialtyRules.specialty_for({ "Carpentry": "journeyman" }, base), "woodworker", "a high carpentry skill")
	assert_eq(SpecialtyRules.specialty_for({ "Swordsmanship": "master" }, base), "hunter", "a high combat skill")
	assert_eq(SpecialtyRules.specialty_for({ "Carpentry": "apprentice" }, base), "", "below the floor")
	# A tie goes to the earlier row.
	var two := { "floor": 1, "specialties": { "a": { "skills": { "Carpentry": 1 } }, "b": { "skills": { "Smithing": 1 } } } }
	assert_eq(SpecialtyRules.specialty_for({ "Carpentry": "apprentice", "Smithing": "apprentice" }, {}, two), "a", "equal scores: the earlier row")
	assert_eq(SpecialtyRules.specialty_for({ "Carpentry": "apprentice", "Smithing": "journeyman" }, {}, two), "b", "the better score wins over order")

func _test_recompute() -> void:
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	var reg: PlayerRegistry = rig["reg"]
	_changes.clear()
	GameBus.specialty_changed.connect(_on_changed)
	assert_false(s.refresh_specialty("p1"), "base values: nothing changes, nothing is emitted")
	reg.record_skill("p1", "Carpentry", "journeyman")
	assert_true(s.refresh_specialty("p1"), "a skill gain changes the specialty")
	assert_eq(s.specialty_of("p1"), "woodworker", "woodworker")
	assert_false(s.refresh_specialty("p1"), "a second recompute with the same result is silent")
	reg.record_skill("p1", "Smithing", "master")
	reg.record_skill("p1", "ArcaneForging", "master")
	assert_true(s.refresh_specialty("p1"), "a better score changes it again")
	assert_eq(s.specialty_of("p1"), "smith", "smith")
	GameBus.specialty_changed.disconnect(_on_changed)
	assert_eq(_changes, [["p1", "woodworker"], ["p1", "smith"]], "exactly one sync per change")
	_free_rig(rig)

func _test_views() -> void:
	var rig := _rig()
	var s: SettlementSlice = rig["s"]
	var reg: PlayerRegistry = rig["reg"]
	assert_eq(s.found("p1", "Oak", Vector2(10.0, 10.0)), "", "founded")
	reg.record_skill("p1", "Carpentry", "journeyman")
	var mine: Dictionary = s.private_view("p1")["mine"]
	assert_eq(mine["specialties"], { "p1": "woodworker" }, "the roster carries the host's specialty")
	assert_eq(mine["specialty"], "woodworker", "and the viewer's own")
	var rows := CharacterSheet.specialty_rows("woodworker")
	assert_eq(rows.size(), 1, "one sheet row")
	assert_eq(rows[0]["icon_key"], "icons/specialties/woodworker.png.raw", "its icon key")
	assert_eq(CharacterSheet.specialty_rows("").size(), 0, "no row without a specialty")
	for key: String in SpecialtyRules.table()["specialties"]:
		assert_true(I18nScript.has_key("settlement.specialty." + key), "specialty %s has a name" % key)
		assert_true(FileAccess.file_exists("res://assets/icons/specialties/%s.png.raw" % key), "specialty %s has an icon" % key)
	assert_true(I18nScript.has_key("character.specialty"), "the sheet label")
	_free_rig(rig)

func _test_audit() -> void:
	for path in ["res://src/settlement/settlement_slice.gd", "res://src/settlement/specialty_rules.gd", "res://src/settlement/settlement_wiring.gd"]:
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for i in lines.size():
			var l: String = lines[i]
			if l.strip_edges().begins_with("#") or not l.contains("specialt"):
				continue
			assert_false(l.contains("args.get(\"specialt") or l.contains("args[\"specialt"), "%s:%d reads a specialty from a message" % [path, i + 1])
	assert_false(SettlementSlice.ACTIONS.has("specialty"), "no intent carries a specialty")
