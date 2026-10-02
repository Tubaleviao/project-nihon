extends RefCounted
## Shared mesh-authoring helpers for the code-built geometry in this project.
##
## Two slices author raw `SurfaceTool` geometry (VoxelSlice's terrain shell and
## its rare-vein deposits, TreeSlice's trunk + canopy), and a box is the shape
## both need. Keeping the winding in ONE place avoids the classic manual-mesh
## bug where one caller winds a face backwards and the mesh renders see-through
## under backface culling.

## Vertices one `add_box` call appends: six faces × six vertices (two triangles
## per face). Callers that assert on a mesh's vertex count use this instead of a
## magic 36.
const BOX_VERTEX_COUNT := 36

## Append an axis-aligned box (six faces, outward normals, flat `color`, no UV
## detail) to an in-progress SurfaceTool. `center` is the box's centre in the
## caller's coordinate space.
##
## Winding: each face's vertices are counter-clockwise seen from OUTSIDE, so the
## face normal follows from (b - a) × (c - a) and a backface-culling material
## renders every face. Verified per face against the right-hand rule.
static func add_box(st: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
	var p := _box_corners(center, size)
	for f in _box_faces(p):
		_add_face(st, f[0], f[1], f[2], f[3], f[4], color)

## The same box, appended to raw mesh ARRAYS instead of a `SurfaceTool` — for geometry
## authored off the main thread and for a build that returns arrays rather than nodes.
##
## Phase 42 review pass 8 — VoxelSlice's rare-vein deposits moved onto the worker, and the
## pure builder returns plain arrays, so it needs this shape. It shares `_box_corners` and
## `_box_faces` with `add_box` precisely so a face cannot be wound one way here and the
## other way there, which is the bug this file exists to prevent.
static func add_box_arrays(vertices: PackedVector3Array, normals: PackedVector3Array,
		colors: PackedColorArray, indices: PackedInt32Array,
		center: Vector3, size: Vector3, color: Color) -> void:
	var p := _box_corners(center, size)
	for f in _box_faces(p):
		_tri_arrays(vertices, normals, colors, indices, f[0], f[1], f[2], f[4], color)
		_tri_arrays(vertices, normals, colors, indices, f[0], f[2], f[3], f[4], color)

## Append one triangle (flat normal, flat colour) to raw mesh arrays. Three vertices, not
## an index pair, so a box built this way carries exactly the `BOX_VERTEX_COUNT` vertices
## `add_box` emits — a caller can count the two forms the same way.
static func _tri_arrays(vertices: PackedVector3Array, normals: PackedVector3Array,
		colors: PackedColorArray, indices: PackedInt32Array,
		a: Vector3, b: Vector3, c: Vector3, normal: Vector3, color: Color) -> void:
	var base := vertices.size()
	vertices.append(a); vertices.append(b); vertices.append(c)
	normals.append(normal); normals.append(normal); normals.append(normal)
	colors.append(color); colors.append(color); colors.append(color)
	indices.append(base); indices.append(base + 1); indices.append(base + 2)

## The eight corners of an axis-aligned box, in the order `_box_faces` indexes them.
## The ONE place the corner order lives.
static func _box_corners(center: Vector3, size: Vector3) -> Array:
	var h := size * 0.5
	return [
		center + Vector3(-h.x, -h.y, -h.z),   # 0
		center + Vector3( h.x, -h.y, -h.z),   # 1
		center + Vector3( h.x, -h.y,  h.z),   # 2
		center + Vector3(-h.x, -h.y,  h.z),   # 3
		center + Vector3(-h.x,  h.y, -h.z),   # 4
		center + Vector3( h.x,  h.y, -h.z),   # 5
		center + Vector3( h.x,  h.y,  h.z),   # 6
		center + Vector3(-h.x,  h.y,  h.z),   # 7
	]

## The six faces of that box as `[a, b, c, d, normal]`, each quad counter-clockwise seen
## from OUTSIDE, so the face normal follows from (b - a) × (c - a). Verified per face
## against the right-hand rule.
static func _box_faces(p: Array) -> Array:
	return [
		[p[4], p[7], p[6], p[5], Vector3.UP],          # +Y
		[p[0], p[1], p[2], p[3], Vector3.DOWN],        # -Y
		[p[3], p[2], p[6], p[7], Vector3(0, 0, 1)],    # +Z
		[p[0], p[4], p[5], p[1], Vector3(0, 0, -1)],   # -Z
		[p[1], p[5], p[6], p[2], Vector3(1, 0, 0)],    # +X
		[p[0], p[3], p[7], p[4], Vector3(-1, 0, 0)],   # -X
	]

## Append one quad (two triangles) with an explicit normal and colour. a, b, c, d
## are counter-clockwise seen from the normal's side.
static func _add_face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color) -> void:
	st.set_normal(normal)
	st.set_color(color)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)
