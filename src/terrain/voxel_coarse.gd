extends RefCounted
## Phase 190 — coarse chunk builds for the ground beyond the near ring.
##
## A full build resolves all 66×66 tiles of a chunk and its ring (edits, ore field, topsoil, biome dither)
## and greedy-meshes 64×64 columns of 0.5 m: about 21 ms of worker time per chunk with the native builder,
## of which the heightmap is under 1 ms. Most of the 9×9 window is ground the player only looks at, so it
## is built from one column per cell of `step`×`step` tiles: 32×32 cells of 1 m (`step` 2) or 16×16 cells
## of 2 m (`step` 4). The heightmap is still the full one (it is cheap, and every height query, neighbour
## seam and spawn reads it), but only one tile per cell is resolved and meshed.
##
## Rules, each one there for the seam with a neighbour built at another level:
##   * A cell stands at the HIGHEST of its tiles' natural tops, and wears that tile's biome colours: its host
##     rock (iced toward the poles) and the topsoil of the biome it shows (the dithered border band
##     included), as a full build colours an unveined tile. The ore field is not read: a rare vein showing
##     at the surface is a few tiles across, a single coarse cell would only flicker with it, and its lookup
##     was most of a coarse build's cost. Veins show once the chunk is upgraded. Coarse ground never dips below
##     the true surface: at a chunk edge it is at least as high as every true column on its side, which is
##     the height a full neighbour subtracts its own walls against.
##   * Phase 241: the cells are meshed smooth, by the full build's surface-nets mesher on the scaled grid
##     (`VoxelSmooth.mesh_coarse_columns`). The columns past the edge repeat the edge column, so the ground
##     runs flat to the chunk's edge plane, and every mesh edge on that plane drops a skirt to bedrock. A
##     full neighbour's ground, which the coarse ground stands above, meets the skirt, so no gap opens
##     between levels whatever order they were built in. Two coarse neighbours both skirt.
##   * No deposits, no edits, and only a conservative collision: the same triangles as a soup, so a
##     body on coarse ground stands at or above the true surface, never inside it. It is parked like a full
##     chunk's (Phase 189) and attached only where the near ring wants collision before the full build lands
##     (in practice, under a fast flyer, whose chunk is not upgraded until it slows). A chunk with an edit
##     is always built at full detail (`NearRing.lod_for`), so a placed block never vanishes at a distance.
##
## Pure and static (no node state), so it runs on a worker. `build_coarse_arrays` routes the native port
## when the extension has it; `build_coarse_arrays_gd` is the reference the parity suite compares.

const VoxelSlice := preload("res://src/terrain/voxel_slice.gd")
const VoxelConsts := preload("res://src/terrain/voxel_consts.gd")
const NativeBuilder := preload("res://src/terrain/native_builder.gd")
const VoxelSmooth := preload("res://src/terrain/voxel_smooth.gd")
const OreField := preload("res://src/terrain/ore_field.gd")
const CHUNK_SIZE := VoxelConsts.CHUNK_SIZE
const TILE_SIZE := VoxelConsts.TILE_SIZE
const BEDROCK_DEPTH := VoxelConsts.BEDROCK_DEPTH
const FALLBACK_TERRAIN_COLOR := VoxelConsts.FALLBACK_TERRAIN_COLOR

## The level of a full build: one cell per tile.
const FULL := 1
## The coarse levels, in tiles per cell side: 32×32 cells of 1 m, then 16×16 cells of 2 m.
const STEPS: Array[int] = [2, 4]

## The chunk's coarse arrays at `step` (one of `STEPS`). `input` carries the build's `biomes` (edits,
## neighbour maps and the ore field's inputs are not read). `local` as in
## `VoxelMesh.build_chunk_arrays`.
static func build_coarse_arrays(chunk_pos: Vector2i, heightmap: Array, input: Dictionary, step: int, local: bool = true) -> Dictionary:
	if NativeBuilder.use_native("build_coarse_arrays"):
		var native := NativeBuilder.builder().call("build_coarse_arrays", chunk_pos, heightmap, input, step, local, VoxelSlice.native_runs_cfg()) as Dictionary
		if native.has("vertices"):   # a rejected input comes back empty: use the reference
			return native
	return build_coarse_arrays_gd(chunk_pos, heightmap, input, step, local)

## The GDScript reference of `build_coarse_arrays`: the columns, meshed smooth (Phase 241).
static func build_coarse_arrays_gd(chunk_pos: Vector2i, heightmap: Array, input: Dictionary, step: int, local: bool = true) -> Dictionary:
	return VoxelSmooth.mesh_coarse_columns(chunk_pos, coarse_columns(chunk_pos, heightmap, input, step), step, local)

## One resolved column per cell, row-major: `tops` (the highest natural top of the cell's tiles), and the
## `colors`, `top_colors`, `soil_colors` and `soil_depths` of that tile's biome (see the header). The first
## tile in row-major order wins a tie.
static func coarse_columns(chunk_pos: Vector2i, heightmap: Array, input: Dictionary, step: int) -> Dictionary:
	@warning_ignore("integer_division")
	var n := CHUNK_SIZE / step
	var biomes: Dictionary = input.get("biomes", {})
	var styles := {}
	var tops := PackedFloat64Array()
	var colors := PackedColorArray()
	var top_colors := PackedColorArray()
	var soil_colors := PackedColorArray()
	var soil_depths := PackedFloat64Array()
	for cz in range(n):
		for cx in range(n):
			var best := -INF
			var btx := 0
			var btz := 0
			for dz in range(step):
				for dx in range(step):
					var tx := cx * step + dx
					var tz := cz * step + dz
					var h := VoxelConsts.voxel_height(float(heightmap[tz * CHUNK_SIZE + tx]))
					if h > best:
						best = h
						btx = tx
						btz = tz
			tops.append(best)
			if best <= BEDROCK_DEPTH:
				colors.append(FALLBACK_TERRAIN_COLOR)
				top_colors.append(FALLBACK_TERRAIN_COLOR)
				soil_colors.append(FALLBACK_TERRAIN_COLOR)
				soil_depths.append(0.0)
				continue
			var gx := chunk_pos.x * CHUNK_SIZE + btx
			var gz := chunk_pos.y * CHUNK_SIZE + btz
			var world_xz := Vector2(gx * TILE_SIZE + TILE_SIZE * 0.5, gz * TILE_SIZE + TILE_SIZE * 0.5)
			var biome := VoxelSlice.biome_of(world_xz, biomes)
			var color := VoxelSlice.icy(VoxelSlice._material_color(OreField.host_material(biome)), world_xz.y)
			var shown := VoxelSlice.blended_biome(world_xz, biomes, biome)
			if not styles.has(shown):
				styles[shown] = VoxelSlice.surface_style(shown)
			var style: Dictionary = styles[shown]
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
