extends "res://src/tests/test_support.gd"
## Phase 276 — the first sounds wired in. Every wired event fires through the registry (`Sound.trace`, the plans
## `play` resolved; nothing here listens to output): the dig and the tool strike, pickups, a creature's attack on
## the host and on a client, footsteps, the ambience and the music, a button click and the window open/close.
## Each plays on its event's bus, one the volume options set. The footstep surface follows the ground underfoot;
## loops cross-fade; a dedicated server or a headless boot plays nothing and wires nothing. Positions hold under a
## shifted scene origin and a sound past its `maxDistance` is culled; a rider plays no footsteps; a refused loose pick
## is silent; a music file that does not load is retried with a back-off.

const SoundEvents := preload("res://src/audio/sound_events.gd")
const AudioWiring := preload("res://src/audio/audio_wiring.gd")
const GameSettings := preload("res://src/core/game_settings.gd")
const MountSlice := preload("res://src/creature/mount_slice.gd")

func register() -> void:
	_run_test("sound wiring: the dig, the tool strike and pickups fire their events", _test_dig_strike_pickup)
	_run_test("sound wiring: a creature's swing plays its attack at the creature, on the host and on a client", _test_creature_attack)
	_run_test("sound wiring: a footstep, the ambience and the music fire through the registry", _test_footstep_ambience_music)
	_run_test("sound wiring: a button clicks and a window opens and closes through the shared hooks", _test_ui_hooks)
	_run_test("sound wiring: every wired event plays on a bus the volume options set", _test_wired_buses)
	_run_test("sound wiring: the footstep surface follows the ground underfoot", _test_footstep_surface)
	_run_test("sound wiring: footsteps fall once per stride, only on the ground", _test_step_cadence)
	_run_test("sound player: one-shots are capped per event", _test_polyphony_cap)
	_run_test("sound wiring: a loop channel cross-fades and fades out", _test_loop_channels)
	_run_test("sound wiring: a dedicated server or a headless boot plays and wires nothing", _test_server_silent)
	_run_test("sound wiring: under a shifted scene origin the dig, the strike and a swing land at world + offset", _test_shifted_origin)
	_run_test("sound wiring: a 3D sound past its event's maxDistance from the listener is culled", _test_max_distance_cull)
	_run_test("sound wiring: no footsteps while the local player rides a mount", _test_no_steps_mounted)
	_run_test("sound wiring: a loose pick sounds only once the host confirms it", _test_loose_pick_confirmed)
	_run_test("sound wiring: a disabled Sound retries nothing", _test_refresh_disabled)
	_run_test("sound wiring: a music file that does not load backs off, without touching the rng", _test_music_back_off)
	_run_test("sound wiring: a failed ambience load is not retried and clears on a biome change", _test_ambience_failed)
	_run_test("sound wiring: a strike resets the work action to mine", _test_work_action_reset)

## Events this phase wires, by where they are played.
## A player body the suite places by hand (a fixture PlayerSlice has no body: no position, never on the floor).
const STUB_PLAYER_SRC := "extends \"res://src/player/player_slice.gd\"\nvar stub_scene := Vector3.ZERO\nvar stub_vel := Vector3.ZERO\nvar stub_grounded := false\nfunc get_scene_position() -> Vector3:\n\treturn stub_scene\nfunc get_velocity() -> Vector3:\n\treturn stub_vel\nfunc is_grounded() -> bool:\n\treturn stub_grounded\n"
## A GameRoot that can enter the tree without booting a world (its `_ready` and frame callbacks do nothing).
const INERT_ROOT_SRC := "extends \"res://src/core/game_root.gd\"\nfunc _ready() -> void:\n\tpass\nfunc _process(_d: float) -> void:\n\tpass\nfunc _physics_process(_d: float) -> void:\n\tpass\nfunc _exit_tree() -> void:\n\tpass\n"

const WIRED := ["ui.click", "ui.window_open", "ui.window_close", "footstep.grass", "footstep.stone", "footstep.sand",
	"world.dig", "item.StonePick.hit", "world.pickup", "creature.GraywolfPack.attack", "ambience.TemperateForest",
	"music.main_theme"]


func _begin() -> void:
	Sound.stop_all()
	Sound.enabled = true
	Sound.trace.clear()
	Sound.tracing = true


func _end() -> void:
	Sound.tracing = false
	Sound.trace.clear()
	Sound.stop_all()


func _traced() -> Array:
	return Sound.trace.map(func(p: Dictionary) -> String: return str(p["event"]))


## A host-shaped root with the slices the audio wiring reads (no player body: a listener with no position).
func _root() -> Node:
	var gr: Node = (load("res://src/core/game_root.gd") as GDScript).new()
	return gr


func _script(src: String) -> GDScript:
	var g := GDScript.new()
	g.source_code = src
	g.reload()
	return g


func _free_root(gr: Node, nodes: Array = []) -> void:
	gr._audio_wiring.unwire()
	for n in nodes:
		n.free()
	gr.free()


func _test_dig_strike_pickup() -> void:
	_begin()
	var gr := _root()
	var bag := InventorySlice.new()
	add_child(bag)
	gr._inventory = bag
	gr._audio_wiring.wire(gr)
	var at := Vector3(10, 4, -6)
	GameBus.block_changed.emit("place", at, Vector3.UP, "Stone")
	GameBus.block_changed.emit("settle", at, Vector3.UP, "Sand")
	assert_eq(_traced(), [], "a placement or a settle is not a dig")
	GameBus.block_changed.emit("mine", at, Vector3.UP, "Soil")
	assert_eq(_traced(), ["world.dig"], "a mined block digs")
	assert_eq(Sound.trace[-1]["spatial"], "3d", "the dig is positional")
	assert_eq(Sound.trace[-1]["position"], at, "at the dug block (no rebase: scene = world)")
	Sound.trace.clear()
	GameBus.block_mine_requested.emit(at, Vector3.UP, "", {})
	assert_eq(_traced(), [], "bare hands strike with no tool sound")
	bag.add_item("StonePick", 1)
	GameBus.work_started.emit("block:1", 1.0, "mine", "Stone")
	GameBus.block_mine_requested.emit(at, Vector3.UP, "", {})
	assert_eq(_traced(), ["item.StonePick.hit"], "the local player's pick strikes")
	assert_eq(Sound.trace[-1]["position"], at, "at the aimed point")
	var exact := WorldPos.from_world(at.x, at.y, at.z)
	GameBus.block_mine_requested.emit(Vector3.ZERO, Vector3.UP, "", exact)
	assert_true((Sound.trace[-1]["position"] as Vector3).is_equal_approx(at), "an exact aim is placed exactly")
	Sound.trace.clear()
	GameBus.block_mine_requested.emit(at, Vector3.UP, "peer-player-2", {})
	assert_eq(_traced(), [], "a remote actor's mine re-run on the host strikes nothing here")
	GameBus.item_picked_up.emit("Branch", 1)
	GameBus.loose_picked.emit("loose:1", 0.0)   # a host answers inside the request's emit, before this handler runs
	GameBus.loose_pick_requested.emit("loose:1", "")
	GameBus.loose_pick_requested.emit("loose:2", "peer-player-2")
	assert_eq(_traced(), ["world.pickup", "world.pickup"], "a pickup and the local loose pick play; a remote pick does not")
	assert_eq(Sound.trace[-1]["spatial"], "2d", "the own pickup is not positional")
	_free_root(gr, [bag])
	_end()


func _test_creature_attack() -> void:
	_begin()
	var gr := _root()
	var cr := CreatureSlice.new()
	add_child(cr)
	var wolf_at := Vector3(5, 2, 7)
	cr.apply_creature_state("w0", "GraywolfPack", "aggressive", wolf_at, 10.0)
	gr._creature = cr
	gr._audio_wiring.wire(gr)
	GameBus.combat_hit_resolved.emit("w0", "player", "hit", 3.0)
	assert_eq(_traced(), ["creature.GraywolfPack.attack"], "the host hears the wolf's swing")
	assert_true((Sound.trace[-1]["position"] as Vector3).is_equal_approx(wolf_at), "at the wolf")
	Sound.trace.clear()
	GameBus.combat_hit_resolved.emit("player", "w0", "hit", 3.0)
	GameBus.combat_hit_resolved.emit("nobody", "player", "miss", 0.0)
	assert_eq(_traced(), [], "a player's swing or an unknown attacker plays no creature attack")
	GameBus.combat_hit_synced.emit("c:w0", "p:1", "hit")
	assert_eq(_traced(), [], "a host ignores the client-side copy")
	gr._is_client = true
	GameBus.combat_hit_resolved.emit("w0", "player", "hit", 3.0)
	assert_eq(_traced(), [], "a client does not resolve swings itself")
	GameBus.combat_hit_synced.emit("c:w0", "p:2", "hit")
	GameBus.combat_hit_synced.emit("p:2", "c:w0", "hit")
	assert_eq(_traced(), ["creature.GraywolfPack.attack"], "a client hears the host's creature swing, not a player's")
	_free_root(gr, [cr])
	_end()


func _test_footstep_ambience_music() -> void:
	_begin()
	var gr := _root()
	var terrain := TerrainSlice.new()
	var player := PlayerSlice.new()
	gr._terrain = terrain
	gr._player = player
	gr._audio_wiring.wire(gr)
	var biome := str(terrain.get_biome_at_chunk(player.get_world_pos()["chunk"]))
	var step: Node = gr._audio_wiring.play_footstep()
	var want := AudioWiring.footstep_event(AudioWiring.surface_for("", biome))
	assert_true(want != "", "the biome at the origin (%s) has a footstep" % biome)
	assert_eq(_traced(), [want], "a footstep on %s ground" % biome)
	assert_true(step is AudioStreamPlayer3D, "a footstep is a 3D sound")
	assert_eq(Sound.trace[-1]["position"], player.get_scene_position(), "at the feet")
	Sound.trace.clear()
	gr._audio_wiring.refresh_surroundings()
	var amb := AudioWiring.ambience_for(biome)
	assert_eq(Sound.channel_event(AudioWiring.CHANNEL_MUSIC), AudioWiring.MUSIC_EVENT, "the music starts in the world")
	assert_eq(Sound.channel_event(AudioWiring.CHANNEL_AMBIENCE), amb, "the ambience is the biome's (%s)" % amb)
	gr._audio_wiring.refresh_surroundings()
	assert_eq(_traced().count(AudioWiring.MUSIC_EVENT), 1, "a second refresh does not restart the music")
	assert_eq(AudioWiring.ambience_for("TemperateForest"), "ambience.TemperateForest", "the temperate forest has its ambience")
	assert_eq(AudioWiring.ambience_for("Desert"), "", "a biome with no ambience row has none (the channel fades out)")
	gr._audio_wiring.unwire()
	assert_eq(Sound.channel_event(AudioWiring.CHANNEL_MUSIC), "", "unwiring stops the music")
	_free_root(gr, [player, terrain])
	_end()


func _test_ui_hooks() -> void:
	_begin()
	var b := Button.new()
	add_child(b)
	b.pressed.emit()
	assert_eq(_traced(), ["ui.click"], "any button in the tree clicks")
	remove_child(b)
	add_child(b)
	Sound.trace.clear()
	b.pressed.emit()
	assert_eq(_traced(), ["ui.click"], "a re-added button clicks once, not twice")
	b.free()
	var quiet := Button.new()
	quiet.set_meta("no_click_sound", true)
	add_child(quiet)
	Sound.trace.clear()
	quiet.pressed.emit()
	assert_eq(_traced(), [], "a button marked no_click_sound is silent")
	quiet.remove_meta("no_click_sound")
	quiet.pressed.emit()
	assert_eq(_traced(), ["ui.click"], "the meta is read at press time: removed, the button clicks")
	quiet.free()
	var late := Button.new()
	add_child(late)
	late.set_meta("no_click_sound", true)   # set after the button entered the tree
	Sound.trace.clear()
	late.pressed.emit()
	assert_eq(_traced(), [], "a meta set after add_child still silences it")
	late.free()
	var ui := UiSlice.new()
	add_child(ui)
	Sound.trace.clear()
	ui.open_window(UiSlice.WINDOW_INVENTORY)
	ui.open_window(UiSlice.WINDOW_INVENTORY)
	assert_eq(_traced(), ["ui.window_open"], "a window opens with one sound, not again while open")
	ui.close_window(UiSlice.WINDOW_INVENTORY)
	ui.close_window(UiSlice.WINDOW_INVENTORY)
	assert_eq(_traced(), ["ui.window_open", "ui.window_close"], "and closes with one")
	Sound.trace.clear()
	ui.open_window(UiSlice.WINDOW_INVENTORY)
	ui.open_window(UiSlice.WINDOW_CRAFTING)
	ui.close_top_window()
	assert_eq(_traced(), ["ui.window_open", "ui.window_open", "ui.window_close"], "Esc closes the top window with a sound")
	ui.free()
	_end()


func _test_wired_buses() -> void:
	var buses: Array = GameSettings.VOLUME_BUSES.values()
	for id in WIRED:
		assert_true(SoundEvents.has_event(id), "%s is in the fabric's table" % id)
		var p := Sound.plan(id, Vector3.ONE)
		assert_eq(p.get("bus", ""), SoundEvents.event(id).get("bus", "?"), "%s plays on its event's bus" % id)
		assert_true(buses.has(p.get("bus", "")), "%s's bus (%s) has a volume option" % [id, p.get("bus", "")])
		assert_true(AudioServer.get_bus_index(str(p.get("bus", ""))) > 0, "%s's bus is in the layout" % id)
		var ev := SoundEvents.event(id)
		assert_eq(p.get("spatial", ""), str(ev.get("spatial", "")), "%s is %s when given a position" % [id, ev.get("spatial", "")])


func _test_footstep_surface() -> void:
	assert_eq(AudioWiring.surface_for("", "TemperateForest"), "grass", "a forest floor is grass")
	assert_eq(AudioWiring.surface_for("", "TwilightGrove"), "grass", "moss sounds like grass")
	assert_eq(AudioWiring.surface_for("", "Desert"), "sand", "a desert is sand")
	assert_eq(AudioWiring.surface_for("", "Tundra"), "sand", "snow crunches like sand")
	assert_eq(AudioWiring.surface_for("", "VoidRift"), "stone", "the rift floor is rock")
	assert_eq(AudioWiring.surface_for("Stone", "TemperateForest"), "stone", "a placed block is stone, whatever the biome")
	assert_eq(AudioWiring.surface_for("Thornwood", "Desert"), "stone", "any placed block")
	for b in GameData.BIOMES:
		var s := AudioWiring.surface_for("", str(b))
		assert_true(AudioWiring.footstep_event(s) != "", "%s's ground has a footstep event (%s)" % [b, s])
	assert_eq(AudioWiring.footstep_event("velvet"), "", "a surface with no event plays nothing")
	var runs := [{ "bottom": -10.0, "top": 2.0, "material": "" }, { "bottom": 2.0, "top": 2.5, "material": "Stone" },
		{ "bottom": 6.0, "top": 7.0, "material": "Thornwood" }]
	assert_eq(AudioWiring.material_underfoot(runs, 2.5), "Stone", "standing on a placed slab")
	assert_eq(AudioWiring.material_underfoot(runs, 2.0), "", "standing on the natural ground beside it")
	assert_eq(AudioWiring.material_underfoot(runs, 7.0), "Thornwood", "on a roof")
	assert_eq(AudioWiring.material_underfoot([], 0.0), "", "no runs, natural ground")


func _test_step_cadence() -> void:
	var stride := AudioWiring.STRIDE_METRES
	var r := AudioWiring.step_due(0.0, 0.0, 0.1, true)
	assert_eq(r, [stride * 0.5, false], "standing still: no step, half a stride to go")
	r = AudioWiring.step_due(1.0, 5.0, 0.1, false)
	assert_eq(r, [stride * 0.5, false], "in the air: no step")
	var steps := 0
	var s := stride * 0.5
	for i in 100:   # 10 s at 4 m/s = 40 m
		var d := AudioWiring.step_due(s, 4.0, 0.1, true)
		s = float(d[0])
		if bool(d[1]):
			steps += 1
	assert_eq(steps, int(floor((40.0 + stride * 0.5) / stride)), "one step per stride walked")
	assert_false(bool(AudioWiring.step_due(0.0, 0.3, 1.0, true)[1]), "creeping below the walking speed is silent")


func _test_loop_channels() -> void:
	_begin()
	var a: Node = Sound.play_loop("probe", "ambience.TemperateForest", 2.0)
	assert_true(a != null, "the loop plays")
	var full := float(SoundEvents.event("ambience.TemperateForest")["volumeDb"])
	assert_eq(float(a.get("volume_db")), Sound.FADE_FLOOR_DB, "it starts at the fade floor")
	Sound.step_fades(1.0)
	assert_true(float(a.get("volume_db")) > Sound.FADE_FLOOR_DB and float(a.get("volume_db")) < full, "half way up")
	Sound.step_fades(1.0)
	assert_true(is_equal_approx(float(a.get("volume_db")), full), "and at the event's volume when the fade ends")
	assert_true(Sound.play_loop("probe", "ambience.TemperateForest", 2.0) == a, "the same event again keeps the player")
	var m: Node = Sound.play_loop("probe", "music.main_theme", 1.0)
	assert_eq(Sound.channel_event("probe"), "music.main_theme", "the channel switched")
	assert_eq(Sound.playing("ambience.TemperateForest").size(), 1, "the old loop is still fading out")
	assert_eq(Sound.fading_count(), 2, "one fades out while the other fades in")
	Sound.step_fades(1.0)
	assert_eq(Sound.playing("ambience.TemperateForest").size(), 0, "the old loop is freed when its fade ends")
	assert_true(is_instance_valid(m) and is_equal_approx(float(m.get("volume_db")), float(SoundEvents.event("music.main_theme")["volumeDb"])), "the new one is up")
	Sound.stop_channel("probe", 0.0)
	assert_eq(Sound.channel_event("probe"), "", "stop_channel empties the channel")
	assert_eq(Sound.playing("music.main_theme").size(), 0, "a zero fade frees at once")
	_end()


func _test_server_silent() -> void:
	_begin()
	assert_false(AudioWiring.sound_allowed(true, false), "a dedicated server plays nothing")
	assert_false(AudioWiring.sound_allowed(false, true), "nor a headless boot")
	assert_true(AudioWiring.sound_allowed(false, false), "a rendered host or client plays")
	AudioWiring.apply_boot_role(true, false)
	assert_false(Sound.enabled, "the server boot turns Sound off")
	assert_true(Sound.play("ui.click") == null and Sound.play_loop("music", "music.main_theme", 0.0) == null, "nothing plays")
	assert_eq(Sound.trace.size(), 0, "and nothing is asked of the registry")
	var gr := _root()
	gr._is_server = true
	var cr := CreatureSlice.new()
	add_child(cr)
	cr.apply_creature_state("w0", "GraywolfPack", "aggressive", Vector3.ZERO, 10.0)
	gr._creature = cr
	gr._audio_wiring.wire(gr)
	assert_eq(gr._audio_wiring.connection_count(), 0, "a server root wires no sound handler")
	Sound.enabled = true   # even with Sound on, a server root's wiring stays silent
	GameBus.block_changed.emit("mine", Vector3.ZERO, Vector3.UP, "Soil")
	GameBus.combat_hit_resolved.emit("w0", "player", "hit", 1.0)
	gr._audio_wiring.tick(1.0)
	assert_eq(Sound.trace.size(), 0, "a dig, a swing or a tick on a server root plays nothing")
	_free_root(gr, [cr])
	# A booting root (in the tree, as `_build_and_boot` wires it) applies its role when it wires the module; a
	# fixture root (not in the tree) leaves Sound alone. The inert root enters the tree without booting a world.
	var inert := _script(INERT_ROOT_SRC)
	var fixture := _root()
	fixture._is_server = true
	Sound.enabled = true
	fixture._audio_wiring.wire(fixture)
	assert_true(Sound.enabled, "a fixture server root (not in the tree) leaves Sound alone")
	_free_root(fixture)
	var booting: Node = inert.new()
	booting._is_server = true
	add_child(booting)
	booting._audio_wiring.wire(booting)
	assert_false(Sound.enabled, "a booting dedicated server turns Sound off")
	assert_eq(booting._audio_wiring.connection_count(), 0, "and wires no handler")
	booting.free()
	Sound.enabled = true
	var client: Node = inert.new()
	client._is_client = true
	add_child(client)
	client._audio_wiring.wire(client)
	assert_eq(Sound.enabled, DisplayServer.get_name() != "headless", "a booting client plays unless the boot is headless")
	client.free()
	AudioWiring.apply_boot_role(false, false)
	assert_true(Sound.enabled, "a client boot turns it back on")
	_end()


## World positions under a scene origin of chunk (3, -2): each 3D sound lands at world + the player's scene offset.
func _test_shifted_origin() -> void:
	_begin()
	var gr := _root()
	var player = _script(STUB_PLAYER_SRC).new()
	player.shift_scene_to_origin(Vector3.ZERO, Vector2i(3, -2))
	var off: Vector3 = player.scene_offset()
	assert_true(off.x != 0.0 and off.z != 0.0, "the origin is shifted on both axes (%s)" % off)
	var at := Vector3(10, 4, -6)
	player.stub_scene = at + off   # the listener stands at the dig
	var bag := InventorySlice.new()
	add_child(bag)
	bag.add_item("StonePick", 1)
	var cr := CreatureSlice.new()
	add_child(cr)
	var wolf_at := Vector3(5, 2, 7)
	cr.apply_creature_state("w0", "GraywolfPack", "aggressive", wolf_at, 10.0)
	gr._player = player
	gr._inventory = bag
	gr._creature = cr
	gr._audio_wiring.wire(gr)
	GameBus.block_changed.emit("mine", at, Vector3.UP, "Soil")
	assert_eq(_traced(), ["world.dig"], "the dig plays")
	assert_true((Sound.trace[-1]["position"] as Vector3).is_equal_approx(at + off), "at world + offset, not at world")
	Sound.trace.clear()
	GameBus.work_started.emit("block:1", 1.0, "mine", "Stone")
	GameBus.block_mine_requested.emit(at, Vector3.UP, "", {})
	assert_true(_traced() == ["item.StonePick.hit"] and (Sound.trace[-1]["position"] as Vector3).is_equal_approx(at + off),
		"the strike at an aimed point lands at world + offset")
	GameBus.block_mine_requested.emit(Vector3.ZERO, Vector3.UP, "", WorldPos.from_world(at.x, at.y, at.z))
	assert_true((Sound.trace[-1]["position"] as Vector3).is_equal_approx(at + off), "and an exact aim too")
	Sound.trace.clear()
	GameBus.combat_hit_resolved.emit("w0", "player", "hit", 3.0)
	assert_eq(_traced(), ["creature.GraywolfPack.attack"], "the wolf's swing plays")
	assert_true((Sound.trace[-1]["position"] as Vector3).is_equal_approx(wolf_at + off), "at the wolf's world + offset")
	_free_root(gr, [player, bag, cr])
	_end()


func _test_max_distance_cull() -> void:
	_begin()
	var gr := _root()
	var player = _script(STUB_PLAYER_SRC).new()
	player.stub_scene = Vector3(0, 0, 0)
	gr._player = player
	gr._audio_wiring.wire(gr)
	var reach := float(SoundEvents.event("world.dig")["maxDistance"])
	assert_true(reach > 0.0, "the dig has a range")
	assert_true(gr._audio_wiring.play_at("world.dig", Vector3(reach - 0.5, 0, 0)) != null, "just inside the range plays")
	assert_true(gr._audio_wiring.play_at("world.dig", Vector3(reach + 0.5, 0, 0)) == null, "just past it does not")
	GameBus.block_changed.emit("mine", Vector3(0, 0, reach * 2.0), Vector3.UP, "Soil")
	assert_eq(_traced(), ["world.dig"], "a far dig is culled before the registry is asked")
	_free_root(gr, [player])
	_end()


func _test_no_steps_mounted() -> void:
	_begin()
	var gr := _root()
	var player = _script(STUB_PLAYER_SRC).new()
	player.stub_vel = Vector3(8.9, 0, 0)   # a mount's cruise
	player.stub_grounded = true
	var terrain := TerrainSlice.new()   # a biome underfoot, so a step has a surface
	gr._terrain = terrain
	gr._player = player
	var mount := MountSlice.new()
	gr._mount_wiring.slice = mount
	gr._audio_wiring.wire(gr)
	var aw = gr._audio_wiring
	var steps := func() -> int: return _traced().filter(func(e: String) -> bool: return e.begins_with("footstep.")).size()
	aw.tick(0.5)
	assert_true(steps.call() >= 1, "on foot at that speed, steps fall")
	mount._local_mounted = true
	Sound.trace.clear()
	for i in 20:
		aw.tick(0.5)
	assert_eq(steps.call(), 0, "riding 10 s plays no footstep")
	assert_eq(aw._stride, AudioWiring.STRIDE_METRES * 0.5, "and the stride waits at half a stride")
	mount._local_mounted = false
	aw.tick(0.5)
	assert_true(steps.call() >= 1, "off the mount, steps fall again")
	gr._mount_wiring.slice = null
	_free_root(gr, [player, mount, terrain])
	_end()


func _test_loose_pick_confirmed() -> void:
	_begin()
	var gr := _root()
	gr._audio_wiring.wire(gr)
	GameBus.loose_pick_requested.emit("loose:9", "")
	assert_eq(_traced(), [], "a host's refused pick (no loose_picked) is silent")
	GameBus.loose_picked.emit("loose:9", 0.0)
	assert_eq(_traced(), [], "nor does a later pick by someone else sound here")
	gr._is_client = true
	GameBus.loose_pick_requested.emit("loose:3", "")
	assert_eq(_traced(), [], "a client waits for the host")
	GameBus.loose_picked.emit("loose:3", 0.0)
	assert_eq(_traced(), ["world.pickup"], "and plays the pickup on its confirmation")
	GameBus.loose_picked.emit("loose:3", 0.0)
	GameBus.loose_picked.emit("loose:4", 0.0)
	assert_eq(_traced(), ["world.pickup"], "once; another item taken plays nothing")
	_free_root(gr)
	_end()


func _test_music_back_off() -> void:
	_begin()
	var gr := _root()
	gr._audio_wiring.wire(gr)
	var aw = gr._audio_wiring
	var keys := SoundEvents.files(AudioWiring.MUSIC_EVENT)
	AssetOverlay.clear_sound_cache()
	for k in keys:
		AssetOverlay._sounds_missing[str(k)] = true   # a bad pack: the music does not load
	var rng_state := Sound.rng.state
	for i in 60:
		aw.refresh_surroundings(1.0)
	assert_eq(Sound.channel_event(AudioWiring.CHANNEL_MUSIC), "", "no music plays")
	assert_true(aw._music_attempts <= 6, "a minute of refreshes tries the file a handful of times, not 60 (%d)" % aw._music_attempts)
	assert_eq(Sound.rng.state, rng_state, "a failed try does not advance the rng")
	assert_eq(_traced(), [], "nor asks the registry for a player")
	AssetOverlay.clear_sound_cache()   # the pack is fixed
	for i in int(AudioWiring.MUSIC_RETRY_MAX) + 1:
		aw.refresh_surroundings(1.0)
	assert_eq(Sound.channel_event(AudioWiring.CHANNEL_MUSIC), AudioWiring.MUSIC_EVENT, "the music starts once it loads")
	_free_root(gr)
	_end()


func _test_refresh_disabled() -> void:
	_begin()
	var gr := _root()
	gr._audio_wiring.wire(gr)
	var aw = gr._audio_wiring
	var was: bool = Sound.enabled
	Sound.enabled = false
	for i in 5:
		aw.refresh_surroundings(1.0)
	assert_eq(aw._music_attempts, 0, "a disabled Sound never tries the music")
	Sound.enabled = was
	_free_root(gr)
	_end()


const BIOME_STUB_SRC := "extends \"res://src/terrain/terrain_slice.gd\"\nvar stub_biome := \"TemperateForest\"\nfunc get_biome_at_chunk(_c) -> String:\n\treturn stub_biome\n"


func _test_ambience_failed() -> void:
	_begin()
	var gr := _root()
	var terrain: Node = _script(BIOME_STUB_SRC).new()
	var player := PlayerSlice.new()
	gr._terrain = terrain
	gr._player = player
	gr._audio_wiring.wire(gr)
	var aw = gr._audio_wiring
	var amb := AudioWiring.ambience_for("TemperateForest")
	assert_true(amb != "", "the stub biome has an ambience")
	AssetOverlay.clear_sound_cache()
	for k in SoundEvents.files(amb):
		AssetOverlay._sounds_missing[str(k)] = true   # the ambience does not load
	aw.refresh_surroundings(0.0)
	assert_eq(aw._ambience_failed, amb, "a failed load is remembered")
	assert_eq(Sound.channel_event(AudioWiring.CHANNEL_AMBIENCE), "", "nothing plays")
	var tries := _traced().count(amb)
	for i in 5:
		aw.refresh_surroundings(0.0)
	assert_eq(_traced().count(amb), tries, "refreshes in the same biome do not retry it")
	terrain.stub_biome = "Desert"   # no ambience row: the channel's target is empty
	aw.refresh_surroundings(0.0)
	assert_eq(aw._ambience_failed, "", "a biome change clears the failure")
	AssetOverlay.clear_sound_cache()
	terrain.stub_biome = "TemperateForest"
	aw.refresh_surroundings(0.0)
	assert_eq(Sound.channel_event(AudioWiring.CHANNEL_AMBIENCE), amb, "back in the biome, with the pack fixed, it plays")
	_free_root(gr, [player, terrain])
	_end()


func _test_work_action_reset() -> void:
	_begin()
	var gr := _root()
	var bag := InventorySlice.new()
	add_child(bag)
	gr._inventory = bag
	gr._audio_wiring.wire(gr)
	var aw = gr._audio_wiring
	assert_eq(aw._work_action, "mine", "starts as mine")
	GameBus.work_started.emit("block:1", 1.0, "dig", "Soil")
	assert_eq(aw._work_action, "dig", "a dig work answer names the action")
	GameBus.block_mine_requested.emit(Vector3.ZERO, Vector3.UP, "", {})
	assert_eq(aw._work_action, "mine", "the strike resets it")
	GameBus.work_started.emit("block:2", 1.0, "chop", "Wood")
	assert_eq(aw._work_action, "mine", "an action the wiring does not name is ignored")
	_free_root(gr, [bag])
	_end()


func _test_polyphony_cap() -> void:
	Sound.stop_all()
	Sound.enabled = true
	var made := 0
	for i in Sound.MAX_ONE_SHOTS_PER_EVENT + 5:
		if Sound.play("ui.click") != null:
			made += 1
	assert_eq(made, Sound.MAX_ONE_SHOTS_PER_EVENT, "one event stops at its cap")
	Sound.stop_all()
	assert_true(Sound.play("ui.click") != null, "room again once the players are gone")
	Sound.stop_all()
