extends RefCounted
## Phase 287 — what a landed hit feels like on the attacker's own client: a short camera shake and a 40 ms hit-stop
## (the attacker's animation freezes). Each is switched by an option (`camera_shake`, `hit_stop`).

const GameSettings := preload("res://src/core/game_settings.gd")

const HIT_STOP_SECONDS := 0.04
const SHAKE_SECONDS := 0.12
const SHAKE_METRES := 0.04

static func shake_on() -> bool:
	return bool(GameSettings.get_value("camera_shake"))

static func hit_stop_on() -> bool:
	return bool(GameSettings.get_value("hit_stop"))

## Shake `camera` (its h/v offsets, which nothing else drives) and ease back. False when the option is off.
static func shake(camera: Camera3D, strength: float = SHAKE_METRES) -> bool:
	if camera == null or not camera.is_inside_tree() or not shake_on():
		return false
	var previous: Variant = camera.get_meta("shake_tween", null)
	if previous is Tween and (previous as Tween).is_valid():
		(previous as Tween).kill()   # two quick hits: the first's reset must not cut the second shake short
	var tween := camera.create_tween()
	camera.set_meta("shake_tween", tween)
	tween.tween_method(func(t: float) -> void:
		var k := (1.0 - t) * strength
		camera.h_offset = randf_range(-k, k)
		camera.v_offset = randf_range(-k, k), 0.0, 1.0, SHAKE_SECONDS)
	tween.tween_callback(func() -> void:
		camera.h_offset = 0.0
		camera.v_offset = 0.0)
	return true

## Freeze an animation tree for `HIT_STOP_SECONDS`. False when the option is off or the tree is not live.
static func hit_stop(tree: AnimationTree) -> bool:
	if tree == null or not tree.is_inside_tree() or not tree.active or not hit_stop_on():
		return false
	tree.active = false
	tree.get_tree().create_timer(HIT_STOP_SECONDS).timeout.connect(func() -> void:
		if is_instance_valid(tree):
			tree.active = true)
	return true
