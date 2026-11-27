extends RefCounted
## Phase 302 — the host's copy of the planet bake on the wire. A client sends `bake_request` (`op` "offer", or
## "chunk" with an `index`); the host answers `bake_offer` (hash, size, chunking) and `bake_chunk` (index, base64
## data). The client pulls one piece at a time, so the host never pushes more than a peer asked for. The rules
## (bounds, rate limits, the hash check) are in `bake_transfer.gd`; this is the glue. A fetch that fails (an
## offer that is not this client's, a corrupt or over-long piece, a hash that differs, a silent host) ends with
## `GameBus.planet_bake_fetched(false, ...)`, and the caller bakes from the seed instead.

const BakeTransfer := preload("res://src/networking/bake_transfer.gd")
## A fetch with no progress for this long fails.
const STALL_MS := 20000.0
## Pieces asked for at once (inside the host's burst of `BakeTransfer.CHUNK_BURST`).
const WINDOW := 4

var sl: Node
var serve := BakeTransfer.Server.new()
## Host: returns the bake's bytes (empty without a bake yet). Asked until it returns something, then the bytes
## are kept until `serve_bake` is called again; an empty answer is never kept.
var bytes_provider: Callable = Callable()
## Host: when `bytes_provider` may next be asked. It reads files, so a joined peer's requests while the host has no
## servable bake must not each cost a read: it is asked at most once per `BakeTransfer.OFFER_INTERVAL_MS`.
var provider_next_ms := 0.0
var _fetch: BakeTransfer.Fetch = null
var _last_progress_ms := 0.0
var _next_request := 0   ## the next piece index this fetch has not asked for
var _inflight := 0       ## pieces asked for and not yet received

func _init(slice: Node) -> void:
	sl = slice

func serve_bake(bytes: PackedByteArray) -> void:
	serve.set_bake(bytes)

func forget(peer: int) -> void:
	serve.forget(peer)

func _now() -> float:
	return float(Time.get_ticks_msec())

# --- host ---------------------------------------------------------------

## A client packet, routed from `_route_c2h`: only a host answers, and only with what the peer's budget allows.
func on_request(sender: int, payload: Dictionary) -> void:
	if sl._role != sl.Role.HOST:
		return
	# Only a peer that has joined (a bound identity) may ask: an unjoined connection costs the host nothing here.
	if str(sl.get_player_id(sender)) == "":
		return
	if not serve.has_bake() and bytes_provider.is_valid() and _now() >= provider_next_ms:
		provider_next_ms = _now() + BakeTransfer.OFFER_INTERVAL_MS
		serve_bake(bytes_provider.call())
	var op := str(payload.get("op", ""))
	if op == "offer":
		var offer := serve.offer(sender, _now())
		if not offer.is_empty():
			offer["type"] = "bake_offer"
			sl._deliver(sender, offer)
	elif op == "chunk":
		var idx: Variant = payload.get("index", -1)
		if not (idx is int or idx is float):
			return
		var piece := serve.chunk(sender, int(idx), _now())
		if not piece.is_empty():
			piece["type"] = "bake_chunk"
			sl._deliver(sender, piece)

# --- client -------------------------------------------------------------

## Start fetching the host's bake, which this client expects to hash to `expected_hash` and to be w x h cells.
func start_fetch(expected_hash: String, w: int, h: int) -> void:
	_fetch = BakeTransfer.Fetch.new(expected_hash, w, h)
	_last_progress_ms = _now()
	_next_request = 0
	_inflight = 0
	if expected_hash == "" or BakeTransfer.valid_sizes(w, h).is_empty():
		_finish(false)
		return
	sl._deliver(1, { "type": "bake_request", "op": "offer" })

func fetching() -> bool:
	return _fetch != null

func on_offer(payload: Dictionary) -> void:
	if _fetch == null or _fetch.started():
		return
	if not _fetch.begin(payload):
		_finish(false)
		return
	_last_progress_ms = _now()
	_fill_window()

func on_chunk(payload: Dictionary) -> void:
	if _fetch == null or not _fetch.started():
		return
	var idx: Variant = payload.get("index", -1)
	if not (idx is int or idx is float) or not _fetch.accept(int(idx), payload.get("data", null)):
		_finish(false)   # a piece that does not fit is a host that is wrong or hostile: no retry, bake locally
		return
	_last_progress_ms = _now()
	_inflight = maxi(0, _inflight - 1)
	if _fetch.complete():
		_finish(true)
	else:
		_fill_window()

## Keep up to `WINDOW` pieces asked for, in order, each once.
func _fill_window() -> void:
	while _inflight < WINDOW and _next_request < _fetch.count():
		sl._deliver(1, { "type": "bake_request", "op": "chunk", "index": _next_request })
		_next_request += 1
		_inflight += 1

## Called every frame by the slice: a host that goes quiet ends the fetch.
func poll() -> void:
	if _fetch != null and _now() - _last_progress_ms > STALL_MS:
		_finish(false)

func _finish(reached: bool) -> void:
	var f := _fetch
	_fetch = null
	var data := f.verified_bytes() if reached else PackedByteArray()
	GameBus.planet_bake_fetched.emit(not data.is_empty(), data, f.expected_hash)
