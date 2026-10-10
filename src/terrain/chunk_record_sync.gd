extends RefCounted
## Phase 109 — generation records on the wire.
##
## A client regenerates terrain from the seed, so once the host's record can differ from the
## generator the client has to be told. Records are about 20 bytes each and ride the snapshot, scoped
## the way edits are: the chunks of the peer's streamed window plus its first ring, with the scope
## named (`"gen_scope": [cx, cz, radius]`) so a client keeps the records it holds outside it.
##
## Pure functions. The host builds a payload with `records_in_window`; the client validates and
## applies it with `apply`, which drops a malformed record (the `RegionStore.normalize_gen` rules:
## types, finite heights inside `WorldShape` range, a known biome key, a known version) and refuses
## everything past the packet cap.

const ChunkRecords := preload("res://src/terrain/chunk_records.gd")
const RegionStore := preload("res://src/persistence/region_store.gd")
const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")

## Most records one snapshot carries or one client applies. A (2r+1)^2 window of r = 5 is 121 chunks.
const PACKET_CAP := 512

## Records of the chunks within Chebyshev `radius` of `center` (wrapped), nearest ring first, at most
## `cap`. Returns `{ "records": { "cx,cz": rec }, "truncated": bool }`.
static func records_in_window(center: Vector2i, radius: int, cap: int = PACKET_CAP) -> Dictionary:
	var out := {}
	var truncated := false
	if ChunkRecords.is_empty() or radius < 0:
		return { "records": out, "truncated": false }
	for ring in range(radius + 1):
		for dz in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dz)) != ring:
					continue
				var canon := TerrainSlice.wrap_chunk(Vector2i(center.x + dx, center.y + dz))
				var rec := ChunkRecords.get_record(canon)
				if rec.is_empty() or out.has(ChunkRecords.key_of(canon)):
					continue
				if out.size() >= cap:
					truncated = true
					return { "records": out, "truncated": truncated }
				out[ChunkRecords.key_of(canon)] = rec
	return { "records": out, "truncated": truncated }

## The `"cx,cz"` key parsed to a chunk, or `null` when it is not exactly two integers.
static func parse_key(key: Variant) -> Variant:
	if not (key is String):
		return null
	var parts: PackedStringArray = (key as String).split(",")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return null
	return Vector2i(int(parts[0]), int(parts[1]))

## Validate and adopt a wire payload (`"cx,cz" -> rec`). The first `cap` entries are considered; the
## rest are counted as refused. Returns `{ "applied", "dropped", "refused" }`.
static func apply(records: Variant, cap: int = PACKET_CAP) -> Dictionary:
	var applied := 0
	var dropped := 0
	var refused := 0
	if not (records is Dictionary):
		return { "applied": 0, "dropped": 0, "refused": 0 }
	var seen := 0
	for key in records:
		seen += 1
		if seen > cap:
			refused += 1
			continue
		var chunk: Variant = parse_key(key)
		var rec := RegionStore.normalize_gen(records[key])
		if chunk == null or rec.is_empty():
			dropped += 1
			continue
		ChunkRecords.set_record(TerrainSlice.wrap_chunk(chunk), rec)
		applied += 1
	return { "applied": applied, "dropped": dropped, "refused": refused }
