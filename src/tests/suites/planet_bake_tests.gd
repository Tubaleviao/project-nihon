extends "res://src/tests/test_support.gd"
## Phase 245 — the planet bake (GDScript reference): determinism, rivers, and the file's hash.

const PlanetBake := preload("res://src/terrain/planet_bake.gd")
const COLS := 48
const ROWS := 24
const SEA := 0


func register() -> void:
	_run_test("planet bake: the same planet bakes to identical bytes twice", _test_deterministic)
	_run_test("planet bake: every river reaches the sea or a lake, never flows uphill and widens with flow", _test_rivers)
	_run_test("planet bake: every land cell has a way down (no flat or pit left)", _test_no_pits)
	_run_test("planet bake: a corrupted, wrong-hash or wrong-world file is refused", _test_file_refused)
	_run_test("planet bake: a good file parses and keeps its cells", _test_file_roundtrip)
	_run_test("planet bake: the world shape bakes deterministically", _test_bake_world)
	_run_test("planet bake: the native bake matches the GDScript reference", _test_native_parity)
	_run_test("planet bake: a corrupted stored bake is refused and baked again", _test_load_or_bake)

func _hash2(x: int, z: int) -> int:
	var v := (x * 73856093) ^ (z * 19349663)
	v = (v ^ (v >> 13)) * 1274126177
	return (v ^ (v >> 16)) & 0xFFFF

## A continent with a noisy rim: high in the middle, sea at the edges, 16-unit noise on top.
func _base(x: int, z: int) -> int:
	var dx := (x - COLS / 2) * 100 / (COLS / 2)
	var dz := (z - ROWS / 2) * 100 / (ROWS / 2)
	var d2 := dx * dx + dz * dz   # 0..20000
	return 900 - d2 / 14 + (_hash2(x, z) % 80) - 40

func _bake() -> Dictionary:
	return PlanetBake.bake(COLS, ROWS, SEA, _base)

func _test_deterministic() -> void:
	var a := PlanetBake.serialize(_bake(), 42, 13, 2000)
	var b := PlanetBake.serialize(_bake(), 42, 13, 2000)
	assert_eq(a, b, "two bakes give the same bytes")
	assert_eq(a.size(), PlanetBake.HEADER_BYTES + 32 + COLS * ROWS * PlanetBake.CELL_BYTES, "8 bytes a cell")
	assert_true(PlanetBake.file_hash_hex(a) == PlanetBake.file_hash_hex(b) and PlanetBake.file_hash_hex(a).length() == 64, "and the same hash")

func _test_rivers() -> void:
	var b := _bake()
	var h: PackedInt32Array = b["height"]
	var flow: PackedInt32Array = b["flow"]
	var down: PackedInt32Array = b["down"]
	var flags: PackedInt32Array = b["flags"]
	var rivers := 0
	for i in h.size():
		if flags[i] & PlanetBake.FLAG_RIVER == 0:
			continue
		rivers += 1
		var c := i
		var steps := 0
		while true:
			if flags[c] & PlanetBake.FLAG_OCEAN != 0 or flags[c] & PlanetBake.FLAG_LAKE != 0:
				break
			var d := down[c]
			assert_true(d >= 0, "river cell %d has a downstream cell" % c)
			if d < 0:
				break
			assert_true(h[d] < h[c], "river never flows uphill (cell %d)" % c)
			assert_true(flow[d] >= flow[c], "flow never shrinks downstream (cell %d)" % c)
			assert_true(PlanetBake.river_width_m(flow[d]) >= PlanetBake.river_width_m(flow[c]), "and the width grows with it")
			c = d
			steps += 1
			if steps > h.size():
				assert_true(false, "a river loops")
				break
		assert_true(flags[c] & (PlanetBake.FLAG_OCEAN | PlanetBake.FLAG_LAKE) != 0, "river from %d ends in the sea or a lake" % i)
	assert_true(rivers > 0, "the test planet grows rivers (%d cells)" % rivers)

func _test_no_pits() -> void:
	var b := _bake()
	var h: PackedInt32Array = b["height"]
	for i in h.size():
		if h[i] > SEA:
			assert_true(int(b["down"][i]) >= 0 and h[int(b["down"][i])] < h[i], "land cell %d drains strictly downhill" % i)

func _test_file_refused() -> void:
	var file := PlanetBake.serialize(_bake(), 42, 13, 2000)
	var good := PlanetBake.file_hash_hex(file)
	assert_true(PlanetBake.parse(file, 42, 13, good)["ok"], "the untouched file parses")
	var bad := file.duplicate()
	bad[bad.size() - 5] = bad[bad.size() - 5] ^ 0x40
	var r := PlanetBake.parse(bad, 42, 13)
	assert_false(r["ok"], "a flipped byte is refused")
	assert_eq(r["error"], "bake.bad_hash", "by its hash")
	assert_eq(PlanetBake.parse(file, 42, 13, "00".repeat(32))["error"], "bake.bad_hash", "a file that does not match the published hash is refused")
	assert_eq(PlanetBake.parse(file, 43, 13)["error"], "bake.wrong_world", "another seed is refused")
	assert_eq(PlanetBake.parse(file, 42, 14)["error"], "bake.wrong_world", "another worldgen version is refused")
	assert_eq(PlanetBake.parse(file.slice(0, 20), 42, 13)["error"], "bake.bad_header", "a truncated header is refused")
	assert_eq(PlanetBake.parse(file.slice(0, file.size() - 8), 42, 13)["error"], "bake.bad_size", "a short body is refused")

func _test_file_roundtrip() -> void:
	var b := _bake()
	var r := PlanetBake.parse(PlanetBake.serialize(b, 7, 13, 2000), 7, 13)
	assert_true(r["ok"], "parses")
	assert_eq(int(r["cols"]), COLS, "columns kept")
	var cells: PackedByteArray = r["cells"]
	assert_eq(cells.decode_s16(0), clampi(int(b["height"][0]), -32768, 32767), "a height round-trips")

func _test_bake_world() -> void:
	var a := PlanetBake.serialize(PlanetBake.bake_world(1234, 400000.0, 20000.0), 1234, 13, 20000)
	var b := PlanetBake.serialize(PlanetBake.bake_world(1234, 400000.0, 20000.0), 1234, 13, 20000)
	assert_eq(a, b, "the fabric's world shape bakes to the same bytes twice")
	assert_true(PlanetBake.parse(a, 1234, 13)["ok"], "and the file parses")

func _test_load_or_bake() -> void:
	var dir := "user://planet_bake_tests"
	var path := PlanetBake.file_path(dir, 99, 13)
	DirAccess.remove_absolute(path)
	var first := PlanetBake.load_or_bake(path, 99, 13, 400000.0, 20000.0)
	assert_eq(first["source"], "baked", "no file: the host bakes")
	var second := PlanetBake.load_or_bake(path, 99, 13, 400000.0, 20000.0, PlanetBake.file_hash_hex(first["file"]))
	assert_eq(second["source"], "file", "the stored file is used when its hash matches")
	assert_eq(second["file"], first["file"], "and is the same bytes")
	var bad: PackedByteArray = first["file"].duplicate()
	bad[bad.size() - 3] = bad[bad.size() - 3] ^ 0x01
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bad)
	f.close()
	var third := PlanetBake.load_or_bake(path, 99, 13, 400000.0, 20000.0, PlanetBake.file_hash_hex(first["file"]))
	assert_eq(third["source"], "baked", "a corrupted file is refused and the world is baked again")
	assert_eq(third["refused"], "bake.bad_hash", "with the reason")
	assert_eq(third["file"], first["file"], "to the same bytes as the first bake")
	DirAccess.remove_absolute(path)

## The native bake gives the same bytes as the GDScript reference (skipped, with a note, on a build without it).
func _test_native_parity() -> void:
	var gd := PlanetBake.serialize(PlanetBake.bake(COLS, ROWS, SEA, _base, Callable(), 2, false), 5, 13, 2000)
	if not PlanetBake.NativeBuilder.use_native("planet_bake"):
		assert_true(true, "no native planet_bake in this build: the reference stands alone")
		return
	var nat := PlanetBake.serialize(PlanetBake.bake(COLS, ROWS, SEA, _base, Callable(), 2, true), 5, 13, 2000)
	assert_eq(nat, gd, "native and GDScript bakes are byte for byte the same")
	var w_gd := PlanetBake.serialize(PlanetBake.bake_world(77, 400000.0, 20000.0, 2, false), 77, 13, 20000)
	var w_nat := PlanetBake.serialize(PlanetBake.bake_world(77, 400000.0, 20000.0, 2, true), 77, 13, 20000)
	assert_eq(w_nat, w_gd, "and so is the fabric's world shape")
