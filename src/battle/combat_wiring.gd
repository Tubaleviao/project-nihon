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
const PendingHit       := preload("res://src/battle/pending_hit.gd")
const HitFeel          := preload("res://src/battle/hit_feel.gd")
const ComboChain       := preload("res://src/battle/combo_chain.gd")

func tick(_delta: float) -> void:
	if root._battle != null:
		root._battle.tick_impacts()   # Phase 287: the hits whose impact time has come

func _connect_all() -> void:
	if root._battle != null and not root._is_client:
		enable_impact_timing()
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
	connect_bus(GameBus.attack_intent, on_attack_intent)
	connect_bus(GameBus.creature_died, on_creature_died)

## Host: how far past `PlayerSlice.ATTACK_RANGE` a peer's swing may land, measured from the host's last record
## of that peer — covers the creature and the peer moving between the peer's aim and the packet.
const ATTACK_REACH_SLACK_M := 1.5
## Host: the shortest gap between two of one peer's swings. A swing has no cooldown of its own yet, so this only
## bounds a flooding client (the packet bucket alone allows 40 rounds a second).
const ATTACK_MIN_INTERVAL_MS := 200
## player id -> Time.get_ticks_msec() of that player's last accepted swing.
var _last_swing_ms: Dictionary = {}
## Host: attacker id -> { weapon, step, at } for a peer drawn no body here (a dedicated host), so its combo advances.
var _bodyless_combo: Dictionary = {}

## Host: a peer's swing (`attack_intent`, re-emitted by NetworkingSlice with the connection's player id). The
## host checks everything it can know itself: the peer is connected and not downed or held, the target is a
## living untamed creature, the host's record of the peer is within reach of it, and the swing rate. Then it
## requests the round with the peer's player id as the attacker; BattleSlice applies `attack_blocked` (a
## carried body) and resolves it, and `combat_hit_resolved` animates it for everyone. Returns whether the
## round was requested (for tests).
func on_attack_intent(instance_id: String, player_id: String) -> bool:
	if root._is_client or player_id == "" or player_id == "player" or player_id == root._registry.local_player_id:
		return false   # the local body's own swings come in as combat_round_requested("player", …)
	var peer := root._registry.get_peer_id(player_id)
	if peer == 0 or not root._networking.has_last_known_state(peer):
		return false
	if PlayerRegistry.is_downed(root._registry.get_hp(player_id)):
		return false
	if root._status != null and root._status.is_immobilized(player_id, status_now()):
		return false
	if root._creature == null:
		return false
	var state := root._creature.get_instance_state(instance_id)
	if state == "" or state == "dead" or root._creature.is_tamed(instance_id):
		return false
	var reach := PlayerSlice.ATTACK_RANGE + ATTACK_REACH_SLACK_M
	var gap: float = WorldPos.offset_between(root._peer_wiring.peer_exact_pos(peer), root._creature.get_instance_pos(instance_id)).length()
	if gap > reach:
		return false
	if root._battle != null and root._battle.impact_queue != null and root._battle.impact_queue.has_pending(player_id):
		return false   # a swing is already in flight: a dropped click must not restart the rate window
	var now := Time.get_ticks_msec()
	if _last_swing_ms.has(player_id) and now - int(_last_swing_ms[player_id]) < ATTACK_MIN_INTERVAL_MS:
		return false
	_last_swing_ms[player_id] = now
	GameBus.combat_round_requested.emit(player_id, instance_id)
	return true

## Host: a creature a peer killed. The peer's client resolves no rounds of its own, so it never sees the
## `creature_died` its tutorial counts; the host tells only that peer, by species. Returns the peer told (0 none).
func on_creature_died(entity_id: String, _pos: Vector3, killer_id: String, _landing: Vector3) -> int:
	if root._is_client or killer_id == "" or killer_id == "player" or killer_id == root._registry.local_player_id:
		return 0
	var peer := root._registry.get_peer_id(killer_id)
	if peer == 0:
		return 0
	var species: String = root._creature.get_instance_creature_id(entity_id) if root._creature != null else ""
	if species == "":
		species = entity_id if GameData.CREATURES.has(entity_id) else ""
	root._networking.send_creature_killed(peer, species)
	return peer

## Drop a departed player's swing clock (called from the peer-left path).
func forget_swinger(player_id: String) -> void:
	_last_swing_ms.erase(player_id)
	_bodyless_combo.erase(player_id)
	if root._battle != null and root._battle.impact_queue != null:
		root._battle.impact_queue.cancel(player_id)

## Phase 287 — host: turn on impact timing. A player's swing then plays its clip at the click and deals its damage at
## the clip's impact time, after `impact_state` re-checked it.
func enable_impact_timing() -> void:
	root._battle.impact_queue = PendingHit.new()
	root._battle.impact_info_fn = impact_info
	root._battle.impact_state_fn = impact_state
	root._battle.swing_started_fn = _on_swing_started

## Host: a player's swing was queued. Its own clip already plays here; clients in range see it at the click, not
## when (or if) the hit lands.
func _on_swing_started(attacker_id: String, defender_id: String) -> void:
	root._gesture_wiring.note_action(attacker_id)   # a swing ends a pose at the click, hit or no hit
	if root._networking == null or not root._networking.is_host():
		return
	var a_key := _wire_key(attacker_id)
	var at: Variant = _event_position(a_key, _wire_key(defender_id))
	if at != null:
		root._networking.send_combat_hit(a_key, _wire_key(defender_id), "swing", at)

func _attacker_character(attacker_id: String) -> String:
	return _character_for_key(_wire_key(attacker_id))

## The held hotbar item (Phase 280) else the main-hand item the host's registry holds for a player with no body here ("" for the local "player").
func _registry_main_hand(attacker_id: String) -> String:
	if attacker_id == "player":
		return ""
	var held: String = root._held_item_wiring.held_of(attacker_id)
	return held if held != "" else str(root._registry.get_equipment(attacker_id).get("MainHand", ""))

func _main_hand(iid: String) -> String:
	var held: String = root._character.held_item_of(iid)
	return held if held != "" else str(root._character.get_equipment_set(iid).get("MainHand", ""))

## The swing an attacker just started: plays its clip (advancing the combo) and reports weapon, step and the length
## of the clip that actually played. An attacker with no body here (a dedicated host draws none for a peer) takes
## its weapon from the registry's equipment and starts its chain at step 0.
func impact_info(attacker_id: String) -> Dictionary:
	var iid := _attacker_character(attacker_id)
	if iid == "":
		var item := _registry_main_hand(attacker_id)
		var weapon: String = ComboChain.weapon_class(item, GameData.ITEMS)
		var now := Time.get_ticks_msec() / 1000.0
		var last: Dictionary = _bodyless_combo.get(attacker_id, {})
		var bstep: int = ComboChain.next_step(weapon, str(last.get("weapon", "")), int(last.get("step", -1)), now - float(last.get("at", -1e9)))
		_bodyless_combo[attacker_id] = { "weapon": weapon, "step": bstep, "at": now }
		return { "weapon": weapon, "item": item, "step": bstep, "clip_length": ComboChain.placeholder_length(weapon, bstep) }
	root._character.trigger_attack(iid)
	var inst: Dictionary = root._character._instances[iid]
	var combo: Dictionary = inst.get("combo", {})
	var lengths: Dictionary = inst.get("swing_lengths", {})
	var weapon := str(combo.get("weapon", "unarmed"))
	var step := int(combo.get("step", 0))
	var clip: String = ComboChain.clip_for(weapon, step, lengths if not lengths.is_empty() else null)
	if not lengths.has(clip):
		clip = RigTree.ATTACK_DEFAULT   # the clip `trigger_attack` played
	return { "weapon": weapon, "item": _main_hand(iid), "step": step, "clip_length": float(lengths.get(clip, 0.5)) }

## The state at impact for `PendingHit.refusal`, with the same checks as the click: both alive, the attacker not
## immobilised (a stagger or paralysis), not carrying a body, the target living and untamed, and the target within
## reach of the attacker's exact position now.
func impact_state(entry: Dictionary) -> Dictionary:
	var attacker: String = entry["attacker"]
	var target: String = entry["target"]
	var iid := _attacker_character(attacker)
	var state := root._creature.get_instance_state(target) if root._creature != null else ""
	var is_local := attacker == "player" or attacker == root._registry.local_player_id
	var gap := INF
	var apos: Variant = null
	if is_local:
		apos = root._player.get_world_pos() if root._player != null else null
	else:
		var peer: int = root._registry.get_peer_id(attacker)
		if peer != 0 and root._networking.has_last_known_state(peer):
			apos = root._peer_wiring.peer_exact_pos(peer)
	if apos is Dictionary and state != "":
		gap = WorldPos.offset_between(apos, root._creature.get_instance_pos(target)).length()
	var alive := true
	if is_local:
		alive = root._player != null and not PlayerRegistry.is_downed(root._player.get_hp())
	else:
		alive = not PlayerRegistry.is_downed(root._registry.get_hp(attacker))
	var stopped: bool = root._status != null and root._status.is_immobilized(attacker, status_now())
	var blocked: bool = root._battle.attack_blocked.is_valid() and root._battle.attack_blocked.call(attacker)
	return { "attacker_alive": alive, "attacker_staggered": stopped or blocked,
		"attacker_item": _main_hand(iid) if iid != "" else _registry_main_hand(attacker),
		"target_alive": state != "" and state != "dead" and not root._creature.is_tamed(target), "gap": gap,
		"reach": PlayerSlice.ATTACK_RANGE + ATTACK_REACH_SLACK_M }

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
	var reaction := reaction_for(defender_id, _damage)
	_animate_hit(a_key, d_key, outcome, reaction)
	if outcome != "miss" and (attacker_id == "player" or attacker_id == root._registry.local_player_id):
		_hit_feel()
	if outcome != "miss" and outcome != "kill":
		push_struck(attacker_id, defender_id, reaction)
	# Only a hosting machine has clients to tell; offline, the send would just warn on every swing.
	if root._networking != null and root._networking.is_host():
		var at: Variant = _event_position(a_key, d_key)
		if at != null:   # no resolvable position: an AOI broadcast around the origin would be wrong
			# A non-lethal heavy hit goes out as "stagger" so every client plays the stagger clip too.
			var wire := "stagger" if reaction == "stagger" and (outcome == "hit" or outcome == "critical") else outcome
			root._networking.send_combat_hit(a_key, d_key, wire, at)

## Phase 287 — host: a creature a player's landed (non-killing) hit struck is pushed a short way away from the
## attacker, the fabric's `knockbackLight` or (for a stagger) `knockbackHeavy` metres, stopping at ground it can
## step onto. Returns the metres moved (0 when nothing moved). Only with impact timing on, and only a creature:
## a player's body is moved by its own client.
func push_struck(attacker_id: String, defender_id: String, reaction: String) -> float:
	if root._battle == null or root._battle.impact_queue == null or BattleSlice.is_player_target(defender_id) \
			or root._creature == null or root._voxel == null:
		return 0.0
	if attacker_id != "player" and not BattleSlice.is_player_target(attacker_id):
		return 0.0
	var res: Resource = GameData.WORLD_SYSTEMS.get("CombatCombos", null)
	if res == null:
		return 0.0
	var metres := float(res.get("knockbackHeavy" if reaction == "stagger" else "knockbackLight"))
	var apos: Variant = death_attacker_pos(attacker_id)
	if not apos is Vector3 or root._creature.get_instance_state(defender_id) in ["", "dead"]:
		return 0.0
	var tpos: Vector3 = root._creature.get_instance_position(defender_id)
	var dir := PendingHit.knockback_direction(apos, tpos)
	var moved := 0.0
	while moved + 0.1 <= metres + 0.0001 and dir != Vector3.ZERO:
		var probe := tpos + dir * (moved + 0.1)
		if not death_walkable(Vector3(probe.x, tpos.y, probe.z)):
			break
		moved += 0.1
	if moved <= 0.0:
		return 0.0
	var spot := tpos + dir * moved
	root._creature.set_instance_position(defender_id, Vector3(spot.x, death_ground(spot), spot.z))
	return moved

## Client: the host's swing, animated on whatever bodies this client draws.
func _on_combat_hit_synced(attacker_key: String, defender_key: String, outcome: String) -> void:
	if not root._is_client:
		return
	if outcome == "swing":
		_swing(attacker_key)
		return
	# A player's swing played when the host announced it, at the click; only a creature's plays with its hit.
	var reaction := "stagger" if outcome == "stagger" else "hit"
	_animate_hit(attacker_key, defender_key, outcome, reaction, attacker_key.begins_with("c:"))
	if outcome != "miss" and attacker_key.begins_with("p:") and _character_for_key(attacker_key) == root._character.get_player_character() \
			and root._character.get_player_character() != "":
		_hit_feel()

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

## Phase 287 — the local attacker's landed hit: camera shake and a 40 ms hit-stop (each an option).
func _hit_feel() -> void:
	if root._player != null:
		HitFeel.shake(root._player._camera)
	var iid: String = root._character.get_player_character()
	if iid != "":
		HitFeel.hit_stop(root._character._instances[iid].get("anim_tree", null))

## Phase 287 — "stagger" for a hit past the fabric's share of the defender's max health, else "hit".
func reaction_for(defender_id: String, damage: float) -> String:
	var max_hp := 0.0
	if BattleSlice.is_player_target(defender_id):
		if defender_id == "player" or defender_id == root._registry.local_player_id:
			max_hp = root._player.max_hp if root._player != null else 0.0
		else:
			max_hp = root._registry.max_hp_of(defender_id)   # the host's own model of that peer
	elif root._battle != null:
		max_hp = root._battle._field(root._battle._lookup(defender_id), "baseHp", 0.0)
	var res: Resource = GameData.WORLD_SYSTEMS.get("CombatCombos", null)
	return PendingHit.reaction(damage, max_hp, float(res.get("staggerShare")) if res != null else 0.25)

func _animate_hit(a_key: String, d_key: String, outcome: String, reaction: String = "hit", swing: bool = true) -> void:
	if swing and (root._battle == null or root._battle.impact_queue == null or a_key.begins_with("c:")):
		_swing(a_key)   # with impact timing a player's swing played at the click
	# The local body flinches on `player_damaged` (which also covers burns and the like), so a hit on it
	# is skipped here and nobody flinches twice.
	var is_local_body := d_key.begins_with("p:") and _character_for_key(d_key) == root._character.get_player_character()
	# A body killed by this blow (creature or player) goes to its death pose; a queued flinch would
	# replay on respawn.
	if outcome != "miss" and outcome != "kill" and not is_local_body:
		_flinch(d_key, reaction)

## The local body took damage, from any source: flinch.
func _on_local_player_damaged(damage: float, _attacker_id: String, target_id: String) -> void:
	if target_id != "" and target_id != "player" and target_id != root._registry.local_player_id:
		return
	var iid: String = root._character.get_player_character()
	if iid != "":
		root._character.trigger_hit(iid, reaction_for("player", damage) == "stagger")

func _swing(key: String) -> void:
	if key.begins_with("c:"):
		root._creature.trigger_attack_animation(key.substr(2))
		return
	var iid := _character_for_key(key)
	if iid != "":
		root._character.trigger_attack(iid)

func _flinch(key: String, reaction: String = "hit") -> void:
	if key.begins_with("c:"):
		root._creature.trigger_hit_animation(key.substr(2), reaction)
		return
	var iid := _character_for_key(key)
	if iid != "":
		root._character.trigger_hit(iid, reaction == "stagger")

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
