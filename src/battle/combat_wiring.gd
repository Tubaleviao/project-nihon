extends "res://src/core/wiring.gd"
## Combat wiring (Phase 132) — Combat, creature events and status effects.
## Moved out of game_root.gd; `root` is the GameRoot that owns the slices.

const DeathPush := preload("res://src/battle/death_push.gd")
const WorldPos := preload("res://src/terrain/world_pos.gd")
const TerrainSlice     := preload("res://src/terrain/terrain_slice.gd")
const BattleSlice      := preload("res://src/battle/battle_slice.gd")
const CreatureAI       := preload("res://src/creature/creature_ai.gd")
const PlayerRegistry   := preload("res://src/persistence/player_registry.gd")
const PlayerSlice      := preload("res://src/player/player_slice.gd")
const StatusEffects    := preload("res://src/battle/status_effects.gd")
const RigTree          := preload("res://src/character/rig_tree.gd")

func _connect_all() -> void:
	if root._battle != null:
		root._battle.player_stat_fn = player_stat   # Phase 178 — a defending player's attribute stats
	if root._creature != null:
		root._creature.player_points = local_body_points   # Phase 192 — creature models squash against the player
	connect_bus(GameBus.knockback_requested, _on_knockback_requested)
	connect_bus(GameBus.player_died, _on_status_player_died)
	connect_bus(GameBus.combat_hit_resolved, _on_combat_hit_resolved)
	connect_bus(GameBus.combat_hit_synced, _on_combat_hit_synced)
	connect_bus(GameBus.player_damaged, _on_local_player_damaged)
	connect_bus(GameBus.block_mine_requested, _on_mine_swing)
	connect_bus(GameBus.player_damaged, on_player_damaged)
	connect_bus(GameBus.player_died, _on_player_died)
	connect_bus(GameBus.player_respawned, _on_player_respawned)

## Phase 192 — the local player's feet in scene coordinates (none before the body exists).
func local_body_points() -> Array:
	return [root._player.get_scene_position()] if root._player != null else []

## Phase 156 — one swing resolved on the host (a miss too): animate the attacker and the target here and
## tell the clients in range. Ids become wire keys first, so both sides run the same animation path.
func _on_combat_hit_resolved(attacker_id: String, defender_id: String, outcome: String, _damage: float) -> void:
	if root._is_client:
		return
	var a_key := _wire_key(attacker_id)
	var d_key := _wire_key(defender_id)
	_animate_hit(a_key, d_key, outcome)
	# Only a hosting machine has clients to tell; offline, the send would just warn on every swing.
	if root._networking != null and root._networking.is_host():
		var at: Variant = _event_position(a_key, d_key)
		if at != null:   # no resolvable position: an AOI broadcast around the origin would be wrong
			root._networking.send_combat_hit(a_key, d_key, outcome, at)

## Client: the host's swing, animated on whatever bodies this client draws.
func _on_combat_hit_synced(attacker_key: String, defender_key: String, outcome: String) -> void:
	if root._is_client:
		_animate_hit(attacker_key, defender_key, outcome)

## The player's own mining swing (the tool swing), when the player strikes a block.
func _on_mine_swing(_position: Vector3, _normal: Vector3, player_id: String, _exact: Dictionary) -> void:
	if player_id != "" and player_id != "player":
		return
	var iid: String = root._character.get_player_character()
	if iid != "":
		root._character.trigger_attack(iid, RigTree.ATTACK_TOOL)

## "p:<peer id>" for a player body (the host's own is peer 1), "c:<id>" for a creature.
func _wire_key(id: String) -> String:
	if id == "player" or id == root._registry.local_player_id:
		return "p:1"
	if BattleSlice.is_player_target(id):
		return "p:%d" % root._registry.get_peer_id(id)
	return "c:" + id

## The character instance a wire key names on this machine ("" when it draws no avatar for it).
func _character_for_key(key: String) -> String:
	if not key.begins_with("p:"):
		return ""
	var peer := int(key.substr(2))
	var local_peer: int = root.multiplayer.get_unique_id() if root._is_client and root.is_inside_tree() else 1
	if peer == local_peer:
		return root._character.get_player_character()
	return root._character.get_peer_character(peer)

func _animate_hit(a_key: String, d_key: String, outcome: String) -> void:
	_swing(a_key)
	# The local body flinches on `player_damaged` (which also covers burns and the like), so a hit on it
	# is skipped here and nobody flinches twice.
	var is_local_body := d_key.begins_with("p:") and _character_for_key(d_key) == root._character.get_player_character()
	# A body killed by this blow (creature or player) goes to its death pose; a queued flinch would
	# replay on respawn.
	if outcome != "miss" and outcome != "kill" and not is_local_body:
		_flinch(d_key)

## The local body took damage, from any source: flinch.
func _on_local_player_damaged(_damage: float, _attacker_id: String, target_id: String) -> void:
	if target_id != "" and target_id != "player" and target_id != root._registry.local_player_id:
		return
	var iid: String = root._character.get_player_character()
	if iid != "":
		root._character.trigger_hit(iid)

func _swing(key: String) -> void:
	if key.begins_with("c:"):
		root._creature.trigger_attack_animation(key.substr(2))
		return
	var iid := _character_for_key(key)
	if iid != "":
		root._character.trigger_attack(iid)

func _flinch(key: String) -> void:
	if key.begins_with("c:"):
		root._creature.trigger_hit_animation(key.substr(2))
		return
	var iid := _character_for_key(key)
	if iid != "":
		root._character.trigger_hit(iid)

## Where a swing happened, for the packet's area of interest: the attacker's body, else the target's.
func _event_position(a_key: String, d_key: String) -> Variant:
	for key in [a_key, d_key]:
		if key.begins_with("c:"):
			var at: Vector3 = root._creature.get_instance_position(key.substr(2))
			if at != Vector3.ZERO:
				return at
		elif key.begins_with("p:"):
			var peer := int(key.substr(2))
			if peer == 1:
				return root._player.get_position()
			if root._networking.has_last_known_state(peer):
				return root._networking.get_last_known_state(peer)
	return null

## Phase 37/38 — a combat round landed on a player. The damage is applied by the machine
## that SIMULATES that body: the local body in-process (PlayerSlice listens to this
## signal itself), and a remote peer's body HERE, on the host.
##
## This is the other half of routing rounds by target id (CreatureAI emits the round
## against whoever the creature engaged): the host owns the authoritative simulation and
## therefore knows a creature struck a peer.
##
## Phase 38 — the host no longer takes the peer's word for the outcome. The Phase 37 pass
## forwarded the round and left the peer's HP to the peer's own client, which meant a
## client that simply ignored the packet was unkillable: the host had resolved the round
## itself and then discarded the only evidence it had, and the peer's health reset to
## whatever its client said on the next reconnect or restart. The host now applies the
## hit to its OWN simulation of that peer's health first (`record_simulated_hp`), which
## rides the peer's durable record, and THEN sends the round on as a display update. A
## client that drops it diverges from a truth it does not hold, instead of being the
## truth.
##
## The peer's DECLARED hp is still never believed — `_route_c2h` ignores the `hp` its
## `player_moved` packets carry, and `PlayerRegistry.record_hp` refuses a remote id. Only
## a number this process resolved itself is persisted (see
## `PlayerRegistry.simulated_hp_after_hit`).
##
## The local body is skipped: its damage is already applied in-process by PlayerSlice
## (this signal is emitted by BattleSlice, which PlayerSlice itself listens to), and
## there is no peer to send it to.
func on_player_damaged(damage: float, attacker_id: String, target_id: String) -> void:
	if root._is_client:
		return
	if target_id == "" or target_id == "player" or target_id == root._registry.local_player_id:
		return
	var peer := root._registry.get_peer_id(target_id)
	if peer == 0:
		return   # an offline or unknown target: nobody is simulating that body
	# The host's own resolution: a body it has never modelled starts at full health
	# (an unmodelled body has no evidence behind it, and the peer's word is not
	# evidence — see PlayerRegistry.simulated_hp_after_hit), then the hit lands on the
	# number this process holds.
	var was_downed := PlayerRegistry.is_downed(root._registry.get_hp(target_id))
	var simulated := PlayerRegistry.simulated_hp_after_hit(
		root._registry.get_hp(target_id), damage, root._registry.max_hp_of(target_id))
	root._registry.record_simulated_hp(target_id, simulated)
	root._networking.send_player_damaged(peer, damage, attacker_id)
	# Phase 157 — the killing blow throws a peer's body like any other: the host picks the spot, the
	# peer's client is teleported there.
	if PlayerRegistry.is_downed(simulated) and not was_downed and root._networking.has_last_known_state(peer):
		var pos: Vector3 = root._networking.get_last_known_state(peer)
		var landing := player_death_landing(attacker_id, pos, damage, root._registry.max_hp_of(target_id))
		if landing != Vector3.ZERO:
			root._networking.send_teleport(peer, WorldPos.from_world(landing.x, landing.y, landing.z))
	# Phase 129 — a downed body loses every effect.
	if root._status != null and PlayerRegistry.is_downed(simulated):
		root._status.clear(target_id)
		for t in root._status.take_dirty():
			push_status_effects(str(t), status_now())

## Phase 178 — a defending player's derived stat for BattleSlice: the local body ("player" or "") reads the
## host's own record, a peer its record by id. Neutral for a target nobody models.
func player_stat(target_id: String, stat_id: String) -> float:
	var pid: String = root._registry.local_player_id if (target_id == "" or target_id == "player") else target_id
	return root._registry.stat_of(pid, stat_id)

func status_now() -> float:
	return float(root.status_clock.call()) if root.status_clock.is_valid() else float(Time.get_ticks_msec()) / 1000.0

## The chunk a status target stands in: the local body, else the peer's recorded position.
func _status_chunk(target_id: String) -> Vector2i:
	if target_id == "player":
		return root._player.get_world_pos()["chunk"]
	return PlayerRegistry.world_pos_of(root._registry.get_record(target_id))["chunk"]

## Phase 129 — host: advance every effect. Damage over time goes through the same host path a creature
## hit takes (`player_damaged` → simulated peer HP), never a client's word; a burn under a weather
## state the table lists in `extinguishedBy` ends.
func tick_status_effects() -> void:
	if root._status == null or root._is_client:
		return
	var now := status_now()
	var weather_of := func(target_id: String) -> String:
		return root._weather.weather_at(_status_chunk(target_id), root._weather.current_hour())
	for ev in root._status.tick(now, weather_of):
		var target: String = ev["target_id"]
		if BattleSlice.is_player_target(target):
			GameBus.player_damaged.emit(float(ev["damage"]), "status:" + str(ev["effect"]), target)
	for target in root._status.take_dirty():
		push_status_effects(str(target), now)

## Send `target`'s effect list to that player ALONE and keep it on the record.
func push_status_effects(target: String, now: float) -> void:
	var effects := root._status.active(target, now)
	if target == "player":
		GameBus.status_effects_synced.emit("player", effects)
		root._registry.record_status_effects(root._registry.local_player_id, effects)
		return
	var peer := root._registry.get_peer_id(target)
	root._registry.record_status_effects(target, effects)
	if peer != 0 and root._networking != null:
		root._networking.send_status_effects(peer, effects)

## Write every live target's remaining time onto its record before a save reads it.
func refresh_status_records() -> void:
	if root._status == null or root._is_client:
		return
	var now := status_now()
	for target in root._status.targets():
		var pid: String = root._registry.local_player_id if target == "player" else str(target)
		if not pid.is_empty():
			root._registry.record_status_effects(pid, root._status.active(target, now))

## Restore a player's saved effects (a join or boot) and tell its body.
func restore_status_effects(target: String, player_id: String) -> void:
	if root._status == null or root._is_client:
		return
	var now := status_now()
	root._status.from_data(target, root._registry.get_status_effects(player_id), now)
	for t in root._status.take_dirty():
		push_status_effects(str(t), now)

func _on_status_player_died(_position: Vector3, _killer_id: String, _landing: Vector3) -> void:
	if root._status != null and not root._is_client:
		root._status.clear("player")
		for t in root._status.take_dirty():
			push_status_effects(str(t), status_now())

## Phase 157 — host: where an attacker stands, for the death push. A creature instance, or "player" (the
## host's own body, by either of its ids). Anything else (a remote peer) is the peer's last reported
## position when known. Null when nothing places the attacker (no player body on a dedicated server).
func death_attacker_pos(attacker_id: String) -> Variant:
	if attacker_id == "player" or (attacker_id != "" and attacker_id == root._registry.local_player_id):
		return root._player.get_position() if root._player != null else null
	for inst in root._creature.get_all_instances():
		if inst["instance_id"] == attacker_id:
			return inst["position"]
	var peer: int = root._registry.get_peer_id(attacker_id)
	if peer != 0 and root._networking.has_last_known_state(peer):
		return root._networking.get_last_known_state(peer)
	return null

## Phase 157 — host: the landing for a player killed by `killer_id` (ZERO on a client or with no push).
func player_death_landing(killer_id: String, pos: Vector3, damage: float, max_hp: float) -> Vector3:
	if root._is_client or killer_id == "":
		return Vector3.ZERO
	return root._battle.death_landing(pos, killer_id, damage, max_hp, root._battle.size_ratio(killer_id, max_hp))

## Phase 157 — a body may land on ground it can step onto (the knockback rule, shared with
## `_on_knockback_requested`).
func death_walkable(probe: Vector3) -> bool:
	return root._voxel.get_voxel_height_at(Vector2(probe.x, probe.z)) <= probe.y + root.KNOCKBACK_STEP_UP

func death_ground(spot: Vector3) -> float:
	return root._voxel.get_voxel_height_at(Vector2(spot.x, spot.z))

## Phase 129 — host: push `target_id` away from `attacker_id`, clamped to walkable ground.
func _on_knockback_requested(target_id: String, attacker_id: String, tiles: int) -> void:
	if root._is_client:
		return
	var src := Vector3.ZERO
	var found := false
	for inst in root._creature.get_all_instances():
		if inst["instance_id"] == attacker_id:
			src = inst["position"]
			found = true
			break
	if not found:
		return
	var peer := 0
	var pos: Vector3
	if target_id == "player":
		pos = root._player.get_position()
	else:
		peer = root._registry.get_peer_id(target_id)
		if peer == 0 or not root._networking.has_last_known_state(peer):
			return   # a peer that never reported has no position to push from (it reads as the origin)
		pos = root._networking.get_last_known_state(peer)
	var spot := StatusEffects.knockback_target(pos, src, tiles, TerrainSlice.TILE_SIZE, death_walkable)
	if spot == pos:
		return
	spot.y = maxf(spot.y, root._voxel.get_voxel_height_at(Vector2(spot.x, spot.z)))
	if peer == 0:
		root._player.spawn_at(spot)
	else:
		root._networking.send_teleport(peer, WorldPos.from_world(spot.x, spot.y, spot.z))

func _on_player_died(death_pos: Vector3, killer_id: String, landing: Vector3) -> void:
	# The host's death push is the body's authoritative position.
	if landing != Vector3.ZERO and root._player != null and not root._is_client:
		root._player.spawn_at(landing)
		root._player.sync_state_now()   # a dead body does not tick: peers would keep the pre-push spot
	var who: String = root._character.get_player_character()
	if who == "":
		return
	# Phase 157 — the death variant follows the hit: killer to body, against the way the avatar faces.
	GameBus.character_death_requested.emit(who, death_clip(who, death_pos, killer_id))

## Phase 157 — the death variant for `who` killed at `death_pos` by `killer_id`: the push variant from
## the killer-to-body direction against the avatar's facing, else the default clip.
func death_clip(who: String, death_pos: Vector3, killer_id: String) -> String:
	var src: Variant = death_attacker_pos(killer_id) if killer_id != "" else null
	var yaw: Variant = root._character.get_character_yaw(who)
	if src is Vector3 and yaw != null:
		return DeathPush.variant(death_pos - (src as Vector3), float(yaw))
	return DeathPush.DEATH_DEFAULT

func _on_player_respawned(_position: Vector3) -> void:
	# The death pose is terminal until reset: without this the avatar lies down for good after a respawn.
	if root._character.get_player_character() != "":
		root._character.reset_locomotion(root._character.get_player_character())
	# Phase 87 — put the body on the exact spawn after rebasing the scene onto its chunk, so a player
	# who died far from the spawn does not land on a quantised far-from-origin float32.
	if root._player != null and root._rebase != null and not root._player.respawn_world_pos.is_empty():
		root._rebase.rebase_to(root._player.respawn_world_pos["chunk"])
		root._player.place_at_world_pos(root._player.respawn_world_pos)
	root._persistence_wiring.lift_after_respawn()
