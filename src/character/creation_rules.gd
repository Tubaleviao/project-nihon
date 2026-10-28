extends RefCounted
## Phase 180 — pure rules for character creation: the name rule and its uniqueness skeleton, the gender,
## hair and hair-colour checks, and the head-to-height ratio of a preset. No state and no nodes; Phase 181's
## host intent calls these and keeps the taken skeletons.
##
## Tables are `GameData.CREATIONS["CharacterCreation"]` (see fabric/gameplay/characters/creation.js).
## A refusal is a reason id; the client shows `creation.refuse.<reason>` through I18n.t.
##
## Skeleton (a subset of Unicode TR39): lower-case, fold accents and drop combining marks, map confusable
## look-alikes to Latin, drop separators, then replace confusable sequences ("rn" -> "m"). Two names with
## the same skeleton cannot both exist on one server.

const SkeletonRig := preload("res://src/character/skeleton_rig.gd")


static func data() -> Resource:
	return GameData.CREATIONS.get("CharacterCreation", null)


static func _name_rule() -> Dictionary:
	var d := data()
	return d.get("name") if d != null else {}


static func refusal_key(reason: String) -> String:
	return "creation.refuse." + reason


static func gender_key(gender: String) -> String:
	return "creation.gender." + gender


## The name as it is stored and shown: edges trimmed. Everything else is checked, never rewritten.
static func normalize_name(raw: String) -> String:
	return raw.strip_edges()


static func _in_ranges(cp: int, ranges: Array) -> bool:
	for r in ranges:
		if cp >= int(r[0]) and cp <= int(r[1]):
			return true
	return false


## The script group a code point belongs to, or "" when it is not a letter of any group.
static func _script_of(cp: int, scripts: Dictionary) -> String:
	for group in scripts:
		if _in_ranges(cp, scripts[group]):
			return str(group)
	return ""


## The refusal reason for a name, or "" when it may be used. `taken` holds the skeletons of the names
## already on the server (skeleton -> anything).
static func name_refusal(raw: String, taken: Dictionary = {}) -> String:
	var rule := _name_rule()
	if rule.is_empty():
		return "name_chars"
	var name := normalize_name(raw)
	var separators: Array = rule.get("separators", [])
	var combining: Array = rule.get("combining", [])
	var scripts: Dictionary = rule.get("scripts", {})
	var length := 0
	var seps := 0
	var group := ""
	var mixed := false
	var prev_letter := false
	var marks := 0
	var max_marks := int(rule.get("maxMarksPerLetter", 2))
	for i in name.length():
		var ch := name[i]
		var cp := name.unicode_at(i)
		if _in_ranges(cp, combining):
			marks += 1
			if not prev_letter or marks > max_marks:
				return "name_chars"   # a mark must sit on a letter, and only a few may stack
			continue
		marks = 0
		length += 1
		if ch in separators:
			seps += 1
			prev_letter = false
			continue
		var g := _script_of(cp, scripts)
		if g == "":
			return "name_chars"
		if group == "":
			group = g
		elif g != group:
			mixed = true
		prev_letter = true
	if seps > int(rule.get("maxSeparators", 1)):
		return "name_separator"
	if name.length() > 0 and (name[0] in separators or name[name.length() - 1] in separators):
		return "name_separator"
	if mixed:
		return "name_script"
	if length < int(rule.get("minLength", 3)) or length > int(rule.get("maxLength", 16)):
		return "name_length"
	var sk := skeleton(name)
	for r in rule.get("reserved", []):
		if sk == skeleton(str(r)):
			return "name_reserved"
	if taken.has(sk):
		return "name_taken"
	return ""


## The uniqueness key of a name (see the module comment).
static func skeleton(name: String) -> String:
	var rule := _name_rule()
	var fold: Dictionary = rule.get("accentFold", {})
	var confusables: Dictionary = rule.get("confusables", {})
	var separators: Array = rule.get("separators", [])
	var combining: Array = rule.get("combining", [])
	var lower := normalize_name(name).to_lower()
	var out := ""
	for i in lower.length():
		if _in_ranges(lower.unicode_at(i), combining):
			continue
		var folded: String = fold.get(lower[i], lower[i])
		for j in folded.length():
			var c := folded[j]
			if c in separators:
				continue
			out += str(confusables.get(c, c))
	var sequences: Dictionary = rule.get("confusableSequences", {})
	for k in sequences:
		out = out.replace(str(k), str(sequences[k]))
	return out


## The refusal reason for a creation's gender, hair and colour, or "" (the name is `name_refusal`'s).
## `c` is { gender, hair, hairColor }, as the wire carries it.
static func choice_refusal(c: Dictionary) -> String:
	var d := data()
	if d == null:
		return "gender"
	var genders: Dictionary = d.get("genders")
	var gender := str(c.get("gender", ""))
	if not genders.has(gender):
		return "gender"
	var styles: Dictionary = d.get("hairStyles")
	var hair := str(c.get("hair", ""))
	if not styles.has(hair):
		return "hair"
	if str((styles[hair] as Dictionary).get("gender", "")) != gender:
		return "hair_gender"
	var color: Variant = c.get("hairColor", null)
	if not (color is int or color is float) or float(color) != floorf(float(color)):
		return "hair_color"
	for allowed in d.get("hairColors"):
		if int(allowed) == int(color):
			return ""
	return "hair_color"


## The first refusal for a whole creation ({ name, gender, hair, hairColor }), or "".
static func creation_refusal(c: Dictionary, taken: Dictionary = {}) -> String:
	var reason := name_refusal(str(c.get("name", "")), taken)
	return reason if reason != "" else choice_refusal(c)


# ---------------------------------------------------------------------------
# Phase 181 — the creation record, its look on the wire and the screen's choices
# ---------------------------------------------------------------------------

## A player record's `creation` state: "none" (never decided: the screen is offered), "skipped" (the player
## kept the default look and their handle) or "created".
const STATE_NONE := "none"
const STATE_SKIPPED := "skipped"
const STATE_CREATED := "created"
## A player may try a creation (or a skip) at most once per this many milliseconds; faster ones are refused.
const RATE_LIMIT_MSEC := 500
## Longest wire string the intent reads for any field (a name is at most 16 letters plus marks).
const MAX_FIELD_LEN := 64


## A saved or synced creation state: { state, name, gender, hair, hairColor }. A record from before Phase 181
## (no key, or anything that does not parse) is "none". A "created" state whose choices or name no longer pass
## the rules falls back to "none", so it is offered again rather than drawn wrong.
static func sanitize_state(raw: Variant) -> Dictionary:
	var out := { "state": STATE_NONE }
	if not (raw is Dictionary):
		return out
	var s := str((raw as Dictionary).get("state", STATE_NONE))
	if s == STATE_SKIPPED:
		out["state"] = STATE_SKIPPED
	elif s == STATE_CREATED:
		var c := { "name": normalize_name(str(raw.get("name", ""))).left(MAX_FIELD_LEN), "gender": str(raw.get("gender", "")),
			"hair": str(raw.get("hair", "")), "hairColor": raw.get("hairColor", null) }
		if name_refusal(c["name"]) == "" and choice_refusal(c) == "":
			c["hairColor"] = int(c["hairColor"])
			c["state"] = STATE_CREATED
			out = c
	return out


## True while the screen should be offered: the player neither created a character nor skipped.
static func should_offer(state: Dictionary) -> bool:
	return str(state.get("state", STATE_NONE)) == STATE_NONE


## True once a character exists (the screen is no longer reachable from the character sheet).
static func is_created(state: Dictionary) -> bool:
	return str(state.get("state", STATE_NONE)) == STATE_CREATED


## The name a player is shown by: the created name, else their public handle.
static func display_name(state: Dictionary, handle: String) -> String:
	return str(state.get("name", "")) if is_created(state) else handle


## What other peers are sent about a player: { name, gender, hair, hairColor } for a created character, or
## { name } (the handle) for one that has none, which keeps the default look.
static func look(state: Dictionary, handle: String) -> Dictionary:
	if not is_created(state):
		return { "name": handle }
	return { "name": str(state["name"]), "gender": str(state["gender"]), "hair": str(state["hair"]), "hairColor": int(state["hairColor"]) }


## A look as it arrives from the host: the name capped, the choices kept only when they pass the rules.
static func sanitize_look(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return {}
	var out := { "name": str((raw as Dictionary).get("name", "")).left(MAX_FIELD_LEN) }
	var c := { "gender": str(raw.get("gender", "")), "hair": str(raw.get("hair", "")), "hairColor": raw.get("hairColor", null) }
	if choice_refusal(c) == "":
		c["hairColor"] = int(c["hairColor"])
		out.merge(c)
	return out


## The creation fields a client intent carries, as strings and an int, capped; nothing else is read.
static func intent_fields(raw: Variant) -> Dictionary:
	var d: Dictionary = raw if raw is Dictionary else {}
	var color: Variant = d.get("hairColor", null)
	return { "name": str(d.get("name", "")).left(MAX_FIELD_LEN), "gender": str(d.get("gender", "")).left(MAX_FIELD_LEN),
		"hair": str(d.get("hair", "")).left(MAX_FIELD_LEN), "hairColor": int(color) if (color is int or color is float) and is_finite(float(color)) and float(color) == floorf(float(color)) else -1 }


## The genders in a stable order.
static func genders() -> Array:
	var d := data()
	var out: Array = (d.get("genders") as Dictionary).keys() if d != null else []
	out.sort()
	return out


## The hair styles of one gender, sorted by id.
static func hair_options(gender: String) -> Array:
	var d := data()
	var out: Array = []
	if d == null:
		return out
	var styles: Dictionary = d.get("hairStyles")
	for id in styles:
		if str((styles[id] as Dictionary).get("gender", "")) == gender:
			out.append(str(id))
	out.sort()
	return out


## The curated hair colours (palette indices), in fabric order.
static func color_options() -> Array:
	var d := data()
	return (d.get("hairColors") as Array).duplicate() if d != null else []


## The default creation: { gender, hair, hairColor }.
static func default_choice() -> Dictionary:
	var d := data()
	return (d.get("defaultCreation") as Dictionary).duplicate() if d != null else {}


## A random valid gender, hair and colour, drawn from `rng`.
static func random_choice(rng: RandomNumberGenerator) -> Dictionary:
	var gs := genders()
	if gs.is_empty():
		return default_choice()
	var g := str(gs[rng.randi_range(0, gs.size() - 1)])
	var hairs := hair_options(g)
	var colors := color_options()
	return { "gender": g, "hair": str(hairs[rng.randi_range(0, hairs.size() - 1)]), "hairColor": int(colors[rng.randi_range(0, colors.size() - 1)]) }


## The items a created character is given once: [{ item, quantity, equip }].
static func starting_kit() -> Array:
	var d := data()
	return (d.get("startingKit") as Array).duplicate(true) if d != null else []


## The appearance preset (GameData.APPEARANCES) a gender uses, or null.
static func preset(gender: String) -> Resource:
	var d := data()
	if d == null:
		return null
	var row: Dictionary = (d.get("genders") as Dictionary).get(gender, {})
	return GameData.APPEARANCES.get(str(row.get("appearance", "")), null)


## Head height over total height of a body with these proportions, from the same landmarks the rig is built
## with (`SkeletonRig.compute_landmarks` on the HumanoidSkeleton coefficients).
static func head_ratio(props: Dictionary) -> float:
	var skel: Resource = GameData.SKELETONS.get("HumanoidSkeleton", null)
	var coeffs: Dictionary = skel.get("bodyShapeCoefficients") if skel != null else {}
	var lm: Dictionary = SkeletonRig.compute_landmarks(coeffs, props)
	return float(lm["head_size"]) / float(lm["head_top"])
