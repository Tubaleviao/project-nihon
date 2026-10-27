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
	for i in name.length():
		var ch := name[i]
		var cp := name.unicode_at(i)
		if _in_ranges(cp, combining):
			if not prev_letter:
				return "name_chars"   # a mark must sit on a letter
			continue
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
