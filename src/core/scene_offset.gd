extends RefCounted
## Phase 122 — the scene-origin offset a client rebase has applied (Phase 50/63), once for every slice
## that owns scene nodes. Zero until the first rebase; nodes built later add `value` to their world
## position so a rebase never leaves a mix of frames. Slices expose `shift_scene(shift)` for
## `RebaseDriver`, which reports any target without it.

var value: Vector3 = Vector3.ZERO

## Accumulate a rebase shift.
func add(shift: Vector3) -> void:
	value += shift

## The scene position of a world-space position.
func to_scene(world_pos: Vector3) -> Vector3:
	return world_pos + value

## The world-space position of a scene position.
func to_world(scene_pos: Vector3) -> Vector3:
	return scene_pos - value
