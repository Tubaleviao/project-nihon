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
const TreeMaterialScript := preload("res://src/world/tree_material.gd")
const TutorialState := preload("res://src/tutorial/tutorial_state.gd")

## Phase 275: the buses come from `res://default_bus_layout.tres` (Master → Music, Effects, Ambience, UI),
## never created at runtime. Each volume option sets one bus.
const BUS_MUSIC := "Music"
const BUS_EFFECTS := "Effects"
const BUS_AMBIENCE := "Ambience"
const BUS_UI := "UI"
const VOLUME_BUSES := {
	"volume_master": "Master", "volume_music": BUS_MUSIC, "volume_effects": BUS_EFFECTS,
	"volume_ambience": BUS_AMBIENCE, "volume_ui": BUS_UI,
}

const WINDOW_MODES := ["windowed", "fullscreen", "borderless"]
const RESOLUTIONS := ["1280x720", "1600x900", "1920x1080", "2560x1440"]
const SCALE_MODES := ["native", "bilinear", "fsr2"]
const TERRAIN_QUALITIES := ["auto", "low", "high"]

## Read once when a world's terrain is built: changed in a live world they are saved but applied only to
## the next one (the haze reads the rings live, so applying mid-world would split fog from terrain).
const WORLD_KEYS := ["view_distance", "terrain_quality"]

## key → rule, grouped by the tab that shows it. The label key of each is `options.<key>`.
const SPEC := {
	"volume_master": { "tab": "sound", "type": "float", "default": 1.0, "min": 0.0, "max": 1.0 },
	"volume_music": { "tab": "sound", "type": "float", "default": 0.8, "min": 0.0, "max": 1.0 },
	"volume_effects": { "tab": "sound", "type": "float", "default": 1.0, "min": 0.0, "max": 1.0 },
	"volume_ambience": { "tab": "sound", "type": "float", "default": 0.8, "min": 0.0, "max": 1.0 },
	"volume_ui": { "tab": "sound", "type": "float", "default": 1.0, "min": 0.0, "max": 1.0 },
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
	"camera_shake": { "tab": "game", "type": "bool", "default": true },   # Phase 287 — a landed hit shakes the camera
	"hit_stop": { "tab": "game", "type": "bool", "default": true },       # Phase 287 — a landed hit freezes the attacker 40 ms
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
## render scale applies to (the root window when null and the tree is up). `persist` false skips the
## file write (a slider mid-drag; `save` runs when it ends). `apply_now` false only saves it.
static func set_value(key: String, raw: Variant, viewport: Viewport = null, persist := true, apply_now := true) -> bool:
	if not SPEC.has(key):
		return false
	if values.is_empty():
		load_values()
	values[key] = sanitize(key, raw)
	if key == "tutorial":
		var st := TutorialState.load_state()
		st["enabled"] = values[key]
		TutorialState.save_state(st)
	elif persist:
		save()
	if apply_now:
		apply(key, viewport)
	return true

## Boot: load the file and apply what the player has saved, so a fresh install keeps the engine's own window,
## scale and FPS; every volume is applied, saved or default, so a bus never plays louder than its slider shows
## (a fresh install, or a file older than the option). Nothing is applied on a headless boot (server, suite).
static func apply_startup(viewport: Viewport = null) -> void:
	load_values()
	if DisplayServer.get_name() == "headless":
		return
	for k in startup_keys(_read_file().get("options", {})):
		apply(k, viewport)

## The options `apply_startup` applies for the file's saved `options`: every volume key, then each other
## saved key (never the tutorial switch). Pure, so the suite pins it on a headless boot.
static func startup_keys(saved: Variant) -> Array:
	var out: Array = VOLUME_BUSES.keys()
	for k in SPEC:
		if k != "tutorial" and not VOLUME_BUSES.has(k) and saved is Dictionary and (saved as Dictionary).has(k):
			out.append(k)
	return out

static func apply_all(viewport: Viewport = null) -> void:
	if values.is_empty():
		load_values()
	for k in SPEC:
		apply(k, viewport)

static func apply(key: String, viewport: Viewport = null) -> void:
	var v: Variant = get_value(key)
	match key:
		"volume_master", "volume_music", "volume_effects", "volume_ambience", "volume_ui":
			_set_bus_volume(str(VOLUME_BUSES[key]), float(v))
		"window_mode", "resolution":
			_apply_window()
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
			# Phase 283: tree sway is off on the low graphics path
			ProjectSettings.set_setting(TreeMaterialScript.SWAY_SETTING, str(v) != "low")
		_:
			pass   # tutorial: saved in the tutorial state; sensitivity and invert are read where used

## Godot's WINDOW_MODE_FULLSCREEN is already a borderless window over the screen; "fullscreen" here is
## the exclusive one.
static func window_mode_enum(mode: String) -> int:
	match mode:
		"fullscreen":
			return DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		"borderless":
			return DisplayServer.WINDOW_MODE_FULLSCREEN
	return DisplayServer.WINDOW_MODE_WINDOWED

## Mode and resolution together: the saved resolution is the windowed size, so going back to windowed
## restores it.
static func _apply_window() -> void:
	var mode := window_mode_enum(str(get_value("window_mode")))
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	DisplayServer.window_set_mode(mode)
	if mode == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_size(resolution_size(str(get_value("resolution"))))

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

static var _warned_buses: Dictionary = {}

## A bus the layout lacks is reported (once), not created: `default_bus_layout.tres` is the one list of buses.
static func _set_bus_volume(bus: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		if not _warned_buses.has(bus):   # once per bus, not on every slider tick
			_warned_buses[bus] = true
			Diag.warn("GameSettings: no audio bus %s in default_bus_layout.tres" % bus)
		return
	AudioServer.set_bus_volume_db(i, linear_to_db(linear))
	AudioServer.set_bus_mute(i, linear <= 0.0)

## Mouse look scale (1.0 = the shipped feel) and the vertical sign (-1 inverts), read by the player.
static func look_scale() -> float:
	return float(get_value("mouse_sensitivity"))

static func look_y_sign() -> float:
	return -1.0 if bool(get_value("invert_y")) else 1.0

## Tutorial reset: nothing done, nothing dismissed. The switch is left as it is (the window turns it on).
static func reset_tutorial() -> void:
	var st := TutorialState.load_state()
	st["done"] = []
	st["dismissed"] = []
	TutorialState.save_state(st)
