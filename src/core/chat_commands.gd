extends RefCounted
## Phase 63 — slash commands typed in chat. Pure and static: the UI asks, the answer is a string.

const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")

## True when `text` is a command this module answers.
static func is_command(text: String) -> bool:
	return text.strip_edges().to_lower() == "/where"

## The reply to `text` for a player standing at `world_pos`, or "" when it is not a command.
static func run(text: String, world_pos: Vector3) -> String:
	if text.strip_edges().to_lower() == "/where":
		return TerrainSlice.where_text(world_pos)
	return ""
