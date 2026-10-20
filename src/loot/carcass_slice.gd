extends Node
## Carcass slice (Phase 161) — the body a kill leaves, worked or carried by players.
##
## Plug contract (GameBus):
##   IN  : creature_died (host: leaves a carcass instead of rolling a drop table)
##   OUT : carcass_changed(carcass_id), carcass_removed(carcass_id)  — the wiring scopes them to the AOI
##
## The host owns every record; a client holds a view (`apply_view` / `remove_view`) the host sent. Records:
##   { id, creature, position: Vector3, entries: Array (harvest entries not yet worked), killer, remaining
##     (seconds until it decays), carrier (player id or ""), mode ("carry" | "drag" | "") , mass }
## The rules (what a tool can take, how a level scales a yield, capacity against mass) live in
## `carcass_rules.gd` and the fabric; this slice only keeps the bodies and decides who may touch them.

const CarcassRules := preload("res://src/loot/carcass_rules.gd")
const RegionStore := preload("res://src/persistence/region_store.gd")
const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")
const SceneOffset := preload("res://src/core/scene_offset.gd")

## Why a harvest or carry was refused (also what the wiring sends the player as a key).
const OK := ""
const REASON_UNKNOWN := "unknown_carcass"
const REASON_RANGE := "out_of_range"
const REASON_EMPTY := "empty"
const REASON_NO_TOOL := "no_tool"
const REASON_CARRYING := "carrying"
const REASON_TAKEN := "carried_by_other"
const REASON_TOO_HEAVY := "too_heavy"

var _carcasses: Dictionary = {}
var _next_id: int = 0
## player id -> carcass id they carry.
var _carried: Dictionary = {}
## Scene node per carcass (clients and listen hosts only); empty when `render_visuals` is false.
var render_visuals: bool = false
var _nodes: Dictionary = {}
## The scene-origin offset a client rebase has applied; body nodes sit at world position + this.
var _origin: SceneOffset = SceneOffset.new()

# ---------------------------------------------------------------------------
# Host: records
# ---------------------------------------------------------------------------

## Leave the body of `creature_key` at `position`. Returns the carcass id ("" when the creature has no
## harvest entries and so no body worth keeping).
func create_for_death(creature_key: String, position: Vector3, killer: String) -> String:
	var entries := CarcassRules.entries_for(creature_key)
	if entries.is_empty():
		return ""
	var id := "carcass_%d" % _next_id
	_next_id += 1
	_carcasses[id] = {
		"id": id, "creature": creature_key, "position": position, "entries": entries, "killer": killer,
		"remaining": CarcassRules.corpse_seconds(creature_key), "carrier": "", "mode": "",
		"mass": CarcassRules.mass_of(creature_key),
	}
	_enforce_region_cap(position, id)
	_refresh(id)
	return id

func has_carcass(id: String) -> bool:
	return _carcasses.has(id)

func get_carcass(id: String) -> Dictionary:
	return (_carcasses[id] as Dictionary).duplicate(true) if _carcasses.has(id) else {}

func count() -> int:
	return _carcasses.size()

func ids() -> Array:
	return _carcasses.keys()

func position_of(id: String) -> Vector3:
	return (_carcasses[id]["position"] as Vector3) if _carcasses.has(id) else Vector3(INF, INF, INF)

## A snapshot of the bodies for a client view: ids and what a prompt needs, no host-only fields.
func view_of(id: String) -> Dictionary:
	if not _carcasses.has(id):
		return {}
	var c: Dictionary = _carcasses[id]
	return { "id": id, "creature": c["creature"], "position": c["position"], "entries": (c["entries"] as Array).duplicate(true),
		"carrier": c["carrier"], "mode": c["mode"], "mass": c["mass"], "remaining": c["remaining"] }

## Tick the decay clock; a body whose time ran out is removed (a carried one is dropped with it).
func advance(delta: float) -> void:
	for id in _carcasses.keys():
		var c: Dictionary = _carcasses[id]
		c["remaining"] = float(c["remaining"]) - delta
		if float(c["remaining"]) <= 0.0:
			remove(id)

func remove(id: String) -> void:
	if not _carcasses.has(id):
		return
	var carrier := str(_carcasses[id]["carrier"])
	if carrier != "":
		_carried.erase(carrier)
		GameBus.carcass_carrier_lost.emit(carrier)
	_carcasses.erase(id)
	_free_node(id)
	GameBus.carcass_removed.emit(id)

## The region key ("rx,rz") a position falls in.
static func region_key(position: Vector3) -> String:
	var chunk := Vector2i(floori(position.x / TerrainSlice.CHUNK_METERS), floori(position.z / TerrainSlice.CHUNK_METERS))
	var r := RegionStore.region_of_chunk(chunk)
	return "%d,%d" % [r.x, r.y]

## Past `maxCarcassesPerRegion` in a region the body with the least time left decays first.
func _enforce_region_cap(position: Vector3, keep: String) -> void:
	var cap := int(CarcassRules.rule_f("maxCarcassesPerRegion", 24.0))
	var key := region_key(position)
	var here: Array = []
	for id in _carcasses:
		if region_key(_carcasses[id]["position"]) == key:
			here.append(id)
	while here.size() > cap:
		var oldest := ""
		for id in here:
			if id != keep and (oldest == "" or float(_carcasses[id]["remaining"]) < float(_carcasses[oldest]["remaining"])):
				oldest = id
		if oldest == "":
			return
		here.erase(oldest)
		remove(oldest)

# ---------------------------------------------------------------------------
# Host: harvest
# ---------------------------------------------------------------------------

## "" when `player_pos` may harvest `id` with a tool of `category` ("" = bare hands), else the reason.
func check_harvest(id: String, player_pos: Vector3, category: String, player_id: String) -> String:
	if not _carcasses.has(id):
		return REASON_UNKNOWN
	var c: Dictionary = _carcasses[id]
	if (c["entries"] as Array).is_empty():
		return REASON_EMPTY
	if _carried.has(player_id):
		return REASON_CARRYING
	if str(c["carrier"]) != "" and str(c["carrier"]) != player_id:
		return REASON_TAKEN
	if player_pos.distance_to(c["position"]) > CarcassRules.rule_f("harvestRangeMetres", 3.0):
		return REASON_RANGE
	if workable_entries(id, category).is_empty():
		return REASON_NO_TOOL
	return OK

## The remaining entries a tool of `category` can work.
func workable_entries(id: String, category: String) -> Array:
	var out: Array = []
	if not _carcasses.has(id):
		return out
	for e in _carcasses[id]["entries"]:
		if CarcassRules.entry_workable(e, category):
			out.append(e)
	return out

## Work every entry `category` can reach: roll yield and grade from the (effective) level, remove those
## entries, and drop the body when nothing is left. Returns `[{ item, quantity, quality }]` (only entries
## that rolled above zero) — the worked entries are gone either way.
func resolve_harvest(id: String, category: String, efficiency: float, level: int, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	if not _carcasses.has(id):
		return out
	var c: Dictionary = _carcasses[id]
	var eff := CarcassRules.effective_level(level, efficiency)
	var left: Array = []
	for e in c["entries"]:
		if not CarcassRules.entry_workable(e, category):
			left.append(e)
			continue
		var qty := CarcassRules.quantity(e, eff, rng.randf())
		if qty > 0:
			out.append({ "item": str(e["item"]), "quantity": qty, "quality": CarcassRules.quality(eff) })
	c["entries"] = left
	if left.is_empty():
		remove(id)
	else:
		_refresh(id)
	return out

# ---------------------------------------------------------------------------
# Host: carry
# ---------------------------------------------------------------------------

func carried_by(player_id: String) -> String:
	return str(_carried.get(player_id, ""))

## "" when `player_id` takes the body (carry or drag), else the reason. Sets the carrier on success.
func carry(id: String, player_id: String, player_pos: Vector3, level: int) -> String:
	if not _carcasses.has(id):
		return REASON_UNKNOWN
	var c: Dictionary = _carcasses[id]
	if _carried.has(player_id):
		return REASON_CARRYING
	if str(c["carrier"]) != "":
		return REASON_TAKEN
	if player_pos.distance_to(c["position"]) > CarcassRules.rule_f("harvestRangeMetres", 3.0):
		return REASON_RANGE
	var mode := CarcassRules.carry_mode(CarcassRules.carry_rule(str(c["creature"])), float(c["mass"]), CarcassRules.capacity_kg(level))
	if mode == "none":
		return REASON_TOO_HEAVY
	c["carrier"] = player_id
	c["mode"] = mode
	_carried[player_id] = id
	_refresh(id)
	return OK

## Put the carried body down at `position`. Returns its id ("" when nothing was carried).
func drop(player_id: String, position: Vector3) -> String:
	var id := carried_by(player_id)
	if id == "":
		return ""
	var c: Dictionary = _carcasses[id]
	c["carrier"] = ""
	c["mode"] = ""
	c["position"] = position
	_carried.erase(player_id)
	_refresh(id)
	return id

## Walk speed multiplier for a player: 1.0 unless they hold a body.
func speed_multiplier(player_id: String, level: int) -> float:
	var id := carried_by(player_id)
	if id == "":
		return 1.0
	var c: Dictionary = _carcasses[id]
	return CarcassRules.speed_multiplier(str(c["mode"]), float(c["mass"]), CarcassRules.capacity_kg(level))

## The carried body follows its carrier (the host's own position knowledge).
func follow(player_id: String, position: Vector3) -> void:
	var id := carried_by(player_id)
	if id != "":
		_carcasses[id]["position"] = position
		_refresh(id, false)

## The nearest body to `position` within `radius` ("" when none).
func nearest(position: Vector3, radius: float) -> String:
	var best := ""
	var best_d := radius
	for id in _carcasses:
		if str(_carcasses[id]["carrier"]) != "":
			continue
		var d: float = position.distance_to(_carcasses[id]["position"])
		if d <= best_d:
			best_d = d
			best = id
	return best

# ---------------------------------------------------------------------------
# Persistence (the world record) and the client view
# ---------------------------------------------------------------------------

func to_data() -> Dictionary:
	var list: Array = []
	for id in _carcasses:
		var c: Dictionary = _carcasses[id]
		var p: Vector3 = c["position"]
		list.append({ "id": id, "creature": c["creature"], "pos": [p.x, p.y, p.z], "entries": c["entries"],
			"killer": c["killer"], "remaining": c["remaining"], "mass": c["mass"] })
	return { "next_id": _next_id, "carcasses": list }

## Restore saved bodies. A carried body comes back on the ground; an unknown creature or a body past its
## time is dropped. Hostile input is bounded: only known creatures, finite numbers, entries from the fabric.
func from_data(data: Variant) -> void:
	clear()
	if not (data is Dictionary):
		return
	_next_id = maxi(0, int(data.get("next_id", 0)))
	var list: Variant = data.get("carcasses", [])
	if not (list is Array):
		return
	for rec in list:
		if not (rec is Dictionary) or not GameData.CREATURES.has(str(rec.get("creature", ""))):
			continue
		var p: Variant = rec.get("pos", [])
		var remaining := float(rec.get("remaining", 0.0))
		if not (p is Array) or (p as Array).size() != 3 or not is_finite(remaining) or remaining <= 0.0:
			continue
		var coords_ok := true
		for n in p:
			if not (n is float or n is int) or not is_finite(float(n)) or absf(float(n)) > 1.0e7:
				coords_ok = false
		if not coords_ok:
			continue
		var id := str(rec.get("id", ""))
		if id == "" or _carcasses.has(id):
			continue
		var creature := str(rec["creature"])
		var allowed := CarcassRules.entries_for(creature)
		var kept: Array = []
		for e in (rec.get("entries", []) if rec.get("entries", []) is Array else []):
			if e is Dictionary:
				for a in allowed:
					if str(a["item"]) == str(e.get("item", "")):
						kept.append(a)
						break
		if kept.is_empty():
			continue
		_carcasses[id] = { "id": id, "creature": creature, "position": Vector3(float(p[0]), float(p[1]), float(p[2])),
			"entries": kept, "killer": str(rec.get("killer", "")), "remaining": minf(remaining, CarcassRules.corpse_seconds(creature)),
			"carrier": "", "mode": "", "mass": CarcassRules.mass_of(creature) }
		_refresh(id, false)
		# Never hand out an id a restored body already holds.
		if id.begins_with("carcass_") and id.substr(8).is_valid_int():
			_next_id = maxi(_next_id, id.substr(8).to_int() + 1)

func clear() -> void:
	for id in _nodes.keys():
		_free_node(id)
	_carcasses.clear()
	_carried.clear()

## Client: adopt the host's record for a body.
func apply_view(rec: Dictionary) -> void:
	var id := str(rec.get("id", ""))
	if id == "":
		return
	var pos: Variant = rec.get("position", null)
	if not (pos is Vector3):
		return
	_carcasses[id] = { "id": id, "creature": str(rec.get("creature", "")), "position": pos,
		"entries": rec.get("entries", []), "killer": "", "remaining": float(rec.get("remaining", 0.0)),
		"carrier": str(rec.get("carrier", "")), "mode": str(rec.get("mode", "")), "mass": float(rec.get("mass", 0.0)) }
	_place(id)

func remove_view(id: String) -> void:
	if _carcasses.erase(id):
		_free_node(id)

# ---------------------------------------------------------------------------
# Visuals (a placeholder body; the prompt text is the UI's)
# ---------------------------------------------------------------------------

func _refresh(id: String, announce: bool = true) -> void:
	_place(id)
	if announce:
		GameBus.carcass_changed.emit(id)

func _place(id: String) -> void:
	if not render_visuals or not _carcasses.has(id) or not is_inside_tree():
		return
	var node: Node3D = _nodes.get(id, null)
	if node == null:
		node = MeshInstance3D.new()
		var box := BoxMesh.new()
		var m := clampf(CarcassRules.mass_of(str(_carcasses[id]["creature"])) / 100.0, 0.3, 1.5)
		box.size = Vector3(0.9, 0.35, 0.5) * (0.6 + m)
		(node as MeshInstance3D).mesh = box
		node.name = "Carcass_%s" % id
		add_child(node)
		_nodes[id] = node
	node.position = _origin.to_scene(_carcasses[id]["position"] as Vector3) + Vector3(0.0, 0.2, 0.0)

## Rebase (Phase 63): shift every body node by `shift`; the records keep their world positions.
func shift_scene(shift: Vector3) -> void:
	_origin.add(shift)
	for id in _nodes:
		(_nodes[id] as Node3D).position += shift

func _free_node(id: String) -> void:
	var node: Node = _nodes.get(id, null)
	_nodes.erase(id)
	if node != null:
		node.free()
