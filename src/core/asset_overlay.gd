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
		print("[AssetOverlay] production pack mounted — %s overrides res://assets/" % PCK_NAME)
	else:
		print("[AssetOverlay] placeholder mode — no %s found" % PCK_NAME)


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
