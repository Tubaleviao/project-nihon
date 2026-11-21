extends RefCounted
## Methods moved out of `character_slice.gd` (Phase 181): the avatar's per-frame sync and the creation looks
## and nameplates. `sl` is the owning slice; each method keeps a forwarder there.

var sl: Node

## Metres above an avatar's feet its nameplate floats when it has no rig to measure (the procedural body).
const NAMEPLATE_HEIGHT := 2.3
const NAMEPLATE_FONT_SIZE := 40
const NAMEPLATE_PIXEL_SIZE := 0.005
## Phase 293 — metres between the top of a rigged head (hair included) and the nameplate's baseline.
const NAMEPLATE_CLEARANCE := 0.25

func _init(slice: Node) -> void:
	sl = slice

## Drive a live-controlled instance (the player avatar) from its controller's
## per-frame state: position/facing sync, locomotion state, and an approximate
## foot-IK vertical offset (characters.md §37 — hip-height adjustment only, no
## per-leg bone solver). `horizontal_velocity` and `speed` are the controller's
## XZ velocity and its length; `terrain_height` is a Callable(Vector2)->float.
## Foot targets are stashed as root metadata ("foot_ik_l"/"foot_ik_r") for
## later consumers (e.g. a future real IK solver) instead of being discarded.
func sync_player_avatar(
	instance_id: String,
	position: Vector3,
	horizontal_velocity: Vector3,
	velocity_y: float,
	grounded: bool,
	delta: float,
	terrain_height: Callable,
	scene_position: Variant = null
) -> void:
	if not sl._instances.has(instance_id):
		return
	var inst: Dictionary = sl._instances[instance_id]
	var root: Node3D = inst["root"]
	var rig = inst["rig"]
	var props: Dictionary = inst["appearance"].get("proportions", {})
	var landmarks: Dictionary = sl.SkeletonRig.compute_landmarks(rig.get_body_shape_coefficients(), props)

	# Turning — rotate toward the horizontal movement direction at the rig's
	# turnSpeed (radians/sec), rather than snapping to face it instantly.
	var speed: float = Vector2(horizontal_velocity.x, horizontal_velocity.z).length()
	if speed > 0.05:
		# The character's forward (face, -Z) must point along the velocity. A bare
		# atan2(vx, vz) aligns +Z with velocity, which faces the character's BACK
		# forward (walking backwards). Negate both args so -Z tracks velocity.
		var target_yaw := atan2(-horizontal_velocity.x, -horizontal_velocity.z)
		root.rotation.y = rotate_toward(root.rotation.y, target_yaw, rig.get_turn_speed() * delta)

	# Approximate foot IK — sample the surface under both feet at the controller's
	# XZ position and pull the whole body up/down to the higher foot's surface
	# height, instead of leaving the avatar floating over slopes/stairs or sinking
	# into them (no per-leg bone solver — §37).
	#
	# The rig root sits at the FEET: every body part is placed at
	# `landmarks["hip_y"]` ABOVE it (`_make_avatar`), so the root's Y is the
	# ground surface itself. The old expression subtracted `landmarks["hip_y"]`
	# here — the LOCAL hip offset, read off the landmarks dict where the foot
	# targets' own WORLD hip ordinate used to carry the same key name
	# (`compute_foot_targets` now returns `hip_world_y`) — which dropped the
	# whole avatar ~0.9 below the surface it was standing on.
	var feet: Dictionary = sl.SkeletonRig.compute_foot_targets(
		terrain_height,
		position,
		landmarks["hip_y"],
		landmarks["leg_reach"],
		landmarks["foot_side"],
		0.0
	)
	var ground_y: float = maxf(feet["foot_l"].y, feet["foot_r"].y)
	var world_pos := Vector3(position.x, ground_y, position.z)
	root.position = world_pos + sl._origin.value
	# Far from the origin `position` (a float32 world position) is quantised to metres, which would
	# step the avatar along in jumps: when the caller has the body's own scene position, the avatar
	# stands on that instead (XZ exact, Y the foot height).
	if scene_position is Vector3:
		var sp: Vector3 = scene_position
		root.position = Vector3(sp.x, ground_y + sl._origin.value.y, sp.z)
	root.set_meta("foot_ik_l", feet["foot_l"])
	root.set_meta("foot_ik_r", feet["foot_r"])

	inst["position"] = world_pos
	sl.update_locomotion(instance_id, speed, grounded, velocity_y, delta)
	# Phase 159 — a seated body rides the seat's height. Phase 196: after the locomotion step, so the frame a
	# pose ends on is already drawn on the ground (no one-frame pop at the seat height).
	sl._m2.apply_seat_lift(inst, root)
	if inst.has("anim_tree") and is_instance_valid(inst["anim_tree"]):
		sl.RigTree.drive(inst["anim_tree"], inst["locomotion"])

	# Procedural locomotion animation — advance the walk phase by distance
	# travelled and swing the limb pivots. The blend weight (0 idle → 1 run)
	# scales the swing amplitude, so the character settles to a rest pose as it
	# slows to a stop instead of freezing mid-stride.
	var phase: float = inst.get("anim_phase", 0.0)
	phase = fmod(phase + speed * delta * sl.ANIM_FREQ, TAU)
	inst["anim_phase"] = phase
	sl._animate_limbs(inst, phase, inst["locomotion"].get_blend_weight() * sl.RUN_SWING_AMPLITUDE)

## The appearance recipe of a look: the gender's chibi preset with the chosen hair and colour, or the default
## traveller when the look carries no choices (a player who skipped or has not created yet).
func creation_recipe(look: Dictionary) -> Dictionary:
	var res: Resource = sl.CreationRules.preset(str(look.get("gender", ""))) if look.has("hair") else null
	if res == null:
		res = GameData.APPEARANCES.get(sl.DEFAULT_APPEARANCE, null)
		return sl._appearance_to_recipe(res) if res != null else {}
	var recipe: Dictionary = sl._appearance_to_recipe(res)
	recipe["hair"] = str(look["hair"])
	recipe["hairColor"] = int(look["hairColor"])
	return recipe

## Rebuild an instance in a look, keeping what it wears and its nameplate. False for an unknown instance.
func apply_look(instance_id: String, look: Dictionary) -> bool:
	if not sl._instances.has(instance_id):
		return false
	var recipe := creation_recipe(look)
	recipe["equipment"] = (sl._instances[instance_id]["appearance"] as Dictionary).get("equipment", {}).duplicate(true)
	var plate := str(sl._instances[instance_id].get("nameplate", ""))
	if not sl.apply_appearance(instance_id, recipe):
		return false
	if plate != "":
		set_nameplate(instance_id, plate)
	return true

## Show `text` above an instance (a Label3D that always faces the camera). "" removes it.
func set_nameplate(instance_id: String, text: String) -> void:
	if not sl._instances.has(instance_id):
		return
	var inst: Dictionary = sl._instances[instance_id]
	var root: Node3D = inst["root"]
	var label := root.get_node_or_null("Nameplate") as Label3D
	inst["nameplate"] = text
	if text == "":
		if label != null:
			root.remove_child(label)
			label.free()
		return
	if label == null:
		label = Label3D.new()
		label.name = "Nameplate"
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.font_size = NAMEPLATE_FONT_SIZE
		label.pixel_size = NAMEPLATE_PIXEL_SIZE
		label.outline_size = 8
		root.add_child(label)
	label.text = text
	place_nameplate(instance_id)

## Phase 293 — the nameplate sits above the rig's head (the head bone, or the top of the head and hair meshes when
## they reach higher), not at a fixed height; a body without a rig keeps NAMEPLATE_HEIGHT. Also shows the label
## again: attaching a rig hides every child of the instance root.
func place_nameplate(instance_id: String) -> void:
	if not sl._instances.has(instance_id):
		return
	var inst: Dictionary = sl._instances[instance_id]
	var label := (inst["root"] as Node3D).get_node_or_null("Nameplate") as Label3D
	if label == null:
		return
	label.visible = true
	label.position = Vector3(0.0, nameplate_height(inst), 0.0)

## Height of an instance's nameplate above its feet (root space).
func nameplate_height(inst: Dictionary) -> float:
	var rig_node: Variant = inst.get("rig_node", null)
	if rig_node == null or not is_instance_valid(rig_node):
		return NAMEPLATE_HEIGHT
	var root: Node3D = inst["root"]
	var top := -INF
	var skels: Array = (rig_node as Node).find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty():
		var skel := skels[0] as Skeleton3D
		var head := skel.find_bone("Head")
		if head >= 0:
			top = (_to_root(skel, root) * skel.get_bone_global_rest(head).origin).y
	for n in (rig_node as Node).find_children("*", "MeshInstance3D", true, false):
		var m := n as MeshInstance3D
		if m.mesh != null:
			top = maxf(top, (_to_root(m, root) * m.mesh.get_aabb()).end.y)
	return NAMEPLATE_HEIGHT if top == -INF else top + NAMEPLATE_CLEARANCE

## The transform from `node`'s space to `root`'s, by walking the parents (no scene tree needed).
static func _to_root(node: Node, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t

## Put `peer_id`'s stored look (if any) on its avatar instance: the body (rebuilt once per look) and the nameplate.
func dress_peer(peer_id: int, instance_id: String) -> void:
	var look: Dictionary = sl._peer_looks.get(peer_id, {})
	if look.is_empty():
		return
	var body := look.duplicate()
	body.erase("title")   # a title changes the nameplate only, never the body
	var key := JSON.stringify(body)
	if str((sl._instances.get(instance_id, {}) as Dictionary).get("look_key", "")) != key:
		apply_look(instance_id, look)
		if sl._instances.has(instance_id):
			sl._instances[instance_id]["look_key"] = key
	set_nameplate(instance_id, sl.TitleRules.nameplate(str(look.get("name", "")), str(look.get("title", ""))))

## Phase 293 — the one builder of a player body from a look dictionary (`CreationRules.look`: name, gender, hair,
## hairColor; {} or a look without hair is the default player body): the look's recipe on the player rig its body
## type picks (Phase 286), hair on the head (Phase 284). The client's own body at boot and every remote player are
## built here; the Character window's doll dresses the same recipe through `AvatarBuilder.build`. "" on failure.
func build_player_body(look: Dictionary, pos: Vector3) -> String:
	var recipe := creation_recipe(look)
	if recipe.is_empty():
		return ""
	var iid: String = sl.create_character_from_recipe(recipe, pos)
	if iid != "":
		sl.attach_default_rig(iid)
	return iid
