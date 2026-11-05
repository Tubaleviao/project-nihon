extends "res://src/core/wiring.gd"
## Mount wiring (Phase 216) — gives the mount slice its facts from the creature population and the player
## registry, answers a rider with their result, tells other peers who rides what, and lifts the host's speed
## cap for a mounted player to the mount's factor times the walking speed.

const MountSlice := preload("res://src/creature/mount_slice.gd")
const AdminRules := preload("res://src/admin/admin_rules.gd")
const PlayerRegistry := preload("res://src/persistence/player_registry.gd")
const PlayerSlice := preload("res://src/player/player_slice.gd")
## Slack over the exact mounted speed, as for a carried body (`CarcassWiring.CARRY_SPEED_SLACK`).
const SPEED_SLACK := 1.25

## The host's mount slice, built by `make_slice`.
var slice: Node = null

func make_slice(ctx: GameRoot) -> Node:
	root = ctx
	var m := MountSlice.new()
	slice = m
	m.is_host = not root._is_client
	m.creature_of = func(iid: String) -> String: return root._creature.get_instance_creature_id(iid)
	m.owner_of = func(iid: String) -> String: return root._creature.get_tamed_by(iid)
	m.alive = func(iid: String) -> bool: return not root._taming._instance_is_dead(iid)
	m.rider_downed = func(pid: String) -> bool: return PlayerRegistry.is_downed(root._registry.get_hp(pid))
	m.position_of = func(iid: String) -> Variant: return root._creature.get_instance_position(iid)
	m.player_pos = _player_position
	m.local_body = root._player
	m.input_allowed = func() -> bool: return root._player != null and root._player.world_input_allowed()
	m.nearest_to = func(at: Vector3, within: float) -> String: return str(root._creature.nearest_tamed_by(at, within, str(root._registry.local_player_id)))
	m.own_position = func() -> Vector3: return root._player.get_position()
	m.local_player_id = func() -> String: return str(root._registry.local_player_id)
	return m

func _player_position(player_id: String) -> Variant:
	if player_id == str(root._registry.local_player_id):
		return root._player.get_position() if root._player != null else null
	var peer: int = root._registry.get_peer_id(player_id)
	if peer != 0 and root._networking.has_last_known_state(peer):
		return root._networking.get_last_known_state(peer)
	return null

func _connect_all() -> void:
	connect_bus(GameBus.mount_resolved, _on_resolved)
	connect_bus(GameBus.mount_changed, _on_changed)
	connect_bus(GameBus.mount_intent, _forward_mount)
	connect_bus(GameBus.dismount_intent, _forward_dismount)

## Client → host: ride one of my companions, or get off. No identity rides along; the host binds it.
func _forward_mount(instance_id: String, _player_id: String) -> void:
	if root._is_client:
		root._networking._broadcast({ "type": "mount_intent", "instance_id": instance_id })

func _forward_dismount(_player_id: String) -> void:
	if root._is_client:
		root._networking._broadcast({ "type": "dismount_intent" })

## Host: answer the rider who asked.
func _on_resolved(player_id: String, action: String, ok: bool, reason: String) -> void:
	if not root._is_client and player_id != "":
		GameBus.system_message.emit(("mount.ok." + action) if ok else ("mount.refused." + reason), [], player_id)
	if root._is_client or player_id == "" or player_id == str(root._registry.local_player_id):
		return
	var peer: int = root._registry.get_peer_id(player_id)
	if peer != 0:
		root._networking.send_own_state(peer, { "mount_result": { "action": action.left(16), "ok": ok, "reason": reason.left(32) } })

## Host: every peer learns who rides what (the rider's handle is the public one the wire already uses).
func _on_changed(player_id: String, instance_id: String) -> void:
	if root._is_client or root._networking == null:
		return
	root._networking._broadcast({ "type": "mount_changed", "player": root._networking.redact_for_client(player_id), "instance_id": instance_id })

## The fastest horizontal speed (m/s) `peer` may move at while mounted; 0 when it is on foot (no mount cap).
func mounted_speed_cap(peer: int) -> float:
	if root._is_client or slice == null or root._networking == null:
		return 0.0
	var pid: String = root._networking.get_player_id(peer)
	if pid == "" or not slice.is_mounted(pid):
		return 0.0
	var rate: float = slice.accepted_speed(pid, PlayerSlice.SPEED * root._registry.stat_of(pid, "moveSpeedFactor")) * SPEED_SLACK
	# The admin moves the host set for the player (`/speed`, `/fly`) apply on a mount as on foot.
	if root._chat != null:
		var moves: Dictionary = root._chat.admin_moves_of(pid)
		rate *= float(moves["speed"]) * (AdminRules.FLY_SPEED_FACTOR if bool(moves["fly"]) else 1.0)
	return rate

## The host's speed cap for `peer`: the mount's when mounted, else the carried body's.
func peer_speed_cap(peer: int) -> float:
	var mounted := mounted_speed_cap(peer)
	return mounted if mounted > 0.0 else root._carcass_wiring.peer_speed_cap(peer)

## The companion follows its rider's exact position (Phase 171 `{chunk, local}`) every frame.
func tick(_delta: float) -> void:
	if root._is_client or slice == null:
		return
	slice.validate_riders()
	for pid: String in slice.riders():
		var iid: String = slice.mounted_instance(pid)
		var exact: Dictionary = {}
		if pid == str(root._registry.local_player_id):
			exact = root._player.get_world_pos() if root._player != null else {}
		else:
			var peer: int = root._registry.get_peer_id(pid)
			exact = root._networking.get_last_known_exact(peer) if peer != 0 else {}
		if not exact.is_empty():
			root._creature.set_instance_pos(iid, exact)
