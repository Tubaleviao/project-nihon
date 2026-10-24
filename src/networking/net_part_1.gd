extends RefCounted
## Methods moved verbatim out of `networking_slice.gd` (Phase 154). `sl` is the owning slice; each moved method keeps a forwarder there.

var sl: Node

func _init(slice: Node) -> void:
	sl = slice

## Phase 135 — apply `--net-profile` from the command line at boot. An unknown name (or a flag with
## no value) is refused: the process exits 2, because a run that fell back to loopback would report a
## pass for a link it never emulated. Returns false on refusal.
func _apply_profile_arg(args: Array) -> bool:
	var name = sl.profile_from_args(args)
	if name == "":
		return true
	if sl.apply_profile(name):
		print("[Networking] link profile: %s" % name)
		return true
	sl.Diag.error("[Networking] unknown --net-profile '%s' (known: %s)" % [name, ", ".join(sl.NET_PROFILES.keys())])
	sl.get_tree().quit(2)
	return false

## Tear down the peer and return to offline role.
func disconnect_all() -> void:
	if sl._peer:
		sl._peer.close()
	sl._detach_peer()
	sl.multiplayer.multiplayer_peer = null
	sl._role = sl.Role.OFFLINE
	sl._pending.clear()
	sl._link_free_at_ms.clear()
	sl._ordered_at_ms.clear()
	sl._jitter_buffer.clear()
	sl._player_ids.clear()
	# Phase 37 — a torn-down connection cannot complete the snapshot it was
	# reassembling (see forget_player_id).
	sl._snapshot_buffer.clear()

## Record a client's last-known authoritative position. Retained across a
## disconnect so a rejoining client resumes from where it left off.
## Clears the eviction countdown: an active peer is never stale.
func remember_player_state(peer_id: int, position: Vector3, exact: Dictionary = {}) -> void:
	sl._last_known_states[peer_id] = position
	if exact.is_empty():
		sl._last_known_exact.erase(peer_id)
	else:
		sl._last_known_exact[peer_id] = exact
		var pending: Variant = sl._teleport_pending.get(peer_id, null)
		if pending is Dictionary and sl.WorldPos.offset_between(pending["pos"], exact).length() <= sl.TELEPORT_ARRIVED_M:
			sl._teleport_pending.erase(peer_id)
	sl._peer_spatial.update(peer_id, position)
	sl._last_known_timestamps.erase(peer_id)

func _on_player_state_sync_requested(payload: Dictionary) -> void:
	if not sl._connected():
		return
	var pos: Vector3 = payload.get("position", Vector3.ZERO)
	# Phase 86 — the exact `{chunk, local}` position rides the wire when the sender holds one, so the
	# host does not quantise a far-away player to float32 metres.
	var exact = payload.get("world_pos", null)
	var wire: Dictionary = exact if sl._is_exact_pos(exact) else sl.WorldPos.from_world(pos.x, pos.y, pos.z)
	var packet := {
		"type":     "player_moved",
		"peer_id":  sl.multiplayer.get_unique_id(),
		"pk":       sl.WorldPos.pos_to_packet_text(wire),
		"hp":       payload.get("hp",     100.0),
		"max_hp":   payload.get("max_hp", 100.0),
	}
	sl._broadcast_aoi(packet, pos)

## Phase 47 — host: a peer just bound its identity; tell it the worn sets of the other
## connected players (the host's own included) inside its AOI, because
## `_on_equipment_changed` only fires on a change and a late joiner would otherwise
## never learn gear that was already on.
func send_peer_equipment_to(peer_id: int) -> void:
	if sl._role != sl.Role.HOST or not sl._connected() or sl.player_registry == null:
		return
	var others: Array = Array(sl._connected_peers())
	others.append(sl.HOST_PEER_ID)
	var center = sl._joiner_aoi_center(peer_id)
	for other in others:
		var o := int(other)
		if o == peer_id or not sl._has_subject_position(o) or center.distance_to(sl._subject_position(o)) > sl.AOI_RADIUS:
			continue
		# A join intent the host re-answers (the client's snapshot retry) lands here again:
		# a pair already sent is current, because every later change goes out through
		# `_on_equipment_changed`, and a disconnect clears the pair.
		if sl._equipment_sent.has(sl._pair_key(peer_id, o)):
			continue
		var worn = sl._worn_of_peer(o)
		if not worn.is_empty():
			sl._send_equipment(peer_id, o, worn)

func _update_equipment_pair(viewer: int, subject: int) -> void:
	sl.equipment_pair_evaluations += 1
	# The host never needs its own view of anyone, and a viewer without a known
	# position has no AOI yet (the handshake / first-report paths cover it).
	if viewer == sl.HOST_PEER_ID or not sl.has_last_known_state(viewer) or not sl._has_subject_position(subject):
		return
	var key = sl._pair_key(viewer, subject)
	var visible = sl.in_aoi(viewer, sl._subject_position(subject))
	if visible and not sl._equipment_sent.has(key):
		var worn = sl._worn_of_peer(subject)
		if worn.is_empty():
			return
		sl._send_equipment(viewer, subject, worn)
	elif not visible and sl._equipment_sent.has(key):
		sl._equipment_sent.erase(key)
		sl._deliver(viewer, { "type": "peer_equipment_evict", "peer_id": subject })

## The live peer whose player owns the inventory named by `owner_id`, or 0 when there
## is nobody to send it to: an offline owner, a name this host cannot resolve, an
## unwired registry (the check FAILS CLOSED — an unaddressed private payload is not
## broadcast), or this machine's OWN player, whose inventory is already live here.
##
## `""` and `"player"` both denote the local bucket (see
## InventorySlice.LOCAL_OWNER_LITERALS).
func _peer_for_inventory_owner(owner_id: String) -> int:
	if sl.player_registry == null or not sl.player_registry.has_method("get_peer_id"):
		return 0
	var pid := owner_id
	if pid == "" or pid == "player":
		pid = str(sl.player_registry.local_player_id)
	if pid == "":
		return 0
	return int(sl.player_registry.get_peer_id(pid))

## Phase 19 — sequence dedup / gap detection.
## Uses a per-type sliding window so reordered-but-unseen packets are accepted
## (returned true) rather than silently dropped. Only true duplicates (the same
## seq already in the seen window) and packets older than DEDUP_WINDOW behind
## the frontier are dropped (returned false).
## Gap warnings are rate-limited to one per second per (peer, type) channel.
func _dedup(sender: int, payload: Dictionary) -> bool:
	if not payload.has("seq"):
		return true   # legacy packet without seq — accept
	var seq: int = int(payload["seq"])
	var ptype: String = str(payload.get("type", "_"))
	var key: String = "%d:%s" % [sender, ptype]

	if not sl._recv_seen.has(key):
		sl._recv_seen[key] = {}
	var seen: Dictionary = sl._recv_seen[key]

	# True duplicate: this exact seq was already accepted in the window.
	if seen.has(seq):
		return false

	var last: int = sl._recv_seq.get(key, -1)

	# Too stale: more than DEDUP_WINDOW behind the frontier — cannot reorder.
	if last >= 0 and seq < last - sl.DEDUP_WINDOW:
		return false

	# Forward gap (packet loss): log at most once per second per channel.
	if last >= 0 and seq > last + 1:
		var now_ms: float = float(Time.get_ticks_msec())
		var gap_last: float = float(sl._seq_gap_warn_ms.get(key, -sl.SEQ_GAP_WARN_INTERVAL_MS))
		if now_ms - gap_last >= sl.SEQ_GAP_WARN_INTERVAL_MS:
			sl.Diag.warn("NetworkingSlice: seq gap — peer %d type '%s' frontier %d got %d" \
				% [sender, ptype, last, seq])
			sl._seq_gap_warn_ms[key] = now_ms

	# Mark seen and prune entries beyond the window.
	seen[seq] = true
	var cutoff: int = seq - sl.DEDUP_WINDOW
	for k: int in seen.keys():
		if k < cutoff:
			seen.erase(k)

	# Advance the frontier only when this seq is higher.
	if seq > last:
		sl._recv_seq[key] = seq

	return true

## Resolve the counterparty a client NAMED on a trade invite to the player id it
## denotes, or "" when it denotes nothing this host can open a session with.
##
## Phase 36 — this is the ONE identity a client payload may legitimately name: an
## invite grants the named player nothing (it is answered by that player's own
## accept, which is bound to its own connection), and every ACTING half is bound to
## the sender. Requiring the name to resolve against the registry means the host
## only ever opens a session with a player it knows and that is online right now —
## an invite to an offline or invented id is dropped, not parked.
##
## Phase 37 — the name must be a public HANDLE (see
## PlayerRegistry.resolve_named_party): accepting a raw player id as well turned this
## into a yes/no oracle for "is this exact id online", which is a probing tool, not a
## feature. An id is a bearer token and a client is never told one.
func _named_party(raw: String) -> String:
	if raw == "" or sl.player_registry == null:
		return ""
	if not sl.player_registry.has_method("resolve_named_party"):
		return ""
	return str(sl.player_registry.resolve_named_party(raw))

## Walk `value`, mapping every STRING through `mapper` — values and dictionary keys
## alike. Arrays and dictionaries are rebuilt; every other type is passed through. The
## shapes walked here are the replicated social/economy state (dictionaries of
## dictionaries of scalars), never a whole world snapshot.
func _map_identities(value: Variant, mapper: Callable) -> Variant:
	if value is String:
		return mapper.call(value)
	if value is Array:
		var out_items: Array = []
		for item in value:
			out_items.append(sl._map_identities(item, mapper))
		return out_items
	if value is Dictionary:
		var out: Dictionary = {}
		for key in value:
			out[sl._map_identities(key, mapper)] = sl._map_identities(value[key], mapper)
		return out
	return value

## Reassemble a chunked world snapshot (see send_snapshot) and emit
## world_snapshot_received once the final chunk lands. Chunks are indexed so
## out-of-order delivery still reassembles correctly, and duplicate chunks are
## ignored (Phase 19) so emulator re-delivery cannot corrupt the reassembly.
func _accumulate_snapshot_chunk(payload: Dictionary) -> void:
	var snapshot_id: int = int(payload.get("snapshot_id", -1))
	var index: int = int(payload.get("index", -1))
	var count: int = int(payload.get("count", 0))
	var chunk: String = str(payload.get("data", ""))
	if snapshot_id < 0 or count <= 0 or index < 0 or index >= count:
		sl.Diag.error("NetworkingSlice: malformed snapshot_chunk dropped")
		return
	if not sl._snapshot_buffer.has(snapshot_id):
		sl._snapshot_buffer[snapshot_id] = { "count": count, "received": 0, "parts": [] }
	var entry: Dictionary = sl._snapshot_buffer[snapshot_id]
	while entry["parts"].size() < count:
		entry["parts"].append("")
	# Idempotent: only count a chunk once, so a duplicate (emulator re-delivery)
	# never double-increments `received` and prematurely completes reassembly.
	if entry["parts"][index] == "":
		entry["parts"][index] = chunk
		entry["received"] += 1
	if entry["received"] >= count:
		sl._snapshot_buffer.erase(snapshot_id)
		var full := ""
		for part in entry["parts"]:
			full += part
		var data = JSON.parse_string(full)
		if data is Dictionary:
			GameBus.world_snapshot_received.emit(sl._adopt_snapshot_identities(data))
		else:
			sl.Diag.error("NetworkingSlice: snapshot reassembly produced invalid JSON")

## Phase 38 — client side: the host went away. The reconnect policy is game_root's
## (`_on_server_disconnected` there answers a retry), but the transport state left
## behind is this slice's, and the snapshot buffer is the part that leaks: an
## incomplete snapshot can never be completed by the host that just vanished, so its
## entry lived for the whole session. Neither pre-existing clear site covered this —
## one is this slice's own teardown and the other is a PEER disconnecting, and a client
## has no peers to disconnect (see forget_player_id).
##
## Role-gated: a host has no server to lose, and its own teardown clears the buffer
## already. A second, weaker clear here would be a hole rather than a fix.
func _on_server_disconnected() -> void:
	if sl._role != sl.Role.CLIENT:
		return
	sl._snapshot_buffer.clear()

## Phase 163 — host: send the frame's queued position relays, one `player_states` packet per recipient
## (more only past `RelayBatch.BATCH_MAX` subjects). `_process` calls it every frame with `paced`, and it
## then sends only every `RelayBatch.FLUSH_MS`: reports arrive spread over the frames, so a per-frame
## flush sent batches of one or two. A direct call (a test) sends now. Returns the packets sent.
func flush_relays(paced: bool = false) -> int:
	if sl._role != sl.Role.HOST or not sl._relays.has_pending():
		return 0
	var now_ms := float(Time.get_ticks_msec())
	if paced and now_ms - sl._relays.flushed_ms < sl.RelayBatch.FLUSH_MS:
		return 0
	sl._relays.flushed_ms = now_ms
	sl.TickProbe.begin("aoi_relay")
	var connected := {}
	if sl._connected():
		for p in sl._connected_peers():
			connected[int(p)] = true
	var batches: Dictionary = sl._relays.build(now_ms, connected,
			func(pos: Vector3) -> Array: return sl._peer_spatial.query_radius(pos, sl.AOI_RADIUS), Callable(sl, "get_aoi_center"))
	var sent := 0
	for rid in batches:
		for packet in sl.RelayBatch.packets(batches[rid]):
			sl._deliver(int(rid), packet)
			sent += 1
	sl.TickProbe.end()
	return sent

## Peer ids (among `connected`) whose AOI contains `position`.
func aoi_recipients(position: Vector3, connected: Array) -> Array:
	var out: Array = []
	var near: Array = sl._peer_spatial.query_radius(position, sl.AOI_RADIUS)
	if near.is_empty():
		return out   # nobody nearby: skip building the peer set
	var live := {}   # Phase 163 — one pass over `connected`, not an array scan per candidate
	for pid in connected:
		live[pid] = true
	for pid in near:
		if live.has(pid):
			out.append(pid)
	return out

func _route_remote_player_state(payload: Dictionary) -> void:
	var pid := int(payload.get("peer_id", 0))
	if sl.TickProbe.log_relays:   # a second decode, paid only by a stress watcher (outside the timed span)
		var exact: Dictionary = sl.WorldPos.pos_from_packet(payload)
		if not exact.is_empty():
			sl.TickProbe.relay_seen(pid, sl.TickProbe.position_key(exact), exact)
	sl.TickProbe.begin("relay_apply")
	var pos: Vector3 = sl.WorldPos.packet_world(payload, sl._vec3(payload.get("position", [])))
	if sl.emulate_network and sl._role == sl.Role.CLIENT:
		sl._buffer_remote_state(pid, pos)
	else:
		GameBus.remote_player_state.emit(pid, pos)
	sl.TickProbe.end()

## Drop every sent-record involving a peer that disconnected.
func forget_equipment_pairs(peer_id: int) -> void:
	sl._equipment_eval_positions.erase(peer_id)
	for key in sl._equipment_sent.keys():
		var parts := str(key).split(":")
		if int(parts[0]) == peer_id or int(parts[1]) == peer_id:
			sl._equipment_sent.erase(key)
