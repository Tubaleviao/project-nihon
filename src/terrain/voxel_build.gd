extends RefCounted
## Chunk build, input gathering and unload, moved out of `VoxelSlice` verbatim (Phase 154).
## `s` is the owning slice; every moved method keeps a forwarder on the slice.

var s: Node

func _init(slice: Node) -> void:
	s = slice

## Build (or rebuild) the mesh and collision for one chunk.
##
## Phase 42 — `arrays` is the optional result of a `build_chunk_arrays()` call made
## on a WORKER, and `revision` is the `chunk_revision` it was dispatched at (see
## `chunk_revision`); omit both for the synchronous build, which resolves its own
## input and is what the bus path, the edit path and every isolated test use.
##
## Returns TRUE when a mesh was attached, FALSE when the call was a no-op. Two refusals:
## a worker result whose revision has moved on, and (Phase 42 review) a worker result that
## carried NOTHING — a failed task. The second one used to fall through to the synchronous
## branch below and rebuild the whole chunk on the main thread, which is exactly the stall
## the worker exists to remove, done SILENTLY. It is a refusal now, and the manager answers
## a refusal with a fresh dispatch (see `ChunkManager._apply_build_entry`). The 2-arg form
## is untouched: an empty `arrays` with no revision means "build it here", on purpose.
func build_chunk(chunk_pos: Vector2i, heightmap: Array, arrays: Dictionary = {}, revision: int = -1) -> bool:
	var key = s._chunk_key(chunk_pos)
	if revision >= 0 and revision != s.chunk_revision(chunk_pos):
		return false   # stale worker result: this chunk was rebuilt while it was in flight
	if arrays.is_empty() and revision >= 0:
		return false   # a worker build that produced nothing: refuse, do not rebuild here
	s._chunk_revision[key] = s.chunk_revision(chunk_pos) + 1

	# Remember the base heightmap so edits can be reapplied on rebuild.
	s._heightmaps[key] = heightmap
	s._settle.release_chunk(key)   # Phase 137: columns parked until this chunk loaded settle now
	if s._guess_heightmaps.has(key):
		if s._guess_heightmaps[key] != heightmap:
			s.Diag.warn("VoxelSlice: chunk %s was built from a heightmap that differs from the guess its neighbours were built against; seams may show" % key)
		s._guess_heightmaps.erase(key)

	# Remove any previous version of this chunk.
	if s._chunks.has(key):
		s._chunks[key].queue_free()
		s._chunks.erase(key)

	var root := Node3D.new()
	root.name = "Chunk_%s" % key
	s.add_child(root)
	s._chunks[key] = root
	if s._standins.has(key):
		s._free_standin(key)   # the folded-frame chunk is here: its stand-in goes (Phase 120)

	# --- Visual mesh + collision from ONE triangle soup ---
	# The rare-vein deposits below are added AFTER this, deliberately: they are
	# decoration, and a box the player can see but not stand on is the correct
	# read for "a vein showing through the ground". Collision built from this
	# surface can therefore never inherit one.
	var built: Dictionary = arrays
	if built.is_empty() and not s.attach_geometry:
		built = s.no_geometry_arrays()   # #437: nothing below reads the arrays on a server
	elif built.is_empty():
		# Only the SYNCHRONOUS path reaches this now: a worker result that carried nothing
		# was refused above rather than quietly rebuilt here (Phase 42 review).
		built = s.build_chunk_arrays(chunk_pos, heightmap, s.collect_build_runs(chunk_pos, heightmap), true)
	# A chunk-local build puts the node at the chunk's corner: the corner is summed with the scene
	# offset in double precision, so far from the origin the node's position is small and exact and
	# the vertices stay small too (float32 vertices at 2e7 m would snap to 2 m and shatter the ground).
	root.position = s._origin.value
	if bool(built.get("local", false)):
		root.position = Vector3(
			float(chunk_pos.x * s.CHUNK_SIZE) * s.TILE_SIZE + s._origin.value.x,
			s._origin.value.y,
			float(chunk_pos.y * s.CHUNK_SIZE) * s.TILE_SIZE + s._origin.value.z)
	# The chunk's middle in the root's own space: what a fold reads to know which chunk a carried
	# root stands in for (`adopt_standins`).
	var half = float(s.CHUNK_SIZE) * s.TILE_SIZE * 0.5
	if bool(built.get("local", false)):
		root.set_meta("centre", Vector3(half, 0.0, half))
	else:
		root.set_meta("centre", Vector3(float(chunk_pos.x * s.CHUNK_SIZE) * s.TILE_SIZE + half, 0.0,
			float(chunk_pos.y * s.CHUNK_SIZE) * s.TILE_SIZE + half))
	var chunk_mat = null
	if s.attach_geometry:
		var surface = s._mesh_from_arrays(built)
		var mesh_inst := MeshInstance3D.new()
		mesh_inst.mesh = surface
		chunk_mat = s._terrain_material_for(s._biome_at(s._chunk_center_xz(chunk_pos)))
		mesh_inst.material_override = chunk_mat
		root.add_child(mesh_inst)

		# --- Water (Phase 51): a flat, collision-free surface where the ground is below sea level. ---
		var water_mesh = s.water_mesh_for(chunk_pos, heightmap, bool(built.get("local", false)))
		if water_mesh != null:
			var water_inst := MeshInstance3D.new()
			water_inst.name = "Water"
			water_inst.mesh = water_mesh
			water_inst.material_override = s._ice_material() if s.is_frozen_chunk(chunk_pos) else s._water_material()
			root.add_child(water_inst)

		# --- Rare-vein deposits: a SECOND mesh, from arrays the build already carries. ---
		# Phase 42 review pass 8 — this used to call `vein_deposits()` HERE, on the main thread,
		# walking all 4096 of the chunk's columns a second time (run replay + a biome and
		# material roll per tile) after the worker had already finished. The list is resolved
		# by `collect_build_runs` now and the boxes are emitted by `build_chunk_arrays`, so the
		# main thread only attaches what it is handed. They stay a separate mesh with no
		# collision, deliberately: they are decoration, and a box the player can see but not
		# stand on is the correct read for "a vein showing through the ground".
		var deposit_vertices: PackedVector3Array = built.get("deposit_vertices", PackedVector3Array())
		if not deposit_vertices.is_empty():
			var deposit_inst := MeshInstance3D.new()
			deposit_inst.mesh = s._mesh_from_arrays({
				"vertices": built["deposit_vertices"],
				"normals":  built["deposit_normals"],
				"colors":   built["deposit_colors"],
				"indices":  built["deposit_indices"],
			})
			deposit_inst.material_override = chunk_mat
			root.add_child(deposit_inst)

	# --- Collision: ONE ConcavePolygonShape3D per chunk, from the same triangles
	# the mesh shows. The per-row run-merge this replaces existed because
	# TILE_SIZE 0.5 would otherwise emit 4096 boxes per chunk; a single trimesh is
	# smaller than a handful of boxes AND describes everything the boxes could
	# not (ceilings, overhangs, a span of solid material). A CharacterBody3D does
	# not stand ON a concave shape directly — it collides WITH the static body
	# carrying it, which is the supported direction. ---
	if not s.attach_geometry:
		return true
	var static_body := StaticBody3D.new()
	static_body.collision_layer = s.TERRAIN_COLLISION_LAYER
	static_body.collision_mask = 0
	var col_shape := CollisionShape3D.new()
	var trimesh := ConcavePolygonShape3D.new()
	trimesh.set_faces(built["collision"])
	# Both sides of a wall collide, so a body inside a tunnel is held by the roof
	# from below as well as by the floor from above.
	trimesh.backface_collision = true
	col_shape.shape = trimesh
	static_body.add_child(col_shape)
	root.add_child(static_body)
	return true

## Resolve every column a chunk build must READ into a plain table the pure builder can
## consume — plus the chunk's rare-vein deposit list.
##
## Phase 42 review pass 9 — this is a two-line ACCESSOR now, over a split that makes the whole
## resolve worker-legal. The main thread only GATHERS the plain state it reads
## (`gather_build_input`: the chunk's own edits plus the ring's, the ring chunks' heightmaps,
## the ring chunks' biomes), and the STATIC `build_runs()` does the per-tile work from nothing
## but that payload — so `ChunkManager._dispatch_build` can run the resolve AND the build on the
## worker, and the main thread stops paying the ~43 ms per-tile resolve per dispatch (measured;
## see the split probe). This wrapper keeps the synchronous callers — the bus path, an isolated
## test — on the same code path, and the answer is identical because the payload carries exactly
## what the old body read off the slice.
##
## The table covers the chunk's own tiles AND its one-tile ring (the seam neighbours
## whose runs the wall subtraction reads), keyed by global tile ("gx,gz") → Array of
## run records carrying `bottom`, `top`, `material` and the resolved `color`. A ring
## tile whose chunk is not built reads as an EMPTY list, which is the documented
## UNKNOWN-column path: the side that HAS the material emits the facing wall.
##
## Returns `{ "runs": <that table>, "deposits": [ { position, size, color } ] }`.
##
## Phase 42 review pass 8 — three things that pass fixed in the resolve half, all three of them
## still true of `build_runs()`:
##   * the DEPOSITS are resolved here, not in `build_chunk`. `vein_deposits()` walked
##     all 4096 of the chunk's own columns a second time (its own run replay, plus a
##     biome lookup and a material roll per tile) on the MAIN thread, on every build —
##     including every build the worker had just finished, i.e. the stall the worker
##     exists to remove, paid on the main thread right after it. The pure builder emits
##     the deposit BOXES from the list resolved here, so the worker owns all the
##     geometry and `build_chunk` only attaches.
##   * the BIOME is resolved by CHUNK, from the gathered map (`biome_of`). Biome assignment is a
##     per-chunk property, so a 66×66 ring asks for a handful of chunks' worth of answers rather
##     than 4356 — and the terrain-slice call behind each one is a method lookup plus a
##     world→chunk conversion.
##   * the material → COLOUR map is memoised per call. A biome rolls a handful of
##     materials out of a 100-weight table, so the same few colours came back 4356
##     times, each resolution going through `material_for_biome` again.
func collect_build_runs(chunk_pos: Vector2i, heightmap: Array) -> Dictionary:
	return s.build_runs(chunk_pos, heightmap, s.gather_build_input(chunk_pos, heightmap))

## Phase 42 review pass 9 — copy the mutable slice state a chunk's resolve reads, as PLAIN data,
## on the MAIN thread. Everything here is a read that must not happen on a worker: `_edits` and
## `_heightmaps` are the main thread's to mutate, and the biome comes from the terrain slice.
##
## Three things are gathered, and the resolve's reads map onto them exactly:
##   * `edits` — the ops of every tile in the chunk PLUS its one-tile ring that HAS ops
##     (deep-copied, because the main thread can still append to an op list while the worker
##     reads it). An absent key means "no ops for this tile", which is what `_edits.get` said.
##   * `neighbour_heightmaps` — the ring's chunks' maps, for the tiles the ring reaches into.
##     MEMBERSHIP IS THE ANSWER: a chunk absent here is the UNKNOWN neighbour `_neighbour_runs`
##     reads as empty, so the payload carries that decision rather than re-deriving it later.
##   * `biomes` — the biome of every chunk the ring touches, keyed by chunk. A tile's biome is
##     its chunk's biome, so this is the host-rock half of the colour step.
##
## Phase 43 — and the ORE FIELD's two inputs, the other half of the colour step:
##   * `seed` — the world seed the field is a function of (`_world_seed`).
##   * `depleted` — vein id → units taken (`_vein_taken`, copied), so an exhausted vein
##     renders as host rock. It is the whole index, not a window: a vein's anchor tile can
##     sit outside the chunk's ring, and the index is one entry per vein ever mined.
func gather_build_input(chunk_pos: Vector2i, _heightmap: Array) -> Dictionary:
	return {
		"edits":                s._gather_edits(chunk_pos),
		"neighbour_heightmaps": s._gather_neighbour_heightmaps(chunk_pos),
		"biomes":               s.gather_biomes_for(chunk_pos),
		"seed":                 s._world_seed(),
		"depleted":             s._vein_taken.duplicate(),
	}

## The edited tiles of the chunk + its one-tile ring, deep-copied. It walks the CHUNK INDEX
## (`_edits_by_chunk`) and not the whole `_edits` log, so it is proportional to how much has
## been edited around THIS chunk; a fresh world gathers nothing at all.
##
## Phase 42 review pass 10 — this used to iterate every key in `_edits` and `split(",")` its
## string to test it against the window bounds, i.e. one string split per edit in the WORLD
## per dispatch (the row's measurement), even when nothing near the chunk had been touched.
## The ring is at most 3×3 chunks (`_ring_chunks`), and every tile of the chunk+ring window
## belongs to one of those chunks, so reading their three buckets IS the window.
func _gather_edits(chunk_pos: Vector2i) -> Dictionary:
	var out: Dictionary = {}
	if s._edits_by_chunk.is_empty():
		return out
	for chunk in s._ring_chunks(chunk_pos):
		var bucket: Dictionary = s._edits_by_chunk.get(s._chunk_key(chunk), {})
		for key in bucket:
			out[key] = s._edits[key].duplicate(true)
	return out

## Phase 69 — the neighbour offsets (each component in -1..1, never (0,0)) across which `chunk_pos`
## carries a height-changing edit on a border tile. Deplete ops never change a height, so a
## chunk whose only edits are deplete ops reports none. A tile on a corner names both edge
## neighbours and the diagonal one.
func seam_borders(chunk_pos: Vector2i) -> Array:
	var found: Dictionary = {}
	var bucket: Dictionary = s._edits_by_chunk.get(s._chunk_key(chunk_pos), {})
	for tile_key in bucket:
		for off in s._shaped_border_offsets(s._key_to_tile(str(tile_key)), s._edits.get(tile_key, [])):
			found[off] = true
	return found.keys()

## The heightmaps of the chunks the ring reads across, when they are KNOWN.
##
## Phase 42 review pass 10 — the maps are shared BY REFERENCE, deliberately, and this is the
## stated half of an asymmetry with `_gather_edits` (which DEEP-COPIES the op lists). The
## reason is which of the two the main thread ever mutates in place: an edit op list is
## APPENDED to (`_append_edit` does `ops.append` on the very array the worker may be reading),
## so it must be copied; a heightmap array is only ever REPLACED wholesale (`build_chunk`
## stores a freshly generated one, `_prune_heightmaps` erases the entry) and never mutated in
## place, so sharing it is safe — the worker only reads it, and a rebuild that regenerates the
## map hands the worker a NEW array rather than editing the array it holds. If a future change
## ever writes a heightmap IN PLACE, it must copy here too. The same holds for the cached
## GUESS maps (`_generated_heightmap`): they are shared by reference too, and a guess is
## assumed to equal the map the chunk's own build later stores — `build_chunk` warns when a
## caller hands it a different one (tests, a future structure-flattening pass).
func _gather_neighbour_heightmaps(chunk_pos: Vector2i) -> Dictionary:
	var out: Dictionary = {}
	for chunk in s._ring_chunks(chunk_pos):
		var ckey = s._chunk_key(chunk)
		if s._heightmaps.has(ckey):
			out[ckey] = s._heightmaps[ckey]
		else:
			var guess: Array = [] if chunk == chunk_pos else s._generated_heightmap(chunk, ckey)
			if not guess.is_empty():
				out[ckey] = guess
	return out

## Phase 49 — an UNBUILT neighbour's heightmap, from the terrain's deterministic generator
## (identical to what its own build will store), so two chunks built from the same first
## ring each see the other's real surface instead of an empty column and neither emits a
## bedrock-to-top seam wall. Kept apart from `_heightmaps` (which means "built"): a guess
## is dropped when that chunk builds or leaves the ring. Empty when no generator is wired.
func _generated_heightmap(chunk: Vector2i, ckey: String) -> Array:
	s._sync_guess_seed()
	if s._guess_heightmaps.has(ckey):
		return s._guess_heightmaps[ckey]
	if s.terrain_slice == null or not s.terrain_slice.has_method("generate_heightmap"):
		return []
	var hm: Array = s.terrain_slice.generate_heightmap(chunk)
	s._guess_heightmaps[ckey] = hm
	while s._guess_heightmaps.size() > s.GUESS_CACHE_MAX:
		s._guess_heightmaps.erase(s._guess_heightmaps.keys()[0])
	return hm

## The heightmap a chunk's own build should use: a guess already generated for it when one is
## cached (consumed, since `build_chunk` stores it as the real map), else a fresh one from the
## generator. Each chunk's surface is therefore generated ONCE, whether a neighbour's gather
## got to it first or its own dispatch did; the neighbour's guess used to be thrown away and
## the same noise recomputed on the main thread at dispatch.
## Callers that pass the result to `build_chunk` keep the guess == real-map invariant that the
## neighbours' seams rely on. Empty when no generator is wired.
func take_heightmap_for_build(chunk: Vector2i) -> Array:
	s._sync_guess_seed()
	var ckey = s._chunk_key(chunk)
	if s._guess_heightmaps.has(ckey):
		var hm: Array = s._guess_heightmaps[ckey]
		s._guess_heightmaps.erase(ckey)
		return hm
	if s.terrain_slice == null or not s.terrain_slice.has_method("generate_heightmap"):
		return []
	return s.terrain_slice.generate_heightmap(chunk)

## Phase 141 — the cached guess map of `chunk` (consumed, like `take_heightmap_for_build`), or `[]`
## when there is none. Never generates: the streamed build generates a missing map on its worker.
func take_cached_heightmap(chunk: Vector2i) -> Array:
	s._sync_guess_seed()
	var ckey = s._chunk_key(chunk)
	if not s._guess_heightmaps.has(ckey):
		return []
	var hm: Array = s._guess_heightmaps[ckey]
	s._guess_heightmaps.erase(ckey)
	return hm

## Phase 141 — `gather_build_input` for a WORKER build: the same payload, except that a ring
## neighbour with no known map (not built, no cached guess) is not generated here. It is listed
## under `missing_neighbours` instead, and `fill_seam_strips` generates on the worker only the
## edge of it the ring reads. Generating those guesses here cost the main thread up to eight full
## heightmaps per dispatch (120 ms at the equator, 290 ms by a pole, measured).
func gather_build_input_deferred(chunk_pos: Vector2i) -> Dictionary:
	s._sync_guess_seed()
	var known: Dictionary = {}
	var missing: Array = []
	for chunk in s._ring_chunks(chunk_pos):
		var ckey = s._chunk_key(chunk)
		if s._heightmaps.has(ckey):
			known[ckey] = s._heightmaps[ckey]
		elif s._guess_heightmaps.has(ckey):
			known[ckey] = s._guess_heightmaps[ckey]
		elif chunk != chunk_pos:
			missing.append(chunk)
	return {
		"edits":                s._gather_edits(chunk_pos),
		"neighbour_heightmaps": known,
		"missing_neighbours":   missing,
		"biomes":               s.gather_biomes_for(chunk_pos),
		"seed":                 s._world_seed(),
		"depleted":             s._vein_taken.duplicate(),
	}

## Drop every cached guess when the world seed changed under them (`set_world_seed` runs
## before any chunk streams in production, but a re-seed mid-session must not serve a map
## of the old world).
func _sync_guess_seed() -> void:
	var seed_now = s._world_seed()
	if seed_now != s._guess_seed:
		s._guess_seed = seed_now
		s._guess_heightmaps.clear()
		s._shown_biomes.clear()

## The biome of every chunk the ring touches, keyed by chunk — what the colour step needs.
## The gather is ≤ 9 terrain-slice calls, against the 4356 a per-tile lookup would make.
## A ring chunk past the polar rows is left out (it lends nothing, `blended_biome` falls back to
## `own`), the same rule as `Minimap._blendable`; the chunk itself is always in the map.
func gather_biomes_for(chunk_pos: Vector2i) -> Dictionary:
	var out: Dictionary = {}
	for chunk in s._lending_ring(chunk_pos, s._ring_chunks(chunk_pos)):
		out[s._chunk_key(chunk)] = s._biome_at(s._chunk_world_center(chunk))
	return out

## Phase 92 — the one pole-ring rule: of `candidates` (the chunks around `own`), `own` itself and
## every chunk short of the polar ice, in order. Both `gather_biomes_for` and `shown_biome_at` use it.
func _lending_ring(own: Vector2i, candidates: Array) -> Array:
	var bound = s._polar_bound()
	var out: Array = []
	for chunk in candidates:
		if chunk == own or s.TerrainSlice.lends_biome(chunk, bound):
			out.append(chunk)
	return out

## The distinct chunks a chunk's tile+ring spans: at most 3×3, because the ring is one tile wide.
func _ring_chunks(chunk_pos: Vector2i) -> Array:
	var first = chunk_pos * s.CHUNK_SIZE + Vector2i(-1, -1)
	var last = chunk_pos * s.CHUNK_SIZE + Vector2i(s.CHUNK_SIZE, s.CHUNK_SIZE)
	var c0 = s._tile_to_chunk(first)
	var c1 = s._tile_to_chunk(last)
	var out: Array = []
	for cz in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			out.append(Vector2i(cx, cz))
	return out

## Free a chunk's visual + collision nodes without touching its base heightmap
## or any voxel edits. The heightmap is cached in `_heightmaps` so a later
## build_chunk() re-applies edits and restores the column exactly. Used by
## ChunkManager to stream chunks out of view.
##
## The cached map is then PRUNED down to what a loaded chunk can still ask about
## (see `_prune_heightmaps`): session-long retention is the memory this streaming
## is meant to bound, and a chunk nobody can reach for reads as UNKNOWN, which the
## mesher already handles by construction.
func unload_chunk(chunk_pos: Vector2i) -> void:
	var key = s._chunk_key(chunk_pos)
	if s._chunks.has(key):
		s._chunks[key].queue_free()
		s._chunks.erase(key)
	if s._standins.has(key):
		s._free_standin(key)
	s._prune_heightmaps(chunk_pos)

## Drop the base heightmaps of chunks that are no longer worth remembering: one
## that is unloaded AND not edge-adjacent to any loaded chunk.
##
## `_heightmaps` used to grow for the whole session — every chunk ever streamed in
## kept its `CHUNK_SIZE²` floats so a streamed-out neighbour could still answer with
## its real runs — which means a long walk held the whole route in memory. The KEPT
## set is the loaded window plus its one-tile ring: exactly the set a visible chunk
## can ask a NEIGHBOUR about, so a loaded chunk still subtracts against its
## neighbour's real runs. A chunk outside that ring reads as UNKNOWN instead, which
## is the documented, order-independent empty-neighbour path (the side carrying the
## material emits the facing wall, and the pruned chunk rebuilds from its heightmap
## when it is streamed back). Nothing is lost with the map: edits are keyed by
## TILE, and a pruned chunk's natural run comes from the same height function the
## map was sampled from.
##
## Indexed by chunk: unloading one chunk can only change the keep verdict of that chunk
## and its four edge neighbours, so only those five are probed (each against its own
## four neighbours) instead of scanning every loaded chunk and every stored map. A
## crossing unloads a dozen chunks in one frame; the full scan made that quadratic.
##
## The candidates are the full 3x3 around the unloaded chunk, not just its plus ring: a build
## also guesses its DIAGONAL neighbours' maps (`_ring_chunks` is 3x3, for the corner tile),
## and those guesses must be dropped when the chunk that caused them unloads. The keep rule
## itself is unchanged (loaded or edge-adjacent to a loaded chunk).
func _prune_heightmaps(around: Vector2i) -> void:
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var candidate := Vector2i(around.x + dx, around.y + dz)
			var kept := false
			for probe in s._plus_ring(candidate):
				if s._chunks.has(s._chunk_key(probe)):
					kept = true
					break
			if not kept:
				var ckey = s._chunk_key(candidate)
				s._heightmaps.erase(ckey)
				s._guess_heightmaps.erase(ckey)

## Rebuild the chunk holding `tile` — and every chunk whose mesh READS that tile.
##
## A wall face is emitted from the DIFFERENCE between a column's runs and its
## neighbour's, so a chunk's mesh depends on the columns just ACROSS its edge. A
## tile on a chunk boundary is a neighbour column to the next chunk's tiles, so
## editing it changes what THOSE emit: rebuild only the tile's own chunk and the
## neighbour keeps drawing the wall it had — a see-through slot where the seam
## terrain now differs (mine a tunnel into a seam tile and the mouth is open), and
## a ghost wall where it no longer does. Nothing else rebuilds a chunk when its
## neighbour changes, so the hole would stay for the session.
##
## Only the four edge-ADJACENT chunks can read the tile, and only when the tile is
## actually on that edge, so this is one chunk build in a chunk's interior and at
## most three at a corner (see `_touched_chunks`).
##
## Phase 42 REVIEW — the rebuild is DISPATCHED, not built here. `ChunkManager.request_rebuild`
## hands it to the worker like any other streamed chunk, which is the whole point of the
## phase: this method used to build up to three chunks SYNCHRONOUSLY in the frame that
## placed the block, the exact stall the worker exists to remove. Two cases it also fixes:
##
##   * a chunk whose build is still IN FLIGHT has no cached heightmap yet, so the old
##     `_heightmaps.has(ckey)` guard skipped it entirely and the edit was LOST — the
##     in-flight result then attached the pre-edit arrays. `request_rebuild` needs no
##     cached map: it supersedes the in-flight build and dispatches a fresh one.
##   * a chunk that is NOT in the streamed set is a no-op there, which is the existing
##     rule: it has no node to refresh, and it rebuilds from the current edit log when it
##     streams back in. Building it here would resurrect a chunk the manager has already
##     streamed away (see `apply_edits`).
##
## A slice with NO manager wired (the suite, a probe) keeps the synchronous build, and only
## for a chunk that is LOADED — the same rule `ChunkManager.request_rebuild` applies on the
## other path (`if not _loaded.has(key): return`), and the same rule `apply_edits` applies
## for a re-scope. The guard used to be `_heightmaps.has(ckey)`, and since the Phase 41
## review that map deliberately RETAINS the one-tile ring around the loaded window, so an
## unloaded neighbour that a loaded chunk can still ask about answered TRUE: an edit on a
## chunk edge rebuilt — and so RESURRECTED — a chunk `ChunkManager` had already streamed
## away and would never stream out again. A loaded chunk always has its cached map
## (`build_chunk` stores it and `_prune_heightmaps` keeps it), so `_chunks` is the guard.
func _rebuild_chunk_at_tile(tile: Vector2i) -> void:
	for chunk in s._touched_chunks(tile):
		s._rebuild_chunk(chunk)

## Rebuild ONE chunk by the route described above: dispatched through the manager when one is
## wired, else synchronously and only when the chunk is loaded.
func _rebuild_chunk(chunk: Vector2i) -> void:
	if s.chunk_manager != null and s.chunk_manager.has_method("request_rebuild"):
		s.chunk_manager.request_rebuild(chunk)
		return
	var ckey = s._chunk_key(chunk)
	if s._chunks.has(ckey):
		s.build_chunk(chunk, s._heightmaps[ckey])

## The chunks whose mesh reads `tile`, deduplicated: the tile's own chunk plus each
## edge-adjacent one the tile sits on the edge of. A corner tile names three distinct
## chunks; an interior tile names one.
func _touched_chunks(tile: Vector2i) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for probe in [tile, Vector2i(tile.x - 1, tile.y), Vector2i(tile.x + 1, tile.y),
			Vector2i(tile.x, tile.y - 1), Vector2i(tile.x, tile.y + 1)]:
		var chunk = s._tile_to_chunk(probe)
		var ckey = s._chunk_key(chunk)
		if seen.has(ckey):
			continue
		seen[ckey] = true
		out.append(chunk)
	return out
