extends Control
## Phase 259 — hold to work. Pressing the gather input on a target asks the host to start timed work; the host
## answers with the duration it computed (`work_started`), and the bar fills while the input stays held on that
## target. Releasing, turning to another target or losing the target cancels (progress is lost, nothing is spent).
## On completion the existing chop / mine request runs unchanged, and holding on starts the next target under the
## crosshair, so a trench is one hold (Phase 290: a dig asks for the next block in the same frame, the one under the
## crosshair when it has moved to another block, else the one behind the dug block). The host times the work
## independently and drops an early completion.

const I18n := preload("res://src/core/i18n.gd")
const InputLabels := preload("res://src/ui/input_labels.gd")
const VoxelConsts := preload("res://src/terrain/voxel_consts.gd")
const WorldPos := preload("res://src/terrain/world_pos.gd")
const WorkTime := preload("res://src/core/work_time.gd")

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
## Phase 290 — the client's own read of a block target: the material mining it would take, "" when there is nothing
## to work (air, a closed site, bedrock), null when unknown. Unset (tests, no terrain): every target is workable.
var block_probe: Callable = Callable()
var _chain_from: Dictionary = {}   # the dug target a chained dig continued from ({} = not chained)
var _last_aim: Dictionary = {}     # the aimed face of the last tick

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
	_last_aim = aimed_block
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
		if not aimed.is_empty() and not _gave_up and _workable(aimed):
			_begin(aimed)
		return
	if not _chain_from.is_empty() and str(aimed.get("kind", "")) == "block":
		# Phase 290 — a chained dig goes on while the crosshair stays on the dug block (the aim has not caught up yet)
		# or on the chained one; another block (another tile, or a step up or down the same one) is where the player
		# wants the next dig, so the chain follows it.
		var block := block_of(aimed)
		if block != block_of(_target) and block != block_of(_chain_from):
			_cancel()
			if _workable(aimed):
				_begin(aimed)
			return
	elif aimed.is_empty() or not same_target(aimed, _target):
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

## Phase 290 — the tile a block target names, the same arithmetic as the host's `_resolve_edit_tile("mine", …)`:
## from `exact` when present, and half a tile back along a side face's normal into the aimed block.
static func tile_of(t: Dictionary) -> Vector2i:
	var p: Vector3 = t.get("position", Vector3.ZERO)
	var x: float = p.x
	var z: float = p.z
	var exact: Dictionary = t.get("exact", {})
	if exact.has("chunk") and exact.has("local"):
		var c: Vector2i = exact["chunk"]
		var l: Vector3 = exact["local"]
		x = float(c.x) * VoxelConsts.CHUNK_SIZE * VoxelConsts.TILE_SIZE + l.x
		z = float(c.y) * VoxelConsts.CHUNK_SIZE * VoxelConsts.TILE_SIZE + l.z
	var n: Vector3 = t.get("normal", Vector3.UP)
	if n.y <= 0.5:
		x -= n.x * VoxelConsts.TILE_SIZE * 0.5
		z -= n.z * VoxelConsts.TILE_SIZE * 0.5
	return Vector2i(floori(x / VoxelConsts.TILE_SIZE), floori(z / VoxelConsts.TILE_SIZE))

## Phase 290 — the block a block target names: its tile and height step, as the host's `_mine_span` picks it. A side
## face names the step its y is inside; a top face names the step under the plane it lies on.
static func block_of(t: Dictionary) -> Vector3i:
	var tile := tile_of(t)
	var y: float = (t.get("position", Vector3.ZERO) as Vector3).y / VoxelConsts.STEP_HEIGHT
	var n: Vector3 = t.get("normal", Vector3.UP)
	return Vector3i(tile.x, roundi(y) - 1 if n.y > 0.5 else floori(y), tile.y)

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
	_chain_from = {}
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
	_chain_from = {}
	_started = false
	_elapsed = 0.0
	_show_bar(false)

func _complete() -> void:
	var t := _target
	var dug := _action == "dig"
	_target = {}
	_chain_from = {}
	_started = false
	_chained = true
	_show_bar(false)
	if t["kind"] == "tree":
		GameBus.tree_chop_requested.emit(str(t["tree_id"]), "")
	else:
		GameBus.block_mine_requested.emit(t["position"], t["normal"], "", t["exact"])
		if dug and _held:
			_chain_dig(t)

## Phase 290 — a dig hold carries straight on, asked for in the same frame instead of after the crosshair has caught
## up with the new face, so a trench is one continuous dig: to the block under the crosshair when it is another
## diggable block (a sweep across a row, a step up or down a wall), else to the block behind the dug one (under it
## for a top face). Neither diggable (air behind a wall, bedrock, a closed site): nothing is asked, and the tick waits
## for a workable aim.
## The host resolves the new target against the column with the dug block gone.
func _chain_dig(dug: Dictionary) -> void:
	if not _last_aim.is_empty() and block_of(_last_aim) != block_of(dug) and _workable(_last_aim, true):
		_begin(_last_aim)
		return
	var next := next_dig_target(dug)
	if _workable(next, true):
		_begin(next)
		_chain_from = dug

## Whether `t` can be worked (dug, with `dig_only`) by the client's own probe; trees and an unset probe pass.
func _workable(t: Dictionary, dig_only := false) -> bool:
	if str(t.get("kind", "")) != "block" or not block_probe.is_valid():
		return true
	var material = block_probe.call(t)
	if material == null:
		return true
	return str(material) != "" and (not dig_only or WorkTime.action_for_material(str(material)) == "dig")

## Phase 290 — the block a dig continues into once `t` is dug: one step down for a top face, one tile further in for
## a side face. `exact` (the `{chunk, local}` world record) moves with it.
static func next_dig_target(t: Dictionary) -> Dictionary:
	var normal: Vector3 = t.get("normal", Vector3.UP)
	var shift := Vector3(0.0, -VoxelConsts.STEP_HEIGHT, 0.0) if normal.y > 0.5 \
		else -Vector3(normal.x, 0.0, normal.z).normalized() * VoxelConsts.TILE_SIZE
	var next := t.duplicate()
	next["position"] = (t["position"] as Vector3) + shift
	var exact: Dictionary = t.get("exact", {})
	if exact.has("chunk") and exact.has("local"):
		next["exact"] = WorldPos.normalized({ "chunk": exact["chunk"], "local": (exact["local"] as Vector3) + shift })
	return next

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
