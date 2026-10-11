extends VBoxContainer
## Window dock — a collapsible box under the health bar holding one small box per game
## window, each labelled with its shortcut letter. Clicking a box toggles that window, so the
## shortcuts teach themselves: the player sees "I", clicks it, and the inventory opens.
##
## Presentation only: `window_toggled(key)` is handled by the UI slice, which owns the windows.
##
## Pure, headless-testable static: `entries`.

signal window_toggled(window_key: String)

## Dock order. Each entry: { key (window key), letter (shortcut), name }.
## The letters must match the key map in `UiSlice._input`.
const ENTRIES: Array = [
	{"key": "inventory",  "letter": "I", "name": "Inventory"},
	{"key": "character",  "letter": "C", "name": "Character"},
	{"key": "skills",     "letter": "K", "name": "Skills"},
	{"key": "crafting",   "letter": "H", "name": "Crafting"},
	{"key": "technology", "letter": "T", "name": "Technology"},
	{"key": "trade",      "letter": "Y", "name": "Trade"},
	{"key": "market",     "letter": "P", "name": "Market"},
	{"key": "map",        "letter": "M", "name": "Map"},
	{"key": "proposals",  "letter": "G", "name": "Proposals"},
	{"key": "controls",   "letter": "?", "name": "Controls"},
]

const BOX_PX := 32.0
const COLUMNS := 4

## Where the open/closed state persists ("" = nowhere). A client-only view setting.
var save_path: String = ""
var _toggle: Button = null
var _grid: GridContainer = null
var _boxes: Dictionary = {}   # window key -> Button

func _init() -> void:
	name = "WindowDock"

func build() -> void:
	_toggle = Button.new()
	_toggle.text = "▾ Windows"
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.flat = true
	_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_toggle.tooltip_text = "Show or hide the window shortcuts"
	_toggle.pressed.connect(func(): set_expanded(not is_expanded()))
	add_child(_toggle)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	add_child(_grid)
	for e in entries():
		var b := Button.new()
		b.text = str(e["letter"])
		b.custom_minimum_size = Vector2(BOX_PX, BOX_PX)
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = "%s  (%s)" % [e["name"], e["letter"]]
		b.pressed.connect(func(): window_toggled.emit(str(e["key"])))
		_grid.add_child(b)
		_boxes[str(e["key"])] = b
	_apply_expanded(load_expanded(save_path))

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
	_toggle.text = ("▾ Windows" if open else "▸ Windows")

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
