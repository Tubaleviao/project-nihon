extends RefCounted
## Which body the pointer is over. A body's harvest prompt shows only while the pointer is on it (and the
## player is within harvest range), not whenever a body happens to be near.

const CarcassRules := preload("res://src/loot/carcass_rules.gd")

## The pointer ray must pass within this many metres of a point this high above the body's ground position.
const RADIUS_M := 0.9
const LIFT_M := 0.4

## The id of the candidate (`{ id, point }`, scene positions) whose point lies nearest the ray `from` + t·`dir`
## (t > 0), within `radius` metres of it; "" when none does.
static func under_ray(from: Vector3, dir: Vector3, candidates: Array, radius: float = RADIUS_M) -> String:
	var best := ""
	var best_d := radius
	var d := dir.normalized()
	for c in candidates:
		var rel: Vector3 = (c["point"] as Vector3) - from
		var t := rel.dot(d)
		if t <= 0.0:
			continue
		var miss := (rel - d * t).length()
		if miss <= best_d:
			best_d = miss
			best = str(c["id"])
	return best

## The uncarried body of `carcasses` within harvest range of `here` (world) under the pointer ray `from`/`dir`
## (scene); `origin` is the scene offset (scene = world + origin). "" when none.
static func hovered(carcasses: Node, here: Vector3, origin: Vector3, from: Vector3, dir: Vector3) -> String:
	var reach := CarcassRules.rule_f("harvestRangeMetres", 3.0)
	var candidates: Array = []
	for id in carcasses.ids():
		var c: Dictionary = carcasses.get_carcass(str(id))
		if c.is_empty() or str(c.get("carrier", "")) != "":
			continue
		var pos: Vector3 = c["position"]
		if here.distance_to(pos) <= reach:
			candidates.append({ "id": str(id), "point": pos + origin + Vector3.UP * LIFT_M })
	return under_ray(from, dir, candidates) if not candidates.is_empty() else ""

## `hovered` for the pointer of `camera`'s viewport ("" without bodies or a camera).
static func at_pointer(carcasses: Node, here: Vector3, origin: Vector3, camera: Camera3D) -> String:
	if carcasses == null or camera == null or camera.get_viewport() == null:
		return ""
	var m := camera.get_viewport().get_mouse_position()
	return hovered(carcasses, here, origin, camera.project_ray_origin(m), camera.project_ray_normal(m))
