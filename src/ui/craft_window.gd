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
## Phase 288 — a card is a fixed layout: a square icon area, the name under it (two lines at most), a count badge.
const CARD_SIZE := Vector2(100, 100)
const ICON_SIZE := 60.0
const ICON_MIN := 56.0
const CARD_PAD := 4.0
const NAME_FONT := 11
## Gap between cards, both ways.
const CARD_SEP := 6
## The window is at least this many columns wide; a wider window shows more (`columns_for_width`).
const MIN_COLUMNS := 4
## Rows of cards the grid always has room for, whatever the detail below holds.
const MIN_ROWS := 2
## The detail panel's own scroll area: at least this tall, never taller (it scrolls instead).
const DETAIL_HEIGHT := 150.0
const INPUT_ICON := 32.0
const SELECTED_BORDER := Color(1.0, 0.82, 0.3)
## A card that cannot be made dims its frame and name; its icon stays opaque and only slightly darker.
const ICON_DIM_COLOR := Color(0.8, 0.8, 0.8, 1.0)
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
## The card grid's scroll area (at least `MIN_ROWS` card rows tall).
var grid_scroll: ScrollContainer = null
## The detail panel's scroll area.
var detail_scroll: ScrollContainer = null
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
	# Phase 288 — the grid keeps room for MIN_ROWS full card rows and the window is wide enough for MIN_COLUMNS
	# (plus a scroll bar), so the detail below can never squeeze it to a strip.
	custom_minimum_size.x = grid_width(MIN_COLUMNS) + 16.0
	grid_scroll = ScrollContainer.new()
	grid_scroll.name = "CardScroll"
	grid_scroll.custom_minimum_size = Vector2(0, MIN_ROWS * CARD_SIZE.y + (MIN_ROWS - 1) * CARD_SEP)
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 4)
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.resized.connect(_fit_columns)
	grid_scroll.add_child(list_box)
	add_child(grid_scroll)
	grid = GridContainer.new()
	grid.columns = MIN_COLUMNS
	grid.add_theme_constant_override("h_separation", CARD_SEP)
	grid.add_theme_constant_override("v_separation", CARD_SEP)
	list_box.add_child(grid)
	extra_box = VBoxContainer.new()
	extra_box.add_theme_constant_override("separation", 4)
	list_box.add_child(extra_box)
	add_child(HSeparator.new())
	detail_scroll = ScrollContainer.new()
	detail_scroll.name = "DetailScroll"
	detail_scroll.custom_minimum_size = Vector2(0, DETAIL_HEIGHT)
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail = VBoxContainer.new()
	detail.add_theme_constant_override("separation", 4)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(detail)
	add_child(detail_scroll)

## The width `n` card columns take, with the gaps between them.
static func grid_width(n: int) -> float:
	return n * CARD_SIZE.x + maxi(0, n - 1) * CARD_SEP

## The most cards (with the gaps) that fit `width` px, at least one.
static func columns_for_width(width: float) -> int:
	return maxi(1, int(floor((width + CARD_SEP) / (CARD_SIZE.x + CARD_SEP))))

## The column count follows the list's width: cards keep their size, a wider window shows more columns.
func _fit_columns() -> void:
	if grid == null or list_box == null or list_box.size.x <= 0.0:
		return
	var n := columns_for_width(list_box.size.x)
	if grid.columns != n:
		grid.columns = n

## The shown cards whose icon area is not a square of at least ICON_MIN px, as "name WxH" (empty when all are).
func undersized_icons() -> Array:
	var out: Array = []
	for card: Node in grid.get_children():
		if card.is_queued_for_deletion():
			continue
		var icon := card.get_node_or_null("Icon") as Control
		var sz: Vector2 = icon.size if icon != null else Vector2.ZERO
		if sz.x < ICON_MIN or sz.y < ICON_MIN or not is_equal_approx(sz.x, sz.y):
			var name_lbl := card.get_node_or_null("Name") as Label
			out.append("%s %dx%d" % [name_lbl.text if name_lbl != null else str(card.get_meta("recipe_id", "")), int(sz.x), int(sz.y)])
	return out

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
	for c: Node in grid.get_children():
		if not c.is_queued_for_deletion():
			_style_card(c as Button, str(c.get_meta("recipe_id", "")) == selected)
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

## Phase 288 — a card: a fixed layout on a flat button (not the button's own icon and text, which shrank the icon
## to what a wrapped name left). The icon area is a square ICON_SIZE `TextureRect` at the top, the name under it on
## up to two lines with an ellipsis, the count badge in the top-right corner.
func _card_button(card: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = CARD_SIZE
	b.size = CARD_SIZE
	b.set_meta("recipe_id", str(card["id"]))
	b.tooltip_text = str(card["name"]) if bool(card["can_craft"]) else I18n.t("craft.card_refused", [card["name"], I18n.reason_text(str(card["reason"]))])
	var can := bool(card["can_craft"])
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.position = Vector2((CARD_SIZE.x - ICON_SIZE) * 0.5, CARD_PAD)
	icon.size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.texture = ui._load_item_icon(str(card["icon_key"])) if str(card["icon_key"]) != "" else null
	icon.modulate = OK_COLOR if can else ICON_DIM_COLOR
	b.add_child(icon)
	var name_lbl := Label.new()
	name_lbl.name = "Name"
	name_lbl.text = str(card["name"])
	name_lbl.add_theme_font_size_override("font_size", NAME_FONT)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.max_lines_visible = 2
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.clip_text = true
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_top := CARD_PAD + ICON_SIZE + 2.0
	name_lbl.position = Vector2(CARD_PAD, name_top)
	name_lbl.size = Vector2(CARD_SIZE.x - 2.0 * CARD_PAD, CARD_SIZE.y - name_top - CARD_PAD)
	name_lbl.modulate = OK_COLOR if can else DIM_COLOR
	b.add_child(name_lbl)
	var count := int(card["count"])
	if count > 1:
		var badge := Label.new()
		badge.name = "Count"
		badge.text = I18n.t("craft.card_badge", [count])
		badge.add_theme_font_size_override("font_size", NAME_FONT)
		badge.add_theme_color_override("font_outline_color", Color.BLACK)
		badge.add_theme_constant_override("outline_size", 3)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.position = Vector2(CARD_PAD, CARD_PAD)
		badge.size = Vector2(CARD_SIZE.x - 2.0 * CARD_PAD, 16)
		b.add_child(badge)
	b.self_modulate = OK_COLOR if can else DIM_COLOR
	_style_card(b, str(card["id"]) == selected)
	b.pressed.connect(select.bind(str(card["id"])))
	return b

## The selected card has a visible border; the others the theme's look.
func _style_card(b: Button, on: bool) -> void:
	for state: String in ["normal", "hover", "pressed", "focus"]:
		b.remove_theme_stylebox_override(state)
	if not on:
		return
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.2, 0.2, 0.24, 0.9)
	box.set_border_width_all(2)
	box.border_color = SELECTED_BORDER
	box.set_corner_radius_all(4)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, box)

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
		var rect := TextureRect.new()   # Phase 288 — 32 px (was 24); kept (empty) when the item has no icon
		rect.name = "InputIcon"
		rect.texture = ui._load_item_icon(str(e["icon_key"])) if str(e["icon_key"]) != "" else null
		rect.custom_minimum_size = Vector2(INPUT_ICON, INPUT_ICON)
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
