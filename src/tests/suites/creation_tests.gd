extends "res://src/tests/test_support.gd"
## Phase 180 — character creation in the fabric: GameData exposes the creation table, every gender preset and
## hair style resolves to a public placeholder, the name rule accepts and refuses a fixture list (accents,
## emoji, reserved, case-folded, mixed-script and confusable duplicates), a bad gender, hair or colour is
## refused with its own reason, and the chibi presets keep their head ratio. The runtime screen is Phase 181.

const CreationRules := preload("res://src/character/creation_rules.gd")
const CharacterSliceScript := preload("res://src/character/character_slice.gd")


func register() -> void:
	_run_test("creation: GameData exposes the creation table, two genders and a valid default", _test_gamedata_table)
	_run_test("creation: every gender preset and hair option resolves through AssetOverlay in the public build", _test_parts_resolve)
	_run_test("creation: every hair style has an icon", _test_hair_icons)
	_run_test("creation: the name rule accepts letters, accents, one inner separator and other scripts", _test_names_accepted)
	_run_test("creation: the name rule refuses length, digits, emoji, separators, mixed scripts and reserved words", _test_names_refused)
	_run_test("creation: a case-folded, accent-folded or confusable duplicate is taken", _test_names_taken)
	_run_test("creation: a bad gender, hair style or hair colour is refused with its own reason", _test_choices_refused)
	_run_test("creation: the default rig's head-to-height ratio is within the chibi range", _test_head_ratio)
	_run_test("creation: every refusal and gender has a label in every locale", _test_catalog_keys)


func _data() -> Resource:
	return CreationRules.data()


func _test_gamedata_table() -> void:
	var d := _data()
	assert_true(d != null, "GameData.CREATIONS has CharacterCreation")
	if d == null:
		return
	var genders: Dictionary = d.get("genders")
	assert_eq(genders.keys().size(), 2, "two genders")
	for g in genders:
		assert_true(CreationRules.preset(str(g)) != null, "gender %s names an appearance preset" % g)
	var def: Dictionary = d.get("defaultCreation")
	assert_eq(CreationRules.choice_refusal(def), "", "the default creation is valid")
	assert_true((d.get("hairColors") as Array).size() > 0, "a curated colour list")
	for k in d.get("startingKit"):
		assert_true(GameData.ITEMS.has(str(k["item"])), "starting kit item %s exists" % k["item"])


func _exists(rel: String) -> bool:
	return FileAccess.file_exists(AssetOverlay.resolve_path(rel)) and AssetOverlay.resolve_path(rel).begins_with("res://assets/")


func _test_parts_resolve() -> void:
	var d := _data()
	for g in d.get("genders"):
		var app := CreationRules.preset(str(g))
		var body := "models/characters/bodies/%s.glb.raw" % app.get("body")
		var head := "models/characters/heads/%s.glb.raw" % app.get("head")
		var eyes := "textures/characters/eyes/%s.png.raw" % app.get("eyes")
		for key in [body, head, eyes]:
			assert_true(_exists(key), "%s: %s has a public placeholder" % [g, key])
		assert_true(AssetOverlay.has_key("meshes", body) and AssetOverlay.has_key("animations", body), "%s body is in the manifest" % g)
		assert_true(AssetOverlay.load_texture(eyes) != null, "%s eyes decode" % g)
		var hair := str(app.get("hair"))
		assert_eq(str((d.get("hairStyles") as Dictionary).get(hair, {}).get("gender", "")), str(g), "%s preset's default hair is its own" % g)
	for id in d.get("hairStyles"):
		var key := "models/characters/hair/%s.glb.raw" % id
		assert_true(_exists(key) and AssetOverlay.has_key("meshes", key), "hair %s has a public mesh" % id)
	var mesh := AssetOverlay.load_mesh("models/characters/hair/%s.glb.raw" % (d.get("defaultCreation") as Dictionary)["hair"])
	assert_true(mesh != null, "the default hair mesh loads")


func _test_hair_icons() -> void:
	for id in _data().get("hairStyles"):
		var key := "icons/hair/%s.png.raw" % id
		assert_true(_exists(key) and AssetOverlay.has_key("textures", key), "hair %s has an icon" % id)
		var tex := AssetOverlay.load_texture(key)
		assert_true(tex != null and tex.get_width() == 32, "hair %s icon is 32x32" % id)


func _test_names_accepted() -> void:
	for n in ["Alice", "José", "Ana-Maria", "O'Brien", "Mary Ann", "  Bob  ", "Zoëy", "Анна", "Ελένη", "やまだ太郎", "Kim", "Nguye\u0302\u0303n"]:
		assert_eq(CreationRules.name_refusal(n), "", "accepts %s" % n)
	assert_eq(CreationRules.normalize_name("  Bob  "), "Bob", "edges are trimmed")


func _test_names_refused() -> void:
	var cases := {
		"Al": "name_length",
		"Abcdefghijklmnopq": "name_length",
		"Al1ce": "name_chars",
		"Ali\U01F600": "name_chars",
		"Ali_ce": "name_chars",
		"́Ana": "name_chars",
		"Ana\u0301\u0301\u0301": "name_chars",
		"Ana Maria-José": "name_separator",
		"-Ana": "name_separator",
		"Ana-": "name_separator",
		"Ana  Bel": "name_separator",
		"Аlice": "name_script",
		"Aliceα": "name_script",
		"Admin": "name_reserved",
		"ÁDMIN": "name_reserved",
		"Mod": "name_reserved",
	}
	for n in cases:
		assert_eq(CreationRules.name_refusal(n), cases[n], "refuses %s" % n)


func _test_names_taken() -> void:
	var taken := {}
	for n in ["Alice", "Ace", "Ana-Maria", "Marta"]:
		taken[CreationRules.skeleton(n)] = true
	for n in ["alice", "ALICE", "Álice", "Alícé", "Асе", "асе", "Ana Maria", "AnaMaria", "Mada"]:
		var expect := "name_taken" if n != "Mada" else ""
		assert_eq(CreationRules.name_refusal(n, taken), expect, "%s against Alice, Ace, Ana-Maria and Marta" % n)
	# "rn" reads as "m": Marta and "Rnarta" collide.
	assert_eq(CreationRules.name_refusal("Rnarta", taken), "name_taken", "a confusable sequence collides")
	assert_eq(CreationRules.skeleton("Ёлка"), CreationRules.skeleton("Елка"), "ё folds to е")


func _test_choices_refused() -> void:
	var d := _data()
	var ok := { "gender": "masculine", "hair": "hair_m_crop", "hairColor": int((d.get("hairColors") as Array)[0]) }
	assert_eq(CreationRules.choice_refusal(ok), "", "a valid choice")
	var bad := {
		"gender": ok.merged({ "gender": "neuter" }, true),
		"hair": ok.merged({ "hair": "hair_x_afro" }, true),
		"hair_gender": ok.merged({ "hair": "hair_f_bob" }, true),
		"hair_color": ok.merged({ "hairColor": 0 }, true),
	}
	for reason in bad:
		assert_eq(CreationRules.choice_refusal(bad[reason]), reason, "refused with %s" % reason)
	assert_eq(CreationRules.choice_refusal(ok.merged({ "hairColor": "33" }, true)), "hair_color", "a string colour is refused")
	assert_eq(CreationRules.choice_refusal(ok.merged({ "hairColor": 33.5 }, true)), "hair_color", "a fractional colour is refused")
	assert_eq(CreationRules.creation_refusal(ok.merged({ "name": "Al" }, true)), "name_length", "the name is checked first")
	assert_eq(CreationRules.creation_refusal(ok.merged({ "name": "Alice" }, true)), "", "a whole valid creation")


func _test_head_ratio() -> void:
	var d := _data()
	var bounds: Dictionary = d.get("headRatio")
	var cs = CharacterSliceScript.new()
	for g in d.get("genders"):
		var props: Dictionary = cs._normalize_proportions(CreationRules.preset(str(g)).get("proportions"))
		var ratio := CreationRules.head_ratio(props)
		assert_true(ratio >= float(bounds["min"]) and ratio <= float(bounds["max"]),
			"%s head ratio %.3f within %s..%s" % [g, ratio, bounds["min"], bounds["max"]])
	var adult: Dictionary = cs._normalize_proportions(GameData.APPEARANCES["TravellerHuman"].get("proportions"))
	assert_true(CreationRules.head_ratio(adult) < float(bounds["min"]), "an adult traveller is not chibi")
	cs.free()


func _test_catalog_keys() -> void:
	var cats: Dictionary = I18nScript.parse_csv("res://locale/ui.csv")["catalog"]
	var d := _data()
	for loc in ["en", "pt_BR"]:
		var cat: Dictionary = cats.get(loc, {})
		for r in d.get("refusals"):
			assert_true(str(cat.get(CreationRules.refusal_key(str(r)), "")).strip_edges() != "", "%s has %s" % [loc, CreationRules.refusal_key(str(r))])
		for g in d.get("genders"):
			assert_true(str(cat.get(CreationRules.gender_key(str(g)), "")).strip_edges() != "", "%s has %s" % [loc, CreationRules.gender_key(str(g))])
