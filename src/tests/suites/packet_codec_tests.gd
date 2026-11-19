extends "res://src/tests/test_support.gd"
## Phase 256 — the binary layouts of the hot packets (`PacketCodec`): each type round-trips (positions to
## ±1,000 km), a packet one byte short or long is refused, a position report fits 20 bytes, JSON still reads,
## and the u16 `seq` wrap does not make the receiver's dedup refuse a new lap.

const PacketCodec := preload("res://src/networking/packet_codec.gd")

func register() -> void:
	_run_test("codec: remote_player_state round-trips to the centimetre at ±1,000 km", _test_state_round_trip)
	_run_test("codec: remote_player_state is at most 20 bytes on the wire", _test_state_size)
	_run_test("codec: snapshot_chunk and player_states round-trip", _test_chunk_and_batch)
	_run_test("codec: a packet one byte short or long is refused", _test_length_checks)
	_run_test("codec: a large packet is compressd and a lying length is refused", _test_compressed)
	_run_test("codec: JSON packets and legacy peers still read", _test_json)
	_run_test("codec: the host refuses a malformed binary packet and the seq wrap is read", _test_slice)

func _test_state_round_trip() -> void:
	for km in [-1000.0, -1.0, 0.0, 1.0, 1000.0]:
		var m: float = km * 1000.0
		var msg := { "type": "remote_player_state", "seq": 7, "peer_id": 12, "position": [m + 0.37, 12.5, -m] }
		var back: Dictionary = PacketCodec.decode(PacketCodec.encode(msg))
		assert_eq(str(back.get("type")), "remote_player_state", "type at %s km" % km)
		assert_eq(int(back.get("peer_id")), 12, "peer at %s km" % km)
		assert_eq(int(back.get("seq")), 7, "seq")
		for i in 3:
			assert_true(absf(float(back["position"][i]) - float(msg["position"][i])) <= 0.0051, "axis %d at %s km" % [i, km])

func _test_state_size() -> void:
	var b := PacketCodec.encode({ "type": "remote_player_state", "seq": 1, "peer_id": 3, "position": [1.0, 2.0, 3.0] })
	assert_true(b.size() <= 20, "%d bytes" % b.size())
	assert_true(b[0] != PacketCodec.JSON_FIRST_BYTE, "binary, not JSON")

func _test_chunk_and_batch() -> void:
	var chunk := { "type": "snapshot_chunk", "seq": 70000, "snapshot_id": 9, "index": 2, "count": 5, "data": "héllo {\"a\":1} ✓" }
	var back: Dictionary = PacketCodec.decode(PacketCodec.encode(chunk))
	assert_eq(str(back.get("data")), chunk["data"], "data")
	assert_eq(int(back.get("index")), 2, "index")
	assert_eq(int(back.get("count")), 5, "count")
	assert_eq(int(back.get("snapshot_id")), 9, "id")
	assert_eq(int(back.get("seq")), 70000 % 65536, "seq wraps")
	var pk: String = Marshalls.raw_to_base64(PackedByteArray([1, 0, 0, 0, 2, 0, 0, 0, 0, 0, 128, 63, 0, 0, 0, 64, 0, 0, 64, 64]))
	var batch := { "type": "player_states", "seq": 4, "s": [5, pk, 6, pk] }
	var got: Dictionary = PacketCodec.decode(PacketCodec.encode(batch))
	assert_eq(got.get("s"), batch["s"], "batch entries")

func _test_length_checks() -> void:
	var msgs := [
		{ "type": "remote_player_state", "seq": 1, "peer_id": 3, "position": [1.0, 2.0, 3.0] },
		{ "type": "snapshot_chunk", "seq": 1, "snapshot_id": 1, "index": 0, "count": 1, "data": "abc" },
		{ "type": "player_states", "seq": 1, "s": [5, Marshalls.raw_to_base64(PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]))] },
	]
	for m in msgs:
		var b := PacketCodec.encode(m)
		assert_false(PacketCodec.decode(b).is_empty(), "%s whole" % m["type"])
		assert_true(PacketCodec.decode(b.slice(0, b.size() - 1)).is_empty(), "%s one short" % m["type"])
		var long := b.duplicate()
		long.append(0)
		assert_true(PacketCodec.decode(long).is_empty(), "%s one long" % m["type"])
	assert_true(PacketCodec.decode(PackedByteArray([99, 0, 0])).is_empty(), "unknown tag")
	assert_true(PacketCodec.decode(PackedByteArray()).is_empty(), "empty")

func _test_compressed() -> void:
	var text := "{\"k\":\"%s\"}" % "abc".repeat(3000)
	var chunk := { "type": "snapshot_chunk", "seq": 3, "snapshot_id": 1, "index": 0, "count": 1, "data": text }
	var b := PacketCodec.encode(chunk)
	assert_true(b.size() < text.length() / 4, "compressd: %d bytes" % b.size())
	assert_eq(PacketCodec.decode(b).get("data"), text, "round trip")
	assert_true(PacketCodec.decode(b.slice(0, b.size() - 1)).is_empty(), "truncated compress refused")
	var bomb := b.duplicate()
	bomb.encode_u32(1, 0x7FFFFFFF)
	assert_true(PacketCodec.decode(bomb).is_empty(), "stated length over the cap refused")
	var wrong := b.duplicate()
	wrong[0] = PacketCodec.COMPRESSED_FLAG | PacketCodec.TAG_PLAYER_STATES
	assert_true(PacketCodec.decode(wrong).is_empty(), "tag mismatch refused")

func _test_json() -> void:
	var m := { "type": "craft_intent", "recipe_id": "R", "seq": 100000 }
	var b := PacketCodec.encode(m)
	assert_true(PacketCodec.is_json(b), "JSON")
	assert_eq(PacketCodec.decode(b).get("recipe_id"), "R", "read back")
	assert_true(PacketCodec.decode("[1]".to_utf8_buffer()).is_empty(), "not an object")

func _test_slice() -> void:
	var n := NetworkingSlice.new()
	assert_true(n._parse(PackedByteArray([1, 0, 0])) == null, "short binary refused")
	assert_true(n._parse(PackedByteArray([123, 125])) == null, "empty object refused")
	assert_true(n._parse("{\"type\":\"x\"}") is Dictionary, "JSON text still parses")
	# a u16 wrap: after the frontier reaches 65535, seq 0 of the next lap is accepted, a replay is not
	assert_true(n._dedup(2, { "type": "player_states", "seq": 65535 }), "frontier")
	assert_false(n._dedup(2, { "type": "player_states", "seq": 65535 }), "replay")
	assert_true(n._dedup(2, { "type": "player_states", "seq": 0 }), "new lap")
	assert_false(n._dedup(2, { "type": "player_states", "seq": 0 }), "new lap replay")
	n.free()
