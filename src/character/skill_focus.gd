extends RefCounted
## Phase 272 — focus: the active minutes of play time a player spent earning XP in each skill, and the XP
## multiplier they give. Pure functions over one focus dictionary (the player's `skill_focus` record field):
##   { clock: float play seconds, minutes: { skill: [whole play minutes with XP, ascending] }, carry: { skill: float } }
## Play time is the `clock`: the host advances it only for a player who is connected, so time logged off neither
## adds focus nor ages it. A minute counts once per skill however many grants fall in it, and the same minute can
## count for several skills. Minutes older than the window drop out.

const MAX_MINUTES_KEPT := 600
const MAX_SKILLS := 64

static func empty() -> Dictionary:
	return {"clock": 0.0, "minutes": {}, "carry": {}}

static func window_minutes() -> int:
	var res: Resource = GameData.WORLD_SYSTEMS.get("SkillFocus", null)
	return maxi(1, int(res.get("focusWindowMinutes"))) if res != null else 60

static func max_bonus() -> float:
	var res: Resource = GameData.WORLD_SYSTEMS.get("SkillFocus", null)
	return maxf(0.0, float(res.get("maxBonus"))) if res != null else 0.25

static func minute_of(focus: Dictionary) -> int:
	return int(floorf(float(focus.get("clock", 0.0)) / 60.0))

## Play time passes for a connected player.
static func advance(focus: Dictionary, delta: float) -> void:
	if delta > 0.0:
		focus["clock"] = float(focus.get("clock", 0.0)) + delta

## The current play minute counts for `skill` (once).
static func note(focus: Dictionary, skill: String) -> void:
	var minutes: Dictionary = focus.get("minutes", {})
	if not minutes.has(skill) and minutes.size() >= MAX_SKILLS:
		return
	var list: Array = minutes.get(skill, [])
	var now := minute_of(focus)
	if list.is_empty() or int(list[list.size() - 1]) != now:
		list.append(now)
	if list.size() > MAX_MINUTES_KEPT:
		list = list.slice(list.size() - MAX_MINUTES_KEPT)
	minutes[skill] = list
	focus["minutes"] = minutes

## Active minutes of `skill` inside the last `window` minutes (the current minute included).
static func active_minutes(focus: Dictionary, skill: String, window: int) -> int:
	var now := minute_of(focus)
	var n := 0
	for m in (focus.get("minutes", {}) as Dictionary).get(skill, []):
		if int(m) > now - window and int(m) <= now:
			n += 1
	return mini(n, window)

## 1 + maxBonus x active / window: never below 1, `1 + maxBonus` at a full window.
static func multiplier(focus: Dictionary, skill: String, window: int, bonus: float) -> float:
	return 1.0 + maxf(0.0, bonus) * float(active_minutes(focus, skill, window)) / float(maxi(1, window))

## The whole XP a grant of `amount` pays now: the grant's minute is noted, the multiplier applied once, and the
## fractional part carried per skill until it reaches a whole point.
static func boost(focus: Dictionary, skill: String, amount: int, window: int, bonus: float) -> int:
	if amount <= 0:
		return 0
	note(focus, skill)
	var exact := float(amount) * multiplier(focus, skill, window, bonus)
	var carry: Dictionary = focus.get("carry", {})
	exact += float(carry.get(skill, 0.0))
	var paid := int(floorf(exact + 0.000001))
	carry[skill] = maxf(0.0, exact - float(paid))
	focus["carry"] = carry
	return paid

## `boost` with the fabric's window and bonus.
static func boost_fabric(focus: Dictionary, skill: String, amount: int) -> int:
	return boost(focus, skill, amount, window_minutes(), max_bonus())

## Focus as shares of the window by skill: { skill: share in 0..1 } over the skills with any active minute,
## where the shares sum to 1. Empty with no focus.
static func shares(focus: Dictionary, window: int) -> Dictionary:
	var total := 0
	var counts: Dictionary = {}
	for skill in focus.get("minutes", {}):
		var n := active_minutes(focus, str(skill), window)
		if n > 0:
			counts[str(skill)] = n
			total += n
	var out: Dictionary = {}
	for skill in counts:
		out[skill] = float(counts[skill]) / float(total)
	return out

## Shares grouped by skill category: { category: share }.
static func category_shares(focus: Dictionary, window: int, category_of: Callable) -> Dictionary:
	var out: Dictionary = {}
	var by_skill := shares(focus, window)
	for skill in by_skill:
		var c := str(category_of.call(skill))
		out[c] = float(out.get(c, 0.0)) + float(by_skill[skill])
	return out

## A saved or synced focus, bounded: unknown shapes and bad numbers become empty.
static func sanitize(data: Variant) -> Dictionary:
	var out := empty()
	if not data is Dictionary:
		return out
	var clock := float((data as Dictionary).get("clock", 0.0))
	out["clock"] = clampf(clock, 0.0, 1.0e10) if is_finite(clock) else 0.0
	var minutes_in: Variant = (data as Dictionary).get("minutes", {})
	if minutes_in is Dictionary:
		for skill in minutes_in:
			if (out["minutes"] as Dictionary).size() >= MAX_SKILLS or not (minutes_in[skill] is Array):
				continue
			var list: Array = []
			for m in minutes_in[skill]:
				if (m is int or m is float) and int(m) >= 0:
					list.append(int(m))
			list.sort()
			out["minutes"][str(skill)] = list.slice(maxi(0, list.size() - MAX_MINUTES_KEPT))
	var carry_in: Variant = (data as Dictionary).get("carry", {})
	if carry_in is Dictionary:
		for skill in carry_in:
			var c := float(carry_in[skill]) if (carry_in[skill] is int or carry_in[skill] is float) else 0.0
			if is_finite(c) and (out["minutes"] as Dictionary).has(str(skill)):
				out["carry"][str(skill)] = clampf(c, 0.0, 0.999999)
	return out
