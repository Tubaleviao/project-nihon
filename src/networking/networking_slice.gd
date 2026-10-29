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
##         tree_chop_requested(tree_id, player_id)   — client wants to fell a tree
##                                          (the host re-emits the bound actor)
##         tree_chopped(tree_id, wood, state, at)    — host authoritative chop
##         tree_respawned(tree_id)                   — host authoritative regrowth
##         tree_cleared(tree_id)                     — host authoritative, building cleared a tree
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
##   send_snapshot(peer_id, data) -> bool    — host → one client (false: not sent whole)
##   send_own_state(peer_id, data) -> void   — host → one client (Phase 34)
##   send_player_damaged(peer_id, damage, attacker_id) -> void  — host → one client (Phase 37)
##   remember_player_state(peer_id, pos) -> void   — Phase 19
##   get_last_known_state(peer_id) -> Vector3      — Phase 19
##   get_last_known_states() -> Dictionary         — Phase 19
##   has_last_known_state(peer_id) -> bool
##   request_handshake() -> void                   — re-present the join intent
const WorldPos := preload("res://src/terrain/world_pos.gd")
const Diag := preload("res://src/core/diag.gd")
const I18n := preload("res://src/core/i18n.gd")
const GestureRules := preload("res://src/character/gesture_rules.gd")
const TickProbe := preload("res://src/core/tick_probe.gd")

enum Role { OFFLINE, HOST, CLIENT }

## Spatial hash over connected peers' AOI centers so interest filtering is an
## O(radius²)-cells query, not an O(peers) scan (Phase 29).
const SpatialHash := preload("res://src/core/spatial_hash.gd")
const Transport := preload("res://src/networking/transport.gd")
const EnetTransport := preload("res://src/networking/enet_transport.gd")

## Phase 36 — the registry's id-SHAPE predicate, preloaded for the redactor: it is a
## pure static check on a string, and the redactor must recognise a bearer token even
## when no registry is in the tree (an offline seller's id lives on inside a persisted
## listing long after their record was evicted).
const PlayerRegistry := preload("res://src/persistence/player_registry.gd")
const CreationRules := preload("res://src/character/creation_rules.gd")

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
## Radius of the voxel-edit scope of a re-scope snapshot. Wider than AOI_RADIUS: a peer may
## roam anywhere in its AOI grid cell (up to ~136 m from the crossing point) before the next
## re-scope, and the chunk streamer renders ~4 chunks (128 m, ~181 m diagonal) beyond it.
const EDITS_SCOPE_RADIUS := AOI_RADIUS * 4.0
## AOI center used for a peer that has not reported a position yet (freshly
## connected). Matches the world spawn point so the initial snapshot is scoped
## around where players first appear.
const WorldShape := preload("res://src/terrain/world_shape.gd")
const DEFAULT_AOI_CENTER := Vector3(WorldShape.SPAWN_CENTER.x, 0.0, WorldShape.SPAWN_CENTER.y)

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
const NetPart1 := preload("res://src/networking/net_part_1.gd")
const NetPart2 := preload("res://src/networking/net_part_2.gd")
const NetPart3 := preload("res://src/networking/net_part_3.gd")
var _m3 := NetPart3.new(self)

var _m2 := NetPart2.new(self)

var _m1 := NetPart1.new(self)

var claimed_handle: String = ""
## Phase 53 — a friend's handle to spawn beside on a first join ("" = none). Set before connecting.
var friend_code: String = ""

var _peer: ENetMultiplayerPeer
var _role: int = Role.OFFLINE

## Snapshot reassembly state (client): snapshot_id → { count, received, parts }.
## Phase 38 — released with the connection whose chunks carried it: a peer's disconnect
## on the host, this machine's own teardown, and (the case that was missing) a CLIENT
## losing its host, which is what `_on_server_disconnected` is for.
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
## Phase 135 — base one-way delay added to every emulated packet, in ms (jitter rides on top).
@export var emulator_latency_ms: float = 0.0
## Phase 135 — link rate in kbit/s (1 kbit = 125 bytes); 0 = unlimited. Packets queue behind each
## other and the excess is delayed, never dropped.
@export var emulator_bandwidth_kbps: float = 0.0

## Phase 135 — model a RELIABLE transport (ENet): a "lost" packet is retransmitted after a timeout, so
## it arrives late rather than never. Off keeps the Phase 19 behaviour (the packet is dropped).
@export var emulator_retransmit: bool = false
## Phase 135 — how many lost packets were retransmitted instead of dropped (reported by the harness).
var emulator_retransmits: int = 0
## Phase 150 — packets the emulator dropped because their peer was gone or never connected. The harness reports it.
var emulator_dropped: int = 0

## Phase 135 — named link profiles, the one table `--net-profile` and the harness read.
## `loopback` is the no-emulation default. Latency/jitter are ms added by each process to its outbound packets, loss a percentage.
const NetProfiles := preload("res://src/networking/net_profiles.gd")
const NET_PROFILES := NetProfiles.TABLE
const NET_PROFILE_ARG := "--net-profile"
## Phase 135 — the profile this slice runs under ("" = none, emulator off).
var net_profile: String = ""
## Emulated links: peer_id -> the ms at which that peer's wire is next free (bandwidth
## serialisation). One link per peer, so a departed peer's backlog cannot delay a new one.
var _link_free_at_ms: Dictionary = {}
## Reliable model: peer_id -> the ms the last packet queued for that peer is delivered. ENet's reliable
## channel delivers in order, so a later packet never overtakes one waiting on a retransmit (or on a
## longer jitter draw): it is held until that one has arrived (head-of-line blocking).
var _ordered_at_ms: Dictionary = {}

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

## Emulator delivery queue: { at_ms, peer_id, payload }, drained by _process.
var _pending: Array = []

## Jitter buffer (client): peer_id -> Array of { at_ms, position }.
var jitter_buffer_ms: float = 100.0
var _jitter_buffer: Dictionary = {}

## Host-side last-known player states (peer_id -> Vector3), retained across a
## disconnect so a rejoining client can resume from its last position.
var _last_known_states: Dictionary = {}
## Phase 86 — peer_id -> exact `{chunk, local}` of its last report; beside `_last_known_states`, which
## stays the float Vector3 the AOI distance checks use. Absent after a legacy report.
var _last_known_exact: Dictionary = {}

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
## Phase 163 — cells one AOI radius wide: a query probes 3×3 cells, not the 25×25 of 8 m cells.
var _peer_spatial := SpatialHash.new(AOI_RADIUS)

## Phase 163 — this frame's position relays, sent as one `player_states` batch per peer by `flush_relays`.
const RelayBatch := preload("res://src/networking/relay_batch.gd")
var _relays := RelayBatch.new()

## Phase 36 — peer_id → { tokens, at_ms }: the client → host token bucket (see
## RATE_BUCKET_CAPACITY). Entries exist only for live peers: the bucket is dropped
## with the rest of the transport state on disconnect (see forget_player_id).
var _rate_buckets: Dictionary = {}

## Phase 36 — peer_id → last rate-limit warning time_ms. A flooding peer would
## otherwise log a line per dropped packet (a log flood on top of the packet
## flood); the same one-per-second throttle the seq-gap warning uses applies.
var _rate_warn_ms: Dictionary = {}

## peer_id -> time_ms of its last malformed `player_moved` warning. A hostile peer can send one such packet per
## token-bucket token, so the warning is throttled per peer (one per interval), not per packet.
var _malformed_position_warn_ms: Dictionary = {}
const MALFORMED_WARN_INTERVAL_MS := 5000.0

func _ready() -> void:
	_apply_profile_arg(OS.get_cmdline_user_args())
	GameBus.packet_send_requested.connect(_on_packet_send_requested)
	GameBus.player_state_sync_requested.connect(_on_player_state_sync_requested)
	GameBus.block_edit_intent.connect(_on_block_edit_intent)
	GameBus.block_changed.connect(_on_block_changed)
	GameBus.creature_state_changed.connect(_on_creature_state_changed)
	GameBus.remote_player_state.connect(_on_remote_player_state)
	GameBus.inventory_synced.connect(_on_inventory_synced)
	GameBus.void_burst_resolved.connect(_on_void_burst_resolved)
	GameBus.profession_unlocked.connect(_on_profession_unlocked)
	GameBus.equip_intent.connect(_on_equip_intent)
	GameBus.equipment_changed.connect(_on_equipment_changed)
	GameBus.equipment_revoked.connect(_on_equipment_revoked)
	# Phase 31 — trees: a chop intent travels client → host, the resolved chop and
	# the regrowth travel host → client.
	GameBus.tree_chop_requested.connect(_on_tree_chop_requested)
	GameBus.tree_chopped.connect(_on_tree_chopped)
	GameBus.tree_respawned.connect(_on_tree_respawned)
	GameBus.tree_cleared.connect(_on_tree_cleared)
	# Phase 33 — crafting is per-player, so a client's craft travels as an intent.
	GameBus.craft_intent.connect(_on_craft_intent)
	# Phase 34 — repair and research are per-player too, so they travel the same
	# way, and the host re-syncs the peer's own record slice when it resolves one.
	GameBus.repair_intent.connect(_on_repair_intent)
	GameBus.research_intent.connect(_on_research_intent)
	GameBus.waystone_travel_intent.connect(_on_waystone_travel_intent)
	GameBus.settlement_intent.connect(_on_settlement_intent)
	GameBus.bed_place_intent.connect(_on_bed_place_intent)
	# Phase 35 — taming is per-player as well (a granted flag and a companion
	# binding both live on the tamer's record), so it travels the same way.
	GameBus.tame_intent.connect(_on_tame_intent)
	# Phase 85 — chat lines travel client → host as an intent; the host's posts (chat, announcements,
	# command replies) travel back.
	GameBus.chat_intent.connect(_on_chat_intent)
	GameBus.gesture_intent.connect(_on_gesture_intent)
	# Phase 181 — a creation travels client → host as an intent; a look travels host → the peers in AOI.
	GameBus.character_creation_intent.connect(_on_character_creation_intent)
	GameBus.player_look_changed.connect(_on_player_look_changed)
	GameBus.harvest_intent.connect(_on_harvest_intent)
	GameBus.carry_intent.connect(_on_carry_intent)
	GameBus.carcass_drop_intent.connect(_on_carcass_drop_intent)
	GameBus.chat_posted.connect(_on_chat_posted)
	GameBus.system_message.connect(_on_system_message)
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
	GameBus.spawn_placed.connect(_on_spawn_placed)

## Phase 135 — the profile named on the command line: "" when `--net-profile` is absent, the
## name otherwise (valid or not; `has_profile` tells which). A flag with no value is "?" (refused).
static func profile_from_args(args: Array) -> String:
	var i := args.find(NET_PROFILE_ARG)
	if i < 0:
		return ""
	if i + 1 >= args.size() or str(args[i + 1]).begins_with("--"):
		return "?"
	return str(args[i + 1])

func _apply_profile_arg(args: Array) -> bool:
	return _m1._apply_profile_arg(args)

static func has_profile(name: String) -> bool:
	return NET_PROFILES.has(name)

func apply_profile(name: String) -> bool:
	return _m2.apply_profile(name)

## Phase 135 — how much longer than loopback this slice's waits should be: one plus the profile's round
## trip over 250 ms (1.0 with no profile). The harness and the client handshake both scale by it.
func link_time_scale() -> float:
	return profile_time_scale(net_profile)

## Phase 150 — the time scale of a named profile (1.0 for none or an unknown name). `tools/net_harness.sh`
## reads it through `tools/profile_scale.gd`, so a new profile cannot be forgotten in the driver.
static func profile_time_scale(name: String) -> float:
	return NetProfiles.time_scale(name)

## Phase 135 — the profile's round-trip time in ms (worst case with jitter), 0 for an unknown name.
static func profile_rtt_ms(name: String) -> float:
	return NetProfiles.rtt_ms(name)

## Phase 19 — drain the emulator queue and (on clients) the jitter buffer.
## Eviction of stale last-known-states runs unconditionally (no ENet overhead).
func _process(_delta: float) -> void:
	_evict_stale_states()
	flush_relays(true)
	if not emulate_network:
		return
	_drain_emulator()
	if _role == Role.CLIENT:
		_drain_jitter_buffer()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func host(port: int = DEFAULT_PORT, max_clients: int = DEFAULT_MAX_CLIENTS) -> Error:
	return _m3.host(port, max_clients)

## Connect to a remote host. Sets the slice to CLIENT role.
func join(address: String = "127.0.0.1", port: int = DEFAULT_PORT) -> Error:
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(address, port)
	if err != OK:
		Diag.error("NetworkingSlice: failed to connect to %s:%d — %s" % [address, port, error_string(err)])
		return err
	_role = Role.CLIENT
	_attach_peer()
	return OK

func disconnect_all() -> void:
	_m1.disconnect_all()

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

func set_player_id(peer_id: int, player_id: String) -> void:
	_m2.set_player_id(peer_id, player_id)

func forget_player_id(peer_id: int) -> void:
	_m1.forget_player_id(peer_id)

## The player id behind a connection, or "peer_<id>" when the handshake has not
## happened yet. For LABELS and diagnostics only — never for authorizing an action:
## `peer_<id>` is a transport id the host hands out, not an identity it has bound,
## and every acting party must come from `get_player_id()` / `_actor_id()`.
func party_id_for(peer_id: int) -> String:
	var pid := get_player_id(peer_id)
	if pid.is_empty():
		return "peer_%d" % peer_id
	return pid

func send_snapshot(peer_id: int, data: Dictionary) -> bool:
	return _m3.send_snapshot(peer_id, data)

# ---------------------------------------------------------------------------
# Phase 19 — reconnect resume (host side)
# ---------------------------------------------------------------------------

func remember_player_state(peer_id: int, position: Vector3, exact: Dictionary = {}) -> void:
	_m1.remember_player_state(peer_id, position, exact)

## Phase 86 — the exact `{chunk, local}` position of the peer's last report, or an empty dictionary
## when it sent only a legacy float array (or nothing). Persist this in preference to the Vector3.
func get_last_known_exact(peer_id: int) -> Dictionary:
	return _last_known_exact.get(peer_id, {})

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

func _evict_stale_states() -> void:
	_m2._evict_stale_states()

# ---------------------------------------------------------------------------
# Phase 29 — interest management (area of interest)
# ---------------------------------------------------------------------------

## The AOI center for a peer: its last-known position, or the world spawn point
## when it has not reported one yet (a freshly connected client). Pure.
func get_aoi_center(peer_id: int) -> Vector3:
	return _last_known_states.get(peer_id, DEFAULT_AOI_CENTER)

## True when `position` lies within `peer_id`'s area of interest. Pure.
func in_aoi(peer_id: int, position: Vector3) -> bool:
	return within_aoi(get_aoi_center(peer_id), position)

## True when `position` lies within AOI_RADIUS of an explicit `center` — `in_aoi` with the
## centre supplied, for a caller (a re-scope snapshot) that knows a fresher centre than the
## last position this slice recorded. Pure.
static func within_aoi(center: Vector3, position: Vector3) -> bool:
	return center.distance_to(position) <= AOI_RADIUS

## Phase 122 — `within_aoi` on exact `{chunk, local}` positions, so a pair of players 1.5 million
## chunks from the origin is judged by their real distance, not a float32-rounded one. Pure.
static func within_aoi_exact(center: Dictionary, position: Dictionary) -> bool:
	return WorldPos.offset_between(center, position).length() <= AOI_RADIUS

## The AOI grid cell for a world position (cell = AOI_RADIUS). A peer crossing a
## cell boundary re-scopes its snapshot (see game_root). Pure.
func aoi_region(position: Vector3) -> Vector2i:
	return Vector2i(floori(position.x / AOI_RADIUS), floori(position.z / AOI_RADIUS))

## Peer ids (among `connected`) whose AOI contains `position`. Pure — the
## connected set is passed in so the filter is testable headless.
func aoi_recipients(position: Vector3, connected: Array) -> Array:
	return _m1.aoi_recipients(position, connected)

## Phase 163 — host: send the frame's queued relays, one `player_states` packet per recipient (net_part_1).
func flush_relays(paced: bool = false) -> int:
	return _m1.flush_relays(paced)

## Broadcast a spatial delta only to peers whose AOI contains `position`.
## On the host this replaces the N×M broadcast-to-all with a scoped fan-out;
## on a client it forwards to the host unchanged (position is ignored there).
func _broadcast_aoi(payload: Dictionary, position: Vector3) -> void:
	_m1.broadcast_aoi(payload, position)

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

## Phase 119 — the wire. `null` until the first send/connect, then an `EnetTransport` over the engine
## peer. The suite injects a `MemoryTransport` (`set_transport`); a release boot refuses it.
var _transport: Transport = null
## The engine transport, built lazily by `_ensure_transport` when none is injected.
var _enet: Transport = null

## Inject a transport. Allowed only in a `GameRoot.should_run_tests` boot (the suite): a game can never
## silently swap its sockets for an in-memory one. Returns false (and changes nothing) when refused.
func set_transport(transport: Transport) -> bool:
	if not transport_injection_allowed():
		Diag.warn("NetworkingSlice: set_transport refused outside a --run-tests boot")
		return false
	_transport = transport
	return true

## The suite's memory transport when one is injected (its `outbox` holds every send), else null.
func memory_transport() -> Object:
	return _transport if _transport != null and "outbox" in _transport else null

## The rule is `GameRoot.should_run_tests`, loaded on demand because `GameRoot` already depends on this slice.
static func transport_injection_allowed() -> bool:
	return transport_injection_allowed_for(OS.get_cmdline_user_args(), OS.is_debug_build())

static func transport_injection_allowed_for(args: Array, is_debug_build: bool) -> bool:
	var root_script: GDScript = load("res://src/core/game_root.gd")
	return root_script.should_run_tests(args, is_debug_build)

func _ensure_transport() -> Transport:
	if _transport != null:
		return _transport
	# The engine transport follows the node's CURRENT `multiplayer` (null outside the tree, swappable), so
	# it is rebuilt when that changes rather than caching a stale or null API.
	var api := multiplayer
	if _enet == null or not _enet.uses(api):
		_enet = EnetTransport.new(api, _send_raw)
	return _enet

## Peers the host would fan out to.
func _connected_peers() -> Array:
	return _ensure_transport().peers()

## Public read of the peers the host fans out to (empty before a transport is up).
func connected_peers() -> Array:
	return _connected_peers()

func _connected() -> bool:
	return _ensure_transport().is_up()

## Broadcast a packet dict to every peer (host) or to the host (client),
## routing through the Phase 19 emulator.
func _broadcast(payload: Dictionary) -> void:
	if not _connected():
		return
	if _role == Role.HOST:
		for pid in _connected_peers():
			_deliver(int(pid), payload.duplicate(true))
	elif _role == Role.CLIENT:
		_deliver(1, payload)

func _deliver(peer_id: int, payload: Dictionary) -> bool:
	return _m3._deliver(peer_id, payload)

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
	_m1._on_player_state_sync_requested(payload)

## Phase 178 — client packets that carried attribute values, refused and counted (see `_m2.refuse_attribute_claim`).
var attributes_refused: int = 0
var _attribute_refusal_warn_ms: Dictionary = {}

func _warn_malformed_position(sender: int, now_ms: float = -1.0) -> bool:
	if now_ms < 0.0:
		now_ms = float(Time.get_ticks_msec())
	var last: float = float(_malformed_position_warn_ms.get(sender, -MALFORMED_WARN_INTERVAL_MS))
	if now_ms - last < MALFORMED_WARN_INTERVAL_MS:
		return false
	_malformed_position_warn_ms[sender] = now_ms
	Diag.warn("NetworkingSlice: position packet from peer %d has a malformed position — dropped" % sender)
	return true

static func _is_exact_pos(pos: Variant) -> bool:
	return pos is Dictionary and pos.get("chunk") is Vector2i and pos.get("local") is Vector3

func _on_block_edit_intent(action: String, position: Vector3, normal: Vector3, material: String, exact: Dictionary) -> void:
	_m2._on_block_edit_intent(action, position, normal, material, exact)

func _on_block_changed(action: String, position: Vector3, normal: Vector3, material: String) -> void:
	if _role != Role.HOST:
		return
	var packet := {
		"type":     "block_changed",
		"action":   action,
		"position": WorldPos.to_wire(position),
		"normal":   [normal.x, normal.y, normal.z],
		"material": material,
	}
	_broadcast_aoi(packet, position)

func _on_tree_chop_requested(tree_id: String, _player_id: String) -> void:
	if _role != Role.CLIENT:
		# Host (and single-player) resolve the chop directly through TreeSlice;
		# only clients forward the intent.
		return
	# The player id is dropped on purpose: the host binds the actor to the
	# connection when the intent arrives (Phase 36), so a client naming one would
	# only be a claim. Same rule as the craft/repair/tame intent arms.
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

## Phase 110 — building cleared a tree for good; clients free it (an unknown id is ignored).
func _on_tree_cleared(tree_id: String) -> void:
	if _role != Role.HOST:
		return
	_broadcast({ "type": "tree_cleared", "tree_id": tree_id })

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

## Phase 129 — host → the target's peer ALONE: its active status effects (`[{ effect, remaining }]`).
## Private to that peer; the packet names no player (the receiver knows who it is).
func send_status_effects(peer_id: int, effects: Array) -> void:
	if _role != Role.HOST:
		Diag.warn("NetworkingSlice: send_status_effects called on non-host — dropped")
		return
	_deliver(peer_id, { "type": "status_effects", "effects": effects })

## Phase 125 — a client forwards a waystone travel intent; the host binds the identity.
func _on_waystone_travel_intent(from_id: String, to_id: String, _player_id: String) -> void:
	if _role != Role.CLIENT:
		return
	_broadcast({ "type": "waystone_travel_intent", "from": from_id, "to": to_id })

## Phase 185 — a client forwards a bed placement; the host binds the identity and validates the rest.
func _on_bed_place_intent(offset: Vector3, _player_id: String) -> void:
	if _role != Role.CLIENT:
		return
	_broadcast({ "type": "bed_place_intent", "offset": [offset.x, offset.y, offset.z] })

## Phase 140 — a client forwards a settlement intent; the host binds the identity and validates the rest.
func _on_settlement_intent(action: String, args: Dictionary, _player_id: String) -> void:
	if _role != Role.CLIENT:
		return
	_broadcast({ "type": "settlement_intent", "action": action, "args": args })

## Phase 35 — taming: the granted flag and the companion binding live on a player
## record the host owns, so a client forwards the target instance and the host
## tames for the identity it bound. The player_id half is ignored here for the same
## reason as craft_intent: the identity is bound to the connection on the host
## side, never trusted from the payload.
##
## The payload carries no claim about the sender's hands: the host reads them from its
## own record of the sender's worn set (TamingSlice.is_unarmed).
func _on_tame_intent(instance_id: String, _player_id: String) -> void:
	if _role != Role.CLIENT:
		return
	_broadcast({ "type": "tame_intent", "instance_id": instance_id })

## Phase 85 — client → host: a chat line or slash command. Carries no identity: the host binds the
## sender to the connection and decides whether a command is theirs to run.
func _on_chat_intent(text: String, _player_id: String) -> void:
	if _role != Role.CLIENT:
		return
	_broadcast({ "type": "chat_intent", "text": text })

## Phase 85 — host → clients: a posted line. Everyone gets an untargeted line; a targeted one (a
## command reply) goes to that player's peer alone. The host's own display hears the signal directly.
func _on_chat_posted(channel: String, sender: String, text: String, target_id: String) -> void:
	if _role != Role.HOST:
		return
	var payload := { "type": "chat_message", "channel": channel, "sender": sender, "text": text }
	if target_id == "":
		_broadcast(payload)
		return
	var peer := _equipment_owner(target_id)
	if peer > HOST_PEER_ID:
		_deliver(peer, payload)

## Phase 131 — host → clients: a system line as key + args. The text is rendered by each client in its
## own locale; targeting is as for `_on_chat_posted`.
func _on_system_message(key: String, args: Array, target_id: String) -> void:
	if _role != Role.HOST:
		return
	var payload := { "type": "system_message", "key": key, "args": args }
	if target_id == "":
		_broadcast(payload)
		return
	var peer := _equipment_owner(target_id)
	if peer > HOST_PEER_ID:
		_deliver(peer, payload)

func send_teleport(peer_id: int, position: Dictionary) -> bool:
	return _m3.send_teleport(peer_id, position)

## Peer -> { pos, msec }: where the host last teleported the peer, until a report shows it there (or
## TELEPORT_PENDING_MSEC passes). Reports already in flight still carry the old spot, so the last
## report alone would place the peer where it was before the teleport.
var _teleport_pending: Dictionary = {}
const TELEPORT_PENDING_MSEC := 3000
const TELEPORT_ARRIVED_M := 4.0

## The peer's exact position as the host should judge it: the pending teleport target when one is
## newer than its reports, else `get_last_known_exact`. The reports themselves are left untouched.
func get_expected_exact(peer_id: int) -> Dictionary:
	var pending: Variant = _teleport_pending.get(peer_id, null)
	if pending is Dictionary:
		if Time.get_ticks_msec() - int(pending["msec"]) <= TELEPORT_PENDING_MSEC:
			return pending["pos"]
		_teleport_pending.erase(peer_id)
	return get_last_known_exact(peer_id)

## Phase 47 — client → host: one equip / unequip action on this machine's avatar (`item_key`
## "" unequips `slot`). Carries no identity: the host binds it to the connection and decides
## whether it holds; the client's own avatar only shows the result optimistically.
## Phase 70 — client: sequence number of the newest equip action sent. A host correction
## older than this answers an action the client has since superseded and is ignored.
var _equip_seq_sent: int = 0

func equip_seq_sent() -> int:
	return _equip_seq_sent

func _on_equip_intent(_player_id: String, slot: String, item_key: String) -> void:
	if _role != Role.CLIENT:
		return
	_equip_seq_sent += 1
	_broadcast({ "type": "equip_intent", "slot": slot, "item": item_key, "seq": _equip_seq_sent })

## Peer id the host addresses its own avatar by (the server peer).
const HOST_PEER_ID := 1

## Host: the listen host's avatar position, pushed by game_root. The host has no
## `_last_known_states` entry (it never reports to itself), so its AOI membership is
## evaluated from here.
var _host_position: Vector3 = Vector3.ZERO
var _host_position_known: bool = false
## The position the pairs were last evaluated at. The "moved" threshold is measured
## against THIS, not against the previous frame: a per-frame step is far below the
## threshold, so a frame-to-frame comparison would never fire while walking.
var _host_evaluated_position: Vector3 = Vector3.ZERO

## "viewer:subject" → true for every (viewer, subject) pair whose worn set the host has
## sent, so a pair leaving AOI can be told to evict it and one entering can be sent it.
var _equipment_sent: Dictionary = {}

## Squared distance a CLIENT must move from where its pairs were last evaluated before
## they are evaluated again (the host's own movement uses the same 0.5 m). A pair only
## changes state at the AOI boundary, so AOI entry/exit lags by at most this distance.
const EQUIPMENT_REEVAL_DIST_SQ := 0.25
## peer_id → position that peer's pairs were last evaluated at (see above). Erased on
## disconnect with the peer's `_equipment_sent` entries.
var _equipment_eval_positions: Dictionary = {}
## Pair evaluations performed (`_update_equipment_pair` calls). Test/diagnostic counter:
## in the common no-boundary case a position report must add none.
var equipment_pair_evaluations: int = 0

func set_host_position(position: Vector3) -> void:
	if _role != Role.HOST:
		return
	var moved := not _host_position_known or _host_evaluated_position.distance_squared_to(position) > 0.25
	_host_position = position
	_host_position_known = true
	if moved and _connected() and player_registry != null:
		_host_evaluated_position = position
		_refresh_equipment_pairs(HOST_PEER_ID)

## Peer id owning `player_id`'s avatar: its connection, or the server peer for the
## listen host's own player. 0 when offline.
func _equipment_owner(player_id: String) -> int:
	if player_registry == null:
		return 0
	if player_id != "" and player_id == player_registry.local_player_id:
		return HOST_PEER_ID
	return int(player_registry.get_peer_id(player_id))

func _has_subject_position(peer_id: int) -> bool:
	return _host_position_known if peer_id == HOST_PEER_ID else has_last_known_state(peer_id)

func _subject_position(peer_id: int) -> Vector3:
	return _host_position if peer_id == HOST_PEER_ID else get_last_known_state(peer_id)

func _worn_of_peer(peer_id: int) -> Dictionary:
	if peer_id == HOST_PEER_ID:
		return player_registry.get_equipment(player_registry.local_player_id)
	return player_registry.get_equipment(str(player_registry.get_player_id(peer_id)))

func _pair_key(viewer: int, subject: int) -> String:
	return "%d:%d" % [viewer, subject]

## Deliver `subject`'s worn set to `viewer` and remember that it was sent.
func _send_equipment(viewer: int, subject: int, worn: Dictionary) -> void:
	_equipment_sent[_pair_key(viewer, subject)] = true
	_deliver(viewer, { "type": "peer_equipment", "peer_id": subject, "worn": worn.duplicate(true) })

## Phase 47 — host: a player's recorded worn set changed. It goes to the peers whose
## AOI contains that player (never `_broadcast`), tagged with the OWNER's peer id; the
## owner already holds its own set. The listen host is an owner too (peer 1). A player
## with no connection or no known position has no AOI to scope to and is not sent.
func _on_equipment_changed(player_id: String, worn: Dictionary) -> void:
	if _role != Role.HOST or not _connected() or player_registry == null:
		return
	var owner_peer := _equipment_owner(player_id)
	if owner_peer == 0 or not _has_subject_position(owner_peer):
		return
	for pid in equipment_targets(owner_peer):
		_send_equipment(int(pid), owner_peer, worn)

## Phase 48 — host: a worn slot was force-cleared. The owner is told through the
## owner-only `own_state_synced` channel (`equipment` key) so its avatar drops the item
## and its de-dup baseline resets. The listen host's own avatar is handled by game_root.
func _on_equipment_revoked(player_id: String, worn: Dictionary) -> void:
	if _role != Role.HOST or not _connected() or player_registry == null:
		return
	var owner_peer := _equipment_owner(player_id)
	if owner_peer == 0 or owner_peer == HOST_PEER_ID:
		return
	send_own_state(owner_peer, { "equipment": worn.duplicate(), "equipment_seq": player_registry.equip_seq_of(player_id) })

## Peers (the host's own id excluded) whose AOI contains `owner`'s avatar.
func equipment_targets(owner_peer: int) -> Array:
	var out: Array = []
	if not _has_subject_position(owner_peer):
		return out
	for pid in aoi_recipients(_subject_position(owner_peer), _connected_peers()):
		if int(pid) != owner_peer:
			out.append(int(pid))
	return out

func send_peer_equipment_to(peer_id: int) -> void:
	_m1.send_peer_equipment_to(peer_id)

## AOI centre for a peer that has just joined: its reported position when it has one,
## else the position restored from its record (a joiner has reported none yet, and the
## spawn default would scope a reconnecting player to the wrong place), else the default.
func _joiner_aoi_center(peer_id: int) -> Vector3:
	if has_last_known_state(peer_id):
		return get_aoi_center(peer_id)
	var rec: Dictionary = player_registry.get_record(str(player_registry.get_player_id(peer_id)))
	var pos = rec.get("position", null)
	if WorldPos.is_wire(pos):
		return WorldPos.from_wire(pos)
	return DEFAULT_AOI_CENTER

func announce_equipment_to_aoi(peer_id: int) -> void:
	_m2.announce_equipment_to_aoi(peer_id)

func _refresh_equipment_pairs(moved: int) -> void:
	_m3._refresh_equipment_pairs(moved)

func _update_equipment_pair(viewer: int, subject: int) -> void:
	_m1._update_equipment_pair(viewer, subject)

## Phase 54 — host: send every peer the world clock sample `days` (in-game days).
func broadcast_world_clock(days: float) -> void:
	if _role == Role.HOST:
		_broadcast({ "type": "world_clock", "days": days })

## Phase 128 — host: send every peer the weather override table (`WeatherSlice.to_data()` form).
func broadcast_weather_overrides(overrides: Array) -> void:
	if _role == Role.HOST:
		_broadcast({ "type": "weather_overrides", "overrides": overrides })

func _forget_equipment_pairs(peer_id: int) -> void:
	_m1.forget_equipment_pairs(peer_id)

## Phase 34 — host → one client: the peer's OWN record slice changed on the host's
## side of an action it asked for (its inventory after a repair, its technology
## statuses after a research). Delivered to that peer alone: an inventory is
## private, so unlike an AOI-scoped world delta this cannot be broadcast.
## `data` mirrors the like-named join-snapshot keys:
## { inventory, inventory_durability, technology }.
func send_own_state(peer_id: int, data: Dictionary) -> void:
	if _role != Role.HOST:
		Diag.warn("NetworkingSlice: send_own_state called on non-host — dropped")
		return
	_deliver(peer_id, { "type": "own_state_synced", "data": data })

func _on_creature_state_changed(instance_id: String, creature_id: String, state: String, position: Dictionary) -> void:
	_m3.relay_creature_state(instance_id, creature_id, state, position)

## Phase 97 — the exact position of the `player_moved` report being routed right now (empty otherwise);
## `_on_remote_player_state` relays it. Set and cleared around the emit in `_route_c2h`.
var _inbound_exact: Dictionary = {}

## Phase 130 — host: `(peer_id) -> bool`, true while that peer's player is immobilized by a status effect
## (paralysis, knockdown). A `player_moved` report from a held peer is dropped, so its last-known
## position stands whatever its own client sends. Unset: nothing is held.
var peer_held: Callable = Callable()

## Issue #426 — host: `(peer_id) -> float`, a peer's top horizontal speed in m/s (0 = uncapped; a carrier's comes from
## its body). A report that outruns it is clamped and the peer is teleported back (see `_clamp_to_speed_cap`).
var peer_speed_cap: Callable = Callable()
## Phase 182 — `(player_id) -> bool`: whether a player is an admin (ChatSlice.is_admin), told to its
## client with its identity.
var admin_check: Callable = Callable()

func _on_remote_player_state(peer_id: int, position: Vector3) -> void:
	TickProbe.begin("aoi_relay")
	_m2._on_remote_player_state(peer_id, position)
	TickProbe.end()

func _on_inventory_synced(owner_id: String, contents: Dictionary, durabilities: Dictionary = {}) -> void:
	_m3._on_inventory_synced(owner_id, contents, durabilities)

func _peer_for_inventory_owner(owner_id: String) -> int:
	return _m1._peer_for_inventory_owner(owner_id)

## Phase 156 — the longest key and the outcomes a `combat_hit` packet may carry.
const COMBAT_KEY_MAX := 64
const COMBAT_OUTCOMES := ["hit", "critical", "miss", "kill"]

## Phase 159 — the longest gesture id a packet may carry.
const GESTURE_ID_MAX := GestureRules.MAX_ID_CHARS

func send_gesture(subject_peer: int, gesture_id: String, position: Vector3) -> void:
	_m2.send_gesture(subject_peer, gesture_id, position)

func send_peer_gestures_to(peer_id: int, poses: Dictionary) -> void:
	_m2.send_peer_gestures_to(peer_id, poses)

## Phase 159 — client: forward a gesture action; the host binds it to the connection's player.
func _on_gesture_intent(gesture_id: String, _player_id: String) -> void:
	if _role != Role.CLIENT:
		return
	_broadcast({ "type": "gesture_intent", "g": gesture_id })

## Phase 181 — creation and looks (bodies in net_part_1): a client forwards its creation intent and asks for a
## peer's look when that peer's avatar appears; the host answers inside the AOI and pushes a changed look.
func _on_character_creation_intent(action: String, creation: Dictionary, _player_id: String) -> void:
	_m1.forward_creation_intent(action, creation)

func request_peer_look(peer_id: int) -> void:
	if _role == Role.CLIENT and peer_id > 0:
		_broadcast({ "type": "look_request", "peer_id": peer_id })

## Look requests the host answered / refused (subject outside the requester's AOI, unknown, or unbound).
var look_requests_answered: int = 0
var look_requests_refused: int = 0

func answer_look_request(viewer: int, subject: int) -> bool:
	return _m1.answer_look_request(viewer, subject)

func _on_player_look_changed(player_id: String, look: Dictionary) -> void:
	_m1.push_look(player_id, look)

## Phase 161 — carcasses. The host sends a body's record to the peers whose AOI holds it, and its removal to
## everyone (a body that left the AOI is forgotten by the client when it never returns).
func send_carcass(record: Dictionary) -> void:
	_m2.send_carcass(record)

func send_carcass_removed(carcass_id: String, only_peer: int = 0) -> void:   # only_peer 0 = everyone
	_m2.send_carcass_removed(carcass_id, only_peer)

func send_carcasses_to(peer_id: int, records: Array) -> Array:
	return _m2.send_carcasses_to(peer_id, records)

func send_carry_state(peer_id: int, carrying: bool, speed_factor: float) -> void:
	_m2.send_carry_state(peer_id, carrying, speed_factor)

## Phase 182 — host → one client: its admin moves, an admin heal or its admin status (see `_m2.send_admin`).
func send_admin(peer_id: int, kind: String, fields: Dictionary = {}) -> bool:
	return _m2.send_admin(peer_id, kind, fields)
func broadcast_world_regen() -> void:
	_m2.broadcast_world_regen()

## Phase 161 — client: forward a carcass action; the host binds it to the connection's player.
func _on_harvest_intent(carcass_id: String, _player_id: String) -> void:
	if _role == Role.CLIENT:
		_broadcast({ "type": "harvest_intent", "id": carcass_id })

func _on_carry_intent(carcass_id: String, _player_id: String) -> void:
	if _role == Role.CLIENT:
		_broadcast({ "type": "carry_intent", "id": carcass_id })

func _on_carcass_drop_intent(_player_id: String) -> void:
	if _role == Role.CLIENT:
		_broadcast({ "type": "carcass_drop_intent" })

func send_combat_hit(attacker_key: String, defender_key: String, outcome: String, position: Vector3) -> void:
	_m2.send_combat_hit(attacker_key, defender_key, outcome, position)

func send_player_damaged(peer_id: int, damage: float, attacker_id: String) -> void:
	_m2.send_player_damaged(peer_id, damage, attacker_id)

func _on_void_burst_resolved(result: Dictionary) -> void:
	_m3._on_void_burst_resolved(result)

## Phase 118 — host → the owner's peer alone: a profession unlocked for them.
func _on_profession_unlocked(player_id: String, profession: String) -> void:
	if _role != Role.HOST:
		return
	var peer := _peer_for_inventory_owner(player_id)
	if peer == 0:
		return
	_deliver(peer, { "type": "profession_unlocked", "profession": profession })

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
	_m1.packet_send_requested(peer_id, payload)

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
	TickProbe.begin("net_in")   # Phase 162 — the stress run's cost of inbound client packets
	_accept_c2h(multiplayer.get_remote_sender_id(), json)
	TickProbe.end()

func _accept_c2h(sender: int, json: String) -> void:
	if json.length() > MAX_CLIENT_PACKET_BYTES:
		Diag.warn("NetworkingSlice: client packet from peer %d is %d chars (cap %d) — dropped" \
			% [sender, json.length(), MAX_CLIENT_PACKET_BYTES])
		return
	if not _allow_packet(sender, float(Time.get_ticks_msec())):
		return
	var payload = _parse(json)
	if payload == null:
		return
	if TickProbe.enabled:
		TickProbe.count_in(sender, str(payload.get("type", "")), json.to_utf8_buffer().size())
	if not _dedup(sender, payload):
		return
	_route_c2h(sender, payload)

## Host → client channel: authoritative state and the world snapshot.
@rpc("authority", "reliable")
func _rpc_h2c(json: String) -> void:
	var payload = _parse(json)
	if payload == null:
		return
	if TickProbe.enabled:
		TickProbe.count_in(1, str(payload.get("type", "")), json.to_utf8_buffer().size())
	# Snapshot chunks are index-reassembled (out-of-order tolerant) and made
	# idempotent separately; every other packet type is seq-deduplicated.
	if str(payload.get("type", "")) != "snapshot_chunk":
		if not _dedup(multiplayer.get_remote_sender_id(), payload):
			return
	_route_h2c(payload)

func _parse(json: String) -> Variant:
	var payload = JSON.parse_string(json)
	if payload == null:
		Diag.error("NetworkingSlice: malformed JSON packet dropped")
		return null
	if not payload is Dictionary:
		Diag.error("NetworkingSlice: expected Dictionary packet, got %s" % typeof(payload))
		return null
	return payload

func _dedup(sender: int, payload: Dictionary) -> bool:
	return _m1._dedup(sender, payload)

func _allow_packet(peer_id: int, now_ms: float) -> bool:
	return _m2._allow_packet(peer_id, now_ms)

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
	Diag.warn("NetworkingSlice: %s from un-handshaked peer %d — dropped" % [ptype, sender])

func _within_reach(sender: int, position: Vector3, reach: float) -> bool:
	return _m3._within_reach(sender, position, reach)

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

func _named_party(raw: String) -> String:
	return _m1._named_party(raw)

# ---------------------------------------------------------------------------
# Phase 36 — identity redaction on the wire
# ---------------------------------------------------------------------------

## Host side: the public-handle form of a player id, or "" when no registry is wired
## (then there is nothing to redact with; see redact_for_client).
func _public_handle(player_id: String) -> String:
	if player_registry == null or not player_registry.has_method("public_handle"):
		return ""
	return str(player_registry.public_handle(player_id))

func redact_for_client(value: Variant) -> Variant:
	return _m2.redact_for_client(value)

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

func redact_social_state(state: Dictionary) -> Dictionary:
	return _m3.redact_social_state(state)

func _map_identities(value: Variant, mapper: Callable) -> Variant:
	return _m1._map_identities(value, mapper)

## Client side: the world snapshot's identity-bearing blobs, restored to this client's
## own view (see IDENTIFIED_STATE_KEYS — the host half of the same list is
## `redact_social_state`). Only those keys are walked — a snapshot is
## mostly terrain and entity data, and rewriting every string in it would cost a pass
## over the whole world for no privacy gain.
func _adopt_snapshot_identities(data: Dictionary) -> Dictionary:
	for key in IDENTIFIED_STATE_KEYS:
		if data.has(key):
			data[key] = adopt_own_handle(data[key])
	return data

func _route_c2h(sender: int, payload: Dictionary) -> void:
	_m2._route_c2h(sender, payload)

func _route_h2c(payload: Dictionary) -> void:
	_m3._route_h2c(payload)

## Remote-player state on the client: when emulation is enabled, buffer and
## replay through the jitter buffer; otherwise emit straight through (the
## Phase 18 path, unchanged).
func _route_remote_player_state(payload: Dictionary) -> void:
	_m1._route_remote_player_state(payload)

func _accumulate_snapshot_chunk(payload: Dictionary) -> void:
	_m1._accumulate_snapshot_chunk(payload)

## Decode a wire vector. Positions arrive as `{chunk, local}` (Phase 63) or the legacy `[x, y, z]`
## array; normals and other plain vectors are always the array form.
func _vec3(arr) -> Vector3:
	return WorldPos.from_wire(arr)

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

## Phase 135 — when a packet of `size_bytes` sent at `now_ms` is delivered: it waits for the wire
## (bandwidth), takes `size_bytes * 8 / kbps` ms to serialise, then travels `latency + jitter`. With a
## cap the link is a single FIFO, so delivery over any one-second window never exceeds the rate.
func _schedule_at_ms(now_ms: float, size_bytes: int, peer_id: int = 0) -> float:
	var leaves_at := now_ms
	if emulator_bandwidth_kbps > 0.0:
		var free_at: float = maxf(float(_link_free_at_ms.get(peer_id, 0.0)), now_ms) \
				+ float(size_bytes) * 8.0 / emulator_bandwidth_kbps
		_link_free_at_ms[peer_id] = free_at
		leaves_at = free_at
	return leaves_at + maxf(0.0, emulator_latency_ms) + _jitter_delay_ms()

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

## Phase 135 — can a packet for `peer_id` still be sent? Always yes for a transport with no seq
## (in-memory tests); otherwise the link must be up and, on the host, the peer still connected.
func _peer_reachable(peer_id: int) -> bool:
	var transport := _ensure_transport()
	if not transport.stamps_seq:
		return true
	if not transport.is_up():
		return false
	return _role != Role.HOST or peer_id in transport.peers()

func _drain_emulator(now_ms: float = -1.0) -> void:
	_m2._drain_emulator(now_ms)

# ---------------------------------------------------------------------------
# Phase 19 — jitter buffer (client)
# ---------------------------------------------------------------------------

## Push a remote-player snapshot into the jitter buffer.
func _buffer_remote_state(peer_id: int, position: Vector3) -> void:
	var at_ms := float(Time.get_ticks_msec())
	if not _jitter_buffer.has(peer_id):
		_jitter_buffer[peer_id] = []
	_jitter_buffer[peer_id].append({ "at_ms": at_ms, "position": position })

func _sample_remote_state_at(peer_id: int, now_ms: float) -> Vector3:
	return _m3._sample_remote_state_at(peer_id, now_ms)

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
	# Phase 38 — the other end of the same lifecycle: a CLIENT losing its host. Without
	# this the client's reassembly state had no eviction point at all (both clear sites
	# were on the host's side of the wire).
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _detach_peer() -> void:
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)

func _on_server_disconnected() -> void:
	_m1._on_server_disconnected()

## Phase 33 — client side: the connection is up, so present our cached player id.
## The host answers with the id it binds us to (the same one on a reconnect, a
## fresh one on a first join, and a fresh one for a claim it refuses).
func _on_connected_to_server() -> void:
	_equip_seq_sent = 0  # the host numbers a fresh bind from zero too
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
	_deliver(1, { "type": "join_intent", "claimed_id": claimed_player_id, "friend_code": friend_code })

## Phase 53 — host side: tell the peer where it was placed when there is something to say (an
## unknown friend code fell back to the normal search). The message is a catalog key, short, and
## carries no id; the client renders it in its own locale.
func _on_spawn_placed(player_id: String, _position: Vector3, _source: String, message: String) -> void:
	if _role != Role.HOST or message.is_empty():
		return
	var peer := _equipment_owner(player_id)
	if peer > 1:
		_deliver(peer, { "type": "spawn_notice", "key": message })

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

func _on_peer_disconnected(id: int) -> void:
	_m2._on_peer_disconnected(id)
