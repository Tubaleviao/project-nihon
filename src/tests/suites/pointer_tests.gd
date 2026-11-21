extends "res://src/tests/test_support.gd"
## Phase 291 — the pointer goes back where it was after a right-click look: a viewport position is converted to
## window pixels through the final transform (stretch scale 1.0, 1.5, 2.0), ten looks do not drift, and nothing but
## the helper calls `warp_mouse`.

const Pointer := preload("res://src/player/pointer.gd")
const BASE := Vector2(1280, 720)

func register() -> void:
	_run_test("pointer: a look restores the pointer to within 1 px at stretch scales 1.0, 1.5 and 2.0", _test_restore)
	_run_test("pointer: _begin_look then _end_look warps back to the pointer's window pixel", _test_live_look)
	_run_test("pointer: a right click with no motion leaves the pointer where it was", _test_click_no_motion)
	_run_test("pointer: ten looks in a row leave the pointer where it started", _test_no_drift)
	_run_test("pointer: no warp_mouse call outside the helper", _test_only_helper_warps)

## What the viewport reports for a pointer at window pixel `w` (the inverse of the final transform), then what
## the helper warps to when the look ends.
func _round_trip(scale: float, w: Vector2) -> Vector2:
	var final := Transform2D().scaled(Vector2(scale, scale))
	var stored := final.affine_inverse() * w   # `_begin_look`: get_mouse_position()
	return Pointer.window_position(final, stored)   # `_end_look`: the window pixel warped to

func _test_restore() -> void:
	for scale: float in [1.0, 1.5, 2.0]:
		var win: Vector2 = BASE * scale
		for w: Vector2 in [Vector2(100, 100) * scale, win * 0.5, win - Vector2(1, 1)]:
			var back := _round_trip(scale, w)
			assert_true(back.distance_to(w) <= 1.0, "scale %s: %s comes back as %s" % [scale, w, back])

## Through the real `_begin_look`/`_end_look` in a viewport stretched by `scale` (size_2d_override), capturing the warp.
func _live_look(scale: float, vp_pos: Vector2) -> Vector2:
	var sub := SubViewport.new()
	sub.size = Vector2i(BASE * scale)
	sub.size_2d_override = Vector2i(BASE)
	sub.size_2d_override_stretch = true
	var p := PlayerSlice.new()
	p._camera = Camera3D.new()
	p.look_pointer.viewport_override = sub
	var got := [Vector2(-1, -1)]
	p.look_pointer.warp_sink = func(w: Vector2) -> void: got[0] = w
	p._begin_look()
	p.look_pointer.restore_pos = vp_pos   # an unparented SubViewport cannot be given a pointer position
	p._end_look()
	var expect: Vector2 = sub.get_final_transform() * vp_pos
	sub.free()
	p._camera.free()
	p.free()
	return got[0] - expect

func _test_live_look() -> void:
	for scale: float in [1.0, 1.5, 2.0]:
		for vp in [Vector2(100, 100), BASE * 0.5, BASE - Vector2(1, 1)]:
			var d := _live_look(scale, vp)
			assert_true(d.length() <= 1.0, "scale %s: look at %s warps %s off" % [scale, vp, d])

## Phase 291 bullet: a right click that never becomes a look (pressed and released, no motion) warps to the very
## pixel the pointer was on, and only once.
func _test_click_no_motion() -> void:
	var sub := SubViewport.new()
	sub.size = Vector2i(BASE * 1.5)
	sub.size_2d_override = Vector2i(BASE)
	sub.size_2d_override_stretch = true
	var p := PlayerSlice.new()
	p._camera = Camera3D.new()
	p.look_pointer.viewport_override = sub
	var got: Array = []
	p.look_pointer.warp_sink = func(w: Vector2) -> void: got.append(w)
	p._begin_look()
	var at: Vector2 = sub.get_final_transform() * p.look_pointer.restore_pos   # where the pointer is in window pixels
	p._end_look()
	p._end_look()   # a second release is a no-op
	assert_eq(got.size(), 1, "one warp for one click")
	if got.size() == 1:
		assert_true((got[0] as Vector2).distance_to(at) <= 1.0, "click without motion: pointer stays at %s, warped to %s" % [at, got[0]])
	sub.free()
	p._camera.free()
	p.free()

func _test_no_drift() -> void:
	for scale: float in [1.0, 1.5, 2.0]:
		var w: Vector2 = Vector2(640, 360) * scale
		for i in 10:
			w = _round_trip(scale, w)
		assert_true(w.distance_to(Vector2(640, 360) * scale) <= 1.0, "scale %s: no drift over ten looks (%s)" % [scale, w])

func _test_only_helper_warps() -> void:
	var offenders := []
	var dirs := ["res://src"]
	while not dirs.is_empty():
		var d: String = dirs.pop_back()
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".gd") and not d.begins_with("res://src/tests"):
				var path := d + "/" + f
				if path != "res://src/player/pointer.gd" and FileAccess.get_file_as_string(path).contains("warp_mouse("):
					offenders.append(path)
		for sub in DirAccess.get_directories_at(d):
			dirs.append(d + "/" + sub)
	assert_eq(offenders, [], "warp_mouse is called only by the pointer helper")
