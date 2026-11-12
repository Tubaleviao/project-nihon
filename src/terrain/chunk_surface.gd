extends Node3D
const TerrainWeights := preload("res://src/terrain/terrain_weights.gd")
## Phase 239 — one chunk's ground surface, drawn through the RenderingServer instead of a
## `MeshInstance3D`. The mesh is a server resource (`mesh_add_surface_from_arrays`) and the instance
## is placed in the node's world and follows its transform, so a streamed chunk costs two server
## calls and one light node rather than a scene-tree `MeshInstance3D` with its notifications. The
## node frees both RIDs when it leaves the game (`NOTIFICATION_PREDELETE`).

var _mesh: RID = RID()
var _instance: RID = RID()
var _vertex_count := 0

## Build the surface from a build's arrays and `material`. Returns false (and holds nothing) for empty arrays.
func setup(arrays: Dictionary, material: Material) -> bool:
	var verts: PackedVector3Array = arrays.get("vertices", PackedVector3Array())
	if verts.is_empty():
		return false
	var surface: Array = []
	surface.resize(Mesh.ARRAY_MAX)
	surface[Mesh.ARRAY_VERTEX] = verts
	surface[Mesh.ARRAY_NORMAL] = arrays["normals"]
	surface[Mesh.ARRAY_COLOR] = arrays["colors"]
	surface[Mesh.ARRAY_INDEX] = arrays["indices"]
	var flags := TerrainWeights.fill_surface(surface, arrays)   # Phase 242: the material weights, when built
	_mesh = RenderingServer.mesh_create()
	RenderingServer.mesh_add_surface_from_arrays(_mesh, RenderingServer.PRIMITIVE_TRIANGLES, surface, [], {}, flags)
	if material != null:
		RenderingServer.mesh_surface_set_material(_mesh, 0, material.get_rid())
	_instance = RenderingServer.instance_create()
	RenderingServer.instance_set_base(_instance, _mesh)
	_vertex_count = verts.size()
	set_notify_transform(true)
	if is_inside_tree():
		_enter()
	return true

## Phase 243 — the dithered level-change fade (the terrain shader's `lod_fade` instance uniform):
## 0..1 fading in, 2..3 fading out, 1 drawn whole. Only the high terrain shader declares it, so the
## caller sets it only on that path (`LodFade.enabled`).
func set_fade(f: float) -> void:
	if _instance.is_valid():
		RenderingServer.instance_geometry_set_shader_parameter(_instance, "lod_fade", f)

## Phase 243 — the render layers the surface is drawn on (an LOD ring's join the distant ring's layer).
func set_layers(mask: int) -> void:
	if _instance.is_valid():
		RenderingServer.instance_set_layer_mask(_instance, mask)

func has_surface() -> bool:
	return _instance.is_valid()

func vertex_count() -> int:
	return _vertex_count

func _enter() -> void:
	if _instance.is_valid():
		RenderingServer.instance_set_scenario(_instance, get_world_3d().scenario)
		RenderingServer.instance_set_transform(_instance, global_transform)
		RenderingServer.instance_set_visible(_instance, is_visible_in_tree())

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE:
			_enter()
		NOTIFICATION_EXIT_TREE:
			if _instance.is_valid():
				RenderingServer.instance_set_scenario(_instance, RID())
		NOTIFICATION_TRANSFORM_CHANGED:
			if _instance.is_valid() and is_inside_tree():
				RenderingServer.instance_set_transform(_instance, global_transform)
		NOTIFICATION_VISIBILITY_CHANGED:
			if _instance.is_valid() and is_inside_tree():
				RenderingServer.instance_set_visible(_instance, is_visible_in_tree())
		NOTIFICATION_PREDELETE:
			if _instance.is_valid():
				RenderingServer.free_rid(_instance)
			if _mesh.is_valid():
				RenderingServer.free_rid(_mesh)
			# Phase 243: a node freed while in the tree gets EXIT_TREE after this; it must not touch freed RIDs.
			_instance = RID()
			_mesh = RID()
