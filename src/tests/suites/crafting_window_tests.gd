extends "res://src/tests/test_support.gd"
## Phase 269 — crafting by hand, and at the station. The hand window lists exactly the known recipes with no
## station; a station's window exactly that station's known recipes, titled with its name, and it closes when the
## player leaves the station's reach. The host still refuses a station recipe with no station in reach. Cards
## show have/need counts that follow the bag, are dimmed (not hidden) when short, never show an entity id, and
## sort into category tabs and a search. Every new string is in both locales.

const CraftCatalog := preload("res://src/crafting/craft_catalog.gd")
const CraftWindow := preload("res://src/ui/craft_window.gd")
const I18n := preload("res://src/core/i18n.gd")

const NEW_KEYS := ["win.station", "craft.search", "craft.cat.all", "craft.cat.tools", "craft.cat.weapons", "craft.cat.armor",
	"craft.cat.building", "craft.cat.consumables", "craft.cat.materials", "craft.card_count", "craft.card_refused",
	"craft.have_need", "craft.work_time", "craft.work_instant", "craft.trains", "craft.trains_none", "craft.quantity",
	"craft.pick", "craft.none", "controls.row18"]

func register() -> void:
	_run_test("crafting window: the hand window lists exactly the known recipes with no station", _test_hand_lists_stationless_known)
	_run_test("crafting window: a station's window lists exactly that station's known recipes", _test_station_lists_its_recipes)
	_run_test("crafting window: the interact input opens a crafting station's window, titled with its name; a chest keeps its own", _test_open_station_window)
	_run_test("crafting window: the station window closes when the player leaves the station's reach", _test_station_window_closes_out_of_reach)
	_run_test("crafting window: the host refuses a station recipe with no station in reach", _test_host_refuses_without_station)
	_run_test("crafting window: a card's have/need counts follow the bag, short is red and the card dimmed", _test_have_need_follows_bag)
	_run_test("crafting window: no card or detail shows an entity id, in en or pt_BR", _test_no_entity_ids)
	_run_test("crafting window: every recipe has a category; tabs and the search filter the grid", _test_categories_and_search)
	_run_test("crafting window: the Craft button asks for the chosen quantity, at most what the bag pays for", _test_craft_quantity)
	_run_test("crafting window: every new string is in both locales", _test_new_strings_in_both_locales)

# ── rig ──────────────────────────────────────────────────────────────────

## A UI wired to an inventory, a crafting slice, a technology slice and a station slice.
func _rig(with_tech: bool = true) -> Dictionary:
	var ui := _new_test_ui()
	var inv := InventorySlice.new()
	add_child(inv)
	inv._max_slots = 1000
	inv._max_weight = 1000000.0
	var craft := CraftingSlice.new()
	add_child(craft)
	var station := StationSlice.new()
	add_child(station)
	var tech: TechnologySlice = null
	craft.inventory_slice = inv
	craft.station_slice = station
	if with_tech:
		tech = TechnologySlice.new()
		add_child(tech)
		tech.inventory_slice = inv
		craft.technology_slice = tech
		ui.technology_slice = tech
	ui.inventory_slice = inv
	ui.crafting_slice = craft
	ui.station_slice = station
	station.set_player_position(Vector3.ZERO)
	return { "ui": ui, "inv": inv, "craft": craft, "tech": tech, "station": station }

func _free(rig: Dictionary) -> void:
	for k in ["ui", "inv", "craft", "tech", "station"]:
		if rig[k] != null:
			rig[k].free()

func _ids(cards: Array) -> Array:
	var out: Array = cards.map(func(c: Dictionary) -> String: return str(c["id"]))
	out.sort()
	return out

## The recipes needing `type`, read straight from the fabric (not through CraftCatalog), that `known` accepts.
func _fabric_recipes(type: String, known: Callable) -> Array:
	var out: Array = []
	for rid in GameData.RECIPES:
		var res: Resource = GameData.RECIPES[rid]
		var rec: Variant = res.get("recipe")
		if rec is Dictionary and str((rec as Dictionary).get("station", "")) == type and bool(known.call(str(rid))):
			out.append(str(rid))
	out.sort()
	return out

func _card(cards: Array, id: String) -> Dictionary:
	for c: Dictionary in cards:
		if str(c["id"]) == id:
			return c
	return {}

func _input_of(card: Dictionary, item: String) -> Dictionary:
	for e: Dictionary in card.get("inputs", []):
		if str(e["item"]) == item:
			return e
	return {}

## Every Label/Button/LineEdit text and tooltip under `root`, skipping nodes queued for deletion.
func _texts(root: Node) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.is_queued_for_deletion():
			continue
		if n is Label:
			out.append((n as Label).text)
		elif n is Button:
			out.append((n as Button).text)
		if n is Control and (n as Control).tooltip_text != "":
			out.append((n as Control).tooltip_text)
		if n is TabBar:
			for i in (n as TabBar).tab_count:
				out.append((n as TabBar).get_tab_title(i))
		stack.append_array(n.get_children())
	return out

## An id that is also its own name in the active locale ("Ferrite", "Bed") is not a leaked id.
func _own_name(id: String) -> bool:
	for kind: String in ["item", "recipe", "skill"]:
		if I18n.has_content(kind, id) and I18n.content(kind, id) == id:
			return true
	return false

func _live_children(n: Node) -> Array:
	return n.get_children().filter(func(c: Node) -> bool: return not c.is_queued_for_deletion())

# ── tests ────────────────────────────────────────────────────────────────

func _test_hand_lists_stationless_known() -> void:
	var rig := _rig()
	var ui: UiSlice = rig["ui"]
	var tech: TechnologySlice = rig["tech"]
	var known := func(rid: String) -> bool: return tech.is_recipe_unlocked(rid)
	assert_eq(_ids(ui.craft_cards("")), _fabric_recipes("", known), "a fresh player: the hand window lists the known station-less recipes")
	assert_false(_ids(ui.craft_cards("")).has("RecipeStoneAxe"), "a recipe whose technology is not known is hidden")
	assert_eq(tech.learn("technology", "TechStoneTools"), "", "the stone tools are learnt")
	var hand := _ids(ui.craft_cards(""))
	assert_eq(hand, _fabric_recipes("", known), "after learning: still exactly the known station-less recipes")
	assert_true(hand.has("RecipeStoneAxe") and hand.has("RecipeCarpentryBench"), "the learnt hand recipes are listed")
	for rid: String in hand:
		assert_eq(CraftCatalog.station_of(rid), "", "%s needs no station" % rid)
	# The window's grid shows one card per listed recipe.
	ui.refresh_crafting()
	assert_eq(_live_children(ui.hand_window.grid).size(), hand.size(), "one card per hand recipe in the grid")
	# Unaffordable known recipes are listed (dimmed), not hidden.
	assert_false(bool(_card(ui.craft_cards(""), "RecipeStoneAxe")["can_craft"]), "an empty bag cannot make a stone axe")
	_free(rig)

func _test_station_lists_its_recipes() -> void:
	var rig := _rig()
	var ui: UiSlice = rig["ui"]
	var tech: TechnologySlice = rig["tech"]
	var known := func(rid: String) -> bool: return tech.is_recipe_unlocked(rid)
	var types := CraftCatalog.crafting_station_types()
	assert_true(types.has("forge") and types.has("carpentry bench"), "the forge and the carpentry bench are crafting stations")
	assert_false(types.has("chest") or types.has("bed") or types.has("door"), "a chest, bed or door lists no recipes")
	for type: String in types:
		assert_eq(_ids(ui.craft_cards(type)), _fabric_recipes(type, known), "%s lists exactly its known recipes" % type)
	assert_false(_ids(ui.craft_cards("forge")).has("RecipeFerriteIngot"), "the ingot is hidden before smithing is known")
	assert_eq(tech.learn("technology", "TechBasicSmithing"), "", "basic smithing is learnt")
	var forge := _ids(ui.craft_cards("forge"))
	assert_true(forge.has("RecipeFerriteIngot"), "then the forge lists the ingot")
	assert_eq(forge, _fabric_recipes("forge", known), "and still exactly its known recipes")
	assert_false(forge.has("RecipeThornwoodPlank") or forge.has("RecipeStoneAxe"), "no other station's or hand recipe")
	_free(rig)
	# With every recipe known (no technology slice), each station lists every recipe naming it.
	var all := _rig(false)
	var every := func(_rid: String) -> bool: return true
	for type: String in [""] + CraftCatalog.crafting_station_types():
		assert_eq(_ids((all["ui"] as UiSlice).craft_cards(type)), _fabric_recipes(type, every), "all known: %s" % (type if type != "" else "hand"))
	_free(all)

func _test_open_station_window() -> void:
	var rig := _rig(false)
	var ui: UiSlice = rig["ui"]
	var st: StationSlice = rig["station"]
	var forge := st.place_station("forge", Vector3(2.0, 0.0, 0.0))
	var chest := st.place_station("chest", Vector3(0.0, 0.0, 6.0))
	assert_false(ui.is_window_open(UiSlice.WINDOW_STATION), "closed at first")
	ui.open_window(UiSlice.WINDOW_STATION)
	assert_false(ui.is_window_open(UiSlice.WINDOW_STATION), "no station, no station window")
	assert_false(ui.open_station_window(chest), "a chest has no station window")
	GameBus.station_window_requested.emit(forge)
	assert_true(ui.is_window_open(UiSlice.WINDOW_STATION), "the interact request opens the forge's window")
	assert_eq(ui.station_type, "forge", "for the forge")
	assert_eq(_ids(ui.station_window.cards()), _ids(ui.craft_cards("forge")), "listing the forge's recipes")
	var title := str(ui._panels[UiSlice.WINDOW_STATION].find_children("*", "Label", true, false)[0].text)
	for loc: String in ["en", "pt_BR"]:
		var before := TranslationServer.get_locale()
		TranslationServer.set_locale(loc)
		ui._retitle("win.station")
		title = str(ui._panels[UiSlice.WINDOW_STATION].find_children("*", "Label", true, false)[0].text)
		assert_eq(title, I18n.content("station", "forge"), "%s: the window is titled with the station's name" % loc)
		TranslationServer.set_locale(before)
	ui.close_window(UiSlice.WINDOW_STATION)
	assert_eq(ui.station_id, "", "closing forgets the station")
	# The interact rule: the nearest station within reach, and only a crafting station opens a window.
	var stations := st.get_all_stations()
	assert_eq(CraftCatalog.interact_station(stations, Vector3(1.5, 0.0, 0.0)), forge, "beside the forge: the forge")
	assert_eq(CraftCatalog.interact_station(stations, Vector3(0.0, 0.0, 5.5)), "", "beside the chest: the chest keeps its interaction")
	assert_eq(CraftCatalog.interact_station(stations, Vector3(40.0, 0.0, 0.0)), "", "nothing in reach: nothing opens")
	var bench := st.place_station("carpentry bench", Vector3(0.0, 0.0, 5.0))
	assert_eq(CraftCatalog.interact_station(st.get_all_stations(), Vector3(0.0, 0.0, 4.5)), bench, "the bench nearer than the chest opens")
	_free(rig)

func _test_station_window_closes_out_of_reach() -> void:
	var rig := _rig(false)
	var ui: UiSlice = rig["ui"]
	var st: StationSlice = rig["station"]
	var forge := st.place_station("forge", Vector3(10.0, 0.0, 10.0))
	assert_true(ui.open_station_window(forge), "the forge's window opens")
	assert_false(ui.check_station_reach(Vector3(12.0, 0.0, 10.0)), "2 m away it stays open")
	assert_true(ui.is_window_open(UiSlice.WINDOW_STATION), "open within reach")
	var edge := Vector3(10.0 + CraftingSlice.STATION_RADIUS - 0.1, 0.0, 10.0)
	assert_false(ui.check_station_reach(edge), "just inside the host's crafting radius it stays open")
	assert_true(ui.check_station_reach(Vector3(10.0 + CraftingSlice.STATION_RADIUS + 0.5, 0.0, 10.0)), "past the radius it closes")
	assert_false(ui.is_window_open(UiSlice.WINDOW_STATION), "closed out of reach")
	# A station taken away closes its window too.
	assert_true(ui.open_station_window(forge), "reopened")
	st.remove_station(forge)
	assert_true(ui.check_station_reach(Vector3(10.0, 0.0, 10.0)), "a removed station closes its window")
	_free(rig)

func _test_host_refuses_without_station() -> void:
	var rig := _rig(false)
	var craft: CraftingSlice = rig["craft"]
	var st: StationSlice = rig["station"]
	var inv: InventorySlice = rig["inv"]
	inv.add_item("Thornwood", 4)
	craft.set_skill("Carpentry", "novice")
	var where := { "p1": Vector3.ZERO }
	craft.position_of = func(pid: String) -> Variant: return where.get(pid, null)
	var away := craft.craft("RecipeThornwoodPlank", "p1")
	assert_false(bool(away["success"]), "no bench in reach: refused")
	assert_eq(str(away["reason"]), "station_required:carpentry bench", "with the station it needs")
	assert_eq(inv.get_item_count("Thornwood"), 4, "nothing consumed")
	st.place_station("carpentry bench", Vector3(30.0, 0.0, 0.0))
	assert_eq(str(craft.craft("RecipeThornwoodPlank", "p1")["reason"]), "station_required:carpentry bench", "a bench out of reach changes nothing")
	where["p1"] = Vector3(29.0, 0.0, 0.0)
	var at := craft.craft("RecipeThornwoodPlank", "p1")
	assert_true(bool(at["success"]), "at the bench the same request passes (%s)" % str(at["reason"]))
	assert_eq(inv.get_item_count("ThornwoodPlank"), 3, "and makes the planks")
	_free(rig)

func _test_have_need_follows_bag() -> void:
	var rig := _rig(false)
	var ui: UiSlice = rig["ui"]
	var inv: InventorySlice = rig["inv"]
	var craft: CraftingSlice = rig["craft"]
	craft.set_skill("Carpentry", "novice")
	var card := _card(ui.craft_cards(""), "RecipeStonePick")
	assert_false(card.is_empty(), "the stone pick is a hand card")
	assert_eq([int(_input_of(card, "Branch")["have"]), int(_input_of(card, "Branch")["need"])], [0, 1], "no branch: 0/1")
	assert_true(bool(_input_of(card, "LooseStone")["short"]), "no stone: short")
	assert_false(bool(card["can_craft"]), "an empty bag cannot make it")
	inv.add_item("Branch", 1)
	inv.add_item("LooseStone", 1)
	card = _card(ui.craft_cards(""), "RecipeStonePick")
	assert_eq([int(_input_of(card, "Branch")["have"]), bool(_input_of(card, "Branch")["short"])], [1, false], "one branch: 1/1, not short")
	assert_eq([int(_input_of(card, "LooseStone")["have"]), int(_input_of(card, "LooseStone")["need"]), bool(_input_of(card, "LooseStone")["short"])], [1, 2, true], "one stone: 1/2, short")
	assert_eq(int(card["max_quantity"]), 0, "the bag pays for none")
	# The window: the card is dimmed, the short input is red.
	ui.refresh_crafting()
	ui.hand_window.select("RecipeStonePick")
	var dimmed := false
	for b: Node in _live_children(ui.hand_window.grid):
		if (b as Button).text == str(card["name"]):
			dimmed = (b as Button).modulate.a < 1.0
	assert_true(dimmed, "the unaffordable card is dimmed")
	var red := 0
	for lbl: Node in ui.hand_window.detail.find_children("*", "Label", true, false):
		if not lbl.is_queued_for_deletion() and (lbl as Label).text == I18n.t("craft.have_need", [1, 2]):
			red += 1 if (lbl as Label).modulate == CraftWindow.SHORT_COLOR else 0
	assert_eq(red, 1, "the stone count 1/2 is red")
	assert_true(ui.hand_window.craft_button.disabled, "and Craft is disabled")
	inv.add_item("Branch", 2)
	inv.add_item("LooseStone", 5)
	card = _card(ui.craft_cards(""), "RecipeStonePick")
	assert_eq([int(_input_of(card, "Branch")["have"]), int(_input_of(card, "LooseStone")["have"])], [3, 6], "the counts follow the bag")
	assert_true(bool(card["can_craft"]), "now it can be made")
	assert_eq(int(card["max_quantity"]), 3, "three times (three branches, six stones)")
	ui.refresh_crafting()
	assert_false(ui.hand_window.craft_button.disabled, "Craft is enabled")
	_free(rig)

func _test_no_entity_ids() -> void:
	var rig := _rig(false)
	var ui: UiSlice = rig["ui"]
	for skill in GameData.SKILLS.keys():
		(rig["craft"] as CraftingSlice).set_skill(str(skill), "novice")
	var raw := {}
	for id in GameData.ITEMS.keys() + GameData.MATERIALS.keys() + GameData.RECIPES.keys() + GameData.SKILLS.keys():
		raw[str(id)] = true
	var st: StationSlice = rig["station"]
	var forge := st.place_station("forge", Vector3.ZERO)
	ui.open_station_window(forge)
	for loc: String in ["en", "pt_BR"]:
		var before := TranslationServer.get_locale()
		TranslationServer.set_locale(loc)
		var seen := 0
		for type: String in [""] + CraftCatalog.crafting_station_types():
			for card: Dictionary in ui.craft_cards(type):
				seen += 1
				var names: Array = [str(card["name"]), str(card["skill_name"])]
				for e: Dictionary in card["inputs"]:
					names.append(str(e["name"]))
				for n: String in names:
					assert_false(n.contains("⟨"), "%s: no missing-name marker in %s" % [loc, n])
					if n != "" and raw.has(n):
						assert_true(_own_name(n), "%s: %s is a name, not an id" % [loc, n])
		assert_eq(seen, GameData.RECIPES.size(), "%s: every recipe is on exactly one window's cards" % loc)
		# The built windows, every card selected in turn: no text is an id the locale names otherwise.
		ui.refresh_crafting()
		for w: Node in [ui.hand_window, ui.station_window]:
			for card: Dictionary in (w as CraftWindow).cards():
				(w as CraftWindow).select(str(card["id"]))
				for text: String in _texts(w):
					assert_false(text.contains("⟨"), "%s: no marker in '%s'" % [loc, text])
					for word in text.split(" ", false):
						var token := word.strip_edges().trim_suffix(",").trim_suffix(":").trim_suffix(".")
						if raw.has(token):
							assert_true(_own_name(token), "%s: '%s' shows the id %s" % [loc, text, token])
		TranslationServer.set_locale(before)
	_free(rig)

func _test_categories_and_search() -> void:
	var expect := { "RecipeStoneAxe": "tools", "RecipeSkinningKnife": "tools", "RecipeFerriteShortSword": "weapons",
		"RecipeAethermiteBow": "weapons", "RecipeNoviceTunic": "armor", "RecipeForge": "building", "RecipeChest": "building",
		"RecipeAshiteBlock": "building", "RecipeHealthPotion": "consumables", "RecipeFerriteIngot": "materials",
		"RecipeThornwoodPlank": "materials" }
	for rid: String in expect:
		assert_eq(CraftCatalog.category(rid), expect[rid], "%s is in %s" % [rid, expect[rid]])
	for rid in GameData.RECIPES:
		assert_true(CraftCatalog.CATEGORIES.has(CraftCatalog.category(str(rid))), "%s has a category" % rid)
	var rig := _rig(false)
	var ui: UiSlice = rig["ui"]
	var hand: CraftWindow = ui.hand_window
	ui.refresh_crafting()
	var all := hand.shown_cards().size()
	assert_eq(all, ui.craft_cards("").size(), "the All tab shows every card")
	assert_eq(hand._tab_keys[0], "all", "All is the first tab")
	assert_true(hand._tab_keys.has("tools") and hand._tab_keys.has("building"), "the hand window has tools and building tabs")
	assert_false(hand._tab_keys.has("weapons"), "and no empty tab")
	hand.set_category("tools")
	assert_true(hand.shown_cards().size() > 0 and hand.shown_cards().size() < all, "the tools tab narrows the grid")
	for c: Dictionary in hand.shown_cards():
		assert_eq(str(c["category"]), "tools", "only tools under Tools")
	assert_eq(_live_children(hand.grid).size(), hand.shown_cards().size(), "the grid shows the tab's cards")
	hand.set_category("all")
	var before := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	hand.set_query("stone p")
	assert_eq(_ids(hand.shown_cards()), ["RecipeStonePick"], "the search matches the shown name")
	TranslationServer.set_locale("pt_BR")
	hand.set_query("picareta")
	assert_eq(_ids(hand.shown_cards()), ["RecipeStonePick"], "in the reader's locale")
	TranslationServer.set_locale(before)
	hand.set_query("")
	assert_eq(hand.shown_cards().size(), all, "an empty search shows every card")
	_free(rig)

func _test_craft_quantity() -> void:
	var rig := _rig(false)
	var ui: UiSlice = rig["ui"]
	var inv: InventorySlice = rig["inv"]
	(rig["craft"] as CraftingSlice).set_skill("Carpentry", "novice")
	inv.add_item("Branch", 3)
	inv.add_item("LooseStone", 3)
	var asked: Array = []
	var on_req := func(rid: String) -> void: asked.append(rid)
	GameBus.craft_requested.connect(on_req)
	ui.refresh_crafting()
	ui.hand_window.select("RecipeStoneAxe")
	assert_eq(int(ui.hand_window.quantity.max_value), 3, "the quantity stops at what the bag pays for")
	ui.hand_window.quantity.value = 2
	assert_eq(ui.hand_window.craft_selected(), 2, "two crafts asked for")
	assert_eq(asked.size(), 2, "two craft requests on the bus")
	assert_eq(inv.get_item_count("StoneAxe"), 2, "the host made two stone axes")
	ui.hand_window.select("RecipeStonePick")   # one branch, one stone left: a pick needs two stones
	assert_eq(ui.hand_window.craft_selected(), 0, "an unaffordable card asks for nothing")
	GameBus.craft_requested.disconnect(on_req)
	_free(rig)

func _test_new_strings_in_both_locales() -> void:
	var cats: Dictionary = I18n.parse_csv("res://locale/ui.csv")["catalog"]
	assert_true(cats.has("en") and cats.has("pt_BR"), "both columns")
	for k: String in NEW_KEYS:
		for loc in ["en", "pt_BR"]:
			assert_true(str((cats[loc] as Dictionary).get(k, "")) != "", "%s has %s" % [loc, k])
	for c: String in CraftCatalog.CATEGORIES:
		assert_true(NEW_KEYS.has("craft.cat." + c), "the %s tab has a key" % c)
	for type: String in CraftCatalog.crafting_station_types():
		for loc: String in ["en", "pt_BR"]:
			assert_true(I18n.has_content("station", type), "%s station %s has a name" % [loc, type])
