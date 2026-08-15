extends Node
## Persistence slice — JSON save/load via FileAccess.
##
## Plug contract (GameBus signals consumed / emitted):
##   IN  : save_requested(slot, data)
##   OUT : save_completed(slot)
##         load_completed(slot, data)
##         load_failed(slot, reason)
##
## Public API:
##   save(slot: int, data: Dictionary) -> Error
##   load_slot(slot: int)              -> Dictionary  (empty dict on failure)

const SAVE_DIR  := "user://saves/"
const SAVE_EXT  := ".json"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	GameBus.save_requested.connect(_on_save_requested)
	GameBus.load_requested.connect(_on_load_requested)

## Serialize data to the slot file.
func save(slot: int, data: Dictionary) -> Error:
	var path := _path(slot)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("PersistenceSlice: cannot open %s for write — %s" % [path, error_string(FileAccess.get_open_error())])
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	GameBus.save_completed.emit(slot)
	print("PersistenceSlice: saved slot %d → %s" % [slot, path])
	return OK

## Deserialize and return the slot data, or an empty dict on failure.
## Emits load_completed on success and load_failed on any failure.
func load_slot(slot: int) -> Dictionary:
	var path := _path(slot)
	if not FileAccess.file_exists(path):
		var reason := "slot %d not found at %s" % [slot, path]
		push_warning("PersistenceSlice: " + reason)
		GameBus.load_failed.emit(slot, reason)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var reason := "cannot open %s for read — %s" % [path, error_string(FileAccess.get_open_error())]
		push_error("PersistenceSlice: " + reason)
		GameBus.load_failed.emit(slot, reason)
		return {}
	var text  := file.get_as_text()
	file.close()
	var data = JSON.parse_string(text)
	if data == null or not data is Dictionary:
		var reason := "slot %d contains invalid JSON" % slot
		push_error("PersistenceSlice: " + reason)
		GameBus.load_failed.emit(slot, reason)
		return {}
	GameBus.load_completed.emit(slot, data)
	print("PersistenceSlice: loaded slot %d ← %s" % [slot, path])
	return data

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _path(slot: int) -> String:
	return SAVE_DIR + "slot_%02d" % slot + SAVE_EXT

func _on_save_requested(slot: int, data: Dictionary) -> void:
	save(slot, data)

func _on_load_requested(slot: int) -> void:
	load_slot(slot)
