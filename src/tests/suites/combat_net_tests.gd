extends "res://src/tests/test_support.gd"
## A remote player's melee swing: the client forwards it as `attack_intent` instead of resolving it, the host
## binds the attacker to the connection, checks the swing against its own records and resolves the round.
## Before this, a client's swing never left the client: the host's creature kept its HP and kept hitting back.

const GameRoot := preload("res://src/core/game_root.gd")
const CombatWiring := preload("res://src/battle/combat_wiring.gd")

func register() -> void:
	_run_test("combat net: a client's battle slice forwards its own swing and resolves nothing", _test_client_forwards_swing)
	_run_test("combat net: the host binds a forwarded swing to the sending connection", _test_host_binds_attacker)
	_run_test("combat net: the host resolves a peer's swing in reach and refuses the rest", _test_host_checks_swing)

func _test_client_forwards_swing() -> void:
	var b := BattleSlice.new()
	add_child(b)
	b.is_authoritative = false
	var intents: Array = []
	var resolved: Array = []
	var on_intent := func(iid: String, pid: String) -> void: intents.append([iid, pid])
	var on_resolved := func(r: Dictionary) -> void: resolved.append(r)
	GameBus.attack_intent.connect(on_intent)
	GameBus.combat_round_resolved.connect(on_resolved)
	GameBus.combat_round_requested.emit("player", "c_0_0_ForestBoar_0")
	GameBus.combat_round_requested.emit("ForestBoar", "player")   # a creature's round is never the client's
	GameBus.combat_round_requested.emit("player", "player")
	GameBus.attack_intent.disconnect(on_intent)
	GameBus.combat_round_resolved.disconnect(on_resolved)
	assert_eq(intents, [["c_0_0_ForestBoar_0", ""]], "only the local body's swing at a creature goes out, unnamed")
	assert_true(resolved.is_empty(), "and the client resolves no round of its own")
	assert_true(b._hp_state.is_empty(), "nor tracks any creature HP")
	b.free()

func _test_host_binds_attacker() -> void:
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n._player_ids[5] = "p5"
	var got: Array = []
	var on_intent := func(iid: String, pid: String) -> void: got.append([iid, pid])
	GameBus.attack_intent.connect(on_intent)
	n._route_c2h(5, { "type": "attack_intent", "instance_id": "boar_1", "player_id": "victim" })
	var was_quiet := Diag.quiet
	Diag.quiet = true
	n._route_c2h(6, { "type": "attack_intent", "instance_id": "boar_1" })   # no handshake: dropped
	Diag.quiet = was_quiet
	n._route_c2h(5, { "type": "attack_intent", "instance_id": 42 })          # not a string: dropped
	n._route_c2h(5, { "type": "attack_intent", "instance_id": "x".repeat(500) })
	GameBus.attack_intent.disconnect(on_intent)
	assert_eq(got.size(), 2, "two well-formed swings from the bound peer pass")
	assert_eq(got[0], ["boar_1", "p5"], "the attacker is the connection's player, not the payload's name")
	assert_eq((got[1][0] as String).length(), 64, "an over-long id is cut")
	n.free()

## A host root with a registry (p5 on peer 5), networking (p5 last seen at `at`), a creature slice with one
## chunk's population and the combat wiring.
func _host_rig() -> Dictionary:
	var root: GameRoot = GameRoot.new()
	root._is_client = false
	var reg := PlayerRegistry.new()
	reg.is_authoritative = true
	add_child(reg)
	reg.set_local_player("host")
	reg.ensure_player("p5")
	reg._peer_ids[5] = "p5"
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	var c := CreatureSlice.new()
	add_child(c)
	c.spawn_for_chunk(Vector2i(0, 0))
	root._registry = reg
	root._networking = n
	root._creature = c
	var w: CombatWiring = root._combat_wiring
	w.root = root
	root._peer_wiring.root = root
	return { "root": root, "reg": reg, "n": n, "c": c, "w": w }

func _free_host_rig(r: Dictionary) -> void:
	r["c"].free()
	r["n"].free()
	r["reg"].free()
	r["root"].free()

func _stand_by(r: Dictionary, iid: String, offset: Vector3) -> void:
	var p: Vector3 = r["c"].get_instance_position(iid) + offset
	r["n"].remember_player_state(5, p)

func _test_host_checks_swing() -> void:
	var r := _host_rig()
	var c: CreatureSlice = r["c"]
	var w: CombatWiring = r["w"]
	var ids: Array = c._instances.keys()
	assert_true(ids.size() >= 2, "the rig has creatures to swing at")
	if ids.size() < 2:
		_free_host_rig(r)
		return
	var iid: String = ids[0]
	var rounds: Array = []
	var on_round := func(a: String, d: String) -> void: rounds.append([a, d])
	GameBus.combat_round_requested.connect(on_round)

	assert_false(w.on_attack_intent(iid, "p5"), "a peer the host has never seen move is refused")
	_stand_by(r, iid, Vector3(1.0, 0.0, 0.0))
	assert_true(w.on_attack_intent(iid, "p5"), "a swing in reach is resolved")
	assert_eq(rounds, [["p5", iid]], "as a round with the peer's player id as the attacker")
	assert_false(w.on_attack_intent(iid, "p5"), "a second swing inside the minimum gap is refused")
	w._last_swing_ms.clear()

	_stand_by(r, iid, Vector3(PlayerSlice.ATTACK_RANGE + CombatWiring.ATTACK_REACH_SLACK_M + 1.0, 0.0, 0.0))
	assert_false(w.on_attack_intent(iid, "p5"), "a swing from out of reach (the host's record) is refused")
	_stand_by(r, iid, Vector3(1.0, 0.0, 0.0))
	assert_false(w.on_attack_intent("no_such_creature", "p5"), "an unknown target is refused")
	assert_false(w.on_attack_intent(iid, "p6"), "a player with no connection is refused")
	assert_false(w.on_attack_intent(iid, "player"), "the local body's id is not a peer's swing")
	assert_false(w.on_attack_intent(iid, ""), "nor is a nameless one")

	var tamed: String = ids[1]
	c.mark_tamed(tamed, "p5")
	_stand_by(r, tamed, Vector3(1.0, 0.0, 0.0))
	assert_false(w.on_attack_intent(tamed, "p5"), "a tamed companion is refused")

	_stand_by(r, iid, Vector3(1.0, 0.0, 0.0))
	c._instances[iid]["state"] = "dead"
	assert_false(w.on_attack_intent(iid, "p5"), "a dead creature is refused")
	c._instances[iid]["state"] = "idle"

	r["reg"].record_simulated_hp("p5", 0.0)
	assert_false(w.on_attack_intent(iid, "p5"), "a downed player cannot swing")
	r["reg"].record_simulated_hp("p5", r["reg"].max_hp_of("p5"))

	r["root"]._is_client = true
	assert_false(w.on_attack_intent(iid, "p5"), "a client never resolves a swing")
	r["root"]._is_client = false

	assert_true(w.on_attack_intent(iid, "p5"), "the same swing passes once every check does")
	w.forget_swinger("p5")
	assert_false(w._last_swing_ms.has("p5"), "a departed player's swing clock is dropped")
	GameBus.combat_round_requested.disconnect(on_round)
	assert_eq(rounds.size(), 2, "only the two accepted swings became rounds")
	_free_host_rig(r)
