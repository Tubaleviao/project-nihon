extends "res://src/core/wiring.gd"
## Phase 273 — titles at runtime.
##
## Host / offline: a profession becoming active (`profession_unlocked`) or a skill reaching master
## (`skill_tier_recorded`; every skill of a profession at master also unlocks that profession's mastered title)
## adds titles to the player's record once and emits `title_unlocked`; `title_choose_intent` wears one the player
## holds (or none) and refuses any other. A change goes to the peers that see the player as their look (the
## nameplate) and to the owner as the owner-only `titles` own-state entry. Client: mirrors its own record from
## that entry and shows the "new title" toast. Titles never gate anything: recipe gates read professions.

const TitleRules := preload("res://src/character/title_rules.gd")
const MASTER_TIER := "master"

## This machine's own record as the host last told it (a client).
var _own: Dictionary = TitleRules.sanitize({})
## The reason the host gave for the last choice this machine asked for ("" when it was accepted).
var last_refusal: String = ""

func _connect_all() -> void:
	connect_bus(GameBus.profession_unlocked, _on_profession_unlocked)
	connect_bus(GameBus.skill_tier_recorded, _on_skill_tier_recorded)
	connect_bus(GameBus.title_choose_intent, _on_choose_intent)
	connect_bus(GameBus.player_joined, _on_player_joined)

## This machine's own record: the registry's on a host, the mirror on a client.
func own_record() -> Dictionary:
	if root._is_client:
		return _own.duplicate(true)
	return titles_of(root._registry.local_player_id)

## A player's title record, and storing one.
func titles_of(player_id: String) -> Dictionary:
	return TitleRules.of_record(root._registry.get_record(player_id))

func record_titles(player_id: String, titles: Dictionary) -> void:
	var rec: Dictionary = root._registry.ensure_player(player_id)
	if not rec.is_empty():
		rec["titles"] = TitleRules.sanitize(titles)

func _pid(player_id: String) -> String:
	return root._registry.local_player_id if player_id == "" else player_id

## Host: add `title` to a player's record. True when it was new (the toast and the sync follow).
func unlock(player_id: String, title: String) -> bool:
	if root._is_client or not root._registry.has_player(player_id):
		return false
	var rec: Dictionary = titles_of(player_id)
	if not TitleRules.unlock(rec, title):
		return false
	record_titles(player_id, rec)
	GameBus.title_unlocked.emit(player_id, title)
	_sync_owner(player_id)
	return true

func _on_profession_unlocked(player_id: String, profession: String) -> void:
	if root._is_client or player_id == "":
		return
	for t in TitleRules.for_profession(profession, "active"):
		unlock(player_id, t)

func _on_skill_tier_recorded(player_id: String, skill: String, tier: String) -> void:
	if root._is_client or player_id == "" or tier != MASTER_TIER:
		return
	var t := TitleRules.for_skill_master(skill)
	if t != "":
		unlock(player_id, t)
	var profs := TitleRules.professions_of_skill(skill)
	for p in profs:
		var all_master := true
		for s in profs[p]:
			if str(root._crafting.get_skill_for(player_id, str(s))) != MASTER_TIER:
				all_master = false
				break
		if all_master:
			for mt in TitleRules.for_profession(str(p), "mastered"):
				unlock(player_id, mt)

## Host: unlock the titles a player already earned before titles shipped (or before this load): every
## active profession, and every skill at master (plus the mastered title of a profession whose skills all are).
## Idempotent: a title held already is not announced again. Returns the titles added.
func backfill(player_id: String) -> Array:
	var added: Array = []
	if root._is_client or player_id == "" or not root._registry.has_player(player_id):
		return added
	var seen := func(_p: String, t: String) -> void: added.append(t)
	GameBus.title_unlocked.connect(seen)
	if root._professions != null:
		for p in root._professions.get_unlocked(player_id):
			_on_profession_unlocked(player_id, str(p))
	for skill in TitleRules.master_skill_ids():
		if str(root._crafting.get_skill_for(player_id, skill)) == MASTER_TIER:
			_on_skill_tier_recorded(player_id, skill, MASTER_TIER)
	GameBus.title_unlocked.disconnect(seen)
	return added

func _on_player_joined(_peer_id: int, player_id: String, _reconnected: bool) -> void:
	backfill(player_id)

## Host: wear `title` for the local player ("") or a peer bound to its connection; "" or a refusal code.
func choose(player_id: String, title: String) -> String:
	if root._is_client:
		return "not_host"
	var pid := _pid(player_id)
	if not root._registry.has_player(pid):
		return "not_host"
	var rec: Dictionary = titles_of(pid)
	var reason := TitleRules.choose(rec, title)
	if reason == "":
		record_titles(pid, rec)
		GameBus.player_look_changed.emit(pid, root._registry.look_of(pid))
	if pid != root._registry.local_player_id:
		var peer: int = root._registry.get_peer_id(pid)
		if peer != 0 and root._networking != null and root._networking.is_host():
			root._networking.send_own_state(peer, { "titles": titles_of(pid), "title_result": reason })
	else:
		last_refusal = reason
	return reason

func _on_choose_intent(title: String, player_id: String) -> void:
	if root._is_client:
		return   # forwarded by the networking slice
	choose(player_id, title)

func _sync_owner(player_id: String) -> void:
	if player_id != root._registry.local_player_id:
		root._peer_wiring.sync_peer_own_state({ "success": true, "player_id": player_id })

## Client: the titles part of the join snapshot or an own-state message.
func apply_own(data: Dictionary) -> void:
	if not root._is_client:
		return
	if data.has("titles"):
		_own = TitleRules.sanitize(data["titles"])
	if data.has("title_result"):
		last_refusal = str(data["title_result"]).left(32)
