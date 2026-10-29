extends RefCounted
## Tutorial state (Phase 186) — `tutorial.enabled` and the done / dismissed step ids, kept in
## `user://settings.json` beside the locale. Per player on this machine, not per world. A missing or
## corrupt file loads as "tutorial on, nothing done".

const Diag := preload("res://src/core/diag.gd")
const LocaleSettings := preload("res://src/core/locale_settings.gd")

const MAX_IDS := 128
const MAX_ID_LEN := 48

## A fresh state: tutorial on, nothing done or dismissed.
static func fresh() -> Dictionary:
	return { "enabled": true, "done": [], "dismissed": [] }

static func _ids(raw: Variant) -> Array:
	var out: Array = []
	if raw is Array:
		for v in raw:
			if v is String and (v as String).length() <= MAX_ID_LEN and out.size() < MAX_IDS and not out.has(v):
				out.append(v)
	return out

## The file's JSON, or null when it is not JSON (parsed quietly: a corrupt file is expected, not an error).
static func _parse(p: String) -> Variant:
	var json := JSON.new()
	return json.data if json.parse(FileAccess.get_file_as_string(p)) == OK else null

## Read the state from the settings file at `path` (the shared settings path by default).
static func load_state(path: String = "") -> Dictionary:
	var p := path if path != "" else LocaleSettings.settings_path
	if not FileAccess.file_exists(p):
		return fresh()
	var parsed: Variant = _parse(p)
	if not (parsed is Dictionary) or not ((parsed as Dictionary).get("tutorial", null) is Dictionary):
		return fresh()
	var raw: Dictionary = (parsed as Dictionary)["tutorial"]
	var enabled: Variant = raw.get("enabled", true)
	return { "enabled": enabled if enabled is bool else true, "done": _ids(raw.get("done")), "dismissed": _ids(raw.get("dismissed")) }

## Write `state` under `tutorial` in the settings file, keeping the other keys (the locale).
static func save_state(state: Dictionary, path: String = "") -> bool:
	var p := path if path != "" else LocaleSettings.settings_path
	var data: Dictionary = {}
	if FileAccess.file_exists(p):
		var old: Variant = _parse(p)
		if old is Dictionary:
			data = old
	data["tutorial"] = { "enabled": bool(state.get("enabled", true)), "done": _ids(state.get("done")), "dismissed": _ids(state.get("dismissed")) }
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		Diag.warn("TutorialState: could not write %s" % p)
		return false
	f.store_string(JSON.stringify(data))
	return true
