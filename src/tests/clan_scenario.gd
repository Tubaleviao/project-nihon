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
var _next_send_s := 0.0
var _invite_again_s := [0.0, 0.0, 0.0, 0.0, 0.0]
## The host limits each player to one clan intent per `ClanSlice.INTENT_INTERVAL`; space them wider.
const SEND_GAP_S := 0.4

## Beat ids this driver plays today; the rest of `Rules.BEATS` report `not_implemented`.
static func implemented() -> Array:
	return ["found", "invite_accept", "see_skills", "whisper", "outsider"]

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
		_finish_beat(false, "timeout; host answers: %s" % [_answers(bots)], clock_s)
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

## A non-member cannot join the clan uninvited; the host's refusal reason is the evidence.
func _beat_outsider(bots: Array) -> String:
	var s := _slice(bots, 4)
	if not _sent:
		_sent = true
		_mark = s.clan_results.size()
		s.send_clan("join", { "id": _clan_id(bots, 0) })
	for k in range(_mark, s.clan_results.size()):
		var r: Dictionary = s.clan_results[k]
		if str(r.get("action", "")) == "join" and not bool(r.get("ok", true)) and str(r.get("reason", "")) != "rate_limited":
			return "refused: %s" % str(r.get("reason", ""))
	return ""

## What the host told each bot so far, for a failed beat's evidence.
func _answers(bots: Array) -> String:
	var out: Array = []
	for i in range(bots.size()):
		var rs: Array = []
		for r in _slice(bots, i).clan_results:
			rs.append("%s:%s" % [str((r as Dictionary).get("action", "")), str((r as Dictionary).get("reason", "ok"))])
		out.append("bot%d(%s) %s" % [i, str(_slice(bots, i).claimed_handle), ",".join(PackedStringArray(rs))])
	return "; ".join(PackedStringArray(out))

func report(game_s: float) -> Dictionary:
	var v := Rules.verdict(beats, game_s, {})
	return { "scenario": "clan", "beats": beats, "game_s": game_s, "play_s": game_s, "pass": v["pass"], "failures": v["failures"] }
