extends RefCounted
## Map window maths (Phase 111, cube planet). The world is a sphere on a lon/lat chunk grid, and the
## map draws it as a cube papercraft: six equal square faces, each split into the same grid of tiles,
## so no pole is stretched (a pole is the middle of a face). The flat map is the cube's net: four faces
## round the equator, the north face above the front one, the south face below it. The planet folds the
## same six faces into a sphere. Each face is equiangular (its coordinates are tan-warped), so a tile is
## close to square everywhere.
##
## A point on the surface is a face fraction (face, fx, fy) in [0, 1]^2: fx runs east, fy runs south
## (down on the net). Everything here is pure and static, so it is headless-testable; the window only
## draws what these return.

const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")

## Closest zoom: log2 of the chunks across the window (8 chunks, street level).
const ZOOM_MIN := 3.0
## Tile target size in pixels; the level is the coarsest that keeps a tile at least this big.
const TILE_PX := 10.0
## Pyramid depth bound: the coarsest real level is one tile per face (`top_level`), this only caps walks.
const MAX_LEVEL := 24
## The planet's diameter, and the net's width, as a share of the window's short side at the far zoom.
const PLANET_FILL := 0.9
const NET_FILL := 0.9

## Face ids: 0 +z (front), 1 +x, 2 -z, 3 -x, 4 +y (north), 5 -y (south). Per face: the outward normal,
## the east axis (fx) and the north axis (fy runs the other way).
const FACE_N := [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0)]
const FACE_E := [Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(1, 0, 0)]
const FACE_N_AXIS := [Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(0, 0, 1)]
## Net cell of each face (column, row) in the 4 x 3 cross. The band of four runs east: -x, +z, +x, -z.
const NET_COL := [1, 2, 3, 0, 1, 1]
const NET_ROW := [1, 1, 1, 1, 0, 2]
const BAND_FACE := [3, 0, 1, 2]

# ---------------------------------------------------------------------------
# Zoom and scale
# ---------------------------------------------------------------------------

## Farthest zoom (log2 chunks across the window): the planet fills PLANET_FILL of the window, the net its width.
static func zoom_max(circumference_chunks: int, planet: bool) -> float:
	var c := float(circumference_chunks)
	if planet:
		return log(c / (PI * PLANET_FILL)) / log(2.0)
	return log(c / NET_FILL) / log(2.0)

## Tiles per face side at the finest level (a power of two at least a quarter of the circumference).
static func face_grid(pole_chunks: int) -> int:
	var g := 1
	while g < pole_chunks:
		g *= 2
	return g

## The coarsest level: one tile per face.
static func top_level(grid: int) -> int:
	return roundi(log(float(grid)) / log(2.0))

## Tile level for `px_per_tile` (the finest tile's size on screen): the coarsest that keeps a tile
## at least TILE_PX wide, never coarser than the pyramid's top.
static func level_for(px_per_tile: float, grid: int) -> int:
	if px_per_tile >= TILE_PX:
		return 0
	return clampi(ceili(log(TILE_PX / maxf(px_per_tile, 0.000001)) / log(2.0)), 0, top_level(grid))

## On-screen size of a tile at `level` when a face is `face_px` across.
static func tile_px(level: int, face_px: float, grid: int) -> float:
	return face_px * float(1 << level) / float(grid)

# ---------------------------------------------------------------------------
# Lon/lat and chunks
# ---------------------------------------------------------------------------

## Longitude/latitude (radians) of a chunk-space point. Screen-down is +z, so latitude here grows
## toward -z ("up" on screen); the map reads like the minimap, not like an atlas.
static func lonlat(chunk: Vector2, circumference_chunks: int) -> Vector2:
	var k := TAU / float(circumference_chunks)
	return Vector2(chunk.x * k, -chunk.y * k)

## The chunk-space point of a lon/lat (radians): the inverse of `lonlat`.
static func chunk_of_lonlat(ll: Vector2, circumference_chunks: int) -> Vector2:
	var c := float(circumference_chunks) / TAU
	return Vector2(ll.x * c, -ll.y * c)

static func wrap_lon(d: float) -> float:
	return fposmod(d + PI, TAU) - PI

## Unit direction of a lon/lat (lon 0 is +z, lon 90 degrees is +x, north is +y).
static func dir_of_lonlat(ll: Vector2) -> Vector3:
	return Vector3(cos(ll.y) * sin(ll.x), sin(ll.y), cos(ll.y) * cos(ll.x))

static func lonlat_of_dir(d: Vector3) -> Vector2:
	return Vector2(atan2(d.x, d.z), asin(clampf(d.y, -1.0, 1.0)))

# ---------------------------------------------------------------------------
# Cube faces
# ---------------------------------------------------------------------------

## The face a unit direction lies on: the axis it points furthest along.
static func face_of_dir(d: Vector3) -> int:
	var ax := absf(d.x)
	var ay := absf(d.y)
	var az := absf(d.z)
	if ay >= ax and ay >= az:
		return 4 if d.y > 0.0 else 5
	if az >= ax:
		return 0 if d.z > 0.0 else 2
	return 1 if d.x > 0.0 else 3

## Face fraction (face, fx, fy) of a unit direction. Equiangular: equal angles on the sphere are equal
## steps across the face, so the tiles stay near square.
static func frac_of_dir(d: Vector3) -> Vector3:
	var f := face_of_dir(d)
	var p := d / d.dot(FACE_N[f])
	var a := atan(p.dot(FACE_E[f])) * 4.0 / PI   # -1..1 across the face
	var b := atan(p.dot(FACE_N_AXIS[f])) * 4.0 / PI
	return Vector3(f, (a + 1.0) * 0.5, (1.0 - b) * 0.5)

## The unit direction of a face fraction: the inverse of `frac_of_dir`.
static func dir_of_frac(face: int, fx: float, fy: float) -> Vector3:
	var a := tan((2.0 * fx - 1.0) * PI / 4.0)
	var b := tan((1.0 - 2.0 * fy) * PI / 4.0)
	return (FACE_N[face] + FACE_E[face] * a + FACE_N_AXIS[face] * b).normalized()

## The face fraction of a chunk (its exact centre point is what the tiles sample).
static func frac_of_chunk(chunk: Vector2, circumference_chunks: int) -> Vector3:
	return frac_of_dir(dir_of_lonlat(lonlat(chunk, circumference_chunks)))

## The chunk-space point of a face fraction.
static func chunk_of_frac(face: int, fx: float, fy: float, circumference_chunks: int) -> Vector2:
	return chunk_of_lonlat(lonlat_of_dir(dir_of_frac(face, fx, fy)), circumference_chunks)

# ---------------------------------------------------------------------------
# Flat map: the net
# ---------------------------------------------------------------------------

## Net position (in face units, x across the band, y down) of a face fraction.
static func net_of_frac(face: int, fx: float, fy: float) -> Vector2:
	return Vector2(NET_COL[face] + fx, NET_ROW[face] + fy)

## The face fraction under a net position, face -1 when it is in the empty corners of the cross.
## The band wraps east-west.
static func frac_of_net(p: Vector2) -> Vector3:
	var x := fposmod(p.x, 4.0)
	var col := floori(x)
	var row := floori(p.y)
	var fy := p.y - row
	var face := -1
	if row == 1:
		face = BAND_FACE[col]
	elif col == 1 and (row == 0 or row == 2):
		face = 4 if row == 0 else 5
	if face < 0 or p.y < 0.0 or p.y >= 3.0:
		return Vector3(-1, 0, 0)
	return Vector3(face, x - col, fy)

## Pull a net position onto the cross: the rows above and below the band are one face wide.
static func clamp_net(p: Vector2) -> Vector2:
	var y := clampf(p.y, 0.0, 2.999999)
	var x := fposmod(p.x, 4.0)
	if floori(y) != 1:
		x = clampf(x, 1.0, 1.999999)
	return Vector2(x, y)

# ---------------------------------------------------------------------------
# Planet: the sphere seen from its centre direction
# ---------------------------------------------------------------------------

## The view basis at a lon/lat: [centre, east, north], unit and orthogonal.
static func planet_basis(center_ll: Vector2) -> Array:
	var lon := center_ll.x
	var lat := center_ll.y
	var east := Vector3(cos(lon), 0.0, -sin(lon))
	var north := Vector3(-sin(lat) * sin(lon), cos(lat), -sin(lat) * cos(lon))
	return [dir_of_lonlat(center_ll), east, north]

## Orthographic projection of a unit direction: (x right, y down, depth), in radians of the sphere's
## radius, y and depth from the view basis. Depth > 0 is the visible side.
static func project_planet(d: Vector3, basis: Array) -> Vector3:
	return Vector3(d.dot(basis[1]), -d.dot(basis[2]), d.dot(basis[0]))

## The unit direction under an orthographic screen point (radians of radius). Zero when it is off the disc.
static func unproject_planet(xy: Vector2, basis: Array) -> Vector3:
	var r2 := xy.length_squared()
	if r2 > 1.0:
		return Vector3.ZERO
	return basis[0] * sqrt(1.0 - r2) + basis[1] * xy.x - basis[2] * xy.y

# ---------------------------------------------------------------------------
# Tiles
# ---------------------------------------------------------------------------

## A tile is Vector4i(level, face, i, j): i and j count tiles across the face from its west and north
## edges, at `level` (2^level finest cells per tile side).
static func tile_of_frac(level: int, face: int, fx: float, fy: float, grid: int) -> Vector4i:
	var n := grid >> level
	return Vector4i(level, face, clampi(floori(fx * n), 0, n - 1), clampi(floori(fy * n), 0, n - 1))

## The tile holding a chunk-space point (its centre).
static func tile_of_chunk(chunk: Vector2, level: int, circumference_chunks: int, grid: int) -> Vector4i:
	var f := frac_of_chunk(chunk, circumference_chunks)
	return tile_of_frac(level, int(f.x), f.y, f.z, grid)

## The chunk a tile samples: the one at its centre, wrapped east-west and held inside the poles.
static func tile_center_chunk(tile: Vector4i, circumference_chunks: int, grid: int) -> Vector2i:
	var n := float(grid >> tile.x)
	var c := chunk_of_frac(tile.y, (tile.z + 0.5) / n, (tile.w + 0.5) / n, circumference_chunks)
	var half := circumference_chunks / 2
	var pole := circumference_chunks / 4
	var x := posmod(floori(c.x) + half, circumference_chunks) - half
	var z := clampi(floori(c.y), -pole, pole - 1)
	return Vector2i(x, z)

## The cache key of a tile: it carries the seed and generator version, so a tile for one world is
## never answered for another.
static func tile_key(seed_v: int, version: int, tile: Vector4i) -> String:
	return "%d:%d:%d:%d:%d:%d" % [seed_v, version, tile.x, tile.y, tile.z, tile.w]

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

## Great-circle distance in metres between two lon/lat points on a planet of `circumference_m`
## (haversine: stable for short and for near-antipodal legs alike).
static func great_circle_m(from_ll: Vector2, to_ll: Vector2, circumference_m: float) -> float:
	var dl := wrap_lon(to_ll.x - from_ll.x)
	var s1 := sin((to_ll.y - from_ll.y) * 0.5)
	var s2 := sin(dl * 0.5)
	var h := clampf(s1 * s1 + cos(from_ll.y) * cos(to_ll.y) * s2 * s2, 0.0, 1.0)
	return 2.0 * asin(sqrt(h)) * circumference_m / TAU
