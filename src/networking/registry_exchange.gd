extends RefCounted
## Phase 298 — one request and one reply over a TCP connection, in either direction, polled without blocking.
##
## The client side (`dial`) connects to an IP literal, sends its request and reads one reply frame; the server side
## (`accept`) wraps a connection a `TCPServer` took, reads one request frame and later sends `reply`. Either side
## fails on the deadline (`RegistryWire.EXCHANGE_TIMEOUT_MS`), a frame over its cap, a malformed body or a closed
## connection. Reads are bounded by the frame's declared length, so a peer cannot make it buffer more than the cap.

const RegistryWire := preload("res://src/networking/registry_wire.gd")

const PENDING := 0
const DONE := 1
const FAILED := 2

var state: int = PENDING
## The message read (the request on the server side, the reply on the client side) once DONE.
var message: Dictionary = {}
## Why it FAILED: "timeout", "connect", "closed", "oversize", "malformed".
var error: String = ""
var peer_ip: String = ""
var _tcp: StreamPeerTCP = null
var _reader: RefCounted = null
var _out := PackedByteArray()
var _deadline_ms: int = 0
var _server_side: bool = false
var _replied: bool = false

## Client: connect to `ip`:`port`, send `request`, expect a reply of at most `reply_cap` bytes.
static func dial(ip: String, port: int, request: Dictionary, reply_cap: int, now_ms: int = Time.get_ticks_msec()) -> RefCounted:
	var x: RefCounted = (load("res://src/networking/registry_exchange.gd") as GDScript).new()
	x._start_dial(ip, port, request, reply_cap, now_ms)
	return x

## Server: a connection `TCPServer.take_connection` returned; reads one request of at most `request_cap` bytes.
static func accept(tcp: StreamPeerTCP, request_cap: int, now_ms: int = Time.get_ticks_msec()) -> RefCounted:
	var x: RefCounted = (load("res://src/networking/registry_exchange.gd") as GDScript).new()
	x._server_side = true
	x._tcp = tcp
	x.peer_ip = tcp.get_connected_host()
	x._reader = RegistryWire.Reader.new(request_cap)
	x._deadline_ms = now_ms + RegistryWire.EXCHANGE_TIMEOUT_MS
	return x

func _start_dial(ip: String, port: int, request: Dictionary, reply_cap: int, now_ms: int) -> void:
	peer_ip = ip
	_deadline_ms = now_ms + RegistryWire.EXCHANGE_TIMEOUT_MS
	_reader = RegistryWire.Reader.new(reply_cap)
	_out = RegistryWire.frame(request)
	_tcp = StreamPeerTCP.new()
	if _out.is_empty() or not ip.is_valid_ip_address() or _tcp.connect_to_host(ip, port) != OK:
		_fail("connect")

## Server side, once the request is in: send `reply` and close when it is written.
func reply(msg: Dictionary, cap: int = RegistryWire.MAX_REQUEST_BYTES) -> void:
	if not _server_side or _replied:
		return
	_replied = true
	_out = RegistryWire.frame(msg, cap)
	if _out.is_empty():
		_fail("oversize")

## Advance: connect, write what is queued, read what arrived. Returns `state`.
func poll(now_ms: int = Time.get_ticks_msec()) -> int:
	if state == FAILED or (state == DONE and _out.is_empty()):
		return state
	if now_ms > _deadline_ms:
		_fail("timeout")
		return state
	_tcp.poll()
	var st := _tcp.get_status()
	if st == StreamPeerTCP.STATUS_CONNECTING:
		return state
	if st != StreamPeerTCP.STATUS_CONNECTED:
		if state == DONE:
			_out.clear()
		else:
			_fail("closed" if st == StreamPeerTCP.STATUS_NONE else "connect")
		return state
	if not _out.is_empty():
		var sent: Array = _tcp.put_partial_data(_out)
		if int(sent[0]) != OK:
			_fail("closed")
			return state
		_out = _out.slice(int(sent[1]))
		if _out.is_empty() and _server_side and _replied:
			close()
			return state
	if state == PENDING:
		var want: int = _reader.wanted()
		var avail := _tcp.get_available_bytes()
		while avail > 0 and want > 0 and _reader.error == "":
			var got: Array = _tcp.get_partial_data(mini(avail, want))
			if int(got[0]) != OK:
				_fail("closed")
				return state
			_reader.push(got[1])
			want = _reader.wanted()
			avail = _tcp.get_available_bytes()
		if _reader.error != "":
			_fail(_reader.error)
			return state
		var msg: Dictionary = _reader.take()
		if _reader.error != "":
			_fail(_reader.error)
		elif not msg.is_empty():
			message = msg
			state = DONE
			if not _server_side:
				close()
	return state

## Nothing left to do: failed, or (client) the reply is in, or (server) the reply is written.
func finished() -> bool:
	if state == FAILED:
		return true
	if _server_side:
		return _replied and _out.is_empty()
	return state == DONE

func close() -> void:
	if _tcp != null:
		_tcp.disconnect_from_host()
	_out.clear()

func _fail(why: String) -> void:
	state = FAILED
	error = why
	close()
