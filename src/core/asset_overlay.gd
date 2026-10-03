extends Node
## AssetOverlay (autoload) — mounts the production asset pack over res:// at
## startup and resolves each canonical asset key to whichever content is live.
##
## The production pack (`assets.pck`) is built from the private assets
## submodule by `tools/build_pck.sh` (which shells out to Godot's own
## `--export-pack`). Inside that pck, production files sit under the fixed
## `res://_overlay/` namespace — NOT at the same path as the public
## placeholder — because `--export-pack` cannot remap a source file to an
## arbitrary destination path, so packing the private submodule's own tree in
## place can only ever reproduce that submodule's own layout under res://,
## never the public `res://assets/<rel>` layout. `resolve_path`
## below is the explicit substitute for path-collision overlay: prefer
## `res://_overlay/<rel>` when the mounted pack has it, else fall back to the
## committed placeholder at `res://assets/<rel>`.
##
## Every asset resolved this way must be committed with a non-import-claimed
## extension (`.raw`) — see assets/README.md. Godot's import pipeline compiles
## recognized types (e.g. `.png`) into `res://.godot/imported/*.ctex` and drops
## the raw bytes at the bare path entirely from any real export, so a plain
## `.png` can never be read back via FileAccess in a shipped build. `.raw`
## files are opaque to the importer and are packed byte-for-byte instead.
##
## This same pack-mount mechanism is how paid DLC content packs will be
## layered in later — a .pck is the unit of optional content.

const PCK_NAME := "assets.pck"
## Internal namespace inside `assets.pck` for production-art overrides.
const OVERLAY_PREFIX := "res://_overlay/"
## Canonical placeholder key/path. Production art for this key lives at
## OVERLAY_PREFIX + PLACEHOLDER_REL inside the pack.
const PLACEHOLDER_REL := "textures/placeholder_character.png.raw"
const PLACEHOLDER_PATH := "res://assets/" + PLACEHOLDER_REL

var _production_active := false


func _ready() -> void:
	_production_active = _mount_production_pack()
	if _production_active:
		pass
	else:
		pass


## True once the production .pck has been mounted over res://.
func has_production_assets() -> bool:
	return _production_active


## "production" when the .pck is mounted, "placeholder" otherwise.
func asset_mode() -> String:
	return "production" if _production_active else "placeholder"


## Resolve a canonical asset key (e.g. "textures/placeholder_character.png.raw")
## to whichever content is currently live: the mounted production override if
## present, else the committed public placeholder. Never hardcodes a
## private-only path — only the public prefix and the pack's internal
## namespace, both of which are safe to ship.
func resolve_path(rel: String) -> String:
	var overlay_path := OVERLAY_PREFIX + rel
	if FileAccess.file_exists(overlay_path):
		return overlay_path
	return "res://assets/" + rel


## Load a canonical asset key as a texture, decoding raw PNG bytes directly
## (never `Image.load()` / `load()` — both resolve through Godot's disk/import
## machinery and do not see pack-mounted overrides at the bare `res://` path;
## see the module comment above).
func load_texture(rel: String) -> ImageTexture:
	var path := resolve_path(rel)
	var bytes := FileAccess.get_file_as_bytes(path)
	var img := Image.new()
	var err := img.load_png_from_buffer(bytes)
	if err != OK:
		push_warning("[AssetOverlay] failed to decode %s: %s" % [path, error_string(err)])
		return null
	return ImageTexture.create_from_image(img)


## Committed public manifest: canonical key -> relative path, per asset kind
## ("textures", "meshes", "animations"). Lists what EXISTS; an unlisted key is
## never an error — callers warn and fall back. The private pack overrides by
## key through `resolve_path`, so nothing branches on which side is present.
const MANIFEST_REL := "manifest.json"

var _manifest: Dictionary = {}


## The parsed manifest ({} when missing or malformed).
func manifest() -> Dictionary:
	if _manifest.is_empty():
		var path := resolve_path(MANIFEST_REL)
		if FileAccess.file_exists(path):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				_manifest = parsed
	return _manifest


## Keys listed for `kind` ("textures" | "meshes" | "animations"), sorted.
func keys(kind: String) -> Array:
	var section = manifest().get(kind, {})
	var out: Array = section.keys() if section is Dictionary else []
	out.sort()
	return out


## True when the manifest lists `key` under `kind`.
func has_key(kind: String, key: String) -> bool:
	return key in keys(kind)


## Canonical key for a creature-family model: `models/creatures/<Entity>.glb.raw`.
static func creature_model_key(entity_name: String) -> String:
	return "models/creatures/%s.glb.raw" % entity_name


## Parse a `.glb.raw` key into a scene root via GLTFDocument (bytes only —
## never `load()`). Null (with a warning) when missing or undecodable.
func _load_gltf_scene(rel: String) -> Node:
	var path := resolve_path(rel)
	if not FileAccess.file_exists(path):
		push_warning("[AssetOverlay] missing model %s" % rel)
		return null
	var bytes := FileAccess.get_file_as_bytes(path)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_buffer(bytes, "", state)
	if err != OK:
		push_warning("[AssetOverlay] failed to parse %s: %s" % [path, error_string(err)])
		return null
	return doc.generate_scene(state)


static func _first_mesh(n: Node) -> Mesh:
	if n is MeshInstance3D and n.mesh != null:
		return n.mesh
	for c in n.get_children():
		var m := _first_mesh(c)
		if m != null:
			return m
	return null


## Load a canonical key as a Mesh (first mesh in the glTF). Null on failure.
func load_mesh(rel: String) -> Mesh:
	var root := _load_gltf_scene(rel)
	if root == null:
		return null
	var mesh := _first_mesh(root)
	root.free()
	if mesh == null:
		push_warning("[AssetOverlay] %s contains no mesh" % rel)
	return mesh


## Load a canonical key's clips as an AnimationLibrary. Empty library (with a
## warning) on failure, so callers can always attach the result.
func load_animation_library(rel: String) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	var root := _load_gltf_scene(rel)
	if root == null:
		return lib
	var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null:
		for lib_name in player.get_animation_library_list():
			var src := player.get_animation_library(lib_name)
			for clip in src.get_animation_list():
				lib.add_animation(clip, src.get_animation(clip).duplicate())
	root.free()
	return lib


## Search well-known locations for the pack. No private path is hardcoded here —
## only the pack's file name and the standard binary/project directories.
func _mount_production_pack() -> bool:
	for candidate in _pack_candidates():
		if FileAccess.file_exists(candidate):
			var ok := ProjectSettings.load_resource_pack(candidate, true)
			if ok:
				return true
			push_warning("[AssetOverlay] found %s but failed to mount it" % candidate)
	return false


func _pack_candidates() -> Array[String]:
	var out: Array[String] = []
	# Next to the running binary (Steam / exported builds place it there).
	out.append(OS.get_executable_path().get_base_dir().path_join(PCK_NAME))
	# Project root (dev builds).
	out.append(ProjectSettings.globalize_path("res://" + PCK_NAME))
	return out
