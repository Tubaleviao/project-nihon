extends Node
## Persistence slice — JSON save/load via FileAccess.
##
## Two save shapes live here (Phase 33):
##
##   • **Server records** — the authoritative save lifecycle. `server_save_dir`
##     holds ONE world record (chunk manifests, stations, creature state, the
##     local player id) plus ONE record per player (position, HP, inventory with
##     per-instance durability, technology). Records are keyed by the
##     server-issued `player_id`, never by `peer_id`. Writes go through a temp
##     file + rename so a kill during a save cannot leave a truncated record.
##   • **Legacy slot files** — `user://saves/slot_NN.json`, the single-file path
##     the boot sample, the client-side sample, and the older tests use. Kept
##     working unchanged.
##
## **Durability limit of the atomic write (see `_write_json`):** temp-file +
## rename is atomic against the PROCESS dying (a kill or SIGTERM mid-save leaves
## either the old record or the new one, never a truncated file), but it is NOT
## atomic against the MACHINE losing power — the file is never `fsync`ed, so the
## rename (or the data behind it) can still be missing after a hard power loss.
## Godot exposes no fsync (`FileAccess.flush()` is a userspace buffer flush), so
## that half is a documented limit, not a guarantee.
##
## Every path and interval comes from the fabric `PersistenceSystem`
## (GameData.WORLD_SYSTEMS) rather than a bare GDScript literal; the values below
## are only the fallbacks used when the fabric has no entry.
##
## Plug contract (GameBus signals consumed / emitted):
##   IN  : save_requested(slot, data)
##         load_requested(slot)
##   OUT : save_completed(slot)
##         load_completed(slot, data)
##         load_failed(slot, reason)
##         world_saved()                  — authoritative world record written
##         world_save_failed(reason)
##         player_saved(player_id)
##
## Public API:
##   save(slot: int, data: Dictionary) -> Error
##   load_slot(slot: int)              -> Dictionary  (empty dict on failure)
##   save_world(data: Dictionary, incremental := false) -> Error
##   load_world()                      -> Dictionary  (empty dict when absent)
##   has_world()                       -> bool
##   save_player(player_id, data)      -> Error
##   load_player(player_id)            -> Dictionary
##   list_player_records()             -> Array       (player ids on disk)
##   write_job(job)                    -> int         (thread-safe batch write)
##   world_path() / player_path(id) / slot_path(slot) -> String
##   sanitize_player_id(player_id)     -> String      (pure, path-safe)
##   autosave_due(elapsed, interval)   -> bool  (static, pure)
##   resolved_autosave_interval(value) -> float (static, pure)
##   merge_creature_states(base, inc)  -> Array (static, pure)

const SAVE_DIR  := "user://saves/"
const SAVE_EXT  := ".json"

## Fabric-derived save layout (see _load_config). The defaults mirror
## `fabric/gameplay/persistence.js`.
const DEFAULT_SERVER_SAVE_DIR := "user://saves/server/"
const DEFAULT_WORLD_FILE      := "world.json"
const DEFAULT_PLAYER_PREFIX   := "player_"
const DEFAULT_AUTOSAVE_SECS   := 300.0
const DEFAULT_SHUTDOWN_PATH   := "user://shutdown_requested"

var server_save_dir: String = DEFAULT_SERVER_SAVE_DIR
var world_file: String = DEFAULT_WORLD_FILE
var player_prefix: String = DEFAULT_PLAYER_PREFIX
var autosave_interval: float = DEFAULT_AUTOSAVE_SECS
var shutdown_request_path: String = DEFAULT_SHUTDOWN_PATH
var atomic_writes: bool = true

func _ready() -> void:
	_load_config()
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	DirAccess.make_dir_recursive_absolute(server_save_dir)
	GameBus.save_requested.connect(_on_save_requested)
	GameBus.load_requested.connect(_on_load_requested)

## Read the save lifecycle configuration from the fabric. Missing entries fall
## back to the constants above so a slice built before GameData loads (or a
## headless test) still works.
func _load_config() -> void:
	var res: Resource = GameData.WORLD_SYSTEMS.get("PersistenceSystem", null)
	if res == null:
		return
	server_save_dir     = str(res.get("serverSaveDir"))
	world_file          = str(res.get("worldFileName"))
	player_prefix       = str(res.get("playerFilePrefix"))
	autosave_interval   = float(res.get("autosaveIntervalSeconds"))
	shutdown_request_path = str(res.get("shutdownRequestPath"))
	atomic_writes       = bool(res.get("atomicWrites"))
	if server_save_dir.is_empty():
		server_save_dir = DEFAULT_SERVER_SAVE_DIR
	if world_file.is_empty():
		world_file = DEFAULT_WORLD_FILE
	if player_prefix.is_empty():
		player_prefix = DEFAULT_PLAYER_PREFIX
	# An interval of 0 (or a negative) does NOT mean "never autosave": a headless
	# server has no other save hook (Godot 4.7 delivers nothing for SIGTERM), so
	# honouring it would silently drop the only bound on how much world state a
	# hard kill can lose. Fall back like the string fields above instead.
	autosave_interval = resolved_autosave_interval(autosave_interval)

# ---------------------------------------------------------------------------
# Legacy slot path
# ---------------------------------------------------------------------------

## Serialize data to the slot file.
func save(slot: int, data: Dictionary) -> Error:
	var path := slot_path(slot)
	var err := _write_json(path, data)
	if err == OK:
		GameBus.save_completed.emit(slot)
	return err

## Deserialize and return the slot data, or an empty dict on failure.
## Emits load_completed on success and load_failed on any failure.
func load_slot(slot: int) -> Dictionary:
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		var reason := "slot %d not found at %s" % [slot, path]
		push_warning("PersistenceSlice: " + reason)
		GameBus.load_failed.emit(slot, reason)
		return {}
	var data := _read_json(path)
	if data.is_empty():
		var reason := "slot %d contains invalid JSON" % slot
		push_error("PersistenceSlice: " + reason)
		GameBus.load_failed.emit(slot, reason)
		return {}
	GameBus.load_completed.emit(slot, data)
	return data

# ---------------------------------------------------------------------------
# Authoritative server records (Phase 33)
# ---------------------------------------------------------------------------

## Write the authoritative world record. When `incremental` is set, the record on
## disk is read first and only the chunk manifests carried in `data` are merged
## in (`_merge_world`), so an autosave re-serializes the dirty chunks instead of
## every loaded chunk. The first save of a fresh world is always full.
func save_world(data: Dictionary, incremental: bool = false) -> Error:
	var err := _write_world_payload(data, incremental)
	if err == OK:
		GameBus.world_saved.emit()
	else:
		GameBus.world_save_failed.emit(error_string(err))
	return err

## Serialize and write one pre-collected save job, on the CALLER's thread. The job
## is plain data — { "world": Dictionary, "incremental": bool, "players":
## { player_id: Dictionary } } — collected on the main thread because that is the
## half which reads slice state. Everything here is JSON encode + FileAccess, with
## no bus signals and no node access, so it is safe to run on a worker thread (see
## game_root's save thread, which is the whole point: serializing a full record
## inline stalls the frame that triggered the autosave). Returns OK, or the first
## Error encountered — the caller reports it, because a worker cannot emit.
func write_job(job: Dictionary) -> int:
	var world: Variant = job.get("world", {})
	if world is Dictionary and not (world as Dictionary).is_empty():
		var world_err := _write_world_payload(world, bool(job.get("incremental", false)))
		if world_err != OK:
			return world_err
	var players: Variant = job.get("players", {})
	if players is Dictionary:
		for player_id in players:
			var data: Variant = players[player_id]
			if not (data is Dictionary):
				continue
			var err := _write_json(player_path(str(player_id)), data)
			if err != OK:
				return err
	return OK

## The world-record half of a save, without the bus signals: read the existing
## record and merge an incremental payload into it, then write. Split out of
## save_world() so write_job() can run it on a worker.
func _write_world_payload(data: Dictionary, incremental: bool) -> Error:
	var payload := data
	if incremental:
		var existing := load_world()
		if not existing.is_empty():
			payload = _merge_world(existing, data)
	return _write_json(world_path(), payload)

## The world record on disk, or an empty dict when there is none / it is
## unreadable. A missing record is NOT an error — the server boots a fresh world.
func load_world() -> Dictionary:
	var path := world_path()
	if not FileAccess.file_exists(path):
		return {}
	return _read_json(path)

func has_world() -> bool:
	return FileAccess.file_exists(world_path())

## Write one player record, keyed by the server-issued player_id. The id is a
## trusted server-minted value; a NON-canonical one (anything sanitize_player_id
## would change) is refused rather than written to a path derived from it.
func save_player(player_id: String, data: Dictionary) -> Error:
	if player_id.is_empty() or sanitize_player_id(player_id) != player_id:
		push_error("PersistenceSlice: refusing to save a player record with a non-canonical id '%s'" % player_id)
		return ERR_INVALID_PARAMETER
	var err := _write_json(player_path(player_id), data)
	if err == OK:
		GameBus.player_saved.emit(player_id)
	return err

## One player record from disk, or an empty dict when absent. A non-canonical id
## is refused: `player_path` sanitizes, so reading with one would silently read a
## DIFFERENT record (the sanitized id's) rather than the one asked for.
func load_player(player_id: String) -> Dictionary:
	if player_id.is_empty() or sanitize_player_id(player_id) != player_id:
		push_warning("PersistenceSlice: refusing to load a non-canonical player id '%s'" % player_id)
		return {}
	var path := player_path(player_id)
	if not FileAccess.file_exists(path):
		return {}
	return _read_json(path)

## Every player id with a record on disk. Derived from the file names, so a
## record written by a previous process is found on the next boot.
func list_player_records() -> Array:
	var out: Array = []
	var dir := DirAccess.open(server_save_dir)
	if dir == null:
		return out
	for file_name in dir.get_files():
		if not file_name.begins_with(player_prefix) or not file_name.ends_with(SAVE_EXT):
			continue
		var pid := file_name.substr(player_prefix.length())
		pid = pid.substr(0, pid.length() - SAVE_EXT.length())
		if not pid.is_empty():
			out.append(pid)
	out.sort()
	return out

# ---------------------------------------------------------------------------
# Client identity cache
# ---------------------------------------------------------------------------

## The id the host last assigned to this client. A client caches it so a
## reconnect can present it and re-bind to the same record — the record itself
## always stays on the host.
const CLIENT_ID_FILE := "user://identity.json"

func save_client_identity(player_id: String) -> Error:
	return _write_json(CLIENT_ID_FILE, { "player_id": player_id })

func load_client_identity() -> String:
	# A client with no cache is the normal first-join case, not an error.
	if not FileAccess.file_exists(CLIENT_ID_FILE):
		return ""
	var data := _read_json(CLIENT_ID_FILE)
	return str(data.get("player_id", ""))

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

func slot_path(slot: int) -> String:
	return SAVE_DIR + "slot_%02d" % slot + SAVE_EXT

func world_path() -> String:
	return server_save_dir + world_file

## The record path for a player id. The id is SANITIZED first (see
## sanitize_player_id): `player_path()` is the one place an id reaches the
## filesystem, and `player_id` is a wire-supplied bearer token, so interpolating it
## raw let an id like `../../world` (or one with a `/`, a NUL, or a Windows
## separator) name a file outside `server_save_dir`.
func player_path(player_id: String) -> String:
	return server_save_dir + player_prefix + sanitize_player_id(player_id) + SAVE_EXT

## A filesystem-safe form of a player id: every character outside [A-Za-z0-9_-] is
## dropped. A server-minted id is already canonical, so this is the identity for
## every legitimate id and neutralises anything else; `save_player`/`load_player`
## refuse a non-canonical id outright, so the sanitizer never silently renames a
## writable record. Pure.
static func sanitize_player_id(player_id: String) -> String:
	var out := ""
	for i in player_id.length():
		var c := player_id[i]
		var allowed := (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") \
			or (c >= "0" and c <= "9") or c == "_" or c == "-"
		if allowed:
			out += c
	return out

## True when an autosave is due: `elapsed` seconds have accumulated since the
## last save and `interval` is a positive cadence. Pure.
static func autosave_due(elapsed: float, interval: float) -> bool:
	return interval > 0.0 and elapsed >= interval

## The autosave cadence to actually use: a non-positive configured value falls back
## to DEFAULT_AUTOSAVE_SECS rather than disabling the autosave. Pure, so the rule is
## testable without mutating the fabric (the runtime path and the tests share it).
static func resolved_autosave_interval(configured: float) -> float:
	if configured <= 0.0:
		return DEFAULT_AUTOSAVE_SECS
	return configured

## The chunk manifests an INCREMENTAL save should carry: only the dirty keys, so
## an autosave re-serializes the chunks that changed instead of all ~49 loaded
## ones. Returns { "cx,cz": manifest } for every dirty key present in `manifest`.
## Pure, so the runtime path and the tests share one implementation.
static func dirty_chunk_subset(manifest: Dictionary, dirty_keys: Array) -> Dictionary:
	var out := {}
	for key in dirty_keys:
		var k := str(key)
		if manifest.has(k):
			out[k] = manifest[k]
	return out

## Whether a host world snapshot may carry the PEER'S OWN record — inventory,
## technology, position, HP. True only on the join/reconnect snapshot and only
## once the host has resolved the peer's identity.
##
## The record is a durability artifact, not a live feed: `record_position()` /
## `record_hp()` are only called for the local player and at disconnect, so a
## remote peer's recorded position is whatever was loaded from disk. Snapshot
## contents are applied by the client as authoritative, so carrying the record on
## every AOI re-scope (which a moving client triggers repeatedly) would teleport
## the client back to its last-saved position and roll its inventory and
## technology back to that instant. Pure, so the rule is testable on its own.
static func snapshot_carries_own_record(is_handshake_snapshot: bool, player_id: String) -> bool:
	return is_handshake_snapshot and not player_id.is_empty()

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

## Merge an incremental world payload into the record already on disk: the
## chunk manifests in `inc` are folded over `base`'s, the creature list is folded
## per instance_id (see merge_creature_states), and every other field (stations,
## the local player id, the timestamp) is replaced by the newer payload, since
## those are already small and fully re-serialized every save.
func _merge_world(base: Dictionary, inc: Dictionary) -> Dictionary:
	var merged := base.duplicate(true)
	for key in inc:
		if key == "chunks":
			var chunks: Dictionary = merged.get("chunks", {})
			var fresh: Variant = inc["chunks"]
			if fresh is Dictionary:
				for ckey in fresh:
					chunks[ckey] = fresh[ckey]
			merged["chunks"] = chunks
			continue
		if key == "creatures":
			merged["creatures"] = merge_creature_states(merged.get("creatures", []), inc["creatures"])
			continue
		merged[key] = inc[key]
	return merged

## Fold an incremental creature list over the recorded one, keyed on instance_id.
## Pure.
##
## Replacing the list wholesale is wrong for an incremental save: that payload
## carries only the population the process currently holds (the streamed chunks),
## so overwriting would DROP the death state of every creature in a chunk that is
## not in the view window — walk away from a corpse, save, walk back and the
## creature respawns alive, with the recorded death gone. Entries the payload
## carries win; entries it does not are retained, in the base's order.
static func merge_creature_states(base: Variant, inc: Variant) -> Array:
	var by_id: Dictionary = {}
	var order: Array = []
	for source in [base, inc]:
		if not (source is Array):
			continue
		for entry in source:
			if not (entry is Dictionary):
				continue
			var iid := str((entry as Dictionary).get("instance_id", ""))
			if not by_id.has(iid):
				order.append(iid)
			by_id[iid] = entry
	var out: Array = []
	for iid in order:
		out.append(by_id[iid])
	return out

## Serialize `data` to `path`. When atomic_writes is set the payload is written
## to `<path>.tmp` and renamed over the target, so a SIGTERM mid-write leaves
## either the old record or the new one — never a truncated file.
##
## The limit of that guarantee: there is no fsync. The rename is atomic with
## respect to a dying PROCESS (kill -TERM, a crash, a power-cut of the process),
## but neither the temp file's contents nor the rename itself are flushed to the
## platter, so a MACHINE power loss can still leave the previous record — or, on a
## filesystem that reorders metadata, a record whose data blocks were never
## written. Godot 4.7 exposes no fsync (`FileAccess.flush()` only flushes the
## userspace buffer; there is no `fsync`/`fdatasync` binding), so this is a
## documented limit rather than something to fix here: the atomic write bounds
## loss to "the last save", not to "a torn file".
func _write_json(path: String, data: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var target := path
	if atomic_writes:
		target = path + ".tmp"
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		var err := FileAccess.get_open_error()
		push_error("PersistenceSlice: cannot open %s for write — %s" % [target, error_string(err)])
		return err
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	if atomic_writes:
		# DirAccess.rename_absolute is a static helper, so no open handle is
		# needed; error_string() reports a failed rename.
		var rename_err := DirAccess.rename_absolute(target, path)
		if rename_err != OK:
			push_error("PersistenceSlice: rename %s → %s failed — %s" % [target, path, error_string(rename_err)])
			return rename_err
	return OK

func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("PersistenceSlice: cannot open %s for read — %s" % [path, error_string(FileAccess.get_open_error())])
		return {}
	var text := file.get_as_text()
	file.close()
	var data = JSON.parse_string(text)
	if data == null or not data is Dictionary:
		push_error("PersistenceSlice: %s contains invalid JSON" % path)
		return {}
	return data

func _on_save_requested(slot: int, data: Dictionary) -> void:
	save(slot, data)

func _on_load_requested(slot: int) -> void:
	load_slot(slot)
