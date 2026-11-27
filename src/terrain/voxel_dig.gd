extends RefCounted
## Phase 300 — a dig is one brush op over the run columns. `s` is the owning slice. The host resolves the brush
## from its own copy of the tool table (`DigBrush` in the fabric), rasterises it (`DigRasteriser`), appends the
## `remove` spans through `_append_edit` and broadcasts ONE `block_changed("dig", centre, (radius, k, shape), tool)`;
## a client rasterises the same op over the same runs, so the logs are identical. Placed blocks are never cut.

const Ras := preload("res://src/terrain/dig_rasteriser.gd")
const VoxelConsts := preload("res://src/terrain/voxel_consts.gd")
const EditRemesh := preload("res://src/terrain/edit_remesh.gd")
const RecordSanitize := preload("res://src/persistence/record_sanitize.gd")

## Yield volume of one slab: a tile (0.5 m)² by one STEP_HEIGHT.
const SLAB_M3 := 0.5 * 0.5 * 0.125

var s: Node
## player id -> material -> volume (m³) not yet paid out; only when no player registry is wired (the registry saves it).
var remainder: Dictionary = {}

func _init(slice: Node) -> void:
	s = slice

static func _table() -> Dictionary:
	var res: Resource = GameData.WORLD_SYSTEMS.get("DigBrush", null)
	return {} if res == null else { "brushes": res.get("brushes"), "unit": res.get("unitVolume"),
		"default_unit": float(res.get("defaultUnitVolume")), "cap": float(res.get("radiusCap")) }

## The brush a held tool digs with: `{ shape, radius, materials }`, or {} when the fabric has none.
static func brush_for(tool: String) -> Dictionary:
	var t := _table()
	var brushes: Dictionary = t.get("brushes", {})
	return brushes.get(tool, brushes.get("", {}))

## The brush is a brush op, not the old single slab, once its radius reaches one tile.
static func is_brush(tool: String) -> bool:
	var b := brush_for(tool)
	return not b.is_empty() and float(b["radius"]) >= VoxelConsts.TILE_SIZE

## How many times longer a hold is than one slab's: the cells the brush would remove here × the fabric's share, at least 1.
func work_factor(cells: int) -> float:
	var res: Resource = GameData.WORLD_SYSTEMS.get("DigBrush", null)
	var share := float(res.get("workSlabShare")) if res != null else 1.0
	return maxf(1.0, float(cells) * share)

static func unit_volume(material: String) -> float:
	var t := _table()
	return float((t.get("unit", {}) as Dictionary).get(material, t.get("default_unit", SLAB_M3)))

## Rasterise `{centre, radius, k, shape}` cut by `tool` over the slice's runs. Returns
## `{ cells: [{tile, bottom, top, material, vein}], brush }`; each cell's yield is resolved from the ground as it
## is BEFORE the cut (the depth is the span's own).
func plan(centre: Vector3, radius: float, k: float, shape: String, tool: String) -> Dictionary:
	var spec := brush_for(tool)
	if spec.is_empty():
		return { "cells": [] }
	var allowed: Array = spec["materials"]
	var yields := {}
	var cut_ok := func(tile: Vector2i, bottom: float, top: float) -> bool:
		var y: Dictionary = s.natural_yield(tile, { "bottom": bottom, "top": top, "material": "" })
		yields["%d,%d,%f" % [tile.x, tile.y, bottom]] = y
		return allowed.has(str(y["material"]))
	var brush := { "shape": shape, "centre": centre, "radius": radius, "k": k }
	var raw: Array = Ras.rasterise(brush, s.get_runs_at_tile, cut_ok)
	for cell in raw:
		var y: Dictionary = yields["%d,%d,%f" % [cell["tile"].x, cell["tile"].y, cell["bottom"]]]
		cell["material"] = str(y["material"])
		cell["vein"] = y.get("vein", {})
		cell["host"] = bool(y.get("host", false))
	return { "cells": raw, "brush": brush }

## Write a plan's cells into the op log (one remove per contiguous span, compaction batched), record the veins'
## depletion (capped by reserve, in slabs), and remesh. Returns `{ volumes: material -> m³, spans, tiles }`.
## Runs identically on the host and a client.
func apply_plan(cells: Array, level: int) -> Dictionary:
	var by_tile := {}
	for cell in cells:
		var key: Vector2i = cell["tile"]
		if not by_tile.has(key):
			by_tile[key] = []
		by_tile[key].append(cell)
	var volumes := {}
	var depleted := {}   # vein id -> slabs taken by this dig
	var vein_of := {}
	for cell in cells:
		var vein: Dictionary = cell["vein"]
		if vein.is_empty():
			volumes[cell["material"]] = float(volumes.get(cell["material"], 0.0)) + SLAB_M3
			continue
		var id := str(vein["id"])
		var left: int = s.OreField.remaining(vein, s._vein_taken) - int(depleted.get(id, 0))
		if left <= 0:
			continue   # the vein's reserve ran out inside this dig: the ground goes, no more ore
		depleted[id] = int(depleted.get(id, 0)) + 1
		vein_of[id] = vein
		volumes[cell["material"]] = float(volumes.get(cell["material"], 0.0)) + SLAB_M3
	var tiles: Array = by_tile.keys()
	var spans := 0
	for tile in tiles:
		for span in Ras.merge_spans(by_tile[tile]):
			s._edit._append_edit(tile, { "op": "remove", "bottom": span["bottom"], "top": span["top"] }, false)
			spans += 1
			if s.structures != null:
				s.structures.drop_span(tile, float(span["bottom"]), float(span["top"]))
		s._edit._compact_if_long(tile)
	for id in depleted:
		var vein: Dictionary = vein_of[id]
		s._record_depletion(vein, int(depleted[id]))
	for tile in tiles:
		s._mark_dirty(tile)
		s._settle_note(tile)
		s._rebuild_chunk_at_tile(tile, level)
	for id in depleted:
		s._mark_dirty(vein_of[id]["anchor"])
	return { "volumes": volumes, "spans": spans, "tiles": tiles, "depleted": depleted }

## Units paid for `volumes` (material -> m³) to `player_id`, carrying each material's remainder forward so many
## small digs yield what one big one does. Returns material -> whole units.
func pay_units(player_id: String, volumes: Dictionary) -> Dictionary:
	var out := {}
	var reg: Node = s.player_registry
	var rec: Dictionary = reg.ensure_player(player_id) if reg != null and reg.has_method("ensure_player") else {}
	var mine: Dictionary = RecordSanitize.sanitize_dig_remainder(rec.get("dig_remainder", {})) if not rec.is_empty() else remainder.get(player_id, {})
	for material in volumes:
		var unit := unit_volume(str(material))
		var total := float(mine.get(material, 0.0)) + float(volumes[material])
		var units := floori(total / unit + 0.000001)
		mine[material] = maxf(total - float(units) * unit, 0.0)
		if units > 0:
			out[material] = units
	if not rec.is_empty():
		rec["dig_remainder"] = mine   # saved with the player
	else:
		remainder[player_id] = mine
	return out

## Client side of a dig the host broadcast: rasterise the same op and apply it.
func apply_wire(centre: Vector3, params: Vector3, tool: String, level: int) -> Dictionary:
	var shapes: Array = Ras.SHAPES
	var shape := str(shapes[clampi(int(params.z), 0, shapes.size() - 1)])
	var p := plan(centre, params.x, params.y, shape, tool)
	if (p["cells"] as Array).is_empty():
		return { "applied": false }
	apply_plan(p["cells"], level)
	return { "applied": true, "pos": centre, "material": "" }
