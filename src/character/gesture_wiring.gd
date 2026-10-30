extends "res://src/core/wiring.gd"
## Gesture wiring (Phase 159) — sit, lie down, wave and friends.
##
## Host / offline: `gesture_intent` (the local player's, or a peer's bound to its connection) is validated
## by `GestureSlice`, the accepted start or cancel (`gesture_synced`) is played on the host's own avatar
## and sent to the peers whose AOI holds the player. The host also watches movement, damage and death to
## cancel, and applies `restRegen` while a pose is held. Client: `peer_gesture_synced` plays the pose on the
## avatar of the peer it names (this machine's own body included); a pose for an avatar not built yet waits.
## Phase 196: the host decides Sit versus SitGround (and the seat lift) once and syncs it; a listen host also
## poses its own view of a remote player; a resting peer's heal reaches its client.

const GestureRules := preload("res://src/character/gesture_rules.gd")
const PlayerRegistry := preload("res://src/persistence/player_registry.gd")
const PlayerSlice := preload("res://src/player/player_slice.gd")

## Gesture the sit falls back to when no seat is in front of the body.
const GROUND_SIT := "SitGround"
const SEAT_GESTURE := "Sit"
## How far above the terrain under it a peer's reported position may be and still count as standing.
const GROUNDED_TOLERANCE_M := 0.6
## How far ahead of the body a seat is looked for.
const SEAT_REACH_M := 0.6

## `(iid) -> float` seat lift override for the suite; invalid in play (the voxel column ahead is read).
var seat_probe: Callable = Callable()

## Peer id -> gesture id still to show on that peer's avatar, its host-resolved lift, and what is already on
## the avatar (instance id + gesture). On a client, and (Phase 196) on a listen host for its remote players.
var _remote_poses: Dictionary = {}
var _remote_lifts: Dictionary = {}
var _applied: Dictionary = {}
## Host: "viewer:subject" peer pairs in range at the last replay pass.
var _entered: Dictionary = {}
## Host (Phase 196): "viewer:subject" -> the pose that viewer was last told the subject holds; kept while the
## pair is out of range, so a pose that ended meanwhile is sent as "" on re-entry. Erased with either peer.
var _told: Dictionary = {}
## Host: the replay pass runs at most every REPLAY_INTERVAL seconds, not every frame.
const REPLAY_INTERVAL := 0.25
var _replay_clock: float = 0.0
## Host (Phase 196): player id -> msec of the last refusal notice; one notice a second at most.
const REFUSAL_NOTICE_MS := 1000
var _last_notice: Dictionary = {}
## Regen owed per player, applied once a second: each HP write broadcasts the body's state to peers.
var _regen_owed: Dictionary = {}
const REGEN_APPLY_INTERVAL := 1.0
var _regen_clock: float = 0.0

func _connect_all() -> void:
	connect_bus(GameBus.gesture_intent, _on_gesture_intent)
	connect_bus(GameBus.gesture_synced, _on_gesture_synced)
	connect_bus(GameBus.peer_gesture_synced, _on_peer_gesture_synced)
	connect_bus(GameBus.peer_equipment_evicted, _on_peer_evicted)
	connect_bus(GameBus.remote_player_state, _on_remote_state)
	connect_bus(GameBus.player_damaged, _on_player_damaged)
	connect_bus(GameBus.player_died, _on_local_died)
	connect_bus(GameBus.combat_hit_resolved, _on_combat_hit)
	connect_bus(GameBus.block_mine_requested, _on_mine_requested)
	connect_bus(GameBus.player_left, _on_player_left)
	connect_bus(GameBus.player_joined, _on_player_joined)
	connect_bus(GameBus.peer_disconnected, _forget_peer)
	connect_bus(GameBus.player_rest_healed, _on_rest_healed)

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
		return root._player.get_position() if root._player != null else null
	var peer := root._registry.get_peer_id(player_id)
	if peer != 0 and root._networking.has_last_known_state(peer):
		return root._networking.get_last_known_state(peer)
	return null

## Whether a peer's last reported position stands on the ground: the host reads the terrain itself rather
## than taking the client's word. Without a voxel world (no evidence to refute it) the peer counts as grounded.
func _peer_grounded(pos: Vector3) -> bool:
	if root._voxel == null:
		return true
	var support: float = root._voxel.sample_support_height_at(Vector2(pos.x, pos.z), pos.y)
	return pos.y - support <= GROUNDED_TOLERANCE_M

func _alive(player_id: String) -> bool:
	if _is_local(player_id):
		return root._player == null or root._player.get_hp() > 0.0
	return not PlayerRegistry.is_downed(root._registry.get_hp(player_id))

func _on_gesture_intent(gesture_id: String, player_id: String) -> void:
	if root._is_client or root._gesture == null:
		return   # a client's own intent is forwarded by the networking slice
	var pid := _local_id() if _is_local(player_id) else player_id
	if gesture_id == "":
		root._gesture.cancel(pid)   # standing up needs no evidence: a player may always end their own pose
		return
	var pos: Variant = _position_of(pid)
	if pos == null:
		return   # a peer that never reported has no evidence to validate against
	var grounded: bool = root._player.is_grounded() if _is_local(pid) else _peer_grounded(pos)
	# Phase 196 — the host decides Sit versus SitGround once, from its own probe, and the lift travels with it.
	var lift := -1.0
	if gesture_id == SEAT_GESTURE:
		lift = _host_seat_lift(pid, pos)
		if lift < 0.0 and GameData.GESTURES.has(GROUND_SIT):
			gesture_id = GROUND_SIT
	var why: String = root._gesture.request(pid, gesture_id, _alive(pid), grounded, pos, lift)
	if why != "":
		_notify_refusal(pid, why)

## Phase 196 — a refused gesture tells its player why (a keyed line), at most once a second per player.
func _notify_refusal(player_id: String, why: String) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_last_notice.get(player_id, -REFUSAL_NOTICE_MS)) < REFUSAL_NOTICE_MS:
		return
	_last_notice[player_id] = now
	GameBus.system_message.emit("hud.gesture.refused." + why, [], player_id)

## The seat rise in front of `player_id` by the host's own probe: their avatar when this host draws one,
## else their reported position facing -Z (a dedicated server has no avatars). -1 when there is no seat.
func _host_seat_lift(player_id: String, pos: Vector3) -> float:
	var iid := ""
	if root._character != null:
		iid = root._character.get_player_character() if _is_local(player_id) else root._character.get_peer_character(_peer_of(player_id))
	if iid != "" or seat_probe.is_valid():
		return _seat_lift(iid)
	return _probe_seat(pos, Vector3(0.0, 0.0, -1.0))

## The slice accepted a start or a cancel: show it here and tell the peers in range.
func _on_gesture_synced(player_id: String, gesture_id: String) -> void:
	if root._is_client:
		return
	var peer := _peer_of(player_id)
	if peer == 0:
		return
	var lift: float = root._gesture.lift_of(player_id) if gesture_id != "" and root._gesture != null else -1.0
	if peer == 1:
		_play_own(gesture_id, lift)
	elif root._character != null:
		_show_remote(peer, gesture_id, lift)   # Phase 196 — the listen host's own view of that player
	if root._networking != null and root._networking.is_host():
		var at: Variant = _position_of(player_id if peer != 1 else _local_id())
		if at != null:
			root._networking.send_gesture(peer, gesture_id, at, lift)
			# The broadcast above already told everyone in range: the entrant replay must not repeat it.
			for key in _visible_pairs(peer, at):
				_entered[key] = true
				if gesture_id != "" and GestureRules.is_pose(GestureRules.find(gesture_id, GameData.GESTURES)):
					_told[key] = gesture_id
				else:
					_told.erase(key)

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

## A swing takes the body out of its pose (the attack clip would stand it up on the rig otherwise).
func _on_combat_hit(attacker_id: String, _defender_id: String, _outcome: String, _damage: float) -> void:
	_note_action(attacker_id)

func _on_mine_requested(_position: Vector3, _normal: Vector3, player_id: String, _exact: Dictionary) -> void:
	_note_action(player_id)

func _note_action(player_id: String) -> void:
	if root._is_client or root._gesture == null:
		return
	root._gesture.note_action(_local_id() if _is_local(player_id) else player_id)

func _on_local_died(_position: Vector3, _killer_id: String, _landing: Vector3) -> void:
	if not root._is_client and root._gesture != null:
		root._gesture.note_death(_local_id())

func _on_player_left(player_id: String) -> void:
	_last_notice.erase(player_id)
	if root._gesture != null:
		root._gesture.forget(player_id)

## A late joiner learns the poses held inside its AOI (a sitting player stays seated for it).
func _on_player_joined(peer_id: int, _player_id: String, _reconnected: bool) -> void:
	if root._is_client or root._gesture == null or root._networking == null:
		return
	var poses := {}
	var lifts := {}
	var held: Dictionary = root._gesture.held_poses()
	for pid in held:
		var peer := _peer_of(str(pid))
		if peer != 0 and peer != peer_id:
			poses[peer] = held[pid]
			lifts[peer] = root._gesture.lift_of(str(pid))
			_told["%d:%d" % [peer_id, peer]] = held[pid]
	if not poses.is_empty():
		root._networking.send_peer_gestures_to(peer_id, poses, lifts)

func tick(delta: float) -> void:
	if root._gesture == null:
		return
	if root._character != null:
		_apply_pending()
		_advance_remote_avatars(delta)
	if root._is_client:
		return
	var local := _local_id()
	if root._player != null:
		root._gesture.note_position(local, root._player.get_position())
	_replay_clock += delta
	if _replay_clock >= REPLAY_INTERVAL:
		_replay_clock = 0.0
		_replay_to_entrants()
	# restRegen: a held rest pose regains HP at the base rate times its multiplier (host-resolved).
	var held: Dictionary = root._gesture.held_poses()
	for pid in _regen_owed.keys():
		if not held.has(pid):
			_regen_owed.erase(pid)
	for pid in held:
		var mult: float = root._gesture.regen_multiplier(str(pid))
		if mult > 1.0:
			# Phase 178 — Vitality sets the base rate and the pose bonus (host-resolved from the record).
			var rid: String = _local_id() if _is_local(str(pid)) else str(pid)
			mult = maxf(mult * root._registry.stat_of(rid, "restRegenFactor"), 1.0)
			_regen_owed[pid] = float(_regen_owed.get(pid, 0.0)) + GestureRules.regen_amount(mult, delta, root._registry.stat_of(rid, "hpRegenPerSecond"))
	_regen_clock += delta
	if _regen_clock >= REGEN_APPLY_INTERVAL:
		_regen_clock = 0.0
		for pid in _regen_owed:
			_regen(str(pid), float(_regen_owed[pid]))
		_regen_owed.clear()

## A viewer that walks into range of a player who already holds a pose is told it once (the join handler
## covers late joiners; this covers everyone else). A pair that leaves range is forgotten, so re-entry replays.
## Phase 196: a viewer told a pose that ended while it was out of range is told "" when it comes back.
func _replay_to_entrants() -> void:
	var net: Variant = root._networking
	if net == null or not net.is_host():
		return
	var held: Dictionary = root._gesture.held_poses()
	var subjects := {}   # subject peer -> player id, for every held pose and every pose someone still believes
	for pid in held:
		var subject := _peer_of(str(pid))
		if subject != 0:
			subjects[subject] = str(pid)
	for key in _told:
		var subject := int(str(key).get_slice(":", 1))
		if not subjects.has(subject):
			subjects[subject] = _local_id() if subject == 1 else str(root._registry.get_player_id(subject))
	var visible := {}   # "viewer:subject" -> { viewer, subject, pose, lift }
	for subject in subjects:
		var pid: String = subjects[subject]
		var at: Variant = _position_of(pid) if pid != "" else null
		if at == null:
			continue
		var pairs := _visible_pairs(subject, at)
		for key in pairs:
			visible[key] = { "viewer": pairs[key], "subject": subject, "pose": str(held.get(pid, "")),
				"lift": root._gesture.lift_of(pid) }
	for key in GestureRules.new_pairs(visible, _entered):
		var v: Dictionary = visible[key]
		# A held pose is replayed on every re-entry (the viewer may have dropped the avatar meanwhile); a stand-up
		# only to a viewer still believing in a pose.
		if v["pose"] == "" and str(_told.get(key, "")) == "":
			continue
		net.send_peer_gestures_to(v["viewer"], { v["subject"]: v["pose"] }, { v["subject"]: v["lift"] })
		if v["pose"] == "":
			_told.erase(key)
		else:
			_told[key] = v["pose"]
	_entered = visible

## "viewer:subject" -> viewer peer for every connected peer (but the subject) whose AOI holds `at`.
func _visible_pairs(subject: int, at: Vector3) -> Dictionary:
	var out := {}
	var net: Variant = root._networking
	if net == null or not net.is_host():
		return out
	for viewer in net.connected_peers():
		var v := int(viewer)
		if v != subject and net.has_last_known_state(v) and net.in_aoi(v, at):
			out["%d:%d" % [v, subject]] = v
	return out

func _regen(player_id: String, amount: float) -> void:
	if _is_local(player_id):
		var own: float = root._player.get_hp()
		if own > 0.0 and own < root._player.max_hp:
			root._player.set_hp(minf(own + amount, root._player.max_hp))
		return
	var hp: float = root._registry.get_hp(player_id)
	var ceiling: float = root._registry.max_hp_of(player_id)
	if hp >= 0.0 and not PlayerRegistry.is_downed(hp) and hp < ceiling:
		var healed := minf(hp + amount, ceiling)
		root._registry.record_simulated_hp(player_id, healed)
		# Phase 196 — the peer's client owns its HP: the heal is sent to it, not only kept in the host's mirror.
		var peer: int = root._registry.get_peer_id(player_id)
		if peer > 0 and root._networking != null and root._networking.is_host():
			root._networking.send_player_healed(peer, healed - hp)

## Client: the host healed our resting body (restRegen); the local body owns its HP.
func _on_rest_healed(amount: float) -> void:
	if not root._is_client or root._player == null:
		return
	var own: float = root._player.get_hp()
	if own > 0.0 and own < root._player.max_hp:
		root._player.set_hp(minf(own + amount, root._player.max_hp))

# ---------------------------------------------------------------------------
# Client: pose the avatars
# ---------------------------------------------------------------------------

func _on_peer_gesture_synced(peer_id: int, gesture_id: String, lift: float) -> void:
	if not root._is_client:
		return
	var own: int = root.multiplayer.get_unique_id() if root.is_inside_tree() else 0
	if peer_id == own:
		_play_own(gesture_id, lift)
		return
	_show_remote(peer_id, gesture_id, lift)

## This machine's own body plays (or ends) a gesture; the player slice learns whether a pose is held.
func _play_own(gesture_id: String, lift: float) -> void:
	var played := play(root._character.get_player_character(), gesture_id, GameData.GESTURES, lift)
	if root._player != null:
		root._player.in_pose = played != "" and GestureRules.is_pose(GestureRules.find(played, GameData.GESTURES))

## Show `gesture_id` on peer `peer_id`'s avatar here (a client's, or the listen host's view of a client).
func _show_remote(peer_id: int, gesture_id: String, lift: float) -> void:
	if gesture_id == "":
		_forget_pose(peer_id)
		play(root._character.get_peer_character(peer_id), "")
		return
	var res: Resource = GestureRules.find(gesture_id, GameData.GESTURES)
	if res != null and not GestureRules.is_pose(res):
		# A one-shot is played now, every time it arrives (a repeated wave restarts the clip); it is not kept
		# for an avatar that does not exist yet, and a pose it replaces is gone.
		_forget_pose(peer_id)
		play(root._character.get_peer_character(peer_id), gesture_id)
		return
	_remote_poses[peer_id] = gesture_id
	_remote_lifts[peer_id] = lift
	_apply_pending()

func _forget_pose(peer_id: int) -> void:
	_remote_poses.erase(peer_id)
	_remote_lifts.erase(peer_id)
	_applied.erase(peer_id)

func _on_peer_evicted(peer_id: int) -> void:
	_forget_pose(peer_id)

## Phase 196 — a peer left (or its id is about to be reused): its avatar's pose and every replay pair naming it go.
func _forget_peer(peer_id: int) -> void:
	_forget_pose(peer_id)
	var tag := str(peer_id)
	for key in _told.keys():
		if str(key).get_slice(":", 0) == tag or str(key).get_slice(":", 1) == tag:
			_told.erase(key)
	for key in _entered.keys():
		if str(key).get_slice(":", 0) == tag or str(key).get_slice(":", 1) == tag:
			_entered.erase(key)

## Show every waiting pose whose avatar exists now and does not already wear it.
func _apply_pending() -> void:
	for peer in _remote_poses.keys():
		var iid: String = root._character.get_peer_character(int(peer))
		if iid == "":
			continue
		var stamp := "%s|%s" % [iid, _remote_poses[peer]]
		if _applied.get(peer, "") != stamp:
			_applied[peer] = stamp
			play(iid, str(_remote_poses[peer]), GameData.GESTURES, float(_remote_lifts.get(peer, -1.0)))

## Remote avatars are placed by their position reports only, so a gesturing one is stepped here: its
## one-shot timer runs out and the rig tree follows the state.
func _advance_remote_avatars(delta: float) -> void:
	for iid in root._character.peer_character_ids():
		root._character.advance_gesture(str(iid), delta)

# ---------------------------------------------------------------------------
# Rig
# ---------------------------------------------------------------------------

## Play (or, for "", end) `gesture_id` on avatar `iid`. A `Sit` takes the host-resolved `lift`; without one
## (-1) the seat in front is probed here, and with no seat it sits on the ground.
## Returns the gesture id that was played ("" for a stand-up or an unknown avatar/gesture).
func play(iid: String, gesture_id: String, table: Dictionary = GameData.GESTURES, lift: float = -1.0) -> String:
	if iid == "":
		return ""
	if gesture_id == "":
		root._character.end_gesture(iid)
		return ""
	if gesture_id == SEAT_GESTURE:
		if lift < 0.0:
			lift = _seat_lift(iid)
		if lift < 0.0 and table.has(GROUND_SIT):
			gesture_id = GROUND_SIT
	else:
		lift = -1.0
	var res: Resource = GestureRules.find(gesture_id, table)
	if res == null:
		return ""
	var ok: bool = root._character.trigger_gesture(iid, GestureRules.clip_of(res), GestureRules.is_pose(res), maxf(lift, 0.0))
	return gesture_id if ok else ""

## The rise of a seat in front of avatar `iid` (a block edge), or -1 when there is none.
func _seat_lift(iid: String) -> float:
	if seat_probe.is_valid():
		return float(seat_probe.call(iid))
	var at: Variant = root._character.get_character_position(iid)
	if not (at is Vector3):
		return -1.0
	return _probe_seat(at, root._character.character_forward(iid))

## The seat rise SEAT_REACH_M ahead of feet at `at` facing `forward`, from the support surface (Phase 196:
## `sample_support_height_at`, so an overhang above the seat is not taken for its top), or -1.
func _probe_seat(at: Vector3, forward: Vector3) -> float:
	if root._voxel == null:
		return -1.0
	var ahead := Vector2(at.x + forward.x * SEAT_REACH_M, at.z + forward.z * SEAT_REACH_M)
	var top: float = root._voxel.sample_support_height_at(ahead, at.y + GestureRules.SEAT_MAX_RISE + 0.05)
	return GestureRules.seat_lift(at.y, top)
