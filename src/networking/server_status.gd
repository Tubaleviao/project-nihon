extends RefCounted
## Phase 297 — the status query a host answers on its status port, and the protocol version a client and a host
## must share to play together.
##
## The wire is binary and fixed-size so the anti-abuse rules are checks on a length:
##   query  = "NHSQ" · format u8 · nonce u32 · zero padding, at least ANSWER_SIZE and at most QUERY_MAX bytes
##   answer = "NHSA" · format u8 · nonce u32 · protocol u16 · game port u16 · players u16 · max players u16 ·
##            instance u32 · game version (u8 length + UTF-8) · world name (u8 length + UTF-8), zero-padded to
##            exactly ANSWER_SIZE bytes
## A query is padded to at least the answer's size, so the port never sends more bytes than it was sent (no
## amplification of a spoofed source). The nonce is echoed so a client matches an answer to its own query (and
## times the round trip); `instance` is random per host process, so a host heard on both IPv4 and IPv6 is listed
## once. Names are the host's own text: shown as given, never translated.

## The game's network protocol. Bump it whenever a client of the old version would misbehave against a host of the
## new one (or the reverse): a packet's meaning changed, a required field appeared. The join handshake and the
## status answer both carry it, and a client refuses a host whose version differs (`protocol_refusal`).
const PROTOCOL_VERSION := 1

## The status wire's own layout version (not the game's protocol): a query of another format gets no reply.
const FORMAT := 1
const QUERY_MAGIC := "NHSQ"
const ANSWER_MAGIC := "NHSA"
const ANSWER_SIZE := 192
const QUERY_MAX := 512
const VERSION_MAX_BYTES := 32
const NAME_MAX_BYTES := 96

## The status port when a host names none: the game port + 1 (`--status-port 0` turns it off).
static func default_status_port(game_port: int) -> int:
	return game_port + 1 if game_port < 65535 else 0

## #706 — the net harness's forged-build client: `--harness-game-version <v>` makes this process claim build `v`
## instead of its own, so the harness can prove a host refuses it. A client can only sabotage its own join with it:
## the host checks the claim against its own build and never trusts it any further.
const FORGE_VERSION_ARG := "--harness-game-version"

## #706 — this build's identity: `application/config/version` (or the harness's forged one, see FORGE_VERSION_ARG).
## The join and roster intents, the host's hello and its refusal all carry it beside PROTOCOL_VERSION.
static func game_version() -> String:
	var args := OS.get_cmdline_user_args()
	var i := args.find(FORGE_VERSION_ARG)
	if i >= 0 and i + 1 < args.size():
		return valid_version(args[i + 1])
	return str(ProjectSettings.get_setting("application/config/version", ""))

## #706 — a build version read off the wire: the text when it is a String of 1..VERSION_MAX_BYTES UTF-8 bytes with
## no control characters, else "" (missing, another type, oversized or carrying control characters).
static func valid_version(v: Variant) -> String:
	if not v is String:
		return ""
	var s: String = v
	if s.is_empty() or s.to_utf8_buffer().size() > VERSION_MAX_BYTES or clean_text(s) != s:
		return ""
	return s

## #706 — what a client shows when it cannot play on a host: { key, args } (args name the host's version, then this
## build's), or {} when it can. Another protocol is refused with the protocol keys; the same protocol on another
## build (or a host that names no valid build) with `menu.join.fail_version`.
static func build_refusal(own_protocol: int, own_version: String, host_protocol: int, host_version: Variant) -> Dictionary:
	var theirs := valid_version(host_version)
	var shown := theirs if theirs != "" else "?"
	var key := protocol_refusal(own_protocol, host_protocol)
	if key != "":
		return { "key": key, "args": [shown, own_version] }
	if theirs != own_version:
		return { "key": "menu.join.fail_version", "args": [shown, own_version] }
	return {}

## The catalog key a client shows when it cannot play on a host of `host_protocol`; "" when it can.
static func protocol_refusal(own_protocol: int, host_protocol: int) -> String:
	if host_protocol == own_protocol:
		return ""
	return "menu.join.fail_protocol_newer" if host_protocol > own_protocol else "menu.join.fail_protocol_older"

## A query carrying `nonce`, padded to ANSWER_SIZE.
static func encode_query(nonce: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(ANSWER_SIZE)
	b.fill(0)
	_put_magic(b, QUERY_MAGIC)
	b.encode_u8(4, FORMAT)
	b.encode_u32(5, nonce & 0xFFFFFFFF)
	return b

## The nonce of a well-formed query, or -1 for one the host must drop without a reply: shorter than the answer
## (amplification), over QUERY_MAX, another magic or another format.
static func decode_query(b: PackedByteArray) -> int:
	if b.size() < ANSWER_SIZE or b.size() > QUERY_MAX:
		return -1
	if not _has_magic(b, QUERY_MAGIC) or b.decode_u8(4) != FORMAT:
		return -1
	return int(b.decode_u32(5))

## The answer to the query `nonce` for `info` ({protocol, game_port, players, max_players, instance, game_version,
## world_name}). Always exactly ANSWER_SIZE bytes: long names are cut on a character boundary.
static func encode_answer(nonce: int, info: Dictionary) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(ANSWER_SIZE)
	b.fill(0)
	_put_magic(b, ANSWER_MAGIC)
	b.encode_u8(4, FORMAT)
	b.encode_u32(5, nonce & 0xFFFFFFFF)
	b.encode_u16(9, clampi(int(info.get("protocol", PROTOCOL_VERSION)), 0, 65535))
	b.encode_u16(11, clampi(int(info.get("game_port", 0)), 0, 65535))
	b.encode_u16(13, clampi(int(info.get("players", 0)), 0, 65535))
	b.encode_u16(15, clampi(int(info.get("max_players", 0)), 0, 65535))
	b.encode_u32(17, int(info.get("instance", 0)) & 0xFFFFFFFF)
	var at := _put_text(b, 21, str(info.get("game_version", "")), VERSION_MAX_BYTES)
	_put_text(b, at, str(info.get("world_name", "")), NAME_MAX_BYTES)
	return b

## An answer → {nonce, protocol, game_port, players, max_players, instance, game_version, world_name}, or {} for
## anything malformed (wrong size, magic, format, a length past its cap, a game port of 0).
static func decode_answer(b: PackedByteArray) -> Dictionary:
	if b.size() != ANSWER_SIZE or not _has_magic(b, ANSWER_MAGIC) or b.decode_u8(4) != FORMAT:
		return {}
	var game_port := int(b.decode_u16(11))
	if game_port == 0:
		return {}
	var version := _get_text(b, 21, VERSION_MAX_BYTES)
	if version.is_empty():
		return {}
	var world := _get_text(b, 22 + int(b.decode_u8(21)), NAME_MAX_BYTES)
	if world.is_empty():
		return {}
	return {
		"nonce": int(b.decode_u32(5)),
		"protocol": int(b.decode_u16(9)),
		"game_port": game_port,
		"players": int(b.decode_u16(13)),
		"max_players": int(b.decode_u16(15)),
		"instance": int(b.decode_u32(17)),
		"game_version": str(version[0]),
		"world_name": str(world[0]),
	}

static func _put_magic(b: PackedByteArray, magic: String) -> void:
	var m := magic.to_ascii_buffer()
	for i in 4:
		b[i] = m[i]

static func _has_magic(b: PackedByteArray, magic: String) -> bool:
	return b.slice(0, 4) == magic.to_ascii_buffer()

## Write `text` at `at` as a length byte + UTF-8, cut to `max_bytes` on a character boundary. Returns the next
## free offset.
static func _put_text(b: PackedByteArray, at: int, text: String, max_bytes: int) -> int:
	var t := clean_text(text)
	var bytes := t.to_utf8_buffer()
	while bytes.size() > max_bytes:
		t = t.left(t.length() - 1)
		bytes = t.to_utf8_buffer()
	b.encode_u8(at, bytes.size())
	for i in bytes.size():
		b[at + 1 + i] = bytes[i]
	return at + 1 + bytes.size()

## [text] for a well-formed field at `at`, [] when its length is past `max_bytes` or the buffer.
static func _get_text(b: PackedByteArray, at: int, max_bytes: int) -> Array:
	if at >= b.size():
		return []
	var n := int(b.decode_u8(at))
	if n > max_bytes or at + 1 + n > b.size():
		return []
	return [clean_text(b.slice(at + 1, at + 1 + n).get_string_from_utf8())]

## A host's text as it may be shown: control characters dropped, outer whitespace trimmed.
static func clean_text(text: String) -> String:
	var out := ""
	for c in text:
		if c.unicode_at(0) >= 32 and c.unicode_at(0) != 127:
			out += c
	return out.strip_edges()
