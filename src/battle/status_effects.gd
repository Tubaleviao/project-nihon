extends RefCounted
## Status effects — the fabric's `CombatSystem.statusEffects` table runs on the host (Phase 129).
## Burn, paralysis, knockdown and stagger are timed rows kept per target id; knockback is an instant
## displacement the caller carries out. All time is the caller's `now` in seconds, so tests drive it
## without a clock.
##
## Public API:
##   table() -> Dictionary                         the fabric table (rows with defaults)
##   apply(target_id, effect_id, now) -> bool      false for an unknown effect
##   tick(now, weather_of) -> Array                damage events { target_id, effect, damage }
##   damage_factor(target_id, now) -> float        product of the live damageTakenFactors
##   is_immobilized(target_id, now) -> bool
##   active(target_id, now) -> Array               [{ effect, remaining }] for HUD and persistence
##   clear(target_id) / take_dirty() -> Array      targets whose set changed since the last call
##   to_data(target_id, now) / from_data(target_id, list, now)
##   roll_value(seq, attacker, target, index) -> float   the seeded on-hit roll (static)

const SALT_A := 0x1E3779B97F4A7C15
const SALT_B := 0x3F58476D1CE4E5B9
const SALT_C := 0x14D049BB133111EB
const FNV_OFFSET := 0x4BF29CE484222325
const FNV_PRIME := 0x100000001B3

## Most instances one target holds (stacking rows); more are refused, so memory stays bounded.
const MAX_PER_TARGET := 8
## Most targets tracked at once; a new target past it is refused.
const MAX_TARGETS := 512

const DEFAULT_ROW := {
	"durationSeconds": 0.0, "damagePerSecond": 0.0, "immobilize": false, "damageTakenFactor": 1.0,
	"displaceTiles": 0, "stacks": false, "extinguishedBy": [],
}

## Replaces the fabric table when non-empty (tests).
var table_override: Dictionary = {}

## target_id → Array of { "effect": String, "end": float, "last": float }.
var _active: Dictionary = {}
var _dirty: Dictionary = {}
var _table_cache: Dictionary = {}

func table() -> Dictionary:
	if not table_override.is_empty():
		return table_override
	if not _table_cache.is_empty():
		return _table_cache
	var out := {}
	var res: Resource = GameData.WORLD_SYSTEMS.get("CombatSystem", null)
	if res != null:
		var t: Variant = res.get("statusEffects")
		if t is Dictionary:
			for id in (t as Dictionary).keys():
				if (t as Dictionary)[id] is Dictionary:
					var entry := DEFAULT_ROW.duplicate(true)
					entry.merge((t as Dictionary)[id], true)
					out[str(id)] = entry
	_table_cache = out
	return out

func row(effect_id: String) -> Dictionary:
	var r: Variant = table().get(effect_id, null)
	return r if r is Dictionary else {}

## Start `effect_id` on `target_id`. A non-stacking effect already running is refreshed (its timer
## restarts, nothing doubles); an instant effect (duration 0, e.g. knockback) stores nothing.
## `duration_factor` scales a running effect's length (Phase 178 Resistance); an instant effect stays instant.
func apply(target_id: String, effect_id: String, now: float, duration_factor: float = 1.0) -> bool:
	var r := row(effect_id)
	if r.is_empty() or target_id.is_empty():
		return false
	var duration := float(r["durationSeconds"])
	if duration > 0.0:
		duration *= maxf(duration_factor, 0.0)
	if duration <= 0.0:
		return true
	if not _active.has(target_id):
		if _active.size() >= MAX_TARGETS:
			return false
		_active[target_id] = []
	var list: Array = _active[target_id]
	if not bool(r["stacks"]):
		for entry in list:
			if entry["effect"] == effect_id:
				entry["end"] = now + duration
				_dirty[target_id] = true
				return true
	if list.size() >= MAX_PER_TARGET:
		return false
	list.append({ "effect": effect_id, "end": now + duration, "last": now })
	_dirty[target_id] = true
	return true

## Advance to `now`: returns one damage event per (target, effect) that dealt damage, drops expired
## rows and rows a weather state extinguishes. `weather_of` is `(target_id) -> String` (may be invalid).
func tick(now: float, weather_of: Callable = Callable()) -> Array:
	var events: Array = []
	for target_id in _active.keys():
		var list: Array = _active[target_id]
		var weather := ""
		if weather_of.is_valid():
			weather = str(weather_of.call(target_id))
		var kept: Array = []
		for entry in list:
			var r := row(entry["effect"])
			if weather != "" and (r.get("extinguishedBy", []) as Array).has(weather):
				_dirty[target_id] = true
				continue
			var upto := minf(now, float(entry["end"]))
			var dt := upto - float(entry["last"])
			var dps := float(r.get("damagePerSecond", 0.0))
			if dt > 0.0 and dps > 0.0:
				events.append({ "target_id": target_id, "effect": entry["effect"], "damage": dps * dt })
			entry["last"] = maxf(upto, float(entry["last"]))
			if now >= float(entry["end"]):
				_dirty[target_id] = true
				continue
			kept.append(entry)
		if kept.is_empty():
			_active.erase(target_id)
		else:
			_active[target_id] = kept
	return events

func _live(target_id: String, now: float) -> Array:
	var out: Array = []
	for entry in _active.get(target_id, []):
		if now < float(entry["end"]):
			out.append(entry)
	return out

func damage_factor(target_id: String, now: float) -> float:
	var f := 1.0
	for entry in _live(target_id, now):
		f *= float(row(entry["effect"]).get("damageTakenFactor", 1.0))
	return f

func is_immobilized(target_id: String, now: float) -> bool:
	for entry in _live(target_id, now):
		if bool(row(entry["effect"]).get("immobilize", false)):
			return true
	return false

func active(target_id: String, now: float) -> Array:
	var out: Array = []
	for entry in _live(target_id, now):
		out.append({ "effect": entry["effect"], "remaining": float(entry["end"]) - now })
	return out

func has_any(target_id: String) -> bool:
	return _active.has(target_id)

func targets() -> Array:
	return _active.keys()

func clear(target_id: String) -> void:
	if _active.erase(target_id):
		_dirty[target_id] = true

func clear_all() -> void:
	for t in _active.keys():
		_dirty[t] = true
	_active.clear()

## Targets whose effect set changed since the last call (applied, refreshed, expired, cleared).
func take_dirty() -> Array:
	var out: Array = _dirty.keys()
	_dirty.clear()
	return out

func to_data(target_id: String, now: float) -> Array:
	return active(target_id, now)

## Restore `[{ effect, remaining }]`; unknown effects and malformed entries are skipped, a remaining
## time is clamped to the effect's duration. A legacy record (no list) restores nothing.
func from_data(target_id: String, list: Variant, now: float) -> void:
	_active.erase(target_id)
	if not (list is Array):
		return
	for item in list:
		if not (item is Dictionary):
			continue
		var effect := str(item.get("effect", ""))
		var r := row(effect)
		if r.is_empty() or float(r["durationSeconds"]) <= 0.0:
			continue
		var rem := float(item.get("remaining", 0.0))
		if is_nan(rem) or rem <= 0.0:
			continue
		rem = minf(rem, float(r["durationSeconds"]))
		if apply(target_id, effect, now):
			# apply() refreshed the one non-stacking row or appended a stacking one: the entry it touched
			# is the last one for this effect, and it takes this item's own end time.
			var held: Array = _active[target_id]
			for i in range(held.size() - 1, -1, -1):
				if held[i]["effect"] == effect:
					held[i]["end"] = now + rem
					break
	_dirty[target_id] = true

# ---------------------------------------------------------------------------
# The seeded on-hit roll
# ---------------------------------------------------------------------------

static func _mix1(x: int) -> int:
	x += SALT_A
	x = (x ^ ((x >> 30) & 0x3FFFFFFFF)) * SALT_B
	x = (x ^ ((x >> 27) & 0x1FFFFFFFFF)) * SALT_C
	return x ^ ((x >> 31) & 0x1FFFFFFFF)

static func _fnv(s: String) -> int:
	var h := FNV_OFFSET
	for b in s.to_utf8_buffer():
		h = (h ^ int(b)) * FNV_PRIME
	return h

## A value in [0, 1) mixed from (round seq, attacker, target, entry index). Pinned by golden values.
static func roll_value(seq: int, attacker_id: String, target_id: String, index: int) -> float:
	var x := _mix1(_mix1(_mix1(_mix1(seq) ^ _fnv(attacker_id)) ^ _fnv(target_id)) ^ index)
	return float(x & 0xFFFFFF) / float(0x1000000)

## The effects (`[{ effect, chance }]`) that land for this round, in table order.
## `chance_factor` scales every entry's chance (Phase 178 Resistance).
func rolled_effects(on_hit: Variant, seq: int, attacker_id: String, target_id: String, chance_factor: float = 1.0) -> Array:
	var out: Array = []
	if not (on_hit is Array):
		return out
	for i in range((on_hit as Array).size()):
		var entry: Variant = on_hit[i]
		if not (entry is Dictionary):
			continue
		var effect := str(entry.get("effect", ""))
		if row(effect).is_empty():
			continue
		if roll_value(seq, attacker_id, target_id, i) < float(entry.get("chance", 0.0)) * chance_factor:
			out.append(effect)
	return out

## Where a knockback of `tiles` tiles puts `pos` when pushed away from `source`, stepping back toward
## `pos` one tile at a time until `walkable` (`(Vector3) -> bool`) accepts the spot. Returns `pos`
## itself when no spot is free. Y is kept: the caller's walkable test owns the ground.
static func knockback_target(pos: Vector3, source: Vector3, tiles: int, tile_size: float, walkable: Callable) -> Vector3:
	var dir := Vector3(pos.x - source.x, 0.0, pos.z - source.z)
	if dir.length_squared() < 0.000001 or tiles <= 0:
		return pos
	dir = dir.normalized()
	for t in range(tiles, 0, -1):
		var spot := pos + dir * tile_size * float(t)
		if not walkable.is_valid() or bool(walkable.call(spot)):
			return spot
	return pos
