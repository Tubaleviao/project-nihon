extends Node
## Tree slice (Phase 31) — deterministic per-biome trees, the only wood source.
##
## Wood materials (Thornwood / Duskfiber) deliberately do NOT spawn as ground in
## VoxelSlice.BIOME_BIAS (the ore field's biome bias, Phase 43): the fabric's biome prose spawns them as *trees*, so
## this slice is where a player actually gets lumber. Trees are placed
## deterministically inside each loaded chunk — the position and the id derive
## from the chunk coordinate, the species, and an index, so host and client agree
## on both with no snapshot for placement — sit on the terrain surface like
## creatures, and are felled with an axe (`toolType: "axe"`): the wood lands in
## the inventory and the stump regrows after a cooldown.
##
## Only *state* is replicated: chopping is authoritative (a client forwards the
## intent, the host re-runs the chop and broadcasts the result), mirroring the
## voxel-edit path.
##
## Plug contract (GameBus signals consumed / emitted):
##   IN  : tree_chop_requested(tree_id, player_id)         — player intent
##         tree_chopped(tree_id, wood, state, respawn_at)  — host → client state
##         tree_respawned(tree_id)                         — host → client state
##   OUT : tree_chop_requested(tree_id, player_id)         — client → host
##         tree_chopped(tree_id, wood, state, respawn_at)  — host authoritative
##         tree_respawned(tree_id)                         — host authoritative
##         inventory_synced(owner_id, contents, durabilities) — a REMOTE actor's
##           pack after a chop resolved for it (see `_push_inventory`)
##
## Public API:
##   spawn_for_chunk(chunk_pos) / despawn_for_chunk(chunk_pos)   — Phase 17 streaming
##   tree_entry_for_biome(biome) -> Dictionary  ({} when the biome grows no trees)
##   get_tree_record(tree_id) -> Dictionary
##   get_all_trees() / trees_in_chunk(chunk_pos) -> Array
##   chop_tree(tree_id, player_id) -> Dictionary  { success, wood, quantity, reason }
##   apply_chop_state(tree_id, respawn_at) -> void   (client-side host state)
const Diag := preload("res://src/core/diag.gd")

const MultimeshPool := preload("res://src/core/multimesh_pool.gd")
const MeshUtil      := preload("res://src/core/mesh_util.gd")

## Trees own a collision layer (layer 4 / bit 3) so the player's chop aim ray can
## target a trunk without hitting terrain (layer 2) or loot pickups (layer 3).
const TREE_COLLISION_LAYER := 8

## Tree species per biome, transcribed from the fabric biome prose
## (fabric/world/biomes/*.js): the temperate forest prose calls Thornwood "the
## dominant wood source at weight 0.8", the grassland "rare; only isolated copses
## at weight 0.1", and the twilight grove has "Duskwood trees dominate the
## canopy". A biome absent from this table grows no trees — the volcanic
## badlands prose grants no conventional wood. `per_chunk` is the FALLBACK density
## (dominant → 8 trees, isolated copses → 2) used only when no fabric is wired; the
## live density is the biome entity's `treeDensity` (Phase 44), read via `density_for`.
const TREES_BY_BIOME: Dictionary = {
	"TemperateForest":    { "species": "Thornwood", "wood": "Thornwood", "per_chunk": 8 },
	"TemperateGrassland": { "species": "Thornwood", "wood": "Thornwood", "per_chunk": 2 },
	"TwilightGrove":      { "species": "Duskwood",  "wood": "Duskfiber", "per_chunk": 8 },
	"Taiga":              { "species": "Thornwood", "wood": "Thornwood", "per_chunk": 5 },
	"Savanna":            { "species": "Thornwood", "wood": "Thornwood", "per_chunk": 1 },
}

## Biome assumed when no terrain slice is wired (isolated unit tests), mirroring
## CreatureSlice's "no terrain → spawn anyway" test path.
const DEFAULT_BIOME := "TemperateForest"

## Chance a chunk of a tree biome is a clearing with no trees at all, and the amplitude of
## the smooth density noise that thickens and thins the stand across the world (Phase 44).
const CLEARING_CHANCE := 0.1
const DENSITY_NOISE := 0.5

const SpawnRoll := preload("res://src/world/spawn_roll.gd")
const WorldClock := preload("res://src/world/world_clock.gd")
const TerrainSlice := preload("res://src/terrain/terrain_slice.gd")
const ChunkRecords := preload("res://src/terrain/chunk_records.gd")
const RegionStore := preload("res://src/persistence/region_store.gd")

const VoxelScript := preload("res://src/terrain/voxel_slice.gd")
const SeamWrap := preload("res://src/terrain/seam_wrap.gd")
const Frontier := preload("res://src/terrain/frontier.gd")

## Phase 116 — the clear radii are authored on `WorldSystem` (`clearRadiusTiles`, `clearRadiusMetres`);
## these are the fallbacks for a build with no fabric resource.
const FALLBACK_CLEAR_RADIUS_TILES := 1
const FALLBACK_CLEAR_RADIUS_M := 3.0

## Phase 116 — an edit more than this far below a tree's root (a deep mine) does not clear it.
const CLEAR_DEPTH_M := 4.0

## Phase 116 — most spawn indices a CLIENT's `_cleared_local` holds in total; past it the least recently
## touched chunk's entry goes, with one warning (Phase 126). The host never evicts: a clear it cannot pin in
## a record yet waits in `_cleared_local` until the chunk has one.
const CLEARED_LOCAL_CAP := 2048

## Phase 116 — a client keeps a `tree_cleared` only for a chunk within this many chunks of one it has
## loaded; anything farther arrives with the scoped records when the player gets there. Phase 126: this is
## only the fallback before a snapshot names a scope; `set_clear_scope` derives the range from the host's
## `gen_scope` radius.
const CLEAR_ID_RANGE_CHUNKS := 8

## Trunk / canopy proportions of the shared placeholder tree mesh (world units).
const TRUNK_RADIUS  := 0.30
const TRUNK_HEIGHT  := 1.90
const CANOPY_RADIUS := 1.35
const CANOPY_HEIGHT := 1.45
## Trunk collision cylinder — the chop aim target.
const TRUNK_COLLISION_HEIGHT := 2.40

## Wood units one chop yields, and the seconds a stump takes to regrow.
const CHOP_YIELD := 2
const RESPAWN_SECONDS := 120.0

## Instance record: { tree_id, species, wood, position, chunk, state, respawn_at,
## mi, body }. `mi` is an opaque MultiMesh instance index and `body` the trunk's
## StaticBody3D (null headless, or while chopped) — never a rendered Node3D tree.
var _trees: Dictionary = {}

## Phase 49 — chunk -> Array of tree ids, so spawn / despawn / `trees_in_chunk` touch one
## chunk's trees instead of scanning every live tree on each chunk crossing. Kept in step
## with `_trees` by `_spawn` and `despawn_for_chunk`, the only two writers.
var _by_chunk: Dictionary = {}

## Ids of the trees currently in the `stump` state, so `_tick_respawn` walks the (few)
## stumps instead of every live tree each frame. Kept in step by `_set_chopped`,
## `_tick_respawn`, `_spawn` and `despawn_for_chunk`.
var _stumps: Dictionary = {}

## tree_id -> respawn_at (wall-clock Unix seconds) for stumps whose chunk unloaded before
## they regrew. `_spawn` restores the stump instead of a standing tree, so chunk-hopping
## cannot skip the regrowth cooldown. Entries expire the first time the chunk reloads.
var _stump_memory: Dictionary = {}

## Shared MultiMesh pool; null when render_visuals is false (headless server).
var _pool: Node = null
## When false (headless server / `--server`), no pool and no collision bodies are
## built: the same records drive a bare authoritative simulation.
var render_visuals: bool = true

## Phase 110 — read-only edit queries (`has_edit_near`) for a tree standing on already-edited ground.
var voxel_slice: Node = null
## Phase 110 — `(chunk: Vector2i, record: Dictionary) -> void`, set by game_root to
## `ChunkManager.update_record`: how the host persists a record's tree budget `t` and cleared list `x`.
var record_writer: Callable = Callable()
## Cleared spawn indices of chunks with no record to hold them (isolated rigs): chunk -> { index: true }.
## Phase 126 — ordered by recency on a client (a touched chunk moves to the end), so the cap evicts the
## least recently used.
var _cleared_local: Dictionary = {}

## Phase 126 — chunks within this many of a spawned chunk keep a far `tree_cleared`; the host's `gen_scope` radius.
var clear_id_range: int = CLEAR_ID_RANGE_CHUNKS
## Phase 126 — client clears evicted by the cap (the warning is logged once), and whether it has been.
var cleared_evictions: int = 0
var _eviction_warned := false

## Phase 126 — `(chunk: Vector2i) -> bool`, set by game_root: whether the host can pin a record for an
## unrecorded chunk right now (the regions around it are read). Unset, it always can.
var frontier_ready: Callable = Callable()

## Phase 116 — every chunk `spawn_for_chunk` has run for (and `despawn_for_chunk` has not undone), trees
## or not, so a late record resyncs chunks that grew none locally.
var _spawned_chunks: Dictionary = {}
## Phase 126 — `_spawned_chunks` bucketed for `_near_loaded_chunk`: cell -> { chunk: true }, cells `_bucket_size` wide.
var _spawn_buckets: Dictionary = {}
var _bucket_size := 0

## Phase 116 — placed stations (read-only), so a tree on ground a station already covers never spawns.
var station_slice: Node = null

## Set by game_root before the slices enter the tree.
var terrain_slice: Node = null

## Phase 54 — the world clock: a stump regrows faster in its biome's summer and slower in its
## winter (fabric `seasonGrowth`). Null (an isolated rig) leaves the flat RESPAWN_SECONDS.
var world_clock: RefCounted = null
var inventory_slice: Node = null

## Phase 42 review — the registry that owns one inventory PER PLAYER, so a chop the
## host resolves for a REMOTE actor spends and credits THAT player's axe and pack
## instead of this machine's. Optional: an isolated rig (the suite) leaves it null and
## every player id falls back to `inventory_slice` (see `inventory_for`).
var player_registry: Node = null

## Authority mode (Phase 18). When true (host / single-player) this slice resolves
## chops and regrowth; when false (client) it forwards the chop intent and applies
## the host's authoritative tree state.
var is_authoritative: bool = true

func _ready() -> void:
	GameBus.tree_chop_requested.connect(_on_chop_requested)
	GameBus.tree_chopped.connect(_on_tree_chopped)
	GameBus.tree_respawned.connect(_on_tree_respawned)
	GameBus.tree_cleared.connect(_on_tree_cleared)
	GameBus.block_edit_resolved.connect(_on_block_edit_resolved)
	GameBus.station_placed.connect(_on_station_placed)
	if render_visuals:
		_build_pool()

func _process(_delta: float) -> void:
	if not is_authoritative:
		return   # a client never regrows trees locally — the host owns the clock
	_tick_respawn()

# ---------------------------------------------------------------------------
# Streaming (Phase 17)
# ---------------------------------------------------------------------------

## Spawn the per-chunk tree budget for this chunk's biome. Positions, species,
## and ids are deterministic, so a reload restores the same trees; surviving trees
## are counted first so a chunk reload never exceeds the budget.
func spawn_for_chunk(chunk_pos: Vector2i) -> void:
	if not _spawned_chunks.has(chunk_pos):
		_spawned_chunks[chunk_pos] = true
		_bucket_add(chunk_pos)
	var biome := _chunk_biome(chunk_pos)
	var entry := tree_entry_for_biome(biome)
	if entry.is_empty():
		return
	var budget: int = _budget_for(chunk_pos, biome)
	_adopt_local_clears(chunk_pos)
	var cleared := cleared_indices(chunk_pos)
	# Reconcile by id, not by count: a shrunken budget (a density change between visits)
	# drops the surplus trees, and a gap in the 0..budget-1 ids is refilled.
	_trim_chunk_to(chunk_pos, budget, cleared)
	# One lookup per chunk rules the edited-ground check out for every tree in it (Phase 116).
	var stations := _stations_near_chunk(chunk_pos) if is_authoritative else []
	var check_ground := is_authoritative and (not stations.is_empty() or _chunk_has_edits(chunk_pos))
	for i in budget:
		if cleared.has(i) or _trees.has(_tree_id(chunk_pos, i)):
			continue
		var tid := _spawn(str(entry["species"]), str(entry["wood"]), chunk_pos, i)
		# A tree standing on ground players already edited never grew back there.
		if check_ground and _on_edited_ground(_trees[tid], stations):
			_clear_tree(tid)

## Phase 110 — the tree budget of a chunk: the one its record holds (`t`) so a later density change
## adds or drops nothing in recorded land, else the current generator's. The host stamps a record that
## has none yet with the budget it is about to spawn.
func _budget_for(chunk_pos: Vector2i, biome: String) -> int:
	var canon := TerrainSlice.wrap_chunk(chunk_pos)
	var rec := ChunkRecords.get_record(canon)
	if rec.has("t"):
		return int(rec["t"])
	# Capped at the record's range, so every spawn index below the budget is one a record can persist.
	var budget: int = clampi(tree_count_for(chunk_pos, biome), 0, RegionStore.GEN_TREE_MAX)
	if is_authoritative and not rec.is_empty() and record_writer.is_valid():
		var next := rec.duplicate(true)
		next["t"] = budget
		record_writer.call(canon, next)
	return budget

## Spawn indices cleared for good in `chunk_pos`: { index: true }.
func cleared_indices(chunk_pos: Vector2i) -> Dictionary:
	var out: Dictionary = {}
	var canon := TerrainSlice.wrap_chunk(chunk_pos)
	for i in ChunkRecords.get_record(canon).get("x", []):
		out[int(i)] = true
	for i in _cleared_local.get(canon, {}):
		out[int(i)] = true
	return out

## Phase 116 — clears held only locally (the chunk had no record when they happened) move into the
## record once one exists, so they persist and ride the sync. Phase 126: on a client too, so the local
## entry is released the moment the host's record for the chunk is in (and carries the clear).
func _adopt_local_clears(chunk_pos: Vector2i) -> void:
	var canon := TerrainSlice.wrap_chunk(chunk_pos)
	if not _cleared_local.has(canon) or not record_writer.is_valid():
		return
	var rec := ChunkRecords.get_record(canon)
	if rec.is_empty():
		return
	var next := rec.duplicate(true)
	var xs: Array = next.get("x", [])
	for i in _cleared_local[canon]:
		if not xs.has(int(i)):
			xs.append(int(i))
	next["x"] = xs
	record_writer.call(canon, next)
	_cleared_local.erase(canon)

## Placed stations whose clear circle can reach a tree of `chunk_pos` (seam-wrapped), as station dicts.
func _stations_near_chunk(chunk_pos: Vector2i) -> Array:
	var out: Array = []
	if station_slice == null or not station_slice.has_method("get_all_stations"):
		return out
	var span := float(_chunk_size()) * _tile_size()
	var half := span * 0.5
	var cx := (float(chunk_pos.x) + 0.5) * span
	var cz := (float(chunk_pos.y) + 0.5) * span
	var radius := clear_radius_m()
	var wm := _lap_metres()
	for st in station_slice.get_all_stations():
		var sp: Vector3 = st["position"]
		if absf(SeamWrap.delta_f(cx, sp.x, wm)) <= half + radius and absf(cz - sp.z) <= half + radius:
			out.append(st)
	return out

## True when voxel edits may sit within clear range of a tree in `chunk_pos`.
func _chunk_has_edits(chunk_pos: Vector2i) -> bool:
	return voxel_slice != null and voxel_slice.has_method("has_edits_near_chunk") \
		and voxel_slice.has_edits_near_chunk(chunk_pos, clear_radius_tiles())

## Re-run `spawn_for_chunk` over every chunk holding trees (a client whose records arrived after
## its trees spawned): applies the recorded budget and the cleared list.
func resync_recorded_chunks() -> void:
	for chunk in _spawned_chunks.keys():
		spawn_for_chunk(chunk)

## Remove every tree belonging to `chunk_pos`, freeing its visual instance and
## trunk collision. Trees carry no combat state, so unlike creatures none are
## kept alive across a despawn.
func despawn_for_chunk(chunk_pos: Vector2i) -> void:
	# Take the index entry out first so nothing reached from the loop can see (or append
	# to) the array being walked.
	var ids: Array = _by_chunk.get(chunk_pos, []) as Array
	_by_chunk.erase(chunk_pos)
	_spawned_chunks.erase(chunk_pos)
	_bucket_remove(chunk_pos)
	# Phase 126 — a client keeps an unrecorded clear after the chunk unloads (no ghost tree on return); it
	# goes once the host's record for the chunk arrives or the scope moves away (`set_clear_scope`).
	for tid in ids:
		_remove_tree(str(tid), true)

## Drop this chunk's trees whose spawn index is >= `budget` or cleared.
func _trim_chunk_to(chunk_pos: Vector2i, budget: int, cleared: Dictionary = {}) -> void:
	var ids: Array = (_by_chunk.get(chunk_pos, []) as Array).duplicate()
	var keep: Dictionary = {}
	for i in budget:
		if not cleared.has(i):
			keep[_tree_id(chunk_pos, i)] = true
	for tid in ids:
		if keep.has(tid):
			continue
		_remove_clear(str(tid), chunk_pos)

## Free one tree's visual, collision and bookkeeping. `remember` keeps a stump's regrowth
## deadline across the unload (see `_stump_memory`); a trimmed tree is gone for good.
func _remove_tree(tree_id: String, remember: bool) -> void:
	var tree: Dictionary = _trees.get(tree_id, {})
	if tree.is_empty():
		return
	if remember and tree["state"] == "stump" and float(tree["respawn_at"]) > 0.0:
		_stump_memory[tree_id] = float(tree["respawn_at"])
	if _pool != null and int(tree["mi"]) >= 0:
		_pool.release(int(tree["mi"]))
	_free_collision(tree)
	_stumps.erase(tree_id)
	_trees.erase(tree_id)

## True when `_by_chunk`, `_trees` and `_stumps` agree: every indexed id is a live record
## filed under its own chunk, every record is indexed once, every stump is tracked.
func index_is_consistent() -> bool:
	var indexed := 0
	for chunk in _by_chunk:
		for tid in _by_chunk[chunk]:
			indexed += 1
			if not _trees.has(tid) or _trees[tid]["chunk"] != chunk:
				return false
	if indexed != _trees.size():
		return false
	for tid in _trees:
		if (_trees[tid]["state"] == "stump") != _stumps.has(tid):
			return false
	return true

## Mean trees per chunk for a biome: the fabric `treeDensity` when the biome resource is
## loaded, else the `TREES_BY_BIOME` fallback (isolated tests with no fabric wired).
func density_for(biome: String) -> int:
	var entry := tree_entry_for_biome(biome)
	if entry.is_empty():
		return 0
	var b: Variant = GameData.BIOMES.get(biome if biome != "" else DEFAULT_BIOME, null)
	if b != null and b.get("treeDensity") != null:
		return int(b.get("treeDensity"))
	return int(entry["per_chunk"])

## Trees this chunk grows: a seeded clearing roll, then the biome density scaled by the
## smooth density noise. Pure in (world seed, chunk, biome) so host and client agree.
## With no terrain slice wired (biome "") the flat density applies — no world, no roll.
func tree_count_for(chunk_pos: Vector2i, biome: String) -> int:
	var mean: int = density_for(biome)
	if mean <= 0 or biome == "":
		return maxi(mean, 0)
	var seed_v: int = 0
	if terrain_slice != null and terrain_slice.has_method("get_world_seed"):
		seed_v = int(terrain_slice.get_world_seed())
	return SpawnRoll.pack_size(seed_v, chunk_pos, "trees", mean, 1.0 - CLEARING_CHANCE, DENSITY_NOISE)

## Tree entry for a biome, or {} when that biome grows no trees. An empty biome
## (no terrain slice wired — isolated tests) falls back to the default entry.
func tree_entry_for_biome(biome: String) -> Dictionary:
	if biome == "":
		biome = DEFAULT_BIOME
	var entry: Variant = TREES_BY_BIOME.get(biome, null)
	if entry == null:
		return {}
	return (entry as Dictionary).duplicate(true)

# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------

## A deep copy of one tree record, or {} when the id is unknown.
## Named `get_tree_record` — `get_tree()` is a `Node` virtual (SceneTree) and
## overriding it is a parse error.
func get_tree_record(tree_id: String) -> Dictionary:
	var tree: Variant = _trees.get(tree_id, null)
	if tree == null:
		return {}
	return (tree as Dictionary).duplicate(true)

## Snapshot of every tree, for tests and introspection.
func get_all_trees() -> Array:
	var out: Array = []
	for tid in _trees:
		out.append(get_tree_record(str(tid)))
	return out

## Ids of the trees in one chunk.
func trees_in_chunk(chunk_pos: Vector2i) -> Array:
	var out: Array = []
	for tid in _by_chunk.get(chunk_pos, []):
		out.append(str(tid))
	return out

# ---------------------------------------------------------------------------
# Chopping
# ---------------------------------------------------------------------------

## Fell a standing tree. Requires a held axe (`toolType: "axe"` from the fabric),
## spends one point of its durability per chop, yields the tree's wood into the
## inventory, and leaves a stump that regrows after RESPAWN_SECONDS. On a client
## the intent is forwarded and the host's authoritative state is applied instead.
## Returns { success, wood, quantity, reason }; reason is "" on success.
##
## Phase 42 review — `player_id` names the actor whose axe wears and whose pack
## receives the wood: `""` is this machine's own player, and the host re-emits a
## client's intent with the identity bound to its connection (see `inventory_for`).
## Every check and mutation below went through this slice's own `inventory_slice`
## before, which is why a client's chop filled the HOST's pack while the client —
## mirroring only its own pack — saw nothing.
func chop_tree(tree_id: String, player_id: String = "") -> Dictionary:
	if not is_authoritative:
		GameBus.tree_chop_requested.emit(tree_id, player_id)
		return { "success": false, "wood": "", "quantity": 0, "reason": "forwarded" }
	if not _trees.has(tree_id):
		return _fail("no_tree")
	var tree: Dictionary = _trees[tree_id]
	if tree["state"] != "standing":
		return _fail("not_standing")
	var inventory := inventory_for(player_id)
	var axe := _held_axe(inventory)
	if axe == "":
		return _fail("axe_required")
	var wood: String = str(tree["wood"])
	# Refuse before spending durability so a full inventory never costs the axe.
	if inventory != null and inventory.has_method("can_add_items"):
		if not inventory.can_add_items({ wood: CHOP_YIELD }):
			return _fail("no_inventory")
	# Spend the axe's wear BEFORE the tree changes state, so a broken axe can
	# never fell a tree for free (the ordering mine_block uses for the pick).
	if inventory != null and inventory.has_method("use_item"):
		if not inventory.use_item(axe, "chop"):
			return _fail("axe_broken")
	if inventory != null and inventory.has_method("add_item"):
		if not inventory.add_item(wood, CHOP_YIELD):
			return _fail("no_inventory")
	_push_inventory(player_id)
	_set_chopped(tree_id)
	return { "success": true, "wood": wood, "quantity": CHOP_YIELD, "reason": "" }

## The inventory a chop by `player_id` resolves against: that player's own pack from
## the registry when one is wired, else this slice's (`""` = this machine's own
## player). The same resolve shape `CraftingSlice.inventory_for` uses (see
## `VoxelSlice.inventory_for` for the full reasoning).
func inventory_for(player_id: String) -> Node:
	if player_id != "" and player_registry != null and player_registry.has_method("get_inventory"):
		var inv: Node = player_registry.get_inventory(player_id)
		if inv != null:
			return inv
	return inventory_slice

## Is `player_id` a player whose own client mirrors this inventory over the wire?
## False for `""` (this machine's own player) and for the local id, whose pack is live
## in this process — the same test `PeerWiring._sync_peer_own_state` makes.
func _is_remote_actor(player_id: String) -> bool:
	if player_id == "":
		return false
	if player_registry != null and "local_player_id" in player_registry:
		return player_id != str(player_registry.local_player_id)
	return true

## Phase 42 review — a chop the host resolved for a REMOTE actor changed that player's
## pack, which lives here (the registry's copy) but is mirrored by the peer's own client.
## Without this the peer keeps rendering its pre-chop inventory until the next snapshot.
## Addressed to its owner (Phase 37), so networking delivers it to that peer ALONE (the
## mechanism the net harness's `inventory_owner` step pins).
func _push_inventory(player_id: String) -> void:
	if not _is_remote_actor(player_id):
		return
	var inv := inventory_for(player_id)
	if inv == null or not inv.has_method("get_contents"):
		return
	GameBus.inventory_synced.emit(player_id, inv.get_contents(), inv.get_durability_data())

## Apply a host-authoritative chopped state to a local tree (client path). The
## regrowth deadline arrives as a wall-clock Unix second so it stays meaningful
## across a restart, matching the Phase 24 market/proposal convention.
func apply_chop_state(tree_id: String, respawn_at: float) -> void:
	if not _trees.has(tree_id):
		return
	var tree: Dictionary = _trees[tree_id]
	if tree["state"] != "standing":
		return
	tree["respawn_at"] = respawn_at
	_set_chopped(tree_id)

# ---------------------------------------------------------------------------
# Phase 110 — building clears trees for good
# ---------------------------------------------------------------------------

## Tiles (Chebyshev) around a built-on tile within which trees are cleared: `WorldSystem.clearRadiusTiles`.
static func clear_radius_tiles() -> int:
	var ws: Variant = GameData.WORLD_SYSTEMS.get("WorldSystem", null)
	if ws != null and ws.get("clearRadiusTiles") != null:
		return maxi(int(ws.get("clearRadiusTiles")), 0)
	return FALLBACK_CLEAR_RADIUS_TILES

## Metres around a placed station within which trees are cleared: `WorldSystem.clearRadiusMetres`.
static func clear_radius_m() -> float:
	var ws: Variant = GameData.WORLD_SYSTEMS.get("WorldSystem", null)
	if ws != null and ws.get("clearRadiusMetres") != null:
		return maxf(float(ws.get("clearRadiusMetres")), 0.0)
	return FALLBACK_CLEAR_RADIUS_M

## Phase 126 — true when an edit at `edit_y` is deep enough below a tree rooted at `root_y` to leave it
## alone. The one `CLEAR_DEPTH_M` rule, shared by `clear_trees_near_tile` and `_on_edited_ground`.
static func _too_deep(edit_y: float, root_y: float) -> bool:
	return edit_y < root_y - CLEAR_DEPTH_M

## Clear every standing-or-stump tree within `clear_radius_tiles()` tiles of `tile` (seam-wrapped).
## An edit at `edit_y` more than `CLEAR_DEPTH_M` below a tree's root leaves it alone. Host only.
## Returns how many were cleared.
func clear_trees_near_tile(tile: Vector2i, edit_y: float = INF) -> int:
	if not is_authoritative:
		return 0
	var radius := clear_radius_tiles()
	var wt := _lap_tiles()
	var canon := VoxelScript.canonical_tile(tile)
	var centre := _chunk_of_tile(tile)
	@warning_ignore("integer_division")
	var reach := 1 + radius / maxi(_chunk_size(), 1)
	return _clear_where(_lap_keys(centre, reach), func(tree: Dictionary) -> bool:
		if _too_deep(edit_y, float(tree["position"].y)):
			return false
		var t: Vector2i = tree["tile"]
		return maxi(absi(SeamWrap.delta(t.x, canon.x, wt)), absi(t.y - canon.y)) <= radius)

## Clear every tree within `clear_radius_m()` metres (horizontal, seam-wrapped) of `pos`. Host only.
## Trees of a neighbouring chunk that is not loaded yet are recorded as cleared in that chunk's record.
func clear_trees_near_point(pos: Vector3) -> int:
	if not is_authoritative:
		return 0
	var radius := clear_radius_m()
	var wm := _lap_metres()
	var p := Vector2(pos.x, pos.z)
	var centre := _chunk_of_tile(Vector2i(floori(pos.x / _tile_size()), floori(pos.z / _tile_size())))
	var reach: int = maxi(1, int(ceil(radius / (float(_chunk_size()) * _tile_size()))))
	var keys := _lap_keys(centre, reach)   # resolved once for the loaded and the unloaded pass
	var count := _clear_where(keys, func(tree: Dictionary) -> bool:
		var tp: Vector3 = tree["position"]
		return Vector2(SeamWrap.delta_f(tp.x, p.x, wm), tp.z - p.y).length() <= radius)
	# A neighbour that is not loaded has no trees to look at: clear by the spawn positions it would get.
	for canon in keys:
		if (keys[canon] as Array).is_empty():
			count += _clear_unloaded_chunk(canon, p, radius, wm)
	return count

## Phase 126 — for each chunk within `reach` of `centre`: canonical chunk -> the keys (raw chunk or either
## lap of the seam) this slice has it filed or spawned under. Empty = not loaded. One resolution per edit.
func _lap_keys(centre: Vector2i, reach: int) -> Dictionary:
	var out: Dictionary = {}
	var circ := TerrainSlice.circumference_chunks()
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var canon := TerrainSlice.wrap_chunk(Vector2i(centre.x + dx, centre.y + dz))
			if out.has(canon):
				continue
			var found: Array = []
			for lap in [0, -circ, circ]:
				var key := Vector2i(canon.x + lap, canon.y)
				if _by_chunk.has(key) or _spawned_chunks.has(key):
					found.append(key)
			out[canon] = found
	return out

## The trees of the chunks in `keys` (`_lap_keys`) that `matches`, cleared. One loop for tile and point clears.
func _clear_where(keys: Dictionary, matches: Callable) -> int:
	var hit: Array = []
	for canon in keys:
		for key in keys[canon]:
			if not _by_chunk.has(key):
				continue
			for tid in _by_chunk[key]:
				if matches.call(_trees[tid]):
					hit.append(tid)
	for tid in hit:
		_clear_tree(str(tid))
	return hit.size()

## Record (and announce) the trees of an unloaded `chunk` that lie within `radius` of `p`. Needs the
## chunk's biome and budget, so it does nothing where the chunk grows no trees.
func _clear_unloaded_chunk(chunk: Vector2i, p: Vector2, radius: float, wm: float) -> int:
	chunk = TerrainSlice.wrap_chunk(chunk)   # the caller (`_lap_keys`) has ruled out a loaded chunk
	var span := float(_chunk_size()) * _tile_size()
	var half := span * 0.5
	var gap := Vector2(maxf(absf(SeamWrap.delta_f((float(chunk.x) + 0.5) * span, p.x, wm)) - half, 0.0),
		maxf(absf((float(chunk.y) + 0.5) * span - p.y) - half, 0.0))
	if gap.length() > radius:
		return 0   # the circle never reaches this chunk
	# Phase 126 — the chunk is recorded the way `Frontier` will record it (its biome and budget), BEFORE the
	# indices are chosen, so they name the trees the chunk will really grow beside recorded land.
	if not ChunkRecords.has_record(chunk) and not _pin_frontier_record(chunk) and is_authoritative \
			and frontier_ready.is_valid():
		# Its neighbouring regions are unread, so the plain generator's biome and budget may not be what
		# `Frontier` records. Choosing indices now could name other trees later; a reload of the chunk
		# re-checks the stations and edits around it (`_stations_near_chunk`, `has_edit_near`) instead.
		return 0
	var biome := _chunk_biome(chunk)
	var entry := tree_entry_for_biome(biome)
	if entry.is_empty():
		return 0
	var budget: int = _budget_for(chunk, biome)
	var cleared := cleared_indices(chunk)
	var n := 0
	for i in budget:
		if cleared.has(i):
			continue
		var xz := _deterministic_chunk_position(chunk, str(entry["species"]), i)
		if Vector2(SeamWrap.delta_f(xz.x, p.x, wm), xz.y - p.y).length() > radius:
			continue
		_record_cleared(chunk, i)
		GameBus.tree_cleared.emit(_tree_id(chunk, i))
		n += 1
	return n

## `stations` is the candidate list (`_stations_near_chunk`); omitted, every placed station is checked.
## Phase 126 — ground edited more than `CLEAR_DEPTH_M` below the tree's root (a deep mine) does not count,
## the same rule `clear_trees_near_tile` applies, so a reload keeps the tree the live edit kept.
func _on_edited_ground(tree: Dictionary, stations: Variant = null) -> bool:
	if stations == null and station_slice != null and station_slice.has_method("get_all_stations"):
		stations = station_slice.get_all_stations()
	if stations != null:
		var tp: Vector3 = tree["position"]
		var radius := clear_radius_m()
		var wm := _lap_metres()
		for st in stations:
			var sp: Vector3 = st["position"]
			if Vector2(SeamWrap.delta_f(tp.x, sp.x, wm), tp.z - sp.z).length() <= radius:
				return true
	if voxel_slice == null or not voxel_slice.has_method("has_edit_near"):
		return false
	var root_y := float((tree["position"] as Vector3).y)
	if voxel_slice.has_method("has_edit_near_at"):
		return voxel_slice.has_edit_near_at(tree["tile"], clear_radius_tiles(), root_y - CLEAR_DEPTH_M)
	return voxel_slice.has_edit_near(tree["tile"], clear_radius_tiles())

## Chunk containing `tile` (tile units, floor division).
func _chunk_of_tile(tile: Vector2i) -> Vector2i:
	var cs := maxi(_chunk_size(), 1)
	return Vector2i(floori(float(tile.x) / cs), floori(float(tile.y) / cs))

## Tiles / metres in one lap of the world (the seam arithmetic itself lives in `SeamWrap`).
func _lap_tiles() -> int:
	return SeamWrap.world_tiles(TerrainSlice.circumference_chunks(), _chunk_size())

func _lap_metres() -> float:
	return SeamWrap.world_metres(TerrainSlice.circumference_chunks(), _chunk_size(), _tile_size())

## Remove one tree for good: record its spawn index in `x`, free its visual and collision, and tell
## clients. A stump's regrowth deadline is dropped with it.
func _clear_tree(tree_id: String) -> void:
	var tree: Dictionary = _trees.get(tree_id, {})
	if tree.is_empty():
		return
	var chunk: Vector2i = tree["chunk"]
	var index: int = int(tree["index"])
	_record_cleared(chunk, index)
	_remove_clear(tree_id, chunk)
	GameBus.tree_cleared.emit(tree_id)

func _remove_clear(tree_id: String, chunk: Vector2i) -> void:
	if _by_chunk.has(chunk):
		(_by_chunk[chunk] as Array).erase(tree_id)
		if (_by_chunk[chunk] as Array).is_empty():
			_by_chunk.erase(chunk)
	_stump_memory.erase(tree_id)
	_remove_tree(tree_id, false)

func _record_cleared(chunk: Vector2i, index: int) -> void:
	if index < 0 or index >= RegionStore.GEN_TREE_MAX:
		return
	var canon := TerrainSlice.wrap_chunk(chunk)
	if is_authoritative and not ChunkRecords.has_record(canon):
		_pin_frontier_record(canon)
	var rec := ChunkRecords.get_record(canon)
	if not rec.is_empty() and record_writer.is_valid():
		var next := rec.duplicate(true)
		var xs: Array = next.get("x", [])
		if not xs.has(index):
			xs.append(index)
			next["x"] = xs
			record_writer.call(canon, next)
		return
	# No record to pin it in (yet): hold it locally, keyed by the canonical chunk. The host keeps all of
	# them until the chunk has a record; a client's are capped by recency.
	var held: Dictionary = _cleared_local.get(canon, {})
	_cleared_local.erase(canon)   # re-inserted last: the most recently touched chunk
	held[index] = true
	_cleared_local[canon] = held
	if not is_authoritative:
		_evict_cleared_local(canon)

## Phase 126 — an unrecorded chunk a clear lands in gets the record `Frontier` gives it (so its biome,
## and with it the tree budget the cleared indices refer to, are what the chunk will be loaded with),
## stamped with the budget. Host only; does nothing while the regions around the chunk are unread.
## Returns true when the chunk has a record afterwards.
func _pin_frontier_record(canon: Vector2i) -> bool:
	if ChunkRecords.has_record(canon):
		return true
	if not record_writer.is_valid() or terrain_slice == null or not terrain_slice.has_method("get_world_seed"):
		return false
	if frontier_ready.is_valid() and not bool(frontier_ready.call(canon)):
		return false
	var rec := RegionStore.normalize_gen(Frontier.record_for(canon, int(terrain_slice.get_world_seed())))
	if rec.is_empty():
		return false
	rec["t"] = clampi(tree_count_for(canon, str(rec["b"])), 0, RegionStore.GEN_TREE_MAX)
	record_writer.call(canon, rec)
	return ChunkRecords.has_record(canon)

## A client's cap: the least recently touched chunk's clears go first, with one warning.
func _evict_cleared_local(keep: Vector2i) -> void:
	var total := 0
	for c in _cleared_local:
		total += (_cleared_local[c] as Dictionary).size()
	while total > CLEARED_LOCAL_CAP and _cleared_local.size() > 1:
		var oldest: Vector2i = _cleared_local.keys()[0]
		if oldest == keep:
			oldest = _cleared_local.keys()[1]
		total -= (_cleared_local[oldest] as Dictionary).size()
		_cleared_local.erase(oldest)
		cleared_evictions += 1
		if not _eviction_warned:
			_eviction_warned = true
			Diag.warn("TreeSlice: client clear cap (%d) reached; the least recently used chunk's unrecorded clears were dropped" % CLEARED_LOCAL_CAP)

## Phase 126 — the host's `gen_scope` `[cx, cz, radius]`: the clear range is its radius, and unrecorded
## client clears of chunks outside it are released (the host re-delivers anything it recorded on return).
func set_clear_scope(scope: Variant) -> void:
	if not (scope is Array) or (scope as Array).size() < 3:
		return
	for v in scope:
		if not (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT) or not is_finite(float(v)):
			return
	var radius := int(scope[2])
	if radius < 0:
		return
	clear_id_range = radius
	if is_authoritative:
		return
	var circ := TerrainSlice.circumference_chunks()
	for c in _cleared_local.keys():
		var d := Vector2i(SeamWrap.delta(c.x, int(scope[0]), circ), c.y - int(scope[1]))
		if maxi(absi(d.x), absi(d.y)) > radius:
			_cleared_local.erase(c)

## Phase 126 — the tile `VoxelSlice._resolve_edit_tile` resolved (from the exact record when the caller had
## one) arrives with the edit, so a far-from-origin edit clears the tree on the tile it really touched.
func _on_block_edit_resolved(tile: Vector2i, edit_y: float) -> void:
	if not is_authoritative:
		return
	clear_trees_near_tile(tile, edit_y)

func _on_station_placed(_station_id: String, _type: String, position: Vector3) -> void:
	clear_trees_near_point(position)

## Client side: the host cleared this tree; drop it (an unknown id is ignored).
func _on_tree_cleared(tree_id: String) -> void:
	if is_authoritative:
		return
	var tree: Dictionary = _trees.get(tree_id, {})
	if tree.is_empty():
		# Not loaded here: remember it if its chunk is near the loaded ones, or it regrows on arrival.
		# One farther out arrives with the scoped records when the player gets there.
		var parts := tree_id.split("_")
		if parts.size() == 4 and parts[0] == "tree" and parts[1].is_valid_int() \
				and parts[2].is_valid_int() and parts[3].is_valid_int():
			var chunk := Vector2i(int(parts[1]), int(parts[2]))
			if _near_loaded_chunk(chunk):
				_record_cleared(chunk, int(parts[3]))
		return
	# Remember it: records reach a client with the snapshot only, so a reload of the chunk must not regrow it.
	_record_cleared(tree["chunk"], int(tree["index"]))
	_remove_clear(tree_id, tree["chunk"])

## True when `chunk` is within `CLEAR_ID_RANGE_CHUNKS` (seam-wrapped) of a chunk this slice has spawned.
## Phase 126 — answered from a bucket index of the spawned chunks (cells `clear_id_range` wide), so a far
## `tree_cleared` looks at nine cells, not every spawned chunk.
func _near_loaded_chunk(chunk: Vector2i) -> bool:
	var b := maxi(clear_id_range, 1)
	if _bucket_size != b:
		_rebuild_spawn_buckets(b)
	var circ := TerrainSlice.circumference_chunks()
	# Every cell any chunk within range can sit in: X is probed per chunk column (the seam may split the
	# range at a cell edge), Z by cell.
	var xs: Dictionary = {}
	for dx in range(-clear_id_range, clear_id_range + 1):
		xs[_bucket_key(Vector2i(chunk.x + dx, chunk.y), b).x] = true
	var seen: Dictionary = {}
	for kx in xs:
		for oz in range(-1, 2):
			var key := Vector2i(kx, _bucket_key(Vector2i(chunk.x, chunk.y + oz * b), b).y)
			if seen.has(key) or not _spawn_buckets.has(key):
				continue
			seen[key] = true
			for c in _spawn_buckets[key]:
				var dx := absi(SeamWrap.delta(chunk.x, (c as Vector2i).x, circ))
				if maxi(dx, absi(chunk.y - (c as Vector2i).y)) <= clear_id_range:
					return true
	return false

## Bucket cell of a chunk: its canonical X and Z divided by the cell size.
static func _bucket_key(chunk: Vector2i, b: int) -> Vector2i:
	var canon := TerrainSlice.wrap_chunk(chunk)
	return Vector2i(floori(float(canon.x) / b), floori(float(canon.y) / b))

func _rebuild_spawn_buckets(b: int) -> void:
	_bucket_size = b
	_spawn_buckets.clear()
	for c in _spawned_chunks:
		_bucket_add(c)

func _bucket_add(chunk: Vector2i) -> void:
	if _bucket_size <= 0:
		return
	var key := _bucket_key(chunk, _bucket_size)
	if not _spawn_buckets.has(key):
		_spawn_buckets[key] = {}
	_spawn_buckets[key][chunk] = true

func _bucket_remove(chunk: Vector2i) -> void:
	if _bucket_size <= 0:
		return
	var key := _bucket_key(chunk, _bucket_size)
	if _spawn_buckets.has(key):
		_spawn_buckets[key].erase(chunk)
		if (_spawn_buckets[key] as Dictionary).is_empty():
			_spawn_buckets.erase(key)

# ---------------------------------------------------------------------------
# Private — chopping / regrowth
# ---------------------------------------------------------------------------

## Seconds a stump in `chunk` takes to regrow right now: RESPAWN_SECONDS divided by the
## season's growth multiplier for the chunk's biome and latitude (Phase 54).
func regrow_seconds(chunk_pos: Vector2i) -> float:
	if world_clock == null:
		return RESPAWN_SECONDS
	var biome: Variant = GameData.BIOMES.get(_chunk_biome(chunk_pos), null)
	var w: float = world_clock.warmth_at(TerrainSlice.latitude_of(chunk_pos.y))
	return RESPAWN_SECONDS / WorldClock.growth_multiplier(biome, w)

func _set_chopped(tree_id: String) -> void:
	var tree: Dictionary = _trees.get(tree_id, {})
	if tree.is_empty() or tree["state"] != "standing":
		return
	tree["state"] = "stump"
	if float(tree["respawn_at"]) <= 0.0:
		tree["respawn_at"] = _now() + regrow_seconds(tree["chunk"])
	_free_collision(tree)
	_stumps[tree_id] = true
	if _pool != null and int(tree["mi"]) >= 0:
		# Squat, dark stump shape (the shared mesh is truncated, not swapped).
		_pool.set_color(int(tree["mi"]), _stump_color())
		_pool.set_transform(int(tree["mi"]), _stump_transform(tree["position"]))
	GameBus.tree_chopped.emit(tree_id, str(tree["wood"]), "stump", float(tree["respawn_at"]))

func _tick_respawn() -> void:
	if _stumps.is_empty():
		return
	var now := _now()
	for tid in _stumps.keys():
		var tree: Dictionary = _trees[tid]
		if float(tree["respawn_at"]) <= 0.0 or now < float(tree["respawn_at"]):
			continue
		_regrow(str(tid))

## Stump -> standing: restore collision, visual and the regrowth bookkeeping.
func _regrow(tree_id: String) -> void:
	var tree: Dictionary = _trees[tree_id]
	tree["state"] = "standing"
	tree["respawn_at"] = -1.0
	_stumps.erase(tree_id)
	if render_visuals:
		tree["body"] = _build_collision(tree_id, tree["position"], str(tree["species"]))
	if _pool != null and int(tree["mi"]) >= 0:
		_pool.set_color(int(tree["mi"]), _species_color(str(tree["species"])))
		_pool.set_transform(int(tree["mi"]), _visual_transform(tree["position"]))
	GameBus.tree_respawned.emit(tree_id)

## The held axe's item id, or "" when `inventory` holds none. Delegates to the
## inventory's fabric-driven tool lookup ("axe" → CarpenterAxe today).
func _held_axe(inventory: Node) -> String:
	if inventory == null or not inventory.has_method("find_tool"):
		return ""
	return str(inventory.find_tool("axe"))

## Wall-clock seconds since the Unix epoch. NOT `Time.get_ticks_msec()` — that is
## process uptime, which makes a saved regrowth deadline meaningless after a
## restart (the same rule the Phase 24 market deadlines follow).
func _now() -> float:
	return Time.get_unix_time_from_system()

func _fail(reason: String) -> Dictionary:
	Diag.warn("[Tree] chop FAILED — %s" % reason)
	return { "success": false, "wood": "", "quantity": 0, "reason": reason }

func _on_chop_requested(tree_id: String, player_id: String) -> void:
	if is_authoritative:
		chop_tree(tree_id, player_id)

func _on_tree_chopped(tree_id: String, _wood: String, _state: String, respawn_at: float) -> void:
	if is_authoritative:
		return   # the host already applied its own chop
	apply_chop_state(tree_id, respawn_at)

func _on_tree_respawned(tree_id: String) -> void:
	if is_authoritative:
		return
	if not _trees.has(tree_id):
		return
	var tree: Dictionary = _trees[tree_id]
	if tree["state"] != "stump":
		return
	tree["state"] = "standing"
	tree["respawn_at"] = -1.0
	if render_visuals:
		tree["body"] = _build_collision(tree_id, tree["position"], str(tree["species"]))
	if _pool != null and int(tree["mi"]) >= 0:
		_pool.set_color(int(tree["mi"]), _species_color(str(tree["species"])))
		_pool.set_transform(int(tree["mi"]), _visual_transform(tree["position"]))

# ---------------------------------------------------------------------------
# Spawning / visuals
# ---------------------------------------------------------------------------

func _spawn(species: String, wood: String, chunk_pos: Vector2i, spawn_index: int) -> String:
	var xz := _deterministic_chunk_position(chunk_pos, species, spawn_index)
	var pos := Vector3(xz.x, 0.0, xz.y)
	# Stand the tree on the terrain surface instead of a fixed height.
	if terrain_slice != null and terrain_slice.has_method("get_height_at"):
		pos.y = terrain_slice.get_height_at(Vector2(xz.x, xz.y))

	# The id derives from the same deterministic placement inputs, not from a spawn
	# counter: a tree id is the only identity the wire carries, so it has to agree
	# between peers (whose chunk streaming order differs) and survive a chunk reload
	# (which respawns a chunk's trees from scratch).
	var tree_id := _tree_id(chunk_pos, spawn_index)
	var mi := _alloc_visual(species, pos)
	var body: StaticBody3D = null
	if render_visuals:
		body = _build_collision(tree_id, pos, species)

	_trees[tree_id] = {
		"tree_id":    tree_id,
		"species":    species,
		"wood":       wood,
		"position":   pos,
		"chunk":      chunk_pos,
		"index":      spawn_index,
		"tile":       Vector2i(floori(xz.x / _tile_size()), floori(xz.y / _tile_size())),
		"state":      "standing",
		"respawn_at": -1.0,
		"mi":         mi,
		"body":       body,
	}
	if not _by_chunk.has(chunk_pos):
		_by_chunk[chunk_pos] = []
	(_by_chunk[chunk_pos] as Array).append(tree_id)
	_restore_remembered_stump(tree_id)
	return tree_id

static func _tree_id(chunk_pos: Vector2i, spawn_index: int) -> String:
	return "tree_%d_%d_%d" % [chunk_pos.x, chunk_pos.y, spawn_index]

## A tree whose stump was still regrowing when its chunk unloaded comes back as a stump
## with the same deadline; an expired memory just means a standing tree.
func _restore_remembered_stump(tree_id: String) -> void:
	if not _stump_memory.has(tree_id):
		return
	var respawn_at: float = _stump_memory[tree_id]
	_stump_memory.erase(tree_id)
	if _now() >= respawn_at:
		return
	var tree: Dictionary = _trees[tree_id]
	tree["respawn_at"] = respawn_at
	_set_chopped(tree_id)

## Deterministic world XZ inside the chunk footprint (inset one tile from the
## edge), derived from the chunk coordinate, species, and index — the same tree
## always lands on the same spot regardless of call order, so a host and a client
## agree without a snapshot.
func _deterministic_chunk_position(chunk_pos: Vector2i, species: String, spawn_index: int) -> Vector2:
	var cs: int = _chunk_size()
	var ts: float = _tile_size()
	var inner: int = cs - 2   # tiles available after a 1-tile border inset
	var seed_x: int = (chunk_pos.x * 83492791) ^ (chunk_pos.y * 19349663) ^ (species.hash() * 2654435761) ^ (spawn_index * 1000003)
	var seed_z: int = (chunk_pos.x * 19349663) ^ (chunk_pos.y * 83492791) ^ (species.hash() * 1000003) ^ (spawn_index * 73856093)
	var local_x: int = (absi(seed_x) % inner) + 1
	var local_z: int = (absi(seed_z) % inner) + 1
	return Vector2(
		float(chunk_pos.x * cs + local_x) * ts + ts * 0.5,
		float(chunk_pos.y * cs + local_z) * ts + ts * 0.5
	)

## Build the shared MultiMesh pool: one trunk + canopy mesh for every tree of
## every species, tinted per instance by the species' wood colour. The canopy
## keeps its own vertex tint so the per-instance colour only drives the trunk.
## Phase 63: the scene-origin offset a client rebase has applied (see `shift_scene`).
const SceneOffset := preload("res://src/core/scene_offset.gd")
var _origin: SceneOffset = SceneOffset.new()

## Phase 80 — the trunk bodies this slice spawned in world space. `shift_scene` moves exactly
## these plus the pool, so a helper node parented under the slice is never shifted by accident.
var _world_nodes: Array = []

## Shift the pool (every standing tree's mesh) and every trunk body by `shift`. Freed bodies drop out.
func shift_scene(shift: Vector3) -> void:
	_origin.value += shift
	if _pool != null:
		_pool.shift_scene(shift)
	var live: Array = []
	for n in _world_nodes:
		if is_instance_valid(n):
			(n as Node3D).position += shift
			live.append(n)
	_world_nodes = live

## Drop a freed world node from the shift set.
func _forget_world_node(node: Node) -> void:
	_world_nodes.erase(node)

func scene_offset() -> Vector3:
	return _origin.value

func _build_pool() -> void:
	_pool = MultimeshPool.new()
	_pool.name = "TreePool"
	_pool.setup(_tree_mesh(), true)
	add_child(_pool)

func _tree_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	MeshUtil.add_box(st,
		Vector3(0.0, TRUNK_HEIGHT * 0.5, 0.0),
		Vector3(TRUNK_RADIUS * 2.0, TRUNK_HEIGHT, TRUNK_RADIUS * 2.0),
		Color.WHITE)
	MeshUtil.add_box(st,
		Vector3(0.0, TRUNK_HEIGHT + CANOPY_HEIGHT * 0.5, 0.0),
		Vector3(CANOPY_RADIUS * 2.0, CANOPY_HEIGHT, CANOPY_RADIUS * 2.0),
		Color(0.45, 0.95, 0.42))
	return st.commit()

## Allocate a visual instance for a tree. Returns the MultiMesh instance index,
## or -1 when headless (no pool).
func _alloc_visual(species: String, pos: Vector3) -> int:
	if _pool == null:
		return -1
	var idx: int = _pool.alloc()
	_pool.set_color(idx, _species_color(species))
	_pool.set_transform(idx, _visual_transform(pos))
	return idx

## The shared mesh is authored above the origin, so the surface position is the
## instance position — no half-height offset to bake in.
func _visual_transform(pos: Vector3) -> Transform3D:
	return Transform3D(Basis(), pos)

## A chop leaves a squat stump: the same mesh scaled down and tinted dark, so the
## pooled MultiMesh needs no second mesh (and no per-tree node).
func _stump_transform(pos: Vector3) -> Transform3D:
	return Transform3D(Basis().scaled(Vector3(0.7, 0.18, 0.7)), pos)

func _species_color(species: String) -> Color:
	match species:
		"Thornwood": return Color(0.45, 0.32, 0.20)
		"Duskwood":  return Color(0.42, 0.30, 0.52)
		_:           return Color(0.50, 0.36, 0.24)

func _stump_color() -> Color:
	return Color(0.28, 0.20, 0.13)

## One StaticBody3D per standing tree, on TREE_COLLISION_LAYER, carrying the tree
## id and species as metadata so the player's chop ray can resolve its target and
## label it (PlayerSlice reads both). Built only when rendering — a headless
## server has no aim ray to serve.
func _build_collision(tree_id: String, pos: Vector3, species: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "TreeTrunk_%s" % tree_id
	body.collision_layer = TREE_COLLISION_LAYER
	body.collision_mask = 0
	body.set_meta("tree_id", tree_id)
	body.set_meta("species", species)
	body.position = pos + _origin.value
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = TRUNK_RADIUS
	cylinder.height = TRUNK_COLLISION_HEIGHT
	shape.shape = cylinder
	# Cylinder meshes/shapes are centred on their origin — lift it onto the base.
	shape.position = Vector3(0.0, TRUNK_COLLISION_HEIGHT * 0.5, 0.0)
	body.add_child(shape)
	add_child(body)
	_world_nodes.append(body)
	body.tree_exited.connect(_forget_world_node.bind(body))
	return body

## Free a tree's trunk collision so a felled tree stops being an aim target.
func _free_collision(tree: Dictionary) -> void:
	var body: Variant = tree.get("body", null)
	if body != null and is_instance_valid(body):
		(body as Node).queue_free()
	tree["body"] = null

func _chunk_biome(chunk_pos: Vector2i) -> String:
	if terrain_slice != null and terrain_slice.has_method("get_biome_at_chunk"):
		return str(terrain_slice.get_biome_at_chunk(chunk_pos))
	return ""

## Chunk side length from TerrainSlice; falls back to 32 when unwired (tests).
func _chunk_size() -> int:
	if terrain_slice != null and terrain_slice.has_method("world_to_chunk"):
		return terrain_slice.CHUNK_SIZE
	return 32

## Tile world size from TerrainSlice; falls back to 1.0 when unwired (tests).
func _tile_size() -> float:
	if terrain_slice != null and "TILE_SIZE" in terrain_slice:
		return float(terrain_slice.TILE_SIZE)
	return 1.0
