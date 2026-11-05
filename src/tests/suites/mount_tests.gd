extends "res://src/tests/test_support.gd"
## Phase 216 — mounts: the host refuses someone else's companion, a wild creature, a dead one and one out of
## reach, each with a key; a valid mount is recorded and announced; the accepted speed is the fabric factor times
## walking speed; the mount's death and the rider's logout dismount; every refusal key is in the catalog.

const MountSlice := preload("res://src/creature/mount_slice.gd")
const I18n := preload("res://src/core/i18n.gd")

const SPEC := { "speedFactor": 2.0, "staminaSeconds": 0, "terrain": ["ground"], "riderOffset": [0, 0.8, 0] }

var _changes: Array = []
var _resolved: Array = []
var _creatures: Dictionary = {}

func register() -> void:
	_run_test("mount: refusals carry a key (wild, someone else's, dead, far, ridden, not mountable)", _test_mount_refusals)
	_run_test("mount: a valid mount is recorded, announced and puts the rider on the creature", _test_mount_success)
	_run_test("mount: the accepted speed is the fabric factor times walking speed", _test_mount_speed)
	_run_test("mount: the mount's death and the rider's logout each dismount", _test_mount_dismounts)
	_run_test("mount: forced dismounts tell the rider", _test_mount_forced_dismount)
	_run_test("mount: the intents answer with mount_resolved and are rate limited", _test_mount_intents)
	_run_test("mount: a client reporting more than the mounted speed is clamped by the host", _test_mount_clamp)
	_run_test("mount: the shipped fabric declares a mount on a tameable creature", _test_mount_fabric)
	_run_test("mount: every refusal key is in both catalog columns", _test_mount_catalog)

func _rig() -> Node:
	_changes = []
	_resolved = []
	# instance -> { creature, owner, alive, pos }
	_creatures = {
		"w1": { "creature": "Horse", "owner": "p1", "alive": true, "pos": Vector3(1, 0, 0) },
		"w2": { "creature": "Horse", "owner": "p2", "alive": true, "pos": Vector3(1, 0, 0) },
		"w3": { "creature": "Horse", "owner": "", "alive": true, "pos": Vector3(1, 0, 0) },
		"w4": { "creature": "Horse", "owner": "p1", "alive": false, "pos": Vector3(1, 0, 0) },
		"w5": { "creature": "Horse", "owner": "p1", "alive": true, "pos": Vector3(50, 0, 0) },
		"w6": { "creature": "Mouse", "owner": "p1", "alive": true, "pos": Vector3(1, 0, 0) },
	}
	var m: Node = MountSlice.new()
	m.creature_of = func(i: String) -> String: return str(_creatures.get(i, {}).get("creature", ""))
	m.owner_of = func(i: String) -> String: return str(_creatures.get(i, {}).get("owner", ""))
	m.alive = func(i: String) -> bool: return bool(_creatures.get(i, {}).get("alive", false))
	m.position_of = func(i: String) -> Variant: return _creatures.get(i, {}).get("pos", null)
	m.player_pos = func(_p: String) -> Variant: return Vector3.ZERO
	m.spec_of = func(c: String) -> Dictionary: return SPEC if c == "Horse" else {}
	var t := [0.0]
	m.mono_sec = func() -> float: return t[0]
	m.set_meta("clock", t)
	add_child(m)
	GameBus.mount_changed.connect(_on_changed)
	GameBus.mount_resolved.connect(_on_resolved)
	return m

func _drop(m: Node) -> void:
	GameBus.mount_changed.disconnect(_on_changed)
	GameBus.mount_resolved.disconnect(_on_resolved)
	m.free()

func _on_changed(pid: String, iid: String) -> void:
	_changes.append([pid, iid])

func _on_resolved(pid: String, action: String, ok: bool, reason: String) -> void:
	_resolved.append([pid, action, ok, reason])

func _test_mount_refusals() -> void:
	var m := _rig()
	assert_eq(m.mount("p1", "nobody"), "unknown_instance", "an unknown creature")
	assert_eq(m.mount("p1", "w6"), "not_mountable", "a creature with no mount field")
	assert_eq(m.mount("p1", "w3"), "not_yours", "a wild creature")
	assert_eq(m.mount("p1", "w2"), "not_yours", "someone else's companion")
	assert_eq(m.mount("p1", "w4"), "dead", "a dead companion")
	assert_eq(m.mount("p1", "w5"), "too_far", "a companion out of reach")
	assert_eq(m.mount("", "w1"), "unknown_player", "no player")
	assert_true(MountSlice.in_reach(Vector3(0, 12, 0), Vector3(1, 5, 0)), "a few metres of height difference is within reach")
	assert_false(MountSlice.in_reach(Vector3(0, 40, 0), Vector3(1, 5, 0)), "a creature far below is out of reach")
	assert_eq(m.mounted_instance("p1"), "", "nothing was recorded")
	assert_true(_changes.is_empty(), "no change was announced")
	for reason in ["unknown_instance", "not_mountable", "not_yours", "dead", "too_far"]:
		assert_true(MountSlice.REASONS.has(reason), "%s is a declared reason" % reason)
	_drop(m)

func _test_mount_success() -> void:
	var m := _rig()
	assert_eq(m.mount("p1", "w1"), "", "a valid mount succeeds")
	assert_eq(m.mounted_instance("p1"), "w1", "the rider is on the creature")
	assert_eq(m.rider_of("w1"), "p1", "the creature has its rider")
	assert_eq(_changes, [["p1", "w1"]], "the change is announced for other peers")
	assert_eq(m.rider_position("p1"), Vector3(1, 0.8, 0), "the rider sits at the fabric offset")
	assert_eq(m.mount("p1", "w1"), "already_mounted", "a second mount is refused")
	_creatures["w7"] = { "creature": "Horse", "owner": "p3", "alive": true, "pos": Vector3(1, 0, 0) }
	assert_eq(m.mount("p3", "w1"), "not_yours", "a ridden creature of another owner is not theirs")
	_creatures["w1"]["owner"] = "p3"
	assert_eq(m.mount("p3", "w1"), "occupied", "a creature already ridden is refused")
	assert_true(m.dismount("p1"), "dismount reports it was mounted")
	assert_false(m.dismount("p1"), "a second dismount does nothing")
	assert_eq(_changes.back(), ["p1", ""], "the dismount is announced")
	_drop(m)

func _test_mount_speed() -> void:
	var m := _rig()
	assert_eq(m.accepted_speed("p1", 4.5), 4.5, "on foot the walking speed")
	m.mount("p1", "w1")
	assert_eq(m.accepted_speed("p1", 4.5), 9.0, "mounted: the factor times the walking speed")
	assert_eq(m.speed_factor("p2"), 1.0, "another player is unaffected")
	m.dismount("p1")
	assert_eq(m.accepted_speed("p1", 4.5), 4.5, "dismounted: back to walking")
	_drop(m)

func _test_mount_dismounts() -> void:
	var m := _rig()
	m.mount("p1", "w1")
	GameBus.creature_died.emit("w1", Vector3.ZERO, "p9", Vector3.ZERO)
	assert_false(m.is_mounted("p1"), "the mount's death dismounts the rider")
	_creatures["w1"]["owner"] = "p1"
	m.mount("p1", "w1")
	GameBus.player_left.emit("p1")
	assert_false(m.is_mounted("p1"), "logging out dismounts")
	assert_eq(m.rider_of("w1"), "", "the companion is left free beside the player")
	_drop(m)

func _test_mount_intents() -> void:
	var m := _rig()
	GameBus.mount_intent.emit("w3", "p1")
	assert_eq(_resolved.back(), ["p1", "mount", false, "not_yours"], "a refusal is answered with its key")
	GameBus.mount_intent.emit("w1", "p1")
	assert_eq(_resolved.back(), ["p1", "mount", false, "rate_limited"], "an intent in the same instant is rate limited")
	(m.get_meta("clock") as Array)[0] = 1.0
	GameBus.mount_intent.emit("w1", "p1")
	assert_eq(_resolved.back(), ["p1", "mount", true, ""], "a later valid intent succeeds")
	(m.get_meta("clock") as Array)[0] = 2.0
	GameBus.dismount_intent.emit("p1")
	assert_eq(_resolved.back(), ["p1", "dismount", true, ""], "the dismount intent is answered")
	GameBus.mount_intent.emit("w1", "")
	assert_eq(_resolved.size(), 4, "an intent with no player is ignored")
	_drop(m)

func _test_mount_forced_dismount() -> void:
	var m := _rig()
	m.mount("p1", "w1")
	_creatures.erase("w1")
	m.validate_riders()
	assert_false(m.is_mounted("p1"), "a despawned mount dismounts the rider")
	assert_eq(_resolved.back(), ["p1", "dismount", true, ""], "the rider is told")
	_creatures["w2"]["owner"] = "p1"
	m.mount("p1", "w2")
	_creatures["w2"]["owner"] = ""
	m.validate_riders()
	assert_false(m.is_mounted("p1"), "a released companion dismounts the rider")
	_creatures["w2"]["owner"] = "p1"
	m.mount("p1", "w2")
	m.local_player_id = func() -> String: return "p1"
	GameBus.player_died.emit(Vector3.ZERO, "", Vector3.ZERO)
	assert_false(m.is_mounted("p1"), "the local player's death dismounts")
	_creatures["w2"]["owner"] = "p1"
	m.mount("p1", "w2")
	GameBus.combat_hit_resolved.emit("p2", "w2", "miss", 0.0)
	assert_true(m.is_mounted("p1"), "a miss does not throw the rider")
	GameBus.combat_hit_resolved.emit("p2", "w2", "hit", 3.0)
	assert_false(m.is_mounted("p1"), "damage to the mount dismounts the rider")
	_creatures["w2"]["owner"] = "p1"
	m.mount("p1", "w2")
	# A listen host ignores other players' answers.
	GameBus.mount_resolved.emit("p9", "mount", true, "")
	assert_false(m._local_mounted, "another player's answer leaves this machine's state alone")
	_drop(m)

func _test_mount_clamp() -> void:
	var m := _rig()
	m.mount("p1", "w1")
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n.set_transport(MemoryTransport.new([5]))
	# The host's cap for the rider: the mount's factor times the walking speed (4.5 m/s here).
	n.peer_speed_cap = func(_peer: int) -> float: return m.accepted_speed("p1", 4.5)
	n._route_c2h(5, { "type": "player_moved", "position": [0.0, 2.0, 0.0] })
	n._route_c2h(5, { "type": "player_moved", "position": [500.0, 2.0, 0.0] })
	var at: Vector3 = n.get_last_known_state(5)
	assert_true(at.x <= 9.0 * NetworkingSlice.NetPart2.SPEED_BUDGET_SECONDS + 0.5, "a report far above the mounted speed is clamped (got %s)" % at)
	assert_true(at.x > 4.5 * NetworkingSlice.NetPart2.SPEED_BUDGET_SECONDS, "the mounted budget is the factor times the walking budget (got %s)" % at)
	n.free()
	_drop(m)

func _test_mount_fabric() -> void:
	var found := 0
	for cid in GameData.CREATURES:
		var spec := MountSlice.fabric_spec(str(cid))
		if spec.is_empty():
			continue
		found += 1
		assert_true(float(spec.get("speedFactor", 0.0)) > 1.0, "%s: the mount factor is above 1" % cid)
		var tame: Variant = (GameData.CREATURES[cid] as Resource).get("tame")
		assert_true(tame is Dictionary and not (tame as Dictionary).is_empty(), "%s: a mount sits on a tameable creature" % cid)
	assert_true(found >= 1, "at least one creature is mountable")

func _test_mount_catalog() -> void:
	for reason in MountSlice.REASONS:
		var key := "mount.refused.%s" % reason
		assert_true(I18n.has_key(key) and I18n.t(key) != key and I18n.t(key).length() > 4, "%s has text" % key)
