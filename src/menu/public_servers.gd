extends RefCounted
## Phase 298 — the Join screen's "Public servers" tab, without the UI: the list fetched from the registries, each
## server's own status answer (queried by this client, never taken from the registry), the disk cache, and the rows
## as shown after sort and filter.
##
## The list is cached on disk (`user://server_list.json`) and shown at once on the next open while a fresh fetch
## runs. The cache is read back as untrusted input (`RegistryWire.decode_list`). Status queries go out at most
## PARALLEL at a time, each given up after QUERY_TIMEOUT_MS. A host listed on both IPv4 and IPv6 answers with one
## `instance` and is shown once (on IPv4, which needs no scope).

const I18n := preload("res://src/core/i18n.gd")
const NetAddress := preload("res://src/networking/net_address.gd")
const ServerProbe := preload("res://src/networking/server_probe.gd")
const ServerStatus := preload("res://src/networking/server_status.gd")
const RegistryWire := preload("res://src/networking/registry_wire.gd")
const RegistryClient := preload("res://src/networking/registry_client.gd")

const DEFAULT_CACHE_PATH := "user://server_list.json"
const PARALLEL := 16
const QUERY_TIMEOUT_MS := 2000
## While the tab shows, the list is fetched again this often.
const REFRESH_MS := 15000
const SORT_PING := "ping"
const SORT_PLAYERS := "players"

var cache_path: String = DEFAULT_CACHE_PATH
var refresh_ms: int = REFRESH_MS
var registries: Array = []
## The registry's entries (`RegistryWire.decode_list`).
var entries: Array = []
## entry key → {rtt_ms, status, ip, at}
var answers: Dictionary = {}
## "" or a catalog key: what the tab says above the list.
var notice: String = ""
var fetching: bool = false
var _client := RegistryClient.new()
var _probe: ServerProbe = null
var _queue: Array = []
## entry key → sent at (ms)
var _inflight: Dictionary = {}
var _fetched: Dictionary = {}
var _fetch_ok: bool = false
var _next_fetch_ms: int = 0

## Start: the cached list at once, then a fetch. Returns false when the status socket would not open.
func open(now_ms: int = Time.get_ticks_msec()) -> bool:
	close()
	entries = load_cache(cache_path)
	_probe = ServerProbe.new()
	if _probe.open() != OK:
		_probe = null
		notice = "menu.public.error_socket"
		return false
	_queue_all()
	refresh(now_ms)
	return true

func close() -> void:
	_client.cancel()
	if _probe != null:
		_probe.close()
		_probe = null
	_queue.clear()
	_inflight.clear()
	fetching = false

func is_open() -> bool:
	return _probe != null

## Ask the registries again (also on a timer while open).
func refresh(now_ms: int = Time.get_ticks_msec()) -> void:
	_next_fetch_ms = now_ms + refresh_ms
	if registries.is_empty():
		notice = "menu.public.no_registries"
		return
	if _client.busy():
		return
	_fetched.clear()
	_fetch_ok = false
	fetching = _client.fetch_lists(registries, now_ms) > 0
	notice = "menu.public.fetching" if fetching else "menu.public.no_registries"

## Advance the fetch and the status queries. True when the rows may have changed.
func poll(now_ms: int = Time.get_ticks_msec()) -> bool:
	if _probe == null:
		return false
	var changed := false
	if now_ms >= _next_fetch_ms:
		refresh(now_ms)
	for r in _client.poll(now_ms):
		if bool(r["ok"]) and str(r["message"].get("type", "")) == "list":
			_fetch_ok = true
			for e in RegistryWire.decode_list(r["message"]):
				_fetched[RegistryWire.entry_key(str(e["ip"]), int(e["game_port"]))] = e
	if fetching and not _client.busy():
		fetching = false
		changed = true
		if _fetch_ok:
			apply_list(_fetched.values().slice(0, RegistryWire.MAX_LIST))
			save_cache(cache_path, entries)
		else:
			notice = "menu.public.error_fetch"
	for k in _inflight.keys():
		if now_ms - int(_inflight[k]) > QUERY_TIMEOUT_MS:
			_inflight.erase(k)
	while _inflight.size() < PARALLEL and not _queue.is_empty():
		var e: Dictionary = _queue.pop_front()
		var key := RegistryWire.entry_key(str(e["ip"]), int(e["game_port"]))
		if _probe.query_ip(str(e["ip"]), int(e["status_port"]), "pub:" + key, now_ms):
			_inflight[key] = now_ms
	for ans in _probe.poll(now_ms):
		var key := str(ans["key"]).trim_prefix("pub:")
		_inflight.erase(key)
		if apply_answer(key, ans):
			changed = true
	return changed

## A fresh list replaces the old one; answers of servers no longer listed go, and every server is asked again.
func apply_list(list: Array) -> void:
	entries = list
	var keep := {}
	for e in entries:
		keep[RegistryWire.entry_key(str(e["ip"]), int(e["game_port"]))] = true
	for k in answers.keys():
		if not keep.has(k):
			answers.erase(k)
	notice = "" if not entries.is_empty() else "menu.public.none"
	_queue_all()

## A status answer for entry `key`. Counted only when it came from the entry's own IP and names its game port.
func apply_answer(key: String, ans: Dictionary) -> bool:
	for e in entries:
		if RegistryWire.entry_key(str(e["ip"]), int(e["game_port"])) == key:
			var st: Dictionary = ans["status"]
			if str(ans["ip"]) != str(e["ip"]) or int(st["game_port"]) != int(e["game_port"]):
				return false
			answers[key] = { "rtt_ms": int(ans["rtt_ms"]), "status": st, "ip": str(ans["ip"]), "at": int(ans.get("at", 0)) }
			return true
	return false

## Queue the status queries: servers with no answer, in random order (so a long list of silent entries a registry
## puts first cannot keep real servers from ever being asked), then those whose answer is older than a refresh.
func _queue_all(now_ms: int = Time.get_ticks_msec()) -> void:
	var fresh: Array = []
	var stale: Array = []
	for e in entries:
		var a: Dictionary = answers.get(RegistryWire.entry_key(str(e["ip"]), int(e["game_port"])), {})
		if a.is_empty():
			fresh.append(e)
		elif now_ms - int(a.get("at", 0)) >= refresh_ms:
			stale.append(e)
	fresh.shuffle()
	_queue = fresh + stale
	_inflight.clear()

# ---------------------------------------------------------------------------
# Rows
# ---------------------------------------------------------------------------

## The rows as shown: [{key, name, region, players, max_players, ping, version, joinable, full, address,
## answered}], filtered by `filter` (in the name or the region's label, any case) and `hide_full`, sorted by
## SORT_PING (unanswered last) or SORT_PLAYERS (most first). Names are the host's text, shown as given.
func rows(filter: String = "", hide_full: bool = false, sort_by: String = SORT_PING) -> Array:
	var by_instance := {}
	var out: Array = []
	for e in entries:
		var key := RegistryWire.entry_key(str(e["ip"]), int(e["game_port"]))
		var r := row_of(e, answers.get(key, {}))
		r["key"] = key
		if bool(r["answered"]):
			# One host heard on both families is shown once, on IPv4 (it needs no scope). Two rows are one host only
			# when one is IPv4 and the other IPv6, on the same game port, and their status answers agree on the
			# instance, world, version and counts; anything less keeps both rows, so a server that copies another's
			# instance cannot hide or replace it unless it mirrors that host's live answer (Phase 299's signed
			# entries close that last gap).
			var twin := _twin_key(answers[key]["status"], int(e["game_port"]))
			var fam := "v6" if NetAddress.is_v6(str(r["ip"])) else "v4"
			var other_fam := "v4" if fam == "v6" else "v6"
			if by_instance.has(twin + other_fam) and not by_instance.has(twin + fam):
				var other: Dictionary = by_instance[twin + other_fam]
				by_instance[twin + fam] = r
				if fam == "v6":
					continue   # the IPv4 row is already shown
				out.erase(other)
			elif not by_instance.has(twin + fam):
				by_instance[twin + fam] = r
		out.append(r)
	var want := filter.strip_edges().to_lower()
	var kept: Array = []
	for r in out:
		if hide_full and bool(r["full"]):
			continue
		if want != "" and not str(r["name"]).to_lower().contains(want) and not str(r["region_label"]).to_lower().contains(want):
			continue
		kept.append(r)
	kept.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if sort_by == SORT_PLAYERS and int(a["players"]) != int(b["players"]):
			return int(a["players"]) > int(b["players"])
		var pa := int(a["ping"]) if bool(a["answered"]) else 1 << 30
		var pb := int(b["ping"]) if bool(b["answered"]) else 1 << 30
		if pa != pb:
			return pa < pb
		return str(a["name"]) < str(b["name"]))
	return kept

## What two rows of one dual-stack host share: the instance, the game port and the live answer's fields.
static func _twin_key(st: Dictionary, game_port: int) -> String:
	return "%d|%d|%s|%s|%d|%d|" % [int(st["instance"]), game_port, str(st["world_name"]), str(st["game_version"]),
		int(st["players"]), int(st["max_players"])]

## One row from a registry entry and this client's own status answer (`ans`, {} while none arrived). Before an
## answer the registry's counts are shown and the ping is unknown.
static func row_of(e: Dictionary, ans: Dictionary) -> Dictionary:
	var answered := not ans.is_empty()
	var st: Dictionary = ans.get("status", {}) if answered else {}
	var name := str(st.get("world_name", e["world_name"]))
	if name == "":
		name = I18n.t("menu.join.lan_unnamed")
	var protocol := int(st.get("protocol", -1))
	var players := int(st.get("players", e["players"]))
	var max_players := int(st.get("max_players", e["max_players"]))
	var region := str(e["region"])
	return {
		"ip": str(e["ip"]),
		"name": name,
		"region": region,
		"region_label": I18n.t("menu.region." + (region if region != "" else "none")),
		"players": players,
		"max_players": max_players,
		"ping": int(ans.get("rtt_ms", -1)),
		"version": str(st.get("game_version", "")),
		# Joinable only once this client heard the server itself, on this protocol: a registry's word alone never
		# sends a player to an address.
		"joinable": answered and ServerStatus.protocol_refusal(ServerStatus.PROTOCOL_VERSION, protocol) == "",
		"refusal": "menu.public.no_answer" if not answered else ServerStatus.protocol_refusal(ServerStatus.PROTOCOL_VERSION, protocol),
		"full": max_players > 0 and players >= max_players,
		"address": NetAddress.format(str(e["ip"]), int(e["game_port"])),
		"answered": answered,
	}

## The texts of one row's columns, in the active locale: {name, region, players, ping, version}.
static func row_texts(r: Dictionary) -> Dictionary:
	return {
		"name": str(r["name"]),
		"region": str(r["region_label"]),
		"players": I18n.t("menu.public.players_value", [I18n.number(int(r["players"])), I18n.number(int(r["max_players"]))]),
		"ping": I18n.t("menu.join.ping", [I18n.number(int(r["ping"]))]) if bool(r["answered"]) else I18n.t("menu.public.ping_unknown"),
		"version": str(r["version"]) if bool(r["joinable"]) or not bool(r["answered"]) else I18n.t("menu.public.other_version"),
	}

# ---------------------------------------------------------------------------
# Cache
# ---------------------------------------------------------------------------

static func load_cache(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not (json.data is Dictionary):
		return []
	return RegistryWire.decode_list({ "type": "list", "servers": (json.data as Dictionary).get("servers", []) })

static func save_cache(path: String, list: Array) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(RegistryWire.list_reply(list)))
	f.close()
