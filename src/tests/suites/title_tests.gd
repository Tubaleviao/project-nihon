extends "res://src/tests/test_support.gd"
## Phase 273 — titles: a new character holds exactly `Newcomer` and wears it; a profession becoming active and a
## skill (or every skill of a profession) reaching master add their titles once and emit the toast; the host
## refuses a title that is not unlocked and accepts clearing; the choice survives a save; the nameplate shows it
## in the viewer's locale; changing it never changes what a profession-gated recipe does; every string is in
## both catalogs.

const GameRoot := preload("res://src/core/game_root.gd")
const TitleRules := preload("res://src/character/title_rules.gd")
const TitleWiring := preload("res://src/character/title_wiring.gd")
const CreationRules := preload("res://src/character/creation_rules.gd")
const ProfessionSlice := preload("res://src/crafting/profession_slice.gd")

func register() -> void:
	_run_test("titles: a new character has exactly Newcomer unlocked and chosen", _test_new_character)
	_run_test("titles: a profession and a skill master add their titles once and emit the toast", _test_unlocks)
	_run_test("titles: every skill of a profession at master adds its mastered title", _test_profession_master)
	_run_test("titles: a load or join backfills titles for masters reached before titles shipped", _test_backfill)
	_run_test("titles: the host refuses a title not unlocked, accepts another and clearing", _test_choose)
	_run_test("titles: the chosen title survives save and load", _test_persist)
	_run_test("titles: a hostile record or look keeps only known titles", _test_sanitize)
	_run_test("titles: the nameplate shows the title in the viewer's locale", _test_nameplate)
	_run_test("titles: wearing a title never changes a profession-gated recipe", _test_gate)
	_run_test("titles: every new string and title name is in both catalogs", _test_catalog)

func _rig() -> Dictionary:
	var root: GameRoot = GameRoot.new()
	var reg := PlayerRegistry.new()
	reg.is_authoritative = true
	add_child(reg)
	reg.set_local_player("host")
	reg.ensure_player("host")
	reg.ensure_player("p1")
	var cr := CraftingSlice.new()
	cr.player_registry = reg
	add_child(cr)
	root._registry = reg
	root._crafting = cr
	root._is_client = false
	var w := TitleWiring.new()
	w.wire(root)
	return { "root": root, "reg": reg, "w": w, "cr": cr }

func _free_rig(r: Dictionary) -> void:
	r["w"].unwire()
	r["cr"].free()
	r["reg"].free()
	r["root"].free()

func _test_new_character() -> void:
	var r := _rig()
	var rec: Dictionary = r["w"].titles_of("p1")
	assert_eq(TitleRules.unlocked_ids(rec), ["Newcomer"], "exactly Newcomer is unlocked")
	assert_eq(TitleRules.chosen_of(rec), "Newcomer", "and chosen")
	assert_eq(str(r["reg"].look_of("p1")["title"]), "Newcomer", "peers get it in the look")
	_free_rig(r)

func _test_unlocks() -> void:
	var r := _rig()
	var seen: Array = []
	var on := func(pid: String, t: String) -> void: seen.append([pid, t])
	GameBus.title_unlocked.connect(on)
	GameBus.profession_unlocked.emit("p1", "VoidTouched")
	GameBus.profession_unlocked.emit("p1", "VoidTouched")
	assert_eq(seen, [["p1", "VoidTouched"]], "a profession adds its active title once, with one toast")
	r["reg"].record_skill("p1", "Smithing", "master")
	GameBus.skill_tier_recorded.emit("p1", "Smithing", "master")
	GameBus.skill_tier_recorded.emit("p1", "Smithing", "master")
	assert_true(seen.has(["p1", "MasterSmithing"]), "a skill master adds its title")
	assert_eq(seen.count(["p1", "MasterSmithing"]), 1, "once")
	GameBus.skill_tier_recorded.emit("p1", "Archery", "expert")
	assert_false(seen.any(func(s): return s[1] == "MasterArchery"), "a tier below master adds nothing")
	assert_eq(TitleRules.unlocked_ids(r["w"].titles_of("p1")), ["MasterSmithing", "Newcomer", "VoidTouched"], "the record holds them")
	GameBus.title_unlocked.disconnect(on)
	_free_rig(r)

func _test_profession_master() -> void:
	var r := _rig()
	var skills: Array = TitleRules.professions_of_skill("Smithing")["Blacksmith"]
	for i in skills.size():
		r["reg"].record_skill("p1", str(skills[i]), "master")
		GameBus.skill_tier_recorded.emit("p1", str(skills[i]), "master")
		var held: bool = (r["w"].titles_of("p1")["unlocked"] as Dictionary).has("MasterBlacksmith")
		assert_eq(held, i == skills.size() - 1, "the mastered title comes with the last skill (%d of %d)" % [i + 1, skills.size()])
	_free_rig(r)

func _test_backfill() -> void:
	var r := _rig()
	r["reg"].record_skill("p1", "Smithing", "master")
	r["reg"].record_skill("p1", "Archery", "expert")
	assert_eq(TitleRules.unlocked_ids(r["w"].titles_of("p1")), ["Newcomer"], "before: nothing is unlocked")
	var seen: Array = []
	var on := func(pid: String, t: String) -> void: seen.append([pid, t])
	GameBus.title_unlocked.connect(on)
	GameBus.player_joined.emit(2, "p1", false)
	assert_true(seen.has(["p1", "MasterSmithing"]), "a join unlocks and announces the master title already earned")
	assert_false(r["w"].titles_of("p1")["unlocked"].has("MasterArchery"), "a tier below master adds nothing")
	seen.clear()
	assert_eq(r["w"].backfill("p1"), [], "a second pass adds nothing")
	assert_true(seen.is_empty(), "and announces nothing")
	assert_eq(r["w"].backfill("nobody"), [], "an unknown player is skipped")
	GameBus.title_unlocked.disconnect(on)
	_free_rig(r)

func _test_choose() -> void:
	var r := _rig()
	var w: TitleWiring = r["w"]
	var looks: Array = []
	var on := func(pid: String, look: Dictionary) -> void: looks.append([pid, look])
	GameBus.player_look_changed.connect(on)
	assert_eq(w.choose("p1", "MasterSmithing"), "title_locked", "a title not unlocked is refused")
	assert_eq(w.choose("p1", "Nonsense"), "unknown_title", "an unknown title is refused")
	assert_eq(TitleRules.chosen_of(r["w"].titles_of("p1")), "Newcomer", "a refusal changes nothing")
	assert_true(looks.is_empty(), "and tells nobody")
	w.unlock("p1", "MasterSmithing")
	assert_eq(w.choose("p1", "MasterSmithing"), "", "an unlocked one is accepted")
	assert_eq(str(looks.back()[1]["title"]), "MasterSmithing", "and goes out in the look")
	assert_eq(w.choose("p1", ""), "", "clearing is accepted")
	assert_eq(TitleRules.chosen_of(r["w"].titles_of("p1")), "", "to none")
	assert_eq(str(looks.back()[1]["title"]), "", "which peers see")
	GameBus.title_choose_intent.emit("Newcomer", "p1")
	assert_eq(TitleRules.chosen_of(r["w"].titles_of("p1")), "Newcomer", "the intent door wears it again")
	GameBus.title_choose_intent.emit("MasterArchery", "p1")
	assert_eq(TitleRules.chosen_of(r["w"].titles_of("p1")), "Newcomer", "and refuses a locked one")
	GameBus.player_look_changed.disconnect(on)
	_free_rig(r)

func _test_persist() -> void:
	var r := _rig()
	r["w"].unlock("p1", "MasterSmithing")
	r["w"].choose("p1", "MasterSmithing")
	var data: Dictionary = r["reg"].get_player_data("p1")
	var again := PlayerRegistry.new()
	again.is_authoritative = true
	again.apply_player_data("p1", JSON.parse_string(JSON.stringify(data)))
	assert_eq(TitleRules.chosen_of(TitleRules.of_record(again.get_record("p1"))), "MasterSmithing", "the chosen title survives")
	assert_true((TitleRules.of_record(again.get_record("p1"))["unlocked"] as Dictionary).has("MasterSmithing"), "and the unlocked set")
	r["w"].choose("p1", "")
	var none := PlayerRegistry.new()
	none.is_authoritative = true
	none.apply_player_data("p1", JSON.parse_string(JSON.stringify(r["reg"].get_player_data("p1"))))
	assert_eq(TitleRules.chosen_of(TitleRules.of_record(none.get_record("p1"))), "", "wearing none survives too")
	again.free()
	none.free()
	_free_rig(r)

func _test_sanitize() -> void:
	var rec := TitleRules.sanitize({ "unlocked": { "Ghost": true, "MasterSmithing": true, "MasterMining": false }, "chosen": "Ghost" })
	assert_eq(TitleRules.unlocked_ids(rec), ["MasterSmithing", "Newcomer"], "unknown and false entries are dropped")
	assert_eq(TitleRules.chosen_of(rec), "Newcomer", "an unknown chosen title falls back to Newcomer")
	assert_eq(TitleRules.chosen_of(TitleRules.sanitize({ "unlocked": {}, "chosen": "MasterSmithing" })), "Newcomer", "a title not held is not worn")
	assert_eq(TitleRules.sanitize("junk"), TitleRules.sanitize({}), "junk reads as a new character")
	assert_eq(CreationRules.sanitize_look({ "name": "Akira", "title": "Ghost" }), { "name": "Akira" }, "a look with an unknown title drops it")
	assert_eq(CreationRules.sanitize_look({ "name": "Akira", "title": "MasterSmithing" })["title"], "MasterSmithing", "a known one is kept")

func _test_nameplate() -> void:
	var prev := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	assert_eq(TitleRules.nameplate("Akira", "MasterSmithing"), "Akira\nMaster Smith", "en")
	TranslationServer.set_locale("pt_BR")
	assert_eq(TitleRules.nameplate("Akira", "MasterSmithing"), "Akira\nMestre Forjador", "pt_BR")
	TranslationServer.set_locale(prev)
	assert_eq(TitleRules.nameplate("Akira", ""), "Akira", "no title, just the name")

func _test_gate() -> void:
	var r := _rig()
	var prof := ProfessionSlice.new()
	prof.player_registry = r["reg"]
	add_child(prof)
	r["cr"].profession_slice = prof
	var recipe := { "profession": "Blacksmith" }
	var before: String = r["cr"]._check_profession_gate(recipe, "p1")
	assert_eq(before, "requires_profession:Blacksmith", "gated before")
	r["w"].unlock("p1", "Blacksmith")
	r["w"].choose("p1", "Blacksmith")
	assert_eq(r["cr"]._check_profession_gate(recipe, "p1"), before, "wearing the Blacksmith title does not open it")
	r["w"].choose("p1", "")
	assert_eq(r["cr"]._check_profession_gate(recipe, "p1"), before, "nor does clearing it change it")
	prof._unlocked_for("p1")["Blacksmith"] = true
	assert_eq(r["cr"]._check_profession_gate(recipe, "p1"), "", "the unlocked profession opens it, whatever the title")
	prof.free()
	_free_rig(r)

func _test_catalog() -> void:
	for key in ["ui.title_unlocked_toast", "ui.title_none", "ui.title_tooltip"]:
		assert_true(I18nScript.has_key(key), "%s is in the catalog" % key)
	for id in TitleRules.table():
		assert_true(I18nScript.has_content("title", str(id)), "title %s has a name" % id)
