extends RefCounted
## Settlement project rules (Phase 198, designed in Phase 197) — the pure half of settlement projects:
## what a project still needs, whether a contribution is valid, the completion check and the cells a finished
## structure fills (Phase 205 removed project effects). The settlement slice owns the state and
## calls these with plain data. Rules come from the fabric's `SettlementProjects` world system
## (`GameData.WORLD_SYSTEMS["SettlementProjects"].rules`).
##
## A project's state (inside a settlement's `projects`, keyed by project key):
##   { key, by, started, site {x, z}, given {item: n}, work (units), status "building" | "done",
##     done_at, contributors {pid: {items: n, work: units}} }

const TIER_ORDER := ["founded", "growing", "town"]
## Projects a settlement may have under construction at once.
const MAX_BUILDING := 3
## Contributor entries per project (a village has at most 64 members).
const MAX_CONTRIBUTORS := 64

## Phase 203 — the fabric dropped project labour and effects (a project is complete once its materials are
## in); the runtime keeps the labour here until Phase 207 removes the labour stage (Phase 205 removed the effects).
const LABOUR_HOLD := {
	"workSecondsPerUnit": 2,
	"projects": {
		"palisade": {
			"labour": [{ "step": "posts", "specialty": "woodworker", "work": 60 }, { "step": "raise", "specialty": "builder", "work": 90 }],
		},
		"storehouse": {
			"labour": [{ "step": "foundation", "specialty": "builder", "work": 60 }, { "step": "shelving", "specialty": "woodworker", "work": 60 },
				{ "step": "provisions", "specialty": "forager", "work": 30 }],
		},
		"workshop": {
			"labour": [{ "step": "walls", "specialty": "builder", "work": 60 }, { "step": "benches", "specialty": "woodworker", "work": 45 },
				{ "step": "anvil", "specialty": "smith", "work": 45 }],
		},
		"watchtower": {
			"labour": [{ "step": "base", "specialty": "builder", "work": 90 }, { "step": "lookout", "specialty": "woodworker", "work": 60 },
				{ "step": "signal", "specialty": "hunter", "work": 30 }],
		},
	},
}
static var _held: Dictionary = {}
static var _held_source: Resource = null

## The project table: `{ workSecondsPerUnit, projects {key: def} }` (empty projects when the fabric has none),
## with LABOUR_HOLD filling in what the fabric no longer has.
static func table() -> Dictionary:
	var res: Resource = GameData.WORLD_SYSTEMS.get("SettlementProjects", null)
	var r: Variant = res.get("rules") if res != null else null
	if r is Dictionary and (r as Dictionary).get("projects", null) is Dictionary:
		if _held.is_empty() or res != _held_source:
			_held = _with_hold(r)
			_held_source = res
		return _held
	return { "workSecondsPerUnit": 2, "projects": {} }

static func _with_hold(r: Dictionary) -> Dictionary:
	var out: Dictionary = r.duplicate(true)
	if not out.has("workSecondsPerUnit"):
		out["workSecondsPerUnit"] = LABOUR_HOLD["workSecondsPerUnit"]
	for key: String in out["projects"]:
		var hold: Dictionary = LABOUR_HOLD["projects"].get(key, {})
		for f: String in hold:
			if not (out["projects"][key] as Dictionary).has(f):
				out["projects"][key][f] = (hold[f] as Array).duplicate(true)
	return out

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

## Work units the whole project takes (every labour step).
static func total_work(def: Dictionary) -> float:
	var n := 0.0
	for s: Dictionary in def.get("labour", []):
		n += float(s["work"])
	return n

## The labour step `work` units fall in: `{ index, step, specialty, done, work }` (`done` units of this
## step's `work`), or index -1 once every step is done.
static func current_step(def: Dictionary, work: float) -> Dictionary:
	var acc := 0.0
	var steps: Array = def.get("labour", [])
	for i in steps.size():
		var w := float(steps[i]["work"])
		if work < acc + w:
			return { "index": i, "step": str(steps[i]["step"]), "specialty": str(steps[i].get("specialty", "")), "done": work - acc, "work": w }
		acc += w
	return { "index": -1, "step": "", "specialty": "", "done": 0.0, "work": 0.0 }

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

## Whether every material is in and every labour step is worked.
static func is_complete(def: Dictionary, state: Dictionary) -> bool:
	return not def.is_empty() and remaining_materials(def, state.get("given", {})).is_empty() \
		and float(state.get("work", 0.0)) >= total_work(def) - 0.0001

static func building_count(projects: Dictionary) -> int:
	var n := 0
	for k: String in projects:
		if str(projects[k].get("status", "")) != "done":
			n += 1
	return n

static func completed_count(projects: Dictionary) -> int:
	return projects.size() - building_count(projects)

## Work units `seconds` of labour earn (before any specialty bonus).
static func work_units(seconds: float, tbl: Dictionary = {}) -> float:
	var t: Dictionary = tbl if not tbl.is_empty() else table()
	return maxf(0.0, seconds) / maxf(0.001, float(t.get("workSecondsPerUnit", 2)))

## The cells a finished structure fills, as offsets `(dx, dy, dz)` from its site (dy above the ground),
## exactly `blocks` of them: courses of the layout's outline stacked upward, with a doorway left open in
## the two lowest courses of everything but the tower.
static func layout_cells(layout: String, blocks: int) -> Array:
	var half := Vector2i(4, 4)
	match layout:
		"tower": half = Vector2i(1, 1)
		"hall": half = Vector2i(3, 2)
		"shed": half = Vector2i(2, 2)
	var course: Array = []
	for x in range(-half.x, half.x + 1):
		for z in range(-half.y, half.y + 1):
			if absi(x) == half.x or absi(z) == half.y:
				course.append(Vector2i(x, z))
	var out: Array = []
	var y := 0
	while out.size() < blocks and y < 64:
		for c: Vector2i in course:
			if out.size() >= blocks:
				break
			if layout != "tower" and y < 2 and c == Vector2i(0, -half.y):
				continue   # the doorway
			out.append(Vector3i(c.x, y, c.y))
		y += 1
	return out

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

## Whether `item` is a tool (it has a `toolType`): what labour needs in hand.
static func is_tool_item(item: String) -> bool:
	var res: Resource = GameData.ITEMS.get(item, null)
	return res != null and str(res.get("toolType") if "toolType" in res else "") != ""

## Where the structure's stations stand, as ground offsets from its site: side by side inside the outline.
static func station_offsets(count: int) -> Array:
	var out: Array = []
	for i in count:
		out.append(Vector2i(i * 2 - (count - 1), 0))
	return out
