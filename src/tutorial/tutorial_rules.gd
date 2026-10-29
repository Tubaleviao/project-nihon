extends RefCounted
## Tutorial rules (Phase 186) — pure functions over the fabric step table (`GameData.TUTORIALS["Tutorial"]`,
## Phase 184). Steps are dictionaries `{ id, chapter, inputs, requires, trigger }`, in fabric order; `state` is
## `{ enabled: bool, done: Array, dismissed: Array }` (see `TutorialState`).

## The fabric step list, or [] with no fabric.
static func steps() -> Array:
	var res: Resource = GameData.TUTORIALS.get("Tutorial", null)
	return Array(res.get("steps")) if res != null else []

static func _has(list: Variant, id: String) -> bool:
	return list is Array and (list as Array).has(id)

## The first step, in fabric order, that is not done or dismissed and whose `requires` are all done.
## `{}` when the tutorial is off or nothing is left.
static func next_step(state: Dictionary, table: Array = []) -> Dictionary:
	if not bool(state.get("enabled", true)):
		return {}
	for s in (table if not table.is_empty() else steps()):
		var id := str(s["id"])
		if _has(state.get("done"), id) or _has(state.get("dismissed"), id):
			continue
		var ready := true
		for r in s["requires"]:
			if not _has(state.get("done"), str(r)):
				ready = false
				break
		if ready:
			return s
	return {}

## True when the event `kind` with `params` completes `step`'s trigger. Count-based triggers
## (`moved_metres`, `item_gathered`) compare the event's running `metres` / `count` with the trigger's.
## `tags` lists the tags the event's subject carries (an item or creature key matches by itself).
static func event_completes(step: Dictionary, kind: String, params: Dictionary) -> bool:
	var t: Dictionary = step["trigger"]
	if str(t["kind"]) != kind:
		return false
	match kind:
		"moved_metres":
			return float(params.get("metres", 0.0)) >= float(t["metres"])
		"item_gathered":
			return _subject_matches(t, params) and int(params.get("count", 0)) >= int(t["count"])
		"item_crafted", "creature_killed":
			return _subject_matches(t, params) and (t.has("item") or t.has("tag") or t.has("creature"))
		"station_placed":
			return str(params.get("type", "")) == str(t["type"])
		"window_opened":
			return str(params.get("window", "")) == str(t["window"])
		"item_equipped":
			return str(params.get("slot", "")) == str(t["slot"])
		"technology_researched":
			return str(params.get("technology", "")) == str(t["technology"])
	return true

static func _subject_matches(t: Dictionary, params: Dictionary) -> bool:
	var subject := str(params.get("item", params.get("creature", "")))
	var tags: Array = params.get("tags", [])
	if t.has("item"):
		return subject == str(t["item"])
	if t.has("creature"):
		return subject == str(t["creature"])
	return tags.has(str(t.get("tag", "")))

## Progress per chapter: `{ chapter: { done: n, total: n } }`, chapters in fabric order of first use.
static func progress(state: Dictionary, table: Array = []) -> Dictionary:
	var out := {}
	for s in (table if not table.is_empty() else steps()):
		var c := str(s["chapter"])
		if not out.has(c):
			out[c] = { "done": 0, "total": 0 }
		out[c]["total"] += 1
		if _has(state.get("done"), str(s["id"])):
			out[c]["done"] += 1
	return out

## True when every step of `chapter` is done.
static func chapter_done(state: Dictionary, chapter: String, table: Array = []) -> bool:
	var p: Dictionary = progress(state, table).get(chapter, { "done": 0, "total": 1 })
	return int(p["done"]) >= int(p["total"])

## True when what the player already has satisfies `step` without the event (a veteran): `facts` is
## `{ items: { key: count }, tags: { key: [tag…] }, stations: [type…], bed: bool, kills: int, slots: [slot…],
## technologies: [key…] }`. Only the kinds a save can show are checked.
static func facts_complete(step: Dictionary, facts: Dictionary) -> bool:
	var t: Dictionary = step["trigger"]
	match str(t["kind"]):
		"item_crafted":
			var items: Dictionary = facts.get("items", {})
			for key in items:
				if int(items[key]) > 0 and _subject_matches(t, { "item": key, "tags": (facts.get("tags", {}) as Dictionary).get(key, []) }):
					return true
		"station_placed":
			return (facts.get("stations", []) as Array).has(str(t["type"]))
		"bed_placed":
			return bool(facts.get("bed", false))
		"creature_killed":
			return int(facts.get("kills", 0)) > 0 and t.has("tag")
		"item_equipped":
			return (facts.get("slots", []) as Array).has(str(t["slot"]))
		"technology_researched":
			return (facts.get("technologies", []) as Array).has(str(t["technology"]))
	return false

## The step ids already satisfied by `facts`, plus every step they require (a later step done means the
## earlier ones were). In fabric order.
static func ids_satisfied(facts: Dictionary, table: Array = []) -> Array:
	var tbl: Array = table if not table.is_empty() else steps()
	var by_id := {}
	for s in tbl:
		by_id[str(s["id"])] = s
	var done := {}
	var pending: Array = []
	for s in tbl:
		if facts_complete(s, facts):
			pending.append(str(s["id"]))
	while not pending.is_empty():
		var id: String = pending.pop_back()
		if done.has(id):
			continue
		done[id] = true
		for r in by_id[id]["requires"]:
			pending.append(str(r))
	var out: Array = []
	for s in tbl:
		if done.has(str(s["id"])):
			out.append(str(s["id"]))
	return out
