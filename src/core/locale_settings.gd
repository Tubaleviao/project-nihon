extends RefCounted
## Phase 131 — which language the player reads. Order: saved preference → OS locale → `en`.
## The choice lives in `user://settings.json` (`{"locale": "pt_BR"}`); `set_locale` applies it,
## saves it and emits `GameBus.locale_changed` so open UI re-renders without a restart.
const I18n := preload("res://src/core/i18n.gd")
const Diag := preload("res://src/core/diag.gd")

static var settings_path: String = "user://settings.json"

## The supported locale matching `raw` ("pt_BR", "pt-BR", "pt_PT" → "pt_BR" by language), or "".
static func match_locale(raw: String) -> String:
	var want := raw.replace("-", "_")
	var all := I18n.locales()
	if all.has(want):
		return want
	var lang := want.split("_")[0].to_lower()
	for loc in all:
		if str(loc).split("_")[0].to_lower() == lang:
			return str(loc)
	return ""

static func saved_locale() -> String:
	if not FileAccess.file_exists(settings_path):
		return ""
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(settings_path))
	if parsed is Dictionary:
		return match_locale(str((parsed as Dictionary).get("locale", "")))
	return ""

## The locale to start in. `os_locale` is injectable for tests.
static func resolve(os_locale: String = "") -> String:
	var saved := saved_locale()
	if saved != "":
		return saved
	var m := match_locale(os_locale if os_locale != "" else OS.get_locale())
	return m if m != "" else I18n.FALLBACK

## Apply the startup locale without saving it.
static func apply_startup(os_locale: String = "") -> String:
	var loc := resolve(os_locale)
	TranslationServer.set_locale(loc)
	return loc

static func current() -> String:
	I18n.ensure_loaded()
	return TranslationServer.get_locale()

## Switch language, persist it and tell the UI. False for an unsupported locale.
static func set_locale(loc: String, bus: Object = null) -> bool:
	var m := match_locale(loc)
	if m == "":
		return false
	TranslationServer.set_locale(m)
	var data: Dictionary = {}
	if FileAccess.file_exists(settings_path):
		var old: Variant = JSON.parse_string(FileAccess.get_file_as_string(settings_path))
		if old is Dictionary:
			data = old
	data["locale"] = m
	var f := FileAccess.open(settings_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))
	else:
		Diag.warn("LocaleSettings: could not write %s" % settings_path)
	if bus != null:
		bus.locale_changed.emit(m)
	return true

## The locale after `current()` in the supported list (the settings cycle button).
static func next_locale() -> String:
	var all := I18n.locales()
	if all.is_empty():
		return I18n.FALLBACK
	return str(all[(all.find(current()) + 1) % all.size()])
