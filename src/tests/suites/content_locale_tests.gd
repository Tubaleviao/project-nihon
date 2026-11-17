extends "res://src/tests/test_support.gd"
## Phase 267 — names a player can read: `locale/content.csv` and `I18n.content`. Every content key resolves in
## every locale, switching the locale changes what a window shows, a missing key is never the bare id, host
## messages carry content refs each client names itself, and no label in the crafting, technology or skills
## window is an entity id.

const I18n := preload("res://src/core/i18n.gd")
const StationSliceScript := preload("res://src/world/station_slice.gd")
const WritingRules := preload("res://src/technology/writing_rules.gd")
const AttributeRules := preload("res://src/character/attribute_rules.gd")

func register() -> void:
	_run_test("content locale: every content key has text in en and pt_BR, once, and none is also a UI key", _test_catalog_complete)
	_run_test("content locale: every fabric item, material, recipe, technology, skill, profession and station resolves in en and pt_BR", _test_every_entity_resolves)
	_run_test("content locale: switching the locale changes a recipe's shown name", _test_locale_switch_changes_recipe_name)
	_run_test("content locale: a missing key shows a debug marker or Unknown, never the bare id", _test_missing_key)
	_run_test("content locale: host messages and reasons name content in the reader's locale", _test_refs_and_reasons)
	_run_test("content locale: no label in the crafting, technology or skills window is an entity id", _test_window_audit)

func _with_locale(locale: String, fn: Callable) -> void:
	var before := TranslationServer.get_locale()
	TranslationServer.set_locale(locale)
	fn.call()
	TranslationServer.set_locale(before)

func _test_catalog_complete() -> void:
	var parsed := I18n.parse_csv(I18n.CONTENT_PATH)
	assert_true(int(parsed["rows"]) > 200, "the content catalog is loaded (%d rows)" % int(parsed["rows"]))
	assert_true((parsed["locales"] as Array).has("en") and (parsed["locales"] as Array).has("pt_BR"), "it has en and pt_BR columns")
	assert_eq(parsed["empty"], [], "no content cell is empty")
	assert_eq(parsed["dupes"], [], "no content key is listed twice")
	var ui_keys: Dictionary = I18n.parse_csv(I18n.CATALOG_PATH)["catalog"]["en"]
	for key: String in parsed["catalog"]["en"]:
		assert_false(ui_keys.has(key), "%s lives in one catalog only" % key)
		var kind := key.get_slice(".", 0)
		assert_true(I18n.CONTENT_KINDS.has(kind), "%s has a known kind" % key)
	for loc: String in ["en", "pt_BR"]:
		_with_locale(loc, func() -> void:
			for key: String in parsed["catalog"][loc]:
				assert_eq(I18n.t(key), str(parsed["catalog"][loc][key]), "%s resolves in %s" % [key, loc]))

## The ids the game can show, by kind (what the fabric gate also checks, read from GameData).
static func entity_ids() -> Dictionary:
	var items: Array = GameData.ITEMS.keys() + GameData.MATERIALS.keys()
	var st := StationSliceScript.new()
	var stations: Array = st.placeable_station_types()
	st.free()
	return {
		"item": items,
		"recipe": GameData.RECIPES.keys(),
		"tech": GameData.TECHNOLOGIES.keys(),
		"skill": GameData.SKILLS.keys(),
		"profession": GameData.PROFESSIONS.keys(),
		"station": stations,
		"category": AttributeRules.skill_categories(),   # Phase 274
	}

func _test_every_entity_resolves() -> void:
	var ids := entity_ids()
	assert_true((ids["station"] as Array).size() >= 7, "the placeable stations are listed")
	for loc: String in ["en", "pt_BR"]:
		_with_locale(loc, func() -> void:
			for kind: String in ids:
				for id in ids[kind]:
					var name := I18n.content(kind, str(id))
					assert_false(name.contains("⟨") or name == I18n.t(I18n.CONTENT_UNKNOWN_KEY), "%s %s has a %s name (%s)" % [kind, id, loc, name])
			for id in GameData.ITEMS.keys() + GameData.MATERIALS.keys():
				assert_true(I18n.has_content("item", str(id), "desc"), "item %s has a description" % id))

func _test_locale_switch_changes_recipe_name() -> void:
	var names := {}
	for loc: String in ["en", "pt_BR"]:
		_with_locale(loc, func() -> void: names[loc] = I18n.content("recipe", "RecipeFerritePick"))
	assert_eq(names["en"], "Ferrite Pick", "a recipe takes its output's name in en")
	assert_eq(names["pt_BR"], "Picareta de Ferrita", "and in pt_BR")
	_with_locale("pt_BR", func() -> void:
		assert_eq(I18n.content("recipe", "RecipeHealthPotion"), "Poção de Vida", "a recipe's own name wins over its output's"))
	# The crafting window itself shows the switched name.
	var ui := _new_test_ui()
	var craft := CraftingSlice.new()
	add_child(craft)
	ui.crafting_slice = craft
	var content := ui._build_crafting_content()
	var shown := {}
	for loc: String in ["en", "pt_BR"]:
		_with_locale(loc, func() -> void:
			ui.refresh_crafting()
			shown[loc] = _texts(ui._crafting_box).filter(func(s: String) -> bool: return s.begins_with(str(names[loc]) + ":")).size())
	assert_true(int(shown["en"]) >= 1, "the en crafting window lists Ferrite Pick")
	assert_true(int(shown["pt_BR"]) >= 1, "the pt_BR crafting window lists Picareta de Ferrita")
	_free_window(content)
	craft.free()
	ui.free()

func _test_missing_key() -> void:
	var was := I18n.release_names
	I18n.release_names = false
	assert_eq(I18n.content("item", "NoSuchThing"), "⟨NoSuchThing⟩", "a debug build marks a missing name visibly")
	I18n.release_names = true
	_with_locale("en", func() -> void: assert_eq(I18n.content("item", "NoSuchThing"), "Unknown", "a release build shows Unknown"))
	_with_locale("pt_BR", func() -> void: assert_eq(I18n.content("tech", "NoSuchThing"), "Desconhecido", "in the reader's locale"))
	I18n.release_names = was
	assert_eq(I18n.content_key("station", "master forge"), "station.master_forge.name", "station types key with underscores")

func _test_refs_and_reasons() -> void:
	var m := I18n.sanitize_msg("chat.admin_gave", [2, I18n.ref("item", "FerriteIngot")])
	_with_locale("pt_BR", func() -> void:
		assert_eq(I18n.render(m), I18n.t("chat.admin_gave", [2, "Lingote de Ferrita"]), "a host message's item ref is named by the reader"))
	_with_locale("en", func() -> void:
		assert_eq(I18n.render(m), I18n.t("chat.admin_gave", [2, "Ferrite Ingot"]), "in either locale"))
	var cut := TechnologySlice._outputs_arg(["StoneAxe", "StonePick", "StoneShovel", "StoneKnife", "StoneHammer", "StoneAxe", "StonePick"])
	assert_true(cut.length() <= I18n.MAX_ARG_LEN, "the outputs ref fits a message")
	_with_locale("en", func() -> void:
		var shown := str(I18n.resolve_arg(cut))
		assert_true(shown.begins_with("Stone Axe, Stone Pick") and shown.ends_with(" …"), "a cut list names what fits, then … (%s)" % shown)
		assert_eq(I18n.resolve_arg("§nokind:X"), "§nokind:X", "an unknown kind is left as it came")
		assert_eq(I18n.resolve_arg("plain"), "plain", "a plain arg is untouched")
		assert_eq(I18n.resolve_arg(I18n.ref("project", "palisade")), I18n.t("settlement.project.palisade"), "a blueprint's project is named"))
	_with_locale("pt_BR", func() -> void:
		assert_eq(I18n.reason_text("station_required:master forge"), I18n.t("reason.station_required", ["forja mestra"]), "a reason names its station")
		assert_eq(I18n.reason_text("requires_profession:Blacksmith"), I18n.t("reason.requires_profession", ["Ferreiro"]), "and its profession")
		var w := WritingRules.of("BookTechBasicSmithing")
		assert_eq(I18n.resolve_arg(WritingRules.teaches_arg(w)), "Ferraria Básica", "a writing notice names what it teaches"))

## Every Label/Button text and tooltip under `root`, skipping rows already queued for deletion.
func _texts(root: Node) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.is_queued_for_deletion():
			continue  # a row the last refresh replaced (no frame has freed it yet)
		if n is Label:
			out.append((n as Label).text)
		elif n is Button:
			out.append((n as Button).text)
		if n is Control and (n as Control).tooltip_text != "":
			out.append((n as Control).tooltip_text)
		stack.append_array(n.get_children())
	return out

## A built window and everything under it (rows a refresh queued for deletion included: no frames pass).
func _free_window(root: Node) -> void:
	root.free()

func _test_window_audit() -> void:
	var ids := entity_ids()
	var ui := _new_test_ui()
	var inv := InventorySlice.new()
	add_child(inv)
	var craft := CraftingSlice.new()
	add_child(craft)
	var tech := TechnologySlice.new()
	add_child(tech)
	ui.inventory_slice = inv
	ui.crafting_slice = craft
	ui.technology_slice = tech
	for skill in GameData.SKILLS.keys():
		craft.set_skill(str(skill), "novice")
	var windows := [ui._build_crafting_content(), ui._build_technology_content(), ui._build_skills_content()]
	for loc: String in ["en", "pt_BR"]:
		_with_locale(loc, func() -> void:
			ui.refresh_crafting()
			ui.refresh_technology()
			ui._skills_signature = 0
			ui._refresh_skills()
			# An id may also be its own English name ("Ferrite", "Bed"); only an id the locale names otherwise
			# ("FerritePick" is "Ferrite Pick") betrays a raw id when it shows up as a word.
			var raw := {}
			for kind: String in ids:
				for id in ids[kind]:
					if I18n.content(kind, str(id)) != str(id):
						raw[str(id)] = kind
			var labels := 0
			for w: Node in windows:
				for text: String in _texts(w):
					labels += 1
					assert_false(text.contains("⟨"), "%s: no missing-name marker in '%s'" % [loc, text])
					assert_false(raw.has(text.strip_edges()), "%s: a label is the id '%s'" % [loc, text])
					for word in text.split(" ", false):
						var token := word.strip_edges().trim_suffix(",").trim_suffix(":").trim_suffix(".")
						assert_false(raw.has(token), "%s: '%s' shows the %s id %s" % [loc, text, raw.get(token, ""), token])
			assert_true(labels > GameData.RECIPES.size(), "%s: the audit read the windows (%d labels)" % [loc, labels]))
	for w: Node in windows:
		_free_window(w)
	inv.free()
	craft.free()
	tech.free()
	ui.free()
