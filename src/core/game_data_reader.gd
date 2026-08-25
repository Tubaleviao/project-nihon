extends RefCounted
## Shared readers for generated GameData resources.
##
## `newel` emits fabric `json` fields into `.tres` as either a native
## Dictionary/Array or a JSON string (and `string` fields as a plain String).
## These static helpers normalize that ambiguity so slices read fields through
## one code path instead of duplicating the parse-a-string-or-take-the-value
## dance per file. They deliberately return a sensible default rather than
## erroring when a field is absent, because a missing/optional field is a
## content gap, not a crash.

## Read a string-typed field, falling back to `default` when absent/null.
static func str_field(res: Resource, key: String, default: String) -> String:
	var v = res.get(key)
	return str(v) if v != null else default

## Read an int-typed field, accepting int or float storage, else `default`.
static func int_field(res: Resource, key: String, default: int) -> int:
	var v = res.get(key)
	if v is int or v is float:
		return int(v)
	return default

## Read a json-typed field. Accepts a native Dictionary/Array, or a JSON string
## that parses to one; otherwise returns `default`.
static func json_field(res: Resource, key: String, default):
	var v = res.get(key)
	if v is Dictionary or v is Array:
		return v
	if v is String and v != "":
		var parsed = JSON.parse_string(v)
		if parsed != null:
			return parsed
	return default
