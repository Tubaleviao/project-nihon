extends RefCounted
## Phase 193 — a ray against the voxel columns themselves, not against attached collision.
##
## The aim, mine and build ray reaches 60 m, but since Phase 193 a walking body keeps terrain collision only
## on the chunk it stands in and the eight around it (`NearRing.COLLISION_RADIUS`): the ring two out cost the
## walk ~3 ms of main thread a frame for Jolt to take each chunk's trimesh, and nothing but the aim ray
## touched it. The voxel world is a column of solid runs per 0.5 m tile (`VoxelSlice.get_runs_at_tile`),
## and the mesh and collision are both built from those runs, so a ray walked through the tiles hits
## exactly the faces the collision would have had — with no body, and also on ground whose collision has
## not landed yet.
##
## The walk is a 2D DDA over the XZ tiles (Amanatides & Woo). In each tile the ray's height span is first
## tested against the column's top (`top_at`, cheap: a heightmap read when the tile has no edits); only a
## tile the ray can reach reads its runs (`runs_at`). Positions are done in doubles from the scene position
## and the scene offset, so a ray 5,000 km from the origin hits the same tile as one at it (a float32
## world coordinate there is only good to 0.5 m, a whole tile).
##
## A ray that starts inside a solid run does not hit that run (as a physics ray does not report the shape
## it starts in): it hits the next face ahead of it.
##
## Public API:
##   cast(from, dir, max_dist, offset, runs_at, top_at) -> Dictionary — static: {} on a miss, else
##       { position (scene), normal, distance }
##   tile_of(scene_pos, offset) -> Vector2i — static: the tile a scene position stands in

const VoxelConsts := preload("res://src/terrain/voxel_consts.gd")

const TILE := VoxelConsts.TILE_SIZE
## A ray grazing a face within this does not count as starting inside the run.
const EPS := 0.0001

## The tile the scene position `scene_pos` stands in, under the scene offset `offset` (world = scene - offset).
static func tile_of(scene_pos: Vector3, offset: Vector3) -> Vector2i:
	return Vector2i(floori((float(scene_pos.x) - float(offset.x)) / TILE), floori((float(scene_pos.z) - float(offset.z)) / TILE))

## Cast from the scene position `from` along `dir` for `max_dist` metres. `offset` is the scene offset
## (world = scene - offset). `runs_at: Callable(Vector2i) -> Array` of `{ bottom, top }` runs in world
## height; `top_at: Callable(Vector2i) -> float` is the highest solid height of a tile (any value at or
## above its last run's top is correct, only slower). Returns {} on a miss.
static func cast(from: Vector3, dir: Vector3, max_dist: float, offset: Vector3, runs_at: Callable, top_at: Callable) -> Dictionary:
	if dir.length_squared() <= 0.0 or max_dist <= 0.0:
		return {}
	var d := dir.normalized()
	var dx := float(d.x)
	var dy := float(d.y)
	var dz := float(d.z)
	# The start in world units, in doubles.
	var wx := float(from.x) - float(offset.x)
	var wy := float(from.y) - float(offset.y)
	var wz := float(from.z) - float(offset.z)
	var tx := floori(wx / TILE)
	var tz := floori(wz / TILE)
	var step_x := 1 if dx > 0.0 else -1
	var step_z := 1 if dz > 0.0 else -1
	# The ray parameter at the first X and Z tile boundaries, and its advance per tile.
	var t_max_x := INF
	var t_delta_x := INF
	if absf(dx) > 0.0:
		var next_x := float(tx + (1 if step_x > 0 else 0)) * TILE
		t_max_x = (next_x - wx) / dx
		t_delta_x = TILE / absf(dx)
	var t_max_z := INF
	var t_delta_z := INF
	if absf(dz) > 0.0:
		var next_z := float(tz + (1 if step_z > 0 else 0)) * TILE
		t_max_z = (next_z - wz) / dz
		t_delta_z = TILE / absf(dz)
	var t0 := 0.0
	# The side face crossed to enter the current tile (none for the start tile).
	var entered := Vector3.ZERO
	while t0 <= max_dist:
		var t1 := minf(minf(t_max_x, t_max_z), max_dist)
		var hit := _hit_in_tile(Vector2i(tx, tz), t0, t1, wy, dy, entered, runs_at, top_at)
		if hit.size() > 0:
			var t := float(hit[0])
			return {
				"position": Vector3(float(from.x) + dx * t, float(from.y) + dy * t, float(from.z) + dz * t),
				"normal": hit[1],
				"distance": t,
			}
		if t1 >= max_dist:
			break
		t0 = t1
		if t_max_x < t_max_z:
			tx += step_x
			t_max_x += t_delta_x
			entered = Vector3(-step_x, 0, 0)
		else:
			tz += step_z
			t_max_z += t_delta_z
			entered = Vector3(0, 0, -step_z)
	return {}

## The ray's first hit inside tile `tile` over [t0, t1], as [t, normal], or [] when it passes through.
static func _hit_in_tile(tile: Vector2i, t0: float, t1: float, wy: float, dy: float, entered: Vector3,
		runs_at: Callable, top_at: Callable) -> Array:
	var y0 := wy + dy * t0
	var y1 := wy + dy * t1
	if minf(y0, y1) > float(top_at.call(tile)):
		return []   # the ray stays above the column here
	var best: Array = []
	for run in runs_at.call(tile):
		var bottom := float(run["bottom"])
		var top := float(run["top"])
		if top - bottom <= 0.0:
			continue
		var t := INF
		var normal := Vector3.ZERO
		if y0 > bottom + EPS and y0 < top - EPS:
			# Inside the run where the ray enters this tile: a side face, unless the ray started here.
			if entered == Vector3.ZERO:
				continue
			t = t0
			normal = entered
		elif y0 >= top - EPS and dy < 0.0:
			t = maxf(t0, (top - wy) / dy)   # down onto its top
			normal = Vector3.UP
		elif y0 <= bottom + EPS and dy > 0.0:
			t = maxf(t0, (bottom - wy) / dy)   # up into its underside
			normal = Vector3.DOWN
		if t <= t1 and (best.is_empty() or t < float(best[0])):
			best = [t, normal]
	return best
