extends RefCounted
## Column, biome and material queries, moved out of `VoxelSlice` verbatim (Phase 154).
## `s` is the owning slice; every moved method keeps a forwarder on the slice.

var s: Node

func _init(slice: Node) -> void:
	s = slice

## Top of the column at a world XZ position — the highest solid run's top, or
## BEDROCK_DEPTH when the column is mined out to the floor.
##
## This is the column's TOP, not the surface a body stands on: inside a tunnel the
## body's own Y decides which run holds it, which is what `sample_support_height_at`
## answers — and that is the read production uses for footing
## (`peer_wiring.sync_player_avatar`). This accessor stays because it is how a
## column's SHAPE is asserted (the suite), and because the pre-ceiling footing read
## it used to be is still what a caller outside a tunnel means.
func get_voxel_height_at(world_pos: Vector2) -> float:
	return s._column_top_at_tile(s._world_to_tile(world_pos))

## The top of the highest run AT OR BELOW from_y, or BEDROCK_DEPTH when nothing
## solid lies below. Phase 41 — the footing sampler is a function of the body's
## own Y for exactly one reason: a column-top sampler is only correct in a world
## with no ceilings, and a body standing under a tunnel roof would otherwise be
## placed ON the roof. A tolerance of half a step lets a body standing exactly on
## a surface still find it.
func sample_support_height_at(world_pos: Vector2, from_y: float) -> float:
	var support = s.BEDROCK_DEPTH
	for run in s.get_column_runs_at(world_pos):
		var top := float(run["top"])
		if top <= from_y + s.STEP_HEIGHT * 0.5 and top > support:
			support = top
	return support

## Phase 110 — true when any tile within Chebyshev `radius` tiles of `tile` carries an edit.
func has_edit_near(tile: Vector2i, radius: int) -> bool:
	if s._edits.is_empty():
		return false
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if s._edits.has(s._tile_key(Vector2i(tile.x + dx, tile.y + dz))):
				return true
	return false

## Phase 126 — `has_edit_near` for edits that reach `min_y` or higher: an edit whose span tops out below
## it (a deep mine under a tree) does not count. The rule `TreeSlice.CLEAR_DEPTH_M` applies live.
func has_edit_near_at(tile: Vector2i, radius: int, min_y: float) -> bool:
	if s._edits.is_empty():
		return false
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			for e in s._edits.get(s._tile_key(Vector2i(tile.x + dx, tile.y + dz)), []):
				# A deplete op is vein bookkeeping on the anchor tile, not a terrain edit: the dig that
				# took the ore carries its own span, which is what the depth rule judges.
				if (e as Dictionary).get("op", "") == "deplete":
					continue
				if float((e as Dictionary).get("top", INF)) >= min_y:
					return true
	return false

## Phase 116 — true when the chunk or the `radius` tiles around it hold any edit: one index lookup per
## chunk instead of `has_edit_near`'s string keys per tree. A false answer rules every tile of the chunk
## out for a `has_edit_near` of the same radius; a true one means "ask per tile".
func has_edits_near_chunk(chunk_pos: Vector2i, radius: int = 1) -> bool:
	if s._edits_by_chunk.is_empty():
		return false
	var first = chunk_pos * s.CHUNK_SIZE + Vector2i(-radius, -radius)
	var last = chunk_pos * s.CHUNK_SIZE + Vector2i(s.CHUNK_SIZE - 1 + radius, s.CHUNK_SIZE - 1 + radius)
	var c0 = s._tile_to_chunk(first)
	var c1 = s._tile_to_chunk(last)
	for cz in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			if not (s._edits_by_chunk.get(s._chunk_key(Vector2i(cx, cz)), {}) as Dictionary).is_empty():
				return true
	return false

## Advance to the next buildable material — only materials currently held in
## the inventory (sorted GameData.MATERIALS keys). Falls back to an empty
## selection when the inventory holds nothing buildable.
func cycle_place_material() -> String:
	var keys = s._buildable_materials()
	if keys.is_empty():
		s._place_material = ""
	else:
		var idx: int = keys.find(s._place_material)
		idx = (idx + 1) % keys.size()
		s._place_material = str(keys[idx])
	GameBus.block_place_material_changed.emit(s._place_material)
	return s._place_material

## Sorted material keys the player can actually place: every GameData.MATERIALS
## key held in the inventory. With no inventory wired, falls back to all keys.
func _buildable_materials() -> Array:
	var keys: Array = GameData.MATERIALS.keys()
	keys.sort()
	if s.inventory_slice == null or not s.inventory_slice.has_method("get_item_count"):
		return keys
	var out: Array = []
	for key in keys:
		if s.inventory_slice.get_item_count(str(key)) > 0:
			out.append(str(key))
	return out

## Small raised markers on the VEINS in one chunk, as
## `[{ "position": Vector3, "size": Vector3, "color": Color }]` — the geometry
## `build_chunk_arrays` emits on top of the ground. A natural column carries one when its
## top slice lies inside a LIVE vein (Phase 43): the marker marks a vein that is actually
## there, in the vein's own colour — a ferrite vein in ferrite rock included, since the
## marker is its only surface tell. A player-placed surface is never a vein, a column mined
## down OUT of a vein loses its marker, and an exhausted vein shows none. Pure, so the read
## is testable headlessly without a renderer.
##
## Phase 42 review pass 8 — this is the RESOLVE half's job, called from
## `collect_build_runs`, which hands it the memo it already filled (`cache`): the walk below
## asks the same question about the same columns, so the chunk's own runs are replayed once
## rather than twice. Called on its own (a test, a probe) it builds its own memo.
func vein_deposits(chunk_pos: Vector2i, heightmap: Array, cache: Dictionary = {}) -> Array:
	return s.vein_deposits_at(chunk_pos, heightmap, cache, s._edits, s.gather_biomes_for(chunk_pos),
		s._field(s._world_seed(), s._vein_taken))

## Phase 64 — the biome whose surface the tile at `world_xz` WEARS, resolved from the terrain
## slice: the same `blended_biome` answer the mesher gets from the gathered map.
func shown_biome_at(world_xz: Vector2) -> String:
	s._sync_guess_seed()
	var extent = float(s.CHUNK_SIZE * s.TILE_SIZE)
	var c := Vector2i(floori(world_xz.x / extent), floori(world_xz.y / extent))
	var around: Array = []
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			around.append(c + Vector2i(dx, dz))
	var biomes: Dictionary = {}
	for n in s._lending_ring(c, around):
		biomes[s._chunk_key(n)] = s._chunk_biome_memo(n)
	return s.blended_biome(world_xz, biomes, str(biomes[s._chunk_key(c)]))

func _chunk_biome_memo(chunk: Vector2i) -> String:
	var key = s._chunk_key(chunk)
	if not s._shown_biomes.has(key):
		if s._shown_biomes.size() >= s.SHOWN_BIOME_CACHE_MAX:
			s._shown_biomes.erase(s._shown_biomes.keys()[0])
		s._shown_biomes[key] = s._biome_at(s._chunk_world_center(chunk))
	return s._shown_biomes[key]

## A caller with no gathered biome map (an isolated test, a direct call) gets the one answer the
## terrain slice owes for this world position.
##
## Phase 42 review pass 10 — the test is now a LOOKUP OF THIS POSITION'S CHUNK, not "is the map
## non-empty". The old form returned any non-empty map untouched, so a PARTIALLY populated one —
## the realistic case, since a caller that names one chunk does not necessarily name the one a
## stray position falls in — passed straight through, and `biome_of` then answered
## `DEFAULT_BIOME` for the missing chunk, silently tinting a real chunk as TemperateForest. A
## miss is now resolved from the terrain slice (the same read `_biome_at` makes) and folded into
## a COPY, so the caller's map is never mutated and the answer is the chunk's real biome.
func _biomes_or_lookup(world_xz: Vector2, biomes: Dictionary) -> Dictionary:
	var extent = float(s.CHUNK_SIZE * s.TILE_SIZE)
	var ckey = s._chunk_key(Vector2i(floori(world_xz.x / extent), floori(world_xz.y / extent)))
	if biomes.has(ckey) or s.terrain_slice == null:
		return biomes
	var filled = biomes.duplicate()
	filled[ckey] = s._biome_at(world_xz)
	return filled

## Phase 65 — set the season tint of every biome in one call (`{biome: Color}`). Each chunk's
## material belongs to its own biome, so one biome's snow never tints another biome's chunks.
func set_season_tints(tints: Dictionary) -> void:
	s._season_tints = tints.duplicate()
	for biome in s._biome_mats:
		var mat: StandardMaterial3D = s._biome_mats[biome]
		var tint: Color = s._season_tints.get(biome, Color.WHITE)
		if not mat.albedo_color.is_equal_approx(tint):
			mat.albedo_color = tint

## The terrain material the chunks of `biome` share. ONE instance per biome for the slice's life.
## A chunk's material is chosen when it is BUILT: one built before `terrain_slice` is assigned
## resolves `DEFAULT_BIOME` and keeps that biome's material until its next rebuild.
func _terrain_material_for(biome: String) -> StandardMaterial3D:
	if not s._biome_mats.has(biome):
		var mat = s._make_terrain_material()
		mat.albedo_color = s._season_tints.get(biome, Color.WHITE)
		s._biome_mats[biome] = mat
	return s._biome_mats[biome]

## Top of a tile's highest solid run, or BEDROCK_DEPTH when nothing is solid.
func _column_top_at_tile(tile: Vector2i) -> float:
	var runs = s.get_runs_at_tile(tile)
	if runs.is_empty():
		return s.BEDROCK_DEPTH
	return float(runs[-1]["top"])

## The seed the ore field is evaluated with: the world's (Phase 41), or 0 for a slice with no
## terrain wired (an isolated rig).
func _world_seed() -> int:
	if s.terrain_slice != null and s.terrain_slice.has_method("get_world_seed"):
		return int(s.terrain_slice.get_world_seed())
	return 0

## The biome a resolve falls back to when nothing asked a terrain slice — see the
## `DEFAULT_BIOME` constant (Phase 42 review pass 9).
func _biome_at(xz: Vector2) -> String:
	s.biome_lookups += 1
	if s.terrain_slice != null and s.terrain_slice.has_method("get_biome_at"):
		return s.terrain_slice.get_biome_at(xz)
	return s.DEFAULT_BIOME

## A tile's natural (unedited) runs, from its chunk's heightmap when that chunk is
## built, else from the deterministic terrain sampler — the placeholder a tile
## needs BEFORE streaming has reached it, e.g. when a load-time migration runs
## first. Both answer the same height by construction (the heightmap is
## `get_height_at` sampled on the tile grid), so the migration is migration, not a
## guess.
func _base_runs_for_tile(tile: Vector2i) -> Array:
	var top = s._base_top_for_tile(tile)
	if top <= s.BEDROCK_DEPTH:
		return []
	return [{ "bottom": s.BEDROCK_DEPTH, "top": top, "material": "" }]

func _base_top_for_tile(tile: Vector2i) -> float:
	var chunk = s._tile_to_chunk(tile)
	var ckey = s._chunk_key(chunk)
	if s._heightmaps.has(ckey):
		var hm: Array = s._heightmaps[ckey]
		var lx = tile.x - chunk.x * s.CHUNK_SIZE
		var lz = tile.y - chunk.y * s.CHUNK_SIZE
		return s._voxel_height(float(hm[lz * s.CHUNK_SIZE + lx]))
	if s.terrain_slice != null and s.terrain_slice.has_method("get_height_at"):
		return s._voxel_height(s.terrain_slice.get_height_at(Vector2(tile.x * s.TILE_SIZE, tile.y * s.TILE_SIZE)))
	return s.BEDROCK_DEPTH
