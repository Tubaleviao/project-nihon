extends Node
## Phase 202 — the host's half of the `clan` stress scenario. Attached to a `--server --stress-host`
## boot that also carries `--stress-clan <out.json>`. It reads the host's own world record (clans,
## skills, structures, chests, completed trades, whispers, refusals) and never trusts a bot's word.
##
## Twice a second it writes `<out>.live` (the evidence the bots wait on, so each beat starts when the
## host shows the last one happened); when the stop file appears it writes `<out>` with the final
## `world` record for `StressClanRules.failures`.

const StressClanRules := preload("res://src/tests/stress_clan_rules.gd")

const POLL_S := 0.25
const CLAN_NAME_ARG := "--stress-clan-name"

var out_path := ""
var stop_path := ""
var clan_name := "Stressers"
var _root: Node = null
var _poll := 0.0
var _t0_ms := 0
var _trades := 0
var _whisper_count := 0
## First wall second (since attach) each flag became true.
var _seen: Dictionary = {}
## Refusals: [{ "who", "kind", "key" }] from chest_resolved and system_message.
var _refusals: Array = []
var _private_seen := false
var _private_gone := false
var _written := false

static func attach(root: Node) -> void:
	var args := Array(OS.get_cmdline_user_args())
	var i := args.find("--stress-clan")
	if i < 0 or i + 1 >= args.size() or not root._is_server:
		return
	var probe: Node = (load("res://src/tests/stress_clan_probe.gd") as GDScript).new()
	probe.name = "StressClanProbe"
	probe.out_path = str(args[i + 1])
	var s := args.find("--stress-stop")
	probe.stop_path = str(args[s + 1]) if s >= 0 and s + 1 < args.size() else ""
	var n := args.find(CLAN_NAME_ARG)
	if n >= 0 and n + 1 < args.size():
		probe.clan_name = str(args[n + 1])
	probe._root = root
	root.add_child(probe)

func _ready() -> void:
	_t0_ms = Time.get_ticks_msec()
	GameBus.chat_posted.connect(func(channel: String, _s: String, _t: String, _target: String):
		if channel == "whisper":
			_whisper_count += 1)
	GameBus.trade_completed.connect(func(_t: Dictionary): _trades += 1)
	GameBus.chest_resolved.connect(func(pid: String, action: String, ok: bool, reason: String):
		if not ok:
			_refusals.append({ "who": pid, "kind": "chest_" + action, "key": reason }))
	GameBus.system_message.connect(func(key: String, _a: Array, target: String):
		if key.contains("refus") or key.contains("foreign") or key.contains("not_owner") or key.contains("denied"):
			_refusals.append({ "who": target, "kind": "message", "key": key }))

func _wall_s() -> float:
	return float(Time.get_ticks_msec() - _t0_ms) / 1000.0

func _process(delta: float) -> void:
	_poll += delta
	if _poll < POLL_S:
		return
	_poll = 0.0
	var world := world_record()
	_note(world)
	var live := { "seen": _seen, "world": world, "refusals": _refusals }
	_write(out_path + ".live", live)
	if stop_path != "" and FileAccess.file_exists(stop_path) and not _written:
		_written = true
		_write(out_path, { "world": world, "seen": _seen, "refusals": _refusals })

func _note(world: Dictionary) -> void:
	var flags := {
		"found": int(world["clans"]) > 0,
		"members_4": int(world["members"]) >= StressClanRules.MEMBERS,
		"skills_4": int(world["skilled_members"]) >= StressClanRules.MEMBERS,
		"skills_differ": StressClanRules.distinct_top_skills(world["skills"]) >= 2,
		"whisper": int(world["whispers"]) > 0,
		"trade": int(world["trades"]) > 0,
		"structure": int(world["structures"]) > 0,
		"chest_clan": str(world["chest_access"]) == "clan",
		"chest_item": int(world["chest_items"]) > 0,
		"private": _private_seen,
		"private_gone": _private_gone,
	}
	for k: String in flags:
		if bool(flags[k]) and not _seen.has(k):
			_seen[k] = _wall_s()

## The host's world record, read from its own slices.
func world_record() -> Dictionary:
	var clans: Node = _root._clans
	var best_id := ""
	var best_n := -1
	for id: Variant in clans.ids():
		var n := ((clans.get_clan(str(id)).get("members", {})) as Dictionary).size()
		if n > best_n:
			best_n = n
			best_id = str(id)
	var members: Dictionary = clans.get_clan(best_id).get("members", {}) if best_id != "" else {}
	var skills := {}
	var skilled := 0
	for pid: Variant in members.keys():
		var xp: Variant = _root._registry.get_record(str(pid)).get("skill_xp", {})
		skills[str(pid)] = xp if xp is Dictionary else {}
		if (skills[str(pid)] as Dictionary).size() > 0:
			skilled += 1
	var owned := 0
	var private_now := 0
	for sid: Variant in _root._structures.ids():
		var s: Dictionary = _root._structures.get_structure(int(sid))
		if str(s.get("kind", "")) == "clan" and str(s.get("owner", "")) == best_id:
			owned += 1
		elif str(s.get("kind", "")) == "private":
			private_now += 1
	if private_now > 0:
		_private_seen = true
	elif _private_seen:
		_private_gone = true
	var access := ""
	var items := 0
	for cid: Variant in _root._chests.ids():
		var lock: Dictionary = _root._chests.get_lock(str(cid))
		if best_id != "" and str(lock.get("owner", "")) == best_id and str(lock.get("kind", "")) == "clan":
			access = str(lock.get("mode", ""))
			for q: Variant in (_root._chests.items_of(str(cid)) as Dictionary).values():
				items += int(q)
	var inventories := {}
	for pid: Variant in members.keys():
		var inv: Node = _root._registry.get_inventory(str(pid))
		inventories[str(pid)] = (inv._contents as Dictionary).duplicate() if inv != null and "_contents" in inv else {}
	return {
		"inventories": inventories, "trade_ids": _root._trade._trades.keys(),
		"clans": clans.count(), "clan_id": best_id, "members": members.size(), "member_ids": members.keys(),
		"skills": skills, "skilled_members": skilled, "trades": _trades, "structures": owned,
		"chest_access": access, "chest_items": items, "whispers": _whispers(),
	}

func _whispers() -> int:
	return _whisper_count

func _write(path: String, data: Dictionary) -> void:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()
	DirAccess.rename_absolute(tmp, path)
