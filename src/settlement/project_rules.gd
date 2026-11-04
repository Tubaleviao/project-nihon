extends RefCounted
## Settlement project rules (Phase 198, designed in Phase 197) — the pure half of settlement projects:
## what a project still needs, whether a contribution is valid, the completion check and the cells a finished
## structure fills (Phase 205 removed project effects). The settlement slice owns the state and
## calls these with plain data. Rules come from the fabric's `SettlementProjects` world system
## (`GameData.WORLD_SYSTEMS["SettlementProjects"].rules`).
##
## A project's state (inside a settlement's `projects`, keyed by project key):
##   { key, by, started, site {x, z}, given {item: n}, status "building" | "done", done_at,
##     contributors {pid: {items: n}} }

const Limits := preload("res://src/structure/structure_limits.gd")
const VoxelConsts := preload("res://src/terrain/voxel_consts.gd")

const TIER_ORDER := ["founded", "growing", "town"]
## Projects a settlement may have under construction at once.
const MAX_BUILDING := 3
## Contributor entries per project (a village has at most 64 members).
const MAX_CONTRIBUTORS := 64

## The project table: `{ projects {key: def} }` (empty when the fabric has none). Phase 207 removed the labour
## the runtime held after Phase 203: a project is complete once its materials are in.
static func table() -> Dictionary:
	var res: Resource = GameData.WORLD_SYSTEMS.get("SettlementProjects", null)
	var r: Variant = res.get("rules") if res != null else null
	if r is Dictionary and (r as Dictionary).get("projects", null) is Dictionary:
		return r
	return { "projects": {} }

static func def_of(key: String, tbl: Dictionary = {}) -> Dictionary:
	var t: Dictionary = tbl if not tbl.is_empty() else table()
	return (t["projects"] as Dictionary).get(key, {})

## `{ item: quantity }` the project needs in all.
static func needed_materials(def: Dictionary) -> Dictionary:
	var out := {}
	for m: Dictionary in def.get("materials", []):
		out[str(m["item"])] = int(out.get(str(m["item"]), 0)) + int(m["quantity"])
	return out

## `{ item: quantity }` still missing, given `given` ({ item: n } already brought). Items met drop out.
static func remaining_materials(def: Dictionary, given: Dictionary) -> Dictionary:
	var out := {}
	var need := needed_materials(def)
	for item: String in need:
		var left := int(need[item]) - int(given.get(item, 0))
		if left > 0:
			out[item] = left
	return out

## "" when `qty` of `item` may go into the project; else a reason: `unknown_project`, `bad_args`,
## `project_done`, `unknown_item` (not a material this project uses) or `too_much` (more than it still
## needs of that item).
static func contribution_blocker(def: Dictionary, state: Dictionary, item: String, qty: int) -> String:
	if def.is_empty() or state.is_empty():
		return "unknown_project"
	if qty < 1:
		return "bad_args"
	if str(state.get("status", "")) == "done":
		return "project_done"
	if not needed_materials(def).has(item):
		return "unknown_item"
	if qty > int(remaining_materials(def, state.get("given", {})).get(item, 0)):
		return "too_much"
	return ""

## "" when a member of role `role` (rules `role_rules`) who already took `taken_today` units today may
## draw `qty` more from the stockpile; `over_limit` past the role's `withdrawLimit` (the founder has none).
static func stock_draw_blocker(role: String, role_rules: Dictionary, taken_today: int, qty: int) -> String:
	if not bool(role_rules.get("take", false)):
		return "no_permission"
	if role != "founder" and taken_today + qty > int(role_rules.get("withdrawLimit", 0)):
		return "over_limit"
	return ""

## "" when a settlement at tier `tier` with projects `projects` may start `key`; else a reason.
static func start_blocker(key: String, tier: String, projects: Dictionary, tbl: Dictionary = {}) -> String:
	var def := def_of(key, tbl)
	if def.is_empty():
		return "unknown_project"
	if projects.has(key):
		return "project_exists"   # each structure is built once per village
	if TIER_ORDER.find(tier) < TIER_ORDER.find(str(def.get("minTier", "founded"))):
		return "tier_too_low"
	if building_count(projects) >= MAX_BUILDING:
		return "too_many_projects"
	return ""

## Whether every material is in (Phase 207: there is no labour stage).
static func is_complete(def: Dictionary, state: Dictionary) -> bool:
	return not def.is_empty() and remaining_materials(def, state.get("given", {})).is_empty()

static func building_count(projects: Dictionary) -> int:
	var n := 0
	for k: String in projects:
		if str(projects[k].get("status", "")) != "done":
			n += 1
	return n

## Phase 212 — a doorway is this many tiles wide (centred on the front wall) and this many blocks high (2 m).
const DOOR_TILES := 3
const DOOR_COURSES := 16

## Blocks (STEP_HEIGHT courses) per floor: the fabric's `Structure.floorHeight` (3 m = 24 blocks), read where
## the structure limits read it, so a project floor is the floor the limits count.
static func courses_per_floor() -> int:
	return maxi(1, roundi(float(Limits.floor_mm()) / (VoxelConsts.STEP_HEIGHT * 1000.0)))

## The most floors a project may place: what the strongest class carries. The fabric validator holds each
## project to its own block's class, so this only bounds a table the validator never saw.
static func max_floors() -> int:
	return Limits.max_floors(Limits.Rules.CLASSES.size() - 1)

## The cells a finished structure fills, as offsets `(dx, dy, dz)` from its site, dy in blocks above the
## ground of the cell's own column: `floors` floors (Phase 212: a shed is one 3 m floor) of the layout's outline,
## a course per block, with a doorway `DOOR_TILES` wide and `DOOR_COURSES` high left open in the front wall of
## everything but the tower.
static func layout_cells(layout: String, floors: int) -> Array:
	var half := half_of(layout)
	var course: Array = []
	for x in range(-half.x, half.x + 1):
		for z in range(-half.y, half.y + 1):
			if absi(x) == half.x or absi(z) == half.y:
				course.append(Vector2i(x, z))
	var out: Array = []
	for y in clampi(floors, 0, max_floors()) * courses_per_floor():
		for c: Vector2i in course:
			if is_doorway(layout, c, y):
				continue
			out.append(Vector3i(c.x, y, c.y))
	return out

## Whether the cell at outline column `c` and course `y` of `layout` is the doorway (left open).
static func is_doorway(layout: String, c: Vector2i, y: int) -> bool:
	if layout == "tower" or y >= DOOR_COURSES:
		return false
	return c.y == -half_of(layout).y and absi(c.x) <= DOOR_TILES / 2

## The outline's half extents in tiles (x, z); the ring is the default.
static func half_of(layout: String) -> Vector2i:
	match layout:
		"tower": return Vector2i(1, 1)
		"hall": return Vector2i(3, 2)
		"shed": return Vector2i(2, 2)
	return Vector2i(4, 4)

## The voxel material a structure's `places.block` builds with: the key itself when it is a material, else
## the body material of the item (an AshiteBlock builds Ashite). "" when neither.
static func block_material(block: String) -> String:
	if GameData.MATERIALS.has(block):
		return block
	var item: Resource = GameData.ITEMS.get(block, null)
	var shape: Variant = item.get("shape") if item != null else null
	if shape is Dictionary and (shape as Dictionary).get("parts", null) is Dictionary:
		for part: Variant in (shape["parts"] as Dictionary).values():
			if GameData.MATERIALS.has(str(part)):
				return str(part)
	return ""

## Where the structure's stations stand, as ground offsets from its site: side by side inside the outline.
static func station_offsets(count: int) -> Array:
	var out: Array = []
	for i in count:
		out.append(Vector2i(i * 2 - (count - 1), 0))
	return out
