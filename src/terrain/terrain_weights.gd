extends RefCounted
## Phase 242 — which terrain materials natural ground is drawn with, per vertex.
##
## Up to four materials per vertex. Each layer has its own weight channel: `CUSTOM0` holds layers 0-3
## and `CUSTOM1` layers 4-7 (RGBA8, the eight bytes summing to 255), so a weight interpolates correctly
## across a triangle whose corners use different materials (an id per slot would not: two corners'
## ids would blend into a third). The weights are a pure function of
## - the biome blend: the chunk's own biome and, within `BLEND_TILES` of a chunk border, the biome
##   across it, falling from half and half at the border to none at the band's inner edge (the same
##   falloff and width as the dithered border, `BiomeBlend.chance`);
## - wetness: within a material's `nearWater` metres of a lake or river edge (Phase 217);
## - altitude: above the biome's `snowLine` (metres above sea level), snow (each blended biome by its own line);
## - slope: steeper than a material's `slopeMin` degrees, rock, whatever is above.
## Each later rule takes its share from the ones before it. A placed block's vertices get weight zero
## everywhere, which the terrain shader reads as "draw the vertex colour" (a block keeps its material).
##
## The table comes from `GameData.TERRAIN_MATERIALS` and `GameData.BIOMES`, preloaded constants, so a
## worker may read it (as `VoxelSlice.surface_style` does); `warm()` builds it once on the main thread.

const BiomeBlend := preload("res://src/terrain/biome_blend.gd")
const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")
const WorldShape := preload("res://src/terrain/world_shape.gd")
const Hydrology := preload("res://src/terrain/hydrology.gd")
const VoxelConsts := preload("res://src/terrain/voxel_consts.gd")
const NativeBuilder := preload("res://src/terrain/native_builder.gd")

## At most this many materials weigh on one vertex.
const SLOTS := 4
## Weight channels: two RGBA8 arrays, one layer per channel.
const LAYERS := 8
## Must match `VoxelSlice.BLEND_TILES` (the dithered border's width, in tiles).
const BLEND_TILES := 4.0
## Half-width, in metres, of the band over which ground turns to snow around the snow line.
const SNOW_BAND := 15.0
## Half-width, in degrees, of the band over which ground turns to rock around `slopeMin`.
const SLOPE_BAND := 8.0
const DEFAULT_BIOME := "TemperateForest"
const NO_LINE := 100000.0

static var _table: Dictionary = {}
static var _mutex := Mutex.new()

## Build the table now (main thread); later calls return the same one.
static func warm() -> Dictionary:
	return table()

## `{ layers: [{name, layer, key, scale}] by layer, biome_layer: {biome: layer}, snow_line: {biome: m},
## rock: layer, rock_slope: deg, snow: layer, wet: layer, wet_dist: m }`; -1 where no material has a rule.
static func table() -> Dictionary:
	_mutex.lock()
	if _table.is_empty():
		_table = build_table(GameData.TERRAIN_MATERIALS, GameData.BIOMES)
	var t := _table
	_mutex.unlock()
	return t

## Pure: the table from a material map and a biome map (each name -> resource or field dictionary).
static func build_table(materials: Dictionary, biomes: Dictionary) -> Dictionary:
	var layers: Array = []
	var biome_layer := {}
	var t := { "rock": -1, "rock_slope": 90.0, "snow": -1, "wet": -1, "wet_dist": 0.0 }
	for name in materials:
		var m: Variant = materials[name]
		var layer := int(_field(m, "layer", -1))
		layers.append({ "name": str(name), "layer": layer, "key": str(_field(m, "textureKey", "")),
			"scale": float(_field(m, "scale", 4.0)) })
		for b in _field(m, "biomes", []):
			if not biome_layer.has(str(b)):
				biome_layer[str(b)] = layer
		var slope := float(_field(m, "slopeMin", -1.0))
		if slope > 0.0 and (int(t["rock"]) < 0 or slope < float(t["rock_slope"])):
			t["rock"] = layer
			t["rock_slope"] = slope
		if bool(_field(m, "aboveSnowLine", false)) and int(t["snow"]) < 0:
			t["snow"] = layer
		var wet := float(_field(m, "nearWater", -1.0))
		if wet > 0.0 and int(t["wet"]) < 0:
			t["wet"] = layer
			t["wet_dist"] = wet
	layers.sort_custom(func(a, b): return int(a["layer"]) < int(b["layer"]))
	var lines := {}
	for b in biomes:
		lines[str(b)] = float(_field(biomes[b], "snowLine", NO_LINE))
	t["layers"] = layers
	t["biome_layer"] = biome_layer
	t["snow_line"] = lines
	return t

static func _field(res: Variant, field: String, fallback: Variant) -> Variant:
	var v: Variant = res.get(field) if res != null else null
	return v if v != null else fallback

## The layer a biome's flat ground is drawn with (the first material that lists it; 0 when none does).
static func biome_layer(t: Dictionary, biome: String) -> int:
	return int((t["biome_layer"] as Dictionary).get(biome, 0))

## The biome blend at `world_xz` as `{ biome: weight }` summing to 1: the chunk's own biome, and within
## `BLEND_TILES` of a border the biome across it (x, z and, near a corner, the diagonal), each weighing
## `BiomeBlend.chance(d)` (one half at the border, zero at the band's edge) against the own biome's
## `1 - max(chance)`. `biomes` is the gathered `{chunk_key: biome}` map.
static func biome_weights(world_xz: Vector2, biomes: Dictionary) -> Dictionary:
	var extent := float(VoxelConsts.CHUNK_SIZE) * VoxelConsts.TILE_SIZE
	var cx := floori(world_xz.x / extent)
	var cz := floori(world_xz.y / extent)
	var own := str(biomes.get(_key(Vector2i(cx, cz)), DEFAULT_BIOME))
	var lx := world_xz.x - cx * extent
	var lz := world_xz.y - cz * extent
	var dx := minf(lx, extent - lx) / VoxelConsts.TILE_SIZE
	var dz := minf(lz, extent - lz) / VoxelConsts.TILE_SIZE
	if minf(dx, dz) >= BLEND_TILES:
		return { own: 1.0 }
	var sx := -1 if lx < extent - lx else 1
	var sz := -1 if lz < extent - lz else 1
	var out := {}
	var top := 0.0
	var cands := [
		[Vector2i(cx + sx, cz), BiomeBlend.chance(dx, BLEND_TILES)],
		[Vector2i(cx, cz + sz), BiomeBlend.chance(dz, BLEND_TILES)],
		[Vector2i(cx + sx, cz + sz), BiomeBlend.chance(maxf(dx, dz), BLEND_TILES)],
	]
	for c in cands:
		var w := float(c[1])
		var b := str(biomes.get(_key(c[0]), own))
		if w <= 0.0 or b == own:
			continue
		out[b] = float(out.get(b, 0.0)) + w
		top = maxf(top, w)
	out[own] = float(out.get(own, 0.0)) + (1.0 - top)
	var sum := 0.0
	for b in out:
		sum += float(out[b])
	for b in out:
		out[b] = float(out[b]) / sum
	return out

static func _key(c: Vector2i) -> String:
	var w := TerrainSlice.wrap_chunk(c)
	return "%d,%d" % [w.x, w.y]

## The weight function. `ground` is `{ biome: weight }` (`biome_weights`), `slope_deg` the angle of the
## ground from flat, `altitude` metres above sea level and `water_dist` metres outside the nearest lake or
## river (INF when none). Returns `{ layer: weight }` with at most `SLOTS` entries, summing to 1.
static func weights(t: Dictionary, ground: Dictionary, slope_deg: float, altitude: float, water_dist: float) -> Dictionary:
	var w := {}
	# Each biome's own snow share, weighed by its part of the blend: averaging the lines instead would
	# let a biome with none (NO_LINE) lift a snowy neighbour's line out of reach inside the border band.
	var snowy := 0.0
	for b in ground:
		var g := float(ground[b])
		var layer := biome_layer(t, str(b))
		w[layer] = float(w.get(layer, 0.0)) + g
		var line := float((t["snow_line"] as Dictionary).get(str(b), NO_LINE))
		if line < NO_LINE:
			snowy += g * smoothstep(line - SNOW_BAND, line + SNOW_BAND, altitude)
	var wet := int(t["wet"])
	if wet >= 0 and water_dist < float(t["wet_dist"]):
		_take(w, wet, 1.0 - smoothstep(0.0, float(t["wet_dist"]), maxf(water_dist, 0.0)))
	var snow := int(t["snow"])
	if snow >= 0:
		_take(w, snow, snowy)
	var rock := int(t["rock"])
	if rock >= 0:
		var s := float(t["rock_slope"])
		_take(w, rock, smoothstep(s - SLOPE_BAND, s + SLOPE_BAND, slope_deg))
	return _top(w)

## Give `layer` a share `f` of the whole, scaling the others by `1 - f`.
static func _take(w: Dictionary, layer: int, f: float) -> void:
	if f <= 0.0:
		return
	for k in w:
		w[k] = float(w[k]) * (1.0 - f)
	w[layer] = float(w.get(layer, 0.0)) + f

## The `SLOTS` heaviest entries, renormalised to sum to 1 (ties: the lower layer).
static func _top(w: Dictionary) -> Dictionary:
	var keys: Array = []
	for k in w:
		if float(w[k]) > 0.0:
			keys.append(k)
	keys.sort_custom(func(a, b): return float(w[a]) > float(w[b]) or (float(w[a]) == float(w[b]) and int(a) < int(b)))
	keys.resize(mini(keys.size(), SLOTS))
	var sum := 0.0
	for k in keys:
		sum += float(w[k])
	var out := {}
	for k in keys:
		out[k] = float(w[k]) / sum
	return out

## Pack `{ layer: weight }` into vertex `i`'s channels of `w0` (layers 0-3) and `w1` (layers 4-7); the
## bytes sum to exactly 255 (the heaviest layer takes the rounding).
static func pack(w: Dictionary, w0: PackedByteArray, w1: PackedByteArray, i: int) -> void:
	var o := i * 4
	var left := 255
	var heavy := -1
	for k in w:
		var layer := int(k)
		if layer < 0 or layer >= LAYERS:
			continue
		var b := clampi(roundi(float(w[k]) * 255.0), 0, left)
		if heavy < 0 or float(w[k]) > float(w[heavy]):
			heavy = layer
		_write(w0, w1, o, layer, b)
		left -= b
	if heavy >= 0 and left > 0:
		_write(w0, w1, o, heavy, _read(w0, w1, o, heavy) + left)

static func _write(w0: PackedByteArray, w1: PackedByteArray, o: int, layer: int, b: int) -> void:
	if layer < 4:
		w0[o + layer] = b
	else:
		w1[o + layer - 4] = b

static func _read(w0: PackedByteArray, w1: PackedByteArray, o: int, layer: int) -> int:
	return w0[o + layer] if layer < 4 else w1[o + layer - 4]

## Vertex `i`'s weights back as `{ layer: weight }` (weights in 0..1), for tests and probes.
static func unpack(w0: PackedByteArray, w1: PackedByteArray, i: int) -> Dictionary:
	var out := {}
	for layer in LAYERS:
		var b := _read(w0, w1, i * 4, layer)
		if b > 0:
			out[layer] = float(b) / 255.0
	return out

## Metres from (x, z) to the nearest lake or river edge in `features` (`Hydrology.features_for_chunk`):
## 0 inside water, INF when there is none.
static func water_distance(features: Dictionary, x: float, z: float) -> float:
	var best := INF
	for lk in features.get("lakes", []):
		var dx := x - float(lk["x"])
		var dz := z - float(lk["z"])
		best = minf(best, sqrt(dx * dx + dz * dz) - float(lk["r"]))
	for sg in features.get("segs", []):
		var ax: float = sg[0]
		var az: float = sg[1]
		var abx: float = sg[2] - ax
		var abz: float = sg[3] - az
		var len2 := abx * abx + abz * abz
		var tt := clampf(((x - ax) * abx + (z - az) * abz) / len2, 0.0, 1.0) if len2 > 0.0 else 0.0
		var px := ax + abx * tt - x
		var pz := az + abz * tt - z
		best = minf(best, sqrt(px * px + pz * pz) - lerpf(float(sg[7]), float(sg[6]), tt))
	return maxf(best, 0.0)

## Add `custom0` (layers 0-3) and `custom1` (layers 4-7) to a build's arrays: the first `smooth_vertex_count`
## vertices (natural ground) get their weights, the rest (placed blocks) zero. `biomes` is the gathered
## `{chunk_key: biome}` map; `seed_v` reads the chunk's water features. Worker-safe once `warm()` has run.
## The loop runs natively when the extension lists `terrain_weights` (the same bytes; `apply_gd` is the
## reference): in GDScript it costs about as much as the chunk's whole native build.
static func apply(built: Dictionary, chunk_pos: Vector2i, biomes: Dictionary, seed_v: int) -> void:
	if NativeBuilder.use_native("terrain_weights"):
		var verts: PackedVector3Array = built.get("vertices", PackedVector3Array())
		var normals: PackedVector3Array = built.get("normals", PackedVector3Array())
		var natural := mini(int(built.get("smooth_vertex_count", verts.size())), verts.size())
		var out: Array = NativeBuilder.builder().call("terrain_weights", verts, normals, natural,
			native_params(chunk_pos, bool(built.get("local", false)), biomes, seed_v))
		if out.size() == 2:
			built["custom0"] = out[0]
			built["custom1"] = out[1]
			return
	apply_gd(built, chunk_pos, biomes, seed_v)

## The GDScript reference of `apply`.
static func apply_gd(built: Dictionary, chunk_pos: Vector2i, biomes: Dictionary, seed_v: int) -> void:
	var verts: PackedVector3Array = built.get("vertices", PackedVector3Array())
	var normals: PackedVector3Array = built.get("normals", PackedVector3Array())
	var n := verts.size()
	var w0 := PackedByteArray()
	var w1 := PackedByteArray()
	w0.resize(n * 4)
	w1.resize(n * 4)
	var natural := mini(int(built.get("smooth_vertex_count", n)), n)
	if natural > 0:
		var t := table()
		var extent := float(VoxelConsts.CHUNK_SIZE) * VoxelConsts.TILE_SIZE
		var local := bool(built.get("local", false))
		var corner := Vector2(chunk_pos) * extent if local else Vector2.ZERO
		var features := _features(t, chunk_pos, seed_v)
		var dry: bool = (features.get("lakes", []) as Array).is_empty() and (features.get("segs", []) as Array).is_empty()
		var sea := WorldShape.sea_level()
		var own := { str(biomes.get(_key(chunk_pos), DEFAULT_BIOME)): 1.0 }
		var lo := BLEND_TILES * VoxelConsts.TILE_SIZE
		var hi := extent - lo
		for i in natural:
			var v := verts[i]
			var x := v.x + corner.x
			var z := v.z + corner.y
			var lx := v.x if local else x - floorf(x / extent) * extent
			var lz := v.z if local else z - floorf(z / extent) * extent
			var inner := lx > lo and lx < hi and lz > lo and lz < hi
			var ground: Dictionary = own if inner else biome_weights(Vector2(x, z), biomes)
			var slope := rad_to_deg(acos(clampf(normals[i].y, -1.0, 1.0))) if i < normals.size() else 0.0
			var wd := INF if dry else water_distance(features, x, z)
			pack(weights(t, ground, slope, v.y - sea, wd), w0, w1, i)
	built["custom0"] = w0
	built["custom1"] = w1

## Phase 243 — the weights of an LOD-ring chunk's vertices (chunk-local to `corner`, world metres):
## every vertex reads the biome blend at its own place (an LOD chunk spans many level-0 chunks), and no
## wetness (the far rings draw no lake shores). Same weight function as `apply`, GDScript only.
static func apply_at(built: Dictionary, corner: Vector2, biomes: Dictionary) -> void:
	var verts: PackedVector3Array = built.get("vertices", PackedVector3Array())
	var normals: PackedVector3Array = built.get("normals", PackedVector3Array())
	var n := verts.size()
	var w0 := PackedByteArray()
	var w1 := PackedByteArray()
	w0.resize(n * 4)
	w1.resize(n * 4)
	var t := table()
	var sea := WorldShape.sea_level()
	for i in n:
		var v := verts[i]
		var slope := rad_to_deg(acos(clampf(normals[i].y, -1.0, 1.0))) if i < normals.size() else 0.0
		pack(weights(t, biome_weights(Vector2(v.x + corner.x, v.z + corner.y), biomes), slope, v.y - sea, INF), w0, w1, i)
	built["custom0"] = w0
	built["custom1"] = w1

static func _features(t: Dictionary, chunk_pos: Vector2i, seed_v: int) -> Dictionary:
	return Hydrology.features_for_chunk(chunk_pos, seed_v) if int(t["wet"]) >= 0 else { "lakes": [], "segs": [] }

## The flat inputs of the native `terrain_weights`: the table as arrays indexed by a biome id, the 5x5
## chunks round `chunk_pos` as biome ids (-1: not in `biomes`), and the water features as float runs.
static func native_params(chunk_pos: Vector2i, local: bool, biomes: Dictionary, seed_v: int) -> Dictionary:
	var t := table()
	var names: Array = [DEFAULT_BIOME]
	var grid := PackedInt32Array()
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var k := _key(chunk_pos + Vector2i(dx, dz))
			if not biomes.has(k):
				grid.append(-1)
				continue
			var b := str(biomes[k])
			if not names.has(b):
				names.append(b)
			grid.append(names.find(b))
	var layers := PackedInt32Array()
	var lines := PackedFloat64Array()
	for b in names:
		layers.append(biome_layer(t, str(b)))
		lines.append(float((t["snow_line"] as Dictionary).get(str(b), NO_LINE)))
	var features := _features(t, chunk_pos, seed_v)
	var lakes := PackedFloat64Array()
	for lk in features.get("lakes", []):
		lakes.append_array([float(lk["x"]), float(lk["z"]), float(lk["r"])])
	var segs := PackedFloat64Array()
	for sg in features.get("segs", []):
		segs.append_array([float(sg[0]), float(sg[1]), float(sg[2]), float(sg[3]), float(sg[6]), float(sg[7])])
	return {
		"chunk": chunk_pos, "local": local, "extent": float(VoxelConsts.CHUNK_SIZE) * VoxelConsts.TILE_SIZE,
		"tile": VoxelConsts.TILE_SIZE, "band": BLEND_TILES, "sea": WorldShape.sea_level(),
		"grid": grid, "layer": layers, "snow_line": lines,
		"rock": int(t["rock"]), "rock_slope": float(t["rock_slope"]), "snow": int(t["snow"]),
		"wet": int(t["wet"]), "wet_dist": float(t["wet_dist"]),
		"snow_band": SNOW_BAND, "slope_band": SLOPE_BAND, "no_line": NO_LINE,
		"lakes": lakes, "segs": segs,
	}

## Mesh-array format flags for a surface carrying `custom0` / `custom1`.
static func format_flags() -> int:
	return (Mesh.ARRAY_FORMAT_CUSTOM0 | Mesh.ARRAY_FORMAT_CUSTOM1
		| (Mesh.ARRAY_CUSTOM_RGBA8_UNORM << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		| (Mesh.ARRAY_CUSTOM_RGBA8_UNORM << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT))

## Put a build's custom arrays into a `Mesh.ARRAY_MAX` surface array; returns the extra format flags
## (0 when the build carries none, or they do not match its vertex count).
static func fill_surface(surface: Array, built: Dictionary) -> int:
	var w0: PackedByteArray = built.get("custom0", PackedByteArray())
	var w1: PackedByteArray = built.get("custom1", PackedByteArray())
	var n := (built.get("vertices", PackedVector3Array()) as PackedVector3Array).size()
	if n == 0 or w0.size() != n * 4 or w1.size() != n * 4:
		return 0
	surface[Mesh.ARRAY_CUSTOM0] = w0
	surface[Mesh.ARRAY_CUSTOM1] = w1
	return format_flags()
