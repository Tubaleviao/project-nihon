extends Control
## Phase 264 — how many of a stack to drop: the item's icon and name, a slider from 1 to the stack size,
## a number field kept equal to it, 1 / half / all buttons, then Drop and Cancel.
##
## Presentation only. It covers the screen (a dimmed backdrop that swallows clicks, so none reaches the
## world) and says what the player chose through its signals; `UiSlice` opens it for a world drop of a
## stack above one and turns `confirmed` into `request_drop` (the host still clamps to what the bag holds).
## The number field takes the keyboard when the dialog opens and keeps it: the slider and buttons never take
## focus, so while the dialog is up no world input leaks through (Phase 219, `TextFocus.is_typing()`).
## Enter confirms and Esc cancels; `UiSlice._input` routes them here before the field's own Esc handling.

const I18n := preload("res://src/core/i18n.gd")

signal confirmed(item_id: String, quantity: int)
signal cancelled

var item_id: String = ""
var count: int = 1

var _icon: TextureRect = null
var _name: Label = null
var _title: Label = null
var _slider: HSlider = null
var _field: LineEdit = null
## [{button, key}] — re-applied on a language switch.
var _texts: Array = []
var _buttons: Dictionary = {}

func _init() -> void:
	name = "DropQuantityDialog"
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.35)
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
	box.custom_minimum_size = Vector2(300, 0)
	panel.add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	var head := HBoxContainer.new()
	box.add_child(head)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(32, 32)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(_icon)
	_name = Label.new()
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_name)
	var row := HBoxContainer.new()
	box.add_child(row)
	_slider = HSlider.new()
	_slider.min_value = 1
	_slider.step = 1
	_slider.rounded = true
	_slider.focus_mode = Control.FOCUS_NONE
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.value_changed.connect(_on_slider_changed)
	row.add_child(_slider)
	_field = LineEdit.new()
	_field.custom_minimum_size = Vector2(64, 0)
	_field.text_changed.connect(_on_field_changed)
	row.add_child(_field)
	var quick := HBoxContainer.new()
	box.add_child(quick)
	_button(quick, "ui.drop_qty_one", func() -> void: set_quantity(1))
	_button(quick, "ui.drop_qty_half", func() -> void: set_quantity(half_of(count)))
	_button(quick, "ui.drop_qty_all", func() -> void: set_quantity(count))
	var actions := HBoxContainer.new()
	box.add_child(actions)
	_button(actions, "ui.drop_qty_confirm", confirm)
	_button(actions, "ui.drop_qty_cancel", cancel)
	relocalize()

func _ready() -> void:
	GameBus.locale_changed.connect(_on_locale_changed)

func _exit_tree() -> void:
	if GameBus.locale_changed.is_connected(_on_locale_changed):
		GameBus.locale_changed.disconnect(_on_locale_changed)

func _button(parent: Control, key: String, cb: Callable) -> Button:
	var b := Button.new()
	b.name = key.get_slice(".", 1)
	b.focus_mode = Control.FOCUS_NONE   # the number field keeps the keyboard
	b.pressed.connect(cb)
	parent.add_child(b)
	_texts.append({ "button": b, "key": key })
	_buttons[key.trim_prefix("ui.drop_qty_")] = b
	return b

func _on_locale_changed(_locale: String) -> void:
	relocalize()

func relocalize() -> void:
	_title.text = I18n.t("ui.drop_qty_title")
	for e in _texts:
		(e["button"] as Button).text = I18n.t(str(e["key"]))

## The name shown beside the icon. Phase 267 routes item names through the content catalog; until then the
## inventory shows the id, and so does this.
static func item_name(id: String) -> String:
	return id

## The "half" button: half the stack rounded up, never below 1.
static func half_of(n: int) -> int:
	return maxi(1, (n + 1) / 2)

## Open for `qty` of `id`: the range is 1..qty and it starts at the whole stack.
func open(id: String, qty: int, icon: Texture2D = null) -> void:
	item_id = id
	count = maxi(1, qty)
	_icon.texture = icon
	_icon.visible = icon != null
	_name.text = item_name(id)
	_slider.max_value = count
	set_quantity(count)
	visible = true
	if is_inside_tree():
		_field.grab_focus()
		_field.select_all()

func close() -> void:
	visible = false
	if _field.has_focus():
		_field.release_focus()

func is_open() -> bool:
	return visible

func quantity() -> int:
	return int(_slider.value)

## Set both controls to `q`, clamped to 1..count.
func set_quantity(q: int) -> void:
	var v := clampi(q, 1, count)
	_slider.set_value_no_signal(v)
	if _field.text != str(v):
		_field.text = str(v)

func _on_slider_changed(v: float) -> void:
	set_quantity(int(v))

## Typing a number moves the slider; a value out of range is clamped in the field too. An empty or partial
## field (being edited) leaves the slider where it is until it holds a number.
func _on_field_changed(text: String) -> void:
	if not text.is_valid_int():
		return
	var caret := _field.caret_column
	set_quantity(int(text))
	_field.caret_column = mini(caret, _field.text.length())

func confirm() -> void:
	if not visible:
		return
	var q := quantity()
	var id := item_id
	close()
	confirmed.emit(id, q)

func cancel() -> void:
	if not visible:
		return
	close()
	cancelled.emit()

## Enter confirms and Esc cancels. Returns true when the key was the dialog's.
func handle_key(event: InputEvent) -> bool:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return false
	match (event as InputEventKey).keycode:
		KEY_ENTER, KEY_KP_ENTER:
			confirm()
			return true
		KEY_ESCAPE:
			cancel()
			return true
	return false

## The suite drives the controls directly.
func slider() -> HSlider:
	return _slider

func field() -> LineEdit:
	return _field

func button(choice: String) -> Button:
	return _buttons.get(choice, null)
