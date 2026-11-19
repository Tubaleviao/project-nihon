extends SceneTree
## Phase 245 — bake the planet for a seed and write the file plus its hash, for CI to publish as a release asset.
##   godot --headless --path . --script tools/bake_planet.gd -- <seed> <out_dir> [circumference_km] [cell_m]
## Writes <out_dir>/planet_<seed>_v<worldgen>.nbk and the same name + ".sha256" (hex of the body hash).


func _initialize() -> void:
	# loaded here, not preloaded: terrain_slice reads the GameBus autoload, which exists only once the tree is up
	var PlanetBake = load("res://src/terrain/planet_bake.gd")
	var TerrainSlice = load("res://src/terrain/terrain_slice.gd")
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: bake_planet.gd -- <seed> <out_dir> [circumference_km] [cell_m]")
		quit(2)
		return
	var seed_v: int = int(args[0])
	var circ_km: float = float(args[2]) if args.size() > 2 else float(TerrainSlice.circumference_km())
	var cell_m: float = float(args[3]) if args.size() > 3 else 2000.0
	var path: String = PlanetBake.file_path(args[1], seed_v, TerrainSlice.WORLDGEN_VERSION)
	var t: int = Time.get_ticks_msec()
	var r: Dictionary = PlanetBake.load_or_bake(path, seed_v, TerrainSlice.WORLDGEN_VERSION, circ_km * 1000.0, cell_m)
	var hex: String = PlanetBake.file_hash_hex(r["file"])
	var f := FileAccess.open(path + ".sha256", FileAccess.WRITE)
	f.store_string(hex + "\n")
	f.close()
	print("[bake] %s (%s) sha256 %s in %d ms" % [path, r["source"], hex, Time.get_ticks_msec() - t])
	quit(0)
