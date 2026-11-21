extends RefCounted
## Phase 291 — the one place the mouse pointer is warped. `Viewport.get_mouse_position()` is in the root viewport's
## coordinates, `Input.warp_mouse` takes window pixels; with `canvas_items` stretch the two differ by the stretch
## scale, so a viewport position goes through the viewport's final transform first. Nothing else calls `warp_mouse`
## (a suite test greps for it).

## Window pixels of a viewport position, for a viewport whose final transform is `final`.
static func window_position(final: Transform2D, viewport_pos: Vector2) -> Vector2:
	return final * viewport_pos

## Put the pointer back at `viewport_pos` (a root-viewport position, as `get_mouse_position` returns). Not moved
## when the window lost focus (a look that ended because of that must not drag the pointer around).
static func warp(viewport: Viewport, viewport_pos: Vector2) -> bool:
	if viewport == null or not DisplayServer.window_is_focused():
		return false
	Input.warp_mouse(window_position(viewport.get_final_transform(), viewport_pos))
	return true
