extends RefCounted
## Phase 244 — one file per region and layer: a sector table and zstd-compressed entries.
##
## Layout ported (the algorithm, not the code) from Zylann/godot_voxel's `streams/region/region_file.cpp`
## (MIT, © 2016-2024 Marc Gilleron; commit dfb0f81c7fd766f68d78715b2138f4e336cd9737, see `native/THIRD_PARTY.md`):
## sector 0 is the header, one 32-bit entry per chunk of the 32×32 region (a 24-bit sector index above an
## 8-bit sector count, 0 for absent); entries start at sector boundaries. Each entry begins with its own
## 64-bit key, so a stale entry is a miss after reading 16 bytes. An entry that outgrows its sectors is moved
## to the end and the sectors after the old one close the gap.
##
## A cache, never a source of truth: a short, torn or unreadable file is a miss, and the whole file is dropped.
## Every call takes the mutex, so a worker may read while the main thread writes.

const REGION_SIZE := 32
const ENTRIES := REGION_SIZE * REGION_SIZE
const SECTOR := 4096
const MAX_SECTORS := 255
const ENTRY_HEAD := 16   # key (8), compressed size (4), raw size (4)

var path: String
var _table := PackedInt32Array()
var _mutex := Mutex.new()
var _loaded := false

func _init(file_path: String) -> void:
	path = file_path

## Index of the chunk inside its region (0..1023).
static func index_of(chunk: Vector2i) -> int:
	return posmod(chunk.y, REGION_SIZE) * REGION_SIZE + posmod(chunk.x, REGION_SIZE)

static func region_of(chunk: Vector2i) -> Vector2i:
	return Vector2i(floori(float(chunk.x) / REGION_SIZE), floori(float(chunk.y) / REGION_SIZE))

static func _start(e: int) -> int:
	return (e >> 8) & 0xFFFFFF

static func _count(e: int) -> int:
	return e & 0xFF

static func _pack(start: int, count: int) -> int:
	return (start << 8) | count

## Bytes of entry `idx` on disk (0 when absent).
func entry_bytes(idx: int) -> int:
	_mutex.lock()
	_ensure()
	var n := _count(_table[idx]) * SECTOR
	_mutex.unlock()
	return n

## Indices of the present entries, with their sizes in bytes.
func entries() -> Dictionary:
	_mutex.lock()
	_ensure()
	var out := {}
	for i in ENTRIES:
		if _table[i] != 0:
			out[i] = _count(_table[i]) * SECTOR
	_mutex.unlock()
	return out

## True when entry `idx` exists and carries `key` (reads 16 bytes).
func has(idx: int, key: int) -> bool:
	_mutex.lock()
	var ok := _read_head(idx, key).size() == ENTRY_HEAD
	_mutex.unlock()
	return ok

## The entry's bytes, or empty on a miss (absent, another key, or damaged).
func get_entry(idx: int, key: int) -> PackedByteArray:
	_mutex.lock()
	var out := _read_entry(idx, key)
	_mutex.unlock()
	return out

## Store `data` under `key`. False when it does not fit 255 sectors or the file cannot be written.
func put(idx: int, key: int, data: PackedByteArray) -> bool:
	_mutex.lock()
	var ok := _put_entry(idx, key, data)
	_mutex.unlock()
	return ok

func remove(idx: int) -> void:
	_mutex.lock()
	_ensure()
	_remove_entry(idx)
	_mutex.unlock()

## Delete the file.
func drop() -> void:
	_mutex.lock()
	_table = PackedInt32Array()
	_table.resize(ENTRIES)
	_loaded = true
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	_mutex.unlock()

func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_table = PackedInt32Array()
	_table.resize(ENTRIES)
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var len := f.get_length()
	var raw := f.get_buffer(SECTOR)
	f.close()
	if raw.size() < ENTRIES * 4:
		_discard()
		return
	var sectors := ceili(float(len) / SECTOR)
	for i in ENTRIES:
		var e := raw.decode_u32(i * 4)
		if e != 0 and (_start(e) < 1 or _start(e) + _count(e) > sectors or _count(e) == 0):
			_discard()   # a table pointing outside the file: the whole file is untrusted
			return
		_table[i] = e

func _discard() -> void:
	_table.fill(0)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

func _read_head(idx: int, key: int) -> PackedByteArray:
	_ensure()
	var e := _table[idx]
	if e == 0:
		return PackedByteArray()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	f.seek(_start(e) * SECTOR)
	var head := f.get_buffer(ENTRY_HEAD)
	f.close()
	if head.size() != ENTRY_HEAD or head.decode_s64(0) != key:
		return PackedByteArray()
	return head

func _read_entry(idx: int, key: int) -> PackedByteArray:
	var head := _read_head(idx, key)
	if head.size() != ENTRY_HEAD:
		return PackedByteArray()
	var csize := head.decode_u32(8)
	var rsize := head.decode_u32(12)
	var e := _table[idx]
	if csize + ENTRY_HEAD > _count(e) * SECTOR:
		return PackedByteArray()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	f.seek(_start(e) * SECTOR + ENTRY_HEAD)
	var comp := f.get_buffer(csize)
	f.close()
	if comp.size() != csize:
		return PackedByteArray()
	var raw := comp.decompress(rsize, FileAccess.COMPRESSION_ZSTD)
	return raw if raw.size() == rsize else PackedByteArray()

func _end_sector() -> int:
	var end := 1
	for e in _table:
		if e != 0:
			end = maxi(end, _start(e) + _count(e))
	return end

func _put_entry(idx: int, key: int, data: PackedByteArray) -> bool:
	_ensure()
	var comp := data.compress(FileAccess.COMPRESSION_ZSTD)
	var need := ceili(float(comp.size() + ENTRY_HEAD) / SECTOR)
	if need > MAX_SECTORS or comp.is_empty():
		_remove_entry(idx)
		return false
	var head := PackedByteArray()
	head.resize(ENTRY_HEAD)
	head.encode_s64(0, key)
	head.encode_u32(8, comp.size())
	head.encode_u32(12, data.size())
	var old := _table[idx]
	var start: int
	var count: int
	if old != 0 and need <= _count(old):
		start = _start(old)
		count = _count(old)
	else:
		_remove_entry(idx)   # closes the gap the old entry leaves
		start = _end_sector()
		count = need
	var f := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE_READ)
	if f == null:
		return false
	if f.get_length() < SECTOR:
		f.seek(0)
		f.store_buffer(PackedByteArray(_header_bytes()))
	f.seek(start * SECTOR)
	f.store_buffer(head)
	f.store_buffer(comp)
	var pad := count * SECTOR - head.size() - comp.size()
	if pad > 0:
		var z := PackedByteArray()
		z.resize(pad)
		f.store_buffer(z)
	_table[idx] = _pack(start, count)
	f.seek(idx * 4)
	f.store_32(_table[idx])
	f.close()
	return true

func _header_bytes() -> PackedByteArray:
	var raw := PackedByteArray()
	raw.resize(SECTOR)
	for i in ENTRIES:
		raw.encode_u32(i * 4, _table[i])
	return raw

## Drop entry `idx` and shift every later sector down over its space.
func _remove_entry(idx: int) -> void:
	var e := _table[idx]
	if e == 0:
		return
	var start := _start(e)
	var count := _count(e)
	var end := _end_sector()
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	_table[idx] = 0
	if f == null:
		_discard()
		return
	if start + count < end:
		f.seek((start + count) * SECTOR)
		var tail := f.get_buffer((end - start - count) * SECTOR)
		f.seek(start * SECTOR)
		f.store_buffer(tail)
		for i in ENTRIES:
			if _table[i] != 0 and _start(_table[i]) > start:
				_table[i] = _pack(_start(_table[i]) - count, _count(_table[i]))
	f.resize((end - count) * SECTOR)
	f.seek(0)
	f.store_buffer(_header_bytes())
	f.close()
