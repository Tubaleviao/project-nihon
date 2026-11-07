extends Node
## Phase 216 — mounts: a player rides their own tamed companion. The fabric decides what can be ridden (a
## creature's `mount` field: speed factor, stamina, terrain, rider offset); this slice is the host's record of
## who rides what, and nothing here names a creature.
##
##   IN  : mount_intent(instance_id, player_id)   dismount_intent(player_id)
##         creature_died(...)  player_left(player_id)
##   OUT : mount_resolved(player_id, action, ok, reason)   mount_changed(player_id, instance_id)
##
## A mount is refused with a key from `REASONS` (`mount.refused.<code>` in the catalog): the creature is
## unknown, has no `mount` field, is not the player's own tamed companion, is dead, is out of reach, or is
## already ridden, is tired, or stands on terrain it cannot cross; or the player is already mounted or downed.
## A dismount while on foot answers `not_mounted`. While mounted the player's accepted speed is the mount's
## factor times the walking speed (`accepted_speed`), so a client reporting more is clamped by the host's
## speed cap. The creature's death, the rider leaving, riding past the mount's `staminaSeconds` or onto terrain
## outside its `terrain` list dismounts; a tired mount can be ridden again after resting as long as it was ridden.

const REASONS := ["unknown_instance", "not_mountable", "not_yours", "dead", "too_far", "occupied", "already_mounted",
	"unknown_player", "rate_limited", "not_mounted", "downed", "tired", "terrain"]
## Metres from the creature at which a player may mount it.
const MOUNT_RANGE := 4.0
## The most the rider and the creature may differ in height (metres) and still be within reach.
const MAX_STEP_M := 8.0
## Seconds between two intents of one player.
const INTENT_GAP_SEC := 0.25

## Facts about creatures and players, set by the wiring (host) or by a test.
## `(instance_id) -> String`: the fabric creature key, "" when unknown.
var creature_of: Callable = Callable()
## `(instance_id) -> String`: the player the creature is a tamed companion of, "" when wild.
var owner_of: Callable = Callable()
## `(instance_id) -> bool`: whether the creature is alive.
var alive: Callable = Callable()
## `(player_id) -> bool`: whether the player's body is downed (the host's record of a remote rider's health).
var rider_downed: Callable = Callable()
## `(instance_id) -> Variant`: the creature's Vector3 position, or null.
var position_of: Callable = Callable()
## `(instance_id) -> bool`: whether the creature stands in water (the sea, a lake or a river).
var in_water: Callable = Callable()
## `(player_id) -> Variant`: the player's Vector3 position, or null.
var player_pos: Callable = Callable()
## `(creature_id) -> Dictionary`: the fabric `mount` field, {} when the creature cannot be ridden.
var spec_of: Callable = Callable()
## `() -> String`: the id of the player on this machine (a listen host's own player), "" when none.
var local_player_id: Callable = Callable()
## `() -> bool`: whether the world takes keys now (no menu or chat open), and `(origin: Vector3, range: float) ->
## String`: the nearest creature's instance id, "" when none. Both set by the wiring; unset, M does nothing.
var input_allowed: Callable = Callable()
var nearest_to: Callable = Callable()
## `() -> Vector3`: where this machine's player stands.
var own_position: Callable = Callable()
## Whether the host last said this machine's player is mounted (M toggles).
var _local_mounted := false
## This machine's player body: it walks at the mounted creature's fabric factor times the walking speed while mounted.
var local_body: Node = null
var _last_asked := ""
## `() -> float` monotonic seconds. Test seam.
var mono_sec: Callable = Callable()

## player_id -> instance_id, and the reverse.
## False on a client: it forwards intents and applies what the host says, it never resolves a mount.
var is_host := true
var _riding: Dictionary = {}
var _ridden: Dictionary = {}
var _last_intent: Dictionary = {}
## player_id -> when the ride started; instance_id -> when a tired mount may be ridden again.
var _ride_started: Dictionary = {}
var _rested_at: Dictionary = {}

func _ready() -> void:
	GameBus.mount_intent.connect(_on_mount_intent)
	GameBus.dismount_intent.connect(_on_dismount_intent)
	GameBus.creature_died.connect(_on_creature_died)
	GameBus.player_left.connect(_on_player_left)
	GameBus.combat_hit_resolved.connect(_on_combat_hit)
	GameBus.mount_resolved.connect(_on_local_resolved)
	GameBus.player_died.connect(_on_local_died)

## M mounts the nearest creature within `MOUNT_RANGE`, or gets off. The host decides (it must be the player's own
## tamed companion) and answers with a keyed notice.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M):
		return
	var k := event as InputEventKey
	if k.alt_pressed or k.ctrl_pressed or k.meta_pressed:
		return
	if not input_allowed.is_valid() or not bool(input_allowed.call()):
		return
	if _local_mounted:
		GameBus.dismount_intent.emit("")
	elif nearest_to.is_valid() and own_position.is_valid():
		var iid := str(nearest_to.call(own_position.call(), MOUNT_RANGE))
		if iid != "":
			GameBus.mount_intent.emit(iid, "")

func _on_local_resolved(player_id: String, action: String, ok: bool, reason: String) -> void:
	# Only the answer about this machine's own player (a listen host also sees every remote rider's answer).
	if not local_player_id.is_valid() or player_id != str(local_player_id.call()):
		return
	# A refused dismount because the host has us on foot means we missed the dismount: walk again.
	var desync := not ok and action == "dismount" and reason == "not_mounted"
	if ok or desync:
		_local_mounted = ok and action == "mount"
		if local_body != null:
			var cid: String = str(creature_of.call(_last_asked)) if creature_of.is_valid() else ""
			local_body.mount_speed_factor = maxf(1.0, float(_spec(cid).get("speedFactor", 1.0))) if _local_mounted else 1.0

## The fabric `mount` field of `creature_id` as a Dictionary ({} when it has none).
static func fabric_spec(creature_id: String) -> Dictionary:
	var res: Resource = GameData.CREATURES.get(creature_id, null)
	if res == null:
		return {}
	var field: Variant = res.get("mount")
	if field is String and field != "":
		field = JSON.parse_string(field)
	return field if field is Dictionary else {}

func _spec(creature_id: String) -> Dictionary:
	return spec_of.call(creature_id) if spec_of.is_valid() else fabric_spec(creature_id)

func _now() -> float:
	return float(mono_sec.call()) if mono_sec.is_valid() else Time.get_ticks_msec() / 1000.0

## The fabric mount spec of a creature id ({} when it cannot be ridden).
func spec_of_creature(creature_id: String) -> Dictionary:
	return _spec(creature_id)

func mounted_instance(player_id: String) -> String:
	return str(_riding.get(player_id, ""))

func rider_of(instance_id: String) -> String:
	return str(_ridden.get(instance_id, ""))

## The ids of the players now mounted.
func riders() -> Array:
	return _riding.keys()

func is_mounted(player_id: String) -> bool:
	return _riding.has(player_id)

## The riding speed factor of `player_id`: the mount's `speedFactor`, 1.0 on foot.
func speed_factor(player_id: String) -> float:
	var iid := mounted_instance(player_id)
	if iid == "":
		return 1.0
	return maxf(1.0, float(_spec(str(creature_of.call(iid))).get("speedFactor", 1.0)))

## The speed the host accepts from `player_id`: `walk_speed` times the mount's factor while mounted.
func accepted_speed(player_id: String, walk_speed: float) -> float:
	return walk_speed * speed_factor(player_id)

## Where the rider's feet are: the creature's position plus the fabric's rider offset, or null.
func rider_position(player_id: String) -> Variant:
	var iid := mounted_instance(player_id)
	if iid == "":
		return null
	var at: Variant = position_of.call(iid) if position_of.is_valid() else null
	if not (at is Vector3):
		return null
	var o: Variant = _spec(str(creature_of.call(iid))).get("riderOffset", [0, 0, 0])
	if not (o is Array and (o as Array).size() == 3):
		return at
	return (at as Vector3) + Vector3(float(o[0]), float(o[1]), float(o[2]))

## The horizontal offset from the creature to its rider (the fabric `riderOffset` without its height, which
## the ground under the creature sets), Vector3.ZERO on foot. The host keeps the creature this far behind the rider.
func rider_offset(player_id: String) -> Vector3:
	var iid := mounted_instance(player_id)
	if iid == "":
		return Vector3.ZERO
	var o: Variant = _spec(str(creature_of.call(iid))).get("riderOffset", [0, 0, 0])
	if not (o is Array and (o as Array).size() == 3):
		return Vector3.ZERO
	return Vector3(float(o[0]), 0.0, float(o[2]))

## Whether a mount with `spec` may stand where the creature `instance_id` is (its `terrain` list; no list is ground).
func _terrain_ok(spec: Dictionary, instance_id: String) -> bool:
	if not in_water.is_valid() or not bool(in_water.call(instance_id)):
		return true
	var t: Variant = spec.get("terrain", ["ground"])
	return t is Array and (t as Array).has("water")

## Whether `rider` stands within reach of `creature` on the ground plane (a creature on the surface below a
## platform is within `MAX_STEP_M` of vertical difference at most, like a tree on the XZ plane).
static func in_reach(rider: Vector3, creature: Vector3) -> bool:
	return Vector2(rider.x - creature.x, rider.z - creature.z).length() <= MOUNT_RANGE and absf(rider.y - creature.y) <= MAX_STEP_M

## Validate and apply a mount. Returns "" on success, else a key from `REASONS`.
func mount(player_id: String, instance_id: String) -> String:
	if player_id == "":
		return "unknown_player"
	if is_mounted(player_id):
		return "already_mounted"
	if rider_downed.is_valid() and bool(rider_downed.call(player_id)):
		return "downed"
	var cid: String = str(creature_of.call(instance_id)) if creature_of.is_valid() else ""
	if cid == "":
		return "unknown_instance"
	if _spec(cid).is_empty():
		return "not_mountable"
	if not owner_of.is_valid() or str(owner_of.call(instance_id)) != player_id:
		return "not_yours"
	if alive.is_valid() and not bool(alive.call(instance_id)):
		return "dead"
	if _ridden.has(instance_id):
		return "occupied"
	if _now() < float(_rested_at.get(instance_id, -INF)):
		return "tired"
	if not _terrain_ok(_spec(cid), instance_id):
		return "terrain"
	var me: Variant = player_pos.call(player_id) if player_pos.is_valid() else null
	var it: Variant = position_of.call(instance_id) if position_of.is_valid() else null
	if not (me is Vector3 and it is Vector3) or not in_reach(me, it):
		return "too_far"
	_riding[player_id] = instance_id
	_ridden[instance_id] = player_id
	_ride_started[player_id] = _now()
	GameBus.mount_changed.emit(player_id, instance_id)
	return ""

## Put `player_id` back on foot because of something that happened to them or the mount (death, despawn,
## release): unlike `dismount`, the rider is told, so a client drops its riding speed.
func force_dismount(player_id: String) -> void:
	if dismount(player_id):
		GameBus.mount_resolved.emit(player_id, "dismount", true, "")

## Host: dismount every rider whose creature is gone, dead or no longer theirs (despawned, released, re-tamed),
## who is downed, whose mount tired (`staminaSeconds`) or who rode onto terrain the mount cannot cross.
func validate_riders() -> void:
	var now := _now()
	for iid: String in _rested_at.keys():
		if now >= float(_rested_at[iid]):
			_rested_at.erase(iid)
	for pid: String in _riding.keys():
		var iid: String = _riding[pid]
		var cid: String = str(creature_of.call(iid)) if creature_of.is_valid() else ""
		var dead := alive.is_valid() and not bool(alive.call(iid))
		var downed := rider_downed.is_valid() and bool(rider_downed.call(pid))
		if cid == "" or dead or downed or not owner_of.is_valid() or str(owner_of.call(iid)) != pid:
			force_dismount(pid)
			continue
		var spec := _spec(cid)
		var stamina := float(spec.get("staminaSeconds", 0.0))
		var ridden := now - float(_ride_started.get(pid, now))
		if stamina > 0.0 and ridden >= stamina:
			force_dismount(pid)
			_rested_at[iid] = now + ridden   # rests as long as it was ridden
		elif not _terrain_ok(spec, iid):
			force_dismount(pid)

## Put `player_id` back on foot. Returns whether they were mounted.
func dismount(player_id: String) -> bool:
	if not _riding.has(player_id):
		return false
	var iid: String = _riding[player_id]
	_riding.erase(player_id)
	_ridden.erase(iid)
	_ride_started.erase(player_id)
	GameBus.mount_changed.emit(player_id, "")
	return true

func _gate(player_id: String) -> bool:
	var now := _now()
	if now - float(_last_intent.get(player_id, -1.0e12)) < INTENT_GAP_SEC:
		return false
	_last_intent[player_id] = now
	return true

func _on_mount_intent(instance_id: String, player_id: String) -> void:

	if player_id == "":
		_last_asked = instance_id   # this machine's own request: the answer will say which creature it was
	if not is_host:
		return
	if player_id == "" and local_player_id.is_valid():
		player_id = str(local_player_id.call())
	if player_id == "":
		return
	var why := "rate_limited" if not _gate(player_id) else mount(player_id, instance_id)
	GameBus.mount_resolved.emit(player_id, "mount", why == "", why)

func _on_dismount_intent(player_id: String) -> void:
	if not is_host:
		return
	if player_id == "" and local_player_id.is_valid():
		player_id = str(local_player_id.call())
	if player_id == "":
		return
	if not _gate(player_id):
		GameBus.mount_resolved.emit(player_id, "dismount", false, "rate_limited")
		return
	var ok := dismount(player_id)
	GameBus.mount_resolved.emit(player_id, "dismount", ok, "" if ok else "not_mounted")

## The mount's death dismounts the rider.
func _on_creature_died(entity_id: String, _position: Vector3, _killer: String, _landing: Vector3) -> void:
	if not is_host:
		return
	var rider := rider_of(entity_id)
	if rider != "":
		force_dismount(rider)

## Damage to the mount throws the rider (a hit that landed; a miss does nothing).
func _on_combat_hit(_attacker_id: String, defender_id: String, outcome: String, damage: float) -> void:
	if not is_host or outcome == "miss" or damage <= 0.0:
		return
	var rider := rider_of(defender_id)
	if rider != "":
		force_dismount(rider)

## The host's own player dying puts them on foot (a remote rider's death is caught by `validate_riders` through
## `rider_downed`; the host's own body is the one that emits `player_died`).
func _on_local_died(_position: Vector3, _killer: String, _landing: Vector3) -> void:
	if is_host and local_player_id.is_valid():
		force_dismount(str(local_player_id.call()))

## Logging out dismounts; the companion stays where it is beside the player.
func _on_player_left(player_id: String) -> void:
	if not is_host:
		return
	dismount(player_id)
	_last_intent.erase(player_id)
