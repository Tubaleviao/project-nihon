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
	"craft.pick", "craft.none", "controls.row18", "craft.card_badge"]

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
	_run_test("crafting window: a recipe learnt by research or a blueprint shows at once in an open station window", _test_research_redraws_station_window)
	_run_test("crafting window: a closed window is not rebuilt, and is fresh when it opens", _test_closed_window_not_rebuilt)
	_run_test("crafting window: the default hand window has a grid at least two card rows tall; the detail scrolls", _test_grid_two_rows)
	_run_test("crafting window: every card's icon area is a square of at least 56 px, even with a long name", _test_card_icon_area)
	_run_test("crafting window: the column count is the most cards that fit the grid's width, at three widths", _test_columns_follow_width)
	_run_test("crafting window: a station window gets the same card layout; the detail's input icons are 32 px", _test_station_card_layout)
	_run_test("crafting window: the selected card has a border, the others none", _test_selected_border)

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
	ui.open_window(UiSlice.WINDOW_CRAFTING)   # refresh_crafting redraws only an open window
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
		if str(b.get_meta("recipe_id", "")) == "RecipeStonePick":
			dimmed = (b as Button).self_modulate.a < 1.0 and (b.get_node("Name") as Label).modulate.a < 1.0
			# Phase 288 — the icon stays readable: opaque, only a little darker.
			assert_eq((b.get_node("Icon") as Control).modulate.a, 1.0, "the dimmed card's icon stays opaque")
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

## Review of PR #647 — a blueprint read or research arrives as `research_points_synced`: an open station window redraws too.
func _test_research_redraws_station_window() -> void:
	var rig := _rig()
	var ui: UiSlice = rig["ui"]
	var tech: TechnologySlice = rig["tech"]
	var forge := (rig["station"] as StationSlice).place_station("forge", Vector3.ZERO)
	assert_true(ui.open_station_window(forge), "the forge's window opens")
	ui.close_window(UiSlice.WINDOW_CRAFTING)   # only the station window is open
	assert_false(_ids(ui.station_window.shown_cards()).has("RecipeFerriteIngot"), "no ingot before smithing")
	GameBus.set_block_signals(true)   # learnt with no technology_unlocked: only the points sync below tells the UI
	assert_eq(tech.learn("technology", "TechBasicSmithing"), "", "basic smithing is learnt")
	GameBus.set_block_signals(false)
	assert_false(_ids(ui.station_window.shown_cards()).has("RecipeFerriteIngot"), "the window has not redrawn yet")
	GameBus.research_points_synced.emit("", 0)
	assert_true(_ids(ui.station_window.shown_cards()).has("RecipeFerriteIngot"), "the points sync redraws the open station window")
	assert_eq(_live_children(ui.station_window.grid).size(), ui.craft_cards("forge").size(), "one card per forge recipe")
	_free(rig)

## Review of PR #647 — refresh_crafting rebuilds only open windows; opening one rebuilds it.
func _test_closed_window_not_rebuilt() -> void:
	var rig := _rig(false)
	var ui: UiSlice = rig["ui"]
	var inv: InventorySlice = rig["inv"]
	(rig["craft"] as CraftingSlice).set_skill("Carpentry", "novice")
	ui.refresh_crafting()
	var forge := (rig["station"] as StationSlice).place_station("forge", Vector3.ZERO)
	assert_true(ui.open_station_window(forge), "the forge's window opens and fills")
	ui.close_window(UiSlice.WINDOW_STATION)
	ui.close_window(UiSlice.WINDOW_CRAFTING)
	var hand_cards := _live_children(ui.hand_window.grid)
	var station_cards := _live_children(ui.station_window.grid)
	assert_true(hand_cards.size() > 0 and station_cards.size() > 0, "both windows hold cards")
	inv.add_item("Branch", 1)   # an inventory change and a craft result, both windows closed
	GameBus.craft_resolved.emit({ "success": true, "recipe_id": "RecipeStonePick", "player_id": "" })
	ui.refresh_crafting()
	assert_eq(_live_children(ui.hand_window.grid), hand_cards, "the closed hand window keeps its cards: not rebuilt")
	assert_eq(_live_children(ui.station_window.grid), station_cards, "the closed station window keeps its cards: not rebuilt")
	inv.add_item("LooseStone", 2)
	ui.open_window(UiSlice.WINDOW_CRAFTING)
	assert_true(hand_cards.all(func(c: Node) -> bool: return c.is_queued_for_deletion()), "opening rebuilds the hand window")
	assert_true(bool(_card(ui.hand_window.shown_cards(), "RecipeStonePick")["can_craft"]), "fresh: the pick is now affordable")
	assert_true(ui.open_station_window(forge), "the forge's window reopens")
	assert_true(station_cards.all(func(c: Node) -> bool: return c.is_queued_for_deletion()), "opening rebuilds the station window")
	assert_eq(_live_children(ui.station_window.grid).size(), ui.craft_cards("forge").size(), "one card per forge recipe")
	_free(rig)

# ── Phase 288: recipe cards you can read ────────────────────────────────

## Lay a container tree out now: no frames elapse in the suite, so the deferred sorts never run.
func _lay_out(c: Control) -> void:
	if c is Container:
		c.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for child in c.get_children():
		if child is Control:
			_lay_out(child)

## Size `key`'s panel (its minimum on an axis `size` leaves at zero) and lay it out twice (the column fit runs on
## the first pass's resize).
func _size_panel(ui: UiSlice, key: String, size: Vector2 = Vector2.ZERO) -> Control:
	var panel: Control = ui._panels[key]
	var m := panel.get_combined_minimum_size()
	panel.size = Vector2(maxf(size.x, m.x), maxf(size.y, m.y))
	_lay_out(panel)
	_lay_out(panel)
	return panel

func _two_rows() -> float:
	return CraftWindow.MIN_ROWS * CraftWindow.CARD_SIZE.y + (CraftWindow.MIN_ROWS - 1) * CraftWindow.CARD_SEP

func _test_grid_two_rows() -> void:
	var rig := _rig(false)
	var ui: UiSlice = rig["ui"]
	(rig["craft"] as CraftingSlice).set_skill("Carpentry", "novice")
	ui.refresh_crafting()
	var hand = ui.hand_window
	assert_true(CraftWindow.MIN_ROWS >= 2, "at least two rows")
	_size_panel(ui, UiSlice.WINDOW_CRAFTING)
	assert_true(hand.grid_scroll.size.y >= _two_rows(), "the default window's grid area is two card rows tall (%.0f)" % hand.grid_scroll.size.y)
	var panel: Control = ui._panels[UiSlice.WINDOW_CRAFTING]
	var before: float = panel.get_combined_minimum_size().y
	for c: Dictionary in hand.shown_cards():
		hand.select(str(c["id"]))
		assert_eq(panel.get_combined_minimum_size().y, before,
			"selecting %s never raises the window's minimum height: the detail scrolls" % str(c["id"]))
	_size_panel(ui, UiSlice.WINDOW_CRAFTING)
	assert_true(hand.grid_scroll.size.y >= _two_rows(), "with a card selected the grid keeps two rows (%.0f)" % hand.grid_scroll.size.y)
	assert_true(hand.detail.get_parent() is ScrollContainer, "the detail sits in its own scroll area")
	_free(rig)

func _test_card_icon_area() -> void:
	var rig := _rig(false)
	var ui: UiSlice = rig["ui"]
	(rig["craft"] as CraftingSlice).set_skill("Carpentry", "novice")
	ui.refresh_crafting()
	var hand = ui.hand_window
	_size_panel(ui, UiSlice.WINDOW_CRAFTING)
	var cards := _live_children(hand.grid)
	assert_true(cards.size() > 0, "the hand window has cards")
	for b: Node in cards:
		var icon := b.get_node_or_null("Icon") as TextureRect
		assert_true(icon != null, "every card has an icon area")
		if icon == null:
			continue
		assert_eq(icon.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "the icon keeps its aspect, centred")
		assert_true(icon.size.x >= CraftWindow.ICON_MIN and icon.size.y >= CraftWindow.ICON_MIN and is_equal_approx(icon.size.x, icon.size.y),
			"%s: the icon area is a square of at least 56 px (%s)" % [str(b.get_meta("recipe_id")), str(icon.size)])
		assert_eq((b as Control).size, CraftWindow.CARD_SIZE, "the card keeps its size")
	assert_eq(hand.undersized_icons(), [], "no undersized icon")
	# A long localized name wraps to two lines with an ellipsis; the icon keeps its size.
	var long_name := "Extraordinariamente comprida ferramenta de pedra polida e afiada com cabo de madeira"
	var b: Button = hand._card_button({ "id": "RecipeLong", "name": long_name, "count": 12, "can_craft": false, "reason": "",
		"icon_key": "" })
	var icon := b.get_node("Icon") as Control
	var name_lbl := b.get_node("Name") as Label
	assert_eq(icon.size, Vector2(CraftWindow.ICON_SIZE, CraftWindow.ICON_SIZE), "a long name leaves the icon its size")
	assert_true(icon.size.x >= CraftWindow.ICON_MIN, "and at least 56 px")
	assert_eq(name_lbl.max_lines_visible, 2, "the name takes two lines at most")
	assert_eq(name_lbl.text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS, "with an ellipsis")
	assert_true(name_lbl.position.y >= icon.position.y + icon.size.y, "the name sits under the icon")
	assert_true(name_lbl.position.y + name_lbl.size.y <= CraftWindow.CARD_SIZE.y + 0.5, "inside the card (%s)" % str(name_lbl.size))
	assert_eq(b.get_combined_minimum_size(), CraftWindow.CARD_SIZE, "a long name does not grow the card")
	var badge := b.get_node_or_null("Count") as Label
	assert_true(badge != null and badge.text == I18n.t("craft.card_badge", [12]), "the count badge shows the count")
	b.free()
	_free(rig)

func _test_columns_follow_width() -> void:
	var rig := _rig(false)
	var ui: UiSlice = rig["ui"]
	(rig["craft"] as CraftingSlice).set_skill("Carpentry", "novice")
	ui.refresh_crafting()
	var hand = ui.hand_window
	var panel := _size_panel(ui, UiSlice.WINDOW_CRAFTING)
	var min_w := panel.size.x
	var seen: Array = []
	for w: float in [min_w, min_w + 260.0, min_w + 640.0]:
		_size_panel(ui, UiSlice.WINDOW_CRAFTING, Vector2(w, 0))
		var avail: float = hand.grid.size.x
		var sep := float(hand.grid.get_theme_constant("h_separation"))
		var n := 0
		while (n + 1) * CraftWindow.CARD_SIZE.x + n * sep <= avail + 0.01:
			n += 1
		assert_eq(hand.grid.columns, maxi(1, n), "at %d px the grid (%.0f px) shows the most cards that fit" % [int(w), avail])
		for b: Node in _live_children(hand.grid):
			assert_eq((b as Control).size, CraftWindow.CARD_SIZE, "at %d px the cards keep their size" % int(w))
		seen.append(hand.grid.columns)
	assert_true(int(seen[0]) >= CraftWindow.MIN_COLUMNS, "the default width shows at least %d columns" % CraftWindow.MIN_COLUMNS)
	assert_true(int(seen[0]) < int(seen[1]) and int(seen[1]) < int(seen[2]), "a wider window shows more columns (%s)" % str(seen))
	_free(rig)

func _test_station_card_layout() -> void:
	var rig := _rig()
	var ui: UiSlice = rig["ui"]
	assert_eq((rig["tech"] as TechnologySlice).learn("technology", "TechBasicSmithing"), "", "basic smithing is learnt")
	var forge := (rig["station"] as StationSlice).place_station("forge", Vector3.ZERO)
	ui.viewport_size_override = Vector2(1152, 648)
	assert_true(ui.open_station_window(forge), "the forge's window opens")
	var win = ui.station_window
	var panel: Control = ui._panels[UiSlice.WINDOW_STATION]
	assert_true(Rect2(Vector2.ZERO, ui.viewport_size_override).encloses(Rect2(panel.position, panel.size)),
		"the taller window opens wholly on screen at 1152x648 (%s)" % str(Rect2(panel.position, panel.size)))
	_size_panel(ui, UiSlice.WINDOW_STATION)
	var cards := _live_children(win.grid)
	assert_true(cards.size() > 0, "the forge window has cards")
	assert_true(win.grid_scroll.size.y >= _two_rows(), "the station grid area is two card rows tall")
	assert_eq(win.undersized_icons(), [], "every station card's icon area is a square of at least 56 px")
	for b: Node in cards:
		assert_true(b.get_node_or_null("Icon") is TextureRect and b.get_node_or_null("Name") is Label, "the station card has the same layout")
	var with_inputs: Dictionary = {}
	for c: Dictionary in win.shown_cards():
		if not (c["inputs"] as Array).is_empty():
			with_inputs = c
			break
	assert_false(with_inputs.is_empty(), "a station recipe has inputs")
	if not with_inputs.is_empty():
		win.select(str(with_inputs["id"]))
		var rects: Array = win.detail.find_children("InputIcon", "TextureRect", true, false)
		assert_eq(rects.size(), (with_inputs["inputs"] as Array).size(), "one icon per input")
		for r: Node in rects:
			assert_eq((r as Control).custom_minimum_size, Vector2(32, 32), "the detail's input icons are 32 px")
	_free(rig)

func _test_selected_border() -> void:
	var rig := _rig(false)
	var ui: UiSlice = rig["ui"]
	(rig["craft"] as CraftingSlice).set_skill("Carpentry", "novice")
	ui.refresh_crafting()
	var hand = ui.hand_window
	hand.select("RecipeStonePick")
	var bordered := 0
	for b: Node in _live_children(hand.grid):
		var c := b as Control
		var box := c.get_theme_stylebox("normal") as StyleBoxFlat
		var on := c.has_theme_stylebox_override("normal") and box != null and box.border_width_top > 0
		if str(b.get_meta("recipe_id")) == "RecipeStonePick":
			assert_true(on, "the selected card has a border")
		bordered += 1 if on else 0
	assert_eq(bordered, 1, "only the selected card has the border")
	_free(rig)
