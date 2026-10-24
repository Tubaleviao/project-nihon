extends "res://src/tests/test_support.gd"

const HoldablesData := preload("res://src/inventory/holdables.gd")
## Phase 133 — the ui tests, moved unchanged from the old single-file suite.


func register() -> void:
	_run_test("chat: /where prints X and Y", _test_where_command)
	_run_test("chat: slash lines parse, sanitize and validate", _test_chat_parse)
	_run_test("chat: admin commands run for admins only",     _test_chat_admin_commands)
	_run_test("chat: lines and intents cross the wire",       _test_chat_wire)
	_run_test("chat: the input box is on screen while closed", _test_chat_box_visible)
	_run_test("chat: a token bucket bounds each player's lines", _test_chat_rate_limit)
	_run_test("chat: a failed admin effect is reported, not claimed", _test_chat_failed_effects_report)
	_run_test("chat: /tp a million chunks out is exact", _test_chat_tp_far_exact)
	_run_test("chat: /kill on a peer runs through simulated HP", _test_chat_kill_peer_simulated_hp)
	_run_test("chat: no one else calls send_player_damaged",  _test_chat_no_direct_damage_door)
	_run_test("chat: teleports carry the exact position",     _test_chat_exact_teleports)
	_run_test("chat: /tp wraps X and refuses a Z past the poles", _test_chat_tp_limits)
	_run_test("ui: ? hotkey matches on unicode",                 _test_ui_question_mark_hotkey)
	_run_test("ui: failed layout rename cleans tmp",             _test_ui_layout_failed_rename_cleans_tmp)
	_run_test("ui: character window rows + equip",              _test_ui_character_rows)
	_run_test("minimap: blend never borrows an unrevealed biome", _test_minimap_blend_respects_fog)
	_run_test("minimap: a second redraw looks up no biome",      _test_minimap_redraw_uses_cache)
	_run_test("map: past a pole is the far meridian",            _test_map_past_pole_matches_far_meridian)
	_run_test("minimap: a skipped-chunk step leaves no gap",     _test_minimap_walk_leaves_no_gap)
	_run_test("minimap: sub-2px cells draw one rect per chunk",  _test_minimap_far_zoom_one_rect)
	_run_test("minimap: biome cache is bounded and seed-keyed",  _test_minimap_cache_bounded_and_seeded)
	_run_test("ui: saved layout past the edge lands inside",     _test_ui_layout_first_apply_fits)
	_run_test("ui: windows toggle open/close",                 _test_ui_window_toggle)
	_run_test("ui: window lists fill the window",              _test_ui_window_lists_fill)
	_run_test("ui: inventory lines reflect contents",          _test_ui_inventory_lines)
	_run_test("ui: window drag clamps on-screen",              _test_ui_window_clamp)
	_run_test("ui: layout parse/serialise drops junk",         _test_ui_layout_roundtrip)
	_run_test("ui: layout persists through a file",            _test_ui_layout_file_roundtrip)
	_run_test("ui: closing windows ends a drag",               _test_ui_drag_state_resets)
	_run_test("ui: inventory rows project N slots",            _test_ui_inventory_rows)
	_run_test("ui: item icon key + action intent mapping",     _test_ui_icon_key_and_intent)
	_run_test("ui: controls legend lives behind ?, not HUD",   _test_ui_controls_panel)
	_run_test("hud: hotbar fill / wrap / kinds",               _test_hud_hotbar_pure)
	_run_test("hud: hotbar selection drives place material",   _test_hud_hotbar_selection)
	_run_test("hud: skills and shortcut keys on the bar",      _test_hud_hotbar_skills_and_binding)
	_run_test("hud: drag and drop to boxes and the ground",    _test_hud_drag_and_drop)
	_run_test("hud: a dropped tool keeps its wear",            _test_hud_drop_keeps_durability)
	_run_test("hud: skills list + window keys",                _test_hud_skills_rows_and_window_keys)
	_run_test("hud: window dock letters match the key map",    _test_hud_window_dock)
	_run_test("icons: every window, skill, status and HP has a valid UI icon", _test_ui_icons_cover_everything)
	_run_test("icons: dock buttons carry an icon and a letter badge", _test_dock_icons_and_badges)
	_run_test("icons: status icon ids are distinct and ordered", _test_status_icon_ids)
	_run_test("map: cube faces are equal, seams meet, the globe inverts", _test_map_cube_net)
	_run_test("map: tiles are pure and keyed by seed and version", _test_map_tile_purity)
	_run_test("map: tile cache is bounded, coarse answered first", _test_map_tile_cache)
	_run_test("map: revealed set round-trips through save and load", _test_map_revealed_roundtrip)
	_run_test("map: revealed cap and compact encoding",         _test_map_revealed_cap_and_size)
	_run_test("map: home clamp is exact and on the line",       _test_map_home_clamp)
	_run_test("map: 50k revealed chunks save and reload, oldest last", _test_map_revealed_scale)
	_run_test("map: waypoints round-trip, cap and seed scope",  _test_map_waypoints)
	_run_test("map: minimap drops out-of-world chunks and late seeds", _test_map_minimap_load_and_seed)
	_run_test("map: stale tiles are capped and the queue survives a pan", _test_map_tiles_stale_and_queue)
	_run_test("map: window zoom, fog, hover, waypoint delete and great-circle home", _test_map_window_phase117)
	_run_test("ui: HUD toasts are bounded and de-duplicated",   _test_ui_toasts)
	_run_test("ui: a world-version mismatch is one toast, a pre-stamp save none", _test_ui_worldgen_toast)
	_run_test("map: M and the dock box toggle the Map window",  _test_map_window_key)
	_run_test("map: waypoints sit on the game view's horizon",  _test_map_waypoint_horizon)
	_run_test("ui: every item resolves an icon texture on every surface", _test_ui_every_item_has_icon)
	_run_test("ui: no surface falls back to the glyph for any holdable id", _test_ui_no_glyph_for_any_holdable)
	_run_test("ui: crafting rows gate on technology",          _test_ui_crafting_rows_tech_gate)
	_run_test("ui: technology rows report status + prereqs",   _test_ui_technology_rows_status)
	_run_test("ui: the loading screen shows and hides",          _test_loading_screen_visibility)
	_run_test("chat: /where is spelled once",                       _test_chat_command_constant)
	_run_test("ui: retiring 1,000 controls prunes the list a handful of times", _test_ui_retire_prunes_amortised)
	_run_test("p131: catalogs share one key set, no empty cells",  _test_p131_catalog_keys)
	_run_test("p131: no untranslated literal in UI assignments",   _test_p131_literal_audit)
	_run_test("p148: the literal audit fails on a hard-coded fixture", _test_p148_audit_fixture)
	_run_test("p148: every reason code has a catalog key",             _test_p148_reason_codes_have_keys)
	_run_test("p148: reason codes render with params",             _test_p148_reason_text)
	_run_test("p148: multi-digit and numeric placeholders",        _test_p148_number_placeholders)
	_run_test("p148: a missing catalog logs once and retries",     _test_p148_catalog_retry)
	_run_test("p131: locale switch, persistence, OS fallback",     _test_p131_locale_switch)
	_run_test("p131: host system messages travel as key + args",   _test_p131_system_message)

func _test_where_command() -> void:
	var pos := Vector3(0.0, 12.0, 0.0)
	assert_true(ChatCommands.is_command("/where"), "/where is a command")
	assert_true(ChatCommands.is_command("  /WHERE "), "case and padding are ignored")
	assert_true(not ChatCommands.is_command("hello"), "plain chat is not a command")
	assert_eq(ChatCommands.run("/where", pos), TerrainSlice.where_text(pos), "/where prints where_text")
	assert_eq(ChatCommands.run("hello", pos), "", "plain chat prints nothing")
	assert_false(ChatCommands.is_command("/wherever"), "only the exact command matches")
	assert_eq(ChatCommands.run("/WHERE ", pos), TerrainSlice.where_text(pos), "run and is_command agree on spelling")

func _test_chat_parse() -> void:
	var parsed := ChatCommands.parse("  /TP  1 2.5  -3 ")
	assert_eq(parsed["name"], "tp", "name is lower-cased and slash-free")
	assert_eq(parsed["args"], ["1", "2.5", "-3"], "args are whitespace-split")
	assert_eq(ChatCommands.parse("hello")["name"], "", "plain chat parses to no command")
	assert_eq(ChatCommands.parse("/")["name"], "", "a bare slash names nothing")
	assert_true(ChatCommands.is_slash(" /x"), "padding does not hide a slash")
	assert_eq(ChatCommands.sanitize("a\nb\u0001c"), "abc", "control characters are dropped")
	assert_eq(ChatCommands.sanitize("   ").length(), 0, "blank is nothing")
	assert_eq(ChatCommands.sanitize("x".repeat(500)).length(), ChatCommands.MAX_MESSAGE_CHARS, "long lines are capped")
	var ok := ChatCommands.parse_position(["1", "2.5", "-3"])
	assert_true(ok["ok"] and ok["pos"]["chunk"] == Vector2i(0, -1), "three numbers make a position in the right chunk")
	assert_true((ok["pos"]["local"] as Vector3).distance_to(Vector3(1.0, 2.5, TerrainSlice.CHUNK_METERS - 3.0)) < 1e-4, "with the exact local")
	var far_x := 600000.0 * TerrainSlice.CHUNK_METERS + 0.123
	var far := ChatCommands.parse_position([str(far_x), "5", "0"])
	assert_true(far["ok"], "a point a million chunks out parses")
	assert_eq(far["pos"]["chunk"], Vector2i(600000, 0), "into its exact chunk")
	assert_true(absf(float(far["pos"]["local"].x) - 0.123) < 1e-3, "keeping the sub-metre digits a float32 detour would lose")
	assert_false(ChatCommands.parse_position(["1", "2"])["ok"], "too few numbers")
	assert_false(ChatCommands.parse_position(["1", "x", "3"])["ok"], "not a number")
	assert_false(ChatCommands.parse_position(["1", "nan", "3"])["ok"], "nan is refused")
	assert_false(ChatCommands.parse_position(["1", "inf", "3"])["ok"], "inf is refused")
	assert_false(ChatCommands.parse_position(["1", "1e12", "3"])["ok"], "beyond the planet is refused")
	assert_eq(ChatCommands.parse_quantity("5"), 5, "a quantity")
	assert_eq(ChatCommands.parse_quantity("0"), 0, "zero is refused")
	assert_eq(ChatCommands.parse_quantity("-2"), 0, "negative is refused")
	assert_eq(ChatCommands.parse_quantity("99999999"), 0, "huge is refused")
	assert_eq(ChatCommands.parse_quantity("1.5"), 0, "fractions are refused")
	assert_eq(ChatCommands.match_item("ferriteingot", ["FerriteIngot", "Other"]), "FerriteIngot", "item match ignores case")
	assert_eq(ChatCommands.match_item("nope", ["FerriteIngot"]), "", "unknown item")
	assert_true(ChatCommands.is_admin_command("kill") and not ChatCommands.is_admin_command("help"), "admin set")
	assert_true(ChatCommands.is_known("where") and ChatCommands.is_known("give") and not ChatCommands.is_known("nope"), "known set")
	assert_true(ChatCommands.help_lines(true).size() > ChatCommands.help_lines(false).size(), "admins see more of /help")

func _test_chat_admin_commands() -> void:
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("player_host_1")
	var inv := InventorySlice.new()
	add_child(inv)
	var body := PlayerSlice.new()
	body.render_visuals = false
	add_child(body)
	var chat := ChatSlice.new()
	chat.render_visuals = false
	chat.admins_path = "user://does_not_exist_admins.json"
	chat.player_registry = reg
	chat.player_slice = body
	chat.inventory_slice = inv
	add_child(chat)
	# A fake clock that runs a second ahead per line keeps this test clear of the chat token bucket.
	var ticks := [0.0]
	chat.set_clock(func() -> float:
		ticks[0] += 10.0
		return ticks[0])

	var posted: Array = []
	var cb := func(channel: String, sender: String, text: String, target: String) -> void:
		posted.append({ "channel": channel, "sender": sender, "text": text, "target": target })
	GameBus.chat_posted.connect(cb)
	var sysb_18982 := _p131_system_bridge(cb)
	var teleports: Array = []
	var tp := func(pos: Dictionary) -> void: teleports.append(WorldPos.to_scene(pos, Vector2i.ZERO))
	GameBus.player_teleport.connect(tp)

	assert_true(chat.is_admin("player_host_1"), "the host's own player is an admin")
	assert_false(chat.is_admin("player_other"), "anyone else is not")
	assert_false(chat.is_admin(""), "nobody is not")

	chat.handle_intent("hello world", "")
	assert_eq(posted.back()["channel"], "chat", "plain text is said")
	assert_eq(posted.back()["text"], "hello world", "as typed")
	assert_eq(posted.back()["target"], "", "to everyone")

	posted.clear()
	chat.handle_intent("/say server restarts soon", "")
	assert_eq(posted.back()["channel"], "announce", "/say announces")
	assert_eq(posted.back()["sender"], "Server", "from the server")
	assert_eq(posted.back()["text"], "server restarts soon", "the whole message")

	chat.handle_intent("/give ferriteingot 3", "")
	assert_eq(inv.get_item_count("FerriteIngot"), 3, "/give creates items for the admin")
	chat.handle_intent("/give nonsense", "")
	assert_eq(inv.get_item_count("nonsense"), 0, "an unknown item creates nothing")
	assert_true(str(posted.back()["text"]).contains("Unknown item"), "and says so")
	chat.handle_intent("/give FerriteIngot 0", "")
	assert_eq(inv.get_item_count("FerriteIngot"), 3, "a zero quantity creates nothing")

	chat.handle_intent("/tp 10 20 30", "")
	assert_eq(teleports.size(), 1, "/tp moves the admin")
	assert_eq(teleports[0], Vector3(10.0, 20.0, 30.0), "to the typed spot")
	chat.handle_intent("/tp 10 banana 30", "")
	assert_eq(teleports.size(), 1, "a bad coordinate moves nobody")

	chat.handle_intent("/kill", "")
	assert_eq(body.get_hp(), 0.0, "/kill with no target kills the admin")

	# A non-admin is refused every admin command, and the refusal is addressed to them alone.
	posted.clear()
	teleports.clear()
	for line in ["/say hi", "/tp 1 2 3", "/give FerriteIngot 1", "/kill me", "/bring me"]:
		chat.handle_intent(line, "player_other")
	assert_eq(teleports.size(), 0, "a non-admin teleports nobody")
	assert_eq(inv.get_item_count("FerriteIngot"), 3, "a non-admin creates nothing")
	assert_eq(posted.size(), 5, "each refused line is answered")
	for m in posted:
		assert_eq(m["target"], "player_other", "the refusal goes to the caller only")
		assert_eq(m["channel"], "system", "as a system line")
	# Non-admins keep the open commands.
	posted.clear()
	chat.handle_intent("/help", "player_other")
	assert_true(posted.size() >= 3, "/help answers a non-admin")
	posted.clear()
	chat.handle_intent("/nope", "player_other")
	assert_true(str(posted.back()["text"]).contains("Unknown command"), "an unknown command is named")

	# An admins file grants admin to the ids it lists.
	var path := "user://test_admins_phase85.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("[\"player_other\", 7, \"\"]")
	f.close()
	chat.admins_path = path
	chat._load_admins()
	assert_true(chat.is_admin("player_other"), "a listed id is an admin")
	assert_false(chat.is_admin("player_third"), "an unlisted one is not")
	DirAccess.remove_absolute(path)

	GameBus.chat_posted.disconnect(cb)
	GameBus.system_message.disconnect(sysb_18982)
	GameBus.player_teleport.disconnect(tp)
	chat.free()
	body.free()
	inv.free()
	reg.free()

func _test_chat_wire() -> void:
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.set_transport(MemoryTransport.new([4, 5]))
	n._on_chat_posted("announce", "Server", "hello", "")
	var kinds: Array = []
	for m in n.memory_transport().outbox:
		kinds.append([m["peer_id"], m["payload"]["type"], m["payload"]["text"]])
	assert_eq(kinds, [[4, "chat_message", "hello"], [5, "chat_message", "hello"]], "an untargeted line reaches every peer")
	n.memory_transport().outbox.clear()
	n.send_teleport(4, WorldPos.from_world(5.0, 6.0, 7.0))
	assert_eq(n.memory_transport().outbox.size(), 1, "a teleport goes to one peer")
	assert_eq(n.memory_transport().outbox[0]["payload"]["type"], "teleport", "as a teleport packet")

	# Host side of the intent: the speaker is the connection's player, never the payload's claim.
	var got: Array = []
	var cb := func(text: String, pid: String) -> void: got.append([text, pid])
	GameBus.chat_intent.connect(cb)
	n._route_c2h(9, { "type": "chat_intent", "text": "hi", "player_id": "player_forged" })
	assert_eq(got.size(), 0, "an un-handshaked peer cannot speak")
	n.set_player_id(9, "player_real")
	n._route_c2h(9, { "type": "chat_intent", "text": "hi", "player_id": "player_forged" })
	assert_eq(got, [["hi", "player_real"]], "the connection's player speaks, not the claimed one")
	n._route_c2h(9, { "type": "chat_intent", "text": 42 })
	assert_eq(got.size(), 1, "a non-string line is dropped")
	GameBus.chat_intent.disconnect(cb)

	# Client side: the intent is forwarded and a hosted line is shown.
	n.memory_transport().outbox.clear()
	n._role = NetworkingSlice.Role.CLIENT
	n._on_chat_intent("/tp 1 2 3", "")
	assert_eq(n.memory_transport().outbox.size(), 1, "a client forwards its line to the host")
	assert_eq(n.memory_transport().outbox[0]["payload"]["type"], "chat_intent", "as an intent")
	assert_false(n.memory_transport().outbox[0]["payload"].has("player_id"), "carrying no identity")
	var shown: Array = []
	var cb2 := func(channel: String, sender: String, text: String, target: String) -> void:
		shown.append([channel, sender, text, target])
	GameBus.chat_posted.connect(cb2)
	var sysb_19365 := _p131_system_bridge(cb2)
	n._route_h2c({ "type": "chat_message", "channel": "announce", "sender": "Server", "text": "hey" })
	GameBus.chat_posted.disconnect(cb2)
	GameBus.system_message.disconnect(sysb_19365)
	assert_eq(shown, [["announce", "Server", "hey", ""]], "a hosted line is re-emitted for the box")
	var moved: Array = []
	var cb3 := func(pos: Dictionary) -> void: moved.append(WorldPos.to_scene(pos, Vector2i.ZERO))
	GameBus.player_teleport.connect(cb3)
	n._route_h2c({ "type": "teleport", "position": WorldPos.to_wire(Vector3(100.0, 9.0, -40.0)) })
	GameBus.player_teleport.disconnect(cb3)
	assert_eq(moved.size(), 1, "a teleport packet moves the body")
	assert_true(moved[0].distance_to(Vector3(100.0, 9.0, -40.0)) < 0.01, "to the sent spot")
	n.set_transport(null)
	n.free()

func _test_chat_box_visible() -> void:
	var c := ChatSlice.new()
	add_child(c)
	assert_true(c._field != null and c._field.visible, "the box shows before Enter is pressed")
	assert_false(c.is_typing(), "but it does not hold the keyboard")
	assert_true(c._field.placeholder_text.contains("Enter"), "and it says how to start typing")
	c.open_input("/")
	assert_eq(c._field.text, "/", "Enter or / prefills and focuses it")
	c._close_input()
	c.queue_free()

## Phase 101 — a burst is bounded per player, refills with the clock and is dropped on disconnect.
func _test_chat_rate_limit() -> void:
	var rig := _chat_rig()
	var chat: ChatSlice = rig["chat"]
	var now := [100.0]
	chat.set_clock(func() -> float: return now[0])
	var posted: Array = []
	var cb := func(channel: String, _sender: String, text: String, target: String) -> void:
		posted.append({ "channel": channel, "text": text, "target": target })
	GameBus.chat_posted.connect(cb)
	var sysb_19095 := _p131_system_bridge(cb)
	for i in ChatSlice.CHAT_BURST + 10:
		chat.handle_intent("line %d" % i, "player_other")
	var said := posted.filter(func(m): return m["channel"] == "chat" and m["target"] == "")
	var notices := posted.filter(func(m): return m["channel"] == "system")
	assert_eq(said.size(), ChatSlice.CHAT_BURST, "exactly CHAT_BURST lines are broadcast")
	assert_eq(chat.chat_rate_refused, 10, "the rest are counted as refused")
	assert_eq(notices.size(), 1, "one slow-down notice")
	assert_eq(notices[0]["target"], "player_other", "addressed to the speaker alone")
	now[0] += 1.0 / ChatSlice.CHAT_LINES_PER_SEC
	posted.clear()
	chat.handle_intent("again", "player_other")
	assert_eq(posted.size(), 1, "one more line after 1/CHAT_LINES_PER_SEC seconds")
	assert_eq(posted[0]["text"], "again", "and it is the line")
	chat.handle_intent("too soon", "player_other")
	assert_eq(chat.chat_rate_refused, 11, "but not two")
	# Another player has a bucket of their own, and the host's local player is limited too.
	posted.clear()
	chat.handle_intent("hi", "player_third")
	assert_eq(posted.size(), 1, "one player's flood does not starve another")
	for i in ChatSlice.CHAT_BURST + 1:
		chat.handle_intent("host %d" % i, "")
	assert_eq(chat.chat_rate_refused, 12, "the local player is subject to the bucket")
	assert_true(chat._buckets.has("player_other"), "a bucket exists while the player is here")
	# Phase 115 — a reconnect does not refill the bucket.
	GameBus.player_left.emit("player_other")
	assert_true(chat._buckets.has("player_other"), "a disconnect keeps the bucket entry")
	var refused_before := chat.chat_rate_refused
	chat.handle_intent("after reconnect", "player_other")
	assert_eq(chat.chat_rate_refused, refused_before + 1, "so a reconnect does not refill the bucket")
	# An admin's commands are not throttled by the chat bucket (the host's local player is an admin).
	posted.clear()
	for i in ChatSlice.CHAT_BURST * 3:
		chat.handle_intent("/help", "")
	assert_eq(chat.chat_rate_refused, refused_before + 1, "an admin's commands never spend a token")
	assert_false(posted.is_empty(), "and are answered")
	# A non-admin's commands (known, unknown, admin-only) spend the bucket like chat does.
	for cmd in ["/help", "/nope", "/say hi"]:
		chat.handle_intent(cmd, "player_other")
	assert_eq(chat.chat_rate_refused, refused_before + 4, "a non-admin's commands are throttled")
	# The map stays bounded: fully refilled buckets are pruned once many are held.
	for i in ChatSlice.MAX_BUCKETS + 5:
		chat.handle_intent("x", "bulk_%d" % i)
	now[0] += 1000.0
	GameBus.player_left.emit("bulk_0")
	assert_true(chat._buckets.size() <= ChatSlice.MAX_BUCKETS, "a burst of distinct speakers leaves at most the cap")
	chat._prune_buckets(0)
	assert_true(chat._buckets.size() <= 1, "idle full buckets are pruned past the cap")
	GameBus.chat_posted.disconnect(cb)
	GameBus.system_message.disconnect(sysb_19095)
	chat.free()
	rig["reg"].free()

## Phase 115 — an admin command that cannot be carried out says so instead of replying "done".
func _test_chat_failed_effects_report() -> void:
	var rig := _chat_rig()
	var chat: ChatSlice = rig["chat"]
	var reg: PlayerRegistry = rig["reg"]
	var posted: Array = []
	var pcb := func(_c: String, _s: String, text: String, _t: String) -> void: posted.append(text)
	GameBus.chat_posted.connect(pcb)
	var sysb_19284 := _p131_system_bridge(pcb)
	var seen: Array = []
	var cb := func(pos: Dictionary) -> void: seen.append(pos)
	GameBus.player_teleport.connect(cb)
	chat.handle_intent("/kill nobody_here", "")
	assert_true(str(posted.back()).contains("No player"), "/kill on an unknown peer reports a failure")
	assert_false(str(posted.back()).contains("Killed"), "and does not claim a kill")
	# A remote admin with no networking attached: nothing can be sent.
	chat._admins["player_remote"] = true
	posted.clear()
	chat.handle_intent("/tp 1 2 3", "player_remote")
	assert_true(str(posted.back()).contains("Could not teleport"), "/tp with no networking replies a failure")
	assert_false(str(posted.back()).contains("Teleported to"), "not success")
	assert_eq(seen.size(), 0, "and moves nobody")
	GameBus.player_teleport.disconnect(cb)
	GameBus.chat_posted.disconnect(pcb)
	GameBus.system_message.disconnect(sysb_19284)
	chat.free()
	reg.free()

## Phase 115 — `/tp` a million chunks out lands within 1e-3 m of the typed coordinate.
func _test_chat_tp_far_exact() -> void:
	var rig := _chat_rig()
	var chat: ChatSlice = rig["chat"]
	var seen: Array = []
	var cb := func(pos: Dictionary) -> void: seen.append(pos)
	GameBus.player_teleport.connect(cb)
	# 600,000 chunks is the far side of the half-lap; 1,200,000 wraps onto the seam side of the planet
	# (X is folded onto one lap, exactly, in doubles) and must keep its sub-metre digits there too.
	var lap_chunks := TerrainSlice.circumference_chunks()
	for typed_chunk in [600000, 1200000]:
		seen.clear()
		var x := float(typed_chunk) * TerrainSlice.CHUNK_METERS + 7.3125
		chat.handle_intent("/tp %s 12.5 %s" % [str(x), str(3.0 * TerrainSlice.CHUNK_METERS + 0.0625)], "")
		assert_eq(seen.size(), 1, "the far /tp teleports (%d chunks)" % typed_chunk)
		@warning_ignore("integer_division")
		var want_chunk: int = posmod(typed_chunk + lap_chunks / 2, lap_chunks) - lap_chunks / 2
		assert_eq(seen[0]["chunk"], Vector2i(want_chunk, 3), "to the typed chunk, wrapped onto one lap")
		var l: Vector3 = seen[0]["local"]
		assert_true(absf(l.x - 7.3125) < 1e-3 and absf(l.z - 0.0625) < 1e-3 and absf(l.y - 12.5) < 1e-3,
				"within 1e-3 m of the typed point (%d chunks)" % typed_chunk)
	GameBus.player_teleport.disconnect(cb)
	chat.free()
	rig["reg"].free()

## Phase 101 — `/kill` on a peer goes through the host's hit path: simulated HP floor, one packet,
## and the simulated number survives a reconnect.
func _test_chat_kill_peer_simulated_hp() -> void:
	var rig := _chat_rig()
	var chat: ChatSlice = rig["chat"]
	var reg: PlayerRegistry = rig["reg"]
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.set_transport(MemoryTransport.new([7]))
	chat.networking = n
	var pid := str(reg.resolve_identity(7))
	var gr: Node = (load("res://src/core/game_root.gd") as GDScript).new()
	gr._is_client = false
	gr._registry = reg
	gr._networking = n
	GameBus.player_damaged.connect(gr._combat_wiring.on_player_damaged)
	n.memory_transport().outbox.clear()
	chat.handle_intent("/kill %s" % reg.public_handle(pid), "")
	GameBus.player_damaged.disconnect(gr._combat_wiring.on_player_damaged)
	var hits: Array = n.memory_transport().outbox.filter(func(o): return o["payload"]["type"] == "player_damaged")
	assert_eq(hits.size(), 1, "exactly one player_damaged goes out")
	assert_eq(hits[0]["peer_id"], 7, "to that peer")
	assert_eq(reg.get_hp(pid), 0.0, "the host's simulated HP is at the floor")
	var back := PlayerRegistry.new()
	add_child(back)
	back.apply_player_data(pid, reg.get_player_data(pid))
	assert_eq(back.get_hp(pid), 0.0, "a reconnect restores the simulated value, not MAX_HP")
	back.free()
	gr.free()
	n.set_transport(null)
	n.free()
	chat.free()
	reg.free()

## Phase 101 — the damage door is game_root's: nothing else calls `send_player_damaged`.
func _test_chat_no_direct_damage_door() -> void:
	var offenders: Array = []
	var stack: Array = ["res://src"]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			stack.append(dir + "/" + sub)
		if dir.begins_with("res://src/tests"):
			continue
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd") or f in ["game_root.gd", "combat_wiring.gd", "networking_slice.gd"] or f.begins_with("net_part_"):
				continue
			if FileAccess.get_file_as_string(dir + "/" + f).contains("send_player_damaged("):
				offenders.append(f)
	assert_eq(offenders, [], "no file but game_root / its combat wiring / networking calls send_player_damaged")

## Phase 101 — a teleport keeps the exact `{chunk, local}` end to end, far from the origin.
func _test_chat_exact_teleports() -> void:
	var rig := _chat_rig()
	var chat: ChatSlice = rig["chat"]
	var reg: PlayerRegistry = rig["reg"]
	var stub := _StubBody.new()
	stub.wp = { "chunk": Vector2i(1200000, 3), "local": Vector3(0.25, 10.0, 0.75) }
	add_child(stub)
	chat.player_slice = stub
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.set_transport(MemoryTransport.new([7]))
	chat.networking = n
	var pid := str(reg.resolve_identity(7))
	var handle: String = reg.public_handle(pid)
	n._route_c2h(7, { "type": "player_moved", "position": WorldPos.pos_to_wire(
		{ "chunk": Vector2i(-900001, 40), "local": Vector3(31.9, 2.0, 0.1) }) })
	n.memory_transport().outbox.clear()
	chat.handle_intent("/bring " + handle, "")
	var sent: Array = n.memory_transport().outbox.filter(func(o): return o["payload"]["type"] == "teleport")
	assert_eq(sent.size(), 1, "/bring sends one teleport")
	var got: Dictionary = WorldPos.pos_from_wire(sent[0]["payload"]["position"])
	assert_eq(got["chunk"], Vector2i(1200000, 3), "to the admin's exact chunk")
	assert_true((got["local"] as Vector3).distance_to(Vector3(0.25, 10.0, 0.75)) < 1e-3, "and local")
	# The client side decodes it to the same record.
	var seen: Array = []
	var cb := func(pos: Dictionary) -> void: seen.append(pos)
	GameBus.player_teleport.connect(cb)
	n._role = NetworkingSlice.Role.CLIENT
	n._route_h2c(sent[0]["payload"])
	assert_eq(seen.size(), 1, "the client places the body")
	assert_eq(seen[0]["chunk"], Vector2i(1200000, 3), "in the exact chunk")
	# A malformed position is dropped and moves nothing.
	var was_quiet := Diag.quiet
	Diag.quiet = true
	n._route_h2c({ "type": "teleport", "position": { "chunk": [0, 0], "local": [NAN, 0, 0] } })
	n._route_h2c({ "type": "teleport", "position": "elsewhere" })
	n._route_h2c({ "type": "teleport", "position": { "chunk": [1.5, 0], "local": [1, 2, 3] } })
	Diag.quiet = was_quiet
	assert_eq(seen.size(), 1, "a malformed teleport position is dropped")
	# `/tp <peer>` by the local admin lands on the peer's exact chunk.
	seen.clear()
	n._role = NetworkingSlice.Role.HOST
	chat.handle_intent("/tp " + handle, "")
	GameBus.player_teleport.disconnect(cb)
	assert_eq(seen.size(), 1, "/tp <player> teleports the admin")
	assert_eq(seen[0]["chunk"], Vector2i(-900001, 40), "to the peer's exact chunk")
	assert_true((seen[0]["local"] as Vector3).distance_to(Vector3(31.9, 2.0, 0.1)) < 1e-3, "and local")
	n.set_transport(null)
	n.free()
	stub.free()
	chat.free()
	reg.free()

## Phase 101 — `/tp x y z` wraps X onto one lap and refuses a Z past the pole rows.
func _test_chat_tp_limits() -> void:
	var rig := _chat_rig()
	var chat: ChatSlice = rig["chat"]
	var seen: Array = []
	var cb := func(pos: Dictionary) -> void: seen.append(pos)
	GameBus.player_teleport.connect(cb)
	var posted: Array = []
	var pcb := func(_c: String, _s: String, text: String, _t: String) -> void: posted.append(text)
	GameBus.chat_posted.connect(pcb)
	var sysb_19261 := _p131_system_bridge(pcb)
	var pole_m := float(TerrainSlice.pole_chunks()) * TerrainSlice.CHUNK_METERS
	var past_z := pole_m + TerrainSlice.CHUNK_METERS
	chat.handle_intent("/tp 0 10 %s" % str(past_z), "")
	assert_eq(seen.size(), 0, "a Z past the pole is refused")
	assert_true(posted.any(func(t): return str(t).contains(str(int(pole_m)))), "and the reply names the limit")
	var lap := float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS
	chat.handle_intent("/tp %s 10 0" % str(2.5 * lap), "")
	assert_eq(seen.size(), 1, "an X several laps round still teleports")
	var at: Vector3 = WorldPos.to_scene(seen[0], Vector2i.ZERO)
	assert_true(absf(absf(at.x) - lap * 0.5) < 1.0, "to the wrapped X (the seam)")
	GameBus.chat_posted.disconnect(pcb)
	GameBus.system_message.disconnect(sysb_19261)
	GameBus.player_teleport.disconnect(cb)
	chat.free()
	rig["reg"].free()

## Phase 67 review — the `?` hotkey matches on the unicode the key produced, whatever the layout.
func _test_ui_question_mark_hotkey() -> void:
	var ui := _new_test_ui()
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.unicode = 63
	ev.keycode = KEY_SLASH
	ui._input(ev)
	assert_true(ui.is_window_open("controls"), "unicode 63 opens the controls panel")
	ui._input(ev)
	assert_false(ui.is_window_open("controls"), "and toggles it closed")
	var slash := InputEventKey.new()
	slash.pressed = true
	slash.unicode = 47
	slash.keycode = KEY_SLASH
	ui._input(slash)
	assert_false(ui.is_window_open("controls"), "a plain / (unicode 47) does not")
	ui.free()

## Phase 67 — a failed layout rename leaves no `.tmp` file behind.
func _test_ui_layout_failed_rename_cleans_tmp() -> void:
	var ui := _new_test_ui()
	# A directory at the target path makes the rename fail.
	DirAccess.make_dir_recursive_absolute(TEST_UI_LAYOUT)
	ui._layout["inventory"] = Vector2(1, 2)
	ui._save_layout()
	assert_false(FileAccess.file_exists(TEST_UI_LAYOUT + ".tmp"), "failed rename removes the temp file")
	ui.free()
	DirAccess.remove_absolute(TEST_UI_LAYOUT)

## Phase 47 — the Character window lists one row per fabric slot and its totals match.
func _test_ui_character_rows() -> void:
	var ch := CharacterSlice.new()
	add_child(ch)
	var cid := ch.create_character("TravellerHuman", Vector3.ZERO)
	ch.set_player_character(cid)
	for slot in ch.get_equipment_set(cid).keys():
		ch.clear_equipment(cid, str(slot))
	var ui := UiSlice.new()
	ui.character_slice = ch
	add_child(ui)
	var rows: Array = ui.character_rows()
	assert_eq(rows.size(), EquipmentRules.slots(GameData.ITEMS).size(), "one row per fabric slot")
	assert_eq(ui.character_stats_text(), "Defense 0", "empty set totals zero")
	var bag := InventorySlice.new()
	add_child(bag)
	ui.inventory_slice = bag
	assert_false(ui.dispatch_item_action("FerriteHelmet", "equip"), "an item the bag does not hold cannot be worn")
	assert_false(ch.get_equipment_set(cid).has("Head"), "and the avatar stays bare")
	bag.add_item("FerriteHelmet", 1)
	assert_true(ui.dispatch_item_action("FerriteHelmet", "equip"), "equip goes through apply_equipment")
	assert_eq(ch.get_equipment_set(cid).get("Head", ""), "FerriteHelmet", "the avatar wears it")
	assert_eq(ui.item_actions("FerriteHelmet", {}).filter(func(a): return a["action"] == "equip").size(), 0,
		"a worn item offers no Equip action")
	assert_true(ui.character_stats_text() != "Defense 0", "and the totals changed")
	assert_true(ui.dispatch_item_action("FerriteHelmet", "unequip"), "unequip clears the slot")
	assert_eq(ui.character_stats_text(), "Defense 0", "back to zero")
	assert_eq(ui.item_actions("FerriteHelmet", {}).filter(func(a): return a["action"] == "equip").size(), 1,
		"an unworn held item offers Equip")
	bag.free()
	ui.free()
	ch.free()

## Phase 64 — a revealed border cell next to an UNREVEALED chunk never wears that chunk's biome.
func _test_minimap_blend_respects_fog() -> void:
	var mm := Minimap.new()
	add_child(mm)
	mm._revealed = { Vector2i(0, 0): true, Vector2i(-1, 0): true }
	mm.terrain_slice = _own(BiomeStub.new())
	var n := Minimap.CELLS_PER_CHUNK
	var cell_tiles := float(TerrainSlice.CHUNK_SIZE) / n
	var west_cells := 0
	for j in n:
		for i in n:
			var got: String = mm._cell_biome(Vector2i(0, 0), i, j, "TemperateForest")
			assert_true(got != "VoidRift", "the unrevealed east/south chunks' biome is never worn (%d,%d)" % [i, j])
			if i < n - 1 - i and i <= mini(j, n - 1 - j):   # nearest border is the revealed west one
				west_cells += 1
				var expect := "DesertDunes" if BiomeBlend.wears_neighbour(i, j, cell_tiles * 0.5, cell_tiles) else "TemperateForest"
				assert_eq(got, expect, "a west-border cell wears the revealed neighbour exactly when the blend rule says so (%d,%d)" % [i, j])
	assert_true(west_cells > 0, "the revealed west neighbour has border cells to check")
	assert_false(mm._has_blend_neighbour(Vector2i(5, 5), "TemperateForest"), "no revealed neighbours: one rect")
	mm.free()

func _test_minimap_redraw_uses_cache() -> void:
	var mm := Minimap.new()
	add_child(mm)
	var stub := BiomeStub.new()
	mm.terrain_slice = stub
	mm.set_zoom(Minimap.ZOOM_DEFAULT)
	mm.set_player_pos(Vector2(16.0, 16.0))
	var first: Array = mm._view_rects(Vector2(180, 180))
	assert_true(stub.lookups > 0, "the first redraw looks biomes up")
	var after_first := stub.lookups
	var second: Array = mm._view_rects(Vector2(180, 180))
	assert_eq(stub.lookups, after_first, "the second redraw of the same view looks up zero biomes")
	assert_eq(second.size(), first.size(), "and draws the same thing")
	stub.free()
	mm.free()

## Phase 74 — a persistent biome cache: the second redraw of an unchanged view asks the terrain
## nothing.
func _test_map_past_pole_matches_far_meridian() -> void:
	var c := float(TerrainSlice.circumference_chunks())
	var pole := float(TerrainSlice.pole_chunks())
	var past: Vector3 = _MapMath.dir_of_chunk(Vector2(10.0, pole + 5.0))
	var folded: Vector3 = _MapMath.dir_of_chunk(Vector2(10.0 + c * 0.5, pole - 5.0))
	assert_true(past.distance_to(folded) < 0.0001, "a point past the pole is the mirrored point on the far meridian")
	var a := _MapMath.face_uv_xz(10.0, pole + 5.0)
	var b := _MapMath.face_uv_xz(10.0 + c * 0.5, pole - 5.0)
	assert_eq(a[0], b[0], "and lands on the same face")

func _test_minimap_walk_leaves_no_gap() -> void:
	var mm := Minimap.new()
	add_child(mm)
	var cm := TerrainSlice.CHUNK_METERS
	mm.set_player_pos(Vector2(0.5 * cm, 0.5 * cm))
	mm.set_player_pos(Vector2(0.5 * cm, 10.5 * cm))   # ten chunks in one step
	for z in range(0, 11):
		assert_true(mm.is_revealed(Vector2i(0, z)), "chunk row %d on the path is revealed" % z)
	mm.set_player_pos(Vector2(0.5 * cm, 5000.5 * cm))   # a teleport reveals nothing between
	assert_false(mm.is_revealed(Vector2i(0, 2500)), "a teleport leaves its middle unexplored")
	mm.free()

## Phase 74 — at a zoom where a sub-cell is under 2 px, a revealed chunk is a single rect.
func _test_minimap_far_zoom_one_rect() -> void:
	var mm := Minimap.new()
	add_child(mm)
	mm.terrain_slice = BiomeStub.new()
	mm.set_player_pos(Vector2(16.0, 16.0))
	mm._revealed = { Vector2i(0, 0): true, Vector2i(-1, 0): true, Vector2i(1, 0): true, Vector2i(0, 1): true }   # mixed biomes: blend would split
	mm.set_zoom(Minimap.ZOOM_MAX)
	var size := Vector2(120, 120)   # 120 / 65 = 1.8 px per chunk
	var rects: Array = mm._view_rects(size)
	assert_eq(rects.size(), mm._revealed.size(), "one rect per revealed chunk, no outlines")
	mm.set_zoom(Minimap.ZOOM_MIN)
	assert_true(mm._view_rects(Vector2(400, 400)).size() > mm._revealed.size(), "zoomed in, the blend cells and outlines draw")
	mm.terrain_slice.free()
	mm.free()

## Phase 74 — the cache is bounded and forgets everything when the seed changes.
func _test_minimap_cache_bounded_and_seeded() -> void:
	var mm := Minimap.new()
	add_child(mm)
	var stub := BiomeStub.new()
	mm.terrain_slice = stub
	mm.set_player_pos(Vector2(16.0, 16.0))
	mm._view_rects(Vector2(180, 180))
	var before := stub.lookups
	stub.world_seed = 2
	mm._view_rects(Vector2(180, 180))
	assert_true(stub.lookups > before, "a new world seed re-asks every biome")
	for i in Minimap.BIOME_CACHE_MAX + 10:
		mm._biome_cache[Vector2i(i, 999)] = "TemperateForest"
	mm._view_rects(Vector2(180, 180))
	assert_true(mm._biome_cache.size() <= Minimap.BIOME_CACHE_MAX, "the cache is pruned past its bound")
	stub.free()
	mm.free()

	# A fully revealed ZOOM_MAX view fits the cache: the second redraw asks nothing.
	var big := Minimap.new()
	add_child(big)
	var bstub := BiomeStub.new()
	big.terrain_slice = bstub
	big.set_zoom(Minimap.ZOOM_MAX)
	big.set_player_pos(Vector2(16.0, 16.0))
	for cz in range(-35, 36):
		for cx in range(-35, 36):
			big._revealed[Vector2i(cx, cz)] = true
	big._view_rects(Vector2(400, 400))
	var filled := bstub.lookups
	big._view_rects(Vector2(400, 400))
	assert_eq(bstub.lookups, filled, "a full ZOOM_MAX view does not thrash the cache")
	bstub.free()
	big.free()

	# With no terrain wired the fallback biome is not remembered.
	var bare := Minimap.new()
	add_child(bare)
	bare.set_player_pos(Vector2(16.0, 16.0))
	bare._view_rects(Vector2(180, 180))
	assert_eq(bare._biome_cache.size(), 0, "the no-terrain fallback is not cached")
	bare.free()

## Phase 74 — a saved window position at x = 10,000 ends up wholly inside an 800x600 viewport
## after the first apply plus the deferred one.
func _test_ui_layout_first_apply_fits() -> void:
	var ui := _new_test_ui()
	ui.viewport_size_override = Vector2(800, 600)
	ui._layout["inventory"] = Vector2(10000, 10000)
	ui._apply_layout()
	var panel: Control = ui._panels["inventory"]
	panel.size = Vector2(520, 380)   # the real size, known only after the first layout pass
	ui._apply_layout()
	assert_true(panel.position.x >= 0.0 and panel.position.x + panel.size.x <= 800.0, "fully inside horizontally")
	assert_true(panel.position.y >= 0.0 and panel.position.y + panel.size.y <= 600.0, "fully inside vertically")
	assert_eq(UiSlice.fit_window_position(Vector2(-50, -50), Vector2(100, 100), Vector2(800, 600)), Vector2.ZERO, "negative pulled in")
	assert_eq(UiSlice.fit_window_position(Vector2(5, 5), Vector2(900, 900), Vector2(800, 600)), Vector2.ZERO, "oversized window pins to the origin")
	ui.free()
	DirAccess.remove_absolute(TEST_UI_LAYOUT)

func _test_ui_window_toggle() -> void:
	var ui := _new_test_ui()
	assert_false(ui.any_window_open(), "no windows open initially")
	ui.toggle_window("inventory")
	assert_true(ui.is_window_open("inventory"), "inventory opens on toggle")
	assert_true(ui.any_window_open(), "any_window_open true after open")
	ui.toggle_window("technology")
	assert_true(ui.is_window_open("technology"), "technology opens independently")
	ui.toggle_window("inventory")
	assert_false(ui.is_window_open("inventory"), "inventory closes on second toggle")
	assert_true(ui.any_window_open(), "technology still open")
	ui.close_window("technology")
	assert_false(ui.any_window_open(), "all windows closed")
	ui.free()

## The crafting and technology lists sit in a ScrollContainer (no minimum height): every container
## between it and the window must expand vertically, or the list draws 0 px tall.
func _test_ui_window_lists_fill() -> void:
	var ui := _new_test_ui()
	for box in [ui._crafting_box, ui._technology_box]:
		var node: Control = (box as Control).get_parent()
		assert_true(node is ScrollContainer, "the list scrolls")
		while node != null and not (node.get_parent() is MarginContainer):
			assert_true((node.size_flags_vertical & Control.SIZE_EXPAND) != 0, "%s expands vertically" % node.get_class())
			node = node.get_parent() as Control
	ui.free()

func _test_ui_inventory_lines() -> void:
	var ui := _new_test_ui()
	var inv := InventorySlice.new()
	add_child(inv)
	ui.inventory_slice = inv
	inv.add_item("Ferrite", 5)
	inv.add_item("Thornwood", 2)
	var lines: Array = ui.inventory_lines()
	assert_true(lines.has("Ferrite ×5"), "Ferrite line present")
	assert_true(lines.has("Thornwood ×2"), "Thornwood line present")
	ui.free()
	inv.free()

func _test_ui_window_clamp() -> void:
	var vp := Vector2(1280, 720)
	var sz := Vector2(420, 300)
	assert_eq(UiSlice.clamp_window_position(Vector2(100, 100), sz, vp), Vector2(100, 100), "on-screen position unchanged")
	var far := UiSlice.clamp_window_position(Vector2(99999, 99999), sz, vp)
	assert_true(far.x < vp.x and far.y < vp.y, "far bottom-right is pulled back inside")
	assert_true(far.x + sz.x > 0.0 and far.y >= 0.0, "still reachable")
	var neg := UiSlice.clamp_window_position(Vector2(-99999, -99999), sz, vp)
	assert_true(neg.x + sz.x >= UiSlice.DRAG_VISIBLE_MARGIN, "left edge keeps a margin visible")
	assert_eq(neg.y, 0.0, "title bar never above the screen")

func _test_ui_layout_roundtrip() -> void:
	var layout := {"inventory": Vector2(10, 20), "controls": Vector2(300.5, 40)}
	var back := UiSlice.parse_layout(UiSlice.layout_to_json(layout))
	assert_eq(back, layout, "layout survives serialise/parse")
	assert_eq(UiSlice.parse_layout("not json"), {}, "garbage parses to empty")
	var junk := UiSlice.parse_layout('{"bogus":[1,2],"inventory":["a",2],"market":[5,6]}')
	assert_false(junk.has("bogus"), "unknown window key dropped")
	assert_false(junk.has("inventory"), "non-numeric entry dropped")
	assert_eq(junk.get("market"), Vector2(5, 6), "valid entry kept")
	var huge := UiSlice.parse_layout('{"inventory":[1e999,2],"market":[5,6]}')
	assert_false(huge.has("inventory"), "non-finite entry dropped")
	assert_eq(huge.get("market"), Vector2(5, 6), "finite entry beside it kept")
	var absurd := UiSlice.parse_layout('{"inventory":[1e308,2],"market":[5,-1e308],"controls":[7,8]}')
	assert_false(absurd.has("inventory"), "1e308 x dropped to default")
	assert_false(absurd.has("market"), "-1e308 y dropped to default")
	assert_eq(absurd.get("controls"), Vector2(7, 8), "sane entry beside absurd ones kept")
	var nan_text := UiSlice.parse_layout('{"inventory":[NaN,2],"market":[5,6]}')
	assert_false(nan_text.has("inventory"), "NaN entry dropped")
	# The JSON parser rejects a bare NaN token outright, so the whole file falls back to defaults.
	assert_false(nan_text.has("market"), "NaN token makes the file parse to defaults")
	# Per entry, with a real NaN (a hand-built value, as JSON cannot spell one): dropped, its neighbour kept.
	assert_eq(UiSlice.layout_entry([NAN, 2.0]), null, "a NaN x is dropped")
	assert_eq(UiSlice.layout_entry([2.0, NAN]), null, "a NaN y is dropped")
	assert_eq(UiSlice.layout_entry([INF, 2.0]), null, "an infinite entry is dropped")
	assert_eq(UiSlice.layout_entry([5, 6]), Vector2(5, 6), "a finite entry is kept")
	assert_eq(UiSlice.layout_entry("x"), null, "a non-array entry is dropped")

func _test_ui_layout_file_roundtrip() -> void:
	var ui := _new_test_ui()
	ui._layout["inventory"] = Vector2(50, 60)
	ui._save_layout()
	ui.free()
	var ui2 := UiSlice.new()
	ui2.layout_path = TEST_UI_LAYOUT
	add_child(ui2)
	assert_eq(ui2._layout.get("inventory"), Vector2(50, 60), "layout reloaded from file")
	assert_eq(ui2._panels["inventory"].position, Vector2(50, 60), "window reopens at stored position")
	assert_false(FileAccess.file_exists(TEST_UI_LAYOUT + ".tmp"), "no partial temp file remains after save")
	assert_true(UiSlice.parse_layout(FileAccess.get_file_as_string(TEST_UI_LAYOUT)).has("inventory"), "saved file is complete and parseable")
	ui2.free()
	DirAccess.remove_absolute(TEST_UI_LAYOUT)

func _test_ui_drag_state_resets() -> void:
	var ui := _new_test_ui()
	ui._drag_key = "inventory"
	ui._close_all_windows()
	assert_eq(ui._drag_key, "", "closing windows ends a drag")
	ui.free()

func _test_ui_inventory_rows() -> void:
	var ui := _new_test_ui()
	assert_eq(ui.inventory_rows().size(), 0, "no inventory -> no rows")
	var inv := InventorySlice.new()
	add_child(inv)
	ui.inventory_slice = inv
	inv.add_item("Ferrite", 5)
	inv.add_item("Thornwood", 2)
	var rows: Array = ui.inventory_rows()
	assert_eq(rows.size(), 2, "N items -> N slots")
	var r := _ui_row(rows, "Ferrite")
	assert_eq(r["quantity"], 5, "row carries quantity")
	assert_true(str(r["tooltip"]).contains("Ferrite") and str(r["tooltip"]).contains("5"), "tooltip names item and quantity")
	assert_eq(r["icon_key"], "icons/items/Ferrite.png.raw", "icon key derived from entity name")
	ui.refresh_inventory()
	assert_eq(ui._inventory_grid.get_child_count(), 2, "grid renders one slot per row")
	assert_true(ui.inventory_rows()[0]["actions"].is_empty(), "stackable material offers no actions")
	ui.free()
	inv.free()

func _test_ui_icon_key_and_intent() -> void:
	assert_eq(UiSlice.item_icon_key("FerritePick"), "icons/items/FerritePick.png.raw", "icon key")
	assert_eq(UiSlice.item_glyph("ferrite"), "F", "placeholder glyph is the initial")
	assert_eq(UiSlice.item_glyph(""), "?", "empty id glyph")
	var intent := UiSlice.action_intent("FerritePick", "repair")
	assert_eq(intent["signal"], "repair_requested", "repair maps to the existing bus intent")
	assert_eq(intent["args"], ["FerritePick"], "intent carries the item id")
	assert_true(UiSlice.action_intent("X", "nope").is_empty(), "unknown action maps to nothing")
	var ui := _new_test_ui()
	assert_false(ui.dispatch_item_action("X", "nope"), "unknown action is not dispatched")
	var got: Array = []
	var cb := func(id: String) -> void: got.append(id)
	GameBus.repair_requested.connect(cb)
	assert_true(ui.dispatch_item_action("FerritePick", "repair"), "repair dispatches")
	GameBus.repair_requested.disconnect(cb)
	assert_eq(got, ["FerritePick"], "same intent the text UI emitted")
	ui.free()

## Phase 153: no glyph fallback is hit for any item, and the craft/repair/market rows carry the key.
func _test_ui_every_item_has_icon() -> void:
	var ui := _new_test_ui()
	for id in GameData.ITEMS:
		var key := UiSlice.item_icon_key(str(id))
		assert_true(ui._load_item_icon(key) != null, "%s resolves an icon texture" % id)
	var crafting := CraftingSlice.new()
	ui.crafting_slice = crafting
	for row in ui.crafting_rows():
		assert_true(str(row["icon_key"]) != "" and ui._load_item_icon(str(row["icon_key"])) != null,
			"%s output icon resolves" % row["id"])
	crafting.free()
	ui.free()

## Phase 176: a fixture holding every holdable id (items, materials, harvest outputs) builds the
## inventory, hotbar, crafting, technology, market and trade rows without one glyph fallback, and
## every row's icon key resolves to a texture.
func _test_ui_no_glyph_for_any_holdable() -> void:
	var ui := _new_test_ui()
	var inv := InventorySlice.new()
	add_child(inv)
	inv._max_slots = 1000
	inv._max_weight = 1000000.0
	var craft := CraftingSlice.new()
	add_child(craft)
	var tech := TechnologySlice.new()
	add_child(tech)
	var market := MarketSlice.new()
	add_child(market)
	var trade := TradeSlice.new()
	add_child(trade)
	ui.inventory_slice = inv
	ui.crafting_slice = craft
	ui.technology_slice = tech
	ui.market_slice = market
	ui.trade_slice = trade
	var ids: Array = HoldablesData.ids()
	var offer := {}
	for id in ids:
		assert_true(inv.add_item(str(id), 3), "%s fits the fixture bag" % id)
		offer[str(id)] = 1
	market.set_party_inventory("player", inv)
	for id in ids:
		assert_true(market.list_item("player", str(id), 1, 2.0) != "", "%s lists on the market" % id)
	ui._active_trade_id = trade.start_trade("player", "merchant")
	trade.propose(ui._active_trade_id, "player", offer, {})
	trade.propose(ui._active_trade_id, "merchant", {}, offer)
	for id in ids:
		inv.add_item(str(id), 1)
	var before := UiSlice.glyph_calls
	var rows: Array = []
	rows.append_array(ui.inventory_rows())
	rows.append_array(ui.crafting_rows())
	rows.append_array(ui.technology_rows())
	rows.append_array(ui.market_rows())
	rows.append_array(ui._m2.trade_rows())
	ui.refresh_inventory()
	ui.refresh_crafting()
	ui.refresh_technology()
	ui.refresh_market()
	ui.refresh_trade()
	assert_eq(ui.inventory_rows().size(), ids.size(), "one inventory row per holdable id")
	assert_eq(ui.market_rows().size(), ids.size(), "one market row per holdable id")
	assert_eq(ui._m2.trade_rows().size(), ids.size() * 2, "a give row and a want row per holdable id")
	for row in rows:
		var key := str(row.get("icon_key", ""))
		var label := str(row.get("id", row.get("item_id", "")))
		if key != "":
			assert_true(ui._load_item_icon(key) != null, "%s: %s resolves a texture" % [label, key])
	for id in ids:
		assert_true(ui._load_item_icon(UiSlice.item_icon_key(str(id))) != null, "%s resolves a texture" % id)
	var techs_with_icon := 0
	for row in ui.technology_rows():
		if str(row["icon_key"]) != "":
			techs_with_icon += 1
	assert_eq(techs_with_icon, GameData.TECHNOLOGIES.size(), "every technology shows what it unlocks")
	for row in ui.crafting_rows():
		assert_true(str(row["icon_key"]) != "", "%s shows what it produces" % row["id"])
	assert_eq(UiSlice.glyph_calls, before, "no row fell back to the glyph")
	ui.free()
	inv.free()
	craft.free()
	tech.free()
	market.free()
	trade.free()

func _test_ui_controls_panel() -> void:
	var rows := UiSlice.controls_rows()
	var descs: Array = rows.map(func(r): return r["desc"])
	assert_true(descs.has("Move") and descs.has("Mine") and descs.has("Place"), "legend rows moved into the panel")
	var ui := _new_test_ui()
	assert_false(ui.is_window_open("controls"), "controls collapsed by default")
	ui.toggle_window("controls")
	assert_true(ui.is_window_open("controls"), "? opens controls")
	ui.toggle_window("controls")
	assert_false(ui.is_window_open("controls"), "? closes controls")
	ui.free()
	var p := PlayerSlice.new()
	p.render_visuals = true
	add_child(p)
	var names: Array = []
	for c in p._hud.get_children():
		names.append(str(c.name))
	assert_false(names.has("ShortcutsMenu"), "HUD paints no always-on legend")
	p.free()

func _test_hud_hotbar_pure() -> void:
	var block := _first_block()
	var gear := _first_gear_item()
	assert_eq(_HotbarScript.kind_of(block, GameData.MATERIALS, ""), "block", "a material is a block")
	assert_eq(_HotbarScript.kind_of(gear, {}, "mainHand"), "gear", "an equippable is gear")
	assert_eq(_HotbarScript.kind_of("skill:Archery", GameData.MATERIALS, ""), "skill", "a skill entry is a skill")
	assert_eq(_HotbarScript.kind_of("", GameData.MATERIALS, ""), "", "empty is neither")
	var usable := func(id: String) -> bool: return id == block or id == gear
	var cur := _blank_slots()
	var filled := _HotbarScript.fill(cur, {block: 3, gear: 1, "Junk": 5}, usable)
	assert_eq(filled.count(block) + filled.count(gear), 2, "usable held items take boxes")
	assert_false(filled.has("Junk"), "non-usable items stay off the bar")
	assert_eq(_HotbarScript.fill(filled, {block: 3, gear: 1}, usable), filled, "fill is stable: nothing reshuffles")
	var after := _HotbarScript.fill(filled, {gear: 1}, usable)
	assert_false(after.has(block), "an item no longer held leaves its box")
	assert_eq(after.find(gear), filled.find(gear), "the other boxes keep their place")
	assert_eq(_HotbarScript.fill(cur, {block: 3}, usable, {block: true}), cur, "an item taken off by hand is not re-added")
	var with_skill := cur.duplicate()
	with_skill[12] = "skill:Archery"
	assert_eq(_HotbarScript.fill(with_skill, {}, usable)[12], "skill:Archery", "a skill box survives an empty pack")
	var full := cur.duplicate()
	for i in 9:
		full[i] = "x%d" % i
	var refilled := _HotbarScript.fill(full, {block: 1}, usable)
	assert_eq(refilled[0], block, "a held usable item takes a freed bottom box")
	var row2 := cur.duplicate()
	for i in range(0, 9):
		row2[i] = "skill:S%d" % i
	assert_eq(_HotbarScript.fill(row2, {block: 1}, usable).slice(9).count(block), 0, "auto-fill never uses the player's second row")
	# place / swap
	var placed := _HotbarScript.place(cur, 3, "Ferrite")
	assert_eq(placed[3], "Ferrite", "place puts the entry in the box")
	assert_eq(_HotbarScript.place(placed, 10, "Ferrite")[3], "", "placing an entry elsewhere moves it")
	var swapped := _HotbarScript.swap(placed, 3, 4)
	assert_eq([swapped[3], swapped[4]], ["", "Ferrite"], "swap exchanges two boxes")
	# keys
	assert_eq(_HotbarScript.digit_slot(KEY_1), 0, "1 fires the first box")
	assert_eq(_HotbarScript.digit_slot(KEY_9), 8, "9 fires the ninth box")
	assert_eq(_HotbarScript.digit_slot(KEY_0), -1, "0 is not a bottom-row key")
	for k in [KEY_W, KEY_I, KEY_C, KEY_H, KEY_M, KEY_P, KEY_1, KEY_ESCAPE, KEY_SPACE]:
		assert_false(_HotbarScript.bind_allowed(k), "game key %d cannot be a shortcut" % k)
	for k in [KEY_U, KEY_J, KEY_F5, KEY_0]:
		assert_true(_HotbarScript.bind_allowed(k), "key %d may be a shortcut" % k)
	for k in [KEY_X, KEY_Z]:
		assert_false(_HotbarScript.bind_allowed(k), "harvest and carry keys %d cannot be a shortcut" % k)
	var binds := []
	for i in 18:
		binds.append(0)
	binds[11] = KEY_U
	assert_eq(_HotbarScript.slot_for_key(binds, KEY_U), 11, "a bound key finds its box")
	assert_eq(_HotbarScript.slot_for_key(binds, KEY_J), -1, "an unbound key finds none")
	# persistence
	var json := _HotbarScript.state_to_json(placed, binds, true)
	var back := _HotbarScript.parse_state(json)
	assert_eq(back["slots"], placed, "slots round-trip")
	assert_eq(back["binds"], binds, "binds round-trip")
	assert_true(back["expanded"], "expansion round-trips")
	var bad := _HotbarScript.parse_state('{"slots": [1, {}, "ok"], "binds": [0,0,0,0,0,0,0,0,0,87,"x",99999], "expanded": "yes"}')
	assert_eq(bad["slots"][2], "ok", "a good entry survives")
	assert_eq(bad["slots"][0], "", "a non-string entry is dropped")
	assert_eq(bad["binds"][9], 0, "a reserved key (W) is dropped from the file")
	assert_eq(bad["binds"][11], 0, "an absurd key is dropped")
	assert_false(bad["expanded"], "a non-bool expansion is false")
	assert_eq(_HotbarScript.parse_state("not json")["slots"], _blank_slots(), "a corrupt file starts empty")

func _test_hud_hotbar_selection() -> void:
	var ui := _new_hud_ui()
	var inv := InventorySlice.new()
	add_child(inv)
	var vox := VoxelSlice.new()
	add_child(vox)
	ui.inventory_slice = inv
	ui.voxel_slice = vox
	var block := _first_block()
	inv.add_item(block, 4)
	ui.refresh_hud()
	assert_eq(ui.hotbar.slots[0], block, "a picked-up block lands in the first box")
	assert_eq(vox.get_place_material(), block, "and, being selected, becomes the place material")
	ui.hotbar.select_slot(1)
	assert_eq(vox.get_place_material(), "", "an empty box clears the place material")
	ui.hotbar.select_slot(0)
	assert_eq(vox.get_place_material(), block, "selecting the block box re-selects it")
	ui.hotbar.select_slot(5)
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_1
	assert_true(ui.hotbar.handle_key(key), "the 1 key is used by the bar")
	assert_eq(ui.hotbar.selected, 0, "1 selects the first box")
	GameBus.block_place_material_changed.emit(block)
	assert_eq(ui.hotbar.selected, 0, "R cycling to a material on the bar keeps/selects its box")
	vox.free()
	inv.free()
	ui.free()

func _test_hud_hotbar_skills_and_binding() -> void:
	var ui := _new_hud_ui()
	var hb = ui.hotbar
	# Button i is box i (the numbered row is first), so a swapped item renders in its own box.
	hb.assign(3, "skill:Mining")
	assert_eq((hb._buttons[3] as Button).text, "Mini", "box 3 draws its own contents")
	assert_eq((hb._buttons[12] as Button).text, "", "box 12 stays empty")
	assert_true(hb._buttons[0].get_parent() == hb._row1 and hb._buttons[9].get_parent() == hb._row2, "numbered row first, extra row second")
	assert_true(hb.get_child(0) == hb._row1, "the numbered row sits above the extra row")
	hb.assign(3, "")
	hb.assign(2, "skill:Alchemy")
	var got: Array = []
	var cb := func(slot: int, skill: String) -> void: got.append([slot, skill])
	GameBus.skill_slot_triggered.connect(cb)
	var k3 := InputEventKey.new()
	k3.pressed = true
	k3.keycode = KEY_3
	assert_true(hb.handle_key(k3), "3 fires the third box")
	GameBus.skill_slot_triggered.disconnect(cb)
	assert_eq(got, [[2, "Alchemy"]], "a skill box reports the press on the bus")
	# Bottom row boxes cannot be rebound; a second-row box can.
	hb.begin_binding(1)
	assert_false(hb.is_binding(), "the bottom row is fixed to 1-9")
	hb.assign(10, "skill:Archery")
	hb.begin_binding(10)
	assert_true(hb.is_binding() and hb.expanded, "binding a second-row box expands the bar")
	var bad := InputEventKey.new()
	bad.pressed = true
	bad.keycode = KEY_W
	assert_true(hb.handle_key(bad), "a key press is swallowed while choosing a shortcut")
	assert_true(hb.is_binding(), "a game key is refused and the choice stays open")
	var z := InputEventKey.new()
	z.pressed = true
	z.keycode = KEY_U
	hb.handle_key(z)
	assert_false(hb.is_binding(), "an allowed key finishes the choice")
	assert_eq(hb.binds[10], KEY_U, "the box now has that shortcut")
	got.clear()
	GameBus.skill_slot_triggered.connect(cb)
	assert_true(hb.handle_key(z), "the chosen key fires the box")
	GameBus.skill_slot_triggered.disconnect(cb)
	assert_eq(got, [[10, "Archery"]], "second-row shortcut fires its skill")
	# A second box taking the same key steals it.
	hb.assign(11, "skill:Smithing")
	hb.begin_binding(11)
	hb.handle_key(z)
	assert_eq([hb.binds[10], hb.binds[11]], [0, KEY_U], "a key belongs to one box")
	# Persistence
	assert_true(FileAccess.file_exists(ui.hotbar.save_path), "the bar saved itself")
	var again := _HotbarScript.parse_state(FileAccess.get_file_as_string(ui.hotbar.save_path))
	assert_eq(again["slots"][2], "skill:Alchemy", "contents persisted")
	assert_eq(again["binds"][11], KEY_U, "shortcuts persisted")
	ui.free()
	DirAccess.remove_absolute(_TEST_HOTBAR_FILE)

func _test_hud_drag_and_drop() -> void:
	var ui := _new_hud_ui()
	var inv := InventorySlice.new()
	add_child(inv)
	var loot := LootSlice.new()
	add_child(loot)
	inv.loot_slice = loot
	ui.inventory_slice = inv
	var hb = ui.hotbar
	# Drop onto a box.
	assert_true(hb._can_drop(Vector2.ZERO, {"kind": "item", "id": "Ferrite"}), "an inventory item can be dropped on a box")
	assert_false(hb._can_drop(Vector2.ZERO, {"kind": "junk", "id": "x"}), "unknown payloads are refused")
	assert_false(hb._can_drop(Vector2.ZERO, "text"), "non-dictionary payloads are refused")
	hb._drop(Vector2.ZERO, {"kind": "item", "id": "Ferrite"}, 12)
	assert_eq(hb.slots[12], "Ferrite", "the item is in the box")
	hb._drop(Vector2.ZERO, {"kind": "skill", "id": "Archery"}, 13)
	assert_eq(hb.slots[13], "skill:Archery", "a skill is in the box")
	hb._drop(Vector2.ZERO, {"kind": "hotbar", "from": 12, "id": "skill:Archery"}, 13)
	assert_eq([hb.slots[12], hb.slots[13]], ["skill:Archery", "Ferrite"], "dragging a box onto another swaps them")
	# Out into the world: a box is emptied, an item lands on the ground.
	assert_eq(ui.finish_world_drop({"kind": "hotbar", "from": 13, "id": "Ferrite"}, false), "cleared", "a box dragged to the world is emptied")
	assert_eq(hb.slots[13], "", "and is empty")
	inv.add_item("Ferrite", 5)
	var seen: Array = []
	var cb := func(id: String, qty: int, _pos: Vector3) -> void: seen.append([id, qty])
	GameBus.item_drop_requested.connect(cb)
	assert_eq(ui.finish_world_drop({"kind": "item", "id": "Ferrite", "quantity": 5}, false), "dropped", "an item dragged to the world is dropped")
	assert_eq(inv.get_item_count("Ferrite"), 4, "a plain drag drops one unit")
	assert_eq(ui.finish_world_drop({"kind": "item", "id": "Ferrite", "quantity": 4}, true), "dropped", "shift drops the stack")
	assert_eq(inv.get_item_count("Ferrite"), 0, "and the whole stack leaves the pack")
	assert_eq(ui.request_drop("Ferrite", 1), "none", "an item not held is refused")
	ui.drops_enabled = false
	assert_eq(ui.request_drop("Ferrite", 1), "client", "a client cannot drop")
	GameBus.item_drop_requested.disconnect(cb)
	assert_eq(seen, [["Ferrite", 1], ["Ferrite", 4]], "the bus carried one unit, then the stack")
	assert_eq(loot.get_pickups_near(Vector3.ZERO, 100.0).size(), 2, "both landed on the ground")
	# The slice's own limits.
	inv.add_item("Ferrite", 3)
	GameBus.item_drop_requested.emit("Ferrite", 99, Vector3(1, 0, 1))
	assert_eq(inv.get_item_count("Ferrite"), 0, "a drop is capped at what is held")
	GameBus.item_drop_requested.emit("Ferrite", 1, Vector3.ZERO)
	assert_eq(inv.get_item_count("Ferrite"), 0, "dropping what is not held does nothing")
	inv.is_authoritative = false
	inv.add_item("Ferrite", 2)
	GameBus.item_drop_requested.emit("Ferrite", 1, Vector3.ZERO)
	assert_eq(inv.get_item_count("Ferrite"), 2, "a client inventory never removes goods on its own")
	loot.free()
	inv.free()
	ui.free()
	DirAccess.remove_absolute(_TEST_HOTBAR_FILE)

func _test_hud_drop_keeps_durability() -> void:
	var inv := InventorySlice.new()
	add_child(inv)
	var loot := LootSlice.new()
	add_child(loot)
	inv.loot_slice = loot
	var tool := ""
	for k in GameData.ITEMS.keys():
		if inv.is_durable(str(k)):
			tool = str(k)
			break
	if tool == "":
		loot.free()
		inv.free()
		return
	inv.add_item(tool, 1, [7.0])
	GameBus.item_drop_requested.emit(tool, 1, Vector3(5, 0, 5))
	assert_eq(inv.get_item_count(tool), 0, "the tool left the pack")
	var near := loot.get_pickups_near(Vector3(5, 0, 5), 1.0)
	assert_eq(near.size(), 1, "it lies on the ground")
	GameBus.pickup_requested.emit(str(near[0]["id"]))
	assert_eq(inv.get_item_count(tool), 1, "picked up again")
	assert_eq(inv.get_durability(tool), 7.0, "with its wear intact: dropping cannot repair a tool")
	loot.free()
	inv.free()

func _test_hud_skills_rows_and_window_keys() -> void:
	var rows := UiSlice.skills_rows({"Archery": "novice", "Smithing": "master", "Alchemy": "expert"})
	assert_eq(rows.map(func(r): return r["id"]), ["Smithing", "Alchemy", "Archery"], "skills list best tier first")
	var ui := _new_hud_ui()
	for pair in [[KEY_C, "character"], [KEY_K, "skills"], [KEY_H, "crafting"], [KEY_P, "market"], [KEY_I, "inventory"]]:
		var e := InputEventKey.new()
		e.pressed = true
		e.keycode = pair[0]
		ui._input(e)
		assert_true(ui.is_window_open(pair[1]), "key %d opens %s" % [pair[0], pair[1]])
	ui.free()

func _test_hud_window_dock() -> void:
	var seen := {}
	for e in _WindowDockScript.entries():
		assert_false(seen.has(e["letter"]), "shortcut letters are unique: %s" % e["letter"])
		seen[e["letter"]] = true
		assert_true(UiSlice.WINDOW_KEYS.has(e["key"]), "dock window exists: %s" % e["key"])
		assert_false(_HotbarScript.bind_allowed(OS.find_keycode_from_string(str(e["letter"]))) , "dock letter %s is reserved from box shortcuts" % e["letter"])
	assert_true(seen.has("M"), "M is the map window")
	assert_true(seen.has("K"), "K is Skills")
	assert_true(seen.has("C") and seen.has("H"), "C is Character, H is Crafting")
	var ui := _new_hud_ui()
	var toggled: Array = []
	ui.window_dock.window_toggled.connect(func(k: String) -> void: toggled.append(k))
	ui.window_dock.window_toggled.emit("inventory")
	assert_true(ui.is_window_open("inventory"), "clicking the I box opens the inventory")
	assert_eq(toggled, ["inventory"], "the dock reported the click")
	ui.window_dock.set_expanded(false)
	assert_false(ui.window_dock.is_expanded(), "the dock collapses")
	ui.free()
	# A collapsed dock stays collapsed on the next start.
	var again := _new_test_ui()
	assert_false(again.window_dock.is_expanded(), "the dock reopens the way it was left")
	again.window_dock.set_expanded(true)
	again.free()
	var third := _new_test_ui()
	assert_true(third.window_dock.is_expanded(), "an expanded dock persists too")
	third.free()
	DirAccess.remove_absolute(_TEST_DOCK_FILE)

func _test_map_cube_net() -> void:
	# Sphere <-> face round trip on every face, edges and corners included.
	for f in 6:
		for uv in [Vector2(0, 0), Vector2(0.5, -0.3), Vector2(-0.99, 0.99), Vector2(0.999, 0.2)]:
			var back := _MapMath.face_uv(_MapMath.dir_of_face(f, uv.x, uv.y))
			assert_eq(int(back.x), f, "face %d round-trips" % f)
			assert_true(Vector2(back.y, back.z).distance_to(uv) < 0.000001, "and so does its (u, v)")
	# Chunks <-> sphere: within 2 m (Vector3 is single precision) anywhere, next to a pole too, and the
	# poles land on the pole faces.
	var circ := TerrainSlice.circumference_chunks()
	@warning_ignore("integer_division")
	for p in [Vector2(0.5, 0.5), Vector2(1234.25, -5678.5), Vector2(circ / 2 - 3, circ / 8), Vector2(-circ / 3, -circ / 5), Vector2(-3000.5, -circ / 4 + 40)]:
		assert_true(_MapMath.chunk_of_dir(_MapMath.dir_of_chunk(p)).distance_to(p) < 0.05, "chunk %s round-trips (%s)" % [p, _MapMath.chunk_of_dir(_MapMath.dir_of_chunk(p))])
	@warning_ignore("integer_division")
	assert_eq(int(_MapMath.face_uv(_MapMath.dir_of_chunk(Vector2(77, -circ / 4))).x), 4, "the map-up pole is face 4")
	@warning_ignore("integer_division")
	assert_eq(int(_MapMath.face_uv(_MapMath.dir_of_chunk(Vector2(77, circ / 4))).x), 5, "the map-down pole is face 5")
	# Seams: stepping over any edge of any placement lands on the same point of the sphere.
	var worst := 0.0
	for f in 6:
		var pl := _MapMath.placement_of(f)
		for turn in 4:
			for t in [-0.9, -0.2, 0.0, 0.6]:
				worst = maxf(worst, _MapMath.local_dir(pl, 1.0, t).distance_to(_MapMath.local_dir(_MapMath.step(pl, 1, 0), -1.0, t)))
				worst = maxf(worst, _MapMath.local_dir(pl, -1.0, t).distance_to(_MapMath.local_dir(_MapMath.step(pl, -1, 0), 1.0, t)))
				worst = maxf(worst, _MapMath.local_dir(pl, t, 1.0).distance_to(_MapMath.local_dir(_MapMath.step(pl, 0, 1), t, -1.0)))
				worst = maxf(worst, _MapMath.local_dir(pl, t, -1.0).distance_to(_MapMath.local_dir(_MapMath.step(pl, 0, -1), t, 1.0)))
			assert_eq(_MapMath.step(_MapMath.step(pl, 1, 0), -1, 0), pl, "right then left is where it started")
			var lap := pl
			for i in 4:
				lap = _MapMath.step(lap, 1, 0)
			assert_eq(lap, pl, "four faces over is the same face the same way up")
			pl = [pl[0], pl[2], -(pl[1] as Vector3)]
	assert_true(worst < 0.000001, "every seam meets exactly (%f)" % worst)
	# The net's cross has all six faces, whichever face it is built round.
	for f in 6:
		var seen: Dictionary = {}
		for cell in _MapMath.net_cells(_MapMath.placement_of(f), -2, 2):
			seen[_MapMath.face_of(cell[1])] = true
		assert_eq(seen.size(), 6, "the net round face %d shows every face" % f)
	# Equal faces, square tiles: a tile's two sides differ by under 35% anywhere, the pole face included.
	var level := maxi(_MapMath.max_level() - 4, 0)
	var n := _MapMath.tiles_per_side(level)
	for f in [0, 4]:
		@warning_ignore("integer_division")
		for ij in [Vector2i(0, 0), Vector2i(n / 2, n / 2), Vector2i(n - 1, n / 3), Vector2i(n / 4, n - 1)]:
			var r := _MapMath.tile_rect(level, ij.x, ij.y)
			var a := _MapMath.dir_of_face(f, r.position.x, r.position.y)
			var w := a.angle_to(_MapMath.dir_of_face(f, r.end.x, r.position.y))
			var h := a.angle_to(_MapMath.dir_of_face(f, r.position.x, r.end.y))
			assert_true(maxf(w, h) / minf(w, h) < 1.35, "face %d tile %s is close to square (%f x %f)" % [f, ij, w, h])
	assert_true(_MapMath.chunks_per_cell() <= 1.0, "a finest tile is no wider than a chunk")
	# A pan that crosses faces keeps the point under it; upright turns a band face map-up.
	var pl0 := _MapMath.placement_of(0)
	var moved := _MapMath.wrap_local(pl0, 2.5, 0.3)
	assert_true(_MapMath.local_dir(moved[0], moved[1], moved[2]).distance_to(_MapMath.local_dir(_MapMath.step(pl0, 1, 0), 0.5, 0.3)) < 0.000001, "a pan over an edge keeps the point")
	var over := _MapMath.wrap_local(pl0, 0.2, 3.5)   # over the up pole onto the back face, upside down
	var up := _MapMath.upright(over[0], over[1], over[2])
	assert_eq(up[0][2], Vector3(0, 1, 0), "upright turns the band face map-up")
	assert_true(_MapMath.local_dir(up[0], up[1], up[2]).distance_to(_MapMath.local_dir(over[0], over[1], over[2])) < 0.000001, "without moving the point")
	# Double precision: a chunk-space point survives the face round trip to a millimetre, far out and by a pole.
	@warning_ignore("integer_division")
	for p in [Vector2(1234567.25, -5678.5), Vector2(-3000.5, -circ / 4 + 3)]:
		var fuv := _MapMath.face_uv_xz(p.x, p.y)
		var back := _MapMath.xz_of_face(fuv[0], fuv[1], fuv[2])
		var wrapped := fposmod(p.x + circ * 0.5, float(circ)) - circ * 0.5
		assert_true(absf(back[0] - wrapped) < 0.00003 and absf(back[1] - p.y) < 0.00003, "%s round-trips in double precision (%s)" % [p, back])
	# Globe: the inverse of the projection, the far side flagged.
	var frame := _MapMath.globe_frame(0.3, -0.2)
	for d in [Vector3(0.1, 0.2, 1.0).normalized(), Vector3(0.7, -0.5, 0.4).normalized()]:
		var q := _MapMath.globe_project(frame, d)
		assert_true(q.z > 0.0 and Vector2(q.x, q.y).length() <= 1.0 + 0.000001, "a near point is on the disc")
		assert_true(_MapMath.globe_unproject(frame, Vector2(q.x, q.y)).distance_to(d) < 0.000001, "and inverts")
	assert_true(_MapMath.globe_project(frame, -frame[0]).z < 0.0, "the far side is behind")
	assert_eq(_MapMath.globe_unproject(frame, Vector2(1.1, 0.0)), Vector3.ZERO, "off the disc is no place")
	assert_true(_MapMath.zoom_max(true) < _MapMath.zoom_max(false), "the planet fits nearer than the whole net")

func _test_map_tile_purity() -> void:
	var a := _MapTiles.new()
	a.reset(1234)
	var b := _MapTiles.new()
	b.reset(1234)
	var top := _MapMath.max_level()
	var cases := [[0, 0, 5, 3], [4, 3, 11, 4], [5, top - 2, 2, 1], [2, top, 0, 0]]
	for t in cases:
		a.request(t[0], t[1], t[2], t[3])
		b.request(t[0], t[1], t[2], t[3])
	a.pump(10)
	b.pump(10)
	var terrain := TerrainSlice.new()
	terrain.set_world_seed(1234)
	for t in cases:
		assert_eq(a.get_tile(t[0], t[1], t[2], t[3]), b.get_tile(t[0], t[1], t[2], t[3]), "a tile is identical across runs")
		var c := _MapMath.tile_center_chunk(t[0], t[1], t[2], t[3])
		assert_eq(a.get_tile(t[0], t[1], t[2], t[3]), terrain.get_biome_at_chunk(c), "the tile equals the terrain's sample at its centre")
	terrain.free()
	var k := a.key_of(0, 3, 1, 1)
	assert_true(a.key_of(1, 3, 1, 1) != k, "the face is in the key")
	a.reset(99)
	assert_true(a.key_of(0, 3, 1, 1) != k, "the seed is in the key")
	a.version += 1
	assert_true(a.key_of(0, 3, 1, 1) != k and a.key_of(0, 3, 1, 1) != _MapMath.tile_key(99, TerrainSlice.WORLDGEN_VERSION, 0, 3, 1, 1), "the version is in the key")

func _test_map_tile_cache() -> void:
	var t := _MapTiles.new()
	t.reset(7)
	t.request(0, 0, 1, 1)
	t.request(3, 5, 0, 0)
	t.request(1, 2, 3, 3)
	var got := t.take(3)
	assert_eq(got.map(func(v: Vector4i) -> int: return v.y), [5, 2, 0], "coarser levels are answered first")
	t.store(_MapTiles.compute(7, got))
	# Duplicates are not re-queued once cached or in flight.
	t.request(3, 5, 0, 0)
	assert_eq(t.pending_count(), 0, "a cached tile is not requested again")
	# Bounded: past the cap the oldest go first.
	t.reset(7)
	var first := t.key_of(0, 0, 0, 0)
	var results: Array = []
	for i in _MapTiles.CACHE_MAX + 5:
		results.append([Vector4i(0, 0, i, 0), "Ocean"])
	t.store(results)
	assert_eq(t.size(), _MapTiles.CACHE_MAX, "the cache never exceeds its cap")
	assert_false(t.has_tile(0, 0, 0, 0), "the oldest tile was dropped")
	assert_true(t.has_tile(0, 0, _MapTiles.CACHE_MAX + 4, 0), "the newest tile stays")
	assert_true(first != "", "keys are non-empty")
	# Missing tiles fall back to a coarser ancestor on the same face.
	var u := _MapTiles.new()
	u.reset(7)
	u.store([[Vector4i(2, 3, 1, 1), "Ocean"]])
	assert_eq(u.best_biome(2, 0, 8, 8), "Ocean", "a fine tile shows its coarse ancestor until it is computed")
	assert_eq(u.best_biome(1, 0, 8, 8), "", "another face's tile is not its ancestor")
	# Invalidate: old answers keep showing, but a batch taken before it must be dropped by generation.
	var g := u.generation
	u.invalidate()
	assert_true(u.generation != g, "invalidate bumps the generation")
	assert_eq(u.size(), 0, "invalidate empties the live cache")
	assert_eq(u.best_biome(2, 3, 1, 1), "Ocean", "the stale answer shows until recomputed")
	u.store([[Vector4i(2, 3, 1, 1), "Desert"]])
	assert_eq(u.best_biome(2, 3, 1, 1), "Desert", "a fresh answer wins over the stale one")
	u.reset(7)
	assert_eq(u.best_biome(2, 3, 1, 1), "", "reset drops stale answers too")

func _test_map_revealed_roundtrip() -> void:
	var path := "user://test_revealed.json"
	DirAccess.remove_absolute(path)
	var chunks: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(-5, 3), Vector2i(7, 3)]
	assert_true(_RevealedStore.save(path, chunks, 42), "saves")
	var back := _RevealedStore.load_file(path, 42)
	chunks.sort()
	back.sort()
	assert_eq(back, chunks, "the revealed set round-trips")
	var w := Diag.warn_count()
	assert_eq(_RevealedStore.load_file(path, 43), [], "a file for another seed is ignored")
	assert_eq(Diag.warn_count(), w + 1, "and warns once")
	DirAccess.remove_absolute(path)
	w = Diag.warn_count()
	assert_eq(_RevealedStore.load_file(path, 42), [], "a missing file starts empty")
	assert_eq(Diag.warn_count(), w + 1, "and warns once")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	w = Diag.warn_count()
	assert_eq(_RevealedStore.load_file(path, 42), [], "a corrupt file starts empty")
	assert_eq(Diag.warn_count(), w + 1, "and warns once")
	DirAccess.remove_absolute(path)
	# The minimap persists through its own debounced path.
	var dir := "user://test_revealed_dir"
	DirAccess.remove_absolute(_RevealedStore.path_for(dir, 5))
	var terrain := TerrainSlice.new()
	terrain.set_world_seed(5)
	var m := Minimap.new()
	m.terrain_slice = terrain
	m.revealed_dir = dir
	m.set_player_pos(Vector2(40.0, 40.0))
	m._tick_revealed_store(0.0)
	assert_false(m.is_revealed_loaded(), "a seed that has only just appeared is not trusted yet")
	m._tick_revealed_store(Minimap.SEED_SETTLE_SECONDS)
	assert_true(m.is_revealed_loaded(), "a seed that held still is loaded")
	m.set_player_pos(Vector2(40.0, 40.0))
	for i in 4:   # a new chunk every 2 s must not postpone the save forever
		m.set_player_pos(Vector2(40.0 + 400.0 * (i + 1), 40.0))
		m._tick_revealed_store(2.0)
	m.finish_save()
	assert_true(FileAccess.file_exists(_RevealedStore.path_for(dir, 5)), "steady exploring still reaches the debounced save")
	m.save_revealed(true)
	var m2 := Minimap.new()
	m2.terrain_slice = terrain
	m2.revealed_dir = dir
	m2._tick_revealed_store(0.0)
	m2._tick_revealed_store(Minimap.SEED_SETTLE_SECONDS)
	assert_eq(m2.get_revealed_chunks().size(), m.get_revealed_chunks().size(), "a relog restores the explored set")
	assert_true(m2.is_revealed(Vector2i(1, 1)), "the player's chunk is explored after the relog")
	# Saving before the seed's file was loaded must not overwrite it; the revision moves with the set.
	var m3 := Minimap.new()
	m3.revealed_dir = dir
	m3.save_revealed(true)
	assert_false(FileAccess.file_exists(_RevealedStore.path_for(dir, 0)), "no seed-0 file appears")
	var rev: int = m.revealed_revision()
	m.set_player_pos(Vector2(4000.0, 4000.0))
	assert_true(m.revealed_revision() != rev, "revealing new chunks changes the revision")
	m3.free()
	m.free()
	m2.free()
	terrain.free()
	DirAccess.remove_absolute(_RevealedStore.path_for(dir, 5))

func _test_map_revealed_cap_and_size() -> void:
	var d: Dictionary = {}
	for i in 10:
		d[Vector2i(i, 0)] = true
	_RevealedStore.cap(d, 4)
	assert_eq(d.keys(), [Vector2i(6, 0), Vector2i(7, 0), Vector2i(8, 0), Vector2i(9, 0)], "the cap drops the oldest chunks")
	var chunks: Array = []
	for z in 100:
		for x in 100:
			chunks.append(Vector2i(x - 50, z - 50))
	var text := _RevealedStore.encode(chunks, 1)
	assert_true(text.length() < 20000, "10,000 contiguous chunks encode small (%d bytes)" % text.length())
	assert_eq(_RevealedStore.decode(text, 1).size(), 10000, "and decode back whole")

func _test_map_home_clamp() -> void:
	var inside := _MapMath.clamp_home(Vector2(30, -20), Vector2(100, 80), 500.0)
	assert_true(inside["inside"], "inside the map")
	assert_eq(inside["pos"], Vector2(30, -20), "the point itself")
	var out := _MapMath.clamp_home(Vector2(300, 150), Vector2(100, 80), 1234.0)
	assert_false(out["inside"], "outside the map")
	var pos: Vector2 = out["pos"]
	assert_true(absf(pos.x) <= 100.0 + 0.0001 and absf(pos.y) <= 80.0 + 0.0001, "clamped to the rect")
	assert_true(absf(pos.x) >= 100.0 - 0.0001 or absf(pos.y) >= 80.0 - 0.0001, "on the edge")
	assert_true(absf(pos.normalized().angle() - Vector2(300, 150).angle()) < 0.000001, "on the line toward it")
	assert_eq(out["distance"], 1234.0, "with the distance")
	# Exact far from the origin: 1,500,000 chunks away, a 10 m offset stays 10 m.
	var far := 1500000
	var d := _MapMath.delta_m(Vector2i(far, far), Vector2(1.5, 2.5), Vector2i(far + 3, far - 2), Vector2(11.5, 2.5))
	assert_eq(d, Vector2(3.0 * TerrainSlice.CHUNK_METERS + 10.0, -2.0 * TerrainSlice.CHUNK_METERS), "exact at 1,500,000 chunks")
	var c := _MapMath.clamp_home(d, Vector2(40, 40), d.length())
	assert_eq(c["distance"], d.length(), "the distance is carried exactly")

## Phase 117 — 50,000 chunks save (from a snapshot, on a worker) and reload in age order through the
## Vector2i API, and the oldest-first cap survives the round trip.
func _test_map_revealed_scale() -> void:
	var path := "user://test_revealed_scale.json"
	DirAccess.remove_absolute(path)
	var live: Dictionary = {}
	for i in 50000:
		live[Vector2i(1500000 + (i * 7) % 4000, (i * 13) % 900 - 450)] = true
	var n: int = live.size()
	assert_true(n > 20000, "the fixture has many distinct chunks (%d)" % n)
	var snap := _RevealedStore.snapshot(live)
	live.clear()   # the live set moving on does not touch the snapshot
	var th := Thread.new()
	th.start(_RevealedStore.save.bind(path, snap, 9, []))
	assert_true(th.wait_to_finish(), "the worker writes the snapshot")
	var back := _RevealedStore.load_file(path, 9)
	assert_eq(back.size(), n, "every chunk reloads")
	assert_eq(back, snap, "in the order it was revealed (oldest first)")
	assert_true(back[0] is Vector2i, "as Vector2i, no string keys")
	# Reload into a dictionary and cap it: the oldest chunks go, the newest stay.
	var d: Dictionary = {}
	for c in back:
		d[c] = true
	_RevealedStore.cap(d, 1000)
	assert_eq(d.size(), 1000, "the cap holds")
	assert_eq(d.keys(), back.slice(n - 1000), "and kept the newest 1000 across the reload")
	# The Phase 111 row-sorted form still loads.
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string('{"seed": 9, "rows": {"3": [0, 2, 10, 1]}}')
	f.close()
	assert_eq(_RevealedStore.load_file(path, 9), [Vector2i(0, 3), Vector2i(1, 3), Vector2i(10, 3)], "an older file still loads")
	DirAccess.remove_absolute(path)

## Phase 117 — waypoints keep their exact {chunk, local}, the cap refuses the extra one, and another
## seed's file carries none.
func _test_map_waypoints() -> void:
	var dir := "user://test_waypoints_dir"
	var path := _RevealedStore.path_for(dir, 21)
	DirAccess.remove_absolute(path)
	var terrain := TerrainSlice.new()
	terrain.set_world_seed(21)
	var m := Minimap.new()
	m.terrain_slice = terrain
	m.revealed_dir = dir
	m._tick_revealed_store(0.0)
	m._tick_revealed_store(Minimap.SEED_SETTLE_SECONDS)
	@warning_ignore("integer_division")
	assert_true(m.add_waypoint("Camp", _wp_pos(TerrainSlice.circumference_chunks() / 2 - 1, -7)), "a waypoint is added")
	assert_false(m.add_waypoint("Bad", {}), "a position without chunk and local is refused")
	assert_true(m.add_waypoint("  ", _wp_pos(3, 4)), "an empty name is allowed")
	assert_eq(m.get_waypoints()[1]["name"], "Waypoint 2", "and defaults to a numbered one")
	while m.get_waypoints().size() < _RevealedStore.MAX_WAYPOINTS:
		assert_true(m.add_waypoint("w", _wp_pos(1, 1)), "up to the cap")
	assert_false(m.add_waypoint("extra", _wp_pos(1, 1)), "the cap refuses the extra one")
	m.save_revealed(true)
	var m2 := Minimap.new()
	m2.terrain_slice = terrain
	m2.revealed_dir = dir
	m2._tick_revealed_store(0.0)
	m2._tick_revealed_store(Minimap.SEED_SETTLE_SECONDS)
	assert_eq(m2.get_waypoints().size(), _RevealedStore.MAX_WAYPOINTS, "every waypoint reloads")
	assert_eq(m2.get_waypoints()[0]["name"], "Camp", "with its name")
	@warning_ignore("integer_division")
	assert_eq(m2.get_waypoints()[0]["pos"], WorldPos.normalized(_wp_pos(TerrainSlice.circumference_chunks() / 2 - 1, -7)), "and its exact chunk and local")
	assert_eq(_RevealedStore.load_all(path, 22)["waypoints"], [], "a file for another seed carries no waypoints")
	m2.set_player_pos(Vector2(40.0, 40.0))
	var marker := m2.waypoint_marker(0, Vector2(100, 100))
	assert_false(marker.is_empty(), "a waypoint has a minimap marker")
	m.free()
	m2.free()
	terrain.free()
	DirAccess.remove_absolute(path)

## Phase 117 — a loaded chunk outside the world is dropped; a late seed change waits for the settle
## and writes nothing under the seed that went away.
func _test_map_minimap_load_and_seed() -> void:
	var dir := "user://test_revealed_seed_dir"
	var path_a := _RevealedStore.path_for(dir, 31)
	var path_b := _RevealedStore.path_for(dir, 32)
	DirAccess.remove_absolute(path_a)
	DirAccess.remove_absolute(path_b)
	var pole := TerrainSlice.pole_chunks() + TerrainSlice.FOLD_MARGIN_CHUNKS
	assert_true(_RevealedStore.save(path_a, [Vector2i(0, 0), Vector2i(5, pole + 50), Vector2i(TerrainSlice.circumference_chunks() + 2, 1)], 31), "a file with an off-world chunk")
	var terrain := TerrainSlice.new()
	terrain.set_world_seed(31)
	var m := Minimap.new()
	m.terrain_slice = terrain
	m.revealed_dir = dir
	m._tick_revealed_store(0.0)
	m._tick_revealed_store(Minimap.SEED_SETTLE_SECONDS)
	assert_true(m.is_revealed(Vector2i(0, 0)), "an in-world chunk loads")
	assert_false(m.is_revealed(Vector2i(5, pole + 50)), "a chunk past the poles is dropped")
	assert_true(m.is_revealed(Vector2i(2, 1)), "a chunk past the seam is wrapped onto the planet")
	# A late seed change: not acted on before it holds still, never written under the old seed.
	m.set_player_pos(Vector2(900.0, 900.0))
	terrain.set_world_seed(32)
	m._tick_revealed_store(0.1)
	assert_eq(m.is_revealed_loaded(), true, "still loaded for the old seed")
	assert_false(m.is_revealed(Vector2i(2, 2)) and not m.is_revealed(Vector2i(0, 0)), "the set is untouched while the new seed settles")
	m._tick_revealed_store(Minimap.SEED_SETTLE_SECONDS)
	assert_false(m.is_revealed(Vector2i(0, 0)), "after the settle the old world's set is gone")
	assert_false(FileAccess.file_exists(path_b), "and no file was written for the new seed from the old set")
	m.finish_save()
	m.free()
	terrain.free()
	DirAccess.remove_absolute(path_a)
	DirAccess.remove_absolute(path_b)

## Phase 117 — the stale list is capped (oldest dropped), and a pan keeps the queued tiles.
func _test_map_tiles_stale_and_queue() -> void:
	var t := _MapTiles.new()
	t.reset(3)
	for i in _MapTiles.STALE_MAX + 500:
		t._cache["k%d" % i] = "TemperateForest"
	t.invalidate()
	assert_eq(t.stale_count(), _MapTiles.STALE_MAX, "the stale list is at its cap")
	assert_false(t._stale.has("k0"), "and the oldest tiles went first")
	assert_true(t._stale.has("k%d" % (_MapTiles.STALE_MAX + 499)), "the newest stayed")
	invalidate_twice_check(t)
	var u := _MapTiles.new()
	u.reset(3)
	for x in 6:
		u.request(0, 2, x, 0)
	u.request(1, 2, 3, 0)
	u.retain_pending({ Vector2i(0, 2): Rect2i(2, 0, 4, 1) })
	assert_eq(u.pending_count(), 4, "a pan drops only the tiles that left the view, and faces out of view")
	u.request(0, 2, 6, 0)
	assert_eq(u.pending_count(), 5, "and adds the one that came into view")
	u.retain_pending({ Vector2i(0, 1): Rect2i(0, 0, 9, 9) })
	assert_eq(u.pending_count(), 0, "a level out of view is dropped whole")

## The Map window: zoom clamped on a small world, no redraw for an unchanged player pixel, the home
## marker's great-circle distance, fog that is never sampled, hover coordinates and waypoint delete.
func _test_map_window_phase117() -> void:
	var saved_circ: int = TerrainSlice._circumference_cache
	TerrainSlice._circumference_cache = 64
	var small := _MapWindow.new()
	for on in [false, true]:
		small.set_planet(on)
		assert_true(small.get_zoom() >= _MapMath.ZOOM_MIN and small.get_zoom() <= _MapMath.zoom_max(on), "_zoom starts in range on a small world")
	small.free()
	TerrainSlice._circumference_cache = saved_circ
	var w := _MapWindow.new()
	w.size = Vector2(500, 400)
	var stub := GDScript.new()
	stub.source_code = "extends Node\nvar respawn_world_pos := {}\nvar pos := Vector3.ZERO\nfunc get_position() -> Vector3:\n\treturn pos\n"
	stub.reload()
	var player: Node = Node.new()
	player.set_script(stub)
	w.player_slice = player
	player.pos = Vector3(100.0, 2.0, 100.0)
	w.set_center(Vector2(1.5, 1.5))
	var sig := w.redraw_signature()
	player.pos = Vector3(100.05, 2.0, 100.0)
	assert_eq(w.redraw_signature(), sig, "a sub-pixel move triggers no redraw")
	player.pos = Vector3(100.0 + 4000.0, 2.0, 100.0)
	assert_true(w.redraw_signature() != sig, "a move of many pixels does")
	# Home far away: the great-circle distance within 0.1%, flat or folded.
	var circ := TerrainSlice.circumference_chunks()
	@warning_ignore("integer_division")
	var home := { "chunk": Vector2i(circ / 4 + 100, 80000), "local": Vector3(10.0, 0.0, 10.0) }
	player.respawn_world_pos = home
	var lon := (float(home["chunk"].x) + 10.0 / TerrainSlice.CHUNK_METERS) / float(circ) * TAU
	var lat := -(float(home["chunk"].y) + 10.0 / TerrainSlice.CHUNK_METERS) / (float(circ) * 0.25) * (PI * 0.5)
	var expected := acos(clampf(cos(lat) * cos(lon), -1.0, 1.0)) * float(circ) * TerrainSlice.CHUNK_METERS / TAU
	for on in [false, true]:
		w.set_planet(on)
		w.set_zoom(_MapMath.zoom_max(on))
		w.set_center(Vector2.ZERO)
		var m := w.home_marker(Vector2(500, 400))
		assert_true(absf(m["distance"] - expected) / expected < 0.001, "home distance %f matches the great circle %f" % [m["distance"], expected])
	# A pixel maps back to the exact place under it, flat and folded, a pole face included.
	for on in [false, true]:
		w.set_planet(on)
		w.set_zoom(_MapMath.ZOOM_MIN)
		assert_eq(w.get_zoom(), _MapMath.zoom_min(on, w._view_px()), "the closest zoom: street level flat, a bit out on the globe")
		@warning_ignore("integer_division")
		for c in [Vector2(1000.0, -20.0), Vector2(-3000.5, -circ / 4 + 40), Vector2(50.0, circ / 5)]:
			w.set_center(c)
			var at := w.world_pos_at(Vector2.ZERO)
			assert_false(at.is_empty(), "the pixel under the centre is a place")
			assert_true(absf(float(at["chunk"].x) - floorf(c.x)) <= 1.0 and absf(float(at["chunk"].y) - floorf(c.y)) <= 1.0, "and it is the centre's chunk (%s at %s)" % [at["chunk"], c])
			var off := Vector2(37.0, -21.0)
			var pl := w.place_at(off)
			var xz := _MapMath.xz_of_face(pl[0], pl[1], pl[2])
			var s := w.screen_of_xz(xz[0], xz[1])
			assert_true(s["visible"] and (s["pos"] as Vector2).distance_to(off) < 0.05, "a pixel and its place agree both ways (%s)" % s["pos"])
	w.set_planet(true)
	w.set_zoom(_MapMath.zoom_max(true))
	assert_true(w.world_pos_at(Vector2(249.0, 0.0)).is_empty(), "past the globe's rim is no place")
	w.set_planet(false)
	w.set_zoom(_MapMath.zoom_max(false))
	w.set_center(Vector2.ZERO)
	assert_true(w.world_pos_at(Vector2(240.0, 190.0)).is_empty(), "the net's empty corner is no place")
	# Hover: the same latitude and longitude /where prints.
	w.set_zoom(_MapMath.ZOOM_MIN)
	w.set_center(Vector2(200.25, -300.75))
	var p := w.get_center()
	assert_eq(w.hover_text(Vector2.ZERO), "X %d  Y %d" % [roundi(p.x * TerrainSlice.CHUNK_METERS), roundi(p.y * TerrainSlice.CHUNK_METERS)], "hover shows world metres")
	# The numbers are the ones /tp takes: they land on the chunk under the cursor.
	var hover_at := w.world_pos_at(Vector2(80.0, -45.0))
	var nums := w.hover_text(Vector2(80.0, -45.0)).split(" ", false)
	var tp := ChatCommands.parse_position([nums[1], "0", nums[3]])
	assert_true(tp["ok"], "/tp accepts the hover numbers")
	assert_true(absi(tp["pos"]["chunk"].x - hover_at["chunk"].x) <= 1 and absi(tp["pos"]["chunk"].y - hover_at["chunk"].y) <= 1, "and lands where the cursor was")
	w.set_center(Vector2(-5000.0, 700.0))
	assert_true(w.hover_text(Vector2.ZERO).begins_with("X -160000"), "west is a negative X (%s)" % w.hover_text(Vector2.ZERO))
	w.set_center(Vector2(200.25, -300.75))
	# The globe turns pole-up: dragging over a cube corner never flips the picture round.
	w.set_planet(true)
	w.set_zoom(_MapMath.zoom_max(true) - 1.0)
	var corner_lon := PI * 0.25
	var corner_lat := atan(1.0 / sqrt(2.0))
	var rad := w._radius_px()
	var start_lat := corner_lat - 100.0 * 1.5 / rad   # 100 steps short of the corner, on the line through it
	var start_lon := corner_lon - 100.0 * 1.5 / (rad * cos(corner_lat))
	w.set_center(Vector2(start_lon / TAU * circ, -start_lat / (PI * 0.5) * circ * 0.25))
	var prev_up: Vector3 = w._frame()[2]
	var worst_turn := 0.0
	for i in 200:
		w.pan(Vector2(-1.5, 1.5))
		var up: Vector3 = w._frame()[2]
		worst_turn = maxf(worst_turn, prev_up.angle_to(up))
		prev_up = up
	assert_true(worst_turn < 0.05, "the globe's up turns smoothly across a cube corner (%f rad)" % worst_turn)
	w.set_planet(false)
	# Fog: only explored tiles are revealed and requested; the rest are never sampled.
	var terrain := TerrainSlice.new()
	terrain.set_world_seed(5)
	var mm := Minimap.new()
	mm.terrain_slice = terrain
	w.minimap = mm
	w.terrain_slice = terrain
	w._refresh_records()
	mm.set_player_pos(Vector2(200.25, -300.75) * TerrainSlice.CHUNK_METERS)
	var level := 0
	var fog := w._revealed_set(level)
	var fuv := _MapMath.face_uv(_MapMath.dir_of_chunk(Vector2(200.5, -300.5)))
	var here := _MapMath.tile_index(fuv.y, fuv.z, level)
	assert_true(w.tile_revealed(fog, int(fuv.x), level, here.x, here.y), "the explored chunk's tile is revealed")
	@warning_ignore("integer_division")
	var far := _MapMath.face_uv(_MapMath.dir_of_chunk(Vector2(circ / 2 - 500, 9000)))
	var far_t := _MapMath.tile_index(far.y, far.z, level)
	assert_false(w.tile_revealed(fog, int(far.x), level, far_t.x, far_t.y), "a far tile is fog")
	var f := int(fuv.x)
	var r := Rect2i(here - Vector2i(40, 40), Vector2i(81, 81))
	w._request([f], [r], level, fog)
	var revealed := 0
	for j in range(r.position.y, r.end.y):
		for i in range(r.position.x, r.end.x):
			if w.tile_revealed(fog, f, level, i, j):
				revealed += 1
	assert_true(revealed > 0 and revealed < r.get_area(), "some of the view is explored (%d of %d)" % [revealed, r.get_area()])
	var taken := w.tiles.take(100000)
	var fine := 0
	for t in taken:
		if t.y == level:
			fine += 1
			assert_true(w.tile_revealed(fog, t.x, t.y, t.z, t.w), "only explored tiles are sampled")
	assert_eq(fine, revealed, "every explored tile in view is requested")
	# Waypoints: right-click adds one; right-click on it deletes it.
	w.set_center(Vector2(200.25, -300.75))
	var before: int = mm.get_waypoints().size()
	w.right_click(Vector2(60.0, 30.0))
	assert_eq(mm.get_waypoints().size(), before + 1, "right-click on empty ground adds a waypoint")
	assert_eq(w.waypoint_at(Vector2(62.0, 31.0)), before, "the cursor near it picks it")
	assert_true(w.hover_text(Vector2(60.0, 30.0)).contains("right-click to delete"), "hover says how to delete it")
	w.right_click(Vector2(61.0, 29.0))
	assert_eq(mm.get_waypoints().size(), before, "right-click on a waypoint deletes it")
	assert_eq(w.waypoint_at(Vector2(60.0, 30.0)), -1, "and it is gone")
	mm.free()
	terrain.free()
	player.free()
	w.free()

## Phase 117 — the HUD toast queue.
func _test_ui_toasts() -> void:
	var ui := _new_test_ui()
	assert_true(ui.push_toast("one"), "a toast is shown")
	assert_eq(ui.toast_shown(), "one", "at once")
	assert_false(ui.push_toast("one"), "the same text on screen is not added again")
	assert_true(ui.push_toast("two"), "another queues")
	assert_false(ui.push_toast("two"), "and is not queued twice")
	for i in UiSlice.TOAST_MAX + 5:
		ui.push_toast("n%d" % i)
	assert_eq(ui.toast_queue().size(), UiSlice.TOAST_MAX, "the queue is bounded")
	assert_false(ui.toast_queue().has("two"), "the oldest queued toast was dropped")
	ui.advance_toasts(UiSlice.TOAST_SECONDS + 0.1)
	assert_true(ui.toast_shown() != "one", "the next one is shown")
	ui.free()

## Phase 117 — game_root raises the version mismatch once; the UI turns it into exactly one toast. A
## pre-stamp record raises nothing.
func _test_ui_worldgen_toast() -> void:
	var ui := _new_test_ui()
	var root_script: GDScript = load("res://src/core/game_root.gd")
	var gr: Node = root_script.new()
	gr._loaded_world = { "seed": 7 }
	gr._persistence_wiring.note_worldgen_version()
	assert_eq(ui.toast_shown(), "", "a pre-stamp save produces no toast")
	gr._loaded_world = { "seed": 7, "worldgenVersion": TerrainSlice.WORLDGEN_VERSION - 1,
		"worldgenFingerprint": TerrainSlice.worldgen_fingerprint() }
	gr._persistence_wiring.note_worldgen_version()
	assert_true(ui.toast_shown().contains("generator v%d" % (TerrainSlice.WORLDGEN_VERSION - 1)), "a mismatch shows the toast")
	assert_eq(ui.toast_queue().size(), 0, "exactly one")
	ui.push_toast("World saved with generator v%d, running v%d: terrain may not match saved edits." % [TerrainSlice.WORLDGEN_VERSION - 1, TerrainSlice.WORLDGEN_VERSION])
	assert_eq(ui.toast_queue().size(), 0, "the same notice is never queued twice")
	gr.free()
	ui.free()

func _test_map_window_key() -> void:
	var ui := _new_hud_ui()
	var e := InputEventKey.new()
	e.pressed = true
	e.keycode = KEY_M
	ui._input(e)
	assert_true(ui.is_window_open("map"), "M opens the Map window")
	ui._input(e)
	assert_false(ui.is_window_open("map"), "M closes it again")
	ui.window_dock.window_toggled.emit("map")
	assert_true(ui.is_window_open("map"), "the dock's M box opens it")
	var users := 0
	for entry in _WindowDockScript.entries():
		if entry["letter"] == "M":
			users += 1
	assert_eq(users, 1, "no other window uses M")
	ui.free()

## Waypoints on the horizon: one ahead projects onto the screen at the horizon toward it, one behind
## waits on the edge it is nearer to, and the minimap gives the offset the short way round.
func _test_map_waypoint_horizon() -> void:
	var Horizon: GDScript = load("res://src/ui/waypoint_horizon.gd")
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = Vector3(0.0, 10.0, 0.0)   # looking down -Z, level
	var view := cam.get_viewport().get_visible_rect().size
	var ahead: Dictionary = Horizon.place(cam, Vector2(0.0, -400.0), view)
	assert_false(ahead["behind"], "a waypoint ahead is in front")
	var p: Vector2 = ahead["pos"]
	assert_true(absf(p.x - view.x * 0.5) < 1.0, "straight ahead is mid-screen (%s of %s)" % [p, view])
	assert_true(p.y > Horizon.EDGE_PX and p.y < view.y * 0.5 + 1.0, "at the horizon, not the ground underfoot")
	var right: Dictionary = Horizon.place(cam, Vector2(300.0, -400.0), view)
	assert_true((right["pos"] as Vector2).x > p.x, "one ahead-right is right of centre")
	var back_left: Dictionary = Horizon.place(cam, Vector2(-50.0, 400.0), view)
	assert_true(back_left["behind"] and (back_left["pos"] as Vector2).x == Horizon.EDGE_PX, "one behind-left waits on the left edge")
	var back_right: Dictionary = Horizon.place(cam, Vector2(50.0, 400.0), view)
	assert_true(back_right["behind"] and (back_right["pos"] as Vector2).x == view.x - Horizon.EDGE_PX, "one behind-right on the right edge")
	assert_true(Horizon.place(cam, Vector2.ZERO, view).is_empty(), "one underfoot has no direction")
	cam.free()
	# The minimap's offset: metres, the short way round the seam.
	var m := Minimap.new()
	@warning_ignore("integer_division")
	var half := TerrainSlice.circumference_chunks() / 2
	m.set_player_pos(Vector2((half - 2) * TerrainSlice.CHUNK_METERS, 40.0))   # two chunks west of the seam
	m.add_waypoint("Seam", { "chunk": Vector2i(-half + 1, 1), "local": Vector3(0, 0, 8.0) })   # one chunk past it
	var d := m.waypoint_offset_m(0)
	assert_true(absf(d.x - 3.0 * TerrainSlice.CHUNK_METERS) < 0.001 and absf(d.y) < 0.001, "a waypoint over the seam is the short way, east (%s)" % d)
	assert_eq(m.waypoint_offset_m(5), Vector2(INF, INF), "no such waypoint")
	m.free()

func _test_ui_crafting_rows_tech_gate() -> void:
	var ui := _new_test_ui()
	var inv := InventorySlice.new()
	add_child(inv)
	var tech := TechnologySlice.new()
	add_child(tech)
	var craft := CraftingSlice.new()
	add_child(craft)
	ui.inventory_slice = inv
	ui.crafting_slice = craft
	ui.technology_slice = tech
	craft.inventory_slice = inv
	craft.technology_slice = tech
	tech.inventory_slice = inv
	craft.set_skill("Smithing", "novice")
	inv.add_item("Ferrite", 6)   # 4 for research + 2 for the craft
	var locked := _ui_row(ui.crafting_rows(), "RecipeFerriteIngot")
	assert_false(bool(locked["can_craft"]), "crafting blocked while tech locked")
	assert_true(str(locked["reason"]).begins_with("technology_locked"), "reason is technology_locked")
	assert_true(tech.begin_research("TechBasicSmithing")["success"], "begin research succeeds")
	assert_true(tech.complete_research("TechBasicSmithing")["success"], "complete research succeeds")
	var unlocked := _ui_row(ui.crafting_rows(), "RecipeFerriteIngot")
	assert_true(bool(unlocked["can_craft"]), "crafting allowed after unlock")
	ui.free()
	craft.free()
	tech.free()
	inv.free()

func _test_ui_technology_rows_status() -> void:
	var ui := _new_test_ui()
	var tech := TechnologySlice.new()
	add_child(tech)
	var inv := InventorySlice.new()
	add_child(inv)
	ui.technology_slice = tech
	ui.inventory_slice = inv
	tech.inventory_slice = inv
	var root := _ui_row(ui.technology_rows(), "TechBasicSmithing")
	assert_eq(root["status"], "locked", "root tech starts locked")
	assert_true(bool(root["can_research"]), "root tech researchable (no prereqs)")
	var gated := _ui_row(ui.technology_rows(), "TechMasterForge")
	assert_false(bool(gated["can_research"]), "TechMasterForge gated by prereq")
	assert_true((gated["requires"] as Array).has("TechBasicSmithing"), "requires lists TechBasicSmithing")
	ui.free()
	tech.free()
	inv.free()

# ---------------------------------------------------------------------------
# CreatureAI tests (Phase 15)
# ---------------------------------------------------------------------------

## Phase 42 review — the loading screen's own visibility contract, asserted by the suite
## instead of by hand. It is presentation (a CanvasLayer), so nothing else in the run
## observes it: before this test the only evidence that it ever appeared was a `visible`
## flag read off a live boot.
func _test_loading_screen_visibility() -> void:
	var screen = load("res://src/ui/loading_screen.gd").new()
	add_child(screen)
	var emitted: Array = []
	var cb := func(frozen: bool): emitted.append(frozen)
	GameBus.world_input_frozen.connect(cb)
	assert_false(screen.is_active(), "a fresh loading screen is down")
	assert_false(screen.visible, "and hidden")
	screen.begin()
	assert_true(screen.is_active(), "begin shows it")
	assert_true(screen.visible, "and makes it visible")
	assert_eq(emitted.size(), 1, "and emits the freeze")
	assert_true(bool(emitted[0]), "freezing world input")
	screen.set_progress(0.5)
	assert_eq(screen._bar.value, 50.0, "the bar tracks the progress fraction")
	screen.finish()
	assert_false(screen.is_active(), "finish puts it away")
	assert_false(screen.visible, "and hides it")
	assert_eq(emitted.size(), 2, "and emits the thaw")
	assert_false(bool(emitted[1]), "releasing world input")
	GameBus.world_input_frozen.disconnect(cb)
	screen.free()

# ---------------------------------------------------------------------------
# Phase 43 — natural resource distribution
# ---------------------------------------------------------------------------

## Phase 63 — the one chat command is spelled in one place.
func _test_chat_command_constant() -> void:
	assert_true(ChatCommands.is_command(ChatCommands.WHERE), "the constant is a command")
	assert_true(ChatCommands.is_command("  /WHERE "), "case and padding are ignored")
	assert_eq(ChatCommands.run("/where", Vector3.ZERO), TerrainSlice.where_text(Vector3.ZERO), "run answers it")
	assert_eq(ChatCommands.run("/nope", Vector3.ZERO), "", "anything else answers nothing")

func _test_ui_retire_prunes_amortised() -> void:
	var ui := _new_test_ui()
	var controls: Array = []
	for i in 1000:
		var c := Control.new()
		controls.append(c)
		ui._retire(c)
	assert_true(ui.retired_prunes <= 11, "retiring 1,000 controls prunes at most 11 times (%d)" % ui.retired_prunes)
	assert_true(ui.retired_prunes >= 1, "and the prune does run")
	ui.free()
	var leaked := 0
	for c in controls:
		if is_instance_valid(c):
			leaked += 1
	assert_eq(leaked, 0, "freeing the slice frees every retired control still valid")

func _test_p131_catalog_keys() -> void:
	var parsed := I18nScript.parse_csv(I18nScript.CATALOG_PATH)
	var locales: Array = parsed["locales"]
	assert_true(locales.has("en") and locales.has("pt_BR"), "the catalog has en and pt_BR columns")
	assert_true(int(parsed["rows"]) > 100, "the catalog is not empty")
	assert_eq(parsed["dupes"], [], "no key appears twice")
	assert_eq(parsed["empty"], [], "no empty cell in any locale")
	var en: Dictionary = parsed["catalog"]["en"]
	for loc in locales:
		var cat: Dictionary = parsed["catalog"][loc]
		assert_eq(cat.keys().size(), en.keys().size(), "%s has the same number of keys as en" % loc)
		for key in en:
			assert_true(cat.has(key), "%s has key %s" % [loc, key])
			if cat.has(key):
				assert_eq(_p131_placeholders(cat[key]), _p131_placeholders(en[key]), "%s: %s keeps the same placeholders" % [loc, key])
	# Every catalog key a script names with a literal exists.
	for path in _p131_scripts():
		var src := FileAccess.get_file_as_string(path)
		var rx := RegEx.create_from_string("I18n\\.t\\(\"([a-z0-9_]+(?:\\.[a-z0-9_]+)+)\"")
		for m in rx.search_all(src):
			assert_true(en.has(m.get_string(1)), "%s names a known key: %s" % [path, m.get_string(1)])

func _test_p131_literal_audit() -> void:
	var allow: Dictionary = {}
	for line in FileAccess.get_file_as_string("res://locale/audit_allow.txt").split("\n"):
		if line.strip_edges() == "" or line.begins_with("#"):
			continue
		var parts := line.split(" | ")
		assert_true(parts.size() == 3 and parts[2].strip_edges() != "", "allow-list entry has a reason: %s" % line)
		if parts.size() == 3:
			allow[parts[0].strip_edges() + "|" + parts[1].strip_edges()] = true
	var bad: Array = []
	for path in _p131_scripts():
		bad.append_array(_p148_audit_source(path.trim_prefix("res://"), FileAccess.get_file_as_string(path), allow))
	assert_eq(bad, [], "every literal assigned to a UI text property or passed to a toast or chat post goes through I18n.t or is allow-listed")

## Phase 148 — the audit on one source text, so a fixture can prove it fails. Flags a literal with words
## assigned to `.text` / `.tooltip_text` / `.title` / `.placeholder_text`, or passed to `push_toast(` or
## `_post(` / `chat_posted.emit(` (the chat and notice emits), unless the line goes through I18n or is allow-listed.
func _p148_audit_source(path: String, src: String, allow: Dictionary) -> Array:
	var rx := RegEx.create_from_string("\\.(text|tooltip_text|title|placeholder_text)\\s*=[^=]|push_toast\\(|\\b_post\\(|chat_posted\\.emit\\(")
	var lit := RegEx.create_from_string("\"(?:[^\"\\\\]|\\\\.)*\"")
	var words := RegEx.create_from_string("[A-Za-z]{2,}")
	var keyed := RegEx.create_from_string("(\\[|get\\(|has\\()\"[^\"]*\"")
	var bad: Array = []
	for raw in src.split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("#") or line.begins_with("func ") or rx.search(line) == null:
			continue
		var rhs := line.substr(line.find("=") + 1) if line.contains(".text") or line.contains("_text") or line.contains(".title") else line
		if rhs.contains("I18n.t(") or rhs.contains("I18n.render(") or rhs.contains("tr("):
			continue
		# Dictionary keys (`row["quantity"]`, `get("reason", ...)`) are not text; only real literals count.
		var has_words := false
		for m in lit.search_all(keyed.sub(rhs, "", true)):
			if words.search(m.get_string()) != null:
				has_words = true
		if not has_words:
			continue
		if allow.has(path + "|" + line):
			continue
		bad.append(path.get_file() + ": " + line)
	return bad

func _test_p148_audit_fixture() -> void:
	var fixture := "func f():\n\tlabel.text = \"Hello\"\n\tpush_toast(\"Saved\")\n\tlabel.text = I18n.t(\"ui.craft\")\n\tpush_toast(I18n.t(\"ui.craft\"))\n\t_post(CHANNEL_CHAT, \"x\", \"Hi there\", \"\")\n"
	var bad := _p148_audit_source("fixture.gd", fixture, {})
	assert_eq(bad.size(), 3, "the audit flags a literal text assignment, a literal toast and a literal chat post")
	assert_eq(_p148_audit_source("fixture.gd", "func f():\n\tlabel.text = I18n.t(\"ui.craft\")\n", {}), [], "and passes a translated one")
	assert_eq(_p148_audit_source("fixture.gd", "label.text = \"Hello\"", { "fixture.gd|label.text = \"Hello\"": true }), [], "and honours the allow-list")

func _test_p131_locale_switch() -> void:
	_p131_with_settings(func() -> void:
		TranslationServer.set_locale("en")
		var en_code := UiSlice.friend_code_text("")
		var en_status := PlayerSlice.status_line([{"effect": "paralysis", "remaining": 2.0}])
		assert_eq(en_code, "Friend code: (not assigned yet)", "English text before the switch")
		assert_eq(en_status, "paralysis 2s", "status line in English")
		var seen: Array = []
		var cb := func(loc: String) -> void: seen.append(loc)
		GameBus.locale_changed.connect(cb)
		assert_true(LocaleSettingsScript.set_locale("pt_BR", GameBus), "pt_BR is supported")
		GameBus.locale_changed.disconnect(cb)
		assert_eq(seen, ["pt_BR"], "switching emits locale_changed once")
		assert_eq(UiSlice.friend_code_text(""), "Código de amigo: (ainda não atribuído)", "the friend-code projection is in Portuguese")
		assert_eq(PlayerSlice.status_line([{"effect": "paralysis", "remaining": 2.0}]), "paralisia 2s", "the HUD status line is in Portuguese")
		assert_eq(TerrainSlice.where_text(Vector3(1.0, 2.0, 3.0)), "X 1  Y 3  alt 2 m", "where_text keeps its shape")
		assert_eq(UiSlice.language_button_text(), "Idioma: Português (Brasil)", "the selector names the active language")
		assert_eq(LocaleSettingsScript.next_locale(), "en", "and steps to the next one in the catalog")
		var live := _new_test_ui()
		TranslationServer.set_locale("en")
		GameBus.locale_changed.emit("en")
		assert_eq(live._language_button.text, "Language: English", "the selector button reads English")
		assert_eq(live._panels[UiSlice.WINDOW_INVENTORY].find_children("*", "Label", true, false)[0].text, "Inventory", "the window title reads English")
		LocaleSettingsScript.set_locale("pt_BR", GameBus)
		assert_eq(live._language_button.text, "Idioma: Português (Brasil)", "an open window re-renders the selector")
		assert_eq(live._panels[UiSlice.WINDOW_INVENTORY].find_children("*", "Label", true, false)[0].text, "Inventário", "and its title, without a restart")
		live._on_language_pressed()
		assert_eq(TranslationServer.get_locale(), "en", "pressing the selector steps to the next language")
		live.free()
		LocaleSettingsScript.set_locale("pt_BR")
		assert_eq(I18nScript.number(1.5, 1), "1,5", "pt_BR numbers use a decimal comma")
		# The choice survives a settings round trip: a fresh resolve reads the saved file.
		TranslationServer.set_locale("en")
		assert_eq(LocaleSettingsScript.resolve("en_US"), "pt_BR", "the saved preference wins over the OS locale")
		assert_eq(LocaleSettingsScript.apply_startup("en_US"), "pt_BR", "and is applied at boot")
		assert_false(LocaleSettingsScript.set_locale("xx_XX", GameBus), "an unsupported locale is refused")
		# No saved choice: the OS locale, else English.
		DirAccess.remove_absolute(LocaleSettingsScript.settings_path)
		assert_eq(LocaleSettingsScript.resolve("pt_PT"), "pt_BR", "a regional OS locale maps to its language")
		assert_eq(LocaleSettingsScript.resolve("ja_JP"), "en", "an unsupported OS locale falls back to en")
		assert_eq(LocaleSettingsScript.resolve("en-GB"), "en", "a dashed OS locale is understood")
	)

func _test_p131_system_message() -> void:
	_p131_with_settings(func() -> void:
		# Validation: an unknown key, too many args or an oversize arg become the fallback line.
		assert_eq(I18nScript.sanitize_msg("chat.killed", ["Ana"]), {"key": "chat.killed", "args": ["Ana"]}, "a known key passes")
		assert_eq(I18nScript.sanitize_msg("no.such.key", []), I18nScript.msg(I18nScript.UNKNOWN_KEY), "an unknown key is refused")
		assert_eq(I18nScript.sanitize_msg("chat.killed", ["a", "b", "c", "d", "e"])["key"], I18nScript.UNKNOWN_KEY, "too many args are refused")
		assert_eq(I18nScript.sanitize_msg("chat.killed", ["x".repeat(I18nScript.MAX_ARG_LEN + 1)])["key"], I18nScript.UNKNOWN_KEY, "an oversize arg is refused")
		assert_eq(I18nScript.sanitize_msg("chat.killed", [[1]])["key"], I18nScript.UNKNOWN_KEY, "a nested arg is refused")
		assert_eq(I18nScript.sanitize_msg(42, []) ["key"], I18nScript.UNKNOWN_KEY, "a non-string key is refused")
		assert_eq(I18nScript.sanitize_msg("chat.killed", [3.0])["args"], [3], "a whole float from JSON is restored to an int")
		assert_eq(I18nScript.fill("{0} then {1}", ["{1}", "x"]), "{1} then x", "an argument is never re-scanned for placeholders")
		LocaleSettingsScript.set_locale("en")
		assert_eq(I18nScript.number(12345.5, 1), "12,345.5", "en groups thousands with a comma")
		LocaleSettingsScript.set_locale("pt_BR")
		assert_eq(I18nScript.number(-1234567.0), "-1.234.567", "pt_BR groups thousands with a point")
		assert_eq(I18nScript.number(999.0), "999", "no grouping below a thousand")
		# Saving the language keeps the other keys of the settings file.
		var sf := FileAccess.open(LocaleSettingsScript.settings_path, FileAccess.WRITE)
		sf.store_string('{"other": 7}')
		sf.close()
		LocaleSettingsScript.set_locale("en")
		var kept: Variant = JSON.parse_string(FileAccess.get_file_as_string(LocaleSettingsScript.settings_path))
		assert_eq(str(kept["locale"]) + str(int(kept["other"])), "en7", "set_locale merges into the settings file")
		assert_eq(I18nScript.render(I18nScript.sanitize_msg("<b>raw</b>", [])), I18nScript.t(I18nScript.UNKNOWN_KEY), "raw input is never shown")
		# Host serialization: key + args, never rendered text.
		var n := NetworkingSlice.new()
		add_child(n)
		n._role = NetworkingSlice.Role.HOST
		n.set_transport(MemoryTransport.new([4]))
		n._on_system_message("chat.killed", ["Ana"], "")
		var payload: Dictionary = n.memory_transport().outbox[0]["payload"]
		assert_eq(payload, {"type": "system_message", "key": "chat.killed", "args": ["Ana"]}, "the wire carries key + args")
		assert_false(payload.has("text"), "and no rendered text")
		# Client: validates, then each locale renders it.
		n._role = NetworkingSlice.Role.CLIENT
		var got: Array = []
		var cb := func(key: String, args: Array, target: String) -> void: got.append([key, args, target])
		GameBus.system_message.connect(cb)
		n._route_h2c({ "type": "system_message", "key": "chat.killed", "args": ["Ana"] })
		n._route_h2c({ "type": "system_message", "key": "evil", "args": [] })
		n._route_h2c({ "type": "system_message", "key": "chat.killed", "args": ["a", "b", "c", "d", "e"] })
		GameBus.system_message.disconnect(cb)
		assert_eq(got, [["chat.killed", ["Ana"], ""], [I18nScript.UNKNOWN_KEY, [], ""], [I18nScript.UNKNOWN_KEY, [], ""]], "good lines pass; bad ones become the fallback")
		n.free()
		TranslationServer.set_locale("en")
		var line := I18nScript.render(I18nScript.msg("chat.player_joined", ["Ana"]))
		TranslationServer.set_locale("pt_BR")
		var line_pt := I18nScript.render(I18nScript.msg("chat.player_joined", ["Ana"]))
		assert_eq(line, "Ana joined the world.", "English render")
		assert_eq(line_pt, "Ana entrou no mundo.", "Portuguese render of the same message")
		# The chat box keeps the key, so a switch re-renders the line already on screen.
		var chat := ChatSlice.new()
		chat.render_visuals = false
		chat.admins_path = "user://does_not_exist_admins.json"
		add_child(chat)
		GameBus.system_message.emit("chat.killed", ["Ana"], "")
		TranslationServer.set_locale("en")
		assert_eq(ChatSlice._format_line(chat.lines().back()), "[color=#9fc7ff]Killed Ana.[/color]", "system line rendered in English")
		TranslationServer.set_locale("pt_BR")
		assert_eq(ChatSlice._format_line(chat.lines().back()), "[color=#9fc7ff]Ana foi morto.[/color]", "and in Portuguese after the switch")
		chat.free()
	)

# ── Phase 148 — i18n leftovers ───────────────────────────────────────────

## Every `return "code"` / `"code"` literal handed to `pattern`'s capture in a source file.
func _p148_codes(path: String, pattern: String) -> Array:
	var out: Array = []
	var rx := RegEx.create_from_string(pattern)
	for m in rx.search_all(FileAccess.get_file_as_string(path)):
		var code := m.get_string(1)
		if code != "" and not out.has(code):
			out.append(code)
	return out

func _test_p148_reason_codes_have_keys() -> void:
	var cats: Dictionary = I18nScript.parse_csv("res://locale/ui.csv")["catalog"]
	var codes: Array = []
	# craft, repair and research paths
	codes.append_array(_p148_codes("res://src/crafting/crafting_slice.gd", "(?:_fail|_repair_result|_result)\\([^\\n]*?\"([a-z_]+)(?::[^\"]*)?\"(?:, pid\\)|, player_id\\))"))
	codes.append_array(["skill_requirement", "requires_flag", "requires_profession", "technology_locked", "station_required", "prerequisite_locked"])
	codes.append_array(_p148_codes("res://src/technology/technology_slice.gd", "_result\\(tech_id, false, \"([a-z_]+)"))
	codes.append_array(_p148_codes("res://src/inventory/inventory_slice.gd", "\"reason\": \"([a-z_]+)\""))
	codes.append_array(_p148_codes("res://src/governance/proposal_slice.gd", "\"reason\": \"([a-z_]+)\""))
	# placement
	codes.append_array(_p148_codes("res://src/world/station_slice.gd", "return \"([a-z_]+)(?::%s)?\""))
	for forbidden in ["forwarded", "rejected"]:
		codes.erase(forbidden)
	assert_true(codes.size() >= 25, "the scan found the reason codes (%d)" % codes.size())
	for loc in cats:
		for code in codes:
			assert_true((cats[loc] as Dictionary).has("reason." + str(code)), "%s has reason.%s" % [loc, code])
		assert_true((cats[loc] as Dictionary).has("reason.needs_points"), "%s has reason.needs_points" % loc)
	# settlement paths
	var settle: Array = _p148_codes("res://src/settlement/settlement_slice.gd", "return \"([a-z_]+)\"")
	assert_true(settle.size() >= 15, "the scan found the settlement codes (%d)" % settle.size())
	for loc in cats:
		for code in settle:
			assert_true((cats[loc] as Dictionary).has("settlement.refused." + str(code)), "%s has settlement.refused.%s" % [loc, code])

func _test_p148_reason_text() -> void:
	_p131_with_settings(func() -> void:
		TranslationServer.set_locale("en")
		assert_eq(I18nScript.reason_text("missing_inputs"), "Missing ingredients.", "a plain code")
		assert_eq(I18nScript.reason_text("station_required:forge"), "Needs a forge station nearby.", "a code with a param")
		assert_eq(I18nScript.reason_text("too_close_station:station_0"), "Too close to station_0.", "the placement overlap code")
		assert_eq(I18nScript.reason_text("no_such_code_zz"), "Refused (no_such_code_zz).", "an unknown code never renders raw-empty")
		TranslationServer.set_locale("pt_BR")
		assert_eq(I18nScript.reason_text("inside_claim"), "Dentro da área de um assentamento.", "pt_BR renders the same code")
	)

func _test_p148_number_placeholders() -> void:
	_p131_with_settings(func() -> void:
		assert_eq(I18nScript.fill("{10} {1}", ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k"]), "k b", "multi-digit placeholders fill")
		assert_eq(I18nScript.fill("{10} {1}", ["a", "b"]), "{10} b", "an out-of-range one stays literal")
		TranslationServer.set_locale("pt_BR")
		assert_eq(I18nScript.fill("{0:1}", [1234.5]), "1.234,5", "pt_BR groups with a dot and uses a decimal comma")
		TranslationServer.set_locale("en")
		assert_eq(I18nScript.fill("{0:1}", [1234.5]), "1,234.5", "en groups with a comma")
		# A coordinates line travels as numbers and each locale formats them.
		var m := I18nScript.sanitize_msg("chat.teleported_xyz", [1234.5, 2.0, -7.25])
		assert_eq(I18nScript.render(m), "Teleported to 1,234.5, 2.0, -7.2.", "en chat line")
		TranslationServer.set_locale("pt_BR")
		assert_eq(I18nScript.render(m), "Teletransportado para 1.234,5, 2,0, -7,2.", "pt_BR chat line")
	)

func _test_p148_catalog_retry() -> void:
	var old_path: String = I18nScript.catalog_path
	var old_loaded: bool = I18nScript._loaded
	var failures: int = I18nScript.load_failures
	var quiet: bool = Diag.quiet
	Diag.quiet = true
	I18nScript._loaded = false
	I18nScript.catalog_path = "res://locale/does_not_exist.csv"
	I18nScript.ensure_loaded()
	assert_eq(I18nScript.load_failures, failures + 1, "a missing catalog logs one error")
	assert_false(I18nScript._loaded, "and stays unloaded")
	I18nScript.catalog_path = old_path
	I18nScript.ensure_loaded()
	assert_true(I18nScript._loaded, "a later call retries and loads")
	assert_eq(I18nScript.load_failures, failures + 1, "with no further error")
	Diag.quiet = quiet
	I18nScript._loaded = old_loaded


## Phase 175 — the UI icon keys every window, skill, status effect and HP must have, by directory.
func _ui_icon_expectations() -> Dictionary:
	var windows: Array = []
	for e in _WindowDockScript.entries():
		windows.append(str(e["key"]))
	var hud: Array = [UiIcons.HP]
	var effects := StatusEffects.new()
	for id in effects.table().keys():
		hud.append(str(id))
	var skills: Array = GameData.SKILLS.keys()
	return {
		"res://assets/icons/ui/window": windows,
		"res://assets/icons/ui/hud": hud,
		"res://assets/icons/skills": skills,
	}

func _test_ui_icons_cover_everything() -> void:
	var seen: Dictionary = {}
	var want := _ui_icon_expectations()
	assert_true((want["res://assets/icons/ui/hud"] as Array).size() >= 6, "HP and the five status effects are expected")
	for dir in want:
		var ids: Array = want[dir]
		for id in ids:
			var path: String = "%s/%s.png.raw" % [dir, id]
			assert_true(FileAccess.file_exists(path), "an icon exists at %s" % path)
			var bytes := FileAccess.get_file_as_bytes(path)
			var img := Image.new()
			assert_eq(img.load_png_from_buffer(bytes), OK, "%s decodes as PNG" % path)
			var w := img.get_width()
			assert_true((w == 32 or w == 64) and img.get_height() == w, "%s is 32x32 or 64x64" % path)
			img.convert(Image.FORMAT_RGBA8)
			var last := w - 1
			for corner in [Vector2i(0, 0), Vector2i(last, 0), Vector2i(0, last), Vector2i(last, last)]:
				assert_eq(img.get_pixelv(corner).a, 0.0, "%s has a transparent corner" % path)
			var opaque := 0
			for y in w:
				for x in w:
					if img.get_pixel(x, y).a > 0.5:
						opaque += 1
			assert_true(opaque > 40, "%s has more than 40 opaque pixels (%d)" % [path, opaque])
			var h := hash(bytes)
			assert_false(seen.has(h) and seen[h] == bytes, "%s is not byte-identical to another icon" % path)
			seen[h] = bytes
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".png.raw"):
				assert_true(ids.has(file.trim_suffix(".png.raw")), "%s/%s is not an orphan" % [dir, file])

func _test_dock_icons_and_badges() -> void:
	var ui := _new_hud_ui()
	for e in _WindowDockScript.entries():
		var b: Button = ui.window_dock.box(str(e["key"]))
		assert_true(b != null, "a dock box exists for %s" % e["key"])
		if b == null:
			continue
		assert_true(b.icon != null, "the %s dock button carries a texture" % e["key"])
		assert_true(b.text.length() != 1, "the %s dock button text is not a bare letter" % e["key"])
		var badge := b.get_node_or_null("Badge") as Label
		assert_true(badge != null and badge.text == str(e["letter"]), "the %s button has a badge with %s" % [e["key"], e["letter"]])
		assert_true(b.tooltip_text.begins_with(I18nScript.t(str(e["name"]))), "the tooltip keeps the translated name")
	ui.free()

func _test_status_icon_ids() -> void:
	var rows := [{"effect": "paralysis"}, {"effect": "heat_burn"}, {"effect": "paralysis"}, {}]
	assert_eq(PlayerSlice.status_icon_ids(rows), ["paralysis", "heat_burn"], "one icon per distinct effect, in order")
	assert_eq(PlayerSlice.status_icon_ids([]), [], "no effects, no icons")
