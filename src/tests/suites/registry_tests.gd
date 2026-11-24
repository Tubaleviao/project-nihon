extends "res://src/tests/test_support.gd"
## Phase 298 — the server list: the registry's table (back-probe, missed heartbeats, per-address cap and rate limit,
## an address in the body ignored), the wire (frames, caps, list codec and truncation), the registry over real
## loopback sockets, the Join screen's Public servers tab (rows, sort, filter, hide full, other version, cache), the
## boot flags and the registry list, and the catalog.

const RegistryWire := preload("res://src/networking/registry_wire.gd")
const RegistryTable := preload("res://src/networking/registry_table.gd")
const RegistryServer := preload("res://src/networking/registry_server.gd")
const RegistryClient := preload("res://src/networking/registry_client.gd")
const RegistryHeartbeat := preload("res://src/networking/registry_heartbeat.gd")
const RegistryList := preload("res://src/networking/registry_list.gd")
const StatusServer := preload("res://src/networking/status_server.gd")
const ServerStatus := preload("res://src/networking/server_status.gd")
const PublicServers := preload("res://src/menu/public_servers.gd")
const MainMenu := preload("res://src/menu/main_menu.gd")
const BootWiring := preload("res://src/core/boot_wiring.gd")
const MenuWiring := preload("res://src/menu/menu_wiring.gd")
const I18n := preload("res://src/core/i18n.gd")

const KEYS := ["menu.join.tab_direct", "menu.public.tab", "menu.public.filter", "menu.public.hide_full",
	"menu.public.sort_ping", "menu.public.sort_players", "menu.public.refresh", "menu.public.col_name",
	"menu.public.col_region", "menu.public.col_players", "menu.public.col_ping", "menu.public.col_version",
	"menu.public.players_value", "menu.public.ping_unknown", "menu.public.other_version", "menu.public.fetching",
	"menu.public.none", "menu.public.none_match", "menu.public.no_registries", "menu.public.error_fetch",
	"menu.public.error_socket", "menu.public.no_answer", "menu.public.registries", "menu.public.registries_save", "menu.world.public",
	"menu.region.none"]

func register() -> void:
	_run_test("registry: an entry is listed only after its host answers the back-probe from the heartbeat's source", _test_back_probe)
	_run_test("registry: an address in the heartbeat body is ignored", _test_body_address_ignored)
	_run_test("registry: an entry that missed three heartbeats is dropped", _test_missed_heartbeats)
	_run_test("registry: servers per address are capped and heartbeats rate-limited", _test_caps)
	_run_test("registry: a new status port is probed again before the entry is listed again", _test_status_port_change)
	_run_test("registry: frames are size-capped and a malformed body is refused", _test_frames)
	_run_test("registry: the heartbeat decoder keeps only well-formed fields", _test_heartbeat_codec)
	_run_test("registry: the list codec round-trips; a list over the cap is truncated, not trusted", _test_list_codec)
	_run_test("registry: the registry answers heartbeats, list queries and junk", _test_handle)
	_run_test("registry: a host heartbeats to a registry on loopback, is back-probed and listed, and a client fetches it", _test_loopback)
	_run_test("registry: the public tab's rows: one per host, sort, filter, hide full, other version", _test_public_rows)
	_run_test("registry: the public list is cached on disk and read back as untrusted", _test_public_cache)
	_run_test("registry: the Join page's Public servers tab shows the rows and a row joins on click", _test_public_tab)
	_run_test("registry: --registry, --public, --region and --save-dir; Show in server list on a listen host", _test_boot_flags)
	_run_test("registry: the registry list: --registries, then the saved list, then the repository's seed", _test_registry_list)
	_run_test("registry: every new string is in both catalogs", _test_catalog)

func _hb(game_port: int = 7000, status_port: int = 7001, extra: Dictionary = {}) -> Dictionary:
	var m := RegistryWire.heartbeat({ "game_port": game_port, "status_port": status_port, "world_name": "Alpha",
		"region": "sa", "players": 2, "max_players": 8 })
	m.merge(extra, true)
	return m

func _status(game_port: int = 7000, instance: int = 1, players: int = 2, protocol: int = ServerStatus.PROTOCOL_VERSION) -> Dictionary:
	return { "nonce": 1, "protocol": protocol, "game_port": game_port, "players": players, "max_players": 8,
		"instance": instance, "game_version": "0.2.0", "world_name": "Alpha" }

## The back-probes due now, each reported sent (what the registry's prober does when its socket takes them).
func _due(t: RegistryTable, now_ms: int) -> Array:
	var due := t.probe_due()
	for p in due:
		t.probe_sent(str(p["key"]), now_ms)
	return due

func _test_back_probe() -> void:
	var t := RegistryTable.new()
	var r := t.heartbeat("203.0.113.5", _hb(), 0)
	assert_true(bool(r["ok"]) and not bool(r["listed"]), "a first heartbeat is accepted but not listed")
	assert_eq(t.listed(), [], "nothing is listed before the back-probe")
	var due := _due(t, 10)
	assert_eq(due.size(), 1, "one back-probe is due")
	assert_eq([due[0]["ip"], due[0]["status_port"]], ["203.0.113.5", 7001], "to the heartbeat's source IP and status port")
	assert_eq(_due(t, 20), [], "and it is sent once")
	var key := str(due[0]["key"])
	assert_false(t.probe_answered(key, "198.51.100.9", _status()), "an answer from another IP does not list it")
	assert_false(t.probe_answered(key, "203.0.113.5", _status(7100)), "nor one naming another game port")
	assert_true(t.probe_answered(key, "203.0.113.5", _status()), "the host's own answer lists it")
	assert_eq(t.listed().size(), 1, "and it is in the list")
	assert_true(bool(t.heartbeat("203.0.113.5", _hb(), 1000)["listed"]), "the next heartbeat's reply says listed")
	# An unanswered back-probe drops the unverified entry at once; the next heartbeat starts over.
	t.heartbeat("203.0.113.6", _hb(), 2000)
	_due(t, 2000)
	assert_eq(t.pending_count(), 1, "an unverified entry is pending")
	assert_eq(t.sweep(2000 + RegistryTable.PROBE_TIMEOUT_MS + 1).size(), 1, "an unanswered back-probe drops it")
	assert_eq(t.pending_count(), 0, "and frees its pending slot")
	t.heartbeat("203.0.113.6", _hb(), 2000 + RegistryTable.PROBE_TIMEOUT_MS + 2)
	assert_eq(_due(t, 2000 + RegistryTable.PROBE_TIMEOUT_MS + 3).size(), 1, "the next heartbeat is probed again")
	# A probe the socket could not send stays due.
	var u := RegistryTable.new()
	u.heartbeat("203.0.113.8", _hb(), 0)
	assert_eq(u.probe_due().size(), 1, "due")
	assert_eq(u.probe_due().size(), 1, "and still due while nobody reported it sent")
	# The list's counts are the status answer's, never the heartbeat body's.
	var w := RegistryTable.new()
	w.heartbeat("203.0.113.9", _hb(7000, 7001, { "players": 65535, "max_players": 65535 }), 0)
	w.probe_answered(str(_due(w, 0)[0]["key"]), "203.0.113.9", _status(7000, 1, 3))
	assert_eq([int(w.listed()[0]["players"]), int(w.listed()[0]["max_players"])], [3, 8], "the listed counts are the back-probe's")
	w.heartbeat("203.0.113.9", _hb(7000, 7001, { "players": 65535 }), 1000)
	assert_eq(w.listed().size(), 1, "a listed entry stays listed while its counts are re-asked")
	var re := _due(w, 1000)
	assert_eq(re.size(), 1, "each heartbeat of a listed entry asks its status port again")
	w.probe_answered(str(re[0]["key"]), "203.0.113.9", _status(7000, 1, 5))
	assert_eq(int(w.listed()[0]["players"]), 5, "and takes the fresh counts")
	_due(w, 2000)
	w.heartbeat("203.0.113.9", _hb(), 2000)
	_due(w, 2000)
	w.sweep(2000 + RegistryTable.PROBE_TIMEOUT_MS + 1)
	assert_eq(w.listed().size(), 1, "a listed entry whose refresh probe times out keeps its place until its heartbeats stop")

func _test_body_address_ignored() -> void:
	var t := RegistryTable.new()
	t.heartbeat("203.0.113.5", _hb(7000, 7001, { "ip": "8.8.8.8", "address": "8.8.8.8", "host": "8.8.8.8" }), 0)
	var due := _due(t, 0)
	assert_eq(str(due[0]["ip"]), "203.0.113.5", "the back-probe goes to the connection's source, not the body's IP")
	t.probe_answered(str(due[0]["key"]), "203.0.113.5", _status())
	assert_eq(str(t.listed()[0]["ip"]), "203.0.113.5", "the listed IP is the source")
	assert_eq(t.count_for("8.8.8.8"), 0, "the body's IP gets no entry")
	assert_false(RegistryWire.decode_heartbeat(_hb(7000, 7001, { "ip": "8.8.8.8" })).has("ip"), "the decoder drops it")

func _test_missed_heartbeats() -> void:
	var t := RegistryTable.new()
	t.heartbeat("203.0.113.5", _hb(), 0)
	t.probe_answered(str(_due(t, 0)[0]["key"]), "203.0.113.5", _status())
	var interval := RegistryWire.HEARTBEAT_S * 1000
	t.heartbeat("203.0.113.5", _hb(), interval)
	assert_eq(t.sweep(interval + 2 * interval).size(), 0, "two missed heartbeats keep the entry")
	assert_eq(t.listed().size(), 1, "still listed")
	var gone := t.sweep(interval + t.drop_after_ms() + 1)
	assert_eq(gone.size(), 1, "the third missed heartbeat drops it")
	assert_eq(t.listed(), [], "and it leaves the list")
	assert_true(t.drop_after_ms() <= 3 * interval + 5000, "within the three intervals plus a short grace")

func _test_caps() -> void:
	var t := RegistryTable.new()
	for i in RegistryTable.MAX_PER_ADDRESS:
		assert_true(bool(t.heartbeat("203.0.113.5", _hb(7000 + 2 * i, 7001 + 2 * i), 0)["ok"]), "server %d from one address" % i)
	var r := t.heartbeat("203.0.113.5", _hb(7100, 7101), 0)
	assert_eq(str(r.get("code", "")), "address_full", "one more from the same address is refused")
	assert_true(bool(t.heartbeat("203.0.113.6", _hb(), 0)["ok"]), "another address is not affected")
	var u := RegistryTable.new()
	var refused := 0
	for i in RegistryTable.HEARTBEATS_PER_WINDOW + 5:
		if str(u.heartbeat("203.0.113.7", _hb(), 0).get("code", "")) == "rate_limited":
			refused += 1
	assert_eq(refused, 5, "heartbeats past the per-address rate are refused")
	assert_true(bool(u.heartbeat("203.0.113.7", _hb(), RegistryWire.HEARTBEAT_S * 1000)["ok"]), "the next window admits again")
	assert_eq(str(u.heartbeat("not-an-ip", _hb(), 0).get("code", "")), "malformed", "a source that is no IP is refused")
	# IPv6: one /64 is one address, so rotating the low bits buys nothing.
	assert_eq(RegistryTable.bucket("2001:db8:1:2::5"), RegistryTable.bucket("2001:0db8:0001:0002:ffff:1:2:3"), "one /64 is one bucket")
	assert_true(RegistryTable.bucket("2001:db8:1:2::5") != RegistryTable.bucket("2001:db8:1:3::5"), "another /64 is another")
	assert_eq(RegistryTable.bucket("0:0:0:0:0:0:0:1"), RegistryTable.bucket("::1"), "expanded and compressed forms agree")
	assert_eq(RegistryTable.bucket("::ffff:203.0.113.5"), "203.0.113.5", "an IPv4-mapped address counts as its IPv4 address")
	var v := RegistryTable.new()
	var ok := 0
	for i in 40:
		if bool(v.heartbeat("2001:db8:1:2::%x" % (i + 1), _hb(7000 + 2 * (i % 4), 7001), 0)["ok"]):
			ok += 1
	assert_eq(ok, RegistryTable.MAX_PER_ADDRESS, "a /64 gets the per-address cap however many addresses it uses")
	# Unverified entries have their own cap, below the table's.
	var x := RegistryTable.new()
	var full := ""
	for i in RegistryTable.MAX_PENDING + 1:
		var r2 := x.heartbeat("10.%d.%d.1" % [i / 250, i % 250], _hb(), 0)
		if not bool(r2["ok"]):
			full = str(r2["code"])
	assert_eq(x.pending_count(), RegistryTable.MAX_PENDING, "at most MAX_PENDING entries wait for their back-probe")
	assert_eq(full, "registry_full", "one more is refused")

func _test_status_port_change() -> void:
	var t := RegistryTable.new()
	t.heartbeat("203.0.113.5", _hb(), 0)
	t.probe_answered(str(_due(t, 0)[0]["key"]), "203.0.113.5", _status())
	t.heartbeat("203.0.113.5", _hb(7000, 7555), 100)
	assert_eq(t.listed(), [], "a heartbeat with a new status port unlists the entry")
	var due := _due(t, 100)
	assert_eq(int(due[0]["status_port"]), 7555, "and probes the new port")
	assert_true(t.probe_answered(str(due[0]["key"]), "203.0.113.5", _status()), "an answer there lists it again")

func _test_frames() -> void:
	var f := RegistryWire.frame({ "type": "list" })
	assert_eq([f[0], f[1], f[2]], [0, 0, 0], "the length is big-endian")
	var rd := RegistryWire.Reader.new(RegistryWire.MAX_REQUEST_BYTES)
	rd.push(f.slice(0, 3))
	assert_eq(rd.take(), {}, "half a frame is not a message")
	rd.push(f.slice(3))
	assert_eq(rd.take(), { "type": "list" }, "a whole frame is")
	var big := RegistryWire.Reader.new(16)
	big.push(PackedByteArray([0, 0, 1, 0]))
	assert_eq(big.wanted(), 0, "a frame over the cap asks for no more bytes")
	assert_eq(big.take(), {}, "and is not read")
	assert_eq(big.error, "oversize", "it is refused as oversize")
	assert_true(RegistryWire.frame({ "x": "a".repeat(RegistryWire.MAX_REQUEST_BYTES) }).is_empty(), "a request over the cap is never sent")
	var junk := RegistryWire.Reader.new(64)
	junk.push(PackedByteArray([0, 0, 0, 3]) + "[1]".to_utf8_buffer())
	junk.take()
	assert_eq(junk.error, "malformed", "a body that is not a JSON object is refused")

func _test_heartbeat_codec() -> void:
	var d := RegistryWire.decode_heartbeat(_hb())
	assert_eq([d["game_port"], d["status_port"], d["world_name"], d["region"], d["players"], d["max_players"]],
		[7000, 7001, "Alpha", "sa", 2, 8], "a heartbeat round-trips")
	for bad in [{ "type": "list" }, _hb(0, 7001), _hb(7000, 70000), _hb(7000, 7001, { "game_port": "7000" }),
			_hb(7000, 7001, { "status_port": 7001.5 })]:
		assert_eq(RegistryWire.decode_heartbeat(bad), {}, "a malformed heartbeat is refused: %s" % str(bad).left(60))
	var odd := RegistryWire.decode_heartbeat(_hb(7000, 7001, { "region": "moon", "world_name": "a\nb" + "x".repeat(300), "players": -4 }))
	assert_eq(str(odd["region"]), "", "an unknown region is none")
	assert_true(str(odd["world_name"]).to_utf8_buffer().size() <= ServerStatus.NAME_MAX_BYTES and not str(odd["world_name"]).contains("\n"),
		"a name is cleaned and cut to its cap")
	assert_eq(int(odd["players"]), 0, "a negative count is 0")

func _test_list_codec() -> void:
	var servers: Array = []
	for i in RegistryWire.MAX_LIST + 20:
		servers.append({ "ip": "10.0.%d.%d" % [i / 250, i % 250], "game_port": 7000, "status_port": 7001, "world_name": "W%d" % i,
			"region": "eu", "protocol": 1, "players": i % 9, "max_players": 8 })
	var reply := RegistryWire.list_reply(servers)
	assert_eq((reply["servers"] as Array).size(), RegistryWire.MAX_LIST, "a registry never sends more than the cap")
	var back := RegistryWire.decode_list(JSON.parse_string(JSON.stringify(reply)))
	assert_eq(back.size(), RegistryWire.MAX_LIST, "the list round-trips through JSON")
	assert_eq([back[3]["ip"], back[3]["game_port"], back[3]["world_name"], back[3]["region"]], ["10.0.0.3", 7000, "W3", "eu"], "with its fields")
	var hostile := { "type": "list", "servers": servers.duplicate() }
	hostile["servers"].append_array(servers)
	assert_eq(RegistryWire.decode_list(hostile).size(), RegistryWire.MAX_LIST, "a list over the cap is truncated")
	var junk := { "type": "list", "servers": [
		{ "ip": "example.org", "game_port": 7000, "status_port": 7001 },
		{ "ip": "fe80::1%eth0", "game_port": 7000, "status_port": 7001 },
		{ "ip": "10.0.0.1", "game_port": 0, "status_port": 7001 },
		"x", 5,
		{ "ip": "10.0.0.2", "game_port": 7000, "status_port": 7001, "world_name": 12 },
		{ "ip": "10.0.0.2", "game_port": 7000, "status_port": 7001 },
	] }
	var kept := RegistryWire.decode_list(junk)
	assert_eq(kept.size(), 1, "names, zones, port 0, non-objects and duplicates are dropped")
	assert_eq(str(kept[0]["world_name"]), "", "a name that is not text is empty")
	assert_eq(RegistryWire.decode_list({ "type": "list", "servers": "x" }), [], "a list that is not an array is empty")
	var fat: Array = []
	for i in RegistryWire.MAX_LIST:
		fat.append({ "ip": "2001:db8::%x" % i, "game_port": 7000, "status_port": 7001, "world_name": "ç".repeat(48),
			"region": "sa", "protocol": 1, "players": 1, "max_players": 2 })
	var fit := RegistryServer._fit_list(fat)
	assert_true(JSON.stringify(fit).to_utf8_buffer().size() <= RegistryWire.MAX_LIST_BYTES, "a list reply always fits its byte cap")
	assert_true((fit["servers"] as Array).size() > 0, "and keeps what fits")

func _test_handle() -> void:
	var reg := RegistryServer.new()
	var r := reg.handle("203.0.113.5", _hb(), 0)
	assert_eq([r["type"], r["listed"]], ["heartbeat_ok", false], "a heartbeat is acknowledged, not yet listed")
	assert_eq(reg.handle("203.0.113.5", { "type": "list" }, 0), RegistryWire.list_reply([]), "the list holds only verified servers")
	assert_eq(reg.handle("203.0.113.5", { "type": "nope" }, 0), { "type": "error", "code": "malformed" }, "junk gets an error")
	assert_eq(str(reg.handle("203.0.113.5", { "type": "heartbeat" }, 0)["code"]), "malformed", "a heartbeat with no ports too")
	var refused := 0
	for i in RegistryServer.LIST_PER_WINDOW + 3:
		if str(reg.handle("2001:db8::%x" % (i + 1), { "type": "list" }, 100).get("code", "")) == "rate_limited":
			refused += 1
	assert_eq(refused, 3, "list queries are rate-limited per address bucket (a /64 is one)")
	assert_eq(str(reg.handle("2001:db8::1", { "type": "list" }, 100 + RegistryServer.LIST_WINDOW_MS)["type"]), "list", "the next window admits again")
	var f1 := reg.reply_frame("198.51.100.1", { "type": "list" }, 0)
	var f2 := reg.reply_frame("198.51.100.2", { "type": "list" }, 0)
	assert_true(f1 == f2 and reg._list_version == reg.table.version, "the list reply is encoded once per table version")
	reg.free()

## A registry, a status port and a heartbeat on loopback, ticked by hand: the heartbeat is back-probed and listed,
## then a list query returns it. On 127.0.0.1, and on ::1 where the machine has it.
func _test_loopback() -> void:
	var families := ["127.0.0.1"]
	var v6 := PacketPeerUDP.new()
	if v6.bind(0, "::1") == OK:
		families.append("::1")
	v6.close()
	for addr in families:
		var reg := RegistryServer.new()
		var rport := 0
		for p in range(27900, 27960):
			if reg.start(p) == OK:
				rport = p
				break
		assert_true(rport > 0, "the registry listens")
		var status := StatusServer.new()
		var sport := 0
		for p in range(28000, 28060):
			if status.start(p) == OK:
				sport = p
				break
		status.info = func() -> Dictionary:
			return { "protocol": ServerStatus.PROTOCOL_VERSION, "game_port": 7000, "players": 1, "max_players": 4,
				"game_version": "0.2.0", "world_name": "Loop" }
		var hb := RegistryHeartbeat.new()
		hb.registries = [_addr(addr, rport)]
		hb.interval_ms = 300
		hb.info = func() -> Dictionary:
			var i: Dictionary = status.info.call()
			i["status_port"] = sport
			i["region"] = "sa"
			return i
		var deadline := Time.get_ticks_msec() + 6000
		while Time.get_ticks_msec() < deadline and reg.table.listed().is_empty():
			hb.poll()
			reg.poll()
			status.poll()
			OS.delay_msec(5)
		assert_eq(reg.table.listed().size(), 1, "on %s the host is listed after the back-probe" % addr)
		if not reg.table.listed().is_empty():
			var ip := str(reg.table.listed()[0]["ip"])
			assert_true(ip == addr or (addr == "::1" and ip == "0:0:0:0:0:0:0:1"), "under the heartbeat's source address (%s)" % ip)
		var client := RegistryClient.new()
		client.fetch_lists([_addr(addr, rport)])
		var got: Array = []
		deadline = Time.get_ticks_msec() + 4000
		while Time.get_ticks_msec() < deadline and got.is_empty():
			reg.poll()
			got = client.poll()
			OS.delay_msec(5)
		assert_eq(got.size(), 1, "the list query on %s finishes" % addr)
		if got.size() == 1:
			var list := RegistryWire.decode_list(got[0]["message"])
			assert_eq(list.size(), 1, "and returns the host")
			if list.size() == 1:
				assert_eq([list[0]["world_name"], list[0]["game_port"], list[0]["status_port"], list[0]["region"]],
					["Loop", 7000, sport, "sa"], "with its name, ports and region")
		# A connection that sends a frame over the cap is closed without a reply.
		var raw := StreamPeerTCP.new()
		raw.connect_to_host(addr, rport)
		deadline = Time.get_ticks_msec() + 2000
		while Time.get_ticks_msec() < deadline and raw.get_status() == StreamPeerTCP.STATUS_CONNECTING:
			raw.poll()
			reg.poll()
			OS.delay_msec(5)
		raw.put_data(PackedByteArray([0, 1, 0, 0]) + "x".repeat(2048).to_utf8_buffer())
		deadline = Time.get_ticks_msec() + 2000
		while Time.get_ticks_msec() < deadline and raw.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			reg.poll()
			raw.poll()
			OS.delay_msec(5)
		assert_true(raw.get_status() != StreamPeerTCP.STATUS_CONNECTED or raw.get_available_bytes() <= 0, "an oversized request gets no reply")
		assert_true(reg._open.is_empty(), "and its connection is dropped")
		raw.disconnect_from_host()
		hb.free()
		client.cancel()
		reg.stop()
		reg.free()
		status.stop()
		status.free()

static func _addr(host: String, port: int) -> String:
	return ("[%s]:%d" if host.contains(":") else "%s:%d") % [host, port]

func _entry(ip: String, name: String, players: int = 1, max_players: int = 8, region: String = "sa", protocol: int = ServerStatus.PROTOCOL_VERSION) -> Dictionary:
	return { "ip": ip, "game_port": 7000, "status_port": 7001, "world_name": name, "region": region, "protocol": protocol,
		"players": players, "max_players": max_players }

func _ans(ip: String, rtt: int, instance: int, name: String, players: int = 1, protocol: int = ServerStatus.PROTOCOL_VERSION) -> Dictionary:
	var st := _status(7000, instance, players, protocol)
	st["world_name"] = name
	return { "key": "", "ip": ip, "rtt_ms": rtt, "status": st }

func _test_public_rows() -> void:
	var ps := PublicServers.new()
	ps.apply_list([_entry("10.0.0.1", "Alpha", 3), _entry("2001:db8::1", "Alpha"), _entry("10.0.0.2", "Beta", 8, 8, "eu"),
		_entry("10.0.0.3", "Gamma", 0, 8, "na", ServerStatus.PROTOCOL_VERSION + 1), _entry("10.0.0.4", "Silent")])
	assert_true(ps.apply_answer("2001:db8::1|7000", _ans("2001:db8::1", 5, 11, "Alpha", 3)), "the IPv6 answer counts")
	assert_true(ps.apply_answer("10.0.0.1|7000", _ans("10.0.0.1", 9, 11, "Alpha", 3)), "the IPv4 answer counts")
	assert_true(ps.apply_answer("10.0.0.2|7000", _ans("10.0.0.2", 40, 22, "Beta", 8)), "Beta answers")
	assert_true(ps.apply_answer("10.0.0.3|7000", _ans("10.0.0.3", 20, 33, "Gamma", 0, ServerStatus.PROTOCOL_VERSION + 1)), "Gamma answers")
	assert_false(ps.apply_answer("10.0.0.4|7000", _ans("10.9.9.9", 1, 44, "Fake")), "an answer from another IP than the entry's is ignored")
	var rows := ps.rows()
	assert_eq(rows.map(func(r: Dictionary) -> String: return str(r["name"])), ["Alpha", "Gamma", "Beta", "Silent"],
		"one row per host, by ping, the silent one last")
	assert_eq(str(rows[0]["address"]), "10.0.0.1:7000", "a host heard on both families joins on IPv4")
	assert_false(bool(rows[1]["joinable"]), "another protocol cannot be joined")
	assert_eq(str(PublicServers.row_texts(rows[1])["version"]), I18n.t("menu.public.other_version"), "and is marked")
	assert_eq(str(PublicServers.row_texts(rows[3])["ping"]), I18n.t("menu.public.ping_unknown"), "no answer yet: the ping is unknown")
	assert_eq(str(PublicServers.row_texts(rows[0])["players"]), I18n.t("menu.public.players_value", ["3", "8"]), "players and the cap")
	assert_false(bool(rows[3]["joinable"]), "a server that never answered this client cannot be joined")
	assert_eq(str(rows[3]["refusal"]), "menu.public.no_answer", "and says why")
	# A server that copies another's instance does not hide or replace it.
	var cp := PublicServers.new()
	cp.apply_list([_entry("2001:db8::9", "Victim"), _entry("10.0.0.9", "Copycat")])
	cp.apply_answer("2001:db8::9|7000", _ans("2001:db8::9", 30, 55, "Victim"))
	cp.apply_answer("10.0.0.9|7000", _ans("10.0.0.9", 5, 55, "Copycat"))
	assert_eq(cp.rows().map(func(r: Dictionary) -> String: return str(r["address"])), ["10.0.0.9:7000", "[2001:db8::9]:7000"],
		"a copied instance with another answer keeps both rows")
	var by_players := ps.rows("", false, PublicServers.SORT_PLAYERS)
	assert_eq(str(by_players[0]["name"]), "Beta", "sorted by players, the busiest first")
	assert_eq(ps.rows("", true).map(func(r: Dictionary) -> String: return str(r["name"])).has("Beta"), false, "hide full drops a full server")
	assert_eq(ps.rows("gam").size(), 1, "the filter matches the name, any case")
	assert_eq(ps.rows(I18n.t("menu.region.eu").to_lower()).map(func(r: Dictionary) -> String: return str(r["name"])), ["Beta"], "or the region's label")
	ps.apply_list([_entry("10.0.0.2", "Beta", 8, 8, "eu")])
	assert_eq(ps.answers.keys(), ["10.0.0.2|7000"], "a server no longer listed loses its answer")
	ps.apply_list([])
	assert_eq(ps.notice, "menu.public.none", "an empty list says so")

func _test_public_cache() -> void:
	var path := "user://test_registry_cache.json"
	PublicServers.save_cache(path, [_entry("10.0.0.1", "Alpha")])
	var back := PublicServers.load_cache(path)
	assert_eq(back.size(), 1, "the cached list reads back")
	assert_eq(str(back[0]["world_name"]), "Alpha", "with its entries")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({ "servers": [{ "ip": "evil.example", "game_port": 1, "status_port": 2 }, _entry("10.0.0.5", "Ok")] }))
	f.close()
	assert_eq(PublicServers.load_cache(path).size(), 1, "a tampered cache keeps only well-formed entries")
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{nope")
	f.close()
	assert_eq(PublicServers.load_cache(path), [], "a corrupt cache is empty")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _test_public_tab() -> void:
	var settings := "user://test_registry_settings.json"
	var old_settings := RegistryList.settings_path
	RegistryList.settings_path = settings
	var menu := MainMenu.new()
	menu.recent_path = "user://test_registry_recent.json"
	menu.worlds_base = "user://test_registry_worlds/"
	menu.public_servers.cache_path = "user://test_registry_tab_cache.json"
	PublicServers.save_cache(menu.public_servers.cache_path, [_entry("10.0.0.1", "Alpha", 2), _entry("10.0.0.2", "Beta", 5)])
	add_child(menu)
	menu.show_page(MainMenu.PAGE_JOIN)
	menu.show_public_tab()
	assert_true(menu.public_servers.is_open(), "the tab opens the public list")
	assert_eq(menu.public_rows().size(), 2, "the cached list shows at once")
	assert_eq(menu.public_servers.notice, "menu.public.no_registries", "with no registry set, the tab says so")
	menu.public_servers.apply_answer("10.0.0.2|7000", _ans("10.0.0.2", 7, 2, "Beta", 5))
	menu.refresh_public_rows()
	assert_eq(menu._public_list.get_child_count(), 2, "one line per row")
	var first: HBoxContainer = menu._public_list.get_child(0)
	assert_eq((first.get_child(0) as Button).text, "Beta", "the answered server first (by ping)")
	assert_eq((first.get_child(3) as Label).text, I18n.t("menu.join.ping", ["7"]), "with its ping")
	assert_true((menu._public_list.get_child(1).get_child(0) as Button).disabled, "a server that has not answered cannot be clicked")
	assert_eq(menu.join_public(menu.public_rows()[1]), "menu.public.no_answer", "nor joined")
	menu.set_public_sort(PublicServers.SORT_PLAYERS)
	menu._public_filter.text = "bet"
	menu.refresh_public_rows()
	assert_eq(menu._public_list.get_child_count(), 1, "the filter narrows the table")
	var asked: Array = []
	menu.start_requested.connect(func(c: Dictionary) -> void: asked.append(c))
	(menu._public_list.get_child(0).get_child(0) as Button).emit_signal("pressed")
	assert_eq(asked.size(), 1, "a row joins on click")
	if asked.size() == 1:
		assert_eq(str(asked[0]["address"]), "10.0.0.2:7000", "on its address and game port")
		assert_eq(menu._address_edit.text, "10.0.0.2:7000", "which fills the address field")
	menu.save_registries("127.0.0.1:7700, bad address, 127.0.0.1:7700")
	assert_eq(RegistryList.saved(), ["127.0.0.1:7700"], "the tab saves the cleaned registry list")
	menu.show_page(MainMenu.PAGE_HOME)
	assert_false(menu.public_servers.is_open(), "leaving the page closes the public list")
	var recent := menu.recent_path
	remove_child(menu)
	menu.free()
	RegistryList.settings_path = old_settings
	for p in [settings, recent, "user://test_registry_tab_cache.json"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _test_boot_flags() -> void:
	assert_eq(BootWiring.registry_port(["--registry"]), RegistryWire.DEFAULT_PORT, "--registry alone takes the default port")
	assert_eq(BootWiring.registry_port(["--registry", "7801"]), 7801, "or the one named")
	assert_eq(BootWiring.registry_port(["--registry", "--x"]), RegistryWire.DEFAULT_PORT, "a following flag is not a port")
	assert_eq(BootWiring.registry_port(["--registry", "0"]), -1, "a bad port is refused")
	assert_eq(BootWiring.registry_port(["--server"]), 0, "no flag, no registry")
	assert_false(MenuWiring.should_show_main_menu(["--registry"]), "a registry boot skips the menu")
	assert_true(MenuWiring.should_show_main_menu(["--menu-public-join", "--registries", "127.0.0.1"]), "the harness's menu client opens it")
	var bw := BootWiring.new()
	bw.parse_host_args(PackedStringArray(["--public", "--region", "EU", "--save-dir", "user://saves/b/", "--port", "7010"]))
	assert_true(bw.public, "--public")
	assert_eq(bw.region, "eu", "--region is a known tag, any case")
	assert_eq(bw.save_dir, "user://saves/b/", "--save-dir under user://")
	var opts := bw.host_options({}, true)
	assert_true(bool(opts["public"]), "a --public dedicated server announces itself")
	assert_eq(str(opts["region"]), "eu", "with its region")
	var listen := bw.host_options({ "name": "Mine", "public": false }, false)
	assert_false(bool(listen["public"]), "a listen host follows its own tick box, not --public")
	assert_true(bool(bw.host_options({ "name": "Mine", "public": true }, false)["public"]), "ticked, it announces itself")
	var bad := BootWiring.new()
	bad.parse_host_args(PackedStringArray(["--region", "moon", "--save-dir", "user://../etc/"]))
	assert_eq([bad.region, bad.save_dir, bad.public], ["", "", false], "an unknown region and an escaping save folder are refused")
	for d in ["/tmp/x/", "user://", "user://a", "res://a/"]:
		assert_false(BootWiring.valid_save_dir(d), "'%s' is no save folder" % d)
	# The Play page's tick box rides the host choice into the world the boot reads.
	var menu := MainMenu.new()
	menu.worlds_base = "user://test_registry_worlds2/"
	add_child(menu)
	var made := menu.create_world("Pub")
	var asked: Array = []
	menu.start_requested.connect(func(c: Dictionary) -> void: asked.append(c))
	menu._public_check.button_pressed = true
	menu._region_pick.select(RegistryWire.REGIONS.find("eu"))
	menu.play_world(str(made.get("id", "")))
	assert_true(asked.size() == 1 and bool(asked[0].get("public", false)), "Show in server list rides the host choice")
	assert_true(asked.size() == 1 and str(asked[0].get("region", "")) == "eu", "with the region picked beside it")
	assert_eq(str(bw.host_options({ "name": "Mine", "public": true, "region": "eu" }, false)["region"]), "eu", "which the listen host announces")
	assert_eq(str(bw.host_options({ "name": "Mine", "region": "moon" }, false)["region"]), "", "an unknown one is none")
	remove_child(menu)
	menu.free()
	_remove_tree("user://test_registry_worlds2/")

func _remove_tree(dir: String) -> void:
	var abs := ProjectSettings.globalize_path(dir)
	var d := DirAccess.open(abs)
	if d == null:
		return
	for sub in d.get_directories():
		_remove_tree(dir + sub + "/")
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(abs)

func _test_registry_list() -> void:
	var settings := "user://test_registry_list.json"
	var old_settings := RegistryList.settings_path
	RegistryList.settings_path = settings
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings))
	assert_eq(RegistryList.seed_list(), RegistryList.clean(JSON.parse_string(FileAccess.get_file_as_string(RegistryList.SEED_PATH))["registries"]),
		"the repository's seed reads and cleans")
	assert_eq(RegistryList.current([]), RegistryList.seed_list(), "with nothing saved, the seed is the list")
	var f := FileAccess.open(settings, FileAccess.WRITE)
	f.store_string(JSON.stringify({ "locale": "pt_BR" }))
	f.close()
	RegistryList.save(["reg.example.org", "[::1]:7701", "http://x", "reg.example.org"])
	assert_eq(RegistryList.current([]), ["reg.example.org", "[::1]:7701"], "a saved list wins over the seed, cleaned")
	assert_eq(str(JSON.parse_string(FileAccess.get_file_as_string(settings))["locale"]), "pt_BR", "other settings are untouched")
	assert_eq(RegistryList.current(["--registries", "127.0.0.1:7800,10.0.0.1"]), ["127.0.0.1:7800", "10.0.0.1"], "--registries wins over both")
	RegistryList.save([])
	assert_eq(RegistryList.current([]), [], "a saved empty list means no public list")
	assert_eq(int(RegistryWire.parse_registry("reg.example.org")["port"]), RegistryWire.DEFAULT_PORT, "no port is the registry's default")
	assert_eq(int(RegistryWire.parse_registry("[::1]:7701")["port"]), 7701, "a named port is kept")
	assert_eq(int(RegistryWire.parse_registry("::1")["port"]), RegistryWire.DEFAULT_PORT, "a bare IPv6 literal carries no port")
	assert_eq(RegistryClient.families(["10.0.0.1", "2001:db8::1", "10.0.0.2", "2001:db8::2"]), ["2001:db8::1", "10.0.0.1"],
		"a heartbeat goes to one address of each family, IPv6 first")
	RegistryList.settings_path = old_settings
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings))

func _test_catalog() -> void:
	var cats: Dictionary = I18n.parse_csv("res://locale/ui.csv")["catalog"]
	var keys: Array = KEYS.duplicate()
	for r in RegistryWire.REGIONS:
		if str(r) != "":
			keys.append("menu.region." + str(r))
	for loc in ["en", "pt_BR"]:
		for k: String in keys:
			assert_true(str((cats.get(loc, {}) as Dictionary).get(k, "")).strip_edges() != "", "%s has %s" % [loc, k])
