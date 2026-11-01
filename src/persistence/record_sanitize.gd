extends RefCounted
## Pure sanitizers for fields of a saved or synced player record, moved out of `PlayerRegistry` (Phase 207
## review: the registry is at the source line cap).

## Most waystones one player may be attuned to.
const MAX_WAYSTONES := 256

## A saved or synced attunement list as sorted unique non-empty strings, at most `MAX_WAYSTONES`.
static func sanitize_waystones(raw: Variant) -> Array:
	var seen := {}
	if raw is Array:
		for v in raw:
			if v is String and v != "" and v.length() <= 64:
				seen[v] = true
	var out: Array = seen.keys()
	out.sort()
	return out.slice(0, MAX_WAYSTONES)

## Phase 161 — a saved or synced XP table as { skill: non-negative int } with bounded names.
static func sanitize_skill_xp(raw: Variant) -> Dictionary:
	var out := {}
	if raw is Dictionary:
		for k in raw:
			if k is String and k != "" and k.length() <= 32 and (raw[k] is int or raw[k] is float) and is_finite(float(raw[k])):
				out[k] = clampi(int(raw[k]), 0, 100000000)
	return out
