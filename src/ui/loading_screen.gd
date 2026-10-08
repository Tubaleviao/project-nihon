extends CanvasLayer
## LoadingScreen — the first-ring loading gate (Phase 42).
##
## The ground a body stands on is now built on a WORKER (see VoxelSlice's pure
## builder and ChunkManager's dispatch), so for the first frames of a boot the world
## under the player's spawn point does not exist yet: the body would be placed on
## nothing and fall. This screen is what covers that window — it is shown until
## ChunkManager reports the first ring (Chebyshev 0..1 around the centre, 9 chunks)
## BUILT, and it owns the freeze that stops the player acting in a world that is not
## there yet.
##
## Plug contract (GameBus signals emitted):
##   OUT : world_input_frozen(frozen)
##
## Public API:
##   begin()                  — show the screen and freeze world input
##   set_progress(fraction)   — 0..1, drives the bar and the caption
##   finish()                 — hide, unfreeze, restore the mouse state
##   is_active()              -> bool
##
## The freeze is this screen's OWN hook, and it has to be: the gate a world action
## actually consults is the mouse-capture state (`PlayerSlice._input`), and
## `UIControl.any_window_open()` answers only for the panels the UI slice holds — a
## loading screen is not one of them, so that predicate would answer `false` and
## freeze nothing. So the screen (a) releases the mouse while it is up, which is the
## state the player's input reads, and (b) emits `world_input_frozen`, which
## PlayerSlice listens to, so the refusal survives a display server that has no mouse
## at all (a headless run) and is directly assertable.
##
## Presentation only: it is added to the tree by the boot path behind the same
## `not _is_server` guard the minimap and the UI use, so a dedicated server never
## builds it.

## Deliberately above the minimap (layer 20) and the UI windows (layer 10).
const LAYER := 30
const PANEL_SIZE := Vector2(440.0, 104.0)

var _panel: Control = null
var _bar: ProgressBar = null
var _caption: Label = null
var _active: bool = false
## What `Input.mouse_mode` was before `begin()`, so `finish()` hands the mouse back
## rather than assuming capture is what the caller wanted.
var _restore_mouse: int = Input.MOUSE_MODE_VISIBLE

func _ready() -> void:
	layer = LAYER
	visible = false
	_build()

## Assemble the dim + centred panel. Built in code like every other surface in this
## slice family: there is no `.tscn` for the UI in this project.
func _build() -> void:
	var root := Control.new()
	root.name = "LoadingRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# The screen must swallow clicks that land on it, so a world action cannot be
	# aimed through it even if something else forgets the freeze.
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.03, 0.04, 0.06, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	_panel = PanelContainer.new()
	_panel.name = "LoadingPanel"
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = PANEL_SIZE
	root.add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)

	_caption = Label.new()
	_caption.name = "LoadingCaption"
	_caption.text = "Building the world…"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_caption)

	_bar = ProgressBar.new()
	_bar.name = "LoadingBar"
	_bar.min_value = 0.0
	_bar.max_value = 100.0
	_bar.value = 0.0
	_bar.custom_minimum_size = Vector2(PANEL_SIZE.x - 32.0, 22.0)
	_bar.show_percentage = false
	box.add_child(_bar)

## Show the screen, freeze world input, and release the mouse the player's input reads.
func begin() -> void:
	if _active:
		return
	_active = true
	_restore_mouse = Input.mouse_mode
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	GameBus.world_input_frozen.emit(true)
	visible = true
	set_progress(0.0)

## Drive the bar and the caption from a 0..1 progress fraction.
func set_progress(fraction: float) -> void:
	var f := clampf(fraction, 0.0, 1.0)
	if _bar != null:
		_bar.value = f * 100.0
	if _caption != null:
		_caption.text = "Building the world…  %d%%" % int(round(f * 100.0))

## Hide, unfreeze, and hand the mouse back to whatever held it before `begin()`.
func finish() -> void:
	if not _active:
		return
	_active = false
	visible = false
	Input.set_mouse_mode(_restore_mouse)
	GameBus.world_input_frozen.emit(false)

func is_active() -> bool:
	return _active
