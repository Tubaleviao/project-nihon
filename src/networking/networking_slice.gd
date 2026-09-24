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
## Phase 36 adds the inbound trust boundary. The host acts only on what it can
## verify about the CONNECTION, never on what a payload claims about identity:
## every acting party (market seller/buyer, proposal author/voter, trade
## propose/accept/reject, craft/repair/research/tame) is the player id bound to the
## sending connection, and a peer that has not completed the handshake cannot act
## at all. World edits additionally have to land within arm's reach of the position
## the host last saw that peer at (`MAX_EDIT_REACH`), a client packet is capped at
## `MAX_CLIENT_PACKET_BYTES`, and each peer draws from its own token bucket
## (`RATE_BUCKET_CAPACITY`) so one connection cannot flood the authoritative
## process. The only identity a payload may name is a trade invite's counterparty,
## which is resolved against the registry's ONLINE set (`resolve_named_party`).
##
## Plug contract (GameBus signals consumed / emitted):
##   IN  : packet_send_requested(peer_id, payload)   — legacy low-level send
##         player_state_sync_requested(payload)      — local player state
##         block_edit_intent(action, pos, normal, mat) — client wants an edit
##         block_changed(action, pos, normal, mat)   — host authoritative edit
##         creature_state_changed(iid, state, pos)   — host authoritative delta
##         remote_player_state(peer_id, pos)         — host player ghost update
##         inventory_synced(owner_id, contents, durabilities) — one player's contents
##                                          (host → that player's peer only, Phase 37)
##         player_damaged(damage, attacker_id, target_id) — a round that landed on a
##                                          player (host → the target's peer, Phase 37)
##         tree_chop_requested(tree_id)              — client wants to fell a tree
##         tree_chopped(tree_id, wood, state, at)    — host authoritative chop
##         tree_respawned(tree_id)                   — host authoritative regrowth
##         craft_intent(recipe_id, player_id)        — client wants to craft
##         repair_intent(item_id, player_id)         — client wants to repair
##         research_intent(tech_id, player_id)       — client wants to research
##         tame_intent(instance_id, player_id)       — client wants to tame
##   OUT : peer_connected(peer_id)
##         peer_disconnected(peer_id)
##         packet_received(peer_id, payload)         — legacy low-level receive
##         block_edit_intent(...)                     — re-emitted on host from wire
##         block_changed(...)                         — re-emitted on client from wire
##         creature_state_changed(...)                — re-emitted on client
##         remote_player_state(...)                   — re-emitted on client
##         inventory_synced(...)                      — re-emitted on client
##         craft_intent(...)                          — re-emitted on host from wire
##         repair_intent(...)                         — re-emitted on host from wire
##         research_intent(...)                       — re-emitted on host from wire
##         own_state_synced(data)                     — re-emitted on client
##         world_snapshot_received(data)              — client received snapshot
##
## Public API:
##   host(port, max_clients) -> Error
##   join(address, port)     -> Error
##   disconnect_all()        -> void
##   is_host() / is_client() / is_offline() -> bool
##   send_snapshot(peer_id, data) -> void    — host → one client
##   send_own_state(peer_id, data) -> void   — host → one client (Phase 34)
##   send_player_damaged(peer_id, damage, attacker_id) -> void  — host → one client (Phase 37)
##   remember_player_state(peer_id, pos) -> void   — Phase 19
##   get_last_known_state(peer_id) -> Vector3      — Phase 19
##   get_last_known_states() -> Dictionary         — Phase 19
##   has_last_known_state(peer_id) -> bool
##   request_handshake() -> void                   — re-present the join intent

enum Role { OFFLINE, HOST, CLIENT }

## Spatial hash over connected peers' AOI centers so interest filtering is an
## O(radius²)-cells query, not an O(peers) scan (Phase 29).
const SpatialHash := preload("res://src/core/spatial_hash.gd")

## Phase 36 — the registry's id-SHAPE predicate, preloaded for the redactor: it is a
## pure static check on a string, and the redactor must recognise a bearer token even
## when no registry is in the tree (an offline seller's id lives on inside a persisted
## listing long after their record was evicted).
const PlayerRegistry := preload("res://src/persistence/player_registry.gd")

const DEFAULT_PORT    := 7777
const DEFAULT_CHANNEL := 0
## Default max peers for a dedicated/headless server (the single-player demo
## host caps at 1). ENet's practical ceiling; see Phase 29 interest management.
const DEFAULT_MAX_CLIENTS := 64
## Max JSON chars per snapshot chunk (≈ bytes for ASCII). Large snapshots are
## split across multiple reliable packets and reassembled on the client.
const SNAPSHOT_CHUNK_SIZE := 16384

## Phase 19 — maximum packet-loss percentage the emulator will accept.
const MAX_LOSS_RATE := 30.0

## Phase 29 — area-of-interest radius (world units). A client receives deltas
## and snapshot entities within this radius of its position; anything farther is
## not sent. 96 units = 3 chunks (CHUNK_SIZE 32), matching the chunk-streaming
## view distance so interest and streaming agree.
const AOI_RADIUS := 96.0
## AOI center used for a peer that has not reported a position yet (freshly
## connected). Matches the world spawn point so the initial snapshot is scoped
## around where players first appear.
const DEFAULT_AOI_CENTER := Vector3(16.0, 0.0, 16.0)

## Phase 36 — reach limit (world units) for a wire-supplied world edit. Mirrors
## PlayerSlice.BUILD_RANGE / CHOP_RANGE (60 m: the aim-ray reach the local client
## applies to itself). The host re-checks a remote peer's edit against the distance
## its OWN recorded position allows, so a client cannot mine, build or fell what it
## is nowhere near — the client-side range is a convenience for the player, never
## the gate. Mirrored instead of imported: this slice must not depend on the local
## player's presentation slice to police the wire.
const MAX_EDIT_REACH := 60.0

## Phase 36 — largest client → host packet accepted, in JSON characters (≈ bytes
## for ASCII). A client's packet is an unverified claim, so the cap keeps one peer
## from making the authoritative process parse an arbitrarily large payload — a
## CPU/heap denial of service against the host. Host → client packets are NOT
## capped: the host is the only writer there, and a world snapshot is legitimately
## far larger than this.
const MAX_CLIENT_PACKET_BYTES := 8192

## Phase 36 — per-peer client → host rate limit, a token bucket: `CAPACITY` tokens
## to start (enough for a join burst) refilled at `REFILL_PER_SEC`, one token per
## accepted packet. Movement is the chattiest legitimate traffic (one packet per
## frame, ~60/s), so the refill is set above that; what the bucket stops is one peer
## flooding the host with fresh intents (edit spam, market/proposal spam). The
## Phase 19 dedup cannot: it rejects a REPLAYED seq, never a new one.
const RATE_BUCKET_CAPACITY := 120.0
const RATE_BUCKET_REFILL_PER_SEC := 40.0

## Phase 36 — the replicated blobs whose CONTENTS name players: a listing's seller, a
## trade's parties (values AND the keys of `offers`/`accepted`), a proposal's author
## and its `votes` keys. Written with player ids on the authority side and redacted to
## public handles before they cross the wire. One list, so the world snapshot
## (game_root) and the delta broadcasts cannot disagree about which parts of the world
## are identity-bearing.
const IDENTIFIED_STATE_KEYS: PackedStringArray = ["market", "governance", "trade"]

## Phase 36 — the public handle THIS client was told to call itself (see
## `identity_assigned`). A client is shown its own handle back as the literal
## "player", so its local view keeps the convention it has always had.
var claimed_handle: String = ""

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

## Phase 33 — transport mapping only: peer_id (ENet, reassigned every connection)
## → player_id (server-issued, stable). Every player-scoped record and inventory
## is keyed on the player_id; this dict is thrown away on disconnect.
var _player_ids: Dictionary = {}

## Phase 33 — the id this client last received from a host, presented on join so
## a reconnect re-binds to the same record. Set by game_root before join().
var claimed_player_id: String = ""

## Timestamps (peer_id -> ms) set when a peer disconnects; used to evict
## entries from _last_known_states after LAST_KNOWN_STATE_TTL_MS.
var _last_known_timestamps: Dictionary = {}
const LAST_KNOWN_STATE_TTL_MS := 300_000  # 5 minutes

## Spatial hash of peer AOI centers (peer_id -> position), mirroring
## _last_known_states so interest queries stay O(cells), not O(peers) (Phase 29).
var _peer_spatial := SpatialHash.new()

## Phase 36 — peer_id → { tokens, at_ms }: the client → host token bucket (see
## RATE_BUCKET_CAPACITY). Entries exist only for live peers: the bucket is dropped
## with the rest of the transport state on disconnect (see forget_player_id).
var _rate_buckets: Dictionary = {}

## Phase 36 — peer_id → last rate-limit warning time_ms. A flooding peer would
## otherwise log a line per dropped packet (a log flood on top of the packet
## flood); the same one-per-second throttle the seq-gap warning uses applies.
var _rate_warn_ms: Dictionary = {}

func _ready() -> void:
	GameBus.packet_send_requested.connect(_on_packet_send_requested)
	GameBus.player_state_sync_requested.connect(_on_player_state_sync_requested)
	GameBus.block_edit_intent.connect(_on_block_edit_intent)
	GameBus.block_changed.connect(_on_block_changed)
	GameBus.creature_state_changed.connect(_on_creature_state_changed)
	GameBus.remote_player_state.connect(_on_remote_player_state)
	GameBus.inventory_synced.connect(_on_inventory_synced)
	# Phase 31 — trees: a chop intent travels client → host, the resolved chop and
	# the regrowth travel host → client.
	GameBus.tree_chop_requested.connect(_on_tree_chop_requested)
	GameBus.tree_chopped.connect(_on_tree_chopped)
	GameBus.tree_respawned.connect(_on_tree_respawned)
	# Phase 33 — crafting is per-player, so a client's craft travels as an intent.
	GameBus.craft_intent.connect(_on_craft_intent)
	# Phase 34 — repair and research are per-player too, so they travel the same
	# way, and the host re-syncs the peer's own record slice when it resolves one.
	GameBus.repair_intent.connect(_on_repair_intent)
	GameBus.research_intent.connect(_on_research_intent)
	# Phase 35 — taming is per-player as well (a granted flag and a companion
	# binding both live on the tamer's record), so it travels the same way.
	GameBus.tame_intent.connect(_on_tame_intent)
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
	# Phase 33 — the identity handshake: the host answers a join with the
	# server-issued player id for that connection.
	GameBus.player_joined.connect(_on_player_joined)

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
## Prints one boot line on success (the same line a dedicated server and a
## listen host both emit) so CI can assert the server actually came up rather
## than merely failing to crash.
func host(port: int = DEFAULT_PORT, max_clients: int = DEFAULT_MAX_CLIENTS) -> Error:
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(port, max_clients)
	if err != OK:
		push_error("NetworkingSlice: failed to create server on port %d — %s" % [port, error_string(err)])
		return err
	_role = Role.HOST
	_attach_peer()
	print("[Server] listening on port %d, max_clients %d" % [port, max_clients])
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
	_player_ids.clear()
	# Phase 37 — a torn-down connection cannot complete the snapshot it was
	# reassembling (see forget_player_id).
	_snapshot_buffer.clear()

func is_host() -> bool:
	return _role == Role.HOST

func is_client() -> bool:
	return _role == Role.CLIENT

func is_offline() -> bool:
	return _role == Role.OFFLINE

# ---------------------------------------------------------------------------
# Phase 33 — identity transport mapping
# ---------------------------------------------------------------------------

## The server-issued player id behind a connection, or "" when the peer has not
## completed the join handshake.
func get_player_id(peer_id: int) -> String:
	return str(_player_ids.get(peer_id, ""))

## Record the peer → player_id mapping, and (on a host) send the assigned id back
## to that peer so it can cache it for a reconnect.
func set_player_id(peer_id: int, player_id: String) -> void:
	if player_id.is_empty():
		return
	_player_ids[peer_id] = player_id
	if _role == Role.HOST:
		_deliver(peer_id, {
			"type": "identity_assigned",
			"player_id": player_id,
			"handle": _public_handle(player_id),
		})

func forget_player_id(peer_id: int) -> void:
	_player_ids.erase(peer_id)
	# Phase 36 — the rate-limit state is transport state too: a reconnecting peer
	# starts with a full bucket rather than inheriting its predecessor's debt.
	_rate_buckets.erase(peer_id)
	_rate_warn_ms.erase(peer_id)
	# Phase 37 — and so is snapshot reassembly: a snapshot that lost a chunk is never
	# completed, so its buffer entry lived for the whole session (one leak per lost
	# chunk, on a connection that may be long gone). The parts are keyed by
	# snapshot_id, and the sender is the connection that carried them, so the whole
	# buffer goes with the connection: a later snapshot is a fresh snapshot_id anyway.
	_snapshot_buffer.clear()

## The player id behind a connection, or "peer_<id>" when the handshake has not
## happened yet. For LABELS and diagnostics only — never for authorizing an action:
## `peer_<id>` is a transport id the host hands out, not an identity it has bound,
## and every acting party must come from `get_player_id()` / `_actor_id()`.
func party_id_for(peer_id: int) -> String:
	var pid := get_player_id(peer_id)
	if pid.is_empty():
		return "peer_%d" % peer_id
	return pid

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
	_peer_spatial.update(peer_id, position)
	_last_known_timestamps.erase(peer_id)

## Last-known position for a peer, or Vector3.ZERO when unknown.
func get_last_known_state(peer_id: int) -> Vector3:
	return _last_known_states.get(peer_id, Vector3.ZERO)

## True when a position for `peer_id` has actually been recorded this session.
## `get_last_known_state()` cannot be used to tell "at the origin" from "never
## reported": both answer Vector3.ZERO, and a caller that writes the answer into a
## durable record would overwrite the saved position with the origin. Check this
## first when persisting a disconnect.
func has_last_known_state(peer_id: int) -> bool:
	return _last_known_states.has(peer_id)

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
			_peer_spatial.remove(pid)

# ---------------------------------------------------------------------------
# Phase 29 — interest management (area of interest)
# ---------------------------------------------------------------------------

## The AOI center for a peer: its last-known position, or the world spawn point
## when it has not reported one yet (a freshly connected client). Pure.
func get_aoi_center(peer_id: int) -> Vector3:
	return _last_known_states.get(peer_id, DEFAULT_AOI_CENTER)

## True when `position` lies within `peer_id`'s area of interest. Pure.
func in_aoi(peer_id: int, position: Vector3) -> bool:
	return get_aoi_center(peer_id).distance_to(position) <= AOI_RADIUS

## The AOI grid cell for a world position (cell = AOI_RADIUS). A peer crossing a
## cell boundary re-scopes its snapshot (see game_root). Pure.
func aoi_region(position: Vector3) -> Vector2i:
	return Vector2i(floori(position.x / AOI_RADIUS), floori(position.z / AOI_RADIUS))

## Peer ids (among `connected`) whose AOI contains `position`. Pure — the
## connected set is passed in so the filter is testable headless.
func aoi_recipients(position: Vector3, connected: Array) -> Array:
	var out: Array = []
	for pid in _peer_spatial.query_radius(position, AOI_RADIUS):
		if pid in connected:
			out.append(pid)
	return out

## Broadcast a spatial delta only to peers whose AOI contains `position`.
## On the host this replaces the N×M broadcast-to-all with a scoped fan-out;
## on a client it forwards to the host unchanged (position is ignored there).
func _broadcast_aoi(payload: Dictionary, position: Vector3) -> void:
	if not _connected():
		return
	if _role == Role.HOST:
		for pid in aoi_recipients(position, multiplayer.get_peers()):
			_deliver(int(pid), payload.duplicate(true))
	elif _role == Role.CLIENT:
		_deliver(1, payload)

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
	_broadcast_aoi(packet, pos)

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
	_broadcast_aoi(packet, position)

func _on_tree_chop_requested(tree_id: String) -> void:
	if _role != Role.CLIENT:
		# Host (and single-player) resolve the chop directly through TreeSlice;
		# only clients forward the intent.
		return
	_broadcast({ "type": "tree_chop_intent", "tree_id": tree_id })

func _on_tree_chopped(tree_id: String, wood: String, state: String, respawn_at: float) -> void:
	if _role != Role.HOST:
		return
	# Not AOI-scoped: trees are deterministic per chunk, so a client either knows
	# the tree or ignores an unknown id.
	_broadcast({
		"type":       "tree_chopped",
		"tree_id":    tree_id,
		"wood":       wood,
		"state":      state,
		"respawn_at": respawn_at,
	})

func _on_tree_respawned(tree_id: String) -> void:
	if _role != Role.HOST:
		return
	_broadcast({ "type": "tree_respawned", "tree_id": tree_id })

## Phase 33 — a client-side craft request travels to the host as an intent; the host
## resolves it against the REQUESTING peer's inventory (see the craft_intent arm of
## _route_c2h). The player_id half is ignored here: the identity is bound to the
## connection on the host side, never trusted from the payload. Mirrors the tree
## chop intent — the host re-emits this signal inbound and must not echo it back.
func _on_craft_intent(recipe_id: String, _player_id: String) -> void:
	if _role != Role.CLIENT:
		return
	_broadcast({ "type": "craft_intent", "recipe_id": recipe_id })

## Phase 34 — the repair half of the same rule: a client cannot repair, because a
## repair consumes materials from a persisted inventory. It forwards the item as an
## intent and the host resolves it against the connection's own player record (see
## the repair_intent arm of _route_c2h). The player_id half is ignored here for the
## same reason as craft_intent: the identity is bound to the connection on the host
## side, never trusted from the payload.
func _on_repair_intent(item_id: String, _player_id: String) -> void:
	if _role != Role.CLIENT:
		return
	_broadcast({ "type": "repair_intent", "item_id": item_id })

## Phase 34 — research likewise: the technology tree is per-player state, so a
## client forwards the tech and the host researches for the identity it bound.
func _on_research_intent(tech_id: String, _player_id: String) -> void:
	if _role != Role.CLIENT:
		return
	_broadcast({ "type": "research_intent", "tech_id": tech_id })

## Phase 35 — taming: the granted flag and the companion binding live on a player
## record the host owns, so a client forwards the target instance and the host
## tames for the identity it bound. The player_id half is ignored here for the same
## reason as craft_intent: the identity is bound to the connection on the host
## side, never trusted from the payload.
##
## Phase 36 — the payload also carries the sender's own bare-hands claim, which is
## forwarded untouched: it is evidence ABOUT the client (its own body is the only
## place that knows what it is holding), not a claim about anyone else, and the host
## evaluates the fabric's `requiresUnarmed` rule against it. A peer that sends no
## claim reads as armed (see TamingSlice.is_unarmed).
func _on_tame_intent(instance_id: String, _player_id: String, unarmed: bool) -> void:
	if _role != Role.CLIENT:
		return
	_broadcast({ "type": "tame_intent", "instance_id": instance_id, "unarmed": unarmed })

## Phase 34 — host → one client: the peer's OWN record slice changed on the host's
## side of an action it asked for (its inventory after a repair, its technology
## statuses after a research). Delivered to that peer alone: an inventory is
## private, so unlike an AOI-scoped world delta this cannot be broadcast.
## `data` mirrors the like-named join-snapshot keys:
## { inventory, inventory_durability, technology }.
func send_own_state(peer_id: int, data: Dictionary) -> void:
	if _role != Role.HOST:
		push_warning("NetworkingSlice: send_own_state called on non-host — dropped")
		return
	_deliver(peer_id, { "type": "own_state_synced", "data": data })

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
	_broadcast_aoi(packet, position)

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
	_broadcast_aoi(packet, position)

func _on_inventory_synced(owner_id: String, contents: Dictionary, durabilities: Dictionary = {}) -> void:
	if _role != Role.HOST:
		return
	# Phase 37 — an inventory is PRIVATE to its owner and the sync now names that
	# owner, so it goes to that owner's peer alone. Broadcasting it handed every client
	# one player's pack (and, before the owner was carried at all, had every
	# InventorySlice in the process apply it).
	var peer := _peer_for_inventory_owner(owner_id)
	if peer == 0:
		return
	var packet := {
		"type":     "inventory_synced",
		"contents": contents,
		"durabilities": durabilities,
	}
	_deliver(peer, packet)

## The live peer whose player owns the inventory named by `owner_id`, or 0 when there
## is nobody to send it to: an offline owner, a name this host cannot resolve, an
## unwired registry (the check FAILS CLOSED — an unaddressed private payload is not
## broadcast), or this machine's OWN player, whose inventory is already live here.
##
## `""` and `"player"` both denote the local bucket (see
## InventorySlice.LOCAL_OWNER_LITERALS).
func _peer_for_inventory_owner(owner_id: String) -> int:
	if player_registry == null or not player_registry.has_method("get_peer_id"):
		return 0
	var pid := owner_id
	if pid == "" or pid == "player":
		pid = str(player_registry.local_player_id)
	if pid == "":
		return 0
	return int(player_registry.get_peer_id(pid))

## Phase 37 — host → one client: a creature struck THIS player. Damage is applied by
## the machine that simulates the body (`PlayerSlice` on the peer's own client, which
## owns its HP), so the host sends the round's outcome rather than trying to hold a
## peer's health it cannot verify (`PlayerRegistry.record_hp` refuses a
## client-declared HP for the same reason). Peer-scoped, like `send_own_state`: one
## player's damage is not world state.
func send_player_damaged(peer_id: int, damage: float, attacker_id: String) -> void:
	if _role != Role.HOST:
		push_warning("NetworkingSlice: send_player_damaged called on non-host — dropped")
		return
	_deliver(peer_id, {
		"type":        "player_damaged",
		"damage":      damage,
		"attacker_id": attacker_id,
	})

# ---------------------------------------------------------------------------
# Phase 24 — social/economy replication (host → clients authoritative state,
# client → host intents)
# ---------------------------------------------------------------------------

func _on_market_synced(data: Dictionary) -> void:
	if _role != Role.HOST:
		return
	# Phase 36 — the listings name their sellers; ids are redacted to handles here
	# (see redact_for_client) because the wire has no business carrying a bearer token.
	_broadcast({ "type": "market_synced", "data": redact_for_client(data) })

func _on_governance_synced(data: Dictionary) -> void:
	if _role != Role.HOST:
		return
	_broadcast({ "type": "governance_synced", "data": redact_for_client(data) })

func _on_trade_completed(trade: Dictionary) -> void:
	if _role != Role.HOST:
		return
	_broadcast({ "type": "trade_completed", "trade": redact_for_client(trade) })

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
	_broadcast({ "type": "trade_synced", "data": redact_for_client(data) })

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
##
## Phase 36 — the two inbound guards live here, before the payload is even parsed,
## because they police the CHANNEL rather than any one packet type: a size cap (a
## client may not make the host parse an arbitrarily large JSON string) and a
## per-peer token bucket (a client may not flood the host with fresh packets; the
## Phase 19 dedup only rejects replayed seqs). Both refuse silently apart from a
## rate-limited warning — a dropped packet is not an error the sender can fix.
@rpc("any_peer", "reliable")
func _rpc_c2h(json: String) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if json.length() > MAX_CLIENT_PACKET_BYTES:
		push_warning("NetworkingSlice: client packet from peer %d is %d chars (cap %d) — dropped" \
			% [sender, json.length(), MAX_CLIENT_PACKET_BYTES])
		return
	if not _allow_packet(sender, float(Time.get_ticks_msec())):
		return
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

## Phase 36 — per-peer client → host token bucket. `now_ms` is an argument (not a
## clock read) so the rule is testable without waiting: the same shape the
## emulator's `_sample_remote_state_at` uses. Returns true when a token was
## available and the packet may be routed, false when the bucket is empty and the
## packet is dropped.
##
## Refill is continuous (elapsed ms × RATE_BUCKET_REFILL_PER_SEC) and capped at
## RATE_BUCKET_CAPACITY, so an idle peer always has a full burst waiting and a
## flooding one is held to the sustained rate. The bucket is created on a peer's
## first packet with a full capacity — the join burst (handshake + first snapshot
## request + first movement packets) is exactly what that burst is for.
func _allow_packet(peer_id: int, now_ms: float) -> bool:
	if not _rate_buckets.has(peer_id):
		_rate_buckets[peer_id] = { "tokens": RATE_BUCKET_CAPACITY, "at_ms": now_ms }
	var bucket: Dictionary = _rate_buckets[peer_id]
	var elapsed: float = maxf(0.0, now_ms - float(bucket["at_ms"]))
	bucket["at_ms"] = now_ms
	bucket["tokens"] = minf(
		RATE_BUCKET_CAPACITY,
		float(bucket["tokens"]) + elapsed * 0.001 * RATE_BUCKET_REFILL_PER_SEC
	)
	if float(bucket["tokens"]) < 1.0:
		var last_warn: float = float(_rate_warn_ms.get(peer_id, -SEQ_GAP_WARN_INTERVAL_MS))
		if now_ms - last_warn >= SEQ_GAP_WARN_INTERVAL_MS:
			_rate_warn_ms[peer_id] = now_ms
			push_warning("NetworkingSlice: peer %d exceeded the client packet rate — dropping" % peer_id)
		return false
	bucket["tokens"] = float(bucket["tokens"]) - 1.0
	return true

## The ACTING party behind a connection: the identity the host bound to it, and
## nothing else. `""` when the peer has not completed the handshake.
##
## Phase 36 — this used to resolve the literal "player" to the sender's identity
## and pass EVERY other string through verbatim, so a client could name another
## player as itself: accept a trade as the victim, list the victim's goods (the
## escrow debit drains the victim's inventory), or cast the victim's vote. The
## payload's identity half is now ignored outright — the same rule craft_intent,
## repair_intent, research_intent and tame_intent already followed. Callers refuse
## an un-handshaked peer rather than acting for a nameless connection.
func _actor_id(sender: int) -> String:
	return get_player_id(sender)

## Log and drop a client packet from a peer that has not completed the handshake.
## Every identity-bound intent shares this refusal, so the reason is worded once.
func _refuse_unhandshaked(sender: int, ptype: String) -> void:
	push_warning("NetworkingSlice: %s from un-handshaked peer %d — dropped" % [ptype, sender])

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
	if not has_last_known_state(sender):
		return false
	return get_last_known_state(sender).distance_to(position) <= reach

## Phase 36 — the host-side tree population, wired by game_root. A chop intent
## names only a tree id, so the tree's own position is the only way to check the
## sender's reach; there is no way to carry it on the bus. Left unwired (isolated
## tests) the check FAILS CLOSED, deliberately: a reach check that silently passes
## when its source is missing is not a check.
var tree_slice: Node = null

## Phase 36 — the host-side identity resolver, wired by game_root: it is what turns
## a counterparty NAME on a trade invite into the player id it denotes (and, in a
## later pass, a public handle). Unwired, a named counterparty cannot be resolved at
## all and the invite is dropped rather than parked in the trade table.
var player_registry: Node = null

## Is a chop of `tree_id` within `reach` of the peer? A tree the host does not
## have is not chopable either (TreeSlice re-checks that authoritatively, on its
## own side of the bus).
func _chop_is_in_reach(sender: int, tree_id: String) -> bool:
	if tree_slice == null or not tree_slice.has_method("get_tree_record"):
		return false
	var rec: Dictionary = tree_slice.get_tree_record(tree_id)
	if rec.is_empty():
		return false
	return _within_reach(sender, rec["position"], MAX_EDIT_REACH)

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
	if raw == "" or player_registry == null:
		return ""
	if not player_registry.has_method("resolve_named_party"):
		return ""
	return str(player_registry.resolve_named_party(raw))

# ---------------------------------------------------------------------------
# Phase 36 — identity redaction on the wire
# ---------------------------------------------------------------------------

## Host side: the public-handle form of a player id, or "" when no registry is wired
## (then there is nothing to redact with; see redact_for_client).
func _public_handle(player_id: String) -> String:
	if player_registry == null or not player_registry.has_method("public_handle"):
		return ""
	return str(player_registry.public_handle(player_id))

## Host side: replace every player id inside a host → client payload with its public
## handle, recursively — dictionary KEYS as well as values, because a trade's `offers`
## and `accepted` maps are keyed by party.
##
## The player id is a BEARER TOKEN (`resolve_identity` hands the record to whoever
## presents it on join), so broadcasting it handed every client the means to take over
## any player's record once that player disconnected — inventories, positions,
## appearance, technology. Market listings, trade sessions, and proposals all named
## players by id; this is where they stop. The handle is derived, opaque and stable
## (see PlayerRegistry.public_handle), and it is not a claim: claiming it mints a new
## identity.
##
## Non-id strings ("merchant", a proposal title, an item key) are untouched: the
## shape test recognises a minted id and nothing else.
func redact_for_client(value: Variant) -> Variant:
	if player_registry == null:
		return value
	return _map_identities(value, func(s: String) -> String:
		if PlayerRegistry.looks_like_player_id(s):
			return _public_handle(s)
		return s
	)

## Client side: show THIS client's own handle back to its own slices as the literal
## "player" — the convention the local player has always had (`TradeSlice.PARTY_PLAYER`,
## `MarketSlice`) — so a client recognises itself in synced state without ever holding
## another player's identity. Every OTHER handle is left exactly as it arrived: opaque
## is the point.
func adopt_own_handle(value: Variant) -> Variant:
	if claimed_handle == "":
		return value
	return _map_identities(value, func(s: String) -> String:
		return "player" if s == claimed_handle else s
	)

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
			out_items.append(_map_identities(item, mapper))
		return out_items
	if value is Dictionary:
		var out: Dictionary = {}
		for key in value:
			out[_map_identities(key, mapper)] = _map_identities(value[key], mapper)
		return out
	return value

## Client side: the world snapshot's identity-bearing blobs, restored to this client's
## own view (see IDENTIFIED_STATE_KEYS). Only those keys are walked — a snapshot is
## mostly terrain and entity data, and rewriting every string in it would cost a pass
## over the whole world for no privacy gain.
func _adopt_snapshot_identities(data: Dictionary) -> Dictionary:
	for key in IDENTIFIED_STATE_KEYS:
		if data.has(key):
			data[key] = adopt_own_handle(data[key])
	return data

## Route a client → host packet. Only client-originated types are accepted;
## host-only types sent by a malicious client are dropped and logged.
func _route_c2h(sender: int, payload: Dictionary) -> void:
	match str(payload.get("type", "")):
		"join_intent":
			# Phase 33 — the client presents its cached id ("" on a first join).
			# The registry owns resolution; the host answers with player_joined.
			GameBus.player_join_intent.emit(sender, str(payload.get("claimed_id", "")))
		"player_moved":
			var pos := _vec3(payload.get("position", []))
			# The packet also carries the peer's self-declared `hp` / `max_hp`,
			# used for its own display. The host deliberately keeps NO durable
			# copy: the value is client-declared and cannot be verified here, so
			# persisting it made health a restart-proof cheat (see
			# PlayerRegistry.record_hp). Position is the only half the host
			# retains, and only so a reconnect can resume from it.
			GameBus.remote_player_state.emit(sender, pos)
		"craft_intent":
			# A remote peer's craft must resolve against ITS OWN inventory (crafting
			# is per-player now that each player persists one). The identity comes
			# from the connection, never from the payload: a client cannot name
			# whose inventory it crafts against.
			var crafter := _actor_id(sender)
			if crafter == "":
				_refuse_unhandshaked(sender, "craft_intent")
				return
			GameBus.craft_intent.emit(str(payload.get("recipe_id", "")), crafter)
		"repair_intent":
			# Phase 34 — the same identity rule as craft_intent: the repairing
			# player is the one bound to THIS connection, so a client cannot name
			# whose tool it repairs or whose materials it spends.
			var repairer := _actor_id(sender)
			if repairer == "":
				_refuse_unhandshaked(sender, "repair_intent")
				return
			GameBus.repair_intent.emit(str(payload.get("item_id", "")), repairer)
		"research_intent":
			# Phase 34 — and the same for research: whose tree moves is decided by
			# the connection, never by the payload.
			var researcher := _actor_id(sender)
			if researcher == "":
				_refuse_unhandshaked(sender, "research_intent")
				return
			GameBus.research_intent.emit(str(payload.get("tech_id", "")), researcher)
		"tame_intent":
			# Phase 35 — and the same for taming: the flag and the companion bind
			# to the connection's own player, never to a name in the payload.
			# Phase 36 — the sender's bare-hands claim is passed through: it is
			# evidence about the sender itself (the only machine that knows what its
			# body is holding), and the taming slice evaluates the fabric's rule
			# against it, defaulting to "armed" when no claim arrived.
			var tamer := _actor_id(sender)
			if tamer == "":
				_refuse_unhandshaked(sender, "tame_intent")
				return
			GameBus.tame_intent.emit(
				str(payload.get("instance_id", "")),
				tamer,
				bool(payload.get("unarmed", false))
			)
		"block_edit_intent":
			# Phase 36 — a world edit needs a bound identity AND a target within the
			# host's evidence of arm's reach. The block position arrives as a bare
			# claim: with no reach check a client could mine or build anywhere in the
			# world (under another player's feet included), and with no handshake
			# requirement it could do so before the host knew who it was at all.
			if _actor_id(sender) == "":
				_refuse_unhandshaked(sender, "block_edit_intent")
				return
			var action := str(payload.get("action", ""))
			var ipos := _vec3(payload.get("position", []))
			var inorm := _vec3(payload.get("normal", [0, 1, 0]))
			if not _within_reach(sender, ipos, MAX_EDIT_REACH):
				push_warning("NetworkingSlice: block_edit_intent from peer %d is out of reach — dropped" % sender)
				return
			if action == "mine":
				GameBus.block_mine_requested.emit(ipos, inorm)
			elif action == "place":
				GameBus.block_place_requested.emit(ipos, inorm)
			else:
				push_error("NetworkingSlice: unknown block_edit_intent action '%s'" % action)
		"tree_chop_intent":
			# Phase 36 — same two rules as block_edit_intent. The intent names only
			# a tree id, so the reach check resolves the tree's own position through
			# the wired TreeSlice (a tree the host does not have is not chopable
			# either — TreeSlice re-checks that too, authoritatively). The host then
			# re-runs the chop and broadcasts tree_chopped back to every client.
			if _actor_id(sender) == "":
				_refuse_unhandshaked(sender, "tree_chop_intent")
				return
			var tree_id := str(payload.get("tree_id", ""))
			if not _chop_is_in_reach(sender, tree_id):
				push_warning("NetworkingSlice: tree_chop_intent from peer %d is out of reach — dropped" % sender)
				return
			GameBus.tree_chop_requested.emit(tree_id)
		"market_list_intent":
			# Phase 36 — a listing is the CONNECTION's player selling. `seller` used
			# to be passed through verbatim unless it read exactly "player", so a
			# client could name a victim: the escrow debit then emptied that player's
			# inventory into a listing the attacker could buy back.
			var seller := _actor_id(sender)
			if seller == "":
				_refuse_unhandshaked(sender, "market_list_intent")
				return
			GameBus.market_list_intent.emit(
				seller,
				str(payload.get("item_id", "")),
				int(payload.get("quantity", 0)),
				float(payload.get("price", 0.0))
			)
		"market_buy_intent":
			# Phase 36 — the buyer is the connection's player too: naming one let a
			# client drain a victim's market purchases into its own listing.
			var buyer := _actor_id(sender)
			if buyer == "":
				_refuse_unhandshaked(sender, "market_buy_intent")
				return
			GameBus.market_buy_intent.emit(str(payload.get("listing_id", "")), buyer)
		"proposal_submit_intent":
			# Phase 36 — the author is the connection's player, never a name.
			var author := _actor_id(sender)
			if author == "":
				_refuse_unhandshaked(sender, "proposal_submit_intent")
				return
			GameBus.proposal_submit_intent.emit(
				author,
				str(payload.get("title", "")),
				str(payload.get("body", ""))
			)
		"proposal_vote_intent":
			# Phase 36 — "one vote per distinct voter" is what a quorum MEANS, so the
			# voter must be the connection's player: a client that could name voters
			# could ratify any proposal alone, and could vote a proposal through under
			# the author's name (the one identity the rule forbids).
			var voter := _actor_id(sender)
			if voter == "":
				_refuse_unhandshaked(sender, "proposal_vote_intent")
				return
			GameBus.proposal_vote_intent.emit(
				str(payload.get("proposal_id", "")),
				voter,
				str(payload.get("verdict", ""))
			)
		"proposal_supersede_intent":
			# Superseding names no party — it is a transition between two proposals —
			# so there is no identity to bind. It still requires a bound identity: an
			# anonymous connection may not move the decisions log. WHICH players may
			# supersede a given proposal is a governance rule, not an identity one,
			# and is not decided here.
			if _actor_id(sender) == "":
				_refuse_unhandshaked(sender, "proposal_supersede_intent")
				return
			GameBus.proposal_supersede_intent.emit(
				str(payload.get("proposal_id", "")),
				str(payload.get("replacement_id", ""))
			)
		"trade_start_intent":
			# Phase 36 — party_a is the connection's player: a client cannot open a
			# session in someone else's name. party_b is the counterparty the client
			# NAMES — an invite is the one thing a payload may legitimately name here,
			# because it grants nothing: every later step (propose, accept, reject)
			# acts as the connection's own player, so a session aimed at a name nobody
			# answers simply never resolves. Rate-limited like every other intent, so
			# a nameless invite flood cannot be a cheap amplification either.
			var actor := _actor_id(sender)
			if actor == "":
				_refuse_unhandshaked(sender, "trade_start_intent")
				return
			var other := _named_party(str(payload.get("party_b", "")))
			if other == "" or other == actor:
				push_warning("NetworkingSlice: trade_start_intent from peer %d names an unusable counterparty — dropped" % sender)
				return
			GameBus.trade_start_intent.emit(actor, other)
		"trade_propose_intent":
			# Phase 36 — the party proposing is the connection's player.
			var proposer := _actor_id(sender)
			if proposer == "":
				_refuse_unhandshaked(sender, "trade_propose_intent")
				return
			GameBus.trade_propose_intent.emit(
				str(payload.get("trade_id", "")),
				proposer,
				payload.get("give", {}),
				payload.get("want", {})
			)
		"trade_accept_intent":
			# Phase 36 — THE trade finding: `party` used to pass through verbatim,
			# so a client could accept AS the other side and commit the other
			# player's goods. The accepter is the connection's player, always.
			var accepter := _actor_id(sender)
			if accepter == "":
				_refuse_unhandshaked(sender, "trade_accept_intent")
				return
			GameBus.trade_accept_intent.emit(
				str(payload.get("trade_id", "")),
				accepter
			)
		"trade_reject_intent":
			# Phase 36 — and a client may only reject on its own behalf (a spoofed
			# reject closed another player's session for both sides).
			var rejecter := _actor_id(sender)
			if rejecter == "":
				_refuse_unhandshaked(sender, "trade_reject_intent")
				return
			GameBus.trade_reject_intent.emit(
				str(payload.get("trade_id", "")),
				rejecter
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
		"tree_chopped":
			GameBus.tree_chopped.emit(
				str(payload.get("tree_id", "")),
				str(payload.get("wood", "")),
				str(payload.get("state", "")),
				float(payload.get("respawn_at", 0.0))
			)
		"tree_respawned":
			GameBus.tree_respawned.emit(str(payload.get("tree_id", "")))
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
		"market_synced":
			# Phase 36 — the payload names players by public handle; our OWN handle is
			# shown back to the slices as "player" so the local view is unchanged.
			GameBus.market_synced.emit(adopt_own_handle(payload.get("data", {})))
		"governance_synced":
			GameBus.governance_synced.emit(adopt_own_handle(payload.get("data", {})))
		"trade_synced":
			GameBus.trade_synced.emit(adopt_own_handle(payload.get("data", {})))
		"trade_completed":
			GameBus.trade_completed.emit(adopt_own_handle(payload.get("trade", {})))
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
			claimed_player_id = str(payload.get("player_id", ""))
			claimed_handle = str(payload.get("handle", ""))
			GameBus.player_identity_assigned.emit(claimed_player_id)
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
			GameBus.world_snapshot_received.emit(_adopt_snapshot_identities(data))
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
	multiplayer.connected_to_server.connect(_on_connected_to_server)

func _detach_peer() -> void:
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)

## Phase 33 — client side: the connection is up, so present our cached player id.
## The host answers with the id it binds us to (the same one on a reconnect, a
## fresh one on a first join, and a fresh one for a claim it refuses).
func _on_connected_to_server() -> void:
	if _role != Role.CLIENT:
		return
	request_handshake()

## Client side: (re-)present the join intent. Called on connect, and again by
## game_root while the client is still waiting for its world snapshot — the
## handshake is the ONLY way a client gets an identity and a world, so a lost
## join_intent (or a lost snapshot) used to leave a connected client with
## nothing at all and no way to ask again. Each call gets a fresh `seq`, so the
## retry is not swallowed by the receiver's dedup, and the host re-answers an
## already-bound peer idempotently (PlayerRegistry.resolve_identity).
func request_handshake() -> void:
	if _role != Role.CLIENT:
		return
	_deliver(1, { "type": "join_intent", "claimed_id": claimed_player_id })

## Phase 33 — host side: an identity was bound to a connection. Record the
## transport mapping and ship the assigned id back to that peer.
func _on_player_joined(peer_id: int, player_id: String, _reconnected: bool) -> void:
	if _role != Role.HOST or _is_local_peer(peer_id):
		return
	set_player_id(peer_id, player_id)

## True when `peer_id` is this machine's own id (the host's own player), which
## needs no wire handshake.
func _is_local_peer(peer_id: int) -> bool:
	return peer_id == multiplayer.get_unique_id()

func _on_peer_connected(id: int) -> void:
	# Phase 29 — seed the peer's AOI center (its retained last-known position,
	# else the spawn default) into the peer spatial hash so it receives deltas
	# before its first movement reports a position.
	_peer_spatial.update(id, get_aoi_center(id))
	GameBus.peer_connected.emit(id)

## Phase 19 — a peer disconnecting does NOT erase its last-known position; it is
## retained (with a TTL) so a rejoining client resumes from where it left off and
## the record written at disconnect carries that position.
## A disconnect timestamp is set so _evict_stale_states() can expire the entry
## after LAST_KNOWN_STATE_TTL_MS if the peer never reconnects.
func _on_peer_disconnected(id: int) -> void:
	GameBus.peer_disconnected.emit(id)
	# Phase 33 — the connection is gone, so its transport mapping goes with it.
	# The player's durable record stays on disk, which is what lets a reconnect
	# with the same player id re-bind to it; game_root writes it and then releases
	# the in-memory copy (PlayerRegistry.evict_player).
	forget_player_id(id)
	if _last_known_states.has(id):
		_last_known_timestamps[id] = Time.get_ticks_msec()
