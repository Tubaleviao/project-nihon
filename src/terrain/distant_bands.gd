extends Node3D
## Phase 165 — mountains on the horizon: coarse bands outside Phase 164's distant ring, out to the
## distance where the tallest terrain can still clear the horizon. RENDER-ONLY (no collision body).
##
## The bands are nested square annuli in the clipmap style. Band k has a cell of `CELL_0 · 2^k`; its
## outer edge is the next band's hole, so no band overlaps another and no crack opens between them:
## band k's outer-edge vertices take band k+1's heights (and the midpoints between them the average of
## the two neighbours), which is exactly what band k+1 draws along its hole. A band's lattice is the
## world's, multiples of its cell, so it re-centres only when the player moves a whole cell of that
## band: the far bands rebuild rarely. Band 0's hole lies inside the ring's circle (`HOLE_FRACTION` of
## its radius) and the ring, drawn `RING_DROP` above the bands, hides the overlap.
##
## Bands sample `WorldShape` only (no detail noise, no records) and keep peaks: a vertex takes the
## highest shape height in its cell (`SUB` × `SUB` samples), so a ridge never vanishes between two
## samples. Heights are the same `polar_ground` ones the ring uses, and X wraps inside the shape's noise,
## so the bands cross the antimeridian and fold over the poles as the ring does. Each build runs on a
## `WorkerThreadPool` task; the main thread only swaps finished meshes in (`poll`).

const WorldShape := preload("res://src/terrain/world_shape.gd")
const TerrainSliceScript := preload("res://src/terrain/terrain_slice.gd")
const DistantTerrain := preload("res://src/terrain/distant_terrain.gd")
const Horizon := preload("res://src/terrain/horizon.gd")

const CELL_0 := 256.0          ## band 0's cell in metres; band k is `CELL_0 · 2^k`
const SUB := 3                 ## height samples per cell side (the highest one is kept)
const BAND_DROP := DistantTerrain.RING_DROP * 2.0   ## the bands are drawn this far below the shape height
const HOLE_FRACTION := 0.6     ## band 0's hole half-extent, as a share of the ring's outer radius
const MAX_BANDS := 8
## The eye height `outer_radius` is computed for: a standing eye (the farthest a given peak is seen from
## is the summed horizon distances of the eye and the peak).
const EYE_HEIGHT := 1.7
## A render layer only the bands are on (besides layer 1), so the playtest bot can draw them alone.
const BANDS_RENDER_LAYER := 1 << 20
## All bands together stay within this many vertices at the default view distance (the suite checks it).
const VERTEX_BUDGET := 120000

var world_seed: int = 0
var circumference_m: float = 40000.0 * 1000.0
## Radius of the ring the bands begin under (`DistantTerrain.outer_radius_m`), set by `update`.
var ring_radius_m: float = 0.0
## Outermost band radius (`outer_radius`), set by `update`; the camera's far plane follows it.
var outer_radius_m: float = 0.0

## One band's build state: the request it is built for, the one the worker holds and a newer one waiting.
class Band extends RefCounted:
	var index := 0
	var spec: Dictionary = {}
	var want: Dictionary = {}       ## the newest accepted request (what the mesh is, or will be, for)
	var running: Dictionary = {}
	var queued: Dictionary = {}
	var discarded: Dictionary = {}  ## the request `_exit_tree` set aside so `_enter_tree` can restart it
	var task := -1
	var control: BuildControl = null
	var mesh_inst: MeshInstance3D = null
	var builds_started := 0
	var builds_completed := 0
	var last_thread := -1           ## the thread id the last build job ran on (the suite reads it)

class BuildControl extends RefCounted:
	var aborted := false
	var mesh: ArrayMesh = null
	var thread := -1

var _bands: Array[Band] = []
var _plan_key := ""
var _origin: SceneOffset = SceneOffset.new()
const SceneOffset := preload("res://src/core/scene_offset.gd")

## Outermost radius: the horizon of an eye `eye_h` high plus the horizon of the tallest terrain
## (`WorldShape.max_height`), about 85 km at the fabric's 512 m.
## `tallest` replaces the fabric's `maxHeight` when positive (the suite).
static func outer_radius(circ: float = -1.0, eye_h: float = EYE_HEIGHT, tallest: float = -1.0) -> float:
	var top := tallest if tallest > 0.0 else WorldShape.max_height()
	return Horizon.horizon_distance(eye_h, circ) + Horizon.horizon_distance(top, circ)

## The bands for a ring of `ring_radius` out to `outer`: an Array of `{cell, hole_half, half}` in metres.
## Band k's `half` is the next band's `hole_half`; the last one reaches `outer` clear of its own cell.
static func plan(ring_radius: float, outer: float) -> Array:
	var out: Array = []
	var hole0 := maxf(floorf(HOLE_FRACTION * ring_radius / CELL_0), 4.0) * CELL_0
	hole0 = floorf(hole0 / (CELL_0 * 2.0)) * CELL_0 * 2.0   # an even number of cells: every edge lies on the coarser lattice
	for k in MAX_BANDS:
		var cell := CELL_0 * pow(2.0, float(k))
		var half := hole0 * pow(2.0, float(k + 1))
		out.append({"cell": cell, "hole_half": half * 0.5, "half": half})
		if half - cell >= outer:
			break
	return out

## Cells along one side of every band's outer square (the same for all bands).
static func cells_per_side(spec: Dictionary) -> int:
	return roundi(2.0 * float(spec["half"]) / float(spec["cell"]))

## Vertices a band of `spec` has: its lattice minus the strict inside of its hole.
static func band_vertex_count(spec: Dictionary) -> int:
	var n := cells_per_side(spec)
	var hh := roundi(float(spec["hole_half"]) / float(spec["cell"]))
	return (n + 1) * (n + 1) - (2 * hh - 1) * (2 * hh - 1)

## The shape's ground height the bands read (the ring's `ground_at` minus the detail noise and records).
static func shape_ground(seed_v: int, w: float, x: float, z: float) -> float:
	var h := clampf(WorldShape.height(seed_v, x, z, w), WorldShape.min_height(), WorldShape.max_height())
	return TerrainSliceScript.polar_ground(seed_v, h, x, z, w)

## The height of the band-`cell` lattice vertex (ix, iz): the highest of `SUB` × `SUB` samples over the
## cell around it. `height_fn(x, z)` replaces the shape (the suite's fixtures).
static func cell_height(seed_v: int, w: float, cell: float, ix: int, iz: int, height_fn: Callable = Callable()) -> float:
	var best := -INF
	for a in SUB:
		var x := (float(ix) + float(a) / float(SUB - 1) - 0.5) * cell
		for b in SUB:
			var z := (float(iz) + float(b) / float(SUB - 1) - 0.5) * cell
			var h: float = height_fn.call(x, z) if height_fn.is_valid() else shape_ground(seed_v, w, x, z)
			best = maxf(best, h)
	return best

## The y a band vertex of ground height `h` is drawn at.
static func band_y(h: float, sea: float) -> float:
	return maxf(h, sea) - BAND_DROP

## The lattice origin (whole cells) of band `spec` for a player at world XZ `p`.
static func origin_for(spec: Dictionary, p: Vector2) -> Vector2i:
	var cell: float = spec["cell"]
	return Vector2i(floori(p.x / cell), floori(p.y / cell))

## The band's mesh. `origin` is the hole's centre in cells of this band; the outer square is centred on
## the next band's lattice below it when `has_outer` (so the two edges coincide), else on `origin`.
## Returns null when `control` was aborted.
static func build_band(seed_v: int, w: float, spec: Dictionary, origin: Vector2i, has_outer: bool,
		control: BuildControl = null, height_fn: Callable = Callable()) -> ArrayMesh:
	var cell: float = spec["cell"]
	var sea := WorldShape.sea_level()
	var sh := roundi(float(spec["half"]) / cell)
	var hh := roundi(float(spec["hole_half"]) / cell)
	var oc := origin
	if has_outer:
		oc = Vector2i(floori(float(origin.x) / 2.0) * 2, floori(float(origin.y) / 2.0) * 2)
	var side := 2 * sh + 1
	var index := PackedInt32Array()
	index.resize(side * side)
	index.fill(-1)
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var heights := PackedFloat32Array()
	for j in side:
		if control != null and control.aborted:
			return null
		var iz := oc.y - sh + j
		for i in side:
			var ix := oc.x - sh + i
			if absi(ix - origin.x) < hh and absi(iz - origin.y) < hh:
				continue   # strictly inside the hole: the finer band draws it
			var h: float
			var on_edge_x := has_outer and (i == 0 or i == side - 1)
			var on_edge_z := has_outer and (j == 0 or j == side - 1)
			if on_edge_x or on_edge_z:
				h = _coarse_edge_height(seed_v, w, cell, ix, iz, height_fn)
			else:
				h = cell_height(seed_v, w, cell, ix, iz, height_fn)
			index[j * side + i] = vertices.size()
			var x := float(ix) * cell
			var z := float(iz) * cell
			vertices.append(Vector3(x, band_y(h, sea), z))
			colors.append(DistantTerrain.color_for(h - sea, z))
			heights.append(h)
	var indices := PackedInt32Array()
	var acc := PackedVector3Array()
	acc.resize(vertices.size())
	for j in side - 1:
		for i in side - 1:
			var a := index[j * side + i]
			var b := index[j * side + i + 1]
			var c := index[(j + 1) * side + i + 1]
			var d := index[(j + 1) * side + i]
			if a < 0 or b < 0 or c < 0 or d < 0:
				continue   # a corner is inside the hole: the cell is too (the hole is whole cells)
			indices.append_array([a, b, c, a, c, d])
			var f := (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a])
			if f.y < 0.0:
				f = -f
			acc[a] += f
			acc[b] += f
			acc[c] += f
			acc[d] += f
	var normals := PackedVector3Array()
	for v in acc:
		normals.append(v.normalized() if v.length_squared() > 0.0 else Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	if not indices.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## An outer-edge vertex (ix, iz) of a band of `cell`: the NEXT band's height there when it lies on that
## band's lattice (both coordinates even), else the average of the two next-band vertices beside it
## (the edge runs along the coordinate that is even).
static func _coarse_edge_height(seed_v: int, w: float, cell: float, ix: int, iz: int, height_fn: Callable) -> float:
	var cc := cell * 2.0
	var ex := ix % 2 == 0
	var ez := iz % 2 == 0
	if ex and ez:
		return cell_height(seed_v, w, cc, ix / 2, iz / 2, height_fn)
	if ex:   # odd z: between coarse (ix/2, (iz-1)/2) and (ix/2, (iz+1)/2)
		var z0 := floori(float(iz) / 2.0)
		return 0.5 * (cell_height(seed_v, w, cc, ix / 2, z0, height_fn) + cell_height(seed_v, w, cc, ix / 2, z0 + 1, height_fn))
	var x0 := floori(float(ix) / 2.0)
	return 0.5 * (cell_height(seed_v, w, cc, x0, iz / 2, height_fn) + cell_height(seed_v, w, cc, x0 + 1, iz / 2, height_fn))

# ---------------------------------------------------------------- lifecycle

## The band count and the per-band specs, read by the suite.
func band_count() -> int:
	return _bands.size()

func band_spec(k: int) -> Dictionary:
	return _bands[k].spec

func band_builds_started(k: int) -> int:
	return _bands[k].builds_started

func band_builds_completed(k: int) -> int:
	return _bands[k].builds_completed

## The lattice origin band `k` was last asked for (`Vector2i(-999999, -999999)` before any request).
func band_origin(k: int) -> Vector2i:
	return _bands[k].want.get("origin", Vector2i(-999999, -999999))

func band_thread(k: int) -> int:
	return _bands[k].last_thread

## Total vertices of the bands' current plan.
func vertex_total() -> int:
	var t := 0
	for b in _bands:
		t += band_vertex_count(b.spec)
	return t

func shift_scene(shift: Vector3) -> void:
	_origin.value += shift
	for b in _bands:
		if b.mesh_inst != null:
			b.mesh_inst.position += shift

func scene_offset() -> Vector3:
	return _origin.value

## True while any band's build is in flight.
func is_building() -> bool:
	for b in _bands:
		if b.task >= 0:
			return true
	return false

## Request the bands around world XZ `center` for a ring that ends at `ring_radius`. A band is asked for
## again only when the player has moved a whole cell of that band (or the plan, seed or world changed).
## Returns true when any build was started or queued.
func update(center: Vector2, ring_radius: float) -> bool:
	ring_radius_m = ring_radius
	outer_radius_m = outer_radius(circumference_m)
	var specs := plan(ring_radius, outer_radius_m)
	var key := "%d:%s" % [roundi(circumference_m), str(specs)]
	if key != _plan_key:
		_reset_bands(specs)
		_plan_key = key
	var any := false
	WorldShape.warm()   # the fabric snapshot is taken here, never first on a worker
	TerrainSliceScript.warm_polar_caches()
	for b in _bands:
		var o := origin_for(b.spec, center)
		var req := {"origin": o, "seed": world_seed, "circ": circumference_m, "last": b.index == _bands.size() - 1}
		if b.want == req:
			continue
		b.want = req
		b.discarded = {}
		any = true
		if b.task >= 0:
			b.queued = req
		else:
			_start(b, req)
	return any

func _reset_bands(specs: Array) -> void:
	for b in _bands:
		_abort(b)
		if b.mesh_inst != null:
			b.mesh_inst.queue_free()
	_bands.clear()
	for k in specs.size():
		var b := Band.new()
		b.index = k
		b.spec = specs[k]
		_bands.append(b)

func _start(b: Band, req: Dictionary) -> void:
	b.builds_started += 1
	b.control = BuildControl.new()
	b.running = req
	b.task = WorkerThreadPool.add_task(Callable(get_script(), "_build_job").bind(b.spec, req, b.control, circumference_m))

static func _build_job(spec: Dictionary, req: Dictionary, control: BuildControl, w: float) -> void:
	control.thread = OS.get_thread_caller_id()
	control.mesh = build_band(req["seed"], w, spec, req["origin"], not req["last"], control)

## Swap in finished builds (non-blocking; `block` waits for all). Returns true when any mesh was swapped in.
func poll(block: bool = false) -> bool:
	var swapped := false
	for b in _bands:
		while b.task >= 0:
			if not block and not WorkerThreadPool.is_task_completed(b.task):
				break
			WorkerThreadPool.wait_for_task_completion(b.task)
			b.task = -1
			var mesh: ArrayMesh = b.control.mesh if b.control != null else null
			b.last_thread = b.control.thread if b.control != null else -1
			if mesh == null:
				b.queued = {}
				break
			if b.queued.is_empty():
				_swap_in(b, mesh)
				b.builds_completed += 1
				swapped = true
			else:   # superseded while building: build the newest request
				var next := b.queued
				b.queued = {}
				_start(b, next)
	return swapped

func _swap_in(b: Band, mesh: ArrayMesh) -> void:
	if b.mesh_inst != null:
		b.mesh_inst.queue_free()
	b.mesh_inst = MeshInstance3D.new()
	b.mesh_inst.name = "DistantBand%d" % b.index
	b.mesh_inst.mesh = mesh
	b.mesh_inst.material_override = Horizon.curvature_material(circumference_m)
	b.mesh_inst.layers = 1 | BANDS_RENDER_LAYER
	b.mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.mesh_inst.position = _origin.value
	add_child(b.mesh_inst)

func _process(_delta: float) -> void:
	poll()

func _abort(b: Band) -> void:
	if b.task < 0:
		return
	if b.control != null:
		b.control.aborted = true
	WorkerThreadPool.wait_for_task_completion(b.task)
	b.task = -1

## Leaving the tree aborts the in-flight builds; the requests are remembered so a reparent rebuilds them.
func _exit_tree() -> void:
	for b in _bands:
		if b.task >= 0:
			b.discarded = b.queued if not b.queued.is_empty() else b.running
			_abort(b)
			b.queued = {}

func _enter_tree() -> void:
	for b in _bands:
		if not b.discarded.is_empty() and b.task < 0:
			var r := b.discarded
			b.discarded = {}
			_start(b, r)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for b in _bands:
			_abort(b)

## Number of collision bodies under the bands — always 0 (asserted by the suite).
func collision_body_count() -> int:
	return _count_collision(self)

static func _count_collision(n: Node) -> int:
	var c := 1 if n is CollisionObject3D or n is CollisionShape3D else 0
	for ch in n.get_children():
		c += _count_collision(ch)
	return c
