extends VBoxContainer
## Chest window (Phase 208) — what the open chest holds, put and take, and (for an owner) who may open it:
## the owner, their clan or everyone. A door shows only its access mode. Presentation only: every button emits
## a `GameBus.chest_intent` and the host decides. All text goes through `I18n`. `source` returns the view the
## host last sent (`ChestWiring.view`).

const I18n := preload("res://src/core/i18n.gd")
const ChestRules := preload("res://src/world/chest_rules.gd")
const REFRESH_SEC := 0.5

## `() -> Dictionary`: what this player has open ({} for nothing).
var source: Callable = Callable()

var _status: Label = null
var _items: Label = null
var _feedback: Label = null
var _item_edit: LineEdit = null
var _qty_edit: LineEdit = null
var _mode_row: HBoxContainer = null
var _item_row: VBoxContainer = null
var _controls: Array = []   # [Control, i18n key]
var _elapsed: float = 0.0

func _init() -> void:
	add_theme_constant_override("separation", 6)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	_mode_row = HBoxContainer.new()
	add_child(_mode_row)
	for mode: Variant in ChestRules.modes():
		var b := Button.new()
		b.pressed.connect(func() -> void: GameBus.chest_intent.emit("mode", { "mode": str(mode) }, ""))
		_mode_row.add_child(b)
		_controls.append([b, "chest.mode." + str(mode)])
	_item_row = VBoxContainer.new()
	add_child(_item_row)
	_items = Label.new()
	_items.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_item_row.add_child(_items)
	_item_edit = _line("chest.item_ph")
	_qty_edit = _line("chest.qty_ph")
	_button("chest.put", func() -> void: GameBus.chest_intent.emit("put", { "item": _item_edit.text.strip_edges(), "qty": _qty() }, ""))
	_button("chest.take", func() -> void: GameBus.chest_intent.emit("take", { "item": _item_edit.text.strip_edges(), "qty": _qty() }, ""))
	var close := Button.new()
	close.pressed.connect(func() -> void: GameBus.chest_intent.emit("close", {}, ""))
	add_child(close)
	_controls.append([close, "chest.close"])
	_feedback = Label.new()
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_feedback)

func _ready() -> void:
	GameBus.chest_resolved.connect(_on_resolved)
	visibility_changed.connect(refresh)
	refresh()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_elapsed += delta
	if _elapsed >= REFRESH_SEC:
		_elapsed = 0.0
		refresh()

func _line(ph_key: String) -> LineEdit:
	var e := LineEdit.new()
	_item_row.add_child(e)
	_controls.append([e, ph_key])
	return e

func _button(key: String, action: Callable) -> void:
	var b := Button.new()
	b.pressed.connect(action)
	_item_row.add_child(b)
	_controls.append([b, key])

func _qty() -> int:
	return int(_qty_edit.text) if _qty_edit.text.is_valid_int() else 0

## The host resolves every player's intents on this bus; it only re-renders here (the actor's result line
## comes as a system message).
func _on_resolved(_player_id: String, _action: String, _ok: bool, _reason: String) -> void:
	refresh()

func view() -> Dictionary:
	var v: Variant = source.call() if source.is_valid() else {}
	return v if v is Dictionary else {}

## Re-render from the last view (also re-applies the active language).
func refresh() -> void:
	for pair: Array in _controls:
		var c: Control = pair[0]
		if c is LineEdit:
			(c as LineEdit).placeholder_text = I18n.t(str(pair[1]))
		elif c is Button:
			(c as Button).text = I18n.t(str(pair[1]))
	var v := view()
	if v.is_empty():
		_status.text = I18n.t("chest.none")
		_mode_row.visible = false
		_item_row.visible = false
		return
	var what := I18n.t("chest.kind.%s" % str(v.get("type", "")))
	_status.text = I18n.t("chest.status", [what, I18n.t("chest.mode." + str(v.get("mode", ""))), int(v.get("hp", 0)), int(v.get("max_hp", 0))])
	_mode_row.visible = bool(v.get("owner", false))
	_item_row.visible = ChestRules.holds_items(str(v.get("type", "")))
	var items: Dictionary = v.get("items", {})
	var keys: Array = items.keys()
	keys.sort()
	var parts: Array = []
	for k: Variant in keys:
		parts.append(I18n.t("chest.item_entry", [str(k), int(items[k])]))
	_items.text = I18n.t("chest.items", [int(v.get("used", 0)), int(v.get("capacity", 0)), ", ".join(parts) if not parts.is_empty() else I18n.t("chest.empty")])
