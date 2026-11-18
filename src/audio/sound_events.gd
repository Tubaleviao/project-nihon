extends RefCounted
## Phase 275 — the sound event table, read from the fabric's `SoundEvents` world system
## (`GameData.WORLD_SYSTEMS["SoundEvents"]`, generated from `fabric/gameplay/sounds.js`). Gameplay names an
## event id; this maps it to its row (key, bus, spatial, variants, volumeDb, pitchJitter, loop, maxDistance)
## and its asset keys. Pure lookups, no state: `Sound` (`sound_player.gd`) plays what these describe.

static func _table() -> Resource:
	return GameData.WORLD_SYSTEMS.get("SoundEvents", null)


## Every event id, sorted.
static func ids() -> Array:
	var t := _table()
	var out: Array = (t.events as Dictionary).keys() if t != null else []
	out.sort()
	return out


static func has_event(id: String) -> bool:
	var t := _table()
	return t != null and (t.events as Dictionary).has(id)


## The event's row, or {} for an unknown id.
static func event(id: String) -> Dictionary:
	var t := _table()
	if t == null:
		return {}
	return (t.events as Dictionary).get(id, {})


## The event's asset keys: one `<key>.ogg.raw`, or `<key>_01.ogg.raw`.. for sfx variants. [] for an unknown id.
static func files(id: String) -> Array:
	var t := _table()
	if t == null:
		return []
	return (t.files as Dictionary).get(id, [])


## Every asset key of every event, sorted.
static func all_files() -> Array:
	var out: Array = []
	for id in ids():
		out.append_array(files(id))
	out.sort()
	return out


## The buses under Master the fabric expects (`default_bus_layout.tres` order).
static func buses() -> Array:
	var t := _table()
	return (t.buses as Array).duplicate() if t != null else []
