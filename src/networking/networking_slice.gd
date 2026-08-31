extends Node
## Networking slice — authoritative host/client model (Phase 18), hardened
## against real network conditions (Phase 19).
##
## The host runs the authoritative simulation (terrain, creature AI, combat,
## voxel edits, loot). Clients send their local input and block-edit intents
## to the host, and apply authoritative state deltas the host broadcasts back.
## A client never mutates world state on its own — every block edit and
## creature state change flows through the host.
##
## Phase 19 adds chaos resilience: a configurable network emulator (jitter,
## loss, reordering), sequence-numbered packets with duplicate/out-of-order
## discard and gap detection, a client-side jitter buffer for remote-player
## snapshots, and a host-side last-known-state store for disconnect/reconnect
## resume. The emulator is disabled by default (zero overhead in production).
##
## Plug contract (GameBus signals consumed / emitted):
##   IN  : packet_send_requested(peer_id, payload)   — legacy low-level send
##         player_state_sync_requested(payload)      — local player state
##         block_edit_intent(action, pos, normal, mat) — client wants an edit
##         block_changed(action, pos, normal, mat)   — host authoritative edit
##         creature_state_changed(iid, state, pos)   — host authoritative delta
##         remote_player_state(peer_id, pos)         — host player ghost update
##         inventory_synced(contents)                — host authoritative contents
##   OUT : peer_connected(peer_id)
##         peer_disconnected(peer_id)
##         packet_received(peer_id, payload)         — legacy low-level receive
##         block_edit_intent(...)                     — re-emitted on host from wire
##         block_changed(...)                         — re-emitted on client from wire
##         creature_state_changed(...)                — re-emitted on client
##         remote_player_state(...)                   — re-emitted on client
##         inventory_synced(...)                      — re-emitted on client
##         world_snapshot_received(data)              — client received snapshot
##
## Public API:
##   host(port, max_clients) -> Error
##   join(address, port)     -> Error
##   disconnect_all()        -> void
##   is_host() / is_client() / is_offline() -> bool
##   send_snapshot(peer_id, data) -> void    — host → one client
##   remember_player_state(peer_id, pos) -> void   — Phase 19
##   get_last_known_state(peer_id) -> Vector3      — Phase 19
##   get_last_known_states() -> Dictionary         — Phase 19

enum Role { OFFLINE, HOST, CLIENT }

const DEFAULT_PORT    := 7777
const DEFAULT_CHANNEL := 0
## Max JSON chars per snapshot chunk (≈ bytes for ASCII). Large snapshots are
## split across multiple reliable packets and reassembled on the client.
const SNAPSHOT_CHUNK_SIZE := 16384

## Phase 19 — maximum packet-loss percentage the emulator will accept.
const MAX_LOSS_RATE := 30.0

var _peer: ENetMultiplayerPeer
var _role: int = Role.OFFLINE

## Snapshot reassembly state (client): snapshot_id → { count, received, parts }.
var _snapshot_buffer: Dictionary = {}
var _next_snapshot_id: int = 0

# ---------------------------------------------------------------------------
# Phase 19 — chaos resilience configuration
# ---------------------------------------------------------------------------

## Network emulator: when enabled, outbound packets are subjected to jitter,
## loss, and reordering. Disabled by default in production (zero overhead).
@export var emulate_network: bool = false
## Packet-loss rate as a percentage (0.0–30.0). Only active when emulate_network.
@export var emulator_loss_rate: float = 0.0
## Artificial jitter as a ±N ms delivery delay. Only active when emulate_network.
@export var emulator_jitter_ms: float = 0.0
## Reorder adjacent queued packets to model out-of-order delivery.
@export var emulator_reorder: bool = false

## Sequence numbering: every outbound packet carries a per-type monotonic seq;
## the receiver uses it to drop duplicates and detect gaps.
## _send_seq is keyed on packet type so interleaved types don't create false gaps.
var _send_seq: Dictionary = {}          # packet_type -> next seq int
## _recv_seq is keyed on "peer_id:packet_type" to namespace each type independently.
var _recv_seq: Dictionary = {}          # "peer:type" -> highest seq seen
## Sliding dedup window: keeps recently-seen seqs per "peer:type" channel.
var _recv_seen: Dictionary = {}         # "peer:type" -> {seq -> true}
const DEDUP_WINDOW := 64               # number of recent seqs to remember
## Rate-limit seq-gap warnings to one per second per channel.
var _seq_gap_warn_ms: Dictionary = {}  # "peer:type" -> last warn time_ms
const SEQ_GAP_WARN_INTERVAL_MS := 1000.0
var _rng := RandomNumberGenerator.new()

## Emulator delivery queue: { at_ms, peer_id, json }, drained by _process.
var _pending: Array = []

## Jitter buffer (client): peer_id -> Array of { at_ms, position }.
var jitter_buffer_ms: float = 100.0
var _jitter_buffer: Dictionary = {}

## Host-side last-known player states (peer_id -> Vector3), retained across a
## disconnect so a rejoining client can resume from its last position.
var _last_known_states: Dictionary = {}
## Timestamps (peer_id -> ms) set when a peer disconnects; used to evict
## entries from _last_known_states after LAST_KNOWN_STATE_TTL_MS.
var _last_known_timestamps: Dictionary = {}
const LAST_KNOWN_STATE_TTL_MS := 300_000  # 5 minutes

func _ready() -> void:
	GameBus.packet_send_requested.connect(_on_packet_send_requested)
	GameBus.player_state_sync_requested.connect(_on_player_state_sync_requested)
	GameBus.block_edit_intent.connect(_on_block_edit_intent)
	GameBus.block_changed.connect(_on_block_changed)
	GameBus.creature_state_changed.connect(_on_creature_state_changed)
	GameBus.remote_player_state.connect(_on_remote_player_state)
	GameBus.inventory_synced.connect(_on_inventory_synced)
	# Phase 24 — social/economy replication.
	GameBus.market_synced.connect(_on_market_synced)
	GameBus.governance_synced.connect(_on_governance_synced)
	GameBus.trade_completed.connect(_on_trade_completed)
	GameBus.market_list_intent.connect(_on_market_list_intent)
	GameBus.market_buy_intent.connect(_on_market_buy_intent)
	GameBus.proposal_submit_intent.connect(_on_proposal_submit_intent)
	GameBus.proposal_vote_intent.connect(_on_proposal_vote_intent)
	GameBus.proposal_supersede_intent.connect(_on_proposal_supersede_intent)
	GameBus.trade_synced.connect(_on_trade_synced)
	GameBus.trade_start_intent.connect(_on_trade_start_intent)
	GameBus.trade_propose_intent.connect(_on_trade_propose_intent)
	GameBus.trade_accept_intent.connect(_on_trade_accept_intent)
	GameBus.trade_reject_intent.connect(_on_trade_reject_intent)

## Phase 19 — drain the emulator queue and (on clients) the jitter buffer.
## Eviction of stale last-known-states runs unconditionally (no ENet overhead).
func _process(_delta: float) -> void:
	_evict_stale_states()
	if not emulate_network:
		return
	_drain_emulator()
	if _role == Role.CLIENT:
		_drain_jitter_buffer()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Start an authoritative ENet server. Sets the slice to HOST role.
func host(port: int = DEFAULT_PORT, max_clients: int = 64) -> Error:
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(port, max_clients)
	if err != OK:
		push_error("NetworkingSlice: failed to create server on port %d — %s" % [port, error_string(err)])
		return err
	_role = Role.HOST
	_attach_peer()
	print("NetworkingSlice: hosting on port %d" % port)
	return OK

## Connect to a remote host. Sets the slice to CLIENT role.
func join(address: String = "127.0.0.1", port: int = DEFAULT_PORT) -> Error:
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(address, port)
	if err != OK:
		push_error("NetworkingSlice: failed to connect to %s:%d — %s" % [address, port, error_string(err)])
		return err
	_role = Role.CLIENT
	_attach_peer()
	print("NetworkingSlice: connecting to %s:%d" % [address, port])
	return OK

## Tear down the peer and return to offline role.
func disconnect_all() -> void:
	if _peer:
		_peer.close()
	_detach_peer()
	multiplayer.multiplayer_peer = null
	_role = Role.OFFLINE
	_pending.clear()
	_jitter_buffer.clear()

func is_host() -> bool:
	return _role == Role.HOST

func is_client() -> bool:
	return _role == Role.CLIENT

func is_offline() -> bool:
	return _role == Role.OFFLINE

## Host → one client: send the initial world snapshot, split into fixed-size
## chunks so a large world (many heightmaps + creatures + edits) never exceeds
## a single reliable packet. The client reassembles chunks by snapshot_id.
func send_snapshot(peer_id: int, data: Dictionary) -> void:
	if not _role == Role.HOST:
		push_warning("NetworkingSlice: send_snapshot called on non-host — dropped")
		return
	var json := JSON.stringify(data)
	var chunk_count := maxi(1, ceili(float(json.length()) / float(SNAPSHOT_CHUNK_SIZE)))
	var snapshot_id: int = _next_snapshot_id
	_next_snapshot_id += 1
	for i in range(chunk_count):
		var packet := {
			"type":        "snapshot_chunk",
			"snapshot_id": snapshot_id,
			"index":       i,
			"count":       chunk_count,
			"data":        json.substr(i * SNAPSHOT_CHUNK_SIZE, SNAPSHOT_CHUNK_SIZE),
		}
		_deliver(peer_id, packet)

# ---------------------------------------------------------------------------
# Phase 19 — reconnect resume (host side)
# ---------------------------------------------------------------------------

## Record a client's last-known authoritative position. Retained across a
## disconnect so a rejoining client resumes from where it left off.
## Clears the eviction countdown: an active peer is never stale.
func remember_player_state(peer_id: int, position: Vector3) -> void:
	_last_known_states[peer_id] = position
	_last_known_timestamps.erase(peer_id)

## Last-known position for a peer, or Vector3.ZERO when unknown.
func get_last_known_state(peer_id: int) -> Vector3:
	return _last_known_states.get(peer_id, Vector3.ZERO)

## All retained player states, for folding into a reconnect world snapshot.
func get_last_known_states() -> Dictionary:
	return _last_known_states.duplicate(true)

## Evict last-known states for peers that have been disconnected longer than
## LAST_KNOWN_STATE_TTL_MS. Called every frame from _process() so the host
## dict doesn't grow without bound over long sessions.
func _evict_stale_states() -> void:
	if _last_known_timestamps.is_empty():
		return
	var now_ms: float = float(Time.get_ticks_msec())
	for pid: int in _last_known_timestamps.keys():
		if now_ms - float(_last_known_timestamps[pid]) > float(LAST_KNOWN_STATE_TTL_MS):
			_last_known_states.erase(pid)
			_last_known_timestamps.erase(pid)

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _connected() -> bool:
	var mp_peer := multiplayer.multiplayer_peer
	if mp_peer == null:
		return false
	return mp_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

## Broadcast a packet dict to every peer (host) or to the host (client),
## routing through the Phase 19 emulator.
func _broadcast(payload: Dictionary) -> void:
	if not _connected():
		return
	if _role == Role.HOST:
		for pid in multiplayer.get_peers():
			_deliver(pid, payload.duplicate(true))
	elif _role == Role.CLIENT:
		_deliver(1, payload)

## Central outbound path (Phase 19). Attach a per-type monotonic seq, then
## either send immediately (emulation disabled — zero overhead) or queue for
## emulated delivery (loss / jitter / reorder).
func _deliver(peer_id: int, payload: Dictionary) -> void:
	var ptype: String = str(payload.get("type", "_"))
	if not _send_seq.has(ptype):
		_send_seq[ptype] = 0
	payload["seq"] = _send_seq[ptype]
	_send_seq[ptype] += 1
	var json := JSON.stringify(payload)
	if not emulate_network:
		_send_raw(peer_id, json)
		return
	if _should_drop():
		return
	var at_ms: float = float(Time.get_ticks_msec()) + _jitter_delay_ms()
	_pending.append({ "at_ms": at_ms, "peer_id": peer_id, "json": json })
	if emulator_reorder:
		_maybe_reorder()

## Perform the actual RPC send. Host → client uses _rpc_h2c (authority), client
## → host uses _rpc_c2h. No-op when no peer is attached (isolated tests).
func _send_raw(peer_id: int, json: String) -> void:
	if _peer == null:
		return
	if _role == Role.HOST:
		_rpc_h2c.rpc_id(peer_id, json)
	elif _role == Role.CLIENT:
		_rpc_c2h.rpc_id(1, json)

# ---------------------------------------------------------------------------
# GameBus → wire (outbound)
# ---------------------------------------------------------------------------

func _on_player_state_sync_requested(payload: Dictionary) -> void:
	if not _connected():
		return
	var pos: Vector3 = payload.get("position", Vector3.ZERO)
	var packet := {
		"type":     "player_moved",
		"peer_id":  multiplayer.get_unique_id(),
		"position": [pos.x, pos.y, pos.z],
		"hp":       payload.get("hp",     100.0),
		"max_hp":   payload.get("max_hp", 100.0),
	}
	_broadcast(packet)

func _on_block_edit_intent(action: String, position: Vector3, normal: Vector3, material: String) -> void:
	if _role != Role.CLIENT:
		# Host applies edits directly through the voxel slice; only clients
		# forward intents to the host.
		return
	var packet := {
		"type":     "block_edit_intent",
		"action":   action,
		"position": [position.x, position.y, position.z],
		"normal":   [normal.x, normal.y, normal.z],
		"material": material,
	}
	_broadcast(packet)

func _on_block_changed(action: String, position: Vector3, normal: Vector3, material: String) -> void:
	if _role != Role.HOST:
		return
	var packet := {
		"type":     "block_changed",
		"action":   action,
		"position": [position.x, position.y, position.z],
		"normal":   [normal.x, normal.y, normal.z],
		"material": material,
	}
	_broadcast(packet)

func _on_creature_state_changed(instance_id: String, creature_id: String, state: String, position: Vector3) -> void:
	if _role != Role.HOST:
		return
	var packet := {
		"type":        "creature_state_changed",
		"instance_id": instance_id,
		"creature_id": creature_id,
		"state":       state,
		"position":    [position.x, position.y, position.z],
	}
	_broadcast(packet)

func _on_remote_player_state(peer_id: int, position: Vector3) -> void:
	if _role != Role.HOST:
		return
	# Phase 19 — persist the client's last-known authoritative position so a
	# rejoining client can resume from it.
	remember_player_state(peer_id, position)
	var packet := {
		"type":     "remote_player_state",
		"peer_id":  peer_id,
		"position": [position.x, position.y, position.z],
	}
	_broadcast(packet)

func _on_inventory_synced(contents: Dictionary) -> void:
	if _role != Role.HOST:
		return
	var packet := {
		"type":     "inventory_synced",
		"contents": contents,
	}
	_broadcast(packet)

# ---------------------------------------------------------------------------
# Phase 24 — social/economy replication (host → clients authoritative state,
# client → host intents)
# ---------------------------------------------------------------------------

func _on_market_synced(data: Dictionary) -> void:
	if _role != Role.HOST:
		return
	_broadcast({ "type": "market_synced", "data": data })

func _on_governance_synced(data: Dictionary) -> void:
	if _role != Role.HOST:
		return
	_broadcast({ "type": "governance_synced", "data": data })

func _on_trade_completed(trade: Dictionary) -> void:
	if _role != Role.HOST:
		return
	_broadcast({ "type": "trade_completed", "trade": trade })

func _on_market_list_intent(seller: String, item_id: String, quantity: int, price: float) -> void:
	if _role != Role.CLIENT:
		return
	_broadcast({ "type": "market_list_intent", "seller": seller, "item_id": item_id, "quantity": quantity, "price": price })

func _on_market_buy_intent(listing_id: String, buyer: String) -> void:
	if _role != Role.CLIENT:
		return
	_broadcast({ "type": "market_buy_intent", "listing_id": listing_id, "buyer": buyer })

func _on_proposal_submit_intent(author: String, title: String, body: String) -> void:
	if _role != Role.CLIENT:
		return
	_broadcast({ "type": "proposal_submit_intent", "author": author, "title": title, "body": body })

func _on_proposal_vote_intent(proposal_id: String, voter: String, verdict: String) -> void:
	if _role != Role.CLIENT:
		return
	_broadcast({ "type": "proposal_vote_intent", "proposal_id": proposal_id, "voter": voter, "verdict": verdict })

func _on_proposal_supersede_intent(proposal_id: String, replacement_id: String) -> void:
	if _role != Role.CLIENT:
		return
	_broadcast({ "type": "proposal_supersede_intent", "proposal_id": proposal_id, "replacement_id": replacement_id })

func _on_trade_synced(data: Dictionary) -> void:
	if _role != Role.HOST:
		return
	_broadcast({ "type": "trade_synced", "data": data })

func _on_trade_start_intent(party_a: String, party_b: String) -> void:
	if _role != Role.CLIENT:
		return
	_broadcast({ "type": "trade_start_intent", "party_a": party_a, "party_b": party_b })

func _on_trade_propose_intent(trade_id: String, party: String, give: Dictionary, want: Dictionary) -> void:
	if _role != Role.CLIENT:
		return
	_broadcast({ "type": "trade_propose_intent", "trade_id": trade_id, "party": party, "give": give, "want": want })

func _on_trade_accept_intent(trade_id: String, party: String) -> void:
	if _role != Role.CLIENT:
		return
	_broadcast({ "type": "trade_accept_intent", "trade_id": trade_id, "party": party })

func _on_trade_reject_intent(trade_id: String, party: String) -> void:
	if _role != Role.CLIENT:
		return
	_broadcast({ "type": "trade_reject_intent", "trade_id": trade_id, "party": party })

func _on_packet_send_requested(peer_id: int, payload: Dictionary) -> void:
	# Legacy low-level send: wraps an arbitrary payload and ships it as-is.
	if not _connected():
		return
	if _role == Role.HOST:
		_deliver(peer_id, payload.duplicate(true))
	else:
		_deliver(1, payload)

# ---------------------------------------------------------------------------
# Wire → GameBus (inbound)
# ---------------------------------------------------------------------------

## Client → host channel: input and edit intents from a client.
@rpc("any_peer", "reliable")
func _rpc_c2h(json: String) -> void:
	var sender := multiplayer.get_remote_sender_id()
	var payload = _parse(json)
	if payload == null:
		return
	if not _dedup(sender, payload):
		return
	_route_c2h(sender, payload)

## Host → client channel: authoritative state and the world snapshot.
@rpc("authority", "reliable")
func _rpc_h2c(json: String) -> void:
	var payload = _parse(json)
	if payload == null:
		return
	# Snapshot chunks are index-reassembled (out-of-order tolerant) and made
	# idempotent separately; every other packet type is seq-deduplicated.
	if str(payload.get("type", "")) != "snapshot_chunk":
		if not _dedup(multiplayer.get_remote_sender_id(), payload):
			return
	_route_h2c(payload)

func _parse(json: String) -> Variant:
	var payload = JSON.parse_string(json)
	if payload == null:
		push_error("NetworkingSlice: malformed JSON packet dropped")
		return null
	if not payload is Dictionary:
		push_error("NetworkingSlice: expected Dictionary packet, got %s" % typeof(payload))
		return null
	return payload

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

	if not _recv_seen.has(key):
		_recv_seen[key] = {}
	var seen: Dictionary = _recv_seen[key]

	# True duplicate: this exact seq was already accepted in the window.
	if seen.has(seq):
		return false

	var last: int = _recv_seq.get(key, -1)

	# Too stale: more than DEDUP_WINDOW behind the frontier — cannot reorder.
	if last >= 0 and seq < last - DEDUP_WINDOW:
		return false

	# Forward gap (packet loss): log at most once per second per channel.
	if last >= 0 and seq > last + 1:
		var now_ms: float = float(Time.get_ticks_msec())
		var gap_last: float = float(_seq_gap_warn_ms.get(key, -SEQ_GAP_WARN_INTERVAL_MS))
		if now_ms - gap_last >= SEQ_GAP_WARN_INTERVAL_MS:
			push_warning("NetworkingSlice: seq gap — peer %d type '%s' frontier %d got %d" \
				% [sender, ptype, last, seq])
			_seq_gap_warn_ms[key] = now_ms

	# Mark seen and prune entries beyond the window.
	seen[seq] = true
	var cutoff: int = seq - DEDUP_WINDOW
	for k: int in seen.keys():
		if k < cutoff:
			seen.erase(k)

	# Advance the frontier only when this seq is higher.
	if seq > last:
		_recv_seq[key] = seq

	return true

## Resolve a client's self-reference to a peer-scoped party id. A client sends
## the literal "player" to mean "me", but on the host every remote client would
## collide on that string and resolve to the host's own inventory. Rewriting
## "player" → "peer_<id>" keeps each peer's market/trade/proposal actions aimed
## at that peer, never at the host's "player" identity.
func _peer_party(sender: int, party: String) -> String:
	if party == "player":
		return "peer_%d" % sender
	return party

## Route a client → host packet. Only client-originated types are accepted;
## host-only types sent by a malicious client are dropped and logged.
func _route_c2h(sender: int, payload: Dictionary) -> void:
	match str(payload.get("type", "")):
		"player_moved":
			var pos := _vec3(payload.get("position", []))
			GameBus.remote_player_state.emit(sender, pos)
		"block_edit_intent":
			var action := str(payload.get("action", ""))
			var ipos := _vec3(payload.get("position", []))
			var inorm := _vec3(payload.get("normal", [0, 1, 0]))
			if action == "mine":
				GameBus.block_mine_requested.emit(ipos, inorm)
			elif action == "place":
				GameBus.block_place_requested.emit(ipos, inorm)
			else:
				push_error("NetworkingSlice: unknown block_edit_intent action '%s'" % action)
		"market_list_intent":
			GameBus.market_list_intent.emit(
				_peer_party(sender, str(payload.get("seller", ""))),
				str(payload.get("item_id", "")),
				int(payload.get("quantity", 0)),
				float(payload.get("price", 0.0))
			)
		"market_buy_intent":
			GameBus.market_buy_intent.emit(
				str(payload.get("listing_id", "")),
				_peer_party(sender, str(payload.get("buyer", "")))
			)
		"proposal_submit_intent":
			GameBus.proposal_submit_intent.emit(
				_peer_party(sender, str(payload.get("author", ""))),
				str(payload.get("title", "")),
				str(payload.get("body", ""))
			)
		"proposal_vote_intent":
			GameBus.proposal_vote_intent.emit(
				str(payload.get("proposal_id", "")),
				_peer_party(sender, str(payload.get("voter", ""))),
				str(payload.get("verdict", ""))
			)
		"proposal_supersede_intent":
			GameBus.proposal_supersede_intent.emit(
				str(payload.get("proposal_id", "")),
				str(payload.get("replacement_id", ""))
			)
		"trade_start_intent":
			GameBus.trade_start_intent.emit(
				_peer_party(sender, str(payload.get("party_a", ""))),
				str(payload.get("party_b", ""))
			)
		"trade_propose_intent":
			GameBus.trade_propose_intent.emit(
				str(payload.get("trade_id", "")),
				_peer_party(sender, str(payload.get("party", ""))),
				payload.get("give", {}),
				payload.get("want", {})
			)
		"trade_accept_intent":
			GameBus.trade_accept_intent.emit(
				str(payload.get("trade_id", "")),
				_peer_party(sender, str(payload.get("party", "")))
			)
		"trade_reject_intent":
			GameBus.trade_reject_intent.emit(
				str(payload.get("trade_id", "")),
				_peer_party(sender, str(payload.get("party", "")))
			)
		_:
			# Clients may not send host-authoritative types (block_changed,
			# inventory_synced, etc.) — drop anything else and log it.
			push_warning("NetworkingSlice: unexpected type '%s' from client %d — dropped" \
				% [payload.get("type", ""), sender])

## Route a host → client packet. Only host-originated types are handled.
func _route_h2c(payload: Dictionary) -> void:
	match str(payload.get("type", "")):
		"player_moved":
			# The host's own movement arrives as player_moved (peer_id == host id).
			var pos := _vec3(payload.get("position", []))
			GameBus.remote_player_state.emit(int(payload.get("peer_id", 1)), pos)
		"block_changed":
			GameBus.block_changed.emit(
				str(payload.get("action", "")),
				_vec3(payload.get("position", [])),
				_vec3(payload.get("normal", [0, 1, 0])),
				str(payload.get("material", ""))
			)
		"creature_state_changed":
			GameBus.creature_state_changed.emit(
				str(payload.get("instance_id", "")),
				str(payload.get("creature_id", "")),
				str(payload.get("state", "")),
				_vec3(payload.get("position", []))
			)
		"remote_player_state":
			_route_remote_player_state(payload)
		"inventory_synced":
			GameBus.inventory_synced.emit(payload.get("contents", {}))
		"market_synced":
			GameBus.market_synced.emit(payload.get("data", {}))
		"governance_synced":
			GameBus.governance_synced.emit(payload.get("data", {}))
		"trade_synced":
			GameBus.trade_synced.emit(payload.get("data", {}))
		"trade_completed":
			GameBus.trade_completed.emit(payload.get("trade", {}))
		"world_snapshot":
			GameBus.world_snapshot_received.emit(payload.get("data", {}))
		"snapshot_chunk":
			_accumulate_snapshot_chunk(payload)
		_:
			# Legacy low-level packets fall through to packet_received.
			GameBus.packet_received.emit(1, payload)

## Remote-player state on the client: when emulation is enabled, buffer and
## replay through the jitter buffer; otherwise emit straight through (the
## Phase 18 path, unchanged).
func _route_remote_player_state(payload: Dictionary) -> void:
	var pid := int(payload.get("peer_id", 0))
	var pos := _vec3(payload.get("position", []))
	if emulate_network and _role == Role.CLIENT:
		_buffer_remote_state(pid, pos)
	else:
		GameBus.remote_player_state.emit(pid, pos)

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
		push_error("NetworkingSlice: malformed snapshot_chunk dropped")
		return
	if not _snapshot_buffer.has(snapshot_id):
		_snapshot_buffer[snapshot_id] = { "count": count, "received": 0, "parts": [] }
	var entry: Dictionary = _snapshot_buffer[snapshot_id]
	while entry["parts"].size() < count:
		entry["parts"].append("")
	# Idempotent: only count a chunk once, so a duplicate (emulator re-delivery)
	# never double-increments `received` and prematurely completes reassembly.
	if entry["parts"][index] == "":
		entry["parts"][index] = chunk
		entry["received"] += 1
	if entry["received"] >= count:
		_snapshot_buffer.erase(snapshot_id)
		var full := ""
		for part in entry["parts"]:
			full += part
		var data = JSON.parse_string(full)
		if data is Dictionary:
			GameBus.world_snapshot_received.emit(data)
		else:
			push_error("NetworkingSlice: snapshot reassembly produced invalid JSON")

func _vec3(arr) -> Vector3:
	if arr is Array and arr.size() >= 3:
		return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
	return Vector3.ZERO

# ---------------------------------------------------------------------------
# Phase 19 — network emulator
# ---------------------------------------------------------------------------

## Loss decision: true to DROP the packet. Loss rate is clamped to
## [0, MAX_LOSS_RATE]. Pure and deterministic under a seeded `_rng`.
func _should_drop() -> bool:
	var rate: float = clampf(emulator_loss_rate, 0.0, MAX_LOSS_RATE)
	if rate <= 0.0:
		return false
	return _rng.randf() * 100.0 < rate

## Jitter delay: uniformly distributed in [-emulator_jitter_ms, +emulator_jitter_ms].
## Negative values are delivered immediately by _drain_emulator (at_ms in the past).
## The distribution is centered at zero — no positive bias.
func _jitter_delay_ms() -> float:
	if emulator_jitter_ms <= 0.0:
		return 0.0
	return _rng.randf_range(-emulator_jitter_ms, emulator_jitter_ms)

## Reorder: swap two adjacent pending packets with a small probability to
## model out-of-order delivery.
func _maybe_reorder() -> void:
	if _pending.size() < 2:
		return
	if _rng.randf() < 0.25:
		var i := _rng.randi_range(0, _pending.size() - 2)
		var tmp: Dictionary = _pending[i]
		_pending[i] = _pending[i + 1]
		_pending[i + 1] = tmp

## Drain the emulator queue, delivering due packets via the real RPC.
func _drain_emulator() -> void:
	var now := float(Time.get_ticks_msec())
	var i := 0
	while i < _pending.size():
		var entry: Dictionary = _pending[i]
		if float(entry["at_ms"]) <= now:
			_send_raw(int(entry["peer_id"]), str(entry["json"]))
			_pending.remove_at(i)
		else:
			i += 1

# ---------------------------------------------------------------------------
# Phase 19 — jitter buffer (client)
# ---------------------------------------------------------------------------

## Push a remote-player snapshot into the jitter buffer.
func _buffer_remote_state(peer_id: int, position: Vector3) -> void:
	var at_ms := float(Time.get_ticks_msec())
	if not _jitter_buffer.has(peer_id):
		_jitter_buffer[peer_id] = []
	_jitter_buffer[peer_id].append({ "at_ms": at_ms, "position": position })

## Sample the buffered snapshots for `peer_id` at playback time
## (now_ms - jitter_buffer_ms), interpolating between the two surrounding
## snapshots. Pure — accepts an explicit clock for tests.
func _sample_remote_state_at(peer_id: int, now_ms: float) -> Vector3:
	var queue: Array = _jitter_buffer.get(peer_id, [])
	if queue.is_empty():
		return Vector3.ZERO
	var play: float = now_ms - jitter_buffer_ms
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

## Drop buffered snapshots older than the playback window.
func _prune_jitter_buffer(peer_id: int, now_ms: float) -> void:
	if not _jitter_buffer.has(peer_id):
		return
	var queue: Array = _jitter_buffer[peer_id]
	var cutoff: float = now_ms - jitter_buffer_ms - 1000.0
	while queue.size() > 1 and float(queue[0]["at_ms"]) < cutoff:
		queue.pop_front()

## Replay buffered snapshots on the fixed playback delay, emitting the
## interpolated remote-player state to the bus.
func _drain_jitter_buffer() -> void:
	var now := float(Time.get_ticks_msec())
	for peer_id in _jitter_buffer:
		var queue: Array = _jitter_buffer[peer_id]
		if queue.is_empty():
			continue
		var pos: Vector3 = _sample_remote_state_at(int(peer_id), now)
		GameBus.remote_player_state.emit(int(peer_id), pos)
		_prune_jitter_buffer(int(peer_id), now)

# ---------------------------------------------------------------------------
# Peer lifecycle
# ---------------------------------------------------------------------------

func _attach_peer() -> void:
	_detach_peer()
	multiplayer.multiplayer_peer = _peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _detach_peer() -> void:
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)

func _on_peer_connected(id: int) -> void:
	GameBus.peer_connected.emit(id)

## Phase 19 — a peer disconnecting does NOT erase its last-known state; the
## record is retained so a rejoining client resumes from its last position.
## A disconnect timestamp is set so _evict_stale_states() can expire the entry
## after LAST_KNOWN_STATE_TTL_MS if the peer never reconnects.
func _on_peer_disconnected(id: int) -> void:
	GameBus.peer_disconnected.emit(id)
	if _last_known_states.has(id):
		_last_known_timestamps[id] = Time.get_ticks_msec()
