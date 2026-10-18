extends "res://src/networking/transport.gd"
## Phase 119 — the game's transport: packets travel as JSON strings over the slice's reliable RPCs on
## the engine's ENet multiplayer peer. `send_raw` is the slice's `(peer, json)` RPC sender, so the RPC
## declarations stay on the node that owns them.

const TickProbe := preload("res://src/core/tick_probe.gd")

var _multiplayer: MultiplayerAPI
var _send_raw: Callable

func _init(multiplayer_api: MultiplayerAPI, send_raw: Callable) -> void:
	_multiplayer = multiplayer_api
	_send_raw = send_raw

func uses(api: MultiplayerAPI) -> bool:
	return _multiplayer == api

func peers() -> Array:
	if _multiplayer == null:
		return []
	return Array(_multiplayer.get_peers())

func is_up() -> bool:
	if _multiplayer == null:
		return false
	var mp_peer := _multiplayer.multiplayer_peer
	return mp_peer != null and mp_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func send(peer: int, msg: Dictionary) -> void:
	var json := JSON.stringify(msg)
	TickProbe.count_out(peer, str(msg.get("type", "")), json.length())   # Phase 162 — stress run byte counts
	_send_raw.call(peer, json)
