extends RefCounted
## Phase 200 — the host's raid scheduler. It owns the transient raids (a warning, then the pack on the field,
## then a result) and asks `RaidRules` whether a settlement may be raided on each settlement tick. The pack's
## creatures are spawned through `spawn_raider` (`GameBus.raid_pack_spawn` only announces the spawned pack);
## a raid ends when every raider is dead or has fled. The slice owns the persisted part (the cooldown clock and the last result, `end_raid`).

const SettlementSlice := preload("res://src/settlement/settlement_slice.gd")
const RaidRules := preload("res://src/settlement/raid_rules.gd")

## `() -> Array` the ids of the players online (the host's own registry, never a message).
var online_ids: Callable = Callable()
## `(Vector2 xz) -> String` the biome key at a ground point; "" when unknown (no pack then).
var biome_at: Callable = Callable()
## `(String seed_text) -> float` a deterministic 0..1 value; the default hashes the text.
var roll: Callable = Callable()

## `(creature_id, xz, goal, raid_id, n) -> String` spawns one raider (CreatureSlice.spawn_raider); "" when none.
var spawn_raider: Callable = Callable()
## `(raid_id) -> Array` of { id, alive, xz } (CreatureSlice.raiders_of).
var raiders_of: Callable = Callable()
## `(raid_id) -> void` removes the raid's creatures (CreatureSlice.remove_raiders).
var remove_raiders: Callable = Callable()

## A raider this close to the hearth has reached it.
const REACH_M := 4.0

var slice: SettlementSlice = null
## settlement id -> { phase "warning" | "fighting", started, spawn_at, ends_at, pack [{creature, count}], edge Vector2 }
var _raids: Dictionary = {}
var _count: int = 0

func active(id: String) -> bool:
	return _raids.has(id)

func phase_of(id: String) -> String:
	return str(_raids.get(id, {}).get("phase", ""))

## The live raid as the views carry it ({} when none).
func view_of(id: String) -> Dictionary:
	if not _raids.has(id):
		return {}
	var r: Dictionary = _raids[id]
	return { "phase": str(r["phase"]), "edge_x": (r["edge"] as Vector2).x, "edge_z": (r["edge"] as Vector2).y, "spawn_at": float(r["spawn_at"]) }

func raid_of(id: String) -> Dictionary:
	return (_raids.get(id, {}) as Dictionary).duplicate(true)

## Members online whose position is inside the claim.
func online_in_claim(id: String) -> int:
	if slice == null or not online_ids.is_valid():
		return 0
	var n := 0
	var centre := slice.hearth_xz(id)
	var radius := slice.claim_radius(id)
	for pid: Variant in online_ids.call():
		if not slice.is_member(str(pid), id):
			continue
		var xz: Variant = slice.player_xz(str(pid))
		if xz is Vector2 and (xz as Vector2).distance_to(centre) <= radius:
			n += 1
	return n

## Members online anywhere (the claim edge, where the fight is, may lie just outside the claim).
func online_members(id: String) -> int:
	if slice == null or not online_ids.is_valid():
		return 0
	var n := 0
	for pid: Variant in online_ids.call():
		if slice.is_member(str(pid), id):
			n += 1
	return n

func _info(id: String, now: float) -> Dictionary:
	var s := slice.get_settlement(id)
	var rec := slice.raid_record(id)
	return { "age_sec": now - float(s.get("created", now)), "tier": str(s.get("status", "founded")), "stock_stacks": slice.used_stacks(id),
		"since_last_sec": (now - float(rec["last_end"])) if float(rec["last_end"]) > 0.0 else 1.0e12, "active": active(id),
		"online_in_claim": online_in_claim(id), "biome": str(biome_at.call(slice.hearth_xz(id))) if biome_at.is_valid() else "" }

## Why `id` cannot be raided now ("" when it can).
func blocker(id: String, now: float) -> String:
	if slice == null or slice.get_settlement(id).is_empty() or str(slice.get_settlement(id).get("status", "")) == "abandoned":
		return "no_pack"
	return RaidRules.start_blocker(_info(id, now))

## Start a raid. `forced` (the admin command) skips the age, value and cooldown checks, keeping one raid at a time,
## a member online inside the claim and a biome with a pack. Returns "" or a refusal key.
func start(id: String, now: float, forced: bool = false) -> String:
	var why := blocker(id, now)
	if forced and why in ["too_young", "not_worth_raiding", "cooldown"]:
		why = ""
	if why != "":
		return why
	var t := RaidRules.table()
	var info := _info(id, now)
	_count += 1
	var rolls: Array = []
	for i in 4:
		rolls.append(_roll("%s:%d:%d" % [id, _count, i]))
	var pack := RaidRules.pack_for(str(info["biome"]), rolls, t)
	var angle := _roll("%s:%d:edge" % [id, _count]) * TAU
	var edge := slice.hearth_xz(id) + Vector2(cos(angle), sin(angle)) * slice.claim_radius(id)
	_raids[id] = { "phase": "warning", "started": now, "spawn_at": now + float(t["warningSeconds"]), "ends_at": now + float(t["warningSeconds"]) + float(t["durationSeconds"]),
		"pack": pack, "edge": edge }
	GameBus.raid_warned.emit(id, int(t["warningSeconds"]))
	return ""

## The tick: schedule raids on eligible settlements, move warnings to the field, and lose raids that ran out.
func tick(now: float) -> void:
	if slice == null:
		return
	var live := slice.ids()
	for id: String in _raids.keys():
		if not live.has(id):   # the settlement is gone: drop its raid and pack
			_cancel(id)
	for id: String in live:
		if not active(id):
			if blocker(id, now) == "":
				start(id, now)
			continue
		var r: Dictionary = _raids[id]
		# Nobody left to defend: no pack, no loss.
		if online_ids.is_valid() and online_members(id) == 0:
			_cancel(id)
			continue
		if str(r["phase"]) == "warning" and now >= float(r["spawn_at"]):
			r["phase"] = "fighting"
			r["spawned"] = _spawn_pack(id, r)
			if int(r["spawned"]) <= 0 and spawn_raider.is_valid():
				_finish(id, true)   # nothing could be spawned: the raid is over, nothing lost
				continue
			GameBus.settlements_changed.emit()   # the views carry the new phase
			GameBus.raid_pack_spawn.emit(id, (r["pack"] as Array).duplicate(true), r["edge"])
		elif str(r["phase"]) == "fighting":
			if now >= float(r["ends_at"]):
				_finish(id, false)
			elif raiders_of.is_valid():
				_judge(id, r)

func _spawn_pack(id: String, r: Dictionary) -> int:
	if not spawn_raider.is_valid():
		return 0
	var goal := slice.hearth_xz(id)
	var n := 0
	for row: Dictionary in r["pack"]:
		for i in int(row["count"]):
			# A little spread along the edge so the pack is not one point.
			var at: Vector2 = (r["edge"] as Vector2) + Vector2(float(i) * 1.5, float(n % 3))
			if str(spawn_raider.call(str(row["creature"]), at, goal, id, n)) != "":
				n += 1
	return n

## Defended once every raider is dead or has fled; lost the moment a live one reaches the hearth.
func _judge(id: String, r: Dictionary) -> void:
	if int(r.get("spawned", 0)) <= 0:
		return
	var goal := slice.hearth_xz(id)
	var threats := 0
	for e: Dictionary in raiders_of.call(id):
		if bool(e["alive"]) and not bool(e.get("fled", false)):
			threats += 1
			if (e["xz"] as Vector2).distance_to(goal) <= REACH_M:
				_finish(id, false)
				return
	if threats == 0:
		_finish(id, true)

## End a raid with no result and no loss (nobody online, or its settlement is gone).
func _cancel(id: String) -> void:
	_raids.erase(id)
	if remove_raiders.is_valid():
		remove_raiders.call(id)
	GameBus.settlements_changed.emit()

func _finish(id: String, defended: bool) -> void:
	_raids.erase(id)
	if remove_raiders.is_valid():
		remove_raiders.call(id)
	var out := slice.end_raid(id, defended)
	GameBus.raid_resolved.emit(id, str(out.get("result", "")), out.get("stock", {}), float(out.get("damage", 0.0)))

func _roll(text: String) -> float:
	if roll.is_valid():
		return float(roll.call(text))
	return float(hash(text) & 0xFFFF) / 65536.0
