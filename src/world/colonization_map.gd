extends RefCounted
## Colonization map — how settled each region of the planet is (Phase 53).
##
## A region (`RegionStore.REGION_SIZE` chunks square, 1,024 m) scores
##   edited chunks  +  homes x HOME_WEIGHT  +  1 while a player was present recently.
## New-player spawn placement (`SpawnFinder`) keeps a minimum distance from every region at or
## above the fabric's `colonizedScore`, so a new player lands on empty land rather than inside
## somebody's base. The map persists on the world record (`to_data` / `from_data`), beside the
## Phase 52 region files, and is seeded from them (`seed_from_regions`) so an older world whose
## record has no map still counts every region that holds an edit.
const RegionStore := preload("res://src/persistence/region_store.gd")
const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")

const HOME_WEIGHT := 10.0
## A player seen in a region counts toward its score for a week.
const PRESENCE_WINDOW_SECONDS := 7.0 * 86400.0
## Metres on a side of one region.
const REGION_METERS := float(RegionStore.REGION_SIZE) * TerrainSlice.CHUNK_METERS

## "rx,rz" -> { "edits": int, "homes": int, "presence_at": float (Unix seconds, 0 = never) }.
var _regions: Dictionary = {}
## "cx,cz" chunks already counted this session, so a second edit of one chunk is not a second chunk.
var _counted_chunks: Dictionary = {}

func region_count() -> int:
	return _regions.size()

func _entry(region: Vector2i) -> Dictionary:
	var key := RegionStore.region_key(region)
	if not _regions.has(key):
		_regions[key] = { "edits": 0, "homes": 0, "presence_at": 0.0 }
	return _regions[key]

## A chunk was edited. Counts the chunk once per session; returns true when it was new.
func note_edited_chunk(chunk: Vector2i) -> bool:
	var wrapped := TerrainSlice.wrap_chunk(chunk)
	var ckey := "%d,%d" % [wrapped.x, wrapped.y]
	if _counted_chunks.has(ckey):
		return false
	_counted_chunks[ckey] = true
	var e := _entry(RegionStore.region_of_chunk(wrapped))
	e["edits"] = int(e["edits"]) + 1
	return true

## A player made a home (their spawn point, for now) in `chunk`'s region.
func note_home(chunk: Vector2i) -> void:
	var e := _entry(RegionStore.region_of_chunk(TerrainSlice.wrap_chunk(chunk)))
	e["homes"] = int(e["homes"]) + 1

## A player was seen in `chunk`'s region at `now` (Unix seconds).
func note_presence(chunk: Vector2i, now: float) -> void:
	var e := _entry(RegionStore.region_of_chunk(TerrainSlice.wrap_chunk(chunk)))
	e["presence_at"] = maxf(float(e["presence_at"]), now)

## Make sure every region in `regions` (Vector2i, one per region file on disk) counts at least
## one edited chunk. Idempotent: it never lowers a count.
func seed_from_regions(regions: Array) -> void:
	for r in regions:
		var e := _entry(r)
		if int(e["edits"]) < 1:
			e["edits"] = 1

func score(region: Vector2i, now: float = 0.0) -> float:
	var e: Variant = _regions.get(RegionStore.region_key(region), null)
	if e == null:
		return 0.0
	var s := float(e["edits"]) + float(e["homes"]) * HOME_WEIGHT
	var seen := float(e["presence_at"])
	if seen > 0.0 and now - seen <= PRESENCE_WINDOW_SECONDS:
		s += 1.0
	return s

func is_colonized(region: Vector2i, threshold: float, now: float = 0.0) -> bool:
	return score(region, now) >= threshold

## Every region (Vector2i) at or above `threshold`.
func colonized_regions(threshold: float, now: float = 0.0) -> Array:
	var out: Array = []
	for key in _regions:
		var r := RegionStore.region_from_key(str(key))
		if score(r, now) >= threshold:
			out.append(r)
	return out

## True when world (x, z) lies within `min_distance_m` of a colonized region (the region's
## rectangle, not its centre). Looks only at the regions the radius can reach, so the cost does
## not grow with the number of colonized regions. X wraps around the circumference.
func is_near_colonized(x: float, z: float, min_distance_m: float, threshold: float, now: float = 0.0) -> bool:
	if _regions.is_empty():
		return false
	var span := int(ceil(min_distance_m / REGION_METERS)) + 1
	var rx0 := floori(x / REGION_METERS)
	var rz0 := floori(z / REGION_METERS)
	var ring := maxi(TerrainSlice.circumference_chunks() / RegionStore.REGION_SIZE, 1)
	var circ := float(ring) * REGION_METERS
	for dz in range(-span, span + 1):
		for dx in range(-span, span + 1):
			# The stored region X is canonical (`wrap_chunk`), so look it up in that form.
			var rx := RegionStore.region_of_chunk(TerrainSlice.wrap_chunk(Vector2i((rx0 + dx) * RegionStore.REGION_SIZE, 0))).x
			var rz := rz0 + dz
			if score(Vector2i(rx, rz), now) < threshold:
				continue
			# Distance from the point to the region rectangle, X taken the short way round.
			var cx := (float(rx) + 0.5) * REGION_METERS
			var cz := (float(rz) + 0.5) * REGION_METERS
			var ddx := absf(fposmod(x - cx + circ * 0.5, circ) - circ * 0.5)
			var ddz := absf(z - cz)
			var gap_x := maxf(ddx - REGION_METERS * 0.5, 0.0)
			var gap_z := maxf(ddz - REGION_METERS * 0.5, 0.0)
			if sqrt(gap_x * gap_x + gap_z * gap_z) < min_distance_m:
				return true
	return false

func to_data() -> Dictionary:
	return { "regions": _regions.duplicate(true) }

## Replace the map from `data`. Malformed entries are dropped, never trusted.
func from_data(data: Variant) -> void:
	_regions.clear()
	_counted_chunks.clear()
	if not (data is Dictionary):
		return
	var regions: Variant = (data as Dictionary).get("regions", null)
	if not (regions is Dictionary):
		return
	for key in regions:
		var e: Variant = regions[key]
		var parts: PackedStringArray = str(key).split(",")
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int() or not (e is Dictionary):
			continue
		var seen: Variant = e.get("presence_at", 0.0)
		_regions[str(key)] = {
			"edits": maxi(int(e.get("edits", 0)), 0),
			"homes": maxi(int(e.get("homes", 0)), 0),
			"presence_at": float(seen) if (seen is float or seen is int) and is_finite(float(seen)) else 0.0,
		}
