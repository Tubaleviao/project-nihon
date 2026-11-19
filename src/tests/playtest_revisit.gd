extends RefCounted
## Phase 244 — the playtest bot's `revisit` step: the flight loop flown twice over the same ground, with the
## memory chunk cache dropped between the passes. The first pass builds and writes the disk cache, the second
## decodes from it, so its worker ms per local chunk crossing is at most MAX_SHARE of the first's.
## Report-only under the GDScript builder (CI's `--no-native` run builds too slowly for a timing gate).

const NativeBuilder := preload("res://src/terrain/native_builder.gd")
const TickProbe := preload("res://src/core/tick_probe.gd")
const MAX_SHARE := 0.5

## `bot` is the PlaytestBot; returns the step's `[ok, note]`.
static func run(bot: Node) -> Array:
	var cm = bot._root._chunk_manager
	var disk = cm._m1.disk_cache
	if disk == null:
		return [true, "the disk cache is off in this boot (report only)"]
	var home: Dictionary = bot._root._player.get_world_pos()
	var home_chunk: Vector2i = home["chunk"]
	var home_local: Vector3 = home["local"]
	var was_flying: bool = bot._root._player.flying
	var speed: float = bot._root._player.admin_speed_factor
	bot._step_restore = bot._restore_flight.bind(speed, was_flying, TickProbe.enabled)
	GameBus.admin_moves_synced.emit(speed, true)
	disk.clear()   # the first pass must build: what an earlier run left is not the step's to count on
	cm.chunk_cache().clear()
	var first: Dictionary = await bot._fly_east(home_chunk, home_local)
	var settled: bool = await bot._return_home(home_chunk, home_local)
	disk.flush()
	cm.chunk_cache().clear()   # a revisit from disk, not from the memory cache
	var disk0: int = cm._m1.disk_attaches
	var usec0: int = cm._m1.disk_usec
	var second: Dictionary = await bot._fly_east(home_chunk, home_local)
	bot._step_restore.call()
	settled = await bot._return_home(home_chunk, home_local) and settled
	var a := float(first["worker_ms_per_crossing"])
	var b := float(second["worker_ms_per_crossing"])
	var from_disk: int = cm._m1.disk_attaches - disk0
	var note := "worker %.1f ms per crossing the first pass (%d crossings, %d attached), %.1f ms the second (%d crossings, %d attached, %d from disk, %.0f ms decoding)" % [a, first["crossings"], first["attached"], b, second["crossings"], second["attached"], from_disk, float(cm._m1.disk_usec - usec0) / 1000.0]
	if not settled:
		return [false, note + "; the start chunk never rebuilt"]
	if NativeBuilder.mode() != NativeBuilder.MODE_NATIVE:
		return [true, note + " (report only: %s builder)" % NativeBuilder.mode()]
	return [from_disk > 0 and b <= a * MAX_SHARE, note]
