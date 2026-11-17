extends VBoxContainer
## Phase 269 — the body of a crafting window: the hand window (`station_type` "") or one station's window.
##
## A grid of recipe cards (the output's icon, its localized name and count), a search field and category tabs.
## Selecting a card shows its inputs as icons with have/need counts (red when short), the work time, the skill it
## trains and a Craft button with a quantity. The cards come from `UiSlice.craft_cards` (only known recipes; one
## the player cannot afford is dimmed, not hidden). Every string is a catalog key or a content name.

const I18n := preload("res://src/core/i18n.gd")
const CraftCatalog := preload("res://src/crafting/craft_catalog.gd")

const SHORT_COLOR := Color(1.0, 0.45, 0.45)
const OK_COLOR := Color(1.0, 1.0, 1.0)
const DIM_COLOR := Color(1.0, 1.0, 1.0, 0.45)
const CARD_SIZE := Vector2(92, 76)
const COLUMNS := 4
const ALL := "all"

var ui: Node = null
## The station type whose recipes this window lists ("" = the hand window).
var station_type: String = ""
var category: String = ALL
var query: String = ""
var selected: String = ""

var feedback: Label = null
var search: LineEdit = null
var tabs: TabBar = null
## The scrolled list: the card grid, then `extra_box` (the hand window's repairs).
var list_box: VBoxContainer = null
var grid: GridContainer = null
var extra_box: VBoxContainer = null
var detail: VBoxContainer = null
var quantity: SpinBox = null
var craft_button: Button = null
var _tab_keys: Array = []
var _cards: Array = []

func setup(p_ui: Node, p_station_type: String = "") -> void:
	ui = p_ui
	station_type = p_station_type
	add_theme_constant_override("separation", 6)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	feedback = Label.new()
	feedback.add_theme_font_size_override("font_size", 14)
	add_child(feedback)
	search = LineEdit.new()
	search.clear_button_enabled = true
	ui._set_tr(search, "placeholder_text", "craft.search")
	search.text_changed.connect(_on_search)
	add_child(search)
	tabs = TabBar.new()
	tabs.clip_tabs = true
	tabs.tab_changed.connect(_on_tab)
	add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 4)
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list_box)
	add_child(scroll)
	grid = GridContainer.new()
	grid.columns = COLUMNS
	list_box.add_child(grid)
	extra_box = VBoxContainer.new()
	extra_box.add_theme_constant_override("separation", 4)
	list_box.add_child(extra_box)
	add_child(HSeparator.new())
	detail = VBoxContainer.new()
	detail.add_theme_constant_override("separation", 4)
	add_child(detail)

## Every card this window lists now, before the search and the tab: `UiSlice.craft_cards(station_type)`.
func cards() -> Array:
	return ui.craft_cards(station_type) if ui != null else []

## The cards the grid shows: those in the open tab whose name matches the search.
func shown_cards() -> Array:
	return _cards.filter(func(c: Dictionary) -> bool:
		return (category == ALL or str(c["category"]) == category) and CraftCatalog.matches(str(c["name"]), query))

## The open card's entry ({} when none is selected or it left the list).
func selected_card() -> Dictionary:
	for c: Dictionary in _cards:
		if str(c["id"]) == selected:
			return c
	return {}

func refresh() -> void:
	if ui == null:
		return
	_cards = cards()
	_refresh_tabs()
	for c in grid.get_children():
		c.queue_free()
	for card: Dictionary in shown_cards():
		grid.add_child(_card_button(card))
	if selected != "" and selected_card().is_empty():
		selected = ""
	_refresh_detail()

func select(recipe_id: String) -> void:
	selected = recipe_id
	_refresh_detail()

func set_category(cat: String) -> void:
	category = cat if (cat == ALL or CraftCatalog.CATEGORIES.has(cat)) else ALL
	var i := _tab_keys.find(category)
	if tabs != null and i >= 0 and tabs.current_tab != i:
		tabs.set_block_signals(true)
		tabs.current_tab = i
		tabs.set_block_signals(false)
	refresh()

func set_query(text: String) -> void:
	query = text
	if search != null and search.text != text:
		search.text = text
	refresh()

## Ask for the selected recipe `quantity` times (a client's requests go to the host, which decides each one).
## Returns how many requests were sent.
func craft_selected() -> int:
	var card := selected_card()
	if card.is_empty() or not bool(card["can_craft"]):
		return 0
	var n := clampi(int(quantity.value) if quantity != null else 1, 1, maxi(1, int(card["max_quantity"])))
	for i in n:
		GameBus.craft_requested.emit(str(card["id"]))
	return n

func _on_search(text: String) -> void:
	query = text
	refresh()

func _on_tab(i: int) -> void:
	if i >= 0 and i < _tab_keys.size():
		category = str(_tab_keys[i])
		refresh()

## The tabs: All, then each category some listed card is in (tab order of CraftCatalog.CATEGORIES).
func _refresh_tabs() -> void:
	var present := {}
	for c: Dictionary in _cards:
		present[str(c["category"])] = true
	var keys: Array = [ALL]
	for cat in CraftCatalog.CATEGORIES:
		if present.has(cat):
			keys.append(cat)
	if not keys.has(category):
		category = ALL
	tabs.set_block_signals(true)
	if keys != _tab_keys or tabs.tab_count != keys.size():
		tabs.clear_tabs()
		for k in keys:
			tabs.add_tab("")
		_tab_keys = keys
	for i in keys.size():
		tabs.set_tab_title(i, I18n.t("craft.cat." + str(keys[i])))
	tabs.current_tab = keys.find(category)
	tabs.set_block_signals(false)

func _card_button(card: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = CARD_SIZE
	b.clip_text = true
	b.toggle_mode = true
	b.button_pressed = str(card["id"]) == selected
	var count := int(card["count"])
	b.text = str(card["name"]) if count <= 1 else I18n.t("craft.card_count", [card["name"], count])
	b.tooltip_text = str(card["name"]) if bool(card["can_craft"]) else I18n.t("craft.card_refused", [card["name"], I18n.reason_text(str(card["reason"]))])
	var tex: Texture2D = ui._load_item_icon(str(card["icon_key"])) if str(card["icon_key"]) != "" else null
	if tex != null:
		b.icon = tex
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.add_theme_font_size_override("font_size", 11)
	b.modulate = OK_COLOR if bool(card["can_craft"]) else DIM_COLOR
	b.pressed.connect(select.bind(str(card["id"])))
	return b

func _refresh_detail() -> void:
	for c in detail.get_children():
		c.queue_free()
	quantity = null
	craft_button = null
	var card := selected_card()
	if card.is_empty():
		var hint := Label.new()
		hint.text = I18n.t("craft.pick" if not _cards.is_empty() else "craft.none")
		hint.modulate = Color(0.75, 0.75, 0.75)
		detail.add_child(hint)
		return
	var title := Label.new()
	var count := int(card["count"])
	title.text = str(card["name"]) if count <= 1 else I18n.t("craft.card_count", [card["name"], count])
	title.add_theme_font_size_override("font_size", 16)
	detail.add_child(title)
	var ins := HFlowContainer.new()
	ins.add_theme_constant_override("h_separation", 10)
	for e: Dictionary in card["inputs"]:
		var cell := HBoxContainer.new()
		cell.tooltip_text = str(e["name"])
		var tex: Texture2D = ui._load_item_icon(str(e["icon_key"]))
		if tex != null:
			var rect := TextureRect.new()
			rect.texture = tex
			rect.custom_minimum_size = Vector2(24, 24)
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rect.tooltip_text = str(e["name"])
			cell.add_child(rect)
		var lbl := Label.new()
		lbl.text = I18n.t("craft.have_need", [int(e["have"]), int(e["need"])])
		lbl.modulate = SHORT_COLOR if bool(e["short"]) else OK_COLOR
		lbl.tooltip_text = str(e["name"])
		lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		cell.add_child(lbl)
		ins.add_child(cell)
	detail.add_child(ins)
	var work := Label.new()
	var secs := float(card["work_seconds"])
	work.text = I18n.t("craft.work_time", [I18n.number(secs, 1)]) if secs > 0.0 else I18n.t("craft.work_instant")
	detail.add_child(work)
	var skill := Label.new()
	skill.text = I18n.t("craft.trains", [card["skill_name"]]) if str(card["skill"]) != "" else I18n.t("craft.trains_none")
	detail.add_child(skill)
	if not bool(card["can_craft"]):
		var why := Label.new()
		why.text = I18n.reason_text(str(card["reason"]))
		why.modulate = SHORT_COLOR
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_child(why)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var qlabel := Label.new()
	qlabel.text = I18n.t("craft.quantity")
	row.add_child(qlabel)
	quantity = SpinBox.new()
	quantity.min_value = 1
	quantity.max_value = maxi(1, int(card["max_quantity"]))
	quantity.value = 1
	quantity.editable = bool(card["can_craft"])
	row.add_child(quantity)
	craft_button = Button.new()
	craft_button.text = I18n.t("ui.craft")
	craft_button.disabled = not bool(card["can_craft"])
	craft_button.pressed.connect(func() -> void: craft_selected())
	row.add_child(craft_button)
	detail.add_child(row)
