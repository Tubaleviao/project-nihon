extends RefCounted
## Phase 242 — the terrain shader's material: three texture arrays (albedo, normal, roughness), one
## layer per terrain material in the fabric (`GameData.TERRAIN_MATERIALS`, ordered by `layer`), built
## once from the `assets/` maps through `AssetOverlay` (so a production pack overrides them by key), and
## one `ShaderMaterial` per biome carrying that biome's season tint.
##
## Low-end fallback: the project setting `nihon/graphics/terrain_quality` (0 = low: biplanar sampling,
## no detail texture; 1 = high; -1 = auto, the default: low on the Compatibility renderer, the low-end
## and software-GL path, high otherwise). Phase 225's options window will put it in front of the player.

const SHADER := preload("res://src/terrain/terrain_material.gdshader")
## Phase 242 CI fix: the low path is its own lean shader (two layers, albedo, biplanar, no loops).
const LOW_SHADER := preload("res://src/terrain/terrain_material_low.gdshader")
const TerrainWeights := preload("res://src/terrain/terrain_weights.gd")
const Diag := preload("res://src/core/diag.gd")

const QUALITY_SETTING := "nihon/graphics/terrain_quality"
const QUALITY_LOW := 0
const QUALITY_HIGH := 1
const QUALITY_AUTO := -1
const MAPS := ["albedo", "normal", "roughness"]
## Every map is resized to this edge before it goes in an array (the arrays need one size); the low path
## binds `LOW_SIZE` arrays, which a software rasteriser samples far faster.
const SIZE := 1024
const LOW_SIZE := 256

static var _arrays: Dictionary = {}   # size -> { map: Texture2DArray }

## The terrain quality in effect: the project setting, with auto resolved for the current renderer.
static func quality() -> int:
	return quality_for(int(ProjectSettings.get_setting(QUALITY_SETTING, QUALITY_AUTO)),
		RenderingServer.get_current_rendering_method())

## Pure: low or high for a setting and a rendering method (auto, or a value out of range, is low on
## `gl_compatibility` and high on the others).
static func quality_for(setting: int, method: String) -> int:
	if setting == QUALITY_LOW or setting == QUALITY_HIGH:
		return setting
	return QUALITY_LOW if method == "gl_compatibility" else QUALITY_HIGH

## `{ albedo, normal, roughness }` Texture2DArrays, built on first use (main thread). A map that fails
## to load is a flat mid-grey layer, so a missing file draws grey ground rather than breaking the array.
static func texture_arrays(size: int = SIZE) -> Dictionary:
	if not _arrays.has(size):
		var layers: Array = TerrainWeights.table()["layers"]
		var by_map := {}
		for map in MAPS:
			var images: Array[Image] = []
			for entry in layers:
				images.append(_layer_image(entry, map, size))
			var arr := Texture2DArray.new()
			arr.create_from_images(images)
			by_map[map] = arr
		_arrays[size] = by_map
	return _arrays[size]

static func _layer_image(entry: Dictionary, map: String, size: int) -> Image:
	var key := str(entry["key"])
	var img: Image = null
	var overlay: Node = _overlay()
	if overlay != null:
		img = overlay.load_image("%s_%s.jpg.raw" % [key, map])
		if map == "albedo":
			img = checked_albedo(img, "%s_%s.jpg.raw" % [key, map], float(entry.get("min_mean", 0.0)), float(entry.get("min_dark", 0.0)))
	if img == null:
		img = Image.create(8, 8, false, Image.FORMAT_RGB8)
		img.fill(Color(0.5, 0.5, 1.0) if map == "normal" else Color(0.5, 0.5, 0.5))
	if img.get_format() != Image.FORMAT_RGB8:
		img.convert(Image.FORMAT_RGB8)
	if img.get_width() != size or img.get_height() != size:
		img.resize(size, size, Image.INTERPOLATE_BILINEAR if size >= img.get_width() else Image.INTERPOLATE_LANCZOS)
	img.generate_mipmaps(map == "normal")
	return img

## Phase 285 — mean luminance and the luminance of the darkest 1% of texels of an image (0..1), read from a
## 128 px copy so a 2k map costs little.
static func luminance_stats(img: Image) -> Dictionary:
	var small := img.duplicate() as Image
	if small.get_format() != Image.FORMAT_RGB8:
		small.convert(Image.FORMAT_RGB8)
	small.resize(128, 128, Image.INTERPOLATE_BILINEAR)
	var lums := PackedFloat32Array()
	var sum := 0.0
	for y in 128:
		for x in 128:
			var c := small.get_pixel(x, y)
			var l := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			lums.append(l)
			sum += l
	lums.sort()
	return { "mean": sum / lums.size(), "dark": lums[int(lums.size() * 0.01)] }

## "" when an albedo map clears the fabric floors, else why it is refused.
static func map_rejection(img: Image, min_mean: float, min_dark: float) -> String:
	if img == null or img.is_empty():
		return "no pixels"
	var st := luminance_stats(img)
	if float(st["mean"]) < min_mean:
		return "mean luminance %.3f is under the floor %.3f" % [st["mean"], min_mean]
	if float(st["dark"]) < min_dark:
		return "its darkest 1%% of texels (luminance %.3f) are under the floor %.3f" % [st["dark"], min_dark]
	return ""

## The overlay's albedo map when it clears the floors, else (logged) the public placeholder at the same key,
## so a broken production map cannot ship black ground. A null image stays null (the flat-grey fallback).
static func checked_albedo(img: Image, rel: String, min_mean: float, min_dark: float) -> Image:
	if img == null:
		return null
	var why := map_rejection(img, min_mean, min_dark)
	if why == "":
		return img
	Diag.warn("[TerrainMaterial] %s rejected (%s); using the placeholder" % [rel, why])
	var fallback := Image.new()
	var bytes := FileAccess.get_file_as_bytes("res://assets/" + rel)
	return fallback if fallback.load_jpg_from_buffer(bytes) == OK else img

static func _overlay() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("AssetOverlay") if tree != null else null

## A new terrain material: the shared arrays, each layer's scale, the quality switches and `tint`.
static func make(tint: Color = Color.WHITE) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var low := quality() == QUALITY_LOW
	mat.shader = LOW_SHADER if low else SHADER
	var arrays := texture_arrays(LOW_SIZE if low else SIZE)
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
	var floors := PackedFloat32Array()
	floors.resize(TerrainWeights.LAYERS)
	floors.fill(0.2)
	for entry in TerrainWeights.table()["layers"]:
		var layer := int(entry["layer"])
		if layer >= 0 and layer < TerrainWeights.LAYERS:
			floors[layer] = clampf(float(entry.get("height_floor", 0.2)), 0.0, 1.0)
	mat.set_shader_parameter("layer_height_floor", floors)
	mat.set_shader_parameter("biplanar", low)
	mat.set_shader_parameter("detail", not low)
	mat.set_shader_parameter("surface_maps", not low)
	set_tint(mat, tint)
	return mat

static func set_tint(mat: ShaderMaterial, tint: Color) -> void:
	mat.set_shader_parameter("tint", tint)

static func tint_of(mat: ShaderMaterial) -> Color:
	var v: Variant = mat.get_shader_parameter("tint")
	return v if v is Color else Color.WHITE
