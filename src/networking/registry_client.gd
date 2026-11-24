extends RefCounted
## Phase 298 — talking to registries from a public host (heartbeats) or a client (list queries), polled without
## blocking. Names are resolved on the resolver queue; each exchange is a `RegistryExchange`.
##
## A heartbeat goes once to each address family a registry resolves to (its first IPv4 and first IPv6 address), so a
## dual-stack host is verified, and listed, on both. A list query tries the registry's addresses in order until one
## answers. `poll` hands back what finished: [{kind, registry, ip, ok, message, error}].

const RegistryWire := preload("res://src/networking/registry_wire.gd")
const RegistryExchange := preload("res://src/networking/registry_exchange.gd")
const NetAddress := preload("res://src/networking/net_address.gd")

const MAX_REGISTRIES := 8
const RESOLVE_TIMEOUT_MS := 5000

## [{kind, registry, port, request, reply_cap, addrs, resolve_id, resolve_ms, exchange}]
var _jobs: Array = []

func busy() -> bool:
	return not _jobs.is_empty()

## One heartbeat (`RegistryWire.heartbeat(info)`) to each registry in `registries`, over each family it resolves to.
func send_heartbeats(registries: Array, info: Dictionary, now_ms: int = Time.get_ticks_msec()) -> int:
	return _start(registries, "heartbeat", RegistryWire.heartbeat(info), RegistryWire.MAX_REQUEST_BYTES, now_ms)

## One list query to each registry in `registries`.
func fetch_lists(registries: Array, now_ms: int = Time.get_ticks_msec()) -> int:
	return _start(registries, "list", { "type": "list" }, RegistryWire.MAX_LIST_BYTES, now_ms)

func cancel() -> void:
	for j in _jobs:
		if j["exchange"] != null:
			j["exchange"].close()
		if int(j["resolve_id"]) != IP.RESOLVER_INVALID_ID:
			IP.erase_resolve_item(int(j["resolve_id"]))
	_jobs.clear()

func _start(registries: Array, kind: String, request: Dictionary, reply_cap: int, now_ms: int) -> int:
	var n := 0
	for raw in registries.slice(0, MAX_REGISTRIES):
		var a := RegistryWire.parse_registry(str(raw))
		if not bool(a["ok"]):
			continue
		var job := { "kind": kind, "registry": str(raw), "port": int(a["port"]), "request": request,
			"reply_cap": reply_cap, "addrs": [], "resolve_id": IP.RESOLVER_INVALID_ID, "resolve_ms": now_ms,
			"exchange": null }
		if str(a["family"]) == NetAddress.FAMILY_NAME:
			job["resolve_id"] = IP.resolve_hostname_queue_item(str(a["host"]), IP.TYPE_ANY)
			if int(job["resolve_id"]) == IP.RESOLVER_INVALID_ID:
				continue
		else:
			job["addrs"] = [str(a["host"])]
		_jobs.append(job)
		n += 1
		if int(job["resolve_id"]) == IP.RESOLVER_INVALID_ID:
			_resolved(job, now_ms)
	return n

## A job whose addresses are known: a heartbeat splits into one job per family; a list query dials the first address.
func _resolved(job: Dictionary, now_ms: int) -> void:
	var addrs: Array = job["addrs"]
	if str(job["kind"]) == "heartbeat":
		addrs = families(addrs)
		if addrs.size() > 1:
			var twin := job.duplicate()
			twin["addrs"] = [addrs[1]]
			twin["exchange"] = RegistryExchange.dial(str(addrs[1]), int(job["port"]), job["request"], int(job["reply_cap"]), now_ms)
			_jobs.append(twin)
		job["addrs"] = addrs.slice(0, 1)
	if (job["addrs"] as Array).is_empty():
		return
	job["exchange"] = RegistryExchange.dial(str(job["addrs"][0]), int(job["port"]), job["request"], int(job["reply_cap"]), now_ms)

## The first IPv4 and the first IPv6 address of `addrs`, IPv6 first.
static func families(addrs: Array) -> Array:
	var v4 := ""
	var v6 := ""
	for a in addrs:
		var s := str(a)
		if NetAddress.is_v6(s):
			if v6 == "":
				v6 = s
		elif s.is_valid_ip_address() and v4 == "":
			v4 = s
	var out: Array = []
	if v6 != "":
		out.append(v6)
	if v4 != "":
		out.append(v4)
	return out

func poll(now_ms: int = Time.get_ticks_msec()) -> Array:
	var out: Array = []
	for job in _jobs.duplicate():
		if job["exchange"] == null:
			var id := int(job["resolve_id"])
			var st := IP.get_resolve_item_status(id) if id != IP.RESOLVER_INVALID_ID else IP.RESOLVER_STATUS_ERROR
			if st == IP.RESOLVER_STATUS_WAITING and now_ms - int(job["resolve_ms"]) < RESOLVE_TIMEOUT_MS:
				continue
			if st == IP.RESOLVER_STATUS_DONE:
				job["addrs"] = Array(IP.get_resolve_item_addresses(id))
			if id != IP.RESOLVER_INVALID_ID:
				IP.erase_resolve_item(id)
			job["resolve_id"] = IP.RESOLVER_INVALID_ID
			_resolved(job, now_ms)
			if job["exchange"] == null:
				out.append(_result(job, "", false, {}, "resolve"))
				_jobs.erase(job)
			continue
		var x: RefCounted = job["exchange"]
		x.poll(now_ms)
		if not x.finished():
			continue
		if x.state == RegistryExchange.DONE:
			out.append(_result(job, x.peer_ip, true, x.message, ""))
			_jobs.erase(job)
			continue
		var addrs: Array = job["addrs"]
		if str(job["kind"]) == "list" and addrs.size() > 1:
			addrs.pop_front()   # the next address of the same registry
			job["exchange"] = RegistryExchange.dial(str(addrs[0]), int(job["port"]), job["request"], int(job["reply_cap"]), now_ms)
			continue
		out.append(_result(job, x.peer_ip, false, {}, x.error))
		_jobs.erase(job)
	return out

static func _result(job: Dictionary, ip: String, ok: bool, message: Dictionary, error: String) -> Dictionary:
	return { "kind": str(job["kind"]), "registry": str(job["registry"]), "ip": ip, "ok": ok, "message": message, "error": error }
