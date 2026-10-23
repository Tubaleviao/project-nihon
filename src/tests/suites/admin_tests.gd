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
	assert_false(n.send_admin_moves(9, 1.0, false), "an unconnected peer is not sent anything")
	n._role = NetworkingSlice.Role.CLIENT
	assert_false(n.send_admin_heal(4), "and a client sends no admin packets")
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
	client._role = NetworkingSlice.Role.HOST
	client._route_h2c({ "type": "admin_heal" })
	GameBus.admin_moves_synced.disconnect(on_moves)
	GameBus.admin_healed.disconnect(on_heal)
	GameBus.admin_status_synced.disconnect(on_status)
	assert_eq(moves, [[2.5, true]], "a client applies a numeric speed and drops a malformed one")
	assert_eq(heals[0], 1, "a heal reaches a client's bus, never a host's")
	assert_eq(status, [true, false], "the admin flag is read strictly from the identity")
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
