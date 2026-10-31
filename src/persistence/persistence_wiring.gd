extends "res://src/core/wiring.gd"
## Persistence wiring (Phase 132) — Save lifecycle, local player restore and world-record loading.
## Moved out of game_root.gd; `root` is the GameRoot that owns the slices.

const WorldPos := preload("res://src/terrain/world_pos.gd")
const Diag := preload("res://src/core/diag.gd")
const TickProbe := preload("res://src/core/tick_probe.gd")
const TerrainSlice     := preload("res://src/terrain/terrain_slice.gd")
const VoxelSlice       := preload("res://src/terrain/voxel_slice.gd")
const ChunkRecords     := preload("res://src/terrain/chunk_records.gd")
const PersistenceSlice := preload("res://src/persistence/persistence_slice.gd")
const SpawnFinder := preload("res://src/world/spawn_finder.gd")
const PlayerRegistry   := preload("res://src/persistence/player_registry.gd")

func _connect_all() -> void:
	connect_bus(GameBus.player_teleport, _on_player_teleport)
	connect_bus(GameBus.load_completed, _on_load_completed)
	# `save_completed` is deliberately not handled: the slot file is a sample, not the world record, and
	# the authoritative world save clears the manifest keys it serialized itself (`collect_save_job`).

## Accumulate the autosave timer and honour a shutdown request. Authoritative
## roles only: a client neither loads a world nor writes one — its state arrives
## in the host's AOI-scoped snapshot (Phase 29).
##
## The shutdown-request file is polled on its OWN cadence (`shutdownPollSeconds`,
## seconds by default), NOT on the autosave tick: it used to be gated behind
## `autosaveIntervalSeconds` (300 s), so a restart request sat unread for up to
## five minutes. An orchestrator that writes the request and sigkills after a
## short grace period therefore killed the server before it saved, losing up to a
## full autosave interval per restart. It is still not a per-frame
## `FileAccess.file_exists()` (the file is written at most once), so the separate
## short cadence keeps the "don't stat every frame" fix while bounding the
## shutdown latency to `shutdownPollSeconds` instead of the autosave interval.
func tick_save_lifecycle(delta: float) -> void:
	TickProbe.begin("save")   # Phase 162 — the stress run's per-phase tick cost
	_tick_save_lifecycle(delta)
	TickProbe.end()

func _tick_save_lifecycle(delta: float) -> void:
	if root._is_client:
		return
	root._shutdown_poll_elapsed += delta
	if PersistenceSlice.poll_due(root._shutdown_poll_elapsed, root._persistence.shutdown_poll_interval):
		root._shutdown_poll_elapsed = 0.0
		if FileAccess.file_exists(root._persistence.shutdown_request_path):
			print("[Server] shutdown requested — saving before quit")
			save_everything(true)
			flush_save()
			DirAccess.remove_absolute(root._persistence.shutdown_request_path)
			root.get_tree().quit()
			return
	root._autosave_elapsed += delta
	if not PersistenceSlice.autosave_due(root._autosave_elapsed, root._persistence.autosave_interval):
		return
	root._autosave_elapsed = 0.0
	save_everything(true)

## Write the world record plus one record per player. `incremental` merges only the
## dirty chunk manifests into the record already on disk, so a periodic autosave does
## not re-serialize every loaded chunk.
##
## Authoritative roles only — this is the single choke point for every caller
## (boot, autosave, window close, shutdown request). A client owns no world and no
## records: it holds a cached player_id and receives its state from the host, so
## writing here would drop a client-side `world.json` into `user://saves/server/`
## that a later host boot would load as authoritative (client state, no world).
## `_notification()` runs on a client too — `auto_accept_quit` only decides whether
## the engine also quits, not whether the notification is delivered.
##
## The write itself runs on a worker thread (see _start_save_thread): this function
## only COLLECTS the payload, which is the part that reads live slice state and so
## has to happen on the main thread. Callers that must not outrun their write
## (shutdown) call flush_save() afterwards.
func save_everything(incremental: bool) -> void:
	if root._is_client:
		return
	_reap_save_thread()
	_snapshot_local_player()
	root._peer_wiring.snapshot_remote_players()
	_start_save_thread(collect_save_job(incremental))

## Fold the local player's LIVE state into its registry record before a write.
func _snapshot_local_player() -> void:
	var pid := root._registry.local_player_id
	if pid.is_empty():
		return
	root._registry.record_world_pos(pid, root._player.get_world_pos())
	root._peer_wiring.note_presence(root._player.get_world_pos())
	root._registry.record_hp(pid, root._player.get_hp())
	root._registry.record_technology(pid, root._technology.get_statuses(pid))
	# Phase 35 — the live taming flags and companion bindings ride the same record.
	root._taming.sync_record(pid)
	root._professions.sync_record(pid)
	# Appearance is part of the identity ("owning their inventory, HP, position,
	# and appearance"): the character's recipe is stored, not its visual nodes.
	var char_id := root._character.get_player_character()
	if char_id != "":
		root._registry.record_appearance(pid, root._character.get_appearance(char_id))
		# Phase 47 — the worn set is its own record key (the Character window's source).
		root._registry.record_equipment(pid, root._character.get_equipment_set(char_id))

func collect_save_job(incremental: bool) -> Dictionary:
	var manifest := root._voxel.get_save_manifest()
	var dirty := root._voxel.get_dirty_chunk_keys()
	# An incremental save carries ONLY the dirty chunk manifests; save_world() then
	# merges them into the record already on disk. The rest of the world (stations,
	# creatures) is small and always rewritten.
	if incremental:
		manifest = PersistenceSlice.dirty_chunk_subset(manifest, dirty)
	else:
		# A full save still carries the empty-edit-set marker for a dirty chunk whose edits
		# compacted away, so its stale entry is erased from the region file.
		for key in dirty:
			if not manifest.has(str(key)):
				manifest[str(key)] = { "edits": {} }
	var creatures := root._creature.get_snapshot_creatures()
	var stations := root._station.get_station_data()
	var world := {
		"version":         PersistenceSlice.WORLD_FORMAT_VERSION,
		"timestamp":       Time.get_unix_time_from_system(),
		"local_player_id": root._registry.local_player_id,
		# Phase 41 — the world's seed rides the WORLD record, not a player record:
		# two players in one world must regenerate the same ground, and a reload
		# that picked a fresh seed would land every saved edit on a different hill.
		"seed":            root._terrain.get_world_seed(),
		"worldgenVersion": root._worldgen_stamp,
		"worldgenFingerprint": root._worldgen_fp_stamp if root._worldgen_fp_stamp >= 0 else TerrainSlice.worldgen_fingerprint(),
		"worldgenFingerprintHistory": root._worldgen_fp_history if not root._worldgen_fp_history.is_empty() else [TerrainSlice.worldgen_fingerprint()],
		"chunks":          manifest,
		"stations":        stations,
		"station_next_id": root._station.next_id(),
		"waystone_exact":  root._waystones.exact_data() if root._waystones != null else {},
		"creatures":       creatures,
		"colonization":    root._colonization.to_data(),
		"clock":           root._clock.to_data(),
		"settlements":     root._settlements.to_data() if root._settlements != null else {},
		# Phase 204 — clans (world format 3). A record without them is from before clans: its settlements migrate.
		"clans":           root._clans.to_data() if root._clans != null else {},
		# Phase 161 — the bodies kills left, with the time each has left.
		"carcasses":       root._carcass.to_data() if root._carcass != null else {},
		"weather":         root._weather.to_data() if root._weather != null else [],
		# Phase 138 — tree clears the host could not pin in a record yet (see TreeSlice._pending_spots).
		"treeSpots":       root._tree.pending_spots_to_data() if root._tree != null else {},
		# Phase 181 — every created name on the server, so uniqueness covers offline players.
		"names":           root._registry.names_to_data(),
	}
	# NOTE: no `dirty_chunks` key. It used to ride the record, but nothing ever read
	# it back — dirty tracking lives in memory (VoxelSlice) and is reset by the save
	# that consumed it, so writing the list to disk only made the record bigger.
	var players := {}
	# ONLINE players only (see PlayerRegistry.get_online_player_ids): an offline
	# player's record is already durable and cannot have changed since it was
	# written, so rewriting every long-gone player on every autosave was pure churn —
	# the write cost grew with the number of players who had EVER joined.
	root._combat_wiring.refresh_status_records()
	for pid in root._registry.get_online_player_ids():
		var player_id := str(pid)
		players[player_id] = root._registry.get_player_data(player_id)
	# The clear happens HERE, on the main thread, in the same synchronous step that
	# read the dirty set: an edit made while the worker writes re-marks its chunk and
	# is carried by the next save. Clearing after the write landed would need a
	# second, racy bookkeeping pass; clearing before it but on failure re-marking is
	# exact in both directions.
	root._voxel.clear_dirty_chunk_keys(dirty)
	root._voxel.begin_inflight_chunks(dirty)
	root._save_summary = {
		"dirty":       dirty,
		"incremental": incremental,
		"chunks":      manifest.size(),
		"creatures":   creatures.size(),
		"stations":    stations.size(),
		"players":     players.size(),
	}
	return { "world": world, "incremental": incremental, "players": players }

func _start_save_thread(job: Dictionary) -> void:
	# Deep-copied before it crosses the thread boundary: the payload holds references
	# into live records (positions, appearance, technology), and the worker must not
	# be able to read state the main thread is still writing.
	job = job.duplicate(true)
	root._save_thread = Thread.new()
	var err := root._save_thread.start(root._persistence.write_job.bind(job))
	if err != OK:
		# No thread available (or the OS refused one). Fall back to writing inline:
		# a stalled frame beats a save that never happened.
		Diag.error("[Server] save thread failed to start (%s) — saving inline" % error_string(err))
		root._save_thread = null
		_finish_save(root._persistence.write_job(job))
		return
	print("[Server] world save started (threaded)")

## Wait for the in-flight write, report it, and settle the dirty-chunk bookkeeping.
## Exactly one place reads the worker's result, so the success and failure paths
## cannot drift. Runs on the main thread (Thread.wait_to_finish blocks, which is why
## only the shutdown paths call it directly).
func _reap_save_thread() -> void:
	if root._save_thread == null:
		return
	_finish_save(int(root._save_thread.wait_to_finish()))
	root._save_thread = null

## Reap the save worker as soon as it has FINISHED, without blocking.
##
## Before this, the only reaper was `_reap_save_thread()` at the START of the next
## `save_everything()`, so a failed write was discovered up to one whole autosave
## interval late — and the chunks it had serialized had already been cleared from
## the dirty set at collection time. In that window the edits looked saved and
## were not, and a process that died inside it lost them with no error reported.
## `Thread.is_alive()` is false the moment the worker returns, so this costs one
## bool per frame and reuses the same single reaper (no second result path).
func poll_save_completion() -> void:
	if root._save_thread == null or root._save_thread.is_alive():
		return
	_reap_save_thread()

## Block until the in-flight write has landed. Shutdown (window close, the polled
## shutdown-request file, process exit) must not outrun its own save.
func flush_save() -> void:
	_reap_save_thread()

func _finish_save(result: int) -> void:
	root._voxel.end_inflight_chunks(root._save_summary.get("dirty", []))
	if result != OK:
		Diag.error("[Server] world save failed — %s" % error_string(result))
		GameBus.world_save_failed.emit(error_string(result))
		# The dirty set was cleared when the payload was collected, so a failed write
		# has to put its chunks back or the next save would skip them.
		root._voxel.mark_dirty_chunks(root._chunks_to_remark(root._save_summary.get("dirty", []), root._persistence.failed_chunk_keys()))
		root._save_summary = {}
		return
	print("[Server] world saved (%s) — %d chunk manifest(s), %d creature(s), %d station(s), %d player record(s)" % [
		"incremental" if bool(root._save_summary.get("incremental", false)) else "full",
		int(root._save_summary.get("chunks", 0)),
		int(root._save_summary.get("creatures", 0)),
		int(root._save_summary.get("stations", 0)),
		int(root._save_summary.get("players", 0)),
	])
	root._save_summary = {}
	GameBus.world_saved.emit()

## Bind the local (authoritative) player's identity and inventory. The id comes
## from the world record when a previous process minted one, so identity is as
## persistent as the world; otherwise a fresh id is minted here. Binding the
## game's own `_inventory` is what makes the local player's inventory per-player
## without touching any existing call site.
## Phase 183 — the id a FRESH world's local player gets instead of a minted one ("" mints). Only the
## playtest bot sets it: the spawn search is seeded by the player id, so a pin keeps every run on one ground.
var fixed_local_id := ""

func _bind_local_identity() -> void:
	var pid := str(root._loaded_world.get("local_player_id", ""))
	if pid.is_empty():
		pid = fixed_local_id if fixed_local_id != "" else root._registry.mint_player_id()
	root._registry.set_local_player(pid, root._inventory)

## Rebuild the local avatar from the appearance recipe in the saved player
## record, or create the default appearance when the record has none (a fresh
## world). Returns the character instance id.
func restore_or_create_player_character(pos: Vector3) -> String:
	var pid := root._registry.local_player_id
	var appearance: Variant = root._registry.get_record(pid).get("appearance", {}) if not pid.is_empty() else {}
	# Phase 181 — a created character's look wins over a stored recipe (a save from before the creation).
	var created: Variant = root._creation_wiring.boot_recipe(root._registry.creation_of(pid)) if not pid.is_empty() else null
	if created != null:
		var made: String = root._character.create_character_from_recipe(created, pos)
		if made != "":
			return made
	if appearance is Dictionary and not (appearance as Dictionary).is_empty():
		var restored: String = root._character.create_character_from_recipe(appearance, pos)
		if restored != "":
			return restored
	return root._character.create_character("TravellerHuman", pos)

## Restore the local player's position, HP, and technologies from its record.
## Called AFTER the spawn point is set, so the record wins over the spawn.
func restore_local_player() -> void:
	var pid := root._registry.local_player_id
	if pid.is_empty():
		return
	var rec := root._registry.get_record(pid)
	var saved_pos: Variant = saved_local_position()
	root._local_player_returning = saved_pos != null
	if saved_pos != null:
		place_local_player(saved_pos)
	# Phase 66 — a respawn goes to the ORIGINAL spawn point: the recorded one, else (a record from
	# before the field existed) the saved position; a fresh player's placement is recorded now.
	var spawn: Variant = SpawnFinder.original_spawn_for(rec)
	root._bed_wiring.note_local(rec)   # Phase 185 — the bed overrides it at death time, never the stored spawn
	if spawn != null:
		root._player.set_respawn_world_pos(_lifted_world_pos(spawn))
	else:
		record_first_spawn(pid)
	# Phase 178 — the attributes first, so a saved HP above 100 is not clamped under the default ceiling.
	root._player.set_attributes(root._registry.get_attributes(pid))
	var hp := float(rec.get("hp", -1.0))
	if hp >= 0.0:
		root._player.set_hp(hp)
	var tech: Variant = rec.get("technology", {})
	if tech is Dictionary and not (tech as Dictionary).is_empty():
		root._technology.apply_statuses(tech, pid)
	# Phase 35 — the local player's taming flags and companion bindings.
	root._taming.apply_record(rec, pid)
	root._professions.apply_record(rec, pid)
	# Phase 47 — and the worn set.
	root._character_wiring.apply_local_equipment(rec.get("equipment", {}))

## Phase 98 — a fresh player's placement becomes its spawn, from the body's exact `{chunk, local}`
## (the float32 `respawn_point` is metres off far from the origin).
func record_first_spawn(pid: String) -> void:
	root._registry.record_spawn_world_pos(pid, root._player.get_world_pos())

## `wp`, lifted onto the surface above it when it lies inside the ground (see `_lifted_out_of_ground`);
## only `local.y` changes, so the chunk and the horizontal offset stay exact.
func _lifted_world_pos(wp: Dictionary) -> Dictionary:
	var chunk: Vector2i = wp["chunk"]
	var local: Vector3 = wp["local"]
	var world := Vector3(chunk.x * WorldPos.CHUNK_METERS + local.x, local.y, chunk.y * WorldPos.CHUNK_METERS + local.z)
	var lifted := _lifted_out_of_ground(world)
	if lifted == world:
		return wp
	return {"chunk": chunk, "local": Vector3(local.x, lifted.y, local.z)}

## The local player's recorded position, or null when there is no identity or the
## record carries none. Read by the host boot (to arm the first ring where the player
## will stand) and by `restore_local_player`.
func saved_local_position() -> Variant:
	root._saved_position_reads += 1
	var pid := root._registry.local_player_id
	if pid.is_empty():
		return null
	var arr = root._registry.get_record(pid).get("position", [])
	if arr is Array and (arr as Array).size() >= 3:
		var pos := Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
		# A brand-new record is created at the exact origin (`ensure_player`), which is inside the
		# ground: it is "never placed", not a saved position, so the first-boot spawn still runs.
		if pos == Vector3.ZERO:
			return null
		return pos
	return null

## Phase 85 — an admin teleport: land the local body at the world position `pos`, rebasing the scene
## first so a far target lands on a small float32 (the same door a saved position uses).
func _on_player_teleport(pos: Dictionary) -> void:
	if root._player == null or not (pos.get("chunk") is Vector2i and pos.get("local") is Vector3):
		return
	if root._rebase != null:
		root._rebase.rebase_to(pos["chunk"])
		root._player.place_at_world_pos(pos)
	else:
		root._player.spawn_at(WorldPos.to_scene(pos, Vector2i.ZERO))

## Phase 78 — put the local player at `pos`. A saved position is placed from the record's exact
## `{chunk, local}` (rebasing the scene first, so the body lands on a small float32), not from the
## quantised double `position`; a position with no saved record (a first-boot spawn) and a headless
## server, which has no rebase driver, place by world position. So the record WINS over `pos`
## whenever one exists and a rebase driver is present; `pos` is used otherwise. The record is read
## once per placement.
func place_local_player(pos: Vector3) -> void:
	var pid := root._registry.local_player_id
	var saved: Variant = saved_local_position()
	if root._rebase != null and not pid.is_empty() and saved != null:
		var wp := root._registry.get_world_pos(pid)
		root._rebase.rebase_to(wp["chunk"])
		root._player.place_at_world_pos(wp)
	else:
		root._player.spawn_at(pos)

## A restored body that sits inside solid ground (a record saved while the player was stuck, or one
## written before the terrain changed) is lifted onto the surface above it; a body in open air, in
## a tunnel or a cave is left alone.
func lift_out_of_ground() -> void:
	if root._player == null:
		return
	var pos := root._player.get_position()
	var lifted := _lifted_out_of_ground(pos)
	if lifted != pos:
		Diag.warn("GameRoot: position %s is inside the ground — lifted to %.2f" % [pos, lifted.y])
		root._player.spawn_at(lifted)

## `pos`, or the surface above it when it lies inside (or under) the solid ground of its column.
func _lifted_out_of_ground(pos: Vector3) -> Vector3:
	if root._voxel == null:
		return pos
	var runs: Array = root._voxel.get_column_runs_at(Vector2(pos.x, pos.z))
	if runs.is_empty():
		return pos
	var inside := pos.y < float(runs[0]["bottom"])
	for run in runs:
		if pos.y > float(run["bottom"]) and pos.y < float(run["top"]):
			inside = true
	return Vector3(pos.x, float(runs[-1]["top"]) + 0.1, pos.z) if inside else pos

## A respawn lands on the recorded spawn point; one recorded inside the ground (by the old
## origin-spawn bug) is lifted too.
func lift_after_respawn() -> void:
	if root._player != null and not root._player.respawn_world_pos.is_empty():
		var wp := root._player.get_world_pos()
		var lifted := _lifted_world_pos(wp)
		if lifted != wp:
			root._player.place_at_world_pos(lifted)
		return
	lift_out_of_ground()

## Read the world record and the LOCAL player's record off disk. A missing world
## record is NOT an error — a server with no save boots a fresh world.
##
## Chunk manifests and stations are applied here (pure data). The creature state
## is applied by apply_loaded_creature_state() AFTER chunk streaming, because
## spawn_for_chunk() builds fresh instance records.
##
## Only the local player's record is read at boot. Every OTHER record on disk used
## to be loaded here too, and the registry never evicts — so a server that had seen
## a thousand players held a thousand records, their inventories and all, in memory
## for the whole session, whether or not any of them ever came back. A record is now
## brought in on demand: the registry is given a reader (set_record_loader) and pulls
## one in the first time a peer CLAIMS it (a reconnect). That is the only moment a
## remote record is needed.
## Phase 71 — keep the loaded record's original stamp when re-saving (a new world takes the
## running one), and tell the bus when that stamp is not the running generator's.
## Phase 196 — the registry's ground dropper: `item` x `quantity` at `player_id`'s feet (the local body,
## or a remote peer's last reported position).
func _drop_at_feet(player_id: String, item: String, quantity: int) -> void:
	Diag.warn("PersistenceWiring: starting kit %s x%d did not fit %s's bag — dropped at their feet" % [item, quantity, player_id])
	if root._loot == null:
		return
	var pos: Vector3
	var peer: int = root._registry.get_peer_id(player_id)
	if player_id == root._registry.local_player_id and root._player != null:
		pos = root._player.get_position()
	elif peer > 0 and root._networking.has_last_known_state(peer):
		pos = root._networking.get_last_known_state(peer)
	else:
		return
	root._loot.spawn_pickup(item, quantity, pos)

func note_worldgen_version() -> void:
	root._worldgen_stamp = PersistenceSlice.worldgen_stamp_for_save(root._loaded_world, TerrainSlice.WORLDGEN_VERSION)
	if PersistenceSlice.check_worldgen_version(root._loaded_world, TerrainSlice.WORLDGEN_VERSION):
		GameBus.worldgen_version_mismatch.emit(root._worldgen_stamp, TerrainSlice.WORLDGEN_VERSION)
	var running_fp := TerrainSlice.worldgen_fingerprint()
	root._worldgen_fp_stamp = PersistenceSlice.fingerprint_stamp_for_save(root._loaded_world, running_fp)
	if PersistenceSlice.check_worldgen_fingerprint(root._loaded_world, running_fp):
		GameBus.worldgen_fingerprint_mismatch.emit(root._worldgen_fp_stamp, running_fp)
		# Phase 138 — the notice is given once: the next save stamps the running fingerprint, so a later
		# load of the same world is silent (the records, not the stamp, keep old land stable).
		root._worldgen_fp_stamp = running_fp
	root._worldgen_fp_history = PersistenceSlice.fingerprint_history(root._loaded_world, root._worldgen_fp_stamp)

## Phase 114 — generation records never outlive the world they describe.
func forget_world_records() -> void:
	ChunkRecords.clear()

func load_world_records() -> void:
	# Phase 52 — the GLOBAL record only; a Phase 51 monolithic record is split into region
	# files by this read, and the edits themselves stream in by region.
	root._loaded_world = root._persistence.load_world_record()
	forget_world_records()
	note_worldgen_version()
	_bind_local_identity()
	# Lazy reader for every other player's record (see the docstring above).
	root._registry.set_record_loader(root._persistence.load_player)
	root._registry.set_spawn_placer(root._peer_wiring.place_new_player)
	root._registry.set_friend_locator(root._peer_wiring.locate_friend_on_disk)
	root._registry.set_ground_dropper(_drop_at_feet)
	root._registry.names_from_data(root._loaded_world.get("names", {}))
	root._colonization.from_data(root._loaded_world.get("colonization", {}))
	root._clock.from_data(root._loaded_world.get("clock", {}))
	root._weather.from_data(root._loaded_world.get("weather", []))
	if root._tree != null:
		root._tree.pending_spots_from_data(root._loaded_world.get("treeSpots", {}))
	root._colonization.seed_from_regions(root._persistence.region_store.list_regions())
	root._peer_wiring.wire_colonization()
	if root._loaded_world.is_empty():
		print("[Server] no world record at %s — booting a fresh world" % root._persistence.world_path())
	else:
		# Phase 41 — adopt the recorded world seed BEFORE any chunk is built or any
		# edit is migrated: the ground a save was written against is the ground a
		# reload must regenerate, and the migration of a pre-Phase-41 edit needs
		# the tile's natural height, which comes from this noise field.
		var recorded_seed: Variant = root._loaded_world.get("seed", null)
		if recorded_seed != null:
			root._terrain.set_world_seed(int(recorded_seed))
			print("[Server] world seed %d restored from the world record" % int(recorded_seed))
		else:
			root._terrain.seed_adopted = true
			print("[Server] world record carries no seed (format %d) — adopting the fresh seed %d" % [
				int(root._loaded_world.get("version", PersistenceSlice.LEGACY_WORLD_FORMAT_VERSION)),
				root._terrain.get_world_seed()])
		root._station.apply_station_data(root._loaded_world.get("stations", []))
		root._station.restore_next_id(int(root._loaded_world.get("station_next_id", 0)))
		if root._settlements != null:
			root._settlements.from_data(root._loaded_world.get("settlements", {}))
		if root._clans != null:
			if root._loaded_world.has("clans"):
				root._clans.from_data(root._loaded_world["clans"])
			else:
				root._clans.from_data({})
				var made: int = root._clans.migrate_settlements(root._loaded_world.get("settlements", {}))
				if made > 0:
					print("[Server] %d settlements became clans (world format %d → %d)" % [made,
						int(root._loaded_world.get("version", PersistenceSlice.LEGACY_WORLD_FORMAT_VERSION)), PersistenceSlice.WORLD_FORMAT_VERSION])
		if root._carcass != null:
			root._carcass.from_data(root._loaded_world.get("carcasses", {}))
		if root._waystones != null:
			root._waystones.apply_exact_data(root._loaded_world.get("waystone_exact", {}))
		print("[Server] world loaded from %s" % root._persistence.world_path())
	# A failed region migration hands the record back WITH its chunks: apply them and mark
	# them dirty so the next save writes them to regions instead of dropping them. Phase 61 —
	# applied AFTER the world seed is restored above: a pre-Phase-41 height migrates against
	# the tile's natural run, which comes from that seed.
	var legacy_chunks: Variant = root._loaded_world.get("chunks", null)
	if legacy_chunks is Dictionary and not (legacy_chunks as Dictionary).is_empty():
		root._voxel.apply_chunk_manifest(legacy_chunks)
		root._voxel.mark_dirty_chunks((legacy_chunks as Dictionary).keys())
	# The local player's record: position, HP, inventory (with per-instance
	# durability), and technology. It lands in the game's own slices because
	# _bind_local_identity() ran first.
	_load_local_player_record()

func _load_local_player_record() -> void:
	var pid := root._registry.local_player_id
	if pid.is_empty():
		return
	var record := root._persistence.load_player(pid)
	if record.is_empty():
		return
	root._registry.apply_player_data(pid, record)
	print("[Server] restored the local player record '%s'" % pid)

## Re-apply the recorded creature state (state, HP, and the wall-clock respawn
## deadline) over the population chunk streaming just spawned. `apply_recorded_…`
## (not the client's `apply_snapshot_creatures`) so a record for a chunk outside
## the current view window is skipped instead of fabricating an instance.
func apply_loaded_creature_state() -> void:
	var creatures: Variant = root._loaded_world.get("creatures", [])
	if not (creatures is Array) or (creatures as Array).is_empty():
		return
	root._creature.apply_recorded_creature_states(creatures)

# ---------------------------------------------------------------------------
# Bus listeners
# ---------------------------------------------------------------------------

func _on_load_completed(_slot: int, data: Dictionary) -> void:
	if data.has("inventory") and data["inventory"] is Dictionary:
		# A MISSING `inventory_durability` key is the intentional old-save signal:
		# saves written before per-instance durability carried no per-instance
		# wear, so `replace_contents` correctly grants fresh (pristine) durable
		# instances rather than resurrecting stale local wear.
		root._inventory.replace_contents(data["inventory"], data.get("inventory_durability", {}))
	var world: Dictionary = data.get("world", {})
	if world.has("chunks"):
		root._voxel.apply_chunk_manifest(world["chunks"])
	elif world.has("voxel_edits"):
		root._voxel.apply_edits(world["voxel_edits"], world.get("voxel_materials", {}))
	if data.has("technology"):
		root._technology.apply_statuses(data["technology"], root._registry.local_player_id)
	# Phase 33 — the snapshot carries the player's own record: position is set
	# FIRST (spawn_at), then HP, so the restored body sits where the record says.
	var player_data: Variant = data.get("player", {})
	if player_data is Dictionary and not root._is_client:
		var arr = player_data.get("position", [])
		if arr is Array and (arr as Array).size() >= 3:
			root._player.spawn_at(Vector3(float(arr[0]), float(arr[1]), float(arr[2])))
			lift_out_of_ground()
		var hp := float(player_data.get("hp", -1.0))
		if hp >= 0.0:
			root._player.set_hp(hp)
		# Phase 129 — the saved effects; a legacy snapshot has none.
		if root._status != null:
			root._status.from_data("player", player_data.get("status_effects", []), root._combat_wiring.status_now())
			for t in root._status.take_dirty():
				root._combat_wiring.push_status_effects(str(t), root._combat_wiring.status_now())
	if data.has("market"):
		root._market.apply_market_data(data["market"])
	if data.has("governance"):
		var gov: Variant = data["governance"]
		if gov is Dictionary:
			root._proposal.apply_governance_data(gov)
		elif gov is Array:
			# Backward compat: older saves stored only the decisions log.
			root._proposal.apply_decisions_log(gov)
	if data.has("trade"):
		var saved_trade: Variant = data["trade"]
		if saved_trade is Dictionary:
			root._trade.apply_trade_data(saved_trade)

# ---------------------------------------------------------------------------
# GameData smoke test
# ---------------------------------------------------------------------------
