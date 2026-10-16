extends RefCounted
## Map window maths — the planet as a cube papercraft. Six equal square faces (an equiangular cube:
## a face's local u, v in [-1, 1] are angles, so its tiles stay close to square everywhere, the poles
## included). Flat, the faces unfold into a net around the face in view; folded, the same faces are
## the sphere. Static and headless-testable; the window itself only draws what these return.
##
## Sphere frame: +X east at longitude 90, +Y the map's "up" pole (chunk -z, as on the minimap), +Z
## longitude 0 on the equator.
##
## A placement is how one face lies on the screen: [n, sr, su], the face's normal and the cube axes
## that point screen-right and screen-up across it. Stepping off an edge into the neighbour face is
## pure axis bookkeeping (`step`), so the net and the globe never need a face table beyond FACES.
const SeamWrap := preload("res://src/terrain/seam_wrap.gd")

const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")

## Closest zoom: log2 of the finest tiles across the window (8, about street level).
const ZOOM_MIN := 3.0
## Face half-sides (local units) across the short side at the farthest zoom: the flat net shows its
## three faces of height with a margin; the planet is a sphere filling 0.9 of the short side (a
## half-side spans PI/4 of arc, so the radius is 4/PI of them).
const NET_UNITS := 7.0
const GLOBE_UNITS := 4.0 / (0.45 * PI)
## Tile target size in pixels; the level is the coarsest that keeps a tile at least this big.
const TILE_PX := 10.0
## The globe's closest zoom: pixels per face half-side (a single-precision step is then ~0.01 px).
const GLOBE_MAX_PX_PER_UNIT := 200000.0
## The globe never draws a face coarser than 2^GLOBE_MIN_SPLIT tiles a side, so it stays round.
const GLOBE_MIN_SPLIT := 3

## The six faces: [normal, u axis, v axis]. u x v = normal for every face.
const FACES := [
	[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],     # 0 front (longitude 0)
	[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],    # 1 east (90)
	[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],   # 2 back (180)
	[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],    # 3 west (-90)
	[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],    # 4 map-up pole
	[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],    # 5 map-down pole
]

static var _bits_for := -1
static var _bits := 0

## log2 of the finest tiles along a face side: the smallest power of two with at least a quarter
## circumference of them, so a finest tile is never wider than a chunk.
static func face_bits() -> int:
	var c := TerrainSlice.circumference_chunks()
	if c != _bits_for:
		_bits_for = c
		_bits = maxi(1, ceili(log(float(c) / 4.0) / log(2.0) - 0.000001))
	return _bits

static func face_cells() -> int:
	return 1 << face_bits()

## Coarsest tile level: a whole face is one tile.
static func max_level() -> int:
	return face_bits()

static func face_of_normal(n: Vector3) -> int:
	for f in 6:
		if FACES[f][0].is_equal_approx(n):
			return f
	return -1

# ---------------------------------------------------------------------------
# Sphere <-> chunks <-> faces
# ---------------------------------------------------------------------------

## Unit vector of a chunk-space point (fractional chunks).
static func dir_of_chunk(chunk: Vector2) -> Vector3:
	var c := float(TerrainSlice.circumference_chunks())
	var lon := chunk.x / c * TAU
	var lat := -chunk.y / (c * 0.25) * (PI * 0.5)   # past a pole is the same sphere point as on the far meridian: no clamp
	return Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon))

## Fractional chunk-space point of a direction, x wrapped into [-C/2, C/2).
static func chunk_of_dir(d: Vector3) -> Vector2:
	var p := _xz_of_xyz(d.x, d.y, d.z)
	return Vector2(p[0], p[1])

## The face a direction falls on and its local (u, v): Vector3(face, u, v).
static func face_uv(d: Vector3) -> Vector3:
	var r := _face_uv_xyz(d.x, d.y, d.z)
	return Vector3(r[0], r[1], r[2])

## Unit vector at local (u, v) of a face.
static func dir_of_face(f: int, u: float, v: float) -> Vector3:
	var face: Array = FACES[f]
	return (face[0] + face[1] * tan(u * PI * 0.25) + face[2] * tan(v * PI * 0.25)).normalized()

# Vector2 and Vector3 are single precision: at street zoom a pixel is below their step. The net, the
# markers and the tile samples go through these double-precision forms on plain floats instead.

## Face and local (u, v) of a chunk-space point: [face, u, v].
static func face_uv_xz(x: float, z: float) -> Array:
	var c := float(TerrainSlice.circumference_chunks())
	var lon := x / c * TAU
	var lat := -z / (c * 0.25) * (PI * 0.5)   # not clamped: over a pole the sphere continues down the far meridian
	return _face_uv_xyz(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon))

## Chunk-space point [x, z] of local (u, v) of a face, x wrapped into [-C/2, C/2).
static func xz_of_face(f: int, u: float, v: float) -> Array:
	var face: Array = FACES[f]
	var n: Vector3 = face[0]
	var eu: Vector3 = face[1]
	var ev: Vector3 = face[2]
	var a := tan(u * PI * 0.25)
	var b := tan(v * PI * 0.25)
	return _xz_of_xyz(n.x + a * eu.x + b * ev.x, n.y + a * eu.y + b * ev.y, n.z + a * eu.z + b * ev.z)

static func _face_uv_xyz(x: float, y: float, z: float) -> Array:
	var f := 0
	if absf(x) >= absf(y) and absf(x) >= absf(z):
		f = 1 if x > 0.0 else 3
	elif absf(y) >= absf(z):
		f = 4 if y > 0.0 else 5
	else:
		f = 0 if z > 0.0 else 2
	var face: Array = FACES[f]
	var dn := _dot(face[0], x, y, z)
	return [f, atan(_dot(face[1], x, y, z) / dn) * 4.0 / PI, atan(_dot(face[2], x, y, z) / dn) * 4.0 / PI]

## Not necessarily unit length. The latitude comes from atan2: asin of y loses the rows by a pole.
static func _xz_of_xyz(x: float, y: float, z: float) -> Array:
	var c := float(TerrainSlice.circumference_chunks())
	var lon := atan2(x, z)
	var lat := atan2(y, sqrt(x * x + z * z))
	return [SeamWrap.wrap_f(lon / TAU * c, c), -lat / (PI * 0.5) * (c * 0.25)]

static func _dot(a: Vector3, x: float, y: float, z: float) -> float:
	return a.x * x + a.y * y + a.z * z

# ---------------------------------------------------------------------------
# Tiles: a tile at (face, level, i, j) is 2^level finest tiles on a side
# ---------------------------------------------------------------------------

static func tiles_per_side(level: int) -> int:
	return face_cells() >> level

## The tile at `level` holding local (u, v) of a face.
static func tile_index(u: float, v: float, level: int) -> Vector2i:
	var n := tiles_per_side(level)
	return Vector2i(clampi(floori((u + 1.0) * 0.5 * n), 0, n - 1), clampi(floori((v + 1.0) * 0.5 * n), 0, n - 1))

## Local (u, v) bounds of a tile: Rect2(u0, v0, du, dv).
static func tile_rect(level: int, i: int, j: int) -> Rect2:
	var s := 2.0 / float(tiles_per_side(level))
	return Rect2(-1.0 + i * s, -1.0 + j * s, s, s)

## The chunk a tile samples: the one under its centre.
static func tile_center_chunk(f: int, level: int, i: int, j: int) -> Vector2i:
	var s := 2.0 / float(tiles_per_side(level))
	var p := xz_of_face(f, -1.0 + (i + 0.5) * s, -1.0 + (j + 0.5) * s)
	return TerrainSlice.wrap_chunk(Vector2i(floori(p[0]), floori(p[1])))

## Tile level for `px_per_unit` pixels per face half-side: tiles of at least TILE_PX pixels.
static func level_for(px_unit: float) -> int:
	var finest_px := 2.0 * px_unit / float(face_cells())
	if finest_px >= TILE_PX:
		return 0
	return clampi(ceili(log(TILE_PX / maxf(finest_px, 0.000001)) / log(2.0)), 0, max_level())

## The cache key of a tile: it carries the seed and generator version, so a tile for one world is
## never answered for another.
static func tile_key(seed_v: int, version: int, f: int, level: int, i: int, j: int) -> String:
	return "%d:%d:%d:%d:%d:%d" % [seed_v, version, f, level, i, j]

## Chunks along a finest tile's side at the middle of a face, about one.
static func chunks_per_cell() -> float:
	return float(TerrainSlice.circumference_chunks()) * 0.25 / float(face_cells())

# ---------------------------------------------------------------------------
# Placements and the net
# ---------------------------------------------------------------------------

## A face's own placement: u right, v up.
static func placement_of(f: int) -> Array:
	return [FACES[f][0], FACES[f][1], FACES[f][2]]

## The placement one face over on the screen: dx = +1 right, -1 left; dy = +1 up, -1 down.
static func step(pl: Array, dx: int, dy: int) -> Array:
	var n: Vector3 = pl[0]
	var sr: Vector3 = pl[1]
	var su: Vector3 = pl[2]
	if dx > 0:
		return [sr, -n, su]
	if dx < 0:
		return [-sr, n, su]
	if dy > 0:
		return [su, sr, -n]
	if dy < 0:
		return [-su, sr, n]
	return pl

## The face shown by a placement.
static func face_of(pl: Array) -> int:
	return face_of_normal(pl[0])

## Unit vector at screen-local (x right, y up) of a placement.
static func local_dir(pl: Array, x: float, y: float) -> Vector3:
	return (pl[0] + pl[1] * tan(x * PI * 0.25) + pl[2] * tan(y * PI * 0.25)).normalized()

## Screen-local [x, y] of local (u, v) of face `f` on a placement showing it. A signed swap, so
## exact: tile edges stay on whole pixels' worth of precision.
static func local_of_face_uv(pl: Array, f: int, u: float, v: float) -> Array:
	var face: Array = FACES[f]
	var sr: Vector3 = pl[1]
	var su: Vector3 = pl[2]
	return [u * sr.dot(face[1]) + v * sr.dot(face[2]), u * su.dot(face[1]) + v * su.dot(face[2])]

## Face-local [u, v] of a placement's screen-local (x, y).
static func face_uv_of_local(pl: Array, x: float, y: float) -> Array:
	var face: Array = FACES[face_of(pl)]
	var sr: Vector3 = pl[1]
	var su: Vector3 = pl[2]
	return [x * sr.dot(face[1]) + y * su.dot(face[1]), x * sr.dot(face[2]) + y * su.dot(face[2])]

## Bring a screen-local point back onto its placement's face, stepping over edges as needed:
## [placement, x, y].
static func wrap_local(pl: Array, x: float, y: float) -> Array:
	for i in 16:   # a pan never crosses more than a few faces at once
		if x > 1.0:
			pl = step(pl, 1, 0)
			x -= 2.0
		elif x < -1.0:
			pl = step(pl, -1, 0)
			x += 2.0
		elif y > 1.0:
			pl = step(pl, 0, 1)
			y -= 2.0
		elif y < -1.0:
			pl = step(pl, 0, -1)
			y += 2.0
		else:
			break
	return [pl, x, y]

## An equatorial face turned so that the map's up pole is up; a pole face is left as it is.
## Returns [placement, x, y] for the same point.
static func upright(pl: Array, x: float, y: float) -> Array:
	var up := Vector3(0, 1, 0)
	if absf((pl[0] as Vector3).y) > 0.5:
		return [pl, x, y]
	for i in 4:
		if (pl[2] as Vector3).is_equal_approx(up):
			break
		pl = [pl[0], pl[2], -(pl[1] as Vector3)]   # a quarter turn: sr' = su, su' = -sr
		var t := x
		x = y
		y = -t
	return [pl, x, y]

## The net around a home placement: the band of faces through it (left and right, as many cells as
## `i0..i1` asks, wrapping round the planet) and the faces above and below it. [[Vector2i cell, placement]].
static func net_cells(home: Array, i0: int, i1: int) -> Array:
	var out: Array = [[Vector2i(0, 0), home]]
	var pl := home
	for i in range(1, i1 + 1):
		pl = step(pl, 1, 0)
		out.append([Vector2i(i, 0), pl])
	pl = home
	for i in range(1, -i0 + 1):
		pl = step(pl, -1, 0)
		out.append([Vector2i(-i, 0), pl])
	out.append([Vector2i(0, 1), step(home, 0, 1)])
	out.append([Vector2i(0, -1), step(home, 0, -1)])
	return out

# ---------------------------------------------------------------------------
# Globe (orthographic)
# ---------------------------------------------------------------------------

## The globe camera looking down at longitude `lon`, map latitude `lat` (radians, map-up positive):
## [centre, right, up], an orthonormal frame with up toward the map-up pole. Tied to the poles, not to
## the cube's faces, so turning the globe never flips it round at a cube corner.
static func globe_frame(lon: float, lat: float) -> Array:
	var c := Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon))
	var up := Vector3(-sin(lat) * sin(lon), cos(lat), -sin(lat) * cos(lon))
	return [c, up.cross(c), up]

## Screen offset in sphere radii (y down) of a direction; z > 0 when it faces the viewer.
static func globe_project(frame: Array, d: Vector3) -> Vector3:
	return Vector3(d.dot(frame[1]), -d.dot(frame[2]), d.dot(frame[0]))

## Direction under a screen offset in sphere radii (y down); Vector3.ZERO off the disc.
static func globe_unproject(frame: Array, q: Vector2) -> Vector3:
	var r2 := q.length_squared()
	if r2 > 1.0:
		return Vector3.ZERO
	return (frame[1] * q.x - frame[2] * q.y + frame[0] * sqrt(1.0 - r2)).normalized()

# ---------------------------------------------------------------------------
# Zoom
# ---------------------------------------------------------------------------

## Farthest zoom (log2 finest tiles across the short side) for the flat net or the planet.
static func zoom_max(planet: bool) -> float:
	var units := GLOBE_UNITS if planet else NET_UNITS
	return maxf(log(units * float(face_cells()) * 0.5) / log(2.0), ZOOM_MIN)

## Closest zoom. The globe works in single precision, so it stops where a pixel is still well above
## that step (GLOBE_MAX_PX_PER_UNIT); the flat net goes to street level.
static func zoom_min(planet: bool, view_px: float) -> float:
	if not planet or view_px <= 0.0:
		return ZOOM_MIN
	return maxf(log(view_px * float(face_cells()) * 0.5 / GLOBE_MAX_PX_PER_UNIT) / log(2.0), ZOOM_MIN)

## Pixels per face half-side (local unit) for a view `view_px` across.
static func px_per_unit(zoom: float, view_px: float) -> float:
	return view_px * float(face_cells()) * 0.5 / pow(2.0, zoom)

# ---------------------------------------------------------------------------
# Markers
# ---------------------------------------------------------------------------

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

## Great-circle distance in metres between two directions on a planet of `circumference_m`; the
## atan2 form, exact for short and near-antipodal steps alike.
static func arc_m(a: Vector3, b: Vector3, circumference_m: float) -> float:
	return atan2(a.cross(b).length(), a.dot(b)) * circumference_m / TAU
