extends RefCounted
## Which body the pointer is over. A body's harvest prompt shows, and the harvest/carry key acts, only while
## the pointer is on it (and the player is within harvest range), not whenever a body happens to be near.

const CarcassRules := preload("res://src/loot/carcass_rules.gd")
const I18n := preload("res://src/core/i18n.gd")

## The smallest pick radius (metres) around a body's centre; heavier bodies get a larger one (`radius_for`).
const RADIUS_M := 0.9
## Pick radius per cube root of carcass mass (kg): 900 kg -> about 2.9 m, 100 kg -> about 1.4 m.
const RADIUS_PER_CBRT_KG := 0.3
## The centre sits this fraction of the radius above the body's ground position.
const LIFT_FRACTION := 0.45

## The pick radius of a body of `mass_kg`.
static func radius_for(mass_kg: float) -> float:
	return maxf(RADIUS_M, RADIUS_PER_CBRT_KG * pow(maxf(mass_kg, 0.0), 1.0 / 3.0))

## The id of the candidate (`{ id, point, radius? }`, scene positions) the ray `from` + t·`dir` (t > 0) passes
## closest to, relative to its radius (`radius` when a candidate has none); "" when the ray misses all of them.
## A candidate whose nearest approach lies beyond `max_t` (the first terrain hit) is behind it and is skipped.
static func under_ray(from: Vector3, dir: Vector3, candidates: Array, radius: float = RADIUS_M, max_t: float = INF) -> String:
	var best := ""
	var best_score := 1.0
	var d := dir.normalized()
	for c in candidates:
		var r := float(c.get("radius", radius))
		var rel: Vector3 = (c["point"] as Vector3) - from
		var t := rel.dot(d)
		# The ray's terrain hit may land just past the body's centre (the ground under or behind it): allow one radius.
		if t <= 0.0 or t > max_t + r:
			continue
		var score := (rel - d * t).length() / r
		if score <= best_score:
			best_score = score
			best = str(c["id"])
	return best

## The uncarried bodies of `carcasses` within harvest range of `here` (world) as `under_ray` candidates
## (scene = world + `origin`). Reads positions in place: no record is copied.
static func candidates(carcasses: Node, here: Vector3, origin: Vector3) -> Array:
	var out: Array = []
	if carcasses == null:
		return out
	var reach := CarcassRules.rule_f("harvestRangeMetres", 3.0)
	for id in carcasses.ids():
		var sid := str(id)
		if carcasses.carrier_of(sid) != "":
			continue
		var pos: Vector3 = carcasses.position_of(sid)
		if here.distance_to(pos) > reach:
			continue
		var r := radius_for(carcasses.body_mass(sid))
		out.append({ "id": sid, "point": pos + origin + Vector3.UP * (r * LIFT_FRACTION), "radius": r })
	return out

## The uncarried body in harvest range of `here` (world) under the pointer ray `from`/`dir` (scene), not behind
## terrain nearer than `max_t`; "" when none.
static func hovered(carcasses: Node, here: Vector3, origin: Vector3, from: Vector3, dir: Vector3, max_t: float = INF) -> String:
	var list := candidates(carcasses, here, origin)
	return under_ray(from, dir, list, RADIUS_M, max_t) if not list.is_empty() else ""

## `id` while that body still exists and nobody carries it ("" otherwise).
static func live(carcasses: Node, id: String) -> String:
	if carcasses == null or id == "" or not carcasses.has_carcass(id) or carcasses.carrier_of(id) != "":
		return ""
	return id

## The harvest prompt for body `cid` given the tools in `inventory`, through I18n; "" when `cid` is "".
static func prompt(carcasses: Node, cid: String, inventory: Node) -> String:
	if cid == "":
		return ""
	var held: Array = []
	if inventory != null:
		# A fully worn tool does not count: the host refuses it too.
		var worn: Dictionary = inventory.get_durability_data()
		for item in inventory.get_contents():
			var t := CarcassRules.tool_of(str(item))
			if not t.is_empty() and has_usable_copy(worn, str(item)):
				held.append(t["tool"])
	var p: Array = CarcassRules.prompt_for(carcasses.view_of(cid)["entries"], held, false)
	var args: Array = []
	for a in p[1]:
		args.append(I18n.t(a) if str(a).begins_with("tool.") else a)
	return I18n.t(p[0], args)

## True unless `item` is durable and every copy is at 0 durability.
static func has_usable_copy(durability: Dictionary, item: String) -> bool:
	if not durability.has(item):
		return true
	for v in durability[item]:
		if float(v) > 0.0:
			return true
	return false
