extends Node3D
## #629 — draws the work marks (`work_marks.gd`) on this machine: a crack overlay on the top face of a worked block,
## darker and more broken with each stage, and a sway on a tree being chopped. Presentation only: it reads the marks
## the wiring applied and never decides anything. A rebase target (`shift_scene`), so the overlays stay on their
## blocks when the scene origin moves.
## #714 — a work strike (`strike`, the clip's impact marker) is the beat of a mark: once a mark has been struck, its
## crack stage only steps on a strike (it holds the progress of the last one), the tree it shakes kicks harder for
## `KICK_SECONDS`, and a short burst of chips flies off the struck point. A mark nobody's strike reaches here (no
## body for the worker, a rig without the clip) keeps its time-driven drawing.

const WorkMarks := preload("res://src/world/work_marks.gd")
const VoxelConsts := preload("res://src/terrain/voxel_consts.gd")

## The crack texture's size (pixels) and the overlay's lift above the face, so it never z-fights the ground.
const CRACK_TEXTURE_SIZE := 64
const LIFT := 0.01
## A strike reaches the mark nearest the striking body within this many metres (work reach plus slack).
const STRIKE_REACH := 6.0
## How long a struck tree's sway is boosted, and by how much at the strike (1 = double).
const KICK_SECONDS := 0.25
const KICK_GAIN := 1.5
## Chip bursts: particles per burst, lifetime (s), and the most alive at once (older bursts are freed first).
const CHIP_COUNT := 8
const CHIP_LIFETIME := 0.5
const MAX_CHIP_BURSTS := 8

var marks := WorkMarks.new()
## `TreeSlice` (for the shake); null on a boot with no trees.
var tree_slice: Node = null
## `Callable() -> float`, seconds; the suite sets a fake clock.
var clock: Callable = func() -> float: return Time.get_ticks_msec() * 0.001

## The scene-origin shift applied so far (world frame → scene).
var _offset := Vector3.ZERO
## `{ key: MeshInstance3D }` — one overlay per block mark.
var _overlays: Dictionary = {}
## Tree ids this view tilted, so a stop puts them back.
var _shaken: Dictionary = {}
## `{ key: seconds }` — when each mark was last struck (#714). A struck mark draws the progress of that moment.
var _struck: Dictionary = {}
## `[[CPUParticles3D, born seconds], ...]` — the chip bursts still alive, oldest first.
var chips: Array = []
## One texture per crack stage, built once (deterministic).
static var _textures: Array = []

## Apply a host message (see `WorkMarks.apply`) and redraw at once. Returns whether it was taken.
func apply(key: Variant, duration: Variant) -> bool:
	if not marks.apply(key, duration, clock.call()):
		return false
	_struck.erase(str(key))   # a restart (or a stop) begins a new beat
	if not marks.has(str(key)):
		_drop(str(key))
	step()
	return true

func _process(_delta: float) -> void:
	step()

## One frame: expire lost marks, then draw each one at its progress.
func step() -> void:
	var now: float = clock.call()
	for k in marks.expire(now):
		_drop(str(k))
	# A mark the store evicted when full never comes back from `expire`: drop what it left drawn.
	for k in _overlays.keys():
		if not marks.has(str(k)):
			_drop(str(k))
	for tid in _shaken.keys():
		if not marks.has("tree:" + str(tid)):
			_drop("tree:" + str(tid))
	for k in _struck.keys():
		if not marks.has(str(k)):
			_struck.erase(k)
	_expire_chips(now)
	for k in marks.keys():
		var key := str(k)
		var target := WorkMarks.parse_key(key)
		if target["kind"] == "tree":
			_shake(key, str(target["tree_id"]), now)
		else:
			_crack(key, target, now)

## #714 — a work strike landed by a body standing at `at` (unshifted world frame). `key`, when this machine knows
## which mark the striker works (its own hold, or any hold on the host), takes the beat; otherwise the nearest mark
## within `STRIKE_REACH` of the kind's target (a tree for `chop`, a block for `mine`/`dig`) does. Returns the key
## struck, "" when none.
func strike(at: Vector3, kind: String = "", key: String = "") -> String:
	var now: float = clock.call()
	var best := ""
	var best_d := STRIKE_REACH * STRIKE_REACH
	var best_p := Vector3.ZERO
	var want := "tree" if kind == "chop" else ("block" if kind == "mine" or kind == "dig" else "")
	if key != "" and marks.has(key):
		var kp: Variant = mark_point(key)
		if kp is Vector3 and (kp as Vector3).distance_squared_to(at) <= best_d:
			best = key
			best_p = kp
	for k in marks.keys() if best == "" else []:
		if want != "" and WorkMarks.parse_key(str(k))["kind"] != want:
			continue
		var p: Variant = mark_point(str(k))
		if p == null:
			continue
		var d := (p as Vector3).distance_squared_to(at)
		if d <= best_d:
			best = str(k)
			best_d = d
			best_p = p
	if best == "":
		return ""
	_struck[best] = now
	_spawn_chips(best_p + _offset, WorkMarks.parse_key(best)["kind"] == "tree" or kind == "chop")
	step()
	return best

## Where `key`'s mark is, in the unshifted world frame: a block's top face centre, a tree's base. Null for a tree
## this view cannot see.
func mark_point(key: String) -> Variant:
	var target := WorkMarks.parse_key(key)
	if target.is_empty():
		return null
	if target["kind"] == "tree":
		if tree_slice == null or not "_trees" in tree_slice:
			return null
		var tree: Variant = tree_slice._trees.get(str(target["tree_id"]), null)
		return (tree["position"] as Vector3) + Vector3(0.0, 1.0, 0.0) if tree is Dictionary and tree.has("position") else null
	return WorkMarks.block_top(target["tile"], float(target["bottom"]), VoxelConsts.TILE_SIZE, VoxelConsts.STEP_HEIGHT)

## When `key` was last struck, or -1.0 if never (the suite reads it).
func struck_at(key: String) -> float:
	return float(_struck.get(key, -1.0))

## The progress a mark is drawn at: the moment of its last strike once struck, otherwise now.
func _shown_progress(key: String, now: float) -> float:
	return marks.progress(key, float(_struck[key])) if _struck.has(key) else marks.progress(key, now)

func _spawn_chips(scene_at: Vector3, wood: bool) -> void:
	while chips.size() >= MAX_CHIP_BURSTS:
		_free_burst(chips.pop_front()[0])
	var p := CPUParticles3D.new()
	p.name = "Chips"
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = CHIP_COUNT
	p.lifetime = CHIP_LIFETIME
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0.0, -9.8, 0.0)
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.05, 0.05)
	p.mesh = box
	p.color = Color(0.45, 0.3, 0.15) if wood else Color(0.5, 0.48, 0.45)
	p.position = scene_at
	add_child(p)
	p.emitting = true
	chips.append([p, float(clock.call())])

func _expire_chips(now: float) -> void:
	while not chips.is_empty() and now - float(chips[0][1]) > CHIP_LIFETIME:
		_free_burst(chips.pop_front()[0])

func _free_burst(p: Variant) -> void:
	if p != null and is_instance_valid(p):
		if (p as Node).get_parent() == self:
			remove_child(p)
		(p as Node).free()

## The overlay drawn for `key` (null when none), for the suite.
func overlay(key: String) -> MeshInstance3D:
	return _overlays.get(key, null)

func is_shaking(tree_id: String) -> bool:
	return _shaken.has(tree_id)

func shift_scene(shift: Vector3) -> void:
	_offset += shift
	for k in _overlays:
		(_overlays[k] as Node3D).position += shift
	for b in chips:
		if is_instance_valid(b[0]):
			(b[0] as Node3D).position += shift

func clear() -> void:
	for k in marks.keys():
		_drop(str(k))
	marks.clear()
	_struck.clear()
	while not chips.is_empty():
		_free_burst(chips.pop_front()[0])

func _exit_tree() -> void:
	for tid in _shaken.keys():
		_untilt(str(tid))
	_shaken.clear()

func _shake(key: String, tree_id: String, now: float) -> void:
	if tree_slice == null or not "_fall" in tree_slice:
		return
	var angle := WorkMarks.shake_angle(marks.elapsed(key, now), _shown_progress(key, now))
	if _struck.has(key):
		angle *= 1.0 + KICK_GAIN * clampf(1.0 - (now - float(_struck[key])) / KICK_SECONDS, 0.0, 1.0)
	if tree_slice._fall.shake(tree_id, angle):
		_shaken[tree_id] = true

func _untilt(tree_id: String) -> void:
	if tree_slice != null and is_instance_valid(tree_slice) and "_fall" in tree_slice:
		tree_slice._fall.shake(tree_id, 0.0)

func _crack(key: String, target: Dictionary, now: float) -> void:
	var stage := WorkMarks.crack_stage(_shown_progress(key, now))
	var mi: MeshInstance3D = _overlays.get(key, null)
	if mi == null:
		mi = MeshInstance3D.new()
		mi.name = "Crack"
		var quad := QuadMesh.new()
		quad.size = Vector2(VoxelConsts.TILE_SIZE, VoxelConsts.TILE_SIZE)
		quad.orientation = PlaneMesh.FACE_Y
		mi.mesh = quad
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.05, 0.04, 0.03, 1.0)
		mi.material_override = mat
		mi.position = WorkMarks.block_top(target["tile"], float(target["bottom"]), VoxelConsts.TILE_SIZE,
			VoxelConsts.STEP_HEIGHT) + Vector3(0.0, LIFT, 0.0) + _offset
		add_child(mi)
		_overlays[key] = mi
	var m := mi.material_override as StandardMaterial3D
	if stage > 0 and int(mi.get_meta("stage", 0)) != stage:
		m.albedo_texture = crack_texture(stage)
		mi.set_meta("stage", stage)
	mi.visible = stage > 0

func _drop(key: String) -> void:
	_struck.erase(key)
	var mi: MeshInstance3D = _overlays.get(key, null)
	if mi != null:
		_overlays.erase(key)
		remove_child(mi)
		mi.free()
	var target := WorkMarks.parse_key(key)
	if not target.is_empty() and target["kind"] == "tree":
		var tid := str(target["tree_id"])
		if _shaken.has(tid):
			_untilt(tid)
			_shaken.erase(tid)

## The crack texture of `stage` (1..CRACK_STAGES): the same few cracks every time (a fixed seed), each stage drawing
## more of them and longer, on a transparent ground.
static func crack_texture(stage: int) -> Texture2D:
	if _textures.is_empty():
		for s in range(1, WorkMarks.CRACK_STAGES + 1):
			_textures.append(ImageTexture.create_from_image(crack_image(s)))
	return _textures[clampi(stage, 1, WorkMarks.CRACK_STAGES) - 1]

## The crack image of `stage`: random walks from the centre, `stage * 2` of them, each `stage * 6` steps long.
static func crack_image(stage: int) -> Image:
	var n := CRACK_TEXTURE_SIZE
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 629
	var c := Vector2(n * 0.5, n * 0.5)
	for i in stage * 2:
		var p := c
		var dir := Vector2.RIGHT.rotated(TAU * float(i) / float(stage * 2) + rng.randf_range(-0.3, 0.3))
		for _s in stage * 6:
			dir = dir.rotated(rng.randf_range(-0.6, 0.6))
			p += dir * 2.0
			var px := Vector2i(clampi(int(p.x), 0, n - 1), clampi(int(p.y), 0, n - 1))
			img.set_pixelv(px, Color(1, 1, 1, 0.9))
			img.set_pixelv(Vector2i(mini(px.x + 1, n - 1), px.y), Color(1, 1, 1, 0.6))
	return img
