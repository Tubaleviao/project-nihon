extends RefCounted
## Phase 297 — what a client dials for a typed server address: the host and port from `NetAddress`, and for a host
## name that resolves to both IPv6 and IPv4, which of the two (Happy Eyeballs, RFC 8305).
##
## The race runs on the status query, not on ENet: a losing ENet attempt would be a half-open peer on the host, and
## `SceneMultiplayer` only learns of a connection made while it holds the peer. The IPv6 address is asked first, the
## IPv4 one STAGGER_MS later, and whichever answers first is dialled. With no answer by DECIDE_MS (a host with its
## status port off, or a firewall that drops it) the OS's first address is dialled, which is today's behaviour.
## IPv6 is not faster; it matters because a host behind IPv4 CGNAT can be reached on IPv6 with a firewall rule.

const NetAddress := preload("res://src/networking/net_address.gd")
const ServerStatus := preload("res://src/networking/server_status.gd")
const ServerProbe := preload("res://src/networking/server_probe.gd")

const STAGGER_MS := 250
const DECIDE_MS := 1000

## The race's state, pure so the suite can step it with its own clock.
class Eyeballs:
	var v6 := ""
	var v4 := ""
	var fallback := ""
	var chosen := ""
	var _start := 0
	var _v4_sent := false

	## Start a race over `addresses` (resolver order). Returns the keys to query now ("v6"); a single family needs
	## no race and is chosen at once.
	func begin(addresses: Array, now_ms: int) -> Array:
		for a in addresses:
			var s := str(a)
			if NetAddress.is_v6(s):
				if v6 == "":
					v6 = s
			elif v4 == "":
				v4 = s
		fallback = str(addresses[0]) if not addresses.is_empty() else ""
		_start = now_ms
		if v6 == "" or v4 == "":
			chosen = fallback
			return []
		return ["v6"]

	## The keys whose query is due at `now_ms` (IPv4, STAGGER_MS after IPv6).
	func due(now_ms: int) -> Array:
		if chosen == "" and not _v4_sent and now_ms - _start >= STAGGER_MS:
			_v4_sent = true
			return ["v4"]
		return []

	## The first answer wins; later ones change nothing.
	func answered(key: String) -> void:
		if chosen == "":
			chosen = v6 if key == "v6" else v4

	## No answer by DECIDE_MS: the resolver's first address.
	func expire(now_ms: int) -> void:
		if chosen == "" and now_ms - _start >= DECIDE_MS:
			chosen = fallback

	func address_of(key: String) -> String:
		return v6 if key == "v6" else v4

## The longest a host name may take to resolve before the join goes on with ENet's own lookup.
const RESOLVE_MAX_MS := 5000

## Join `address` on `networking` (a NetworkingSlice): its host and port, a name raced as `resolve_join` says.
## A coroutine: `await` it. `tree` paces the wait (one frame at a time, the window stays live).
static func join(networking: Node, address: String, tree: SceneTree) -> Error:
	var target: Dictionary = await resolve_join(address, tree)
	if not bool(target["ok"]):
		return ERR_INVALID_PARAMETER
	if not is_instance_valid(networking):
		return ERR_UNAVAILABLE
	return networking.join(str(target["host"]), int(target["port"]))

## {ok, host, port} for a literal address (dialled as given), or {} for a host name, which needs `resolve_join`.
## {ok: false} when `address` does not parse.
static func literal_target(address: String) -> Dictionary:
	var a := NetAddress.parse(address)
	if not bool(a["ok"]):
		return { "ok": false }
	if str(a["family"]) == NetAddress.FAMILY_NAME:
		return {}
	return { "ok": true, "host": str(a["host"]), "port": int(a["port"]) }

## {ok, host, port} to dial for `address` (already accepted by `NetAddress`). A coroutine that never blocks the main
## thread: the name resolves on the resolver queue and the race is polled once a frame (`tree`). A name with one
## family is dialled at once; a name that does not resolve in time is handed to ENet as is, which then fails the way
## it always did.
static func resolve_join(address: String, tree: SceneTree) -> Dictionary:
	var lit := literal_target(address)
	if not lit.is_empty():
		return lit
	var a := NetAddress.parse(address)
	var host := str(a["host"])
	var port := int(a["port"])
	var id := IP.resolve_hostname_queue_item(host, IP.TYPE_ANY)
	var addrs: Array = []
	if id != IP.RESOLVER_INVALID_ID:
		var until := Time.get_ticks_msec() + RESOLVE_MAX_MS
		while IP.get_resolve_item_status(id) == IP.RESOLVER_STATUS_WAITING and Time.get_ticks_msec() < until:
			await tree.process_frame
		if IP.get_resolve_item_status(id) == IP.RESOLVER_STATUS_DONE:
			addrs = Array(IP.get_resolve_item_addresses(id))
		IP.erase_resolve_item(id)
	var race := Eyeballs.new()
	var pending := race.begin(addrs, Time.get_ticks_msec())
	if race.chosen != "" or addrs.is_empty():
		return { "ok": true, "host": race.chosen if race.chosen != "" else host, "port": port }
	var probe := ServerProbe.new()
	if probe.open() != OK:
		return { "ok": true, "host": race.fallback, "port": port }
	var status_port := ServerStatus.default_status_port(port)
	while race.chosen == "":
		var now := Time.get_ticks_msec()
		for key in pending:
			probe.query_ip(race.address_of(str(key)), status_port, str(key), now)
		for ans in probe.poll(now):
			race.answered(str(ans["key"]))
		pending = race.due(now)
		race.expire(now)
		if race.chosen == "":
			await tree.process_frame
	probe.close()
	print("[Networking] %s resolves to both families — dialling %s" % [host, race.chosen])
	return { "ok": true, "host": race.chosen, "port": port }
