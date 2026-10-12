extends Control
## Waypoints on the horizon of the game view. Each waypoint is drawn where its direction from the
## player meets the horizon, with its name and distance; one behind the camera waits on the left or
## right edge, on the side it is nearer to. The minimap owns the waypoints and the player's place.

const MapMath := preload("res://src/ui/map_math.gd")

## How far out along a waypoint's direction the projected point sits: far enough to read as the horizon.
const HORIZON_M := 5000.0
## Markers stay this far inside the screen edge.
const EDGE_PX := 18.0
const FILL := Color(0.4, 0.9, 1.0)
const TEXT := Color(0.8, 0.97, 1.0)

var minimap: Node = null

func _init() -> void:
	name = "WaypointHorizon"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()   # the camera moves every frame; a handful of waypoints is cheap

## Where a waypoint `d` metres away (x east, y world +z) sits for `cam` on a view of `view` px:
## { pos, behind }, or {} when it is right underfoot. In front, the projection of a point on the
## horizon toward it (kept on screen); behind, the left or right edge at mid-height.
static func place(cam: Camera3D, d: Vector2, view: Vector2) -> Dictionary:
	var flat := Vector3(d.x, 0.0, d.y)
	if flat.length_squared() < 0.0001:
		return {}
	var target := cam.global_position + flat.normalized() * HORIZON_M
	var lo := Vector2(EDGE_PX, EDGE_PX)
	var hi := view - lo
	if cam.is_position_behind(target):
		var right := cam.global_transform.basis.x
		var x := hi.x if flat.dot(right) >= 0.0 else lo.x
		return { "pos": Vector2(x, view.y * 0.5), "behind": true }
	return { "pos": cam.unproject_position(target).clamp(lo, hi), "behind": false }

func _draw() -> void:
	if minimap == null or not minimap.has_method("get_waypoints"):
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var font := ThemeDB.fallback_font
	var view := size
	var wps: Array = minimap.get_waypoints()
	for i in wps.size():
		var d: Vector2 = minimap.waypoint_offset_m(i)
		if d.x >= INF:
			continue
		var m := place(cam, d, view)
		if m.is_empty():
			continue
		var p: Vector2 = m["pos"]
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -7), p + Vector2(6, 0), p + Vector2(0, 7), p + Vector2(-6, 0)]), FILL)
		var label := "%s %s" % [str(wps[i]["name"]), MapMath.distance_text(d.length())]
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var at := Vector2(clampf(p.x - w * 0.5, 2.0, view.x - w - 2.0), p.y - 11.0)
		draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0, 0, 0, 0.85))
		draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT)
