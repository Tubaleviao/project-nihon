extends RefCounted
## Phase 159 — the gesture wheel: a window listing every fabric gesture. A click is a `gesture_intent`
## (the same action as typing the gesture's chat command). The key that opens it defaults to Q (G is
## the Proposals window and the tame key) and is rebindable; the choice lives in `user://settings.json`.

const I18n := preload("res://src/core/i18n.gd")
const GestureRules := preload("res://src/character/gesture_rules.gd")
const HotbarScript := preload("res://src/ui/hotbar.gd")
const LocaleSettings := preload("res://src/core/locale_settings.gd")

const DEFAULT_KEY := KEY_Q
const SETTINGS_KEY := "gesture_key"

static var _cached_key: int = -1

## The key that opens the wheel: the saved choice, else Q.
static func key_code() -> int:
	if _cached_key >= 0:
		return _cached_key
	_cached_key = DEFAULT_KEY
	if FileAccess.file_exists(LocaleSettings.settings_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LocaleSettings.settings_path))
		if parsed is Dictionary and allowed_key(int((parsed as Dictionary).get(SETTINGS_KEY, 0))):
			_cached_key = int((parsed as Dictionary)[SETTINGS_KEY])
	return _cached_key

## Whether `code` may open the wheel: the default, or any key the hotbar could take.
static func allowed_key(code: int) -> bool:
	return code == DEFAULT_KEY or HotbarScript.bind_allowed(code)

## Rebind the wheel to `code` and save it next to the language choice. False for a key the game claims.
static func set_key(code: int) -> bool:
	if not allowed_key(code):
		return false
	var data: Dictionary = {}
	if FileAccess.file_exists(LocaleSettings.settings_path):
		var old: Variant = JSON.parse_string(FileAccess.get_file_as_string(LocaleSettings.settings_path))
		if old is Dictionary:
			data = old
	data[SETTINGS_KEY] = code
	var f := FileAccess.open(LocaleSettings.settings_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	_cached_key = code
	return true

## The label of a gesture's button: its translated name and its chat command.
static func label_for(id: String, table: Dictionary) -> String:
	var res: Resource = table[id]
	return "%s  (%s)" % [I18n.t(str(res.get("nameKey"))), str(res.get("chatCommand"))]

## Build the window content: one button per gesture. `on_pick` is called after a button fires its intent.
static func build(table: Dictionary, on_pick: Callable) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	for id in GestureRules.ids(table):
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.text = label_for(id, table)
		btn.set_meta("gesture_id", id)
		btn.pressed.connect(func() -> void:
			GameBus.gesture_intent.emit(id, "")
			if on_pick.is_valid():
				on_pick.call())
		box.add_child(btn)
	return box

## Re-render the button labels (the language changed).
static func relabel(box: Control, table: Dictionary) -> void:
	for child in box.get_children():
		if child is Button and child.has_meta("gesture_id"):
			child.text = label_for(str(child.get_meta("gesture_id")), table)
