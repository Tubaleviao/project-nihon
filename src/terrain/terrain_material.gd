extends RefCounted
## Phase 242 — the terrain shader's material: three texture arrays (albedo, normal, roughness), one
## layer per terrain material in the fabric (`GameData.TERRAIN_MATERIALS`, ordered by `layer`), built
## once from the `assets/` maps through `AssetOverlay` (so a production pack overrides them by key), and
## one `ShaderMaterial` per biome carrying that biome's season tint.
##
## Low-end fallback: the project setting `nihon/graphics/terrain_quality` (0 = low: biplanar sampling,
## no detail texture; 1 = high, the default). Phase 225's options window will put it in front of the player.

const SHADER := preload("res://src/terrain/terrain_material.gdshader")
const TerrainWeights := preload("res://src/terrain/terrain_weights.gd")

const QUALITY_SETTING := "nihon/graphics/terrain_quality"
const QUALITY_LOW := 0
const QUALITY_HIGH := 1
const MAPS := ["albedo", "normal", "roughness"]
## Every map is resized to this edge before it goes in an array (the arrays need one size).
const SIZE := 1024

static var _arrays: Dictionary = {}

## The terrain quality from the project settings (high when unset or out of range).
static func quality() -> int:
	var q := int(ProjectSettings.get_setting(QUALITY_SETTING, QUALITY_HIGH))
	return q if q == QUALITY_LOW or q == QUALITY_HIGH else QUALITY_HIGH

## `{ albedo, normal, roughness }` Texture2DArrays, built on first use (main thread). A map that fails
## to load is a flat mid-grey layer, so a missing file draws grey ground rather than breaking the array.
static func texture_arrays() -> Dictionary:
	if _arrays.is_empty():
		var layers: Array = TerrainWeights.table()["layers"]
		for map in MAPS:
			var images: Array[Image] = []
			for entry in layers:
				images.append(_layer_image(str(entry["key"]), map))
			var arr := Texture2DArray.new()
			arr.create_from_images(images)
			_arrays[map] = arr
	return _arrays

static func _layer_image(key: String, map: String) -> Image:
	var img: Image = null
	var overlay: Node = _overlay()
	if overlay != null:
		img = overlay.load_image("%s_%s.jpg.raw" % [key, map])
	if img == null:
		img = Image.create(8, 8, false, Image.FORMAT_RGB8)
		img.fill(Color(0.5, 0.5, 1.0) if map == "normal" else Color(0.5, 0.5, 0.5))
	if img.get_format() != Image.FORMAT_RGB8:
		img.convert(Image.FORMAT_RGB8)
	if img.get_width() != SIZE or img.get_height() != SIZE:
		img.resize(SIZE, SIZE, Image.INTERPOLATE_BILINEAR)
	img.generate_mipmaps(map == "normal")
	return img

static func _overlay() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("AssetOverlay") if tree != null else null

## A new terrain material: the shared arrays, each layer's scale, the quality switches and `tint`.
static func make(tint: Color = Color.WHITE) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	var arrays := texture_arrays()
	for map in MAPS:
		mat.set_shader_parameter("%s_maps" % map, arrays[map])
	var scales := PackedFloat32Array()
	scales.resize(TerrainWeights.LAYERS)
	scales.fill(4.0)
	for entry in TerrainWeights.table()["layers"]:
		var layer := int(entry["layer"])
		if layer >= 0 and layer < TerrainWeights.LAYERS:
			scales[layer] = maxf(float(entry["scale"]), 0.01)
	mat.set_shader_parameter("layer_scale", scales)
	var low := quality() == QUALITY_LOW
	mat.set_shader_parameter("biplanar", low)
	mat.set_shader_parameter("detail", not low)
	set_tint(mat, tint)
	return mat

static func set_tint(mat: ShaderMaterial, tint: Color) -> void:
	mat.set_shader_parameter("tint", tint)

static func tint_of(mat: ShaderMaterial) -> Color:
	var v: Variant = mat.get_shader_parameter("tint")
	return v if v is Color else Color.WHITE
