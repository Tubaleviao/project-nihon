extends Node
## Networking slice — ENet peer with host / join helpers.
##
## Plug contract (GameBus signals consumed / emitted):
##   IN  : packet_send_requested(peer_id, payload)
##         player_state_sync_requested(payload)   — broadcasts own state to all peers
##   OUT : peer_connected(peer_id)
##         peer_disconnected(peer_id)
##         packet_received(peer_id, payload)       — carries typed payloads from peers
##
## Packet schema (all payloads carry a "type" key):
##   "player_state" : { type, peer_id, position:[x,y,z], hp, max_hp }
##   "creature_died": { type, entity_id, position:[x,y,z], killer_id }
##
## Public API:
##   host(port: int, max_clients: int) -> Error
##   join(address: String, port: int)  -> Error
##   disconnect_all()                  -> void

const DEFAULT_PORT    := 7777
const DEFAULT_CHANNEL := 0

var _peer: ENetMultiplayerPeer

func _ready() -> void:
	GameBus.packet_send_requested.connect(_on_packet_send_requested)
	GameBus.player_state_sync_requested.connect(_on_player_state_sync_requested)
	GameBus.creature_died.connect(_on_creature_died_for_broadcast)

## Start an ENet server on the given port.
func host(port: int = DEFAULT_PORT, max_clients: int = 64) -> Error:
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(port, max_clients)
	if err != OK:
		push_error("NetworkingSlice: failed to create server on port %d — %s" % [port, error_string(err)])
		return err
	_attach_peer()
	print("NetworkingSlice: hosting on port %d" % port)
	return OK

## Connect to a remote host.
func join(address: String = "127.0.0.1", port: int = DEFAULT_PORT) -> Error:
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(address, port)
	if err != OK:
		push_error("NetworkingSlice: failed to connect to %s:%d — %s" % [address, port, error_string(err)])
		return err
	_attach_peer()
	print("NetworkingSlice: connecting to %s:%d" % [address, port])
	return OK

## Tear down the peer.
func disconnect_all() -> void:
	if _peer:
		_peer.close()
	_detach_peer()
	multiplayer.multiplayer_peer = null

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _attach_peer() -> void:
	# Disconnect stale handlers before reconnecting to prevent duplicates.
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

func _on_player_state_sync_requested(payload: Dictionary) -> void:
	var mp_peer := multiplayer.multiplayer_peer
	if mp_peer == null or mp_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	var pos: Vector3 = payload.get("position", Vector3.ZERO)
	var packet := {
		"type":     "player_state",
		"peer_id":  multiplayer.get_unique_id(),
		"position": [pos.x, pos.y, pos.z],
		"hp":       payload.get("hp",     100.0),
		"max_hp":   payload.get("max_hp", 100.0),
	}
	# Broadcast to all connected peers.
	for pid in multiplayer.get_peers():
		var json := JSON.stringify(packet)
		_relay_packet.rpc_id(pid, json)

func _on_creature_died_for_broadcast(entity_id: String, position: Vector3, killer_id: String) -> void:
	var mp_peer := multiplayer.multiplayer_peer
	if mp_peer == null or mp_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	var packet := {
		"type":      "creature_died",
		"entity_id": entity_id,
		"position":  [position.x, position.y, position.z],
		"killer_id": killer_id,
	}
	for pid in multiplayer.get_peers():
		var json := JSON.stringify(packet)
		_relay_packet.rpc_id(pid, json)

func _on_packet_send_requested(peer_id: int, payload: Dictionary) -> void:
	var mp_peer := multiplayer.multiplayer_peer
	if mp_peer == null:
		return
	# Only send when fully connected; drop packets during the handshake window.
	if mp_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		push_warning("NetworkingSlice: dropping packet to peer %d — not yet connected" % peer_id)
		return
	var json := JSON.stringify(payload)
	_relay_packet.rpc_id(peer_id, json)

@rpc("any_peer", "reliable")
func _relay_packet(json: String) -> void:
	var sender := multiplayer.get_remote_sender_id()
	# Server-side only: reject relays from non-authoritative senders.
	# sender == 0 means the call originated locally (server calling itself),
	# which is a sign of a mis-routed packet_send_requested event.
	if multiplayer.is_server() and sender == 0:
		push_error("NetworkingSlice: _relay_packet called locally on the server — dropped")
		return
	var payload = JSON.parse_string(json)
	if payload == null:
		push_error("NetworkingSlice: received malformed JSON packet from peer %d" % sender)
		return
	if not payload is Dictionary:
		push_error("NetworkingSlice: expected Dictionary payload from peer %d, got %s" % [sender, typeof(payload)])
		return
	GameBus.packet_received.emit(sender, payload)
