extends RefCounted
## Phase 300 — digging with a brush on the run columns: the host's plan and execution, and the apply every peer
## shares. `DigBrush` is the pure rasteriser; this file feeds it the slice's runs and ground (`natural_yield`),
## appends what it cuts through the ordinary edit path and pays the yield by volume.
##
## The wire: the host resolves a client's one "mine" intent into one `block_changed` with action `dig`. Its
## `position` is the brush centre (metres, for interest management), `normal` the hit normal, and `material` the
## op as `shape|radius_mm|k_mm|tool|cx,cy,cz|deplete` (`encode` / `decode`): `tool` names a fabric brush (the cuts
## are looked up from the fabric on every peer, never sent), `deplete` is the per-vein units the host's yield took
## (`id@n/id@n`), `?` for a peer that must estimate it (a client's prediction) and empty for none. It stays on
## the JSON `block_changed` path (Phase 256's binary codec covers only tags 1-3).
##
## Trust: the host recomputes shape, radius and cuts from its own held tool, skill tier and runs (`plan`); a
## client's intent carries only the aim. A peer applying a `dig` bounds the op (`DigBrush.problem`, the fabric's
## radius cap) and looks the tool up in the fabric table.

const WorkSkills := preload("res://src/character/work_skills.gd")
const WorkTime := preload("res://src/core/work_time.gd")
const SkillTiers := preload("res://src/core/skill_tiers.gd")
const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")
const EditRemesh := preload("res://src/terrain/edit_remesh.gd")
const DigBrush := preload("res://src/terrain/dig_brush.gd")
const RecordSanitize := preload("res://src/persistence/record_sanitize.gd")

## One slab (a tile by a step) in m3: the unit the fabric's `unitVolume` is measured against.
const SLAB_M3 := 0.5 * 0.5 * 0.125
const EPS := 1.0e-9

var s: Node   # the VoxelSlice
var e: RefCounted   # its VoxelEdit
## The remainders of a slice with no player registry (an isolated rig): { player_id: { material: fraction } }.
var _local_remainder: Dictionary = {}

func _init(slice: Node, edit: RefCounted) -> void:
	s = slice
	e = edit

# --- the fabric table ---------------------------------------------------------

static func _res() -> Resource:
	return GameData.WORLD_SYSTEMS.get("DigBrushes", null)

static func _fab(key: String, fallback: Variant) -> Variant:
	var res := _res()
	var v: Variant = res.get(key) if res != null else null
	return v if v != null else fallback

static func radius_cap_mm() -> int:
	return roundi(float(_fab("radiusCap", 1.5)) * 1000.0)

static func brushes() -> Dictionary:
	var v: Variant = _fab("brushes", {})
	return v if v is Dictionary else {}

## The fabric brush named `tool` (`hands` for an item that has none), `{}` when the table is absent.
static func brush_of(tool_name: String) -> Dictionary:
	var b := brushes()
	return b.get(tool_name, b.get("hands", {}))

## The materials brush `tool_name` cuts, as `{ material: true }`.
static func cuts_of(tool_name: String) -> Dictionary:
	var out: Dictionary = {}
	for m in brush_of(tool_name).get("cuts", []):
		out[str(m)] = true
	return out

## Cells of `material` one yielded unit takes (the fabric's unit volume over one slab; 1.0 by default).
static func unit_cells(material: String) -> float:
	var uv: Variant = _fab("unitVolume", {})
	var d: Dictionary = uv if uv is Dictionary else {}
	var vol := float((d.get("overrides", {}) as Dictionary).get(material, d.get("default", SLAB_M3)))
	return maxf(vol, 1.0e-6) / SLAB_M3

# --- wire ---------------------------------------------------------------------

static func encode(op: Dictionary, tool_name: String, deplete: Variant) -> String:
	var c: Array = op["centre"]
	var dep := "?"
	if deplete is Dictionary:
		var parts: Array = []
		var ids: Array = (deplete as Dictionary).keys()
		ids.sort()
		for id in ids:
			parts.append("%s@%d" % [id, int(deplete[id])])
		dep = "/".join(parts)
	return "%s|%d|%d|%s|%d,%d,%d|%s" % [op["shape"], op["radius"], op["k"], tool_name, c[0], c[1], c[2], dep]

## `{ op, tool, deplete }` (`deplete` null = estimate it), or `{}` for a string that is not a well-formed, bounded
## op of a fabric brush.
static func decode(text: String) -> Dictionary:
	var parts := text.split("|")
	if parts.size() != 6 or not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return {}
	var cs := parts[4].split(",")
	if cs.size() != 3:
		return {}
	for v in cs:
		if not v.is_valid_int():
			return {}
	var op := { "shape": parts[0], "centre": [int(cs[0]), int(cs[1]), int(cs[2])], "radius": int(parts[1]), "k": int(parts[2]) }
	if DigBrush.problem(op, radius_cap_mm()) != "" or not brushes().has(parts[3]):
		return {}
	var deplete: Variant = null
	if parts[5] != "?":
		var d: Dictionary = {}
		for item in parts[5].split("/", false):
			var kv := item.split("@")
			if kv.size() != 2 or not kv[1].is_valid_int() or int(kv[1]) < 0 or kv[0].length() > 40:
				return {}
			d[kv[0]] = int(kv[1])
		deplete = d
	return { "op": op, "tool": parts[3], "deplete": deplete }

# --- plan: the host's own brush -------------------------------------------------

## The Mining tier (0 = novice) of `player_id` from the registry this slice owns; 0 without one.
func tier_index(player_id: String) -> int:
	var registry: Object = s.player_registry
	var skill := WorkSkills.bonus_skill("dig", "speed")
	if skill == "" or registry == null or not registry.has_method("get_skill_tier"):
		return 0
	var pid := player_id
	if pid == "" and "local_player_id" in registry:
		pid = str(registry.local_player_id)
	return maxi(SkillTiers.TIER_ORDER.find(str(registry.get_skill_tier(pid, skill))), 0)

## The brush a dig at the aim makes for `player_id`, from this machine's own copy of the held tool, tier and runs:
## `{ op, tool }`, or `{}` when it is the old single slab (a placed block, a brush smaller than the fabric's
## minimum radius, nothing to dig, a closed site). The caller's client-sent fields never reach it but `world_pos`,
## `normal` and `exact`.
func plan(world_pos: Vector3, normal: Vector3, player_id: String, exact: Dictionary = {}) -> Dictionary:
	if brushes().is_empty():
		return {}
	var probe: Dictionary = s._resolve_edit_tile("mine", world_pos, normal, exact)
	var tile: Vector2i = probe["tile"]
	if TerrainSlice.in_closed_site(probe["xz"]):
		return {}
	var span: Dictionary = s._mine_span(s.get_runs_at_tile(tile), world_pos, normal)
	if span.is_empty() or str(span["material"]) != "":
		return {}   # a placed block: Phase 205's rules decide it, one slab at a time
	var material := str(e._natural_yield(tile, span)["material"])
	var action := WorkTime.action_for_material(material)
	var inventory: Node = e.inventory_for(player_id)
	var tool_name := WorkTime.held_tool(inventory, action if action != "" else "mine")
	if not brushes().has(tool_name):
		tool_name = "hands"
	var brush := brush_of(tool_name)
	if brush.is_empty():
		return {}
	var radius: float = minf(float(brush["radius"]) + float(_fab("skillRadiusPerTier", 0.0)) * tier_index(player_id),
		float(_fab("radiusCap", 1.5)))
	if radius < float(_fab("minRadius", 0.25)):
		return {}
	var x: float = world_pos.x
	var z: float = world_pos.z
	if exact.has("chunk") and exact.has("local"):
		var c: Vector2i = exact["chunk"]
		var l: Vector3 = exact["local"]
		x = float(c.x) * s.CHUNK_SIZE * s.TILE_SIZE + l.x
		z = float(c.y) * s.CHUNK_SIZE * s.TILE_SIZE + l.z
	var op := DigBrush.make_op(str(brush["shape"]), Vector3(x, world_pos.y, z), normal, roundi(radius * 1000.0),
		roundi(float(_fab("blend", 0.25)) * 1000.0))
	return { "op": op, "tool": tool_name }

# --- the runs the brush reads -----------------------------------------------------

## The natural runs of every tile the op's bounds reach, outside closed sites, as `DigBrush` columns.
func columns_for(op: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var b := DigBrush.bounds(op)
	for tx in range(b[0], b[1] + 1):
		for tz in range(b[2], b[3] + 1):
			var tile := Vector2i(tx, tz)
			if TerrainSlice.in_closed_site(Vector2((tx + 0.5) * s.TILE_SIZE, (tz + 0.5) * s.TILE_SIZE)):
				continue
			var flat := PackedInt32Array()
			for run in s.get_runs_at_tile(tile):
				if str((run as Dictionary).get("material", "")) == "":
					flat.append(roundi(float(run["bottom"]) * 1000.0))
					flat.append(roundi(float(run["top"]) * 1000.0))
			if not flat.is_empty():
				out[tile] = flat
	return out

## The ground's answer for a cell (`natural_yield` on the span it is): `{ material, vein }`.
func _classify(tx: int, tz: int, bottom_mm: int) -> Dictionary:
	var span := { "bottom": float(bottom_mm) / 1000.0, "top": float(bottom_mm + DigBrush.STEP_MM) / 1000.0 }
	var y: Dictionary = e._natural_yield(Vector2i(tx, tz), span)
	return { "material": str(y["material"]), "vein": y["vein"] }

## The op rasterised over this slice's runs, with the tool's cuts: `DigBrush.rasterise`'s result.
func preview(op: Dictionary, tool_name: String) -> Dictionary:
	return DigBrush.rasterise(op, columns_for(op), _classify, cuts_of(tool_name))

## `[tile, bottom, top]` the ack carries: the centre tile's removed extent (else the first tile's); `{}` for none.
func span_of(op: Dictionary, result: Dictionary) -> Dictionary:
	var tiles: Array = result["tiles"]
	if tiles.is_empty():
		return {}
	var c: Array = op["centre"]
	var want := Vector2i(floori(float(c[0]) / DigBrush.TILE_MM), floori(float(c[2]) / DigBrush.TILE_MM))
	var pick: Array = tiles[0]
	for t in tiles:
		if Vector2i(t[0], t[1]) == want:
			pick = t
			break
	var spans: PackedInt32Array = pick[2]
	return { "tile": Vector2i(pick[0], pick[1]), "bottom": float(spans[0]) / 1000.0, "top": float(spans[spans.size() - 1]) / 1000.0 }

## Every tile key the op may write: its bounds, and the anchor of each vein it reaches.
func keys_of(op: Dictionary, result: Dictionary) -> Array:
	var keys: Array = []
	for t in result["tiles"]:
		keys.append(s._tile_key(Vector2i(t[0], t[1])))
	for id in result["veins"]:
		var k: String = s._tile_key(result["veins"][id]["vein"]["anchor"])
		if not keys.has(k):
			keys.append(k)
	return keys

## Every tile key in the op's bounds (what a prediction watches before it knows what the op cuts).
func bound_keys(op: Dictionary) -> Array:
	var keys: Array = []
	var b := DigBrush.bounds(op)
	for tx in range(b[0], b[1] + 1):
		for tz in range(b[2], b[3] + 1):
			keys.append(s._tile_key(Vector2i(tx, tz)))
	return keys

# --- yield by volume ----------------------------------------------------------------

## What the removed volume pays, given the player's `remainders` (`{ material: fraction of a unit }`):
## `{ units: { material: n }, remainders: { material: fraction }, deplete: { vein id: n }, veins: { id: vein } }`.
## A vein's cells count `quantity` slabs each (a vein slab pays its own per-slice quantity, as a single slab did),
## capped by what is left of its reserve; `deplete` is exactly the units a vein paid, so its reserve falls by what
## was yielded.
func yield_of(result: Dictionary, remainders: Dictionary) -> Dictionary:
	var acc: Dictionary = {}   # material -> { "plain": float units, "veins": [[id, units]] }
	for m in result["volume"]:
		acc[m] = acc.get(m, { "plain": 0.0, "veins": [] })
		acc[m]["plain"] = float(result["volume"][m]) / unit_cells(m)
	var ids: Array = (result["veins"] as Dictionary).keys()
	ids.sort()
	var veins: Dictionary = {}
	for id in ids:
		var v: Dictionary = result["veins"][id]["vein"]
		var m := str(v["material"])
		var room := float(s.OreField.remaining(v, s._vein_taken))
		var units := minf(float(result["veins"][id]["cells"]) * float(v["quantity"]) / unit_cells(m), room)
		acc[m] = acc.get(m, { "plain": 0.0, "veins": [] })
		acc[m]["veins"].append([id, units])
		veins[id] = v
	var out_units: Dictionary = {}
	var out_rem: Dictionary = remainders.duplicate()
	var deplete: Dictionary = {}
	for m in acc:
		var total: float = float(remainders.get(m, 0.0)) + float(acc[m]["plain"])
		for pair in acc[m]["veins"]:
			total += float(pair[1])
		var qty := int(floorf(total + EPS))
		out_units[m] = qty
		out_rem[m] = maxf(total - float(qty), 0.0)
		var left := qty
		for pair in acc[m]["veins"]:
			var take := mini(mini(left, int(ceilf(float(pair[1]) - EPS))), s.OreField.remaining(veins[pair[0]], s._vein_taken))
			if take > 0:
				deplete[pair[0]] = take
				left -= take
	return { "units": out_units, "remainders": out_rem, "deplete": deplete, "veins": veins }

## A prediction's estimate of the depletion (no remainder): whole units each vein's cells pay.
func estimate_deplete(result: Dictionary) -> Dictionary:
	var d: Dictionary = {}
	for id in result["veins"]:
		var v: Dictionary = result["veins"][id]["vein"]
		var units := mini(int(floorf(float(result["veins"][id]["cells"]) * float(v["quantity"]) / unit_cells(str(v["material"])) + EPS)),
			s.OreField.remaining(v, s._vein_taken))
		if units > 0:
			d[id] = units
	return d

func _remainders_of(player_id: String) -> Dictionary:
	var registry: Object = s.player_registry
	if registry != null and registry.has_method("get_record"):
		var pid := player_id
		if pid == "" and "local_player_id" in registry:
			pid = str(registry.local_player_id)
		return RecordSanitize.sanitize_remainders(registry.get_record(pid).get("dig_remainder", {}))
	return RecordSanitize.sanitize_remainders(_local_remainder.get(player_id, {}))

func _store_remainders(player_id: String, rem: Dictionary) -> void:
	var registry: Object = s.player_registry
	if registry != null and registry.has_method("ensure_player"):
		var pid := player_id
		if pid == "" and "local_player_id" in registry:
			pid = str(registry.local_player_id)
		var rec: Dictionary = registry.ensure_player(pid)
		if not rec.is_empty():
			rec["dig_remainder"] = rem
			return
	_local_remainder[player_id] = rem

# --- work time (Phase 259) -----------------------------------------------------------

## The brush dig the aim would make, without touching anything: `{ material, key, seconds }` or `{}` when the aim
## is not a brush dig (the single slab's own `work_target`). `seconds` is the sum over the cells it would remove
## of the material's one-slab work time at the worker's tool and tier, times the fabric's `workFactor`, and never
## less than one slab's.
func work_target(world_pos: Vector3, normal: Vector3, player_id: String, exact: Dictionary = {}) -> Dictionary:
	var p := plan(world_pos, normal, player_id, exact)
	if p.is_empty():
		return {}
	var result := preview(p["op"], str(p["tool"]))
	if (result["tiles"] as Array).is_empty():
		return {}
	var inventory: Node = e.inventory_for(player_id)
	var seconds := 0.0
	var first := ""
	var counts: Dictionary = (result["volume"] as Dictionary).duplicate()
	for id in result["veins"]:
		var v: Dictionary = result["veins"][id]["vein"]
		counts[str(v["material"])] = int(counts.get(str(v["material"]), 0)) + int(result["veins"][id]["cells"])
	for m in counts:
		var action := WorkTime.action_for_material(str(m))
		if action == "":
			action = "mine"
		var tool_name := WorkTime.held_tool(inventory, action)
		var per := WorkTime.duration(str(m), action, tool_name, _tier_name(player_id, action), action)
		seconds += per * float(counts[m]) * float(_fab("workFactor", 0.1))
		if first == "" or int(counts[m]) > int(counts.get(first, 0)):
			first = str(m)
	var c: Array = p["op"]["centre"]
	return { "material": first, "key": "dig:%d,%d,%d,%d" % [c[0], c[1], c[2], int(p["op"]["radius"])],
		"seconds": seconds }

func _tier_name(player_id: String, action: String) -> String:
	return WorkTime.worker_tier(s.player_registry, player_id, action)

# --- execution ---------------------------------------------------------------------------

## Host: the brush dig of an aim (`plan` was non-empty). The result is `mine_block`'s: `{ success, material, quantity,
## position, player_id }` (`material`/`quantity` the first and largest yield), plus `units` for the whole dig.
func dig(p: Dictionary, world_pos: Vector3, normal: Vector3, player_id: String) -> Dictionary:
	var op: Dictionary = p["op"]
	var tool_name: String = p["tool"]
	var fail := { "success": false, "material": "", "quantity": 0, "position": world_pos, "player_id": player_id }
	var result := preview(op, tool_name)
	if (result["tiles"] as Array).is_empty():
		return fail
	var inventory: Node = e.inventory_for(player_id)
	var y := yield_of(result, _remainders_of(player_id))
	if tool_name != "hands" and inventory != null and inventory.has_method("use_item"):
		if not inventory.use_item(tool_name, "dig" if WorkTime.action_for_material(_first_material(result)) == "dig" else "mine"):
			return fail
	var level: int = e._edit_level(player_id)
	_apply(op, result, y["deplete"], level, true)
	_store_remainders(player_id, y["remainders"])
	var banked_total := 0
	var best := ""
	var best_qty := 0
	var host_rock := false
	for m in y["units"]:
		var qty: int = int(y["units"][m])
		if qty <= 0:
			continue
		var banked := 0
		if inventory != null and inventory.has_method("add_item"):
			banked = _bank(inventory, str(m), qty)
		if banked < qty and not s._is_remote_actor(player_id):
			GameBus.inventory_full.emit()
		if banked > 0:
			banked_total += banked
			GameBus.block_mined.emit(str(m), banked, world_pos)
			GameBus.resource_gathered.emit(player_id, str(m), banked)
			if s.is_authoritative:
				WorkSkills.grant(s.player_registry, player_id, WorkSkills.gather_row(str(m)), banked)
		if qty > best_qty:
			best_qty = qty
			best = str(m)
	s._push_inventory(player_id)
	var span := span_of(op, result)
	GameBus.block_edit_resolved.emit(span["tile"], float(span["top"]))
	GameBus.block_edit_span.emit(span["tile"], float(span["bottom"]), float(span["top"]))
	var c: Array = op["centre"]
	GameBus.block_changed.emit("dig", Vector3(c[0], c[1], c[2]) * 0.001, normal, encode(op, tool_name, y["deplete"]))
	return { "success": true, "material": best, "quantity": best_qty, "position": world_pos, "player_id": player_id,
		"units": y["units"], "banked": banked_total }

func _first_material(result: Dictionary) -> String:
	var best := ""
	for m in result["volume"]:
		if best == "" or int(result["volume"][m]) > int(result["volume"][best]):
			best = str(m)
	if best == "":
		for id in result["veins"]:
			return str(result["veins"][id]["vein"]["material"])
	return best

## Put as much of `qty` in the pack as fits (the ground is dug either way); the number banked.
func _bank(inventory: Node, material: String, qty: int) -> int:
	var q := qty
	while q > 0:
		if inventory.add_item(material, q):
			return q
		q -= 1
	return 0

## Append the cut spans of `result` to the logs and record the depletion. Host and client share it; the host-only
## extras (placed-block index, dirty marks, settling) run only when `commit` (the host's own dig, never a prebuild
## or a prediction that is taken back).
func _apply(op: Dictionary, result: Dictionary, deplete: Dictionary, level: int, commit: bool = false) -> void:
	var chunks: Dictionary = {}
	var own_chunk: Vector2i = s._tile_to_chunk(Vector2i(floori(float(op["centre"][0]) / DigBrush.TILE_MM), floori(float(op["centre"][2]) / DigBrush.TILE_MM)))
	for t in result["tiles"]:
		var tile := Vector2i(t[0], t[1])
		var spans: PackedInt32Array = t[2]
		for i in range(0, spans.size(), 2):
			var bottom := float(spans[i]) / 1000.0
			var top := float(spans[i + 1]) / 1000.0
			e._append_edit(tile, { "op": "remove", "bottom": bottom, "top": top }, false)
			if commit and s.structures != null:
				s.structures.drop_span(tile, bottom, top)
		e._compact_if_long(tile)
		if commit:
			s._mark_dirty(tile)
			s._settle_note(tile)
		for c in s._touched_chunks(tile):
			chunks[c] = true
	for id in deplete:
		var vein: Dictionary = (result["veins"][id]["vein"]) if result["veins"].has(id) else s._vein_from_id(str(id))
		if vein.is_empty():
			continue
		s._record_depletion(vein, int(deplete[id]))
		if commit:
			s._mark_dirty(vein["anchor"])
	for c in chunks:
		s._rebuild_chunk(c, level if c == own_chunk else mini(level, EditRemesh.NEIGHBOUR))

## A peer applying the host's `dig` change (`block_changed`): the op decoded and bounded, rasterised over this
## peer's runs. `{ applied, tile, new_h, pos, material }` like `_apply_edit`.
func apply_wire(position: Vector3, normal: Vector3, text: String, level: int) -> Dictionary:
	var d := decode(text)
	if d.is_empty():
		return { "applied": false }
	var op: Dictionary = d["op"]
	var c: Array = op["centre"]
	if Vector3(c[0], c[1], c[2]).distance_to(position * 1000.0) > 2000.0 + float(op["radius"]):
		return { "applied": false }   # a centre nowhere near where the change says it is
	var result := preview(op, str(d["tool"]))
	if (result["tiles"] as Array).is_empty():
		return { "applied": false }
	var deplete: Dictionary = d["deplete"] if d["deplete"] is Dictionary else estimate_deplete(result)
	_apply(op, result, deplete, level)
	var span := span_of(op, result)
	return { "applied": true, "tile": span["tile"], "new_h": s.column_top_at_tile(span["tile"]),
		"pos": Vector3(float(c[0]) * 0.001, float(span["top"]), float(c[2]) * 0.001), "material": text }

## The tile keys a decoded wire op writes (for a prebuild or a prediction watching a host `dig`).
func wire_keys(text: String) -> Array:
	var d := decode(text)
	if d.is_empty():
		return []
	return keys_of(d["op"], preview(d["op"], str(d["tool"])))

## The span a wire op would remove on this peer's runs now (`{ tile, bottom, top }`), `{}` for none.
func wire_span(text: String) -> Dictionary:
	var d := decode(text)
	if d.is_empty():
		return {}
	return span_of(d["op"], preview(d["op"], str(d["tool"])))

## Tile keys to watch for a host `dig` change: its bounds, and what it writes on this peer's runs.
func wire_watch(text: String) -> Array:
	var d := decode(text)
	if d.is_empty():
		return []
	var keys := bound_keys(d["op"])
	for k in keys_of(d["op"], preview(d["op"], str(d["tool"]))):
		if not keys.has(k):
			keys.append(k)
	return keys
