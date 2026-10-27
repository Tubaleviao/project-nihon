extends RefCounted
## Methods moved verbatim out of `character_slice.gd` (Phase 154). `sl` is the owning slice; each moved method keeps a forwarder there.

var sl: Node

## Seconds a one-shot gesture plays when the rig has no clip to measure (the procedural body).
const DEFAULT_GESTURE_SECONDS := 1.5

func _init(slice: Node) -> void:
	sl = slice

## Equip an item onto a character slot (replaces any existing equipment there).
## `item_key` is a GameData.ITEMS key; `state` is the attachment state
## (equipped/sheathed/stored/hidden). Returns true on success.
func apply_equipment(instance_id: String, slot: String, item_key: String, state: String = "equipped") -> bool:
	if not sl._instances.has(instance_id):
		return false
	var def = sl._equipment_def(item_key)
	# Reject an item that doesn't actually fit this slot — mirrors
	# deserialize_appearance()'s recipe-side guard so a caller can't force any
	# equippable item into any slot regardless of what it fits (§30).
	if def.is_empty() or str(def.get("slot", "")) != slot:
		return false

	var inst: Dictionary = sl._instances[instance_id]
	var rig = inst["rig"]
	var props: Dictionary = inst["appearance"].get("proportions", {})

	var entry = sl._normalize_equipment({
		"item": item_key,
		"state": state,
	})
	var rec: Dictionary = sl._attach_equipment(rig, slot, entry, props)
	if rec.is_empty():
		return false

	# Replace any existing mesh on the slot.
	var equipment: Dictionary = inst["equipment"]
	if equipment.has(slot):
		var old: Dictionary = equipment[slot]
		var old_node: Node3D = old.get("node", null)
		if old_node != null:
			old_node.queue_free()

	equipment[slot] = rec
	inst["parts"][slot] = { "node": rec["node"], "max_lod": int(rec["def"].get("minLodLevel", sl.MAX_LOD)) }

	# Reflect the change in the appearance recipe so persistence / visual state
	# stay consistent with the live instance.
	var app: Dictionary = inst["appearance"]
	var eq: Dictionary = app.get("equipment", {})
	eq[slot] = entry
	app["equipment"] = eq
	# The new equipment node defaults to visible; reset the early-out state so
	# _apply_lod applies the correct visibility (e.g. hides it at impostor LOD)
	# rather than skipping the freshly-built node.
	inst["lod"] = -1
	inst.erase("_hidden")
	sl._apply_lod(instance_id)
	GameBus.character_appearance_changed.emit(instance_id, app)
	return true

func _make_visual(instance_id: String, appearance: Dictionary) -> Dictionary:
	var rig = sl.SkeletonRig.new()
	rig.name = "Character_%s" % instance_id
	var parts: Dictionary = {}

	var props: Dictionary = appearance.get("proportions", {})
	var height: float = props.get("height", 1.0)
	var mass: float = props.get("bodyMass", 1.0)
	var shoulder: float = props.get("shoulderWidth", 1.0)
	var head_scale: float = props.get("headScale", 1.0)

	var skin_idx: int = int(appearance.get("skinColor", 12))
	var hair_idx: int = int(appearance.get("hairColor", 40))
	var beard_idx: int = int(appearance.get("beardColor", 40))

	# Skeleton rig (Phase 20) — build a real Skeleton3D from the fabric
	# SkeletonDefinition so the character carries a bone hierarchy. Body and head
	# are skinned to their bones (torso / legs / head) so they deform with the
	# skeleton; hair/beard stay rig-root children (placeholder details) pending
	# real skinned assets; equipment attaches to sockets through the rig.
	var skeleton_res: Resource = GameData.SKELETONS.get(str(appearance.get("skeleton", sl.DEFAULT_SKELETON)), null)
	rig.build(skeleton_res, props)
	var is_humanoid: bool = rig.get_family() == "humanoid"

	var torso_bone = sl._torso_bone(rig)
	var head_bone = rig.socket_to_bone("socket_head")
	if rig.get_bone_index(head_bone) == -1:
		head_bone = ""

	## Procedural-limb pivots for the walk/run cycle, populated by the humanoid
	## branch and left empty for non-humanoid families (which get no limb
	## animation). Stored on the instance record so sync_player_avatar can swing
	## them.
	var limb_pivots: Dictionary = {}

	if is_humanoid:
		# Humanoid placeholders use the full body-shape landmark system (torso/
		# hip/head landmarks — characters.md §37.4), which only humanoid
		# skeletons declare `bodyShapeCoefficients` for.
		var landmarks: Dictionary = sl.SkeletonRig.compute_landmarks(rig.get_body_shape_coefficients(), props)
		var torso_h: float = landmarks["torso_h"]
		var hip_y: float = landmarks["hip_y"]
		var neck_len: float = landmarks["neck_len"]
		var head_size: float = landmarks["head_size"]
		var head_y: float = landmarks["head_y"]
		var foot_side: float = landmarks["foot_side"]

		# Chest — a rounded vertical capsule (not the old flat box) so the torso
		# reads as a 3D body rather than a plate, skinned to the torso bone.
		var torso_radius: float = 0.20 * shoulder * mass
		var chest = sl._make_capsule(torso_radius, torso_h, skin_idx)
		var chest_pos = Vector3(0.0, hip_y + torso_h * 0.5, 0.0)
		rig.attach_to_bone(torso_bone, chest, chest_pos - rig.get_bone_global_rest(torso_bone))
		parts["body_chest"] = { "node": chest, "max_lod": sl.MAX_LOD }

		# Legs — a thigh hanging from a hip pivot and a shin hanging from a knee
		# pivot, so the procedural walk cycle can swing each leg around its local
		# X axis and bend it at the knee. Both hip pivots live under a "body_legs"
		# container so hide/LOD toggle both at once (§16 BodyLegs); each foot rides
		# its knee pivot so it follows the shin.
		var leg_radius: float = 0.09 * mass * shoulder
		var legs_container = Node3D.new()
		legs_container.name = "Legs"
		rig.add_child(legs_container)
		for side in [["leg_l", -1.0], ["leg_r", 1.0]]:
			var pivot_key: String = side[0]
			var side_sign: float = side[1]
			var leg = sl._make_limb(Vector3(foot_side * side_sign, hip_y, 0.0), hip_y, leg_radius, skin_idx)
			legs_container.add_child(leg["pivot"])
			limb_pivots[pivot_key] = leg["pivot"]
			limb_pivots[pivot_key.replace("leg", "knee")] = leg["joint"]
			var foot = sl._make_box(Vector3(0.14 * shoulder, 0.08, 0.26), skin_idx)
			foot.position = Vector3(0.0, -leg["lower_length"] + 0.04, -0.10)
			leg["joint"].add_child(foot)
		parts["body_legs"] = { "node": legs_container, "max_lod": sl.MAX_LOD }

		# Arms — one capsule per arm hanging from a shoulder pivot (at the top of
		# the torso, not the chest) so they read as attached to the shoulders and
		# swing in opposition to the legs during the walk cycle.
		var arm_radius: float = 0.08 * mass
		var arm_len: float = 0.55 * height * props.get("armLength", 1.0)
		var arm_side: float = 0.20 * shoulder * mass
		var shoulder_y: float = hip_y + torso_h - 0.06
		for side in [["arm_l", -1.0], ["arm_r", 1.0]]:
			var pivot_key: String = side[0]
			var side_sign: float = side[1]
			var arm = sl._make_limb(Vector3(arm_side * side_sign, shoulder_y, 0.0), arm_len, arm_radius, skin_idx)
			rig.add_child(arm["pivot"])
			limb_pivots[pivot_key] = arm["pivot"]
			limb_pivots[pivot_key.replace("arm", "elbow")] = arm["joint"]
			parts[pivot_key] = { "node": arm["pivot"], "max_lod": sl.MAX_LOD }

		# Neck — a short capsule bridging the torso and head, so the head reads
		# as sitting on a neck (the Neck bone spans this gap) rather than fused
		# to the torso.
		var neck_radius: float = 0.06 * mass
		var neck = sl._make_capsule(neck_radius, neck_len, skin_idx)
		neck.position = Vector3(0.0, hip_y + torso_h + neck_len * 0.5, 0.0)
		rig.add_child(neck)
		parts["neck"] = { "node": neck, "max_lod": sl.MAX_LOD }

		# Head — a rounded ovoid (slightly taller than wide) sitting on the neck.
		var head_radius: float = head_size * 0.55
		var head_height: float = head_size * 1.25
		var head = sl._make_sphere(head_radius, head_height, skin_idx)
		var head_pos = Vector3(0.0, head_y, 0.0)
		rig.attach_to_bone(head_bone, head, head_pos - rig.get_bone_global_rest(head_bone))
		parts["head"] = { "node": head, "max_lod": sl.MAX_LOD }

		# Hair (independent component — §13) caps the top of the head.
		var hair_id: String = str(appearance.get("hair", "none"))
		if hair_id != "none" and hair_id != "":
			var hair = sl._make_box(Vector3(head_size * 1.05, head_size * 0.4, head_size * 1.05), hair_idx)
			hair.position = Vector3(0.0, head_y + head_height * 0.5 + head_size * 0.1, 0.0)
			rig.add_child(hair)
			parts["hair"] = { "node": hair, "max_lod": 0 }

		# Beard (independent component — §14) hangs on the front of the chin
		# (the face side is -Z), not inside the head.
		var beard_id: String = str(appearance.get("beard", "none"))
		if beard_id != "none" and beard_id != "":
			var beard = sl._make_box(Vector3(head_size * 0.7, head_size * 0.5, head_size * 0.25), beard_idx)
			beard.position = Vector3(0.0, head_y - head_height * 0.35, -head_radius - head_size * 0.15)
			rig.add_child(beard)
			parts["beard"] = { "node": beard, "max_lod": 0 }
	else:
		# Non-humanoid families (quadruped/bird/serpent) don't declare
		# bodyShapeCoefficients and don't share the humanoid torso/hip/head
		# layout, so use a single generic body box and a generic head box,
		# sized from height/mass/headScale only and centered on their bone
		# (zero bone-local offset) rather than the humanoid landmark math.
		var body = sl._make_box(Vector3(0.5 * mass, height * 0.5, 0.5 * mass), skin_idx)
		rig.attach_to_bone(torso_bone, body, Vector3.ZERO)
		parts["body"] = { "node": body, "max_lod": sl.MAX_LOD }

		var nh_head_size: float = 0.25 * head_scale
		var head = sl._make_box(Vector3(nh_head_size, nh_head_size, nh_head_size), skin_idx)
		rig.attach_to_bone(head_bone, head, Vector3.ZERO)
		parts["head"] = { "node": head, "max_lod": sl.MAX_LOD }

	# Equipment — socket attachment with deformation modes (Phase 20 §10).
	var equipment: Dictionary = appearance.get("equipment", {})
	var eq_records: Dictionary = {}
	for slot in equipment:
		var entry: Dictionary = equipment[slot]
		var rec: Dictionary = sl._attach_equipment(rig, str(slot), entry, props)
		if rec.is_empty():
			continue
		eq_records[str(slot)] = rec
		parts[str(slot)] = { "node": rec["node"], "max_lod": int(rec["def"].get("minLodLevel", sl.MAX_LOD)) }

	var locomotion = sl.Locomotion.new()

	# Impostor billboard (Phase 23) — a camera-facing quad tinted to the
	# character's dominant (skin) palette colour, shown in place of the full rig
	# at LOD ≥ IMPOSTOR_LOD. This is a coloured-quad placeholder; the real
	# pre-baked sprite impostor is deferred (ROADMAP Phase 23).
	var impostor = sl._make_impostor(rig, appearance, props)

	return {
		"root":        rig,
		"rig":         rig,
		"parts":       parts,
		"equipment":   eq_records,
		"locomotion":  locomotion,
		"impostor":    impostor,
		"limb_pivots": limb_pivots,
	}

## Play an attack swing on an instance. `clip` is the variant ("" for the one the main hand picks); the
## hold time follows the clip that will actually play (a variant the rig lacks plays `attack`).
func trigger_attack(instance_id: String, clip: String = "") -> void:
	if not sl._instances.has(instance_id):
		return
	var inst: Dictionary = sl._instances[instance_id]
	if clip == "":
		clip = attack_clip_of(instance_id)
	var lengths: Dictionary = inst.get("swing_lengths", {})
	var played: String = clip if lengths.has(clip) else sl.RigTree.ATTACK_DEFAULT
	inst["locomotion"].trigger_attack(clip, float(lengths.get(played, -1.0)))

## Phase 159 — see `CharacterSlice.trigger_gesture`.
func trigger_gesture(instance_id: String, clip: String, hold: bool, seat_lift: float = 0.0) -> bool:
	if not sl._instances.has(instance_id):
		return false
	var inst: Dictionary = sl._instances[instance_id]
	var loco = inst["locomotion"]
	if loco.get_state() == sl.Locomotion.State.DEATH:
		return false
	var lengths: Dictionary = inst["anim_tree"].get_meta("clip_lengths", {}) if inst.has("anim_tree") and is_instance_valid(inst["anim_tree"]) else {}
	loco.trigger_gesture(clip, hold, float(lengths.get(clip, DEFAULT_GESTURE_SECONDS)))
	inst["seat_lift"] = seat_lift
	_settle_lift(inst)
	return true

## Raise a seated body's root by its seat lift; any state but a gesture drops the lift. Called right after the
## root was placed on the ground, so the whole lift is added.
func apply_seat_lift(inst: Dictionary, root: Node3D) -> void:
	if not inst["locomotion"].is_gesturing():
		inst["seat_lift"] = 0.0
	var lift := float(inst.get("seat_lift", 0.0))
	root.position.y += lift
	inst["lift_applied"] = lift

## Move the root by the change in lift since it was last applied, so a pose started or ended while the body
## stands still sits down or stands up at once instead of at the next position report.
func _settle_lift(inst: Dictionary) -> void:
	var node: Variant = inst.get("root")
	var lift := float(inst.get("seat_lift", 0.0))
	if node is Node3D:
		(node as Node3D).position.y += lift - float(inst.get("lift_applied", 0.0))
	inst["lift_applied"] = lift

## Step the locomotion machine of an avatar whose gesture would otherwise never advance (a remote peer's:
## only the local body runs `sync_player_avatar`). A no-op for a body that is not gesturing.
func advance_gesture(instance_id: String, delta: float) -> void:
	if not sl._instances.has(instance_id):
		return
	var inst: Dictionary = sl._instances[instance_id]
	if not inst["locomotion"].is_gesturing():
		return
	sl.update_locomotion(instance_id, 0.0, true, 0.0, delta)
	if not inst["locomotion"].is_gesturing():
		inst["seat_lift"] = 0.0
		_settle_lift(inst)
	if inst.has("anim_tree") and is_instance_valid(inst["anim_tree"]):
		sl.RigTree.drive(inst["anim_tree"], inst["locomotion"])

func end_gesture(instance_id: String) -> void:
	if not sl._instances.has(instance_id):
		return
	var inst: Dictionary = sl._instances[instance_id]
	inst["locomotion"].end_gesture()
	inst["seat_lift"] = 0.0
	_settle_lift(inst)
	# A remote avatar's tree has no other driver, so leave the pose node here.
	if inst.has("anim_tree") and is_instance_valid(inst["anim_tree"]):
		sl.RigTree.drive(inst["anim_tree"], inst["locomotion"])

func gesture_clip_of(instance_id: String) -> String:
	if not sl._instances.has(instance_id):
		return ""
	var loco = sl._instances[instance_id]["locomotion"]
	return loco.gesture_clip if loco.is_gesturing() else ""

## The swing an instance plays by its main hand: bare hands punch, a tool (anything with a fabric
## `toolType`) uses the tool swing, any other held item swings one-handed.
func attack_clip_of(instance_id: String) -> String:
	return sl.RigTree.attack_clip_for(str(sl.get_equipment_set(instance_id).get("MainHand", "")), GameData.ITEMS)

func set_character_position(instance_id: String, pos: Vector3) -> bool:
	if not sl._instances.has(instance_id):
		return false
	var inst: Dictionary = sl._instances[instance_id]
	inst["position"] = pos
	(inst["root"] as Node3D).position = pos + sl._origin.value + Vector3(0.0, float(inst.get("seat_lift", 0.0)), 0.0)
	return true

func get_character_yaw(instance_id: String) -> Variant:
	if not sl._instances.has(instance_id):
		return null
	return (sl._instances[instance_id]["root"] as Node3D).rotation.y

func trigger_hit(instance_id: String, stagger: bool = false) -> void:
	if sl._instances.has(instance_id):
		sl._instances[instance_id]["locomotion"].trigger_hit(stagger)

## The worn set of an instance as { slot: item_key } (empty for an unknown id).
func get_equipment_set(instance_id: String) -> Dictionary:
	var out: Dictionary = {}
	if not sl._instances.has(instance_id):
		return out
	var eq: Dictionary = sl._instances[instance_id]["appearance"].get("equipment", {})
	for slot in eq:
		var entry: Variant = eq[slot]
		if entry is Dictionary:
			var item := str((entry as Dictionary).get("item", ""))
			if item != "" and str((entry as Dictionary).get("state", "equipped")) == "equipped":
				out[str(slot)] = item
	return out

## Phase 179 — a second body for the character sheet's preview, added under `parent` (the preview's viewport): the
## local avatar's appearance on the default rig (Phase 123 material), wearing what it wears, idling on the rig's own
## clip. This slice keeps no record of it (no LOD pass, no sync); the caller frees it. It is built where it will
## stay: a Skeleton3D that leaves the tree drops a PhysicalBoneSimulator3D it never frees. Null when there is no
## local avatar or the manifest lists no rig.
func build_preview(parent: Node) -> Node3D:
	var src: String = sl.get_player_character()
	if src == "" or not sl._instances.has(src):
		return null
	var pid: String = sl.create_character_from_recipe(sl.get_appearance(src), Vector3.ZERO, parent)
	if pid == "" or not sl.attach_default_rig(pid):
		sl.remove_character(pid)
		return null
	sl.apply_equipment_set(pid, sl.get_equipment_set(src))
	var root: Node3D = sl._instances[pid]["root"]
	sl._instances.erase(pid)
	root.position = Vector3.ZERO
	root.visible = true
	return root
