extends Node
## AssetOverlay (autoload) — mounts the production asset pack over res:// at
## startup so private art replaces the committed placeholders.
##
## The production pack (`assets.pck`) is built from the private assets submodule
## by tools/pack_pck.gd. Public clones ship only the ugly placeholders under
## assets/ and boot with no missing-resource errors; a build that bundles the
## .pck (Steam) loads it here and swaps placeholders for production art.
##
## This same pack-mount mechanism is how paid DLC content packs will be layered
## in later — a .pck is the unit of optional content.

const PCK_NAME := "assets.pck"
## Canonical placeholder path. Production art lives at the SAME res:// path
## inside the .pck, so nothing in code ever references a private-only path.
const PLACEHOLDER_PATH := "res://assets/textures/placeholder_character.png"

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
