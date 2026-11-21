extends RefCounted
## Phase 265 — one builder for the avatar every view draws.
##
## The world avatar, the creation screen's rig and the Character window's doll all go through here: the
## player rig scene (`CharacterSlice.DEFAULT_RIG_KEYS`), its character material and palette indices, the
## hair style's own mesh on the head bone, and the worn equipment `CharacterSlice._make_visual` puts on
## the sockets. The procedural body stays only as the fallback when the manifest lists no rig.

const RigTree := preload("res://src/character/rig_tree.gd")
const CharacterMaterial := preload("res://src/character/character_material.gd")
const Diag := preload("res://src/core/diag.gd")
const HAIR_KEY_FORMAT := "models/characters/hair/%s.glb.raw"
const HAIR_SOCKET := "HairSocket"
const HAIR_NODE := "Hair"
const HEAD_BONE := "Head"
## Phase 286: the body type's own meshes on the shared skeleton and clips.
const BODY_KEY_FORMAT := "models/characters/bodies/%s.glb.raw"
const HEAD_KEY_FORMAT := "models/characters/heads/%s.glb.raw"
const HEAD_SOCKET := "HeadSocket"
const HEAD_NODE := "HeadMesh"
## Meta on a rig scene whose body has no head of its own mesh: the builder attaches the head's mesh.
const OWN_HEAD_META := "own_head"
## Phase 284: the scalp-top marker a head carries (a node of the rig scene) and the matching marker of a hair mesh.
const HEAD_ANCHOR := "hair_anchor"
const HAIR_ANCHOR := "anchor"
## Hair ids already logged for a missing `anchor`, so a style without one warns once.
static var _warned_no_anchor := {}
const IDLE_CLIP := "idle"
## Meta on the hair mesh: the style id it was loaded for.
const HAIR_META := "hair_style"

## The rig a character wears: its body type's own mesh (`models/characters/bodies/<body>.glb.raw`) when the manifest
## lists one, else the first default rig (the single rig mesh stays as the fallback). The body id is an
## unvalidated string, so only a key the manifest lists is ever loaded.
static func rig_key(ch: Node, appearance: Dictionary) -> String:
	var body := str(appearance.get("body", ""))
	if body != "":
		var key := BODY_KEY_FORMAT % body
		if AssetOverlay.has_key("meshes", key):
			return key
	return AssetOverlay.first_key("meshes", ch.DEFAULT_RIG_KEYS)

static func is_body_key(key: String) -> bool:
	return key.begins_with("models/characters/bodies/")

## The manifest key of the head mesh for an appearance, "" when none is listed. `head` falls back to the body id's
## sibling (`chibi_body_m` -> `chibi_head_m`).
static func head_key(appearance: Dictionary) -> String:
	var head := str(appearance.get("head", ""))
	if head == "" or not AssetOverlay.has_key("meshes", HEAD_KEY_FORMAT % head):
		head = str(appearance.get("body", "")).replace("body", "head")
	var key := HEAD_KEY_FORMAT % head
	return key if head != "" and AssetOverlay.has_key("meshes", key) else ""

## Put the appearance's head mesh on the Head bone of a rig scene marked `own_head`. Returns the mesh node or null.
static func attach_head(rig_scene: Node3D, appearance: Dictionary) -> MeshInstance3D:
	for old in rig_scene.find_children(HEAD_SOCKET, "BoneAttachment3D", true, false):
		old.get_parent().remove_child(old)
		old.free()
	var key := head_key(appearance)
	var mesh: Mesh = AssetOverlay.load_mesh(key) if key != "" else null
	var skeleton: Skeleton3D = null
	for n in rig_scene.find_children("*", "Skeleton3D", true, false):
		skeleton = n as Skeleton3D
		break
	if mesh == null or skeleton == null or skeleton.find_bone(HEAD_BONE) == -1:
		return null
	var node := MeshInstance3D.new()
	node.name = HEAD_NODE
	node.mesh = mesh
	var socket := BoneAttachment3D.new()
	socket.name = HEAD_SOCKET
	socket.bone_name = HEAD_BONE
	skeleton.add_child(socket)
	socket.add_child(node)
	return node

## The manifest key of a hair style's mesh, "" when the style has none (or none is listed).
static func hair_key(hair_id: String) -> String:
	if hair_id == "" or hair_id == "none":
		return ""
	var key := HAIR_KEY_FORMAT % hair_id
	return key if AssetOverlay.has_key("meshes", key) else ""

## Where a hair mesh sits so its `anchor` lands on the head's `hair_anchor`, in the Head bone's space. `scale` is
## the head's scale when the head is scaled outside the bone (an attachment on a scaled bone inherits it, so the
## builder passes 1): the hair grows with the head and the two anchors still coincide.
static func fit_transform(head_anchor: Vector3, hair_anchor: Vector3, scale: float = 1.0) -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3.ONE * scale), (head_anchor - hair_anchor) * scale)

## The rig scene's scalp anchor in Head-bone space, null when the rig has none (the production rig until its art
## lands) or the node is not under the Head bone.
static func head_anchor(rig_scene: Node3D) -> Variant:
	var node := rig_scene.find_child(HEAD_ANCHOR, true, false) as Node3D
	if node == null:
		return null
	var parent := node.get_parent()
	if parent is BoneAttachment3D and (parent as BoneAttachment3D).bone_name == HEAD_BONE:
		return node.position
	return null

## Give every mesh of a rig scene the character material, then put the appearance's hair on its head.
static func dress(ch: Node, rig_scene: Node3D, appearance: Dictionary) -> void:
	var sheets: Dictionary = ch._sheets_for_body(str(appearance.get("body", "")))
	var mat := CharacterMaterial.body_material(ch._palette_colors(), str(sheets["id"]))
	CharacterMaterial.bind_rig_textures(mat, sheets["detail"], sheets["color_mask"], sheets["channel"])
	if rig_scene.get_meta(OWN_HEAD_META, false):
		attach_head(rig_scene, appearance)
	var skin: int = int(appearance.get("skinColor", 12))   # mask: primary hair, secondary eye, accent beard
	for node in rig_scene.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.material_override = mat
		CharacterMaterial.apply_instance(mesh, skin, {
			"primary_index": int(appearance.get("hairColor", 0)),
			"secondary_index": int(appearance.get("eyeColor", 0)),
			"accent_index": int(appearance.get("beardColor", 0)),
		})
	attach_hair(ch, rig_scene, appearance)

## Replace the rig scene's hair with the appearance's style, tinted by its hair colour. Returns the hair mesh
## node, or null when the style has no mesh (the head stays bare).
static func attach_hair(ch: Node, rig_scene: Node3D, appearance: Dictionary) -> MeshInstance3D:
	remove_hair(rig_scene)
	var hair_id := str(appearance.get("hair", ""))
	var key := hair_key(hair_id)
	if key == "":
		return null
	var mesh: Mesh = AssetOverlay.load_mesh(key)
	if mesh == null:
		return null
	var node := MeshInstance3D.new()
	node.name = HAIR_NODE
	node.mesh = mesh
	node.set_meta(HAIR_META, hair_id)
	var scalp: Variant = head_anchor(rig_scene)
	if scalp != null:
		var anchor: Variant = AssetOverlay.load_marker(key, HAIR_ANCHOR)
		if anchor != null:
			node.transform = fit_transform(scalp, anchor)
		elif not _warned_no_anchor.has(hair_id):
			_warned_no_anchor[hair_id] = true
			Diag.warn("[AvatarBuilder] hair %s has no '%s' node; placed at the bone origin" % [hair_id, HAIR_ANCHOR])
	ch._finish_part(node, int(appearance.get("hairColor", 40)), {})
	var skeleton: Skeleton3D = null
	for n in rig_scene.find_children("*", "Skeleton3D", true, false):
		skeleton = n as Skeleton3D
		break
	if skeleton != null and skeleton.find_bone(HEAD_BONE) != -1:
		var socket := BoneAttachment3D.new()
		socket.name = HAIR_SOCKET
		socket.bone_name = HEAD_BONE
		skeleton.add_child(socket)
		socket.add_child(node)
	else:
		rig_scene.add_child(node)
	return node

static func remove_hair(rig_scene: Node3D) -> void:
	for socket in rig_scene.find_children(HAIR_SOCKET, "BoneAttachment3D", true, false):
		socket.get_parent().remove_child(socket)
		socket.free()
	for node in rig_scene.find_children(HAIR_NODE, "MeshInstance3D", true, false):
		node.get_parent().remove_child(node)
		node.free()

## The hair mesh node of a rig scene (or a built avatar's root), null when it is bare.
static func hair_node(root: Node) -> MeshInstance3D:
	for node in root.find_children(HAIR_NODE, "MeshInstance3D", true, false):
		return node as MeshInstance3D
	return null

## A standalone avatar for a view that is not a world instance (the creation rig, the doll): the visual
## `_make_visual` builds, with the default rig scene dressed, hair on and the idle clip playing. The same
## dressing `attach_rig` gives a world instance. `built["rig_node"]` is the scene (absent on the fallback).
static func build(ch: Node, instance_id: String, appearance: Dictionary) -> Dictionary:
	var built: Dictionary = ch._make_visual(instance_id, appearance)
	var key: String = rig_key(ch, appearance)
	if key == "" or not built.has("root"):
		return built
	var scene := AssetOverlay.load_rig_scene(key)
	if scene == null:
		return built
	var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		scene.free()
		return built
	scene.name = "RigScene"
	scene.set_meta(OWN_HEAD_META, is_body_key(key))
	var root: Node3D = built["root"]
	var impostor: Variant = built.get("impostor", null)
	for child in root.get_children():
		if child is Node3D and child != impostor:
			(child as Node3D).visible = false
	root.add_child(scene)
	dress(ch, scene, appearance)
	RigTree.prepare_library(player)
	if player.has_animation(IDLE_CLIP):
		player.play(IDLE_CLIP)
	built["rig_node"] = scene
	built["rig_key"] = key
	return built
