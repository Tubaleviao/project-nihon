extends RefCounted
## Player state relay and look/equipment sharing: the peer → player id map, remembering, ageing out, sampling and relaying player states, the area of interest, equipment pairs (announced to and refreshed over the area of interest), creation intents, look tokens, title intents, the disconnect paths and snapshot chunk accumulation. Methods moved verbatim out of `networking_slice.gd` (Phase 154, renamed Phase 257). `sl` is the owning slice; each moved method keeps a forwarder there. Does not hold: the packet senders and client-to-host router (`net_packets.gd`) or the host session and snapshots (`net_session.gd`).

var sl: Node

func _init(slice: Node) -> void:
	sl = slice

## Tear down the peer and return to offline role.
func disconnect_all() -> void:
	sl._m3.stop_status()   # Phase 297
	if sl._peer:
		sl._peer.close()
	sl._detach_peer()
	sl.multiplayer.multiplayer_peer = null
	sl._role = sl.Role.OFFLINE
	sl._pending.clear()
	sl._link_free_at_ms.clear()
	sl._ordered_at_ms.clear()
	sl._jitter_buffer.clear()
	_last_report = {}   # Phase 294 — a new connection hears the first report at once
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

## Phase 294 — the last movement report this machine sent ({ pk, hp, max_hp, ms }), and how often an unchanged one
## is still sent.
var _last_report: Dictionary = {}
const REPORT_KEEPALIVE_MS := 500.0

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
	# Phase 294 — reports go out every `RemoteMotion.players.sendIntervalMs`; one that changes nothing (a body
	# standing still) is sent only as a keepalive every REPORT_KEEPALIVE_MS, the old report rate.
	var now_ms := float(Time.get_ticks_msec())
	var same: bool = packet["pk"] == _last_report.get("pk", "") and packet["hp"] == _last_report.get("hp", null) \
			and packet["max_hp"] == _last_report.get("max_hp", null)
	if same and now_ms - float(_last_report.get("ms", -INF)) < REPORT_KEEPALIVE_MS:
		return
	_last_report = { "pk": packet["pk"], "hp": packet["hp"], "max_hp": packet["max_hp"], "ms": now_ms }
	if sl._role == sl.Role.HOST:
		introduce_host_body(pos, float(Time.get_ticks_msec()))
	sl._broadcast_aoi(packet, pos)
	if sl._role == sl.Role.HOST:
		for rid in _host_entered:
			GameBus.aoi_pair_entered.emit(int(rid), sl.HOST_PEER_ID)
		_host_entered = []

## Phase 293 — the host's own body is not relayed through `RelayBatch` (it is broadcast straight to the AOI), so
## its first meetings are tracked here: recipient -> ms of the last state it was sent. A recipient that has not
## been sent one for `RelayBatch.PAIR_TTL_MS` (or never) is meeting the host anew and gets the look first.
var _host_seen: Dictionary = {}
## Recipients meeting the host in the current broadcast (their `aoi_pair_entered` goes after the state).
var _host_entered: Array = []

## Send the host's look to every AOI recipient of a host state at `pos` meeting the host anew; returns how many.
func introduce_host_body(pos: Vector3, now_ms: float) -> int:
	_host_entered = []
	if not sl._connected():
		return 0
	var live: Dictionary = sl._ensure_transport().peer_set()
	for rid in _host_seen.keys():
		if not live.has(int(rid)):
			_host_seen.erase(rid)   # gone: forgotten, so the map stays as small as the peer list
	for rid in sl.aoi_recipients(pos, live):
		var r := int(rid)
		if r == sl.HOST_PEER_ID:
			continue
		if now_ms - float(_host_seen.get(r, -INF)) >= sl.RelayBatch.PAIR_TTL_MS:
			send_look_to(r, sl.HOST_PEER_ID)
			_host_entered.append(r)
		_host_seen[r] = now_ms
	return _host_entered.size()

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
	var connected: Dictionary = sl._ensure_transport().peer_set() if sl._connected() else {}
	var batches: Dictionary = sl._relays.build(now_ms, connected,
			func(pos: Vector3) -> Array: return sl._peer_spatial.query_radius(pos, sl.AOI_RADIUS), Callable(sl, "get_aoi_center"))
	# Phase 293 — a subject new to a recipient's AOI: its look goes in the same flush, just ahead of its first
	# state, so the recipient builds the player body already dressed instead of asking for the look later.
	for rid in sl._relays.entered:
		for subject in sl._relays.entered[rid]:
			send_look_to(int(rid), int(subject))
	var sent := 0
	for rid in batches:
		for packet in sl.RelayBatch.packets(batches[rid]):
			sl._deliver(int(rid), packet)
			sent += 1
	# Other per-pair state (the hand item) follows the state, through `aoi_pair_entered`.
	for rid in sl._relays.entered:
		for subject in sl._relays.entered[rid]:
			GameBus.aoi_pair_entered.emit(int(rid), int(subject))
	sl.TickProbe.end()
	return sent

## Phase 293 — looks the host sent on its own (a pair's first relay), for the suite.
var looks_pushed: int = 0

## Phase 293 — host: send `subject`'s look to `viewer` (the host's own body is peer 1). False when the subject has
## no player behind it yet.
func send_look_to(viewer: int, subject: int) -> bool:
	if sl._role != sl.Role.HOST or sl.player_registry == null or subject == viewer:
		return false
	var owner_id: String = sl.player_registry.local_player_id if subject == sl.HOST_PEER_ID else sl.get_player_id(subject)
	if owner_id == "":
		return false
	looks_pushed += 1
	sl._deliver(viewer, { "type": "peer_look", "peer_id": subject, "look": cached_look(owner_id).duplicate() })
	return true

## Phase 293 — player id -> the look last read from the registry. A crowd meeting at once (a restart, a teleport
## into a town) makes many pairs new in one flush; each player's look is built once, not once per viewer. Replaced
## by `push_look` (the only way a look changes: a creation or a title), dropped when it outgrows LOOK_CACHE_MAX.
const LOOK_CACHE_MAX := 4096
var _look_cache: Dictionary = {}

func cached_look(player_id: String) -> Dictionary:
	if not _look_cache.has(player_id):
		if _look_cache.size() >= LOOK_CACHE_MAX:
			_look_cache.clear()
		_look_cache[player_id] = sl.player_registry.look_of(player_id)
	return _look_cache[player_id]

## Peer ids (among `connected`) whose AOI contains `position`. Phase 195 — `connected` is the peer set
## (`Transport.peer_set()`, id -> true, reused until the peer list changes); an Array is still accepted and
## turned into one here.
func aoi_recipients(position: Vector3, connected: Variant) -> Array:
	var out: Array = []
	var near: Array = sl._peer_spatial.query_radius(position, sl.AOI_RADIUS)
	if near.is_empty():
		return out   # nobody nearby: skip building the peer set
	var live: Dictionary
	if connected is Dictionary:
		live = connected
	else:
		live = {}   # Phase 163 — one pass over `connected`, not an array scan per candidate
		for pid in connected:
			live[int(pid)] = true
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

func forget_player_id(peer_id: int) -> void:
	sl._player_ids.erase(peer_id)
	# Phase 36 — the rate-limit state is transport state too: a reconnecting peer
	# starts with a full bucket rather than inheriting its predecessor's debt.
	sl._rate_buckets.erase(peer_id)
	sl._m3.bake.forget(peer_id)   # Phase 302
	sl._rate_warn_ms.erase(peer_id)
	_look_buckets.erase(peer_id)
	sl._m2.speed_ledger.erase(peer_id)
	# Phase 37 — and so is snapshot reassembly: a snapshot that lost a chunk is never
	# completed, so its buffer entry lived for the whole session (one leak per lost
	# chunk, on a connection that may be long gone). The parts are keyed by
	# snapshot_id, and the sender is the connection that carried them, so the whole
	# buffer goes with the connection: a later snapshot is a fresh snapshot_id anyway.
	sl._snapshot_buffer.clear()

## Phase 181 — client: forward a creation or skip; the host binds it to the connection's player. Only the four
## creation fields travel, as capped strings and an int.
func forward_creation_intent(action: String, creation: Dictionary) -> void:
	if sl._role != sl.Role.CLIENT:
		return
	var packet: Dictionary = sl.CreationRules.intent_fields(creation)
	packet["type"] = "creation_intent"
	packet["action"] = action.left(8)
	sl._broadcast(packet)

## Phase 181 — host: `viewer` asked for `subject`'s look (its avatar just appeared there). Pulled on appearance
## rather than pushed per AOI pair: every player has a look, and a pushed pair per (viewer, subject) is the crowd
## cost Phase 163 removed for gear. Answered only while the subject stands inside the viewer's AOI (the scope its
## position relay has), so a client cannot list everyone's names.
func answer_look_request(viewer: int, subject: int, now_ms: float = -1.0) -> bool:
	if sl._role != sl.Role.HOST or sl.player_registry == null or subject == viewer:
		sl.look_requests_refused += 1
		return false
	if not _take_look_token(viewer, now_ms if now_ms >= 0.0 else float(Time.get_ticks_msec())):
		sl.look_requests_refused += 1
		return false
	var owner_id: String = sl.player_registry.local_player_id if subject == sl.HOST_PEER_ID else sl.get_player_id(subject)
	if owner_id == "" or not sl._has_subject_position(subject) or not sl.has_last_known_state(viewer) \
			or not sl.in_aoi(viewer, sl._subject_position(subject)):
		sl.look_requests_refused += 1
		return false
	sl.look_requests_answered += 1
	sl._deliver(viewer, { "type": "peer_look", "peer_id": subject, "look": sl.player_registry.look_of(owner_id) })
	return true

## Phase 196 — a peer's own look-request budget, under the global packet bucket: a burst for walking into a
## crowd, then a sustained rate. peer_id → { tokens, at_ms }; dropped with the transport state on disconnect.
const LOOK_BUCKET_CAPACITY := 32.0
const LOOK_REFILL_PER_SEC := 4.0
var _look_buckets: Dictionary = {}

## Phase 196 — one token from `viewer`'s look budget (LOOK_BUCKET_CAPACITY burst, LOOK_REFILL_PER_SEC), false
## when it is spent. Like `creation_intent`'s registry limit, a dedicated cap under the global packet bucket.
func _take_look_token(viewer: int, now_ms: float) -> bool:
	var b: Dictionary = _look_buckets.get(viewer, { "tokens": LOOK_BUCKET_CAPACITY, "at_ms": now_ms })
	var elapsed: float = maxf(0.0, now_ms - float(b["at_ms"]))
	b["tokens"] = minf(LOOK_BUCKET_CAPACITY, float(b["tokens"]) + elapsed * 0.001 * LOOK_REFILL_PER_SEC)
	b["at_ms"] = now_ms
	_look_buckets[viewer] = b
	if float(b["tokens"]) < 1.0:
		return false
	b["tokens"] = float(b["tokens"]) - 1.0
	return true

## Phase 181 — host: a player's look changed (a creation, a title). It goes to the peers whose AOI holds that
## player, named by the owner's peer id; peers that meet the player later are sent it with its first state
## (Phase 293, `send_look_to`), and `answer_look_request` stays as the client's fallback.
func push_look(player_id: String, look: Dictionary) -> void:
	_look_cache.erase(player_id)
	if sl._role != sl.Role.HOST or not sl._connected() or sl.player_registry == null:
		return
	var owner_peer: int = sl._equipment_owner(player_id)
	if owner_peer == 0 or not sl._has_subject_position(owner_peer):
		return
	for pid in sl.equipment_targets(owner_peer):
		sl._deliver(int(pid), { "type": "peer_look", "peer_id": owner_peer, "look": look.duplicate() })

## Broadcast a spatial delta only to peers whose AOI contains `position` (a client forwards it to the host).
func broadcast_aoi(payload: Dictionary, position: Vector3) -> void:
	if not sl._connected():
		return
	if sl._role == sl.Role.HOST:
		for pid in sl.aoi_recipients(position, sl._ensure_transport().peer_set()):
			sl._deliver(int(pid), payload.duplicate(true))
	elif sl._role == sl.Role.CLIENT:
		sl._deliver(1, payload)

## Legacy low-level send: wraps an arbitrary payload and ships it as-is.
func packet_send_requested(peer_id: int, payload: Dictionary) -> void:
	if not sl._connected():
		return
	if sl._role == sl.Role.HOST:
		sl._deliver(peer_id, payload.duplicate(true))
	else:
		sl._deliver(1, payload)

## Phase 273 — a client's title choice travels to the host; a title unlocked for a remote player is told to
## that player alone (the toast), the record itself riding the own-state channel.
func on_title_choose_intent(title: String, _player_id: String) -> void:
	if sl._role != sl.Role.CLIENT:
		return
	sl._broadcast({ "type": "title_intent", "title": title.left(40) })

func on_title_unlocked(player_id: String, title: String) -> void:
	if sl._role != sl.Role.HOST:
		return
	var peer: int = sl._peer_for_inventory_owner(player_id)
	if peer != 0:
		sl._deliver(peer, { "type": "title_unlocked", "title": title })

## Record the peer → player_id mapping, and (on a host) send the assigned id back
## to that peer so it can cache it for a reconnect.
func set_player_id(peer_id: int, player_id: String) -> void:
	if player_id.is_empty():
		return
	sl._player_ids[peer_id] = player_id
	if sl._role == sl.Role.HOST:
		sl._deliver(peer_id, {
			"type": "identity_assigned",
			"player_id": player_id,
			# Phase 226 — the account the client caches and presents next time (the player id is its character).
			"account": str(sl.player_registry.accounts.get_account(peer_id)) if sl.player_registry != null and "accounts" in sl.player_registry else player_id,
			"handle": sl._public_handle(player_id),
			# Phase 182 — whether this player may run admin commands, so its client shows the Admin
			# window. A hint only: the host checks every command again.
			"admin": bool(sl.admin_check.call(player_id)) if sl.admin_check.is_valid() else false,
		})

## Evict last-known states for peers that have been disconnected longer than
## LAST_KNOWN_STATE_TTL_MS. Called every frame from _process() so the host
## dict doesn't grow without bound over long sessions.
func _evict_stale_states() -> void:
	if sl._last_known_timestamps.is_empty():
		return
	var now_ms: float = float(Time.get_ticks_msec())
	for pid: int in sl._last_known_timestamps.keys():
		if now_ms - float(sl._last_known_timestamps[pid]) > float(sl.LAST_KNOWN_STATE_TTL_MS):
			sl._last_known_states.erase(pid)
			sl._last_known_exact.erase(pid)
			sl._teleport_pending.erase(pid)
			sl._last_known_timestamps.erase(pid)
			sl._peer_spatial.remove(pid)

## Phase 47 — host: tell the peers whose AOI contains `peer_id` what it wears. Used when
## a peer's position first becomes known: a reconnecting player's worn set is restored
## from its record, which fires no `equipment_changed`, and at the handshake the peer has
## no position yet to scope by (a reconnect gets a fresh ENet id, so the spawn default
## would be used). Does nothing for a peer with no connection, no worn set or no position.
func announce_equipment_to_aoi(peer_id: int) -> void:
	if sl._role != sl.Role.HOST or not sl._connected() or sl.player_registry == null or not sl.has_last_known_state(peer_id):
		return
	var worn = sl._worn_of_peer(peer_id)
	if worn.is_empty():
		return
	for pid in sl.equipment_targets(peer_id):
		sl._send_equipment(int(pid), peer_id, worn)

func _on_remote_player_state(peer_id: int, position: Vector3) -> void:
	if sl._role != sl.Role.HOST:
		return
	# Phase 19 — persist the client's last-known authoritative position so a
	# rejoining client can resume from it.
	var first_report = not sl.has_last_known_state(peer_id)
	sl.remember_player_state(peer_id, position, sl._inbound_exact)
	if first_report:
		sl.announce_equipment_to_aoi(peer_id)
	sl._refresh_equipment_pairs(peer_id)
	# Phase 97 — relay the peer's exact `{chunk, local}` when its report carried one, so a far-from-origin
	# avatar does not jitter by float32 metres on the other clients.
	var relayed: Dictionary = sl._inbound_exact if not sl._inbound_exact.is_empty() \
			else sl.WorldPos.from_world(position.x, position.y, position.z)
	# Phase 163 — queued for the frame's `player_states` batch (`flush_relays`), not sent one by one.
	sl._relays.offer(peer_id, sl.WorldPos.pos_to_packet_text(relayed), position)

## Phase 19 — a peer disconnecting does NOT erase its last-known position; it is
## retained (with a TTL) so a rejoining client resumes from where it left off and
## the record written at disconnect carries that position.
## A disconnect timestamp is set so _evict_stale_states() can expire the entry
## after LAST_KNOWN_STATE_TTL_MS if the peer never reconnects.
func _on_peer_disconnected(id: int) -> void:
	sl._malformed_position_warn_ms.erase(id)
	sl._m2._protocol_refused.erase(id)   # Phase 297
	GameBus.peer_disconnected.emit(id)
	# Phase 33 — the connection is gone, so its transport mapping goes with it.
	# The player's durable record stays on disk, which is what lets a reconnect
	# with the same player id re-bind to it; game_root writes it and then releases
	# the in-memory copy (PlayerRegistry.evict_player).
	sl.forget_player_id(id)
	sl._forget_equipment_pairs(id)
	sl._relays.forget(id)
	sl._m2.forget_peer_channels(id)
	if not sl._last_known_states.has(id):
		sl._teleport_pending.erase(id)   # nothing will age it out otherwise
	if sl._last_known_states.has(id):
		sl._last_known_timestamps[id] = Time.get_ticks_msec()

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
