extends Node
## Tree slice (Phase 31) — deterministic per-biome trees, the only wood source.
##
## Wood materials (Thornwood / Duskfiber) deliberately do NOT spawn as ground in
## VoxelSlice.BIOME_MATERIALS: the fabric's biome prose spawns them as *trees*, so
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
##   IN  : tree_chop_requested(tree_id)                    — player intent
##         tree_chopped(tree_id, wood, state, respawn_at)  — host → client state
##         tree_respawned(tree_id)                         — host → client state
##   OUT : tree_chop_requested(tree_id)                    — client → host
##         tree_chopped(tree_id, wood, state, respawn_at)  — host authoritative
##         tree_respawned(tree_id)                         — host authoritative
##
## Public API:
##   spawn_for_chunk(chunk_pos) / despawn_for_chunk(chunk_pos)   — Phase 17 streaming
##   tree_entry_for_biome(biome) -> Dictionary  ({} when the biome grows no trees)
##   get_tree_record(tree_id) -> Dictionary
##   get_all_trees() / trees_in_chunk(chunk_pos) -> Array
##   chop_tree(tree_id) -> Dictionary  { success, wood, quantity, reason }
##   apply_chop_state(tree_id, respawn_at) -> void   (client-side host state)

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
## badlands prose grants no conventional wood. `per_chunk` follows the prose
## weight: dominant → 8 trees, isolated copses → 2.
##
## GDScript-first on purpose: the roadmap lands trees as a runtime feature and
## adds the fabric world-system entity once the runtime shape has settled (see
## Phase 31's Newel dependency note).
const TREES_BY_BIOME: Dictionary = {
	"TemperateForest":    { "species": "Thornwood", "wood": "Thornwood", "per_chunk": 8 },
	"TemperateGrassland": { "species": "Thornwood", "wood": "Thornwood", "per_chunk": 2 },
	"TwilightGrove":      { "species": "Duskwood",  "wood": "Duskfiber", "per_chunk": 8 },
}

## Biome assumed when no terrain slice is wired (isolated unit tests), mirroring
## CreatureSlice's "no terrain → spawn anyway" test path.
const DEFAULT_BIOME := "TemperateForest"

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

## Shared MultiMesh pool; null when render_visuals is false (headless server).
var _pool: Node = null
## When false (headless server / `--server`), no pool and no collision bodies are
## built: the same records drive a bare authoritative simulation.
var render_visuals: bool = true

## Set by game_root before the slices enter the tree.
var terrain_slice: Node = null
var inventory_slice: Node = null

## Authority mode (Phase 18). When true (host / single-player) this slice resolves
## chops and regrowth; when false (client) it forwards the chop intent and applies
## the host's authoritative tree state.
var is_authoritative: bool = true

func _ready() -> void:
	GameBus.tree_chop_requested.connect(_on_chop_requested)
	GameBus.tree_chopped.connect(_on_tree_chopped)
	GameBus.tree_respawned.connect(_on_tree_respawned)
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
	var entry := tree_entry_for_biome(_chunk_biome(chunk_pos))
	if entry.is_empty():
		return
	var budget: int = int(entry["per_chunk"])
	var existing: int = 0
	for tid in _trees:
		if _trees[tid]["chunk"] == chunk_pos:
			existing += 1
	for i in range(existing, budget):
		_spawn(str(entry["species"]), str(entry["wood"]), chunk_pos, i)

## Remove every tree belonging to `chunk_pos`, freeing its visual instance and
## trunk collision. Trees carry no combat state, so unlike creatures none are
## kept alive across a despawn.
func despawn_for_chunk(chunk_pos: Vector2i) -> void:
	var to_erase: Array = []
	for tid in _trees:
		if _trees[tid]["chunk"] == chunk_pos:
			to_erase.append(tid)
	for tid in to_erase:
		var tree: Dictionary = _trees[tid]
		if _pool != null and int(tree["mi"]) >= 0:
			_pool.release(int(tree["mi"]))
		_free_collision(tree)
		_trees.erase(tid)

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
	for tid in _trees:
		if _trees[tid]["chunk"] == chunk_pos:
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
func chop_tree(tree_id: String) -> Dictionary:
	if not is_authoritative:
		GameBus.tree_chop_requested.emit(tree_id)
		return { "success": false, "wood": "", "quantity": 0, "reason": "forwarded" }
	if not _trees.has(tree_id):
		return _fail("no_tree")
	var tree: Dictionary = _trees[tree_id]
	if tree["state"] != "standing":
		return _fail("not_standing")
	var axe := _held_axe()
	if axe == "":
		return _fail("axe_required")
	var wood: String = str(tree["wood"])
	# Refuse before spending durability so a full inventory never costs the axe.
	if inventory_slice != null and inventory_slice.has_method("can_add_items"):
		if not inventory_slice.can_add_items({ wood: CHOP_YIELD }):
			return _fail("no_inventory")
	# Spend the axe's wear BEFORE the tree changes state, so a broken axe can
	# never fell a tree for free (the ordering mine_block uses for the pick).
	if inventory_slice != null and inventory_slice.has_method("use_item"):
		if not inventory_slice.use_item(axe, "chop"):
			return _fail("axe_broken")
	if inventory_slice != null and inventory_slice.has_method("add_item"):
		if not inventory_slice.add_item(wood, CHOP_YIELD):
			return _fail("no_inventory")
	_set_chopped(tree_id)
	return { "success": true, "wood": wood, "quantity": CHOP_YIELD, "reason": "" }

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
# Private — chopping / regrowth
# ---------------------------------------------------------------------------

func _set_chopped(tree_id: String) -> void:
	var tree: Dictionary = _trees.get(tree_id, {})
	if tree.is_empty() or tree["state"] != "standing":
		return
	tree["state"] = "stump"
	if float(tree["respawn_at"]) <= 0.0:
		tree["respawn_at"] = _now() + RESPAWN_SECONDS
	_free_collision(tree)
	if _pool != null and int(tree["mi"]) >= 0:
		# Squat, dark stump shape (the shared mesh is truncated, not swapped).
		_pool.set_color(int(tree["mi"]), _stump_color())
		_pool.set_transform(int(tree["mi"]), _stump_transform(tree["position"]))
	GameBus.tree_chopped.emit(tree_id, str(tree["wood"]), "stump", float(tree["respawn_at"]))

func _tick_respawn() -> void:
	var now := _now()
	for tid in _trees:
		var tree: Dictionary = _trees[tid]
		if tree["state"] != "stump" or float(tree["respawn_at"]) <= 0.0:
			continue
		if now < float(tree["respawn_at"]):
			continue
		tree["state"] = "standing"
		tree["respawn_at"] = -1.0
		if render_visuals:
			tree["body"] = _build_collision(str(tid), tree["position"], str(tree["species"]))
		if _pool != null and int(tree["mi"]) >= 0:
			_pool.set_color(int(tree["mi"]), _species_color(str(tree["species"])))
			_pool.set_transform(int(tree["mi"]), _visual_transform(tree["position"]))
		GameBus.tree_respawned.emit(str(tid))

## The held axe's item id, or "" when the player holds none. Delegates to the
## inventory's fabric-driven tool lookup ("axe" → CarpenterAxe today).
func _held_axe() -> String:
	if inventory_slice == null or not inventory_slice.has_method("find_tool"):
		return ""
	return str(inventory_slice.find_tool("axe"))

## Wall-clock seconds since the Unix epoch. NOT `Time.get_ticks_msec()` — that is
## process uptime, which makes a saved regrowth deadline meaningless after a
## restart (the same rule the Phase 24 market deadlines follow).
func _now() -> float:
	return Time.get_unix_time_from_system()

func _fail(reason: String) -> Dictionary:
	push_warning("[Tree] chop FAILED — %s" % reason)
	return { "success": false, "wood": "", "quantity": 0, "reason": reason }

func _on_chop_requested(tree_id: String) -> void:
	if is_authoritative:
		chop_tree(tree_id)

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
	var tree_id := "tree_%d_%d_%d" % [chunk_pos.x, chunk_pos.y, spawn_index]
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
		"state":      "standing",
		"respawn_at": -1.0,
		"mi":         mi,
		"body":       body,
	}
	return tree_id

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
	body.position = pos
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = TRUNK_RADIUS
	cylinder.height = TRUNK_COLLISION_HEIGHT
	shape.shape = cylinder
	# Cylinder meshes/shapes are centred on their origin — lift it onto the base.
	shape.position = Vector3(0.0, TRUNK_COLLISION_HEIGHT * 0.5, 0.0)
	body.add_child(shape)
	add_child(body)
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
