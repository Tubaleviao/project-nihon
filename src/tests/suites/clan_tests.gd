extends "res://src/tests/test_support.gd"
## Phase 204 — clans at runtime: founding, one clan each, names, invites, roles, the skill roster scoped to the
## clan's own peers, settlement migration, persistence, private messages and the clan window.

const ClanSlice := preload("res://src/clan/clan_slice.gd")
const ClanPanel := preload("res://src/ui/clan_panel.gd")
const ChatCommandsScript := preload("res://src/core/chat_commands.gd")
const I18n := preload("res://src/core/i18n.gd")

func register() -> void:
	_run_test("clan: founding a second clan, or accepting an invite while in one, is refused", _test_clan_one_each)
	_run_test("clan: a duplicate or invalid name is refused", _test_clan_names)
	_run_test("clan: invites, roles, kicks and leaving follow the role table", _test_clan_membership)
	_run_test("clan: invites lapse after the fabric's days and can be withdrawn or declined", _test_clan_invite_lapse)
	_run_test("clan: a migrated settlement is a clan with the same name, members and roles", _test_clan_migration)
	_run_test("clan: save and load round-trips, malformed data is dropped", _test_clan_persistence)
	_run_test("clan: a member's view holds every member's skills, an outsider's and a leaver's none", _test_clan_roster_scope)
	_run_test("clan: the roster sorts by one skill, best first", _test_clan_roster_sort)
	_run_test("clan: intents resolve through the bus, rate-limited, unknown refused", _test_clan_intents)
	_run_test("clan: a client intent binds the connection's player and keeps short strings", _test_clan_wire)
	_run_test("clan: every refusal code has catalog text in each locale", _test_clan_reason_keys)
	_run_test("clan: the window lists the roster by skill and its Message button opens /msg", _test_clan_panel)
	_run_test("chat: /msg reaches only its recipient, with an echo to the sender", _test_private_message)
	_run_test("chat: /msg is limited per minute and to the fabric's length", _test_private_message_limits)
	_run_test("clan: the rules come from the fabric's Clan world system", _test_clan_rules_from_fabric)

func _rig() -> Dictionary:
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("host")
	for p in ["p1", "p2", "p3", "p4"]:
		reg.ensure_player(p)
	var s := ClanSlice.new()
	s.registry = reg
	add_child(s)
	var now := [1000000.0]
	s.now_sec = func() -> float: return now[0]
	s.mono_sec = func() -> float: return now[0]
	return { "reg": reg, "s": s, "now": now }

func _free_rig(rig: Dictionary) -> void:
	rig["s"].free()
	rig["reg"].free()

func _test_clan_one_each() -> void:
	var rig := _rig()
	var s: ClanSlice = rig["s"]
	assert_eq(s.found("p1", "Oakhold"), "", "p1 founds Oakhold")
	assert_eq(s.clan_of("p1"), "clan_1", "and is its member")
	assert_eq(s.role_of("p1"), "founder", "as its founder")
	assert_eq(s.found("p1", "Second"), "already_member", "a second clan is refused")
	assert_eq(s.found("p2", "Elmhold"), "", "p2 founds another")
	assert_eq(s.invite("p1", "p2"), "already_member", "a player in a clan cannot be invited")
	# An invite made while p3 was free cannot be accepted once p3 is in a clan.
	assert_eq(s.invite("p1", "p3"), "", "p1 invites p3")
	assert_eq(s.found("p3", "Ashhold"), "", "p3 founds their own clan first")
	assert_eq(s.join("p3", "clan_1"), "already_member", "accepting an invite while in a clan is refused")
	assert_eq(s.clan_of("p3"), "clan_3", "p3 stays in their own clan")
	assert_false((s.get_clan("clan_1")["invites"] as Dictionary).has("p3"), "founding dropped p3's other invites")
	assert_eq(s.found("", "Hostclan"), "", "an empty actor is the local player")
	assert_eq(s.role_of("host"), "founder", "who founds it")
	_free_rig(rig)

func _test_clan_names() -> void:
	var rig := _rig()
	var s: ClanSlice = rig["s"]
	assert_eq(s.found("p1", "Oak Hold"), "", "a name with a space")
	assert_eq(s.found("p2", "oak hold"), "name_taken", "the same name in another case is refused")
	assert_eq(s.found("p2", "Oak-Hold"), "name_taken", "and with another separator")
	assert_eq(s.found("p2", "Оак Hold"), "name_script", "Cyrillic look-alikes mixed with Latin are refused")
	assert_eq(s.found("p2", "Ok"), "name_length", "too short")
	assert_eq(s.found("p2", "Abcdefghijklmnopqrstuvwxy"), "name_length", "25 letters is too long")
	assert_eq(s.found("p2", "Abcdefghijklmnopqrstuvwx"), "", "24 letters is allowed (a character name stops at 16)")
	assert_eq(s.found("p3", "Ash 9"), "name_chars", "a digit is refused")
	assert_eq(s.found("p3", "A b c d e"), "name_separator", "four separators are refused")
	assert_eq(s.found("p3", " Ash Elm Yew Fir "), "", "three separators, edges trimmed")
	assert_eq(str(s.get_clan(s.clan_of("p3"))["name"]), "Ash Elm Yew Fir", "the name is stored trimmed")
	assert_eq(s.found("p4", "Guild"), "name_reserved", "a clan-only reserved word")
	assert_eq(s.found("p4", "Admin"), "name_reserved", "a character reserved word")
	assert_eq(s.found("p4", ""), "name_length", "an empty name")
	assert_eq(s.clan_of("p4"), "", "no refused name founded anything")
	_free_rig(rig)

func _test_clan_membership() -> void:
	var rig := _rig()
	var s: ClanSlice = rig["s"]
	assert_eq(s.invite("p1", "p2"), "not_member", "an outsider cannot invite")
	s.found("p1", "Oakhold")
	assert_eq(s.invite("p1", "p1"), "self", "not yourself")
	assert_eq(s.invite("p1", "ghost"), "unknown_player", "nor a player the server has never seen")
	assert_eq(s.invite("p1", "p2"), "", "the founder invites p2")
	assert_eq(s.join("p2", "clan_9"), "unknown_clan", "a clan that does not exist")
	assert_eq(s.join("p3", "clan_1"), "not_invited", "p3 has no invite")
	assert_eq(s.join("p2", "clan_1"), "", "p2 joins")
	assert_eq(s.role_of("p2"), "member", "as a member")
	assert_eq(s.invite("p2", "p3"), "no_permission", "a member may not invite")
	assert_eq(s.set_role("p2", "p2", "elder"), "no_permission", "nor set roles")
	assert_eq(s.set_role("p1", "p2", "founder"), "bad_role", "the founder role is never given")
	assert_eq(s.set_role("p1", "p2", "king"), "bad_role", "an unknown role")
	assert_eq(s.set_role("p1", "p2", "elder"), "", "the founder makes p2 an elder")
	assert_eq(s.invite("p2", "p3"), "", "an elder invites")
	assert_eq(s.join("p3", "clan_1"), "", "p3 joins")
	assert_eq(s.set_role("p2", "p3", "guest"), "no_permission", "an elder may not set roles (setRole is the founder's)")
	assert_eq(s.kick("p3", "p2"), "no_permission", "a member may not kick")
	assert_eq(s.kick("p2", "p1"), "founder_locked", "the founder is never kicked")
	s.invite("p1", "p4")
	s.join("p4", "clan_1")
	s.set_role("p1", "p4", "elder")
	assert_eq(s.kick("p2", "p4"), "outranked", "an elder cannot kick an elder")
	assert_eq(s.kick("p2", "p2"), "self", "kicking yourself is leaving")
	assert_eq(s.kick("p2", "p3"), "", "an elder kicks a member")
	assert_eq(s.clan_of("p3"), "", "p3 is out")
	assert_eq(s.kick("p2", "p3"), "not_member", "and cannot be kicked twice")
	assert_eq(s.leave("p1"), "founder_locked", "the founder cannot leave while others remain")
	assert_eq(s.leave("p2"), "", "p2 leaves")
	assert_eq(s.leave("p2"), "not_member", "once")
	assert_eq(s.kick("p1", "p4"), "", "the founder kicks an elder")
	assert_eq(s.leave("p1"), "", "the last member, the founder, leaves")
	assert_eq(s.count(), 0, "which disbands the clan")
	assert_eq(s.found("p2", "Oakhold"), "", "and frees its name")
	assert_true(s.may("p2", "dismantleClanStructures"), "a founder may dismantle clan structures")
	assert_false(s.may("p3", "invite"), "an outsider has no permission")
	_free_rig(rig)

func _test_clan_invite_lapse() -> void:
	var rig := _rig()
	var s: ClanSlice = rig["s"]
	s.found("p1", "Oakhold")
	s.invite("p1", "p2")
	s.invite("p1", "p3")
	assert_eq(s.uninvite("p1", "p2"), "", "an invite is withdrawn")
	assert_eq(s.uninvite("p1", "p2"), "no_such_invite", "once")
	assert_eq(s.join("p2", "clan_1"), "not_invited", "a withdrawn invite cannot be accepted")
	assert_eq(s.decline("p3", "clan_1"), "", "p3 declines")
	assert_eq(s.join("p3", "clan_1"), "not_invited", "a declined invite is gone")
	s.invite("p1", "p4")
	rig["now"][0] += 7.0 * ClanSlice.DAY_SEC
	assert_true(s.tick(float(rig["now"][0])), "the tick lapses a week-old invite")
	assert_eq(s.join("p4", "clan_1"), "not_invited", "a lapsed invite cannot be accepted")
	assert_true(s.take_dirty().has("p4"), "the invitee's view is pushed without it")
	_free_rig(rig)

## A settlement record as SettlementSlice.to_data() writes it (a format-2 world, before clans).
func _settlement_record() -> Dictionary:
	return { "format": 2, "next_id": 4, "next_name": 2, "settlements": {
		"settlement_1": { "id": "settlement_1", "name": "Oak", "name_n": 0, "founder": "p1",
			"members": { "p1": "founder", "p2": "elder", "p3": "guest" }, "invites": { "p4": 999000.0 }, "created": 500.0,
			"hx": 10.0, "hz": 10.0, "status": "growing", "stock": { "Ferrite": 5 }, "taken": {}, "projects": {} },
		"settlement_2": { "id": "settlement_2", "name": "", "name_n": 1, "founder": "p4",
			"members": { "p4": "founder" }, "invites": {}, "created": 600.0, "hx": 900.0, "hz": 900.0, "status": "founded" },
		"settlement_3": { "id": "settlement_3", "name": "oak", "name_n": 0, "founder": "q1",
			"members": { "q1": "founder", "q2": "member" }, "invites": {}, "created": 700.0, "hx": 1900.0, "hz": 900.0 },
		"settlement_9": "not a record",
	} }

func _test_clan_migration() -> void:
	var rig := _rig()
	var s: ClanSlice = rig["s"]
	assert_eq(s.migrate_settlements(_settlement_record()), 3, "every well-formed settlement becomes a clan")
	var oak: Dictionary = s.get_clan(s.clan_of("p1"))
	assert_eq(str(oak["name"]), "Oak", "with the same name")
	assert_eq(oak["members"], { "p1": "founder", "p2": "elder", "p3": "guest" }, "the same members and roles")
	assert_eq(str(oak["founder"]), "p1", "the same founder")
	assert_eq(str(oak["settlement"]), "settlement_1", "and a link to the settlement it was")
	assert_true((oak["invites"] as Dictionary).has("p4"), "a pending invite carries over")
	var numbered: Dictionary = s.get_clan(s.clan_of("p4"))
	assert_eq(int(numbered["name_n"]), 1, "a default-named settlement keeps its number")
	assert_eq(ClanSlice.display_name(numbered), I18n.t("settlement.default_name", [1]), "and renders as before")
	assert_eq(str(s.get_clan(s.clan_of("q1"))["name"]), "oak 2", "a name another clan holds gets a number")
	assert_eq(s.role_of("q2"), "member", "its members keep their roles")
	assert_eq(s.name_refusal("OAK"), "name_taken", "a migrated name is taken")
	# Migrating twice (a second load of the same record) never puts a player in two clans.
	assert_eq(s.migrate_settlements(_settlement_record()), 0, "nothing migrates twice")
	assert_eq(s.migrate_settlements("junk"), 0, "a malformed record migrates nothing")
	_free_rig(rig)

func _test_clan_persistence() -> void:
	var rig := _rig()
	var s: ClanSlice = rig["s"]
	s.found("p1", "Oakhold")
	s.invite("p1", "p2")
	s.join("p2", "clan_1")
	s.set_role("p1", "p2", "elder")
	s.invite("p1", "p3")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(s.to_data()))
	var fresh := ClanSlice.new()
	fresh.registry = rig["reg"]
	fresh.from_data(saved)
	assert_eq(fresh.clan_of("p2"), "clan_1", "membership survives")
	assert_eq(fresh.role_of("p2"), "elder", "roles survive")
	assert_true((fresh.get_clan("clan_1")["invites"] as Dictionary).has("p3"), "invites survive")
	assert_eq(fresh.name_refusal("oakhold"), "name_taken", "the name index is rebuilt")
	assert_eq(fresh.found("p4", "Elmhold"), "", "a new clan after a load")
	assert_eq(fresh.clan_of("p4"), "clan_2", "takes a fresh id")
	var bad := { "format": 1, "next_id": 1, "clans": {
		"clan_5": { "name": "Ok Name", "founder": "x1", "members": { "x1": "founder", "p1": "king" }, "invites": { "x2": "soon" } },
		"clan_6": { "name": "Other", "founder": "x9", "members": { "x1": "member" } },
		"clan_7": { "name": "ok name", "founder": "x3", "members": { "x3": "founder" } },
		"clan_8": [1, 2],
	} }
	fresh.from_data(bad)
	assert_eq(fresh.count(), 1, "a clan without its founder, a duplicate name and a non-record are dropped")
	assert_eq(fresh.role_of("p1"), "guest", "an unknown role loads as guest")
	assert_eq((fresh.get_clan("clan_5")["invites"] as Dictionary).size(), 0, "an invite without a time is dropped")
	assert_eq(fresh.found("p4", "Third"), "", "and ids continue past the loaded ones")
	assert_eq(fresh.clan_of("p4"), "clan_6", "never reusing clan_5")
	fresh.from_data(null)
	assert_eq(fresh.count(), 0, "null loads empty")
	fresh.free()
	_free_rig(rig)

func _test_clan_roster_scope() -> void:
	var rig := _rig()
	var s: ClanSlice = rig["s"]
	var reg: PlayerRegistry = rig["reg"]
	reg.add_skill_xp("p2", "Tailoring", 120)
	reg.record_skill("p2", "Tailoring", "journeyman")
	reg.add_skill_xp("p3", "Smithing", 40)
	s.found("p1", "Oakhold")
	s.invite("p1", "p2")
	s.join("p2", "clan_1")
	s.take_dirty()
	var mine: Dictionary = s.private_view("p1")["mine"]
	var p2_row: Dictionary = {}
	for row: Dictionary in mine["roster"]:
		if str(row["id"]) == "p2":
			p2_row = row
	assert_eq(p2_row.get("skills", {}).get("Tailoring", {}), { "xp": 120, "tier": "journeyman" }, "a member sees another member's skill XP and tier")
	assert_eq(str(p2_row.get("handle", "")), reg.public_handle("p2"), "and the handle /msg takes")
	var outsider: Dictionary = s.private_view("p3")
	assert_true((outsider["mine"] as Dictionary).is_empty(), "an outsider sees no clan")
	assert_false(JSON.stringify(outsider).contains("Tailoring"), "and no member's skills anywhere in the view")
	s.invite("p1", "p3")
	assert_false(JSON.stringify(s.private_view("p3")).contains("Tailoring"), "an invitee sees the clan's name, not its skills")
	assert_eq(s.private_view("p2")["mine"]["invited"], [], "only a role that may invite sees the pending invites")
	reg.add_skill_xp("p2", "Tailoring", 5)
	s.note_skills_changed("p2")
	assert_eq(s.take_dirty().size(), 3, "a member's new XP re-sends the clan's views (members and invitee)")
	assert_eq(s.leave("p2"), "", "p2 leaves")
	assert_true(s.take_dirty().has("p2"), "the leaver gets a new view")
	assert_true((s.private_view("p2")["mine"] as Dictionary).is_empty(), "with no roster: they stop receiving the others' skills")
	assert_false(JSON.stringify(s.private_view("p1")).contains("Tailoring"), "and the clan no longer shows theirs")
	_free_rig(rig)

func _test_clan_roster_sort() -> void:
	var roster := [
		{ "id": "a", "name": "Ana", "role": "member", "skills": { "Tailoring": { "xp": 10, "tier": "novice" } } },
		{ "id": "b", "name": "Bo", "role": "founder", "skills": { "Smithing": { "xp": 900, "tier": "master" } } },
		{ "id": "c", "name": "Cy", "role": "elder", "skills": { "Tailoring": { "xp": 300, "tier": "expert" } } },
		{ "id": "d", "name": "Di", "role": "guest", "skills": { "Tailoring": { "xp": 300, "tier": "journeyman" } } },
	]
	var ids := func(r: Array) -> Array: return r.map(func(e: Dictionary) -> String: return str(e["id"]))
	assert_eq(ids.call(ClanSlice.sort_roster(roster, "Tailoring")), ["c", "d", "a", "b"], "best sewer first: XP, then tier, then none")
	assert_eq(ids.call(ClanSlice.sort_roster(roster, "Smithing")), ["b", "a", "c", "d"], "another skill, ties by name")
	assert_eq(ids.call(ClanSlice.sort_roster(roster, "")), ["b", "c", "a", "d"], "no skill sorts by role")
	assert_eq(ids.call(roster), ["a", "b", "c", "d"], "the input is not reordered")

func _test_clan_intents() -> void:
	var rig := _rig()
	var s: ClanSlice = rig["s"]
	var seen: Array = []
	var cb := func(pid: String, action: String, ok: bool, reason: String) -> void: seen.append([pid, action, ok, reason])
	GameBus.clan_resolved.connect(cb)
	GameBus.clan_intent.emit("found", { "name": "Oakhold" }, "p1")
	assert_eq(seen[-1], ["p1", "found", true, ""], "a found intent resolves")
	GameBus.clan_intent.emit("invite", { "target": "p2" }, "p1")
	assert_eq(seen[-1], ["p1", "invite", false, "rate_limited"], "a second intent inside the interval is refused")
	rig["now"][0] += 1.0
	rig["reg"]._peer_ids[7] = "p2"   # a handle names a player who is here
	GameBus.clan_intent.emit("invite", { "target": reg_handle(rig, "p2") }, "p1")
	assert_eq(seen[-1], ["p1", "invite", true, ""], "a target can be a handle")
	rig["now"][0] += 1.0
	GameBus.clan_intent.emit("dance", {}, "p1")
	assert_eq(seen[-1][3], "unknown_action", "an unknown action")
	rig["now"][0] += 1.0
	GameBus.clan_intent.emit("join", { "id": 7 }, "p2")
	assert_eq(seen[-1][3], "unknown_clan", "a non-string arg reads as empty")
	GameBus.clan_intent.emit("found", {}, "")
	assert_eq(seen[-1][0], "host", "an empty actor is the local player")
	GameBus.clan_resolved.disconnect(cb)
	s.is_host = false
	var before := seen.size()
	GameBus.clan_intent.emit("leave", {}, "p1")
	assert_eq(s.clan_of("p1"), "clan_1", "a client never resolves an intent")
	assert_eq(seen.size(), before, "nor answers it")
	_free_rig(rig)

func reg_handle(rig: Dictionary, pid: String) -> String:
	return str(rig["reg"].public_handle(pid))

func _test_clan_wire() -> void:
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.set_transport(MemoryTransport.new([9]))
	var seen: Array = []
	var cb := func(action: String, args: Dictionary, pid: String) -> void: seen.append([action, args, pid])
	GameBus.clan_intent.connect(cb)
	n._route_c2h(9, { "type": "clan_intent", "action": "found", "args": { "name": "X" }, "player_id": "p2" })
	assert_eq(seen.size(), 0, "an un-handshaked peer's intent is dropped")
	GameBus.clan_intent.disconnect(cb)
	n.free()
	var c := NetworkingSlice.new()
	add_child(c)
	c._role = NetworkingSlice.Role.CLIENT
	c.set_transport(MemoryTransport.new([1]))
	assert_true(GameBus.clan_intent.is_connected(c._m2.forward_clan_intent), "the networking slice forwards clan intents")
	c._m2.forward_clan_intent("leave", {}, "")
	c.free()
	var src := FileAccess.get_file_as_string("res://src/networking/net_part_2.gd")
	var at := src.find("\"clan_intent\":")
	assert_true(at >= 0, "the host routes clan intents")
	var body := src.substr(at, src.find("\"tame_intent\":") - at)
	assert_true(body.contains("_actor_id(sender)"), "the actor is the connection's player")
	assert_false(body.contains("payload.get(\"player_id\""), "never a player id from the payload")

func _test_clan_reason_keys() -> void:
	var cats: Dictionary = I18n.parse_csv("res://locale/ui.csv")["catalog"]
	var src := FileAccess.get_file_as_string("res://src/clan/clan_slice.gd")
	var re := RegEx.create_from_string("return \"([a-z_]+)\"")
	var codes: Array = ClanSlice.REASONS.duplicate()
	for m in re.search_all(src):
		assert_true(ClanSlice.REASONS.has(m.get_string(1)), "returned code %s is listed in REASONS" % m.get_string(1))
	for loc in cats:
		for code in codes:
			assert_true((cats[loc] as Dictionary).has(ClanPanel.refusal_key(str(code))), "%s has clan.refused.%s" % [loc, code])
		for action in ClanSlice.ACTIONS:
			assert_true((cats[loc] as Dictionary).has("clan.ok." + str(action)), "%s has clan.ok.%s" % [loc, action])
		for role in ClanSlice.ROLE_ORDER:
			assert_true((cats[loc] as Dictionary).has("clan.role." + str(role)), "%s has clan.role.%s" % [loc, role])

func _test_clan_panel() -> void:
	var rig := _rig()
	var s: ClanSlice = rig["s"]
	var reg: PlayerRegistry = rig["reg"]
	reg.add_skill_xp("p2", "Tailoring", 50)
	reg.add_skill_xp("p3", "Tailoring", 400)
	s.found("host", "Oakhold")
	for p in ["p2", "p3"]:
		s.invite("host", p)
		s.join(p, "clan_1")
	s.apply_view(s.private_view("host"))
	var panel := ClanPanel.new()
	panel.clan_slice = s
	add_child(panel)
	# A rebuild queue_frees the old rows and no frame runs here: keep them to free at the end.
	var retired: Array = _rows_of(panel)
	panel.sort_by("Tailoring")
	var lines := ClanPanel.roster_lines(s.view()["mine"]["roster"], "Tailoring")
	assert_eq(lines.size(), 3, "one line per member")
	assert_true(str(lines[0]).begins_with(reg.display_name("p3")), "the best sewer is first")
	var rows: Array = panel._roster.get_children()
	assert_eq(rows.size(), 3, "the window shows each member")
	var compose: Array = []
	var cb := func(prefill: String) -> void: compose.append(prefill)
	GameBus.chat_compose_requested.connect(cb)
	for c: Node in (rows[0] as Node).get_children():
		if c is Button:
			(c as Button).pressed.emit()
	GameBus.chat_compose_requested.disconnect(cb)
	# Any chat box alive in this run took the keyboard: give it back, or later tests read "typing".
	get_viewport().gui_release_focus()
	assert_eq(compose, ["/msg %s " % reg.public_handle("p3")], "Message opens the chat on /msg <handle>")
	GameBus.clan_resolved.emit("host", "found", false, "name_taken")
	assert_eq(panel.feedback_text(), I18n.t("clan.refused.name_taken"), "a refusal shows its catalog line")
	s.apply_view({ "mine": {}, "invites": [{ "id": "clan_1", "name": "Oakhold", "name_n": 0 }] })
	retired.append_array(_rows_of(panel))
	panel.refresh()
	assert_eq(panel._roster.get_child_count(), 0, "an outsider's window has no roster")
	assert_eq(panel._invites.get_child_count(), 1, "but shows the invite")
	panel.free()
	for n: Node in retired:
		if is_instance_valid(n) and not n.is_inside_tree():
			n.free()
	_free_rig(rig)

func _rows_of(panel: Node) -> Array:
	return panel._roster.get_children() + panel._invites.get_children()

## A chat rig with two remote players online (peers 7 and 8).
func _pm_rig() -> Dictionary:
	var rig := _chat_rig()
	var reg: PlayerRegistry = rig["reg"]
	for p in ["p2", "p3"]:
		reg.ensure_player(p)
	reg._peer_ids[7] = "p2"
	reg._peer_ids[8] = "p3"
	var clock := [0.0]
	rig["chat"].now_sec = func() -> float: return clock[0]
	rig["clock"] = clock
	return rig

func _free_pm_rig(rig: Dictionary) -> void:
	rig["chat"].free()
	rig["reg"].free()

func _test_private_message() -> void:
	var rig := _pm_rig()
	var chat: ChatSlice = rig["chat"]
	var reg: PlayerRegistry = rig["reg"]
	var posted: Array = []
	var cb := func(channel: String, sender: String, text: String, target: String) -> void: posted.append([channel, sender, text, target])
	GameBus.chat_posted.connect(cb)
	chat.handle_intent("/msg %s can you sew me a cloak?" % reg.public_handle("p3"), "p2")
	assert_eq(posted.size(), 2, "one line to the recipient and one echo")
	assert_eq(posted[0], [ChatSlice.CHANNEL_WHISPER, reg.display_name("p2"), "can you sew me a cloak?", "p3"], "the recipient alone gets it")
	assert_eq(posted[1], [ChatSlice.CHANNEL_WHISPER_TO, reg.display_name("p3"), "can you sew me a cloak?", "p2"], "the sender gets the echo")
	for p in posted:
		assert_true(str(p[3]) != "", "no private line is broadcast")
	posted.clear()
	chat.handle_intent("/msg %s hi" % reg.display_name("p2"), "")
	assert_eq(posted.size(), 2, "a display name works too, from the host's own player")
	assert_eq(str(posted[0][3]), "p2", "to that player")
	posted.clear()
	var said: Array = []
	var cb2 := func(key: String, _args: Array, target: String) -> void: said.append([key, target])
	GameBus.system_message.connect(cb2)
	chat.handle_intent("/msg nobody_here hello", "p2")
	chat.handle_intent("/msg %s hello" % reg.public_handle("p2"), "p2")
	chat.handle_intent("/msg %s" % reg.public_handle("p3"), "p2")
	GameBus.system_message.disconnect(cb2)
	GameBus.chat_posted.disconnect(cb)
	assert_eq(posted.size(), 0, "no message without a recipient online, to yourself, or without text")
	assert_eq(said, [["chat.no_player", "p2"], ["chat.msg_self", "p2"], ["chat.usage.msg", "p2"]], "each explained to the sender alone")
	_free_pm_rig(rig)

func _test_private_message_limits() -> void:
	var rig := _pm_rig()
	var chat: ChatSlice = rig["chat"]
	var reg: PlayerRegistry = rig["reg"]
	var per_minute := int(ChatSlice.private_rules()["perMinute"])
	var max_len := int(ChatSlice.private_rules()["maxLength"])
	assert_eq([per_minute, max_len], [10, 280], "the fabric's Clan.messages")
	var posted: Array = []
	var cb := func(channel: String, _s: String, text: String, _t: String) -> void:
		if channel == ChatSlice.CHANNEL_WHISPER:
			posted.append(text)
	GameBus.chat_posted.connect(cb)
	var long := "x".repeat(300)
	var line := ChatCommandsScript.sanitize("/msg %s %s" % [reg.public_handle("p3"), long])
	assert_true(line.length() > ChatCommandsScript.MAX_MESSAGE_CHARS, "a /msg line keeps more than a plain chat line")
	chat.handle_intent(line, "p2")
	assert_eq(str(posted[0]).length(), max_len, "the text is capped at the fabric's maxLength")
	posted.clear()
	# The chat bucket (5 lines, 1/s) must not be what limits this: space the lines a few seconds apart.
	for i in per_minute + 2:
		rig["clock"][0] += 3.0
		chat.handle_intent("/msg %s line %d" % [reg.public_handle("p3"), i], "p2")
	assert_eq(posted.size(), per_minute - 1, "with one sent this minute, %d more pass and the rest are refused" % (per_minute - 1))
	assert_true(chat.private_rate_refused >= 3, "the refusals are counted")
	rig["clock"][0] += 61.0
	chat.handle_intent("/msg %s again" % reg.public_handle("p3"), "p2")
	assert_eq(posted[-1], "again", "a minute later they pass again")
	GameBus.chat_posted.disconnect(cb)
	assert_eq(ChatCommandsScript.sanitize("x".repeat(300)).length(), ChatCommandsScript.MAX_MESSAGE_CHARS, "a plain line is still capped at 240")
	_free_pm_rig(rig)

func _test_clan_rules_from_fabric() -> void:
	var s := ClanSlice.new()
	var r := s.rules()
	var fab: Dictionary = GameData.WORLD_SYSTEMS["Clan"].rules
	assert_eq(r["roles"], fab["roles"], "the role table is the fabric's")
	assert_eq(int(r["invites"]["ttlDays"]), int(fab["invites"]["ttlDays"]), "the invite lifetime is the fabric's")
	assert_eq(int(r["name"]["maxLength"]), int(fab["name"]["maxLength"]), "the name bounds are the fabric's")
	assert_eq(str(r["founderRole"]), "founder", "the founder role")
	s.free()
