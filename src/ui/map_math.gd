extends RefCounted
## Map window maths (Phase 111) — everything the full-map window decides that is a pure function:
## the flat-to-globe projection blend, the tile pyramid keys, and the home marker's edge clamp.
## Static and headless-testable; the window itself only draws what these return.

const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")

## Closest zoom: log2 of the chunks across the window (8 chunks, street level).
const ZOOM_MIN := 3.0
## The blend runs over this many zoom steps (log2) ending at the far end, where the globe is a full sphere.
const BLEND_SPAN := 3.0
## The globe's radius as a share of the window's short side at the far end.
const GLOBE_FILL := 0.45
## Finest and coarsest tile level: a tile is 2^level chunks on a side.
const MAX_LEVEL := 24
## Tile target size in pixels; the level is the coarsest that keeps a tile at least this big.
const TILE_PX := 10.0

## Farthest zoom (log2 chunks across): the whole planet is a round globe filling GLOBE_FILL of the view.
static func zoom_max(circumference_chunks: int) -> float:
	return log(float(circumference_chunks) / (TAU * GLOBE_FILL)) / log(2.0)

## The projection blend, 0 = flat chunk map, 1 = orthographic globe. Smooth and monotone in zoom.
static func blend(zoom: float, zmax: float) -> float:
	return smoothstep(zmax - BLEND_SPAN, zmax, zoom)

## Pixels per radian of arc at this zoom for a view `view_px` across (the globe radius at the far end).
static func scale_px(zoom: float, view_px: float, circumference_chunks: int) -> float:
	var chunks_across := pow(2.0, zoom)
	return view_px * float(circumference_chunks) / (chunks_across * TAU)

## Longitude/latitude (radians) of a chunk-space point. Screen-down is +z, so latitude here
## grows toward -z ("up" on screen); the map reads like the minimap, not like an atlas.
static func lonlat(chunk: Vector2, circumference_chunks: int) -> Vector2:
	var c := float(circumference_chunks)
	return Vector2(chunk.x / c * TAU, -chunk.y / (c * 0.25) * (PI * 0.5))

static func wrap_lon(d: float) -> float:
	return fposmod(d + PI, TAU) - PI

## Screen offset, in units of the scale (radians), of `ll` from the view centre `center_ll` at blend `t`.
## t = 0 is equirectangular (pan-friendly flat map); t = 1 is the orthographic globe (length <= 1);
## in between is the straight mix of the two, so there is no jump anywhere along the zoom.
static func project(ll: Vector2, center_ll: Vector2, t: float) -> Vector2:
	var dl := wrap_lon(ll.x - center_ll.x)
	var flat := Vector2(dl, -(ll.y - center_ll.y))
	if t <= 0.0:
		return flat
	var cp := cos(ll.y)
	var globe := Vector2(cp * sin(dl),
		-(cos(center_ll.y) * sin(ll.y) - sin(center_ll.y) * cp * cos(dl)))
	return flat.lerp(globe, t)

## False for a point on the far side of the globe once the picture is mostly a sphere.
static func facing(ll: Vector2, center_ll: Vector2, t: float) -> bool:
	if t < 0.5:
		return true
	var dl := wrap_lon(ll.x - center_ll.x)
	return sin(center_ll.y) * sin(ll.y) + cos(center_ll.y) * cos(ll.y) * cos(dl) > 0.0

## Tile level for a flat scale of `px_per_chunk`: tiles of at least TILE_PX pixels.
static func level_for(px_per_chunk: float) -> int:
	if px_per_chunk >= TILE_PX:
		return 0
	return clampi(ceili(log(TILE_PX / maxf(px_per_chunk, 0.000001)) / log(2.0)), 0, MAX_LEVEL)

## The cache key of a tile: it carries the seed and generator version, so a tile for one world is
## never answered for another.
static func tile_key(seed_v: int, version: int, level: int, tx: int, tz: int) -> String:
	return "%d:%d:%d:%d:%d" % [seed_v, version, level, tx, tz]

## The chunk a tile samples: the one at its centre.
static func tile_center_chunk(level: int, tx: int, tz: int) -> Vector2i:
	var size := 1 << level
	return Vector2i(tx * size + size / 2, tz * size + size / 2)

## The tile containing a chunk at a level.
static func tile_of(chunk: Vector2i, level: int) -> Vector2i:
	return Vector2i(chunk.x >> level, chunk.y >> level)

## World-space offset in metres from view (chunk + local) to target (chunk + local), exact for
## chunks far from the origin: the chunk difference is an integer before it meets a float.
static func delta_m(view_chunk: Vector2i, view_local: Vector2, target_chunk: Vector2i, target_local: Vector2) -> Vector2:
	var dc := target_chunk - view_chunk
	return Vector2(dc) * TerrainSlice.CHUNK_METERS + (target_local - view_local)

## The home marker: a target at screen `offset` px from the window centre. Inside the half-size
## rect it is drawn as itself; outside, it is clamped to the rect's edge on the line toward it and
## the caller draws an arrow there. `distance_m` is passed through. Returns
## { inside, pos, distance, angle }.
static func clamp_home(offset: Vector2, half: Vector2, distance_m: float, margin: float = 0.0) -> Dictionary:
	var lim := Vector2(maxf(half.x - margin, 0.0), maxf(half.y - margin, 0.0))
	if absf(offset.x) <= lim.x and absf(offset.y) <= lim.y:
		return {"inside": true, "pos": offset, "distance": distance_m, "angle": offset.angle()}
	var k := minf(lim.x / maxf(absf(offset.x), 0.000001), lim.y / maxf(absf(offset.y), 0.000001))
	return {"inside": false, "pos": offset * k, "distance": distance_m, "angle": offset.angle()}

## "1.2 km" / "340 m" for the arrow's label.
static func distance_text(m: float) -> String:
	return "%.1f km" % (m / 1000.0) if m >= 1000.0 else "%d m" % roundi(m)
