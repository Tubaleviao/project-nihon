extends RefCounted
## Phase 220 — key labels read from the action map, so the controls legend follows project.godot. Names come
## from the catalog (`controls.key.<name>`, "Space" / "Espaço"); a key with no row falls back to the OS name.

const I18n := preload("res://src/core/i18n.gd")

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
