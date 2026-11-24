extends Node
## Phase 298 — the registry: a headless boot role (`--registry [port]`) that keeps the table of public servers and
## answers list queries. Same Godot build as the game, no second stack.
##
## TCP on `port` (dual-stack): each connection carries one request — a host's heartbeat or a client's list query —
## and one reply (`RegistryWire`). Untrusted input on an open port, so: at most MAX_CONNECTIONS open at once and
## MAX_PER_IP from one address bucket (an IPv4 address or an IPv6 /64; more are closed unread), every frame
## size-capped, every exchange on a deadline, list queries rate-limited per bucket and their reply encoded once per
## table change. The
## back-probe (`RegistryTable`) goes out from one UDP socket (`ServerProbe`), so an entry is listed only once the
## host at the heartbeat's source IP answered on its status port.

const RegistryWire := preload("res://src/networking/registry_wire.gd")
const RegistryTable := preload("res://src/networking/registry_table.gd")
const RegistryExchange := preload("res://src/networking/registry_exchange.gd")
const ServerProbe := preload("res://src/networking/server_probe.gd")

const MAX_CONNECTIONS := 64
const MAX_PER_IP := 4
## Connections taken per frame at most, so a connect flood cannot stall the frame.
const MAX_ACCEPTS_PER_POLL := 32

var table := RegistryTable.new()
var _server: TCPServer = null
var _probe: ServerProbe = null
## Open exchanges: [RegistryExchange]
var _open: Array = []
var _last_sweep_ms: int = 0
const LIST_WINDOW_MS := 10000
const LIST_PER_WINDOW := 20
var _list_window_start: int = -LIST_WINDOW_MS
var _list_rate: Dictionary = {}
var _list_frame := PackedByteArray()
var _list_version: int = -1

## Listen on `port` (`bind_address` "*" is dual-stack). OK, or the error that stopped it.
func start(port: int, bind_address: String = "*") -> Error:
	stop()
	_server = TCPServer.new()
	var err := _server.listen(port, bind_address)
	if err != OK:
		_server = null
		return err
	_probe = ServerProbe.new()
	err = _probe.open()
	if err != OK:
		stop()
		return err
	print("[Registry] listening on port %d" % port)
	return OK

func stop() -> void:
	for x in _open:
		x.close()
	_open.clear()
	if _server != null:
		_server.stop()
		_server = null
	if _probe != null:
		_probe.close()
		_probe = null

func is_listening() -> bool:
	return _server != null and _server.is_listening()

func local_port() -> int:
	return _server.get_local_port() if _server != null else 0

func _process(_delta: float) -> void:
	poll()

func _exit_tree() -> void:
	stop()

func poll(now_ms: int = Time.get_ticks_msec()) -> void:
	if _server == null:
		return
	_accept(now_ms)
	for x in _open.duplicate():
		var was_pending: bool = x.state == RegistryExchange.PENDING
		x.poll(now_ms)
		if was_pending and x.state == RegistryExchange.DONE:
			x.reply_frame(reply_frame(x.peer_ip, x.message, now_ms))
			x.poll(now_ms)
		if x.finished():
			x.close()
			_open.erase(x)
	for p in table.probe_due():
		if _probe.query_ip(str(p["ip"]), int(p["status_port"]), str(p["key"]), now_ms):
			table.probe_sent(str(p["key"]), now_ms)
		else:
			break   # the probe's pending table is full: the rest stay due for a later frame
	for ans in _probe.poll(now_ms):
		if table.probe_answered(str(ans["key"]), str(ans["ip"]), ans["status"]):
			print("[Registry] listed %s (%s)" % [str(ans["key"]), str(ans["status"]["world_name"])])
	if now_ms - _last_sweep_ms >= 1000:
		_last_sweep_ms = now_ms
		for key in table.sweep(now_ms):
			print("[Registry] dropped %s" % str(key))

## The reply to one request from `ip`. Pure apart from the table and the list-query rate limit, so the suite drives
## it without sockets.
func handle(ip: String, msg: Dictionary, now_ms: int) -> Dictionary:
	match str(msg.get("type", "")):
		"heartbeat":
			var r := table.heartbeat(ip, msg, now_ms)
			if not bool(r["ok"]):
				return { "type": "error", "code": str(r["code"]) }
			return { "type": "heartbeat_ok", "listed": bool(r["listed"]), "interval_s": table.interval_s }
		"list":
			if not _admit_list(ip, now_ms):
				return { "type": "error", "code": "rate_limited" }
			return _fit_list(table.listed())
	return { "type": "error", "code": "malformed" }

## The encoded reply. A list reply is encoded once per table version and reused, so list queries cost a copy, not a
## sort and an encode each.
func reply_frame(ip: String, msg: Dictionary, now_ms: int) -> PackedByteArray:
	var reply := handle(ip, msg, now_ms)
	if str(reply.get("type", "")) != "list":
		return RegistryWire.frame(reply)
	if _list_frame.is_empty() or _list_version != table.version:
		_list_frame = RegistryWire.frame(reply, RegistryWire.MAX_LIST_BYTES)
		_list_version = table.version
	return _list_frame

## At most LIST_PER_WINDOW list queries per address bucket per LIST_WINDOW_MS: a client asks every 15 s, so this is
## generous for players behind one NAT and bounds what one source can pull.
func _admit_list(ip: String, now_ms: int) -> bool:
	if now_ms - _list_window_start >= LIST_WINDOW_MS:
		_list_window_start = now_ms
		_list_rate.clear()
	var b := RegistryTable.bucket(ip)
	var n := int(_list_rate.get(b, 0))
	if n >= LIST_PER_WINDOW or (n == 0 and _list_rate.size() >= RegistryTable.MAX_RATE_SOURCES):
		return false
	_list_rate[b] = n + 1
	return true

## The list reply, trimmed until its frame fits MAX_LIST_BYTES (long names on many entries).
static func _fit_list(servers: Array) -> Dictionary:
	var n := mini(servers.size(), RegistryWire.MAX_LIST)
	while true:
		var reply := RegistryWire.list_reply(servers.slice(0, n))
		if n == 0 or JSON.stringify(reply).to_utf8_buffer().size() <= RegistryWire.MAX_LIST_BYTES:
			return reply
		n = n * 3 / 4
	return {}

func _accept(now_ms: int) -> void:
	var taken := 0
	while _server.is_connection_available() and taken < MAX_ACCEPTS_PER_POLL:
		taken += 1
		var tcp := _server.take_connection()
		if tcp == null:
			break
		var ip := tcp.get_connected_host()
		if _open.size() >= MAX_CONNECTIONS or _open_from(RegistryTable.bucket(ip)) >= MAX_PER_IP:
			tcp.disconnect_from_host()
			continue
		_open.append(RegistryExchange.accept(tcp, RegistryWire.MAX_REQUEST_BYTES, now_ms))

## Open connections from the address bucket `b` (an IPv4 address or an IPv6 /64).
func _open_from(b: String) -> int:
	var n := 0
	for x in _open:
		if RegistryTable.bucket(x.peer_ip) == b:
			n += 1
	return n
