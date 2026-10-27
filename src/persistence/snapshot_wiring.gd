extends "res://src/core/wiring.gd"
## Snapshot wiring (Phase 132) — World snapshot: host build and client apply.
## Moved out of game_root.gd; `root` is the GameRoot that owns the slices.

const WorldPos := preload("res://src/terrain/world_pos.gd")
const Diag := preload("res://src/core/diag.gd")
const WorldShape       := preload("res://src/terrain/world_shape.gd")
const ChunkManager     := preload("res://src/terrain/chunk_manager.gd")
const ChunkRecordSync  := preload("res://src/terrain/chunk_record_sync.gd")
const ChunkRecords     := preload("res://src/terrain/chunk_records.gd")
const CreatureSlice    := preload("res://src/creature/creature_slice.gd")
const NetworkingSlice  := preload("res://src/networking/networking_slice.gd")
const PersistenceSlice := preload("res://src/persistence/persistence_slice.gd")
const PlayerRegistry   := preload("res://src/persistence/player_registry.gd")
const PlayerSlice      := preload("res://src/player/player_slice.gd")
const TreeSlice        := preload("res://src/world/tree_slice.gd")

func _connect_all() -> void:
	connect_bus(GameBus.world_snapshot_received, on_world_snapshot_received)

## Host-side: serialize authoritative world state for a connecting client,
## AOI-scoped (Phase 29) — only entities within the peer's area of interest are
## sent, so the initial payload scales with local density, not world population.
##
## Phase 33 — the inventory half is the CONNECTING PEER's own record, not the
## host's: inventory is per-player now, and shipping the host's contents would
## hand every client the host's items.
##
## `include_own_record` is TRUE only for the join/reconnect snapshot. The record is
## a durability artifact, not a live feed (see
## PersistenceSlice.snapshot_carries_own_record), and the client applies whatever
## it receives as authoritative — so carrying a stale record on an AOI re-scope
## would teleport the client to its last-saved position and roll its inventory and
## technology back to that instant.
func build_snapshot(peer_id: int, include_own_record: bool = true,
		aoi_center_override: Variant = null, full_edits_override: Variant = null) -> Dictionary:
	# Every AOI test below reads the SAME centre: the override when a re-scope names the
	# crossing position (the networking slice may not have recorded it yet), else the peer's
	# last known one.
	var aoi_center: Vector3 = root._networking.get_aoi_center(peer_id)
	var aoi_exact: Dictionary
	if aoi_center_override is Vector3:
		aoi_center = aoi_center_override
		aoi_exact = WorldPos.from_world(aoi_center.x, aoi_center.y, aoi_center.z)
	elif root._networking.has_last_known_state(peer_id):
		aoi_exact = root._peer_wiring.peer_exact_pos(peer_id)
	else:
		aoi_exact = WorldPos.from_world(aoi_center.x, aoi_center.y, aoi_center.z)
	var players := {}
	# Phase 122 — scoped on exact positions, so a far-from-origin peer sees who is really near.
	if NetworkingSlice.within_aoi_exact(aoi_exact, root._player.get_world_pos()):
		players[str(root.multiplayer.get_unique_id())] = WorldPos.pos_to_wire(root._player.get_world_pos())
	# Phase 19 — include last-known remote player states so a rejoining client
	# resumes from its last authoritative position after a disconnect.
	var last_known := root._networking.get_last_known_states()
	for pid in last_known:
		var last_pos: Vector3 = last_known[pid]
		var last_exact := root._peer_wiring.peer_exact_pos(int(pid))
		if NetworkingSlice.within_aoi_exact(aoi_exact, last_exact):
			players[str(pid)] = WorldPos.pos_to_wire(last_exact) if root._networking.get_last_known_exact(int(pid)) == last_exact else WorldPos.to_wire(last_pos)
	var player_id := root._registry.get_player_id(peer_id)
	# A join/reconnect snapshot (own record included) carries the full edit manifest: the
	# peer's real position may be unknown (AOI centre defaults to spawn). Re-scopes send
	# only the edits within EDITS_SCOPE_RADIUS and name that scope. The two are separate
	# decisions that happen to coincide today, so the manifest scope has its own parameter.
	var full_edits: bool = include_own_record if not (full_edits_override is bool) else full_edits_override
	var snapshot := {
		# Phase 41 — the world's SEED, not its heightmaps: the client regenerates
		# the host's terrain from the same noise field instead of receiving every
		# column of every loaded chunk. It is the world's identity, so it is small,
		# exact, and the only thing that has to travel.
		"seed":      root._terrain.get_world_seed(),
		# Phase 54 — the host's clock, so the client starts in step and only slews afterwards.
		"clock":     root._clock.to_data(),
		# Phase 128 — the host's weather overrides; the weather itself is computed from the seed.
		"weather":   root._weather.to_data(),
		# Phase 49 — only the edits of chunks inside the peer's AOI, with the scope named so
		# the client keeps what it holds outside it.
		"edits":     (root._voxel.get_chunk_manifest() if full_edits
				else root._voxel.get_chunk_manifest_in_radius(aoi_center, NetworkingSlice.EDITS_SCOPE_RADIUS)),
		"creatures": _scoped_creatures(aoi_center),
		"stations":  root._station.get_station_data(),
		"players":   players,
	}
	# Phase 36/38 — the social/economy state the snapshot carries is redacted the same
	# way the deltas are (the listings' sellers, the trades' parties and the proposals'
	# authors/voters reach a client as public handles, never as the player ids those
	# records are claimed by), and it travels under exactly the keys the receiving side
	# walks to adopt its OWN handle — `NetworkingSlice.IDENTIFIED_STATE_KEYS`. Iterating
	# that one list is what keeps the two halves from drifting: three literals here and
	# the constant there were two places to update, and the failure mode was a blob a
	# client would adopt but nobody would redact.
	snapshot.merge(root._networking.redact_social_state(_social_state()))
	add_generation_records(snapshot, peer_id, aoi_center, not include_own_record)
	if not full_edits:
		snapshot["edits_aoi"] = [aoi_center.x, aoi_center.z, NetworkingSlice.EDITS_SCOPE_RADIUS]
	# The peer's own record exists only once the host resolved its identity, and it
	# is shipped only on the handshake snapshot — an AOI re-scope omits the keys
	# entirely, so the client keeps the state it already holds.
	if PersistenceSlice.snapshot_carries_own_record(include_own_record, player_id):
		snapshot.merge(snapshot_own_record(player_id))
	return snapshot

## The peer's own record as the handshake snapshot carries it (`inventory`, `technology`, `flags`,
## `companions`, `equipment`, `player` and, when one is recorded, the original `spawn`).
func snapshot_own_record(player_id: String) -> Dictionary:
	var own := root._registry.get_player_data(player_id)
	var snapshot := {}
	snapshot["inventory"] = own.get("inventory", {})
	snapshot["inventory_durability"] = own.get("inventory_durability", {})
	snapshot["technology"] = own.get("technology", {})
	# Phase 35 — taming flags (`wolfBondHolder`) and the companion bindings are
	# part of the peer's own record, so they ride the same own-record payload.
	snapshot["flags"] = own.get("flags", {})
	snapshot["companions"] = own.get("companions", [])
	snapshot["professions"] = own.get("professions", {})
	snapshot["attributes"] = own.get("attributes", {})
	snapshot["waystones"] = own.get("waystones", [])
	# Phase 47 — the worn set rides the own-record payload too.
	snapshot["equipment"] = own.get("equipment", {})
	# The stored exact {chunk, local} goes out as stored, no float round trip (Phase 78); a legacy
	# float-array record is re-encoded, and a record with no position stays empty so the client
	# leaves its spawn alone.
	var own_pos = PlayerRegistry.snapshot_position(own)
	snapshot["player"] = { "position": own_pos, "hp": own.get("hp", -1.0) }
	# Phase 66 — the original spawn point, so a reconnecting client respawns there and not
	# where it happened to be standing when it rejoined.
	if own.has("spawn"):
		snapshot["player"]["spawn"] = own["spawn"]
	return snapshot

## Phase 163 — host: peer id -> { record key -> hash }, the generation records that peer holds.
var records_sent: Dictionary = {}

## Send a snapshot built by `build_snapshot`. Building it already advanced `records_sent` to the new
## scope; a snapshot that did not go out whole never reaches the client, so the peer's entry is
## forgotten and its next re-scope carries every record again (#444).
func send_snapshot(peer_id: int, snapshot: Dictionary) -> bool:
	var sent: bool = root._networking.send_snapshot(peer_id, snapshot)
	if not sent:
		records_sent.erase(peer_id)
	return sent

## Phase 109 — the generation records of the chunks in the peer's streamed window plus its first ring.
## The scope is named (`gen_scope`) so the client knows which part of its table the packet speaks for.
## Re-scopes are rate-limited by `_on_remote_player_state`, which defers the whole crossing rather than
## sending it without records.
##
## Phase 163 — a re-scope (`delta`) carries only the records this peer was not sent at its last scope, or
## that changed since: the client keeps every record inside the new scope, so resending them was the bulk
## of `snapshot_chunk` bytes on every AOI crossing. `records_sent` mirrors what the client
## holds (key -> record hash, pruned to the scope like the client's table); a join starts it afresh.
func add_generation_records(snapshot: Dictionary, peer_id: int, aoi_center: Vector3, delta: bool = false) -> void:
	if root._chunk_manager == null:
		return
	var now := Time.get_ticks_msec()
	var center: Vector2i = root._chunk_manager.world_to_chunk(Vector2(aoi_center.x, aoi_center.z))
	var radius: int = root._chunk_manager.stream_radius() + ChunkManager.FIRST_RING_RADIUS
	var found := ChunkRecordSync.records_in_window(center, radius)
	if bool(found["truncated"]):
		Diag.warn("GameRoot: generation records for peer %d truncated at the %d-record packet cap" % [peer_id, ChunkRecordSync.PACKET_CAP])
	snapshot["gen_scope"] = [center.x, center.y, radius]   # always named: a client prunes to it
	root._peer_records_msec[peer_id] = now   # the window was served, records or not: the re-scope interval counts from here
	var held: Dictionary = records_sent.get(peer_id, {}) if delta else {}
	var records: Dictionary = found["records"]
	var sent := {}
	var out := {}
	for key in records:
		var h := hash(records[key])
		sent[key] = h
		if held.get(key) != h:
			out[key] = records[key]
	records_sent[peer_id] = sent
	if out.is_empty():
		return   # no records to attach
	snapshot["gen_records"] = out

## Phase 38 — the replicated social/economy state, keyed by the names the wire uses
## (`NetworkingSlice.IDENTIFIED_STATE_KEYS`).
##
## One mapping, so the snapshot needs no literals of its own: a fourth social slice is
## added HERE and its key added to that constant, and both the redaction the snapshot
## does and the identity walk the receiving client does pick it up. The three keys are
## still named in exactly one place each — this table says where the data lives, the
## constant says which blobs carry identities.
func _social_state() -> Dictionary:
	return {
		"market":     root._market.get_market_data(),
		"governance": root._proposal.get_governance_data(),
		"trade":      root._trade.get_trade_data(),
	}

## Phase 29 — the creature subset of the snapshot, filtered to the joining
## peer's AOI so a client seeds only the population it can actually see.
func _scoped_creatures(aoi_center: Vector3) -> Array:
	var out: Array = []
	for c in root._creature.get_snapshot_creatures():
		var pos := WorldPos.from_wire(c.get("position", []))
		if NetworkingSlice.within_aoi(aoi_center, pos):
			out.append(c)
	return out

## Client: put the body where the snapshot's `player` record says (exactly, via a rebase, when the
## position is a `{chunk, local}` record) and restore its HP. Anything but a dictionary is ignored.
func place_from_snapshot(own: Variant) -> void:
	if own is Dictionary:
		var arr = own.get("position", [])
		if WorldPos.is_wire(arr):
			if arr is Dictionary and root._rebase != null:
				# Exact placement: rebase to the target chunk, then land on its small local offset.
				var l: Array = arr["local"]
				var exact := WorldPos.normalized({"chunk": WorldPos.wire_chunk(arr),
					"local": Vector3(float(l[0]), float(l[1]), float(l[2]))})
				exact = PlayerRegistry.canonical_world_pos(exact)   # Phase 122 — a row past the pole folds first
				root._rebase.rebase_to(exact["chunk"])
				root._player.place_at_world_pos(exact)
			else:
				root._player.spawn_at(WorldPos.from_wire(arr))
			if not root._client_respawn_point_set:
				# Only the first snapshot carries the placement; later AOI re-scoped snapshots
				# carry wherever the player has since walked, which is not a spawn point.
				root._player.set_respawn_world_pos(root.client_respawn_point(own, root._player.get_world_pos()))
				root._client_respawn_point_set = true
		elif (arr is Array and not (arr as Array).is_empty()) or arr is Dictionary:
			# Phase 122 — a position that is not a valid wire position (forged, corrupt or from a newer
			# build) spawns the body at the spawn point instead of leaving it wherever it booted.
			Diag.warn("GameRoot: snapshot position refused; spawning at the spawn point")
			if root._rebase != null:
				root._rebase.rebase_to(Vector2i.ZERO)
			root._player.place_at_world_pos(WorldPos.from_world(WorldShape.SPAWN_CENTER.x, root._terrain.get_height_at(WorldShape.SPAWN_CENTER) + 1.0, WorldShape.SPAWN_CENTER.y))
		var hp := float(own.get("hp", -1.0))
		if hp >= 0.0:
			root._player.set_hp(hp)

## Client-side: apply the host's world snapshot and begin rendering.
func on_world_snapshot_received(data: Dictionary) -> void:
	if not root._is_client:
		return
	if data.has("seed"):
		# Phase 41 — adopt the host's world seed BEFORE anything is streamed (a
		# chunk built from this machine's own random seed would be a different
		# world, and every voxel edit the host sends would land elsewhere).
		root._terrain.set_world_seed(int(data["seed"]))
	if data.has("clock"):
		root._clock.from_data(data["clock"])
	if data.has("weather"):
		root._weather.apply_view(data["weather"])
	# Phase 109 — the host's generation records, BEFORE `_chunk_manager.start()` below builds from them;
	# a malformed one is dropped, anything past the packet cap is refused.
	if data.has("gen_records") or data.has("gen_scope"):
		var rev_before := ChunkRecords.content_revision()
		# Phase 114 — the table is pruned to the host's scope first, so it never outgrows one window.
		var pruned: Array = []
		if data.has("gen_scope"):
			ChunkRecordSync.prune_to_scope(data["gen_scope"], pruned)
			root._tree.set_clear_scope(data["gen_scope"])   # Phase 126 — the clear range is the scope's radius
		var gen_result := ChunkRecordSync.apply(data.get("gen_records", {}))
		if ChunkRecords.content_revision() != rev_before:
			root._tree.resync_recorded_chunks()   # Phase 110 — a record may carry a budget or cleared trees
		# A record that arrives after its chunk was built (a re-scope) changes the ground: rebuild it.
		# A pruned record means its loaded chunk now draws from the generator: rebuild that too.
		if root._chunk_manager != null:
			var rebuilt := {}
			for c in gen_result["changed"] + pruned:
				if not rebuilt.has(c) and root._chunk_manager.is_chunk_built(c):
					rebuilt[c] = true
					root._chunk_manager.request_rebuild(c)
		if int(gen_result["dropped"]) > 0 or int(gen_result["refused"]) > 0:
			Diag.warn("GameRoot: generation records: %d applied, %d dropped, %d refused" % [
				int(gen_result["applied"]), int(gen_result["dropped"]), int(gen_result["refused"])])
	if data.has("edits") and data["edits"] is Dictionary:
		var scope: Variant = data.get("edits_aoi", null)
		if scope is Array and scope.size() >= 3:
			root._voxel.apply_scoped_chunk_manifest(data["edits"],
				Vector3(float(scope[0]), 0.0, float(scope[1])), float(scope[2]))
		else:
			root._voxel.apply_chunk_manifest(data["edits"])
	# Phase 33 — stations and the client's OWN record (position / HP /
	# technologies). Stations are world data, so a client mirrors the host's set.
	if data.has("stations") and data["stations"] is Array:
		root._station.apply_station_data(data["stations"])
	if data.has("technology") and data["technology"] is Dictionary:
		# A client has no registry identity: its own tree is the only one it holds,
		# which is the "" bucket resolve_player() falls back to.
		root._technology.apply_statuses(data["technology"], root._registry.local_player_id)
	if data.has("flags") or data.has("companions"):
		# Phase 35 — the peer's own taming record, same "" bucket rule as above.
		root._taming.apply_record({
			"flags":      data.get("flags", {}),
			"companions": data.get("companions", []),
		}, root._registry.local_player_id)
	if data.has("professions"):
		root._professions.apply_record({ "professions": data["professions"] }, root._registry.local_player_id)
	if data.get("attributes", null) is Dictionary:
		root._peer_wiring.apply_own_attributes(data["attributes"])
	if data.get("attribute_growth", null) is Dictionary and root._player != null:
		root._player.set_attribute_growth(data["attribute_growth"])
	root._waystone_wiring.apply_own_view(data)
	if data.has("equipment") and data["equipment"] is Dictionary:
		# A client builds no avatar at boot, so the first snapshot creates it; without
		# one there is nothing to wear the set, to show in the Character window, or to
		# forward equipment intents from.
		if root._character.get_player_character() == "":
			var client_char: String = root._character.create_character("TravellerHuman", root._player.get_position())
			root._character.set_player_character(client_char)
			root._character.attach_default_rig(client_char)
		root._character_wiring.apply_local_equipment(data["equipment"])
	place_from_snapshot(data.get("player", {}))
	if data.has("creatures") and data["creatures"] is Array:
		root._creature.apply_snapshot_creatures(data["creatures"])
	if data.has("inventory") and data["inventory"] is Dictionary:
		root._inventory.replace_contents(data["inventory"], data.get("inventory_durability", {}))
	if data.has("market") and data["market"] is Dictionary:
		root._market.apply_market_data(data["market"])
	if data.has("governance") and data["governance"] is Dictionary:
		root._proposal.apply_governance_data(data["governance"])
	if data.has("trade") and data["trade"] is Dictionary:
		root._trade.apply_trade_data(data["trade"])
	if data.has("players") and data["players"] is Dictionary:
		for pid in data["players"]:
			var pos = data["players"][pid]
			if WorldPos.is_wire(pos):
				GameBus.remote_player_state.emit(int(pid), WorldPos.from_wire(pos))
	# Phase 41 — the client streams its OWN chunks now, from the seed above and
	# around the position the snapshot just restored, because the snapshot no
	# longer carries heightmaps to build them from. TREES need no placement payload
	# for it: `TreeSlice.spawn_for_chunk` derives every tree from the chunk
	# coordinate on either side, and only a tree's chopped/standing STATE is
	# replicated. CREATURES are the host's to place — the snapshot still carries
	# them (`apply_snapshot_creatures`, above), because `CreatureSlice.spawn_for_chunk`
	# refuses to run on a non-authoritative slice.
	root._chunk_manager.start()
	# Phase 42 review — the CLIENT arms the same first-ring gate the host does, instead of
	# placing the body from the snapshot into a world whose ground is still being built on
	# a worker. The body is spawned from the snapshot ABOVE (so `player_chunk()` names the
	# ground it will stand on and the streaming window centres on it), and it is held still
	# by the loading screen's freeze until the ring is built (see `PlayerSlice`).
	root._chunk_manager.build_first_ring(root._chunk_manager.player_chunk())
	root._chunk_manager.refresh()
	root._snapshot_pending = false
	# Phase 42 review pass 11 — a re-scope snapshot (the join is already released, or its
	# wait is still running) keeps the ring's head start above but never (re)starts the
	# wait: that popped the loading screen mid-game and reset a running wait's timeout.
	if root._client_boot_done or root._pending_client_boot:
		return
	if root._chunk_manager.is_first_ring_ready():
		root._finish_client_boot()
		return
	root._loading_screen.begin()
	root._client_boot_wait_elapsed = 0.0
	root._pending_client_boot = true

# ---------------------------------------------------------------------------
# Phase 33 — authoritative persistence lifecycle
# ---------------------------------------------------------------------------
