extends "res://src/core/wiring.gd"
## Peer wiring (Phase 132) — Peers: join/leave, identity, remote avatars, fold stand-ins, handshake, own-state sync.
## Moved out of game_root.gd; `root` is the GameRoot that owns the slices.

const WorldPos := preload("res://src/terrain/world_pos.gd")
const Diag := preload("res://src/core/diag.gd")
const TerrainSlice     := preload("res://src/terrain/terrain_slice.gd")
const CreatureAI       := preload("res://src/creature/creature_ai.gd")
const NetworkingSlice  := preload("res://src/networking/networking_slice.gd")
const PlayerRegistry   := preload("res://src/persistence/player_registry.gd")
const PlayerSlice      := preload("res://src/player/player_slice.gd")
const SpawnFinder      := preload("res://src/world/spawn_finder.gd")

func _connect_all() -> void:
	if root.is_inside_tree():
		connect_bus(root.multiplayer.connection_failed, _on_connection_failed)
		connect_bus(root.multiplayer.server_disconnected, _on_server_disconnected)
	connect_bus(GameBus.own_state_synced, on_own_state_synced)
	connect_bus(GameBus.peer_disconnected, _on_peer_disconnected)
	connect_bus(GameBus.player_joined, _on_player_joined)
	connect_bus(GameBus.player_identity_assigned, _on_player_identity_assigned)
	connect_bus(GameBus.remote_player_state, on_remote_player_state)
	connect_bus(GameBus.remote_player_state, _on_remote_avatar_state)
	connect_bus(GameBus.peer_equipment_evicted, _remove_remote_avatar)

## Phase 33 — host: an identity was bound (first join, or a reconnect). The peer's
## own inventory is now known, so register it as that peer's trade/market party (the
## party id the client's "player" self-reference resolves to) and send its world
## snapshot.
##
## The snapshot is sent HERE, on the handshake, and NOT also on `peer_connected`.
## It used to be sent twice — once on connect, once on join — so every reconnecting
## client paid for a full world snapshot twice, and the FIRST one was the worse of
## the two: it was built before the peer's identity was resolved, so it carried no
## own-record and was immediately replaced. One snapshot, with the identity in hand.
func _on_player_joined(peer_id: int, player_id: String, reconnected: bool) -> void:
	if root._is_client:
		return
	root._networking.send_peer_equipment_to(peer_id)
	var inv = root._registry.get_inventory(player_id)
	if inv != null:
		root._trade.set_party_inventory(player_id, inv)
		root._market.set_party_inventory(player_id, inv)
	# Phase 34 — the peer's technology tree is part of its record, so hand it to the
	# slice before the snapshot goes out: a reconnecting peer resumes its own
	# "researching"/"unlocked" statuses (and the research timer for a status restored
	# mid-research), and a first join gets a seeded, all-locked tree.
	var tech: Variant = root._registry.get_record(player_id).get("technology", {})
	if tech is Dictionary:
		root._technology.apply_statuses(tech, player_id)
	# Phase 35 — the peer's taming flags and companion bindings ride the same
	# record: a reconnecting peer keeps its `wolfBondHolder` flag and its tamed
	# wolf (re-bound to the creature instance when that instance is resident).
	root._taming.apply_record(root._registry.get_record(player_id), player_id)
	root._professions.apply_record(root._registry.get_record(player_id), player_id)
	root._combat_wiring.restore_status_effects(player_id, player_id)
	print("[Server] %s player '%s' as %s" % ["reconnected" if reconnected else "joined", player_id, "peer_%d" % peer_id])
	root._chat.announce_joined(player_id)
	# Phase 52 — the peer's window opens NOW, so the regions around its saved position are
	# resident (and its snapshot carries their edits) before the snapshot is built.
	root._chunk_manager.set_peer_center(peer_id, peer_window_chunk(peer_id), true)
	root._chunk_manager.refresh(false)
	root._networking.send_snapshot(peer_id, root._snapshot_wiring.build_snapshot(peer_id))

## Phase 53 — the local (host / offline) player's placement on a boot with no saved position:
## the friend named by `--friend` if any, else habitable land away from colonized regions. Cached,
## so the boot and its tail agree. null when a saved position exists or nothing qualifies.
func first_boot_spawn() -> Variant:
	if root._persistence_wiring.saved_local_position() != null:
		return null
	if root._local_spawn == null:
		var placed := place_new_player(root._registry.local_player_id, root._friend_code_arg)
		if placed.has("position"):
			root._local_spawn = placed["position"]
			root._colonization.note_home(Vector2i(floori(root._local_spawn.x / TerrainSlice.CHUNK_METERS), floori(root._local_spawn.z / TerrainSlice.CHUNK_METERS)))
			if not str(placed.get("message", "")).is_empty():
				print("[Spawn] %s" % placed["message"])  # a catalog key, shown to remote peers in their locale
	return root._local_spawn

## Phase 53 — where a NEW player lands: beside the friend whose handle they gave, else on habitable
## land far from every colonized region. Returns { position, source, message } (empty when the
## world has no qualifying spot, and the caller keeps its old default).
func place_new_player(player_id: String, friend_code: String) -> Dictionary:
	var height_fn := func(p: Vector2) -> float: return root._terrain.get_height_at(p)
	var world_seed := root._terrain.get_world_seed()
	var message := ""
	var source := "search"
	if friend_code != "":
		var friend_pos: Variant = _friend_position(friend_code)
		if friend_pos != null:
			var radius := float(SpawnFinder.rule()["friend_radius"])
			var near: Variant = SpawnFinder.find_near(world_seed, player_id, Vector2(friend_pos.x, friend_pos.z), radius, height_fn)
			if near != null:
				root._colonization.note_home(Vector2i(floori(near.x / TerrainSlice.CHUNK_METERS), floori(near.z / TerrainSlice.CHUNK_METERS)))
				return { "position": near, "source": "friend", "message": "" }
			message = "spawn.no_safe_ground"
		else:
			message = "spawn.unknown_friend"
		source = "friend_unknown"
	var found: Variant = SpawnFinder.find_new(world_seed, player_id, root._colonization, height_fn, Time.get_unix_time_from_system())
	if found == null:
		return {}
	root._colonization.note_home(Vector2i(floori(found.x / TerrainSlice.CHUNK_METERS), floori(found.z / TerrainSlice.CHUNK_METERS)))
	return { "position": found, "source": source, "message": message }

## The live position of the player behind `handle`: the local player's body, else the registry.
func _friend_position(handle: String) -> Variant:
	if root._registry.public_handle(root._registry.local_player_id) == handle and root._player != null:
		return root._player.get_position()
	return root._registry.friend_position(handle)

## The saved position of an OFFLINE player behind `handle`, found by hashing the ids of the
## records on disk. null when no record matches.
func locate_friend_on_disk(handle: String) -> Variant:
	for pid in root._persistence.list_player_records():
		if root._registry.public_handle(str(pid)) != handle:
			continue
		var rec := root._persistence.load_player(str(pid))
		var arr: Variant = rec.get("position", [])
		if arr is Array and (arr as Array).size() >= 3:
			return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
	return null

## Phase 122 — presence is noted at the exact chunk of `wp` (`{chunk, local}`), not a float32 position.
func note_presence(wp: Dictionary) -> void:
	root._colonization.note_presence(wp["chunk"], Time.get_unix_time_from_system())

## Phase 122 — a peer's last known position as an exact `{chunk, local}`: the exact record when the
## peer reported one, else the float position promoted.
func peer_exact_pos(peer_id: int) -> Dictionary:
	var exact: Dictionary = root._networking.get_last_known_exact(peer_id)
	if not exact.is_empty() and WorldPos.is_plausible_pos(exact):
		return exact
	var p := root._networking.get_last_known_state(peer_id)
	return WorldPos.from_world(p.x, p.y, p.z)

## Late connection (host/server boot, once the colonization map is loaded); tracked so `unwire` drops it.
func wire_colonization() -> void:
	if not GameBus.block_changed.is_connected(_on_block_changed_colonization):
		connect_bus(GameBus.block_changed, _on_block_changed_colonization)

func _on_block_changed_colonization(_action: String, position: Vector3, _normal: Vector3, _material: String) -> void:
	root._colonization.note_edited_chunk(Vector2i(floori(position.x / TerrainSlice.CHUNK_METERS), floori(position.z / TerrainSlice.CHUNK_METERS)))

## Phase 33 — client: the host told us which record we are. Cache the id so the
## next connection can claim it, and read our own state out of it.
func _on_player_identity_assigned(player_id: String) -> void:
	if not root._is_client or player_id.is_empty():
		return
	root._persistence.save_client_identity(player_id)
	if root._ui != null:
		root._ui.set_own_handle(root._networking.claimed_handle)
	print("[Client] identity assigned: %s" % player_id)

## Phase 33 — host: a connection dropped. Write the player's record before the
## transport mapping is discarded; the record stays on DISK (and is re-loaded
## lazily on the reconnect claim), so the same player_id reconnects to the same
## inventory, position, and HP.
##
## The in-memory record and the player's inventory node are then RELEASED
## (`evict_player`): keeping them was what made the registry grow with every peer
## that had ever connected. Order matters — fold, write, unbind, then evict — so
## the durable copy is complete before the only reference to the live one goes.
## The party bindings in trade/market are dropped with it: they hold a raw node
## reference, and a freed node is not null.
func _on_peer_disconnected(peer_id: int) -> void:
	_remove_remote_avatar(peer_id)
	root._character.forget_peer(peer_id)
	if root._is_client:
		return
	root._chunk_manager.clear_peer_center(peer_id)
	var player_id := root._registry.get_player_id(peer_id)
	if player_id.is_empty():
		return
	fold_last_known_state(peer_id, player_id)
	root._combat_wiring.refresh_status_records()
	if root._status != null:
		root._status.clear(player_id)
		root._status.take_dirty()
	root._persistence.save_player(player_id, root._registry.get_player_data(player_id))
	root._registry.unbind_peer(peer_id)
	# A stale AOI cell for a peer_id ENet may hand to the next connection would
	# suppress that peer's very first re-scoped snapshot.
	root._peer_aoi_regions.erase(peer_id)
	root._peer_records_msec.erase(peer_id)
	root._trade.clear_party_inventory(player_id)
	root._market.clear_party_inventory(player_id)
	root._registry.evict_player(player_id)
	# Phase 37 — and the taming slice's per-player mirrors (flags, companion bindings,
	# cooldowns) go with it. They are the same kind of memory: the durable copy is the
	# record just written, so a server that has seen a thousand tamers no longer holds
	# a thousand tables for the rest of the session, and a reconnect re-applies the
	# record it claims (see _on_player_joined).
	root._taming.forget_player_id(player_id)
	root._professions.forget_player_id(player_id)
	GameBus.player_left.emit(player_id)

## Fold everything the host knows about a LIVE remote peer into its registry record:
## its last-reported position.
##
## Position is guarded by has_last_known_state() — get_last_known_state() answers
## Vector3.ZERO for BOTH "at the origin" and "never reported", so writing it
## unconditionally would reset a returning player's record to the world origin
## from a peer that connected but never sent a state packet.
##
## HP is not folded EITHER — but for the opposite reason to before Phase 38. The HP
## this host holds for a remote peer is now its OWN simulation of that body
## (`PlayerRegistry.record_simulated_hp`, written the moment the host resolves a
## creature's round against it), not a value read back out of the wire's movement
## packets, so there is nothing left to fold: the record is already current. What is
## still refused at every door is the peer's DECLARED hp — `_route_c2h` ignores the
## `hp` that rides `player_moved` and `PlayerRegistry.record_hp` refuses a remote id —
## because that is a claim about a body this process cannot check. Only the local
## player's live body and the host's own hit resolution may write a record's health.
func fold_last_known_state(peer_id: int, player_id: String) -> void:
	if root._networking.has_last_known_state(peer_id):
		# Phase 86 — the exact position when the peer reported one; the float Vector3 otherwise.
		var exact: Dictionary = root._networking.get_last_known_exact(peer_id)
		# Phase 97 — an exact position that is not a plausible wire position (a chunk past the pole row)
		# is not persisted; the record keeps its previous position.
		if not exact.is_empty() and not WorldPos.is_plausible_pos(exact):
			return
		if exact.is_empty():
			root._registry.record_position(player_id, root._networking.get_last_known_state(peer_id))
		else:
			root._registry.record_world_pos(player_id, exact)

## Phase 33 — fold every ONLINE remote peer's last-known position into its record.
## This runs on every autosave, not only at disconnect: a peer whose process
## is KILLED (or whose host is) never reaches _on_peer_disconnected, so the durable
## record would otherwise still hold whatever was loaded from disk — a returning
## player resurrected at the world origin. The autosave interval is now the bound
## on how much of a remote peer's live position a hard kill can lose. (Its HP needs no
## folding — the host's own simulated value is written when the hit is resolved; see
## fold_last_known_state.)
func snapshot_remote_players() -> void:
	for peer_id in root._networking.get_last_known_states():
		var player_id := root._registry.get_player_id(int(peer_id))
		if player_id.is_empty():
			continue
		fold_last_known_state(int(peer_id), player_id)
		if root._networking.has_last_known_state(int(peer_id)):
			note_presence(peer_exact_pos(int(peer_id)))

## Phase 36 — every player CreatureAI can place on this machine, as
## { target_id: Vector3 }: the local body under the id "player" (the defender id
## `combat_round_requested` has always used for it) plus each connected peer's last
## recorded position, under its player id.
##
## A peer that has never reported a position is deliberately NOT included: aiming a
## creature at the world origin would be worse than not seeing that peer at all. The
## position is the host's own evidence of where the peer is (recorded from the
## peer's movement packets — see NetworkingSlice.remember_player_state), not a claim
## from the client.
func player_targets() -> Dictionary:
	var out := {}
	if root._player != null:
		out["player"] = root._player.get_position()
	for peer_id in root._networking.get_last_known_states():
		var player_id := root._registry.get_player_id(int(peer_id))
		if player_id.is_empty():
			continue
		out[player_id] = root._networking.get_last_known_state(int(peer_id))
	return out

func _on_remote_avatar_state(peer_id: int, position: Vector3) -> void:
	if not root._is_client or peer_id == root.multiplayer.get_unique_id():
		return
	var iid: String = str(root._remote_avatars.get(peer_id, ""))
	if iid != "" and root._character.set_character_position(iid, position):
		return
	iid = root._character.create_character("TravellerHuman", position)
	if iid == "":
		return
	root._remote_avatars[peer_id] = iid
	root._character.bind_peer_character(peer_id, iid)
	# The avatar IS this peer now; the PlayerSlice capsule ghost would draw it a second time.
	root._player.set_ghost_suppressed(peer_id, true)

## A peer with nothing worn is never sent an evict, so a body that has drifted out of range
## is dropped here as well (the host stops reporting its state once it leaves our AOI).
func prune_remote_avatars() -> void:
	if root._remote_avatars.is_empty() or root._player == null:
		return
	var here: Vector3 = root._player.get_position()
	for peer_id in root._remote_avatars.keys():
		var at: Variant = root._character.get_character_position(str(root._remote_avatars[peer_id]))
		if at is Vector3 and (at as Vector3).distance_to(here) > root.REMOTE_AVATAR_PRUNE_RADIUS:
			_remove_remote_avatar(int(peer_id))

func _remove_remote_avatar(peer_id: int) -> void:
	if root._remote_avatars.has(peer_id):
		root._character.remove_character(str(root._remote_avatars[peer_id]))
		root._remote_avatars.erase(peer_id)
		root._player.set_ghost_suppressed(peer_id, false)

func on_remote_player_state(peer_id: int, position: Vector3) -> void:
	if root._is_client:
		return
	# A non-finite or absurd claim is dropped before ANY consumer reads it (the region lookup
	# below included); a planet is far smaller than MAX_CLAIMED_COORD.
	if not root._is_plausible_position(position):
		return
	var region: Vector2i = root._networking.aoi_region(position)
	if root._peer_aoi_regions.get(peer_id, null) == region:
		return
	# Phase 109 — a re-scope carries generation records, and a snapshot without them is never resent
	# for that crossing, so inside the interval the whole re-scope waits for the next state packet.
	if Time.get_ticks_msec() - int(root._peer_records_msec.get(peer_id, -root.RECORDS_RESCOPE_INTERVAL_MSEC)) < root.RECORDS_RESCOPE_INTERVAL_MSEC:
		return
	root._peer_aoi_regions[peer_id] = region
	# Phase 62 — re-centre the peer's window and make the regions around the new position
	# resident BEFORE the snapshot is built, as the join path does: a teleport into a region
	# with stored edits must carry those edits in the re-scope snapshot. The re-centre is
	# rate-limited and clamped (`set_peer_center`), so this cannot be used to flood reads.
	# When the window could not reach the target yet (refused or clamped) the snapshot would
	# miss the destination's edits: forget the crossing so the next state packet retries it.
	if root._chunk_manager != null and root._registry.get_player_id(peer_id) != "":
		var target: Vector2i = root._chunk_manager.world_to_chunk(Vector2(position.x, position.z))
		if root._chunk_manager.set_peer_center(peer_id, target):
			root._chunk_manager.refresh(false)
		# The window centre is stored wrapped past the seam; compare like with like. A move that was
		# refused or clamped builds no snapshot (it would miss the destination's edits): the crossing is
		# forgotten and the next state packet retries it once the window has caught up.
		if root._chunk_manager.peer_center(peer_id) != TerrainSlice.wrap_chunk(target):
			root._peer_aoi_regions.erase(peer_id)
			return
	# Phase 33 — world/entity data only: the peer's own record is NOT re-sent, or
	# the client would re-apply a stale position/HP/inventory on every region
	# crossing (the record is written at load and at disconnect, not per frame).
	# The crossing position is passed explicitly: this handler may run before the
	# networking slice's own handler has recorded it, so get_aoi_center() can be stale.
	root._networking.send_snapshot(peer_id, root._snapshot_wiring.build_snapshot(peer_id, false, position, false))

## The chunk a peer's window is centred on: its last reported position, else the position
## its record holds (a joining peer has not sent a state packet yet).
func peer_window_chunk(peer_id: int) -> Vector2i:
	if root._networking.has_last_known_state(peer_id):
		# Phase 97 — the exact chunk when the peer reported one; the float32 Vector3 only as fallback.
		# (The slice only stores an exact position that decoded and validated, so it is trusted here.)
		var exact: Dictionary = root._networking.get_last_known_exact(peer_id)
		if not exact.is_empty():
			return exact["chunk"]
		var p: Vector3 = root._networking.get_last_known_state(peer_id)
		return root._chunk_manager.world_to_chunk(Vector2(p.x, p.z))
	var player_id := root._registry.get_player_id(peer_id)
	if player_id.is_empty():
		return root._chunk_manager.player_chunk()
	return root._registry.get_world_pos(player_id)["chunk"]

## Phase 52 — keep one streaming window per connected peer, so creatures, trees and edit
## validation run around every player and not only near the server's own body. Throttled:
## a window moves by whole chunks, so twice a second is ample.
func sync_peer_windows(delta: float) -> void:
	root._peer_window_elapsed += delta
	if root._peer_window_elapsed < root.PEER_WINDOW_INTERVAL:
		return
	root._peer_window_elapsed = 0.0
	for peer_id in root._registry.get_peer_ids():
		if int(peer_id) > 0:
			root._chunk_manager.sync_peer_center(int(peer_id), peer_window_chunk(int(peer_id)))

func fold_local_player() -> void:
	if not root._player.has_method("fold_to"):
		return
	_expire_fold_standins()
	if root._player.ground_hold:
		_release_fold_hold()
		return
	var fold := TerrainSlice.fold_world_pos(root._player.get_world_pos())
	if not fold["folded"]:
		return
	var pos: Dictionary = fold["pos"]
	var turned: bool = fold["turned"]
	var before: Vector3 = root._player.get_scene_position()
	var pole_sign := 1 if (root._player.get_world_pos()["chunk"] as Vector2i).y >= 0 else -1
	# Phase 145 — what the window holds is carried across the fold, not despawned with it: re-keyed here
	# on this peer's own view (the host's state stays canonical), placed once the scene has rebased.
	root._creature.fold_contents(turned, pole_sign)
	root._tree.fold_contents(turned, pole_sign)
	var standins: Array = root._voxel.detach_standins() if root._voxel != null else []
	var ring: Node3D = root._distant.detach_ring() if root._distant != null and root._distant.has_method("detach_ring") else null
	if root._chunk_manager != null:
		root._chunk_manager.restream()
	root._rebase.rebase_to(pos["chunk"])
	root._creature.place_after_fold()
	root._tree.place_after_fold()
	root._player.fold_to(pos, turned)
	if turned:
		root._sun_turned = not root._sun_turned
	var xform := TerrainSlice.fold_scene_transform(before, root._player.get_scene_position(), turned)
	if ring != null:
		ring.transform = xform * ring.transform
	if root._voxel != null:
		root._voxel.adopt_standins(standins, xform)
		root._fold_standins_since_msec = Time.get_ticks_msec()
	if root._chunk_manager != null:
		# Queue the folded window now, and drop the stand-ins it does not cover: nothing rebuilds them.
		root._chunk_manager.refresh(false)
		var covered := func(c: Vector2i) -> bool: return root._chunk_manager.chunk_ref_count(c) > 0
		root._creature.prune_carried(covered)
		root._tree.prune_carried(covered)
		if root._voxel != null:
			root._voxel.prune_standins(func(c: Vector2i) -> bool: return root._chunk_manager.chunk_ref_count(c) > 0)
		if root._voxel == null or not root._voxel.has_standin(pos["chunk"]):
			root._player.ground_hold = true
			root._fold_hold_extended = false
			root._fold_hold_since_msec = Time.get_ticks_msec()

func _expire_fold_standins() -> void:
	if root._voxel == null or root._voxel.standin_count() == 0:
		return
	if Time.get_ticks_msec() - root._fold_standins_since_msec > root.FOLD_STANDIN_MAX_MSEC:
		root._voxel.release_standins()

func _release_fold_hold() -> void:
	var waited := Time.get_ticks_msec() - root._fold_hold_since_msec
	if root._chunk_manager.is_chunk_built(root._player.get_world_pos()["chunk"]):
		root._fold_hold_extended = false
		root._player.ground_hold = false
	elif waited > root.FOLD_HOLD_MAX_MSEC:
		# A stalled build is retried once and the hold extended once; then it is given up so it cannot pin the player.
		root.fold_hold_retries += 1
		root._chunk_manager.refresh(false)
		if not root._fold_hold_extended:
			root._fold_hold_extended = true
			root._fold_hold_since_msec = Time.get_ticks_msec()
			return
		root._fold_hold_extended = false
		root._player.ground_hold = false

## Client-side: wait for the host's world snapshot, re-presenting the join intent
## while it does not arrive. The handshake is the only route to an identity and a
## world, and it used to be fire-and-forget: one lost join_intent — or one lost
## snapshot — left a fully connected client with nothing and no way to ask again.
## Each retry re-sends the intent (a fresh seq, so the host's dedup passes it) and
## the host re-answers an already-bound peer (see
## PlayerRegistry.resolve_identity), so the retry re-delivers the snapshot.
func tick_client_handshake(delta: float) -> void:
	root._snapshot_elapsed += delta
	root._handshake_elapsed += delta
	# Phase 135 — a delayed, capped link (`--net-profile`) stretches the deadlines by its round trip.
	var scale: float = root._networking.link_time_scale()
	if root._handshake_elapsed >= root.HANDSHAKE_RETRY_SECS * scale and root._handshake_retries < root.MAX_HANDSHAKE_RETRIES:
		root._handshake_elapsed = 0.0
		root._handshake_retries += 1
		Diag.warn("[Networking] no world snapshot after %.1fs — re-presenting join intent (retry %d/%d)" % [
			root.HANDSHAKE_RETRY_SECS * scale, root._handshake_retries, root.MAX_HANDSHAKE_RETRIES])
		root._networking.request_handshake()
	if root._snapshot_elapsed >= root.SNAPSHOT_TIMEOUT * scale:
		Diag.error("[Networking] world snapshot timed out after %.1fs — giving up" % (root.SNAPSHOT_TIMEOUT * scale))
		root._snapshot_pending = false

## Drive the player's visual avatar from the real player controller every
## frame — position/facing, locomotion state, and approximate foot IK
## (characters.md §37). Only the host currently spawns character visuals
## (_boot_host), so this is a no-op on clients until one exists.
func sync_player_avatar(delta: float) -> void:
	var player_char: String = root._character.get_player_character()
	if player_char == "":
		return
	var vel: Vector3 = root._player.get_velocity()
	var pos: Vector3 = root._player.get_position()
	# The avatar's feet are driven by the surface the BODY actually stands on: the
	# voxel columns carry the collision (layer 2) and are quantised to
	# STEP_HEIGHT, so sampling `_terrain`'s raw noise heightmap floated the visual
	# avatar off its own collision surface by up to a step. The voxel sampler is
	# the same function the collision is built from.
	#
	# Phase 41 — it is a function of the body's own Y as well: a column's TOP is
	# the ROOF of a tunnel, so a column-top sampler would stand the avatar on the
	# ceiling it is walking under. The body's Y is closed over per frame.
	var foot_sampler := func(xz: Vector2) -> float:
		return root._voxel.sample_support_height_at(xz, pos.y)
	root._character.sync_player_avatar(
		player_char,
		pos,
		Vector3(vel.x, 0.0, vel.z),
		vel.y,
		root._player.is_grounded(),
		delta,
		foot_sampler,
		root._player.get_scene_position()
	)

func _on_connection_failed() -> void:
	if not root._is_client:
		return
	Diag.error("[Networking] connection to host failed")
	root._snapshot_pending = false

func _on_server_disconnected() -> void:
	if not root._is_client:
		return
	Diag.error("[Networking] disconnected from host")
	root._snapshot_pending = false
	if root._creature != null:
		root._creature.reset_fold_log()

## Host → the peer whose own record just changed. Nothing to do for a local player
## (its state is already live in this process) and nothing to send for a failed
## action (nothing changed).
func sync_peer_own_state(result: Dictionary, changed_anyway: bool = false) -> void:
	if root._is_client:
		return
	if not bool(result.get("success", false)) and not changed_anyway:
		return
	var pid := str(result.get("player_id", ""))
	if pid == "" or pid == root._registry.local_player_id:
		return
	var peer := root._registry.get_peer_id(pid)
	if peer == 0:
		return
	root._networking.send_own_state(peer, _own_state_payload(pid))

## The slice of `player_id`'s record its own client mirrors: inventory contents with
## per-instance durability, plus its technology statuses. Position and HP are
## deliberately absent — they are host-simulated and ride the normal player-state
## path, and re-sending a stored position here would teleport the peer back to it.
func _own_state_payload(player_id: String) -> Dictionary:
	var own := root._registry.get_player_data(player_id)
	return {
		"inventory": own.get("inventory", {}),
		"inventory_durability": own.get("inventory_durability", {}),
		"technology": own.get("technology", {}),
		"flags": own.get("flags", {}),
		"companions": own.get("companions", []),
		"professions": own.get("professions", {}),
	}

## Client-side: the host changed our own record while acting on our behalf (a craft,
## repair, or research we asked for). Applied exactly like the like-named keys of the
## join snapshot.
func on_own_state_synced(data: Dictionary) -> void:
	if not root._is_client:
		return
	if data.has("equipment") and data["equipment"] is Dictionary:
		# Phase 70 — a correction that answers an action older than the newest one sent
		# would wipe the newer item; the newer action's own reply sets the record.
		var answers: int = int(data.get("equipment_seq", root._networking.equip_seq_sent()))
		if answers >= root._networking.equip_seq_sent():
			root._character_wiring.apply_host_equipment(data["equipment"])
	if data.has("inventory") and data["inventory"] is Dictionary:
		root._inventory.replace_contents(data["inventory"], data.get("inventory_durability", {}))
	if data.has("technology") and data["technology"] is Dictionary:
		root._technology.apply_statuses(data["technology"], root._registry.local_player_id)
	if data.has("flags") or data.has("companions"):
		# Phase 35 — the same own-state route carries the taming flags and the
		# companion bindings a host resolved on our behalf.
		root._taming.apply_record({
			"flags":      data.get("flags", {}),
			"companions": data.get("companions", []),
		}, root._registry.local_player_id)
	if data.has("professions"):
		root._professions.apply_record({ "professions": data["professions"] }, root._registry.local_player_id)
	if data.has("waystones") and data["waystones"] is Array:
		root._waystones.apply_view(data["waystones"])
		GameBus.waystones_synced.emit(root._registry.local_player_id, data["waystones"])
	if data.get("waystone_result", null) is Dictionary:
		var res: Dictionary = data["waystone_result"]
		GameBus.waystone_travel_resolved.emit(root._registry.local_player_id, bool(res.get("ok", false)), str(res.get("reason", "")).left(32))
	if data.get("settlement_view", null) is Dictionary:
		root._settlements.apply_view(data["settlement_view"])
	if data.get("settlement_result", null) is Dictionary:
		var sres: Dictionary = data["settlement_result"]
		GameBus.settlement_resolved.emit(root._registry.local_player_id, str(sres.get("action", "")).left(16), bool(sres.get("ok", false)), str(sres.get("reason", "")).left(32))

## Phase 130 — true while the host's own status state holds `peer` (paralysis, knockdown).
func peer_is_held(peer: int) -> bool:
	if root._status == null or root._is_client:
		return false
	var pid := root._networking.get_player_id(peer)
	return pid != "" and root._status.is_immobilized(pid, root._combat_wiring.status_now())
