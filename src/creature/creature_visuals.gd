extends Node3D
## Rigged models for creatures near the camera (ROADMAP Phase 143).
##
## `CreatureSlice` keeps one box in a shared MultiMesh for every creature. This node gives the
## creatures within `MODEL_RANGE_M` of the camera (at most `MAX_MODELS`, nearest first) a skinned
## model from `AssetOverlay.creature_model_key`, tells the slice to drop their box (`model_attached`)
## and to bring it back when the model goes (`model_detached`). A creature whose model key is absent
## or does not parse keeps its box, with one warning per type. Clips are driven from the creature's
## AI state and measured movement speed through the same `RigTree` the avatar uses, so the wire is
## unchanged and clients animate from the synced state.
##
## The placeholder rigs face -Z (the Godot forward); the fabric `restPose` puts the head at +Z.
## `yaw_for_direction` is the one place that reconciles the two.

const RigTree := preload("res://src/character/rig_tree.gd")
const Locomotion := preload("res://src/character/locomotion.gd")
const CharacterMaterial := preload("res://src/character/character_material.gd")
const Diag := preload("res://src/core/diag.gd")
const GameDataReader := preload("res://src/core/game_data_reader.gd")

## Creatures closer than this to the camera get a model.
const MODEL_RANGE_M := 40.0
## A modelled creature keeps its model out to MODEL_RANGE_M + this, so one at the edge does not flicker.
const HYSTERESIS_M := 6.0
## Cap on live model rigs; the nearest creatures win.
const MAX_MODELS := 24
## Seconds between range checks (the models themselves are updated every frame).
const SELECT_INTERVAL := 0.25
## A creature that moves farther than this between two model updates was teleported (a respawn), not
## run: its speed estimate restarts at rest instead of reading the jump as a sprint.
const TELEPORT_JUMP_M := 8.0
## Seconds a dead creature's model holds its death pose before it is dropped.
const CORPSE_SECONDS := 8.0
## Horizontal speed (m/s) above which the model turns to face the direction of travel.
const FACE_SPEED := 0.3

## Creature AI state -> locomotion state at rest; movement speed refines it (see `loco_state`).
const STATES := ["idle", "alert", "aggressive", "fleeing", "dead", "respawning"]

signal model_attached(instance_id: String)
signal model_detached(instance_id: String)

## instance_id -> { node, tree, speed, last_pos, yaw, state, dead_at, node_name }
var models: Dictionary = {}
## creature_id -> { scene: PackedScene, material: ShaderMaterial } or null (settled: no model).
var _templates: Dictionary = {}
## creature_id -> true once its missing/broken model has warned.
var warned_types: Dictionary = {}
var max_models: int = MAX_MODELS
## Colour a creature type's box is tinted with; the model's palette index is the nearest entry.
var tint_of: Callable = Callable()
var _select_accum: float = 0.0
var _palette: Array = []
## creature_id -> true: types seen by `reselect` (in the slice, out of model range) whose template is not
## built yet. `tick` builds one per frame so a type's first model does not hitch the frame it comes in range.
var _warm_queue: Dictionary = {}


## Pure: which instances hold a model. `cands` is [[instance_id, distance_m], ...], `current` maps the
## instance ids that already have a model. Nearest first, capped at `max_n`; a current holder is kept
## out to `range_m + hysteresis_m`.
static func select_ids(cands: Array, current: Dictionary, range_m: float, hysteresis_m: float, max_n: int) -> Array:
	var eligible: Array = []
	for c in cands:
		var limit := range_m + (hysteresis_m if current.has(c[0]) else 0.0)
		if float(c[1]) <= limit:
			eligible.append(c)
	eligible.sort_custom(func(a, b): return float(a[1]) < float(b[1]) if a[1] != b[1] else str(a[0]) < str(b[0]))
	var out: Array = []
	for c in eligible:
		if out.size() >= max_n:
			break
		out.append(c[0])
	return out


## Pure: locomotion state for a creature AI state and horizontal speed (m/s).
static func loco_state(state: String, speed: float) -> int:
	if state == "dead":
		return Locomotion.State.DEATH
	var moving := Locomotion.State.IDLE
	if speed >= Locomotion.RUN_SPEED:
		moving = Locomotion.State.RUN
	elif speed >= Locomotion.WALK_SPEED:
		moving = Locomotion.State.WALK
	match state:
		"fleeing":
			return Locomotion.State.RUN
		"aggressive":
			return moving if moving != Locomotion.State.IDLE else Locomotion.State.ATTACK
	return moving


## Pure: the clip a creature plays, one of the seven shared names.
static func clip_name(state: String, speed: float) -> String:
	var s := loco_state(state, speed)
	match s:
		Locomotion.State.IDLE: return "idle"
		Locomotion.State.WALK: return "walk"
		Locomotion.State.RUN: return "run"
	return RigTree.node_for_state(s).to_lower()


## Pure: whether the clip for `state` loops. Death plays once and holds its last pose.
static func clip_loops(state: String) -> bool:
	return state != "dead"


## Pure: yaw (radians about +Y) that turns a -Z-forward model to face the horizontal direction `dir`.
static func yaw_for_direction(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


## Pure: blend position in the Locomotion space (idle 0, walk 0.5, run 1) for a speed.
static func blend_for_speed(speed: float) -> float:
	if speed >= Locomotion.RUN_SPEED:
		return 1.0
	if speed >= Locomotion.WALK_SPEED:
		return 0.5
	return 0.0


## Play a swing on a modelled creature. `id` is an instance id, or a creature type when the round
## named the type (the first modelled instance of it). False when no model answers to `id`.
func trigger_attack(id: String) -> bool:
	var iid := _model_for(id)
	if iid == "":
		return false
	var m: Dictionary = models[iid]
	var tree: AnimationTree = m["tree"]
	RigTree.set_attack_clip(tree, RigTree.ATTACK_DEFAULT)
	m["swing"] = int(m["swing"]) + 1
	m["swing_left"] = _attack_length(m)
	m["swings"] = int(m.get("swings", 0)) + 1
	return true


## Play the hit flinch on a modelled creature (see `trigger_attack` for `id`).
func trigger_hit(id: String) -> bool:
	var iid := _model_for(id)
	if iid == "":
		return false
	return RigTree.fire_hit(models[iid]["tree"])


func _attack_length(m: Dictionary) -> float:
	var player := (m["node"] as Node).find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null and player.has_animation("attack"):
		return player.get_animation("attack").length
	return Locomotion.ATTACK_DURATION


func _model_for(id: String) -> String:
	if models.has(id):
		return id
	for iid in models:
		if str((models[iid]["node"] as Node).get_meta("creature_id", "")) == id:
			return iid
	return ""


func has_model(instance_id: String) -> bool:
	return models.has(instance_id)


## Shift every model by `shift` (a client rebase moves this node; positions stay world coordinates).
func shift_scene(shift: Vector3) -> void:
	position += shift


## Run one frame. `instances` is the slice's id -> record map; `cam_world` the camera in world coordinates
## (a zero-length query is skipped when `has_cam` is false).
func tick(instances: Dictionary, cam_world: Vector3, has_cam: bool, delta: float) -> void:
	_select_accum += delta
	if has_cam and _select_accum >= SELECT_INTERVAL:
		_select_accum = 0.0
		reselect(instances, cam_world)
	prewarm_one()
	for iid in models.keys():
		if not instances.has(iid):
			detach(iid)
			continue
		_update_model(iid, instances[iid], delta)


## Range check: attach models to the nearest creatures, detach the rest.
func reselect(instances: Dictionary, cam_world: Vector3) -> void:
	var cands: Array = []
	var limit := MODEL_RANGE_M + HYSTERESIS_M
	for iid in instances:
		var inst: Dictionary = instances[iid]
		if inst["state"] == "dead" and not models.has(iid):
			continue
		var d: float = cam_world.distance_to(inst["position"])
		var cid := str(inst["creature_id"])
		if d > limit:
			if not _templates.has(cid):
				_warm_queue[cid] = true
			continue
		# A type with no usable model keeps its box and must not take a slot from one that has a model.
		if not models.has(iid) and _template(cid) == null:
			continue
		cands.append([iid, d])
	var keep := select_ids(cands, models, MODEL_RANGE_M, HYSTERESIS_M, max_models)
	var keep_set := {}
	for iid in keep:
		keep_set[iid] = true
	for iid in models.keys():
		if not keep_set.has(iid):
			detach(iid)
	for iid in keep:
		if not models.has(iid):
			attach(iid, instances[iid])


## Build at most one queued template (see `_warm_queue`). Returns the type built, or "" when none was due.
func prewarm_one() -> String:
	for cid in _warm_queue.keys():
		_warm_queue.erase(cid)
		if _templates.has(cid):
			continue
		_template(str(cid))
		return str(cid)
	return ""


## Give `iid` a model. False (the box stays) when its type has no usable model.
func attach(iid: String, inst: Dictionary) -> bool:
	if models.has(iid):
		return true
	var cid: String = inst["creature_id"]
	var tpl: Variant = _template(cid)
	if tpl == null:
		return false
	var node := (tpl["scene"] as PackedScene).instantiate() as Node3D
	if node == null:
		return false
	node.name = "Model_%s" % iid.validate_node_name()
	node.set_meta("creature_id", cid)
	for m in node.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_override = tpl["material"]
		CharacterMaterial.apply_instance(m as GeometryInstance3D, tpl["index"])
	var player := node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var tree := RigTree.build_tree(player)
	node.add_child(tree)
	tree.anim_player = tree.get_path_to(player)
	tree.active = true
	add_child(node)
	var pos: Vector3 = inst["position"]
	node.transform = Transform3D(Basis(), pos)
	models[iid] = {"node": node, "tree": tree, "speed": 0.0, "last_pos": pos, "yaw": 0.0,
		"loco": -1, "dead_at": -1.0, "state": str(inst["state"]), "swing_left": 0.0, "swing": 0, "swing_seen": 0}
	model_attached.emit(iid)
	return true


## Drop a model without the detach signal (its instance is going away, so no box comes back).
func detach_silently(iid: String) -> void:
	if not models.has(iid):
		return
	var m: Dictionary = models[iid]
	models.erase(iid)
	if is_instance_valid(m["node"]):
		(m["node"] as Node).free()


func detach(iid: String) -> void:
	if not models.has(iid):
		return
	var m: Dictionary = models[iid]
	models.erase(iid)
	if is_instance_valid(m["node"]):
		(m["node"] as Node).free()
	model_detached.emit(iid)


func _update_model(iid: String, inst: Dictionary, delta: float) -> void:
	var m: Dictionary = models[iid]
	var pos: Vector3 = inst["position"]
	var state: String = inst["state"]
	var last: Vector3 = m["last_pos"]
	if m["state"] == "dead" and state != "dead":
		# Leaving death is a respawn: the body was put back at its spawn point, however near, so
		# the move is not a run and the model does not turn toward it.
		last = pos
		m["speed"] = 0.0
	m["state"] = state
	var flat := Vector3(pos.x - last.x, 0.0, pos.z - last.z)
	if flat.length() > TELEPORT_JUMP_M:
		m["speed"] = 0.0
		flat = Vector3.ZERO
	elif delta > 0.0:
		var inst_speed := flat.length() / delta
		m["speed"] = lerpf(float(m["speed"]), inst_speed, minf(1.0, delta * 14.0))
	m["last_pos"] = pos
	if flat.length() > 0.0 and float(m["speed"]) >= FACE_SPEED and state != "dead":
		m["yaw"] = yaw_for_direction(flat.normalized())
	var node: Node3D = m["node"]
	node.transform = Transform3D(Basis(Vector3.UP, float(m["yaw"])), pos)
	if state == "dead":
		if float(m["dead_at"]) < 0.0:
			m["dead_at"] = 0.0
		m["dead_at"] = float(m["dead_at"]) + delta
		if float(m["dead_at"]) >= CORPSE_SECONDS:
			detach(iid)
			return
	else:
		m["dead_at"] = -1.0
	var s := loco_state(state, float(m["speed"]))
	var tree: AnimationTree = m["tree"]
	# A swing holds the Attack node for its clip's length whatever the creature is doing, and a new one
	# restarts it, so every hit of a round shows.
	if float(m["swing_left"]) > 0.0 and state != "dead":
		m["swing_left"] = float(m["swing_left"]) - delta
		s = Locomotion.State.ATTACK
	if int(m["swing"]) != int(m["swing_seen"]):
		m["swing_seen"] = m["swing"]
		var playback: Object = tree.get(RigTree.PLAYBACK_PARAM)
		if state != "dead" and playback != null and tree.get_meta("travel_node", "") == "Attack":
			playback.start("Attack")
			tree.set_meta("swing_restarts", int(tree.get_meta("swing_restarts", 0)) + 1)
	if s != int(m["loco"]):
		m["loco"] = s
		RigTree.travel_once(tree, tree.get(RigTree.PLAYBACK_PARAM), RigTree.node_for_state(s))
	RigTree.apply_motion(tree, float(m["speed"]), blend_for_speed(float(m["speed"])))


## The packed rig and material for a creature type, built once. Null (with one warning per type)
## when the manifest lists no model or it fails to parse.
func _template(cid: String) -> Variant:
	if _templates.has(cid):
		return _templates[cid]
	_templates[cid] = null
	var key: String = AssetOverlay.creature_model_key(cid)
	if not AssetOverlay.has_key("meshes", key):
		_warn_type(cid, "no model %s in the manifest" % key)
		return null
	var root := AssetOverlay.load_rig_scene(key)
	if root == null:
		_warn_type(cid, "model %s failed to load" % key)
		return null
	var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		root.free()
		_warn_type(cid, "model %s has no AnimationPlayer" % key)
		return null
	# Loop modes (death plays once and holds its last pose); the clip resources are shared by every instance.
	RigTree.prepare_library(player)
	var scene := PackedScene.new()
	var err := scene.pack(root)
	root.free()
	if err != OK:
		_warn_type(cid, "model %s could not be packed" % key)
		return null
	var colors := _palette_colors()
	var mat := CharacterMaterial.creature_material(colors)
	var base := "textures/creatures/%s" % cid
	CharacterMaterial.bind_rig_textures(mat, AssetOverlay.load_texture(base + ".png.raw"),
		AssetOverlay.load_texture(base + "_color_mask.png.raw"), AssetOverlay.load_texture(base + "_channel.png.raw"))
	var tint: Color = tint_of.call(cid) if tint_of.is_valid() else Color.WHITE
	var tpl := {"scene": scene, "material": mat, "index": _nearest_index(colors, tint)}
	_templates[cid] = tpl
	return tpl


func _warn_type(cid: String, why: String) -> void:
	if warned_types.has(cid):
		return
	warned_types[cid] = true
	Diag.warn("[CreatureVisuals] %s: %s; keeping the box" % [cid, why])


func _palette_colors() -> Array:
	if _palette.is_empty():
		var res: Resource = GameData.PALETTES.get("DefaultPalette", null)
		var entries = GameDataReader.json_field(res, "entries", []) if res != null else []
		if entries is Array:
			for hex_str in entries:
				_palette.append(Color(str(hex_str)))
		if _palette.is_empty():
			for i in 256:
				var g := float(i) / 255.0
				_palette.append(Color(g, g, g))
	return _palette


static func _nearest_index(colors: Array, tint: Color) -> int:
	var best := 0
	var best_d := INF
	for i in colors.size():
		var c: Color = colors[i]
		var d := (c.r - tint.r) * (c.r - tint.r) + (c.g - tint.g) * (c.g - tint.g) + (c.b - tint.b) * (c.b - tint.b)
		if d < best_d:
			best_d = d
			best = i
	return best
