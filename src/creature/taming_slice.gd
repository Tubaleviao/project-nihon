extends Node
## Taming slice — resolves creature taming interactions per player (Phase 35).
##
## The fabric is the single source of truth. Each tameable creature carries a
## structured `tame` json field (fabric/world/creatures/*.js, built by
## `tameData()` in shared.js) naming the result kind (a companion or a shed
## yield), the bare-hands / skill / offered-item requirements, the defeated-alpha
## gate, the granted player flag, the shed items, the cooldown and whether a
## tamed instance still respawns. Nothing in this file hardcodes a creature: add
## the field to another creature and it becomes tameable.
##
## Two fabric rules are modelled in one place:
##
##   • GraywolfPack — "tame a surviving pup after defeating the alpha wolf",
##     unarmed, Unarmed: Journeyman, grants the `wolfBondHolder` flag (which the
##     Ranger profession requires) and the pup does not respawn once tamed.
##   • GlimmerFox — "feed the fox to harvest shed fur without harming it":
##     unarmed, Alchemy: Apprentice, offers field rations OR raw meat, the fox
##     stays alive and sheds a glimmer fur tuft, on a 10-minute cooldown.
##
## Taming is per-player for the same reason research is (Phase 34): the granted
## flag, the companion binding and the consumed offering all belong to one
## player's record and one player's inventory. A client owns no records, so it
## never resolves a tame locally — it forwards an intent to the host.
##
## Plug contract (GameBus signals consumed / emitted):
##   IN  : tame_requested(instance_id)
##         tame_intent(instance_id, player_id)    — Phase 35: who is taming
##   OUT : tame_resolved(result)      { instance_id, creature_id, success,
##                                      reason, result, player_id, flag, yields }
##         creature_tamed(instance_id, creature_id, player_id)
##         tame_intent(instance_id, "")           — client forwards to the host
##
## Public API (every call takes an optional `player_id`; "" means THIS machine's
## local player — see `resolve_player`, the Phase 34 convention):
##   can_tame(instance_id, player_id := "")   -> Dictionary  { ok, reason, creature_id }
##   tame(instance_id, player_id := "")       -> Dictionary  (validate + resolve)
##   tame_data(creature_id)                   -> Dictionary  (fabric `tame` field)
##   is_tameable(creature_id)                 -> bool
##   is_unarmed(player_id := "")              -> bool
##   skill_tier(player_id, skill)             -> String
##   has_flag(player_id, flag)                -> bool
##   get_flags(player_id := "")               -> Dictionary
##   get_companions(player_id := "")          -> Array      (instance ids, sorted)
##   companion_target(player_id)              -> Variant    (Vector3 or null)
##   apply_record(record, player_id := "")    -> void       (persistence restore)
##   sync_record(player_id := "")             -> void       (persistence write)

## How close the tamer must be to the creature to interact with it — the fabric
## rule is "player must approach the pup while unarmed" / "offer field rations
## while unarmed". Metres.
const TAME_RANGE := 4.0

## Shared skill-tier ordering (novice → master) — see src/core/skill_tiers.gd.
const SkillTiers := preload("res://src/core/skill_tiers.gd")

## Set by game_root: the creature population (tamed bindings, alpha-down gate).
var creature_slice: Node = null

## Set by game_root: the AI driver, notified when an instance becomes a companion.
var creature_ai: Node = null

## Set by game_root: the local player's body, for the tamer's own position.
var player_slice: Node = null

## Set by game_root: the PlayerRegistry, which owns the per-player records the
## granted flags and companions are persisted on.
var player_registry: Node = null

## Set by game_root: the per-process skill table the skill requirement is read
## from (the same table the crafting gates use — Phase 16).
var crafting_slice: Node = null

## Set by game_root: the character slice, for the bare-hands requirement.
var character_slice: Node = null

## Set by game_root so a tame consumes the offering from the tamer's inventory.
## The fallback inventory when no per-player registry is wired (isolated tests).
var inventory_slice: Node = null

## Authority mode: true on the host / single-player (this slice resolves the
## tame), false on a client (it forwards the intent to the host, which is the
## only machine that owns the player records and their inventories).
var is_authoritative: bool = true

## player_id -> { flag: true }. Created lazily per player, persisted on the record.
var _flags: Dictionary = {}

## player_id -> { instance_id: true } — the live companion binding. Mirrored from
## creature_slice (which owns the instance) so a record write is one lookup.
var _companions: Dictionary = {}

## player_id -> { instance_id: wall-clock deadline (Unix seconds) }. A "yield"
## tame leaves the creature alive, so the fabric's cooldown is what stops the
## same fox being fed in a loop.
var _cooldowns: Dictionary = {}

func _ready() -> void:
	GameBus.tame_requested.connect(_on_tame_requested)
	GameBus.tame_intent.connect(_on_tame_intent)
	GameBus.creature_spawned.connect(_on_creature_spawned)

## A restored companion binding is kept in the mirror even when its creature is not
## resident (its chunk is not streamed yet, so the taming happened before the world
## finished booting). Re-apply it the moment that instance enters the world, or the
## wolf would come back wild and its owner's record would contradict the world.
func _on_creature_spawned(instance_id: String, _creature_id: String, _position: Vector3) -> void:
	for player_id in _companions:
		if (_companions[player_id] as Dictionary).has(instance_id):
			rebind_companion(instance_id, str(player_id))

# ---------------------------------------------------------------------------
# Player resolution (Phase 34 convention)
# ---------------------------------------------------------------------------

## The player a call is about: the id it was given, or THIS machine's local player
## when the caller passed "". On a client — and in an isolated unit test with no
## registry — the local id is "" and that single bucket IS the machine's own player.
func resolve_player(player_id: String) -> String:
	if player_id != "":
		return player_id
	return local_player_id()

func local_player_id() -> String:
	if player_registry != null and "local_player_id" in player_registry:
		return str(player_registry.local_player_id)
	return ""

## The inventory a tame by `player_id` consumes from and yields into: that
## player's own inventory from the registry when one is wired, else the fallback.
func inventory_for(player_id: String) -> Node:
	if player_id != "" and player_registry != null and player_registry.has_method("get_inventory"):
		return player_registry.get_inventory(player_id)
	return inventory_slice

## The tamer's world position, or null when it is not knowable on this machine.
## The local player's body is simulated here; a remote peer's position is the
## last value the host recorded from its own movement packets.
func _player_position(player_id: String) -> Variant:
	if player_id == "":
		return null
	if player_id == local_player_id() and player_slice != null and player_slice.has_method("get_position"):
		return player_slice.get_position()
	if player_registry != null and player_registry.has_method("get_record"):
		var rec: Dictionary = player_registry.get_record(player_id)
		var arr = rec.get("position", [])
		if arr is Array and (arr as Array).size() >= 3:
			return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
	return null

## Where a companion owned by `player_id` should head, or null when the owner's
## position is not knowable here. Read by CreatureAI so a tamed wolf follows its
## owner instead of patrolling.
func companion_target(player_id: String) -> Variant:
	return _player_position(player_id)

# ---------------------------------------------------------------------------
# Fabric data
# ---------------------------------------------------------------------------

## The structured `tame` field for a creature, or {} when it is not tameable.
## Accepts the json field as a Dictionary (generator-godot emits one) or as a
## String, and returns {} rather than throwing on a malformed value.
func tame_data(creature_id: String) -> Dictionary:
	var res: Resource = GameData.CREATURES.get(creature_id, null)
	if res == null:
		return {}
	var tame = res.get("tame")
	if tame is Dictionary:
		return tame
	if tame is String and tame != "":
		var parsed = JSON.parse_string(tame)
		if parsed is Dictionary:
			return parsed
	return {}

func is_tameable(creature_id: String) -> bool:
	return not tame_data(creature_id).is_empty()

# ---------------------------------------------------------------------------
# Requirements
# ---------------------------------------------------------------------------

## Whether the tamer's hands are free. Only the LOCAL player's character is
## modelled on this machine — a remote peer's equipment is not replicated, and
## the tame intent carries no equipment claim, so for a peer the rule cannot be
## evaluated and is reported as satisfied (documented gap, same shape as the
## skill-tier / station-proximity gaps Phase 34 recorded).
func is_unarmed(player_id: String = "") -> bool:
	var pid := resolve_player(player_id)
	if character_slice == null or pid != local_player_id():
		return true
	if not character_slice.has_method("get_player_character") or not character_slice.has_method("get_visual_state"):
		return true
	var char_id := str(character_slice.get_player_character())
	if char_id == "":
		return true
	var state: Dictionary = character_slice.get_visual_state(char_id)
	var equipment = state.get("equipment", {})
	if not (equipment is Dictionary) or not (equipment as Dictionary).has("MainHand"):
		return true
	var entry = (equipment as Dictionary)["MainHand"]
	if entry is Dictionary and str((entry as Dictionary).get("state", "equipped")) == "equipped":
		return false
	return true

## The tamer's tier name for a skill, resolved for THAT player (Phase 36): tiers are
## per-player, so a peer's Unarmed tier is its own record's and never this machine's.
## An unwired table — or a record with no tier yet — resolves to "novice", so a
## requirement above novice fails closed rather than being skipped.
func skill_tier(player_id: String, skill: String) -> String:
	if crafting_slice != null and crafting_slice.has_method("get_skill_for"):
		return str(crafting_slice.get_skill_for(player_id, skill))
	if crafting_slice != null and crafting_slice.has_method("get_skill"):
		return str(crafting_slice.get_skill(skill))
	return "novice"

# ---------------------------------------------------------------------------
# Flags / companions
# ---------------------------------------------------------------------------

func has_flag(player_id: String, flag: String) -> bool:
	if flag == "":
		return false
	return _flags_for(resolve_player(player_id)).has(flag)

func get_flags(player_id: String = "") -> Dictionary:
	return _flags_for(resolve_player(player_id)).duplicate()

## The instance ids tamed by `player_id`, sorted. CreatureSlice owns the binding;
## this mirrors it after any change so the record write is one lookup.
func get_companions(player_id: String = "") -> Array:
	var pid := resolve_player(player_id)
	var ids: Array = _companions_for(pid).keys()
	# Ordered, so the value is stable for the record write and for any caller that
	# compares two lists (CreatureSlice.companions_of sorts for the same reason).
	ids.sort()
	return ids

func _flags_for(player_id: String) -> Dictionary:
	if not _flags.has(player_id):
		_flags[player_id] = {}
	return _flags[player_id]

func _companions_for(player_id: String) -> Dictionary:
	if not _companions.has(player_id):
		_companions[player_id] = {}
	return _companions[player_id]

func _cooldowns_for(player_id: String) -> Dictionary:
	if not _cooldowns.has(player_id):
		_cooldowns[player_id] = {}
	return _cooldowns[player_id]

## Wall-clock seconds left on a creature's cooldown for `player_id` (0.0 when
## none). Unix-epoch based, like every other deadline in the project.
func cooldown_remaining(instance_id: String, player_id: String = "") -> float:
	var pid := resolve_player(player_id)
	var table: Dictionary = _cooldowns_for(pid)
	if not table.has(instance_id):
		return 0.0
	return maxf(0.0, float(table[instance_id]) - Time.get_unix_time_from_system())

# ---------------------------------------------------------------------------
# Taming
# ---------------------------------------------------------------------------

## Validate a tame by `player_id` WITHOUT mutating anything. Returns
## { ok: bool, reason: String, creature_id: String }. Every reason is a stable
## token the UI and the tests assert on.
##
## Precedence is deliberate, and it is the order the reasons are worth telling a
## player in: is this even a taming interaction (unknown / not tameable), is this
## instance already spoken for or gone (already_tamed / target_dead), can the
## player interact with it at all from here (too_far), is the world state right
## (alpha_alive), then are the player's own hands and knowledge up to it
## (armed / skill_locked / missing_offer / inventory_full), and finally the
## creature's own cooldown. A distance failure is answered before a state one
## because a player who cannot reach the creature cannot act on its state either.
func can_tame(instance_id: String, player_id: String = "") -> Dictionary:
	var pid := resolve_player(player_id)
	if creature_slice == null:
		return { "ok": false, "reason": "no_creature_slice", "creature_id": "" }
	var creature_id := str(creature_slice.get_instance_creature_id(instance_id))
	if creature_id == "":
		return { "ok": false, "reason": "unknown_instance", "creature_id": "" }
	var data := tame_data(creature_id)
	if data.is_empty():
		return { "ok": false, "reason": "not_tameable", "creature_id": creature_id }
	if is_tamed_by_anyone(instance_id):
		return { "ok": false, "reason": "already_tamed", "creature_id": creature_id }
	if _instance_is_dead(instance_id):
		return { "ok": false, "reason": "target_dead", "creature_id": creature_id }

	# A creature is approached, not summoned (fabric: "player must approach the
	# pup"). Only enforced when the tamer's position is knowable here — for a peer
	# with no recorded position the check is skipped, not faked.
	var pos: Variant = _player_position(pid)
	if pos != null and creature_slice.has_method("get_instance_position"):
		var creature_pos: Variant = creature_slice.get_instance_position(instance_id)
		if creature_pos is Vector3 and (creature_pos as Vector3).distance_to(pos as Vector3) > TAME_RANGE:
			return { "ok": false, "reason": "too_far", "creature_id": creature_id }

	# The pack's alpha-down gate: "tame a surviving pup AFTER defeating the alpha
	# wolf". The runtime models a pack as N instances of one creature id, so
	# "the alpha is down" is "one instance of that species is dead".
	if bool(data.get("requiresDefeated", false)) and not creature_slice.has_defeated_species(creature_id):
		return { "ok": false, "reason": "alpha_alive", "creature_id": creature_id }

	if bool(data.get("requiresUnarmed", false)) and not is_unarmed(pid):
		return { "ok": false, "reason": "armed", "creature_id": creature_id }

	# Skill requirement, fail-closed: an unwired table reads as "novice".
	var skill_req = data.get("requiresSkill", {})
	if skill_req is Dictionary and not (skill_req as Dictionary).is_empty():
		var skill := str((skill_req as Dictionary).get("skill", ""))
		var tier := str((skill_req as Dictionary).get("tier", ""))
		var have := skill_tier(pid, skill)
		if SkillTiers.rank(have) < SkillTiers.rank(tier):
			return { "ok": false, "reason": "skill_locked:%s:%s" % [skill, tier], "creature_id": creature_id }

	var inventory := inventory_for(pid)
	if inventory == null:
		return { "ok": false, "reason": "no_inventory", "creature_id": creature_id }

	# The offering: ANY ONE listed item satisfies it (the fabric rules name
	# alternatives — "field rations or raw meat") and the matched one is consumed.
	var offers: Array = data.get("requiresAnyItem", [])
	if not offers.is_empty() and _first_available_offer(inventory, offers).is_empty():
		return { "ok": false, "reason": "missing_offer", "creature_id": creature_id }

	# The shed yield has to fit BEFORE the offering is consumed, so a full pack
	# cannot eat the player's rations and hand back nothing.
	var yields: Array = data.get("yields", [])
	if not yields.is_empty() and inventory.has_method("can_add_items"):
		if not inventory.can_add_items(_to_counts(yields)):
			return { "ok": false, "reason": "inventory_full", "creature_id": creature_id }

	if cooldown_remaining(instance_id, pid) > 0.0:
		return { "ok": false, "reason": "on_cooldown", "creature_id": creature_id }

	return { "ok": true, "reason": "", "creature_id": creature_id }

## Resolve a tame for `player_id`: validate, consume the offering, apply the
## fabric's outcome (companion binding and/or granted flag and/or shed items),
## start the cooldown and persist the player's flags and companions. Never throws;
## every failure comes back as a `tame_resolved` result with a reason token.
##
## A refusal is ATOMIC: it spends no offering and moves no flag. The offering is
## consumed first (see below) and is handed straight back if the companion binding
## then refuses it, and the flag is granted only once the binding is taken — a
## refused tame that had already eaten the player's rations and set their
## progression flag would misreport what happened.
func tame(instance_id: String, player_id: String = "") -> Dictionary:
	var pid := resolve_player(player_id)
	var check := can_tame(instance_id, pid)
	if not bool(check["ok"]):
		return _emit(_result(instance_id, str(check["creature_id"]), false, str(check["reason"]), "", pid, "", []))

	var creature_id := str(check["creature_id"])
	var data := tame_data(creature_id)
	var inventory := inventory_for(pid)
	var result_kind := str(data.get("result", ""))

	# Consume the offering before applying anything, so two tamers racing the same
	# fox cannot both spend the same ration: the second `can_tame` after the first
	# consumption finds nothing to offer. `spent` remembers what was taken, so a
	# refusal further down can hand it straight back.
	var offers: Array = data.get("requiresAnyItem", [])
	var spent: Dictionary = {}
	if not offers.is_empty():
		var offer := _first_available_offer(inventory, offers)
		spent = {
			str(offer["item"]): int(offer.get("quantity", 1)),
		}
		if not inventory.consume_items(spent):
			return _emit(_result(instance_id, creature_id, false, "missing_offer", "", pid, "", []))

	# The companion binding is the last step that can still refuse after validation:
	# an unidentified tamer (the "" bucket — see the class docstring) or a rival that
	# bound the instance between `can_tame` and here. Take it BEFORE the flag is
	# granted, and give the offering back when it refuses — exactly the rule
	# `inventory_full` already follows: a refusal must not take anything.
	if result_kind == "companion" and not creature_slice.mark_tamed(instance_id, pid):
		_return_items(inventory, spent)
		return _emit(_result(instance_id, creature_id, false, "already_tamed", result_kind, pid, "", []))

	var flag := str(data.get("grantsFlag", ""))
	if flag != "":
		_flags_for(pid)[flag] = true

	if result_kind == "companion":
		_companions_for(pid)[instance_id] = true
		if creature_ai != null and creature_ai.has_method("on_companion_tamed"):
			creature_ai.on_companion_tamed(instance_id, pid)
		GameBus.creature_tamed.emit(instance_id, creature_id, pid)

	# Shed yield: the creature stays alive and hands over its material (fabric:
	# "sheds glimmer fur tuft (1) without dying").
	var granted: Array = []
	for entry in data.get("yields", []):
		if not (entry is Dictionary):
			continue
		var item_id := str((entry as Dictionary).get("item", ""))
		var qty := int((entry as Dictionary).get("quantity", 1))
		if item_id == "" or qty <= 0:
			continue
		if inventory.add_item(item_id, qty):
			granted.append({ "item": item_id, "quantity": qty })

	var cooldown := float(data.get("cooldownSeconds", 0.0))
	if cooldown > 0.0:
		# Wall-clock seconds, not process uptime: the same rule every other
		# deadline in the project follows (Phase 24/31/33/34).
		_cooldowns_for(pid)[instance_id] = Time.get_unix_time_from_system() + cooldown

	sync_record(pid)
	return _emit(_result(instance_id, creature_id, true, "", result_kind, pid, flag, granted))

# ---------------------------------------------------------------------------
# Persistence (player record)
# ---------------------------------------------------------------------------

## Write the player's flags and companion bindings onto their record, so a
## restart keeps them (the flag is what the Ranger profession gate reads).
func sync_record(player_id: String = "") -> void:
	var pid := resolve_player(player_id)
	if pid == "" or player_registry == null:
		return
	if player_registry.has_method("record_flags"):
		player_registry.record_flags(pid, get_flags(pid))
	if player_registry.has_method("record_companions"):
		player_registry.record_companions(pid, get_companions(pid))

## Restore a player's flags and companions from their record. Companion bindings
## whose instance is not resident (its chunk is not streamed) are kept in the
## mirror and re-applied when that instance exists again — see `rebind_companion`.
func apply_record(record: Dictionary, player_id: String = "") -> void:
	var pid := resolve_player(player_id)
	if pid == "":
		return
	var flags = record.get("flags", {})
	if flags is Dictionary:
		for flag in flags:
			if bool(flags[flag]):
				_flags_for(pid)[str(flag)] = true
	var companions = record.get("companions", [])
	if companions is Array:
		for iid in companions:
			_companions_for(pid)[str(iid)] = true
			rebind_companion(str(iid), pid)

## Re-apply a companion binding to the creature population when the instance is
## resident. Safe to call at any time: a missing instance is left pending in the
## mirror, and re-marking an already-tamed instance is idempotent.
func rebind_companion(instance_id: String, player_id: String) -> void:
	if creature_slice == null or instance_id == "" or player_id == "":
		return
	if not creature_slice.has_method("get_instance_creature_id"):
		return
	if str(creature_slice.get_instance_creature_id(instance_id)) == "":
		return
	creature_slice.mark_tamed(instance_id, player_id)

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

## The first offered item the tamer actually holds, as { item, quantity }, or {}
## when none of the alternatives is available.
func _first_available_offer(inventory: Node, offers: Array) -> Dictionary:
	for entry in offers:
		if not (entry is Dictionary):
			continue
		var item_id := str((entry as Dictionary).get("item", ""))
		var qty := int((entry as Dictionary).get("quantity", 1))
		if item_id == "" or qty <= 0:
			continue
		if inventory.get_item_count(item_id) >= qty:
			return { "item": item_id, "quantity": qty }
	return {}

func _instance_is_dead(instance_id: String) -> bool:
	var iid := str(instance_id)
	for inst in creature_slice.get_all_instances():
		if str(inst.get("instance_id", "")) == iid:
			return str(inst.get("state", "")) == "dead"
	return false

## True when the instance is already somebody's companion (the instance record
## owns this, not the mirror, so a tame resolved by another player is seen).
func is_tamed_by_anyone(instance_id: String) -> bool:
	if creature_slice == null:
		return false
	if not creature_slice.has_method("is_tamed"):
		return false
	return bool(creature_slice.is_tamed(instance_id))

## Collapse a [{ item, quantity }] list into a { item: quantity } map.
func _to_counts(entries: Array) -> Dictionary:
	var counts: Dictionary = {}
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var item_id := str((entry as Dictionary).get("item", ""))
		var qty := int((entry as Dictionary).get("quantity", 1))
		if item_id == "":
			continue
		counts[item_id] = counts.get(item_id, 0) + qty
	return counts

## Hand a consumed { item_id: quantity } map back to `inventory`. Only ever called
## on a refusal, moments after the consumption with nothing in between: the weight
## and slot budget are exactly the pre-consumption ones, so this cannot fail.
func _return_items(inventory: Node, spent: Dictionary) -> void:
	for item_id in spent:
		inventory.add_item(str(item_id), int(spent[item_id]))

func _result(instance_id: String, creature_id: String, success: bool, reason: String, result: String, player_id: String, flag: String, yields: Array) -> Dictionary:
	return {
		"instance_id": instance_id,
		"creature_id": creature_id,
		"success":     success,
		"reason":      reason,
		"result":      result,
		"player_id":   player_id,
		"flag":        flag,
		"yields":      yields,
	}

func _emit(result: Dictionary) -> Dictionary:
	GameBus.tame_resolved.emit(result)
	return result

## Host-local tame request (the player input or any host-side system). A CLIENT
## does not resolve a tame at all — it owns no records, so it forwards an intent
## to the host, which is the only machine that can grant a flag or bind a companion.
func _on_tame_requested(instance_id: String) -> void:
	if not is_authoritative:
		GameBus.tame_intent.emit(instance_id, "")
		return
	tame(instance_id, local_player_id())

## A tame intent carrying a tamer. On the host this is the resolved path (the
## networking slice re-emits an inbound intent with the identity it bound to that
## connection). On a client the same signal is the OUTBOUND one — networking
## forwards it and this slice must not also resolve it locally.
func _on_tame_intent(instance_id: String, player_id: String) -> void:
	if not is_authoritative:
		return
	tame(instance_id, player_id if player_id != "" else local_player_id())
