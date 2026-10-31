extends VBoxContainer
## Window dock — a collapsible box under the health bar holding one small box per game
## window, each showing the window's icon with its shortcut letter as a corner badge. Clicking a box toggles that window, so the
## shortcuts teach themselves: the player sees "I", clicks it, and the inventory opens.
##
## Presentation only: `window_toggled(key)` is handled by the UI slice, which owns the windows.
##
## Pure, headless-testable static: `entries`.

signal window_toggled(window_key: String)

## Dock order. Each entry: { key (window key), letter (shortcut), name }.
## The letters must match the key map in `UiSlice._input`.
const I18n := preload("res://src/core/i18n.gd")
const UiIcons := preload("res://src/ui/ui_icons.gd")
const ENTRIES: Array = [
	{"key": "inventory",  "letter": "I", "name": "dock.inventory"},
	{"key": "character",  "letter": "C", "name": "dock.character"},
	{"key": "skills",     "letter": "K", "name": "dock.skills"},
	{"key": "crafting",   "letter": "H", "name": "dock.crafting"},
	{"key": "technology", "letter": "T", "name": "dock.technology"},
	{"key": "trade",      "letter": "Y", "name": "dock.trade"},
	{"key": "market",     "letter": "P", "name": "dock.market"},
	{"key": "map",        "letter": "M", "name": "dock.map"},
	{"key": "proposals",  "letter": "G", "name": "dock.proposals"},
	{"key": "settlement", "letter": "L", "name": "dock.settlement"},
	{"key": "clan",       "letter": "J", "name": "dock.clan"},
	{"key": "controls",   "letter": "?", "name": "dock.controls"},
	{"key": "admin",      "letter": "O", "name": "dock.admin"},
]
## Phase 182 — boxes hidden until `set_entry_visible` shows them (the Admin window, for admins only).
const HIDDEN_BY_DEFAULT := ["admin"]

const BOX_PX := 32.0
const COLUMNS := 4

## Where the open/closed state persists ("" = nowhere). A client-only view setting.
var save_path: String = ""
var _toggle: Button = null
var _grid: GridContainer = null
var _boxes: Dictionary = {}   # window key -> Button
var _shown: Dictionary = {}   # a HIDDEN_BY_DEFAULT key -> true once shown (kept for a dock built later)

func _init() -> void:
	name = "WindowDock"

func build() -> void:
	_toggle = Button.new()
	_toggle.text = "▾ " + I18n.t("dock.windows")
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.flat = true
	_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_toggle.tooltip_text = I18n.t("dock.tip")
	_toggle.pressed.connect(func(): set_expanded(not is_expanded()))
	add_child(_toggle)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	add_child(_grid)
	for e in entries():
		var b := Button.new()
		b.custom_minimum_size = Vector2(BOX_PX, BOX_PX)
		b.icon = UiIcons.load_icon(UiIcons.window_key(str(e["key"])))
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_child(_badge(str(e["letter"])))
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = "%s  (%s)" % [I18n.t(e["name"]), e["letter"]]
		b.pressed.connect(func(): window_toggled.emit(str(e["key"])))
		_grid.add_child(b)
		_boxes[str(e["key"])] = b
		b.visible = not (str(e["key"]) in HIDDEN_BY_DEFAULT) or _shown.has(str(e["key"]))
	_apply_expanded(load_expanded(save_path))

## The shortcut letter as a small corner badge over the icon.
static func _badge(letter: String) -> Label:
	var badge := Label.new()
	badge.name = "Badge"
	badge.text = letter
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	badge.offset_left = -12.0
	badge.offset_top = -14.0
	badge.offset_right = -1.0
	badge.offset_bottom = 0.0
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override("font_color", Color(1, 1, 1))
	badge.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	badge.add_theme_constant_override("outline_size", 4)
	return badge

## The language changed: re-render the toggle and every box tooltip.
func relocalize() -> void:
	if _grid == null:
		return
	_apply_expanded(is_expanded())
	_toggle.tooltip_text = I18n.t("dock.tip")
	for e in entries():
		(_boxes[str(e["key"])] as Button).tooltip_text = "%s  (%s)" % [I18n.t(e["name"]), e["letter"]]

## Show or hide one window's box (Phase 182: the Admin box follows the admin status).
func set_entry_visible(window_key: String, shown: bool) -> void:
	if shown:
		_shown[window_key] = true
	else:
		_shown.erase(window_key)
	var b: Button = _boxes.get(window_key, null)
	if b != null:
		b.visible = shown

## The box of one window (tests and the UI slice).
func box(window_key: String) -> Button:
	return _boxes.get(window_key, null)

func is_entry_visible(window_key: String) -> bool:
	var b: Button = _boxes.get(window_key, null)
	return b != null and b.visible

static func entries() -> Array:
	return ENTRIES

func is_expanded() -> bool:
	return _grid != null and _grid.visible

func set_expanded(open: bool) -> void:
	if _grid == null:
		return
	_apply_expanded(open)
	if save_path != "":
		var f := FileAccess.open(save_path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify({"expanded": open}))

func _apply_expanded(open: bool) -> void:
	_grid.visible = open
	_toggle.text = ("▾ " if open else "▸ ") + I18n.t("dock.windows")

## The saved open/closed state; open when there is no (valid) save.
static func load_expanded(path: String) -> bool:
	if path == "" or not FileAccess.file_exists(path):
		return true
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not (json.data is Dictionary):
		return true
	var v = (json.data as Dictionary).get("expanded", true)
	return v if v is bool else true

## Highlight the boxes whose window is open.
func mark_open(open_keys: Array) -> void:
	for key in _boxes:
		_boxes[key].modulate = Color(1.0, 0.9, 0.4) if open_keys.has(key) else Color.WHITE
