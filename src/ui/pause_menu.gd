extends Control
## Phase 224 — the Esc menu: Resume, Options, Exit to main menu, Quit game.
##
## Presentation only. It covers the screen (a dimmed backdrop that swallows clicks, so none reaches the
## world) and says what the player chose through its signals; `UiSlice` opens and closes it and turns a
## choice into a bus intent (`GameBus.exit_to_menu_requested` / `quit_game_requested`). It never pauses
## the tree: on a listen host the world keeps running for the players connected to it.

const I18n := preload("res://src/core/i18n.gd")
const OptionsWindow := preload("res://src/ui/options_window.gd")

signal resume_requested
signal options_requested
signal exit_requested
signal quit_requested

## [{button, key}] — re-applied on a language switch.
var _texts: Array = []
var _title: Label = null
var _options_button: Button = null
var _resume_button: Button = null
var _options: Control = null   # Phase 225 — the options window, built on first use

func _init() -> void:
	name = "PauseMenu"
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(260, 0)
	panel.add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_resume_button = _button(box, "pause.resume", resume_requested.emit)
	_options_button = _button(box, "pause.options", _open_options)
	_button(box, "pause.exit_menu", exit_requested.emit)
	_button(box, "pause.quit", quit_requested.emit)
	relocalize()

func _ready() -> void:
	GameBus.locale_changed.connect(_on_locale_changed)

func _exit_tree() -> void:
	if GameBus.locale_changed.is_connected(_on_locale_changed):
		GameBus.locale_changed.disconnect(_on_locale_changed)

func _button(parent: Control, key: String, cb: Callable) -> Button:
	var b := Button.new()
	b.name = key.get_slice(".", 1)
	b.pressed.connect(cb)
	parent.add_child(b)
	_texts.append({ "button": b, "key": key })
	return b

func _on_locale_changed(_locale: String) -> void:
	relocalize()

func relocalize() -> void:
	_title.text = I18n.t("pause.title")
	for e in _texts:
		(e["button"] as Button).text = I18n.t(str(e["key"]))

func _open_options() -> void:
	if _options == null:
		_options = OptionsWindow.new()
		add_child(_options)
	_options.open()
	options_requested.emit()

func options_window() -> Control:
	return _options

func is_open() -> bool:
	return visible

## No button takes the keyboard: Space (jump) or Enter must not press Resume by accident.
func open() -> void:
	visible = true

func close() -> void:
	visible = false
	if _options != null:
		_options.close()

func options_enabled() -> bool:
	return not _options_button.disabled

## The button for a choice ("resume", "options", "exit_menu", "quit"): the suite presses it.
func button(choice: String) -> Button:
	for e in _texts:
		if str(e["key"]) == "pause." + choice:
			return e["button"]
	return null
