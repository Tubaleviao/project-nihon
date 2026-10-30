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
## Phase 196 — true between a click on the rebind button and the next key press (`take_rebind_key`).
static var awaiting_key: bool = false

## The key that opens the wheel: the saved choice, else Q.
static func key_code() -> int:
	if _cached_key >= 0:
		return _cached_key
	_cached_key = DEFAULT_KEY
	if FileAccess.file_exists(LocaleSettings.settings_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LocaleSettings.settings_path))
		if parsed is Dictionary and allowed_key(int((parsed as Dictionary).get(SETTINGS_KEY, 0))):
			_cached_key = int((parsed as Dictionary)[SETTINGS_KEY])
	HotbarScript.gesture_key = _cached_key
	return _cached_key

## Phase 196 — the wheel key as the player sees it ("Q"), for the strings that name it.
static func key_label() -> String:
	return OS.get_keycode_string(key_code())

## Whether `code` may open the wheel: the default, or any key no built-in action claims.
static func allowed_key(code: int) -> bool:
	return code == DEFAULT_KEY or HotbarScript.free_key(code)

## Phase 196 — what a key press means to the wheel (`handle_key`).
enum { KEY_IGNORED, KEY_TOGGLE, KEY_REBOUND, KEY_SWALLOWED }

## Phase 196 — a key press: while a rebind waits, it becomes the wheel key (KEY_REBOUND; an echo or Escape
## is swallowed); else a bare press of the wheel key (no echo, no Ctrl/Alt/Shift/Meta) toggles the wheel,
## unless the hotbar is choosing a box's key.
static func handle_key(event: InputEventKey, hotbar_binding: bool) -> int:
	if awaiting_key:
		if event.echo:
			return KEY_SWALLOWED
		return KEY_REBOUND if take_rebind_key(event.keycode) else KEY_SWALLOWED
	if event.keycode != key_code() or hotbar_binding or event.echo \
			or event.ctrl_pressed or event.alt_pressed or event.shift_pressed or event.meta_pressed:
		return KEY_IGNORED
	return KEY_TOGGLE

## Phase 196 — the key pressed after the rebind button: Escape cancels, any other key is tried with
## `set_key`. Returns whether the wheel now opens on `code`.
static func take_rebind_key(code: int) -> bool:
	awaiting_key = false
	if code == KEY_ESCAPE:
		return false
	return set_key(code)

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
	HotbarScript.gesture_key = code
	return true

## Phase 196 — the rebind button's label: the current key and how to change it.
static func rebind_label() -> String:
	return I18n.t("controls.gesture_key.waiting") if awaiting_key else I18n.t("controls.gesture_key.rebind", [key_label()])

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
	# Phase 196 — the wheel key is chosen here: click, then press the new key (`take_rebind_key`).
	var rebind := Button.new()
	rebind.focus_mode = Control.FOCUS_NONE
	rebind.set_meta("rebind", true)
	rebind.text = rebind_label()
	rebind.pressed.connect(func() -> void:
		awaiting_key = true
		rebind.text = rebind_label())
	box.add_child(rebind)
	return box

## Re-render the button labels (the language changed).
static func relabel(box: Control, table: Dictionary) -> void:
	for child in box.get_children():
		if child is Button and child.has_meta("gesture_id"):
			child.text = label_for(str(child.get_meta("gesture_id")), table)
		elif child is Button and child.has_meta("rebind"):
			child.text = rebind_label()
