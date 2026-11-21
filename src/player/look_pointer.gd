extends RefCounted
## Phase 291 — where the pointer was when a right-click look began, put back when the look ends. Held by
## `PlayerSlice` as `look_pointer`; the suite swaps in a stretched viewport and a warp sink on this object.

const Pointer := preload("res://src/player/pointer.gd")

## Root-viewport position of the pointer when the look began.
var restore_pos: Vector2 = Vector2.ZERO
## Suite only: a viewport used instead of the slice's own (an unparented, stretched SubViewport).
var viewport_override: Viewport = null
## Suite only: called with the window pixel instead of moving the real pointer.
var warp_sink: Callable = Callable()

## The viewport the look reads and warps in: the override when set, else `own`.
func viewport_of(own: Viewport) -> Viewport:
	return viewport_override if viewport_override != null else own

## Remember the pointer's position at the start of a look.
func remember(own: Viewport) -> void:
	var vp := viewport_of(own)
	if vp != null:
		restore_pos = vp.get_mouse_position()

## Put the pointer back where `remember` saw it (window pixels, not viewport coordinates).
func restore(own: Viewport) -> bool:
	return Pointer.warp(viewport_of(own), restore_pos, warp_sink)
