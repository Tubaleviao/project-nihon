extends RefCounted
## Character material pipeline (ROADMAP Phase 22) — characters.md §17–§25.
##
## Builds ONE shared, parameterised ShaderMaterial and a shared 256×1 palette
## texture; every character part references the same material and carries only
## per-instance palette indices + channel scalars (§20), written with
## `set_instance_shader_parameter` — no new material (or texture) per part.
##
## All state lives in static members so a single preloaded script serves every
## CharacterSlice instance (tests create and free many within one run) and the
## palette texture / material are built once and shared.

const SHADER := preload("res://src/character/character_material.gdshader")
const PALETTE_SIZE := 256

## Palette index channels a caller may set per-instance (§20). Unknown keys are
## rejected (see set_index / get_index).
const INDEX_KEYS := ["base_index", "primary_index", "secondary_index", "accent_index"]

## Cached shared palette texture, keyed by colour CONTENT (not entry count) so
## two same-sized palettes with different colours never alias.
static var _palette_tex: ImageTexture = null
static var _palette_tex_key: int = 0

## The single shared ShaderMaterial every part uses (§20).
static var _shared_material: ShaderMaterial = null

# ---------------------------------------------------------------------------
# Palette texture
# ---------------------------------------------------------------------------

## Build (once) and return the shared 256×1 palette texture from a list of
## `Color` entries. Nearest/Point filtering is declared on the shader's sampler
## (`filter_nearest`), not the texture, so no import preset is involved. The
## texture is always PALETTE_SIZE wide (empty input is guarded), so a palette
## shorter than 256 entries repeats its last colour and a longer one truncates —
## the one-byte-per-index framing (§19) holds regardless of source length.
static func palette_texture(colors: Array) -> ImageTexture:
	if colors.is_empty():
		if _palette_tex == null:
			var empty := Image.create(1, 1, false, Image.FORMAT_RGBA8)
			empty.fill(Color.BLACK)
			_palette_tex = ImageTexture.create_from_image(empty)
			_palette_tex_key = 0
		return _palette_tex
	var key := _content_key(colors)
	if _palette_tex != null and _palette_tex_key == key:
		return _palette_tex
	var img := Image.create(PALETTE_SIZE, 1, false, Image.FORMAT_RGBA8)
	var last := colors.size() - 1
	for i in range(PALETTE_SIZE):
		img.set_pixel(i, 0, colors[mini(i, last)])
	_palette_tex = ImageTexture.create_from_image(img)
	_palette_tex_key = key
	return _palette_tex

# ---------------------------------------------------------------------------
# Shared material + per-instance parameters (§20)
# ---------------------------------------------------------------------------

## The single shared ShaderMaterial (built once). The palette texture is bound
## here; per-part colour/channel values are written per-instance on each mesh
## via apply_instance() — a palette swap is a uniform write, never a new
## material or texture.
static func shared_material(colors: Array) -> ShaderMaterial:
	if _shared_material == null:
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("palette_tex", palette_texture(colors))
		_shared_material = mat
	return _shared_material

## Write every per-instance shader parameter onto a part mesh (no new material).
## `base_index` is the base palette colour; `opts` carries the optional channel
## scalars (primary/secondary/accent indices, metalness, emission_strength,
## emission_index, roughness, wear).
static func apply_instance(mesh: GeometryInstance3D, base_index: int, opts: Dictionary = {}) -> void:
	mesh.set_instance_shader_parameter("base_index", _idx(base_index))
	mesh.set_instance_shader_parameter("primary_index", _idx(opts.get("primary_index", 0)))
	mesh.set_instance_shader_parameter("secondary_index", _idx(opts.get("secondary_index", 0)))
	mesh.set_instance_shader_parameter("accent_index", _idx(opts.get("accent_index", 0)))
	mesh.set_instance_shader_parameter("emission_index", _idx_region(opts.get("emission_index", 192), 192, 223))
	mesh.set_instance_shader_parameter("metalness", clampf(float(opts.get("metalness", 0.0)), 0.0, 1.0))
	mesh.set_instance_shader_parameter("emission_strength", clampf(float(opts.get("emission_strength", 0.0)), 0.0, 1.0))
	mesh.set_instance_shader_parameter("roughness", clampf(float(opts.get("roughness", 0.55)), 0.0, 1.0))
	mesh.set_instance_shader_parameter("wear", clampf(float(opts.get("wear", 0.0)), 0.0, 1.0))

# ---------------------------------------------------------------------------
# Per-instance palette swap (§20)
# ---------------------------------------------------------------------------

## Write one palette index channel on a part mesh (no new texture, no new
## material). `key` is one of base_index / primary_index / secondary_index /
## accent_index; unknown keys are rejected (-1). Returns the clamped value.
static func set_index(mesh: GeometryInstance3D, key: String, index: int) -> int:
	if key not in INDEX_KEYS:
		return -1
	var clamped := _idx(index)
	mesh.set_instance_shader_parameter(key, clamped)
	return clamped

## Read a palette index channel back from a part mesh (round-trip / tests).
static func get_index(mesh: GeometryInstance3D, key: String) -> int:
	if key not in INDEX_KEYS:
		return -1
	return int(mesh.get_instance_shader_parameter(key))

# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

## Stable content hash so two palettes with equal size but different colours
## never alias in the cache.
static func _content_key(colors: Array) -> int:
	var h := 17
	for c in colors:
		h = (h * 31 + str(c).hash()) & 0x7fffffff
	return h

static func _idx(v) -> int:
	if v is int or v is float:
		return clampi(int(v), 0, PALETTE_SIZE - 1)
	return 0

static func _idx_region(v, lo: int, hi: int) -> int:
	if v is int or v is float:
		return clampi(int(v), lo, hi)
	return lo
