extends RefCounted
## Phase 225 — the player's options: sound, graphics and game settings, kept under `options` in
## `user://settings.json` beside the locale and the tutorial state (other keys are never touched).
## `set_value` validates against `SPEC`, saves, and applies at once; `load_values` + `apply_all` run at boot.
##
## Each entry of `SPEC` is `{ type, default, ... }`: `float` (min, max), `int` (min, max), `bool`, or
## `choice` (values). Anything out of range or of the wrong type loads as the default.

const Diag := preload("res://src/core/diag.gd")
const LocaleSettings := preload("res://src/core/locale_settings.gd")
const LodRingPolicy := preload("res://src/terrain/lod_ring_policy.gd")
const TerrainMaterialScript := preload("res://src/terrain/terrain_material.gd")
const TutorialState := preload("res://src/tutorial/tutorial_state.gd")

const BUS_MUSIC := "Music"
const BUS_EFFECTS := "Effects"

const WINDOW_MODES := ["windowed", "fullscreen", "borderless"]
const RESOLUTIONS := ["1280x720", "1600x900", "1920x1080", "2560x1440"]
const SCALE_MODES := ["native", "bilinear", "fsr2"]
const TERRAIN_QUALITIES := ["auto", "low", "high"]

## key → rule, grouped by the tab that shows it. The label key of each is `options.<key>`.
const SPEC := {
	"volume_master": { "tab": "sound", "type": "float", "default": 1.0, "min": 0.0, "max": 1.0 },
	"volume_music": { "tab": "sound", "type": "float", "default": 0.8, "min": 0.0, "max": 1.0 },
	"volume_effects": { "tab": "sound", "type": "float", "default": 1.0, "min": 0.0, "max": 1.0 },
	"window_mode": { "tab": "graphics", "type": "choice", "default": "windowed", "values": WINDOW_MODES },
	"resolution": { "tab": "graphics", "type": "choice", "default": "1920x1080", "values": RESOLUTIONS },
	"vsync": { "tab": "graphics", "type": "bool", "default": true },
	"view_distance": { "tab": "graphics", "type": "int", "default": 5, "min": 0, "max": 6 },
	"fps_cap": { "tab": "graphics", "type": "int", "default": 0, "min": 0, "max": 360 },
	"render_scale": { "tab": "graphics", "type": "float", "default": 1.0, "min": 0.5, "max": 1.0 },
	"scale_mode": { "tab": "graphics", "type": "choice", "default": "native", "values": SCALE_MODES },
	"terrain_quality": { "tab": "graphics", "type": "choice", "default": "auto", "values": TERRAIN_QUALITIES },
	"tutorial": { "tab": "game", "type": "bool", "default": true },
	"mouse_sensitivity": { "tab": "game", "type": "float", "default": 1.0, "min": 0.2, "max": 3.0 },
	"invert_y": { "tab": "game", "type": "bool", "default": false },
}

## The values in effect; `load_values` replaces them from the file.
static var values: Dictionary = {}

static func defaults() -> Dictionary:
	var d := {}
	for k in SPEC:
		d[k] = (SPEC[k] as Dictionary)["default"]
	return d

## `raw` coerced to the rule of `key`, or the default when it does not fit.
static func sanitize(key: String, raw: Variant) -> Variant:
	var rule: Dictionary = SPEC[key]
	match str(rule["type"]):
		"bool":
			return raw if raw is bool else rule["default"]
		"float":
			if (raw is float or raw is int) and is_finite(float(raw)):
				return clampf(float(raw), float(rule["min"]), float(rule["max"]))
		"int":
			if raw is float or raw is int:
				return clampi(int(raw), int(rule["min"]), int(rule["max"]))
		"choice":
			if raw is String and (rule["values"] as Array).has(raw):
				return raw
	return rule["default"]

static func _read_file() -> Dictionary:
	if not FileAccess.file_exists(LocaleSettings.settings_path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(LocaleSettings.settings_path)) == OK and json.data is Dictionary:
		return json.data
	return {}

## Read every option from the settings file (defaults for what is missing or invalid) into `values`.
## The tutorial switch lives in the tutorial state, where Phase 186 keeps it.
static func load_values() -> Dictionary:
	var raw: Variant = _read_file().get("options", {})
	var src: Dictionary = raw if raw is Dictionary else {}
	values = defaults()
	for k in SPEC:
		if k != "tutorial" and src.has(k):
			values[k] = sanitize(k, src[k])
	values["tutorial"] = bool(TutorialState.load_state()["enabled"])
	return values

static func get_value(key: String) -> Variant:
	if values.is_empty():
		load_values()
	return values[key]

## Write every option but the tutorial switch under `options`, keeping the file's other keys.
static func save() -> bool:
	var data := _read_file()
	var out := {}
	for k in SPEC:
		if k != "tutorial":
			out[k] = values[k]
	data["options"] = out
	var f := FileAccess.open(LocaleSettings.settings_path, FileAccess.WRITE)
	if f == null:
		Diag.warn("GameSettings: could not write %s" % LocaleSettings.settings_path)
		return false
	f.store_string(JSON.stringify(data))
	return true

## Change one option: validate, apply, save. False for an unknown key. `viewport` is the one the
## render scale applies to (the root window when null and the tree is up).
static func set_value(key: String, raw: Variant, viewport: Viewport = null) -> bool:
	if not SPEC.has(key):
		return false
	if values.is_empty():
		load_values()
	values[key] = sanitize(key, raw)
	if key == "tutorial":
		var st := TutorialState.load_state()
		st["enabled"] = values[key]
		TutorialState.save_state(st)
	else:
		save()
	apply(key, viewport)
	return true

## Boot: load the file and apply only what the player has saved, so a fresh install keeps the engine's
## own window, scale and FPS. Nothing is applied on a headless boot (server, suite).
static func apply_startup(viewport: Viewport = null) -> void:
	load_values()
	if DisplayServer.get_name() == "headless":
		return
	var saved: Variant = _read_file().get("options", {})
	for k in SPEC:
		if k != "tutorial" and saved is Dictionary and (saved as Dictionary).has(k):
			apply(k, viewport)

static func apply_all(viewport: Viewport = null) -> void:
	if values.is_empty():
		load_values()
	for k in SPEC:
		apply(k, viewport)

static func apply(key: String, viewport: Viewport = null) -> void:
	var v: Variant = get_value(key)
	match key:
		"volume_master":
			_set_bus_volume("Master", float(v))
		"volume_music":
			_set_bus_volume(BUS_MUSIC, float(v))
		"volume_effects":
			_set_bus_volume(BUS_EFFECTS, float(v))
		"window_mode":
			DisplayServer.window_set_mode(window_mode_enum(str(v)))
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, str(v) == "borderless")
		"resolution":
			if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
				DisplayServer.window_set_size(resolution_size(str(v)))
		"vsync":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(v) else DisplayServer.VSYNC_DISABLED)
		"view_distance":
			ProjectSettings.set_setting(LodRingPolicy.RINGS_SETTING, int(v))
		"fps_cap":
			Engine.max_fps = int(v)
		"render_scale", "scale_mode":
			var vp := viewport
			if vp == null and Engine.get_main_loop() is SceneTree:
				vp = (Engine.get_main_loop() as SceneTree).root
			if vp != null:
				var mode: String = str(get_value("scale_mode"))
				vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2 if mode == "fsr2" else Viewport.SCALING_3D_MODE_BILINEAR
				vp.scaling_3d_scale = 1.0 if mode == "native" else float(get_value("render_scale"))
		"terrain_quality":
			ProjectSettings.set_setting(TerrainMaterialScript.QUALITY_SETTING, terrain_quality_setting(str(v)))
		_:
			pass   # tutorial: saved in the tutorial state; sensitivity and invert are read where used

static func window_mode_enum(mode: String) -> int:
	return DisplayServer.WINDOW_MODE_FULLSCREEN if mode == "fullscreen" else DisplayServer.WINDOW_MODE_WINDOWED

static func resolution_size(res: String) -> Vector2i:
	var p := res.split("x")
	return Vector2i(int(p[0]), int(p[1])) if p.size() == 2 else Vector2i(1920, 1080)

static func terrain_quality_setting(q: String) -> int:
	match q:
		"low":
			return TerrainMaterialScript.QUALITY_LOW
		"high":
			return TerrainMaterialScript.QUALITY_HIGH
	return TerrainMaterialScript.QUALITY_AUTO

## The Music / Effects buses (sends to Master) are created on first use: the project ships no layout yet.
static func ensure_buses() -> void:
	for n in [BUS_MUSIC, BUS_EFFECTS]:
		if AudioServer.get_bus_index(n) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, n)
			AudioServer.set_bus_send(i, "Master")

static func _set_bus_volume(bus: String, linear: float) -> void:
	ensure_buses()
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(linear))
		AudioServer.set_bus_mute(i, linear <= 0.0)

## Mouse look scale (1.0 = the shipped feel) and the vertical sign (-1 inverts), read by the player.
static func look_scale() -> float:
	return float(get_value("mouse_sensitivity"))

static func look_y_sign() -> float:
	return -1.0 if bool(get_value("invert_y")) else 1.0

## Tutorial reset: nothing done, nothing dismissed, the switch as it is.
static func reset_tutorial() -> void:
	var st := TutorialState.load_state()
	st["done"] = []
	st["dismissed"] = []
	TutorialState.save_state(st)
