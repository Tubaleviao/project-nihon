extends Node
## Networking slice — authoritative host/client model (Phase 18).
##
## The host runs the authoritative simulation (terrain, creature AI, combat,
## voxel edits, loot). Clients send their local input and block-edit intents
## to the host, and apply authoritative state deltas the host broadcasts back.
## A client never mutates world state on its own — every block edit and
## creature state change flows through the host.
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

enum Role { OFFLINE, HOST, CLIENT }

const DEFAULT_PORT    := 7777
const DEFAULT_CHANNEL := 0
## Max JSON chars per snapshot chunk (≈ bytes for ASCII). Large snapshots are
## split across multiple reliable packets and reassembled on the client.
const SNAPSHOT_CHUNK_SIZE := 16384

var _peer: ENetMultiplayerPeer
var _role: int = Role.OFFLINE

## Snapshot reassembly state (client): snapshot_id → { count, received, parts }.
var _snapshot_buffer: Dictionary = {}
var _next_snapshot_id: int = 0

func _ready() -> void:
	GameBus.packet_send_requested.connect(_on_packet_send_requested)
	GameBus.player_state_sync_requested.connect(_on_player_state_sync_requested)
	GameBus.block_edit_intent.connect(_on_block_edit_intent)
	GameBus.block_changed.connect(_on_block_changed)
	GameBus.creature_state_changed.connect(_on_creature_state_changed)
	GameBus.remote_player_state.connect(_on_remote_player_state)
	GameBus.inventory_synced.connect(_on_inventory_synced)

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
		_rpc_h2c.rpc_id(peer_id, JSON.stringify(packet))

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _connected() -> bool:
	var mp_peer := multiplayer.multiplayer_peer
	if mp_peer == null:
		return false
	return mp_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

## Broadcast a JSON packet to every connected peer (host) or to the host (client).
func _send_json(json: String) -> void:
	if not _connected():
		return
	if _role == Role.HOST:
		for pid in multiplayer.get_peers():
			_rpc_h2c.rpc_id(pid, json)
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
	_send_json(JSON.stringify(packet))

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
	_send_json(JSON.stringify(packet))

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
	_send_json(JSON.stringify(packet))

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
	_send_json(JSON.stringify(packet))

func _on_remote_player_state(peer_id: int, position: Vector3) -> void:
	if _role != Role.HOST:
		return
	var packet := {
		"type":     "remote_player_state",
		"peer_id":  peer_id,
		"position": [position.x, position.y, position.z],
	}
	_send_json(JSON.stringify(packet))

func _on_inventory_synced(contents: Dictionary) -> void:
	if _role != Role.HOST:
		return
	var packet := {
		"type":     "inventory_synced",
		"contents": contents,
	}
	_send_json(JSON.stringify(packet))

func _on_packet_send_requested(peer_id: int, payload: Dictionary) -> void:
	# Legacy low-level send: wraps an arbitrary payload and ships it as-is.
	if not _connected():
		return
	var json := JSON.stringify(payload)
	if _role == Role.HOST:
		_rpc_h2c.rpc_id(peer_id, json)
	else:
		_rpc_c2h.rpc_id(1, json)

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
	_route_c2h(sender, payload)

## Host → client channel: authoritative state and the world snapshot.
@rpc("authority", "reliable")
func _rpc_h2c(json: String) -> void:
	var payload = _parse(json)
	if payload == null:
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
			GameBus.remote_player_state.emit(
				int(payload.get("peer_id", 0)),
				_vec3(payload.get("position", []))
			)
		"inventory_synced":
			GameBus.inventory_synced.emit(payload.get("contents", {}))
		"world_snapshot":
			GameBus.world_snapshot_received.emit(payload.get("data", {}))
		"snapshot_chunk":
			_accumulate_snapshot_chunk(payload)
		_:
			# Legacy low-level packets fall through to packet_received.
			GameBus.packet_received.emit(1, payload)

## Reassemble a chunked world snapshot (see send_snapshot) and emit
## world_snapshot_received once the final chunk lands. Chunks are indexed so
## out-of-order delivery still reassembles correctly.
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

func _on_peer_disconnected(id: int) -> void:
	GameBus.peer_disconnected.emit(id)
