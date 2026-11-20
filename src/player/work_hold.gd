extends Control
## Phase 259 — hold to work. Pressing the gather input on a target asks the host to start timed work; the host
## answers with the duration it computed (`work_started`), and the bar fills while the input stays held on that
## target. Releasing, turning to another target or losing the target cancels (progress is lost, nothing is spent).
## On completion the existing chop / mine request runs unchanged, and holding on starts the next target under the
## crosshair, so a trench is one hold. The host times the work independently and drops an early completion.

const I18n := preload("res://src/core/i18n.gd")
const InputLabels := preload("res://src/ui/input_labels.gd")

const GIVE_UP_SECONDS := 1.5   # no answer from the host: stop asking until the input is pressed again

var _target: Dictionary = {}   # { kind, tree_id, position, normal, exact }
var _held := false
var _kind := ""
var _duration := 0.0
var _elapsed := 0.0
var _waiting := 0.0
var _started := false
var _gave_up := false
var _action := ""
var _material := ""
var _bar: ProgressBar = null
var _label: Label = null

## Phase 289 — layout. The bar sits centred under the crosshair, BAR_DROP of the screen height below it, clear of the
## hotbar, minimap and chat; the label (material, seconds left, tool, then "Keep holding <input>") stands above it.
const BAR_SIZE := Vector2(220.0, 12.0)
const BAR_DROP := 0.12
const LABEL_SIZE := Vector2(420.0, 50.0)
const HINT_SIZE := Vector2(420.0, 26.0)
const HINT_SECONDS := 2.0   # how long "Released too early" stays

var _hint: Label = null
var _hint_left := 0.0
var _chained := false   # a hold completed since the press: the targets held on to after it show no hint

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.custom_minimum_size = BAR_SIZE
	_bar.size = BAR_SIZE
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar)
	_label = _outlined_label()
	_label.size = LABEL_SIZE
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	add_child(_label)
	_hint = _outlined_label()
	_hint.size = HINT_SIZE
	_hint.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	add_child(_hint)
	GameBus.work_started.connect(_on_started)
	GameBus.player_damaged.connect(_on_damaged)
	get_viewport().size_changed.connect(place)
	place()
	_show_bar(false)
	_hint.visible = false
	visible = false

func _outlined_label() -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Spread over the whole viewport and put the bar, label and hint at their places for its size (also on resize).
func place() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vp := get_viewport()
	if vp == null:
		return
	var view := vp.get_visible_rect().size
	position = Vector2.ZERO
	size = view
	var r := bar_rect(view)
	_bar.position = r.position
	_bar.size = r.size
	_label.position = Vector2(view.x * 0.5 - LABEL_SIZE.x * 0.5, r.position.y - LABEL_SIZE.y - 2.0)
	_hint.position = Vector2(view.x * 0.5 - HINT_SIZE.x * 0.5, r.end.y + 4.0)

## The bar's rect on a viewport of `view` size: centred, BAR_DROP of the height under the centre.
static func bar_rect(view: Vector2) -> Rect2:
	return Rect2(Vector2(roundf(view.x * 0.5 - BAR_SIZE.x * 0.5), roundf(view.y * (0.5 + BAR_DROP))), BAR_SIZE)

func _process(delta: float) -> void:
	step_hint(delta)

## Count the early-release hint down; it hides when its time is up.
func step_hint(delta: float) -> void:
	if _hint_left <= 0.0:
		return
	_hint_left -= delta
	if _hint_left <= 0.0:
		_hint_left = 0.0
		_hint.visible = false
		_sync_visible()

func hint_showing() -> bool:
	return _hint != null and _hint.visible

func bar_showing() -> bool:
	return visible and _bar.visible

func bar() -> ProgressBar:
	return _bar

func _show_bar(on: bool) -> void:
	_bar.visible = on
	_label.visible = on
	_sync_visible()

func _sync_visible() -> void:
	visible = _bar.visible or _hint.visible

## The gather input went down on `target` (`{}` = nothing aimed).
func press(target: Dictionary) -> void:
	_held = true
	_gave_up = false
	_chained = false
	_begin(target)

## The gather input went up: a cancel, always.
## Phase 289: letting go of a running hold before the bar fills shows the hint for HINT_SECONDS. Not before the host
## started the work (nothing could be lost) and not once a hold of this press completed (the bar then shows the next
## target, already carried on).
func release() -> void:
	_held = false
	var early := not _target.is_empty() and _started and not _chained
	_cancel()
	if early:
		_hint.text = I18n.t("controls.work_released_early")
		_hint.visible = true
		_hint_left = HINT_SECONDS
		_sync_visible()

## Per frame: finish when the host's duration has passed, drop on retarget, start the next target while held.
func tick(delta: float, aimed_tree: String, aimed_block: Dictionary) -> void:
	if not _held:
		return
	# Working a target: the aim of its kind. Between targets: a tree, else the aimed face (a Shift hold keeps mining).
	var tree_aim: Dictionary = { "kind": "tree", "tree_id": aimed_tree } if aimed_tree != "" else {}
	var aimed: Dictionary
	if not _target.is_empty():
		aimed = tree_aim if _kind == "tree" else aimed_block
	elif _kind == "block":
		aimed = aimed_block
	else:
		aimed = tree_aim if not tree_aim.is_empty() else aimed_block
	if _target.is_empty():
		if not aimed.is_empty() and not _gave_up:
			_begin(aimed)
		return
	if aimed.is_empty() or not same_target(aimed, _target):
		_cancel()
		return
	if not _started:
		_waiting += delta
		if _waiting >= GIVE_UP_SECONDS:
			_cancel()
			_gave_up = true
		return
	_elapsed += delta
	_refresh()
	if _elapsed >= _duration:
		_complete()

static func same_target(a: Dictionary, b: Dictionary) -> bool:
	if a.get("kind", "") != b.get("kind", ""):
		return false
	if a["kind"] == "tree":
		return str(a["tree_id"]) == str(b["tree_id"])
	return (a["position"] as Vector3).distance_to(b["position"]) <= 1.0

func progress() -> float:
	return clampf(_elapsed / _duration, 0.0, 1.0) if _started and _duration > 0.0 else 0.0

func _begin(target: Dictionary) -> void:
	if target.is_empty():
		return
	_target = target
	_kind = str(target["kind"])
	_started = false
	_elapsed = 0.0
	_waiting = 0.0
	GameBus.work_start_requested.emit(str(target["kind"]), str(target.get("tree_id", "")), target.get("position", Vector3.ZERO),
		target.get("normal", Vector3.UP), target.get("exact", {}), "")

func _on_started(key: String, duration: float, action: String, material: String) -> void:
	if _target.is_empty() or _started:
		return
	# An answer for a target we have left (retarget while it was in flight) is stale.
	if _target["kind"] == "tree" and key != "tree:" + str(_target["tree_id"]):
		return
	_started = true
	_duration = duration
	_action = action
	_material = material
	_elapsed = 0.0
	_refresh()

## Being hit cancels the work; it restarts only on a fresh press.
func _on_damaged(_damage: float, _attacker: String, target: String) -> void:
	if target == "player" and not _target.is_empty():
		_cancel()
		_gave_up = true

func _cancel() -> void:
	if not _target.is_empty():
		GameBus.work_cancel_requested.emit("")
	_target = {}
	_started = false
	_elapsed = 0.0
	_show_bar(false)

func _complete() -> void:
	var t := _target
	_target = {}
	_started = false
	_chained = true
	_show_bar(false)
	if t["kind"] == "tree":
		GameBus.tree_chop_requested.emit(str(t["tree_id"]), "")
	else:
		GameBus.block_mine_requested.emit(t["position"], t["normal"], "", t["exact"])

func _refresh() -> void:
	show_work(_action, _material, _duration, _elapsed, _kind)

## Draw the bar for work of `action` on `material`, `elapsed` of `duration` seconds in, with the input to keep holding.
## The playtest bot calls it to shoot the bar mid-hold on a hold it drives itself.
func show_work(action: String, material: String, duration: float, elapsed: float, kind: String) -> void:
	_hint.visible = false
	_hint_left = 0.0
	_bar.value = clampf(elapsed / duration, 0.0, 1.0) if duration > 0.0 else 0.0
	var tool_key := "work.tool." + ("axe" if action == "chop" else ("shovel" if action == "dig" else "pick"))
	_label.text = I18n.t("work.progress", [I18n.content("item", material), int(ceil(maxf(duration - elapsed, 0.0))), I18n.t(tool_key)]) \
		+ "\n" + I18n.t("controls.work_keep_holding", [InputLabels.work_input(kind)])
	_show_bar(true)
