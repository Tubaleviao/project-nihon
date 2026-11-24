extends RefCounted
## Phase 297 — the one server-address rule: what the Join form, `--client` and the recent-servers file accept,
## and how an accepted address splits into the host ENet dials and its port.
##
## Accepted: `host`, `host:port`, `1.2.3.4`, `1.2.3.4:port`, `[v6]`, `[v6]:port` and a bare IPv6 literal, which
## never carries a port (`2001:db8::1` is the whole host). No port means `DEFAULT_PORT`. Refused: a scheme, a path,
## whitespace, an unclosed bracket, a port outside 1–65535, a malformed IPv4 or IPv6 literal, an IPv6 zone
## (`%eth0`: Godot's sockets drop it, see the Phase 297 notes in ROADMAP.md) and anything over `ADDRESS_MAX`.

const DEFAULT_PORT := 7777
## The longest address text: a DNS name's ceiling plus room for a bracketed literal and a port.
const ADDRESS_MAX := 253

const FAMILY_V4 := "v4"
const FAMILY_V6 := "v6"
const FAMILY_NAME := "name"

static var _host_re: RegEx = null

## `{ok: true, host, port, family}` or `{ok: false}`. `host` is what ENet and UDP sockets take (an IPv6 literal
## without brackets); `family` is FAMILY_V4, FAMILY_V6 or FAMILY_NAME.
static func parse(raw: String) -> Dictionary:
	var bad := { "ok": false }
	if raw.is_empty() or raw.length() > ADDRESS_MAX:
		return bad
	for c in [" ", "\t", "\n", "\r", "/", "\\", "@", "?", "#", "%"]:
		if raw.contains(c):
			return bad
	if raw.begins_with("["):
		var close := raw.find("]")
		if close < 0:
			return bad
		var inner := raw.substr(1, close - 1)
		var rest := raw.substr(close + 1)
		if not _is_v6(inner):
			return bad
		if rest.is_empty():
			return _ok(inner, DEFAULT_PORT, FAMILY_V6)
		if not rest.begins_with(":"):
			return bad
		var p := port_of(rest.substr(1))
		return _ok(inner, p, FAMILY_V6) if p > 0 else bad
	if raw.contains("]"):
		return bad
	var colons := raw.count(":")
	if colons > 1:
		# A bare IPv6 literal: the whole text is the host, never a port.
		return _ok(raw, DEFAULT_PORT, FAMILY_V6) if _is_v6(raw) else bad
	var host := raw
	var port := DEFAULT_PORT
	if colons == 1:
		var cut := raw.find(":")
		host = raw.left(cut)
		port = port_of(raw.substr(cut + 1))
		if port <= 0:
			return bad
	if _looks_v4(host):
		return _ok(host, port, FAMILY_V4) if host.is_valid_ip_address() else bad
	return _ok(host, port, FAMILY_NAME) if _is_name(host) else bad

static func valid(raw: String) -> bool:
	return bool(parse(raw)["ok"])

## A port's text → 1..65535, or 0 when it is not one (empty, a sign, a letter, out of range).
static func port_of(text: String) -> int:
	if text.is_empty() or text.length() > 5 or not text.is_valid_int() or text.begins_with("+") or text.begins_with("-"):
		return 0
	var p := text.to_int()
	return p if p >= 1 and p <= 65535 else 0

## The text a player would type for `host` and `port`: IPv6 bracketed when it carries a port, the port left out when
## it is the default.
static func format(host: String, port: int) -> String:
	var v6 := host.contains(":")
	if port == DEFAULT_PORT:
		return host
	return ("[%s]:%d" if v6 else "%s:%d") % [host, port]

## True for an IPv6 literal (`::1`, `2001:db8::1`; no zone, no brackets).
static func is_v6(host: String) -> bool:
	return _is_v6(host)

static func _ok(host: String, port: int, family: String) -> Dictionary:
	return { "ok": true, "host": host, "port": port, "family": family }

static func _is_v6(s: String) -> bool:
	return s.contains(":") and not s.contains("%") and s.is_valid_ip_address()

static func _looks_v4(s: String) -> bool:
	for c in s:
		if not (c == "." or (c >= "0" and c <= "9")):
			return false
	return true

## A DNS-style host name: labels of letters, digits and inner hyphens, dot-separated.
static func _is_name(s: String) -> bool:
	if _host_re == null:
		_host_re = RegEx.create_from_string("^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)*\\.?$")
	return _host_re.search(s) != null
