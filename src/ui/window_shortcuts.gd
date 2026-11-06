extends RefCounted
## Phase 214 — the one table of window shortcuts. Every window opens with Alt plus a letter, so the bare
## letters stay free for movement, combat and the hotbar. The key handler, the window dock's chips, and the `?`
## controls rows are built from `TABLE`; no window letter is written
## anywhere else. A window added later gets a row here.
##
## Kept apart from `UiSlice` (which exposes it as `WINDOW_SHORTCUTS`) so the dock and the hotbar can read it
## without a circular preload.

const I18n := preload("res://src/core/i18n.gd")

## { window, keycode }; Alt is implied. Windows without a row: controls (`?`), gestures (the wheel key) and the
## chest (opened by using a chest or door, never by a hotkey).
const TABLE: Array = [
	{"window": "attributes", "keycode": KEY_A},
	{"window": "skills", "keycode": KEY_S},
	{"window": "inventory", "keycode": KEY_E},
	{"window": "equipment", "keycode": KEY_Q},
	{"window": "clan", "keycode": KEY_G},
	{"window": "crafting", "keycode": KEY_H},
	{"window": "technology", "keycode": KEY_T},
	{"window": "trade", "keycode": KEY_Y},
	{"window": "market", "keycode": KEY_P},
	{"window": "proposals", "keycode": KEY_V},
	{"window": "map", "keycode": KEY_M},
	{"window": "settlement", "keycode": KEY_L},
	{"window": "admin", "keycode": KEY_O},
]

## The window an Alt+key press opens, or "". Matches on `keycode` only (never `unicode`, which holds the Option
## character on macOS), and only with Alt alone: Ctrl or Meta held with Alt does not match.
static func window_for(keycode: int, alt: bool, ctrl: bool, meta: bool) -> String:
	if not alt or ctrl or meta:
		return ""
	for row: Dictionary in TABLE:
		if int(row["keycode"]) == keycode:
			return str(row["window"])
	return ""

static func window_for_event(event: InputEventKey) -> String:
	return window_for(int(event.keycode), event.alt_pressed, event.ctrl_pressed, event.meta_pressed)

## True for an Alt+letter that opens a window: the bare-letter action of the same key must not fire.
static func is_window_key(event: InputEventKey) -> bool:
	return window_for_event(event) != ""

## Keys pressed as part of an Alt+letter window shortcut and not yet released (#558). Such a key must not walk
## even after Alt is released while the letter is still held.
static var _consumed: Dictionary = {}

## Record that `keycode` was pressed as a window shortcut (called by the key handler on a match).
static func consume(keycode: int) -> void:
	_consumed[keycode] = true

static func clear_consumed() -> void:
	_consumed.clear()

## Pure form of `walk_down`: `pressed` is the key's state, `alt` the Alt state. A key consumed by a window
## shortcut stays silent until it is released once; Alt held with a window letter is silent too.
static func walk_held(keycode: int, pressed: bool, alt: bool) -> bool:
	if not pressed:
		_consumed.erase(keycode)
		return false
	if _consumed.has(keycode):
		return false
	return not (alt and window_for(keycode, true, false, false) != "")

## Whether a movement key counts as held: not while Alt is down and Alt+key is a window shortcut (Alt+A, Alt+S),
## nor after Alt is released while that letter is still down.
static func walk_down(keycode: int) -> bool:
	return walk_held(keycode, Input.is_key_pressed(keycode), Input.is_key_pressed(KEY_ALT))

## The keycode of a window's shortcut, or 0.
static func keycode_of(window: String) -> int:
	for row: Dictionary in TABLE:
		if str(row["window"]) == window:
			return int(row["keycode"])
	return 0

## "Alt+A" for a window with a row, "" otherwise. The modifier label is a catalog key.
static func label_of(window: String) -> String:
	var code := keycode_of(window)
	if code == 0:
		return ""
	return "%s+%s" % [I18n.t("controls.key.alt"), OS.get_keycode_string(code)]

## The labels of every row, in table order, joined for the `?` window row ("Alt+A · Alt+S · ...").
static func all_labels() -> String:
	var parts: PackedStringArray = []
	for row: Dictionary in TABLE:
		parts.append(label_of(str(row["window"])))
	return " · ".join(parts)
