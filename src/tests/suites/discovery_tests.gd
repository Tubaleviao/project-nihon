extends "res://src/tests/test_support.gd"
## Phase 297 — finding servers nearby: one address parser (ports, IPv6), the status port's codec and anti-abuse
## rules, the protocol version a client and a host must share, LAN discovery rows, the Happy Eyeballs pick, the
## host's boot flags, and real dual-stack sockets on loopback.

const NetAddress := preload("res://src/networking/net_address.gd")
const ServerStatus := preload("res://src/networking/server_status.gd")
const StatusServer := preload("res://src/networking/status_server.gd")
const ServerProbe := preload("res://src/networking/server_probe.gd")
const ServerConnector := preload("res://src/networking/server_connector.gd")
const BootWiring := preload("res://src/core/boot_wiring.gd")
const MainMenu := preload("res://src/menu/main_menu.gd")
const RecentServers := preload("res://src/menu/recent_servers.gd")
const I18n := preload("res://src/core/i18n.gd")
const MenuWiring := preload("res://src/menu/menu_wiring.gd")

const KEYS := ["menu.join.fail_protocol_newer", "menu.join.fail_protocol_older", "menu.join.lan", "menu.join.lan_refresh",
	"menu.join.lan_none", "menu.join.lan_row", "menu.join.lan_unnamed", "menu.join.lan_incompatible", "menu.join.ping",
	"menu.join.error_address", "menu.join.fail_version"]

func register() -> void:
	_run_test("discovery: the address parser splits host and port for IPv4, names and IPv6, and refuses the malformed", _test_parser)
	_run_test("discovery: --client, the Join form and the recent-servers file agree on every address", _test_one_rule)
	_run_test("discovery: the status codec round-trips and caps its names", _test_codec)
	_run_test("discovery: a short, oversized, foreign or malformed query gets no reply", _test_query_rules)
	_run_test("discovery: the status port rate-limits per address and in all", _test_rate_limit)
	_run_test("discovery: a client of protocol N refuses a host of N+1 with a key in both catalogs", _test_protocol_refusal)
	_run_test("discovery: the host refuses a join or roster intent of another protocol, and the client leaves on one", _test_protocol_wire)
	_run_test("discovery: #706 a build version is a short String with no control characters", _test_version_field)
	_run_test("discovery: #706 a client refuses a host of another build and names both versions", _test_build_refusal)
	_run_test("discovery: #706 the host refuses a join or roster intent of another, missing or malformed build", _test_build_wire)
	_run_test("discovery: #706 a build refusal returns to the menu with both versions, and the menu client exits 2", _test_build_refusal_menu)
	_run_test("discovery: LAN rows are one per host, joined on IPv4, and another protocol cannot be joined", _test_lan_rows)
	_run_test("discovery: Happy Eyeballs asks IPv6 first, IPv4 250 ms later, and keeps the first answer", _test_eyeballs)
	_run_test("discovery: --port, --bind, --status-port and --world-name set what the host listens on", _test_host_args)
	_run_test("discovery: a dual-stack host answers ENet and the status query on 127.0.0.1 and ::1", _test_dual_stack_sockets)
	_run_test("discovery: every new string is in both catalogs", _test_catalog)

func _test_parser() -> void:
	var good := {
		"127.0.0.1": ["127.0.0.1", 7777, "v4"],
		"10.0.0.2:7000": ["10.0.0.2", 7000, "v4"],
		"example.org": ["example.org", 7777, "name"],
		"host-1.local:65535": ["host-1.local", 65535, "name"],
		"[2001:db8::1]:7000": ["2001:db8::1", 7000, "v6"],
		"[::1]": ["::1", 7777, "v6"],
		"2001:db8::1": ["2001:db8::1", 7777, "v6"],
		"::1": ["::1", 7777, "v6"],
		"fe80::1": ["fe80::1", 7777, "v6"],
	}
	for raw in good:
		var a := NetAddress.parse(raw)
		assert_true(bool(a["ok"]), "'%s' is accepted" % raw)
		if bool(a["ok"]):
			assert_eq([a["host"], a["port"], a["family"]], good[raw], "'%s' splits into host, port and family" % raw)
	for raw in ["", "http://x", "a/b", "a b", "a\tb", "-lead", ".dot", "a..b", "host:", "host:0", "host:65536", "host:+80",
			"host:-1", "host:x", "1.2.3.4:5:6", "[::1", "[::1]x", "[::1]:", "[::1]:99999", "::1]", "[1.2.3.4]:80",
			"999.1.1.1", "1.2.3", "fe80::1%eth0", "[fe80::1%eth0]:7777", "2001:db8::g", "user@host", "a".repeat(NetAddress.ADDRESS_MAX + 1)]:
		assert_false(NetAddress.valid(raw), "'%s' is refused" % raw.left(24))
	assert_true(NetAddress.valid("a".repeat(NetAddress.ADDRESS_MAX)), "a name at the length cap is accepted")
	assert_eq(NetAddress.format("::1", 7000), "[::1]:7000", "an IPv6 host with a port is bracketed")
	assert_eq(NetAddress.format("::1", 7777), "::1", "the default port is left out")
	assert_eq(NetAddress.format("10.0.0.2", 7000), "10.0.0.2:7000", "an IPv4 host takes a plain port")
	for h in [["::1", 7000], ["10.0.0.2", 7001], ["example.org", 7777], ["2001:db8::1", 9000]]:
		var back := NetAddress.parse(NetAddress.format(str(h[0]), int(h[1])))
		assert_eq([back["host"], back["port"]], h, "format → parse returns %s" % str(h))

func _test_one_rule() -> void:
	var was_quiet := Diag.quiet
	Diag.quiet = true
	var path := "user://test_discovery_recent.json"
	var cases := ["127.0.0.1", "10.0.0.2:7777", "[2001:db8::1]:7000", "2001:db8::1", "example.org:80", "", "http://x",
		"[::1", "host:0", "a b", "1.2.3.4:5:6"]
	var entries: Array = []
	for addr in cases:
		entries.append({ "address": addr, "friend": "", "last": 1 })
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({ "servers": entries }))
	f.close()
	var loaded: Array = []
	for e in RecentServers.load_list(path):
		loaded.append(str(e["address"]))
	for addr in cases:
		var valid := NetAddress.valid(addr)
		assert_eq(BootWiring.client_address(addr) == addr, valid, "--client agrees on '%s'" % addr)
		var choice := MainMenu.join_choice(addr, "")
		assert_eq(bool(choice["ok"]), valid, "the Join form agrees on '%s'" % addr)
		if not valid and addr != "":
			assert_eq(str(choice.get("error", "")), "menu.join.error_address", "with the address key for '%s'" % addr)
		assert_eq(loaded.has(addr), valid, "the recent-servers loader agrees on '%s'" % addr)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Diag.quiet = was_quiet

func _info(name: String = "Akira's world") -> Dictionary:
	return { "protocol": ServerStatus.PROTOCOL_VERSION, "game_port": 7000, "players": 3, "max_players": 65,
		"instance": 0x1234ABCD, "game_version": "0.3.0", "world_name": name }

func _test_codec() -> void:
	var q := ServerStatus.encode_query(0xDEADBEEF)
	assert_eq(q.size(), ServerStatus.ANSWER_SIZE, "a query is padded to the answer's size")
	assert_eq(ServerStatus.decode_query(q), 0xDEADBEEF, "and its nonce reads back")
	var a := ServerStatus.encode_answer(0xDEADBEEF, _info())
	assert_eq(a.size(), ServerStatus.ANSWER_SIZE, "an answer has the fixed size")
	var d := ServerStatus.decode_answer(a)
	for k in ["protocol", "game_port", "players", "max_players", "instance", "game_version", "world_name"]:
		assert_eq(d.get(k), _info()[k], "%s round-trips" % k)
	assert_eq(int(d["nonce"]), 0xDEADBEEF, "the nonce is echoed")
	var long_name := "ç".repeat(200)
	var cut := ServerStatus.decode_answer(ServerStatus.encode_answer(1, _info(long_name)))
	assert_true(str(cut["world_name"]).to_utf8_buffer().size() <= ServerStatus.NAME_MAX_BYTES, "a long name is cut to its byte cap")
	assert_true(long_name.begins_with(str(cut["world_name"])) and str(cut["world_name"]).length() > 0, "on a character boundary")
	var ctrl := ServerStatus.decode_answer(ServerStatus.encode_answer(1, _info("a\u0001b\nc")))
	assert_eq(str(ctrl["world_name"]), "abc", "control characters are dropped")
	var bad := a.duplicate()
	bad.encode_u8(21, 200)   # a version length past its cap
	assert_eq(ServerStatus.decode_answer(bad), {}, "a field length past its cap is refused")
	assert_eq(ServerStatus.decode_answer(a.slice(0, 100)), {}, "a short answer is refused")
	assert_eq(ServerStatus.decode_answer(q), {}, "a query is no answer")

func _test_query_rules() -> void:
	var srv := StatusServer.new()
	srv.info = _info
	var q := ServerStatus.encode_query(7)
	assert_eq(srv.handle(q, "10.0.0.9", 0).size(), ServerStatus.ANSWER_SIZE, "a good query gets the fixed-size answer")
	var answer := srv.handle(q, "10.0.0.9", 0)
	assert_true(answer.size() <= q.size(), "never more bytes than the query (no amplification)")
	assert_eq(srv.handle(q.slice(0, ServerStatus.ANSWER_SIZE - 1), "10.0.0.9", 0).size(), 0, "a query smaller than the answer gets none")
	var big := q.duplicate()
	big.resize(ServerStatus.QUERY_MAX + 1)
	assert_eq(srv.handle(big, "10.0.0.8", 0).size(), 0, "a query over the size cap gets none")
	var at_cap := q.duplicate()
	at_cap.resize(ServerStatus.QUERY_MAX)
	assert_eq(srv.handle(at_cap, "10.0.0.7", 0).size(), ServerStatus.ANSWER_SIZE, "one at the cap is answered")
	var other := q.duplicate()
	other.encode_u8(4, ServerStatus.FORMAT + 1)
	assert_eq(srv.handle(other, "10.0.0.6", 0).size(), 0, "a query of another format gets none")
	var magic := q.duplicate()
	magic[0] = 0x58
	assert_eq(srv.handle(magic, "10.0.0.5", 0).size(), 0, "a foreign datagram gets none")
	assert_eq(srv.handle(PackedByteArray(), "10.0.0.4", 0).size(), 0, "an empty one gets none")
	srv.free()

func _test_rate_limit() -> void:
	var srv := StatusServer.new()
	srv.info = _info
	var q := ServerStatus.encode_query(1)
	var got := 0
	for i in StatusServer.PER_ADDRESS + 3:
		got += int(srv.handle(q, "10.1.1.1", 100).size() > 0)
	assert_eq(got, StatusServer.PER_ADDRESS, "one address gets PER_ADDRESS answers a window, the excess is dropped")
	assert_true(srv.handle(q, "10.1.1.2", 100).size() > 0, "another address is still answered")
	assert_true(srv.handle(q, "10.1.1.1", 100 + StatusServer.WINDOW_MS).size() > 0, "the next window answers again")
	var total := 0
	for i in StatusServer.PER_WINDOW + 50:
		total += int(srv.handle(q, "10.2.%d.%d" % [int(i / 250.0), i % 250], 10000).size() > 0)
	assert_eq(total, StatusServer.PER_WINDOW, "the port answers at most PER_WINDOW in all, whatever the sources")
	srv.free()

func _test_protocol_refusal() -> void:
	var n := ServerStatus.PROTOCOL_VERSION
	assert_eq(ServerStatus.protocol_refusal(n, n), "", "the same version plays")
	var key := ServerStatus.protocol_refusal(n, n + 1)
	assert_eq(key, "menu.join.fail_protocol_newer", "a host of N+1 is refused as newer")
	assert_eq(ServerStatus.protocol_refusal(n + 1, n), "menu.join.fail_protocol_older", "a host of N-1 as older")
	var cats: Dictionary = I18n.parse_csv("res://locale/ui.csv")["catalog"]
	for loc in ["en", "pt_BR"]:
		assert_true(str((cats.get(loc, {}) as Dictionary).get(key, "")).strip_edges() != "", "%s has the reason" % loc)

func _test_protocol_wire() -> void:
	var was_quiet := Diag.quiet
	Diag.quiet = true
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	var joins: Array = []
	var on_join := func(peer: int, _claim: String) -> void: joins.append(peer)
	GameBus.player_join_intent.connect(on_join)
	var rosters: Array = []
	var on_roster := func(_op: String, _args: Dictionary, peer: int) -> void: rosters.append(peer)
	GameBus.character_roster_intent.connect(on_roster)
	n._route_c2h(5, { "type": "join_intent", "claimed_id": "" })
	n._route_c2h(6, { "type": "join_intent", "claimed_id": "", "protocol": ServerStatus.PROTOCOL_VERSION + 1 })
	n._route_c2h(7, { "type": "roster_intent", "op": "list", "protocol": "1" })
	assert_eq(joins, [], "a join with no protocol or another one is not acted on")
	assert_eq(rosters, [], "nor a roster intent naming a protocol as text")
	assert_true(n._m2._protocol_refused.has(5) and n._m2._protocol_refused.has(6), "each refused peer is marked to be dropped")
	n._route_c2h(8, { "type": "join_intent", "claimed_id": "", "protocol": ServerStatus.PROTOCOL_VERSION,
		"game_version": ServerStatus.game_version() })
	n._route_c2h(8, { "type": "roster_intent", "op": "list", "protocol": ServerStatus.PROTOCOL_VERSION,
		"game_version": ServerStatus.game_version() })
	assert_eq(joins, [8], "a join of this protocol goes on")
	assert_eq(rosters, [8], "and so does its roster intent")
	n._m2._on_peer_disconnected(5)
	assert_false(n._m2._protocol_refused.has(5), "a disconnect forgets the mark (ENet may reuse the id)")
	GameBus.player_join_intent.disconnect(on_join)
	GameBus.character_roster_intent.disconnect(on_roster)
	# Client side: a hello of another version ends the join with the key; this one's changes nothing.
	n._role = NetworkingSlice.Role.CLIENT
	var refused: Array = []
	var on_refused := func(key: String, _args: Array) -> void: refused.append(key)
	GameBus.join_refused.connect(on_refused)
	n._route_h2c({ "type": "server_hello", "protocol": ServerStatus.PROTOCOL_VERSION, "game_version": ServerStatus.game_version() })
	assert_eq(refused, [], "a host of the same protocol is kept")
	n._route_h2c({ "type": "server_hello", "protocol": ServerStatus.PROTOCOL_VERSION + 1 })
	assert_eq(refused, ["menu.join.fail_protocol_newer"], "a newer host ends the join with the reason")
	assert_true(n.is_offline(), "and the client leaves")
	n._role = NetworkingSlice.Role.CLIENT
	n._route_h2c({ "type": "protocol_refused", "protocol": ServerStatus.PROTOCOL_VERSION })
	assert_eq(refused.size(), 2, "a refusal from the host ends it too")
	GameBus.join_refused.disconnect(on_refused)
	remove_child(n)
	n.free()
	Diag.quiet = was_quiet

func _answer(ip: String, inst: int, rtt: int, protocol: int = ServerStatus.PROTOCOL_VERSION, players: int = 2) -> Dictionary:
	var st := _info("")
	st["instance"] = inst
	st["protocol"] = protocol
	st["players"] = players
	return { "key": "lan", "ip": ip, "rtt_ms": rtt, "status": st }

func _test_lan_rows() -> void:
	var rows := {}
	ServerProbe.merge_lan_row(rows, _answer("fe80::1", 9, 12))
	ServerProbe.merge_lan_row(rows, _answer("192.168.0.4", 9, 8))
	assert_eq(rows.size(), 1, "a host heard on both families is one row")
	assert_eq(str(rows[9]["ip"]), "192.168.0.4", "joined on its IPv4 address")
	assert_eq(int(rows[9]["rtt_ms"]), 8, "with its best round trip")
	ServerProbe.merge_lan_row(rows, _answer("fe80::1", 9, 3))
	assert_eq(str(rows[9]["ip"]), "192.168.0.4", "a later IPv6 answer keeps the IPv4 address")
	for i in ServerProbe.MAX_LAN_ROWS + 10:
		ServerProbe.merge_lan_row(rows, _answer("10.0.0.%d" % (i % 250), 1000 + i, 50))
	assert_eq(rows.size(), ServerProbe.MAX_LAN_ROWS, "a flood of instances cannot grow the list past its cap")
	assert_true(rows.has(9), "and does not push out a faster host")
	ServerProbe.merge_lan_row(rows, _answer("10.0.1.1", 77, 2))
	assert_true(rows.has(77) and rows.size() == ServerProbe.MAX_LAN_ROWS, "a faster new host replaces the slowest row at the cap")
	var aged := { 1: { "seen": 100 }, 2: { "seen": 5000 } }
	assert_true(ServerProbe.drop_stale_rows(aged, 6000, 3000), "a host silent past the stale time")
	assert_eq(aged.keys(), [2], "leaves the list; one that answered stays")
	var view := MainMenu.lan_row_view(rows[9])
	assert_true(bool(view["joinable"]), "a host of this protocol can be joined")
	assert_eq(str(view["address"]), "192.168.0.4:7000", "on the game port from its answer")
	assert_true(str(view["text"]).contains(I18n.t("menu.join.lan_unnamed")), "a nameless world reads as unnamed")
	var old := MainMenu.lan_row_view({ "ip": "::1", "rtt_ms": 4, "status": _answer("::1", 1, 4, ServerStatus.PROTOCOL_VERSION + 1)["status"] })
	assert_false(bool(old["joinable"]), "a host of another protocol is listed but cannot be joined")
	assert_eq(str(old["address"]), "[::1]:7000", "an IPv6 row's address is bracketed with its port")
	# The menu merges probe answers into its list and pings recent servers.
	var menu := MainMenu.new()
	var recent_path := "user://test_discovery_menu_recent.json"
	menu.recent_path = recent_path
	menu.worlds_base = "user://test_discovery_worlds/"
	RecentServers.remember("10.9.9.9:7000", "", menu.recent_path, 5)
	add_child(menu)
	menu.show_page(MainMenu.PAGE_JOIN)
	menu.apply_answers([_answer("192.168.0.4", 1, 9, ServerStatus.PROTOCOL_VERSION, 1), _answer("192.168.0.5", 2, 9, ServerStatus.PROTOCOL_VERSION, 5),
		{ "key": "recent:10.9.9.9:7000", "ip": "10.9.9.9", "rtt_ms": 42, "status": _info() }])
	var shown := menu.lan_rows()
	assert_eq(shown.size(), 2, "the Join page lists both hosts")
	assert_eq(str(shown[0]["address"]), "192.168.0.5:7000", "the busier world first")
	assert_eq(str(menu._ping_labels["10.9.9.9:7000"].text), I18n.t("menu.join.ping", ["42"]), "the recent server shows its ping")
	var asked: Array = []
	menu.start_requested.connect(func(c: Dictionary) -> void: asked.append(c))
	menu._lan_list.get_child(0).emit_signal("pressed")
	assert_eq(asked.size(), 1, "a row joins on click")
	if asked.size() == 1:
		assert_eq(str(asked[0]["address"]), "192.168.0.5:7000", "the host on its game port")
	menu.search_servers()
	assert_eq(menu.lan_rows(), [], "Search again starts from an empty list")
	menu.apply_answers([_answer("192.168.0.4", 1, 9)])
	menu.show_page(MainMenu.PAGE_HOME)
	assert_true(menu._probe == null, "leaving the page closes the probe")
	assert_eq(menu.lan_rows(), [], "and forgets the rows")
	remove_child(menu)
	menu.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(recent_path))

func _test_eyeballs() -> void:
	var e := ServerConnector.Eyeballs.new()
	assert_eq(e.begin(["2001:db8::1", "192.0.2.1", "2001:db8::2"], 1000), ["v6"], "IPv6 is asked first")
	assert_eq(e.due(1100), [], "IPv4 waits")
	assert_eq(e.due(1000 + ServerConnector.STAGGER_MS), ["v4"], "and goes 250 ms later")
	assert_eq(e.due(1400), [], "once")
	e.answered("v4")
	e.answered("v6")
	assert_eq(e.chosen, "192.0.2.1", "the first answer wins")
	var slow := ServerConnector.Eyeballs.new()
	slow.begin(["192.0.2.1", "2001:db8::1"], 0)
	slow.expire(ServerConnector.DECIDE_MS - 1)
	assert_eq(slow.chosen, "", "no pick before the deadline")
	slow.expire(ServerConnector.DECIDE_MS)
	assert_eq(slow.chosen, "192.0.2.1", "no answer by the deadline dials the resolver's first address")
	var fast := ServerConnector.Eyeballs.new()
	fast.begin(["2001:db8::1", "192.0.2.1"], 0)
	fast.answered("v6")
	assert_eq(fast.chosen, "2001:db8::1", "a quick IPv6 answer is kept")
	assert_eq(fast.due(ServerConnector.STAGGER_MS), [], "and IPv4 is never asked")
	var one := ServerConnector.Eyeballs.new()
	assert_eq(one.begin(["192.0.2.7"], 0), [], "one family needs no race")
	assert_eq(one.chosen, "192.0.2.7", "it is dialled at once")
	var lit: Dictionary = ServerConnector.literal_target("[::1]:7100")
	assert_eq([lit["host"], lit["port"]], ["::1", 7100], "a literal is dialled as given")
	assert_eq(ServerConnector.literal_target("example.org"), {}, "a name goes to the race")
	var src := FileAccess.get_file_as_string("res://src/networking/server_connector.gd")
	assert_false(src.contains("OS.delay_msec") or src.contains("resolve_hostname_addresses("), "the race never blocks the main thread")

func _test_host_args() -> void:
	var was_quiet := Diag.quiet
	Diag.quiet = true
	var b := BootWiring.new()
	b.parse_host_args(PackedStringArray(["--server", "--port", "7100", "--bind", "::", "--status-port", "7200", "--world-name", "Nara\u0001"]))
	assert_eq([b.host_port, b.bind_address, b.status_port, b.world_name], [7100, "::", 7200, "Nara"], "the flags are read")
	var opts := b.host_options({}, true)
	assert_eq([opts["bind"], opts["status_port"], opts["world_name"], opts["local_players"]], ["::", 7200, "Nara", 0], "into the host's options")
	assert_eq(str(b.host_options({ "name": "Menu world" }, false)["world_name"]), "Menu world", "a menu world answers with its own name")
	var d := BootWiring.new()
	d.parse_host_args(PackedStringArray(["--port", "0", "--bind", "nope", "--status-port", "x"]))
	assert_eq([d.host_port, d.bind_address, d.status_port], [7777, "*", -1], "malformed flags keep the defaults")
	assert_eq(int(d.host_options({}, false)["status_port"]), 7778, "the status port defaults to the game port + 1")
	var off := BootWiring.new()
	off.parse_host_args(PackedStringArray(["--port", "7300", "--status-port", "0"]))
	assert_eq(int(off.host_options({}, true)["status_port"]), 0, "--status-port 0 turns it off")
	Diag.quiet = was_quiet

## Real sockets on loopback, polled by hand (the suite has no frames): Godot's default "*" bind is one dual-stack
## socket, so ENet and the status port answer on both families.
func _test_dual_stack_sockets() -> void:
	var v6 := _has_ipv6_loopback()
	if not v6:
		print("  (no IPv6 loopback on this machine: the ::1 half is skipped)")
	var srv := ENetMultiplayerPeer.new()
	var port := 0
	for p in range(27700, 27760):
		if srv.create_server(p, 4) == OK:
			port = p
			break
	assert_true(port > 0, "an ENet host listens on the default dual-stack bind")
	var clients: Array = []
	for addr in (["127.0.0.1", "::1"] if v6 else ["127.0.0.1"]):
		var c := ENetMultiplayerPeer.new()
		c.create_client(addr, port)
		clients.append([addr, c])
	var deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline:
		srv.poll()
		var all := true
		for pair in clients:
			(pair[1] as ENetMultiplayerPeer).poll()
			all = all and (pair[1] as ENetMultiplayerPeer).get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
		if all:
			break
		OS.delay_msec(5)
	for pair in clients:
		assert_eq((pair[1] as ENetMultiplayerPeer).get_connection_status(), MultiplayerPeer.CONNECTION_CONNECTED, "a client on %s connects" % pair[0])
		(pair[1] as ENetMultiplayerPeer).close()
	srv.close()
	var status := StatusServer.new()
	status.info = _info
	var sport := 0
	for p in range(27800, 27860):
		if status.start(p) == OK:
			sport = p
			break
	assert_true(sport > 0, "the status port binds")
	var probe := ServerProbe.new()
	assert_eq(probe.open(), OK, "the probe opens")
	var seen := {}
	for addr in (["127.0.0.1", "::1"] if v6 else ["127.0.0.1"]):
		probe.query_ip(addr, sport, addr)
	deadline = Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < deadline and seen.size() < (2 if v6 else 1):
		status.poll()
		for ans in probe.poll():
			seen[str(ans["key"])] = ans
		OS.delay_msec(5)
	for addr in (["127.0.0.1", "::1"] if v6 else ["127.0.0.1"]):
		assert_true(seen.has(addr), "the status query is answered on %s" % addr)
		if seen.has(addr):
			assert_eq(int(seen[addr]["status"]["game_port"]), 7000, "with the host's game port")
	# LAN discovery's real targets (IPv4 broadcast, IPv6 all-nodes) reach a host on this machine too.
	var lan := ServerProbe.new()
	lan.open()
	var sent := lan.discover(sport)
	if sent == 0:
		print("  (this machine refuses broadcast and multicast sends: the LAN-target half is skipped)")
	else:
		var heard := {}
		deadline = Time.get_ticks_msec() + 2000
		while Time.get_ticks_msec() < deadline and heard.is_empty():
			status.poll()
			for ans in lan.poll():
				heard[int(ans["status"]["instance"])] = ans
			OS.delay_msec(5)
		assert_true(heard.has(status.instance), "a discovery query to %s finds the host" % str(ServerProbe.LAN_TARGETS))
	lan.close()
	var stray := PacketPeerUDP.new()
	stray.bind(0, "*")
	stray.set_dest_address("127.0.0.1", probe._udp.get_local_port())
	stray.put_packet(ServerStatus.encode_answer(424242, _info()))
	OS.delay_msec(20)
	assert_eq(probe.poll(), [], "an answer to no query of this probe is ignored")
	stray.close()
	probe.close()
	status.stop()
	status.free()

static func _has_ipv6_loopback() -> bool:
	var u := PacketPeerUDP.new()
	var ok := u.bind(0, "::1") == OK
	u.close()
	return ok

func _test_catalog() -> void:
	var cats: Dictionary = I18n.parse_csv("res://locale/ui.csv")["catalog"]
	for loc in ["en", "pt_BR"]:
		for k: String in KEYS:
			assert_true(str((cats.get(loc, {}) as Dictionary).get(k, "")).strip_edges() != "", "%s has %s" % [loc, k])

## #706 — what the host accepts as a build version off the wire.
func _test_version_field() -> void:
	assert_eq(ServerStatus.valid_version("0.2.0"), "0.2.0", "a plain version is kept")
	assert_eq(ServerStatus.valid_version(""), "", "an empty one is refused")
	assert_eq(ServerStatus.valid_version(null), "", "a missing one is refused")
	assert_eq(ServerStatus.valid_version(2), "", "a number is refused")
	assert_eq(ServerStatus.valid_version(["0.2.0"]), "", "an array is refused")
	assert_eq(ServerStatus.valid_version("1".repeat(ServerStatus.VERSION_MAX_BYTES)), "1".repeat(ServerStatus.VERSION_MAX_BYTES),
		"a version of exactly the cap is kept")
	assert_eq(ServerStatus.valid_version("1".repeat(ServerStatus.VERSION_MAX_BYTES + 1)), "", "one byte past the cap is refused")
	assert_eq(ServerStatus.valid_version("1.0ã"), "", "a letter outside A-Z is refused")
	assert_eq(ServerStatus.valid_version("1.0\u202e"), "", "a bidi override is refused")
	assert_eq(ServerStatus.valid_version("1.0\u200b"), "", "a zero-width space is refused")
	assert_eq(ServerStatus.valid_version("0.3.0-rc.1+b7_x"), "0.3.0-rc.1+b7_x", "dots, dashes, plus and underscores are kept")
	assert_eq(ServerStatus.valid_version("0.2\n.0"), "", "a control character is refused")
	assert_eq(ServerStatus.valid_version(" 0.2.0"), "", "outer whitespace is refused")
	var own := ServerStatus.game_version()
	assert_eq(own, str(ProjectSettings.get_setting("application/config/version", "")), "this build is the project version")
	assert_eq(ServerStatus.valid_version(own), own, "and is itself a valid version")

## #706 — the client's verdict on a host's hello: protocol first, then the build, args naming the host's then ours.
func _test_build_refusal() -> void:
	var n := ServerStatus.PROTOCOL_VERSION
	assert_eq(ServerStatus.build_refusal(n, "0.2.0", n, "0.2.0"), {}, "the same protocol and build play")
	var r := ServerStatus.build_refusal(n, "0.2.0", n, "0.3.0")
	assert_eq(str(r.get("key", "")), "menu.join.fail_version", "another build on the same protocol is refused")
	assert_eq(r.get("args", []), ["0.3.0", "0.2.0"], "naming the host's version, then this one's")
	r = ServerStatus.build_refusal(n, "0.2.0", n + 1, "0.3.0")
	assert_eq(str(r.get("key", "")), "menu.join.fail_protocol_newer", "another protocol keeps its own key")
	assert_eq(r.get("args", []), ["0.3.0", "0.2.0"], "and names both versions too")
	r = ServerStatus.build_refusal(n, "0.2.0", n, null)
	assert_eq(str(r.get("key", "")), "menu.join.fail_version", "a host that names no build is refused")
	assert_eq(r.get("args", []), ["?", "0.2.0"], "and shown as ?")
	assert_eq(ServerStatus.build_refusal(n, "0.2.0", n, "x".repeat(200)).get("args", []), ["?", "0.2.0"],
		"an oversized host version is never shown")
	var cats: Dictionary = I18n.parse_csv("res://locale/ui.csv")["catalog"]
	for loc in ["en", "pt_BR"]:
		var text := str((cats.get(loc, {}) as Dictionary).get("menu.join.fail_version", ""))
		assert_true(text.contains("{0}") and text.contains("{1}"), "%s names both versions" % loc)
	assert_eq(I18n.fill("v{0} / v{1}", ["0.3.0", "0.2.0"]), "v0.3.0 / v0.2.0", "the args fill the message in order")

## #706 — the host's side: an intent of this protocol but another build, or no build, or a build of another type or
## past the cap, is never acted on and is answered with a refusal that names the host's build.
func _test_build_wire() -> void:
	var was_quiet := Diag.quiet
	Diag.quiet = true
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	var joins: Array = []
	var on_join := func(peer: int, _claim: String) -> void: joins.append(peer)
	GameBus.player_join_intent.connect(on_join)
	var rosters: Array = []
	var on_roster := func(_op: String, _args: Dictionary, peer: int) -> void: rosters.append(peer)
	GameBus.character_roster_intent.connect(on_roster)
	var proto := ServerStatus.PROTOCOL_VERSION
	var before: int = n._m2.refused_total
	n._route_c2h(21, { "type": "join_intent", "claimed_id": "", "protocol": proto, "game_version": "0.0.0-forged" })
	n._route_c2h(22, { "type": "join_intent", "claimed_id": "", "protocol": proto })
	n._route_c2h(23, { "type": "roster_intent", "op": "list", "protocol": proto, "game_version": 7 })
	n._route_c2h(24, { "type": "roster_intent", "op": "list", "protocol": proto, "game_version": "x".repeat(10000) })
	assert_eq(joins, [], "a join of another, or no, build is not acted on")
	assert_eq(rosters, [], "nor a roster intent of a malformed build")
	assert_eq(n._m2.refused_total - before, 4, "each refused peer is counted")
	for p in [21, 22, 23, 24]:
		assert_true(n._m2._protocol_refused.has(p), "peer %d is marked to be dropped" % p)
	n._route_c2h(21, { "type": "join_intent", "claimed_id": "", "protocol": proto, "game_version": "0.0.0-forged" })
	assert_eq(n._m2.refused_total - before, 4, "a repeat from a marked peer is not answered again")
	n._route_c2h(25, { "type": "join_intent", "claimed_id": "", "protocol": proto, "game_version": ServerStatus.game_version() })
	assert_eq(joins, [25], "a join of this build goes on")
	GameBus.player_join_intent.disconnect(on_join)
	GameBus.character_roster_intent.disconnect(on_roster)
	# Client side: the host's refusal (or hello) of another build ends the join with both versions.
	n._role = NetworkingSlice.Role.CLIENT
	var refused: Array = []
	var on_refused := func(key: String, args: Array) -> void: refused.append([key, args])
	GameBus.join_refused.connect(on_refused)
	n._route_h2c({ "type": "server_hello", "protocol": proto, "game_version": "9.9.9" })
	assert_eq(refused, [["menu.join.fail_version", ["9.9.9", ServerStatus.game_version()]]], "a hello of another build ends the join")
	assert_true(n.is_offline(), "and the client leaves")
	n._role = NetworkingSlice.Role.CLIENT
	n._route_h2c({ "type": "server_hello", "protocol": proto })
	assert_eq(refused.size(), 2, "a hello that names no build ends it too")
	n._role = NetworkingSlice.Role.CLIENT
	n._route_h2c({ "type": "protocol_refused", "protocol": proto, "game_version": ServerStatus.game_version() })
	assert_eq(refused[-1][0], "menu.join.fail_protocol_older", "a refusal naming our own build still ends the join")
	GameBus.join_refused.disconnect(on_refused)
	remove_child(n)
	n.free()
	Diag.quiet = was_quiet

## #706 — the refusal reaches the menu as a key + both versions; the harness's menu client tells a build refusal
## (exit 2) from any other failure (exit 1) and a join (exit 0).
func _test_build_refusal_menu() -> void:
	var menu := MainMenu.new()
	add_child(menu)
	menu.show_notice("menu.join.fail_version", ["9.9.9", "0.2.0"])
	var text := menu.notice_text()
	assert_true(text.contains("9.9.9") and text.contains("0.2.0"), "the menu line names both versions: %s" % text)
	assert_false(text.contains("{0}") or text.contains("{1}"), "with no placeholder left")
	menu.show_notice("")
	assert_eq(menu.notice_text(), "", "an empty key hides the line")
	remove_child(menu)
	menu.free()
	assert_eq(MenuWiring.menu_join_exit_code(true, ""), 0, "a join exits 0")
	assert_eq(MenuWiring.menu_join_exit_code(false, "menu.join.fail_version"), MenuWiring.MENU_JOIN_BUILD_REFUSED, "a build refusal exits 2")
	assert_eq(MenuWiring.menu_join_exit_code(false, "menu.join.fail_protocol_newer"), MenuWiring.MENU_JOIN_BUILD_REFUSED, "so does a protocol one")
	assert_eq(MenuWiring.menu_join_exit_code(false, "menu.join.fail_unreachable"), 1, "anything else exits 1")
