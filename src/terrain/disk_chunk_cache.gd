extends RefCounted
## Phase 244 — chunk data kept on disk between visits and between sessions.
##
## Two layers, each one file per 32×32 chunk region (`RegionLayerFile`): `gen` holds the generator's
## output for a chunk (the host's; a later build reads it instead of generating) and `mesh` the arrays a
## build produced (the client's; a revisit decodes them on a worker instead of meshing). Every entry
## carries a 64-bit key made from `WORLDGEN_VERSION`, the worldgen fingerprint, the mesher version and what
## the build read (see `ChunkManager.disk_signature`): another key is a miss, never an error, and deleting
## the directory only costs time. The mesh layer is capped in bytes; past the cap the least recently used
## entries go first.
##
## Pure data and files, no nodes. Reads and writes are safe from worker threads.

const RegionLayerFile := preload("res://src/persistence/region_layer_file.gd")
const VoxelMesh := preload("res://src/terrain/voxel_mesh.gd")
const TerrainSliceScript := preload("res://src/terrain/terrain_slice.gd")

## Bump when the mesh builders' output changes shape (a stale mesh is a miss).
const MESHER_VERSION := 1
const DEFAULT_MAX_BYTES := 512 * 1024 * 1024

var root: String
var max_bytes: int = DEFAULT_MAX_BYTES
var hits: int = 0
var misses: int = 0

var _mutex := Mutex.new()
var _files: Dictionary = {}   # "layer/rx.rz" -> RegionLayerFile
var _lru: Dictionary = {}     # "layer/rx.rz#idx" -> bytes; insertion order is recency, oldest first
var _keys: Dictionary = {}    # "layer/rx.rz#idx" -> the key this cache last wrote there (absent after a scan)
var _bytes: int = 0
var _tasks: Array = []

func _init(dir: String, cap: int = DEFAULT_MAX_BYTES) -> void:
	root = dir if dir.ends_with("/") else dir + "/"
	max_bytes = cap
	DirAccess.make_dir_recursive_absolute(root)
	_scan()

func bytes() -> int:
	return _bytes

func entry_count() -> int:
	return _lru.size()

## The key a build's inputs make: the generator's versions, the mesher's, and the build's own signature.
static func key_of(parts: Array) -> int:
	var h := str([TerrainSliceScript.WORLDGEN_VERSION, TerrainSliceScript.worldgen_fingerprint(), MESHER_VERSION, parts]).sha256_text()
	return h.substr(0, 15).hex_to_int()

## A key for a layer that does not depend on the mesher.
static func gen_key_of(parts: Array) -> int:
	var h := str([TerrainSliceScript.WORLDGEN_VERSION, TerrainSliceScript.worldgen_fingerprint(), parts]).sha256_text()
	return h.substr(0, 15).hex_to_int()

func _file_name(layer: String, chunk: Vector2i) -> String:
	var r := RegionLayerFile.region_of(chunk)
	return "%s.%d.%d" % [layer, r.x, r.y]

func _file(layer: String, chunk: Vector2i) -> RegionLayerFile:
	var n := _file_name(layer, chunk)
	var f: RegionLayerFile = _files.get(n)
	if f == null:
		f = RegionLayerFile.new(root + n + ".bin")
		_files[n] = f
	return f

func _lru_key(layer: String, chunk: Vector2i) -> String:
	return "%s#%d" % [_file_name(layer, chunk), RegionLayerFile.index_of(chunk)]

func _scan() -> void:
	var d := DirAccess.open(root)
	if d == null:
		return
	# Least recently written files first, so a restart evicts what an earlier session touched last, not
	# whatever the directory listing happens to put first.
	var names: Array = []
	for fname in d.get_files():
		if fname.ends_with(".bin"):
			names.append([FileAccess.get_modified_time(root + fname), fname])
	names.sort()
	for pair in names:
		var fname: String = pair[1]
		var n := fname.trim_suffix(".bin")
		var f := RegionLayerFile.new(root + fname)
		_files[n] = f
		var es := f.entries()
		for idx in es:
			_lru["%s#%d" % [n, idx]] = int(es[idx])
			_bytes += int(es[idx])

## True when the entry for `chunk` carries `key`.
func probe(layer: String, chunk: Vector2i, key: int) -> bool:
	_mutex.lock()
	var f := _file(layer, chunk)
	_mutex.unlock()
	return f.has(RegionLayerFile.index_of(chunk), key)

## The raw bytes stored for `chunk`, or empty. A hit makes the entry the most recently used.
func read(layer: String, chunk: Vector2i, key: int) -> PackedByteArray:
	_mutex.lock()
	var f := _file(layer, chunk)
	_mutex.unlock()
	var out := f.get_entry(RegionLayerFile.index_of(chunk), key)
	_mutex.lock()
	if out.is_empty():
		misses += 1
	else:
		hits += 1
		var k := _lru_key(layer, chunk)
		if _lru.has(k):
			var b: int = _lru[k]
			_lru.erase(k)
			_lru[k] = b
	_mutex.unlock()
	return out

func write(layer: String, chunk: Vector2i, key: int, data: PackedByteArray) -> bool:
	_mutex.lock()
	var f := _file(layer, chunk)
	_mutex.unlock()
	var idx := RegionLayerFile.index_of(chunk)
	var ok := f.put(idx, key, data)
	var now := f.entry_bytes(idx)
	_mutex.lock()
	var k := _lru_key(layer, chunk)
	if _lru.has(k):
		_bytes -= int(_lru[k])
		_lru.erase(k)
	# What is on disk now is counted, also when the put failed and left the older entry in place.
	if now > 0:
		_lru[k] = now
		_bytes += now
		if ok:
			_keys[k] = key
	else:
		_keys.erase(k)
	var evict := _evict_over_cap(k)
	_mutex.unlock()
	# Removed only while the slot still holds the key the eviction chose: a rewrite that raced in between keeps
	# its newer entry. An entry from an earlier session (its key unknown) is removed outright.
	for e in evict:
		if int(e[2]) != 0:
			e[0].remove_if_key(e[1], e[2])
		else:
			e[0].remove(e[1])
	return ok

## Drops the entry for `chunk`; with a `key` only while it still carries that key (a newer write is kept).
func invalidate(layer: String, chunk: Vector2i, key: int = 0) -> void:
	_mutex.lock()
	var f := _file(layer, chunk)
	_mutex.unlock()
	var idx := RegionLayerFile.index_of(chunk)
	if key != 0:
		if not f.remove_if_key(idx, key):
			return
	else:
		f.remove(idx)
	_mutex.lock()
	var k := _lru_key(layer, chunk)
	if _lru.has(k):
		_bytes -= int(_lru[k])
		_lru.erase(k)
	_keys.erase(k)
	_mutex.unlock()

## Entries to remove so the layer files fit `max_bytes`, oldest first, never `keep`. Caller holds the mutex.
func _evict_over_cap(keep: String) -> Array:
	var out: Array = []
	for k in _lru.keys():
		if _bytes <= max_bytes:
			break
		if k == keep:
			continue
		var parts: PackedStringArray = (k as String).split("#")
		_bytes -= int(_lru[k])
		_lru.erase(k)
		out.append([_files[parts[0]], int(parts[1]), int(_keys.get(k, 0))])
		_keys.erase(k)
	return out

## Queue `job` on a worker; `flush` waits for every one.
func run_async(job: Callable) -> void:
	# Reap finished tasks: an id never waited on keeps its task record alive, one per chunk written.
	var live: Array = []
	for t in _tasks:
		if WorkerThreadPool.is_task_completed(t):
			WorkerThreadPool.wait_for_task_completion(t)
		else:
			live.append(t)
	_tasks = live
	_tasks.append(WorkerThreadPool.add_task(job, false, "chunk disk cache"))

func flush() -> void:
	var ts := _tasks
	_tasks = []
	for t in ts:
		WorkerThreadPool.wait_for_task_completion(t)

## Delete every file.
func clear() -> void:
	flush()
	for n in _files:
		(_files[n] as RegionLayerFile).drop()
	_files.clear()
	_lru.clear()
	_keys.clear()
	_bytes = 0

# ---- encoding ------------------------------------------------------------------------------------

## A build result as bytes. `{}` when it holds something plain data cannot carry. Collision shapes are not
## stored: their faces are (`collision`, or one list per quadrant), and `decode` makes the shapes again.
static func encode(arrays: Dictionary, heightmap: Array) -> PackedByteArray:
	var plain := {}
	var parts: Array = []
	for k in arrays:
		var v: Variant = arrays[k]
		if k == "shape":
			continue
		if k == "shape_parts":
			for s in (v as Array):
				if not s is ConcavePolygonShape3D:
					return PackedByteArray()
				parts.append((s as ConcavePolygonShape3D).get_faces())
			continue
		if v is Object:
			return PackedByteArray()
		plain[k] = v
	var had_shape := arrays.has("shape")
	return var_to_bytes({ "a": plain, "h": heightmap, "s": had_shape, "p": parts })

## `{ arrays, heightmap }`, or `{}` when the bytes are not a result `encode` made.
static func decode(raw: PackedByteArray) -> Dictionary:
	if raw.is_empty():
		return {}
	var d: Variant = bytes_to_var(raw)
	if not d is Dictionary or not (d as Dictionary).get("a") is Dictionary or not (d as Dictionary).get("h") is Array:
		return {}
	var arrays: Dictionary = (d as Dictionary)["a"]
	if bool(d.get("s", false)):
		if not arrays.get("collision") is PackedVector3Array:
			return {}
		arrays["shape"] = VoxelMesh.collision_shape(arrays["collision"])
	var parts: Array = d.get("p", [])
	if not parts.is_empty():
		var shapes: Array = []
		for faces in parts:
			if not faces is PackedVector3Array:
				return {}
			shapes.append(VoxelMesh.collision_shape(faces))
		arrays["shape_parts"] = shapes
	return { "arrays": arrays, "heightmap": d["h"] }
