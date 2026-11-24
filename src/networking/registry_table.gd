extends RefCounted
## Phase 298 — a registry's table of public servers. Pure (clock passed in), so the suite drives every rule.
##
## A heartbeat arrives from `source_ip` (the TCP connection's peer, never the body). Its entry, keyed by
## (source IP, game port), is listed only after the host at that IP answered a status query on the heartbeat's status
## port (`probe_due` → the registry's prober → `probe_answered`), so a heartbeat cannot list someone else's IP: only
## the machine at the source address can answer at it. The answer must name the heartbeat's game port. A listed entry
## that changes its status port is probed again before it is listed again.
##
## An entry that missed MISSED_HEARTBEATS heartbeats is dropped (`sweep`). Per source address: at most
## MAX_PER_ADDRESS entries (pending or listed) and HEARTBEATS_PER_WINDOW heartbeats per heartbeat interval; the
## whole table holds at most MAX_ENTRIES.

const RegistryWire := preload("res://src/networking/registry_wire.gd")
const ServerStatus := preload("res://src/networking/server_status.gd")

const MAX_ENTRIES := 4096
const MAX_PER_ADDRESS := 4
## Heartbeats one address may send per interval: one per entry, twice over (a restart, a retry).
const HEARTBEATS_PER_WINDOW := MAX_PER_ADDRESS * 2
## A back-probe that got no answer in this long is given up; the next heartbeat tries again.
const PROBE_TIMEOUT_MS := 5000
## The most addresses the rate-limit table tracks in one window.
const MAX_RATE_SOURCES := 8192

## Seconds between heartbeats; an entry is dropped once `MISSED_HEARTBEATS × interval_s` (+ a small grace) passed
## since its last one.
var interval_s: int = RegistryWire.HEARTBEAT_S
## key → {ip, game_port, status_port, world_name, region, protocol, players, max_players, last_ms, listed,
##        probe_state ("" | "due" | "sent"), probe_ms}
var entries: Dictionary = {}
var _rate_window_start: int = -1
var _rate: Dictionary = {}

## The grace past the third missed heartbeat before an entry goes (a live host's heartbeat a little late).
const DROP_GRACE_MS := 2000

func drop_after_ms() -> int:
	return RegistryWire.MISSED_HEARTBEATS * interval_s * 1000 + DROP_GRACE_MS

## A heartbeat `msg` (decoded JSON) from `source_ip`. Returns {ok: true, listed} or {ok: false, code}:
## "malformed", "rate_limited", "address_full", "registry_full".
func heartbeat(source_ip: String, msg: Dictionary, now_ms: int) -> Dictionary:
	var hb := RegistryWire.decode_heartbeat(msg)
	if hb.is_empty() or not source_ip.is_valid_ip_address():
		return { "ok": false, "code": "malformed" }
	if not _admit(source_ip, now_ms):
		return { "ok": false, "code": "rate_limited" }
	var key := RegistryWire.entry_key(source_ip, int(hb["game_port"]))
	var e: Dictionary = entries.get(key, {})
	if e.is_empty():
		if count_for(source_ip) >= MAX_PER_ADDRESS:
			return { "ok": false, "code": "address_full" }
		if entries.size() >= MAX_ENTRIES:
			return { "ok": false, "code": "registry_full" }
		e = { "ip": source_ip, "game_port": int(hb["game_port"]), "listed": false, "probe_state": "due", "probe_ms": 0 }
		entries[key] = e
	elif int(e["status_port"]) != int(hb["status_port"]):
		e["listed"] = false   # a new status port answers for itself before the entry is listed again
		e["probe_state"] = "due"
	elif not bool(e["listed"]) and str(e["probe_state"]) == "":
		e["probe_state"] = "due"   # an earlier back-probe went unanswered: try again on this heartbeat
	for k in ["status_port", "world_name", "region", "protocol", "players", "max_players"]:
		e[k] = hb[k]
	e["last_ms"] = now_ms
	return { "ok": true, "listed": bool(e["listed"]) }

## The back-probes to send now: [{key, ip, status_port}]. Each is marked sent; one that is not answered within
## PROBE_TIMEOUT_MS is given up by `sweep`.
func probe_due(now_ms: int) -> Array:
	var out: Array = []
	for key in entries:
		var e: Dictionary = entries[key]
		if str(e["probe_state"]) == "due":
			e["probe_state"] = "sent"
			e["probe_ms"] = now_ms
			out.append({ "key": key, "ip": str(e["ip"]), "status_port": int(e["status_port"]) })
	return out

## The status answer to the back-probe for `key`, received from `from_ip`. The entry is listed when the answer came
## from the entry's own IP and names its game port. True when it was listed.
func probe_answered(key: String, from_ip: String, status: Dictionary) -> bool:
	var e: Dictionary = entries.get(key, {})
	if e.is_empty() or str(e["probe_state"]) != "sent":
		return false
	if from_ip != str(e["ip"]) or int(status.get("game_port", 0)) != int(e["game_port"]):
		return false
	e["probe_state"] = ""
	e["listed"] = true
	return true

## Drop entries that missed their heartbeats and give up back-probes that timed out. Returns the keys dropped.
func sweep(now_ms: int) -> Array:
	var gone: Array = []
	for key in entries.keys():
		var e: Dictionary = entries[key]
		if now_ms - int(e["last_ms"]) > drop_after_ms():
			entries.erase(key)
			gone.append(key)
		elif str(e["probe_state"]) == "sent" and now_ms - int(e["probe_ms"]) > PROBE_TIMEOUT_MS:
			e["probe_state"] = ""
	return gone

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

func count_for(ip: String) -> int:
	var n := 0
	for key in entries:
		if str(entries[key]["ip"]) == ip:
			n += 1
	return n

func _admit(ip: String, now_ms: int) -> bool:
	if _rate_window_start < 0 or now_ms - _rate_window_start >= interval_s * 1000:
		_rate_window_start = now_ms
		_rate.clear()
	var n := int(_rate.get(ip, 0))
	if n >= HEARTBEATS_PER_WINDOW:
		return false
	if n == 0 and _rate.size() >= MAX_RATE_SOURCES:
		return false
	_rate[ip] = n + 1
	return true
