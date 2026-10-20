extends "res://src/networking/networking_slice.gd"
## Phase 162 — one stress bot's end of the wire: the shipped `NetworkingSlice` in the CLIENT role, so
## every packet a bot sends is built, sequenced, rate-shaped and (under `--net-profile`) emulated by the
## same code a player's client runs. The host sees the same join intent, the same `player_moved` claims
## at the same rate, from a connection with its own ENet peer and player identity.
##
## What a bot does NOT do is hand the host's packets to a game: it has none, and n bots re-emitting
## every relay on the one shared GameBus would cost the bot process n² handler calls. It keeps only
## what a bot needs — its identity, the spawn its join snapshot names, an admin teleport — and drops
## the rest after the base class has parsed and de-duplicated it, as a client would.

const PlayerSlice := preload("res://src/player/player_slice.gd")

## The host bound an identity to this connection (cleared on a new connection).
var joined := false
## The join snapshot arrived whole.
var snapshot_done := false
## This bot's own position from the join snapshot (`{chunk, local}`; empty until it lands).
var spawn: Dictionary = {}
## Where an admin teleport put the bot (empty when none is pending); the driver adopts it.
var teleported: Dictionary = {}
## Host → bot packets routed, all types.
var packets_in := 0
## Snapshot reassembly for the JOIN snapshot only: id -> { count, got, parts }.
var _join_parts: Dictionary = {}
var _join_snapshot_id := -1

## No GameBus wiring (see the header): only the link profile is read from the command line.
func _ready() -> void:
	_apply_profile_arg(OS.get_cmdline_user_args())

## Connect (or reconnect) to the host. A reconnect presents the identity the host gave the last one.
func connect_to(address: String, port: int) -> Error:
	joined = false
	snapshot_done = false
	spawn = {}
	_join_parts.clear()
	_join_snapshot_id = -1
	return join(address, port)

## Leave the way a player's client does when it quits: a graceful ENet disconnect, which the host
## acknowledges (`server_disconnected` fires here then). A forced close sends one unreliable goodbye
## that a host busy enough to drop packets never sees, and it then holds the peer until ENet times out.
func leave() -> void:
	if _peer != null and _peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		_peer.disconnect_peer(1)

## The movement report a client sends every `SYNC_INTERVAL` physics ticks, for `exact`.
## Returns the key the watcher will see this position under (`TickProbe.position_key`).
func report(exact: Dictionary) -> String:
	_on_player_state_sync_requested({
		"position": WorldPos.to_scene(exact, Vector2i.ZERO),
		"world_pos": exact,
		"hp": PlayerSlice.MAX_HP,
		"max_hp": PlayerSlice.MAX_HP,
	})
	return TickProbe.position_key(WorldPos.pos_from_compact(WorldPos.pos_to_packet_text(exact)))

func _route_h2c(payload: Dictionary) -> void:
	packets_in += 1
	match str(payload.get("type", "")):
		"identity_assigned":
			claimed_player_id = str(payload.get("player_id", ""))
			claimed_handle = str(payload.get("handle", ""))
			joined = true
		"snapshot_chunk":
			_take_join_chunk(payload)
		"teleport":
			var spot: Dictionary = WorldPos.pos_from_wire(payload.get("position", null))
			if not spot.is_empty():
				teleported = spot

## Reassemble the first snapshot after the identity (the join snapshot) and read the bot's own
## position out of it; later snapshots (AOI re-scopes) are counted and dropped.
func _take_join_chunk(payload: Dictionary) -> void:
	var sid := int(payload.get("snapshot_id", -1))
	if snapshot_done or not joined:
		return
	if _join_snapshot_id < 0:
		_join_snapshot_id = sid
	if sid != _join_snapshot_id:
		return
	var count := int(payload.get("count", 0))
	var index := int(payload.get("index", -1))
	if count <= 0 or index < 0 or index >= count:
		return
	if _join_parts.is_empty():
		_join_parts = { "count": count, "got": 0, "parts": [] }
		_join_parts["parts"].resize(count)
		_join_parts["parts"].fill("")
	if str(_join_parts["parts"][index]) == "":
		_join_parts["parts"][index] = str(payload.get("data", ""))
		_join_parts["got"] = int(_join_parts["got"]) + 1
	if int(_join_parts["got"]) < count:
		return
	var data: Variant = JSON.parse_string("".join(PackedStringArray(_join_parts["parts"])))
	_join_parts.clear()
	snapshot_done = true
	if data is Dictionary:
		var own: Variant = (data as Dictionary).get("player", {})
		if own is Dictionary:
			spawn = WorldPos.pos_from_wire((own as Dictionary).get("position", null))
