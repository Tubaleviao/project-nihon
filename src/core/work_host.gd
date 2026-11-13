extends RefCounted
## Phase 259 — the host's side of timed work. Resolves a work target (a tree, or the span a mine would remove),
## computes the duration itself from the worker's own held tool (`WorkTime`), records it in a `WorkSession`, and
## answers a completion claim. Nothing here is read from a client: the client names only a target.

const WorkTime := preload("res://src/core/work_time.gd")
const WorkSession := preload("res://src/core/work_session.gd")

var sessions := WorkSession.new()
var tree_slice: Node = null
var voxel_slice: Node = null

## Tree key for a completion claim.
static func tree_key(tree_id: String) -> String:
	return "tree:" + tree_id

## Starts work. `kind` is "tree" (target `tree_id`) or "block" (position/normal/exact). Returns
## `{ ok, key, duration, action, material }`; `ok` is false for a target that cannot be worked.
func start(player_id: String, kind: String, tree_id: String, pos: Vector3, normal: Vector3, exact: Dictionary, now: float) -> Dictionary:
	var t := resolve(player_id, kind, tree_id, pos, normal, exact)
	if t.is_empty() or not sessions.start(player_id, str(t["key"]), str(t["action"]), float(t["duration"]), now):
		return { "ok": false }
	t["ok"] = true
	return t

## The target a start or a claim names: `{ key, action, material, duration }` or `{}`.
func resolve(player_id: String, kind: String, tree_id: String, pos: Vector3, normal: Vector3, exact: Dictionary) -> Dictionary:
	var material := ""
	var key := ""
	var action := ""
	var inventory: Node = null
	if kind == "tree":
		if tree_slice == null:
			return {}
		var rec: Dictionary = tree_slice.get_tree_record(tree_id)
		if rec.is_empty() or str(rec.get("state", "")) != "standing":
			return {}
		material = str(rec["wood"])
		key = tree_key(tree_id)
		action = "chop"
		inventory = tree_slice.inventory_for(player_id)
	elif kind == "block":
		if voxel_slice == null:
			return {}
		var tgt: Dictionary = voxel_slice._edit.work_target(pos, normal, exact)
		if tgt.is_empty():
			return {}
		material = str(tgt["material"])
		key = str(tgt["key"])
		action = WorkTime.action_for_material(material)
		if action == "":
			action = "mine"
		inventory = voxel_slice.inventory_for(player_id)
	else:
		return {}
	var tool := WorkTime.held_tool(inventory, action)
	return { "key": key, "action": action, "material": material, "duration": WorkTime.duration(material, action, tool) }

## A completion claim for `key`: true once the host's own timer has run out with the work still held and in reach.
## `in_reach` is the caller's own check; a claim is "held" while its session exists (a release cancels it).
func claim(player_id: String, key: String, now: float, in_reach: bool = true) -> bool:
	return sessions.try_complete(player_id, key, now, true, in_reach)

func cancel(player_id: String) -> bool:
	return sessions.cancel(player_id)
