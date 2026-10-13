extends RefCounted
## Save transaction — a set of staged `.tmp` files made live together (Phase 121).
##
## A save stages every file it writes (region files, `world.json`) as a `<path>.tmp` sibling, then
## `commit` makes them live: a small journal naming every target is written first, each target is
## moved aside to `<path>.bak` and its `.tmp` renamed into place, and the journal is deleted last-but-
## one (before the `.bak` files). A failed step rolls every moved file back, so a failure leaves the
## full old state. A crash mid-commit leaves the journal behind and `recover` (run on load) rolls
## back from the `.bak` files; a crash before the journal exists leaves only `.tmp` files, which
## `recover` deletes; a crash after the journal was deleted leaves the full new state.
##
## `fault` is a test hook: `fault.call(step)` returning true fails that step ("journal", "backup",
## "region_rename", "world_rename") with no change to the disk.
const Diag := preload("res://src/core/diag.gd")

const TMP_EXT := ".tmp"
const BAK_EXT := ".bak"

## Make the staged `ops` live. Each op is { "path": String, "tmp": String ("" removes the target),
## "kind": "region" | "world" }. Returns OK, or the first error with every moved file put back.
static func commit(ops: Array, journal_path: String, fault: Callable = Callable()) -> int:
	if ops.is_empty():
		return OK
	var targets: Array = []
	for op in ops:
		targets.append({ "path": str(op["path"]), "had": FileAccess.file_exists(str(op["path"])) })
	if _fails(fault, "journal"):
		discard(ops)
		return ERR_CANT_CREATE
	var jfile := FileAccess.open(journal_path, FileAccess.WRITE)
	if jfile == null:
		var jerr := FileAccess.get_open_error()
		Diag.error("SaveTxn: cannot open %s for write — %s" % [journal_path, error_string(jerr)])
		discard(ops)
		return jerr
	jfile.store_string(JSON.stringify({ "targets": targets }))
	jfile.close()
	var done: Array = []
	for op in ops:
		var path := str(op["path"])
		var err := OK
		if FileAccess.file_exists(path):
			err = ERR_CANT_CREATE if _fails(fault, "backup") else DirAccess.rename_absolute(path, path + BAK_EXT)
		if err == OK and str(op.get("tmp", "")) != "":
			err = ERR_CANT_CREATE if _fails(fault, str(op.get("kind", "region")) + "_rename") \
					else DirAccess.rename_absolute(str(op["tmp"]), path)
			if err != OK and FileAccess.file_exists(path + BAK_EXT):
				done.append(path)   # moved aside already: roll it back with the rest
		if err != OK:
			Diag.error("SaveTxn: committing %s failed — %s; rolling back %d file(s)" % [path, error_string(err), done.size()])
			var clean := _rollback(done)
			discard(ops)
			if clean:
				DirAccess.remove_absolute(journal_path)
			return err
		done.append(path)
	DirAccess.remove_absolute(journal_path)   # the commit point: past it a crash keeps the new state
	for path in done:
		if FileAccess.file_exists(str(path) + BAK_EXT):
			DirAccess.remove_absolute(str(path) + BAK_EXT)
	return OK

## Delete the staged `.tmp` files of `ops` (a save that is not going to commit).
static func discard(ops: Array) -> void:
	for op in ops:
		var tmp := str(op.get("tmp", ""))
		if tmp != "" and FileAccess.file_exists(tmp):
			DirAccess.remove_absolute(tmp)

## Put every path in `done` back to its `.bak` (or remove it when it had none). True when all landed.
static func _rollback(done: Array) -> bool:
	var ok := true
	for i in range(done.size() - 1, -1, -1):
		var path := str(done[i])
		var bak := path + BAK_EXT
		if FileAccess.file_exists(bak):
			if FileAccess.file_exists(path) and DirAccess.remove_absolute(path) != OK:
				ok = false
				continue
			if DirAccess.rename_absolute(bak, path) != OK:
				ok = false
		elif FileAccess.file_exists(path):
			if DirAccess.remove_absolute(path) != OK:
				ok = false
	return ok

## Run on load: finish or undo a save that was interrupted, then delete stray `.tmp` / `.bak` files
## in `dirs`. Returns how many files were removed or restored.
static func recover(journal_path: String, dirs: Array) -> int:
	var touched := 0
	if FileAccess.file_exists(journal_path):
		var f := FileAccess.open(journal_path, FileAccess.READ)
		var data: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
		if f != null:
			f.close()
		if data is Dictionary and (data as Dictionary).get("targets", null) is Array:
			Diag.warn("SaveTxn: an interrupted save was found — rolling back to the previous world")
			var targets: Array = data["targets"]
			# A target moved aside is restored from its `.bak`; one that had no previous file is
			# removed; one that was never reached (it had a file, no `.bak` yet) is left alone.
			var moved: Array = []
			for t in targets:
				if not (t is Dictionary):
					continue
				var tpath := str(t.get("path", ""))
				if tpath != "" and (not bool(t.get("had", true)) or FileAccess.file_exists(tpath + BAK_EXT)):
					moved.append(tpath)
			touched += moved.size()
			if _rollback(moved):
				DirAccess.remove_absolute(journal_path)
		else:
			DirAccess.remove_absolute(journal_path)   # torn before any rename: nothing to undo
	for dir in dirs:
		var d := DirAccess.open(str(dir))
		if d == null:
			continue
		for name in d.get_files():
			if name.ends_with(TMP_EXT) or (name.ends_with(BAK_EXT) and not FileAccess.file_exists(journal_path)):
				if DirAccess.remove_absolute(str(dir).path_join(name)) == OK:
					touched += 1
	return touched

static func _fails(fault: Callable, step: String) -> bool:
	return fault.is_valid() and bool(fault.call(step))
