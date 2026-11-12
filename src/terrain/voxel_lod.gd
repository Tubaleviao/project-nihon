extends RefCounted
## Phase 243 — one LOD-ring chunk: the ground past the voxel window at a level of detail.
##
## A level-k chunk (`LodRingPolicy.chunk_meters(k)` a side) is `CELLS`² columns of
## `LodRingPolicy.cell_meters(k)`, meshed smooth by the full build's surface-nets mesher on the scaled grid
## (`VoxelSmooth.mesh_lod_columns`, the coarse chunks' path with its own cell count) with a skirt to
## bedrock under every edge. Each column stands at the ground the full chunks lay down at the cell's
## middle: the shape (or a chunk's generation record, from the `snap` of `ChunkRecords`) plus the detail
## noise, the polar ice and the lakes' surfaces (`DistantTerrain.ground_at`), quantised as a full chunk's
## columns are. Edits are summarised to the cell: an edited tile known to the client raises its cell to
## the tile's top (`edit_tops`), so a tower stands in the far ground too.
##
## The rings sit `DROP_CELLS` of a cell below the ground, each coarser ring a little lower than the finer
## one inside it: the finer level's edge skirts (the window's coarse chunks' and every LOD chunk's) then
## always close the crack between two levels from above.
##
## Render only: no collision, no deposits. Pure and static, so it runs on a worker.

const VoxelSlice := preload("res://src/terrain/voxel_slice.gd")
const VoxelConsts := preload("res://src/terrain/voxel_consts.gd")
const VoxelSmooth := preload("res://src/terrain/voxel_smooth.gd")
const OreField := preload("res://src/terrain/ore_field.gd")
const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")
const TerrainWeights := preload("res://src/terrain/terrain_weights.gd")
const DistantTerrain := preload("res://src/terrain/distant_terrain.gd")
const LodRingPolicy := preload("res://src/terrain/lod_ring_policy.gd")

const CELLS := LodRingPolicy.CELLS
const TILE_SIZE := VoxelConsts.TILE_SIZE
const BEDROCK_DEPTH := VoxelConsts.BEDROCK_DEPTH
const FALLBACK_TERRAIN_COLOR := VoxelConsts.FALLBACK_TERRAIN_COLOR
## How far below the ground a ring is drawn, in cells of its own level.
const DROP_CELLS := 0.25

## The corner of level-`level` chunk `lchunk`, in world metres (x, z).
static func corner_m(level: int, lchunk: Vector2i) -> Vector2:
	return Vector2(lchunk) * LodRingPolicy.chunk_meters(level)

## Add to `biomes` (`{ "cx,cz": biome }`) the biome of the level-0 chunk under each of `points` (world
## x, z) not there yet: the recorded biome where `snap` holds the chunk's record, else the generator's.
## Only the chunks a cell or a vertex lies in are read: a far ring's chunk spans up to 32×32 of them.
## Worker-safe (reads no shared table).
static func gather_biomes_at(points: PackedVector2Array, snap: Dictionary, biomes: Dictionary) -> void:
	for p in points:
		var c := Vector2i(floori(p.x / TerrainSlice.CHUNK_METERS), floori(p.y / TerrainSlice.CHUNK_METERS))
		var key := VoxelSlice._chunk_key(c)
		if biomes.has(key):
			continue
		var rec: Dictionary = snap.get(TerrainSlice.wrap_chunk(c), {})
		biomes[key] = str(rec["b"]) if not rec.is_empty() else TerrainSlice.generated_biome_for_chunk(c)

## The middles of an LOD chunk's cells, in world metres.
static func cell_middles(level: int, lchunk: Vector2i) -> PackedVector2Array:
	var cell := LodRingPolicy.cell_meters(level)
	var corner := corner_m(level, lchunk)
	var out := PackedVector2Array()
	for cz in CELLS:
		for cx in CELLS:
			out.append(corner + Vector2((float(cx) + 0.5) * cell, (float(cz) + 0.5) * cell))
	return out

## The chunk's columns (the shape `VoxelSmooth.load_columns` reads): `tops`, `colors`, `top_colors`,
## `soil_colors`, `soil_depths`. `edit_tops` maps a tile (Vector2i, global tile coordinates) to its top.
static func lod_columns(level: int, lchunk: Vector2i, seed_v: int, snap: Dictionary, edit_tops: Dictionary, biomes: Dictionary, noise: FastNoiseLite = null) -> Dictionary:
	if noise == null:
		noise = FastNoiseLite.new()
		TerrainSlice.configure_noise(noise, seed_v)
	var cell := LodRingPolicy.cell_meters(level)
	var corner := corner_m(level, lchunk)
	var w := float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS
	var drop := DROP_CELLS * cell
	var tops := PackedFloat64Array()
	tops.resize(CELLS * CELLS)
	for cz in CELLS:
		for cx in CELLS:
			var x := corner.x + (float(cx) + 0.5) * cell
			var z := corner.y + (float(cz) + 0.5) * cell
			tops[cz * CELLS + cx] = VoxelConsts.voxel_height(DistantTerrain.ground_at(noise, seed_v, x, z, w, snap))
	for tile in edit_tops:
		var t: Vector2i = tile
		var cx := floori(((float(t.x) + 0.5) * TILE_SIZE - corner.x) / cell)
		var cz := floori(((float(t.y) + 0.5) * TILE_SIZE - corner.y) / cell)
		if cx < 0 or cz < 0 or cx >= CELLS or cz >= CELLS:
			continue
		tops[cz * CELLS + cx] = maxf(tops[cz * CELLS + cx], float(edit_tops[tile]))
	var styles := {}
	var colors := PackedColorArray()
	var top_colors := PackedColorArray()
	var soil_colors := PackedColorArray()
	var soil_depths := PackedFloat64Array()
	for i in CELLS * CELLS:
		tops[i] -= drop
		if tops[i] <= BEDROCK_DEPTH:
			colors.append(FALLBACK_TERRAIN_COLOR)
			top_colors.append(FALLBACK_TERRAIN_COLOR)
			soil_colors.append(FALLBACK_TERRAIN_COLOR)
			soil_depths.append(0.0)
			continue
		@warning_ignore("integer_division")
		var world_xz := corner + Vector2((float(i % CELLS) + 0.5) * cell, (float(i / CELLS) + 0.5) * cell)
		var biome := VoxelSlice.biome_of(world_xz, biomes)
		var color := VoxelSlice.icy(VoxelSlice._material_color(OreField.host_material(biome)), world_xz.y)
		if not styles.has(biome):
			styles[biome] = VoxelSlice.surface_style(biome)
		var style: Dictionary = styles[biome]
		colors.append(color)
		if style.is_empty():
			top_colors.append(color)
			soil_colors.append(color)
			soil_depths.append(0.0)
		else:
			top_colors.append(VoxelSlice.icy(style["top"], world_xz.y))
			soil_colors.append(VoxelSlice.icy(style["soil"], world_xz.y))
			soil_depths.append(float(style["depth"]))
	return { "tops": tops, "colors": colors, "top_colors": top_colors, "soil_colors": soil_colors, "soil_depths": soil_depths }

## The chunk's arrays, chunk-local to `corner_m(level, lchunk)`, with the terrain weights (Phase 242) when
## `weights`. `biomes` is filled in here as `gather_biomes_at` (a caller may pass ones it has).
static func build_lod_arrays(level: int, lchunk: Vector2i, seed_v: int, snap: Dictionary = {}, edit_tops: Dictionary = {}, biomes: Dictionary = {}, weights: bool = true) -> Dictionary:
	gather_biomes_at(cell_middles(level, lchunk), snap, biomes)
	var cols := lod_columns(level, lchunk, seed_v, snap, edit_tops, biomes)
	@warning_ignore("integer_division")
	var step := int(round(LodRingPolicy.cell_meters(level) / TILE_SIZE))
	var built := VoxelSmooth.mesh_lod_columns(cols, step, CELLS)
	built["level"] = level
	built["chunk"] = lchunk
	built["biome"] = VoxelSlice.biome_of(corner_m(level, lchunk) + Vector2.ONE * LodRingPolicy.chunk_meters(level) * 0.5, biomes)
	if weights:
		# A vertex's blend reads its own chunk and, near a chunk border, the one across it.
		var corner := corner_m(level, lchunk)
		var at := PackedVector2Array()
		var reach := TerrainWeights.BLEND_TILES * TILE_SIZE
		for v in built["vertices"] as PackedVector3Array:
			for o in [Vector2.ZERO, Vector2(-reach, -reach), Vector2(reach, reach), Vector2(-reach, reach), Vector2(reach, -reach)]:
				at.append(Vector2(v.x + corner.x, v.z + corner.y) + o)
		gather_biomes_at(at, snap, biomes)
		TerrainWeights.apply_at(built, corner, biomes)
	return built
