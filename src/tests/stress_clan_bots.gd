extends Node
## Phase 202 — the `clan` scenario, bot side. Five bots (four clan members and an outsider, bot index 4)
## play the clan loop through their ENet connections: every action is the packet a real client sends
## (`clan_intent`, `chat_intent`, `trade_*_intent`, `block_edit_intent`, `chest_intent`, ...), so the host
## validates it as it would a player's. The only admin command is `/time`, and every use is recorded.
##
## A beat starts when the host's probe (`StressClanProbe`, `<live>` file) shows the last one happened, and
## passes when the host's own record shows this one did. The bots never decide a verdict from what they sent.

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
	_finish()

func _finish() -> void:
	var f := FileAccess.open(out_path, FileAccess.WRITE) if out_path != "" else null
	if f != null:
		f.store_string(JSON.stringify({ "beats": beats, "admin": admin }))
		f.close()
	done = true
