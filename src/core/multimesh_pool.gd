extends Node
## MultimeshPool — renders many instances of one shared mesh with a single
## draw call (one MultiMeshInstance3D). Callers allocate an instance index,
## then set that instance's transform and colour as it changes. A zero-scale
## transform hides an instance (death / unload), mirroring the old per-node
## `visible = false`.
##
## This is the seam for the headless server (Phase 27): a headless process
## constructs NO pool, so the same entity data model drives both a rendered
## client and a bare simulation with zero visual nodes.

const GROW_STEP := 256

var _multimesh_instance: MultiMeshInstance3D
var _multimesh: MultiMesh
var _use_color: bool = false
var _free: Array[int] = []
var _next: int = 0

## Build the MultiMesh from a shared mesh. `use_color` enables per-instance
## colour (INSTANCE COLOR → vertex color, albedo via `vertex_color_use_as_albedo`).
func setup(mesh: Mesh, use_color: bool = true) -> void:
	_use_color = use_color
	_multimesh_instance = MultiMeshInstance3D.new()
	_multimesh_instance.name = "MultimeshPool"
	_multimesh = MultiMesh.new()
	_multimesh.mesh = mesh
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = use_color
	_multimesh.instance_count = 0
	_multimesh_instance.multimesh = _multimesh

	if use_color:
		# One shared material: the instance colour drives the albedo.
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.albedo_color = Color.WHITE
		_multimesh_instance.material_override = mat

	add_child(_multimesh_instance)

## Allocate a free instance index, growing the MultiMesh when exhausted.
func alloc() -> int:
	if not _free.is_empty():
		return _free.pop_back()
	if _next >= _multimesh.instance_count:
		_grow()
	var idx := _next
	_next += 1
	return idx

## Release an index back to the free list (hidden until reallocated).
func release(idx: int) -> void:
	hide(idx)
	_free.append(idx)

func set_transform(idx: int, t: Transform3D) -> void:
	_multimesh.set_instance_transform(idx, t)

func set_color(idx: int, c: Color) -> void:
	if _use_color:
		_multimesh.set_instance_color(idx, c)

## Hide an instance with a zero-scale transform (degenerate geometry is skipped
## by the renderer, so it draws nothing).
func hide(idx: int) -> void:
	_multimesh.set_instance_transform(idx, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))

func instance_count() -> int:
	return _multimesh.instance_count

func _grow() -> void:
	var old := _multimesh.instance_count
	var new_count := old + GROW_STEP
	_multimesh.instance_count = new_count
	# New instances default to the identity transform (visible at origin) — hide
	# them so an unset instance never flashes at the world origin before its
	# caller assigns a real transform.
	for i in range(old, new_count):
		hide(i)
