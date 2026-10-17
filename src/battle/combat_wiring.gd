extends "res://src/core/wiring.gd"
## Combat wiring (Phase 132) — Combat, creature events and status effects.
## Moved out of game_root.gd; `root` is the GameRoot that owns the slices.

const WorldPos := preload("res://src/terrain/world_pos.gd")
const TerrainSlice     := preload("res://src/terrain/terrain_slice.gd")
const BattleSlice      := preload("res://src/battle/battle_slice.gd")
const CreatureAI       := preload("res://src/creature/creature_ai.gd")
const PlayerRegistry   := preload("res://src/persistence/player_registry.gd")
const PlayerSlice      := preload("res://src/player/player_slice.gd")
const StatusEffects    := preload("res://src/battle/status_effects.gd")

func _connect_all() -> void:
	connect_bus(GameBus.knockback_requested, _on_knockback_requested)
	connect_bus(GameBus.player_died, _on_status_player_died)
	connect_bus(GameBus.combat_round_requested, _on_combat_round_requested)
	connect_bus(GameBus.player_damaged, on_player_damaged)
	connect_bus(GameBus.player_died, _on_player_died)
	connect_bus(GameBus.player_respawned, _on_player_respawned)

## Drive the player avatar's attack animation whenever the player attacks.
func _on_combat_round_requested(attacker_id: String, _defender_id: String) -> void:
	if attacker_id == "player" and root._character.get_player_character() != "":
		GameBus.character_attack_requested.emit(root._character.get_player_character())

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
	var simulated := PlayerRegistry.simulated_hp_after_hit(
		root._registry.get_hp(target_id), damage, PlayerSlice.MAX_HP)
	root._registry.record_simulated_hp(target_id, simulated)
	root._networking.send_player_damaged(peer, damage, attacker_id)
	# Phase 129 — a downed body loses every effect.
	if root._status != null and PlayerRegistry.is_downed(simulated):
		root._status.clear(target_id)
		for t in root._status.take_dirty():
			push_status_effects(str(t), status_now())

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

func _on_status_player_died(_position: Vector3, _killer_id: String) -> void:
	if root._status != null and not root._is_client:
		root._status.clear("player")
		for t in root._status.take_dirty():
			push_status_effects(str(t), status_now())

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
	var walkable := func(probe: Vector3) -> bool:
		return root._voxel.get_voxel_height_at(Vector2(probe.x, probe.z)) <= probe.y + root.KNOCKBACK_STEP_UP
	var spot := StatusEffects.knockback_target(pos, src, tiles, TerrainSlice.TILE_SIZE, walkable)
	if spot == pos:
		return
	spot.y = maxf(spot.y, root._voxel.get_voxel_height_at(Vector2(spot.x, spot.z)))
	if peer == 0:
		root._player.spawn_at(spot)
	else:
		root._networking.send_teleport(peer, WorldPos.from_world(spot.x, spot.y, spot.z))

func _on_player_died(_position: Vector3, _killer_id: String) -> void:
	if root._character.get_player_character() != "":
		GameBus.character_death_requested.emit(root._character.get_player_character())

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
