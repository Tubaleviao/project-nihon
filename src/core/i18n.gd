extends RefCounted
## Phase 131 — the one door to translated text. `locale/ui.csv` (columns `keys,en,pt_BR,...`) is read
## at runtime and registered with the `TranslationServer`, so a new language is a new column and
## nothing else. (The CSV is parsed here instead of through the editor's import so the headless
## suite, CI and exports all see the same catalog without an import step.)
##
## Placeholders are positional and order-independent: `{0}`, `{1}` ... filled from `args`, so a
## translation may reorder them. A missing key renders as the key itself, never as an empty string.
const CATALOG_PATH := "res://locale/ui.csv"
const FALLBACK := "en"
## Wire limits for a host-originated message (key + args): bounded like any network input.
const MAX_ARGS := 4
const MAX_ARG_LEN := 64
const MAX_KEY_LEN := 64
## The key a client shows for a message it cannot render (unknown key, bad args).
const UNKNOWN_KEY := "msg.unknown"

static var _loaded: bool = false
static var _catalog: Dictionary = {}   # locale -> { key -> text }
static var _locales: Array = []

## Parse the CSV and register one `Translation` per locale column. Idempotent.
static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed := parse_csv(CATALOG_PATH)
	_catalog = parsed["catalog"]
	_locales = parsed["locales"]
	for loc in _locales:
		var tr_obj := Translation.new()
		tr_obj.locale = str(loc)
		for key in _catalog[loc]:
			tr_obj.add_message(key, _catalog[loc][key])
		TranslationServer.add_translation(tr_obj)

## Read a catalog CSV: { locales: [..], catalog: { locale: { key: text } }, empty: [[key, locale]],
## dupes: [key], rows: int }. `empty` and `dupes` are for the suite.
static func parse_csv(path: String) -> Dictionary:
	var out := { "locales": [], "catalog": {}, "empty": [], "dupes": [], "rows": 0 }
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	var header := f.get_csv_line()
	var locales: Array = []
	for i in range(1, header.size()):
		var loc := header[i].strip_edges()
		if loc != "":
			locales.append(loc)
			out["catalog"][loc] = {}
	out["locales"] = locales
	var seen: Dictionary = {}
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < 1 or row[0].strip_edges() == "":
			continue
		var key := row[0].strip_edges()
		out["rows"] += 1
		if seen.has(key):
			out["dupes"].append(key)
		seen[key] = true
		for i in locales.size():
			var cell: String = row[i + 1] if i + 1 < row.size() else ""
			if cell.strip_edges() == "":
				out["empty"].append([key, locales[i]])
			out["catalog"][locales[i]][key] = cell
	return out

static func locales() -> Array:
	ensure_loaded()
	return _locales.duplicate()

static func has_key(key: String) -> bool:
	ensure_loaded()
	return _catalog.has(FALLBACK) and (_catalog[FALLBACK] as Dictionary).has(key)

## Translate `key` in the active locale and fill `{0}`.. from `args`.
static func t(key: String, args: Array = []) -> String:
	ensure_loaded()
	return fill(TranslationServer.translate(key), args)

static func fill(text: String, args: Array) -> String:
	for i in args.size():
		text = text.replace("{%d}" % i, str(args[i]))
	return text

## A host message as it travels: key + args, no rendered text.
static func msg(key: String, args: Array = []) -> Dictionary:
	return { "key": key, "args": args }

## Check a received key + args. Returns a clean `{key, args}`; anything unknown, too long or
## carrying nested values becomes the generic fallback line (never the raw input).
static func sanitize_msg(key: Variant, args: Variant) -> Dictionary:
	if not (key is String) or (key as String).length() > MAX_KEY_LEN or not has_key(key):
		return msg(UNKNOWN_KEY)
	if args == null:
		return msg(key)
	if not (args is Array) or (args as Array).size() > MAX_ARGS:
		return msg(UNKNOWN_KEY)
	var clean: Array = []
	for a in args:
		if not (a is String or a is int or a is float):
			return msg(UNKNOWN_KEY)
		if str(a).length() > MAX_ARG_LEN:
			return msg(UNKNOWN_KEY)
		clean.append(a)
	return msg(key, clean)

## Render a `{key, args}` message in the active locale.
static func render(m: Dictionary) -> String:
	return t(str(m.get("key", UNKNOWN_KEY)), m.get("args", []))

## Numbers and dates follow the active locale: decimal comma in pt_BR, point in en.
static func number(value: float, decimals: int = 0) -> String:
	var s := String.num(value, decimals)
	if TranslationServer.get_locale().begins_with("pt"):
		s = s.replace(".", ",")
	return s

static func date(unix: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(unix)
	if TranslationServer.get_locale().begins_with("pt"):
		return "%02d/%02d/%04d" % [d["day"], d["month"], d["year"]]
	return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]
