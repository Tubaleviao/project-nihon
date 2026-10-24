extends RefCounted
## Methods moved verbatim out of `networking_slice.gd` (Phase 154). `sl` is the owning slice; each moved method keeps a forwarder there.

var sl: Node

func _init(slice: Node) -> void:
	sl = slice

## Start an authoritative ENet server. Sets the slice to HOST role.
## Prints one boot line on success (the same line a dedicated server and a
## listen host both emit) so CI can assert the server actually came up rather
## than merely failing to crash.
func host(port: int = sl.DEFAULT_PORT, max_clients: int = sl.DEFAULT_MAX_CLIENTS) -> Error:
	sl._peer = ENetMultiplayerPeer.new()
	var err = sl._peer.create_server(port, max_clients)
	if err != OK:
		sl.Diag.error("NetworkingSlice: failed to create server on port %d — %s" % [port, error_string(err)])
		return err
	sl._role = sl.Role.HOST
	sl._attach_peer()
	print("[Server] listening on port %d, max_clients %d" % [port, max_clients])
	return OK

## Phase 171 — the exact position a `creature_state_changed` packet carries (compact `pk`, else the wire
## `position`; a legacy float array is split). A packet whose `pk` does not decode is empty (the caller drops it).
func _creature_wire_pos(sl_: Node, payload: Dictionary) -> Dictionary:
	var exact: Dictionary = sl_.WorldPos.pos_from_packet(payload)
	if not exact.is_empty():
		return exact
	if payload.has("pk"):
		return {}
	var w: Vector3 = sl_.WorldPos.packet_world(payload, sl_._vec3(payload.get("position", [])))
	return sl_.WorldPos.from_world(w.x, w.y, w.z)

## Host → one client: send the initial world snapshot, split into fixed-size
## chunks so a large world (the chunk-edit manifest + creatures + the peer's own
## record) never exceeds a single reliable packet. Since Phase 41 the terrain
## itself is NOT in the payload — the snapshot carries the world `seed` and the
## client regenerates the ground from it. The client reassembles chunks by
## snapshot_id.
func send_snapshot(peer_id: int, data: Dictionary) -> void:
	if not sl._role == sl.Role.HOST:
		sl.Diag.warn("NetworkingSlice: send_snapshot called on non-host — dropped")
		return
	var json := JSON.stringify(data)
	var chunk_count = maxi(1, ceili(float(json.length()) / float(sl.SNAPSHOT_CHUNK_SIZE)))
	var snapshot_id: int = sl._next_snapshot_id
	sl._next_snapshot_id += 1
	for i in range(chunk_count):
		var packet := {
			"type":        "snapshot_chunk",
			"snapshot_id": snapshot_id,
			"index":       i,
			"count":       chunk_count,
			"data":        json.substr(i * sl.SNAPSHOT_CHUNK_SIZE, sl.SNAPSHOT_CHUNK_SIZE),
		}
		sl._deliver(peer_id, packet)

## Central outbound path (Phase 19). Attach a per-type monotonic seq, then
## either send immediately (emulation disabled — zero overhead) or queue for
## emulated delivery (loss / jitter / reorder).
## True when the packet was sent or queued; false when the emulator dropped it.
func _deliver(peer_id: int, payload: Dictionary) -> bool:
	var transport = sl._ensure_transport()
	if not transport.stamps_seq:
		transport.send(peer_id, payload)
		return true
	var ptype: String = str(payload.get("type", "_"))
	if not sl._send_seq.has(ptype):
		sl._send_seq[ptype] = 0
	payload["seq"] = sl._send_seq[ptype]
	sl._send_seq[ptype] += 1
	if not sl.emulate_network:
		transport.send(peer_id, payload)
		return true
	var retransmit_delay_ms := 0.0
	if sl._should_drop():
		if not sl.emulator_retransmit:
			return false
		# One retransmission timeout: a round trip plus the jitter allowance, then it is sent again.
		retransmit_delay_ms = 2.0 * (maxf(0.0, sl.emulator_latency_ms) + sl.emulator_jitter_ms) + 50.0
		sl.emulator_retransmits += 1
	# A serialised copy: the caller may reuse or mutate `payload` before the delayed delivery.
	var json := JSON.stringify(payload)
	var at_ms: float = sl._schedule_at_ms(float(Time.get_ticks_msec()), json.to_utf8_buffer().size(), peer_id) \
			+ retransmit_delay_ms
	if sl.emulator_retransmit:
		at_ms = maxf(at_ms, float(sl._ordered_at_ms.get(peer_id, 0.0)))
		sl._ordered_at_ms[peer_id] = at_ms
	sl._pending.append({ "at_ms": at_ms, "peer_id": peer_id, "payload": json })
	if sl.emulator_reorder:
		sl._maybe_reorder()
	return true

## Phase 85 — host → one client: move that player's body to `position` (an admin teleport).
func send_teleport(peer_id: int, position: Dictionary) -> bool:
	if sl._role != sl.Role.HOST:
		sl.Diag.warn("NetworkingSlice: send_teleport called on non-host — dropped")
		return false
	if sl._peer == null and sl._transport == null:
		return false
	if not sl._connected_peers().has(peer_id):
		return false
	if not sl._deliver(peer_id, { "type": "teleport", "position": sl.WorldPos.pos_to_wire(position) }):
		return false
	if position.get("chunk") is Vector2i and position.get("local") is Vector3:
		sl._teleport_pending[peer_id] = { "pos": sl.WorldPos.normalized(position), "msec": Time.get_ticks_msec() }
	return true

## Phase 48 — host: `moved` changed position (or is the host avatar), so re-evaluate every
## (viewer, subject) pair it is part of. A pair that ENTERED AOI is sent the subject's
## set; a pair that LEFT is told to evict it.
func _refresh_equipment_pairs(moved: int) -> void:
	if not sl._connected() or sl.player_registry == null:
		return
	# A client reports at movement rate; its pairs only change at an AOI boundary, so
	# skip the whole pass until it has moved EQUIPMENT_REEVAL_DIST_SQ from the last one.
	if moved != sl.HOST_PEER_ID and sl.has_last_known_state(moved):
		var at = sl.get_last_known_state(moved)
		if sl._equipment_eval_positions.has(moved) \
				and (sl._equipment_eval_positions[moved] as Vector3).distance_squared_to(at) <= sl.EQUIPMENT_REEVAL_DIST_SQ:
			return
		sl._equipment_eval_positions[moved] = at
	var others: Array = Array(sl._connected_peers())
	others.append(sl.HOST_PEER_ID)
	# Phase 163 — a pair needs work only when its subject wears something to show, or the viewer holds a
	# record to evict. In a crowd where nobody wears gear that is no pair at all, instead of 2 per peer.
	var moved_worn: bool = not sl._worn_of_peer(moved).is_empty()
	for other in others:
		var o := int(other)
		if o == moved:
			continue
		if moved_worn or sl._equipment_sent.has(sl._pair_key(o, moved)):
			sl._update_equipment_pair(o, moved)
		if sl._equipment_sent.has(sl._pair_key(moved, o)) or not sl._worn_of_peer(o).is_empty():
			sl._update_equipment_pair(moved, o)

func _on_inventory_synced(owner_id: String, contents: Dictionary, durabilities: Dictionary = {}) -> void:
	if sl._role != sl.Role.HOST:
		return
	# Phase 37 — an inventory is PRIVATE to its owner and the sync now names that
	# owner, so it goes to that owner's peer alone. Broadcasting it handed every client
	# one player's pack (and, before the owner was carried at all, had every
	# InventorySlice in the process apply it).
	var peer = sl._peer_for_inventory_owner(owner_id)
	if peer == 0:
		return
	var packet := {
		"type":     "inventory_synced",
		"contents": contents,
		"durabilities": durabilities,
	}
	sl._deliver(peer, packet)

## Phase 118 — host → the crafter's peer ALONE: a void burst resolved against them. The
## packet carries no player id (the receiving machine knows who it is), and a burst that
## struck the host's own player has no peer to send to. An unresolvable owner fails
## closed, like `_on_inventory_synced`.
func _on_void_burst_resolved(result: Dictionary) -> void:
	if sl._role != sl.Role.HOST:
		return
	var peer = sl._peer_for_inventory_owner(str(result.get("player_id", "")))
	if peer == 0:
		return
	sl._deliver(peer, {
		"type":      "void_burst_resolved",
		"recipe_id": str(result.get("recipe_id", "")),
		"damage":    float(result.get("damage", 0.0)),
		"survived":  bool(result.get("survived", false)),
		"flag":      str(result.get("flag", "")),
	})

## Phase 36 — is `position` within `reach` metres of the peer's last recorded
## position? The host records that position from the peer's own movement packets
## (see remember_player_state), so it is the host's evidence of where the peer is,
## not the peer's claim.
##
## A peer that has never reported a position has none the host can check against,
## and the edit is refused rather than measured from an assumed origin:
## `has_last_known_state()` is what distinguishes "never reported" from "at the
## origin" (get_last_known_state answers Vector3.ZERO for both).
func _within_reach(sender: int, position: Vector3, reach: float) -> bool:
	if not sl.has_last_known_state(sender):
		return false
	return sl.get_last_known_state(sender).distance_to(position) <= reach

## Phase 38 — host side: the world snapshot's social/economy blobs, redacted and keyed
## by the ONE list that says which parts of the world name players
## (`IDENTIFIED_STATE_KEYS`).
##
## The snapshot used to hardcode exactly those three keys, which left two lists to
## keep in step: this side's literals and the constant `_adopt_snapshot_identities`
## walks on the receiving side. A fourth identity-bearing blob added to the constant
## would then have been ADOPTED by every client while never being redacted on the way
## out — a player id on the wire, which is the leak the constant exists to prevent.
## Blobs the constant does not name are dropped rather than passed through: an
## identity-bearing key that nobody has added to the list is a key whose redaction
## story has not been decided yet.
func redact_social_state(state: Dictionary) -> Dictionary:
	var out := {}
	for key in sl.IDENTIFIED_STATE_KEYS:
		if state.has(key):
			out[key] = sl.redact_for_client(state[key])
	return out

## Route a host → client packet. Only host-originated types are handled.
func _route_h2c(payload: Dictionary) -> void:
	match str(payload.get("type", "")):
		"player_moved":
			# The host's own movement arrives as player_moved (peer_id == host id).
			var pos = sl.WorldPos.packet_world(payload, sl._vec3(payload.get("position", [])))
			GameBus.remote_player_state.emit(int(payload.get("peer_id", 1)), pos)
		"block_changed":
			GameBus.block_changed.emit(
				str(payload.get("action", "")),
				sl._vec3(payload.get("position", [])),
				sl._vec3(payload.get("normal", [0, 1, 0])),
				str(payload.get("material", ""))
			)
		"tree_chopped":
			GameBus.tree_chopped.emit(
				str(payload.get("tree_id", "")),
				str(payload.get("wood", "")),
				str(payload.get("state", "")),
				float(payload.get("respawn_at", 0.0))
			)
		"tree_respawned":
			GameBus.tree_respawned.emit(str(payload.get("tree_id", "")))
		"tree_cleared":
			GameBus.tree_cleared.emit(str(payload.get("tree_id", "")))
		"chat_message":
			# Phase 85 — host text for this player's chat box; the target is us by delivery.
			GameBus.chat_posted.emit(
				str(payload.get("channel", "chat")),
				str(payload.get("sender", "")),
				str(payload.get("text", "")),
				""
			)
		"system_message":
			# Phase 131 — a keyed host line; an unknown key, too many args or an oversize arg becomes the
			# generic fallback line, never the raw input.
			var clean = sl.I18n.sanitize_msg(payload.get("key", null), payload.get("args", null))
			GameBus.system_message.emit(str(clean["key"]), clean["args"], "")
		"teleport":
			# Phase 85 — an admin moved us; game_root places the body (rebasing the scene if far).
			var spot: Dictionary = sl.WorldPos.pos_from_wire(payload.get("position", null))
			if spot.is_empty():
				sl.Diag.warn("NetworkingSlice: malformed teleport position dropped")
			else:
				GameBus.player_teleport.emit(spot)
		"creature_state_changed":
			var cpos: Dictionary = _creature_wire_pos(sl, payload)
			if cpos.is_empty():
				sl.Diag.warn("NetworkingSlice: creature_state_changed with undecodable position dropped")
			else:
				GameBus.creature_state_changed.emit(
					str(payload.get("instance_id", "")),
					str(payload.get("creature_id", "")),
					str(payload.get("state", "")),
					cpos
				)
		"combat_hit":
			# Phase 156 — animation only. An oversize key or an unknown outcome is dropped.
			var a := str(payload.get("a", ""))
			var d := str(payload.get("d", ""))
			var o := str(payload.get("o", ""))
			if sl._role == sl.Role.CLIENT and a.length() <= sl.COMBAT_KEY_MAX and d.length() <= sl.COMBAT_KEY_MAX \
					and o in sl.COMBAT_OUTCOMES:
				GameBus.combat_hit_synced.emit(a, d, o)
		"remote_player_state":
			sl._route_remote_player_state(payload)
		"player_states":
			# Phase 163 — the host's batch of position relays; a malformed batch is refused whole.
			var entries: Array = sl.RelayBatch.decode(payload)
			if entries.is_empty():
				sl.Diag.warn("NetworkingSlice: malformed player_states batch dropped")
			for e in entries:
				sl._route_remote_player_state({ "peer_id": e[0], "pk": e[1] })
		"weather_overrides":
			# Phase 128 — only a client adopts the host's table; the list is validated by the slice.
			if sl._role == sl.Role.CLIENT and payload.get("overrides", null) is Array:
				GameBus.weather_overrides_synced.emit(payload["overrides"])
		"world_clock":
			# Phase 54 — the host's clock sample; game_root's WorldClock slews to it.
			GameBus.world_clock_received.emit(float(payload.get("days", 0.0)))
		"gesture":
			# Phase 159 — animation only: a peer id and a short gesture id ("" = stood up).
			var g: Variant = payload.get("g", "")
			if sl._role == sl.Role.CLIENT and g is String and (g as String).length() <= sl.GESTURE_ID_MAX:
				GameBus.peer_gesture_synced.emit(int(payload.get("peer_id", 0)), g)
		"carcass":
			# Phase 161 — a body in our AOI; the slice keeps a view of it.
			var cpos: Variant = payload.get("pos", [])
			var cid: Variant = payload.get("id", "")
			if sl._role == sl.Role.CLIENT and cid is String and cpos is Array and (cpos as Array).size() == 3:
				GameBus.peer_carcass_synced.emit({ "id": cid, "creature": str(payload.get("creature", "")),
					"position": Vector3(float(cpos[0]), float(cpos[1]), float(cpos[2])),
					"entries": payload.get("entries", []) if payload.get("entries", []) is Array else [],
					"carrier": str(payload.get("carrier", "")), "mode": str(payload.get("mode", "")),
					"mass": float(payload.get("mass", 0.0)), "remaining": float(payload.get("remaining", 0.0)) })
		"carcass_removed":
			if sl._role == sl.Role.CLIENT and payload.get("id", "") is String:
				GameBus.peer_carcass_removed.emit(payload["id"])
		"carry_state":
			if sl._role == sl.Role.CLIENT:
				GameBus.carry_state_synced.emit(bool(payload.get("carrying", false)), clampf(float(payload.get("factor", 1.0)), 0.0, 1.0))
		"admin_moves":
			# Phase 182 — the host set our `/speed` / `/fly`; the factor is clamped again where it is applied.
			var speed: Variant = payload.get("speed", 1.0)
			if sl._role == sl.Role.CLIENT and (speed is float or speed is int):
				GameBus.admin_moves_synced.emit(float(speed), bool(payload.get("fly", false)))
		"admin_heal":
			if sl._role == sl.Role.CLIENT:
				GameBus.admin_healed.emit()
		"admin_status":
			# Phase 182 — the host's admins file changed: read strictly, like the identity's flag.
			var now_admin: Variant = payload.get("admin", false)
			if sl._role == sl.Role.CLIENT:
				GameBus.admin_status_synced.emit(now_admin is bool and now_admin)
		"peer_equipment_evict":
			# Phase 48 — the peer left our AOI; drop what we stored for it.
			GameBus.peer_equipment_evicted.emit(int(payload.get("peer_id", 0)))
		"peer_equipment":
			# Phase 47 — another peer's worn set, scoped to our AOI by the host.
			var worn: Variant = payload.get("worn", {})
			if worn is Dictionary:
				GameBus.peer_equipment_synced.emit(int(payload.get("peer_id", 0)), worn)
		"inventory_synced":
			# Phase 37 — the packet is addressed to THIS client alone (the host sends it
			# to the owner's peer, see _on_inventory_synced) and carries no identity: the
			# only inventory it can be is this machine's own, which is the local bucket
			# (`""` / `"player"`). Re-broadcasting a player id here would put a bearer
			# token on the wire for nothing.
			GameBus.inventory_synced.emit(
				"",
				payload.get("contents", {}),
				payload.get("durabilities", {})
			)
		"player_damaged":
			# Phase 37 — a creature struck US on the host's authoritative simulation. The
			# local body is the one that takes the hit, so the target is the local bucket
			# id the bus has always used for it.
			GameBus.player_damaged.emit(
				float(payload.get("damage", 0.0)),
				str(payload.get("attacker_id", "")),
				"player"
			)
		"status_effects":
			# Phase 129 — addressed to us alone; the slice validates each entry.
			if sl._role == sl.Role.CLIENT and payload.get("effects", null) is Array:
				GameBus.status_effects_synced.emit("player", payload["effects"])
		"void_burst_resolved":
			# Phase 118 — addressed to us alone; the player id is the local bucket.
			GameBus.void_burst_resolved.emit({
				"recipe_id": str(payload.get("recipe_id", "")),
				"player_id": "",
				"damage":    float(payload.get("damage", 0.0)),
				"survived":  bool(payload.get("survived", false)),
				"flag":      str(payload.get("flag", "")),
			})
		"profession_unlocked":
			GameBus.profession_unlocked.emit("", str(payload.get("profession", "")))
		"market_synced":
			# Phase 36 — the payload names players by public handle; our OWN handle is
			# shown back to the slices as "player" so the local view is unchanged.
			GameBus.market_synced.emit(sl.adopt_own_handle(payload.get("data", {})))
		"governance_synced":
			GameBus.governance_synced.emit(sl.adopt_own_handle(payload.get("data", {})))
		"trade_synced":
			GameBus.trade_synced.emit(sl.adopt_own_handle(payload.get("data", {})))
		"trade_completed":
			GameBus.trade_completed.emit(sl.adopt_own_handle(payload.get("trade", {})))
		"world_snapshot":
			GameBus.world_snapshot_received.emit(payload.get("data", {}))
		"own_state_synced":
			# Phase 34 — the host's copy of OUR record changed (it resolved a repair
			# or research for us). Apply it; game_root owns what that means.
			# NOTE: no listener on this side of the signal — `send_own_state` is a
			# direct call, and re-emitting from a listener on the same signal would
			# make the client loop forever on its own packet.
			GameBus.own_state_synced.emit(payload.get("data", {}))
		"identity_assigned":
			# Phase 33 — the host's answer to our join intent. Cache it so a
			# reconnect claims the same record. Phase 36 — it now also carries our
			# public HANDLE, which is what this client is called by in everything
			# that is broadcast (a handle is not a claim: it is one-way and no record
			# is keyed by it, so caching it is safe where caching an id would not be).
			sl.claimed_player_id = str(payload.get("player_id", ""))
			sl.claimed_handle = str(payload.get("handle", ""))
			GameBus.player_identity_assigned.emit(sl.claimed_player_id)
			var admin: Variant = payload.get("admin", false)
			GameBus.admin_status_synced.emit(admin is bool and admin)
		"spawn_notice":
			# Phase 131 — a catalog key (+ args), rendered here in this client's locale.
			var note = sl.I18n.sanitize_msg(payload.get("key", null), payload.get("args", null))
			GameBus.spawn_notice.emit(sl.I18n.render(note))
		"snapshot_chunk":
			sl._accumulate_snapshot_chunk(payload)
		_:
			# Legacy low-level packets fall through to packet_received.
			GameBus.packet_received.emit(1, payload)

## Sample the buffered snapshots for `peer_id` at playback time
## (now_ms - jitter_buffer_ms), interpolating between the two surrounding
## snapshots. Pure — accepts an explicit clock for tests.
func _sample_remote_state_at(peer_id: int, now_ms: float) -> Vector3:
	var queue: Array = sl._jitter_buffer.get(peer_id, [])
	if queue.is_empty():
		return Vector3.ZERO
	var play: float = now_ms - sl.jitter_buffer_ms
	var first: Dictionary = queue[0]
	if play <= float(first["at_ms"]):
		return first["position"]
	var last: Dictionary = queue[queue.size() - 1]
	if play >= float(last["at_ms"]):
		return last["position"]
	for i in range(queue.size() - 1):
		var a: Dictionary = queue[i]
		var b: Dictionary = queue[i + 1]
		var ta: float = float(a["at_ms"])
		var tb: float = float(b["at_ms"])
		if play >= ta and play <= tb:
			var t: float = (play - ta) / maxf(tb - ta, 0.0001)
			return (a["position"] as Vector3).lerp(b["position"], t)
	return last["position"]

## Host: relay a creature's state change to the peers whose AOI holds it.
func relay_creature_state(instance_id: String, creature_id: String, state: String, position: Dictionary) -> void:
	if sl._role != sl.Role.HOST:
		return
	var packet := {
		"type":        "creature_state_changed",
		"instance_id": instance_id,
		"creature_id": creature_id,
		"state":       state,
		"pk":          sl.WorldPos.pos_to_packet_text(position),
	}
	sl._broadcast_aoi(packet, sl.WorldPos.to_scene(position, Vector2i.ZERO))
