extends Control
## Phase 225 — the options window: Sound, Graphics and Game tabs over `GameSettings`. Reached from the main
## menu and the Esc menu (each owns one). Every control writes through `GameSettings.set_value`, so a change
## is validated, saved and applied at once. Labels are catalog keys (`options.*`) re-rendered on a language
## switch. Presentation only: no state of its own beyond the controls.

const I18n := preload("res://src/core/i18n.gd")
const GameSettings := preload("res://src/core/game_settings.gd")
const LocaleSettings := preload("res://src/core/locale_settings.gd")
const InputLabels := preload("res://src/ui/input_labels.gd")
const TutorialCard := preload("res://src/tutorial/tutorial_card.gd")

signal closed

const TABS := ["sound", "graphics", "game"]

var _tabs: TabContainer = null
var _controls := {}   # setting key → Control
var _labels: Array = []   # [{ node, key }] re-localized on a language switch
var _language_button: Button = null
var _close_button: Button = null
var _controls_list: VBoxContainer = null
var _choices := {}   # setting key → OptionButton, its items re-localized on a language switch
var _world_note: Label = null
var _dragging := ""   # the slider key being dragged: applied live, saved when the drag ends

## Set by the Esc menu: a world is running, so WORLD_KEYS are saved for the next world, not applied.
var in_world := false:
	set(v):
		in_world = v
		if _world_note != null:
			_world_note.visible = v

func _init() -> void:
	name = "OptionsWindow"
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(0, 360)
	box.add_child(_tabs)
	for t in TABS:
		var page := VBoxContainer.new()
		page.name = t
		page.add_theme_constant_override("separation", 6)
		_tabs.add_child(page)
	for key in GameSettings.SPEC:
		var rule: Dictionary = GameSettings.SPEC[key]
		_add_row(_tabs.get_node(str(rule["tab"])) as VBoxContainer, key, rule)
	_build_game_extras(_tabs.get_node("game") as VBoxContainer)
	_world_note = Label.new()
	_world_note.name = "world_note"
	_world_note.visible = in_world
	_world_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	(_tabs.get_node("graphics") as VBoxContainer).add_child(_world_note)
	_labels.append({ "node": _world_note, "key": "next_world" })
	_close_button = Button.new()
	_close_button.name = "Close"
	_close_button.pressed.connect(close)
	box.add_child(_close_button)

func _ready() -> void:
	GameBus.locale_changed.connect(_on_locale_changed)
	GameBus.tutorial_changed.connect(_sync)
	relocalize()

func _exit_tree() -> void:
	if GameBus.locale_changed.is_connected(_on_locale_changed):
		GameBus.locale_changed.disconnect(_on_locale_changed)
	if GameBus.tutorial_changed.is_connected(_sync):
		GameBus.tutorial_changed.disconnect(_sync)

func _label(parent: Control, key: String) -> Label:
	var l := Label.new()
	l.custom_minimum_size = Vector2(190, 0)
	parent.add_child(l)
	_labels.append({ "node": l, "key": key })
	return l

func _add_row(page: VBoxContainer, key: String, rule: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.name = key
	page.add_child(row)
	if str(rule["type"]) == "bool":
		var c := CheckButton.new()
		c.focus_mode = Control.FOCUS_NONE
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.toggled.connect(func(on: bool) -> void: _commit(key, on))
		row.add_child(c)
		_controls[key] = c
		_labels.append({ "node": c, "key": key })
		return
	_label(row, key)
	match str(rule["type"]):
		"choice":
			var o := OptionButton.new()
			o.focus_mode = Control.FOCUS_NONE
			for v in rule["values"]:
				o.add_item(choice_text(key, str(v)))
			o.item_selected.connect(func(i: int) -> void: _commit(key, str(rule["values"][i])))
			row.add_child(o)
			_controls[key] = o
			_choices[key] = o
		_:
			var s := HSlider.new()
			s.focus_mode = Control.FOCUS_NONE
			s.custom_minimum_size = Vector2(220, 0)
			s.min_value = float(rule["min"])
			s.max_value = float(rule["max"])
			s.step = 1.0 if str(rule["type"]) == "int" else 0.05
			s.drag_started.connect(func() -> void: _dragging = key)
			s.drag_ended.connect(func(_changed: bool) -> void:
				_dragging = ""
				GameSettings.save())
			s.value_changed.connect(func(v: float) -> void: _commit(key, v))
			row.add_child(s)
			_controls[key] = s

func _build_game_extras(page: VBoxContainer) -> void:
	var lang_row := HBoxContainer.new()
	lang_row.name = "language"
	page.add_child(lang_row)
	_label(lang_row, "language")
	_language_button = Button.new()
	_language_button.focus_mode = Control.FOCUS_NONE
	_language_button.pressed.connect(func() -> void: LocaleSettings.set_locale(LocaleSettings.next_locale(), GameBus))
	lang_row.add_child(_language_button)
	var reset := Button.new()
	reset.name = "tutorial_reset"
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(reset_tutorial)
	page.add_child(reset)
	_labels.append({ "node": reset, "key": "tutorial_reset" })
	_controls_list = VBoxContainer.new()
	_controls_list.name = "controls_list"
	page.add_child(_controls_list)

## Write one option and apply it; the live tutorial slice (when there is one) keeps its own state in step.
## A slider mid-drag applies without writing the file; WORLD_KEYS in a live world are saved, not applied.
func _commit(key: String, value: Variant) -> void:
	GameSettings.set_value(key, value, null, _dragging != key,
		not (in_world and GameSettings.WORLD_KEYS.has(key)))
	if key == "tutorial" and is_instance_valid(TutorialCard.active):
		TutorialCard.active.set_enabled(bool(value))

func reset_tutorial() -> void:
	if is_instance_valid(TutorialCard.active):
		TutorialCard.active.restart()
	else:
		GameSettings.reset_tutorial()
		GameSettings.set_value("tutorial", true)
		_sync()

## Put every control on the value now in effect, without writing it back.
func _sync() -> void:
	GameSettings.load_values()
	for key in _controls:
		var c: Control = _controls[key]
		var v: Variant = GameSettings.get_value(key)
		if c is CheckButton:
			(c as CheckButton).set_pressed_no_signal(bool(v))
		elif c is OptionButton:
			(c as OptionButton).select((GameSettings.SPEC[key]["values"] as Array).find(v))
		elif c is HSlider:
			(c as HSlider).set_value_no_signal(float(v))

func _on_locale_changed(_l: String) -> void:
	relocalize()

func relocalize() -> void:
	for e in _labels:
		(e["node"] as Control).set("text", I18n.t("options." + str(e["key"])))
	for i in TABS.size():
		_tabs.set_tab_title(i, I18n.t("options.tab." + str(TABS[i])))
	_language_button.text = _language_text()
	_close_button.text = I18n.t("options.close")
	for key in _choices:
		var o: OptionButton = _choices[key]
		var vals: Array = GameSettings.SPEC[key]["values"]
		for i in vals.size():
			o.set_item_text(i, choice_text(key, str(vals[i])))
	for c in _controls_list.get_children():
		c.free()
	for row in InputLabels.controls_rows():
		var l := Label.new()
		l.text = "%s — %s" % [str(row["keys"]) if int(row["mouse"]) == 0 else I18n.t("options.mouse_button"), str(row["desc"])]
		_controls_list.add_child(l)

## A choice's label: `options.<key>.<value>` when the catalog has it (resolutions show as they are).
static func choice_text(key: String, value: String) -> String:
	var k := "options.%s.%s" % [key, value]
	return I18n.t(k) if I18n.has_key(k) else value

func _language_text() -> String:
	var loc := LocaleSettings.current()
	var key := "locale." + loc
	return I18n.t("settings.language", [I18n.t(key) if I18n.has_key(key) else loc])

func is_open() -> bool:
	return visible

func open() -> void:
	_sync()
	relocalize()
	visible = true

func close() -> void:
	if visible:
		visible = false
		closed.emit()

## The control for a setting key (the suite drives them).
func control(key: String) -> Control:
	return _controls.get(key)
