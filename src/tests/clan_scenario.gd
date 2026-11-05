extends RefCounted
## Phase 202 — the clan loop scenario's driver. `stress_bots.gd` owns the five bot connections and
## calls `step()` every frame with the bots and its clock; the driver plays one beat at a time over
## the bots' own ENet links and judges each from what the HOST sent back (`clan_view`,
## `clan_result`, chat lines), never from what a bot did. The beats and the verdict live in
## `clan_scenario_rules.gd`.
##
## Bot 0 founds the clan, bots 1-3 are invited and join, bot 4 stays outside.

const Rules := preload("res://src/tests/clan_scenario_rules.gd")

const CLAN_NAME := "Stress Clan"
const BEAT_TIMEOUT_S := 30.0
const WHISPER_TEXT := "stress whisper"

var beats: Array = []
var done := false
var _index := 0
var _beat_start_s := 0.0
var _sent := false
var _started := -1
## Per-beat scratch.
var _mark := 0
var _clock := 0.0
var _mark2 := 0
var _soil_before := 0
var _soil_mid := 0
var _xp_before := 0.0
var _marks_seen := 0
var _refusals: Array = []
var _trade_id := ""
var _next_send_s := 0.0
var _invite_again_s := [0.0, 0.0, 0.0, 0.0, 0.0]
## The host limits each player to one clan intent per `ClanSlice.INTENT_INTERVAL`; space them wider.
const SEND_GAP_S := 0.4

## Beat ids this driver plays today; the rest of `Rules.BEATS` report `not_implemented`.
static func implemented() -> Array:
	return ["found", "invite_accept", "work", "see_skills", "whisper", "trade", "build", "dismantle", "outsider"]

func step(bots: Array, clock_s: float) -> void:
	if done:
		return
	if bots.size() < Rules.BOT_COUNT:
		_finish_beat(false, "needs %d bots" % Rules.BOT_COUNT, clock_s)
		return
	_clock = clock_s
	for bot in bots:
		if not (bot["slice"] as Node).snapshot_done:
			return   # the scenario starts once everyone has joined
	if _index >= Rules.BEATS.size():
		done = true
		return
	var id := str(Rules.BEATS[_index]["id"])
	if _started != _index:
		_started = _index
		_beat_start_s = clock_s
		_mark = 0
	if not implemented().has(id):
		_finish_beat(false, "not_implemented", clock_s)
		return
	if clock_s - _beat_start_s > BEAT_TIMEOUT_S:
		_finish_beat(false, "timeout at step %d; sys %s %s; trade %s; packs %s %s; host answers: %s" % [_mark, str(_slice(bots, 0).system_keys), str(_slice(bots, 4).system_keys), str(_slice(bots, 1).trade_data), str(_slice(bots, 1).inventory), str(_slice(bots, 2).inventory), _answers(bots)], clock_s)
		return
	var result: String = call("_beat_" + id, bots)
	if result != "":
		_finish_beat(true, result, clock_s)

func _finish_beat(ok: bool, evidence: String, clock_s: float) -> void:
	beats.append({ "id": str(Rules.BEATS[_index]["id"]), "pass": ok, "evidence": evidence,
		"game_s": clock_s - _beat_start_s, "wall_s": clock_s - _beat_start_s })
	_index += 1
	_sent = false
	if _index >= Rules.BEATS.size():
		done = true

static func _slice(bots: Array, i: int) -> Node:
	return bots[i]["slice"]

func _clan_id(bots: Array, i: int) -> String:
	return str(((_slice(bots, i).clan_view as Dictionary).get("mine", {}) as Dictionary).get("id", ""))

func _beat_found(bots: Array) -> String:
	var s := _slice(bots, 0)
	if not _sent:
		_sent = true
		s.send_clan("found", { "name": CLAN_NAME })
	var id := _clan_id(bots, 0)
	return "clan %s founded, role %s" % [id, str(((s.clan_view as Dictionary).get("mine", {}) as Dictionary).get("role", ""))] if id != "" else ""

func _beat_invite_accept(bots: Array) -> String:
	var clan_id := _clan_id(bots, 0)
	if clan_id == "":
		return ""
	if _clock >= _next_send_s:
		# One clan intent per gap, whichever bot needs it: the founder invites whoever holds no invite
		# yet (a rate-limited invite simply comes round again), an invited bot joins.
		for i in range(1, Rules.MEMBERS):
			var s := _slice(bots, i)
			if _clan_id(bots, i) != "":
				continue
			if _invited_to(s, clan_id):
				s.send_clan("join", { "id": clan_id })
				_next_send_s = _clock + SEND_GAP_S
				break
			if _clock >= _invite_again_s[i]:
				_slice(bots, 0).send_clan("invite", { "target": str(s.claimed_handle) })
				_invite_again_s[i] = _clock + 3.0
				_next_send_s = _clock + SEND_GAP_S
				break
	for i in range(Rules.MEMBERS):
		if _clan_id(bots, i) != clan_id:
			return ""
	var roster: Array = (((_slice(bots, 0).clan_view as Dictionary).get("mine", {}) as Dictionary).get("roster", []))
	return "roster of %d" % roster.size() if roster.size() == Rules.MEMBERS else ""

static func _invited_to(s: Node, clan_id: String) -> bool:
	for inv in (s.clan_view as Dictionary).get("invites", []):
		if str((inv as Dictionary).get("id", "")) == clan_id:
			return true
	return false

## Each member mines the ground under their feet for a while; the host's own roster then shows who
## gained which skill. (Experiment: prints what the host sent so the beat can be shaped around it.)
func _beat_work(bots: Array) -> String:
	# Each member mines 8 times (one per 0.3 s). The host digs one block deeper per mine whatever
	# depth the claim names, so every member gains the same: Building from soil and stone, then 6 Smithing
	# from the first metal. Passes once every member's own roster row shows a gain from the host's record.
	if _mark < 8 and _clock >= _next_send_s:
		_next_send_s = _clock + 0.3
		for i in range(Rules.BOT_COUNT):
			var at: Dictionary = (_slice(bots, i).spawn as Dictionary).duplicate(true)
			if at.is_empty():
				continue
			var l: Vector3 = at["local"]
			at["local"] = Vector3(l.x + 3.0 * i, l.y - 0.5 - float(_mark) * 0.5, l.z)
			_slice(bots, i).send_mine(at)
		_mark += 1
	if _mark < 8:
		return ""
	var gains: Array = []
	for i in range(Rules.MEMBERS):
		var xp := _xp_of(bots, i, "Building")
		if xp <= 0.0:
			return ""
		gains.append("bot%d Building %.0f Smithing %.0f" % [i, xp, maxf(0.0, _xp_of(bots, i, "Smithing"))])
	return "; ".join(PackedStringArray(gains)) + " | inv " + str(_slice(bots, 1).inventory)

func _xp_of(bots: Array, i: int, skill: String) -> float:
	var h := str(_slice(bots, i).claimed_handle)
	for row in (((_slice(bots, i).clan_view as Dictionary).get("mine", {}) as Dictionary).get("roster", [])):
		if str((row as Dictionary).get("handle", "")) == h:
			return float(((row as Dictionary).get("skills", {}) as Dictionary).get(skill, {}).get("xp", 0.0))
	return -1.0

func _beat_see_skills(bots: Array) -> String:
	# Every member's view lists every member with a skills table, the host's own record.
	for i in range(Rules.MEMBERS):
		var roster: Array = (((_slice(bots, i).clan_view as Dictionary).get("mine", {}) as Dictionary).get("roster", []))
		if roster.size() != Rules.MEMBERS:
			return ""
		for row in roster:
			if not (row is Dictionary and (row as Dictionary).has("skills")):
				return ""
	return "4 members see 4 rosters with skills"

func _beat_whisper(bots: Array) -> String:
	var from := _slice(bots, 1)
	var to := _slice(bots, 2)
	if not _sent:
		_sent = true
		_mark = to.chat_lines.size()
		from.send_chat("/msg %s %s" % [str(to.claimed_handle), WHISPER_TEXT])
	for k in range(_mark, to.chat_lines.size()):
		var line: Dictionary = to.chat_lines[k]
		if str(line["channel"]) == "whisper" and str(line["text"]).contains(WHISPER_TEXT):
			return "recipient got a whisper line"
	return ""

## Bot 1 and bot 2 swap mined goods through the trade window's protocol: start, both propose, both accept.
## The host's own `trade_completed` packet is the evidence.
func _beat_trade(bots: Array) -> String:
	var a := _slice(bots, 1)
	var b := _slice(bots, 2)
	if a.trades_completed > 0 and b.trades_completed > 0:
		return "trade completed; bot1 pack now %s" % str(a.inventory)
	if _clock < _next_send_s:
		return ""
	_next_send_s = _clock + 0.6
	var trades: Dictionary = a.trade_data.get("trades", {}) if a.trade_data.get("trades", null) is Dictionary else {}
	match _mark:
		0:
			a.send_trade("trade_start_intent", { "party_b": str(b.claimed_handle) })
			_mark = 1
		1:
			if not trades.is_empty():
				_trade_id = str(trades.keys()[0])
				a.send_trade("trade_propose_intent", { "trade_id": _trade_id, "give": { "Soil": 2 }, "want": { "Soil": 1 } })
				_mark = 2
		2:
			b.send_trade("trade_propose_intent", { "trade_id": _trade_id, "give": { "Soil": 1 }, "want": { "Soil": 2 } })
			_mark = 3
		3:
			a.send_trade("trade_accept_intent", { "trade_id": _trade_id })
			_mark = 4
		4:
			b.send_trade("trade_accept_intent", { "trade_id": _trade_id })
			_mark = 5
		5:
			# An accept the host dropped (rate limit) is simply sent again until the trade completes.
			b.send_trade("trade_accept_intent", { "trade_id": _trade_id })
			a.send_trade("trade_accept_intent", { "trade_id": _trade_id })
	return ""

## Bot 0 builds as the clan, then places a small row of Soil blocks beside the spawn. Evidence: the host's
## `circle_view` shows the outsider (bot 4) a circle it may not build in.
func _beat_build(bots: Array) -> String:
	var a := _slice(bots, 0)
	if _clock < _next_send_s:
		return ""
	_next_send_s = _clock + 0.5
	if _mark == 0:
		a.send_chat("/buildas clan")
		_mark = 1
		return ""
	if _mark <= 4:
		var at: Dictionary = (a.spawn as Dictionary).duplicate(true)
		var l: Vector3 = at["local"]
		at["local"] = Vector3(l.x + 2.0 + 0.125 * float(_mark), l.y, l.z + 6.0)
		a.send_place(at, "Soil")
		_mark += 1
		return ""
	if not (_slice(bots, 4).circle_view as Array).is_empty():
		return "outsider is shown %d circle(s); keys %s" % [(_slice(bots, 4).circle_view as Array).size(), str(a.system_keys)]
	return ""

## Bot 3 builds one private block of its own (`/buildas private`), then mines it again. Evidence: its pack
## count of Soil falls by one on the place and the host's roster shows its Building xp rising on the mine.
func _beat_dismantle(bots: Array) -> String:
	var c := _slice(bots, 3)
	if _clock < _next_send_s:
		return ""
	_next_send_s = _clock + 1.2
	var at: Dictionary = (c.spawn as Dictionary).duplicate(true)
	var l: Vector3 = at["local"]
	at["local"] = Vector3(l.x - 8.0, l.y, l.z - 8.0)
	match _mark:
		0:
			c.send_chat("/buildas private")
			_mark = 1
		1:
			_soil_before = int(c.inventory.get("Soil", 0))
			c.send_place(at, "Soil")
			_mark = 2
		2:
			if int(c.inventory.get("Soil", 0)) >= _soil_before:
				c.send_place(at, "Soil")   # the place did not land yet
				return ""
			_xp_before = _xp_of(bots, 3, "Building")
			_soil_mid = int(c.inventory.get("Soil", 0))
			var hit: Dictionary = at.duplicate(true)
			hit["local"] = Vector3(l.x - 8.0, l.y + 0.0625, l.z - 8.0)
			c.send_mine(hit)
			_mark = 3
		3:
			# Until the block is gone, aim at each step height near the ground in turn.
			if _xp_of(bots, 3, "Building") <= _xp_before:
				var hit2: Dictionary = at.duplicate(true)
				hit2["local"] = Vector3(l.x - 8.0, l.y + [0.0625, 0.1875, -0.0625, 0.3125, 0.4375, 0.0, 0.25][_mark2 % 7], l.z - 8.0)
				_mark2 += 1
				c.send_mine(hit2)
				_next_send_s = _clock + 1.3
				return ""
			if _xp_of(bots, 3, "Building") > _xp_before:
				return "placed one private block (Soil %d -> %d) and mined it back (Soil %d, Building xp %.0f -> %.0f; keys %s)" % [
					_soil_before, _soil_mid, int(c.inventory.get("Soil", 0)), _xp_before, _xp_of(bots, 3, "Building"), str(c.system_keys)]
	return ""

## The fifth bot is not in the clan: its join is refused, and so is a block placed in the clan's circle.
## The host's refusal reason or key is the evidence. Mark: 0 join, 1 place, 2 done.
func _beat_outsider(bots: Array) -> String:
	var s := _slice(bots, 4)
	if _clock < _next_send_s:
		return ""
	_next_send_s = _clock + 0.5
	if _mark == 0:
		_marks_seen = s.clan_results.size()
		s.send_clan("join", { "id": _clan_id(bots, 0) })
		_mark = 1
		return ""
	if _mark == 1:
		for k in range(_marks_seen, s.clan_results.size()):
			var r: Dictionary = s.clan_results[k]
			if str(r.get("action", "")) == "join" and not bool(r.get("ok", true)) and str(r.get("reason", "")) != "rate_limited":
				_refusals.append("clan_" + str(r.get("reason", "")))
				_mark = 2
				_marks_seen = s.system_keys.size()
				break
		if _mark == 1:
			s.send_clan("join", { "id": _clan_id(bots, 0) })
		return ""
	if _mark == 2:
		var at: Dictionary = (s.spawn as Dictionary).duplicate(true)
		var l: Vector3 = at["local"]
		at["local"] = Vector3(l.x + 2.0 + 0.125 * 2.0, l.y, l.z + 6.0)
		s.send_place(at, "Soil")
		_mark = 3
		return ""
	for k in range(_marks_seen, s.system_keys.size()):
		var key := str(s.system_keys[k])
		if key.contains("refused") or key.contains("circle"):
			_refusals.append(key)
			return "refusals: %s" % str(_refusals)
	return ""

## What the host told each bot so far, for a failed beat's evidence.
func _answers(bots: Array) -> String:
	var out: Array = []
	for i in range(bots.size()):
		var rs: Array = []
		for r in _slice(bots, i).clan_results:
			rs.append("%s:%s" % [str((r as Dictionary).get("action", "")), str((r as Dictionary).get("reason", "ok"))])
		out.append("bot%d %s" % [i, ",".join(PackedStringArray(rs))])
	return "; ".join(PackedStringArray(out))

func report(game_s: float) -> Dictionary:
	var v := Rules.verdict(beats, game_s, {})
	return { "scenario": "clan", "beats": beats, "game_s": game_s, "play_s": game_s, "pass": v["pass"], "failures": v["failures"] }
