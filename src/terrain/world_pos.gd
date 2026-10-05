extends RefCounted
## Phase 50 — a world position as `{ chunk: Vector2i, local: Vector3 }`.
##
## Float32 scene positions are exact to 0.125 m only within ~1 km of the origin, so a planet-sized
## world cannot store or send a raw Vector3. The chunk index is an exact int; `local` is the offset
## from that chunk's origin corner (X/Z in [0, CHUNK_METERS), Y as is), small enough for float32.
## Pure and static: the server, the client and the save code share it.

const CHUNK_METERS := 32.0   ## TerrainSlice.CHUNK_SIZE * TILE_SIZE
const REBASE_DISTANCE := 2000.0   ## the client rebases once the player drifts this far from the scene origin

## Split an XZ-planar world position (double precision, e.g. from a save) into chunk + local.
static func from_world(x: float, y: float, z: float) -> Dictionary:
	var cx := floori(x / CHUNK_METERS)
	var cz := floori(z / CHUNK_METERS)
	return {
		"chunk": Vector2i(cx, cz),
		"local": Vector3(x - cx * CHUNK_METERS, y, z - cz * CHUNK_METERS),
	}

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
