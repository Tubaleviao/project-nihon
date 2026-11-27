class_name BakeTransfer
extends RefCounted
## Phase 302 — the host's copy of the planet bake, the pure half: chunking, bounds, reassembly and the hash check.
## A bake is about 4 MB, so it travels in `CHUNK_BYTES` pieces a client pulls one at a time. Nothing here touches
## the network: `Server` is what the host keeps per peer (rate limits), `Fetch` what a client keeps while it
## downloads. Glue is in `bake_net.gd`.
##
## Trust boundary. The host bounds how often a peer may ask and how much it is served. The client takes the SIZE
## from its OWN w x h (the layout `PlanetBake.to_bytes` writes), never from the host, refuses an offer that
## names another size, hash or chunking, allocates once and only up to that size, accepts a piece only at its
## exact length and place, and trusts the result only when its SHA-256 is the one it was told to expect.

const PlanetBake := preload("res://src/terrain/planet_bake.gd")
## This script, for the inner classes: they cannot name the outer `class_name` on a boot with no class cache.
const Transfer := preload("res://src/networking/bake_transfer.gd")

## Raw bytes per piece; the wire carries them base64 (about 16.4 KB of text), well under an ENet packet.
const CHUNK_BYTES := 12288
## The longest base64 text a piece may carry, checked before it is decoded.
const MAX_CHUNK_TEXT := (CHUNK_BYTES + 2) / 3 * 4
## The largest bake a client will hold, whatever a host claims.
const MAX_BAKE_BYTES := 12 + PlanetBake.MAX_CELLS * 13

## Host: one offer per peer per this long (an offer is cheap, but it must not be a flood).
const OFFER_INTERVAL_MS := 2000.0
## Host: a peer's piece budget, a bucket (burst, refill per second).
const CHUNK_BURST := 24.0
const CHUNK_REFILL_PER_SEC := 80.0
## Host: pieces served to one peer over a connection, as a multiple of the bake's piece count (retries after a
## refused or lost piece, one full re-download). Past it the peer is refused until it reconnects.
const SERVE_LIMIT_FACTOR := 3


## The two sizes a bake of w x h cells can have: without and with the biome byte.
static func valid_sizes(w: int, h: int) -> PackedInt32Array:
	if w <= 0 or h <= 0 or w * h > PlanetBake.MAX_CELLS:
		return PackedInt32Array()
	return PackedInt32Array([12 + w * h * 12, 12 + w * h * 13])


static func size_fits(size: int, w: int, h: int) -> bool:
	return valid_sizes(w, h).has(size)


static func chunk_count(size: int) -> int:
	return maxi(1, ceili(float(size) / float(CHUNK_BYTES)))


## Raw length of piece `index` of a `size`-byte bake (0 when out of range).
static func chunk_len(size: int, index: int) -> int:
	if index < 0 or index >= chunk_count(size):
		return 0
	return mini(CHUNK_BYTES, size - index * CHUNK_BYTES)


static func chunk_at(bytes: PackedByteArray, index: int) -> PackedByteArray:
	return bytes.slice(index * CHUNK_BYTES, mini(bytes.size(), (index + 1) * CHUNK_BYTES))


## Host side: the bytes it serves and, per peer, what it has served and when.
class Server extends RefCounted:
	var bytes := PackedByteArray()
	var hash := ""
	var _peers: Dictionary = {}   # peer -> { tokens, at_ms, offer_ms, served }

	func set_bake(b: PackedByteArray) -> void:
		bytes = b
		hash = PlanetBake.hash_hex(b) if not b.is_empty() else ""

	func has_bake() -> bool:
		return not bytes.is_empty() and bytes.size() <= MAX_BAKE_BYTES

	func forget(peer: int) -> void:
		_peers.erase(peer)

	func peer_count() -> int:
		return _peers.size()

	func _state(peer: int, now_ms: float) -> Dictionary:
		if not _peers.has(peer):
			_peers[peer] = { "tokens": CHUNK_BURST, "at_ms": now_ms, "offer_ms": -OFFER_INTERVAL_MS * 2.0, "served": 0 }
		return _peers[peer]

	## The offer a peer asked for, or {} when the host has no bake or the peer asks too often.
	func offer(peer: int, now_ms: float) -> Dictionary:
		if not has_bake():
			return {}
		var st := _state(peer, now_ms)
		if now_ms - float(st["offer_ms"]) < OFFER_INTERVAL_MS:
			return {}
		st["offer_ms"] = now_ms
		return { "hash": hash, "size": bytes.size(), "chunk": CHUNK_BYTES, "count": Transfer.chunk_count(bytes.size()) }

	## Piece `index` for a peer ({ index, data }), or {} when out of range, over the peer's rate or over its
	## serve limit.
	func chunk(peer: int, index: int, now_ms: float) -> Dictionary:
		if not has_bake() or index < 0 or index >= Transfer.chunk_count(bytes.size()):
			return {}
		var st := _state(peer, now_ms)
		var elapsed := maxf(0.0, now_ms - float(st["at_ms"]))
		st["at_ms"] = now_ms
		st["tokens"] = minf(CHUNK_BURST, float(st["tokens"]) + elapsed * 0.001 * CHUNK_REFILL_PER_SEC)
		if float(st["tokens"]) < 1.0 or int(st["served"]) >= SERVE_LIMIT_FACTOR * Transfer.chunk_count(bytes.size()):
			return {}
		st["tokens"] = float(st["tokens"]) - 1.0
		st["served"] = int(st["served"]) + 1
		return { "index": index, "data": Marshalls.raw_to_base64(Transfer.chunk_at(bytes, index)) }


## Client side: one download, sized from the client's own expectation.
class Fetch extends RefCounted:
	var expected_hash := ""
	var w := 0
	var h := 0
	var size := 0
	var _buf := PackedByteArray()
	var _got := PackedByteArray()   # one byte per piece: 1 when stored
	var _have := 0

	func _init(hash_expected: String, w_cells: int, h_cells: int) -> void:
		expected_hash = hash_expected
		w = w_cells
		h = h_cells

	## True when the host's offer names this client's hash, a size its own w x h can have, and the fixed chunking;
	## only then is the buffer allocated.
	func begin(offer: Dictionary) -> bool:
		if expected_hash == "" or not _is_int(offer.get("size")) or not _is_int(offer.get("chunk")) or not _is_int(offer.get("count")):
			return false
		var sz := int(offer["size"])
		if str(offer.get("hash", "")) != expected_hash or not Transfer.size_fits(sz, w, h) \
				or int(offer["chunk"]) != CHUNK_BYTES or int(offer["count"]) != Transfer.chunk_count(sz):
			return false
		size = sz
		_buf.resize(size)
		_got.resize(Transfer.chunk_count(size))
		_have = 0
		return true

	static func _is_int(v: Variant) -> bool:
		return v is int or (v is float and is_finite(v) and v == floorf(v))

	func started() -> bool:
		return size > 0

	func count() -> int:
		return _got.size()

	## Store one piece; false (nothing stored) when it is out of range, repeated, over long, or not exactly the
	## length its place needs.
	func accept(index: int, data: Variant) -> bool:
		if size == 0 or index < 0 or index >= _got.size() or _got[index] == 1 or not (data is String):
			return false
		if (data as String).length() > MAX_CHUNK_TEXT:
			return false
		var raw := Marshalls.base64_to_raw(data)
		if raw.size() != Transfer.chunk_len(size, index):
			return false
		for i in raw.size():
			_buf[index * CHUNK_BYTES + i] = raw[i]
		_got[index] = 1
		_have += 1
		return true

	## The first piece not yet held, -1 when all are.
	func next_needed() -> int:
		for i in _got.size():
			if _got[i] == 0:
				return i
		return -1

	func complete() -> bool:
		return size > 0 and _have == _got.size()

	## The assembled bytes when complete and their SHA-256 is the expected one; empty otherwise.
	func verified_bytes() -> PackedByteArray:
		if not complete() or PlanetBake.hash_hex(_buf) != expected_hash:
			return PackedByteArray()
		return _buf
