extends RefCounted
## Mine/place/settle edit authority, moved out of `VoxelSlice` verbatim (Phase 154).
## `s` is the owning slice; every moved method keeps a forwarder on the slice.

var s: Node

func _init(slice: Node) -> void:
	s = slice

func mine_block(world_pos: Vector3, normal: Vector3 = Vector3.UP, player_id: String = "", exact: Dictionary = {}) -> Dictionary:
	# Resolve the span BEFORE spending tool durability, so a blocked mine never
	# consumes the held pick (the repo's standing atomic-refusal rule).
	var probe = s._resolve_edit_tile("mine", world_pos, normal, exact)
	var tile: Vector2i = probe["tile"]
	var span = s._mine_span(s.get_runs_at_tile(tile), world_pos, normal)
	if span.is_empty() or s._claim_refused(player_id, probe):
		return { "success": false, "material": "", "quantity": 0, "position": world_pos, "player_id": player_id }

	# The ACTOR's own pack: the durability spent and the yield credited are the
	# acting player's, which for a remote mine is the peer the intent came from.
	var inventory = s.inventory_for(player_id)

	# Tool durability: mining consumes the held pick. A broken pick blocks the
	# mine; bare-handed (no pick) mining is still allowed.
	var pick = s._held_pick(inventory)
	if pick != "" and inventory != null and inventory.has_method("use_item"):
		if not inventory.use_item(pick, "mine"):
			return { "success": false, "material": "", "quantity": 0, "position": world_pos, "player_id": player_id }

	# Phase 43 — a NATURAL span yields what the ore field holds there: a live vein's
	# material and per-slice quantity (capped by what is left of its reserve), else the
	# biome's host rock, one unit. Resolved BEFORE the remove is appended, because the
	# depth it reads is the span's, measured from the tile's natural surface.
	var material := str(span["material"])
	var quantity := 1
	var vein: Dictionary = {}
	var natural := material == ""
	if natural:
		var yielded = s._natural_yield(tile, span)
		material = str(yielded["material"])
		quantity = int(yielded["quantity"])
		vein = yielded["vein"]
	s._append_edit(tile, { "op": "remove", "bottom": span["bottom"], "top": span["top"] })
	s._mark_dirty(tile)
	s._settle_note(tile)
	if not vein.is_empty():
		s._record_depletion(vein, quantity)
		s._mark_dirty(vein["anchor"])
	s._rebuild_chunk_at_tile(tile)

	var banked := false
	if inventory != null and inventory.has_method("add_item"):
		# The ground is dug either way; a yield the pack cannot hold is lost, and the local
		# player is told rather than left wondering where it went.
		banked = inventory.add_item(material, quantity)
		if not banked and not s._is_remote_actor(player_id):
			GameBus.inventory_full.emit()
	s._push_inventory(player_id)

	var pos = Vector3(world_pos.x, float(span["top"]), world_pos.z)
	GameBus.block_mined.emit(material, quantity, pos)
	# Phase 124 — only a natural yield that reached the pack counts as gathering; a
	# placed block mined back would otherwise be a research-point farm.
	if natural and banked:
		GameBus.resource_gathered.emit(player_id, material, quantity)
	# Phase 138 — the span top, the same height `has_edit_near_at` judges on a reload, so live and reload agree.
	GameBus.block_edit_resolved.emit(tile, float(span["top"]))
	GameBus.block_changed.emit("mine", world_pos, normal, material)
	s._note_claim_activity(player_id, probe)
	return { "success": true, "material": material, "quantity": quantity, "position": pos, "player_id": player_id }

## Phase 43 — what mining a NATURAL span of `tile` yields, off the ore field:
## `{ material, quantity, vein }`. Inside a LIVE vein it is the vein's material and its
## per-slice `quantity`, capped by the reserve still left; anywhere else the biome's ground,
## one unit, with `vein` empty. Pure — the depletion it implies is recorded by the caller
## (`_record_depletion`).
##
## Phase 49 — the ground is layered: a slice within the biome's `topsoilDepth` yields that
## biome's fabric `soilMaterial` (Grass/Moss/Ash/Void ground alike), and only below it the
## biome's host rock. The surface-material → soil-material mapping is a BIOME field, so no
## GDScript branch decides which cover becomes which soil (issue #111).
func _natural_yield(tile: Vector2i, span: Dictionary) -> Dictionary:
	var xz = Vector2(tile.x * s.TILE_SIZE + s.TILE_SIZE * 0.5, tile.y * s.TILE_SIZE + s.TILE_SIZE * 0.5)
	var depth = s._run_depth(span, s._base_top_for_tile(tile))
	var vein = s._live_vein_at(xz, depth, s._world_seed(), s._vein_taken, {})
	if vein.is_empty():
		var biome = s._biome_at(xz)
		# The soil is the one the surface draws: the tile's BLENDED biome (Phase 64).
		var b: Variant = GameData.BIOMES.get(s.shown_biome_at(xz), null)
		var topsoil: Variant = b.get("topsoilDepth") if b != null else null
		if b != null and b.get("soilMaterial") != null \
				and depth < float(topsoil if topsoil != null else 0.0):
			return { "material": str(b.get("soilMaterial")), "quantity": 1, "vein": {} }
		return { "material": s.OreField.host_material(biome), "quantity": 1, "vein": {} }
	var take = mini(int(vein["quantity"]), s.OreField.remaining(vein, s._vein_taken))
	return { "material": str(vein["material"]), "quantity": take, "vein": vein }

## Record `take` more units mined out of `vein`, as ONE fact per vein on the edit path.
##
## The record is a `{ "op": "deplete", "vein": id, "taken": n }` op on the vein's ANCHOR
## tile (the tile its blob centre sits in), REPLACED in place on every mine — never appended
## — so a vein costs one op however many swings it took, and the save does not grow with
## every click. Riding the tile op log is what makes it persist and travel for free: the
## per-chunk manifest saves it, the join/re-scope snapshot carries it, and `apply_edits`
## re-derives `_vein_taken` from it. Depletion is per VEIN, not per tile: depleting tile by
## tile would turn a blob into a checkerboard.
##
## When the vein runs out, every chunk its blob can touch is rebuilt, so its tint and its
## surface markers give way to host rock.
func _record_depletion(vein: Dictionary, take: int) -> void:
	if take <= 0:
		return
	var id := str(vein["id"])
	var taken = int(s._vein_taken.get(id, 0)) + take
	s._vein_taken[id] = taken
	var key = s._tile_key(vein["anchor"])
	var ops: Array = (s._edits.get(key, []) as Array).duplicate()
	var replaced := false
	for i in range(ops.size()):
		var op: Dictionary = ops[i]
		if str(op.get("op", "")) == "deplete" and str(op.get("vein", "")) == id:
			ops[i] = { "op": "deplete", "vein": id, "taken": taken }
			replaced = true
			break
	if not replaced:
		ops.append({ "op": "deplete", "vein": id, "taken": taken })
	var anchor_chunk = s._chunk_key(s._tile_to_chunk(vein["anchor"]))
	if not s._edits_by_chunk.has(anchor_chunk):
		s._partial_chunks[anchor_chunk] = true
	s._set_edit_ops(key, ops)
	if not s.OreField.is_live(vein, s._vein_taken):
		s._rebuild_vein_chunks(vein)

## Rebuild every chunk a vein's blob can reach — its bounding box, widened by the blob's
## noise margin — by the same route an edit takes (`_rebuild_chunk`).
func _rebuild_vein_chunks(vein: Dictionary) -> void:
	var center: Vector3 = vein["center"]
	var reach = float(vein["radius"]) * (1.0 + s.OreField.SHAPE_NOISE) + 1.0
	var seen: Dictionary = {}
	for corner in [Vector2(-reach, -reach), Vector2(reach, -reach), Vector2(-reach, reach), Vector2(reach, reach)]:
		var tile := Vector2i(floori(center.x + corner.x), floori(center.z + corner.y))
		var chunk = s._tile_to_chunk(tile)
		var ckey = s._chunk_key(chunk)
		if seen.has(ckey):
			continue
		seen[ckey] = true
		s._rebuild_chunk(chunk)

## The vein a depletion id names, re-derived from the field (the id IS its cell), or `{}`
## for an id that does not parse or names an empty cell.
func _vein_from_id(id: String) -> Dictionary:
	var parts := id.split(",")
	if parts.size() != 3:
		return {}
	var cell := Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))
	var vein = s.OreField.vein_in_cell(s._world_seed(), cell)
	return vein if not vein.is_empty() and str(vein["id"]) == id else {}

## Add one STEP_HEIGHT of the selected material on the column under world_pos.
## Consumes the material from the inventory. Returns true on success; false if no
## material is selected, the cell is already solid, or the build cap is reached.
##
## Phase 42 review — `material` is the ACTOR's selection and `player_id` the actor:
## `""` for either means "this machine's own" (its `_place_material`, its pack), and
## the host re-emits a client's intent with the identity bound to that connection
## plus the material the client named. Two rules keep a client-declared material
## from granting anything: it must be a real fabric material, and the debit lands on
## the actor's own pack — so a peer can only ever place what it actually holds. Both
## are checked BEFORE the debit and the edit (the atomic-refusal rule).
func place_block(world_pos: Vector3, normal: Vector3, material: String = "", player_id: String = "", exact: Dictionary = {}) -> bool:
	# `_place_material` is THIS machine's selection, so only the local actor may fall back
	# to it: a remote actor that named no material (a client with nothing selected) must
	# not place whatever the host happens to have selected.
	if material == "" and s._is_remote_actor(player_id):
		return false
	var chosen = material if material != "" else s._place_material
	if chosen == "" or not GameData.MATERIALS.has(chosen):
		return false

	# The placement is validated BEFORE anything is spent, so a refused placement
	# leaves no side effect to roll back.
	var probe = s._resolve_edit_tile("place", world_pos, normal, exact)
	var tile: Vector2i = probe["tile"]
	var span = s._place_span(s.get_runs_at_tile(tile), world_pos, normal)
	if span.is_empty() or s._claim_refused(player_id, probe):
		return false

	var inventory = s.inventory_for(player_id)
	if inventory != null and inventory.has_method("drop_item"):
		if not inventory.drop_item(chosen, 1):
			return false

	s._append_edit(tile, { "op": "add", "bottom": span["bottom"], "top": span["top"], "material": chosen })
	s._mark_dirty(tile)
	s._settle_note(tile)
	s._rebuild_chunk_at_tile(tile)
	s._push_inventory(player_id)

	var pos := Vector3(probe["xz"].x, float(span["top"]), probe["xz"].y)
	GameBus.block_placed.emit(chosen, pos)
	GameBus.block_edit_resolved.emit(tile, float(span["top"]))
	GameBus.block_changed.emit("place", world_pos, normal, chosen)
	s._note_claim_activity(player_id, probe)
	return true

## Resolve the target tile for a block edit from the hit position + face normal.
## A side-face hit lands on the boundary between two columns, so we step along
## the normal: back for mining (into the block aimed at), forward for placing
## (into the adjacent empty cell). Pure — performs no mutation.
##
## Phase 91 — with `exact` (a `{chunk, local}` record of the same point) the arithmetic runs on
## doubles from the exact chunk, so the tile is right however far from the origin the edit is.
func _resolve_edit_tile(action: String, position: Vector3, normal: Vector3, exact: Dictionary = {}) -> Dictionary:
	var x: float = position.x
	var z: float = position.z
	if exact.has("chunk") and exact.has("local"):
		var c: Vector2i = exact["chunk"]
		var l: Vector3 = exact["local"]
		x = float(c.x) * s.CHUNK_SIZE * s.TILE_SIZE + l.x
		z = float(c.y) * s.CHUNK_SIZE * s.TILE_SIZE + l.z
	if normal.y <= 0.5:
		var along := -1.0 if action == "mine" else 1.0
		x += along * normal.x * s.TILE_SIZE * 0.5
		z += along * normal.z * s.TILE_SIZE * 0.5
	return { "tile": Vector2i(floori(x / s.TILE_SIZE), floori(z / s.TILE_SIZE)), "xz": Vector2(x, z) }

## The span a mine removes, or {} when it is refused. A top-face hit takes the last
## step of the run whose top is the hit plane (see `runs_topping_at`) and refuses at
## BEDROCK_DEPTH; any other hit takes the STEP_HEIGHT block the ray is INSIDE, and
## falls back to the block below it — a y that lands exactly on a step boundary
## names the cell ABOVE it first, so aiming at the very top edge of a wall (where
## that cell is empty) still mines the wall instead of refusing.
func _mine_span(runs: Array, world_pos: Vector3, normal: Vector3) -> Dictionary:
	if runs.is_empty():
		return {}
	if normal.y > 0.5:
		var top_run: Dictionary = s.VoxelRuns.runs_topping_at(runs, world_pos.y)
		if top_run.is_empty():
			top_run = runs[-1]   # a y on no run boundary: the column's own surface
		var top := float(top_run["top"])
		var bottom = top - s.STEP_HEIGHT
		if bottom < s.BEDROCK_DEPTH:
			return {}   # bedrock: nothing below the floor to yield
		return { "bottom": bottom, "top": top, "material": str(top_run.get("material", "")) }
	var cell: float = floorf(world_pos.y / s.STEP_HEIGHT) * s.STEP_HEIGHT
	for cell_bottom in [cell, cell - s.STEP_HEIGHT]:
		var cb := float(cell_bottom)
		if cb < s.BEDROCK_DEPTH:
			continue
		var cell_top: float = cb + s.STEP_HEIGHT
		for run in runs:
			if float(run["bottom"]) <= cb + 0.000001 and float(run["top"]) >= cell_top - 0.000001:
				return { "bottom": cb, "top": cell_top, "material": str(run.get("material", "")) }
	return {}

## The span a place adds, or {} when it is refused (the cell is already solid, or
## the build cap would be passed). A top-face hit stacks on the run whose top is the
## hit plane (see `runs_topping_at` — a click on a tunnel FLOOR stacks on the floor,
## not on the roof above it); any other hit fills the STEP_HEIGHT cell the ray
## landed on, which is what lets a player lay a ceiling under a tunnel roof.
func _place_span(runs: Array, world_pos: Vector3, normal: Vector3) -> Dictionary:
	var bottom = s.BEDROCK_DEPTH
	if normal.y > 0.5:
		var top_run: Dictionary = s.VoxelRuns.runs_topping_at(runs, world_pos.y)
		if not top_run.is_empty():
			bottom = float(top_run["top"])
		elif not runs.is_empty():
			bottom = float(runs[-1]["top"])   # a y on no run boundary: the column's surface
	else:
		bottom = maxf(floorf(world_pos.y / s.STEP_HEIGHT) * s.STEP_HEIGHT, s.BEDROCK_DEPTH)
	var top = bottom + s.STEP_HEIGHT
	if top > s.MAX_HEIGHT:
		return {}
	if s.VoxelRuns.runs_cover_y(runs, bottom + s.STEP_HEIGHT * 0.5):
		return {}   # the cell already holds material
	return { "bottom": bottom, "top": top }

## Append one typed run edit to a tile's op list, and COMPACT the list once it
## outgrows the column it describes.
##
## The list is an append-only log by design — an edit says what the player DID, and
## the column is that log replayed over the natural run — but a log with no bound
## grows forever. Mine and rebuild the same block a few dozen times and every click
## adds a replay step to every column read (meshing, the collision soup, the footing
## sampler, the save manifest) for the rest of the session, in the save file too,
## and the replay is O(ops) per read, so an unbounded log is an unbounded per-frame
## cost on a tile the player is standing next to.
##
## So: keep appending, and past MAX_TILE_OPS rewrite the list as the minimal
## description of what the column IS (`_compact_ops`). The rewrite is exact — both
## shapes resolve to the same runs — and it is bounded by the column's run count
## (a plain column carrying one placed stack is one remove plus two adds), which
## bounds the log until the next compaction. A column that has been mined and put
## back is compacted to NOTHING, because it is its natural self again.
func _append_edit(tile: Vector2i, op: Dictionary) -> void:
	var key = s._tile_key(tile)
	if not s._edits.has(key):
		s._edits[key] = []
		s._index_edit(key)
	var ops: Array = s._edits[key]
	ops.append(op)
	if ops.size() <= s.MAX_TILE_OPS:
		return
	var compacted = s._compact_ops(tile)
	if compacted.is_empty():
		s._set_edit_ops(key, [])   # back to natural: the whole log was cancelled work
	else:
		s._edits[key] = compacted

## The ONE place a tile's op log is written, so the chunk index (`_edits_by_chunk`) cannot
## drift from `_edits` (Phase 42 review pass 10). An EMPTY list drops the tile: it is back to
## its natural self, and both the log entry and its index mark go.
func _set_edit_ops(tile_key: String, ops: Array) -> void:
	if ops.is_empty():
		s._edits.erase(tile_key)
		s._unindex_edit(tile_key)
		s._bump_edit_rev(tile_key)
		return
	s._edits[tile_key] = ops
	s._index_edit(tile_key)
	s._bump_edit_rev(tile_key)

func _bump_edit_rev(tile_key: String) -> void:
	s._bump_chunk_rev(s._chunk_key(s._tile_to_chunk(s._key_to_tile(tile_key))))

func _bump_chunk_rev(ckey: String) -> void:
	s._edit_rev[ckey] = int(s._edit_rev.get(ckey, 0)) + 1

## Record `tile_key` under its chunk in the read-side index (idempotent).
func _index_edit(tile_key: String) -> void:
	var ckey = s._chunk_key(s._tile_to_chunk(s._key_to_tile(tile_key)))
	var bucket: Dictionary = s._edits_by_chunk.get(ckey, {})
	bucket[tile_key] = true
	s._edits_by_chunk[ckey] = bucket

## Drop `tile_key` from the read-side index, and the whole bucket with it when it empties.
func _unindex_edit(tile_key: String) -> void:
	var ckey = s._chunk_key(s._tile_to_chunk(s._key_to_tile(tile_key)))
	var bucket: Dictionary = s._edits_by_chunk.get(ckey, {})
	bucket.erase(tile_key)
	if bucket.is_empty():
		s._edits_by_chunk.erase(ckey)
	else:
		s._edits_by_chunk[ckey] = bucket

## Rebuild the chunk index from the log — the wholesale path (`apply_edits` replaces `_edits`
## in one assignment, so the index is re-derived rather than diffed).
##
## Phase 43 — the vein depletion index (`_vein_taken`) is re-derived in the same pass: it is
## read off the log's deplete ops, never stored beside it.
func _reindex_edits() -> void:
	s._edits_by_chunk = {}
	s._vein_taken = {}
	for key in s._edits:
		s._index_edit(str(key))
		for op in s._edits[key]:
			if op is Dictionary and str(op.get("op", "")) == "deplete":
				s._vein_taken[str(op["vein"])] = int(op["taken"])
	# Phase 61 — veins whose op is not resident keep the count their evicted chunk carried.
	for vid in s._vein_carry.keys():
		if s._vein_taken.has(vid):
			s._vein_carry.erase(vid)
		else:
			s._vein_taken[vid] = int(s._vein_carry[vid])

## The minimal op list resolving a tile's natural runs to the runs it has NOW: the
## natural run(s) removed, then the resolved run(s) re-added. An EMPTY list means
## the column is its natural self again (the mined-then-rebuilt case, where the log
## would otherwise keep both halves of every cancelled pair forever).
##
## Phase 43 — a tile's vein DEPLETION ops are not run edits and are carried over verbatim:
## compaction rewrites what the column IS, and a depletion record is what a vein HAS LOST,
## which no replay of the runs can reconstruct.
func _compact_ops(tile: Vector2i) -> Array:
	var current: Array = s._edits.get(s._tile_key(tile), [])
	var base = s._base_runs_for_tile(tile)
	var runs = s.VoxelRuns.apply_run_ops(base, current)
	var ops: Array = []
	if not s._runs_equal(runs, base):
		for run in base:
			ops.append({ "op": "remove", "bottom": float(run["bottom"]), "top": float(run["top"]) })
		for run in runs:
			ops.append({ "op": "add", "bottom": float(run["bottom"]), "top": float(run["top"]), "material": str(run["material"]) })
	for op in current:
		if op is Dictionary and str(op.get("op", "")) == "deplete":
			ops.append(op)
	return ops

## Coerce a loaded edit list into plain { bottom, top, material } / op dicts with
## numeric fields — JSON hands back Variants, and the run algebra compares floats.
##
## An op whose kind is not one of the two known ones is DROPPED, and so is an entry
## that is not a dict at all. Never defaulted: `remove` CARVES and `add` FILLS, so
## defaulting an unrecognized or corrupt op to `remove` turns a damaged save into
## silent terrain damage, while a dropped op is inert — the only safe reading of an
## op this version does not understand.
func _normalise_ops(ops: Array) -> Array:
	var out: Array = []
	for op in ops:
		if not (op is Dictionary):
			continue
		var o: Dictionary = op
		var kind := str(o.get("op", ""))
		if kind == "deplete":
			# Phase 43 — a vein depletion record (see `_record_depletion`). Kept only when it
			# names a vein and a non-negative count; it never touches the runs.
			var vein_id := str(o.get("vein", ""))
			var taken := int(o.get("taken", -1))
			if vein_id != "" and taken >= 0:
				out.append({ "op": "deplete", "vein": vein_id, "taken": taken })
			continue
		if kind != "add" and kind != "remove":
			continue
		var entry := {
			"op":     kind,
			"bottom": float(o.get("bottom", 0.0)),
			"top":    float(o.get("top", 0.0)),
		}
		if kind == "add":
			entry["material"] = str(o.get("material", ""))
		out.append(entry)
	return out

## Apply a block edit's terrain mutation (tile resolution + run edit + chunk
## rebuild). Shared by the authoritative mine/place path and the client's
## apply_block_change so host and client derive the identical tile, span, and
## material from the same math. Returns { applied, tile, new_h, pos, material }.
## Dirty-chunk tracking is host-only and done by the callers
## (mine_block/place_block), never here.
func _apply_edit(action: String, position: Vector3, normal: Vector3, material: String) -> Dictionary:
	if action == "settle":
		return s._apply_settle(position, normal, material)
	var r = s._resolve_edit_tile(action, position, normal)
	var tile: Vector2i = r["tile"]
	var xz: Vector2 = r["xz"]
	if action == "mine":
		var span = s._mine_span(s.get_runs_at_tile(tile), position, normal)
		if span.is_empty():
			return { "applied": false }
		# Phase 43 — the client records the SAME depletion the host did: both evaluate the
		# same field over the same log, so the vein's reserve agrees with nothing extra on
		# the wire (and a re-scope snapshot carries the deplete op if a change was missed).
		# The yield is resolved BEFORE the remove (its depth is the span's), but recorded
		# AFTER it — the host's order in `mine_block` — so an anchor tile's op log is
		# identical on both sides (`_ops_equal` compares positionally) and an exhaustion
		# rebuild never gathers the pre-mine column.
		var yielded: Dictionary = {}
		if str(span["material"]) == "":
			yielded = s._natural_yield(tile, span)
		s._append_edit(tile, { "op": "remove", "bottom": span["bottom"], "top": span["top"] })
		if not yielded.is_empty() and not (yielded["vein"] as Dictionary).is_empty():
			s._record_depletion(yielded["vein"], int(yielded["quantity"]))
		s._rebuild_chunk_at_tile(tile)
		return {
			"applied": true, "tile": tile, "new_h": s.column_top_at_tile(tile),
			"pos": Vector3(position.x, float(span["top"]), position.z),
			"material": str(span["material"]),
		}
	if action == "place":
		var span = s._place_span(s.get_runs_at_tile(tile), position, normal)
		if span.is_empty():
			return { "applied": false }
		s._append_edit(tile, { "op": "add", "bottom": span["bottom"], "top": span["top"], "material": material })
		s._rebuild_chunk_at_tile(tile)
		return {
			"applied": true, "tile": tile, "new_h": float(span["top"]),
			"pos": Vector3(xz.x, float(span["top"]), xz.y),
			"material": material,
		}
	return { "applied": false }

## Host only: a mine or place at `tile` may leave loose ground over air in it or a neighbour. A client
## never settles on its own — it applies the host's `settle` changes — so it queues nothing.
func _settle_note(tile: Vector2i) -> void:
	if s.is_authoritative:
		s._settle.push_edit(tile)

## Phase 149 — the settle queue is not stored: every edited column read from disk is queued again, and a
## settled column costs one no-op visit. That covers the columns that were queued or parked when the
## world was saved, so a quit before the sand finished falling leaves nothing floating after the reload.
func _settle_requeue_loaded(tile_keys: Array) -> void:
	if not s.is_authoritative:
		return
	for key in tile_keys:
		s._settle.push(s._key_to_tile(str(key)))

## Columns waiting to settle, parked ones included (a test reads it).
func settle_pending() -> int:
	return s._settle.size() + s._settle.pending_size()

## Settle up to `budget` queued columns; returns how many were processed. A column whose chunk is not
## loaded is parked until it loads (`build_chunk`), not dropped. Host only.
func settle_tick(budget: int = s.SETTLE_BUDGET) -> int:
	if not s.is_authoritative:
		return 0
	var done := 0
	for tile in s._settle.take(budget):
		var ckey = s._chunk_key(s._tile_to_chunk(tile))
		if not s._heightmaps.has(ckey):
			s._settle.defer(ckey, tile)
			continue
		done += 1
		s._settle_tile(tile)
	return done

## Drop the loose runs of one column onto their support through the ordinary edit path. A settle edit
## grants no item and costs no material, and it queues nothing (a vertical fall touches no neighbour).
## Each fall goes to clients as a `settle` change: position = the old span's bottom (tile centre in XZ),
## normal = (old top, new bottom, 0).
func _settle_tile(tile: Vector2i) -> bool:
	var falls = s.Settle.moves(s.get_runs_at_tile(tile), s.is_granular, s.BEDROCK_DEPTH)
	if falls.is_empty():
		return false
	var xz = Vector2((tile.x + 0.5) * s.TILE_SIZE, (tile.y + 0.5) * s.TILE_SIZE)
	for f in falls:
		var from_bottom: float = f["from_bottom"]
		var from_top: float = f["from_top"]
		var to_bottom: float = f["to_bottom"]
		s._append_edit(tile, { "op": "remove", "bottom": from_bottom, "top": from_top })
		s._append_edit(tile, { "op": "add", "bottom": to_bottom, "top": to_bottom + (from_top - from_bottom), "material": f["material"] })
	s.settle_edits += falls.size()
	s._mark_dirty(tile)
	s._rebuild_chunk_at_tile(tile)
	for f in falls:
		var from_bottom: float = f["from_bottom"]
		var from_top: float = f["from_top"]
		if from_bottom - float(f["to_bottom"]) > s.Settle.TREE_CLEAR_DROP_M:
			GameBus.block_edit_resolved.emit(tile, from_top)   # a tree on the fallen ground goes (Phase 116 path)
		GameBus.block_changed.emit("settle", Vector3(xz.x, from_bottom, xz.y), Vector3(from_top, float(f["to_bottom"]), 0.0), str(f["material"]))
	return true

## Client side of a host `settle` change (see `_settle_tile`). The span must be well formed and inside
## the world; anything else is ignored.
func _apply_settle(position: Vector3, normal: Vector3, material: String) -> Dictionary:
	var from_bottom := position.y
	var from_top := normal.x
	var to_bottom := normal.y
	var height := from_top - from_bottom
	if height <= 0.0 or to_bottom >= from_bottom or to_bottom < s.BEDROCK_DEPTH or from_top > s.MAX_HEIGHT or material == "":
		return { "applied": false }
	if not s.is_granular(material):
		return { "applied": false }   # only loose ground falls: a rock run never moves
	var tile = s._world_to_tile(Vector2(position.x, position.z))
	s._append_edit(tile, { "op": "remove", "bottom": from_bottom, "top": from_top })
	s._append_edit(tile, { "op": "add", "bottom": to_bottom, "top": to_bottom + height, "material": material })
	s._rebuild_chunk_at_tile(tile)
	return { "applied": true, "tile": tile, "new_h": s.column_top_at_tile(tile), "pos": position, "material": material }

func _on_mine_requested(position: Vector3, normal: Vector3, player_id: String, exact: Dictionary = {}) -> void:
	if s.is_authoritative:
		s.mine_block(position, normal, player_id, exact)
	else:
		GameBus.block_edit_intent.emit("mine", position, normal, "", exact)

## The inventory an edit by `player_id` resolves against: that player's own pack from
## the registry when one is wired, else this slice's (`""` = this machine's own
## player, the Phase 34 `resolve_player` convention). The same resolve shape
## `CraftingSlice.inventory_for` uses, and for the same reason: one process holds one
## inventory per player, so a host resolving an action for a peer must reach THAT
## player's, never its own (see `mine_block`).
func inventory_for(player_id: String) -> Node:
	if player_id != "" and s.player_registry != null and s.player_registry.has_method("get_inventory"):
		var inv: Node = s.player_registry.get_inventory(player_id)
		if inv != null:
			return inv
	return s.inventory_slice

## Is `player_id` a player whose own client mirrors this inventory over the wire? False
## for `""` (this machine's own player) and for the local id, whose pack is live in this
## process and already in sync — the same test `PeerWiring.sync_peer_own_state` makes
## before it sends. A slice with no registry (an isolated rig) answers true for any
## non-empty id: it cannot tell, and the sync signal is addressee-filtered anyway.
func _is_remote_actor(player_id: String) -> bool:
	if player_id == "":
		return false
	if s.player_registry != null and "local_player_id" in s.player_registry:
		return player_id != str(s.player_registry.local_player_id)
	return true

## Phase 42 review — an edit the host resolved for a REMOTE actor changed that player's
## pack, which lives HERE (the registry's copy) but is mirrored by the peer's own
## client. Without this the client keeps rendering its pre-edit inventory until the next
## snapshot — the client's half of the transfer the review found missing. The signal is
## addressed to its owner (Phase 37), so networking delivers it to that peer ALONE; it
## is the same mechanism the net harness's `inventory_owner` step pins.
func _push_inventory(player_id: String) -> void:
	if not s._is_remote_actor(player_id):
		return
	var inv = s.inventory_for(player_id)
	if inv == null or not inv.has_method("get_contents"):
		return
	GameBus.inventory_synced.emit(player_id, inv.get_contents(), inv.get_durability_data())

## The held mining pick's item id, or "" when `inventory` holds none. Delegates to the
## inventory's fabric-driven tool lookup ("pick" → FerritePick/VeilsteelPick).
func _held_pick(inventory: Node) -> String:
	if inventory == null or not inventory.has_method("find_tool"):
		return ""
	return str(inventory.find_tool("pick"))

func _on_place_requested(position: Vector3, normal: Vector3, player_id: String, material: String, exact: Dictionary = {}) -> void:
	if s.is_authoritative:
		# `material` as received: `place_block` decides whether "" may fall back to this
		# machine's own selection (only for the local actor, never for a remote one).
		s.place_block(position, normal, material, player_id, exact)
	else:
		var chosen = material if material != "" else s._place_material
		GameBus.block_edit_intent.emit("place", position, normal, chosen, exact)

## Client-side application of a host-authoritative block edit (see block_changed).
## Delegates to the shared _apply_edit helper so host and client derive the same
## tile and span from the same math.
func apply_block_change(action: String, position: Vector3, normal: Vector3, material: String) -> void:
	s._apply_edit(action, position, normal, material)
