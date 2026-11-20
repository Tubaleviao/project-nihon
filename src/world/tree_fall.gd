extends RefCounted
## Phase 282 — a felled tree's presentation: it topples about its base away from the feller, bounces, sinks and
## fades, and is freed; a regrown tree grows from a sapling. Client-side only, owned by `TreeSlice`: the host's
## state is "felled at time t". Driven by `step(delta)`, which tests call with explicit time steps.

const FALL_SECONDS := 2.5
const SINK_SECONDS := 1.5
const BOUNCE_SECONDS := 0.3
const BOUNCE_DEGREES := 5.0
const SAPLING_SCALE := 0.12
const GROW_SECONDS := 30.0

var _s: Node
## tree_id -> { node, t, yaw } for the trees mid-fall; tree_id -> seconds grown for the saplings.
var _falls: Dictionary = {}
var _growing: Dictionary = {}

func _init(slice: Node) -> void:
	_s = slice

## The direction a tree felled by `player_id` falls, as a yaw (radians; the fall vector is `(sin yaw, 0, cos yaw)`):
## straight away from the feller. A feller of unknown position gets a yaw from the tree id (still the host's call).
func yaw_for(tree_id: String, tree_pos: Vector3, player_id: String) -> float:
	if _s.feller_pos.is_valid():
		var at: Variant = _s.feller_pos.call(player_id)
		if at is Vector3:
			# Both are in the unshifted frame (a tree's `position` and `ChestWiring.player_pos`), so no origin shift.
			var away: Vector3 = tree_pos - (at as Vector3)
			away.y = 0.0
			if away.length_squared() > 0.0001:
				return atan2(away.x, away.z)
	return float(hash(tree_id) % 6283) / 1000.0 - PI

## The instance transform of a tree that is growing back: a sapling scaled up to full size.
func growth_transform(tree_id: String, pos: Vector3) -> Transform3D:
	if not _growing.has(tree_id):
		return _s._visual_transform(pos)
	var k := clampf(float(_growing[tree_id]) / GROW_SECONDS, 0.0, 1.0)
	return Transform3D(Basis().scaled(Vector3.ONE * lerpf(SAPLING_SCALE, 1.0, k)), pos)

## Seconds a regrown tree has been growing, or -1.0 once it is full size.
func growth_seconds(tree_id: String) -> float:
	return float(_growing.get(tree_id, -1.0))

func forget_growth(tree_id: String) -> void:
	_growing.erase(tree_id)

func begin_growth(tree_id: String) -> void:
	var tree: Dictionary = _s._trees.get(tree_id, {})
	if tree.is_empty():
		return
	_growing[tree_id] = 0.0
	var pool: Node = _s._tree_pool(tree)
	if pool != null and int(tree["mi"]) >= 0:
		pool.set_color(int(tree["mi"]), _s._tree_color(tree))
		pool.set_transform(int(tree["mi"]), growth_transform(tree_id, tree["position"]))

## Advance toppling trees and growing saplings by `delta` seconds.
func step(delta: float) -> void:
	for tid in _falls.keys():
		_step_fall(str(tid), delta)
	for tid in _growing.keys():
		var t: float = float(_growing[tid]) + delta
		var tree: Dictionary = _s._trees.get(tid, {})
		if tree.is_empty():
			_growing.erase(tid)
			continue
		if t >= GROW_SECONDS:
			_growing.erase(tid)
		else:
			_growing[tid] = t
		var pool: Node = _s._tree_pool(tree)
		if pool != null and int(tree["mi"]) >= 0:
			pool.set_transform(int(tree["mi"]), growth_transform(str(tid), tree["position"]))

## The node of a tree mid-fall, or null.
func fall_node(tree_id: String) -> Node3D:
	if not _falls.has(tree_id):
		return null
	return _falls[tree_id]["node"]

func begin_fall(tree_id: String, yaw: float) -> void:
	var tree: Dictionary = _s._trees.get(tree_id, {})
	if tree.is_empty() or not _s.render_visuals or _falls.has(tree_id):
		return
	var node := Node3D.new()
	node.name = "FallingTree"
	var pool: Node = _s._tree_pool(tree)
	if pool != null and pool.has_method("mesh") and pool.mesh() != null:
		var mi := MeshInstance3D.new()
		mi.mesh = pool.mesh()
		# A private copy: the fallback mesh is tinted per instance in the pool, and the fade needs alpha.
		var mat: Material = pool.material()
		if mat is StandardMaterial3D:
			var own := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
			own.albedo_color = _s._tree_color(tree)
			own.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat = own
		mi.material_override = mat
		node.add_child(mi)
	node.position = (tree["position"] as Vector3) + _s._origin.value
	_s.add_child(node)
	_s._world_nodes.append(node)
	_falls[tree_id] = { "node": node, "t": 0.0, "yaw": yaw }

func end_fall(tree_id: String) -> void:
	if not _falls.has(tree_id):
		return
	var node: Node3D = _falls[tree_id]["node"]
	_falls.erase(tree_id)
	_s._world_nodes.erase(node)
	if is_instance_valid(node):
		node.free()

## Put every falling node back on its tree after a scene rebase.
func replace_nodes() -> void:
	for tid in _falls:
		var fnode: Node3D = _falls[tid]["node"]
		if is_instance_valid(fnode) and _s._trees.has(tid):
			fnode.position = (_s._trees[tid]["position"] as Vector3) + _s._origin.value

## The tilt (radians from upright) of a tree `t` seconds into its fall: an ease-in to 90 degrees at
## FALL_SECONDS, then a short bounce.
static func fall_angle(t: float) -> float:
	if t < FALL_SECONDS:
		var k := t / FALL_SECONDS
		return deg_to_rad(90.0) * k * k
	var b := (t - FALL_SECONDS) / BOUNCE_SECONDS
	if b < 1.0:
		return deg_to_rad(90.0 - BOUNCE_DEGREES * sin(PI * b))
	return deg_to_rad(90.0)

func _step_fall(tree_id: String, delta: float) -> void:
	var f: Dictionary = _falls[tree_id]
	var t: float = float(f["t"]) + delta
	f["t"] = t
	if t >= FALL_SECONDS + SINK_SECONDS:
		end_fall(tree_id)
		return
	var node: Node3D = f["node"]
	if not is_instance_valid(node):
		_falls.erase(tree_id)
		return
	var yaw: float = f["yaw"]
	var dir := Vector3(sin(yaw), 0.0, cos(yaw))
	node.basis = Basis(Vector3.UP.cross(dir).normalized(), fall_angle(t))
	var sink := clampf((t - FALL_SECONDS) / SINK_SECONDS, 0.0, 1.0)
	var base: Vector3 = node.position
	if _s._trees.has(tree_id):
		base = (_s._trees[tree_id]["position"] as Vector3) + _s._origin.value
	node.position = Vector3(base.x, base.y - sink * sink * 1.2, base.z)
	for child in node.get_children():
		if child is GeometryInstance3D:
			var m: Material = (child as GeometryInstance3D).material_override
			if m is StandardMaterial3D:
				var c := (m as StandardMaterial3D).albedo_color
				c.a = 1.0 - sink
				(m as StandardMaterial3D).albedo_color = c
