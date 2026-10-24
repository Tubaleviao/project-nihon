extends "res://src/tests/test_support.gd"
## Phase 182 — the admin tools: `/time`, `/speed`, `/fly`, `/heal`, their packets, and the Admin window.

const AdminRules := preload("res://src/admin/admin_rules.gd")
const AdminPanel := preload("res://src/ui/admin_panel.gd")
const WindowDock := preload("res://src/ui/window_dock.gd")
const WorldClockScript := preload("res://src/world/world_clock.gd")
const PlayerRules := preload("res://src/core/player_rules.gd")


func register() -> void:
	_run_test("admin: /time parses hh:mm and +hours and only runs the clock forward", _test_parse_time)
	_run_test("admin: /speed takes 0.1 to 10 and flying climbs, sinks and hovers", _test_parse_speed_and_fly)
	_run_test("admin: a non-admin is refused every admin command", _test_non_admin_refused)
	_run_test("admin: /time moves the host clock and tells the clients", _test_time_command)
	_run_test("admin: /speed and /fly on the admin's own body go through the bus", _test_moves_local)
	_run_test("admin: /speed, /fly and /heal reach a remote player's client", _test_moves_and_heal_remote)
	_run_test("admin: /heal fills the local bar and leaves a downed body down", _test_heal_local)
	_run_test("admin: the player body applies moves clamped, and flying speeds it up", _test_player_moves)
	_run_test("admin: the client routes admin packets and the admin flag from its identity", _test_client_routes)
	_run_test("admin: the Admin box is hidden until the host says admin, and the window refuses otherwise", _test_dock_and_window)
	_run_test("admin: the Admin window types the chat commands", _test_panel_commands)
	_run_test("admin: every new command has a usage line and every catalog key both languages", _test_catalog)
	_run_test("admin: a heal that cannot reach the peer leaves the host's simulated health alone", _test_heal_unsent_keeps_hp)
	_run_test("admin: a rejoining player walks normally on the host and on its own client", _test_moves_reset_on_rejoin)
	_run_test("admin: flying holds still while immobilized or while a text field has the keyboard", _test_fly_gated)
	_run_test("admin: an admins file edited mid-session takes effect and tells the player's client", _test_admins_file_live)
	_run_test("admin: an admin's /speed and /fly raise the host's carry cap to match", _test_carry_cap_follows_moves)
	_run_test("admin: /regen world asks for confirm before it asks the host to regenerate", _test_regen_command)
	_run_test("admin: the voxel, tree and region-streamer resets forget the old ground", _test_regen_resets)
	_run_test("admin: /regen world moves the regions aside, empties memory and keeps stations", _test_regen_world_host)
	_run_test("admin: a client told of a regen drops its records and edits", _test_regen_client)


func _test_parse_time() -> void:
	var now := 3.25   # day 3, 06:00
	var noon := AdminRules.parse_time("12:00", now)
	assert_true(noon["ok"], "12:00 parses")
	assert_true(absf(float(noon["days"]) - 3.5) < 1e-9, "later today: the same day at noon")
	var dawn := AdminRules.parse_time("05:30", now)
	assert_true(absf(float(dawn["days"]) - (4.0 + 5.5 / 24.0)) < 1e-9, "earlier than now: tomorrow, never backwards")
	assert_true(absf(float(AdminRules.parse_time("6", now)["days"]) - 4.25) < 1e-9, "the same time as now is a whole day on")
	assert_true(absf(float(AdminRules.parse_time("+3", now)["days"]) - (now + 3.0 / 24.0)) < 1e-9, "+3 skips three hours")
	for bad in ["24:00", "12:60", "-1", "ab", "1:2:3", "+0", "+%d" % (AdminRules.TIME_SKIP_MAX_HOURS + 1), "+x"]:
		assert_false(AdminRules.parse_time(bad, now)["ok"], "'%s' is refused" % bad)
	assert_eq(str(AdminRules.parse_time("+0", now)["error"]), "chat.time_bad_skip", "a bad skip names its own key")

func _test_parse_speed_and_fly() -> void:
	assert_eq(AdminRules.parse_speed("2"), 2.0, "2 is a speed")
	assert_eq(AdminRules.parse_speed("0.1"), 0.1, "the minimum is allowed")
	assert_eq(AdminRules.parse_speed("10"), 10.0, "and the maximum")
	for bad in ["0", "11", "-2", "nan", "fast", ""]:
		assert_eq(AdminRules.parse_speed(bad), -1.0, "'%s' is not a speed" % bad)
	assert_eq(AdminRules.sanitize_speed(1000.0), AdminRules.SPEED_MAX, "a wire value is clamped")
	assert_eq(AdminRules.sanitize_speed(NAN), 1.0, "and a non-number is normal speed")
	assert_eq(AdminRules.fly_vertical_velocity(true, false, 1.0), AdminRules.FLY_VERTICAL_SPEED, "Space climbs")
	assert_eq(AdminRules.fly_vertical_velocity(false, true, 2.0), -AdminRules.FLY_VERTICAL_SPEED * 2.0, "Ctrl sinks, scaled by speed")
	assert_eq(AdminRules.fly_vertical_velocity(true, true, 1.0), 0.0, "both hover")
	assert_eq(AdminRules.fly_vertical_velocity(false, false, 1.0), 0.0, "and so does neither")

## The system lines sent to anyone while `body` runs: [key, args, target].
func _capture(body: Callable) -> Array:
	var heard: Array = []
	var cb := func(key: String, args: Array, target: String) -> void: heard.append([key, args, target])
	GameBus.system_message.connect(cb)
	body.call()
	GameBus.system_message.disconnect(cb)
	return heard

func _keys(heard: Array) -> Array:
	var out: Array = []
	for h in heard:
		out.append(str(h[0]))
	return out

func _test_non_admin_refused() -> void:
	var rig := _chat_rig()
	var chat: ChatSlice = rig["chat"]
	var clock := WorldClockScript.new()
	clock.time_days = 2.0
	chat.world_clock = clock
	for cmd in ["/time 12:00", "/speed 3", "/fly", "/heal"]:
		var heard := _capture(func() -> void: chat.handle_intent(cmd, "stranger_1"))
		assert_eq(_keys(heard), ["chat.admin_only"], "%s is refused for a non-admin" % cmd)
	assert_eq(clock.time_days, 2.0, "and the clock did not move")
	assert_true(chat._admin_moves.is_empty(), "nor did anyone's moves change")
	chat.free()
	rig["reg"].free()

func _test_time_command() -> void:
	var rig := _chat_rig()
	var chat: ChatSlice = rig["chat"]
	var heard := _capture(func() -> void: chat.handle_intent("/time 12:00", ""))
	assert_eq(_keys(heard), ["chat.time_off"], "no clock: said so")
	var clock := WorldClockScript.new()
	clock.time_days = 7.75   # 18:00
	chat.world_clock = clock
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	var wire := MemoryTransport.new([4])
	n.set_transport(wire)
	chat.networking = n
	heard = _capture(func() -> void: chat.handle_intent("/time 06:30", ""))
	assert_true(absf(clock.time_days - (8.0 + 6.5 / 24.0)) < 1e-9, "06:30 after 18:00 is tomorrow morning")
	assert_eq(_keys(heard), ["chat.time_set"], "the admin is told")
	assert_eq(str(heard[0][1][0]), "06:30", "with the new time")
	var clocks: Array = wire.outbox.filter(func(m: Dictionary) -> bool: return str(m["payload"].get("type", "")) == "world_clock")
	assert_eq(clocks.size(), 1, "every client is sent the clock")
	assert_true(absf(float(clocks[0]["payload"]["days"]) - clock.time_days) < 1e-9, "at the new time")
	heard = _capture(func() -> void: chat.handle_intent("/time 25:00", ""))
	assert_eq(_keys(heard), ["chat.time_bad", "chat.usage.time"], "a bad time is explained, with the usage")
	n.free()
	chat.free()
	rig["reg"].free()

func _test_moves_local() -> void:
	var rig := _chat_rig()
	var chat: ChatSlice = rig["chat"]
	var got: Array = []
	var cb := func(speed: float, fly: bool) -> void: got.append([speed, fly])
	GameBus.admin_moves_synced.connect(cb)
	var heard := _capture(func() -> void:
		chat.handle_intent("/speed 3", "")
		chat.handle_intent("/fly", "")
		chat.handle_intent("/fly", "")
		chat.handle_intent("/speed 99", "")
		chat.handle_intent("/speed 2 nobody_here", ""))
	GameBus.admin_moves_synced.disconnect(cb)
	assert_eq(got, [[3.0, false], [3.0, true], [3.0, false]], "speed, fly on, fly off, each keeping the other")
	assert_eq(_keys(heard), ["chat.speed_set", "chat.fly_on", "chat.fly_off", "chat.speed_range", "chat.no_player"],
		"each is answered, and an out-of-range speed or unknown player is refused")
	assert_eq(chat.admin_moves_of("player_host_1"), { "speed": 3.0, "fly": false }, "the host remembers the moves")
	chat.handle_intent("/speed 1", "")
	assert_false(chat._admin_moves.has("player_host_1"), "normal moves are not kept")
	chat.free()
	rig["reg"].free()

func _test_moves_and_heal_remote() -> void:
	var rig := _chat_rig()
	var chat: ChatSlice = rig["chat"]
	var reg: PlayerRegistry = rig["reg"]
	reg.is_authoritative = true
	var pid := reg.resolve_identity(4, "")
	var handle := reg.public_handle(pid)
	var heard := _capture(func() -> void: chat.handle_intent("/speed 2 %s" % handle, ""))
	assert_eq(_keys(heard), ["chat.unreachable"], "without networking the peer is unreachable")
	assert_false(chat._admin_moves.has(pid), "and nothing is recorded")
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	var wire := MemoryTransport.new([4])
	n.set_transport(wire)
	chat.networking = n
	heard = _capture(func() -> void:
		chat.handle_intent("/speed 2 %s" % handle, "")
		chat.handle_intent("/fly %s" % handle, "")
		chat.handle_intent("/heal %s" % handle, ""))
	assert_eq(_keys(heard), ["chat.speed_set", "chat.fly_on", "chat.healed"], "all three land")
	var types: Array = []
	for m: Dictionary in wire.outbox:
		assert_eq(int(m["peer_id"]), 4, "every packet goes to that player's peer alone")
		types.append(str(m["payload"]["type"]))
	assert_eq(types, ["admin_moves", "admin_moves", "admin_heal"], "as admin_moves twice and one admin_heal")
	assert_eq(wire.outbox[1]["payload"]["speed"], 2.0, "the fly toggle keeps the speed")
	assert_eq(wire.outbox[1]["payload"]["fly"], true, "and turns flying on")
	assert_eq(reg.get_hp(pid), PlayerRules.MAX_HP, "the host's own simulation of the peer is full too")
	assert_false(n.send_admin(9, "admin_moves", { "speed": 1.0, "fly": false }), "an unconnected peer is not sent anything")
	assert_false(n.send_admin(4, "teleport"), "nor anything but an admin packet")
	n._role = NetworkingSlice.Role.CLIENT
	assert_false(n.send_admin(4, "admin_heal"), "and a client sends no admin packets")
	n.free()
	chat.free()
	reg.free()

func _test_heal_local() -> void:
	var rig := _chat_rig()
	var chat: ChatSlice = rig["chat"]
	var heard := _capture(func() -> void: chat.handle_intent("/heal", ""))
	assert_eq(_keys(heard), ["chat.no_body"], "no body: said so")
	var player := PlayerSlice.new()
	player.render_visuals = false
	add_child(player)
	chat.player_slice = player
	var healed := [0]
	var cb := func() -> void: healed[0] += 1
	GameBus.admin_healed.connect(cb)
	heard = _capture(func() -> void: chat.handle_intent("/heal", ""))
	assert_eq(healed[0], 1, "a live body is healed through the bus")
	assert_eq(_keys(heard), ["chat.healed"], "and the admin is told")
	player._alive = false
	heard = _capture(func() -> void: chat.handle_intent("/heal", ""))
	GameBus.admin_healed.disconnect(cb)
	assert_eq(healed[0], 1, "a downed body is not revived")
	assert_eq(_keys(heard), ["chat.heal_downed"], "and the admin hears why")
	player.free()
	chat.free()
	rig["reg"].free()

func _test_player_moves() -> void:
	var player := PlayerSlice.new()
	player.set_admin_moves(50.0, true)
	assert_eq(player.admin_speed_factor, AdminRules.SPEED_MAX, "a factor over the cap is clamped by the body too")
	assert_true(player.flying, "flying is on")
	player.set_admin_moves(0.5, false)
	assert_eq(player.admin_speed_factor, 0.5, "a factor in range is kept")
	assert_false(player.flying, "and flying is off")
	assert_true(player.is_alive(), "a fresh body is alive")
	player.free()

func _test_client_routes() -> void:
	var client := NetworkingSlice.new()
	add_child(client)
	client._role = NetworkingSlice.Role.CLIENT
	var moves: Array = []
	var heals := [0]
	var status: Array = []
	var on_moves := func(s: float, f: bool) -> void: moves.append([s, f])
	var on_heal := func() -> void: heals[0] += 1
	var on_status := func(a: bool) -> void: status.append(a)
	GameBus.admin_moves_synced.connect(on_moves)
	GameBus.admin_healed.connect(on_heal)
	GameBus.admin_status_synced.connect(on_status)
	client._route_h2c({ "type": "admin_moves", "speed": 2.5, "fly": true })
	client._route_h2c({ "type": "admin_moves", "speed": "fast", "fly": true })
	client._route_h2c({ "type": "admin_heal" })
	client._route_h2c({ "type": "identity_assigned", "player_id": "p1", "handle": "h1", "admin": true })
	client._route_h2c({ "type": "identity_assigned", "player_id": "p1", "handle": "h1", "admin": "yes" })
	client._route_h2c({ "type": "admin_status", "admin": true })
	client._route_h2c({ "type": "admin_status", "admin": 1 })
	client._role = NetworkingSlice.Role.HOST
	client._route_h2c({ "type": "admin_heal" })
	GameBus.admin_moves_synced.disconnect(on_moves)
	GameBus.admin_healed.disconnect(on_heal)
	GameBus.admin_status_synced.disconnect(on_status)
	assert_eq(moves, [[2.5, true]], "a client applies a numeric speed and drops a malformed one")
	assert_eq(heals[0], 1, "a heal reaches a client's bus, never a host's")
	assert_eq(status, [true, false, true, false], "the admin flag is read strictly from the identity and a status packet")
	# The host side: the identity packet carries what admin_check says.
	var host := NetworkingSlice.new()
	add_child(host)
	host._role = NetworkingSlice.Role.HOST
	var wire := MemoryTransport.new([4, 5])
	host.set_transport(wire)
	host.admin_check = func(pid: String) -> bool: return pid == "boss"
	host.set_player_id(4, "boss")
	host.set_player_id(5, "pleb")
	var flags := {}
	for m: Dictionary in wire.outbox:
		if str(m["payload"]["type"]) == "identity_assigned":
			flags[int(m["peer_id"])] = m["payload"]["admin"]
	assert_eq(flags, { 4: true, 5: false }, "only the admin's client is told it is one")
	host.free()
	client.free()

func _test_dock_and_window() -> void:
	var dock := WindowDock.new()
	dock.build()
	assert_false(dock.is_entry_visible("admin"), "the Admin box starts hidden")
	assert_true(dock.is_entry_visible("inventory"), "the others are shown")
	dock.set_entry_visible("admin", true)
	assert_true(dock.is_entry_visible("admin"), "the host's word shows it")
	dock.set_entry_visible("admin", false)
	assert_false(dock.is_entry_visible("admin"), "and hides it again")
	dock.free()
	var ui := UiSlice.new()
	add_child(ui)
	ui.open_window(UiSlice.WINDOW_ADMIN)
	assert_false(ui.is_window_open(UiSlice.WINDOW_ADMIN), "a non-admin cannot open the Admin window")
	ui.set_admin(true)
	assert_true(ui.window_dock.is_entry_visible("admin"), "an admin sees its box")
	ui.open_window(UiSlice.WINDOW_ADMIN)
	assert_true(ui.is_window_open(UiSlice.WINDOW_ADMIN), "and can open the window")
	ui.set_admin(false)
	assert_false(ui.is_window_open(UiSlice.WINDOW_ADMIN), "losing the right closes it")
	assert_false(ui.window_dock.is_entry_visible("admin"), "and hides the box")
	ui.free()

func _test_panel_commands() -> void:
	assert_true("rain" in AdminPanel.weather_states(), "the weather list comes from the fabric")
	assert_eq(AdminPanel.weather_command("rain", 6), "/weather rain 6", "weather")
	assert_eq(AdminPanel.time_command(7), "/time 07:00", "time")
	assert_eq(AdminPanel.time_command(30), "/time 23:00", "an hour is clamped")
	assert_eq(AdminPanel.speed_command(2.5), "/speed 2.5", "speed")
	assert_eq(AdminPanel.speed_command(99.0), "/speed 10.0", "a speed is clamped")
	assert_eq(AdminPanel.weather_label("rain"), I18nScript.t("weather.state.rain"), "a state's name is translated")
	assert_eq(AdminPanel.weather_label("no_such_state"), "no_such_state", "an unnamed one shows its id")
	var panel := AdminPanel.new()
	add_child(panel)
	var said: Array = []
	var cb := func(text: String, pid: String) -> void: said.append([text, pid])
	GameBus.chat_intent.connect(cb)
	panel.run("/heal")
	GameBus.chat_intent.disconnect(cb)
	assert_eq(said, [["/heal", ""]], "a button is a chat intent from the local player")
	panel.free()

func _test_catalog() -> void:
	for cmd in ["time", "speed", "fly", "heal"]:
		assert_true(ChatCommands.is_admin_command(cmd), "/%s is an admin command" % cmd)
		var key: String = ChatCommands.USAGE[cmd]
		assert_true(key in ChatCommands.help_lines(true), "/%s is in an admin's /help" % cmd)
		assert_false(key in ChatCommands.help_lines(false), "and not in a player's")
	var keys := ["chat.time_off", "chat.time_bad", "chat.time_bad_skip", "chat.time_set", "chat.speed_range",
		"chat.speed_set", "chat.fly_on", "chat.fly_off", "chat.heal_downed", "chat.healed", "dock.admin", "win.admin",
		"admin.weather", "admin.time", "admin.speed", "admin.set", "admin.skip_hour", "admin.reset", "admin.fly", "admin.heal"]
	for cmd in ["time", "speed", "fly", "heal"]:
		keys.append(ChatCommands.USAGE[cmd])
	for id in AdminPanel.weather_states():
		keys.append("weather.state." + str(id))
	var csv := I18nScript.parse_csv(I18nScript.CATALOG_PATH)
	assert_eq(csv["dupes"], [], "no key is listed twice")
	for key in keys:
		assert_true(I18nScript.has_key(key), "%s is in the catalog" % key)
		for loc in csv["locales"]:
			assert_true(str((csv["catalog"][loc] as Dictionary).get(key, "")).strip_edges() != "", "%s has a %s line" % [key, loc])

func _test_heal_unsent_keeps_hp() -> void:
	var rig := _chat_rig()
	var chat: ChatSlice = rig["chat"]
	var reg: PlayerRegistry = rig["reg"]
	reg.is_authoritative = true
	var pid := reg.resolve_identity(4, "")
	reg.record_simulated_hp(pid, 40.0)
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.set_transport(MemoryTransport.new([]))   # the registry still names peer 4, but the wire has dropped it
	chat.networking = n
	var heard := _capture(func() -> void: chat.handle_intent("/heal %s" % reg.public_handle(pid), ""))
	assert_eq(_keys(heard), ["chat.unreachable"], "the admin hears the peer is out of reach")
	assert_eq(reg.get_hp(pid), 40.0, "and the host did not fill a bar the client never heard about")
	n.free()
	chat.free()
	reg.free()

func _test_moves_reset_on_rejoin() -> void:
	var rig := _chat_rig()
	var chat: ChatSlice = rig["chat"]
	chat._admin_moves["p9"] = { "speed": 3.0, "fly": true }
	GameBus.player_joined.emit(4, "p9", true)
	assert_eq(chat.admin_moves_of("p9"), { "speed": 1.0, "fly": false }, "the host forgets the moves on a (re)join")
	chat.free()
	rig["reg"].free()
	# The client side: its identity resets the body it kept from the last connection.
	var gr: Node = (load("res://src/core/game_root.gd") as GDScript).new()
	gr._is_client = true
	var player := PlayerSlice.new()
	gr._player = player
	gr._admin_wiring.wire(gr)
	player.set_admin_moves(3.0, true)
	GameBus.player_identity_assigned.emit("p9")
	gr._admin_wiring.unwire()
	assert_eq(player.admin_speed_factor, 1.0, "the client walks at normal speed again")
	assert_false(player.flying, "and no longer flies")
	player.free()
	gr.free()

func _test_fly_gated() -> void:
	var t := [0.0]
	var player := PlayerSlice.new()
	player.status_clock = func() -> float: return t[0]
	add_child(player)
	player.set_admin_moves(2.0, true)
	assert_eq(player.fly_vertical(true, false), AdminRules.FLY_VERTICAL_SPEED * 2.0, "Space climbs at the admin speed")
	player.apply_status_effects([{ "effect": "paralysis", "remaining": 3.0 }])
	assert_eq(player.fly_vertical(true, false), 0.0, "an immobilized body neither climbs")
	assert_eq(player.fly_vertical(false, true), 0.0, "nor sinks")
	t[0] = 3.1
	player.set_world_input_frozen(true)
	assert_eq(player.fly_vertical(true, false), 0.0, "and the keys mean nothing while world input is refused")
	player.set_world_input_frozen(false)
	assert_eq(player.fly_vertical(false, true), -AdminRules.FLY_VERTICAL_SPEED * 2.0, "until it is allowed again")
	player.free()

func _test_admins_file_live() -> void:
	var path := "user://admin_tests_admins.json"
	var rig := _chat_rig()
	var chat: ChatSlice = rig["chat"]
	var reg: PlayerRegistry = rig["reg"]
	reg.is_authoritative = true
	var pid := reg.resolve_identity(4, "")
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	var wire := MemoryTransport.new([4])
	n.set_transport(wire)
	chat.networking = n
	chat.admins_path = path
	assert_eq(chat.poll_admins_file(), [], "no file, no change")
	_write_admins(path, [pid])
	assert_eq(chat.poll_admins_file(), [pid], "an added id flips")
	assert_true(chat.is_admin(pid), "and may run admin commands now")
	assert_eq(chat.poll_admins_file(), [], "an unchanged file is not read again")
	_write_admins(path, [])
	chat._admins_mtime = -1   # the file's mtime has a one-second grain; the test cannot wait for it
	assert_eq(chat.poll_admins_file(), [pid], "a removed id flips back")
	assert_false(chat.is_admin(pid), "and is refused again")
	var sent: Array = []
	for m: Dictionary in wire.outbox:
		assert_eq(int(m["peer_id"]), 4, "the status goes to that player's peer alone")
		sent.append(m["payload"].get("admin"))
	assert_eq(sent, [true, false], "as an admin_status each time it flipped")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	n.free()
	chat.free()
	reg.free()

func _write_admins(path: String, ids: Array) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(ids))
	f.close()

func _test_carry_cap_follows_moves() -> void:
	var gr: Node = (load("res://src/core/game_root.gd") as GDScript).new()
	gr._registry = PlayerRegistry.new()
	gr._registry.local_player_id = "p1"
	var sl := CarcassSlice.new()
	add_child(sl)
	gr._carcass = sl
	var chat := ChatSlice.new()
	gr._chat = chat
	var base: float = gr._carcass_wiring.carry_rate("p1")
	chat._admin_moves["p1"] = { "speed": 2.0, "fly": false }
	assert_true(absf(gr._carcass_wiring.carry_rate("p1") - base * 2.0) < 1e-6, "/speed 2 doubles the carry cap")
	chat._admin_moves["p1"] = { "speed": 2.0, "fly": true }
	assert_true(absf(gr._carcass_wiring.carry_rate("p1") - base * 2.0 * AdminRules.FLY_SPEED_FACTOR) < 1e-6, "and flying multiplies it again")
	chat.free()
	sl.free()
	gr._registry.free()
	gr.free()
func _test_regen_command() -> void:
	var rig := _chat_rig()
	var chat: ChatSlice = rig["chat"]
	var asked: Array = []
	var cb := func(pid: String) -> void: asked.append(pid)
	GameBus.world_regen_requested.connect(cb)
	var heard := _capture(func() -> void:
		chat.handle_intent("/regen", "")
		chat.handle_intent("/regen world", "")
		chat.handle_intent("/regen world please", "")
		chat.handle_intent("/regen world confirm", "stranger_1")
		chat.handle_intent("/regen world confirm", ""))
	GameBus.world_regen_requested.disconnect(cb)
	assert_eq(_keys(heard), ["chat.usage.regen", "chat.regen_confirm", "chat.regen_confirm", "chat.admin_only"],
		"usage, then the warning twice, and a non-admin is refused")
	assert_eq(asked, ["player_host_1"], "only the confirmed admin line asks the host")
	assert_eq(AdminPanel.REGEN_COMMAND, "/regen world confirm", "the window's button sends the confirmed form")
	chat.free()
	rig["reg"].free()

func _test_regen_resets() -> void:
	var voxel := _make_voxel()
	voxel.apply_edits({ "3,4": [{ "op": "remove", "bottom": 1.0, "top": 2.0 }] })
	voxel._vein_taken["v1"] = 3
	voxel._dirty_chunks["0,0"] = true
	var hm: Array = []
	hm.resize(VoxelSlice.CHUNK_SIZE * VoxelSlice.CHUNK_SIZE)
	hm.fill(0.0)
	voxel._heightmaps["0,0"] = hm
	voxel.reset_world()
	assert_true(voxel.get_edits().is_empty(), "no edit is left")
	assert_true(voxel._vein_taken.is_empty(), "no ore is depleted")
	assert_true(voxel._dirty_chunks.is_empty(), "nothing is waiting to be saved")
	assert_true(voxel._heightmaps.is_empty(), "and no heightmap of the old ground is cached")
	voxel.free()
	var t := _make_tree_slice()
	t._record_cleared(Vector2i(2, 2), 1)
	t._pending_spots[Vector2i(1, 1)] = [[1.0, 1.0, 2.0]]
	t._pending_spot_count = 1
	t._stump_memory["tree_x"] = 99.0
	t.reset_world()
	assert_true(t._cleared_local.is_empty() and t._cleared_total == 0, "tree clears are forgotten")
	assert_true(t._pending_spots.is_empty() and t._pending_spot_count == 0, "and so are held spots")
	assert_true(t._stump_memory.is_empty(), "and remembered stumps")
	t.free()
	var store := RegionStoreScript.new(_fresh_region_dir("test_p182_streamer") + "regions/")
	store.write_chunks({ "1,1": { "gen": RegionStoreScript.normalize_gen(TerrainSlice.generation_record(Vector2i(1, 1), 31)) } })
	var v2 := _make_voxel()
	var streamer := RegionStreamerScript.new(store, v2)
	streamer.sync({ "0,0": true })
	assert_true(streamer._resident.has("0,0"), "a region was read")
	streamer.reset()
	assert_true(streamer._resident.is_empty() and streamer._wanted_last.is_empty(), "the streamer forgets every read")
	v2.free()
	ChunkRecordsScript.clear()

## A GameRoot with just the slices a regen touches (the suite builds roots without `_ready`).
func _regen_root(dir: String) -> Node:
	var gr: Node = load("res://src/core/game_root.gd").new()
	gr._persistence = PersistenceSlice.new()
	gr._persistence.server_save_dir = dir
	gr._voxel = _make_voxel()
	gr._terrain = TerrainSlice.new()
	gr._terrain.set_world_seed(31)
	gr._voxel.terrain_slice = gr._terrain
	gr._station = StationSlice.new()
	gr._tree = _make_tree_slice()
	gr._chunk_manager = ChunkManager.new()
	return gr

func _free_regen_root(gr: Node) -> void:
	for n in [gr._persistence, gr._voxel, gr._terrain, gr._station, gr._tree, gr._chunk_manager]:
		if is_instance_valid(n):
			n.free()
	gr.free()

func _test_regen_world_host() -> void:
	var dir := _fresh_region_dir("test_p182_regen")
	var gr := _regen_root(dir)
	var store: RegionStoreScript = gr._persistence.region_store
	store.write_chunks({ "1,1": { "gen": RegionStoreScript.normalize_gen(TerrainSlice.generation_record(Vector2i(1, 1), 31)),
		"edits": { "40,40": [{ "op": "remove", "bottom": 1.0, "top": 2.0 }] } } })
	assert_eq(_region_files(dir + "regions/").size(), 1, "the world has a region on disk")
	ChunkRecordsScript.set_record(Vector2i(1, 1), _sync_record(Vector2i(1, 1)))
	gr._voxel.apply_edits({ "40,40": [{ "op": "remove", "bottom": 1.0, "top": 2.0 }] })
	gr._station.place_station("forge", Vector3(8.5, 6.0, 8.5))
	var placed_y := WorldPos.from_wire(gr._station.get_station_data()[0]["position"]).y
	var lift: float = placed_y - gr._voxel.get_voxel_height_at(Vector2(8.5, 8.5))
	gr._worldgen_stamp = TerrainSlice.WORLDGEN_VERSION - 3
	gr._worldgen_fp_stamp = 12345
	assert_eq(gr._admin_wiring.regen_world(false), "", "a host regenerates")
	assert_eq(gr._worldgen_stamp, TerrainSlice.WORLDGEN_VERSION, "the world is stamped with the running generator")
	assert_eq(gr._worldgen_fp_stamp, TerrainSlice.worldgen_fingerprint(), "and its fingerprint")
	assert_true(gr._worldgen_fp_history.has(12345), "the old fingerprint stays in the history")
	assert_true(ChunkRecordsScript.is_empty(), "no generation record is left in memory")
	assert_true(gr._voxel.get_edits().is_empty(), "nor any edit")
	assert_eq(_region_files(dir + "regions/").size(), 0, "the regions folder is empty")
	var backups: Array = []
	for name in DirAccess.open(dir).get_directories():
		if str(name).begins_with("regions.regen-"):
			backups.append(str(name))
	assert_eq(backups.size(), 1, "the old regions were moved aside")
	assert_eq(_region_files(dir + str(backups[0]) + "/").size(), 1, "with their file in it")
	var kept: Array = gr._station.get_station_data()
	assert_eq(kept.size(), 1, "the station is kept")
	var kept_y := WorldPos.from_wire(kept[0]["position"]).y
	var ground: float = gr._voxel.get_voxel_height_at(Vector2(8.5, 8.5))
	assert_true(absf(kept_y - (ground + lift)) < 1e-4, "as high above the new ground as it stood above the old (%.3f over %.3f)" % [kept_y, ground])
	gr._is_client = true
	assert_eq(gr._admin_wiring.regen_world(false), "not_host", "a client cannot regenerate")
	for name in backups:
		_wipe_dir(dir + str(name) + "/")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + str(name)))
	_free_regen_root(gr)
	ChunkRecordsScript.clear()

func _test_regen_client() -> void:
	var gr := _regen_root(_fresh_region_dir("test_p182_regen_client"))
	gr._is_client = true
	gr._admin_wiring.wire(gr)
	ChunkRecordsScript.set_record(Vector2i(1, 1), _sync_record(Vector2i(1, 1)))
	gr._voxel.apply_edits({ "3,4": [{ "op": "remove", "bottom": 1.0, "top": 2.0 }] })
	var client := NetworkingSlice.new()
	add_child(client)
	client._role = NetworkingSlice.Role.CLIENT
	client._route_h2c({ "type": "world_regen" })
	assert_true(ChunkRecordsScript.is_empty(), "the client's records are gone")
	assert_true(gr._voxel.get_edits().is_empty(), "and its edits")
	gr._admin_wiring.unwire()
	client.free()
	_free_regen_root(gr)
	ChunkRecordsScript.clear()
