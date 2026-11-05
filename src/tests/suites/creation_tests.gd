extends "res://src/tests/test_support.gd"
## Phase 180 — character creation in the fabric: GameData exposes the creation table, every gender preset and
## hair style resolves to a public placeholder, the name rule accepts and refuses a fixture list (accents,
## emoji, reserved, case-folded, mixed-script and confusable duplicates), a bad gender, hair or colour is
## refused with its own reason, and the chibi presets keep their head ratio. The runtime screen is Phase 181.

const CreationRules := preload("res://src/character/creation_rules.gd")
const CharacterSliceScript := preload("res://src/character/character_slice.gd")
const CharacterMaterial := preload("res://src/character/character_material.gd")


func register() -> void:
	_run_test("creation: GameData exposes the creation table, two genders and a valid default", _test_gamedata_table)
	_run_test("creation: every gender preset and hair option resolves through AssetOverlay in the public build", _test_parts_resolve)
	_run_test("creation: every hair style has an icon", _test_hair_icons)
	_run_test("creation: Phase 215 each body binds its own sheets and a body without sheets binds the player sheets", _test_body_sheet_binding)
	_run_test("creation: Phase 215 skin colour drives the base index the colour mask shows through, on both genders", _test_body_skin_through_mask)
	_run_test("creation: Phase 215 the novice outfit region is inside the sheet and documented", _test_novice_region)
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
		for sheet in CharacterMaterial.body_sheet_keys(str(app.get("body"))):
			assert_true(_exists(sheet) and AssetOverlay.has_key("textures", sheet), "%s body sheet %s is public and in the manifest" % [g, sheet])
			var tex := AssetOverlay.load_texture(sheet)
			assert_true(tex != null and tex.get_width() == 64 and tex.get_height() == 64, "%s decodes at 64x64" % sheet)
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


func _rig_mat(ch: CharacterSlice, iid: String) -> ShaderMaterial:
	var meshes: Array = ch._instances[iid]["rig_node"].find_children("*", "MeshInstance3D", true, false)
	assert_true(meshes.size() > 0, "the rig has a mesh")
	return (meshes[0] as MeshInstance3D).material_override as ShaderMaterial


func _test_body_sheet_binding() -> void:
	var ch := CharacterSliceScript.new()
	add_child(ch)
	var mats: Dictionary = {}
	for body in ["chibi_body_m", "chibi_body_f"]:
		var iid := ch.create_character_from_recipe({"skeleton": "HumanoidSkeleton", "body": body}, Vector3.ZERO)
		assert_true(ch.attach_rig(iid, "models/player_rig.glb.raw"), "%s rig attaches" % body)
		var mat := _rig_mat(ch, iid)
		mats[body] = mat
		var keys := CharacterMaterial.body_sheet_keys(body)
		for pair in [["detail_tex", keys[0]], ["color_mask_tex", keys[1]], ["channel_tex", keys[2]]]:
			var tex := mat.get_shader_parameter(pair[0]) as Texture2D
			assert_true(tex != null and AssetOverlay.has_key("textures", pair[1]), "%s binds %s" % [body, pair[1]])
			assert_true(tex == AssetOverlay.load_texture(pair[1]) or tex.get_width() == 64, "%s is the body's own 64x64 sheet" % pair[0])
	assert_true(mats["chibi_body_m"] != mats["chibi_body_f"], "each body keeps its own material")
	assert_true(mats["chibi_body_m"].get_shader_parameter("detail_tex") != mats["chibi_body_f"].get_shader_parameter("detail_tex"),
		"the two bodies bind different detail textures")
	# A body with no sheets falls back to the player sheets.
	var other := ch.create_character_from_recipe({"skeleton": "HumanoidSkeleton", "body": "no_such_body"}, Vector3.ZERO)
	assert_true(ch.attach_rig(other, "models/player_rig.glb.raw"), "a body without sheets still attaches")
	var fb := _rig_mat(ch, other)
	assert_eq(fb, CharacterMaterial.rig_material(ch._palette_colors()), "a body without sheets uses the player rig material")
	assert_eq(fb.get_shader_parameter("detail_tex"), ch._rig_detail, "it binds the player detail sheet")
	assert_eq(fb.get_shader_parameter("color_mask_tex"), ch._rig_color_mask, "it binds the player colour mask")
	assert_eq(fb.get_shader_parameter("channel_tex"), ch._rig_channel, "it binds the player channel sheet")
	ch.free()


func _test_body_skin_through_mask() -> void:
	var ch := CharacterSliceScript.new()
	add_child(ch)
	for body in ["chibi_body_m", "chibi_body_f"]:
		var seen: Array = []
		for skin in [10, 77]:
			var iid := ch.create_character_from_recipe({"skeleton": "HumanoidSkeleton", "body": body, "skinColor": skin}, Vector3.ZERO)
			assert_true(ch.attach_rig(iid, "models/player_rig.glb.raw"), "%s rig attaches" % body)
			var meshes: Array = ch._instances[iid]["rig_node"].find_children("*", "MeshInstance3D", true, false)
			seen.append(int((meshes[0] as MeshInstance3D).get_instance_shader_parameter("base_index")))
		assert_eq(seen, [10, 77], "%s: skin colour sets the base index the mask shows through" % body)
		# The mask is the public black one: every pixel keeps the base (skin) colour.
		var mask := AssetOverlay.load_texture(CharacterMaterial.body_sheet_keys(body)[1])
		var img := mask.get_image()
		assert_eq(img.get_pixel(5, 30).r + img.get_pixel(5, 30).g + img.get_pixel(5, 30).b, 0.0, "%s: public mask is black, skin shows" % body)
	ch.free()


func _test_novice_region() -> void:
	var r := CharacterMaterial.NOVICE_OUTFIT_REGION
	assert_true(Rect2i(0, 0, 64, 64).encloses(r) and r.size.x > 0 and r.size.y > 0, "the novice region lies inside the 64x64 sheet")
	var needle := "x 0–63, y 20–51"
	for path in ["res://assets/README.md", "res://characters.md"]:
		var f := FileAccess.open(path, FileAccess.READ)
		assert_true(f != null and f.get_as_text().contains(needle), "%s documents the novice outfit region" % path)
