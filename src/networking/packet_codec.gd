extends RefCounted
## Phase 256 — the binary layouts of the hot packets. Every other packet type stays JSON.
##
## The wire carries a `PackedByteArray`. Its first byte says how to read the rest: `{` (0x7B) is a UTF-8
## JSON object (any packet without a layout here, and any peer that predates the codec); a tag below is a
## fixed layout. All integers are little-endian. A binary packet whose length does not match its layout
## decodes to an empty dictionary, so a caller never reads half a packet.
##
##   remote_player_state  tag(1) seq(u16) peer_id(i32) x,y,z (i32 centimetres of world position)   = 19 B
##   snapshot_chunk       tag(1) seq(u16) snapshot_id(u32) index(u32) count(u32) len(u32) bytes(len)
##   player_states        tag(1) seq(u16) n(u16) n x [ subject(i32) compact position (20 B) ]
##
## `seq` is the sender's per-type counter modulo 65536; the receiver's dedup reads the wrap (`SEQ_MOD`).

const JSON_FIRST_BYTE := 0x7B
const TAG_REMOTE_PLAYER_STATE := 1
const TAG_SNAPSHOT_CHUNK := 2
const TAG_PLAYER_STATES := 3

const SEQ_MOD := 65536
const REMOTE_PLAYER_STATE_BYTES := 19
const SNAPSHOT_HEADER_BYTES := 19
const PLAYER_STATES_HEADER_BYTES := 5
const PLAYER_STATES_ENTRY_BYTES := 24
## Largest world coordinate (metres) a centimetre i32 holds.
const CM_LIMIT_M := 21474836.0
const BATCH_MAX := 256
## Most data bytes in one snapshot chunk (a UTF-8 chunk of `SNAPSHOT_CHUNK_SIZE` characters, 4 bytes each, at worst).
const SNAPSHOT_DATA_MAX := 16384 * 4

## True for a packet type that has a binary layout (its `seq` wraps at `SEQ_MOD`).
static func has_layout(ptype: String) -> bool:
	return ptype == "remote_player_state" or ptype == "snapshot_chunk" or ptype == "player_states"

## True when the bytes are a JSON object (a legacy peer's, or a type without a layout).
static func is_json(bytes: PackedByteArray) -> bool:
	return bytes.size() > 0 and bytes[0] == JSON_FIRST_BYTE

## The wire bytes of a packet: its binary layout when it has one and fits it, else its JSON text.
static func encode(msg: Dictionary) -> PackedByteArray:
	var out := _encode_binary(msg)
	if out.is_empty():
		return JSON.stringify(msg).to_utf8_buffer()
	return out

static func _encode_binary(msg: Dictionary) -> PackedByteArray:
	match str(msg.get("type", "")):
		"remote_player_state":
			return _encode_remote_player_state(msg)
		"snapshot_chunk":
			return _encode_snapshot_chunk(msg)
		"player_states":
			return _encode_player_states(msg)
	return PackedByteArray()

static func _encode_remote_player_state(msg: Dictionary) -> PackedByteArray:
	var p = msg.get("position", null)
	var id = msg.get("peer_id", null)
	if not (p is Array) or (p as Array).size() != 3 or not (id is int or id is float):
		return PackedByteArray()   # an exact-chunk position (`pk`) stays JSON: centimetres would drop its chunk
	var b := PackedByteArray()
	b.resize(REMOTE_PLAYER_STATE_BYTES)
	b[0] = TAG_REMOTE_PLAYER_STATE
	b.encode_u16(1, int(msg.get("seq", 0)) % SEQ_MOD)
	b.encode_s32(3, int(id))
	for i in 3:
		var m := float(p[i])
		if not is_finite(m) or absf(m) > CM_LIMIT_M:
			return PackedByteArray()
		b.encode_s32(7 + 4 * i, roundi(m * 100.0))
	return b

static func _encode_snapshot_chunk(msg: Dictionary) -> PackedByteArray:
	var data := str(msg.get("data", "")).to_utf8_buffer()
	var b := PackedByteArray()
	b.resize(SNAPSHOT_HEADER_BYTES)
	b[0] = TAG_SNAPSHOT_CHUNK
	b.encode_u16(1, int(msg.get("seq", 0)) % SEQ_MOD)
	b.encode_u32(3, int(msg.get("snapshot_id", 0)))
	b.encode_u32(7, int(msg.get("index", 0)))
	b.encode_u32(11, int(msg.get("count", 1)))
	b.encode_u32(15, data.size())
	b.append_array(data)
	return b

static func _encode_player_states(msg: Dictionary) -> PackedByteArray:
	var s = msg.get("s", null)
	if not (s is Array) or (s as Array).size() % 2 != 0 or (s as Array).size() > BATCH_MAX * 2:
		return PackedByteArray()
	var n: int = (s as Array).size() / 2
	var b := PackedByteArray()
	b.resize(PLAYER_STATES_HEADER_BYTES + PLAYER_STATES_ENTRY_BYTES * n)
	b[0] = TAG_PLAYER_STATES
	b.encode_u16(1, int(msg.get("seq", 0)) % SEQ_MOD)
	b.encode_u16(3, n)
	for i in n:
		var at := PLAYER_STATES_HEADER_BYTES + PLAYER_STATES_ENTRY_BYTES * i
		var raw: PackedByteArray = Marshalls.base64_to_raw(str(s[2 * i + 1]))
		if raw.size() != 20:
			return PackedByteArray()
		b.encode_s32(at, int(s[2 * i]))
		for j in 20:
			b[at + 4 + j] = raw[j]
	return b

## The packet a wire message carries, or an empty dictionary when it is not one: a binary packet of an
## unknown tag or of the wrong length for its layout, or JSON that does not parse to an object.
static func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty():
		return {}
	if bytes[0] == JSON_FIRST_BYTE:
		var parsed = JSON.parse_string(bytes.get_string_from_utf8())
		return parsed if parsed is Dictionary else {}
	match bytes[0]:
		TAG_REMOTE_PLAYER_STATE:
			if bytes.size() != REMOTE_PLAYER_STATE_BYTES:
				return {}
			return {
				"type": "remote_player_state", "seq": bytes.decode_u16(1), "peer_id": bytes.decode_s32(3),
				"position": [bytes.decode_s32(7) / 100.0, bytes.decode_s32(11) / 100.0, bytes.decode_s32(15) / 100.0],
			}
		TAG_SNAPSHOT_CHUNK:
			if bytes.size() < SNAPSHOT_HEADER_BYTES:
				return {}
			var len := bytes.decode_u32(15)
			if len > SNAPSHOT_DATA_MAX or bytes.size() != SNAPSHOT_HEADER_BYTES + len:
				return {}
			return {
				"type": "snapshot_chunk", "seq": bytes.decode_u16(1), "snapshot_id": bytes.decode_u32(3),
				"index": bytes.decode_u32(7), "count": bytes.decode_u32(11),
				"data": bytes.slice(SNAPSHOT_HEADER_BYTES).get_string_from_utf8(),
			}
		TAG_PLAYER_STATES:
			if bytes.size() < PLAYER_STATES_HEADER_BYTES:
				return {}
			var n := bytes.decode_u16(3)
			if n > BATCH_MAX or bytes.size() != PLAYER_STATES_HEADER_BYTES + PLAYER_STATES_ENTRY_BYTES * n:
				return {}
			var flat: Array = []
			for i in n:
				var at := PLAYER_STATES_HEADER_BYTES + PLAYER_STATES_ENTRY_BYTES * i
				flat.append(bytes.decode_s32(at))
				flat.append(Marshalls.raw_to_base64(bytes.slice(at + 4, at + PLAYER_STATES_ENTRY_BYTES)))
			return { "type": "player_states", "seq": bytes.decode_u16(1), "s": flat }
	return {}
