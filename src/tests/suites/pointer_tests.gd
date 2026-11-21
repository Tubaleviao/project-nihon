extends "res://src/tests/test_support.gd"
## Phase 291 — the pointer goes back where it was after a right-click look: a viewport position is converted to
## window pixels through the final transform (stretch scale 1.0, 1.5, 2.0), ten looks do not drift, and nothing but
## the helper calls `warp_mouse`.

const Pointer := preload("res://src/player/pointer.gd")
const BASE := Vector2(1280, 720)

func register() -> void:
	_run_test("pointer: a look restores the pointer to within 1 px at stretch scales 1.0, 1.5 and 2.0", _test_restore)
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
