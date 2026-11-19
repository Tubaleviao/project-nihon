extends RefCounted
## Phase 265 — one builder for the avatar every view draws.
##
## The world avatar, the creation screen's rig and the Character window's doll all go through here: the
## player rig scene (`CharacterSlice.DEFAULT_RIG_KEYS`), its character material and palette indices, the
## hair style's own mesh on the head bone, and the worn equipment `CharacterSlice._make_visual` puts on
## the sockets. The procedural body stays only as the fallback when the manifest lists no rig.

const RigTree := preload("res://src/character/rig_tree.gd")
const CharacterMaterial := preload("res://src/character/character_material.gd")
const HAIR_KEY_FORMAT := "models/characters/hair/%s.glb.raw"
const HAIR_SOCKET := "HairSocket"
const HAIR_NODE := "Hair"
const HEAD_BONE := "Head"
const IDLE_CLIP := "idle"
## Meta on the hair mesh: the style id it was loaded for.
const HAIR_META := "hair_style"

## The manifest key of a hair style's mesh, "" when the style has none (or none is listed).
static func hair_key(hair_id: String) -> String:
	if hair_id == "" or hair_id == "none":
		return ""
	var key := HAIR_KEY_FORMAT % hair_id
	return key if AssetOverlay.has_key("meshes", key) else ""

## Give every mesh of a rig scene the character material, then put the appearance's hair on its head.
static func dress(ch: Node, rig_scene: Node3D, appearance: Dictionary) -> void:
	var sheets: Dictionary = ch._sheets_for_body(str(appearance.get("body", "")))
	var mat := CharacterMaterial.body_material(ch._palette_colors(), str(sheets["id"]))
	CharacterMaterial.bind_rig_textures(mat, sheets["detail"], sheets["color_mask"], sheets["channel"])
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
	var key: String = AssetOverlay.first_key("meshes", ch.DEFAULT_RIG_KEYS)
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
