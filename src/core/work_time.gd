extends RefCounted
## Phase 259 — work takes time: the pure half. How long gathering a material takes with a held tool, read from the
## fabric's `WorkTimes` world system (`GameData.WORLD_SYSTEMS["WorkTimes"]`). The host computes every duration
## here from its own state (material, action, held tool), never from a client message.
##
## seconds = workSeconds[material] / speed, where speed is the held tool's `toolSpeeds[tool][class]` when the
## tool's class is the one the action wants, else the bare-hands speed (a wrong-class tool counts as bare hands).

const WorkSkills := preload("res://src/character/work_skills.gd")

const ACTIONS := ["dig", "mine", "chop"]

static func _res() -> Resource:
	return GameData.WORLD_SYSTEMS.get("WorkTimes", null)

static func _dict(key: String) -> Dictionary:
	var res := _res()
	var v: Variant = res.get(key) if res != null else null
	return v if v is Dictionary else {}

## Speed multiplier of bare hands (0 when the table is absent).
static func bare_hands_speed() -> float:
	var res := _res()
	return float(res.get("bareHandsSpeed")) if res != null else 0.0

## The action that works a material's gather family ("" for a material no action works).
static func action_for_material(material: String) -> String:
	var family := WorkSkills.family_of(material)
	var actions := _dict("actions")
	for action in actions:
		if (actions[action].get("families", []) as Array).has(family):
			return str(action)
	return ""

## The tool class an action wants ("" for an unknown action).
static func tool_class(action: String) -> String:
	return str((_dict("actions").get(action, {}) as Dictionary).get("toolClass", ""))

## Speed of `tool_item` ("" = bare hands) at `action`: its speed for the action's class, else bare hands.
static func speed(action: String, tool_item: String) -> float:
	var cls := tool_class(action)
	if tool_item != "" and cls != "":
		var row: Dictionary = _dict("toolSpeeds").get(tool_item, {})
		if row.has(cls):
			return float(row[cls])
	return bare_hands_speed()

## Seconds to work `material` with `action` holding `tool_item` ("" = bare hands); 0.0 for an unknown material.
static func seconds(material: String, action: String, tool_item: String = "") -> float:
	var base := float(_dict("workSeconds").get(material, 0.0))
	var s := speed(action, tool_item)
	if base <= 0.0 or s <= 0.0:
		return 0.0
	return base / s

## What a work time falls back to for a material the table does not name (a made block, say): this many seconds at speed 1.
const FALLBACK_SECONDS := 2.0

## The duration the host uses: `seconds`, or the fallback over the speed for an unlisted material.
static func duration(material: String, action: String, tool_item: String = "") -> float:
	var t := seconds(material, action, tool_item)
	if t > 0.0:
		return t
	var s := speed(action, tool_item)
	return FALLBACK_SECONDS / s if s > 0.0 else 0.0

## The tool the player holds for `action`'s class ("" = bare hands): the inventory's first usable tool of it.
static func held_tool(inventory: Node, action: String) -> String:
	var cls := tool_class(action)
	if inventory == null or cls == "" or not inventory.has_method("find_tool"):
		return ""
	return str(inventory.find_tool(cls))
