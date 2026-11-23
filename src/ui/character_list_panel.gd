extends Control
## Phase 226 — the character list shown after choosing a local world or joining a server, before entering it.
##
## One row per character as the host sent it (`RosterView`): its name (or "New character" for one never
## created), its body (body type and a hair-colour swatch) and when it was last played, with Play and Delete.
## New character asks the host for a fresh one (greyed at the limit); Delete opens a confirmation where the
## character's name must be typed, and the host checks it. Back returns to the main menu.
##
## Presentation only: it emits what the player asked for, and the host's next list (`set_view`) is the truth.
## Every label goes through I18n.t(); names are the players' own text.

signal play_requested(id: String)
signal create_requested()
signal delete_requested(id: String, confirm: String)
signal back_requested()

const I18n := preload("res://src/core/i18n.gd")
const RosterView := preload("res://src/character/roster_view.gd")

## `(hair colour index) -> Color` for the body swatch (the character slice's palette); unset draws none.
var palette: Callable = Callable()

var _view: Dictionary = {}
var _list: VBoxContainer = null
var _status: Label = null
var _new_button: Button = null
var _confirm_box: VBoxContainer = null
var _confirm_label: Label = null
var _confirm_edit: LineEdit = null
var _pending_delete: String = ""

func _init() -> void:
	name = "CharacterListPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.09, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	panel.add_child(stack)
	var title := Label.new()
	title.text = I18n.t("characters.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	stack.add_child(title)
	_list = VBoxContainer.new()
	_list.name = "Characters"
	_list.add_theme_constant_override("separation", 6)
	stack.add_child(_list)
	_status = Label.new()
	_status.name = "Status"
	_status.modulate = Color(1.0, 0.55, 0.5)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_status)
	_confirm_box = VBoxContainer.new()
	_confirm_box.name = "Confirm"
	_confirm_box.visible = false
	stack.add_child(_confirm_box)
	_confirm_label = Label.new()
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_box.add_child(_confirm_label)
	_confirm_edit = LineEdit.new()
	_confirm_edit.name = "ConfirmName"
	_confirm_edit.max_length = 64
	_confirm_edit.placeholder_text = I18n.t("characters.delete_placeholder")
	_confirm_box.add_child(_confirm_edit)
	var confirm_row := HBoxContainer.new()
	_confirm_box.add_child(confirm_row)
	_button(confirm_row, "characters.delete_yes", _confirm_delete).name = "ConfirmDelete"
	_button(confirm_row, "menu.cancel", cancel_delete)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	stack.add_child(bottom)
	_new_button = _button(bottom, "characters.new", func() -> void: request_create())
	_new_button.name = "NewCharacter"
	_button(bottom, "menu.back", func() -> void: back_requested.emit())
	_status.text = I18n.t("characters.loading")
	_status.modulate = Color(1, 1, 1, 0.7)

func _button(parent: Control, key: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = I18n.t(key)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

## The host's list (already sanitized). Rebuilds the rows and shows the result's refusal, if any.
func set_view(view: Dictionary) -> void:
	_view = view
	for c in _list.get_children():
		# Freed now, not queued: the list is rebuilt from the host's answer, never from inside one of its rows.
		_list.remove_child(c)
		c.free()
	var chars: Array = view.get("characters", [])
	if chars.is_empty():
		var none := Label.new()
		none.text = I18n.t("characters.none")
		_list.add_child(none)
	for c: Dictionary in chars:
		_list.add_child(_row(c, str(c["id"]) == str(view.get("last", ""))))
	# An account the host does not know yet has no limit to show: its first character is made on joining.
	_new_button.disabled = str(view.get("account", "")) != "" and not RosterView.may_create(view)
	var reason := str((view.get("result", {}) as Dictionary).get("reason", ""))
	_status.modulate = Color(1.0, 0.55, 0.5)
	_status.text = I18n.t(reason) if reason != "" and I18n.has_key(reason) else ""
	if reason == "" and str((view.get("result", {}) as Dictionary).get("op", "")) == "delete":
		cancel_delete()

func view() -> Dictionary:
	return _view

## One character's row: name, body, last played; Play and Delete.
func _row(c: Dictionary, last: bool) -> Control:
	var row := HBoxContainer.new()
	row.name = "Row_" + str(c["id"]).right(8)
	row.add_theme_constant_override("separation", 8)
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(18, 18)
	var look: Dictionary = c.get("look", {})
	swatch.color = palette.call(int(look["hairColor"])) if palette.is_valid() and look.has("hairColor") else Color(0.4, 0.4, 0.45)
	row.add_child(swatch)
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = row_text(c)
	if last:
		label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	row.add_child(label)
	var id := str(c["id"])
	_button(row, "characters.play", func() -> void: play_requested.emit(id)).name = "Play"
	_button(row, "characters.delete", func() -> void: ask_delete(id)).name = "Delete"
	return row

## A row's text in the reader's locale: name · body type · last played.
static func row_text(c: Dictionary) -> String:
	var name := str(c.get("name", ""))
	if name == "":
		name = I18n.t("characters.unnamed")
	var look: Dictionary = c.get("look", {})
	var body := I18n.t("creation.gender." + str(look["gender"])) if look.has("gender") and I18n.has_key("creation.gender." + str(look["gender"])) else I18n.t("characters.body_default")
	var at := int(c.get("last_played", 0))
	if at <= 0:
		return I18n.t("characters.row_never", [name, body])
	return I18n.t("characters.row", [name, body, I18n.date(at)])

func request_create() -> void:
	if str(_view.get("account", "")) == "":
		play_requested.emit("")   # no account yet: the join makes the first character
		return
	create_requested.emit()

## Open the delete confirmation for `id`: the player types its name.
func ask_delete(id: String) -> void:
	var c := RosterView.entry(_view, id)
	if c.is_empty():
		return
	_pending_delete = id
	var name := str(c.get("name", ""))
	# One never named is deleted by typing its handle (the host checks the same).
	_confirm_label.text = I18n.t("characters.delete_confirm", [name if name != "" else str(c.get("handle", ""))])
	_confirm_edit.text = ""
	_confirm_box.visible = true

func cancel_delete() -> void:
	_pending_delete = ""
	_confirm_box.visible = false

## Type the confirmation (the suite and the harness drive the screen with these).
func type_confirm(text: String) -> void:
	_confirm_edit.text = text

func _confirm_delete() -> void:
	if _pending_delete == "":
		return
	delete_requested.emit(_pending_delete, _confirm_edit.text)

func pending_delete() -> String:
	return _pending_delete

func status_text() -> String:
	return _status.text
