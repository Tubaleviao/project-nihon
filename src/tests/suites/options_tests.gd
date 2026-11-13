extends "res://src/tests/test_support.gd"
## Phase 225 — the options window: every setting round-trips through `user://settings.json` into a fresh
## load and is applied (bus volume, locale, tutorial flag, FPS cap, project settings), invalid values fall back,
## the file's other keys survive, and every label is in both catalog columns.

const GameSettings := preload("res://src/core/game_settings.gd")
const LocaleSettings := preload("res://src/core/locale_settings.gd")
const OptionsWindow := preload("res://src/ui/options_window.gd")
const TutorialState := preload("res://src/tutorial/tutorial_state.gd")
const I18n := preload("res://src/core/i18n.gd")
const PauseMenu := preload("res://src/ui/pause_menu.gd")

func register() -> void:
	_run_test("options: each setting is saved, reloaded in a fresh load and applied", _test_round_trip)
	_run_test("options: invalid or out-of-range values load as defaults or clamp; the file's other keys survive", _test_sanitize)
	_run_test("options: the window's controls write through and a pause menu opens it", _test_window)
	_run_test("options: every label is a key in both en and pt_BR", _test_catalog)

func _with_settings(fn: Callable) -> void:
	var old_path: String = LocaleSettings.settings_path
	var old_locale := TranslationServer.get_locale()
	var old_fps := Engine.max_fps
	var old_rings: Variant = ProjectSettings.get_setting("nihon/graphics/lod_rings")
	var old_quality: Variant = ProjectSettings.get_setting("nihon/graphics/terrain_quality")
	var old_vol: Array = []
	GameSettings.ensure_buses()
	for b in ["Master", "Music", "Effects"]:
		old_vol.append(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(b)))
	LocaleSettings.settings_path = "user://test_settings_p225.json"
	if FileAccess.file_exists(LocaleSettings.settings_path):
		DirAccess.remove_absolute(LocaleSettings.settings_path)
	GameSettings.values = {}
	fn.call()
	if FileAccess.file_exists(LocaleSettings.settings_path):
		DirAccess.remove_absolute(LocaleSettings.settings_path)
	LocaleSettings.settings_path = old_path
	GameSettings.values = {}
	TranslationServer.set_locale(old_locale)
	Engine.max_fps = old_fps
	ProjectSettings.set_setting("nihon/graphics/lod_rings", old_rings)
	ProjectSettings.set_setting("nihon/graphics/terrain_quality", old_quality)
	var i := 0
	for b in ["Master", "Music", "Effects"]:
		var idx := AudioServer.get_bus_index(b)
		AudioServer.set_bus_volume_db(idx, old_vol[i])
		AudioServer.set_bus_mute(idx, false)
		i += 1

func _test_round_trip() -> void:
	_with_settings(func() -> void:
		var changes := {
			"volume_master": 0.5, "volume_music": 0.25, "volume_effects": 0.75, "window_mode": "windowed",
			"resolution": "1600x900", "vsync": false, "view_distance": 3, "fps_cap": 120, "render_scale": 0.75,
			"scale_mode": "fsr2", "terrain_quality": "low", "tutorial": false, "mouse_sensitivity": 1.5, "invert_y": true,
		}
		assert_eq(changes.size(), GameSettings.SPEC.size(), "the test changes every setting")
		var vp := SubViewport.new()
		for k in changes:
			assert_true(GameSettings.set_value(k, changes[k], vp), "%s is accepted" % k)
		# A fresh load from the file reads the same values back.
		GameSettings.values = {}
		var back := GameSettings.load_values()
		for k in changes:
			assert_eq(back[k], changes[k], "%s round-trips through the file" % k)
		# And each was applied.
		var db := func(b: String) -> float: return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(b))
		assert_true(absf(db.call("Master") - linear_to_db(0.5)) < 0.01, "master bus volume applied")
		assert_true(absf(db.call("Music") - linear_to_db(0.25)) < 0.01, "music bus volume applied")
		assert_true(absf(db.call("Effects") - linear_to_db(0.75)) < 0.01, "effects bus volume applied")
		assert_eq(Engine.max_fps, 120, "FPS cap applied")
		assert_eq(int(ProjectSettings.get_setting("nihon/graphics/lod_rings")), 3, "view distance sets the LOD rings")
		assert_eq(int(ProjectSettings.get_setting("nihon/graphics/terrain_quality")), 0, "terrain quality applied")
		assert_eq(vp.scaling_3d_mode, Viewport.SCALING_3D_MODE_FSR2, "FSR 2 upscaling applied")
		assert_true(is_equal_approx(vp.scaling_3d_scale, 0.75), "render scale applied")
		assert_false(bool(TutorialState.load_state()["enabled"]), "the tutorial flag is saved where the tutorial reads it")
		assert_true(is_equal_approx(GameSettings.look_scale(), 1.5) and GameSettings.look_y_sign() == -1.0, "look settings read back")
		# Language: saved preference wins, applied at once.
		assert_true(LocaleSettings.set_locale("pt_BR"), "language switches")
		assert_eq(TranslationServer.get_locale(), "pt_BR", "locale applied")
		assert_eq(LocaleSettings.saved_locale(), "pt_BR", "locale saved beside the options")
		assert_eq(GameSettings.load_values()["volume_music"], 0.25, "saving the locale kept the options")
		vp.free())

func _test_sanitize() -> void:
	_with_settings(func() -> void:
		var f := FileAccess.open(LocaleSettings.settings_path, FileAccess.WRITE)
		f.store_string(JSON.stringify({ "locale": "en", "other": 7, "options": {
			"volume_master": 9.0, "volume_music": "loud", "window_mode": "tiny", "fps_cap": -5, "vsync": 3, "bogus": 1 } }))
		f = null
		var v := GameSettings.load_values()
		assert_eq(v["volume_master"], 1.0, "a volume above 1 clamps")
		assert_eq(v["volume_music"], GameSettings.defaults()["volume_music"], "a string volume is the default")
		assert_eq(v["window_mode"], "windowed", "an unknown choice is the default")
		assert_eq(v["fps_cap"], 0, "a negative cap clamps to 0")
		assert_eq(v["vsync"], true, "a non-bool is the default")
		assert_false(GameSettings.set_value("bogus", 1), "an unknown key is refused")
		assert_true(GameSettings.set_value("invert_y", true), "a change saves")
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LocaleSettings.settings_path))
		assert_eq(raw["other"], 7, "unrelated keys survive a save")
		assert_eq(raw["locale"], "en", "the locale survives a save")
		assert_false((raw["options"] as Dictionary).has("tutorial"), "the tutorial switch is not duplicated under options"))

func _test_window() -> void:
	_with_settings(func() -> void:
		var w := OptionsWindow.new()
		add_child(w)
		w.open()
		assert_true(w.is_open(), "the window opens")
		for k in GameSettings.SPEC:
			assert_true(w.control(k) != null, "a control for %s" % k)
		(w.control("fps_cap") as HSlider).value = 90
		assert_eq(Engine.max_fps, 90, "moving the slider applies at once")
		assert_eq(GameSettings.load_values()["fps_cap"], 90, "and saves")
		(w.control("vsync") as CheckButton).button_pressed = false
		assert_eq(GameSettings.load_values()["vsync"], false, "a toggle saves")
		var opt := w.control("scale_mode") as OptionButton
		opt.select(1)
		opt.item_selected.emit(1)
		assert_eq(GameSettings.load_values()["scale_mode"], "bilinear", "a choice saves")
		w.close()
		assert_false(w.is_open(), "close hides it")
		w.free()
		var m := PauseMenu.new()
		add_child(m)
		m.open()
		assert_true(m.options_enabled(), "the Esc menu's Options is live")
		m.button("options").pressed.emit()
		assert_true(m.options_window() != null and m.options_window().is_open(), "Options opens the window")
		m.close()
		assert_false(m.options_window().is_open(), "closing the menu closes the window")
		m.free())

func _test_catalog() -> void:
	var cats: Dictionary = I18n.parse_csv("res://locale/ui.csv")["catalog"]
	var keys: Array = ["options.close", "options.language", "options.tutorial_reset", "options.mouse_button"]
	for k in GameSettings.SPEC:
		keys.append("options." + str(k))
	for t in OptionsWindow.TABS:
		keys.append("options.tab." + str(t))
	for k in keys:
		for loc in ["en", "pt_BR"]:
			assert_true(cats.has(loc) and str((cats[loc] as Dictionary).get(k, "")) != "", "%s is in %s" % [k, loc])
