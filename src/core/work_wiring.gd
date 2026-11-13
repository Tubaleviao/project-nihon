extends "res://src/core/wiring.gd"
## Phase 259 — timed work, the host's own player (a listen host or single player): the start intent is answered
## with the duration the host computed. A remote client's start/cancel/claim arrive as packets and reach the same
## `WorkHost` through `NetworkingSlice.work_host`.

const WorkHost := preload("res://src/core/work_host.gd")

var host := WorkHost.new()

func _connect_all() -> void:
	host.tree_slice = root._tree
	host.voxel_slice = root._voxel
	root._networking.set_meta("work_host", host)
	connect_bus(GameBus.work_start_requested, _on_start)
	connect_bus(GameBus.work_cancel_requested, _on_cancel)

func _on_start(kind: String, tree_id: String, position: Vector3, normal: Vector3, exact: Dictionary, player_id: String) -> void:
	if root._is_client:
		# The host binds the actor to the connection and answers with a `work_started` packet.
		var net := root._networking
		var packet := { "type": "work_start_intent", "kind": kind, "tree_id": tree_id, "normal": [normal.x, normal.y, normal.z] }
		if net._is_exact_pos(exact) and net.WorldPos.is_plausible_pos(exact):
			packet["pk"] = net.WorldPos.pos_to_packet_text(exact)
		else:
			packet["position"] = net.WorldPos.to_wire(position)
		net._broadcast(packet)
		return
	var r := host.start(player_id, kind, tree_id, position, normal, exact, Time.get_ticks_msec() * 0.001)
	if bool(r["ok"]):
		GameBus.work_started.emit(str(r["key"]), float(r["duration"]), str(r["action"]), str(r["material"]))

func _on_cancel(player_id: String) -> void:
	if root._is_client:
		root._networking._broadcast({ "type": "work_cancel_intent" })
	else:
		host.cancel(player_id)
