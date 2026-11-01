extends "res://src/core/wiring.gd"
## Admin wiring (Phase 182) — applies what the host's admin commands did to THIS machine's player:
## its moves (`/speed`, `/fly`), a heal, and whether it is an admin at all (the Admin window).
## The commands themselves run in ChatSlice on the host; the host emits these signals for its own
## player and its networking carries them to a remote player's client.

const PlayerSlice := preload("res://src/player/player_slice.gd")
const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")
const PersistenceSlice := preload("res://src/persistence/persistence_slice.gd")
const WorldPos := preload("res://src/terrain/world_pos.gd")
const ChunkRecords := preload("res://src/terrain/chunk_records.gd")
const RegionStore := preload("res://src/persistence/region_store.gd")

func _connect_all() -> void:
	connect_bus(GameBus.admin_moves_synced, _on_admin_moves)
	connect_bus(GameBus.admin_healed, _on_admin_healed)
	connect_bus(GameBus.admin_status_synced, _on_admin_status)
	# A client's (re)connection starts walking normally: the host dropped its moves when it left or joined.
	connect_bus(GameBus.player_identity_assigned, _on_identity_assigned)
	connect_bus(GameBus.world_regen_requested, _on_world_regen_requested)
	connect_bus(GameBus.world_regen_received, _on_world_regen_received)
	# The commands' doors: `/time` runs the host's clock, and a joining client is told whether it is an admin.
	if root._chat != null:
		root._chat.world_clock = root._clock
		if root._networking != null:
			root._networking.admin_check = root._chat.is_admin
	# A host's or offline game's own player is an admin; a client learns it from the host.
	if not root._is_client and not root._is_server:
		GameBus.admin_status_synced.emit(true)

func _on_admin_moves(speed_factor: float, flying: bool) -> void:
	if root._player != null:
		root._player.set_admin_moves(speed_factor, flying)

## A downed body is left to respawn: healing is not a revive.
func _on_admin_healed() -> void:
	if root._player != null and root._player.is_alive():
		root._player.set_hp(root._player.max_hp)

func _on_identity_assigned(_player_id: String) -> void:
	if root._is_client:
		_on_admin_moves(1.0, false)

func _on_admin_status(is_admin: bool) -> void:
	if root._ui != null:
		root._ui.set_admin(is_admin)

# ---------------------------------------------------------------------------
# `/regen world`
# ---------------------------------------------------------------------------

## Where the regions folder goes before a regen: beside it, named for the moment, so a regen can be
## undone by hand (stop the host, move the folder back).
const REGEN_BACKUP_FORMAT := "%s.regen-%d"
## Regens a client has applied (the harness reads it).
var regens_applied := 0

## Host: regenerate the world's terrain. The regions folder (records, edits, depletion) is moved aside;
## memory forgets the same and every chunk restreams from the generator; stations and players keep their
## height above the ground they stood on; every client drops its copy and is sent its scope again; and
## the world is saved. Players, inventories, stations, creatures and the clock are kept.
## Returns "" on success, else a reason code (nothing changed then). `save` false skips the closing save
## (the suite, whose rig has no full world to write).
func regen_world(save := true) -> String:
	if root._is_client:
		return "not_host"
	var store: RegionStore = root._persistence.region_store
	root._persistence_wiring.flush_save()   # nothing may land in the folder once it has moved
	# Heights above the old ground, read before it goes.
	var stations: Array = root._station.get_station_data()
	var station_lift: Array = []
	for s: Dictionary in stations:
		var p := WorldPos.from_wire(s["position"])
		station_lift.append(p.y - root._voxel.get_voxel_height_at(Vector2(p.x, p.z)))
	var bodies := _bodies_and_lift()
	var backup := _move_regions_aside(store.dir)
	if backup == "":
		return "backup_failed"
	# Forget the old ground everywhere it is held.
	root._chunk_manager.discard_pending_records()
	root._chunk_manager.restream()
	if root._chunk_manager.region_streamer != null:
		root._chunk_manager.region_streamer.reset()
	ChunkRecords.clear()
	root._voxel.reset_world()
	root._tree.reset_world()
	if root._structures != null:
		root._structures.reset_world()   # Phase 205 — the placed blocks went with the old ground
	_stamp_current_generator()
	# Stand everything back on the new ground.
	for i in stations.size():
		var p := WorldPos.from_wire(stations[i]["position"])
		p.y = root._voxel.get_voxel_height_at(Vector2(p.x, p.z)) + float(station_lift[i])
		stations[i]["position"] = WorldPos.to_wire(p)
	root._station.apply_station_data(stations)
	root._bed_wiring.world_regenerated()   # Phase 185 — a regenerated world leaves no bed
	# Clients drop their copy first, so a teleport onto the new ground never lands among old terrain.
	var hosting: bool = root._networking != null and root._networking.is_host()
	if hosting:
		root._networking.broadcast_world_regen()
	for b: Dictionary in bodies:
		_place_body(b)
	# Then they get their scope again with every record in it.
	if hosting:
		for peer in root._networking.connected_peers():
			root._snapshot_wiring.forget_records(int(peer))
			root._snapshot_wiring.send_snapshot(int(peer), root._snapshot_wiring.build_snapshot(int(peer), false, null, true))
	root._chunk_manager.refresh()
	if save:
		root._persistence_wiring.save_everything(false)
	print("[Admin] world regenerated; " + ("there were no old regions" if backup == NO_BACKUP else "the old regions are in %s" % backup))
	return ""

## The regenerated ground is the running generator's, so the next save stamps its version and
## fingerprint (the old stamps would warn at every boot that saved edits may not match the terrain).
## The fingerprint history keeps what the world was generated with before.
func _stamp_current_generator() -> void:
	var running_fp := TerrainSlice.worldgen_fingerprint()
	var was := { "worldgenFingerprint": root._worldgen_fp_stamp, "worldgenFingerprintHistory": root._worldgen_fp_history }
	root._worldgen_stamp = TerrainSlice.WORLDGEN_VERSION
	root._worldgen_fp_stamp = running_fp
	root._worldgen_fp_history = PersistenceSlice.fingerprint_history(was, running_fp)

## Every online body with its height above the ground under it: { local: bool, peer: int, pos, lift }.
func _bodies_and_lift() -> Array:
	var out: Array = []
	if root._player != null:
		var wp: Dictionary = root._player.get_world_pos()
		out.append({ "local": true, "peer": 0, "pos": wp, "lift": _lift_of(wp) })
	if root._networking != null and root._networking.is_host():
		for peer in root._networking.connected_peers():
			var exact: Dictionary = root._networking.get_last_known_exact(int(peer))
			if not exact.is_empty():
				out.append({ "local": false, "peer": int(peer), "pos": exact, "lift": _lift_of(exact) })
	return out

func _lift_of(wp: Dictionary) -> float:
	var v := WorldPos.to_scene(wp, Vector2i.ZERO)
	return maxf(v.y - root._voxel.get_voxel_height_at(Vector2(v.x, v.z)), 0.0)

## Put a body at its old height above the new ground (never under it).
func _place_body(b: Dictionary) -> void:
	var v := WorldPos.to_scene(b["pos"], Vector2i.ZERO)
	var y := root._voxel.get_voxel_height_at(Vector2(v.x, v.z)) + maxf(float(b["lift"]), 0.0) + BODY_CLEARANCE_M
	var pos: Dictionary = (b["pos"] as Dictionary).duplicate(true)
	var local: Vector3 = pos["local"]
	local.y = y
	pos["local"] = local
	pos = WorldPos.normalized(pos)
	if bool(b["local"]):
		GameBus.player_teleport.emit(pos)
	else:
		root._networking.send_teleport(int(b["peer"]), pos)

## A body is set this far above the ground it lands on, so it settles onto it instead of into it.
const BODY_CLEARANCE_M := 0.5
## `_move_regions_aside`'s answer when there was no regions folder to keep.
const NO_BACKUP := "(none)"

## Move the regions folder `dir` to a dated sibling and leave an empty one. The path of the backup, or ""
## when the move failed (the world is then left as it was).
func _move_regions_aside(dir: String) -> String:
	var from := ProjectSettings.globalize_path(dir.trim_suffix("/"))
	var to := REGEN_BACKUP_FORMAT % [from, int(Time.get_unix_time_from_system())]
	var n := 1
	while DirAccess.dir_exists_absolute(to):   # two regens in one second
		n += 1
		to = REGEN_BACKUP_FORMAT % [from, int(Time.get_unix_time_from_system())] + "-%d" % n
	if DirAccess.dir_exists_absolute(from):
		var err := DirAccess.rename_absolute(from, to)
		if err != OK:
			push_error("[Admin] could not move %s aside (%s): the world was not regenerated" % [from, error_string(err)])
			return ""
	else:
		to = NO_BACKUP
	DirAccess.make_dir_recursive_absolute(from)
	return to

func _on_world_regen_requested(player_id: String) -> void:
	if root._is_client:
		return
	var why := regen_world()
	if why == "":
		GameBus.system_message.emit("chat.regen_done", [], "")
	else:
		GameBus.system_message.emit("chat.regen_failed", [], player_id)
		push_warning("[Admin] /regen world refused: %s" % why)

## Client: the host regenerated the world. Drop the old ground; its next snapshot brings the new scope.
func _on_world_regen_received() -> void:
	if not root._is_client:
		return
	regens_applied += 1
	root._chunk_manager.restream()
	ChunkRecords.clear()
	root._voxel.reset_world()
	root._tree.reset_world()
	root._chunk_manager.refresh()
