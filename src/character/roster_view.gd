extends RefCounted
## Phase 226 — the character list as the host sends it (`PlayerRegistry.roster_view`), checked on arrival. The
## client never decides which characters exist: it shows what this returns and asks the host for every change.

const CreationRules := preload("res://src/character/creation_rules.gd")

const MAX_ID_LEN := 96
const MAX_CHARACTERS := 16
const MAX_KEY_LEN := 48

## A roster view from the wire: every field capped and typed, unknown fields dropped, at most MAX_CHARACTERS.
static func sanitize(raw: Variant) -> Dictionary:
	var d: Dictionary = raw if raw is Dictionary else {}
	var chars: Array = []
	var list: Variant = d.get("characters", [])
	if list is Array:
		for c: Variant in list:
			if chars.size() >= MAX_CHARACTERS:
				break
			if not (c is Dictionary) or str((c as Dictionary).get("id", "")) == "":
				continue
			var at: Variant = (c as Dictionary).get("last_played", 0)
			var look: Dictionary = CreationRules.sanitize_look((c as Dictionary).get("look", {})) if (c as Dictionary).get("look", {}) is Dictionary and not ((c as Dictionary).get("look", {}) as Dictionary).is_empty() else {}
			chars.append({
				"id": str(c["id"]).left(MAX_ID_LEN),
				"name": str((c as Dictionary).get("name", "")).left(CreationRules.MAX_FIELD_LEN),
				"handle": str((c as Dictionary).get("handle", "")).left(32),
				"look": look,
				"last_played": maxi(0, int(at)) if (at is int or at is float) else 0,
				"created": (c as Dictionary).get("created", false) == true,
			})
	var res: Variant = d.get("result", {})
	var r: Dictionary = res if res is Dictionary else {}
	var lim: Variant = d.get("limit", 0)
	return {
		"account": str(d.get("account", "")).left(MAX_ID_LEN),
		"characters": chars,
		"last": str(d.get("last", "")).left(MAX_ID_LEN),
		"limit": clampi(int(lim), 0, MAX_CHARACTERS) if (lim is int or lim is float) else 0,
		"result": {
			"op": str(r.get("op", "")).left(8),
			"reason": str(r.get("reason", "")).left(MAX_KEY_LEN),
			"id": str(r.get("id", "")).left(MAX_ID_LEN),
		},
	}

## The entry for `id` in a view, or {}.
static func entry(view: Dictionary, id: String) -> Dictionary:
	for c: Dictionary in view.get("characters", []):
		if str(c["id"]) == id:
			return c
	return {}

## Whether the view's account may make another character (the host checks again).
static func may_create(view: Dictionary) -> bool:
	return (view.get("characters", []) as Array).size() < int(view.get("limit", 0))
