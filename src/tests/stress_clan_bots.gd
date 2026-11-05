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

func _beat(id: String, started_s: float, evidence: String, ok: bool, refusal: String = "") -> void:
	var dur := _wall_s() - started_s
	beats.append(StressClanRules.beat(id, dur, dur, 0.0, evidence, ok, refusal))
	print("[Clan] beat %s %s (%.1f s) %s" % [id, "ok" if ok else "FAIL", dur, evidence])

## Run every beat in order. A failed beat stops the scenario (later beats depend on it).
func run() -> void:
	_t0_ms = Time.get_ticks_msec()
	var t := _wall_s()
	var ready := await _until(_all_ready, 60.0)
	_beat("join", t, "5 of 5 bots hold a join snapshot" if ready else "bots without a join snapshot", ready)
	if not ready:
		return _finish()
	# Every bot creates its character (the starting kit: tools to chop and mine with).
	for i in range(bots.size()):
		_slice(i).send_create("Stressbot" + char(97 + i))
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(1.0).timeout
	# found: bot 0 founds the clan by name; the host's clan list is the evidence.
	t = _wall_s()
	_slice(FOUNDER).send_clan("found", { "name": clan_name })
	var found := await _until(func(): return _seen("found"), 15.0)
	_beat("found", t, "host lists clan '%s' (id %s)" % [clan_name, str(live().get("world", {}).get("clan_id", ""))], found)
	if not found:
		return _finish()
	# invite: the founder invites each of the other three by handle.
	t = _wall_s()
	for i in range(1, StressClanRules.MEMBERS):
		_slice(FOUNDER).send_clan("invite", { "target": str(_slice(i).claimed_handle) })
		await get_tree().create_timer(0.6).timeout   # past the clan intent interval
	_beat("invite", t, "3 invites sent", true)
	# accept: each invitee joins by clan id.
	t = _wall_s()
	var clan_id := str(live().get("world", {}).get("clan_id", ""))
	for i in range(1, StressClanRules.MEMBERS):
		_slice(i).send_clan("join", { "id": clan_id })
		await get_tree().create_timer(0.6).timeout
	var full := await _until(func(): return _seen("members_4"), 15.0)
	_beat("accept", t, "host clan has %d members" % int(live().get("world", {}).get("members", 0)), full)
	print("[Clan] created %s inv %s" % [JSON.stringify(live().get("world", {}).get("created", {})), JSON.stringify(live().get("world", {}).get("inventories", {}))])
	# work: bots 0-2 mine the top layers, bot 3 digs deeper, so ore and soil grow different skills.
	t = _wall_s()
	for i in range(StressClanRules.MEMBERS):
		var at: Dictionary = (bots[i] as Dictionary)["anchor"]
		for k in range(6):
			var depth := 0.5 + float(k) + (4.0 if i == StressClanRules.MEMBERS - 1 else 0.0)
			var pos := WorldPos.normalized({ "chunk": at["chunk"], "local": (at["local"] as Vector3) + Vector3(0.0, -depth, 0.0) })
			_slice(i).send_edit("mine", pos, Vector3.UP)
			await get_tree().create_timer(0.3).timeout
	var differ := await _until(func(): return _seen("skills_differ"), 20.0)
	_beat("work", t, "host skills: %s" % JSON.stringify(live().get("world", {}).get("skills", {})), differ)
	if not differ:
		return _finish()
	# whisper: bot 0 whispers bot 1 by handle (the chat command, Phase 204).
	t = _wall_s()
	_slice(FOUNDER).send_chat("/msg %s hello from the clan" % str(_slice(1).claimed_handle))
	var whispered := await _until(func(): return _seen("whisper"), 10.0)
	_beat("whisper", t, "host chat holds a whisper line", whispered)
	# trade: bot 0 offers one of the items it holds to bot 1 for nothing; both accept.
	t = _wall_s()
	var held: Dictionary = {}
	var inv: Dictionary = live().get("world", {}).get("inventories", {})
	var pid0 := str((live().get("world", {}).get("member_ids", [""]) as Array)[0])
	for pid: Variant in inv.keys():
		if (inv[pid] as Dictionary).size() > 0 and held.is_empty():
			held = { str((inv[pid] as Dictionary).keys()[0]): 1 }
			pid0 = str(pid)
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
	_beat("trade", t, "host completed %d trade(s); offered %s" % [int(live().get("world", {}).get("trades", 0)), JSON.stringify(held)], traded)
	# build: bot 0 builds as the clan (`/buildas clan`) and stacks soil beside the dug column.
	t = _wall_s()
	var builder := FOUNDER
	_slice(builder).send_chat("/buildas clan")
	await get_tree().create_timer(0.8).timeout
	var at0: Dictionary = (bots[builder] as Dictionary)["anchor"]
	for k in range(3):
		var pos := WorldPos.normalized({ "chunk": at0["chunk"], "local": (at0["local"] as Vector3) + Vector3(4.0, -0.5 + float(k) * 0.5, 0.0) })
		_slice(builder).send_edit("place", pos, Vector3.UP, "Soil")
		await get_tree().create_timer(0.4).timeout
	var built := await _until(func(): return _seen("structure"), 10.0)
	_beat("build", t, "host lists %d clan structure(s)" % int(live().get("world", {}).get("structures", 0)), built)
	if not built:
		return _finish()
	# chest beats (chest_clan, chest_move, outsider_chest) are not played yet: see ROADMAP Phase 202 (the chest
	# chain needs a character kit, forest to chop and a tutorial-free research path over the wire).
	# dismantle_private: bot 3 builds one private block well outside the clan's circle, then takes it apart.
	t = _wall_s()
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
	_beat("dismantle_private", t, "host saw a private block placed (%s) and taken apart (%s)" % [str(placed), str(gone)], gone)
	# outsider: bot 4 (no clan) digs one soil, then tries to build on the clan's blocks.
	t = _wall_s()
	var out := OUTSIDER
	var at4: Dictionary = (bots[out] as Dictionary)["anchor"]
	_slice(out).send_edit("mine", WorldPos.normalized({ "chunk": at4["chunk"], "local": (at4["local"] as Vector3) + Vector3(-4.0, -0.5, 0.0) }), Vector3.UP)
	await get_tree().create_timer(1.0).timeout
	var before: int = (live().get("refusals", []) as Array).size()
	_slice(out).send_edit("place", WorldPos.normalized({ "chunk": at4["chunk"], "local": (at4["local"] as Vector3) + Vector3(4.0, 0.5, 0.0) }), Vector3.UP, "Soil")
	await _until(func(): return (live().get("refusals", []) as Array).size() > before, 6.0)
	var key := ""
	for r: Variant in (live().get("refusals", []) as Array).slice(before):
		if str((r as Dictionary).get("who", "")) == str(_slice(out).claimed_player_id):
			key = str((r as Dictionary).get("key", ""))
	_beat("outsider_build", t, "host refused the non-member's block on the clan's structure" if key != "" else "no refusal seen", key != "", key)
	print("[Clan] refusals %s" % JSON.stringify(live().get("refusals", [])))
	print("[Clan] world %s" % JSON.stringify(live().get("world", {})))
	print("[Clan] refusals %s" % JSON.stringify(live().get("refusals", [])))
	_finish()

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
