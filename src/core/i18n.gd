extends RefCounted
## Phase 131 — the one door to translated text. `locale/ui.csv` (columns `keys,en,pt_BR,...`) is read
## at runtime and registered with the `TranslationServer`, so a new language is a new column and
## nothing else. (The CSV is parsed here instead of through the editor's import so the headless
## suite, CI and exports all see the same catalog without an import step.)
##
## Placeholders are positional and order-independent: `{0}`, `{1}` ... filled from `args`, so a
## translation may reorder them. A missing key renders as the key itself, never as an empty string.
const Diag := preload("res://src/core/diag.gd")
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
## Where the catalog is read from; the suite points it at a missing file to prove the retry.
static var catalog_path: String = CATALOG_PATH
## How many times a load found no catalog (the suite reads it; each one also logs an error).
static var load_failures: int = 0

## Parse the CSV and register one `Translation` per locale column. Idempotent once it succeeds. A
## missing or empty catalog logs one error and leaves the class unloaded, so the next call retries
## (every key would otherwise render raw and every host message would become `msg.unknown`).
static func ensure_loaded() -> void:
	if _loaded:
		return
	var parsed := parse_csv(catalog_path)
	if (parsed["locales"] as Array).is_empty() or int(parsed["rows"]) == 0:
		load_failures += 1
		Diag.error("I18n: catalog %s is missing or empty — text renders as raw keys" % catalog_path)
		return
	_loaded = true
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
	var found: Array = []
	for i in range(1, header.size()):
		var loc := header[i].strip_edges()
		if loc != "":
			found.append(loc)
			out["catalog"][loc] = {}
	out["locales"] = found
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
		for i in found.size():
			var cell: String = row[i + 1] if i + 1 < row.size() else ""
			if cell.strip_edges() == "":
				out["empty"].append([key, found[i]])
			out["catalog"][found[i]][key] = cell
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

## `{N}` is argument N as text (any number of digits). `{N:D}` formats a numeric argument for the
## active locale with D decimals (`{0:1}` renders 1234.5 as `1,234.5` in en and `1.234,5` in pt_BR),
## so a host sends the raw number and each client formats it.
static func fill(text: String, args: Array) -> String:
	# One pass, so text injected by an argument (a handle, a waypoint name) is never re-scanned.
	var out := ""
	var i := 0
	while i < text.length():
		var c := text[i]
		if c == "{":
			var close := text.find("}", i + 1)
			if close > i + 1 and close - i <= 8:
				var parts := text.substr(i + 1, close - i - 1).split(":")
				if parts.size() <= 2 and parts[0].is_valid_int() and (parts.size() == 1 or parts[1].is_valid_int()):
					var idx := parts[0].to_int()
					if idx >= 0 and idx < args.size():
						var a: Variant = args[idx]
						if parts.size() == 2 and (a is float or a is int):
							out += number(float(a), parts[1].to_int())
						else:
							out += str(a)
						i = close + 1
						continue
		out += c
		i += 1
	return out

## A slice `reason` code (`missing_inputs`, `station_required:forge`) as text in the active locale:
## the part before the first `:` picks the `reason.<code>` key and the rest are its `{0}`.. params.
static func reason_text(code: String) -> String:
	var parts := code.split(":")
	var key := "reason." + parts[0]
	if parts[0] == "" or not has_key(key):
		return t("reason.unknown", [code])
	return t(key, Array(parts.slice(1)))

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
		# The wire is JSON: whole numbers come back as floats ("3.0"), so restore the int.
		if a is float and is_finite(a) and a == floorf(a) and absf(a) < 1e15:
			a = int(a)
		clean.append(a)
	return msg(key, clean)

## Render a `{key, args}` message in the active locale.
static func render(m: Dictionary) -> String:
	return t(str(m.get("key", UNKNOWN_KEY)), m.get("args", []))

## Numbers and dates follow the active locale: pt_BR groups with "." and uses a decimal comma,
## en groups with "," and uses a decimal point.
static func number(value: float, decimals: int = 0) -> String:
	var s := String.num(absf(value), decimals)
	var dot := s.find(".")
	var whole := s if dot < 0 else s.substr(0, dot)
	var frac := "" if dot < 0 else s.substr(dot + 1)
	var pt := TranslationServer.get_locale().begins_with("pt")
	var group := "." if pt else ","
	var grouped := ""
	for i in whole.length():
		if i > 0 and (whole.length() - i) % 3 == 0:
			grouped += group
		grouped += whole[i]
	if frac != "":
		grouped += ("," if pt else ".") + frac
	var negative := value < 0.0 and grouped.replace(",", "").replace(".", "").lstrip("0") != ""
	return ("-" if negative else "") + grouped

static func date(unix: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(unix)
	if TranslationServer.get_locale().begins_with("pt"):
		return "%02d/%02d/%04d" % [d["day"], d["month"], d["year"]]
	return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]
