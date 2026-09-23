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
	var h := size * 0.5
	var p: Array[Vector3] = [
		center + Vector3(-h.x, -h.y, -h.z),   # 0
		center + Vector3( h.x, -h.y, -h.z),   # 1
		center + Vector3( h.x, -h.y,  h.z),   # 2
		center + Vector3(-h.x, -h.y,  h.z),   # 3
		center + Vector3(-h.x,  h.y, -h.z),   # 4
		center + Vector3( h.x,  h.y, -h.z),   # 5
		center + Vector3( h.x,  h.y,  h.z),   # 6
		center + Vector3(-h.x,  h.y,  h.z),   # 7
	]
	_add_face(st, p[4], p[7], p[6], p[5], Vector3.UP, color)          # +Y
	_add_face(st, p[0], p[1], p[2], p[3], Vector3.DOWN, color)        # -Y
	_add_face(st, p[3], p[2], p[6], p[7], Vector3(0, 0, 1), color)    # +Z
	_add_face(st, p[0], p[4], p[5], p[1], Vector3(0, 0, -1), color)   # -Z
	_add_face(st, p[1], p[5], p[6], p[2], Vector3(1, 0, 0), color)    # +X
	_add_face(st, p[0], p[3], p[7], p[4], Vector3(-1, 0, 0), color)   # -X

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
