extends "res://src/core/wiring.gd"
## Bed wiring (Phase 185) — the bed as the owner's spawn point: placement attribution, owner-only sync
## (`bed_synced`) and notices, and the client/local respawn target. `BedSlice` holds the host's rules.

const WorldPos := preload("res://src/terrain/world_pos.gd")
const BedRule := preload("res://src/world/bed_rule.gd")
const PlayerRegistry := preload("res://src/persistence/player_registry.gd")
const I18n := preload("res://src/core/i18n.gd")

## The local body's bed `{chunk, local}`, `{}` for none. The player's own `respawn_world_pos` stays the original
## spawn; `respawn_target` overrides it at death time.
var _bed: Dictionary = {}

func attach() -> void:
	var b = root._bed
	b.station_slice = root._station
	b.registry = root._registry
	b.position_of = root._waystone_wiring._waystone_player_pos
	b.runs_at = self.runs_at
	root._player.respawn_target_fn = self.respawn_target
	if root._is_client:
		root._station.remote_placer = self._place_remote

func _connect_all() -> void:
	connect_bus(GameBus.station_placed, _on_station_placed)
	connect_bus(GameBus.station_removed, _on_station_removed)
	connect_bus(GameBus.block_changed, _on_block_changed)
	connect_bus(GameBus.bed_synced, _on_bed_synced)
	connect_bus(GameBus.bed_resolved, _on_bed_resolved)

## The column runs of one tile from the live voxels (what `BedRule` reads).
func runs_at(tile: Vector2i) -> Array:
	return root._voxel.get_runs_at_tile(tile)

## `wp` itself when its spot is free, else the nearest free standing cell, else null.
static func free_spot(wp: Dictionary, runs: Callable) -> Variant:
	var chunk: Vector2i = wp["chunk"]
	var local: Vector3 = wp["local"]
	var world := Vector3(chunk.x * WorldPos.CHUNK_METERS + local.x, local.y, chunk.y * WorldPos.CHUNK_METERS + local.z)
	var off: Variant = BedRule.nearest_free(world, runs)
	if off == null:
		return null
	return WorldPos.normalized({ "chunk": chunk, "local": local + (off as Vector3) })

## Where the local body respawns: the bed (or the nearest free cell beside it), `{}` for the original spawn.
func respawn_target() -> Dictionary:
	if _bed.is_empty():
		return {}
	var free: Variant = free_spot(_bed, self.runs_at)
	return free if free != null else {}

## Host: take the local player's bed from its record at boot.
func note_local(rec: Dictionary) -> void:
	var bed: Variant = PlayerRegistry.bed_from_record(rec)
	_bed = bed if bed != null else {}

# --- host: placement attribution --------------------------------------------------------------------------

## A bed station was placed: by a remote placer (BedSlice is mid-placement) or by the local player.
func _on_station_placed(station_id: String, type: String, position: Vector3) -> void:
	if root._is_client or root._bed == null or type != root._bed.station_type():
		return
	var pid: String = root._bed.placing_for()
	var here: Dictionary
	var anchor: Vector3
	if pid != "":
		here = root._waystone_wiring._waystone_player_pos(pid)
		var chunk: Vector2i = here["chunk"]
		var l: Vector3 = here["local"]
		anchor = Vector3(chunk.x * WorldPos.CHUNK_METERS + l.x, l.y, chunk.y * WorldPos.CHUNK_METERS + l.z)
	else:
		if root._player == null:
			return
		pid = root._registry.local_player_id
		here = root._player.get_world_pos()
		anchor = root._player.get_position()
	var exact := WorldPos.normalized({ "chunk": here["chunk"], "local": (here["local"] as Vector3) + (position - anchor) })
	root._bed.claim(pid, station_id, exact)

func _on_station_removed(station_id: String) -> void:
	if not root._is_client and root._bed != null:
		root._bed.on_station_removed(station_id)

func _on_block_changed(_action: String, position: Vector3, _normal: Vector3, _material: String) -> void:
	if not root._is_client and root._bed != null:
		root._bed.on_block_changed(position)

## `/regen world` replaced the ground: every bed is cleared.
func world_regenerated() -> void:
	if root._bed != null:
		root._bed.clear_all()

# --- owner-only sync -------------------------------------------------------------------------------------

func _on_bed_synced(player_id: String, bed: Dictionary) -> void:
	if player_id == root._registry.local_player_id or player_id == "":
		_bed = bed.duplicate(true)
		return
	if root._is_client:
		return
	var peer: int = root._registry.get_peer_id(player_id)
	if peer != 0:
		root._networking.send_own_state(peer, { "bed": (WorldPos.pos_to_wire(bed) if not bed.is_empty() else {}) })

func _on_bed_resolved(player_id: String, _ok: bool, key: String) -> void:
	if player_id == root._registry.local_player_id or player_id == "":
		GameBus.spawn_notice.emit(I18n.t(key))
		return
	if root._is_client:
		return
	var peer: int = root._registry.get_peer_id(player_id)
	if peer != 0:
		root._networking.send_own_state(peer, { "bed_notice": key })

## Client: the bed half of the host's view of this player (a join snapshot or an own-state sync).
func apply_own_view(data: Dictionary) -> void:
	if data.has("bed"):
		var b: Variant = data["bed"]
		_bed = WorldPos.pos_from_wire(b) if (b is Dictionary and WorldPos.is_wire(b)) else {}
	var key := str(data.get("bed_notice", "")).left(40)
	if key.begins_with("bed.") and I18n.has_key(key):
		GameBus.spawn_notice.emit(I18n.t(key))

# --- client: placement intent ----------------------------------------------------------------------------

## A client's `_place_station` of a bed goes to the host as an intent; false lets other types place locally.
func _place_remote(type: String, target: Vector3) -> bool:
	if root._bed == null or type != root._bed.station_type() or root._player == null:
		return false
	GameBus.bed_place_intent.emit(target - root._player.get_position(), "")
	return true
