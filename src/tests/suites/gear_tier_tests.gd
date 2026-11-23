extends "res://src/tests/test_support.gd"
## Phase 229 — skills capped by the gear. A combat ability needs the skill's tier and an equipped weapon of that
## tier; a recipe needs a tool and a crafting station of its tier. Novice is the floor (bare hands, a missing tool
## and another skill's weapon count as novice), the host reads every tier from its own records, and the hotbar,
## skill page and crafting window mark what the gear cannot reach with the tier it needs.

const GameRoot := preload("res://src/core/game_root.gd")
const CombatWiring := preload("res://src/battle/combat_wiring.gd")
const GearTiers := preload("res://src/character/gear_tiers.gd")
const Hotbar := preload("res://src/ui/hotbar.gd")
const I18n := preload("res://src/core/i18n.gd")

const SWORD_ABILITIES := ["executePowerStrike", "executeCounterSlash", "executeWhirlwindBlade"]
const NEW_KEYS := ["combat.refuse.weapon_tier", "combat.refuse.skill_tier", "craft.refuse.tool_tier",
	"craft.refuse.station_tier", "reason.unknown_ability", "ui.skill_page_abilities", "ui.skill_page_ability",
	"ui.skill_page_ability_refused", "ui.tier_novice", "ui.tier_apprentice", "ui.tier_journeyman", "ui.tier_expert",
	"ui.tier_master"]

func register() -> void:
	_run_test("gear tiers: the fabric table loads through GameData (items, stations, recipes, abilities)", _test_table_loads)
	_run_test("gear tiers: master Swordsmanship with a novice sword uses only novice abilities; a master sword all", _test_sword_tiers)
	_run_test("gear tiers: a master recipe needs a master tool and a master station; a refused craft takes nothing", _test_craft_tiers)
	_run_test("gear tiers: the host refuses a peer's ability above its weapon and deals no damage", _test_host_refuses_peer_ability)
	_run_test("gear tiers: a craft intent cannot claim a station tier; the host judges the station it finds", _test_craft_intent_station_from_record)
	_run_test("gear tiers: hotbar, skill page and crafting window mark what the gear cannot reach, with the tier", _test_projections)
	_run_test("gear tiers: refusal and tier labels are keys in en and pt_BR", _test_keys_in_both_locales)
	_run_test("gear tiers: the client's wielded items drop a worn-out weapon, as the host does", _test_wielded_wear)
	_run_test("gear tiers: hotbar and skill page redraw only on the local player's gear change", _test_gear_change_local_only)
	_run_test("gear tiers: a reason code travels as a key with refs that render as reason_text", _test_reason_msg)

func _test_table_loads() -> void:
	var t := GearTiers.table()
	assert_false(t.is_empty(), "GearTiers is in GameData.WORLD_SYSTEMS")
	assert_eq(GearTiers.floor_tier(), "novice", "novice is the floor")
	assert_eq(GearTiers.item_tier("StoneKnife"), "novice", "a stone knife is novice")
	assert_eq(GearTiers.item_tier("VeilsteelLongsword"), "master", "a veilsteel longsword is master")
	assert_eq(GearTiers.item_tier(""), "novice", "bare hands are novice")
	assert_eq(GearTiers.station_tier("master forge"), "master", "the master forge is master")
	assert_eq(GearTiers.station_tier("forge"), "novice", "the forge is novice")
	assert_eq(GearTiers.station_tool("forge"), "hammer", "a forge recipe uses a hammer")
	assert_eq(GearTiers.station_tool("alchemy bench"), "", "an alchemy bench needs no tool")
	assert_eq(str(GearTiers.ability_spec("executeWhirlwindBlade").get("tier", "")), "expert", "an ability's tier comes from its skill rule")
	for rid in GameData.RECIPES:
		var rec: Variant = (GameData.RECIPES[rid] as Resource).get("recipe")
		assert_true(rec is Dictionary and SkillTiers.is_valid_tier(str((rec as Dictionary).get("requiredTier", ""))), "%s has a requiredTier" % rid)

func _test_sword_tiers() -> void:
	for a in SWORD_ABILITIES:
		assert_true(GearTiers.check_ability(a, "master", "StoneKnife").begins_with("combat.refuse.weapon_tier:"),
			"%s is refused with a novice sword at master Swordsmanship" % a)
		assert_eq(GearTiers.check_ability(a, "master", "VeilsteelLongsword"), "", "%s resolves with a master sword" % a)
	assert_eq(GearTiers.check_ability("executePowerStrike", "master", "StoneKnife"), "combat.refuse.weapon_tier:apprentice",
		"the refusal names the tier needed")
	assert_eq(GearTiers.check_ability("executeDisarm", "master", "StoneKnife"), "", "a novice ability needs nothing")
	assert_eq(GearTiers.check_ability("executeDisarm", "novice", ""), "", "not even a weapon")
	assert_eq(GearTiers.check_ability("executePowerStrike", "master", "FerriteShield"), "combat.refuse.weapon_tier:apprentice",
		"another skill's weapon counts as bare hands")
	# A shield worn in the off hand beside a sword still counts for Shieldcraft (and not for Swordsmanship).
	assert_eq(GearTiers.check_ability("executeParry", "master", ["StoneKnife", "FerriteShield"]), "",
		"an apprentice shield in the off hand serves an apprentice Shieldcraft ability")
	assert_eq(GearTiers.check_ability("executePowerStrike", "master", ["FerriteShield", "StoneKnife"]),
		"combat.refuse.weapon_tier:apprentice", "the off-hand shield does not lift Swordsmanship")
	assert_eq(GearTiers.check_ability("executePowerStrike", "novice", "VeilsteelLongsword"),
		"combat.refuse.skill_tier:Swordsmanship:apprentice", "a master sword does not lift the skill")
	assert_eq(GearTiers.check_ability("noSuchAbility", "master", "VeilsteelLongsword"), "unknown_ability", "an unknown ability is refused")

	# The host path: the local player's abilities through CombatWiring.
	var r := _host_rig()
	var w: CombatWiring = r["w"]
	r["reg"].record_skill("host", "Swordsmanship", "master")
	r["reg"].record_equipment("host", { "MainHand": "StoneKnife" })
	var rounds: Array = []
	var on_round := func(a: String, d: String) -> void: rounds.append([a, d])
	GameBus.combat_round_requested.connect(on_round)
	var iid: String = r["c"]._instances.keys()[0]
	_place_player_at(r, iid)
	assert_true(bool(w.on_ability_intent("executeDisarm", iid, "")["success"]), "a novice ability resolves with a novice sword")
	for a in SWORD_ABILITIES:
		var res: Dictionary = w.on_ability_intent(a, iid, "")
		assert_false(bool(res["success"]), "%s is refused by the host with a novice sword" % a)
		assert_true(str(res["reason"]).begins_with("combat.refuse.weapon_tier"), "%s: combat.refuse.weapon_tier" % a)
	assert_eq(rounds.size(), 1, "only the novice ability became a round")
	r["reg"].record_equipment("host", { "MainHand": "VeilsteelLongsword" })
	var inv := InventorySlice.new()   # the host's own pack: a worn-out sword in it counts as bare hands
	add_child(inv)
	r["root"]._inventory = inv
	inv.add_item("VeilsteelLongsword", 1, [0.0])
	r["reg"].record_equipment("host", { "MainHand": "VeilsteelLongsword" })
	assert_eq(w._registry_main_hand("host"), "VeilsteelLongsword", "the worn-out sword is the one wielded")
	assert_true(str(w.on_ability_intent("executePowerStrike", iid, "")["reason"]).begins_with("combat.refuse.weapon_tier"), "a worn-out master sword is no sword")
	inv.consume_items({ "VeilsteelLongsword": 1 })
	r["root"]._inventory = null
	r["reg"].record_equipment("host", { "MainHand": "VeilsteelLongsword" })   # the pack change took the sword off
	inv.free()
	for a in SWORD_ABILITIES:
		var ok_res: Dictionary = w.on_ability_intent(a, iid, "")
		assert_true(bool(ok_res["success"]), "%s resolves with a master sword (%s)" % [a, ok_res["reason"]])
	assert_eq(rounds.size(), 4, "every ability became a round with the master sword")
	GameBus.combat_round_requested.disconnect(on_round)
	_free_host_rig(r)

func _test_craft_tiers() -> void:
	var rig := _craft_rig()
	var craft: StubCrafting = rig["craft"]
	var inv: InventorySlice = rig["inv"]
	var station: StationSlice = rig["station"]
	craft.set_skill("Smithing", "master")
	craft.extra_recipes["TestMasterRecipe"] = _master_recipe("master forge")
	craft.extra_recipes["TestMasterAtForge"] = _master_recipe("forge")
	inv.add_item("FerriteIngot", 4)
	inv.add_item("StoneHammer", 1)
	var master_forge := station.place_station("master forge", Vector3.ZERO)
	var res := craft.craft("TestMasterRecipe")
	assert_false(bool(res["success"]), "a novice hammer at a master forge is refused")
	assert_eq(str(res["reason"]), "craft.refuse.tool_tier:hammer:master", "with craft.refuse.tool_tier and the tier needed")
	assert_eq(inv.get_item_count("FerriteIngot"), 4, "a refused craft takes no materials")
	assert_eq(inv.get_item_count("VeilsteelHammer"), 0, "and makes nothing")

	inv.add_item("VeilsteelHammer", 1)
	station.remove_station(master_forge)
	station.place_station("forge", Vector3.ZERO)
	res = craft.craft("TestMasterAtForge")
	assert_false(bool(res["success"]), "a master hammer at a novice forge is refused")
	assert_eq(str(res["reason"]), "craft.refuse.station_tier:forge:master", "with craft.refuse.station_tier")
	assert_eq(inv.get_item_count("FerriteIngot"), 4, "no materials taken")

	station.place_station("master forge", Vector3(1.0, 0.0, 0.0))
	res = craft.craft("TestMasterRecipe")
	assert_true(bool(res["success"]), "a master hammer at a master forge crafts the master recipe")
	assert_eq(inv.get_item_count("FerriteIngot"), 3, "and takes its inputs")

	# Real fabric: a novice forge recipe needs nothing beyond the forge; a worn-out hammer is no hammer.
	assert_eq(craft._check_gear_gate({ "station": "forge", "requiredTier": "novice" }), "", "a novice recipe needs no tool")
	inv.consume_items({ "VeilsteelHammer": inv.get_item_count("VeilsteelHammer") })
	inv.add_item("VeilsteelHammer", 1, [0.0])
	assert_eq(GearTiers.best_tier_of("hammer", craft.tool_items_of("")), "novice", "a worn-out master hammer does not count")
	_free_craft_rig(rig)

func _test_host_refuses_peer_ability() -> void:
	var r := _host_rig()
	var w: CombatWiring = r["w"]
	var n: NetworkingSlice = r["n"]
	r["reg"].record_skill("p5", "Swordsmanship", "master")
	r["reg"].record_equipment("p5", { "MainHand": "StoneKnife" })
	var iid: String = r["c"]._instances.keys()[0]
	n.remember_player_state(5, r["c"].get_instance_position(iid) + Vector3(1.0, 0.0, 0.0))
	var battle := BattleSlice.new()   # the host's HP book: a refused ability must leave it untouched
	add_child(battle)
	var rounds: Array = []
	var msgs: Array = []
	var on_round := func(a: String, d: String) -> void: rounds.append([a, d])
	var on_msg := func(k: String, args: Array, to: String) -> void: msgs.append([k, args, to])
	GameBus.combat_round_requested.connect(on_round)
	GameBus.system_message.connect(on_msg)
	GameBus.ability_intent.connect(w.on_ability_intent)
	# The wire: the payload's own player id is ignored; the user is the connection's player.
	n._player_ids[5] = "p5"
	n._route_c2h(5, { "type": "ability_intent", "ability": "executeWhirlwindBlade", "instance_id": iid, "player_id": "host" })
	assert_true(rounds.is_empty(), "an ability above the peer's weapon requests no round: no damage")
	assert_false(battle._hp_state.has(iid), "the creature's HP is untouched")
	battle.free()
	assert_eq(msgs.size(), 1, "the peer is told why")
	if msgs.size() == 1:
		assert_eq(msgs[0][0], "combat.refuse.weapon_tier", "as combat.refuse.weapon_tier")
		assert_eq(msgs[0][2], "p5", "to the peer that sent it, not the payload's name")
		assert_eq(I18n.render(I18n.msg(msgs[0][0], msgs[0][1])), I18n.t("combat.refuse.weapon_tier", [I18n.t("ui.tier_expert")]), "naming the tier in the reader's locale")
	r["reg"].record_equipment("p5", { "MainHand": "VeilsteelLongsword" })
	w._last_ability_ms["p5"] = Time.get_ticks_msec()   # pinned: the next intent lands inside the gap however slow the run
	n._route_c2h(5, { "type": "ability_intent", "ability": "executeWhirlwindBlade", "instance_id": iid })
	assert_true(rounds.is_empty(), "an intent right after the last is dropped: a flooding peer is rate limited")
	assert_eq(msgs.size(), 1, "and gets no reply for it")
	w._last_ability_ms["p5"] = Time.get_ticks_msec() - CombatWiring.ATTACK_MIN_INTERVAL_MS
	n._route_c2h(5, { "type": "ability_intent", "ability": "executeWhirlwindBlade", "instance_id": iid })
	assert_eq(rounds, [["p5", iid]], "the same ability with a master sword is a round for the peer")
	GameBus.ability_intent.disconnect(w.on_ability_intent)
	GameBus.combat_round_requested.disconnect(on_round)
	GameBus.system_message.disconnect(on_msg)
	_free_host_rig(r)

func _test_craft_intent_station_from_record() -> void:
	var rig := _craft_rig()
	var craft: StubCrafting = rig["craft"]
	var inv: InventorySlice = rig["inv"]
	var station: StationSlice = rig["station"]
	# A remote crafter: with no registry wired its skills are the floor, so this recipe carries no skill guard
	# (the gear gate is what is under test).
	var rec := _master_recipe("forge")
	rec["skillGuards"] = []
	craft.extra_recipes["TestMasterAtForge"] = rec
	inv.add_item("FerriteIngot", 4)
	inv.add_item("VeilsteelHammer", 1)
	station.place_station("forge", Vector3.ZERO)
	var got: Array = []
	var on_res := func(res: Dictionary) -> void: got.append(res)
	GameBus.craft_resolved.connect(on_res)
	var n := NetworkingSlice.new()
	add_child(n)
	n._role = NetworkingSlice.Role.HOST
	n._player_ids[5] = "p5"
	# A client naming a master station in its intent: the host ignores it and reads its own novice forge.
	n._route_c2h(5, { "type": "craft_intent", "recipe_id": "TestMasterAtForge", "station": "master forge", "station_tier": "master" })
	GameBus.craft_resolved.disconnect(on_res)
	assert_eq(got.size(), 1, "the intent was resolved once")
	if got.size() == 1:
		assert_false(bool(got[0]["success"]), "refused")
		assert_eq(str(got[0]["reason"]), "craft.refuse.station_tier:forge:master", "from the host's record of the forge")
	assert_eq(inv.get_item_count("VeilsteelHammer"), 1, "no item made")
	assert_eq(inv.get_item_count("FerriteIngot"), 4, "nothing taken")
	n.free()
	_free_craft_rig(rig)

func _test_projections() -> void:
	# Hotbar: a skill box whose ability the weapon cannot reach is unavailable and carries the tier.
	var st := Hotbar.skill_box_state("Swordsmanship", "master", "StoneKnife")
	assert_false(bool(st["available"]), "master Swordsmanship with a novice sword: the box is unavailable")
	assert_eq(str(st["ability"]), "executeWhirlwindBlade", "it would fire the highest ability the skill reaches")
	assert_eq(str(st["tier_needed"]), "expert", "and carries the tier needed")
	assert_true(bool(Hotbar.skill_box_state("Swordsmanship", "master", "VeilsteelLongsword")["available"]), "a master sword makes it available")
	var apprentice := Hotbar.skill_box_state("Swordsmanship", "master", "FerriteShortSword")
	assert_true(bool(apprentice["available"]), "an apprentice sword still uses what it reaches")
	assert_eq(str(apprentice["ability"]), "executePowerStrike", "the box fires the highest ability the sword reaches")
	# The drawn bar: the box dims with the weapon and lights when a better one is wielded.
	var bar := Hotbar.new()
	var wield := { "item": "StoneKnife" }
	bar.tier_provider = func() -> Dictionary: return { "Swordsmanship": "master" }
	bar.weapon_provider = func() -> String: return str(wield["item"])
	bar.build()
	bar.slots[0] = "skill:Swordsmanship"
	bar._render()
	var box: Button = bar._buttons[0]
	assert_eq(box.modulate, Hotbar.DIMMED, "a novice sword dims the Swordsmanship box")
	assert_true(box.tooltip_text.contains(I18n.t("combat.refuse.weapon_tier", [I18n.t("ui.tier_expert")])), "its tooltip says the tier needed")
	wield["item"] = "VeilsteelLongsword"
	GameBus.held_item_synced.emit("host", "VeilsteelLongsword")
	assert_eq(box.modulate, Color.WHITE, "wielding a master sword lights it again on the held-item sync")
	bar.free()
	assert_true(bool(Hotbar.skill_box_state("Unarmed", "novice", "")["available"]), "Unarmed needs nothing")
	assert_true(bool(Hotbar.skill_box_state("Smithing", "novice", "")["available"]), "a non-combat skill is never gear-capped")
	# Skill page rows.
	var rows := GearTiers.ability_rows("Swordsmanship", "master", "FerriteShortSword")
	assert_eq(rows.size(), 3, "a row per Swordsmanship ability")
	assert_true(bool(rows[0]["available"]) and str(rows[0]["tier_needed"]) == "", "Power Strike with an apprentice sword")
	assert_false(bool(rows[1]["available"]), "Counter Slash is out of reach of an apprentice sword")
	assert_eq(str(rows[1]["tier_needed"]), "journeyman", "and says journeyman")
	# Crafting window: a card above the held tool or the station carries the tier needed.
	var ui := _new_test_ui()
	var rig := _craft_rig()
	var craft: CraftingSlice = rig["craft"]
	ui.crafting_slice = craft
	ui.inventory_slice = rig["inv"]
	ui.station_slice = rig["station"]
	for sk in ["Smithing", "ArcaneForging", "Enchanting", "Carpentry"]:
		craft.set_skill(sk, "master")
	rig["station"].place_station("arcane forge", Vector3.ZERO)
	var row := _row(ui.crafting_rows(), "RecipeEnchantedAethermiteShard")
	assert_eq(str(row.get("required_tier", "")), "journeyman", "the shard is a journeyman arcane-forge recipe")
	assert_false(bool(row.get("can_craft", true)), "with no hammer it is unavailable")
	assert_eq(str(row.get("reason", "")), "craft.refuse.tool_tier:hammer:journeyman", "refused by the tool tier")
	assert_eq(str(row.get("tier_needed", "")), "journeyman", "and carries the tier needed")
	rig["inv"].add_item("VeilsteelHammer", 1)
	row = _row(ui.crafting_rows(), "RecipeEnchantedAethermiteShard")
	assert_eq(str(row.get("tier_needed", "x")), "", "a master hammer clears the gear refusal")
	assert_eq(str(row.get("reason", "")), "missing_inputs", "and the next rule is the inputs")
	rig["inv"].consume_items({ "VeilsteelHammer": 1 })
	var any_gear := false
	for r: Dictionary in ui.crafting_rows():
		if str(r["reason"]).begins_with("craft.refuse.tool_tier"):
			any_gear = true
			assert_true(SkillTiers.is_valid_tier(str(r["tier_needed"])), "%s carries its tier" % r["id"])
			assert_false(I18n.reason_text(str(r["reason"])).begins_with(I18n.t("reason.unknown", [""]).left(4)), "%s renders" % r["id"])
	assert_true(any_gear, "some recipe at the arcane forge is refused by the tool tier")
	ui.free()
	_free_craft_rig(rig)

func _test_keys_in_both_locales() -> void:
	var cats: Dictionary = I18n.parse_csv("res://locale/ui.csv")["catalog"]
	for k: String in NEW_KEYS:
		for loc in ["en", "pt_BR"]:
			assert_true(str((cats[loc] as Dictionary).get(k, "")) != "", "%s has %s" % [loc, k])
	for kind in ["weapon", "tool", "station"]:
		var key := GearTiers.refusal_key(kind)
		assert_true(NEW_KEYS.has(key), "the fabric's %s refusal %s is in the catalog" % [kind, key])
	for skill in (GearTiers.table()["abilities"] as Dictionary):
		for row: Dictionary in GearTiers.abilities_of(str(skill)):
			for loc in ["en", "pt_BR"]:
				assert_true(str((cats[loc] as Dictionary).get("ui.ability." + str(row["ability"]), "")) != "", "%s names %s" % [loc, row["ability"]])
	var tool_line := I18n.reason_text("craft.refuse.tool_tier:hammer:master")
	assert_true(tool_line.contains(I18n.content("equipment", "hammer")) and not tool_line.contains("⟨"), "the tool refusal names the tool: %s" % tool_line)
	assert_true(tool_line.contains(I18n.t("ui.tier_master")), "and the tier")
	var station_line := I18n.reason_text("craft.refuse.station_tier:forge:master")
	assert_true(station_line.contains(I18n.content("station", "forge")) and not station_line.contains("⟨"), "the station refusal names the station")
	for code in ["craft.refuse.tool_tier:hammer:master", "craft.refuse.station_tier:forge:master", "combat.refuse.weapon_tier:expert",
			"combat.refuse.skill_tier:Swordsmanship:apprentice", "unknown_ability"]:
		assert_false(I18n.reason_text(code).contains(code), "%s renders as text, not the code" % code)

func _test_wielded_wear() -> void:
	var ch := FakeCharacter.new()
	ch.equipment = { "MainHand": "VeilsteelLongsword", "OffHand": "FerriteShield" }
	assert_eq(GearTiers.wielded_items(ch), ["VeilsteelLongsword", "FerriteShield"], "with no pack, the worn set as recorded")
	var inv := InventorySlice.new()
	add_child(inv)
	inv.add_item("VeilsteelLongsword", 1, [0.0])
	inv.add_item("FerriteShield", 1)
	assert_eq(GearTiers.wielded_items(ch, inv), ["", "FerriteShield"], "a worn-out sword is an empty hand")
	ch.held = "VeilsteelLongsword"
	assert_eq(GearTiers.wielded_items(ch, inv)[0], "", "held or worn, a worn-out sword is an empty hand")
	inv.add_item("VeilsteelLongsword", 1)
	assert_eq(GearTiers.wielded_items(ch, inv)[0], "VeilsteelLongsword", "one sword with wear left serves")
	inv.free()
	ch.free()

func _test_gear_change_local_only() -> void:
	var local_fn := func() -> String: return "host"
	assert_true(GearTiers.is_local_change("host", local_fn), "the local player's change")
	assert_false(GearTiers.is_local_change("p9", local_fn), "another player's change")
	assert_true(GearTiers.is_local_change("p9", Callable()), "with no provider every change counts")
	var bar := Hotbar.new()
	var wield := { "item": "StoneKnife" }
	bar.tier_provider = func() -> Dictionary: return { "Swordsmanship": "master" }
	bar.weapon_provider = func() -> String: return str(wield["item"])
	bar.local_player_provider = local_fn
	bar.build()
	bar.slots[0] = "skill:Swordsmanship"
	bar._render()
	var box: Button = bar._buttons[0]
	assert_eq(box.modulate, Hotbar.DIMMED, "a novice sword dims the box")
	wield["item"] = "VeilsteelLongsword"
	GameBus.held_item_synced.emit("p9", "VeilsteelLongsword")
	GameBus.equipment_changed.emit("p9", { "MainHand": "VeilsteelLongsword" })
	assert_eq(box.modulate, Hotbar.DIMMED, "another player's gear change does not redraw the bar")
	GameBus.held_item_synced.emit("host", "VeilsteelLongsword")
	assert_eq(box.modulate, Color.WHITE, "the local player's does")
	bar.free()

func _test_reason_msg() -> void:
	for code in ["craft.refuse.tool_tier:hammer:master", "craft.refuse.station_tier:forge:master", "combat.refuse.weapon_tier:expert",
			"combat.refuse.skill_tier:Swordsmanship:apprentice", "unknown_ability", "station_required:forge"]:
		var m := I18n.reason_msg(code)
		assert_eq(I18n.render(m), I18n.reason_text(code), "%s: the wire form renders as reason_text" % code)
	assert_eq(str(I18n.reason_msg("unknown_ability")["key"]), "reason.unknown_ability", "a plain head is a reason.<code> key")
	assert_eq(str(I18n.reason_msg("combat.refuse.weapon_tier:expert")["key"]), "combat.refuse.weapon_tier", "a dotted head is its own key")
	for code in ["craft.refuse.tool_tier:hammer:master", "combat.refuse.weapon_tier:expert"]:
		assert_false(I18n.reason_text(code).contains("a " + I18n.t("ui.tier_expert")) or I18n.reason_text(code).contains("a " + I18n.t("ui.tier_master")),
			"%s puts no article before the tier" % code)

# ── rigs ─────────────────────────────────────────────────────────────────

## The few CharacterSlice reads `GearTiers.wielded_items` makes, for one local character.
class FakeCharacter extends Node:
	var held := ""
	var equipment: Dictionary = {}

	func get_player_character() -> String:
		return "c1"

	func held_item_of(_char_id: String) -> String:
		return held

	func get_equipment_set(_char_id: String) -> Dictionary:
		return equipment

func _master_recipe(station: String) -> Dictionary:
	return { "domain": "smithing", "station": station, "requiredTier": "master",
		"inputs": [{ "item": "FerriteIngot", "quantity": 1 }], "outputs": [{ "item": "VeilsteelHammer", "quantity": 1 }],
		"skillGuards": [{ "skill": "Smithing", "tier": "master" }] }

func _row(rows: Array, id: String) -> Dictionary:
	for r: Dictionary in rows:
		if str(r["id"]) == id:
			return r
	return {}

## A crafting slice that also knows the suite's own recipes: the fabric has no recipe above its station's
## tier, so the station-tier gate is proven with recipes named here, read before GameData.RECIPES.
class StubCrafting extends CraftingSlice:
	var extra_recipes: Dictionary = {}

	func get_recipe(recipe_id: String) -> Dictionary:
		if extra_recipes.has(recipe_id):
			return extra_recipes[recipe_id]
		return super.get_recipe(recipe_id)

func _craft_rig() -> Dictionary:
	var inv := InventorySlice.new()
	add_child(inv)
	inv._max_slots = 1000
	inv._max_weight = 1000000.0
	var craft := StubCrafting.new()
	add_child(craft)
	var station := StationSlice.new()
	add_child(station)
	craft.inventory_slice = inv
	craft.station_slice = station
	station.set_player_position(Vector3.ZERO)
	return { "inv": inv, "craft": craft, "station": station }

func _free_craft_rig(rig: Dictionary) -> void:
	for k in ["inv", "craft", "station"]:
		rig[k].free()

## A host root with a registry ("host" local, p5 on peer 5), networking, a creature slice with one chunk's
## population, a local player body and the combat wiring.
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
	var p := PlayerSlice.new()   # not in the tree: no body, so it stands at the world origin
	root._registry = reg
	root._networking = n
	root._creature = c
	root._player = p
	var w: CombatWiring = root._combat_wiring
	w.root = root
	root._peer_wiring.root = root
	root._held_item_wiring.root = root
	return { "root": root, "reg": reg, "n": n, "c": c, "w": w, "p": p }

## Move the creature beside the local player (who stands at the origin).
func _place_player_at(r: Dictionary, iid: String) -> void:
	r["c"].set_instance_position(iid, Vector3(1.0, 0.0, 0.0))

func _free_host_rig(r: Dictionary) -> void:
	r["p"].free()
	r["c"].free()
	r["n"].free()
	r["reg"].free()
	r["root"].free()
