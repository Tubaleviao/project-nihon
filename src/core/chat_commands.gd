extends RefCounted
## Phase 63 — slash commands typed in chat. Pure and static: the UI asks, the answer is a string.

const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")

const WHERE := "/where"

## True when `text` is a command this module answers.
static func is_command(text: String) -> bool:
	return _command_of(text) == WHERE

## The reply to `text` for a player standing at `world_pos`, or "" when it is not a command.
static func run(text: String, world_pos: Vector3) -> String:
	if _command_of(text) == WHERE:
		return TerrainSlice.where_text(world_pos)
	return ""

static func _command_of(text: String) -> String:
	return text.strip_edges().to_lower()
