extends Control
## Phase 259 — hold to work. Pressing the gather input on a target asks the host to start timed work; the host
## answers with the duration it computed (`work_started`), and the bar fills while the input stays held on that
## target. Releasing, turning to another target or losing the target cancels (progress is lost, nothing is spent).
## On completion the existing chop / mine request runs unchanged, and holding on starts the next target under the
## crosshair, so a trench is one hold. The host times the work independently and drops an early completion.

const I18n := preload("res://src/core/i18n.gd")

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

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.custom_minimum_size = Vector2(140.0, 8.0)
	_bar.position = Vector2(-70.0, 34.0)
	_bar.size = Vector2(140.0, 8.0)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar)
	_label = Label.new()
	_label.position = Vector2(-120.0, 44.0)
	_label.size = Vector2(240.0, 24.0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	GameBus.work_started.connect(_on_started)
	GameBus.player_damaged.connect(_on_damaged)
	visible = false

## The gather input went down on `target` (`{}` = nothing aimed).
func press(target: Dictionary) -> void:
	_held = true
	_gave_up = false
	_begin(target)

## The gather input went up: a cancel, always.
func release() -> void:
	_held = false
	_cancel()

## Per frame: finish when the host's duration has passed, drop on retarget, start the next target while held.
func tick(delta: float, aimed_tree: String, aimed_block: Dictionary) -> void:
	if not _held:
		return
	# The next target is of the kind being worked: a tree while chopping, the aimed face while mining.
	var aimed: Dictionary = aimed_block
	if _kind == "tree":
		aimed = { "kind": "tree", "tree_id": aimed_tree } if aimed_tree != "" else {}
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

func _on_started(_key: String, duration: float, action: String, material: String) -> void:
	if _target.is_empty() or _started:
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
	visible = false

func _complete() -> void:
	var t := _target
	_target = {}
	_started = false
	visible = false
	if t["kind"] == "tree":
		GameBus.tree_chop_requested.emit(str(t["tree_id"]), "")
	else:
		GameBus.block_mine_requested.emit(t["position"], t["normal"], "", t["exact"])

func _refresh() -> void:
	visible = true
	_bar.value = progress()
	var tool_key := "work.tool." + ("axe" if _action == "chop" else ("shovel" if _action == "dig" else "pick"))
	_label.text = I18n.t("work.progress", [_material, int(ceil(maxf(_duration - _elapsed, 0.0))), I18n.t(tool_key)])
