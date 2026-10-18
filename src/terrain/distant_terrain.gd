extends Node3D
## Phase 51 — distant terrain: a coarse heightmap ring outside the voxel window, so coastlines and
## mountains are visible from afar. RENDER-ONLY: the mesh carries no collision body (the voxel
## window is the only ground a body can touch), and it leaves a hole where the voxel window is.
##
## The ring covers `RING_FACTOR` times the voxel window's half-extent around a centre, sampled from
## `WorldShape` (the large-scale shape: no detail noise, no edits) on a GRID × GRID lattice and
## re-centred whenever the player moves a whole cell.
##
## Phase 164 — outside that square the lattice turns polar: `POLAR_RINGS` rings of cells whose radial
## step grows geometrically with distance, out to a circle of `outer_radius_for` (at least the horizon
## for the camera's highest eye), so the silhouette is the curved ground and never a mesh corner. The
## innermost polar ring is the square's own boundary row, so the two meet without a crack. The ring is
## drawn with `Horizon.curvature_material`, which lowers every vertex by the planet's curvature drop.

const WorldShape := preload("res://src/terrain/world_shape.gd")
const TerrainSliceScript := preload("res://src/terrain/terrain_slice.gd")
const VoxelSliceScript := preload("res://src/terrain/voxel_slice.gd")
const ChunkRecords := preload("res://src/terrain/chunk_records.gd")
const Horizon := preload("res://src/terrain/horizon.gd")
const CHUNK_METERS := 32.0   # TerrainSlice.CHUNK_SIZE * TILE_SIZE
const RING_FACTOR := 10      ## the ring reaches this many times the voxel window's extent
const GRID := 64             ## cells per side of the ring's lattice
const LAND_COLOR := Color(0.36, 0.5, 0.28)
const ROCK_COLOR := Color(0.5, 0.48, 0.45)
const SNOW_COLOR := Color(0.95, 0.97, 0.98)
const SEA_FLOOR_COLOR := Color(0.2, 0.32, 0.5)
const RING_DROP := 0.5       ## land is drawn this far below the shape + detail height
const EDGE_STEP := 2.0       ## ring vertices are this far apart along the window's edge
const SKIRT_DEPTH := 12.0    ## the wall at the window's edge drops this far below the ring there
## Phase 164 — polar rings outside the square lattice (the boundary row of the square is ring 0).
const POLAR_RINGS := 36
## The highest the camera's eye rises above the ground: `PlayerSlice.camera_eye_height` at the widest
## zoom and the steepest pitch is about 25.2 m (asserted by the suite).
const EYE_HEIGHT_MAX := 26.0
const HORIZON_MARGIN := 1.1  ## the outer radius reaches this far past the horizon of `EYE_HEIGHT_MAX`
## A render layer only the ring is on (besides layer 1), so a camera can draw the ring alone (the
## playtest bot's horizon step reads its silhouette that way).
const RING_RENDER_LAYER := 1 << 19

var world_seed: int = 0
var circumference_m: float = 40000.0 * 1000.0
## Half-extent of the voxel window in metres, and the ring's own.
var window_half_m: float = 0.0
var ring_half_m: float = 0.0
## Phase 164 — radius of the ring's outer circle (`outer_radius_for`), set by `rebuild`.
var outer_radius_m: float = 0.0
var _mesh_inst: MeshInstance3D = null

## Phase 120 — one build request: what the ring is built for (compared by `rebuild` to decide whether
## anything changed) and the arguments the worker is handed, including the snapshot of recorded land.
class Request extends RefCounted:
	var world_seed := 0
	var radius := -1
	var circ := -1.0
	var origin := Vector2i(-999999, -999999)
	var window := Vector2(INF, INF)
	var records_rev := -1
	var window_rev := 0   # ChunkRecords.window_revision when this request was made
	var args: Dictionary = {}

	func same_target(o: Vector2i, win: Vector2, rad: int, sd: int, c: float) -> bool:
		return origin == o and window == win and radius == rad and world_seed == sd and circ == c

## Phase 120 — the whole request lifecycle in one record (it replaces `_built_*`, `_task_args`,
## `_queued` and `_discarded`): `built` is the newest accepted request (what the mesh is, or will be,
## for), `running` the one the worker holds, `queued` a newer one that arrived meanwhile, and
## `discarded` the one `_exit_tree` set aside so `_enter_tree` can start it again on a reparent.
class RequestState extends RefCounted:
	var built: Request = null
	var running: Request = null
	var queued: Request = null
	var discarded: Request = null

var _req := RequestState.new()

## Phase 68 — the lattice build runs on a `WorkerThreadPool` task; the main thread only swaps the
## finished mesh in. `_task` is the task id in flight (-1 when idle); the task writes its mesh to
## its `BuildControl`, read after `wait_for_task_completion`.
var _task := -1

## Phase 83 — shared between the main thread and a build's worker: the main thread raises `aborted`
## (leaving the tree), the worker checks it before each row and returns no mesh. `rows` counts the
## rows the worker has started, which is what the suite reads to bound the teardown.
class BuildControl extends RefCounted:
	var aborted := false
	var rows := 0
	var mesh: ArrayMesh = null   ## the worker's result, read after `wait_for_task_completion`

var _control: BuildControl = null

## Phase 77 — build counters, read by the suite: requests accepted by `rebuild`, builds whose mesh
## was swapped in, and builds dropped because a newer request superseded them.
var rebuilds_requested := 0
var rebuilds_completed := 0
var rebuilds_dropped := 0
## Phase 96/120 — worker tasks started. Invariant: `builds_started == rebuilds_requested -
## rebuilds_dropped + restarts`, where `restarts` counts the starts that were not a fresh request (a
## queued request begun by `poll`, a discarded one begun by `_enter_tree`).
var builds_started := 0
var restarts := 0

## Phase 120 — a records change alone (not a centre move) rebuilds the ring at most this often.
var record_debounce_ms := 500
var _last_start_ms := -1000000

## Phase 63: the scene-origin offset a client rebase has applied (see `shift_scene`).
const SceneOffset := preload("res://src/core/scene_offset.gd")
var _origin: SceneOffset = SceneOffset.new()

## Shift every ring node by `shift`; its world position is unchanged.
func shift_scene(shift: Vector3) -> void:
	_origin.value += shift
	if _mesh_inst != null:
		_mesh_inst.position += shift

func scene_offset() -> Vector3:
	return _origin.value

## Phase 120 — the ring a fold carries across (see `VoxelSlice.detach_standins`): taken out of the
## slice so the fold's rebase does not move it, it keeps drawing until the next ring is swapped in.
var _standin: MeshInstance3D = null

## Hand over the current ring mesh (null when none) for the caller to carry; `_swap_in` frees it.
func detach_ring() -> Node3D:
	if _mesh_inst == null:
		return _standin
	if _standin != null:
		_standin.queue_free()
	_standin = _mesh_inst
	_mesh_inst = null
	return _standin

## Ring half-extent in metres for a voxel window of `radius_chunks` (Chebyshev radius).
static func ring_half_extent(radius_chunks: int) -> float:
	return float(RING_FACTOR) * (float(radius_chunks) + 0.5) * CHUNK_METERS

## Phase 164 — the outer circle's radius for a square lattice of half-extent `half_m`: at least
## `HORIZON_MARGIN` × the horizon of `EYE_HEIGHT_MAX` on a planet of `circumference_m`, and clear of the
## square's corners by one square cell.
static func outer_radius_for(half_m: float, circumference_m: float = -1.0) -> float:
	var corner := half_m * sqrt(2.0) + half_m * 2.0 / float(GRID)
	return maxf(Horizon.horizon_distance(EYE_HEIGHT_MAX, circumference_m) * HORIZON_MARGIN, corner * 1.25)

## Phase 164 — radius of the first polar ring past the square (ring 0 is the square's boundary).
static func first_polar_radius(half_m: float) -> float:
	return half_m * sqrt(2.0) + half_m * 2.0 / float(GRID)

## Phase 164 — rows a full build visits (the `BuildControl.rows` of an unaborted build): the square's
## height rows, its cell rows and one per polar ring.
static func build_rows() -> int:
	return 2 * GRID + 1 + POLAR_RINGS

## Colour of the distant ground at altitude `alt` above sea level, whitened toward the polar ice at
## world Z `z` as the voxel ground is (`VoxelSlice.icy`).
static func color_for(alt: float, z: float = 0.0) -> Color:
	return VoxelSliceScript.icy(_altitude_color(alt), z)

static func _altitude_color(alt: float) -> Color:
	if alt < 0.0:
		return SEA_FLOOR_COLOR
	if alt > 300.0:
		return SNOW_COLOR
	if alt > 150.0:
		return ROCK_COLOR
	return LAND_COLOR

## Request the ring around world XZ `center` for a voxel window of `radius_chunks`. Returns true
## when a build was started or queued (the centre moved a whole cell, or first call); the finished
## mesh is swapped in by `poll` (called every frame from `_process`).
func rebuild(center: Vector2, radius_chunks: int) -> bool:
	window_half_m = (float(radius_chunks) + 0.5) * CHUNK_METERS
	ring_half_m = ring_half_extent(radius_chunks)
	outer_radius_m = outer_radius_for(ring_half_m, circumference_m)
	var cell := ring_half_m * 2.0 / float(GRID)
	var origin := Vector2i(floori(center.x / cell), floori(center.y / cell))
	# The voxel window is chunk-snapped around the player: the hole is exactly that rectangle, so the
	# ring rebuilds when the player's chunk changes as well as when the lattice cell does.
	var win_center := Vector2((floorf(center.x / CHUNK_METERS) + 0.5) * CHUNK_METERS,
		(floorf(center.y / CHUNK_METERS) + 0.5) * CHUNK_METERS)
	var rev := ChunkRecords.revision()
	var built := _req.built
	var same := built != null and built.same_target(origin, win_center, radius_chunks, world_seed, circumference_m) \
		and (_mesh_inst != null or _task >= 0)
	# Same target: only a newer set of recorded chunks can still ask for a rebuild, debounced.
	if same and (built.records_rev == rev or Time.get_ticks_msec() - _last_start_ms < record_debounce_ms):
		return false
	var r := Request.new()
	r.origin = origin
	r.window = win_center
	r.world_seed = world_seed
	r.radius = radius_chunks
	r.circ = circumference_m
	r.records_rev = rev
	WorldShape.warm()   # the fabric snapshot is taken here, never first on a worker
	TerrainSliceScript.warm_polar_caches()   # and the polar caches `polar_ground` reads
	var snap: Dictionary = {}
	# The ring is centred on the lattice cell origin, up to a whole cell from the window centre.
	var wc := Vector2i(floori(win_center.x / CHUNK_METERS), floori(win_center.y / CHUNK_METERS))
	var reach := int(ceil((ring_half_m + cell) / CHUNK_METERS)) + 1
	var circ_chunks := TerrainSliceScript.circumference_chunks()
	var window_rev := ChunkRecords.window_revision(wc, reach, circ_chunks)
	if same and window_rev == built.window_rev:
		built.records_rev = rev   # the change lies outside the ring (per-region revision): nothing to redraw
		return false
	if not ChunkRecords.is_empty():
		snap = ChunkRecords.snapshot_near(wc, reach, circ_chunks)
	r.window_rev = window_rev
	r.args = {
		"seed": world_seed, "w": circumference_m,
		"ring_center": Vector2(float(origin.x) * cell, float(origin.y) * cell),
		"half_m": ring_half_m, "window_half_m": window_half_m, "window_center": win_center,
		"snap": snap,
	}
	_req.built = r
	rebuilds_requested += 1
	_req.discarded = null   # a newer request supersedes whatever `_exit_tree` set aside
	if _task >= 0:
		if _req.queued != null:
			rebuilds_dropped += 1   # the queued request never ran
		_req.queued = r
	else:
		_start(r)
	return true

func _start(r: Request) -> void:
	builds_started += 1
	_last_start_ms = Time.get_ticks_msec()
	_control = BuildControl.new()
	r.args["control"] = _control
	_req.running = r
	# #397 — the task is a STATIC function on the script, handed the request args (never mutated on the main thread once running): a task
	# bound to this node keeps the node locked while it runs, so freeing the ring mid-build failed
	# ("Object is locked and can't be freed") and leaked it.
	_task = WorkerThreadPool.add_task(Callable(get_script(), "_build_job").bind(r.args, _control))

static func _build_job(a: Dictionary, control: BuildControl) -> void:
	control.mesh = build_mesh(a["seed"], a["w"], a["ring_center"], a["half_m"], a["window_half_m"], a["window_center"], control, a["snap"])

## True while a lattice build is in flight or queued.
func is_building() -> bool:
	return _task >= 0

## Swap in a finished build (non-blocking). With `block` true, waits for every pending build.
## Returns true when a mesh was swapped in.
func poll(block: bool = false) -> bool:
	var swapped := false
	while _task >= 0:
		if not block and not WorkerThreadPool.is_task_completed(_task):
			break
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		var mesh: ArrayMesh = _control.mesh if _control != null else null
		if _control != null:
			_control.mesh = null
		if mesh == null:   # the build was aborted: nothing to apply
			if _req.queued != null:
				rebuilds_dropped += 1   # the queued request never ran
			_req.queued = null
			break
		if _req.queued == null:
			_swap_in(mesh)
			rebuilds_completed += 1
			swapped = true
		else:   # superseded while building: drop this one, build the newest request
			rebuilds_dropped += 1
			var next := _req.queued
			_req.queued = null
			restarts += 1
			_start(next)
	return swapped

func _swap_in(mesh: ArrayMesh) -> void:
	if mesh == null:
		return
	if _mesh_inst != null:
		_mesh_inst.queue_free()
	if _standin != null:
		_standin.queue_free()
		_standin = null
	_mesh_inst = MeshInstance3D.new()
	_mesh_inst.name = "DistantRing"
	_mesh_inst.mesh = mesh
	_mesh_inst.material_override = Horizon.curvature_material(circumference_m)
	_mesh_inst.layers = 1 | RING_RENDER_LAYER
	_mesh_inst.position = _origin.value
	add_child(_mesh_inst)

func _process(_delta: float) -> void:
	poll()

## Leaving the tree aborts the in-flight build (the worker stops at its next row) instead of
## waiting out a whole lattice, and drops any queued request and any result. The discarded request
## is remembered so a reparent (exit, then re-enter) rebuilds the ring.
func _exit_tree() -> void:
	_join_worker(true)

## Phase 120 — a worker started while detached is still joined if the node is freed: `_exit_tree`
## never ran for it.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_join_worker(false)

func _join_worker(remember: bool) -> void:
	if _task < 0:
		return
	if _control != null:
		_control.aborted = true
	WorkerThreadPool.wait_for_task_completion(_task)
	if remember:
		_req.discarded = _req.queued if _req.queued != null else _req.running
	if _req.queued != null:
		rebuilds_dropped += 1   # the aborted running request is superseded (or the queued one never runs)
	_task = -1
	_req.queued = null

## Re-requests a build `_exit_tree` discarded. A fresh `BuildControl` (abort flag clear) is made by
## `_start`.
func _enter_tree() -> void:
	var r := _req.discarded
	if r == null:
		return
	_req.discarded = null
	if _task < 0:
		restarts += 1
		_start(r)
	elif _req.queued == null:   # a build is already running: the discarded request waits behind it
		_req.queued = r

## The ring's mesh: GRID × GRID cells centred on `ring_center` spanning ±`half_m`, with the voxel
## window (`window_half_m` around `window_center`) cut out EXACTLY: a cell wholly inside is skipped, a
## cell the window edge crosses is clipped to the part outside it, and a skirt wall drops below the
## ring along the window's edge so no gap shows between the ring and the voxel chunks' side.
##
## Heights are the shape's PLUS the detail noise the voxel ground adds (a land vertex sits `RING_DROP`
## below the voxel ground there), floored at the sea level so the ocean reads as a flat sheet. Clipped
## vertices are sampled where they lie rather than interpolated, so the ring meets the voxel ground at
## the window edge to within the sub-metre difference between the shape's chunk-cell interpolation and
## its direct evaluation. Farther out the lattice is coarse (a cell is 10 × the window's chunk
## width / 64 across) and the detail is sampled, not filtered: the ring is a backdrop, not ground.
## Only the LOCAL player's window is cut; a remote peer's window lies under the ring's sheet.
static func build_mesh(seed_v: int, w: float, ring_center: Vector2, half_m: float, win_half_m: float, window_center: Vector2, control: BuildControl = null, snap: Dictionary = {}) -> ArrayMesh:
	var cell := half_m * 2.0 / float(GRID)
	var sea := WorldShape.sea_level()
	var noise := FastNoiseLite.new()   # this build's own: FastNoiseLite is not shared across threads
	TerrainSliceScript.configure_noise(noise, seed_v)
	var heights := PackedFloat32Array()
	heights.resize((GRID + 1) * (GRID + 1))
	for j in GRID + 1:
		if control != null:
			if control.aborted:
				return null
			control.rows += 1
		for i in GRID + 1:
			var x := ring_center.x - half_m + float(i) * cell
			var z := ring_center.y - half_m + float(j) * cell
			heights[j * (GRID + 1) + i] = ground_at(noise, seed_v, x, z, w, snap)
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var wl := window_center.x - win_half_m
	var wr := window_center.x + win_half_m
	var wb := window_center.y - win_half_m
	var wt := window_center.y + win_half_m
	for j in GRID:
		if control != null:
			if control.aborted:
				return null
			control.rows += 1
		for i in GRID:
			var x0 := ring_center.x - half_m + float(i) * cell
			var z0 := ring_center.y - half_m + float(j) * cell
			var x1 := x0 + cell
			var z1 := z0 + cell
			if x1 <= wl or x0 >= wr or z1 <= wb or z0 >= wt:   # clear of the window: the whole cell
				_add_quad(vertices, colors, normals, indices, sea, x0, z0, x1, z1,
					heights[j * (GRID + 1) + i], heights[j * (GRID + 1) + i + 1],
					heights[(j + 1) * (GRID + 1) + i + 1], heights[(j + 1) * (GRID + 1) + i])
				continue
			if x0 >= wl and x1 <= wr and z0 >= wb and z1 <= wt:
				continue   # wholly inside the voxel window: the voxel chunks draw it
			# The window edge crosses this cell: the part outside it is up to four strips, each cut finely
			# along the window edge (see `_add_strip`) so the ring follows the voxel ground there.
			if x0 < wl:
				_add_strip(vertices, colors, normals, indices, noise, seed_v, w, snap, sea, x0, z0, wl, z1, true, true)
			if x1 > wr:
				_add_strip(vertices, colors, normals, indices, noise, seed_v, w, snap, sea, wr, z0, x1, z1, true, false)
			var mx0 := maxf(x0, wl)
			var mx1 := minf(x1, wr)
			if z0 < wb:
				_add_strip(vertices, colors, normals, indices, noise, seed_v, w, snap, sea, mx0, z0, mx1, wb, false, true)
			if z1 > wt:
				_add_strip(vertices, colors, normals, indices, noise, seed_v, w, snap, sea, mx0, wt, mx1, z1, false, false)
	_add_skirt(vertices, colors, normals, indices, noise, seed_v, w, snap, sea, window_center, win_half_m)
	if not _add_polar(vertices, colors, normals, indices, noise, seed_v, w, snap, sea, ring_center, half_m, heights, control):
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	if not vertices.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## The ground height the voxel ground has at (x, z) to within the shape's interpolation: the
## shape plus the detail noise, clamped to the fabric's height range.
static func ground_at(noise: FastNoiseLite, seed_v: int, x: float, z: float, w: float, snap: Dictionary = {}) -> float:
	var h := TerrainSliceScript.shape_height_in(snap, seed_v, x, z, w) + TerrainSliceScript.detail_of(noise, x, z)
	return TerrainSliceScript.polar_ground(seed_v, clampf(h, WorldShape.min_height(), WorldShape.max_height()), x, z, w)

## The y a ring vertex at ground height `h` is drawn at.
static func ring_y(h: float, sea: float) -> float:
	return maxf(h, sea) - RING_DROP

## A rectangle outside the window with its window-side edge on the window's edge. `along_z` says that
## edge runs along Z (else X); `near_high` that it is the rectangle's high side. The rectangle is cut
## every `EDGE_STEP` along that edge: window-side vertices are sampled exactly, far-side ones
## interpolate the exact far corners.
static func _add_strip(vertices: PackedVector3Array, colors: PackedColorArray, normals: PackedVector3Array,
		indices: PackedInt32Array, noise: FastNoiseLite, seed_v: int, w: float, snap: Dictionary, sea: float,
		x0: float, z0: float, x1: float, z1: float, along_z: bool, near_high: bool) -> void:
	var lo := z0 if along_z else x0
	var hi := z1 if along_z else x1
	var n := maxi(int(ceil((hi - lo) / EDGE_STEP)), 1)
	var near := (x1 if near_high else x0) if along_z else (z1 if near_high else z0)
	var far := (x0 if near_high else x1) if along_z else (z0 if near_high else z1)
	var far_lo := _ground_along(noise, seed_v, w, snap, lo, far, along_z)
	var far_hi := _ground_along(noise, seed_v, w, snap, hi, far, along_z)
	var prev_t := lo
	var prev_near := _ground_along(noise, seed_v, w, snap, lo, near, along_z)
	var prev_far := far_lo
	for k in range(1, n + 1):
		var t := lerpf(lo, hi, float(k) / float(n))
		var h_near := _ground_along(noise, seed_v, w, snap, t, near, along_z)
		var h_far := lerpf(far_lo, far_hi, float(k) / float(n))
		var a := minf(near, far)
		var b := maxf(near, far)
		var lo_h := prev_far if near_high else prev_near
		var hi_h := prev_near if near_high else prev_far
		var lo_h2 := h_far if near_high else h_near
		var hi_h2 := h_near if near_high else h_far
		if along_z:
			_add_quad(vertices, colors, normals, indices, sea, a, prev_t, b, t, lo_h, hi_h, hi_h2, lo_h2)
		else:
			_add_quad(vertices, colors, normals, indices, sea, prev_t, a, t, b, lo_h, lo_h2, hi_h2, hi_h)
		prev_t = t
		prev_near = h_near
		prev_far = h_far

## `ground_at` for a point given as (`along`, `across`): along the strip's cut direction and across
## it. `along_z` strips run along Z (x = across, z = along); the others along X.
static func _ground_along(noise: FastNoiseLite, seed_v: int, w: float, snap: Dictionary, along: float, across: float, along_z: bool) -> float:
	if along_z:
		return ground_at(noise, seed_v, across, along, w, snap)
	return ground_at(noise, seed_v, along, across, w, snap)

static func _add_quad(vertices: PackedVector3Array, colors: PackedColorArray, normals: PackedVector3Array,
		indices: PackedInt32Array, sea: float, x0: float, z0: float, x1: float, z1: float,
		h00: float, h10: float, h11: float, h01: float) -> void:
	var base := vertices.size()
	vertices.append(Vector3(x0, ring_y(h00, sea), z0))
	vertices.append(Vector3(x1, ring_y(h10, sea), z0))
	vertices.append(Vector3(x1, ring_y(h11, sea), z1))
	vertices.append(Vector3(x0, ring_y(h01, sea), z1))
	for v in [[h00, z0], [h10, z0], [h11, z1], [h01, z1]]:
		colors.append(color_for(v[0] - sea, v[1]))
	var n := (vertices[base + 2] - vertices[base]).cross(vertices[base + 1] - vertices[base]).normalized()
	if n.y < 0.0:
		n = -n
	for _k in 4:
		normals.append(n)
	indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])

## The wall around the window's edge: a strip of quads per side, sampled every ~2 m, from the ring's
## height down `SKIRT_DEPTH`, so the ring never shows a sliver of sky between itself and the voxel
## chunks' outer wall.
static func _add_skirt(vertices: PackedVector3Array, colors: PackedColorArray, normals: PackedVector3Array,
		indices: PackedInt32Array, noise: FastNoiseLite, seed_v: int, w: float, snap: Dictionary, sea: float,
		window_center: Vector2, win_half_m: float) -> void:
	var steps := maxi(int(ceil(win_half_m)), 1)   # ~2 m per step along each 2 * window_half_m side
	var corners := [
		Vector2(window_center.x - win_half_m, window_center.y - win_half_m),
		Vector2(window_center.x + win_half_m, window_center.y - win_half_m),
		Vector2(window_center.x + win_half_m, window_center.y + win_half_m),
		Vector2(window_center.x - win_half_m, window_center.y + win_half_m),
	]
	for side in 4:
		var a: Vector2 = corners[side]
		var b: Vector2 = corners[(side + 1) % 4]
		var out_n := Vector3((b - a).y, 0.0, -(b - a).x).normalized()   # outward-facing for this winding
		var prev_top := Vector3.ZERO
		var prev_h := 0.0
		for k in steps + 1:
			var p := a.lerp(b, float(k) / float(steps))
			var h := ground_at(noise, seed_v, p.x, p.y, w, snap)
			var top := Vector3(p.x, ring_y(h, sea), p.y)
			if k > 0:
				var base := vertices.size()
				vertices.append(prev_top)
				vertices.append(top)
				vertices.append(top - Vector3(0.0, SKIRT_DEPTH, 0.0))
				vertices.append(prev_top - Vector3(0.0, SKIRT_DEPTH, 0.0))
				colors.append(color_for(prev_h - sea, prev_top.z))
				colors.append(color_for(h - sea, p.y))
				colors.append(color_for(h - sea, p.y))
				colors.append(color_for(prev_h - sea, prev_top.z))
				for _k in 4:
					normals.append(out_n)
				indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
			prev_top = top
			prev_h = h

## Phase 164 — the polar rings around the square lattice. Ring 0 is the square's boundary row (its
## 4 × GRID vertices, corners included, with the heights the square used, so the two share every edge
## vertex); ring k ≥ 1 lies on a circle of radius `first_polar_radius` × q^(k−1), the last one at
## `outer_radius_for`. Every ring has a vertex on each ray from `ring_center` through a boundary vertex,
## so a cell between two rays is a quad and the corners of the square are vertices, never cut across.
## Vertices are shared between cells (smooth normals): the polar part costs (POLAR_RINGS + 1) × 4 × GRID
## vertices. Returns false when the build was aborted.
static func _add_polar(vertices: PackedVector3Array, colors: PackedColorArray, normals: PackedVector3Array,
		indices: PackedInt32Array, noise: FastNoiseLite, seed_v: int, w: float, snap: Dictionary, sea: float,
		ring_center: Vector2, half_m: float, heights: PackedFloat32Array, control: BuildControl) -> bool:
	var cell := half_m * 2.0 / float(GRID)
	var n := 4 * GRID
	var dirs: Array[Vector2] = []
	var base := vertices.size()
	# Ring 0: the boundary row, counter-clockwise from the (-half, -half) corner.
	for s in n:
		var side := s / GRID
		var t := s % GRID
		var ij := Vector2i.ZERO
		match side:
			0: ij = Vector2i(t, 0)
			1: ij = Vector2i(GRID, t)
			2: ij = Vector2i(GRID - t, GRID)
			_: ij = Vector2i(0, GRID - t)
		var p := Vector2(ring_center.x - half_m + float(ij.x) * cell, ring_center.y - half_m + float(ij.y) * cell)
		var h := heights[ij.y * (GRID + 1) + ij.x]
		dirs.append((p - ring_center).normalized())
		vertices.append(Vector3(p.x, ring_y(h, sea), p.y))
		colors.append(color_for(h - sea, p.y))
	var r1 := first_polar_radius(half_m)
	var q := pow(outer_radius_for(half_m, w) / r1, 1.0 / float(POLAR_RINGS - 1))
	for k in range(1, POLAR_RINGS + 1):
		if control != null:
			if control.aborted:
				return false
			control.rows += 1
		var r := r1 * pow(q, float(k - 1)) if k < POLAR_RINGS else outer_radius_for(half_m, w)
		for s in n:
			var p := ring_center + dirs[s] * r
			var h := ground_at(noise, seed_v, p.x, p.y, w, snap)
			vertices.append(Vector3(p.x, ring_y(h, sea), p.y))
			colors.append(color_for(h - sea, p.y))
	var acc := PackedVector3Array()
	acc.resize(n * (POLAR_RINGS + 1))
	for k in POLAR_RINGS:
		for s in n:
			var a := base + k * n + s
			var b := base + k * n + (s + 1) % n
			var c := base + (k + 1) * n + (s + 1) % n
			var d := base + (k + 1) * n + s
			indices.append_array([a, b, c, a, c, d])
			var f := (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a])
			if f.y < 0.0:
				f = -f
			for v in [a, b, c, d]:
				acc[v - base] += f
	for v in acc:
		var nv := v.normalized() if v.length_squared() > 0.0 else Vector3.UP
		normals.append(nv)
	return true

## Number of collision bodies in this ring's subtree — always 0 (asserted by the suite).
func collision_body_count() -> int:
	return _count_collision(self)

static func _count_collision(n: Node) -> int:
	var c := 1 if n is CollisionObject3D or n is CollisionShape3D else 0
	for ch in n.get_children():
		c += _count_collision(ch)
	return c
