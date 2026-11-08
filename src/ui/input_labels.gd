extends RefCounted
## Phase 220 — key labels read from the action map, so the controls legend follows project.godot. Names come
## from the catalog (`controls.key.<name>`, "Space" / "Espaço"); a key with no row falls back to the OS name.

const I18n := preload("res://src/core/i18n.gd")
const WindowShortcuts := preload("res://src/ui/window_shortcuts.gd")

## Gamepad buttons with a catalog row, by button index.
const PAD_KEYS := { JOY_BUTTON_A: "controls.key.pad_south" }

## The keys bound to an input action, joined with " · " ("Space"), in the active locale. Gamepad buttons are
## listed only with `with_pad`. "" for an unknown action or one with nothing bound.
static func action_keys(action: String, with_pad: bool = false) -> String:
	if not InputMap.has_action(action):
		return ""
	var out: PackedStringArray = []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var code: Key = ev.keycode if ev.keycode != KEY_NONE else ev.physical_keycode
			if code != KEY_NONE:
				out.append(key_name(code))
		elif with_pad and ev is InputEventJoypadButton and PAD_KEYS.has(ev.button_index):
			out.append(I18n.t(PAD_KEYS[ev.button_index]))
	return " · ".join(out)

## One key's name: its catalog row (`controls.key.space`) when there is one, else the OS name.
static func key_name(code: Key) -> String:
	var os_name := OS.get_keycode_string(code)
	var key := "controls.key." + os_name.to_lower().replace(" ", "_")
	return I18n.t(key) if I18n.has_key(key) else os_name

## The `?` legend (moved out of ui_slice.gd for its line cap, Phase 220; `UiSlice.controls_rows()` delegates here). Each row:
## { action, keys, desc, mouse } where `mouse` is a MouseButton for a drawn cue, or 0. `action` is the
## id a tutorial step names in `inputs` (Phase 184, `Tutorial.inputActions`), in this row order.
static func controls_rows() -> Array:
	return [
		{"action": "move", "keys": "WASD", "desc": I18n.t("controls.row0"), "mouse": 0},
		{"action": "jump", "keys": action_keys("jump"), "desc": I18n.t("controls.row1"), "mouse": 0},
		{"action": "look", "keys": I18n.t("controls.key.hold"), "desc": I18n.t("controls.row2"), "mouse": MOUSE_BUTTON_RIGHT},
		{"action": "zoom", "keys": I18n.t("controls.key.scroll"), "desc": I18n.t("controls.row3"), "mouse": 0},
		{"action": "hotbar_use", "keys": "1 – 9", "desc": I18n.t("controls.row4"), "mouse": 0},
		{"action": "hotbar_expand", "keys": "▴", "desc": I18n.t("controls.row5"), "mouse": 0},
		{"action": "drag", "keys": I18n.t("controls.key.drag"), "desc": I18n.t("controls.row6"), "mouse": 0},
		{"action": "attack", "keys": "", "desc": I18n.t("controls.row7"), "mouse": MOUSE_BUTTON_LEFT},
		{"action": "mine", "keys": "Shift +", "desc": I18n.t("controls.row8"), "mouse": MOUSE_BUTTON_LEFT},
		{"action": "place", "keys": "", "desc": I18n.t("controls.row9"), "mouse": MOUSE_BUTTON_MIDDLE},
		{"action": "next_block", "keys": "R", "desc": I18n.t("controls.row10"), "mouse": 0},
		{"action": "station", "keys": "B · V", "desc": I18n.t("controls.row11"), "mouse": 0},
		{"action": "tame", "keys": "G", "desc": I18n.t("controls.row12"), "mouse": 0},
		{"action": "mount", "keys": "M", "desc": I18n.t("controls.row19"), "mouse": 0},
		{"action": "equipment", "keys": "E", "desc": I18n.t("controls.row13"), "mouse": 0},
		{"action": "chest", "keys": "U · Shift+U · Ctrl+U", "desc": I18n.t("controls.row18"), "mouse": 0},
		{"action": "windows", "keys": WindowShortcuts.all_labels(), "desc": I18n.t("controls.row14"), "mouse": 0},
		{"action": "controls", "keys": "?", "desc": I18n.t("controls.row15"), "mouse": 0},
		{"action": "chat", "keys": "Enter · /", "desc": I18n.t("controls.row16"), "mouse": 0},
		{"action": "close", "keys": "ESC", "desc": I18n.t("controls.row17"), "mouse": 0},
	]
