extends "res://src/tests/test_support.gd"
## Phase 226 — several characters per player at runtime: the account keeps a list of characters, each a record
## of its own; a new one starts from scratch; the limit and server-wide names are the host's; a pre-226 save
## becomes each player's first character; deleting one checks the typed name and hands its things on; the list
## on the wire and on screen.

const CharacterRoster := preload("res://src/character/character_roster.gd")
const RosterView := preload("res://src/character/roster_view.gd")
const CharacterListPanel := preload("res://src/ui/character_list_panel.gd")
const CreationRules := preload("res://src/character/creation_rules.gd")
const AttributeRules := preload("res://src/character/attribute_rules.gd")
const ClanSlice := preload("res://src/clan/clan_slice.gd")
const StructureSlice := preload("res://src/structure/structure_slice.gd")
const ChestSlice := preload("res://src/world/chest_slice.gd")
const I18n := preload("res://src/core/i18n.gd")

const DIR := "user://test_roster_226/"
const AKIRA := { "name": "Akira", "gender": "feminine", "hair": "hair_f_bob", "hairColor": 129 }


func register() -> void:
	_run_test("character roster: the fabric limit, delete policy and refusal keys load, every key in both catalogs", _test_fabric_and_catalog)
	_run_test("character roster: a second character of one player starts from scratch and the first is unchanged", _test_second_character)
	_run_test("character roster: the host refuses a character over the limit and a name another character holds", _test_limit_and_names)
	_run_test("character roster: a pre-226 save makes each player's one character their first, with the same state", _test_legacy_save)
	_run_test("character roster: a later character's id is no account, and a busy account is not handed out", _test_claims)
	_run_test("character roster: delete needs the typed name, frees it, and hands the clan, structures and chests on", _test_delete)
	_run_test("character roster: the table round-trips the world record and drops a hostile one", _test_record)
	_run_test("character roster: the listen host binds its account's chosen, saved or last character", _test_local_bind)
	_run_test("character roster: list actions are rate-limited and wired between the bus and the wire", _test_wire)
	_run_test("character roster: the list screen shows the host's list and sends Play, New and Delete", _test_panel)
	_run_test("character roster: admin follows the account onto every character", _test_admin_by_account)


# ── rig ──────────────────────────────────────────────────────────────────

func _reg() -> PlayerRegistry:
	var reg := PlayerRegistry.new()
	reg.is_authoritative = true
	add_child(reg)
	return reg

## A registry whose lazy loader reads `store` ({ id: record }), as the disk does.
func _store_reg(store: Dictionary) -> PlayerRegistry:
	var reg := _reg()
	reg.set_record_loader(func(pid: String) -> Dictionary: return (store.get(pid, {}) as Dictionary).duplicate(true))
	return reg

## A connection leaves: its record is written to `store` and released, as the host does.
func _leave(reg: PlayerRegistry, store: Dictionary, peer: int) -> String:
	var pid := reg.get_player_id(peer)
	store[pid] = reg.get_player_data(pid)
	reg.unbind_peer(peer)
	_evict_now(reg, pid)
	return pid

func _evict_now(reg: PlayerRegistry, pid: String) -> void:
	var inv: Node = reg._inventories.get(pid, null)
	reg._players.erase(pid)
	reg._inventories.erase(pid)
	if inv != null:
		reg.remove_child(inv)
		inv.free()

func _root(reg: PlayerRegistry) -> Node:
	var gr: Node = (load("res://src/core/game_root.gd") as GDScript).new()
	gr._registry = reg
	var clans := ClanSlice.new()
	clans.registry = reg
	var now := [1000000.0]
	clans.now_sec = func() -> float: return now[0]
	clans.mono_sec = func() -> float: return now[0]
	add_child(clans)
	gr._clans = clans
	var st := StructureSlice.new()
	st.registry = reg
	st.clans = clans
	st.now_hour = func() -> int: return 0
	st.mono_sec = func() -> float: return now[0]
	add_child(st)
	gr._structures = st
	var c := ChestSlice.new()
	c.registry = reg
	c.clans = clans
	c.structures = st
	c.mono_sec = func() -> float: return now[0]
	add_child(c)
	gr._chests = c
	gr._persistence = PersistenceSlice.new()
	gr._persistence.server_save_dir = DIR
	gr._roster_wiring.wire(gr)
	return gr

func _free_root(gr: Node) -> void:
	gr._roster_wiring.close()
	gr._roster_wiring.unwire()
	for n: Node in [gr._chests, gr._structures, gr._clans, gr._persistence, gr._registry]:
		if is_instance_valid(n):
			n.free()
	gr.free()

func _clean_dir() -> void:
	var d := DirAccess.open(DIR)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)

# ── tests ────────────────────────────────────────────────────────────────

func _test_fabric_and_catalog() -> void:
	assert_eq(CharacterRoster.limit(), 4, "the fabric's limit is 4 characters per player per server")
	assert_eq(CharacterRoster.on_delete(), "clan", "a deleted character's structures go to its clan")
	assert_eq(CharacterRoster.refusal_key("limit"), "characters.refuse.limit", "the limit key comes from the fabric")
	assert_eq(CharacterRoster.refusal_key("nameTaken"), "creation.refuse.name_taken", "names keep the creation key")
	var keys: Array = CharacterRoster.refusal_keys()
	for k in ["characters.title", "characters.loading", "characters.none", "characters.new", "characters.play",
			"characters.delete", "characters.unnamed", "characters.body_default", "characters.row",
			"characters.row_never", "characters.delete_confirm", "characters.delete_placeholder", "characters.delete_yes"]:
		keys.append(k)
	var cats: Dictionary = I18n.parse_csv("res://locale/ui.csv")["catalog"]
	for loc in ["en", "pt_BR"]:
		for k: String in keys:
			assert_true(str((cats.get(loc, {}) as Dictionary).get(k, "")).strip_edges() != "", "%s has %s" % [loc, k])


func _test_second_character() -> void:
	var store := {}
	var reg := _store_reg(store)
	var clans := ClanSlice.new()
	clans.registry = reg
	clans.now_sec = func() -> float: return 1000.0
	clans.mono_sec = func() -> float: return 1000.0
	add_child(clans)
	var first := reg.resolve_identity(2, "")
	var account := reg.accounts.get_account(2)
	assert_eq(first, account, "a fresh account's first character takes the account id")
	assert_eq(reg.create_character(first, AKIRA, 0), "", "the first character is created")
	reg.get_inventory(first).add_item("Ferrite", 3)
	reg.record_skills(first, { "Smithing": "journeyman" })
	reg.record_technology(first, { "Bronze": "known" })
	var attrs := AttributeRules.defaults()
	attrs[attrs.keys()[0]] = int(attrs[attrs.keys()[0]]) + 2
	reg.get_record(first)["attributes"] = attrs
	assert_eq(clans.found(first, "Oakhold"), "", "the first character founds a clan")
	_leave(reg, store, 2)
	var before: Dictionary = (store[first] as Dictionary).duplicate(true)

	var made := reg.accounts.create_character(account)
	var second := str(made.get("id", ""))
	assert_true(second != "" and second != first, "the host makes a second character with a fresh id")
	assert_eq(reg.roster.characters_of(account), [first, second], "the account lists both, oldest first")
	reg.accounts.note_character_choice(3, second)
	assert_eq(reg.resolve_identity(3, account), second, "the account enters as the second character")
	assert_eq(reg.accounts.get_account(3), account, "bound under the same account")
	assert_eq(reg.get_inventory(second).get_item_count("Ferrite"), 0, "the second has an empty inventory")
	assert_eq(reg.get_attributes(second), AttributeRules.defaults(), "base attributes")
	assert_eq(reg.get_skill_tier(second, "Smithing"), "", "no skills")
	assert_eq(reg.get_record(second).get("technology", {}), {}, "no research")
	assert_eq(clans.clan_of(second), "", "no clan")
	assert_false(CreationRules.is_created(reg.creation_of(second)), "and goes to the creation screen")
	assert_eq(reg.roster.last_of(account), second, "it is the account's last character")
	_leave(reg, store, 3)
	assert_eq(store[first], before, "the first character's record is unchanged")
	assert_eq(clans.clan_of(first), "clan_1", "and still in its clan")
	# Back with no choice: the last character played; with a choice, the first.
	assert_eq(reg.resolve_identity(4, account), second, "a join with no choice enters the last character")
	_leave(reg, store, 4)
	reg.accounts.note_character_choice(5, first)
	assert_eq(reg.resolve_identity(5, account), first, "and the first when it is chosen")
	assert_eq(reg.get_inventory(first).get_item_count("Ferrite"), 3, "with its own pack")
	assert_eq(reg.get_skill_tier(first, "Smithing"), "journeyman", "and skills")
	clans.free()
	reg.free()


func _test_limit_and_names() -> void:
	var store := {}
	var reg := _store_reg(store)
	var first := reg.resolve_identity(2, "")
	var account := reg.accounts.get_account(2)
	assert_eq(reg.create_character(first, AKIRA, 0), "", "Akira is taken by the first character")
	var others: Array = []
	for i in CharacterRoster.limit() - 1:
		var made := reg.accounts.create_character(account)
		assert_true(made.has("id"), "character %d of %d is made" % [i + 2, CharacterRoster.limit()])
		others.append(str(made.get("id", "")))
	var over := reg.accounts.create_character(account)
	assert_eq(str(over.get("reason", "")), "limit", "one over the limit is refused")
	assert_eq(reg.roster.count_of(account), CharacterRoster.limit(), "and not added")
	var view := reg.accounts.roster_view(account, "create", str(over["reason"]))
	assert_eq(str(view["result"]["reason"]), "characters.refuse.limit", "the list carries the limit's locale key")
	assert_eq(int(view["limit"]), CharacterRoster.limit(), "and the limit")
	# A sibling cannot take its own account's name, nor can another player's character.
	_leave(reg, store, 2)
	reg.accounts.note_character_choice(3, str(others[0]))
	var sibling := reg.resolve_identity(3, account)
	assert_eq(reg.create_character(sibling, { "name": "AKIRA", "gender": "masculine", "hair": "hair_m_crop", "hairColor": 129 }, 10000),
		"name_taken", "a sibling may not reuse the name")
	var stranger := reg.resolve_identity(4, "")
	assert_eq(reg.create_character(stranger, { "name": "Akira", "gender": "feminine", "hair": "hair_f_bob", "hairColor": 129 }, 10000),
		"name_taken", "nor another player's character")
	assert_eq(reg.create_character(stranger, { "name": "Hikari", "gender": "feminine", "hair": "hair_f_bob", "hairColor": 129 }, 20000),
		"", "a free name is accepted")
	assert_eq(reg.accounts.create_character("player_0_0_" + "0".repeat(32)), { "reason": "unknown" }, "an unknown account makes nothing")
	reg.free()


func _test_legacy_save() -> void:
	_clean_dir()
	var p := PersistenceSlice.new()
	p.server_save_dir = DIR
	var src := _reg()
	var a := src.mint_player_id()
	var b := src.mint_player_id()
	src.ensure_player(a)
	src.ensure_player(b)
	assert_eq(src.create_character(a, AKIRA, 0), "", "player A has a character")
	src.get_inventory(a).add_item("Ferrite", 3)
	src.record_skills(b, { "Smithing": "journeyman" })
	src.record_position(b, Vector3(5.0, 6.0, 7.0))
	# Exactly what a pre-226 host wrote: one file per player and a world record with names but no roster.
	var rec_a := src.get_player_data(a)
	var rec_b := src.get_player_data(b)
	p.save_player(a, rec_a)
	p.save_player(b, rec_b)
	var world := { "version": 5, "local_player_id": a, "names": src.names_to_data() }
	src.free()

	var reg := _reg()
	reg.set_record_loader(p.load_player)
	reg.roster.from_data(world.get("roster", {}), reg.looks_like_player_id)
	reg.names_from_data(world["names"])
	assert_eq(reg.roster.account_count(), 0, "a pre-226 world has no roster")
	# A remote player claims their old id: it is their account, and their one character is the first.
	assert_eq(reg.resolve_identity(2, b), b, "player B reconnects to the same id")
	assert_eq(reg.accounts.get_account(2), b, "which is now their account")
	assert_eq(reg.roster.characters_of(b), [b], "with their old character as the first, and only, one")
	assert_eq(reg.get_skill_tier(b, "Smithing"), "journeyman", "its skills unchanged")
	assert_eq(reg.get_player_data(b).get("position", null), rec_b.get("position", null), "and its position")
	assert_eq(reg.accounts.roster_view(b)["characters"].size(), 1, "B's list has one character")
	# The listen host's player: the world record's id is the account, its first character the same id.
	var gr: Node = (load("res://src/core/game_root.gd") as GDScript).new()
	gr._registry = reg
	gr._loaded_world = world
	gr._persistence_wiring.root = gr
	gr._persistence_wiring.bind_local_account()
	assert_eq(reg.local_account, a, "the host's account is the old local id")
	assert_eq(gr._persistence_wiring.local_character(), a, "and its first character the same id")
	var listed: Dictionary = reg.accounts.roster_view(a)["characters"][0]
	assert_eq(str(listed["id"]), a, "A's list shows the old character")
	assert_eq(str(listed["name"]), "Akira", "by its name, read from the record on disk")
	assert_false(reg.has_player(a), "listing did not make the record resident")
	reg.set_local_player(a)
	reg.apply_player_data(a, p.load_player(a))
	assert_eq(reg.get_inventory(a).get_item_count("Ferrite"), 3, "its pack is the same")
	assert_eq(reg.character_name(a), "Akira", "and its name")
	gr.free()
	reg.free()
	p.free()
	_clean_dir()


func _test_claims() -> void:
	var store := {}
	var reg := _store_reg(store)
	var first := reg.resolve_identity(2, "")
	var account := reg.accounts.get_account(2)
	var second := str(reg.accounts.create_character(account)["id"])
	assert_false(reg.accounts.account_claimable(account), "an account in the world is not handed to a second connection")
	assert_true(reg.resolve_identity(3, account) != first, "a second connection claiming it gets a fresh id")
	assert_true(reg.accounts.get_account(3) != account, "and a fresh account")
	_leave(reg, store, 2)
	assert_true(reg.accounts.account_claimable(account), "once it left, it can be claimed")
	assert_false(reg.accounts.account_claimable(second), "a later character's id is no account")
	assert_true(reg.resolve_identity(4, second) != second, "claiming it mints instead")
	# A choice that is not the account's is refused: nothing is bound.
	var heard: Array = []
	var cb := func(peer: int, roster: Dictionary) -> void: heard.append([peer, roster])
	GameBus.character_roster_synced.connect(cb)
	reg.accounts.note_character_choice(5, reg.get_player_id(4))
	assert_eq(reg.resolve_identity(5, account), "", "entering another account's character is refused")
	assert_eq(reg.get_player_id(5), "", "and the connection stays unbound")
	GameBus.character_roster_synced.disconnect(cb)
	assert_eq(heard.size(), 1, "the refusal is sent as the list")
	assert_eq(str(heard[0][1]["result"]["reason"]), "characters.refuse.unknown", "with the unknown key")
	reg.free()


func _test_delete() -> void:
	_clean_dir()
	var store := {}
	var reg := _store_reg(store)
	var gr := _root(reg)
	var first := reg.resolve_identity(2, "")
	var account := reg.accounts.get_account(2)
	reg.create_character(first, AKIRA, 0)
	var friend := reg.resolve_identity(3, "")
	var clans: ClanSlice = gr._clans
	assert_eq(clans.found(first, "Oakhold"), "", "Akira founds a clan")
	assert_eq(clans.invite(first, friend), "", "and invites a friend")
	assert_eq(clans.join(friend, "clan_1"), "", "who joins")
	# Akira's private structure and chest, and a lone character's.
	var st: StructureSlice = gr._structures
	st._structures[901] = { "id": 901, "kind": "private", "owner": first, "builder": first, "cells": {}, "count": 0 }
	gr._chests._locks["c1"] = { "type": "chest", "kind": "private", "owner": first, "mode": "owner", "items": {}, "pos": Vector3.ZERO }
	gr._persistence.save_player(first, reg.get_player_data(first))
	_leave(reg, store, 2)
	var heard: Array = []
	var cb := func(peer: int, roster: Dictionary) -> void: heard.append([peer, roster])
	GameBus.character_roster_synced.connect(cb)
	gr._roster_wiring.now_msec = func() -> int: return 50000
	GameBus.character_roster_intent.emit("delete", { "claimed_id": account, "id": first, "confirm": "Akir" }, 7)
	assert_eq(str(heard[-1][1]["result"]["reason"]), "characters.refuse.confirm", "a name typed wrong is refused")
	assert_eq(int(heard[-1][0]), 7, "the answer goes to the asking peer")
	assert_true(reg.roster.is_character(first), "and nothing is deleted")
	gr._roster_wiring.now_msec = func() -> int: return 100000
	GameBus.character_roster_intent.emit("delete", { "claimed_id": account, "id": first, "confirm": "Akira" }, 7)
	GameBus.character_roster_synced.disconnect(cb)
	assert_eq(str(heard[-1][1]["result"]["reason"]), "", "the right name deletes it")
	assert_eq((heard[-1][1]["characters"] as Array).size(), 0, "the list is empty")
	assert_false(reg.roster.is_character(first), "it left the roster")
	assert_true(reg.roster.has_account(account), "the account stays")
	assert_false(FileAccess.file_exists(gr._persistence.player_path(first)), "its record is gone from disk")
	assert_eq(clans.clan_of(first), "", "it left its clan")
	assert_eq(str(clans.get_clan("clan_1")["founder"]), friend, "the friend founds the clan now")
	assert_eq(str(st._structures[901]["kind"]), "clan", "its structure went to the clan")
	assert_eq(str(st._structures[901]["owner"]), "clan_1", "Oakhold's")
	assert_eq(str(gr._chests._locks["c1"]["owner"]), "clan_1", "and its chest")
	var other := reg.resolve_identity(8, "")
	assert_eq(reg.create_character(other, AKIRA, 0), "", "the name is free again for anyone")
	# A clanless character's structures become ownerless (abandoned).
	st._structures[902] = { "id": 902, "kind": "private", "owner": friend, "builder": friend, "cells": {}, "count": 0 }
	reg.unbind_peer(3)
	_evict_now(reg, friend)
	clans.drop_character(friend)
	gr._roster_wiring.delete_character(friend)
	assert_eq(str(st._structures[902]["owner"]), "", "a clanless character's structure has no owner")
	assert_true(st._abandoned(st._structures[902]), "and decays as an abandoned one")
	assert_true(clans.get_clan("clan_1").is_empty(), "a founder alone disbands the clan")
	# The one in the world cannot be deleted.
	var refusal := reg.accounts.delete_refusal(reg.accounts.get_account(8), other, "Akira")
	assert_eq(refusal, "inPlay", "a character in the world is not deleted")
	_free_root(gr)
	_clean_dir()


func _test_record() -> void:
	var r := CharacterRoster.new()
	var acc := "player_1_1_" + "a".repeat(32)
	var c2 := "player_1_2_" + "b".repeat(32)
	assert_true(r.adopt_legacy(acc), "a legacy id is adopted")
	assert_false(r.adopt_legacy(acc), "once")
	assert_true(r.add_character(acc, c2), "a second character")
	r.note_played(c2, 1700000000)
	var back := CharacterRoster.new()
	back.from_data(JSON.parse_string(JSON.stringify(r.to_data())), PlayerRegistry.looks_like_player_id)
	assert_eq(back.characters_of(acc), [acc, c2], "the list survives the world record")
	assert_eq(back.last_of(acc), c2, "and the last character")
	assert_eq(back.played_at(c2), 1700000000, "and when it was played")
	var hostile := {
		acc: { "characters": [acc, c2, "../etc", 5], "last": "nobody", "played": { "x": 3, c2: -4 } },
		"not_an_id": { "characters": [acc] },
		"player_1_3_" + "c".repeat(32): { "characters": [c2] },   # a character claimed twice keeps its first owner
	}
	back.from_data(hostile, PlayerRegistry.looks_like_player_id)
	assert_eq(back.characters_of(acc), [acc, c2], "bad ids are dropped")
	assert_eq(back.last_of(acc), acc, "an unknown last falls back to the oldest")
	assert_eq(back.played_at(c2), 0, "a negative stamp is dropped")
	assert_false(back.has_account("not_an_id"), "a bad account is dropped")
	assert_eq(back.characters_of("player_1_3_" + "c".repeat(32)), [], "a character cannot be on two accounts")
	var many := {}
	many[acc] = { "characters": [] }
	for i in 10:
		many[acc]["characters"].append("player_2_%d_%s" % [i, "d".repeat(32)])
	back.from_data(many, PlayerRegistry.looks_like_player_id)
	assert_eq(back.count_of(acc), CharacterRoster.limit(), "a list past the limit is cut to it")


func _test_local_bind() -> void:
	var reg := _reg()
	var gr: Node = (load("res://src/core/game_root.gd") as GDScript).new()
	gr._registry = reg
	gr._persistence_wiring.root = gr
	var acc := "player_1_1_" + "a".repeat(32)
	var c2 := "player_1_2_" + "b".repeat(32)
	reg.roster.adopt_legacy(acc)
	reg.roster.add_character(acc, c2)
	gr._loaded_world = { "local_player_id": acc, "local_character": c2 }
	gr._persistence_wiring.bind_local_account()
	assert_eq(gr._persistence_wiring.local_character(), c2, "the saved local character is entered")
	gr._persistence_wiring.chosen_character = acc
	assert_eq(gr._persistence_wiring.local_character(), acc, "a choice on the list wins")
	gr._persistence_wiring.chosen_character = "player_9_9_" + "e".repeat(32)
	assert_eq(gr._persistence_wiring.local_character(), c2, "a choice that is not the account's is ignored")
	reg.roster.remove_character(acc)
	reg.roster.remove_character(c2)
	gr._persistence_wiring.chosen_character = ""
	var fresh: String = gr._persistence_wiring.local_character()
	assert_true(fresh != "" and reg.roster.account_of(fresh) == acc, "with every character deleted, a fresh one")
	# The fresh world: the minted account is its first character.
	var reg2 := _reg()
	gr._registry = reg2
	gr._loaded_world = {}
	gr._persistence_wiring.bind_local_account()
	assert_eq(gr._persistence_wiring.local_character(), reg2.local_account, "a fresh world's player is its first character")
	gr.free()
	reg.free()
	reg2.free()


func _test_wire() -> void:
	var store := {}
	var reg := _store_reg(store)
	var gr := _root(reg)
	reg.resolve_identity(2, "")
	var account := reg.accounts.get_account(2)
	_leave(reg, store, 2)
	var heard: Array = []
	var cb := func(peer: int, roster: Dictionary) -> void: heard.append([peer, roster])
	GameBus.character_roster_synced.connect(cb)
	var t := [0]
	gr._roster_wiring.now_msec = func() -> int: return t[0]
	GameBus.character_roster_intent.emit("list", { "claimed_id": account }, 6)
	assert_eq((heard[-1][1]["characters"] as Array).size(), 1, "an unbound peer lists its account's characters")
	GameBus.character_roster_intent.emit("create", { "claimed_id": account }, 6)
	assert_eq(str(heard[-1][1]["result"]["reason"]), "characters.refuse.rate_limited", "a second action within the gap is refused")
	t[0] = 1000
	GameBus.character_roster_intent.emit("create", { "claimed_id": account }, 6)
	assert_eq(str(heard[-1][1]["result"]["reason"]), "", "after the gap the create goes through")
	assert_true(str(heard[-1][1]["result"]["id"]) != "", "and names the new character")
	t[0] = 2000
	GameBus.character_roster_intent.emit("list", { "claimed_id": "player_0_0_" + "0".repeat(32) }, 9)
	assert_eq(heard[-1][1]["account"], "", "an unknown claim sees no account")
	assert_eq((heard[-1][1]["characters"] as Array).size(), 0, "and no characters")
	GameBus.character_roster_synced.disconnect(cb)
	# The host's route: only the fields each op reads, capped.
	var net := NetworkingSlice.new()
	var got: Array = []
	var cb2 := func(op: String, args: Dictionary, peer: int) -> void: got.append([op, args, peer])
	GameBus.character_roster_intent.connect(cb2)
	gr._roster_wiring.unwire()
	net._m2._route_c2h(11, { "type": "roster_intent", "op": "delete", "claimed_id": "x".repeat(500), "id": "y", "confirm": "z".repeat(500), "inventory": { "Gold": 9 } })
	net._m2._route_c2h(11, { "type": "roster_intent", "op": "grant_admin" })
	GameBus.character_roster_intent.disconnect(cb2)
	assert_eq(got.size(), 1, "an unknown op is dropped")
	assert_eq(got[0][2], 11, "the intent is the sender's")
	assert_eq((got[0][1] as Dictionary).keys().size(), 3, "only claimed_id, id and confirm pass")
	assert_eq(str(got[0][1]["confirm"]).length(), 64, "the typed name is capped")
	# The client's side: a list from the host is sanitized before it reaches the screen.
	var v := RosterView.sanitize({ "account": 5, "characters": [{ "id": "a", "name": "N".repeat(200), "look": "x", "last_played": -3 }, "junk"], "limit": 99, "result": { "op": "create-big", "reason": 7 } })
	assert_eq((v["characters"] as Array).size(), 1, "junk rows are dropped")
	assert_eq(int(v["characters"][0]["last_played"]), 0, "a negative stamp reads as never")
	assert_eq(int(v["limit"]), RosterView.MAX_CHARACTERS, "the limit is capped")
	assert_eq(str(v["result"]["op"]).length(), 8, "the op is capped")
	net.free()
	_free_root(gr)


func _test_panel() -> void:
	var p := CharacterListPanel.new()
	add_child(p)
	var played: Array = []
	var created := [0]
	var deleted: Array = []
	p.play_requested.connect(func(id: String) -> void: played.append(id))
	p.create_requested.connect(func() -> void: created[0] += 1)
	p.delete_requested.connect(func(id: String, c: String) -> void: deleted.append([id, c]))
	p.set_view(RosterView.sanitize({ "account": "acc", "last": "c1", "limit": 2, "characters": [
		{ "id": "c1", "name": "Akira", "look": AKIRA, "last_played": 1700000000, "created": true },
		{ "id": "c2", "name": "", "handle": "p_0123456789abcdef", "look": {}, "last_played": 0 },
	] }))
	var rows: Node = p.find_child("Characters", true, false)
	assert_eq(rows.get_child_count(), 2, "one row per character")
	assert_true(CharacterListPanel.row_text(p.view()["characters"][0]).begins_with("Akira"), "a row starts with the name")
	assert_true(CharacterListPanel.row_text(p.view()["characters"][1]).begins_with(I18n.t("characters.unnamed")), "one never named says so")
	(rows.get_child(0).find_child("Play", true, false) as Button).pressed.emit()
	assert_eq(played, ["c1"], "Play sends the character")
	assert_true((p.find_child("NewCharacter", true, false) as Button).disabled, "New is greyed at the limit")
	p.request_create()
	assert_eq(created[0], 1, "New asks the host")
	(rows.get_child(1).find_child("Delete", true, false) as Button).pressed.emit()
	assert_eq(p.pending_delete(), "c2", "Delete opens the confirmation")
	p.type_confirm("p_0123456789abcdef")
	(p.find_child("ConfirmDelete", true, false) as Button).pressed.emit()
	assert_eq(deleted, [["c2", "p_0123456789abcdef"]], "the typed text goes to the host, which checks it")
	p.set_view(RosterView.sanitize({ "account": "acc", "limit": 2, "characters": [], "result": { "op": "delete", "reason": "characters.refuse.confirm" } }))
	assert_eq(p.status_text(), I18n.t("characters.refuse.confirm"), "a refusal is shown in the reader's locale")
	p.set_view(RosterView.sanitize({ "account": "", "limit": 4, "characters": [] }))
	p.request_create()
	assert_eq(played[-1], "", "with no account yet, New joins and the host makes the first character")
	p.free()


func _test_admin_by_account() -> void:
	var store := {}
	var reg := _store_reg(store)
	reg.resolve_identity(2, "")
	var account := reg.accounts.get_account(2)
	var second := str(reg.accounts.create_character(account)["id"])
	var chat := ChatSlice.new()
	chat.player_registry = reg
	chat._admins[account] = true
	assert_true(chat.is_admin(account), "the account's first character is an admin")
	assert_true(chat.is_admin(second), "and so is every other character of the account")
	assert_false(chat.is_admin(reg.resolve_identity(3, "")), "another player is not")
	chat.free()
	reg.free()
