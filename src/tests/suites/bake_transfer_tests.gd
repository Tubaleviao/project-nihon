extends "res://src/tests/test_support.gd"
## Phase 302 — the host's copy of the planet bake: chunking and reassembly, the hash refusal, the size bounds a
## client holds a host to, and the host's per-peer limits. The wire itself is the `planet_bake_fetch` harness step.

const Bake := preload("res://src/terrain/planet_bake.gd")
const BT := preload("res://src/networking/bake_transfer.gd")
const W := 48
const H := 24

func register() -> void:
	_run_test("bake transfer: pieces cover the bake exactly and reassemble to the host's bytes", _test_roundtrip)
	_run_test("bake transfer: a corrupted piece or a changed byte is refused by the hash", _test_corrupt_refused)
	_run_test("bake transfer: an offer that is not this client's hash, size or chunking allocates nothing", _test_offer_bounds)
	_run_test("bake transfer: pieces are refused out of range, repeated, over long or the wrong length", _test_piece_bounds)
	_run_test("bake transfer: the host rate-limits offers and pieces per peer and caps what it serves", _test_host_limits)
	_run_test("bake transfer: the host without a bake offers and serves nothing", _test_no_bake)

func _bake_bytes() -> PackedByteArray:
	var b: Dictionary = Bake.bake_planet(7, W, H, 800000.0, 12)
	return Bake.to_bytes(b)

func _offer(bytes: PackedByteArray) -> Dictionary:
	return { "hash": Bake.hash_hex(bytes), "size": bytes.size(), "chunk": BT.CHUNK_BYTES, "count": BT.chunk_count(bytes.size()) }

func _test_roundtrip() -> void:
	var bytes := _bake_bytes()
	assert_true(BT.size_fits(bytes.size(), W, H), "a baked planet's size is one of its two layouts")
	var total := 0
	for i in BT.chunk_count(bytes.size()):
		total += BT.chunk_at(bytes, i).size()
		assert_eq(BT.chunk_at(bytes, i).size(), BT.chunk_len(bytes.size(), i), "piece %d length" % i)
	assert_eq(total, bytes.size(), "the pieces add up to the bake")
	assert_eq(BT.chunk_len(bytes.size(), BT.chunk_count(bytes.size())), 0, "past the last piece has no length")
	var srv := BT.Server.new()
	srv.set_bake(bytes)
	var f := BT.Fetch.new(srv.hash, W, H)
	assert_true(f.begin(srv.offer(2, 0.0)), "the offer is taken")
	var now := 0.0
	while f.next_needed() >= 0:
		now += 100.0   # 10 pieces a second: inside the refill
		var want := f.next_needed()
		var piece := srv.chunk(2, want, now)
		assert_true(not piece.is_empty() and f.accept(int(piece.index), piece.data), "piece %d stored" % want)
	assert_true(f.complete(), "all pieces held")
	assert_eq(f.verified_bytes(), bytes, "the client ends with the host's bytes")
	assert_true(not Bake.from_bytes(f.verified_bytes(), srv.hash).is_empty(), "and they parse as a bake")

func _test_corrupt_refused() -> void:
	var bytes := _bake_bytes()
	var bad := bytes.duplicate()
	bad[bad.size() / 2] ^= 0x55
	var f := BT.Fetch.new(Bake.hash_hex(bytes), W, H)
	assert_true(f.begin(_offer(bytes)), "the honest offer is taken")
	for i in BT.chunk_count(bytes.size()):
		assert_true(f.accept(i, Marshalls.raw_to_base64(BT.chunk_at(bad, i))), "a corrupt piece has the right shape, so it is stored")
	assert_true(f.complete(), "the download finishes")
	assert_true(f.verified_bytes().is_empty(), "but the hash refuses it")
	var half := BT.Fetch.new(Bake.hash_hex(bytes), W, H)
	half.begin(_offer(bytes))
	half.accept(0, Marshalls.raw_to_base64(BT.chunk_at(bytes, 0)))
	assert_true(not half.complete() and half.verified_bytes().is_empty(), "an unfinished download yields nothing")

func _test_offer_bounds() -> void:
	var bytes := _bake_bytes()
	var good := _offer(bytes)
	var cases := {
		"wrong hash": { "hash": "00" + str(good.hash).substr(2) },
		"huge size": { "size": 1 << 40, "count": BT.chunk_count(1 << 40) },
		"size of another grid": { "size": bytes.size() + 1, "count": BT.chunk_count(bytes.size() + 1) },
		"zero size": { "size": 0, "count": 1 },
		"negative size": { "size": -5, "count": 1 },
		"other chunking": { "chunk": 1 },
		"wrong count": { "count": 3 },
		"text size": { "size": "999" },
	}
	for k in cases:
		var o: Dictionary = good.duplicate()
		o.merge(cases[k], true)
		var f := BT.Fetch.new(str(good.hash), W, H)
		assert_true(not f.begin(o) and not f.started(), "offer refused: %s" % k)
		assert_true(not f.accept(0, "AAAA"), "nothing is stored after a refused offer: %s" % k)
	assert_true(BT.valid_sizes(0, 5).is_empty() and BT.valid_sizes(2000, 2000).is_empty(), "a grid over the cell cap has no valid size")
	assert_true(BT.MAX_BAKE_BYTES <= 13 * 1000 * 1000 + 12, "the most a client can ever allocate is bounded by the cell cap")
	assert_true(not BT.Fetch.new("", W, H).begin(good), "no expected hash, no download")

func _test_piece_bounds() -> void:
	var bytes := _bake_bytes()
	var f := BT.Fetch.new(Bake.hash_hex(bytes), W, H)
	f.begin(_offer(bytes))
	var p0 := Marshalls.raw_to_base64(BT.chunk_at(bytes, 0))
	assert_true(not f.accept(-1, p0) and not f.accept(BT.chunk_count(bytes.size()), p0), "out of range refused")
	assert_true(not f.accept(0, 5) and not f.accept(0, null), "not text refused")
	assert_true(not f.accept(0, "A".repeat(BT.MAX_CHUNK_TEXT + 4)), "over-long text refused before it is decoded")
	assert_true(not f.accept(0, Marshalls.raw_to_base64(BT.chunk_at(bytes, 0).slice(0, 100))), "short piece refused")
	assert_true(f.accept(0, p0), "the right piece at its place is stored")
	assert_true(not f.accept(0, p0), "a repeated piece is refused")
	var last := BT.chunk_count(bytes.size()) - 1
	assert_true(last == 0 or not f.accept(last, p0), "a full piece in the short last place is refused")

func _test_host_limits() -> void:
	var bytes := _bake_bytes()
	var srv := BT.Server.new()
	srv.set_bake(bytes)
	assert_true(not srv.offer(2, 0.0).is_empty(), "the first offer is given")
	assert_true(srv.offer(2, 100.0).is_empty(), "a second offer at once is refused")
	assert_true(not srv.offer(3, 100.0).is_empty(), "another peer is not affected")
	assert_true(not srv.offer(2, BT.OFFER_INTERVAL_MS + 1.0).is_empty(), "an offer after the interval is given")
	var given := 0
	for i in 100:
		if not srv.chunk(4, 0, 0.0).is_empty():
			given += 1
	assert_eq(given, mini(int(BT.CHUNK_BURST), BT.SERVE_LIMIT_FACTOR * BT.chunk_count(bytes.size())), "a burst of requests at one instant gets only the bucket (or the cap)")
	assert_true(srv.chunk(5, -1, 0.0).is_empty() and srv.chunk(5, BT.chunk_count(bytes.size()), 0.0).is_empty(), "out of range index is not served")
	var total := 0
	var t := 10000.0
	for round_i in 100:
		t += 1000.0
		for i in 100:
			if not srv.chunk(6, 0, t).is_empty():
				total += 1
	assert_eq(total, BT.SERVE_LIMIT_FACTOR * BT.chunk_count(bytes.size()), "a peer is served at most the cap over a connection")
	srv.forget(6)
	assert_true(not srv.chunk(6, 0, t + 1.0).is_empty(), "a reconnect starts again")
	assert_true(srv.peer_count() >= 1, "peers are tracked")

func _test_no_bake() -> void:
	var srv := BT.Server.new()
	assert_true(srv.offer(2, 0.0).is_empty() and srv.chunk(2, 0, 0.0).is_empty(), "nothing to serve")
