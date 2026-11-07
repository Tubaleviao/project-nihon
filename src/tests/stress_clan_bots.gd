extends Node
## Phase 202 — the `clan` scenario, bot side. Five bots (four clan members and an outsider, bot index 4)
## play the clan loop through their ENet connections: every action is the packet a real client sends
## (`clan_intent`, `chat_intent`, `trade_*_intent`, `block_edit_intent`, `chest_intent`, ...), so the host
## validates it as it would a player's. The only admin command is `/time`, and every use is recorded.
##
## A beat starts when the host's probe (`StressClanProbe`, `<live>` file) shows the last one happened, and
## passes when the host's own record shows this one did. The bots never decide a verdict from what they sent.

const WorldPos := preload("res://src/terrain/world_pos.gd")
const StressClanRules := preload("res://src/tests/stress_clan_rules.gd")

const FOUNDER := 0
const OUTSIDER := 4

var bots: Array = []
var live_path := ""
var out_path := ""
var clan_name := "Stressers"
var beats: Array = []
var admin: Array = []
var done := false

var _t0_ms := 0
var _skipped_s := 0.0
## Wall second the last beat ended: each beat runs from there, so the beats cover the whole run (#571).
var _last_end := 0.0

func _wall_s() -> float:
	return float(Time.get_ticks_msec() - _t0_ms) / 1000.0

func _slice(i: int) -> Node:
	return (bots[i] as Dictionary)["slice"]

## The host probe's latest evidence (`{}` before the first write).
func live() -> Dictionary:
	if live_path == "" or not FileAccess.file_exists(live_path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(live_path))
	return data if data is Dictionary else {}

func _seen(flag: String) -> bool:
	return (live().get("seen", {}) as Dictionary).has(flag)

func _all_ready() -> bool:
	if bots.size() < StressClanRules.MEMBERS + StressClanRules.OUTSIDERS:
		return false
	for i in range(StressClanRules.MEMBERS + StressClanRules.OUTSIDERS):
		if not bool(_slice(i).snapshot_done):
			return false
	return true

## Wait until `cond` is true or `timeout_s` of wall time passed; true when it held.
func _until(cond: Callable, timeout_s: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await get_tree().create_timer(0.25).timeout
	return cond.call()

func _beat(id: String, evidence: String, ok: bool, refusal: String = "") -> void:
	var now := _wall_s()
	var dur := now - _last_end
	_last_end = now
	beats.append(StressClanRules.beat(id, dur, dur, 0.0, evidence, ok, refusal))
	print("[Clan] beat %s %s (%.1f s) %s" % [id, "ok" if ok else "FAIL", dur, evidence])

## Run every beat in order. A failed beat stops the scenario (later beats depend on it).
func run() -> void:
	_t0_ms = Time.get_ticks_msec()
	var ready := await _until(_all_ready, 60.0)
	_beat("join", "5 of 5 bots hold a join snapshot" if ready else "bots without a join snapshot", ready)
	if not ready:
		return _finish()
	# Every bot creates its character (the starting kit: tools to chop and mine with).
	for i in range(bots.size()):
		_slice(i).send_create("Stressbot" + char(97 + i))
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(1.0).timeout
	# found: bot 0 founds the clan by name; the host's clan list is the evidence.
	_slice(FOUNDER).send_clan("found", { "name": clan_name })
	var found := await _until(func(): return _seen("found"), 15.0)
	_beat("found", "host lists clan '%s' (id %s)" % [clan_name, str(live().get("world", {}).get("clan_id", ""))], found)
	if not found:
		return _finish()
	# invite: the founder invites each of the other three by handle.
	for i in range(1, StressClanRules.MEMBERS):
		_slice(FOUNDER).send_clan("invite", { "target": str(_slice(i).claimed_handle) })
		await get_tree().create_timer(0.6).timeout   # past the clan intent interval
	var invited := await _until(func(): return _seen("invites_3"), 6.0)
	# A dropped or rate-limited invite: send it again for whoever the host does not list as invited.
	for _round in range(3):
		if invited:
			break
		var pending: Array = live().get("world", {}).get("invited_ids", [])
		for i in range(1, StressClanRules.MEMBERS):
			if not pending.has(str(_slice(i).claimed_player_id)):
				_slice(FOUNDER).send_clan("invite", { "target": str(_slice(i).claimed_handle) })
				await get_tree().create_timer(0.6).timeout
		invited = await _until(func(): return _seen("invites_3"), 4.0)
	_beat("invite", "host lists %d pending invite(s)" % (live().get("world", {}).get("invited_ids", []) as Array).size(), invited)
	if not invited:
		return _finish()
	# accept: each invitee joins by clan id.
	var clan_id := str(live().get("world", {}).get("clan_id", ""))
	for i in range(1, StressClanRules.MEMBERS):
		_slice(i).send_clan("join", { "id": clan_id })
		await get_tree().create_timer(0.6).timeout
	var full := await _until(func(): return _seen("members_4"), 6.0)
	# A dropped or rate-limited intent leaves a bot out: invite and join again for whoever is not a member yet.
	for _round in range(4):
		if full:
			break
		var member_ids: Array = live().get("world", {}).get("member_ids", [])
		for i in range(1, StressClanRules.MEMBERS):
			if member_ids.has(str(_slice(i).claimed_player_id)):
				continue
			_slice(FOUNDER).send_clan("invite", { "target": str(_slice(i).claimed_handle) })
			await get_tree().create_timer(0.6).timeout
			_slice(i).send_clan("join", { "id": clan_id })
			await get_tree().create_timer(0.6).timeout
		full = await _until(func(): return _seen("members_4"), 4.0)
	_beat("accept", "host clan has %d members" % int(live().get("world", {}).get("members", 0)), full)
	if not full:
		return _finish()
	# work: bots 0-2 mine the top layers, bot 3 digs deeper, so ore and soil grow different skills.
	for i in range(StressClanRules.MEMBERS):
		var at: Dictionary = (bots[i] as Dictionary)["anchor"]
		for k in range(6):
			var depth := 0.5 + float(k) + (4.0 if i == StressClanRules.MEMBERS - 1 else 0.0)
			var pos := WorldPos.normalized({ "chunk": at["chunk"], "local": (at["local"] as Vector3) + Vector3(0.0, -depth, 0.0) })
			_slice(i).send_edit("mine", pos, Vector3.UP)
			await get_tree().create_timer(0.3).timeout
	var differ := await _until(func(): return _seen("skills_differ"), 20.0)
	_beat("work", "host skills: %s" % JSON.stringify(live().get("world", {}).get("skills", {})), differ)
	if not differ:
		return _finish()
	# whisper: bot 0 whispers bot 1 by handle (the chat command, Phase 204).
	_slice(FOUNDER).send_chat("/msg %s hello from the clan" % str(_slice(1).claimed_handle))
	var whispered := await _until(func(): return _seen("whisper"), 10.0)
	_beat("whisper", "host chat holds a whisper line", whispered)
	# trade: bot 0 offers one of the items it holds to bot 1 for nothing; both accept.
	var held: Dictionary = {}
	var inv: Dictionary = live().get("world", {}).get("inventories", {})
	var pid0 := str((live().get("world", {}).get("member_ids", [""]) as Array)[0])
	for pid: Variant in inv.keys():
		if not held.is_empty():
			break
		for k: Variant in (inv[pid] as Dictionary).keys():
			if not str(k).begins_with("_") and int((inv[pid] as Dictionary)[k]) > 0:
				held = { str(k): 1 }
				pid0 = str(pid)
				break
	var giver := _bot_of(pid0)
	var taker := 1 if giver != 1 else 0
	var ids_before: Array = live().get("world", {}).get("trade_ids", [])
	_slice(giver).send_trade("start", { "party_b": str(_slice(taker).claimed_handle) })
	var opened := await _until(func(): return (live().get("world", {}).get("trade_ids", []) as Array).size() > ids_before.size(), 10.0)
	if opened and not held.is_empty():
		var tid := str((live().get("world", {}).get("trade_ids", []) as Array).back())
		_slice(giver).send_trade("propose", { "trade_id": tid, "party": "x", "give": held, "want": {} })
		await get_tree().create_timer(0.6).timeout
		_slice(taker).send_trade("propose", { "trade_id": tid, "party": "x", "give": {}, "want": {} })
		await get_tree().create_timer(0.6).timeout
		_slice(giver).send_trade("accept", { "trade_id": tid, "party": "x" })
		_slice(taker).send_trade("accept", { "trade_id": tid, "party": "x" })
	var traded := await _until(func(): return _seen("trade"), 10.0)
	_beat("trade", "host completed %d trade(s); offered %s" % [int(live().get("world", {}).get("trades", 0)), JSON.stringify(held)], traded)
	# build: bot 0 builds as the clan (`/buildas clan`) and stacks soil beside the dug column.
	var builder := FOUNDER
	_slice(builder).send_chat("/buildas clan")
	await get_tree().create_timer(0.8).timeout
	var at0: Dictionary = (bots[builder] as Dictionary)["anchor"]
	for k in range(3):
		var pos := WorldPos.normalized({ "chunk": at0["chunk"], "local": (at0["local"] as Vector3) + Vector3(4.0, -0.5 + float(k) * 0.5, 0.0) })
		_slice(builder).send_edit("place", pos, Vector3.UP, "Soil")
		await get_tree().create_timer(0.4).timeout
	var built := await _until(func(): return _seen("structure"), 10.0)
	_beat("build", "host lists %d clan structure(s)" % int(live().get("world", {}).get("structures", 0)), built)
	if not built:
		return _finish()
	# chest chain (timed in the chest_clan beat): bot 3 (it holds the Ferrite) walks to the forest, chops, researches, builds a bench and a forge,
	# mills planks, smelts an ingot and crafts a Chest. Every step is a packet the host validates.
	var smith := StressClanRules.MEMBERS - 1
	var smith_pid := str(_slice(smith).claimed_player_id)
	# Trees come with the chunks the bots stream in: wait (up to 400 s: a two-core CI runner builds chunks slowly) until the eight this chain chops are listed.
	await _until(func(): return (live().get("world", {}).get("trees", []) as Array).size() >= 8, 400.0)
	var trees: Array = live().get("world", {}).get("trees", [])
	var goal := Vector2(float((trees[0] as Array)[1]), float((trees[0] as Array)[2]) - 4.0) if not trees.is_empty() else Vector2(16.0, 16.0)
	# The smith carries too much ore to receive wood (50 kg cap): researching smithing first spends 4 Ferrite and
	# leaves the 2 one ingot needs.
	_slice(smith).send_raw({ "type": "research_intent", "tech_id": "TechBasicSmithing" })
	await _until(func(): return _tech(smith_pid, "TechBasicSmithing") == "unlocked", 45.0)
	(bots[smith] as Dictionary)["hold"] = true
	await _walk(smith, goal)
	# An axe breaks after two chops (4 Thornwood): the smith chops two trees, two clan mates chop two more each
	# and hand their wood over through the trade window.
	await _chop(smith, trees, 0, 2)
	for k in range(2):
		var mate := k
		await _chop(mate, trees, 2 + 2 * k, 2)
		var sp := WorldPos.to_scene((bots[smith] as Dictionary)["anchor"], Vector2i.ZERO)
		await _walk(mate, Vector2(sp.x + 2.0, sp.z))
		await _gift(mate, smith, "Thornwood", 4)
	_slice(smith).send_raw({ "type": "research_intent", "tech_id": "TechBasicCarpentry" })
	await _until(func(): return _tech(smith_pid, "TechBasicCarpentry") == "unlocked", 45.0)
	_slice(smith).send_chest("place", { "type": "carpentry bench", "ox": 2.0, "oy": 0.0, "oz": 0.0 })
	await get_tree().create_timer(0.8).timeout
	_slice(smith).send_chest("place", { "type": "forge", "ox": -2.0, "oy": 0.0, "oz": 0.0 })
	await get_tree().create_timer(0.8).timeout
	for rid in ["RecipeThornwoodPlank", "RecipeThornwoodPlank", "RecipeThornwoodPlank", "RecipeFerriteIngot", "RecipeChest"]:
		_slice(smith).send_raw({ "type": "craft_intent", "recipe_id": rid })
		await get_tree().create_timer(0.8).timeout
	var out_home := WorldPos.to_scene((bots[OUTSIDER] as Dictionary)["anchor"], Vector2i.ZERO)
	var made := await _until(func(): return _count(smith_pid, "Chest") > 0, 8.0)
	var chest_ok := false
	var moved := false
	if made:
		for _try in range(2):
			_slice(smith).send_chat("/buildas clan")
			await get_tree().create_timer(1.0).timeout
		_slice(smith).send_chest("place", { "type": "chest", "ox": 0.0, "oy": 0.0, "oz": 2.0 })
		await get_tree().create_timer(1.0).timeout
		_slice(smith).send_chest("use", {})
		await get_tree().create_timer(0.8).timeout
		_slice(smith).send_chest("mode", { "mode": "clan" })
		chest_ok = await _until(func(): return _seen("chest_clan"), 8.0)
		_beat("chest_clan", "host lists a clan chest in access mode clan", chest_ok)
		var pack: Dictionary = live().get("world", {}).get("inventories", {}).get(smith_pid, {})
		var put_item := ""
		for k: Variant in pack.keys():
			if not str(k).begins_with("_") and int(pack[k]) > 0:
				put_item = str(k)
				break
		if put_item != "":
			_slice(smith).send_chest("put", { "item": put_item, "qty": 1 })
		moved = put_item != "" and await _until(func(): return _seen("chest_item"), 8.0)
		_beat("chest_move", "host chest holds %s" % put_item, moved)
		# outsider: bot 4 walks to the chest and tries to open it and take from it.
		(bots[OUTSIDER] as Dictionary)["hold"] = true
		var cp := WorldPos.to_scene((bots[smith] as Dictionary)["anchor"], Vector2i.ZERO)
		await _walk(OUTSIDER, Vector2(cp.x + 1.0, cp.z))
		var n0: int = (live().get("refusals", []) as Array).size()
		_slice(OUTSIDER).send_chest("use", {})
		await get_tree().create_timer(0.8).timeout
		_slice(OUTSIDER).send_chest("take", { "item": put_item, "qty": 1 })
		await _until(func(): return (live().get("refusals", []) as Array).size() > n0, 6.0)
		var okey := _refusal_of(OUTSIDER, n0, "outsider_chest", "chest")
		_beat("outsider_chest", "host refused the non-member at the clan chest" if okey != "" else "no refusal seen", okey != "", okey)
	# dismantle_private: bot 3 builds one private block well outside the clan's circle, then takes it apart.
	var solo := 1
	_slice(solo).send_chat("/buildas private")
	await get_tree().create_timer(0.8).timeout
	var at3: Dictionary = (bots[solo] as Dictionary)["anchor"]
	var far := WorldPos.normalized({ "chunk": at3["chunk"], "local": (at3["local"] as Vector3) + Vector3(-1.0, -0.5, -45.0) })
	_slice(solo).send_edit("place", far, Vector3.UP, "Soil")
	var placed := await _until(func(): return _seen("private"), 8.0)
	if placed:
		_slice(solo).send_edit("mine", WorldPos.normalized({ "chunk": at3["chunk"], "local": (at3["local"] as Vector3) + Vector3(-1.0, 0.0, -45.0) }), Vector3.UP)
	var gone := placed and await _until(func(): return _seen("private_gone"), 8.0)
	_beat("dismantle_private", "host saw a private block placed (%s) and taken apart (%s)" % [str(placed), str(gone)], gone)
	# outsider: bot 4 (no clan) digs one soil, then tries to build on the clan's blocks.
	var out := OUTSIDER
	(bots[out] as Dictionary)["hold"] = true
	await _walk(out, Vector2(out_home.x, out_home.z))   # back beside the clan's structure after the chest beat
	var at4: Dictionary = (bots[out] as Dictionary)["anchor"]
	_slice(out).send_edit("mine", WorldPos.normalized({ "chunk": at4["chunk"], "local": (at4["local"] as Vector3) + Vector3(-4.0, -0.5, 0.0) }), Vector3.UP)
	await get_tree().create_timer(1.0).timeout
	var before: int = (live().get("refusals", []) as Array).size()
	_slice(out).send_edit("place", WorldPos.normalized({ "chunk": at4["chunk"], "local": (at4["local"] as Vector3) + Vector3(4.0, 0.5, 0.0) }), Vector3.UP, "Soil")
	await _until(func(): return (live().get("refusals", []) as Array).size() > before, 6.0)
	var key := _refusal_of(out, before, "outsider_build", "")
	_beat("outsider_build", "host refused the non-member's block on the clan's structure" if key != "" else "no refusal seen", key != "", key)
	print("[Clan] refusals %s" % JSON.stringify(live().get("refusals", [])))
	_finish()

## Bot `i` walks to and chops `count` trees from `trees[first]` on.
func _chop(i: int, trees: Array, first: int, count: int) -> void:
	(bots[i] as Dictionary)["hold"] = true
	for k in range(first, mini(first + count, trees.size())):
		var tr: Array = trees[k]
		await _walk(i, Vector2(float(tr[1]), float(tr[2]) - 3.0))
		_slice(i).send_raw({ "type": "tree_chop_intent", "tree_id": str(tr[0]) })
		await get_tree().create_timer(0.8).timeout

## `giver` hands `qty` of `item` to `taker` through the trade window (start, propose, propose, accept, accept).
func _gift(giver: int, taker: int, item: String, qty: int) -> void:
	var before: Array = live().get("world", {}).get("trade_ids", [])
	_slice(giver).send_trade("start", { "party_b": str(_slice(taker).claimed_handle) })
	await _until(func(): return (live().get("world", {}).get("trade_ids", []) as Array).size() > before.size(), 10.0)
	var ids: Array = live().get("world", {}).get("trade_ids", [])
	if ids.is_empty():
		return
	var tid := str(ids.back())
	_slice(giver).send_trade("propose", { "trade_id": tid, "party": "x", "give": { item: qty }, "want": {} })
	await get_tree().create_timer(0.6).timeout
	_slice(taker).send_trade("propose", { "trade_id": tid, "party": "x", "give": {}, "want": {} })
	await get_tree().create_timer(0.6).timeout
	_slice(giver).send_trade("accept", { "trade_id": tid, "party": "x" })
	_slice(taker).send_trade("accept", { "trade_id": tid, "party": "x" })
	await get_tree().create_timer(1.0).timeout

## Walk bot `i` (held on its anchor) to ground point `goal` (x, z in metres) at 6 m/s, one report-sized step at a time.
func _walk(i: int, goal: Vector2) -> void:
	var bot: Dictionary = bots[i]
	for _step in range(200):
		var anchor: Dictionary = bot["anchor"]
		var here := WorldPos.to_scene(anchor, Vector2i.ZERO)
		var d := goal - Vector2(here.x, here.z)
		if d.length() < 1.0:
			return
		var step := d.normalized() * minf(3.0, d.length())
		var local: Vector3 = anchor["local"]
		bot["anchor"] = WorldPos.normalized({ "chunk": anchor["chunk"], "local": Vector3(local.x + step.x, local.y, local.z + step.y) })
		await get_tree().create_timer(0.5).timeout

## The host's refusal of bot `i` since refusal index `from` for `beat`: a membership key from
## `StressClanRules.REFUSAL_KEYS` when the host gave one, else the last key it gave (which fails the beat's
## verdict). `kind_prefix` keeps only refusals of that kind ("chest" for chest intents, "" for any).
func _refusal_of(i: int, from: int, beat: String, kind_prefix: String) -> String:
	var want: Array = StressClanRules.REFUSAL_KEYS.get(beat, [])
	var last := ""
	for r: Variant in (live().get("refusals", []) as Array).slice(from):
		var d: Dictionary = r
		if str(d.get("who", "")) != str(_slice(i).claimed_player_id) or not str(d.get("kind", "")).begins_with(kind_prefix):
			continue
		var key := str(d.get("key", ""))
		if want.has(key):
			return key
		last = key
	return last

## The host's research status of `tech` for `pid` ("" before it is known).
func _tech(pid: String, tech: String) -> String:
	var techs: Dictionary = live().get("world", {}).get("techs", {})
	return str((techs.get(pid, {}) as Dictionary).get(tech, ""))

func _count(pid: String, item: String) -> int:
	var inv: Dictionary = live().get("world", {}).get("inventories", {})
	return int((inv.get(pid, {}) as Dictionary).get(item, 0))

## The bot index whose host-bound player id is `pid`.
func _bot_of(pid: String) -> int:
	for i in range(bots.size()):
		if str(_slice(i).claimed_player_id) == pid:
			return i
	return 0

func _finish() -> void:
	var f := FileAccess.open(out_path, FileAccess.WRITE) if out_path != "" else null
	if f != null:
		f.store_string(JSON.stringify({ "beats": beats, "admin": admin }))
		f.close()
	done = true
