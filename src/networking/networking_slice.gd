extends Node
## Networking slice — ENet peer with host / join helpers.
##
## Plug contract (GameBus signals consumed / emitted):
##   IN  : packet_send_requested(peer_id, payload)
##   OUT : peer_connected(peer_id)
##         peer_disconnected(peer_id)
##         packet_received(peer_id, payload)
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
	multiplayer.multiplayer_peer = null

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _attach_peer() -> void:
	multiplayer.multiplayer_peer = _peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _on_peer_connected(id: int) -> void:
	GameBus.peer_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	GameBus.peer_disconnected.emit(id)

func _on_packet_send_requested(peer_id: int, payload: Dictionary) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	var json := JSON.stringify(payload)
	# Use an RPC routed through a dedicated relay method to avoid raw byte sends.
	_relay_packet.rpc_id(peer_id, json)

@rpc("any_peer", "reliable")
func _relay_packet(json: String) -> void:
	var payload = JSON.parse_string(json)
	if payload == null:
		push_error("NetworkingSlice: received malformed JSON packet")
		return
	var sender := multiplayer.get_remote_sender_id()
	GameBus.packet_received.emit(sender, payload)
