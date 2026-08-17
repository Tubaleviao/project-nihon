extends Control
## MouseIcon — draws a top-down mouse with one button highlighted.
## Replaces bare "LMB / RMB / MMB" text in the HUD with a visual cue.
##
## `button` holds a Godot MouseButton value: MOUSE_BUTTON_LEFT, RIGHT, MIDDLE,
## or NONE (no highlight). The icon is drawn entirely in code so it works
## headlessly and needs no texture.

@export var button: int = MOUSE_BUTTON_NONE
@export var body_color: Color = Color(0.85, 0.85, 0.85, 0.8)
@export var highlight_color: Color = Color(1.0, 0.82, 0.25, 0.95)
@export var outline_color: Color = Color(0.12, 0.12, 0.12, 0.9)

func _draw() -> void:
	var s := size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	var radius := int(minf(s.x, s.y) * 0.28)

	# Body silhouette (rounded, semi-transparent).
	_draw_rounded(Rect2(Vector2.ZERO, s), body_color, radius)

	# Button plate: upper 58% of the mouse, split into left / right halves.
	var plate_h := s.y * 0.58
	var left := Rect2(0.0, 0.0, s.x * 0.5, plate_h)
	var right := Rect2(s.x * 0.5, 0.0, s.x * 0.5, plate_h)
	var wheel := Rect2(s.x * 0.35, s.y * 0.04, s.x * 0.3, s.y * 0.2)

	# Highlight the active button (drawn under the divider + wheel).
	match button:
		MOUSE_BUTTON_LEFT:
			draw_rect(left.grow(-1.0), highlight_color, true)
		MOUSE_BUTTON_RIGHT:
			draw_rect(right.grow(-1.0), highlight_color, true)
		MOUSE_BUTTON_MIDDLE:
			draw_rect(wheel.grow(-1.0), highlight_color, true)

	# Divider between the left and right buttons.
	draw_line(Vector2(s.x * 0.5, 1.0), Vector2(s.x * 0.5, plate_h - 1.0), outline_color, 2.0)

	# Scroll wheel (always on top of the plate).
	var wheel_radius := maxi(int(radius * 0.5), 1)
	_draw_rounded(wheel, Color(0.5, 0.5, 0.5, 0.95), wheel_radius)
	_draw_outline(wheel, wheel_radius)

	# Outer outline last so it clips the highlight to the rounded silhouette.
	_draw_outline(Rect2(Vector2.ZERO, s), radius)


func _draw_rounded(rect: Rect2, color: Color, radius: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	draw_style_box(sb, rect)


func _draw_outline(rect: Rect2, radius: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = outline_color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	draw_style_box(sb, rect)
