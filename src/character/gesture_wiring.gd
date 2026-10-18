extends "res://src/core/wiring.gd"
## Gesture wiring (Phase 159) — sit, lie down, wave and friends.
##
## Host / offline: `gesture_intent` (the local player's, or a peer's bound to its connection) is validated
## by `GestureSlice`, the accepted start or cancel (`gesture_synced`) is played on the host's own avatar
## and sent to the peers whose AOI holds the player. The host also watches movement, damage and death to
## cancel, and applies `restRegen` while a pose is held. Client: `peer_gesture_synced` plays the pose on the
## avatar of the peer it names (this machine's own body included); a pose for an avatar not built yet waits.

const GestureRules := preload("res://src/character/gesture_rules.gd")
const PlayerRegistry := preload("res://src/persistence/player_registry.gd")
const PlayerSlice := preload("res://src/player/player_slice.gd")

## Gesture the sit falls back to when no seat is in front of the body.
const GROUND_SIT := "SitGround"
const SEAT_GESTURE := "Sit"
## How far ahead of the body a seat is looked for.
const SEAT_REACH_M := 0.6

## `(iid) -> float` seat lift override for the suite; invalid in play (the voxel column ahead is read).
var seat_probe: Callable = Callable()

## Client: peer id -> gesture id still to show, and what is already on the avatar (instance id + gesture).
var _remote_poses: Dictionary = {}
var _applied: Dictionary = {}
## Host: "viewer:subject" peer pairs already told about a held pose (the viewer had it in its AOI).
var _entered: Dictionary = {}

func _connect_all() -> void:
	connect_bus(GameBus.gesture_intent, _on_gesture_intent)
	connect_bus(GameBus.gesture_synced, _on_gesture_synced)
	connect_bus(GameBus.peer_gesture_synced, _on_peer_gesture_synced)
	connect_bus(GameBus.peer_equipment_evicted, _on_peer_evicted)
	connect_bus(GameBus.remote_player_state, _on_remote_state)
	connect_bus(GameBus.player_damaged, _on_player_damaged)
	connect_bus(GameBus.player_died, _on_local_died)
	connect_bus(GameBus.player_left, _on_player_left)
	connect_bus(GameBus.player_joined, _on_player_joined)

# ---------------------------------------------------------------------------
# Host: validate, cancel, broadcast
# ---------------------------------------------------------------------------

func _local_id() -> String:
	return root._registry.local_player_id if not root._registry.local_player_id.is_empty() else "player"

func _is_local(player_id: String) -> bool:
	return player_id == "" or player_id == "player" or player_id == root._registry.local_player_id

## Wire peer id of a player (the host's own body is peer 1; 0 for an unknown player).
func _peer_of(player_id: String) -> int:
	return 1 if _is_local(player_id) else root._registry.get_peer_id(player_id)

func _position_of(player_id: String) -> Variant:
	if _is_local(player_id):
		return root._player.get_position()
	var peer := root._registry.get_peer_id(player_id)
	if peer != 0 and root._networking.has_last_known_state(peer):
		return root._networking.get_last_known_state(peer)
	return null

func _alive(player_id: String) -> bool:
	if _is_local(player_id):
		return root._player == null or root._player.get_hp() > 0.0
	return not PlayerRegistry.is_downed(root._registry.get_hp(player_id))

func _on_gesture_intent(gesture_id: String, player_id: String) -> void:
	if root._is_client or root._gesture == null:
		return   # a client's own intent is forwarded by the networking slice
	var pid := _local_id() if _is_local(player_id) else player_id
	var pos: Variant = _position_of(pid)
	if pos == null:
		return   # a peer that never reported has no evidence to validate against
	var grounded: bool = root._player.is_grounded() if _is_local(pid) else true
	root._gesture.request(pid, gesture_id, _alive(pid), grounded, pos)

## The slice accepted a start or a cancel: show it here and tell the peers in range.
func _on_gesture_synced(player_id: String, gesture_id: String) -> void:
	if root._is_client:
		return
	var peer := _peer_of(player_id)
	if peer == 0:
		return
	if peer == 1:
		play(root._character.get_player_character(), gesture_id)
	if root._networking != null and root._networking.is_host():
		var at: Variant = _position_of(player_id if peer != 1 else _local_id())
		if at != null:
			root._networking.send_gesture(peer, gesture_id, at)

func _on_remote_state(peer_id: int, position: Vector3) -> void:
	if root._is_client or root._gesture == null:
		return
	var pid: String = root._registry.get_player_id(peer_id)
	if pid != "" and root._is_plausible_position(position):
		root._gesture.note_position(pid, position)

func _on_player_damaged(_damage: float, _attacker_id: String, target_id: String) -> void:
	if root._is_client or root._gesture == null:
		return
	var pid := _local_id() if _is_local(target_id) else target_id
	root._gesture.note_damage(pid)
	if not _alive(pid):
		root._gesture.note_death(pid)

func _on_local_died(_position: Vector3, _killer_id: String, _landing: Vector3) -> void:
	if not root._is_client and root._gesture != null:
		root._gesture.note_death(_local_id())

func _on_player_left(player_id: String) -> void:
	if root._gesture != null:
		root._gesture.forget(player_id)

## A late joiner learns the poses held inside its AOI (a sitting player stays seated for it).
func _on_player_joined(peer_id: int, _player_id: String, _reconnected: bool) -> void:
	if root._is_client or root._gesture == null or root._networking == null:
		return
	var poses := {}
	var held: Dictionary = root._gesture.held_poses()
	for pid in held:
		var peer := _peer_of(str(pid))
		if peer != 0:
			poses[peer] = held[pid]
	if not poses.is_empty():
		root._networking.send_peer_gestures_to(peer_id, poses)

func tick(delta: float) -> void:
	if root._gesture == null:
		return
	if root._is_client:
		_apply_pending()
		return
	var local := _local_id()
	if root._player != null:
		root._gesture.note_position(local, root._player.get_position())
	_replay_to_entrants()
	# restRegen: a held rest pose regains HP at the base rate times its multiplier (host-resolved).
	for pid in root._gesture.held_poses():
		var mult: float = root._gesture.regen_multiplier(str(pid))
		if mult > 1.0:
			_regen(str(pid), GestureRules.regen_amount(mult, delta))

## A viewer that walks into range of a player who already holds a pose is told it once (the join handler
## covers late joiners; this covers everyone else). A pair that leaves range is forgotten, so re-entry replays.
func _replay_to_entrants() -> void:
	var net: Variant = root._networking
	if net == null or not net.is_host():
		return
	var held: Dictionary = root._gesture.held_poses()
	var visible := {}   # "viewer:subject" -> { viewer, subject, pose }
	for pid in held:
		var subject := _peer_of(str(pid))
		var at: Variant = _position_of(str(pid))
		if subject == 0 or at == null:
			continue
		for viewer in net._connected_peers():
			var v := int(viewer)
			if v != subject and net.has_last_known_state(v) and net.in_aoi(v, at):
				visible["%d:%d" % [v, subject]] = { "viewer": v, "subject": subject, "pose": held[pid] }
	for key in GestureRules.new_pairs(visible, _entered):
		net.send_peer_gestures_to(visible[key]["viewer"], { visible[key]["subject"]: visible[key]["pose"] })
	_entered = visible

func _regen(player_id: String, amount: float) -> void:
	if _is_local(player_id):
		var own: float = root._player.get_hp()
		if own > 0.0 and own < PlayerSlice.MAX_HP:
			root._player.set_hp(minf(own + amount, PlayerSlice.MAX_HP))
		return
	var hp: float = root._registry.get_hp(player_id)
	if hp >= 0.0 and not PlayerRegistry.is_downed(hp) and hp < PlayerSlice.MAX_HP:
		root._registry.record_simulated_hp(player_id, minf(hp + amount, PlayerSlice.MAX_HP))

# ---------------------------------------------------------------------------
# Client: pose the avatars
# ---------------------------------------------------------------------------

func _on_peer_gesture_synced(peer_id: int, gesture_id: String) -> void:
	if not root._is_client:
		return
	var own: int = root.multiplayer.get_unique_id() if root.is_inside_tree() else 0
	if peer_id == own:
		play(root._character.get_player_character(), gesture_id)
		return
	if gesture_id == "":
		_remote_poses.erase(peer_id)
		_applied.erase(peer_id)
		play(root._character.get_peer_character(peer_id), "")
		return
	_remote_poses[peer_id] = gesture_id
	_apply_pending()

func _on_peer_evicted(peer_id: int) -> void:
	_remote_poses.erase(peer_id)
	_applied.erase(peer_id)

## Show every waiting pose whose avatar exists now and does not already wear it.
func _apply_pending() -> void:
	for peer in _remote_poses.keys():
		var iid: String = root._character.get_peer_character(int(peer))
		if iid == "":
			continue
		var stamp := "%s|%s" % [iid, _remote_poses[peer]]
		if _applied.get(peer, "") != stamp:
			_applied[peer] = stamp
			play(iid, str(_remote_poses[peer]))

# ---------------------------------------------------------------------------
# Rig
# ---------------------------------------------------------------------------

## Play (or, for "", end) `gesture_id` on avatar `iid`. A `Sit` with no seat in front sits on the ground.
## Returns the gesture id that was played ("" for a stand-up or an unknown avatar/gesture).
func play(iid: String, gesture_id: String, table: Dictionary = GameData.GESTURES) -> String:
	if iid == "":
		return ""
	if gesture_id == "":
		root._character._m2.end_gesture(iid)
		return ""
	var lift := -1.0
	if gesture_id == SEAT_GESTURE:
		lift = _seat_lift(iid)
		if lift < 0.0 and table.has(GROUND_SIT):
			gesture_id = GROUND_SIT
	var res: Resource = GestureRules.find(gesture_id, table)
	if res == null:
		return ""
	var ok: bool = root._character._m2.trigger_gesture(iid, GestureRules.clip_of(res), GestureRules.is_pose(res), maxf(lift, 0.0))
	return gesture_id if ok else ""

## The rise of a seat in front of avatar `iid` (a block edge), or -1 when there is none.
func _seat_lift(iid: String) -> float:
	if seat_probe.is_valid():
		return float(seat_probe.call(iid))
	var at: Variant = root._character.get_character_position(iid)
	var node: Variant = root._character._instances.get(iid, {}).get("root")
	if not (at is Vector3) or not (node is Node3D) or root._voxel == null:
		return -1.0
	var forward: Vector3 = -(node as Node3D).global_transform.basis.z if (node as Node3D).is_inside_tree() else Vector3(0.0, 0.0, -1.0)
	var ahead := Vector2((at as Vector3).x + forward.x * SEAT_REACH_M, (at as Vector3).z + forward.z * SEAT_REACH_M)
	return GestureRules.seat_lift((at as Vector3).y, root._voxel.get_voxel_height_at(ahead))
