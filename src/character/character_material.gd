extends RefCounted
## Character material pipeline (ROADMAP Phase 22) — characters.md §17–§25.
##
## Builds the shared, parameterised ShaderMaterial that replaces the per-part
## `StandardMaterial3D` albedo tint. Every part carries per-instance palette
## indices (§20) and channel scalars (§21/§22/§23) but shares ONE palette
## texture (§19) and ONE shader, so a palette swap is a uniform write — no new
## texture asset and no new material resource per character skin.
##
## All state lives in static members so a single preloaded script serves every
## CharacterSlice instance (tests create and free many within one run) and the
## palette texture is built once and shared.

const SHADER := preload("res://src/character/character_material.gdshader")
const PALETTE_SIZE := 256

## Cached shared palette texture, keyed by the entry count it was built from.
static var _palette_tex: ImageTexture = null
static var _palette_tex_size: int = 0

# ---------------------------------------------------------------------------
# Palette texture
# ---------------------------------------------------------------------------

## Build (once) and return the shared 256×1 palette texture from a list of
## `Color` entries. Nearest/Point filtering is declared on the shader's sampler
## (`filter_nearest`), not the texture, so no import preset is involved. The
## texture is a single row (256×1) matching the one-byte-per-index palette
## (§19): u = (index + 0.5) / 256 samples the centre of each entry.
static func palette_texture(colors: Array) -> ImageTexture:
	var n := colors.size()
	if _palette_tex != null and _palette_tex_size == n:
		return _palette_tex
	var img := Image.create(n, 1, false, Image.FORMAT_RGBA8)
	for i in range(n):
		var c: Color = colors[i]
		img.set_pixel(i, 0, c)
	_palette_tex = ImageTexture.create_from_image(img)
	_palette_tex_size = n
	return _palette_tex

# ---------------------------------------------------------------------------
# Material construction
# ---------------------------------------------------------------------------

## Build a ShaderMaterial from a palette (list of `Color`) and an options
## dictionary. Recognised keys (all optional):
##   base_index, primary_index, secondary_index, accent_index  (int, §20)
##   metalness, emission_strength, wear                        (float, §21-23)
##   emission_color                                            (Color, §22)
##   detail_tex                                                (Texture2D, §24)
static func build(colors: Array, opts: Dictionary = {}) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("palette_tex", palette_texture(colors))
	mat.set_shader_parameter("base_index", _idx(opts.get("base_index", 0)))
	mat.set_shader_parameter("primary_index", _idx(opts.get("primary_index", 0)))
	mat.set_shader_parameter("secondary_index", _idx(opts.get("secondary_index", 0)))
	mat.set_shader_parameter("accent_index", _idx(opts.get("accent_index", 0)))
	mat.set_shader_parameter("metalness", clampf(float(opts.get("metalness", 0.0)), 0.0, 1.0))
	mat.set_shader_parameter("emission_strength", clampf(float(opts.get("emission_strength", 0.0)), 0.0, 1.0))
	mat.set_shader_parameter("emission_color", opts.get("emission_color", Color.BLACK))
	mat.set_shader_parameter("wear", clampf(float(opts.get("wear", 0.0)), 0.0, 1.0))
	var detail = opts.get("detail_tex", null)
	if detail is Texture2D:
		mat.set_shader_parameter("detail_tex", detail)
	return mat

# ---------------------------------------------------------------------------
# Per-instance palette swap (§20)
# ---------------------------------------------------------------------------

## Write one palette index channel on an existing material (no new texture, no
## new material). `key` is one of base_index / primary_index / secondary_index /
## accent_index. Returns the clamped value written.
static func set_index(mat: ShaderMaterial, key: String, index: int) -> int:
	var clamped := _idx(index)
	mat.set_shader_parameter(key, clamped)
	return clamped

## Read a palette index channel back (round-trip / tests).
static func get_index(mat: ShaderMaterial, key: String) -> int:
	return int(mat.get_shader_parameter(key))

# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

static func _idx(v) -> int:
	if v is int or v is float:
		return clampi(int(v), 0, PALETTE_SIZE - 1)
	return 0
