extends RefCounted
## Phase 220 — key labels read from the action map, so the controls legend follows project.godot.

## The keyboard keys bound to an input action, joined with " · " ("Space"). "" for an unknown action or
## one with no key bound.
static func action_keys(action: String) -> String:
	if not InputMap.has_action(action):
		return ""
	var out: PackedStringArray = []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var code: Key = ev.keycode if ev.keycode != KEY_NONE else ev.physical_keycode
			if code != KEY_NONE:
				out.append(OS.get_keycode_string(code))
	return " · ".join(out)
