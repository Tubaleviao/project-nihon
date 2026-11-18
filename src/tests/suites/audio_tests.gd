extends "res://src/tests/test_support.gd"
## Phase 275 — the audio foundation: the bus layout ships Master → Music, Effects, Ambience, UI; every event of
## the fabric's sound table has its files, in the manifest, and each decodes from its `.ogg.raw` bytes; an
## unknown event or a missing key plays nothing and warns once; `Sound.play` builds a player on the event's bus
## with its volume, a variant and a pitch inside the jitter; a mounted pack overrides a sound by key.
## (The volume options applying to the new buses are pinned in `options_tests.gd`.)

const SoundEvents := preload("res://src/audio/sound_events.gd")
const GameRoot := preload("res://src/core/game_root.gd")

func register() -> void:
	_run_test("audio: the bus layout is Master → Music, Effects, Ambience, UI, as the fabric names them", _test_bus_layout)
	_run_test("audio: every event has its files, listed in the manifest and nothing else", _test_event_keys)
	_run_test("audio: every placeholder decodes from its .ogg.raw bytes", _test_placeholders_decode)
	_run_test("audio: an unknown event or a missing key is silent and warns once", _test_missing_is_safe)
	_run_test("audio: play puts the event on its bus with its volume, a variant and its jitter", _test_play)
	_run_test("audio: a looping event plays until stopped; stop and stop_all free the players", _test_loops_and_stop)
	_run_test("audio: a sound in a mounted pack overrides the placeholder at its key", _test_pack_override)
	_run_test("audio: a truncated .ogg.raw (length 0) or a key not ending in .ogg.raw loads nothing, warns once", _test_truncated_and_bad_key)
	_run_test("audio: a loop flag never changes the cached stream another event shares", _test_loop_not_shared)
	_run_test("audio: a dedicated-server boot turns Sound off; a client boot leaves it on", _test_server_boot_disables_sound)

func _test_bus_layout() -> void:
	var want := ["Master"] + SoundEvents.buses()
	assert_eq(SoundEvents.buses(), ["Music", "Effects", "Ambience", "UI"], "the fabric names the four buses")
	assert_eq(AudioServer.bus_count, want.size(), "the layout has exactly Master and the four buses")
	for i in want.size():
		assert_eq(AudioServer.get_bus_name(i), want[i], "bus %d is %s" % [i, want[i]])
		if i > 0:
			assert_eq(str(AudioServer.get_bus_send(i)), "Master", "%s sends to Master" % want[i])
	assert_eq(str(ProjectSettings.get_setting("audio/buses/default_bus_layout")), "res://default_bus_layout.tres",
		"the project names the committed layout")

func _test_event_keys() -> void:
	assert_true(SoundEvents.ids().size() > 0, "the table has events")
	for id in SoundEvents.ids():
		var ev := SoundEvents.event(id)
		var files := SoundEvents.files(id)
		assert_eq(files.size(), int(ev["variants"]), "%s has one file per variant" % id)
		assert_true(AudioServer.get_bus_index(str(ev["bus"])) > 0, "%s plays on a layout bus (%s)" % [id, ev["bus"]])
		for k in files:
			assert_true(str(k).begins_with(str(ev["key"])) and str(k).ends_with(".ogg.raw"), "%s file %s follows its key" % [id, k])
			assert_true(FileAccess.file_exists(AssetOverlay.resolve_path(k)), "%s key %s has a file" % [id, k])
			assert_true(AssetOverlay.has_key("sounds", k), "%s key %s is in the manifest" % [id, k])
	assert_eq(AssetOverlay.keys("sounds"), SoundEvents.all_files(), "the manifest lists exactly the events' keys")
	assert_true(SoundEvents.event("nope.nothing").is_empty() and SoundEvents.files("nope.nothing").is_empty(),
		"an unknown id has no row and no files")

func _test_placeholders_decode() -> void:
	AssetOverlay.clear_sound_cache()
	for k in SoundEvents.all_files():
		var s := AssetOverlay.load_sound(k)
		assert_true(s is AudioStreamOggVorbis, "%s decodes as Ogg Vorbis" % k)
		if s != null:
			assert_true(s.get_length() > 0.03 and s.get_length() < 10.0, "%s has a placeholder's length (%.2f s)" % [k, s.get_length()])
			assert_true(AssetOverlay.load_sound(k) == s, "%s is cached" % k)
	AssetOverlay.clear_sound_cache()

func _test_missing_is_safe() -> void:
	AssetOverlay.clear_sound_cache()
	var w := Diag.warn_count()
	assert_true(AssetOverlay.load_sound("sounds/ui/__missing_probe.ogg.raw") == null, "a missing key loads nothing")
	assert_true(AssetOverlay.load_sound("sounds/ui/__missing_probe.ogg.raw") == null, "and nothing again")
	assert_eq(Diag.warn_count(), w + 1, "a missing key warns once")
	w = Diag.warn_count()
	assert_true(Sound.play("nope.__unknown_probe") == null, "an unknown event plays nothing")
	assert_true(Sound.play("nope.__unknown_probe", Vector3.ONE) == null, "nor at a position")
	assert_eq(Diag.warn_count(), w + 1, "an unknown event warns once")
	assert_eq(Sound.get_child_count(), 0, "no player was made")
	Sound.enabled = false
	assert_true(Sound.play("ui.click") == null, "a disabled player plays nothing")
	Sound.enabled = true
	AssetOverlay.clear_sound_cache()

func _test_play() -> void:
	Sound.rng.seed = 275
	var ui := Sound.play("ui.click")
	assert_true(ui is AudioStreamPlayer, "a UI event is a 2D player")
	if ui is AudioStreamPlayer:
		assert_eq(str((ui as AudioStreamPlayer).bus), "UI", "on the UI bus")
		assert_true(is_equal_approx((ui as AudioStreamPlayer).volume_db, float(SoundEvents.event("ui.click")["volumeDb"])), "at the event's volume")
		assert_eq((ui as AudioStreamPlayer).pitch_scale, 1.0, "no jitter means pitch 1")
		assert_true(ui.get_parent() == Sound, "the player is the autoload's child")
	var at := Vector3(3, 4, 5)
	var step := Sound.play("footstep.grass", at)
	assert_true(step is AudioStreamPlayer3D, "a 3D event at a position is a 3D player")
	if step is AudioStreamPlayer3D:
		var p3 := step as AudioStreamPlayer3D
		assert_eq(str(p3.bus), "Effects", "on the Effects bus")
		assert_eq(p3.position, at, "at the given position")
		assert_true(is_equal_approx(p3.max_distance, float(SoundEvents.event("footstep.grass")["maxDistance"])), "with the event's range")
	assert_true(Sound.play("footstep.grass") is AudioStreamPlayer, "a 3D event with no position plays 2D")
	# Variants and jitter, over the pure plan.
	var jitter := float(SoundEvents.event("footstep.grass")["pitchJitter"])
	var seen := {}
	for i in 60:
		var p := Sound.plan("footstep.grass", at)
		seen[p["key"]] = true
		assert_true(absf(float(p["pitch_scale"]) - 1.0) <= jitter + 1e-6, "pitch stays inside the jitter")
	assert_eq(seen.size(), SoundEvents.files("footstep.grass").size(), "every variant is picked")
	assert_true(Sound.plan("nope.nothing").is_empty(), "an unknown event has no plan")
	assert_eq(Sound.playing("footstep.grass").size(), 2, "both footsteps are alive until they finish")
	Sound.stop_all()
	assert_eq(Sound.get_child_count(), 0, "stop_all frees every player")

func _test_loops_and_stop() -> void:
	var amb := Sound.play("ambience.TemperateForest")
	var music := Sound.play("music.main_theme")
	assert_true(amb is AudioStreamPlayer and music is AudioStreamPlayer, "ambience and music are 2D players")
	if amb is AudioStreamPlayer:
		var s := (amb as AudioStreamPlayer).stream as AudioStreamOggVorbis
		assert_true(s != null and s.loop, "an ambience stream loops")
		assert_eq(str((amb as AudioStreamPlayer).bus), "Ambience", "on the Ambience bus")
		assert_false((amb as AudioStreamPlayer).finished.is_connected((amb as AudioStreamPlayer).queue_free), "a loop is not freed on finish")
	if music is AudioStreamPlayer:
		assert_eq(str((music as AudioStreamPlayer).bus), "Music", "music is on the Music bus")
	var click := Sound.play("ui.click")
	if click is AudioStreamPlayer:
		var cs := (click as AudioStreamPlayer).stream as AudioStreamOggVorbis
		assert_true(cs != null and not cs.loop, "a one-shot does not loop")
		assert_true((click as AudioStreamPlayer).finished.is_connected((click as AudioStreamPlayer).queue_free), "a one-shot frees itself on finish")
	Sound.stop("ambience.TemperateForest")
	assert_eq(Sound.playing("ambience.TemperateForest").size(), 0, "stop ends the loop")
	assert_eq(Sound.playing("music.main_theme").size(), 1, "and leaves the other events")
	Sound.stop_all()
	assert_eq(Sound.get_child_count(), 0, "stop_all frees the rest")

## Packs `bytes` at the overlay path of `rel` in a fixture pck and mounts it (replacing files already mounted).
func _mount_overlay_sound(rel: String, bytes: PackedByteArray, tag: String) -> void:
	var src_path := "user://_p275_%s_src.raw" % tag
	var f := FileAccess.open(src_path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()
	var fixture := "user://_p275_%s.pck" % tag
	var packer := PCKPacker.new()
	assert_eq(packer.pck_start(fixture), OK, "fixture pck starts")
	assert_eq(packer.add_file(AssetOverlay.OVERLAY_PREFIX + rel, src_path), OK, "the overlay sound is added")
	assert_eq(packer.flush(), OK, "fixture pck written")
	assert_true(ProjectSettings.load_resource_pack(fixture, true), "fixture pck mounts")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(src_path))
	# The pck stays on disk: a mounted pack is read from its file, and Godot cannot unmount it.

func _test_pack_override() -> void:
	# `ui/click` has a public placeholder; the pack puts the music's bytes at its key, and they win.
	const REL := "sounds/ui/click.ogg.raw"
	AssetOverlay.clear_sound_cache()
	var public := AssetOverlay.load_sound(REL)
	var music := AssetOverlay.load_sound("sounds/music/main_theme.ogg.raw")
	assert_true(public != null and music != null, "the placeholders decode")
	if public == null or music == null:
		return
	assert_false(is_equal_approx(public.get_length(), music.get_length()), "click and music differ in length")
	AssetOverlay.clear_sound_cache()
	_mount_overlay_sound(REL, FileAccess.get_file_as_bytes("res://assets/sounds/music/main_theme.ogg.raw"), "override")
	var s := AssetOverlay.load_sound(REL)
	assert_true(s != null, "the overlaid key decodes")
	if s != null:
		assert_true(is_equal_approx(s.get_length(), music.get_length()), "the production pack wins over the placeholder")
	# Put the public bytes back under the overlay path so later tests hear the placeholder again.
	_mount_overlay_sound(REL, FileAccess.get_file_as_bytes("res://assets/" + REL), "restore")
	AssetOverlay.clear_sound_cache()

func _test_truncated_and_bad_key() -> void:
	const REL := "sounds/ui/__truncated_probe.ogg.raw"
	AssetOverlay.clear_sound_cache()
	var whole := FileAccess.get_file_as_bytes("res://assets/sounds/ui/click.ogg.raw")
	for cut in [200, 3000]:
		var rel := REL.replace("probe", "probe_%d" % cut)
		_mount_overlay_sound(rel, whole.slice(0, mini(cut, whole.size() - 1)), "truncated_%d" % cut)
		var w := Diag.warn_count()
		assert_true(AssetOverlay.load_sound(rel) == null, "a file cut at %d bytes loads nothing" % cut)
		assert_true(AssetOverlay.load_sound(rel) == null, "and nothing again (cached miss)")
		assert_eq(Diag.warn_count(), w + 1, "a truncated file warns once")
	var w2 := Diag.warn_count()
	for k in ["sounds/ui/click.ogg", "res://assets/sounds/ui/click.ogg.raw.png", "sounds/ui/click"]:
		assert_true(AssetOverlay.load_sound(k) == null, "%s is not a sound key" % k)
		assert_true(AssetOverlay.load_sound(k) == null, "%s again loads nothing" % k)
	assert_eq(Diag.warn_count(), w2 + 3, "each bad key warns once")
	AssetOverlay.clear_sound_cache()

func _test_loop_not_shared() -> void:
	AssetOverlay.clear_sound_cache()
	var cached := AssetOverlay.load_sound("sounds/ambience/TemperateForest.ogg.raw") as AudioStreamOggVorbis
	assert_true(cached != null and not cached.loop, "the cached stream is decoded without a loop")
	var amb := Sound.play("ambience.TemperateForest")
	if amb is AudioStreamPlayer and cached != null:
		var s := (amb as AudioStreamPlayer).stream as AudioStreamOggVorbis
		assert_true(s != null and s.loop, "the ambience player loops")
		assert_false(cached.loop, "the cached stream is unchanged")
		assert_true(AssetOverlay.load_sound("sounds/ambience/TemperateForest.ogg.raw") == cached, "and still the cached one")
	Sound.stop_all()
	AssetOverlay.clear_sound_cache()

func _test_server_boot_disables_sound() -> void:
	var root: GameRoot = GameRoot.new()
	root._boot_wiring.parse_network_args(PackedStringArray(["--server"]))
	assert_true(root._is_server, "--server is a dedicated server")
	assert_false(Sound.enabled, "a dedicated server turns Sound off")
	assert_true(Sound.play("ui.click") == null, "so nothing plays")
	root.free()
	root = GameRoot.new()
	root._boot_wiring.parse_network_args(PackedStringArray(["--client", "127.0.0.1"]))
	assert_true(Sound.enabled, "a client boot leaves Sound on")
	root.free()
	Sound.enabled = true
