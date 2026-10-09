extends RefCounted
## Phase 50 — a world position as `{ chunk: Vector2i, local: Vector3 }`.
##
## Float32 scene positions are exact to 0.125 m only within ~1 km of the origin, so a planet-sized
## world cannot store or send a raw Vector3. The chunk index is an exact int; `local` is the offset
## from that chunk's origin corner (X/Z in [0, CHUNK_METERS), Y as is), small enough for float32.
## Pure and static: the server, the client and the save code share it.

const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")
const CHUNK_METERS := TerrainSlice.CHUNK_METERS
const REBASE_DISTANCE := 2000.0   ## the client rebases once the player drifts this far from the scene origin

## Split an XZ-planar world position (double precision, e.g. from a save) into chunk + local.
static func from_world(x: float, y: float, z: float) -> Dictionary:
	var cx := floori(x / CHUNK_METERS)
	var cz := floori(z / CHUNK_METERS)
	# Renormalise: the float32 Vector3 can round a local just below CHUNK_METERS up to exactly it.
	return normalized({
		"chunk": Vector2i(cx, cz),
		"local": Vector3(x - cx * CHUNK_METERS, y, z - cz * CHUNK_METERS),
	})

## Normalise a record so `local` lies inside its chunk (after adding a movement delta).
static func normalized(pos: Dictionary) -> Dictionary:
	var chunk: Vector2i = pos["chunk"]
	var local: Vector3 = pos["local"]
	var dx := floori(local.x / CHUNK_METERS)
	var dz := floori(local.z / CHUNK_METERS)
	return {
		"chunk": Vector2i(chunk.x + dx, chunk.y + dz),
		"local": Vector3(local.x - dx * CHUNK_METERS, local.y, local.z - dz * CHUNK_METERS),
	}

## Scene position of `pos` relative to a scene origin chunk (what the renderer and physics see).
static func to_scene(pos: Dictionary, origin_chunk: Vector2i) -> Vector3:
	var chunk: Vector2i = pos["chunk"]
	var local: Vector3 = pos["local"]
	return Vector3(
		(chunk.x - origin_chunk.x) * CHUNK_METERS + local.x,
		local.y,
		(chunk.y - origin_chunk.y) * CHUNK_METERS + local.z)

## The inverse: a scene position and the scene's origin chunk back to chunk + local.
static func from_scene(scene_pos: Vector3, origin_chunk: Vector2i) -> Dictionary:
	return normalized({"chunk": origin_chunk, "local": scene_pos})

## True once a scene position is far enough from the scene origin that the client should rebase.
static func needs_rebase(scene_pos: Vector3) -> bool:
	return Vector2(scene_pos.x, scene_pos.z).length() > REBASE_DISTANCE

## The scene origin chunk to rebase to for a player at `pos` (their own chunk).
static func rebase_origin(pos: Dictionary) -> Vector2i:
	return pos["chunk"]

## The offset every streamed node shifts by when the origin moves `from_chunk` -> `to_chunk`.
static func rebase_shift(from_chunk: Vector2i, to_chunk: Vector2i) -> Vector3:
	return Vector3((from_chunk.x - to_chunk.x) * CHUNK_METERS, 0.0, (from_chunk.y - to_chunk.y) * CHUNK_METERS)

## --- Phase 63: the wire form -------------------------------------------------------------
## A position on the wire is `{ "chunk": [cx, cz], "local": [x, y, z] }`: the chunk index is an exact
## int and `local` is small, so nothing sent over JSON loses precision far from the origin. The old
## `[x, y, z]` float array is still accepted on read (saves, an older peer).

## Encode a world position (metres) as the wire dictionary.
static func to_wire(world: Vector3) -> Dictionary:
	return pos_to_wire(from_world(world.x, world.y, world.z))

## Encode a `{chunk, local}` record as the wire dictionary.
static func pos_to_wire(pos: Dictionary) -> Dictionary:
	var chunk: Vector2i = pos["chunk"]
	var local: Vector3 = pos["local"]
	return { "chunk": [chunk.x, chunk.y], "local": [local.x, local.y, local.z] }

## Decode the `{chunk, local}` wire dictionary to a `{chunk, local}` record with no float round trip, or
## an empty dictionary when `data` is not that form (a legacy array has no exact chunk to keep).
static func pos_from_wire(data: Variant) -> Dictionary:
	if data is Dictionary and is_wire(data):
		var c: Array = data["chunk"]
		var l: Array = data["local"]
		return normalized({
			"chunk": Vector2i(int(c[0]), int(c[1])),
			"local": Vector3(float(l[0]), float(l[1]), float(l[2])),
		})
	return {}

## Decode either wire form (the `{chunk, local}` dictionary or a legacy `[x, y, z]` array) to a world
## position. Anything else decodes to `fallback`.
static func from_wire(data: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if data is Dictionary and data.has("chunk") and data.has("local"):
		var c = data["chunk"]
		var l = data["local"]
		if c is Array and c.size() >= 2 and l is Array and l.size() >= 3:
			return Vector3(
				int(c[0]) * CHUNK_METERS + float(l[0]),
				float(l[1]),
				int(c[1]) * CHUNK_METERS + float(l[2]))
	elif data is Array and data.size() >= 3:
		return Vector3(float(data[0]), float(data[1]), float(data[2]))
	return fallback

## Wire form of a world position X wrapped to the seam: the canonical `{chunk, local}`.
static func wire_chunk(data: Variant) -> Vector2i:
	if data is Dictionary and data.has("chunk"):
		var c = data["chunk"]
		if c is Array and c.size() >= 2:
			return TerrainSlice.wrap_chunk(Vector2i(int(c[0]), int(c[1])))
	return Vector2i.ZERO

## Move a world position that crossed the east-west seam back inside [-w/2, w/2).
static func wrap_world(world: Vector3) -> Vector3:
	var w := float(TerrainSlice.circumference_chunks()) * CHUNK_METERS
	return Vector3(fposmod(world.x + w * 0.5, w) - w * 0.5, world.y, world.z)

## True for a decodable wire position: the `{chunk, local}` dictionary or a legacy `[x, y, z]` array.
## Every element must be a finite number of sane size, so a hostile packet cannot reach `int()` /
## `float()` with a non-number or feed NaN / infinity into `normalized`.
##
## Phase 90 — the ONE wire validator. A dictionary needs a `chunk` of exactly two integer-valued
## numbers (JSON hands ints back as floats, so `3.0` passes, `1.5` does not) — X within one lap of
## the world, Z between the poles — and a `local` of exactly three finite numbers under 1e6 m. Saved
## player records share the shape, so `PlayerRegistry` asks this too.
static func is_wire(data: Variant) -> bool:
	if data is Dictionary:
		var c: Variant = data.get("chunk")
		var l: Variant = data.get("local")
		if not (c is Array and l is Array and (c as Array).size() == 2 and (l as Array).size() == 3):
			return false
		if not (_sane(c, 2) and _sane(l, 3)):
			return false
		var limits := [float(TerrainSlice.circumference_chunks()), float(TerrainSlice.pole_chunks())]
		for i in 2:
			if absf(float(c[i])) > limits[i] or floorf(float(c[i])) != float(c[i]):
				return false
		for v in l:
			if absf(float(v)) > LOCAL_LIMIT:
				return false
		return true
	return data is Array and data.size() >= 3 and _sane(data, 3)

## A wire `local` component beyond this many metres is not a position inside a chunk.
const LOCAL_LIMIT := 1.0e6

## The first `count` elements of `arr` are numbers, finite, and within +/- WIRE_LIMIT.
const WIRE_LIMIT := 1.0e9
static func _sane(arr: Array, count: int) -> bool:
	for i in count:
		var v: Variant = arr[i]
		if not (v is int or v is float):
			return false
		if is_nan(float(v)) or absf(float(v)) > WIRE_LIMIT:
			return false
	return true
