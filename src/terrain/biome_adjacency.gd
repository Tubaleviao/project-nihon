extends RefCounted
## Phase 112 — the biome adjacency rules and an offline scan of them.
##
## The fabric (`fabric/world/biomes/adjacency.js`) authors, per biome, a symmetric list of
## `forbiddenNeighbours` and a `transition` biome that belongs between a forbidden pair. They are
## enforced OFFLINE: this scan counts the forbidden 4-neighbour pairs a generator produces over a
## grid, so a new biome or envelope is checked before it ships. A chunk's biome stays a pure
## function of seed and position; nothing here runs per chunk. Phase 113 reads `transition`.

## biome key -> Array of forbidden neighbour keys, from the fabric biome resources.
static func table() -> Dictionary:
	var out: Dictionary = {}
	for key in GameData.BIOMES:
		var f: Variant = GameData.BIOMES[key].get("forbiddenNeighbours")
		out[str(key)] = (f as Array).duplicate() if f is Array else []
	return out

## biome key -> its transition biome key ("" when it has no forbidden neighbour).
static func transitions() -> Dictionary:
	var out: Dictionary = {}
	for key in GameData.BIOMES:
		var t: Variant = GameData.BIOMES[key].get("transition")
		out[str(key)] = str(t) if t != null else ""
	return out

static func is_forbidden(rules: Dictionary, a: String, b: String) -> bool:
	return a != b and (rules.get(a, []) as Array).has(b)

## Forbidden 4-neighbour pairs over the `size` x `size` chunk grid whose corner is `origin`.
## `biome_at` is a Callable(Vector2i) -> String. Returns `[{ "a": Vector2i, "b": Vector2i, "pair": "A|B" }]`
## (the pair name sorted), at most `limit` of them. Each edge is counted once.
static func scan(biome_at: Callable, rules: Dictionary, origin: Vector2i, size: int, limit: int = 64) -> Array:
	var out: Array = []
	var prev_row: Array = []
	for dz in size:
		var row: Array = []
		row.resize(size)
		for dx in size:
			var c := origin + Vector2i(dx, dz)
			var b: String = biome_at.call(c)
			row[dx] = b
			var west: String = row[dx - 1] if dx > 0 else ""
			var north: String = prev_row[dx] if dz > 0 else ""
			if west != "" and is_forbidden(rules, west, b):
				out.append({"a": c + Vector2i(-1, 0), "b": c, "pair": _pair(west, b)})
			if north != "" and is_forbidden(rules, north, b):
				out.append({"a": c + Vector2i(0, -1), "b": c, "pair": _pair(north, b)})
			if out.size() >= limit:
				return out
		prev_row = row
	return out

static func _pair(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]
