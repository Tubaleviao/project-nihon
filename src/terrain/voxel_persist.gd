extends RefCounted
## Edit table, manifest and dirty-chunk persistence for `VoxelSlice`, moved out verbatim (Phase 154).
## `s` is the owning slice; every public method keeps a forwarder on the slice.

var s: Node

func _init(slice: Node) -> void:
	s = slice

## Dump voxel edits for persistence: { "gx,gz": [typed run edit, ...] }.
func get_edits() -> Dictionary:
	return s._edits.duplicate(true)

## Restore voxel edits from a saved world snapshot and rebuild affected chunks.
##
## TOLERANT of both save shapes, deliberately: a value that is an Array is the
## Phase 41 typed run edits and is adopted as-is, while a bare number (or a string
## that parses as one) is a pre-Phase-41 absolute quantised height and is MIGRATED
## (see `legacy_edit_ops`) against the tile's natural run — never dropped, because
## a migration that "repairs" a world by discarding player work is worse than a
## refusal. `materials` maps "gx,gz" → Array of material keys, the other half of
## the legacy shape.
##
## A value that is NEITHER shape is not player work, it is unreadable: it is DROPPED
## with a warning (`_legacy_height_of`) rather than cast into a height, because the
## cast was not a refusal — `float()` answers 0.0 for an unparsable string, which
## migrates the column to the world floor.
##
## Only the chunks whose edits actually CHANGED are rebuilt, and only the ones
## that are LOADED. Both halves are load-path hygiene this method needs because
## it is also the RE-SCOPE path (`SnapshotWiring.on_world_snapshot_received`): a
## snapshot re-sends the manifest a client already applied — or one that differs
## in a chunk or two — and rebuilding every held chunk for that is a whole-frame
## stall per scope change. And a chunk that was streamed out has no mesh to
## refresh: building it here would resurrect the node `ChunkManager` has already
## streamed away, which it will then never unload again.
##
## A changed TILE names the chunks whose mesh reads it (`_touched_chunks`), not just
## the chunk the tile sits in: a wall face is the difference against the NEIGHBOUR
## column, so an edit on a chunk's edge leaves the neighbour's old wall standing — a
## see-through slot or a ghost wall at the seam — until that chunk happens to
## restream. `_rebuild_chunk_at_tile` has closed this since the Phase 41 review; this
## is the same closure on the re-scope path, which was still rebuilding the tile's own
## chunk alone.
##
## Phase 42 review pass 8 — and the rebuild now takes the SAME route as an edit:
## `ChunkManager.request_rebuild` when a manager is wired, the synchronous `build_chunk`
## otherwise. It used to always build synchronously, which both paid the whole build on the
## main thread in the frame that applied a snapshot AND bumped the chunk's revision under
## an in-flight worker build.
func apply_edits(edits: Dictionary, materials: Dictionary = {}) -> void:
	# A wholesale replace is the authority on depletion: evicted-chunk carry is stale.
	s._vein_carry = {}
	s._commit_edits(s._normalise_edit_table(edits, materials))

## The normalising half of `apply_edits`: a typed op list is cleaned, a legacy height is
## migrated against the tile's natural run, anything unreadable is dropped with a warning.
func _normalise_edit_table(edits: Dictionary, materials: Dictionary) -> Dictionary:
	var next: Dictionary = {}
	for key in edits:
		var value: Variant = edits[key]
		if value is Array:
			next[key] = s._normalise_tile_ops(key, value, materials)
			continue
		# The LEGACY half: a bare number (or a numeric string) is a pre-Phase-41
		# absolute quantised height, migrated against the tile's natural run. Any
		# OTHER shape is DROPPED with a warning rather than cast — `float()` answers
		# 0.0 for a string that is not a number, so a corrupt entry used to migrate
		# into a height AT THE WORLD FLOOR (the column carved away), and a dict raised
		# a runtime error on the load path. Dropping is the policy `_normalise_ops`
		# already applies to an op whose kind this version cannot read.
		var legacy_height = s._legacy_height_of(value)
		if is_nan(legacy_height):
			s.Diag.warn("VoxelSlice.apply_edits: dropping an unrecognized edit for '%s' (%s)"
				% [str(key), type_string(typeof(value))])
			continue
		var tile = s._key_to_tile(str(key))
		var stack: Array = materials.get(key, [])
		next[key] = s.VoxelRuns.legacy_edit_ops(legacy_height, s._base_top_for_tile(tile), stack)
	return next

## Phase 91 — a typed op list, with a leading `legacy` op (a bare pre-Phase-41 height the region
## store carried through a depletion overlay) migrated exactly as a bare number is, then the other
## ops after it. A `legacy` op with an unreadable height is dropped with a warning.
func _normalise_tile_ops(key: Variant, value: Array, materials: Dictionary) -> Array:
	var has_legacy := false
	for op in value:
		if op is Dictionary and str(op.get("op", "")) == s.RegionStore.LEGACY_OP:
			has_legacy = true
			break
	if not has_legacy:
		return s._normalise_ops(value)   # the hot path: no legacy op, no extra arrays
	var rest: Array = []
	var migrated: Array = []
	var seen_legacy := false
	for op in value:
		if op is Dictionary and str(op.get("op", "")) == s.RegionStore.LEGACY_OP:
			if seen_legacy:
				continue
			seen_legacy = true
			var h = s._legacy_height_of(op.get("height", null))
			if is_nan(h):
				s.Diag.warn("VoxelSlice.apply_edits: dropping an unreadable legacy height for '%s'" % str(key))
				continue
			migrated = s.VoxelRuns.legacy_edit_ops(h, s._base_top_for_tile(s._key_to_tile(str(key))), materials.get(key, []))
		else:
			rest.append(op)
	return migrated + s._normalise_ops(rest)

## The committing half of `apply_edits`: swap in `next` as the edit log and rebuild what
## changed. `diff_keys` limits the change detection to those tile keys (the scoped re-scope
## path knows nothing outside its disc moved); null compares the whole of both logs.
func _commit_edits(next: Dictionary, diff_keys: Variant = null) -> void:
	var previous: Dictionary = s._edits
	if diff_keys == null:
		s._partial_chunks.clear()   # the log is replaced wholesale: what it holds is the whole truth
	# _dirty_chunks is NOT cleared here: dirty tracking is reset only by
	# clear_dirty_chunks() after a successful save (called from PersistenceWiring._finish_save).
	# Restored on-disk edits are not dirty — they were already persisted.
	var touched: Dictionary = {}
	var changed: Dictionary = {}   # chunks that own a changed tile (Phase 69: their seams)
	var keys: Array = (diff_keys as Array) if diff_keys is Array else s._union_keys(previous, next)
	for key in keys:
		if next.has(key):
			if not s._ops_equal(previous.get(key, null), next[key]):
				s._mark_touched_tile(touched, s._key_to_tile(str(key)))
				changed[s._chunk_key(s._tile_to_chunk(s._key_to_tile(str(key))))] = true
		elif previous.has(key):
			s._mark_touched_tile(touched, s._key_to_tile(str(key)))
			changed[s._chunk_key(s._tile_to_chunk(s._key_to_tile(str(key))))] = true
	var previous_taken: Dictionary = s._vein_taken
	s._edits = next
	# The read-side chunk index is re-derived with it (Phase 42 review pass 10): the log was
	# replaced in one assignment, so the index is rebuilt rather than diffed.
	s._reindex_edits()
	# Phase 69 — only the chunks that own a changed tile get a new revision (the re-index above
	# rewrites every bucket, which must not look like an edit to the seam gate).
	for ckey in changed:
		s._bump_chunk_rev(str(ckey))
	# Phase 43 — a vein whose EXHAUSTION changed with the new log repaints across its whole
	# blob, which is wider than the anchor tile the deplete op sits on (the only tile the
	# diff above marks). A count that moved without crossing the reserve changes nothing
	# visible, so it rebuilds nothing.
	var vein_ids: Dictionary = previous_taken.duplicate()
	vein_ids.merge(s._vein_taken)
	for id in vein_ids:
		var vein = s._vein_from_id(str(id))
		if vein.is_empty():
			continue
		if s.OreField.is_live(vein, previous_taken) != s.OreField.is_live(vein, s._vein_taken):
			s._rebuild_vein_chunks(vein)
	# Phase 42 review pass 8 — this is the REBUILD half of the re-scope, and it goes through
	# the manager exactly like an edit does (`_rebuild_chunk_at_tile`): `request_rebuild`
	# dispatches the build to a WORKER (so a snapshot that changed a corner — three touched
	# chunks — no longer rebuilds them all synchronously in the frame that applied it) and,
	# more importantly, it SUPERSEDES a build already in flight for the chunk. The
	# synchronous `build_chunk` this used to call bumped the chunk's revision on the main
	# thread, which made an in-flight worker result stale (refused) while the worker's pool
	# task was left to be awaited by nobody but the frame path — the mesh that landed was
	# whichever one won the race. With no manager wired (the suite, a probe) the synchronous
	# build stays, and only for a chunk that is LOADED.
	#
	# Phase 42 review pass 11 — the manager path is NOT gated on `_chunks`: a chunk whose
	# FIRST build is still on a worker is in the manager's streamed set but not yet in
	# `_chunks`, and that build read the pre-snapshot edit log. Skipping it attached a mesh
	# without the snapshot's edits and nothing ever rebuilt it. `request_rebuild` supersedes
	# the in-flight build and is itself a no-op for a chunk outside the streamed set.
	for ckey in touched:
		# `ckey` is a CHUNK key ("cx,cz"); the same "x,y" parse as a tile key reads it.
		var chunk = s._chunk_from_key(str(ckey))
		if s.chunk_manager != null and s.chunk_manager.has_method("request_rebuild"):
			s.chunk_manager.request_rebuild(chunk)
			continue
		if not s._chunks.has(ckey) or not s._heightmaps.has(ckey):
			continue   # nothing to refresh: unloaded chunks rebuild when streamed in
		s.build_chunk(chunk, s._heightmaps[ckey])
	# Phase 69 — edits that arrive after a chunk loaded reach the diagonal neighbour of a changed
	# corner tile too; the edge neighbours were requested just above. Judged on the old AND the new
	# ops, so removing a shaping edit (or turning it deplete-only) repairs the neighbour as well.
	if s.chunk_manager != null and s.chunk_manager.has_method("request_rebuild"):
		var diagonals: Dictionary = {}
		for key in keys:
			var tile = s._key_to_tile(str(key))
			var offs = s._shaped_border_offsets(tile, previous.get(key, []), next.get(key, []))
			if offs.size() < 3 or s._ops_equal(previous.get(key, null), next.get(key, null)):
				continue   # not a corner tile, or nothing moved
			var dchunk: Vector2i = s._tile_to_chunk(tile) + offs[2]
			var dkey = s._chunk_key(dchunk)
			if not touched.has(dkey):
				diagonals[dkey] = dchunk
		for dkey in diagonals:
			s.chunk_manager.request_rebuild(diagonals[dkey])

## Mark every chunk whose mesh reads `tile` — the tile's own chunk plus each
## edge-adjacent one it sits on the edge of (see `_touched_chunks`) — as needing a
## rebuild. The one place a tile-level change is turned into chunk-level work.
func _mark_touched_tile(touched: Dictionary, tile: Vector2i) -> void:
	for chunk in s._touched_chunks(tile):
		touched[s._chunk_key(chunk)] = true

## Group voxel edits by chunk into a persistence manifest:
##   { "cx,cz": { "edits": { "gx,gz": [typed run edit, ...] } } }
## Only chunks with edits appear. Used by the world save snapshot so edits are
## stored per-chunk and only dirty chunks need re-serialization.
func get_chunk_manifest() -> Dictionary:
	var manifest: Dictionary = {}
	for key in s._edits:
		var chunk = s._chunk_key(s._tile_to_chunk(s._key_to_tile(str(key))))
		if not manifest.has(chunk):
			manifest[chunk] = { "edits": {} }
		manifest[chunk]["edits"][key] = s._edits[key].duplicate(true)
	return manifest

## `get_chunk_manifest` for the SAVE: an entry of a chunk whose resident edits are partial
## (`_partial_chunks`) carries `"merge": true`, so the region store overlays it on the stored
## entry rather than replacing it (Phase 75). The wire snapshots use the plain manifest.
func get_save_manifest() -> Dictionary:
	var manifest = s.get_chunk_manifest()
	for ckey in s._partial_chunks:
		if manifest.has(ckey):
			manifest[ckey]["merge"] = true
	return manifest

## Phase 49 — `get_chunk_manifest` restricted to chunks inside an area of interest, so a
## re-scope snapshot ships the edits a peer can see instead of the whole world's. Walks the
## chunk index (one parse per EDITED CHUNK, not per edit).
func get_chunk_manifest_in_radius(center: Vector3, radius: float) -> Dictionary:
	var manifest: Dictionary = {}
	for ckey in s._edits_by_chunk:
		if not s.chunk_in_radius(s._chunk_from_key(str(ckey)), center, radius):
			continue
		var edits: Dictionary = {}
		for key in s._edits_by_chunk[ckey]:
			edits[key] = s._edits[key].duplicate(true)
		manifest[ckey] = { "edits": edits }
	return manifest

## Phase 49 — apply a manifest produced by `get_chunk_manifest_in_radius`. It is
## authoritative only INSIDE its scope: edits this slice holds for chunks outside the
## disc are kept untouched, because the host did not (and could not) restate them. Only the
## in-scope buckets are replaced and only their tiles are diffed; the rest of the log is
## neither re-normalised nor compared.
func apply_scoped_chunk_manifest(manifest: Dictionary, center: Vector3, radius: float) -> void:
	var next: Dictionary = s._edits.duplicate()   # shallow: the out-of-scope op lists are shared
	var diff_keys: Array = []
	for ckey in s._edits_by_chunk:
		if s.chunk_in_radius(s._chunk_from_key(str(ckey)), center, radius):
			for key in s._edits_by_chunk[ckey]:
				next.erase(key)
				diff_keys.append(key)
	var edits: Dictionary = {}
	var materials: Dictionary = {}
	for ckey in manifest:
		var chunk_data: Dictionary = manifest[ckey]
		if chunk_data.has("edits"):
			for key in chunk_data["edits"]:
				edits[key] = chunk_data["edits"][key]
		if chunk_data.has("materials"):
			for key in chunk_data["materials"]:
				materials[key] = chunk_data["materials"][key]
	var incoming = s._normalise_edit_table(edits, materials)
	for key in incoming:
		next[key] = incoming[key]
		diff_keys.append(key)
	s._commit_edits(next, diff_keys)

## Restore voxel edits from a chunk manifest (see get_chunk_manifest). Flattens
## the per-chunk grouping back into the global tile-keyed edit table. A manifest
## written before Phase 41 also carries a per-chunk "materials" map; it is read and
## handed to apply_edits for the legacy migration rather than ignored.
func apply_chunk_manifest(manifest: Dictionary) -> void:
	var edits: Dictionary = {}
	var materials: Dictionary = {}
	for ckey in manifest:
		var chunk_data: Dictionary = manifest[ckey]
		if chunk_data.has("edits"):
			for key in chunk_data["edits"]:
				edits[key] = chunk_data["edits"][key]
		if chunk_data.has("materials"):
			for key in chunk_data["materials"]:
				materials[key] = chunk_data["materials"][key]
	s.apply_edits(edits, materials)
	s._settle_requeue_loaded(edits.keys())

## Phase 52 — ADD a region's edits to the log without disturbing the rest of it. The
## streaming counterpart of `apply_chunk_manifest` (which replaces the whole log): a region
## file is read when a window first needs it, and what it carries joins the edits already
## resident. A chunk the log already holds is left alone — memory is at least as new as disk.
func apply_region_chunks(manifest: Dictionary) -> void:
	var edits: Dictionary = {}
	var materials: Dictionary = {}
	for ckey in manifest:
		var rk := str(ckey)
		var chunk_data: Dictionary = manifest[ckey]
		if s._partial_chunks.has(rk) and s._edits_by_chunk.has(rk):
			# Phase 75 — the resident ops are only the depletions written while the chunk was
			# evicted: lay them over what the region file stores, and the chunk is whole again.
			var resident: Dictionary = s.get_chunk_manifest().get(rk, { "edits": {} })
			var whole: Dictionary = s.RegionStore.overlay_entry(chunk_data, resident)
			for key in whole["edits"]:
				edits[key] = whole["edits"][key]
			if whole.has("materials"):
				for key in whole["materials"]:
					materials[key] = whole["materials"][key]
			s._partial_chunks.erase(rk)
			continue
		if s._edits_by_chunk.has(rk) or s._dirty_chunks.has(rk) or s._inflight_chunks.has(rk):
			continue
		if chunk_data.has("edits"):
			for key in chunk_data["edits"]:
				edits[key] = chunk_data["edits"][key]
		if chunk_data.has("materials"):
			for key in chunk_data["materials"]:
				materials[key] = chunk_data["materials"][key]
	if edits.is_empty():
		return
	var incoming = s._normalise_edit_table(edits, materials)
	var next: Dictionary = s._edits.duplicate()   # shallow: resident op lists are shared
	for key in incoming:
		next[key] = incoming[key]
	s._commit_edits(next, incoming.keys())
	s._settle_requeue_loaded(incoming.keys())

## Phase 52 — drop the resident edits of the chunks in `chunk_keys` ("cx,cz") that are NOT
## dirty, so a region that left every window stops costing memory. A dirty chunk keeps its
## edits: they exist nowhere else until the next save carries them. Returns how many
## chunks were released. Callers only name chunks outside every streamed window, so no
## build is reading them.
func evict_clean_chunks(chunk_keys: Array) -> int:
	var released := 0
	var next: Dictionary = s._edits.duplicate()
	for ckey in chunk_keys:
		var k := str(ckey)
		if s._dirty_chunks.has(k) or s._inflight_chunks.has(k) or not s._edits_by_chunk.has(k):
			continue
		for key in s._edits_by_chunk[k].keys():
			for op in s._edits.get(key, []):
				if op is Dictionary and str(op.get("op", "")) == "deplete":
					var vid := str(op["vein"])
					s._vein_carry[vid] = maxi(int(s._vein_carry.get(vid, 0)), int(op["taken"]))
			next.erase(key)
		s._partial_chunks.erase(k)
		released += 1
	if released > 0:
		s._edits = next
		s._reindex_edits()
	return released

## The "cx,cz" keys of every chunk that currently has resident edits.
func edited_chunk_keys() -> Array:
	return s._edits_by_chunk.keys()

## Return the "cx,cz" keys of chunks modified since the last save/clear.
func get_dirty_chunk_keys() -> Array:
	return s._dirty_chunks.keys()

## Clear the dirty-chunk tracking (call after a successful save).
func clear_dirty_chunks() -> void:
	s._dirty_chunks.clear()

## Remove exactly `keys` from the dirty set. The authoritative save runs the file
## write on a worker thread, so the clear happens when the payload is COLLECTED
## (main thread, atomically with reading it) rather than after the write lands. A
## keyed clear is what makes that safe: an edit made while the write is in flight
## marks its chunk dirty again and is carried by the next save, instead of being
## swallowed by a blanket clear.
func clear_dirty_chunk_keys(keys: Array) -> void:
	for key in keys:
		s._dirty_chunks.erase(str(key))

## Phase 52 — mark `keys` as being written (collected, not yet on disk) / as settled.
func begin_inflight_chunks(keys: Array) -> void:
	for key in keys:
		s._inflight_chunks[str(key)] = true

func end_inflight_chunks(keys: Array) -> void:
	for key in keys:
		s._inflight_chunks.erase(str(key))

## Re-mark `keys` dirty — the rollback for a save whose write failed, so a failed
## write cannot lose the chunks it claimed to persist.
func mark_dirty_chunks(keys: Array) -> void:
	for key in keys:
		s._dirty_chunks[str(key)] = true
