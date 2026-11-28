extends RefCounted
## Phase 259 — the host's side of timed work. Resolves a work target (a tree, or the span a mine would remove),
## computes the duration itself from the worker's own held tool (`WorkTime`), records it in a `WorkSession`, and
## answers a completion claim. Nothing here is read from a client: the client names only a target.

const WorkTime := preload("res://src/core/work_time.gd")
const WorkSession := preload("res://src/core/work_session.gd")

var sessions := WorkSession.new()
var tree_slice: Node = null
var voxel_slice: Node = null
## Off only for a test that must probe the wire with bare intents; production always enforces.
var enforce := true

## Tree key for a completion claim.
static func tree_key(tree_id: String) -> String:
	return "tree:" + tree_id

## Starts work. `kind` is "tree" (target `tree_id`) or "block" (position/normal/exact). Returns
## `{ ok, key, duration, action, material }`; `ok` is false for a target that cannot be worked.
## #629 — a session that begins on a new target announces its work mark (`GameBus.work_mark_changed`), and the
## session it replaced (a retarget) announces its stop; a repeated start on the same target announces nothing.
func start(player_id: String, kind: String, tree_id: String, pos: Vector3, normal: Vector3, exact: Dictionary, now: float) -> Dictionary:
	var t := resolve(player_id, kind, tree_id, pos, normal, exact)
	var before := str(sessions.session(player_id).get("target", ""))
	if t.is_empty() or not sessions.start(player_id, str(t["key"]), str(t["action"]), float(t["duration"]), now, str(t.get("plan", ""))):
		return { "ok": false }
	if before != str(t["key"]):
		if before != "":
			GameBus.work_mark_changed.emit(player_id, before, 0.0)
		GameBus.work_mark_changed.emit(player_id, str(t["key"]), float(t["duration"]))
	t["ok"] = true
	return t

## The target a start or a claim names: `{ key, action, material, duration }` or `{}`.
func resolve(player_id: String, kind: String, tree_id: String, pos: Vector3, normal: Vector3, exact: Dictionary) -> Dictionary:
	var material := ""
	var key := ""
	var plan := ""
	var action := ""
	var skill_action := ""
	var inventory: Node = null
	var registry: Object = null
	if kind == "tree":
		if tree_slice == null:
			return {}
		var rec: Dictionary = tree_slice.get_tree_record(tree_id)
		if rec.is_empty() or str(rec.get("state", "")) != "standing":
			return {}
		material = str(rec["wood"])
		key = tree_key(tree_id)
		action = "chop"
		skill_action = action
		inventory = tree_slice.inventory_for(player_id)
		registry = tree_slice.player_registry
	elif kind == "block":
		if voxel_slice == null:
			return {}
		var tgt: Dictionary = voxel_slice.work_target(pos, normal, exact)
		if tgt.is_empty():
			return {}
		material = str(tgt["material"])
		key = str(tgt["key"])
		action = WorkTime.action_for_material(material)
		if action == "":
			action = "mine"
		skill_action = action
		inventory = voxel_slice.inventory_for(player_id)
		registry = voxel_slice.player_registry
		# `mine_block` spends the held pick on any block and the axe only when no pick is held, so a wood block
		# is timed with the pick when one is held.
		if action == "chop" and WorkTime.held_tool(inventory, "mine") != "":
			action = "mine"
	else:
		return {}
	var tool := WorkTime.held_tool(inventory, action)
	# Phase 274 — the worker's tier shortens the work, from the host's own record. The tier is read in the skill
	# the material's work grows (Woodcutting for wood, Mining for stone, ore and soil), not the held tool's, so the
	# skill that speeds a job is the one that grows from it: a wood block mined with a pick takes the pick's speed
	# and the Woodcutting tier.
	var tier := WorkTime.worker_tier(registry, player_id, skill_action)
	var duration := WorkTime.duration(material, action, tool, tier, skill_action)
	if kind == "block":
		# Phase 300 — a brush dig takes the time of the volume it removes (never less than one slab), the host's
		# own plan from its own tool and tier; the key stays the aimed slab's, so marks are unchanged. The plan's own
		# key (centre and radius) binds the claim to the brush that was timed: a completion aimed with another normal
		# or holding another tool plans another op and is refused.
		var brush: Dictionary = voxel_slice._edit._dig.work_target(pos, normal, player_id, exact) if voxel_slice._edit.brush_enabled else {}
		if not brush.is_empty():
			duration = maxf(duration, float(brush["seconds"]))
			plan = str(brush["key"]) + "|" + str(voxel_slice._edit._dig.plan(pos, normal, player_id, exact).get("tool", ""))
	return { "key": key, "action": action, "material": material, "duration": duration, "plan": plan }

## A completion claim for `key`: true once the host's own timer has run out with the work still held and in reach.
## `in_reach` is the caller's own check; a claim is "held" while its session exists (a release cancels it).
## #629 — a claim that ends the session (completed, or out of reach) announces the mark's stop.
## Phase 300 — `plan` is the claim's own resolved plan (`resolve(...)["plan"]`); it must equal the session's.
func claim(player_id: String, key: String, now: float, in_reach: bool = true, plan: String = "") -> bool:
	var target := str(sessions.session(player_id).get("target", ""))
	var done := sessions.try_complete(player_id, key, now, true, in_reach, plan)
	if target != "" and not sessions.has_session(player_id):
		GameBus.work_mark_changed.emit(player_id, target, 0.0)
	return done

func cancel(player_id: String) -> bool:
	var target := str(sessions.session(player_id).get("target", ""))
	if not sessions.cancel(player_id):
		return false
	GameBus.work_mark_changed.emit(player_id, target, 0.0)   # #629
	return true
