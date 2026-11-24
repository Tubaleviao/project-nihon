extends RefCounted
## Phase 298 — the server list's wire: what a public host, a registry and a client say to each other over TCP.
##
## Every message is one frame: a big-endian u32 byte length, then that many bytes of UTF-8 JSON (an object). A frame
## longer than its cap is never read: the reader stops at the length, so a peer cannot make the other side buffer
## more than the cap. A connection carries one request and one reply, then closes.
##
##   heartbeat (host → registry): {type: "heartbeat", game_port, status_port, world_name, region, protocol, players,
##                                 max_players}. The registry takes the host's IP from the TCP connection, never from
##                                 the body (a body's "ip"/"address"/"host" is ignored).
##   reply:                       {type: "heartbeat_ok", listed: bool, interval_s} or {type: "error", code}
##   list (client → registry):    {type: "list"}
##   reply:                       {type: "list", servers: [{ip, game_port, status_port, world_name, region, protocol,
##                                 players, max_players}]}, at most MAX_LIST entries, MAX_LIST_BYTES in all.
##
## Everything read is untrusted: `decode_heartbeat` and `decode_list` keep only well-formed fields, cut text to its
## cap, and a list over MAX_LIST is truncated (the extra entries are dropped, not trusted).

const NetAddress := preload("res://src/networking/net_address.gd")
const ServerStatus := preload("res://src/networking/server_status.gd")

## The registry's port when an address names none.
const DEFAULT_PORT := 7700
## Seconds between a public host's heartbeats; a registry drops an entry that missed three.
const HEARTBEAT_S := 30
const MISSED_HEARTBEATS := 3
## A request (a heartbeat or a list query) is small; a list reply may be larger.
const MAX_REQUEST_BYTES := 1024
const MAX_LIST := 256
const MAX_LIST_BYTES := 65536
## A connection that has not finished its exchange in this long is closed.
const EXCHANGE_TIMEOUT_MS := 5000

## The region tags a host may announce; each is the catalog key `menu.region.<tag>`. "" is "no region".
const REGIONS := ["", "sa", "na", "eu", "af", "as", "oc"]

## A frame: u32 big-endian length + UTF-8 JSON of `msg`. Empty when the JSON is over `cap`.
static func frame(msg: Dictionary, cap: int = MAX_REQUEST_BYTES) -> PackedByteArray:
	var body := JSON.stringify(msg).to_utf8_buffer()
	if body.size() > cap:
		return PackedByteArray()
	var n := body.size()
	var out := PackedByteArray([(n >> 24) & 0xFF, (n >> 16) & 0xFF, (n >> 8) & 0xFF, n & 0xFF])
	out.append_array(body)
	return out

## Frames from a byte stream. `push` the bytes read; `take` returns the first whole message once it arrived, {} while
## it has not, and sets `error` (then never reads further) on a length over `cap` or a body that is not a JSON object.
class Reader:
	extends RefCounted
	var cap: int
	var error: String = ""
	var _buf := PackedByteArray()

	func _init(max_bytes: int) -> void:
		cap = max_bytes

	func push(bytes: PackedByteArray) -> void:
		if error != "":
			return
		_buf.append_array(bytes)
		# Never hold more than one frame's worth: a peer that keeps sending past it is cut off.
		if _buf.size() > cap + 4:
			var n := _length()
			if n < 0 or n > cap:
				error = "oversize"

	## How many bytes the reader still wants before a frame is whole (at most cap + 4 in all).
	func wanted() -> int:
		if _buf.size() < 4:
			return 4 - _buf.size()
		var n := _length()
		if n < 0 or n > cap:
			return 0
		return maxi(0, 4 + n - _buf.size())

	func take() -> Dictionary:
		if error != "" or _buf.size() < 4:
			return {}
		var n := _length()
		if n < 0 or n > cap:
			error = "oversize"
			return {}
		if _buf.size() < 4 + n:
			return {}
		var body := _buf.slice(4, 4 + n)
		_buf = _buf.slice(4 + n)
		var json := JSON.new()
		if json.parse(body.get_string_from_utf8()) != OK or not (json.data is Dictionary):
			error = "malformed"
			return {}
		return json.data

	## The big-endian u32 at the head of the buffer, -1 while shorter than 4.
	func _length() -> int:
		if _buf.size() < 4:
			return -1
		return (int(_buf[0]) << 24) | (int(_buf[1]) << 16) | (int(_buf[2]) << 8) | int(_buf[3])

# ---------------------------------------------------------------------------
# Messages
# ---------------------------------------------------------------------------

## The heartbeat a host sends for `info` ({game_port, status_port, world_name, region, protocol, players, max_players}).
static func heartbeat(info: Dictionary) -> Dictionary:
	return {
		"type": "heartbeat",
		"game_port": int(info.get("game_port", 0)),
		"status_port": int(info.get("status_port", 0)),
		"world_name": ServerStatus.clean_text(str(info.get("world_name", ""))).left(64),
		"region": region_of(info.get("region", "")),
		"protocol": int(info.get("protocol", ServerStatus.PROTOCOL_VERSION)),
		"players": int(info.get("players", 0)),
		"max_players": int(info.get("max_players", 0)),
	}

## A heartbeat body as the registry may use it, or {} when it is not one. Only the named fields are read: an IP or
## address in the body is never looked at (the registry takes the connection's source).
static func decode_heartbeat(msg: Dictionary) -> Dictionary:
	if str(msg.get("type", "")) != "heartbeat":
		return {}
	var game_port := _port(msg.get("game_port", null))
	var status_port := _port(msg.get("status_port", null))
	if game_port <= 0 or status_port <= 0:
		return {}
	return {
		"game_port": game_port,
		"status_port": status_port,
		"world_name": _text(msg.get("world_name", ""), ServerStatus.NAME_MAX_BYTES),
		"region": region_of(msg.get("region", "")),
		"protocol": _count(msg.get("protocol", 0)),
		"players": _count(msg.get("players", 0)),
		"max_players": _count(msg.get("max_players", 0)),
	}

## A list reply for `servers` (registry entries), at most MAX_LIST and MAX_LIST_BYTES.
static func list_reply(servers: Array) -> Dictionary:
	var out: Array = []
	for s in servers.slice(0, MAX_LIST):
		out.append({
			"ip": str(s["ip"]), "game_port": int(s["game_port"]), "status_port": int(s["status_port"]),
			"world_name": str(s["world_name"]), "region": str(s["region"]), "protocol": int(s["protocol"]),
			"players": int(s["players"]), "max_players": int(s["max_players"]),
		})
	return { "type": "list", "servers": out }

## A list reply's servers as a client may show them: entries with an IP literal and two ports, text cut to its cap,
## duplicates (same IP and game port) dropped, at most MAX_LIST (a longer list is truncated, not trusted).
static func decode_list(msg: Dictionary) -> Array:
	if str(msg.get("type", "")) != "list" or not (msg.get("servers", null) is Array):
		return []
	var out: Array = []
	var seen := {}
	for s in msg["servers"]:
		if out.size() >= MAX_LIST:
			break
		if not (s is Dictionary):
			continue
		var ip := str(s.get("ip", ""))
		var game_port := _port(s.get("game_port", null))
		var status_port := _port(s.get("status_port", null))
		if not ip.is_valid_ip_address() or ip.contains("%") or game_port <= 0 or status_port <= 0:
			continue
		var key := entry_key(ip, game_port)
		if seen.has(key):
			continue
		seen[key] = true
		out.append({
			"ip": ip, "game_port": game_port, "status_port": status_port,
			"world_name": _text(s.get("world_name", ""), ServerStatus.NAME_MAX_BYTES),
			"region": region_of(s.get("region", "")),
			"protocol": _count(s.get("protocol", 0)),
			"players": _count(s.get("players", 0)),
			"max_players": _count(s.get("max_players", 0)),
		})
	return out

static func entry_key(ip: String, game_port: int) -> String:
	return "%s|%d" % [ip, game_port]

## A region tag from untrusted input: one of REGIONS, else "".
static func region_of(raw: Variant) -> String:
	var r := str(raw).strip_edges().to_lower() if raw is String else ""
	return r if REGIONS.has(r) else ""

## A registry address (`NetAddress` rules) → {ok, host, port, family}; no port means DEFAULT_PORT (the registry's,
## not the game's).
static func parse_registry(raw: String) -> Dictionary:
	var text := raw.strip_edges()
	var a := NetAddress.parse(text)
	if not bool(a["ok"]):
		return a
	if not _names_port(text):
		a["port"] = DEFAULT_PORT
	return a

## True when the address text carries its own port (`host:p`, `[v6]:p`; a bare IPv6 literal never does).
static func _names_port(text: String) -> bool:
	if text.begins_with("["):
		return text.contains("]:")
	return text.count(":") == 1

static func _port(v: Variant) -> int:
	if not (v is int or v is float) or not is_finite(float(v)) or float(v) != floorf(float(v)):
		return 0
	var p := int(v)
	return p if p >= 1 and p <= 65535 else 0

static func _count(v: Variant) -> int:
	if not (v is int or v is float) or not is_finite(float(v)):
		return 0
	return clampi(int(v), 0, 65535)

static func _text(v: Variant, max_bytes: int) -> String:
	if not (v is String):
		return ""
	var t := ServerStatus.clean_text(v)
	while t.to_utf8_buffer().size() > max_bytes:
		t = t.left(t.length() - 1)
	return t
