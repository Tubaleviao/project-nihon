extends "res://src/tests/test_support.gd"
## Phase 237 — flight that handles like flight: `FlightRules.step` and the flying move's shape.

const FlightRules := preload("res://src/player/flight_rules.gd")
const TOP := 90.0
const DT := 1.0 / 60.0


func register() -> void:
	_run_test("flight: W from rest reaches 95% of top speed in 0.5 to 0.8 s", _test_accelerates)
	_run_test("flight: with no input the speed falls below 5% in 0.8 to 1.5 s", _test_drag)
	_run_test("flight: W with the camera pitched 30 degrees up climbs at sin 30 of the speed", _test_pitch)
	_run_test("flight: opposite input reverses smoothly, never in one step", _test_reverse)
	_run_test("flight: strafe and Space/Ctrl add across and up/down", _test_strafe_vertical)
	_run_test("flight: a wall and a hillside kill only the velocity into the surface", _test_slide)
	_run_test("flight: the flying move skips the step-up probe, the dive guard and the buried lift", _test_flying_move_source)
	_run_test("flight: the camera lag and FOV widening are bounded and ease", _test_camera)


func _p() -> Dictionary:
	return FlightRules.params(TOP, 12.0)

func _pitched(deg: float) -> Basis:
	return Basis(Vector3.RIGHT, deg_to_rad(deg))   # positive x rotation tilts forward (-Z) upward

func _test_accelerates() -> void:
	var v := Vector3.ZERO
	var t := 0.0
	while v.length() < 0.95 * TOP and t < 3.0:
		v = FlightRules.step(v, Vector3(0, 0, -1), Basis.IDENTITY, DT, _p())
		t += DT
	assert_true(t >= 0.5 and t <= 0.8, "95%% of top speed after %.2f s" % t)
	assert_true(v.length() <= TOP + 0.001, "and never above top speed")

func _test_drag() -> void:
	var v := Vector3(0, 0, -TOP)
	var t := 0.0
	while v.length() >= 0.05 * TOP and t < 5.0:
		v = FlightRules.step(v, Vector3.ZERO, Basis.IDENTITY, DT, _p())
		t += DT
	assert_true(t >= 0.8 and t <= 1.5, "below 5%% of top speed after %.2f s" % t)

func _test_pitch() -> void:
	var look := _pitched(30.0)
	assert_true((-look.z).y > 0.0, "the pitched look points up")
	var v := Vector3.ZERO
	for i in 600:
		v = FlightRules.step(v, Vector3(0, 0, -1), look, DT, _p())
	assert_true(absf(v.y / TOP - sin(deg_to_rad(30.0))) <= 0.05 * sin(deg_to_rad(30.0)), "climb is sin 30 of the speed: %.3f" % (v.y / TOP))
	assert_true(absf(v.length() - TOP) < 0.5, "at the full speed")
	var down := Vector3.ZERO
	for i in 600:
		down = FlightRules.step(down, Vector3(0, 0, -1), _pitched(-30.0), DT, _p())
	assert_true(down.y < 0.0, "looking down dives")

func _test_reverse() -> void:
	var v := Vector3(0, 0, -TOP)
	var prev := v
	var crossed := false
	for i in 120:
		v = FlightRules.step(v, Vector3(0, 0, 1), Basis.IDENTITY, DT, _p())
		assert_true((v - prev).length() < TOP * 0.5, "no single step flips the velocity")
		if v.z > 0.0:
			crossed = true
		prev = v
	assert_true(crossed, "it does reverse in the end")
	var one := FlightRules.step(Vector3(0, 0, -TOP), Vector3(0, 0, 1), Basis.IDENTITY, DT, _p())
	assert_true(one.z < 0.0, "the first step of the reversal is still going forward")

func _test_strafe_vertical() -> void:
	var v := Vector3.ZERO
	for i in 300:
		v = FlightRules.step(v, Vector3(1, 1, 0), Basis.IDENTITY, DT, _p())
	assert_true(v.x > TOP * 0.95 and absf(v.z) < 0.001, "D strafes right")
	assert_true(absf(v.y - 12.0) < 0.1, "Space climbs at the vertical speed")
	v = FlightRules.step(Vector3.ZERO, Vector3(1, 0, -1), Basis.IDENTITY, 100.0, _p())
	assert_true(absf(v.length() - TOP) < 0.01, "a diagonal is not faster than straight")

func _test_slide() -> void:
	var wall := FlightRules.slide(Vector3(40, 0, 0), Vector3(-1, 0, 0))
	assert_eq(wall, Vector3.ZERO, "head-on into a wall: stopped, nothing lifted")
	var glance := FlightRules.slide(Vector3(40, 0, 30), Vector3(-1, 0, 0))
	assert_eq(glance, Vector3(0, 0, 30), "a glancing hit keeps the part along the wall")
	var hill_n := Vector3(-1, 1, 0).normalized()
	var hill := FlightRules.slide(Vector3(40, 0, 0), hill_n)
	assert_true(absf(hill.dot(hill_n)) < 0.0001, "on a hillside the velocity ends along the slope")
	assert_eq(FlightRules.slide(Vector3(-40, 0, 0), Vector3(-1, 0, 0)), Vector3(-40, 0, 0), "moving away is untouched")

func _test_flying_move_source() -> void:
	var src := FileAccess.get_file_as_string("res://src/player/player_slice.gd")
	var a := src.find("func _move_flying(")
	var b := src.find("\nfunc ", a + 10)
	assert_true(a > 0 and b > a, "the flying move is its own function")
	var body := src.substr(a, b - a)
	for banned in ["resolve_step_up", "DiveGuard", "buried_lift", "step_up_gate"]:
		assert_false(body.contains(banned), "the flying move does not use %s" % banned)
	assert_true(body.contains("move_and_slide"), "but the body still collides")
	var m := src.find("func _move(")
	var mb := src.substr(m, src.find("\nfunc ", m + 10) - m)
	assert_true(mb.contains("_move_flying"), "and `_move` hands a flying body to it")

func _test_camera() -> void:
	assert_eq(FlightRules.fov_boost(0.0, TOP), 0.0, "no widening at rest")
	assert_eq(FlightRules.fov_boost(TOP, TOP), 12.0, "12 degrees at top speed")
	assert_eq(FlightRules.fov_boost(TOP * 3.0, TOP), 12.0, "never more")
	assert_eq(FlightRules.fov_boost(10.0, 0.0), 0.0, "a zero top speed is safe")
	assert_true(FlightRules.lag_target(Vector3(0, 50, -1000)).length() <= FlightRules.CAMERA_LAG_MAX + 0.001, "the lag is capped")
	assert_true(FlightRules.lag_target(Vector3(10, 0, 0)).x < 0.0, "and trails behind")
	var e := FlightRules.ease_to(0.0, 10.0, 4.0, 0.1)
	assert_true(e > 0.0 and e < 10.0, "the ease approaches, never jumps")
