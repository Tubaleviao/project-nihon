extends RefCounted
## Bed store (Phase 185) — the bed on a player record: `bed` (an exact `{chunk, local}` wire) and `bed_station`
## (the station id that draws it). Static helpers over `PlayerRegistry`, so the registry stays small.

const WorldPos := preload("res://src/terrain/world_pos.gd")
const BedRule := preload("res://src/world/bed_rule.gd")

## The record's bed as an exact `{chunk, local}`, or null (no bed, or a malformed one).
static func from_record(rec: Dictionary) -> Variant:
	var b: Variant = rec.get("bed", null)
	if not (b is Dictionary) or not WorldPos.is_wire(b):
		return null
	return WorldPos.pos_from_wire(b)

static func of(reg: Node, player_id: String) -> Variant:
	return from_record(reg.get_record(player_id))

## The station id that draws `player_id`'s bed ("" when none).
static func station_of(reg: Node, player_id: String) -> String:
	return str(reg.get_record(player_id).get("bed_station", "")).left(64)

static func set_bed(reg: Node, player_id: String, wp: Dictionary, station_id: String) -> void:
	var rec: Dictionary = reg.ensure_player(player_id)
	if rec.is_empty():
		return
	rec["bed"] = WorldPos.pos_to_wire(reg.canonical_world_pos(WorldPos.normalized(wp)))
	rec["bed_station"] = station_id

static func clear(reg: Node, player_id: String) -> void:
	var rec: Dictionary = reg.get_record(player_id)
	rec.erase("bed")
	rec.erase("bed_station")

## The player whose bed `station_id` draws, or "".
static func owner_of_station(reg: Node, station_id: String) -> String:
	if station_id == "":
		return ""
	for pid in reg.get_player_ids():
		if station_of(reg, str(pid)) == station_id and of(reg, str(pid)) != null:
			return str(pid)
	return ""

## Copy the bed from record `rec` into a saved payload `data`.
static func save(rec: Dictionary, data: Dictionary) -> void:
	if from_record(rec) != null:
		data["bed"] = rec["bed"]
		data["bed_station"] = str(rec.get("bed_station", ""))

## Load the bed of a saved payload onto `rec`; none or a malformed one means no bed (every pre-185 save).
static func load_into(rec: Dictionary, data: Dictionary) -> void:
	if from_record(data) != null:
		rec["bed"] = (data["bed"] as Dictionary).duplicate(true)
		rec["bed_station"] = str(data.get("bed_station", "")).left(64)
	else:
		rec.erase("bed")
		rec.erase("bed_station")

## The bed as a respawn point: the bed itself when free, else the nearest free cell, else null.
static func respawn_bed(rec: Dictionary, runs_at: Callable) -> Variant:
	var bed: Variant = from_record(rec)
	return bed if bed == null or not runs_at.is_valid() else free_spot(bed, runs_at)

## `wp` itself when its spot is free, else the nearest free standing cell, else null.
static func free_spot(wp: Dictionary, runs_at: Callable) -> Variant:
	var chunk: Vector2i = wp["chunk"]
	var local: Vector3 = wp["local"]
	var world := Vector3(chunk.x * WorldPos.CHUNK_METERS + local.x, local.y, chunk.y * WorldPos.CHUNK_METERS + local.z)
	var off: Variant = BedRule.nearest_free(world, runs_at)
	return null if off == null else WorldPos.normalized({ "chunk": chunk, "local": local + (off as Vector3) })
