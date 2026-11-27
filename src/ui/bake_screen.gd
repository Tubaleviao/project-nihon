extends CanvasLayer
## BakeScreen — the progress screen while a host bakes the planet at world creation (Phase 302).
##
## The bake (`BakeJob`) runs on a worker thread; the boot path polls its snapshot each frame and calls
## `show_progress`. Every string goes through `I18n.t()` (`bake.*` keys); the percent is formatted for the
## active locale. Presentation only: a dedicated server or headless boot never builds it (`BakeBoot` logs).

const I18n := preload("res://src/core/i18n.gd")
const LAYER := 40   ## above the loading screen (30)
const PANEL_SIZE := Vector2(480.0, 128.0)

var _title: Label = null
var _stage: Label = null
var _bar: ProgressBar = null


func _ready() -> void:
	layer = LAYER
	_build()
	show_progress(&"load", 0.0, 0.0)


func _build() -> void:
	var root := Control.new()
	root.name = "BakeRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.06, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = PANEL_SIZE
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	_title = Label.new()
	_title.name = "BakeTitle"
	_title.text = I18n.t("bake.title")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_stage = Label.new()
	_stage.name = "BakeStage"
	_stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_stage)
	_bar = ProgressBar.new()
	_bar.name = "BakeBar"
	_bar.max_value = 100.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(PANEL_SIZE.x - 32.0, 22.0)
	box.add_child(_bar)


## The stage's translation key (`bake.stage.<stage>`).
static func stage_key(stage: StringName) -> String:
	return "bake.stage.%s" % stage


## The line under the title: the stage's text and the overall percent, in the active locale.
static func caption(stage: StringName, overall: float) -> String:
	return I18n.t("bake.progress", [I18n.t(stage_key(stage)), clampf(overall, 0.0, 1.0) * 100.0])


## Every translation key the screen can show.
static func keys() -> Array[String]:
	var out: Array[String] = ["bake.title", "bake.progress"]
	for s in load("res://src/terrain/planet_bake.gd").STAGES:
		out.append(stage_key(s))
	return out


func show_progress(stage: StringName, _fraction: float, overall: float) -> void:
	if _stage != null:
		_stage.text = caption(stage, overall)
	if _bar != null:
		_bar.value = clampf(overall, 0.0, 1.0) * 100.0
