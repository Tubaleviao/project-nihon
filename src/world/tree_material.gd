extends RefCounted
## The tree material (Phase 283): vertex (and per-instance) colour as albedo, plus a gentle wind sway of
## the crown in the vertex shader. The sway is weighted by height, so the trunk's foot never moves, and is
## off when the project setting `nihon/graphics/tree_sway` is false (terrain quality "low" in the options,
## `GameSettings`), where the plain colour material is used. The sway phase comes from the instance position, so a floating-origin
## rebase shifts every tree's phase at once (a sub-0.1 m effect). Placeholder models stand about 3.8 m tall.

const Diag := preload("res://src/core/diag.gd")
const SWAY_SETTING := "nihon/graphics/tree_sway"
## Metres of crown sway at the top of a tree; the weight rises from `SWAY_FROM` to `SWAY_TO` (the placeholder
## models' height, 3.8 m; `tools/gen_tree_models.py`). The procedural fallback tree is shorter (3.35 m,
## `TreeSlice.TRUNK_HEIGHT + CANOPY_HEIGHT`), so its crown top reaches about 0.84 of the full sway.
const SWAY_AMPLITUDE := 0.06
const SWAY_FROM := 1.8
const SWAY_TO := 3.8
## Extra model variants a species may have beyond its base model (`<Species>_v1` … `_v<MAX_VARIANTS>`).
const MAX_VARIANTS := 1

const SHADER_CODE := """
shader_type spatial;
uniform float amplitude = 0.06;
uniform float sway_from = 1.8;
uniform float sway_to = 3.8;
void vertex() {
	float w = smoothstep(sway_from, sway_to, VERTEX.y);
	float phase = MODEL_MATRIX[3].x * 0.7 + MODEL_MATRIX[3].z * 0.9;
	VERTEX.x += sin(TIME * 1.3 + phase) * amplitude * w;
	VERTEX.z += cos(TIME * 1.1 + phase * 1.3) * amplitude * 0.7 * w;
}
void fragment() {
	ALBEDO = COLOR.rgb;
}
"""

## The same shader for a felled tree's private copy: the per-instance colour becomes `tint` and `alpha` fades it.
static var SHADER_CODE_FALLING: String = SHADER_CODE.replace("void fragment() {\n\tALBEDO = COLOR.rgb;\n}",
	"uniform vec4 tint : source_color = vec4(1.0);\nuniform float alpha = 1.0;\nvoid fragment() {\n\tALBEDO = COLOR.rgb * tint.rgb;\n\tALPHA = alpha;\n}")
static var _shader: Shader = null
static var _shader_falling: Shader = null
static var _model_meshes: Dictionary = {}
## Model keys already warned about as unusable, so a missing model warns once per run, not once per retry.
static var _model_warned: Dictionary = {}

static func sway_enabled() -> bool:
	return bool(ProjectSettings.get_setting(SWAY_SETTING, true))

## Issue #703 — give every live pool in `pools` the material for the current sway setting when it differs from
## `was` (what they draw now); null entries are skipped. Returns the setting now applied.
static func refresh_pools(pools: Array, was: bool) -> bool:
	var on := sway_enabled()
	if on != was:
		for pool in pools:
			if pool != null:
				pool.set_material(make(on))
	return on

## The material for the tree pools: the swaying shader, or a plain vertex-colour material when sway is off.
static func make(sway: bool = true) -> Material:
	if not sway:
		var plain := StandardMaterial3D.new()
		plain.vertex_color_use_as_albedo = true
		plain.albedo_color = Color.WHITE
		return plain
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("amplitude", SWAY_AMPLITUDE)
	mat.set_shader_parameter("sway_from", SWAY_FROM)
	mat.set_shader_parameter("sway_to", SWAY_TO)
	return mat

## A private material for a falling tree: `base` (a pool material) with the colour and fade controls of a
## felled tree. A ShaderMaterial gets the falling shader (`tint`, `alpha`); a StandardMaterial3D is duplicated
## with alpha blending on and `tint` as its albedo colour.
static func make_falling(base: Material, tint: Color) -> Material:
	if base is ShaderMaterial:
		if _shader_falling == null:
			_shader_falling = Shader.new()
			_shader_falling.code = SHADER_CODE_FALLING
		var mat := ShaderMaterial.new()
		mat.shader = _shader_falling
		for k in ["amplitude", "sway_from", "sway_to"]:
			mat.set_shader_parameter(k, (base as ShaderMaterial).get_shader_parameter(k))
		mat.set_shader_parameter("tint", tint)
		mat.set_shader_parameter("alpha", 1.0)
		return mat
	if base is StandardMaterial3D:
		var own := (base as StandardMaterial3D).duplicate() as StandardMaterial3D
		own.albedo_color = tint
		own.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		return own
	return base

## Set a falling material's opacity (see `make_falling`).
static func set_fade(m: Material, a: float) -> void:
	if m is ShaderMaterial:
		(m as ShaderMaterial).set_shader_parameter("alpha", a)
	elif m is StandardMaterial3D:
		var c := (m as StandardMaterial3D).albedo_color
		c.a = a
		(m as StandardMaterial3D).albedo_color = c

## Model keys a species can draw: `models/trees/<Species>.glb.raw`, then `<Species>_v1` when the
## manifest lists it (an absent variant is never picked).
static func model_keys(species: String) -> Array:
	var out: Array = ["models/trees/%s.glb.raw" % species]
	for n in range(1, MAX_VARIANTS + 1):
		var key := "models/trees/%s_v%d.glb.raw" % [species, n]
		if AssetOverlay.has_key("meshes", key):
			out.append(key)
	return out

## The model key a tree draws, stable for its id (host and client agree), or "" when the species has
## no model at all.
static func model_key_for(species: String, tree_id: String) -> String:
	var keys := model_keys(species)
	if not AssetOverlay.has_key("meshes", keys[0]):
		return ""
	return keys[posmod(hash([tree_id, "tree_variant"]), keys.size())]


## The mesh for a model key (cached), or null when it does not load (not cached, so a later mount can succeed).
static func model_mesh(key: String) -> Mesh:
	if _model_meshes.has(key):
		return _model_meshes[key]
	var mesh: Mesh = null
	if AssetOverlay.has_key("meshes", key):
		mesh = AssetOverlay.load_mesh(key)
	if mesh == null:
		if not _model_warned.has(key):
			_model_warned[key] = true
			Diag.warn("[Tree] no usable model %s; using the procedural tree" % key)
		return null   # not cached: the overlay may mount later
	_model_meshes[key] = mesh
	return mesh
