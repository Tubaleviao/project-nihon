extends RefCounted
## UI icon keys and a texture cache (Phase 175). The files come from `tools/gen_ui_icons.py`; the
## private pack overrides them by key through `AssetOverlay`. A missing key returns null.

const WINDOW_FORMAT := "icons/ui/window/%s.png.raw"
const SKILL_FORMAT := "icons/skills/%s.png.raw"
const HUD_FORMAT := "icons/ui/hud/%s.png.raw"
const HP := "hp"

static var _cache: Dictionary = {}

static func window_key(window_key_id: String) -> String:
	return WINDOW_FORMAT % window_key_id

static func skill_key(skill: String) -> String:
	return SKILL_FORMAT % skill

static func hud_key(id: String) -> String:
	return HUD_FORMAT % id

## The texture at an asset key, cached per resolved path.
static func load_icon(key: String) -> Texture2D:
	var path := AssetOverlay.resolve_path(key)
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = null
	if FileAccess.file_exists(path):
		tex = AssetOverlay.load_texture(key)
	_cache[path] = tex
	return tex
