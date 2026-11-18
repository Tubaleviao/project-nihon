extends RefCounted
## Phase 271 — the skill wheel's layout as a pure function of the fabric's `SkillWheel` table.
##
## Professions sit on the rim (radius 1) evenly spaced, in the fabric's order, starting at the top. A node's
## angle is the affinity-weighted mean of its professions' angles (the direction of the weighted vector sum), and
## its radius grows with its depth, so an advanced node of one profession sits beside that profession on the rim
## while a skill shared by two sits between them, nearer the centre. A node with no affinity sits inside the
## centre disc. Skills sharing one direction are staggered radially (`SLOT_STEP`) so they do not overlap; the
## stagger is smaller than a tier's step, so a deeper tier of a skill still lies farther out. Same table in,
## same layout out.

## Radius of the centre disc and of the ring the deepest nodes reach, in grid units (the rim is 1).
const CENTRE_RADIUS := 0.22
const NODE_REACH := 0.94
## Share of the span (centre disc edge to NODE_REACH) a tier's depth uses, and one slot's radial stagger.
const DEPTH_SHARE := 0.65
const SLOT_STEP := 0.03
const SLOTS := 4

static var _fabric_cache: Dictionary = {}

## `professions`: ordered ids. `nodes`: { node_id: { skill, depth, affinity: {profession: weight}, requires: [ids] } }.
## Returns { profession_position: {id: Vector2}, profession_angle: {id: float}, position: {node_id: Vector2},
##   edges: [[from, to]] (sorted), centre_radius: float }.
static func layout(professions: Array, nodes: Dictionary) -> Dictionary:
	var angle: Dictionary = {}
	var ppos: Dictionary = {}
	for i in professions.size():
		var a := -PI / 2.0 + TAU * float(i) / float(professions.size())
		angle[str(professions[i])] = a
		ppos[str(professions[i])] = Vector2.from_angle(a)
	var ids: Array = nodes.keys().map(func(k): return str(k))
	ids.sort()
	# Slots: the skills that share one direction, in id order.
	var group_skills: Dictionary = {}
	var centre_ids: Array = []
	for id: String in ids:
		var n: Dictionary = nodes[id]
		var key := _direction_key(n.get("affinity", {}))
		if key == "":
			centre_ids.append(id)
			continue
		var skills: Array = group_skills.get(key, [])
		if not skills.has(str(n["skill"])):
			skills.append(str(n["skill"]))
			skills.sort()
		group_skills[key] = skills
	var pos: Dictionary = {}
	for id: String in ids:
		var n: Dictionary = nodes[id]
		var aff: Dictionary = n.get("affinity", {})
		var key := _direction_key(aff)
		if key == "":
			continue
		var v := Vector2.ZERO
		for p in aff:
			if angle.has(str(p)):
				v += Vector2.from_angle(float(angle[str(p)])) * float(aff[p])
		if v.length() < 0.0001:
			v = ppos.get(_heaviest(aff), Vector2.RIGHT)
		var slot: int = (group_skills[key] as Array).find(str(n["skill"])) % SLOTS
		var span := NODE_REACH - CENTRE_RADIUS
		var radius := CENTRE_RADIUS + span * (float(n["depth"]) * DEPTH_SHARE) + SLOT_STEP * float(slot) + 0.05
		pos[id] = v.normalized() * radius
	# No affinity: a deterministic sunflower spread inside the centre disc.
	for i in centre_ids.size():
		var r := CENTRE_RADIUS * 0.85 * sqrt((float(i) + 0.5) / float(centre_ids.size()))
		pos[centre_ids[i]] = Vector2.from_angle(float(i) * 2.399963) * r
	var edges: Array = []
	for id: String in ids:
		for r in nodes[id].get("requires", []):
			if nodes.has(str(r)):
				edges.append([str(r), id])
	edges.sort()
	return {"profession_position": ppos, "profession_angle": angle, "position": pos, "edges": edges, "centre_radius": CENTRE_RADIUS}

## "" when the affinity names nothing; else a stable key of its professions and weights.
static func _direction_key(aff: Dictionary) -> String:
	var parts: Array = []
	for p in aff:
		parts.append("%s=%.3f" % [p, float(aff[p])])
	parts.sort()
	return ",".join(parts)

static func _heaviest(aff: Dictionary) -> String:
	var best := ""
	for p in aff:
		if best == "" or float(aff[p]) > float(aff[best]):
			best = str(p)
	return best

## The layout of the shipped fabric table, cached.
static func for_fabric() -> Dictionary:
	if _fabric_cache.is_empty():
		var res: Resource = GameData.WORLD_SYSTEMS.get("SkillWheel", null)
		if res == null:
			return {}
		_fabric_cache = layout(res.get("professions"), res.get("nodes"))
	return _fabric_cache

static func fabric_nodes() -> Dictionary:
	var res: Resource = GameData.WORLD_SYSTEMS.get("SkillWheel", null)
	return res.get("nodes") if res != null else {}

static func fabric_professions() -> Array:
	var res: Resource = GameData.WORLD_SYSTEMS.get("SkillWheel", null)
	return res.get("professions") if res != null else []
