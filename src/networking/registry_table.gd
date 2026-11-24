extends RefCounted
## Phase 298 — a registry's table of public servers. Pure (clock passed in), so the suite drives every rule.
##
## A heartbeat arrives from `source_ip` (the TCP connection's peer, never the body). Its entry, keyed by
## (source IP, game port), is listed only after the host at that IP answered a status query on the heartbeat's status
## port (`probe_due` → the registry's prober → `probe_sent` / `probe_answered`), so a heartbeat cannot list someone
## else's IP: only the machine at the source address can answer at it. The answer must name the heartbeat's game
## port. A listed entry that changes its status port is unlisted and probed again. Every later heartbeat of a listed
## entry asks its status port once more, and the player counts the list reports come from those answers, never from
## the heartbeat body (a host cannot claim a full house to sort itself to the top without answering for it).
##
## An entry that missed MISSED_HEARTBEATS heartbeats is dropped (`sweep`); an unlisted entry whose back-probe went
## unanswered is dropped at once (its host heartbeats again to retry), so unverified entries cannot sit in the table.
## Limits are per *address bucket* (`bucket`): an IPv4 address, or an IPv6 /64 (one host usually owns a whole /64, so
## a per-/128 limit would be no limit). Per bucket: at most MAX_PER_ADDRESS entries and HEARTBEATS_PER_WINDOW
## heartbeats per heartbeat interval. In all: MAX_ENTRIES entries, of which at most MAX_PENDING unverified.

const RegistryWire := preload("res://src/networking/registry_wire.gd")
const ServerStatus := preload("res://src/networking/server_status.gd")
const NetAddress := preload("res://src/networking/net_address.gd")

const MAX_ENTRIES := 4096
const MAX_PENDING := 256
const MAX_PER_ADDRESS := 4
## Heartbeats one bucket may send per interval: one per entry, twice over (a restart, a retry).
const HEARTBEATS_PER_WINDOW := MAX_PER_ADDRESS * 2
## A back-probe that got no answer in this long is given up.
const PROBE_TIMEOUT_MS := 5000
## The most buckets the rate-limit table tracks in one window.
const MAX_RATE_SOURCES := 8192
## The grace past the third missed heartbeat before an entry goes (a live host's heartbeat a little late).
const DROP_GRACE_MS := 2000

## Seconds between heartbeats.
var interval_s: int = RegistryWire.HEARTBEAT_S
## key → {ip, bucket, game_port, status_port, world_name, region, protocol, players, max_players, last_ms, listed,
##        probe_state ("" | "due" | "sent"), probe_ms}. `players` / `max_players` are the last status answer's.
var entries: Dictionary = {}
## Bumped whenever what `listed()` returns may have changed (the registry caches its list reply on it).
var version: int = 0
var _rate_window_start: int = -1
var _rate: Dictionary = {}
var _pending: int = 0

func drop_after_ms() -> int:
	return RegistryWire.MISSED_HEARTBEATS * interval_s * 1000 + DROP_GRACE_MS

## The bucket an address's limits are counted in: an IPv4 address as itself, an IPv6 address as its /64 prefix.
static func bucket(ip: String) -> String:
	if not NetAddress.is_v6(ip):
		return ip
	var halves := ip.split("::")
	if halves.size() > 2:
		return ip
	var head: Array = Array(halves[0].split(":", false))
	var tail: Array = Array(halves[1].split(":", false)) if halves.size() == 2 else []
	if halves.size() == 2:
		while head.size() + tail.size() < 8:
			head.append("0")
	var groups: Array = head + tail
	# An IPv4-mapped or embedded tail ("::ffff:1.2.3.4") is one IPv4 address, counted as such.
	if not groups.is_empty() and str(groups[-1]).contains("."):
		return str(groups[-1])
	var out: Array = []
	for g in groups.slice(0, 4):
		out.append(("%x" % str(g).hex_to_int()))
	return ":".join(PackedStringArray(out)) + "::/64"

## A heartbeat `msg` (decoded JSON) from `source_ip`. Returns {ok: true, listed} or {ok: false, code}:
## "malformed", "rate_limited", "address_full", "registry_full".
func heartbeat(source_ip: String, msg: Dictionary, now_ms: int) -> Dictionary:
	var hb := RegistryWire.decode_heartbeat(msg)
	if hb.is_empty() or not source_ip.is_valid_ip_address():
		return { "ok": false, "code": "malformed" }
	var b := bucket(source_ip)
	if not _admit(b, now_ms):
		return { "ok": false, "code": "rate_limited" }
	var key := RegistryWire.entry_key(source_ip, int(hb["game_port"]))
	var e: Dictionary = entries.get(key, {})
	if e.is_empty():
		if count_for(source_ip) >= MAX_PER_ADDRESS:
			return { "ok": false, "code": "address_full" }
		if entries.size() >= MAX_ENTRIES or _pending >= MAX_PENDING:
			return { "ok": false, "code": "registry_full" }
		e = { "ip": source_ip, "bucket": b, "game_port": int(hb["game_port"]), "listed": false, "probe_state": "due",
			"probe_ms": 0, "players": 0, "max_players": 0 }
		entries[key] = e
		_pending += 1
	elif int(e["status_port"]) != int(hb["status_port"]):
		if bool(e["listed"]):
			if _pending >= MAX_PENDING:
				return { "ok": false, "code": "registry_full" }
			e["listed"] = false   # a new status port answers for itself before the entry is listed again
			_pending += 1
			version += 1
		e["probe_state"] = "due"
	elif str(e["probe_state"]) == "":
		e["probe_state"] = "due"   # a listed entry's counts are refreshed from its own answer
	for k in ["status_port", "world_name", "region", "protocol"]:
		e[k] = hb[k]
	e["last_ms"] = now_ms
	return { "ok": true, "listed": bool(e["listed"]) }

## The back-probes due now: [{key, ip, status_port}]. Nothing is marked: the caller reports each one it really sent
## with `probe_sent`, so a probe the socket could not send stays due.
func probe_due() -> Array:
	var out: Array = []
	for key in entries:
		var e: Dictionary = entries[key]
		if str(e["probe_state"]) == "due":
			out.append({ "key": key, "ip": str(e["ip"]), "status_port": int(e["status_port"]) })
	return out

func probe_sent(key: String, now_ms: int) -> void:
	var e: Dictionary = entries.get(key, {})
	if not e.is_empty() and str(e["probe_state"]) == "due":
		e["probe_state"] = "sent"
		e["probe_ms"] = now_ms

## The status answer to the back-probe for `key`, received from `from_ip`. Counted when it came from the entry's own
## IP and names its game port: the entry is listed (or stays listed) with the answer's player counts. True when it
## counted.
func probe_answered(key: String, from_ip: String, status: Dictionary) -> bool:
	var e: Dictionary = entries.get(key, {})
	if e.is_empty() or str(e["probe_state"]) != "sent":
		return false
	if from_ip != str(e["ip"]) or int(status.get("game_port", 0)) != int(e["game_port"]):
		return false
	e["probe_state"] = ""
	e["players"] = clampi(int(status.get("players", 0)), 0, 65535)
	e["max_players"] = clampi(int(status.get("max_players", 0)), 0, 65535)
	if not bool(e["listed"]):
		e["listed"] = true
		_pending -= 1
	version += 1
	return true

## Drop entries that missed their heartbeats, and unlisted entries whose back-probe timed out; a listed entry whose
## refresh probe timed out keeps its last counts. Returns the keys dropped.
func sweep(now_ms: int) -> Array:
	var gone: Array = []
	for key in entries.keys():
		var e: Dictionary = entries[key]
		var timed_out := str(e["probe_state"]) == "sent" and now_ms - int(e["probe_ms"]) > PROBE_TIMEOUT_MS
		if now_ms - int(e["last_ms"]) > drop_after_ms() or (timed_out and not bool(e["listed"])):
			_remove(key)
			gone.append(key)
		elif timed_out:
			e["probe_state"] = ""
	return gone

func _remove(key: String) -> void:
	var e: Dictionary = entries[key]
	if bool(e["listed"]):
		version += 1
	else:
		_pending -= 1
	entries.erase(key)

## The listed entries, as `RegistryWire.list_reply` takes them, most players first (at most MAX_LIST).
func listed() -> Array:
	var out: Array = []
	for key in entries:
		var e: Dictionary = entries[key]
		if bool(e["listed"]):
			out.append(e)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["players"]) > int(b["players"]) if int(a["players"]) != int(b["players"]) \
			else RegistryWire.entry_key(a["ip"], a["game_port"]) < RegistryWire.entry_key(b["ip"], b["game_port"]))
	return out.slice(0, RegistryWire.MAX_LIST)

func pending_count() -> int:
	return _pending

## Entries in the bucket of `ip`.
func count_for(ip: String) -> int:
	var b := bucket(ip)
	var n := 0
	for key in entries:
		if str(entries[key]["bucket"]) == b:
			n += 1
	return n

func _admit(b: String, now_ms: int) -> bool:
	if _rate_window_start < 0 or now_ms - _rate_window_start >= interval_s * 1000:
		_rate_window_start = now_ms
		_rate.clear()
	var n := int(_rate.get(b, 0))
	if n >= HEARTBEATS_PER_WINDOW:
		return false
	if n == 0 and _rate.size() >= MAX_RATE_SOURCES:
		return false
	_rate[b] = n + 1
	return true
