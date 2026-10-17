extends Node3D
## CreatureVisuals (Phase 143) — rigged, animated models for the creatures near the viewer.
##
## Every creature has a box in `CreatureSlice`'s shared MultiMesh pool. Within `MODEL_RANGE_M` of
## the viewer, up to `MAX_MODELS` of them (the nearest) are drawn as their rigged model instead,
## and the slice hides their pool instance. A model is released only past `MODEL_RANGE_M +
## MODEL_HYSTERESIS_M`, so a creature walking along the edge does not swap back and forth.
##
## Models come from `AssetOverlay.creature_model_key(<Entity>)`, loaded once per creature type
## (`load_rig_scene`) and duplicated per creature. A type whose key is not in the manifest, or whose
## scene fails to load or has no AnimationPlayer, keeps its box and warns once. The production pack
## overrides the same keys, so real meshes drop in with no code change.
##
## Clips are picked from the creature's synced state and its speed (`clip_for`), so a client drives
## them from the host's state deltas and the wire is unchanged. `death` plays once and holds.
##
## Like the pool, this node holds world positions and is moved by `shift_scene` on a rebase. The
## slice builds it only when `render_visuals` is true, so a dedicated server builds no model nodes.

const RigTree := preload("res://src/character/rig_tree.gd")
const CharacterMaterial := preload("res://src/character/character_material.gd")
const GameDataReader := preload("res://src/core/game_data_reader.gd")
const AssetOverlayScript := preload("res://src/core/asset_overlay.gd")
const Diag := preload("res://src/core/diag.gd")

## A creature closer than this to the viewer (m) gets a model.
const MODEL_RANGE_M := 40.0
## A modelled creature keeps its model until it is this much farther than `MODEL_RANGE_M`.
const MODEL_HYSTERESIS_M := 6.0
## Models alive at once; past it the nearest creatures win and the rest stay boxes.
const MAX_MODELS := 24

## The seven clips every creature rig carries (assets/README.md).
const CLIPS := ["idle", "walk", "run", "fall", "land", "attack", "death"]
## Clips that cycle; every other clip plays once and holds its last pose.
const LOOPING_CLIPS := ["idle", "walk", "run"]
## Above this speed (m/s) a creature plays its moving clip.
const MOVING_SPEED := 0.3
## Above this speed (m/s) a walk becomes a run.
const RUN_SPEED := 3.0
## Cross-fade between clips (s).
const BLEND_SECS := 0.15

## Per creature state: [clip when still, clip when moving]. Every state of the fabric
## `creatureStateMachine` is listed; the suite checks that against each creature resource.
const STATE_CLIPS := {
	"idle":       ["idle", "walk"],
	"alert":      ["idle", "walk"],
	"aggressive": ["attack", "run"],
	"fleeing":    ["idle", "run"],
	"dead":       ["death", "death"],
	"respawning": ["idle", "idle"],
}

## Creature rigs face -Z (the private art and the placeholders). Facing turns this onto the
## movement direction, which is what reconciles the model with the fabric `restPose` +Z head:
## the head ends up in front of the creature whatever axis the skeleton was authored along.
const MODEL_FORWARD := Vector3(0.0, 0.0, -1.0)

## The palette the character shader reads (the same one avatars use).
const PALETTE_KEY := "DefaultPalette"

## creature_id -> template Node3D (outside the tree), or null when the type has no usable model.
var _templates: Dictionary = {}
## creature_id -> the per-type ShaderMaterial (its own body sheets, shared by every instance).
var _materials: Dictionary = {}
## instance_id -> { "node": Node3D, "player": AnimationPlayer, "clip": String, "last": Vector3 }
var _models: Dictionary = {}
var _palette: Array = []


## The clip a creature in `state` moving at `speed` m/s plays. An unknown state plays idle.
static func clip_for(state: String, speed: float) -> String:
	var pair: Array = STATE_CLIPS.get(state, ["idle", "walk"])
	if speed <= MOVING_SPEED:
		return pair[0]
	var clip: String = pair[1]
	if clip == "walk" and speed > RUN_SPEED:
		return "run"
	return clip


## Whether a creature `dist` metres away should have a model, given whether it has one now.
static func wants_model(has_model: bool, dist: float) -> bool:
	if has_model:
		return dist <= MODEL_RANGE_M + MODEL_HYSTERESIS_M
	return dist < MODEL_RANGE_M


## The basis that turns a model's -Z forward onto `dir` (horizontal). A zero direction is identity.
static func facing_basis(dir: Vector3) -> Basis:
	var flat := Vector2(dir.x, dir.z)
	if flat.length_squared() < 1e-8:
		return Basis()
	return Basis(Vector3.UP, atan2(-flat.x, -flat.y))


## Whether `instance_id` is drawn as a model right now.
func has_model(instance_id: String) -> bool:
	return _models.has(instance_id)


func model_count() -> int:
	return _models.size()


## The model node of `instance_id`, or null.
func model_node(instance_id: String) -> Node3D:
	var rec: Variant = _models.get(instance_id, null)
	return rec["node"] if rec != null else null


## The clip `instance_id`'s model is playing ("" without a model).
func model_clip(instance_id: String) -> String:
	var rec: Variant = _models.get(instance_id, null)
	return str(rec["clip"]) if rec != null else ""


## Whether `creature_id` has a usable model (loads it on first ask).
func has_model_for(creature_id: String) -> bool:
	return _template_for(creature_id) != null


## Decide which creatures are modelled, then place and animate every model. `instances` is the
## slice's live instance records (`instances_view()`), `viewer` the viewer's world position.
## Returns { "added": [ids], "removed": [ids] } so the slice can hide or restore their boxes.
func update(instances: Array, viewer: Vector3, delta: float) -> Dictionary:
	var eligible: Array = []   # [dist, instance_id]
	var by_id: Dictionary = {}
	for inst in instances:
		var iid: String = str(inst["instance_id"])
		by_id[iid] = inst
		var dist: float = (inst["position"] as Vector3).distance_to(viewer)
		var has := _models.has(iid)
		# A creature already dead when it comes into range stays a (hidden) box: there is nothing
		# to show, and its death clip would start halfway through a fall nobody saw.
		if not has and str(inst["state"]) == "dead":
			continue
		if not wants_model(has, dist):
			continue
		if not has and _template_for(str(inst["creature_id"])) == null:
			continue
		eligible.append([dist, iid])
	eligible.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var keep: Dictionary = {}
	for i in mini(eligible.size(), MAX_MODELS):
		keep[eligible[i][1]] = true
	var removed: Array = []
	for iid in _models.keys():
		if not keep.has(iid):
			release(iid)
			if by_id.has(iid):
				removed.append(iid)
	var added: Array = []
	for iid in keep:
		if not _models.has(iid) and _attach(iid, by_id[iid]):
			added.append(iid)
	for iid in _models:
		_drive(_models[iid], by_id[iid], delta)
	return { "added": added, "removed": removed }


## Free `instance_id`'s model (despawn, or out of range). Safe when it has none.
func release(instance_id: String) -> void:
	var rec: Variant = _models.get(instance_id, null)
	if rec == null:
		return
	_models.erase(instance_id)
	var node: Node3D = rec["node"]
	if is_instance_valid(node):
		remove_child(node)
		node.free()


## Shift every model with the scene origin (a client rebase), like the box pool.
func shift_scene(shift: Vector3) -> void:
	position += shift


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for cid in _templates:
			var t: Variant = _templates[cid]
			if t != null and is_instance_valid(t):
				(t as Node).free()
		_templates.clear()


func _attach(instance_id: String, inst: Dictionary) -> bool:
	var cid: String = str(inst["creature_id"])
	var template: Node3D = _template_for(cid)
	if template == null:
		return false
	var node := template.duplicate() as Node3D
	node.name = instance_id
	var player := node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	add_child(node)
	var pos: Vector3 = inst["position"]
	node.position = pos
	_models[instance_id] = { "node": node, "player": player, "clip": "", "last": pos }
	return true


## Place, face and animate one model from its instance record.
func _drive(rec: Dictionary, inst: Dictionary, delta: float) -> void:
	var node: Node3D = rec["node"]
	var pos: Vector3 = inst["position"]
	var step: Vector3 = pos - (rec["last"] as Vector3)
	rec["last"] = pos
	var speed: float = Vector2(step.x, step.z).length() / delta if delta > 0.0 else 0.0
	node.position = pos
	if speed > MOVING_SPEED:
		node.basis = facing_basis(step)
	var clip := clip_for(str(inst["state"]), speed)
	if clip != rec["clip"]:
		rec["clip"] = clip
		var player: AnimationPlayer = rec["player"]
		if player != null and player.is_inside_tree():
			RigTree.play_clip(player, clip, BLEND_SECS)


## The type's template, loaded on first use. Null (one warning per type) when it has no model.
func _template_for(creature_id: String) -> Node3D:
	if _templates.has(creature_id):
		return _templates[creature_id]
	var template := _load_template(creature_id)
	_templates[creature_id] = template
	return template


func _load_template(creature_id: String) -> Node3D:
	var key := AssetOverlayScript.creature_model_key(creature_id)
	if not AssetOverlay.has_key("meshes", key):
		Diag.warn("[CreatureVisuals] no model %s for %s; it keeps its box" % [key, creature_id])
		return null
	var root := AssetOverlay.load_rig_scene(key)
	if root == null:
		Diag.warn("[CreatureVisuals] model %s for %s failed to load; it keeps its box" % [key, creature_id])
		return null
	var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		Diag.warn("[CreatureVisuals] model %s has no AnimationPlayer; %s keeps its box" % [key, creature_id])
		root.free()
		return null
	for lib_name in player.get_animation_library_list():
		var lib := player.get_animation_library(lib_name)
		for clip in lib.get_animation_list():
			lib.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if str(clip) in LOOPING_CLIPS else Animation.LOOP_NONE
	_dress(root, creature_id)
	return root


## Bind the character shader with the type's three body sheets, and the palette index nearest
## the type's box tint as its base colour (the public masks are black, so that is its colour).
func _dress(root: Node, creature_id: String) -> void:
	var mat := CharacterMaterial.creature_material(_palette_colors())
	CharacterMaterial.bind_rig_textures(mat,
		AssetOverlay.load_texture("textures/creatures/%s.png.raw" % creature_id),
		AssetOverlay.load_texture("textures/creatures/%s_color_mask.png.raw" % creature_id),
		AssetOverlay.load_texture("textures/creatures/%s_channel.png.raw" % creature_id))
	_materials[creature_id] = mat
	var base := nearest_palette_index(_palette_colors(), tint_for(creature_id))
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.material_override = mat
		CharacterMaterial.apply_instance(mesh, base)


## The index of the colour in `palette` nearest `c` (0 for an empty palette).
static func nearest_palette_index(palette: Array, c: Color) -> int:
	var best := 0
	var best_d := INF
	for i in palette.size():
		var p: Color = palette[i]
		var d := Vector3(p.r - c.r, p.g - c.g, p.b - c.b).length_squared()
		if d < best_d:
			best_d = d
			best = i
	return best


## The box tint of a creature type; its model takes the nearest palette colour.
static func tint_for(creature_id: String) -> Color:
	match creature_id:
		"ForestBoar":     return Color(0.55, 0.35, 0.20)
		"GraywolfPack":   return Color(0.42, 0.42, 0.48)
		"SteppeBison":    return Color(0.60, 0.45, 0.25)
		"RidgeHawk":      return Color(0.70, 0.55, 0.30)
		"LavaSlug":       return Color(0.85, 0.25, 0.10)
		"CinderGargoyle": return Color(0.30, 0.15, 0.10)
		"GlimmerFox":     return Color(0.90, 0.80, 0.40)
		"VeilStalker":    return Color(0.25, 0.20, 0.35)
		"VoidSerpent":    return Color(0.10, 0.05, 0.25)
		"RiftWarden":     return Color(0.50, 0.00, 0.50)
		_:                return Color(0.80, 0.80, 0.80)


func _palette_colors() -> Array:
	if _palette.is_empty():
		var res: Resource = GameData.PALETTES.get(PALETTE_KEY, null)
		var entries = GameDataReader.json_field(res, "entries", []) if res != null else []
		if entries is Array:
			for hex_str in entries:
				_palette.append(Color(str(hex_str)))
	return _palette
