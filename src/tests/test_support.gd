extends Node
## Shared state, assertion helpers and fixtures for the suite files in `suites/`.
## Moved out of the old single-file suite (Phase 133); every suite extends this.
const Diag := preload("res://src/core/diag.gd")
const MemoryTransport := preload("res://src/tests/memory_transport.gd")

# Preload slices so tests are isolated from the main scene tree.
const BattleSlice     := preload("res://src/battle/battle_slice.gd")
const CreatureSlice   := preload("res://src/creature/creature_slice.gd")
const CreatureAI      := preload("res://src/creature/creature_ai.gd")
const WaystoneSlice   := preload("res://src/world/waystone_slice.gd")
const WeatherSlice    := preload("res://src/world/weather_slice.gd")
const TamingSlice     := preload("res://src/creature/taming_slice.gd")
const TerrainSlice    := preload("res://src/terrain/terrain_slice.gd")
const SpawnRoll       := preload("res://src/world/spawn_roll.gd")
const WorldClock      := preload("res://src/world/world_clock.gd")
const ChunkManager    := preload("res://src/terrain/chunk_manager.gd")
const PersistenceSlice:= preload("res://src/persistence/persistence_slice.gd")
const LootSlice       := preload("res://src/loot/loot_slice.gd")
const InventorySlice  := preload("res://src/inventory/inventory_slice.gd")
const CharacterSlice  := preload("res://src/character/character_slice.gd")
const CraftingSlice   := preload("res://src/crafting/crafting_slice.gd")
const TechnologySlice := preload("res://src/technology/technology_slice.gd")
const UiSlice         := preload("res://src/ui/ui_slice.gd")
const VoxelSlice      := preload("res://src/terrain/voxel_slice.gd")
const AssetOverlayScript := preload("res://src/core/asset_overlay.gd")
const RebaseDriver    := preload("res://src/terrain/rebase_driver.gd")
const ChatCommands    := preload("res://src/core/chat_commands.gd")
const ChatSlice       := preload("res://src/chat/chat_slice.gd")
const StationSlice    := preload("res://src/world/station_slice.gd")
const TreeSlice       := preload("res://src/world/tree_slice.gd")
const MeshUtil        := preload("res://src/core/mesh_util.gd")
const MarketSlice     := preload("res://src/world/market_slice.gd")
const TradeSlice      := preload("res://src/trade/trade_slice.gd")
const ProposalSlice   := preload("res://src/governance/proposal_slice.gd")
const Minimap         := preload("res://src/ui/minimap.gd")
const BiomeBlend      := preload("res://src/terrain/biome_blend.gd")
const PlayerSlice     := preload("res://src/player/player_slice.gd")
const NetworkingSlice := preload("res://src/networking/networking_slice.gd")
const ClimateField := preload("res://src/terrain/climate_field.gd")
const WorldShape := preload("res://src/terrain/world_shape.gd")
const I18nScript := preload("res://src/core/i18n.gd")
const LocaleSettingsScript := preload("res://src/core/locale_settings.gd")
const DistantTerrainScript := preload("res://src/terrain/distant_terrain.gd")
const Locomotion      := preload("res://src/character/locomotion.gd")
const SkeletonRig     := preload("res://src/character/skeleton_rig.gd")
const SkillTiers      := preload("res://src/core/skill_tiers.gd")
const MultimeshPool   := preload("res://src/core/multimesh_pool.gd")
const SpatialHash     := preload("res://src/core/spatial_hash.gd")
const PlayerRegistry  := preload("res://src/persistence/player_registry.gd")
const EquipmentRules   := preload("res://src/character/equipment_rules.gd")
const GameDataReader   := preload("res://src/core/game_data_reader.gd")
const NetHarness      := preload("res://src/tests/net_harness.gd")
const OreField        := preload("res://src/terrain/ore_field.gd")

var _pass: int = 0
var _fail: int = 0
var _current_test: String = ""
## Method names (e.g. "_test_foo") registered via _run_test, used by the
## self-check to catch a test function that was written but never registered.
var _registered_names: Dictionary = {}

# ---------------------------------------------------------------------------
# Entry
# ---------------------------------------------------------------------------

func _count_files_with(dir: String, needle: String) -> int:
	var n := 0
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd") and FileAccess.get_file_as_string(dir.path_join(f)).contains(needle):
			n += 1
	for d in DirAccess.get_directories_at(dir):
		n += _count_files_with(dir.path_join(d), needle)
	return n

## The `remote_player_state` packets the host's outbox holds about `peer_id`.
func _relays_of_peer(n: NetworkingSlice, peer_id: int) -> Array:
	return n.memory_transport().outbox.filter(func(o): return str(o["payload"].get("type", "")) == "remote_player_state" \
			and int(o["payload"].get("peer_id", 0)) == peer_id)

func _assert_relay_exact(relayed: Array, chunk: Vector2i, local: Vector3, label: String) -> void:
	assert_false(relayed.is_empty(), "%s: the position was relayed to the peer in range" % label)
	if relayed.is_empty():
		return
	var got: Dictionary = WorldPos.pos_from_packet(relayed.back()["payload"])
	assert_eq(got["chunk"], chunk, "%s decodes to the same chunk" % label)
	assert_true((got["local"] as Vector3).distance_to(local) < 1e-3, "%s decodes to the same local" % label)

func _continuous_x(player: PlayerSlice) -> float:
	var wp := player.get_world_pos()
	return float((wp["chunk"] as Vector2i).x) * WorldPos.CHUNK_METERS + (wp["local"] as Vector3).x

const WorldPos := preload("res://src/terrain/world_pos.gd")

const VOID_RECIPE := "RecipeRefinedVoiditeShard"

## A host rig: a registry with a local player, a taming slice as the flag store, a profession
## slice and a crafting slice wired the way game_root wires them (no player body, no terrain).
func _make_void_rig() -> Dictionary:
	var registry := PlayerRegistry.new()
	add_child(registry)
	registry.set_local_player(registry.mint_player_id())
	var crafting := CraftingSlice.new()
	add_child(crafting)
	crafting.player_registry = registry
	var taming := TamingSlice.new()
	add_child(taming)
	taming.player_registry = registry
	var professions: Node = (load("res://src/crafting/profession_slice.gd") as GDScript).new()
	add_child(professions)
	professions.crafting_slice = crafting
	professions.flag_store = taming
	professions.player_registry = registry
	crafting.flag_store = taming
	crafting.profession_slice = professions
	return { "registry": registry, "crafting": crafting, "taming": taming, "professions": professions }

func _free_void_rig(rig: Dictionary) -> void:
	for k in ["professions", "taming", "crafting", "registry"]:
		rig[k].free()

## The first craft counter at or after `from` whose draw is (or is not) a burst.
func _void_counter(pid: String, want_burst: bool, from: int = 0) -> int:
	var chance := float(GameData.RECIPES[VOID_RECIPE].recipe.get("burst", {}).get("chance", 0.0))
	var i := from
	while (CraftingSlice.burst_roll(0, pid, i) < chance) != want_burst:
		i += 1
	return i

func _void_craft(rig: Dictionary, pid: String, counter: int) -> Dictionary:
	var reg: Node = rig["registry"]
	reg.record_craft_counter(pid, counter)
	reg.get_inventory(pid).add_item("Voidite", 1)
	return rig["crafting"].craft(VOID_RECIPE, pid)

## Wear `item_id` down by `uses` via the public use_item API, so durability
## tests exercise the real wear path instead of poking the private
## `_durability` dictionary.
func _wear_item(item: Node, item_id: String, uses: int) -> void:
	for i in uses:
		item.use_item(item_id, "mine")

## Break `item_id` completely by applying use_item max_durability times.
func _break_item(item: Node, item_id: String) -> void:
	var max_d := int(item.get_max_durability(item_id))
	for i in max_d:
		item.use_item(item_id, "mine")

## Sum every per-instance durability value across a list of inventory slices.
## Used to assert durability is conserved across a sync/load copy (never lost,
## never fabricated).
func _sum_durability_across(invs: Array) -> float:
	var total := 0.0
	for inv in invs:
		var data: Dictionary = inv.get_durability_data()
		for item_id in data:
			for v in data[item_id]:
				total += float(v)
	return total

## Build a VoxelSlice over a flat 2.0-tall synthetic chunk (deterministic).
func _make_voxel() -> VoxelSlice:
	var v := VoxelSlice.new()
	add_child(v)
	var hm: Array = []
	hm.resize(64 * 64)
	hm.fill(2.0)
	v.build_chunk(Vector2i(0, 0), hm)
	return v

## The DISTINCT vertical spans of the collision triangles lying wholly on the
## vertical plane x = `plane`, sorted. A seam assertion needs the GEOMETRY: a wall
## emitted across the wrong ordinates (say the whole column instead of the step the
## neighbour does not fill) has exactly the same triangle COUNT as the right one.
func _plane_x_spans(faces: PackedVector3Array, plane: float) -> Array:
	var spans: Array = []
	for i in range(0, faces.size() - 2, 3):
		if not (is_equal_approx(faces[i].x, plane) and is_equal_approx(faces[i + 1].x, plane) and is_equal_approx(faces[i + 2].x, plane)):
			continue
		var span := [
			minf(faces[i].y, minf(faces[i + 1].y, faces[i + 2].y)),
			maxf(faces[i].y, maxf(faces[i + 1].y, faces[i + 2].y)),
		]
		if not spans.has(span):
			spans.append(span)
	spans.sort_custom(func(a: Array, b: Array): return float(a[0]) < float(b[0]))
	return spans

## `_plane_x_spans` with abutting spans fused. Phase 49 splits a wall at the soil line (two
## colours), so a wall is one fused span; only callers on a topsoiled wall should use this —
## the raw form above is what catches a genuinely split wall.
func _plane_x_wall_spans(faces: PackedVector3Array, plane: float) -> Array:
	var merged: Array = []
	for span in _plane_x_spans(faces, plane):
		if not merged.is_empty() and is_equal_approx(float(merged[-1][1]), float(span[0])):
			merged[-1][1] = span[1]
		else:
			merged.append(span)
	return merged

const TEST_UI_LAYOUT := "user://test_ui_layout.json"

## UiSlice wired to a scratch layout file so tests never read the real one.
func _new_test_ui() -> UiSlice:
	DirAccess.remove_absolute(TEST_UI_LAYOUT)
	var ui := UiSlice.new()
	ui.layout_path = TEST_UI_LAYOUT
	add_child(ui)
	return ui

func _ui_row(rows: Array, id: String) -> Dictionary:
	for r in rows:
		if str(r["id"]) == id:
			return r
	return {}

const _HotbarScript := preload("res://src/ui/hotbar.gd")
const _WindowDockScript := preload("res://src/ui/window_dock.gd")
const _TEST_HOTBAR_FILE := "user://test_ui_layout_hotbar.json"
const _TEST_DOCK_FILE := "user://test_ui_layout_dock.json"

func _first_gear_item() -> String:
	var keys: Array = GameData.ITEMS.keys()
	keys.sort()
	for k in keys:
		if EquipmentRules.slot_of(str(k), GameData.ITEMS) != "":
			return str(k)
	return ""

func _first_block() -> String:
	var mats: Array = GameData.MATERIALS.keys()
	mats.sort()
	return str(mats[0])

func _blank_slots() -> Array:
	var cur := []
	for i in _HotbarScript.SLOT_COUNT:
		cur.append("")
	return cur

func _new_hud_ui() -> UiSlice:
	DirAccess.remove_absolute(_TEST_HOTBAR_FILE)
	DirAccess.remove_absolute(_TEST_DOCK_FILE)
	return _new_test_ui()

const _MapMath := preload("res://src/ui/map_math.gd")
const _MapTiles := preload("res://src/ui/map_tiles.gd")
const _MapWindow := preload("res://src/ui/map_window.gd")
const _RevealedStore := preload("res://src/persistence/revealed_store.gd")

func _wp_pos(cx: int, cz: int) -> Dictionary:
	return { "chunk": Vector2i(cx, cz), "local": Vector3(12.5, 3.0, 40.25) }

func invalidate_twice_check(t: RefCounted) -> void:
	for i in 3:
		t.invalidate()
	assert_true(t.stale_count() <= _MapTiles.STALE_MAX, "repeated refreshes never exceed the cap")

## Build an isolated AI rig: CreatureSlice + CreatureAI + a minimal PlayerSlice
## stub (just needs get_position()).
func _make_ai_rig() -> Dictionary:
	var c := CreatureSlice.new()
	add_child(c)
	c.spawn_for_chunk(Vector2i(0, 0))
	var ai := CreatureAI.new()
	ai.creature_slice = c
	add_child(ai)
	return { "creature": c, "ai": ai }

## Collect the instance ids of a specific creature type from a CreatureSlice.
func _instances_of(c: CreatureSlice, creature_id: String) -> Array:
	var out: Array = []
	for iid in c._instances:
		if c._instances[iid]["creature_id"] == creature_id:
			out.append(iid)
	return out

## Recursively collect every MeshInstance3D under `node` into `out`.
func _collect_mesh_instances(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		_collect_mesh_instances(child, out)

func _scan_dir_for_forbidden_strings(dir_path: String, forbidden: Array, violations: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var full_path := dir_path.path_join(entry)
			if dir.current_is_dir():
				_scan_dir_for_forbidden_strings(full_path, forbidden, violations)
			elif entry.ends_with(".gd") and not full_path.begins_with("res://src/tests/"):
				var f := FileAccess.open(full_path, FileAccess.READ)
				if f != null:
					var text := f.get_as_text()
					for needle in forbidden:
						if text.contains(needle):
							violations.append("%s contains '%s'" % [full_path, needle])
		entry = dir.get_next()
	dir.list_dir_end()

## A TreeSlice with no terrain wired: biome "" falls back to the default
## (temperate) entry, mirroring CreatureSlice's isolated-test path.
func _make_tree_slice() -> Node:
	var t := TreeSlice.new()
	add_child(t)
	return t

## Phase 92 — a fake terrain slice for the memo and pole-bound tests: a fixed biome, an optional
## polar bound.
class FixedBiomeStub extends Node:
	var biome := "DesertDunes"
	var radius := -1
	var world_seed := 1
	func get_biome_at(_xz: Vector2) -> String:
		return biome
	func get_world_seed() -> int:
		return world_seed
	func world_radius_chunks() -> int:
		return radius if radius >= 0 else TerrainSlice.polar_chunks()

## A terrain slice whose chunks past the pole rows carry a biome nothing in the world should wear.
class PoleBiomeStub extends Node:
	var world_seed := 1
	func biome_for_chunk(c: Vector2i) -> String:
		if absi(c.y) >= TerrainSlice.polar_chunks():
			return "VoidRift"
		return "DesertDunes" if c.x % 2 == 0 else "TemperateForest"
	func get_biome_at(xz: Vector2) -> String:
		return biome_for_chunk(Vector2i(floori(xz.x / VoxelSlice.CHUNK_SIZE / VoxelSlice.TILE_SIZE), floori(xz.y / VoxelSlice.CHUNK_SIZE / VoxelSlice.TILE_SIZE)))
	func get_world_seed() -> int:
		return world_seed

class BiomeStub extends Node:
	var lookups := 0
	var world_seed := 1
	func get_biome_at_chunk(c: Vector2i) -> String:
		lookups += 1
		return "DesertDunes" if c.x < 0 else ("TemperateForest" if c == Vector2i.ZERO else "VoidRift")
	func get_world_seed() -> int:
		return world_seed

class PartialBiome extends RefCounted:
	var temperature: Dictionary = {}
	var moisture: Dictionary = {}
	var altitude: Dictionary = {}

## First chunk whose biome is one of `biomes`, or Vector2i(-1, -1) when none is found.
## Phase 51: biomes follow latitude and the continents, so the scan walks a few latitude rows
## (the equator, then the temperate and subpolar belts of both hemispheres) and sweeps each east.
func _find_chunk_with_biome(terrain: Node, biomes: Array) -> Vector2i:
	for chunk in _biome_chunks(terrain, biomes, 1):
		return chunk
	return Vector2i(-1, -1)

## Up to `count` chunks whose biome is one of `biomes`, spread over the latitude rows.
func _biome_chunks(terrain: Node, biomes: Array, count: int) -> Array:
	var out: Array = []
	var pole := TerrainSlice.pole_chunks()
	for row in [0.0, 0.1, -0.1, 0.2, -0.2, 0.3, -0.3, 0.45, -0.45, 0.55, -0.55, 0.65, -0.65, 0.75, -0.75]:
		var cz := int(row * float(pole))
		# Continents are thousands of kilometres across: a coarse sweep of the whole circumference
		# finds land, and a fine sweep round each landfall finds the wanted biome.
		for coarse in range(-600000, 600000, 500):
			if str(terrain.get_biome_at_chunk(Vector2i(coarse, cz))) == "Ocean":
				continue
			for cx in range(coarse - 1500, coarse + 1500, 4):
				if biomes.has(str(terrain.get_biome_at_chunk(Vector2i(cx, cz)))):
					out.append(Vector2i(cx, cz))
					if out.size() >= count:
						return out
	return out

## Vertex count of the built chunk's rendered surfaces: the terrain surface plus the
## rare-vein deposit mesh. Phase 41 split those into two MeshInstance3Ds deliberately
## (a deposit is decoration and must never enter the collision soup), so the count is
## summed over the chunk's mesh children.
func _chunk_vein_vertices(voxel: Node, chunk_pos: Vector2i) -> int:
	# The rare-vein overlay is the chunk's SECOND mesh child; the terrain surface is
	# the first. Counted separately because the merged surface's vertex count is not a
	# per-tile number any more (Phase 42).
	var root: Node3D = voxel._chunks["%d,%d" % [chunk_pos.x, chunk_pos.y]]
	var meshes: Array = []
	for child in root.get_children():
		if child is MeshInstance3D:
			meshes.append(child)
	if meshes.size() < 2:
		return 0
	return (meshes[1] as MeshInstance3D).mesh.surface_get_array_len(0)

## Surface vertices of a chunk, from its committed mesh. Used where a test needs the
## TRIANGLE SOUP's shape rather than a per-tile count (see `_chunk_vein_vertices` for
## the overlay, which is unaffected by the merge).
func _chunk_surface_vertices(voxel: Node, chunk_pos: Vector2i) -> int:
	var root: Node3D = voxel._chunks["%d,%d" % [chunk_pos.x, chunk_pos.y]]
	var total := 0
	for child in root.get_children():
		if child is MeshInstance3D:
			total += (child as MeshInstance3D).mesh.surface_get_array_len(0)
	return total

## The MeshInstance3D children of a built chunk, in attach order: the terrain surface
## first, the rare-vein deposit overlay second when the chunk has one.
func _chunk_mesh_instances(voxel: Node, chunk_pos: Vector2i) -> Array:
	var root: Node3D = voxel._chunks["%d,%d" % [chunk_pos.x, chunk_pos.y]]
	var meshes: Array = []
	for child in root.get_children():
		if child is MeshInstance3D:
			meshes.append(child)
	return meshes

## Empty a test save directory so each run starts from a known state.
func _wipe_dir(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		DirAccess.make_dir_recursive_absolute(dir)
		return
	for file_name in d.get_files():
		d.remove(file_name)

## `evict_player` only `queue_free`s the inventory node it detaches, and the suite never reaches a
## frame, so the node would leak into Phase 84's orphan check. Every test that evicts goes through here.
func _evict_and_free(registry: PlayerRegistry, player_id: String) -> bool:
	var inv: Variant = registry.get_inventory(player_id) if registry.has_inventory(player_id) else null
	var evicted: bool = registry.evict_player(player_id)
	if inv != null and is_instance_valid(inv) and (inv as Node).get_parent() == null:
		(inv as Node).free()
	return evicted

# ---------------------------------------------------------------------------
# Phase 35 — creature taming
# ---------------------------------------------------------------------------
## A taming rig: a creature population, the local player's registry + inventory,
## and the taming slice wired to both. `character_slice` is left null unless a
## test needs the bare-hands rule (see _test_taming_requires_unarmed), because a
## null character slice means "no equipment model here" and the rule is skipped.
func _make_taming_rig() -> Dictionary:
	var c := CreatureSlice.new()
	add_child(c)
	c.spawn_for_chunk(Vector2i(0, 0))
	var crafting := CraftingSlice.new()
	add_child(crafting)
	var registry := PlayerRegistry.new()
	add_child(registry)
	registry.set_local_player(registry.mint_player_id())
	var taming := TamingSlice.new()
	add_child(taming)
	taming.creature_slice  = c
	taming.crafting_slice  = crafting
	taming.player_registry = registry
	taming.inventory_slice = null   # prove the registry is what answers
	# Phase 36 — the crafting slice is wired to the same registry game_root wires it
	# to, because skill tiers are resolved per player through it: without it the
	# slice has no notion of "this machine's player" and would read every tier as
	# novice (`get_skill_for` cannot tell a peer from a nameless local player).
	crafting.player_registry = registry
	return { "creature": c, "taming": taming, "crafting": crafting, "registry": registry }

## Resolve a tame for a REMOTE player the way the host does: through the intent the
## networking slice re-emits under the identity bound to the connection. The bare-hands
## rule is read from the host's own record of that peer's worn set.
func _taming_tame_via_intent(instance_id: String, player_id: String) -> Dictionary:
	var captured: Array = []
	var on_resolved := func(result: Dictionary) -> void:
		captured.append(result)
	GameBus.tame_resolved.connect(on_resolved)
	GameBus.tame_intent.emit(instance_id, player_id)
	GameBus.tame_resolved.disconnect(on_resolved)
	if captured.is_empty():
		return {}
	return captured[0]

## The first instance id of a fabric creature key, or "" when the population has
## none. Spawn order is deterministic but not alphabetical, so tests must look the
## species up rather than index the array.
func _taming_instance_of(c: Node, creature_id: String) -> String:
	for inst in c.get_all_instances():
		if str(inst["creature_id"]) == creature_id:
			return str(inst["instance_id"])
	return ""

## Every instance id of one species, in population order.
func _taming_instances_of(c: Node, creature_id: String) -> Array:
	var out: Array = []
	for inst in c.get_all_instances():
		if str(inst["creature_id"]) == creature_id:
			out.append(str(inst["instance_id"]))
	return out

## Put a player next to a creature. The approach rule is real (TamingSlice re-checks
## the distance), and a fresh record sits at the world origin, so a test that
## forgets this reads "too_far" instead of the reason it meant to assert.
func _taming_stand_near(registry: Node, player_id: String, c: Node, instance_id: String) -> void:
	registry.record_position(player_id, c.get_instance_position(instance_id))

## A duck-typed stand-in for a CONTENTS slice (creature or tree): the manager only asks
## for `has_method("spawn_for_chunk")` / `despawn_for_chunk`, so a spy is enough to count
## what the apply path asks for — which is the whole of the review-pass-3 finding that a
## rebuild re-derived a chunk's budgets on every block edit.
class ContentsSpy:
	extends Node
	var spawned: Array = []
	var despawned: Array = []
	func spawn_for_chunk(chunk_pos: Vector2i) -> void:
		spawned.append(chunk_pos)
	func despawn_for_chunk(chunk_pos: Vector2i) -> void:
		despawned.append(chunk_pos)

## A player stand-in that COUNTS how often its position is read. `ChunkManager.player_chunk()`
## reaches the body through `player_slice.get_position()`, so the count is a direct measure of
## how often the manager resolved the streamed window.
class PlayerPosSpy:
	extends Node
	var reads: int = 0
	var position: Vector3 = Vector3(16.0, 40.0, 16.0)
	func get_position() -> Vector3:
		reads += 1
		return position

## A ChunkManager wired to a real TerrainSlice + VoxelSlice and a local player — what
## the threaded build needs. An isolated manager with no terrain has nothing to
## dispatch (see `_dispatch_build`'s early return, which the older rigs rely on).
func _make_chunk_build_rig() -> Dictionary:
	var cm := ChunkManager.new()
	cm.pump_budget_msec = 0   # the suite has no frame: the time bound has its own test (stubbed clock)
	add_child(cm)
	var terrain := TerrainSlice.new()
	add_child(terrain)
	var voxel := VoxelSlice.new()
	voxel.terrain_slice = terrain
	add_child(voxel)
	var player := PlayerSlice.new()
	add_child(player)
	cm.terrain_slice = terrain
	cm.voxel_slice = voxel
	cm.player_slice = player
	# Phase 42 review — the production wiring is two-way: game_root also points the voxel
	# slice back at the manager, so an EDIT dispatches its rebuild to a worker instead of
	# building the touched chunks synchronously (see `request_rebuild`).
	voxel.chunk_manager = cm
	player.spawn_at(Vector3(16.0, 40.0, 16.0))
	return { "cm": cm, "terrain": terrain, "voxel": voxel, "player": player }

## Drive the manager's build pump to quiescence: dispatch, BLOCK on the in-flight
## builds, apply. `flush_builds` is the blocking variant of the frame loop's poll —
## the suite cannot yield, so it waits rather than polling, which is also why it does
## not call `WorkerThreadPool.is_task_completed` itself.
func _wait_for_builds(cm: Node, rounds: int = 128) -> void:
	for i in range(rounds):
		if cm._builds.is_empty() and cm._load_queue.is_empty() and cm._rebuild_queue.is_empty():
			return
		cm._drain_load_queue()
		cm.flush_builds()

## Median of an Array of ints (the upper middle for an even count).
func _median_int(values: Array) -> int:
	var sorted := values.duplicate()
	sorted.sort()
	@warning_ignore("integer_division")
	return int(sorted[sorted.size() / 2])

## One clock read for the build-split probe: the real clock times `clock_scale` (a uniformly slow
## runner), plus — when `spike_every` > 0 — a PROBE_SPIKE_US stall on every `spike_every`-th read, the
## way a descheduled thread stalls one span and not its neighbours. Uniform scaling cancels in
## every ratio the probe asserts; a spike does not, so it exercises the medians and the floor.
const PROBE_SPIKE_US := 40000
var _probe_reads: int = 0

func _probe_now(clock_scale: int, spike_every: int) -> int:
	_probe_reads += 1
	var spike := PROBE_SPIKE_US if spike_every > 0 and _probe_reads % spike_every == 0 else 0
	return Time.get_ticks_usec() * clock_scale + spike

func _chunk_build_split_probe(clock_scale: int, spike_every: int = 0) -> void:
	var terrain := TerrainSlice.new()
	add_child(terrain)
	var voxel := VoxelSlice.new()
	voxel.terrain_slice = terrain
	add_child(voxel)
	# A 3×3 ring of heightmaps, so the resolve has real ring tiles to subtract against — the
	# production case. Without them every ring tile reads as an UNKNOWN neighbour and the measured
	# cost would flatter itself.
	for cz in range(-1, 2):
		for cx in range(-1, 2):
			var c := Vector2i(cx, cz)
			voxel._heightmaps["%d,%d" % [cx, cz]] = terrain.generate_heightmap(c)
	var resolve_us := 0            # the main-thread half, summed (see `main_pass` for per-pass)
	var pure_us := 0               # the worker half (resolve + build), summed
	var apply_us := 0
	var worker_resolve_us := 0
	var main_pass: Array = []      # per-pass main-thread half: generate + gather + apply
	var resolve_pass: Array = []   # per-pass main-thread gather alone
	var pure_pass: Array = []      # per-pass worker half: resolve + build
	var built: Dictionary = {}
	for i in range(5):
		# --- the MAIN-THREAD half of one dispatch, in `_dispatch_build`'s own order ---
		var t0 := _probe_now(clock_scale, spike_every)
		var hm: Array = terrain.generate_heightmap(Vector2i(0, 0))
		var gathered: Dictionary = voxel.gather_build_input(Vector2i(0, 0), hm)
		var r_us := _probe_now(clock_scale, spike_every) - t0
		resolve_us += r_us
		resolve_pass.append(r_us)
		# --- the WORKER half: the resolve, then the pure build ---
		var t0b := _probe_now(clock_scale, spike_every)
		t0 = t0b
		var resolved: Dictionary = VoxelSlice.build_runs(Vector2i(0, 0), hm, gathered)
		worker_resolve_us += _probe_now(clock_scale, spike_every) - t0
		t0 = _probe_now(clock_scale, spike_every)
		built = VoxelSlice.build_chunk_arrays(Vector2i(0, 0), hm, resolved)
		pure_us += _probe_now(clock_scale, spike_every) - t0
		pure_pass.append(_probe_now(clock_scale, spike_every) - t0b)
		# The apply half: exactly what `build_chunk` does with the worker's result on the
		# main thread (minus the node attachment, a few object allocations either way).
		t0 = _probe_now(clock_scale, spike_every)
		VoxelSlice._mesh_from_arrays(built)
		var deposit_vertices: PackedVector3Array = built["deposit_vertices"]
		if not deposit_vertices.is_empty():
			VoxelSlice._mesh_from_arrays({
				"vertices": built["deposit_vertices"], "normals": built["deposit_normals"],
				"colors": built["deposit_colors"], "indices": built["deposit_indices"],
			})
		var trimesh := ConcavePolygonShape3D.new()
		trimesh.set_faces(built["collision"])
		var a_us := _probe_now(clock_scale, spike_every) - t0
		apply_us += a_us
		main_pass.append(r_us + a_us)
	var gathered_empty: Dictionary = voxel.gather_build_input(Vector2i(0, 0), terrain.generate_heightmap(Vector2i(0, 0)))
	var main_us := resolve_us + apply_us
	# Phase 115 (#261) — medians, not one wall-clock sample: a scheduler hiccup in a single pass says
	# nothing about the cost the assertions guard.
	var steady_main: int = _median_int(main_pass)
	var steady_resolve: int = _median_int(resolve_pass)
	var steady_worker: int = _median_int(pure_pass)
	var deposit_verts: int = (built["deposit_vertices"] as PackedVector3Array).size()
	print("PROBE Phase 42 build split (5 passes): main-thread half %d us (generate+gather %d + apply %d), worker half %d us (resolve %d + build %d) (%d faces -> %d quads, %d deposit verts)" % [
		main_us, resolve_us, apply_us, pure_us, worker_resolve_us, pure_us - worker_resolve_us,
		int(built["cell_count"]), int(built["quad_count"]), deposit_verts])
	print("PROBE Phase 42 build split per pass: main %s us (steady state %d, of which generate+gather %d), worker %s us" % [
		str(main_pass), steady_main, steady_resolve, str(resolve_pass)])
	assert_true(int(built["cell_count"]) > 0, "the worker half produced a real chunk")
	assert_true((VoxelSlice._mesh_from_arrays(built)).get_surface_count() == 1,
		"and its arrays commit to a mesh")
	assert_true(resolve_us > 0 and pure_us > 0, "and both halves' costs were measured")
	# THE ratio criterion (row 8): the expensive half is the half that runs off the main thread.
	# Measured ~1.8x on the machine that pass ran on, so a strict `>` is the honest assertion — a
	# ratio test tight enough to be interesting would be a flake.
	assert_true(steady_worker > steady_main,
		"the worker half dominates the main thread's own work (median %d us vs %d us)" % [steady_worker, steady_main])
	# THE ceiling (rows 3 and 4): one dispatch per frame means the main thread pays this every frame.
	# Phase 123 (#324): a fixed 16,667 us budget flaked on slow runners, so the frame is measured by
	# the clock this run reads: the generate+gather part of the main-thread half must stay well under
	# the worker's resolve+build, the work it exists to keep off the main thread.
	assert_true(steady_resolve * 2 < steady_worker,
		"generate+gather is under half the worker half (median %d us vs %d us)" % [steady_resolve, steady_worker])

	# Phase 42 review pass 10 — and the ceiling is asserted AGAIN over a POPULATED edit log,
	# which is what the pass-9 probe could not do: it measured a FRESH slice, so `_edits` was
	# empty, `_gather_edits` returned on its first line, and the gather cost — the one thing the
	# chunk index exists to bound — was never in the number the ceiling checked. Populate a
	# WORLD's worth of edits (a full chunk in the window, plus several chunks far outside it, so
	# the LOG is large while the WINDOW is not) and time the same main-thread half. The far
	# chunks are the point: the old gather walked and string-split EVERY one of them on each
	# dispatch; only the window's are copied now.
	var op_template := [{ "op": "remove", "bottom": 1.5, "top": 2.0 }]
	for ty in range(64):
		for tx in range(64):
			voxel._set_edit_ops(VoxelSlice._tile_key(Vector2i(tx, ty)), op_template)
	# ...plus 24 chunks well OUTSIDE the window (≈98k more edits), so the log is a long-played
	# world's and dwarfs the window. That ratio is the assertion: with the OLD world-scan gather
	# this log cost one string split per edit here per dispatch and blew the frame; with the
	# index only the window's 4096 are copied, whatever the world holds.
	for far_i in range(24):
		@warning_ignore("integer_division")
		var far := Vector2i(far_i % 6 + 4, far_i / 6 + 4)
		for i in range(4096):
			@warning_ignore("integer_division")
			voxel._set_edit_ops(VoxelSlice._tile_key(Vector2i(far.x * 64 + (i % 64), far.y * 64 + (i / 64))), op_template)
	var populated_pass: Array = []
	var window_edits := 0
	for i in range(7):
		var t0p := _probe_now(clock_scale, spike_every)
		var hm2: Array = terrain.generate_heightmap(Vector2i(0, 0))
		var gathered2: Dictionary = voxel.gather_build_input(Vector2i(0, 0), hm2)
		window_edits = (gathered2["edits"] as Dictionary).size()
		populated_pass.append(_probe_now(clock_scale, spike_every) - t0p)
	# Best of several passes: a wall-clock budget on a shared CI runner is noisy, and a scheduler
	# hiccup in one pass says nothing about the gather cost the assertion guards.
	var steady_pop: int = int(populated_pass.min())
	print("PROBE Phase 42 gather with a populated edit log: %d edits across %d chunks (%d in the window), main-thread generate+gather %s us (steady %d of %d)" % [
		voxel._edits.size(), voxel._edits_by_chunk.size(), window_edits, str(populated_pass), steady_pop, 3 * steady_resolve])
	assert_true(window_edits >= 4096, "the window's edit log is genuinely populated (%d tiles)" % window_edits)
	# Work count, not a clock: the gather copies the window's edits and nothing of the far chunks'.
	# A gather that walked the whole log would copy ~100k here whatever the clock says, and a clock
	# ratio alone cannot catch a slow main-thread half that the worker half happens to match.
	assert_eq(window_edits, 4096, "the gather copies exactly the window's 4096 edits")
	assert_true(window_edits * 10 < voxel._edits.size(),
		"out of a log that dwarfs the window (%d of %d edits)" % [window_edits, voxel._edits.size()])
	assert_eq((gathered_empty["edits"] as Dictionary).size(), 0, "an empty edit log gathers no edits")
	# Three times the empty-log cost measured on this same run: a slow shared runner scales both halves
	# alike, while the old world-scan gather cost many times more.
	# The floor keeps a ~1 ms empty-log median from shrinking the ceiling to a few ms of scheduler noise;
	# the work-count assertions above are what pin the gather's cost, this only bounds the wall clock.
	var pop_ceiling: int = maxi(3 * steady_resolve, 3000 * clock_scale)
	assert_true(steady_pop < pop_ceiling,
		"and the main-thread half still fits a frame with a populated edit log (%d us of %d us, %d window edits)" % [
			steady_pop, pop_ceiling, window_edits])
	terrain.free()
	voxel.free()

func _flat_heightmap(h: float) -> Array:
	var hm: Array = []
	hm.resize(64 * 64)
	hm.fill(h)
	return hm

## The first vein (searching chunks along +X) whose blob breaks the surface of a flat 2.0
## chunk: `{ chunk, tile (chunk-local), vein }`, or `{}`.
func _find_surface_vein(seed_v: int) -> Dictionary:
	for cx in range(0, 16):
		var chunk := Vector2i(cx, 0)
		var cache: Dictionary = {}
		for tz in range(64):
			for tx in range(64):
				var vein := OreField.vein_at(seed_v, chunk, Vector2i(tx, tz), 0.0625, cache)
				if not vein.is_empty():
					return { "chunk": chunk, "tile": Vector2i(tx, tz), "vein": vein }
	return {}

## A grid sample of the field: "gx,gz,k" → material ("" outside a vein).
func _ore_sample(seed_v: int) -> Dictionary:
	var out: Dictionary = {}
	for cz in range(-2, 2):
		for cx in range(-2, 2):
			var chunk := Vector2i(cx, cz)
			for tz in range(0, 64, 3):
				for tx in range(0, 64, 3):
					for k in range(0, 12):
						var depth := 0.0625 + float(k) * 0.875
						var vein := OreField.vein_at(seed_v, chunk, Vector2i(tx, tz), depth)
						out["%d,%d,%d" % [cx * 64 + tx, cz * 64 + tz, k]] = "" if vein.is_empty() else str(vein["material"])
	return out

## Aethermite vein counts of up to 16 volcanic chunks of world `seed` (appended to `counts`).
func _collect_volcanic_counts(seed_v: int, counts: Array) -> void:
	for cz in range(-400, 400, 5):   # rare niches are blobs now: scan wide to find volcanic ground
		for cx in range(-400, 400, 5):
			var chunk := Vector2i(cx, cz)
			if TerrainSlice.biome_for_chunk(chunk, seed_v) != "VolcanicBadlands":
				continue
			var n := 0
			var cache: Dictionary = {}
			for tz in range(0, 64, 2):
				for tx in range(0, 64, 2):
					for depth in [4.5, 6.5, 8.5]:
						var vein := OreField.vein_at(seed_v, chunk, Vector2i(tx, tz), depth, cache)
						if not vein.is_empty() and str(vein["material"]) == "Aethermite":
							n += 1
			counts.append(n)
			if counts.size() >= 16:
				break
		if counts.size() >= 16:
			break

func assert_eq(a, b, msg: String = "") -> void:
	if a == b:
		_ok()
	else:
		_ko("assert_eq FAILED [%s]: expected %s, got %s" % [msg, str(b), str(a)])

func assert_true(cond: bool, msg: String = "") -> void:
	if cond:
		_ok()
	else:
		_ko("assert_true FAILED [%s]" % msg)

func assert_false(cond: bool, msg: String = "") -> void:
	if not cond:
		_ok()
	else:
		_ko("assert_false FAILED [%s]" % msg)

func _ok() -> void:
	_pass += 1

func _ko(msg: String) -> void:
	_fail += 1
	push_error("  ✗ [%s] %s" % [_current_test, msg])

## Phase 84 — nodes a test helper created and handed back: freed right after the test, so a
## helper (`_spawn_world`) does not need every caller to remember a `free()`.
var _owned: Array = []

func _own(n: Node) -> Node:
	_owned.append(n)
	return n

func _free_owned() -> void:
	for n in _owned:
		if is_instance_valid(n):
			n.free()
	_owned.clear()

## A wired world for the spawn tests: a real terrain slice on `seed_v`, and the chunks of
## `biome` found in a 24x24 sample (a creature only spawns in chunks of its own biome).
func _spawn_world(seed_v: int, biome: String) -> Dictionary:
	var terrain := TerrainSlice.new()
	_own(terrain)
	terrain.set_world_seed(seed_v)
	var chunks: Array = []
	for x in range(-12, 12):
		for z in range(-12, 12):
			if str(terrain.get_biome_at_chunk(Vector2i(x, z))) == biome:
				chunks.append(Vector2i(x, z))
	return { "terrain": terrain, "chunks": chunks }

class _BiomeStub extends Node:
	var biome: String = ""
	func get_biome_at_chunk(_c: Vector2i) -> String:
		return biome

## Pure envelope pick over `biomes`' resources at (t, m, altitude); `niche` stands in for every
## biome's niche draw. Was `ClimateField.biome_for_climate`, which only the suite called.
func _climate_pick(t: float, m: float, keys: Array, biomes: Dictionary, altitude: float = 50.0, niche: float = 0.0) -> String:
	var envs: Dictionary = {}
	for key in keys:
		envs[str(key)] = ClimateField._envelope_of(biomes.get(key, null))
	return ClimateField._pick(t, m, altitude, keys, envs, niche, false)

## Height of triangle (a, b, c) at the XZ of `pt`, or NAN when the point lies outside it.
func _tri_height_at(a: Vector3, b: Vector3, c: Vector3, pt: Vector2) -> float:
	var d := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
	if absf(d) < 0.000001:
		return NAN
	var l1 := ((b.z - c.z) * (pt.x - c.x) + (c.x - b.x) * (pt.y - c.z)) / d
	var l2 := ((c.z - a.z) * (pt.x - c.x) + (a.x - c.x) * (pt.y - c.z)) / d
	var l3 := 1.0 - l1 - l2
	var e := -0.0001
	if l1 < e or l2 < e or l3 < e:
		return NAN
	return l1 * a.y + l2 * b.y + l3 * c.y

class SwimTerrainStub extends Node:
	var height := 0.0
	func get_height_at(_p: Vector2) -> float:
		return height

class SwimVoxelStub extends Node:
	var runs: Array = []
	func get_column_runs_at(_p: Vector2) -> Array:
		return runs

const RegionStoreScript := preload("res://src/persistence/region_store.gd")
const RegionStreamerScript := preload("res://src/persistence/region_streamer.gd")

func _fresh_region_dir(dir_name: String) -> String:
	var dir := "user://saves/%s/" % dir_name
	_wipe_dir(dir)
	_wipe_dir(dir + "regions/")
	return dir

func _region_files(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d != null:
		for f in d.get_files():
			if f.begins_with("r.") and f.ends_with(".json"):
				out.append(f)
	out.sort()
	return out

func _write_region_file(store: RegionStoreScript, chunks: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(store.dir)
	var f := FileAccess.open(store.path_of(Vector2i.ZERO), FileAccess.WRITE)
	f.store_string(JSON.stringify({ "version": 1, "chunks": chunks }))
	f.close()

func _gen_rec(biome := "Tundra", h0 := 12.34567) -> Dictionary:
	return { "v": TerrainSlice.WORLDGEN_VERSION, "f": TerrainSlice.worldgen_fingerprint(), "b": biome,
		"h": [h0, h0 + 1.5, h0 - 2.25, h0 + 0.00012] }

class _StrandedStub:
	var releases := 0
	func has_stranded() -> bool:
		return true
	func release_stranded() -> int:
		releases += 1
		return 0

const SpawnFinderScript := preload("res://src/world/spawn_finder.gd")
const WorldShapeScript := preload("res://src/terrain/world_shape.gd")
const ColonizationMapScript := preload("res://src/world/colonization_map.gd")

## Distance in metres from world (x, z) to the rectangle of `region`, X the short way round.
## Independent of `ColonizationMap.is_near_colonized`, so the avoidance test is not circular.
func _dist_to_region(x: float, z: float, region: Vector2i) -> float:
	var m := ColonizationMapScript.REGION_METERS
	var circ := float(TerrainSlice.circumference_chunks()) * TerrainSlice.CHUNK_METERS
	var dx := absf(fposmod(x - (float(region.x) + 0.5) * m + circ * 0.5, circ) - circ * 0.5)
	var dz := absf(z - (float(region.y) + 0.5) * m)
	return Vector2(maxf(dx - m * 0.5, 0.0), maxf(dz - m * 0.5, 0.0)).length()

func _wp_world(wp: Variant) -> Vector3:
	var chunk: Vector2i = wp["chunk"]
	var local: Vector3 = wp["local"]
	return Vector3(chunk.x * WorldPos.CHUNK_METERS + local.x, local.y, chunk.y * WorldPos.CHUNK_METERS + local.z)

func _clock_at_year_fraction(yf: float) -> RefCounted:
	var c := WorldClock.new()
	c.time_days = yf * c.year_length_days + 0.5   # solar noon
	return c

## Phase 69 — a loaded rig with the 3×3 block around (0,0) built except (0,0) itself.
func _seam_rig() -> Dictionary:
	var rig := _make_chunk_build_rig()
	var cm: ChunkManager = rig["cm"]
	cm.max_builds_in_flight = 16
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if dx != 0 or dz != 0:
				cm.load_chunk(Vector2i(dx, dz))
	_wait_for_builds(cm)
	cm.reset_rebuild_requests()
	return rig

func _seam_rig_free(rig: Dictionary) -> void:
	rig["cm"].free()
	rig["voxel"].free()
	rig["terrain"].free()
	rig["player"].free()

func _seam_requested(cm: ChunkManager) -> Array:
	var out: Array = cm.rebuilt_chunk_keys()
	out.sort()
	return out

## Test stand-in for the local body: reports a fixed exact world position.
class _StubBody extends Node:
	var wp: Dictionary = {}
	func get_world_pos() -> Dictionary:
		return wp
	func get_position() -> Vector3:
		return Vector3.ZERO

func _chat_rig() -> Dictionary:
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("player_host_1")
	var chat := ChatSlice.new()
	chat.render_visuals = false
	chat.admins_path = "user://does_not_exist_admins.json"
	chat.player_registry = reg
	add_child(chat)
	return { "reg": reg, "chat": chat }

const BiomeAdjacency := preload("res://src/terrain/biome_adjacency.gd")
const ADJACENCY_SEEDS: Array = [20260815, 7, 424242, 1999999]
const ADJACENCY_GRID := 256

## Grid origins for a seed: the equator, the temperate belt, the polar edge and a coastline.
func _adjacency_origins(seed_v: int) -> Array:
	@warning_ignore("integer_division")
	var half := ADJACENCY_GRID / 2
	@warning_ignore("integer_division")
	var belt := TerrainSlice.pole_chunks() / 2
	var polar := TerrainSlice.polar_chunks() - ADJACENCY_GRID
	var out: Array = [Vector2i(-half, -half), Vector2i(-half, belt - half), Vector2i(-half, polar)]
	# Coast: walk east along a temperate row until land meets Ocean, and centre the grid there.
	@warning_ignore("integer_division")
	var found := _find_coast(seed_v, belt / 2, 9000, Callable(), COAST_SCAN_STRIDE)
	assert_true(found["found"], "seed %d: a coast was found within the search (the coast grid is not a stand-in)" % seed_v)
	out.append(found["coast"] - Vector2i(half, half))
	return out

## Most biome calls one `_find_coast` may make across all its rows (a seed with no coast cannot spin).
const COAST_MAX_CALLS := 200000
## The adjacency scan only needs *a* coast, which on a planet-sized row lies far out, so it samples every
## 64 chunks; `_find_coast` itself steps one chunk at a time by default and cannot step over a thin strip.
const COAST_SCAN_STRIDE := 64

## `{ found, coast }`: the first chunk east of x=0 on a temperate row where land and Ocean swap, one chunk
## at a time (a larger stride could step over a one-chunk ocean strip). Row `z` is tried first, then rows
## 64 chunks apart (a seed whose first row is all one kind still has a coast on the next). `stride` is
## the chunks between samples. `found` is
## false (and `coast` the row start) when `max_steps` or `COAST_MAX_CALLS` ends the search without a
## change. `biome_of` (a `Callable(chunk) -> String`) replaces the generator in a test.
func _find_coast(seed_v: int, z: int, max_steps: int, biome_of: Callable = Callable(), stride: int = 1) -> Dictionary:
	var calls := 0
	for row in 8:
		var rz := z + row * 64
		var prev := _coast_ocean(seed_v, Vector2i(0, rz), biome_of)
		calls += 1
		for step in range(1, max_steps):
			if calls >= COAST_MAX_CALLS:
				return { "found": false, "coast": Vector2i(0, z) }
			var c := Vector2i(step * stride, rz)
			var cur := _coast_ocean(seed_v, c, biome_of)
			calls += 1
			if cur != prev:
				return { "found": true, "coast": c }
			prev = cur
	return { "found": false, "coast": Vector2i(0, z) }

func _coast_ocean(seed_v: int, c: Vector2i, biome_of: Callable) -> bool:
	var biome: String = str(biome_of.call(c)) if biome_of.is_valid() else TerrainSlice.generated_biome_for_chunk(c, seed_v)
	return biome == "Ocean"

const Frontier := preload("res://src/terrain/frontier.gd")
const FRONTIER_SEED := 20261011
const FRONTIER_BLOCK := Vector2i(300, 400)   # origin of the recorded block, far from the spawn plain
const FRONTIER_BLOCK_SIZE := 6
const FRONTIER_WINDOW := 24                  # chunks per side of the window around the block
## The largest height step between two adjacent corners across the blend band must stay within the
## plain generator's own largest step over the same window (stand-in change below: ridges at a quarter
## amplitude, the whole spline 30 m higher), plus a margin for the recorded-versus-generated offset.
## Phase 114: no longer a constant; `_frontier_plain_max_step` derives the bound from the generator.

## Stand in for a new generator version: change the warmed ridge amplitude and height spline. Returns
## the old values for `_frontier_restore_generator`.
func _frontier_change_generator() -> Array:
	WorldShape.warm()
	var saved: Array = [WorldShape._ridge_amp, WorldShape._spline]
	WorldShape._ridge_amp = WorldShape._ridge_amp * 0.25
	var sp: Array = []
	for pt in WorldShape._spline:
		sp.append([pt[0], minf(float(pt[1]) + 30.0, WorldShape.max_height())])
	WorldShape._spline = sp
	TerrainSlice.reset_fingerprint_cache()
	return saved

func _frontier_restore_generator(saved: Array) -> void:
	WorldShape._ridge_amp = saved[0]
	WorldShape._spline = saved[1]
	TerrainSlice.reset_fingerprint_cache()

## Record the current generator's record for every chunk of a block (the "recorded land").
func _frontier_record_block() -> void:
	ChunkRecordsScript.clear()
	for dz in FRONTIER_BLOCK_SIZE:
		for dx in FRONTIER_BLOCK_SIZE:
			var c := FRONTIER_BLOCK + Vector2i(dx, dz)
			ChunkRecordsScript.set_record(c, RegionStoreScript.normalize_gen(TerrainSlice.generation_record(c, FRONTIER_SEED)))

func _frontier_window_origin() -> Vector2i:
	@warning_ignore("integer_division")
	return FRONTIER_BLOCK - Vector2i.ONE * ((FRONTIER_WINDOW - FRONTIER_BLOCK_SIZE) / 2)

## Give every unrecorded chunk of the window its frontier record, in raster order (as a player walking
## would), so each border is resolved against whatever is recorded when its later chunk arrives.
func _frontier_fill_window() -> void:
	var o := _frontier_window_origin()
	for dz in FRONTIER_WINDOW:
		for dx in FRONTIER_WINDOW:
			var c := o + Vector2i(dx, dz)
			if not ChunkRecordsScript.has_record(c):
				ChunkRecordsScript.set_record(c, RegionStoreScript.normalize_gen(Frontier.record_for(c, FRONTIER_SEED)))

## The plain (new) generator's largest step between adjacent corners of the window at `o`.
func _frontier_plain_max_step(o: Vector2i) -> float:
	var worst := 0.0
	for dz in FRONTIER_WINDOW:
		for dx in FRONTIER_WINDOW:
			var p := o + Vector2i(dx, dz)
			var h := TerrainSlice.generated_corner_height(p, FRONTIER_SEED)
			worst = maxf(worst, absf(h - TerrainSlice.generated_corner_height(p + Vector2i(1, 0), FRONTIER_SEED)))
			worst = maxf(worst, absf(h - TerrainSlice.generated_corner_height(p + Vector2i(0, 1), FRONTIER_SEED)))
	return worst

## Scratch broken blend: a corner the recorded block touches keeps its recorded height, every other
## corner is the plain generator's. `blended` is the real field (lattice point -> height).
func _frontier_unblended_max_step(_o: Vector2i, blended: Dictionary) -> float:
	var field: Dictionary = {}
	for p in blended:
		var inside: bool = p.x >= FRONTIER_BLOCK.x and p.x <= FRONTIER_BLOCK.x + FRONTIER_BLOCK_SIZE \
				and p.y >= FRONTIER_BLOCK.y and p.y <= FRONTIER_BLOCK.y + FRONTIER_BLOCK_SIZE
		field[p] = float(blended[p]) if inside else TerrainSlice.generated_corner_height(p, FRONTIER_SEED)
	var worst := 0.0
	for p in field:
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			if field.has(p + d):
				worst = maxf(worst, absf(float(field[p]) - float(field[p + d])))
	return worst

const RECORDS_GOLDEN_HASH := 1508089442
const RECORDS_GOLDEN_BIOMES := 3756816773
const ChunkRecordsScript := preload("res://src/terrain/chunk_records.gd")
const SeamWrapScript := preload("res://src/terrain/seam_wrap.gd")

func _records_chunks64() -> Array:
	var out: Array = []
	for i in 64:
		out.append(Vector2i((i * 7919) % 4000 - 2000, (i * 104729) % 2000 - 1000))
	return out

func _records_hash(t: Node, chunks: Array) -> int:
	var h := 17
	for c in chunks:
		var hm: Array = t.generate_heightmap(c)
		for i in range(0, hm.size(), 37):
			h = (h * 31 + int(roundf(float(hm[i]) * 1000.0))) & 0x7fffffff
	return h

func _records_rig(dir_name: String, with_store := true) -> Dictionary:
	ChunkRecordsScript.clear()
	var dir := _fresh_region_dir(dir_name)
	var t := TerrainSlice.new()
	add_child(t)
	t.set_world_seed(31)
	var cm := ChunkManager.new()
	cm.terrain_slice = t
	var store: RegionStoreScript = RegionStoreScript.new(dir + "regions/")
	if with_store:
		cm.record_store = store
	return { "t": t, "cm": cm, "store": store }

const ChunkRecordSyncScript := preload("res://src/terrain/chunk_record_sync.gd")

func _sync_record(c: Vector2i, biome := "Desert") -> Dictionary:
	var rec := RegionStoreScript.normalize_gen(TerrainSlice.generation_record(c, 77))
	rec["b"] = biome
	return rec

## Phase 126 — the tile a top-face edit at `pos` resolves to, as `VoxelSlice._resolve_edit_tile` names it.
func _edit_tile_of(pos: Vector3, tree_slice: Node) -> Vector2i:
	var ts: float = tree_slice._tile_size()
	return Vector2i(floori(pos.x / ts), floori(pos.z / ts))

func _tree_pin_rig(chunk: Vector2i) -> Node:
	ChunkRecordsScript.clear()
	ChunkRecordsScript.set_record(chunk, _sync_record(chunk, "TemperateForest"))
	var t := _make_tree_slice()
	t.record_writer = func(c: Vector2i, rec: Dictionary) -> void:
		ChunkRecordsScript.set_record(c, RegionStoreScript.normalize_gen(rec))
	return t

const RegionStreamerScript114 := preload("res://src/persistence/region_streamer.gd")

func _p114_corrupt_region(store: RegionStoreScript, region: Vector2i) -> void:
	DirAccess.make_dir_recursive_absolute(store.path_of(region).get_base_dir())
	var f := FileAccess.open(store.path_of(region), FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()

const RegionStreamer121 := preload("res://src/persistence/region_streamer.gd")
const SaveTxn121 := preload("res://src/persistence/save_txn.gd")

class _Voxel121 extends RefCounted:
	var scans := 0
	var keys: Array = []
	var dirty := {}
	func apply_region_chunks(_c: Dictionary) -> void:
		pass
	func edited_chunk_keys() -> Array:
		scans += 1
		return keys.duplicate()
	func evict_clean_chunks(listed: Array) -> int:
		var n := 0
		for k in listed:
			if not dirty.has(k) and keys.has(k):
				keys.erase(k)
				n += 1
		return n

func _op121(top: float) -> Dictionary:
	return { "edits": { "0,0": [{ "op": "remove", "bottom": 1.0, "top": top }] } }

func _world121(seed_value: int, top: float) -> Dictionary:
	return { "local_player_id": "p", "seed": seed_value, "chunks": { "0,0": _op121(top), "40,0": _op121(top) } }

func _slice121(slice_name: String) -> PersistenceSlice:
	var dir := _fresh_region_dir(slice_name)
	var slice := PersistenceSlice.new()
	add_child(slice)
	slice.server_save_dir = dir
	return slice

func _state121(slice: PersistenceSlice) -> Array:
	var w := slice.load_world()
	var tops: Array = []
	for k in ["0,0", "40,0"]:
		var e: Variant = (w.get("chunks", {}) as Dictionary).get(k, null)
		tops.append(float(e["edits"]["0,0"][0]["top"]) if e is Dictionary else -1.0)
	return [int(w.get("seed", -1)), tops]

## A fake pack whose availability check passes but whose consume fails (a race).
class RefusingInventory extends InventorySlice:
	func consume_items(_counts: Dictionary) -> bool:
		return false

func _waystone_rig() -> Dictionary:
	var reg := PlayerRegistry.new()
	add_child(reg)
	reg.set_local_player("player_host_1")
	reg.ensure_player("p1")
	reg.ensure_player("p2")
	var stations := StationSlice.new()
	add_child(stations)
	var way := WaystoneSlice.new()
	way.station_slice = stations
	way.registry = reg
	add_child(way)
	var now := [100.0]
	way.now_sec = func() -> float: return now[0]
	var where := { "p1": WorldPos.from_world(0.5, 1.0, 0.5), "p2": WorldPos.from_world(0.5, 1.0, 0.5) }
	way.position_of = func(pid: String) -> Dictionary: return where[pid]
	var moved: Array = []
	way.teleporter = func(pid: String, pos: Dictionary) -> bool:
		moved.append([pid, pos])
		return true
	return { "reg": reg, "stations": stations, "way": way, "now": now, "where": where, "moved": moved }

func _free_waystone_rig(rig: Dictionary) -> void:
	rig["way"].free()
	rig["stations"].free()
	rig["reg"].free()

## A memory transport that stamps a per-type seq, so the emulator (loss, jitter) runs on it.
class _StampingTransport extends MemoryTransport:
	func _init(peer_ids: Array = []) -> void:
		super(peer_ids)
		stamps_seq = true


# ---- Phase 126 — tree clears the host keeps, and one seam-wrap module ----

## A tree slice on a real terrain slice (seed 31), the way a host has it, writing records straight to the table.
func _p126_host_rig() -> Dictionary:
	ChunkRecordsScript.clear()
	var terrain := TerrainSlice.new()
	add_child(terrain)
	terrain.set_world_seed(31)
	var t := _make_tree_slice()
	t.terrain_slice = terrain
	t.record_writer = func(c: Vector2i, rec: Dictionary) -> void:
		ChunkRecordsScript.set_record(c, RegionStoreScript.normalize_gen(rec))
	return { "t": t, "terrain": terrain }

func _p126_free(rig: Dictionary) -> void:
	rig["t"].free()
	rig["terrain"].free()
	ChunkRecordsScript.clear()

## Find a chunk whose frontier biome (beside a recorded neighbour) differs from the plain generator's and
## still grows trees; { "chunk", "plain", "framed" } or {} when none turned up. Only the arid / cold
## biomes have a forbidden neighbour, so the search looks for those and records the opposite beside them.
func _p126_find_transition(t: Node) -> Dictionary:
	var seed_v := int(t.terrain_slice.get_world_seed())
	var opposite := { "Desert": "Tundra", "VolcanicBadlands": "Tundra", "Tundra": "Desert" }
	for r in range(0, 120):
		for z in range(-r, r + 1):
			for x in range(-r, r + 1):
				if maxi(absi(x), absi(z)) != r:
					continue
				var n := Vector2i(x * 3, z * 3)
				var plain: String = TerrainSlice.generated_biome_for_chunk(n, seed_v)
				if not opposite.has(plain):
					continue
				ChunkRecordsScript.clear()
				ChunkRecordsScript.set_record(n + Vector2i(-1, 0), _sync_record(n + Vector2i(-1, 0), str(opposite[plain])))
				var framed: String = Frontier.pick_biome(n, seed_v, Frontier.gather(n))
				if framed != plain and t.tree_count_for(n, framed) > 0 and not t.tree_entry_for_biome(framed).is_empty():
					return { "chunk": n, "plain": plain, "framed": framed }
	ChunkRecordsScript.clear()
	return {}

func _p127_rec(biome := "Desert", h0 := 1.0) -> Dictionary:
	return { "v": TerrainSlice.WORLDGEN_VERSION, "f": 1, "b": biome, "h": [h0, h0, h0, h0] }

func _weather_rig(biome: String = "TemperateForest") -> WeatherSlice:
	var w := WeatherSlice.new()
	w.clock = WorldClock.new()
	w.seed_of = func() -> int: return 424242
	w.biome_of = func(_chunk: Vector2i) -> String: return biome
	add_child(w)
	return w

const StatusEffects := preload("res://src/battle/status_effects.gd")

const STATUS_ROLL_GOLDEN := [10642915, 9902018, 8481431]

const WEATHER_GOLDEN_MIX := 2173728955345170658
const WEATHER_GOLDEN_STATES := ["fog", "clear", "storm", "rain", "clear"]

# ---------------------------------------------------------------------------
# Phase 131 — internationalization
# ---------------------------------------------------------------------------

const P131_PLACEHOLDER := "{"

func _p131_placeholders(text: String) -> Array:
	var out: Array = []
	for i in 8:
		if text.contains("{%d}" % i):
			out.append(i)
	return out

func _p131_scripts() -> Array:
	var out: Array = []
	var stack: Array = ["res://src"]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			if sub != "tests":
				stack.append(dir + "/" + sub)
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				out.append(dir + "/" + f)
	out.sort()
	return out

func _p131_with_settings(fn: Callable) -> void:
	var old_path: String = LocaleSettingsScript.settings_path
	var old_locale := TranslationServer.get_locale()
	LocaleSettingsScript.settings_path = "user://test_settings_p131.json"
	if FileAccess.file_exists(LocaleSettingsScript.settings_path):
		DirAccess.remove_absolute(LocaleSettingsScript.settings_path)
	fn.call()
	if FileAccess.file_exists(LocaleSettingsScript.settings_path):
		DirAccess.remove_absolute(LocaleSettingsScript.settings_path)
	LocaleSettingsScript.settings_path = old_path
	TranslationServer.set_locale(old_locale)

## Phase 131 — host replies are keyed system messages now; older chat tests read them as the
## English lines they used to be by rendering each one into the same callback.
func _p131_system_bridge(cb: Callable) -> Callable:
	var bridge := func(key: String, args: Array, target: String) -> void:
		TranslationServer.set_locale("en")
		cb.call("system", "", I18nScript.t(key, args), target)
	GameBus.system_message.connect(bridge)
	return bridge


func _bus_connection_total() -> int:
	var n := 0
	for s in GameBus.get_signal_list():
		n += GameBus.get_signal_connection_list(s["name"]).size()
	return n

## Phase 133 — `--test-filter=<substring>`: only tests whose registered name contains it run.
## Set by the runner (`test_suite.gd`) before `register()`. Empty runs everything.
var test_filter: String = ""
## Tests that matched the filter and ran, and every test registered (ran or not).
var _ran: int = 0
var _registered: int = 0

## Phase 84 — nothing the suite or the code it drove left parentless. Reads the engine's own
## orphan monitor, so it covers production leaks too (a node created but never parented or freed).
func _assert_no_orphan_nodes() -> void:
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	if orphans != 0:
		Node.print_orphan_nodes()
	assert_eq(orphans, 0, "the suite leaves no orphan nodes")

static func matches_filter(test_name: String, filter: String) -> bool:
	return filter == "" or test_name.to_lower().contains(filter.to_lower())

func _run_test(test_name: String, fn: Callable) -> void:
	_registered_names[str(fn.get_method())] = true
	_registered += 1
	if not matches_filter(test_name, test_filter):
		return
	_ran += 1
	_current_test = test_name
	var fails_before := _fail
	fn.call()
	_free_owned()
	var outcome := "✓" if _fail == fails_before else "✗"
	print("  %s %s" % [outcome, test_name])
