extends Control
## Phase 270 — a pannable, zoomable canvas: the technology tree draws on it, and Phase 271's skill wheel
## reuses it. Children go under `content`, laid out in content coordinates; the canvas shows them scaled
## by `zoom` with the content origin at `offset` (in canvas pixels).
##
## Mouse wheel and pinch (magnify gesture) zoom around the cursor, clamped to [min_zoom, max_zoom];
## dragging the background with the left, middle or right button pans, as does a two-finger pan gesture.
## `fit(rect)` shows a whole content rectangle, `center_on(point)` brings a content point to the middle.
## The math is static (`zoom_about`, `clamp_zoom`) so tests can check it without input events.

signal view_changed

const WHEEL_STEP := 1.15
const PAN_GESTURE_SPEED := 24.0

var min_zoom := 0.3
var max_zoom := 2.5
var zoom := 1.0
var offset := Vector2.ZERO
## Holds the drawn children; `content.draw` can be connected to draw lines under them.
var content: Control = null
var _dragging := false

func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_CLICK
	content = Control.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(content)
	_apply()

static func clamp_zoom(z: float, lo: float, hi: float) -> float:
	return clampf(z, lo, hi)

## The new offset that keeps the content point under `pivot` (canvas pixels) fixed while the zoom
## changes from `old_zoom` to `new_zoom`.
static func zoom_about(old_offset: Vector2, old_zoom: float, new_zoom: float, pivot: Vector2) -> Vector2:
	var point := (pivot - old_offset) / old_zoom
	return pivot - point * new_zoom

## Canvas pixels -> content coordinates.
func to_content(canvas_point: Vector2) -> Vector2:
	return (canvas_point - offset) / zoom

## Content coordinates -> canvas pixels.
func to_canvas(content_point: Vector2) -> Vector2:
	return content_point * zoom + offset

## Multiply the zoom by `factor` (clamped) around `pivot` in canvas pixels.
func zoom_at(factor: float, pivot: Vector2) -> void:
	var nz := clamp_zoom(zoom * factor, min_zoom, max_zoom)
	offset = zoom_about(offset, zoom, nz, pivot)
	zoom = nz
	_apply()

func pan(delta: Vector2) -> void:
	offset += delta
	_apply()

## The canvas size, or its minimum before the first layout pass gives it one.
func view_size() -> Vector2:
	return size if size.x > 1.0 and size.y > 1.0 else custom_minimum_size

## Show the whole of `rect` (content coordinates) with `margin` pixels around it.
func fit(rect: Rect2, margin: float = 16.0) -> void:
	var view := view_size()
	var w := maxf(rect.size.x, 1.0)
	var h := maxf(rect.size.y, 1.0)
	zoom = clamp_zoom(minf((view.x - 2.0 * margin) / w, (view.y - 2.0 * margin) / h), min_zoom, max_zoom)
	offset = view / 2.0 - rect.get_center() * zoom
	_apply()

## Bring a content point to the middle of the canvas at the current zoom.
func center_on(point: Vector2) -> void:
	offset = view_size() / 2.0 - point * zoom
	_apply()

func _apply() -> void:
	if content == null:
		return
	content.position = offset
	content.scale = Vector2(zoom, zoom)
	view_changed.emit()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					zoom_at(WHEEL_STEP, mb.position)
				accept_event()
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					zoom_at(1.0 / WHEEL_STEP, mb.position)
				accept_event()
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT:
				_dragging = mb.pressed
				accept_event()
	elif event is InputEventMouseMotion and _dragging:
		pan((event as InputEventMouseMotion).relative)
		accept_event()
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		zoom_at(mg.factor, mg.position)
		accept_event()
	elif event is InputEventPanGesture:
		pan(-(event as InputEventPanGesture).delta * PAN_GESTURE_SPEED)
		accept_event()
