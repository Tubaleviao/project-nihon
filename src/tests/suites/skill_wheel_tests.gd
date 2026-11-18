extends "res://src/tests/test_support.gd"
## Phase 271 — the skill wheel: a pure layout from the fabric's affinity and depth, a node per skill tier named
## by its skill (never the tier or an id), a rim of professions, and every new string in both locales.

const I18n := preload("res://src/core/i18n.gd")
const SkillWheelLayout := preload("res://src/ui/skill_wheel_layout.gd")
const SkillWheelView := preload("res://src/ui/skill_wheel_view.gd")

const NEW_KEYS := ["ui.skills_fit", "ui.profession_locked", "ui.profession_active", "ui.profession_mastered"]

func register() -> void:
	_run_test("skill wheel: the layout is identical across runs", _test_deterministic)
	_run_test("skill wheel: a one-profession node lies on that profession's ray", _test_on_ray)
	_run_test("skill wheel: a deeper node of a skill lies farther from the centre", _test_deeper_farther)
	_run_test("skill wheel: nodes with no affinity lie inside the centre disc", _test_centre_disc)
	_run_test("skill wheel: a shared skill lies between its professions, nearer the centre than a deep one", _test_shared_between)
	_run_test("skill wheel: node states follow the player's tiers", _test_states)
	_run_test("skill wheel: no node label equals a tier name or an entity id", _test_labels)
	_run_test("skill wheel: every new string is in both locales", _test_locales)

func _test_deterministic() -> void:
	var a := SkillWheelLayout.layout(SkillWheelLayout.fabric_professions(), SkillWheelLayout.fabric_nodes())
	var b := SkillWheelLayout.layout(SkillWheelLayout.fabric_professions(), SkillWheelLayout.fabric_nodes())
	assert_eq(a, b, "same table, same layout")
	assert_eq((a["position"] as Dictionary).size(), SkillWheelLayout.fabric_nodes().size(), "every node is placed")
	assert_true(SkillWheelLayout.fabric_nodes().size() >= 100, "the wheel has a node per skill tier")

func _test_on_ray() -> void:
	var lay := SkillWheelLayout.for_fabric()
	var nodes := SkillWheelLayout.fabric_nodes()
	var checked := 0
	for id: String in nodes:
		var aff: Dictionary = nodes[id]["affinity"]
		if aff.size() != 1:
			continue
		var prof := str(aff.keys()[0])
		var ray: Vector2 = (lay["profession_position"] as Dictionary)[prof]
		var p: Vector2 = (lay["position"] as Dictionary)[id]
		assert_true(absf(p.normalized().dot(ray) - 1.0) < 0.0001, "%s lies on %s's ray" % [id, prof])
		checked += 1
	assert_true(checked > 20, "many nodes belong to one profession (%d)" % checked)

func _test_deeper_farther() -> void:
	var lay := SkillWheelLayout.for_fabric()
	var nodes := SkillWheelLayout.fabric_nodes()
	var checked := 0
	for id: String in nodes:
		var n: Dictionary = nodes[id]
		if (n["affinity"] as Dictionary).is_empty():
			continue
		for r in n["requires"]:
			assert_true((lay["position"][id] as Vector2).length() > (lay["position"][str(r)] as Vector2).length(),
				"%s is farther out than %s" % [id, r])
			checked += 1
	assert_true(checked > 20, "tiers were compared (%d)" % checked)
	# Across skills of one profession: a master tier beats another skill's novice.
	var rp: Dictionary = lay["position"]
	assert_true((rp["Archery:master"] as Vector2).length() > (rp["Tracking:novice"] as Vector2).length(), "a deeper node lies farther out")

func _test_centre_disc() -> void:
	var lay := SkillWheelLayout.for_fabric()
	var nodes := SkillWheelLayout.fabric_nodes()
	var centre := 0
	for id: String in nodes:
		var p: Vector2 = lay["position"][id]
		if (nodes[id]["affinity"] as Dictionary).is_empty():
			centre += 1
			assert_true(p.length() <= float(lay["centre_radius"]), "%s has no affinity and sits in the centre disc" % id)
		else:
			assert_true(p.length() > float(lay["centre_radius"]), "%s has an affinity and sits outside the disc" % id)
	assert_true(centre > 0, "the fabric has skills no profession names (%d nodes)" % centre)

func _test_shared_between() -> void:
	var nodes := {
		"A:novice": {"skill": "A", "depth": 0.5, "affinity": {"P": 0.5, "Q": 0.5}, "requires": []},
		"B:novice": {"skill": "B", "depth": 0.5, "affinity": {"P": 1.0}, "requires": []},
		"C:novice": {"skill": "C", "depth": 0.5, "affinity": {}, "requires": []},
	}
	var lay := SkillWheelLayout.layout(["P", "Q", "R", "S"], nodes)
	var pa: Vector2 = lay["position"]["A:novice"]
	var pp: Vector2 = lay["profession_position"]["P"]
	var pq: Vector2 = lay["profession_position"]["Q"]
	var mid := (pp + pq).normalized()
	assert_true(pa.normalized().dot(mid) > 0.9999, "the shared node sits on the bisector of its professions")
	assert_true((lay["position"]["C:novice"] as Vector2).length() < pa.length(), "a node with no affinity is nearer the centre")

func _test_states() -> void:
	var t: Array = SkillTiers.TIER_ORDER
	assert_eq(SkillWheelView.node_state("apprentice", "novice", t), SkillWheelView.STATE_UNLOCKED, "below the player's tier is unlocked")
	assert_eq(SkillWheelView.node_state("apprentice", "apprentice", t), SkillWheelView.STATE_UNLOCKED, "the player's tier is unlocked")
	assert_eq(SkillWheelView.node_state("apprentice", "journeyman", t), SkillWheelView.STATE_AVAILABLE, "the next tier is available")
	assert_eq(SkillWheelView.node_state("apprentice", "master", t), SkillWheelView.STATE_LOCKED, "further tiers are locked")
	assert_eq(SkillWheelView.profession_state(false, ["master"], "master"), SkillWheelView.PROF_LOCKED, "not unlocked is locked")
	assert_eq(SkillWheelView.profession_state(true, ["master", "expert"], "master"), SkillWheelView.PROF_ACTIVE, "unlocked is active")
	assert_eq(SkillWheelView.profession_state(true, ["master", "master"], "master"), SkillWheelView.PROF_MASTERED, "all master is mastered")

func _test_labels() -> void:
	var rows := SkillWheelView.rows({}, {"Blacksmith": true})
	var tiers: Array = SkillTiers.TIER_ORDER
	for r: Dictionary in rows["nodes"]:
		var name := str(r["name"])
		assert_true(name != "" and not tiers.has(name.to_lower()), "node label %s is not a tier" % name)
		assert_true(not GameData.SKILLS.has(name) or name == I18n.content("skill", name), "node label %s is a name, not an id" % name)
		assert_true(not name.contains(":"), "node label %s carries no node id" % name)
	for r: Dictionary in rows["professions"]:
		assert_true(str(r["name"]) != str(r["id"]) or I18n.content("profession", str(r["id"])) == str(r["id"]), "profession %s is named" % r["id"])

func _test_locales() -> void:
	var cats: Dictionary = I18n.parse_csv(I18n.CATALOG_PATH)["catalog"]
	for loc: String in ["en", "pt_BR"]:
		for key: String in NEW_KEYS:
			assert_true((cats[loc] as Dictionary).has(key) and str(cats[loc][key]) != "", "%s has %s" % [loc, key])
