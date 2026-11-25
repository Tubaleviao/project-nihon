extends Node
## Phase 261 — loose stones and branches: small pickable props on the ground, denser inside a newcomer ground and
## sparse elsewhere. Placement is a pure function of (world seed, 4 m tile), like trees, so no world-gen change and
## no `WORLDGEN_VERSION` bump: every peer computes the same items. The host keeps which were taken and regrows
## them after the fabric's delay, so a ground never runs dry for the next newcomer.
##
##   IN  : loose_pick_requested(id, player_id)  — a pick-up intent (the interact key)
##         loose_picked(id, regrow_at)          — host → client state
##         loose_regrown(id)                    — host → client state
##   OUT : loose_pick_requested                 — client → host
##         loose_picked / loose_regrown         — host authoritative
const NewcomerGrounds := preload("res://src/world/newcomer_grounds.gd")
const StoneTools := preload("res://src/world/stone_tools.gd")
const SpawnFinder := preload("res://src/world/spawn_finder.gd")
const Diag := preload("res://src/core/diag.gd")
const WorldShape := preload("res://src/terrain/world_shape.gd")
const WorldPos := preload("res://src/terrain/world_pos.gd")

const TILE := 4.0
## Items closer than this to the local player are drawn.
const DRAW_RADIUS := 48.0
const MAX_TILE := 20000000   # an id naming a tile past the planet is refused
const KINDS := [StoneTools.BRANCH, StoneTools.LOOSE_STONE]
## #646 — loose items gathered by hand as plants: picking one is foraging (Foraging XP, the tier's yield bonus).
const FORAGED_KINDS := [StoneTools.BRANCH]
const WorkSkills := preload("res://src/character/work_skills.gd")
## Phase 279 — picking up is the `pick_up` input action (E by default; bare, Alt+letter is a window).
const InputLabels := preload("res://src/ui/input_labels.gd")
## A remote pick is checked against the peer's last reported position, which trails the body by a report
## interval: this much is allowed over the fabric's pick reach.
const REMOTE_REACH_SLACK := 4.0
## A player picks at most one item per this many seconds (the host refuses faster intents).
const PICK_COOLDOWN := 0.25
## Most taken entries a join snapshot carries (and a client adopts).
const MAX_SYNCED_TAKEN := 4096

var world_seed: int = 0
## When set, its world seed is the one used (the seed can change after wiring: a loaded save, a menu world).
var terrain_slice: Node = null
var is_authoritative: bool = true
var render_visuals: bool = true
## `() -> Vector3`: the local player's position (reach for the local actor, the interact key, the drawn ring).
var local_position: Callable = Callable()
## `(Vector2) -> float`: the ground height.
var height_fn: Callable = Callable()
var inventory_slice: Node = null
var player_registry: Node = null
## `() -> float`: the clock the regrow deadline uses (wall-clock seconds).
var clock: Callable = Callable()

## id -> regrow_at (unix seconds) of every item picked and not yet regrown.
var _taken: Dictionary = {}
## actor -> unix seconds of their last accepted pick (the host's rate limit).
var _last_pick: Dictionary = {}
var _root: Node3D = null
var _mmis: Dictionary = {}
var _drawn_from := Vector2(INF, INF)

func _ready() -> void:
	GameBus.loose_pick_requested.connect(_on_pick_requested)
	GameBus.loose_picked.connect(_on_picked)
	GameBus.loose_regrown.connect(_on_regrown)
	GameBus.loose_pick_intent.connect(_on_pick_intent)

## Wire the slice to the running game (`root` is the GameRoot): the world, the pack, the registry, the network.
func attach(root: Node) -> void:
	terrain_slice = root._terrain
	height_fn = root._terrain.get_height_at
	inventory_slice = root._inventory
	player_registry = root._registry
	networking = root._networking
	local_position = func() -> Vector3: return root._player.get_position()
	local_exact = func() -> Dictionary: return root._player.get_world_pos()
	scene_position = func() -> Vector3: return root._player.get_scene_position()
	render_visuals = not root._is_server

## The networking slice: a client forwards its pick-up intent through it, the host broadcasts what it resolved.
var networking: Node = null
## `() -> Dictionary`: the local player's exact world position `{ chunk, local }` (drawing far from the origin).
var local_exact: Callable = Callable()
## `() -> Vector3`: the local player's body in scene space (the drawn items are placed relative to it).
var scene_position: Callable = Callable()

func _process(_delta: float) -> void:
	if is_authoritative:
		tick()
	if render_visuals and local_position.is_valid():
		var p: Vector3 = local_position.call()
		if Vector2(p.x, p.z).distance_to(_drawn_from) > 8.0:
			redraw()

# ---------------------------------------------------------------------------
# Placement (pure)
# ---------------------------------------------------------------------------

static func tile_id(tx: int, tz: int) -> String:
	return "%d:%d" % [tx, tz]

## The tile an id names, or null for a malformed or out-of-range id.
static func parse_id(id: String) -> Variant:
	var parts := id.split(":")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return null
	var tx := int(parts[0])
	var tz := int(parts[1])
	if absi(tx) > MAX_TILE or absi(tz) > MAX_TILE:
		return null
	return Vector2i(tx, tz)

## The item on tile (tx, tz): { id, kind, xz } or an empty dictionary. A pure function of the seed and the tile
## (and, for the density, of whether the tile lies inside a ground — itself a pure function of the seed).
static func item_at(seed_v: int, tx: int, tz: int) -> Dictionary:
	var cx := (float(tx) + 0.5) * TILE
	var cz := (float(tz) + 0.5) * TILE
	var r := NewcomerGrounds.rule()
	var density := float(r["looseDensityInside"]) if NewcomerGrounds.inside(seed_v, cx, cz) else float(r["looseDensityOutside"])
	if density <= 0.0:
		return {}
	var h := hash([seed_v, tx, tz, "loose"])
	if float(posmod(h, 10000)) / 10000.0 >= density:
		return {}
	var kind: String = KINDS[posmod(h >> 16, KINDS.size())]
	# hash() is 32 bits: the offset in the tile comes from a second hash (one 16-bit half per axis).
	var j := hash([seed_v, tx, tz, "loose_xz"])
	var jx := 0.5 + float(posmod(j & 0xFFFF, 300)) / 100.0
	var jz := 0.5 + float(posmod((j >> 16) & 0xFFFF, 300)) / 100.0
	return { "id": tile_id(tx, tz), "kind": kind, "xz": Vector2(float(tx) * TILE + jx, float(tz) * TILE + jz),
		"tile": Vector2i(tx, tz), "jitter": Vector2(jx, jz) }

## The world seed in force; the grounds' centres for it are found once (cached) before any placement is asked.
func _seed() -> int:
	var sd := world_seed
	if terrain_slice != null and terrain_slice.has_method("get_world_seed"):
		sd = int(terrain_slice.get_world_seed())
	if height_fn.is_valid():
		SpawnFinder.prime_grounds(sd, height_fn)
	return sd

## Whether the item stands on dry land (a pure function of the terrain).
func _dry(xz: Vector2) -> bool:
	return not height_fn.is_valid() or float(height_fn.call(xz)) >= WorldShape.sea_level() + 0.5

## The item named by `id` when it exists in this world (taken or not), else an empty dictionary.
func record_of(id: String) -> Dictionary:
	var t: Variant = parse_id(id)
	if t == null:
		return {}
	var it := item_at(_seed(), (t as Vector2i).x, (t as Vector2i).y)
	if it.is_empty() or not _dry(it["xz"]):
		return {}
	return it

func is_taken(id: String) -> bool:
	return _taken.has(id)

## Every untaken item within `radius` of `centre` (world XZ).
func items_near(centre: Vector2, radius: float) -> Array:
	var out: Array = []
	var seed_v := _seed()
	var t0 := Vector2i(floori((centre.x - radius) / TILE), floori((centre.y - radius) / TILE))
	var t1 := Vector2i(floori((centre.x + radius) / TILE), floori((centre.y + radius) / TILE))
	for tx in range(t0.x, t1.x + 1):
		for tz in range(t0.y, t1.y + 1):
			var it := item_at(seed_v, tx, tz)
			if it.is_empty() or _taken.has(it["id"]):
				continue
			if (it["xz"] as Vector2).distance_to(centre) > radius or not _dry(it["xz"]):
				continue
			out.append(it)
	return out

## The nearest untaken item within the pick reach of `centre`, or an empty dictionary.
func nearest_pickable(centre: Vector2) -> Dictionary:
	var reach := float(NewcomerGrounds.rule()["pickReachMetres"])
	var best: Dictionary = {}
	var best_d := INF
	for it in items_near(centre, reach):
		var d := (it["xz"] as Vector2).distance_to(centre)
		if d < best_d:
			best = it
			best_d = d
	return best

# ---------------------------------------------------------------------------
# Host authority
# ---------------------------------------------------------------------------

func _now() -> float:
	return float(clock.call()) if clock.is_valid() else Time.get_unix_time_from_system()

func inventory_for(player_id: String) -> Node:
	if player_id != "" and player_registry != null and player_registry.has_method("get_inventory"):
		var inv: Node = player_registry.get_inventory(player_id)
		if inv != null:
			return inv
	return inventory_slice

## Host: `player_id` (`""` = this machine's own player) picks item `id` up. The reach of a remote player is checked
## by the networking arm against `record_of(id)["xz"]`; the local player's is checked here.
func pick(id: String, player_id: String = "") -> Dictionary:
	if not is_authoritative:
		return { "success": false, "reason": "not_authoritative" }
	var it := record_of(id)
	if it.is_empty():
		return { "success": false, "reason": "no_item" }
	if _taken.has(id):
		return { "success": false, "reason": "taken" }
	if _now() - float(_last_pick.get(player_id, -INF)) < PICK_COOLDOWN:
		return { "success": false, "reason": "rate_limited" }
	if player_id == "" and local_position.is_valid():
		var p: Vector3 = local_position.call()
		if Vector2(p.x, p.z).distance_to(it["xz"]) > float(NewcomerGrounds.rule()["pickReachMetres"]) + 1.0:
			return { "success": false, "reason": "out_of_reach" }
	var inv := inventory_for(player_id)
	var kind := str(it["kind"])
	var foraged := is_foraged(kind)
	var regrow_at := _now() + float(NewcomerGrounds.rule()["looseRegrowSeconds"])
	# #646: a plant gathered by hand gives the Foraging tier's yield (rolled from the host's own seeded hash).
	var units := WorkSkills.forage_units(player_registry, player_id, 1, forage_roll(id, regrow_at)) if foraged else 1
	if inv == null or not inv.has_method("add_item") or not inv.add_item(kind, units):
		return { "success": false, "reason": "no_inventory" }
	_taken[id] = regrow_at
	_last_pick[player_id] = _now()
	if foraged:
		WorkSkills.grant(player_registry, player_id, WorkSkills.gather_row("plant"))   # #646 — foraging grows Foraging
	_push_inventory(player_id, inv)
	GameBus.loose_picked.emit(id, regrow_at)
	_broadcast_state({ "type": "loose_picked", "id": id, "regrow_at": regrow_at })
	if render_visuals:
		redraw()
	return { "success": true, "reason": "", "item": it["kind"], "units": units }

## #646 — true for a loose item gathered by hand as a plant (a pick is a forage).
static func is_foraged(kind: String) -> bool:
	return FORAGED_KINDS.has(kind)

## #646 — the yield roll of one forage, in [0, 1): a pure function of the item and the pick's regrow time, so the
## host decides it and nothing a client sends moves it.
static func forage_roll(id: String, regrow_at: float) -> float:
	return float(posmod(hash([id, regrow_at, "forage"]), 10000)) / 10000.0

func _push_inventory(player_id: String, inv: Node) -> void:
	if player_id == "":
		return
	if player_registry != null and "local_player_id" in player_registry and player_id == str(player_registry.local_player_id):
		return
	if inv.has_method("get_contents"):
		GameBus.inventory_synced.emit(player_id, inv.get_contents(), inv.get_durability_data())

## Host: regrow every item whose deadline has passed.
func tick() -> void:
	if _taken.is_empty():
		return
	var now := _now()
	for id in _taken.keys():
		if now >= float(_taken[id]):
			_taken.erase(id)
			GameBus.loose_regrown.emit(id)
			_broadcast_state({ "type": "loose_regrown", "id": id })
			if render_visuals:
				redraw()

# ---------------------------------------------------------------------------
# Bus handlers
# ---------------------------------------------------------------------------

func _on_pick_requested(id: String, player_id: String) -> void:
	if is_authoritative:
		var res := pick(id, player_id)
		if not bool(res["success"]):
			Diag.warn("[Loose] pick of %s by '%s' refused: %s" % [id, player_id, str(res["reason"])])
			_tell(player_id, "hud.loose.refused." + str(res["reason"]))
	elif networking != null and networking._role == networking.Role.CLIENT:
		# The actor is dropped on purpose: the host binds it to the connection (a client naming one is only a claim).
		networking._broadcast({ "type": "loose_pick_intent", "id": id })

## Host: a client's intent from `peer`. An item the host does not have, or one out of the peer's reach, is dropped.
func _on_pick_intent(peer: int, id: String) -> void:
	if not is_authoritative or networking == null:
		return
	var actor: String = networking._actor_id(peer)
	if actor == "":
		networking._refuse_unhandshaked(peer, "loose_pick_intent")
		return
	var it := record_of(id)
	if it.is_empty():
		_tell(actor, "hud.loose.refused.no_item")
		return
	var xz: Vector2 = it["xz"]
	var y := float(height_fn.call(xz)) if height_fn.is_valid() else 0.0
	# The fabric's pick reach (plus the report lag), the same rule the local player has: never the 60 m edit reach.
	var reach := float(NewcomerGrounds.rule()["pickReachMetres"]) + REMOTE_REACH_SLACK
	if networking._within_reach(peer, Vector3(xz.x, y, xz.y), reach):
		GameBus.loose_pick_requested.emit(id, actor)
	else:
		Diag.warn("[Loose] pick intent for %s from peer %d is out of reach — dropped" % [id, peer])
		_tell(actor, "hud.loose.refused.out_of_reach")

## A keyed line for `player_id` alone ("" = this machine's player, named by its id: an empty target is a
## line the hosting networking slice broadcasts to every client).
func _tell(player_id: String, key: String) -> void:
	var target := player_id
	if target == "" and player_registry != null and "local_player_id" in player_registry:
		target = str(player_registry.local_player_id)
	GameBus.system_message.emit(key, [], target)

func _broadcast_state(msg: Dictionary) -> void:
	if is_authoritative and networking != null and networking._role == networking.Role.HOST:
		networking._broadcast(msg)

func _on_picked(id: String, regrow_at: float) -> void:
	if is_authoritative:
		return
	if parse_id(id) == null or not is_finite(regrow_at):
		return
	_taken[id] = regrow_at
	if render_visuals:
		redraw()

func _on_regrown(id: String) -> void:
	if is_authoritative:
		return
	_taken.erase(id)
	if render_visuals:
		redraw()

## The interact key: pick up the nearest item in reach.
func _on_interact() -> void:
	if not local_position.is_valid():
		return
	var p: Vector3 = local_position.call()
	var it := nearest_pickable(Vector2(p.x, p.z))
	if it.is_empty():
		_tell("", "hud.loose.nothing")
		return
	GameBus.loose_pick_requested.emit(str(it["id"]), "")

## The `pick_up` action (E) picks up the loose stone or branch at the player's feet (Alt+E is the inventory
## window, not a pick; a focused text field takes the key).
func _unhandled_input(event: InputEvent) -> void:
	if render_visuals and InputLabels.is_bare_action_press(event, InputLabels.PICK_UP):
		_on_interact()

# ---------------------------------------------------------------------------
# Join sync
# ---------------------------------------------------------------------------

## Host: the taken items for a join snapshot (id -> regrow_at), at most MAX_SYNCED_TAKEN of them.
func taken_data() -> Dictionary:
	var out := {}
	for id in _taken:
		if out.size() >= MAX_SYNCED_TAKEN:
			break
		out[id] = _taken[id]
	return out

## Client: adopt the host's taken items from a join snapshot (malformed entries are dropped).
func apply_taken(data: Variant) -> void:
	if is_authoritative or not (data is Dictionary):
		return
	_adopt_taken(data, -INF)

## Host: the taken items of a saved world record (follow-up #634), so a restart does not regrow every picked
## item at once. Entries whose regrow time has passed are dropped; the rest keep their deadline.
func load_taken(data: Variant) -> void:
	if not is_authoritative or not (data is Dictionary):
		return
	_adopt_taken(data, _now())

func _adopt_taken(data: Dictionary, after: float) -> void:
	_taken.clear()
	for id in data:
		if _taken.size() >= MAX_SYNCED_TAKEN:
			break
		var at: Variant = data[id]
		if id is String and parse_id(id) != null and (at is float or at is int) and is_finite(float(at)) and float(at) > after:
			_taken[id] = float(at)
	if render_visuals:
		redraw()

# ---------------------------------------------------------------------------
# Visuals (one MultiMesh, rebuilt around the local player)
# ---------------------------------------------------------------------------

## The items are placed relative to the body: the instance is at the body's scene X/Z and each item at its exact
## world offset from the body (tile and jitter in 64-bit floats), so they land right however far from the origin
## the player is and whatever rebase shifted the scene (`shift_scene` moves the instance with the world).
func redraw() -> void:
	if not render_visuals or not local_position.is_valid() or not is_inside_tree():
		return
	var p: Vector3 = local_position.call()
	_drawn_from = Vector2(p.x, p.z)
	var items := items_near(_drawn_from, DRAW_RADIUS)
	# The body's exact world X/Z as 64-bit floats (a Vector3 is 32-bit: metres apart at 20,000 km).
	var ax := float(p.x)
	var az := float(p.z)
	if local_exact.is_valid():
		var wp: Dictionary = local_exact.call()
		ax = float((wp["chunk"] as Vector2i).x) * WorldPos.CHUNK_METERS + float((wp["local"] as Vector3).x)
		az = float((wp["chunk"] as Vector2i).y) * WorldPos.CHUNK_METERS + float((wp["local"] as Vector3).z)
	var anchor: Vector3 = scene_position.call() if scene_position.is_valid() else p
	if _root == null:
		_root = Node3D.new()
		_root.top_level = true
		add_child(_root)
	_root.global_position = Vector3(anchor.x, 0.0, anchor.z)
	# Group the items by (kind, variant): one MultiMesh per group, its mesh from the kind's model.
	var groups: Dictionary = {}
	for it in items:
		var look := look_at_tile(it["tile"], str(it["kind"]), variant_keys(str(it["kind"])).size())
		var gk := "%s#%d" % [it["kind"], look["variant"]]
		if not groups.has(gk):
			groups[gk] = []
		groups[gk].append([it, look])
	for gk in _mmis.keys():
		if not groups.has(gk):
			(_mmis[gk] as MultiMeshInstance3D).multimesh.instance_count = 0
	for gk in groups.keys():
		var list: Array = groups[gk]
		var kind: String = list[0][0]["kind"]
		var mmi: MultiMeshInstance3D = _mmis.get(gk, null)
		if mmi == null:
			mmi = MultiMeshInstance3D.new()
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			var model := loose_mesh(variant_keys(kind)[int(list[0][1]["variant"])], kind)
			mm.mesh = model if model != null else fallback_box()
			mmi.set_meta("fallback", model == null)
			mmi.multimesh = mm
			_root.add_child(mmi)
			_mmis[gk] = mmi
		var mm2: MultiMesh = mmi.multimesh
		mm2.instance_count = list.size()
		for i in list.size():
			var it: Dictionary = list[i][0]
			var look: Dictionary = list[i][1]
			var xz: Vector2 = it["xz"]
			var t: Vector2i = it["tile"]
			var jit: Vector2 = it["jitter"]
			var dx := float(t.x) * TILE + float(jit.x) - ax
			var dz := float(t.y) * TILE + float(jit.y) - az
			var y := float(height_fn.call(xz)) if height_fn.is_valid() else p.y
			var basis := Basis(Vector3.UP, float(look["yaw"])).scaled(Vector3.ONE * float(look["scale"]))
			mm2.set_instance_transform(i, Transform3D(basis, Vector3(dx, y + 0.09, dz)))
			mm2.set_instance_color(i, _fallback_color(kind) if mmi.get_meta("fallback", false) else Color.WHITE)

## The multimesh instances now drawn, by "kind#variant" (tests read the meshes through these).
func drawn_multimeshes() -> Dictionary:
	var out := {}
	for gk in _mmis.keys():
		var mm: MultiMesh = (_mmis[gk] as MultiMeshInstance3D).multimesh
		if mm.instance_count > 0:
			out[gk] = mm
	return out

static func _fallback_color(kind: String) -> Color:
	return Color(0.45, 0.32, 0.18) if kind == StoneTools.BRANCH else Color(0.55, 0.55, 0.58)

## Deterministic look of the item on a tile: yaw, scale jitter (0.85-1.15) and variant index into
## `variant_keys` (host and client agree; the pick-up ray uses the logical position, not this).
static func look_at_tile(tile: Vector2i, kind: String, variant_count: int) -> Dictionary:
	var h := hash([tile.x, tile.y, kind, "loose_look"])
	var yaw := float(posmod(h & 0xFFFF, 36000)) / 36000.0 * TAU
	var sc := LOOK_SCALE_MIN + float(posmod((h >> 16) & 0xFFFF, 1000)) / 999.0 * (LOOK_SCALE_MAX - LOOK_SCALE_MIN)
	var v := posmod(hash([tile.x, tile.y, kind, "loose_variant"]), maxi(variant_count, 1))
	return { "yaw": yaw, "scale": sc, "variant": v }

const LOOK_SCALE_MIN := 0.85
const LOOK_SCALE_MAX := 1.15
const MAX_VARIANTS := 2

## Model keys usable for a kind: the base key first, then each `_v<n>` variant key that the
## manifest lists (an absent variant is never picked). Keys are listed even if the base is missing
## (the box fallback then draws every variant slot alike), so the base always comes first.
static func variant_keys(kind: String) -> Array:
	var out: Array = [AssetOverlay.item_model_key(kind)]
	for n in range(1, MAX_VARIANTS + 1):
		var key := "models/items/%s_v%d.glb.raw" % [kind, n]
		if AssetOverlay.has_key("meshes", key):
			out.append(key)
	return out

static var _loose_meshes: Dictionary = {}

## The mesh for a model key, or the box (flagged via `fallback` meta by the caller) when the key
## does not load. The box's material uses vertex colours so the two kinds still differ.
static func loose_mesh(key: String, kind: String) -> Mesh:
	if _loose_meshes.has(key):
		return _loose_meshes[key]
	var mesh: Mesh = null
	if AssetOverlay.has_key("meshes", key):
		mesh = AssetOverlay.load_mesh(key)
	if mesh == null:
		Diag.warn("[LooseItem] no usable model %s; using a box" % key)
	_loose_meshes[key] = mesh
	return mesh

static func fallback_box() -> BoxMesh:
	var box := BoxMesh.new()
	box.size = Vector3(0.35, 0.18, 0.35)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	box.material = mat
	return box

## A rebase moved the scene by `shift`: the drawn instance moves with it (the items keep their world places).
func shift_scene(shift: Vector3) -> void:
	if _root != null:
		_root.global_position += shift
