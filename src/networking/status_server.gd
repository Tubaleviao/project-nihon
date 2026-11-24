extends Node
## Phase 297 — a host's status port: answers `ServerStatus` queries (LAN discovery, a Join screen's ping, the
## Happy Eyeballs pick) with the protocol version, game version, game port, world name and player counts.
##
## Untrusted input on an open UDP port, so: a malformed query, one shorter than the answer or longer than
## `ServerStatus.QUERY_MAX`, or of another format is dropped with no reply; each source address gets at most
## PER_ADDRESS answers per window and the port at most PER_WINDOW in all, so a flood (spoofed or not) costs the host
## a bounded number of fixed-size packets; the table of sources is capped and cleared every window.

const ServerStatus := preload("res://src/networking/server_status.gd")

const WINDOW_MS := 1000
const PER_ADDRESS := 4
const PER_WINDOW := 200
const MAX_SOURCES := 1024
## Datagrams read per frame at most, so a flood cannot stall the host's frame.
const MAX_READS_PER_POLL := 256

## () -> Dictionary: the live answer fields (see `ServerStatus.encode_answer`); `instance` is filled in here.
var info: Callable = Callable()
## Random per process: a host heard on both families is one row on a Join screen.
var instance: int = randi()
var answered: int = 0
var dropped: int = 0
var _udp: PacketPeerUDP = null
var _window_start: int = -WINDOW_MS
var _window_total: int = 0
var _per_source: Dictionary = {}

## Listen on `port` (`bind_address` "*" is dual-stack where the OS has IPv6). OK, or the bind error.
func start(port: int, bind_address: String = "*") -> Error:
	stop()
	_udp = PacketPeerUDP.new()
	var err := _udp.bind(port, bind_address)
	if err != OK:
		_udp = null
	return err

func stop() -> void:
	if _udp != null:
		_udp.close()
		_udp = null

func is_listening() -> bool:
	return _udp != null and _udp.is_bound()

func local_port() -> int:
	return _udp.get_local_port() if _udp != null else 0

func _process(_delta: float) -> void:
	poll()

func _exit_tree() -> void:
	stop()

## Read and answer what arrived. Returns how many answers went out.
func poll(now_ms: int = Time.get_ticks_msec()) -> int:
	if _udp == null:
		return 0
	var sent := 0
	var reads := 0
	while _udp.get_available_packet_count() > 0 and reads < MAX_READS_PER_POLL:
		reads += 1
		var packet := _udp.get_packet()
		var ip := _udp.get_packet_ip()
		var port := _udp.get_packet_port()
		var answer := handle(packet, ip, now_ms)
		if answer.is_empty():
			continue
		_udp.set_dest_address(ip, port)
		if _udp.put_packet(answer) == OK:
			sent += 1
	return sent

## The answer to `packet` from `source_ip`, or empty when it gets none (malformed, rate-limited). Pure except for
## the rate-limit table, so the suite drives it without a socket.
func handle(packet: PackedByteArray, source_ip: String, now_ms: int) -> PackedByteArray:
	var nonce := ServerStatus.decode_query(packet)
	if nonce < 0 or source_ip.is_empty():
		dropped += 1
		return PackedByteArray()
	if not _admit(source_ip, now_ms):
		dropped += 1
		return PackedByteArray()
	var fields: Dictionary = (info.call() as Dictionary).duplicate() if info.is_valid() else {}
	fields["instance"] = instance
	answered += 1
	return ServerStatus.encode_answer(nonce, fields)

func _admit(source_ip: String, now_ms: int) -> bool:
	if now_ms - _window_start >= WINDOW_MS:
		_window_start = now_ms
		_window_total = 0
		_per_source.clear()
	if _window_total >= PER_WINDOW:
		return false
	var n := int(_per_source.get(source_ip, 0))
	if n >= PER_ADDRESS:
		return false
	if n == 0 and _per_source.size() >= MAX_SOURCES:
		return false
	_per_source[source_ip] = n + 1
	_window_total += 1
	return true
