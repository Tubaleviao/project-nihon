extends "res://src/networking/transport.gd"
## Phase 119 — the suite's transport: no sockets. `connected` answers `peers()` and every `send` lands
## in `outbox` as `{ peer_id, payload }`, unsequenced and unserialised, for a test to inspect.

var connected: Array
var outbox: Array = []

func _init(peer_ids: Array = []) -> void:
	connected = peer_ids

func peers() -> Array:
	return connected

func is_up() -> bool:
	return true

func send(peer: int, msg: Dictionary) -> void:
	outbox.append({ "peer_id": peer, "payload": msg })

func is_memory() -> bool:
	return true

func stamps_seq() -> bool:
	return false
