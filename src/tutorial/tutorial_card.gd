extends PanelContainer
## Tutorial card (Phase 186) — one small card in a screen corner that does not block play: chapter, title, body
## with the player's own keys, a step counter, **Dismiss** and **Turn off tutorial**. A completed step shows a
## short check, then the next card. Only the display; `TutorialSlice` owns the state.

const I18n := preload("res://src/core/i18n.gd")
const Rules := preload("res://src/tutorial/tutorial_rules.gd")

var slice: Node = null
## The slice the `?` panel's controls drive (set by `bind`).
static var active: Node = null
## Seconds the check stays after a step completes.
const CHECK_SECONDS := 1.5

var _chapter: Label
var _title: Label
var _body: Label
var _counter: Label
var _check: Label
var _check_left: float = 0.0
var _dismiss: Button
var _off: Button

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(300, 0)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_chapter = Label.new()
	_chapter.add_theme_font_size_override("font_size", 12)
	_chapter.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	box.add_child(_chapter)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 16)
	box.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(280, 0)
	box.add_child(_body)
	_check = Label.new()
	_check.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	box.add_child(_check)
	_counter = Label.new()
	_counter.add_theme_font_size_override("font_size", 11)
	box.add_child(_counter)
	var row := HBoxContainer.new()
	box.add_child(row)
	_dismiss = Button.new()
	_dismiss.focus_mode = Control.FOCUS_NONE
	_dismiss.pressed.connect(func() -> void: if slice != null: slice.dismiss_current())
	row.add_child(_dismiss)
	_off = Button.new()
	_off.focus_mode = Control.FOCUS_NONE
	_off.pressed.connect(func() -> void: if slice != null: slice.set_enabled(false))
	row.add_child(_off)
	visible = false

func bind(tutorial: Node) -> void:
	slice = tutorial
	active = tutorial
	GameBus.tutorial_changed.connect(refresh)
	GameBus.locale_changed.connect(func(_l: String) -> void: refresh())
	refresh()

## The player's own key text for each input action a step names, from the `?` rows.
static func keys_for(step: Dictionary, rows: Array) -> String:
	var out: Array = []
	for action in step["inputs"]:
		for row in rows:
			if str(row["action"]) == str(action) and str(row["keys"]) != "":
				out.append(str(row["keys"]))
	return " / ".join(out)

## Redraw for the current step (a completed one keeps its check for CHECK_SECONDS first).
func refresh() -> void:
	if slice == null:
		return
	var step: Dictionary = slice.current_step()
	if step.is_empty() and _check_left <= 0.0:
		visible = false
		return
	visible = true
	_dismiss.text = I18n.t("tutorial.dismiss")
	_off.text = I18n.t("tutorial.turn_off")
	_check.text = I18n.t("tutorial.done") if _check_left > 0.0 else ""
	if step.is_empty():
		return
	var id := str(step["id"])
	var rows: Array = load("res://src/ui/ui_slice.gd").controls_rows()
	_chapter.text = I18n.t("tutorial.chapter.%s" % step["chapter"])
	_title.text = I18n.t("tutorial.%s.title" % id)
	var keys := keys_for(step, rows)
	_body.text = I18n.t("tutorial.%s.body" % id) + ("\n" + keys if keys != "" else "")
	var steps: Array = slice.steps()
	var done: int = (slice.state["done"] as Array).size()
	_counter.text = I18n.t("tutorial.counter", [mini(done + 1, steps.size()), steps.size()])

## A step just completed: show the check for a moment, then the next card.
func show_check() -> void:
	_check_left = CHECK_SECONDS
	refresh()

func _process(delta: float) -> void:
	if _check_left > 0.0:
		_check_left -= delta
		if _check_left <= 0.0:
			refresh()

## The `?` panel's two controls: a toggle and **Restart tutorial**. They are in the "tutorial_settings" group so
## a rebuild of the key rows keeps them.
static func add_settings(box: Control) -> void:
	var toggle := CheckButton.new()
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.add_to_group("tutorial_settings")
	toggle.name = "TutorialToggle"
	box.add_child(toggle)
	var restart := Button.new()
	restart.focus_mode = Control.FOCUS_NONE
	restart.add_to_group("tutorial_settings")
	restart.name = "TutorialRestart"
	box.add_child(restart)
	toggle.text = I18n.t("tutorial.toggle")
	restart.text = I18n.t("tutorial.restart")
	toggle.toggled.connect(func(on: bool) -> void: if active != null: active.set_enabled(on))
	restart.pressed.connect(func() -> void: if active != null: active.restart())
	var sync := func() -> void:
		if active != null:
			toggle.set_pressed_no_signal(bool(active.state["enabled"]))
		toggle.text = I18n.t("tutorial.toggle")
		restart.text = I18n.t("tutorial.restart")
	GameBus.tutorial_changed.connect(sync)
	var on_locale := func(_l: String) -> void: sync.call()
	GameBus.locale_changed.connect(on_locale)
	toggle.tree_exiting.connect(func() -> void:
		GameBus.tutorial_changed.disconnect(sync)
		GameBus.locale_changed.disconnect(on_locale))
	sync.call()
