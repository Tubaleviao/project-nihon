extends RefCounted
## Phase 297 — the client half of the status query: one UDP socket that asks hosts for their status and times the
## answers. The Join screen uses it for LAN discovery ("On this network") and for the ping beside each recent
## server; the client boot uses it to pick IPv6 or IPv4 for a host name with both (`ServerConnector`).
##
## An answer counts only when it echoes the nonce of a query this probe sent in the last QUERY_TTL_MS, so a stray
## or spoofed datagram never becomes a row. Host names are resolved off the main thread (`IP`'s resolver queue).

const ServerStatus := preload("res://src/networking/server_status.gd")
const NetAddress := preload("res://src/networking/net_address.gd")

## LAN discovery's targets: IPv4 broadcast and IPv6 all-nodes. Godot's sockets carry no IPv6 scope id (checked on
## 4.7: `ff02::1%<iface>` is accepted and the zone dropped), so the multicast query goes out once, on the OS's
## default multicast interface, rather than once per interface.
const LAN_TARGETS := ["255.255.255.255", "ff02::1"]
const QUERY_TTL_MS := 5000
const MAX_PENDING := 256
const MAX_READS_PER_POLL := 128
## The most LAN rows one discovery keeps (each answer names its own instance, so a flood cannot grow the list).
const MAX_LAN_ROWS := 32

var _udp: PacketPeerUDP = null
var _rng := RandomNumberGenerator.new()
## nonce → {key, at, port}
var _sent: Dictionary = {}
## resolver id → {key, port}
var _resolving: Dictionary = {}

## Open the socket (an ephemeral port, both families, broadcast allowed). OK or the bind error.
func open() -> Error:
	close()
	_rng.randomize()
	_udp = PacketPeerUDP.new()
	_udp.set_broadcast_enabled(true)
	var err := _udp.bind(0, "*")
	if err != OK:
		_udp = null
	return err

func close() -> void:
	if _udp != null:
		_udp.close()
		_udp = null
	for id in _resolving:
		IP.erase_resolve_item(int(id))
	_resolving.clear()
	_sent.clear()

func is_open() -> bool:
	return _udp != null

## Ask `ip` (a literal) on `status_port`; answers come back from `poll` tagged `key`. False when nothing was sent.
func query_ip(ip: String, status_port: int, key: String, now_ms: int = Time.get_ticks_msec()) -> bool:
	if _udp == null or status_port <= 0 or not ip.is_valid_ip_address() or _sent.size() >= MAX_PENDING:
		return false
	var nonce := int(_rng.randi())
	while _sent.has(nonce):
		nonce = int(_rng.randi())
	if _udp.set_dest_address(ip, status_port) != OK:
		return false
	if _udp.put_packet(ServerStatus.encode_query(nonce)) != OK:
		return false
	_sent[nonce] = { "key": key, "at": now_ms }
	return true

## Ask a player-typed address (`NetAddress` rules) on its game port + 1. A host name is resolved first, without
## blocking; its query goes out from a later `poll`.
func query_address(address: String, key: String, now_ms: int = Time.get_ticks_msec()) -> bool:
	var a := NetAddress.parse(address)
	if not bool(a["ok"]) or _udp == null:
		return false
	var status_port := ServerStatus.default_status_port(int(a["port"]))
	if str(a["family"]) != NetAddress.FAMILY_NAME:
		return query_ip(str(a["host"]), status_port, key, now_ms)
	var id := IP.resolve_hostname_queue_item(str(a["host"]), IP.TYPE_ANY)
	if id == IP.RESOLVER_INVALID_ID:
		return false
	_resolving[id] = { "key": key, "port": status_port }
	return true

## LAN discovery: the status query to the broadcast address and the all-nodes group on `status_port`.
func discover(status_port: int, key: String = "lan", targets: Array = LAN_TARGETS, now_ms: int = Time.get_ticks_msec()) -> int:
	var n := 0
	for t in targets:
		if query_ip(str(t), status_port, key, now_ms):
			n += 1
	return n

## What arrived since the last call: [{key, ip, rtt_ms, status, at}] (status as `ServerStatus.decode_answer`).
func poll(now_ms: int = Time.get_ticks_msec()) -> Array:
	var out: Array = []
	if _udp == null:
		return out
	_poll_resolver(now_ms)
	var reads := 0
	while _udp.get_available_packet_count() > 0 and reads < MAX_READS_PER_POLL:
		reads += 1
		var packet := _udp.get_packet()
		var ip := _udp.get_packet_ip()
		var status := ServerStatus.decode_answer(packet)
		if status.is_empty() or not _sent.has(int(status["nonce"])):
			continue
		var q: Dictionary = _sent[int(status["nonce"])]
		out.append({ "key": str(q["key"]), "ip": ip, "rtt_ms": maxi(0, now_ms - int(q["at"])), "status": status, "at": now_ms })
	for nonce in _sent.keys():
		if now_ms - int(_sent[nonce]["at"]) > QUERY_TTL_MS:
			_sent.erase(nonce)
	return out

func _poll_resolver(now_ms: int) -> void:
	for id in _resolving.keys():
		var st := IP.get_resolve_item_status(int(id))
		if st == IP.RESOLVER_STATUS_WAITING:
			continue
		var job: Dictionary = _resolving[id]
		_resolving.erase(id)
		if st == IP.RESOLVER_STATUS_DONE:
			var addrs := IP.get_resolve_item_addresses(int(id))
			if not addrs.is_empty():
				query_ip(str(addrs[0]), int(job["port"]), str(job["key"]), now_ms)
		IP.erase_resolve_item(int(id))

## LAN rows from answers: one per host `instance` (a host heard on IPv4 and IPv6 is one row, joined on its IPv4
## address, which needs no IPv6 scope), with the best round trip and when it last answered (`at`, the probe's clock).
## `rows` is updated in place, keyed by instance. At MAX_LAN_ROWS a new host replaces the slowest row only when it
## answered faster, so a flood of made-up instances cannot freeze the list against real hosts nearby.
static func merge_lan_row(rows: Dictionary, answer: Dictionary) -> void:
	var status: Dictionary = answer["status"]
	var inst := int(status["instance"])
	var ip := str(answer["ip"])
	var rtt := int(answer["rtt_ms"])
	var at := int(answer.get("at", 0))
	var row: Dictionary = rows.get(inst, {})
	if row.is_empty():
		if rows.size() >= MAX_LAN_ROWS:
			var worst: Variant = null
			for k in rows:
				if worst == null or int(rows[k]["rtt_ms"]) > int(rows[worst]["rtt_ms"]):
					worst = k
			if rtt >= int(rows[worst]["rtt_ms"]):
				return
			rows.erase(worst)
		rows[inst] = { "ip": ip, "rtt_ms": rtt, "status": status, "seen": at }
		return
	row["rtt_ms"] = mini(int(row["rtt_ms"]), rtt)
	row["status"] = status
	row["seen"] = maxi(int(row.get("seen", 0)), at)
	if NetAddress.is_v6(str(row["ip"])) and not NetAddress.is_v6(ip):
		row["ip"] = ip

## Drop the rows that have not answered since `now_ms - stale_ms` (a host that shut down leaves the list). True when
## any row went.
static func drop_stale_rows(rows: Dictionary, now_ms: int, stale_ms: int) -> bool:
	var gone := false
	for k in rows.keys():
		if now_ms - int(rows[k].get("seen", 0)) > stale_ms:
			rows.erase(k)
			gone = true
	return gone
