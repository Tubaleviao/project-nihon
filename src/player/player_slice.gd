extends Node
## Player slice — CharacterBody3D with a follow camera and keyboard/mouse input.
##
## Plug contract (GameBus signals consumed / emitted):
##   IN  : (none — input is read directly from Input singleton)
##   OUT : player_state_changed(payload)
##         player_state_sync_requested(payload)   — every N ticks for networking
##
## Public API:
##   get_position()   -> Vector3
##   get_hp()         -> float
##   take_damage(dmg) -> void
const WorldPos := preload("res://src/terrain/world_pos.gd")
const Diag := preload("res://src/core/diag.gd")

const SPEED        := 4.5     # m/s horizontal
const JUMP_FORCE   := 5.0     # m/s vertical
const GRAVITY      := -9.8    # m/s²
const MOUSE_SENS   := 0.002   # radians per pixel
# Isometric orbit camera: the mouse orbits (yaw) + tilts (pitch) around the
# player, and the scroll wheel zooms. Pitch is clamped to a downward-only range
# so the camera always looks at the ground from above (classic isometric view).
const CAMERA_PITCH_MIN := -75.0   # degrees below horizontal (looking down)
const CAMERA_PITCH_MAX := -20.0
const CAMERA_PITCH     := -45.0   # default isometric down-angle
const CAMERA_DISTANCE      := 12.0  # orbit radius behind the pivot
const CAMERA_DISTANCE_MIN  := 4.0
const CAMERA_DISTANCE_MAX  := 24.0
const CAMERA_PIVOT_HEIGHT  := 2.0   # vertical point the camera orbits around
const ZOOM_STEP := 1.5             # world units per scroll tick
const SYNC_INTERVAL := 30     # physics ticks between network sync broadcasts
const ATTACK_RANGE := 3.0     # metres — melee interaction radius
## Metres — how close the player must be to tame (Phase 35). Must match
## TamingSlice.TAME_RANGE, which re-checks it and is the authority.
const TAME_RANGE := 4.0
const PICKUP_RANGE := 60.0    # metres — how far the player can aim-pick (camera sits far back)
## Step-up clearance for a voxel rise, in world units. Terrain is quantised to
## `VoxelSlice.STEP_HEIGHT` (0.125), but the capsule's contact normal on a rise is
## mostly horizontal, so a bare `move_and_slide()` stops the body dead at every
## step. A rise no taller than this is climbed instead (`_move` →
## `resolve_step_up`), and `floor_snap_length` uses the same length so stepping
## DOWN a rise keeps the body glued to the surface instead of dropping it.
const STEP_UP_HEIGHT := 0.3
## Phase 51 — water. Ground deeper than WADE_DEPTH under the surface is swum, not walked: the body
## floats with its feet SWIM_FLOAT below the surface and moves at SWIM_SPEED_FACTOR of walking speed.
const WADE_DEPTH := 1.2
const SWIM_FLOAT := 1.0
const SWIM_SPEED_FACTOR := 0.6
const SWIM_RISE_RATE := 4.0   # 1/s — how hard buoyancy pulls the feet to the float line
const SWIM_MAX_VERTICAL := 3.0 # m/s
const PICKUP_COLLISION_MASK := 4   # layer 3 (bit 2) — matches loot pickup bodies
const BUILD_RANGE := 60.0     # metres — how far the player can reach a block
const TERRAIN_COLLISION_MASK := 2  # layer 2 (bit 1) — terrain, for mine/build ray
const CHOP_RANGE := 60.0      # metres — how far the player can reach a tree trunk
const TREE_COLLISION_MASK := 8 # layer 4 (bit 3) — tree trunks, for the chop ray

## The body's shared rules live in a neutral module (Phase 39 review pass): the
## persistence layer has to agree with this slice about the health ceiling and the respawn
## delay — it simulates a REMOTE peer's body — and reading them off this slice made
## persistence preload presentation. Aliased here so every existing reader
## (`_hp`, the HUD, the suite, the harness) keeps the same name.
const PlayerRules := preload("res://src/core/player_rules.gd")
const WorldShape := preload("res://src/terrain/world_shape.gd")

const MAX_HP := PlayerRules.MAX_HP

const MouseIconScript := preload("res://src/ui/mouse_icon.gd")

var _body:   CharacterBody3D
var _camera: Camera3D
var _pivot:  Node3D           # horizontal yaw pivot under _body
var _hp:     float = MAX_HP
var _vel:    Vector3 = Vector3.ZERO
var _sync_tick: int = 0
var _alive: bool = true

## Aim raycast state + HUD.
var _hud: CanvasLayer = null
var _aim_label: Label = null
var _aimed_pickup_id: String = ""
var _aimed_item_id: String = ""
var _build_material_label: Label = null
var _station_label: Label = null

## Aimed terrain block (mine/build target), updated every frame.
var _aimed_block_hit: bool = false
var _aimed_block_pos: Vector3 = Vector3.ZERO
var _aimed_block_normal: Vector3 = Vector3.UP

## Aimed tree trunk (chop target), updated every frame. Empty when no trunk is
## under the crosshair — the id and species ride as metadata on the trunk body.
var _aimed_tree_id: String = ""
var _aimed_tree_species: String = ""

## HP bar label — updated on every damage/heal event.
var _hp_label: Label = null

## Respawn countdown in seconds; -1 when not respawning.
const RESPAWN_DELAY := PlayerRules.RESPAWN_DELAY
var _respawn_timer: float = -1.0

## Remote player ghosts (Phase 18). Keyed by peer_id → { "mi": int, "from":
## Vector3, "to": Vector3, "t": float, "pos": Vector3 }. Each ghost is a
## MultiMesh instance (no per-peer Node3D, no physics) that interpolates from
## the previous snapshot to the latest one, so remote movement renders smoothly
## between host ticks.
const MultimeshPool := preload("res://src/core/multimesh_pool.gd")

var _ghosts: Dictionary = {}
const GHOST_INTERP_TIME := 0.1   # seconds to blend between two snapshots

## Shared MultiMesh pool for remote player ghosts; null when headless.
var _ghost_pool: Node = null
## When false (headless server), no body, camera, or HUD is built — the slice
## tracks no local presentation; remote-player state flows purely as data.
var render_visuals: bool = true

## Set by game_root after all slices are instantiated.
var creature_slice: Node = null
var voxel_slice: Node = null
var station_slice: Node = null

## Station placement preview ghost toggled by N.
var _station_preview_on: bool = false
var terrain_slice: Node = null

## Phase 42 — set while the loading screen is up. It is its OWN gate, not a reuse of
## `UIControl.any_window_open()`: that predicate answers only for the panels the UI
## slice holds, and a loading screen is not among them, so nothing would be refused.
## Driven by the `world_input_frozen` bus signal the loading screen emits, and also
## settable directly (see `set_world_input_frozen`) for a caller that holds the slice.
##
## Phase 42 review — it freezes the BODY as well as the input (see `_physics_process`):
## the freeze is what holds a client's body still over ground that is still being built,
## so it cannot be only an input gate.
var _world_input_frozen: bool = false

func _ready() -> void:
	if render_visuals:
		_build_body()
		_build_hud()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	GameBus.block_place_material_changed.connect(_on_place_material_changed)
	GameBus.player_damaged.connect(_on_player_damaged)
	GameBus.remote_player_state.connect(_on_remote_player_state)
	GameBus.world_input_frozen.connect(set_world_input_frozen)

## Freeze / unfreeze every world action for as long as the loading screen is up.
func set_world_input_frozen(frozen: bool) -> void:
	_world_input_frozen = frozen

func is_world_input_frozen() -> bool:
	return _world_input_frozen

## The ONE predicate `_input` consults before any world action: the mouse must be
## captured (a UI window or a released mouse blocks everything below) AND the world
## input freeze must be off (the loading screen blocks it until the ground the body
## stands on exists). Public so the freeze is assertable without a display server —
## a headless run has no mouse capture, which would make `_input`'s own guard pass
## for the wrong reason.
func world_input_allowed() -> bool:
	if _world_input_frozen:
		return false
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if not _alive:
		if _respawn_timer > 0.0:
			_respawn_timer -= delta
			if _respawn_timer <= 0.0:
				_respawn()
		return
	# Phase 42 review — the loading freeze holds the BODY too, not just `_input`. It used
	# to gate only the input arms above, so while the loading screen was up the body still
	# ran its own physics: on the host it was inert only because it had not been spawned
	# yet, and on a client (which placed the body from the snapshot while its ring built) it
	# fell through ground that did not exist. Frozen means the body holds its position until
	# the ground under it is there.
	if render_visuals and not _world_input_frozen:
		_move(delta)
	_sync_tick += 1
	if _sync_tick >= SYNC_INTERVAL:
		_sync_tick = 0
		_broadcast_state()

func _process(delta: float) -> void:
	if render_visuals:
		_update_aim()
		_update_station_preview()
	_tick_ghosts(delta)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Yaw (horizontal) — rotate the body pivot
		_pivot.rotate_y(-event.relative.x * MOUSE_SENS)
		# Pitch (vertical) — rotate only the camera arm
		var cam_arm: Node3D = _camera.get_parent()
		cam_arm.rotation_degrees.x = clamp(
			cam_arm.rotation_degrees.x - event.relative.y * rad_to_deg(MOUSE_SENS),
			CAMERA_PITCH_MIN, CAMERA_PITCH_MAX
		)
	# Scroll wheel → zoom the orbit camera in/out (captured mouse only).
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(-ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(ZOOM_STEP)
	# All world actions below require a captured mouse and an unfrozen world (Phase
	# 42 — the loading screen owns the freeze hook; see `world_input_allowed`).
	# While a UI window is open the UI slice keeps the mouse visible, so the mouse
	# half prevents attacking, mining, or placing through an open menu, and the
	# loading screen's freeze prevents any of it before the ground exists. ESC (mouse
	# capture toggle) is owned by the UI slice now.
	if not world_input_allowed():
		return
	# Left-click: pick up an aimed item if there is one, else chop an aimed tree,
	# otherwise attack.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _aimed_pickup_id != "":
			_try_pickup_aimed()
		elif _aimed_tree_id != "":
			# "" = this machine's own player; the host binds the real actor to the
			# connection when the intent reaches it (see bus.gd's signal note).
			GameBus.tree_chop_requested.emit(_aimed_tree_id, "")
		else:
			_try_attack()
	# F key → melee attack the nearest creature in range.
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		_try_attack()
	# Right-click → mine the aimed terrain block.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if _aimed_block_hit:
			GameBus.block_mine_requested.emit(_aimed_block_pos, _aimed_block_normal, "")
	# Middle-click → place a block against the aimed terrain face.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_MIDDLE:
		if _aimed_block_hit:
			# Both trailing args are "" = this machine's own player and its own
			# material selection; a client's placement travels to the host as a
			# `block_edit_intent` carrying that selection (see `_on_place_requested`).
			GameBus.block_place_requested.emit(_aimed_block_pos, _aimed_block_normal, "", "")
	# R key → cycle the build material.
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		GameBus.block_cycle_material_requested.emit()
	# B key → cycle the station type to place.
	if event is InputEventKey and event.pressed and event.keycode == KEY_B:
		_cycle_station_type()
	# N key → toggle the station placement preview ghost.
	if event is InputEventKey and event.pressed and event.keycode == KEY_N:
		_station_preview_on = not _station_preview_on
		if not _station_preview_on and station_slice != null and station_slice.has_method("hide_preview"):
			station_slice.hide_preview()
	# V key → place the selected station at the aimed spot (or the player's feet).
	if event is InputEventKey and event.pressed and event.keycode == KEY_V:
		_place_station()
	# G key → tame the nearest creature in range (Phase 35). The rules live in
	# TamingSlice (fabric-driven); this is only the player-facing affordance.
	if event is InputEventKey and event.pressed and event.keycode == KEY_G:
		_try_tame()
	# E key → toggle all equipment on/off (inspect the naked body under the gear).
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		GameBus.character_equipment_toggle_requested.emit()

func get_position() -> Vector3:
	return _body.global_position - _scene_offset if _body else Vector3.ZERO

## Phase 63: the scene-origin offset a client rebase has applied. The body sits at world + offset;
## `get_position` and `spawn_at` still speak world coordinates.
var _scene_offset: Vector3 = Vector3.ZERO

## The body's raw scene position (what the physics server sees).
func get_scene_position() -> Vector3:
	return _body.global_position if _body else Vector3.ZERO

## Shift the body by `shift` in the same frame the world shifts; its world position is unchanged.
func shift_scene(shift: Vector3) -> void:
	_scene_offset += shift
	if _body:
		_body.global_position += shift

func scene_offset() -> Vector3:
	return _scene_offset

func get_velocity() -> Vector3:
	return _vel

func is_grounded() -> bool:
	return _body.is_on_floor() if _body else false

## The player's horizontal facing direction in world XZ (normalized), derived
## from the yaw pivot's forward axis. Used by the minimap to orient the player
## arrow. Falls back to "north" (-Z) before the body is built.
func get_facing() -> Vector2:
	if _pivot == null:
		return Vector2(0.0, -1.0)
	var b: Basis = _pivot.global_transform.basis
	var f := Vector2(-b.z.x, -b.z.z)
	if f.length_squared() < 0.0001:
		return Vector2(0.0, -1.0)
	return f.normalized()

func spawn_at(pos: Vector3) -> void:
	if _body:
		_body.global_position = pos + _scene_offset
		_vel = Vector3.ZERO

## Adjust the orbit camera's distance from the player (scroll-wheel zoom),
## clamped to [CAMERA_DISTANCE_MIN, CAMERA_DISTANCE_MAX].
func _zoom(delta_z: float) -> void:
	if _camera == null:
		return
	_camera.position.z = clampf(_camera.position.z + delta_z, CAMERA_DISTANCE_MIN, CAMERA_DISTANCE_MAX)

func get_hp() -> float:
	return _hp

## Restore HP from a save (Phase 33). Clamped to [0, MAX_HP]; the position half
## of a restore is `spawn_at()`. Restoring HP is what makes the boot snapshot's
## `player.hp` field actually read back instead of written and forgotten.
##
## Phase 39 — this is the ONE door a body can be handed a zero through (a join
## snapshot, a forwarded hit, a save restore), so it is where the respawn countdown
## starts: a zero applied to a body with NO countdown running sets `_respawn_timer`.
## Without it a body could sit `_alive == false` with `_respawn_timer == -1.0` — dead,
## and `_physics_process` ticking a timer that was never started, so it never came back.
## That is exactly the soft-lock a peer downed by a creature then handed its own zero on
## reconnect ended up in; it also covered the single-player case for free, because
## `game_root._restore_local_player` and the load snapshot hand their saved zero to this
## same method.
##
## It must START a countdown, not restart one: the guard below is what stops a REPEATED
## zero (a host re-forwarding a hit at a body already at zero, a snapshot re-delivered)
## from pushing the respawn further away on every application, which would leave the
## body dead forever. `_die()` remains the other way in, and it always sets the timer.
##
## Review pass (Phase 39) — two more rules, both about what this door owes the callers
## that were already using it:
##
##   • a body taken from ALIVE to zero here is announced dead THROUGH `_die()`. A zero
##     applied through this method used to skip the death door: the body was dead on this
##     machine with no `player_died` behind it, yet the countdown this method started
##     still announced `player_respawned` when it ran out — a respawn with no death is
##     half a pair, and every listener that pairs them sees the mistake. A zero applied to
##     a body that is ALREADY down announces nothing: that death is not this call's news,
##     and a re-delivered snapshot must not re-announce it;
##   • a value that leaves the body UP clears any countdown parked on it.
##     `_physics_process` ticks the timer only while `_alive` is false, so a leftover
##     countdown would sit frozen on a living body and then be REUSED by the next zero
##     instead of a fresh one — the body would come back early, on the seconds left over
##     from a death it had already recovered from.
func set_hp(hp: float) -> void:
	_hp = clampf(hp, 0.0, MAX_HP)
	if _hp <= 0.0:
		if _alive:
			_die()   # the death door: arms the countdown AND emits player_died
		elif _respawn_timer < 0.0:
			_respawn_timer = RESPAWN_DELAY
	else:
		_alive = true
		_respawn_timer = -1.0
	_update_hp_bar()
	_broadcast_state()

## Number of remote player ghosts currently tracked.
func get_remote_ghost_count() -> int:
	return _ghosts.size()

## Remote player ghosts — a client renders other players as visual-only bodies
## (no local input, no physics) that interpolate between host snapshots.
const GHOST_COLOR := Color(0.30, 0.55, 0.90)   # blue — distinct from the local player

## Peers a richer body already represents (a CharacterSlice remote avatar): the capsule ghost
## is not built for them, or is released when it already exists, so the same player is not
## drawn twice. See `set_ghost_suppressed`.
var _ghost_suppressed: Dictionary = {}

## Stop (or resume) drawing the capsule ghost for `peer_id`. Suppressing releases an existing
## ghost's pool slot immediately.
func set_ghost_suppressed(peer_id: int, suppressed: bool) -> void:
	if not suppressed:
		_ghost_suppressed.erase(peer_id)
		return
	_ghost_suppressed[peer_id] = true
	if _ghosts.has(peer_id):
		if _ghost_pool != null:
			_ghost_pool.release(int(_ghosts[peer_id]["mi"]))
		_ghosts.erase(peer_id)

func _on_remote_player_state(peer_id: int, position: Vector3) -> void:
	# A headless server renders nothing and has no local player — remote-player
	# ghosts are a client-only concern, so never build a visual pool here.
	if not render_visuals:
		return
	# Never ghost our own local player: the host echoes a client's movement back
	# to every peer (including the originator), and that echo must not spawn a
	# ghost of ourselves.
	if peer_id == multiplayer.get_unique_id():
		return
	if _ghost_suppressed.has(peer_id):
		return
	if not _ghosts.has(peer_id):
		if _ghost_pool == null:
			_build_ghost_pool()
		var mi: int = _ghost_pool.alloc()
		_ghost_pool.set_color(mi, GHOST_COLOR)
		_ghost_pool.set_transform(mi, _ghost_transform(position))
		_ghosts[peer_id] = {
			"mi":   mi,
			"from": position,
			"to":   position,
			"t":    1.0,
			"pos":  position,
		}
		return
	var g: Dictionary = _ghosts[peer_id]
	g["from"] = g["pos"]
	g["to"]   = position
	g["t"]    = 0.0

func _tick_ghosts(delta: float) -> void:
	for peer_id in _ghosts:
		var g: Dictionary = _ghosts[peer_id]
		g["t"] = minf(g["t"] + delta / GHOST_INTERP_TIME, 1.0)
		g["pos"] = g["from"].lerp(g["to"], g["t"])
		if _ghost_pool != null:
			_ghost_pool.set_transform(int(g["mi"]), _ghost_transform(g["pos"]))

func _build_ghost_pool() -> void:
	var cap := CapsuleMesh.new()
	cap.radius = 0.25  # matches the collision capsule (see _build_body)
	cap.height = 1.8
	_ghost_pool = MultimeshPool.new()
	_ghost_pool.name = "GhostPool"
	_ghost_pool.setup(cap, true)
	add_child(_ghost_pool)

## World position → ghost instance transform (capsule half-height 0.9 offset).
func _ghost_transform(pos: Vector3) -> Transform3D:
	return Transform3D(Basis(), pos + Vector3(0.0, 0.9, 0.0))

func take_damage(dmg: float, killer_id: String = "") -> void:
	_hp = maxf(_hp - dmg, 0.0)
	_update_hp_bar()
	_broadcast_state()
	if _hp <= 0.0 and _alive:
		_die(killer_id)

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _build_body() -> void:
	# Build the scene tree entirely in code so no .tscn file is needed.
	_body = CharacterBody3D.new()
	_body.name = "PlayerBody"
	add_child(_body)

	# Terrain collision lives on layer 2 (see VoxelSlice.TERRAIN_COLLISION_LAYER);
	# the body must collide with that layer to stand on the ground.
	_body.collision_layer = 1
	_body.collision_mask = 3   # layer 1 (default) + layer 2 (terrain)

	# Snap the body to the floor over more than one quantised voxel step
	# (STEP_HEIGHT 0.125) — the default 0.1 is shorter than the rise the step-up
	# in `_move` climbs, so the body would step UP onto a voxel and then lose the
	# floor, briefly going airborne on every stair.
	_body.floor_snap_length = STEP_UP_HEIGHT

	# Spawn above the terrain origin so the player lands on the voxel surface.
	_body.global_position = Vector3(16.0, 12.0, 16.0)

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	# Radius 0.25 (diameter 0.5) matches TILE_SIZE so the body doesn't sink into
	# the finer 0.5-unit terrain grid (a wider capsule spans multiple columns of
	# slightly different height and "swims" into the ground).
	cap.radius = 0.25
	cap.height = 1.8
	col.shape   = cap
	col.position = Vector3(0, 0.9, 0)
	_body.add_child(col)

	# Yaw pivot (child of body so it inherits position but NOT rotation from physics).
	_pivot = Node3D.new()
	_pivot.name = "YawPivot"
	_body.add_child(_pivot)

	# Camera arm (controls pitch) — pitched down for the isometric view.
	var cam_arm := Node3D.new()
	cam_arm.name = "CamArm"
	cam_arm.position = Vector3(0, CAMERA_PIVOT_HEIGHT, 0)
	cam_arm.rotation_degrees.x = CAMERA_PITCH
	_pivot.add_child(cam_arm)

	# Camera sits back along the arm's +Z (behind/above the pivot) so it looks
	# down at the player from an isometric angle. Zoom adjusts this distance.
	_camera = Camera3D.new()
	_camera.name = "PlayerCamera"
	_camera.position = Vector3(0, 0, CAMERA_DISTANCE)
	_camera.current  = true
	cam_arm.add_child(_camera)

## True when the ground under a body is deep enough below the sea surface that it swims.
static func is_swimming(ground_y: float, sea_level: float) -> bool:
	return sea_level - ground_y > WADE_DEPTH

## Vertical velocity of a swimming body: buoyancy pulls its feet to `sea_level - SWIM_FLOAT`
## (up from the sea floor, down from a jump), capped at SWIM_MAX_VERTICAL.
static func swim_vertical_velocity(feet_y: float, sea_level: float) -> float:
	return clampf((sea_level - SWIM_FLOAT - feet_y) * SWIM_RISE_RATE, -SWIM_MAX_VERTICAL, SWIM_MAX_VERTICAL)

## Whether the local body is swimming now (needs a terrain slice to read the ground).
func _swimming_now() -> bool:
	if terrain_slice == null or not terrain_slice.has_method("get_height_at"):
		return false
	var p := get_position()
	var sea := WorldShape.sea_level()
	# Only a body at or below the surface swims: one on a platform or falling in from a cliff does not.
	if p.y > sea + WADE_DEPTH:
		return false
	return is_swimming(float(terrain_slice.get_height_at(Vector2(p.x, p.z))), sea)

func _move(delta: float) -> void:
	var swimming := _swimming_now()
	# Apply gravity.
	if swimming:
		_vel.y = swim_vertical_velocity(_body.global_position.y, WorldShape.sea_level())
	elif not _body.is_on_floor():
		_vel.y += GRAVITY * delta
	else:
		if _vel.y < 0.0:
			_vel.y = 0.0

	# Jump.
	if not swimming and Input.is_action_just_pressed("ui_accept") and _body.is_on_floor():
		_vel.y = JUMP_FORCE

	# Horizontal movement relative to camera yaw.
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): dir.z -= 1.0
	if Input.is_key_pressed(KEY_S): dir.z += 1.0
	if Input.is_key_pressed(KEY_A): dir.x -= 1.0
	if Input.is_key_pressed(KEY_D): dir.x += 1.0

	if dir.length_squared() > 0.0:
		dir = dir.normalized()
		# Transform direction by yaw pivot's global basis (XZ plane only).
		var basis := _pivot.global_transform.basis
		dir = (basis.x * dir.x + basis.z * dir.z).normalized()

	var speed := SPEED * (SWIM_SPEED_FACTOR if swimming else 1.0)
	_vel.x = dir.x * speed
	_vel.z = dir.z * speed

	# Stair step-up. Voxel rises are quantised to STEP_HEIGHT (0.125), but the
	# capsule's contact normal against a rise is mostly horizontal, so a bare
	# `move_and_slide()` leaves the player stuck at the foot of every step. When
	# we are grounded, pushing horizontally, and already touching a wall, ask the
	# three-stage probe in `resolve_step_up` (rise, then forward) whether the step
	# can be cleared; if it can, the body is lifted and advanced onto it and
	# `move_and_slide()` (with `floor_snap_length = STEP_UP_HEIGHT`) settles it
	# back down onto the new surface. Horizontal velocity is untouched and no
	# vertical velocity is added, so the player WALKS up — never jumps.
	if dir.length_squared() > 0.0 and _body.is_on_floor() and _body.is_on_wall():
		var climbed: Transform3D = resolve_step_up(
			func(xform: Transform3D, motion: Vector3) -> bool: return _body.test_move(xform, motion),
			_body.global_transform,
			Vector3(_vel.x, 0.0, _vel.z) * delta,
			STEP_UP_HEIGHT
		)
		if climbed != _body.global_transform:
			_body.global_position = climbed.origin

	_body.velocity = _vel
	_body.move_and_slide()
	# Sync velocity after slide so gravity accumulation is correct.
	_vel = _body.velocity

	# Keep the player inside the finite world. The CharacterBody3D's physics
	# body is moved directly so the clamp is authoritative for both the visible
	# avatar and collision, without relying on a wall at the world edge.
	if terrain_slice != null and terrain_slice.has_method("clamp_to_world"):
		_body.global_position = WorldPos.wrap_world(terrain_slice.clamp_to_world(_body.global_position - _scene_offset)) + _scene_offset

func _broadcast_state() -> void:
	if not render_visuals:
		return
	var payload := {
		"position": get_position(),
		"hp":       _hp,
		"max_hp":   MAX_HP,
	}
	GameBus.player_state_changed.emit(payload)
	GameBus.player_state_sync_requested.emit(payload)

func _die(killer_id: String = "") -> void:
	_alive = false
	_respawn_timer = RESPAWN_DELAY
	GameBus.player_died.emit(get_position(), killer_id)

## Phase 53 — where a respawn puts the body: the player's own spawn point (game_root sets it from
## the placement), not a fixed world coordinate that may now be open ocean.
var respawn_point := Vector3(16.0, 12.0, 16.0)

func _respawn() -> void:
	_hp = MAX_HP
	_alive = true
	_respawn_timer = -1.0
	# Teleport back to the world spawn point.
	var spawn_pos := respawn_point
	spawn_at(spawn_pos)
	_update_hp_bar()
	_broadcast_state()
	GameBus.player_respawned.emit(spawn_pos)

## Phase 37 — `target_id` names WHICH player took the hit (see the bus signal). This
## body is simulated here, so it takes the damage only when the round was addressed to
## it (see `_is_local_target`); a round aimed at ANOTHER player — a remote peer's id —
## belongs to that peer's own client.
func _on_player_damaged(dmg: float, attacker_id: String, target_id: String = "player") -> void:
	if not _is_local_target(target_id):
		return
	if not _alive:
		return
	take_damage(dmg, attacker_id)

## Whether a player-target id names THIS machine's own body: the local bucket literals
## only — `""` (the `resolve_player` convention) and `"player"` (the id the bus has
## always used for the local body, and the one a client is handed by the wire — see
## NetworkingSlice._route_h2c). A player ID is deliberately NOT accepted here: this
## slice owns exactly one body, and the only ids the host routes to it are those.
func _is_local_target(target_id: String) -> bool:
	return target_id == "" or target_id == "player"

func _try_attack() -> void:
	if not _alive:
		return
	if creature_slice == null:
		Diag.warn("PlayerSlice: creature_slice not wired — cannot resolve attack target")
		return
	var target_id: String = creature_slice.nearest_creature(get_position(), ATTACK_RANGE)
	if target_id == "":
		return   # no creature in range
	var creature_id: String = creature_slice.get_instance_creature_id(target_id)
	GameBus.combat_round_requested.emit("player", target_id)

# ---------------------------------------------------------------------------
# Aim + pickup
# ---------------------------------------------------------------------------

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "HUD"
	_hud.layer = 10

	# Crosshair at screen centre (aim reference point).
	var crosshair := Label.new()
	crosshair.name = "Crosshair"
	crosshair.text = "+"
	crosshair.anchor_left = 0.5
	crosshair.anchor_right = 0.5
	crosshair.anchor_top = 0.5
	crosshair.anchor_bottom = 0.5
	crosshair.offset_left = -12.0
	crosshair.offset_right = 12.0
	crosshair.offset_top = -12.0
	crosshair.offset_bottom = 12.0
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.add_theme_font_size_override("font_size", 22)
	_hud.add_child(crosshair)

	# HP bar — bottom-left corner, updates on every damage/heal event.
	var hp_label := Label.new()
	hp_label.name = "HpLabel"
	hp_label.anchor_left = 0.0
	hp_label.anchor_right = 0.0
	hp_label.anchor_top = 1.0
	hp_label.anchor_bottom = 1.0
	hp_label.offset_left = 12.0
	hp_label.offset_right = 220.0
	hp_label.offset_top = -44.0
	hp_label.offset_bottom = -16.0
	hp_label.add_theme_font_size_override("font_size", 18)
	hp_label.add_theme_color_override("font_color", Color(0.85, 0.20, 0.20))
	_hud.add_child(hp_label)
	_hp_label = hp_label
	_update_hp_bar()

	# Aimed item name (shown only when a pickup is under the crosshair).
	var aim_label := Label.new()
	aim_label.name = "AimLabel"
	aim_label.anchor_left = 0.5
	aim_label.anchor_right = 0.5
	aim_label.anchor_top = 0.5
	aim_label.anchor_bottom = 0.5
	aim_label.offset_left = -200.0
	aim_label.offset_right = 200.0
	aim_label.offset_top = 28.0
	aim_label.offset_bottom = 56.0
	aim_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aim_label.add_theme_font_size_override("font_size", 20)
	aim_label.visible = false
	_hud.add_child(aim_label)
	_aim_label = aim_label

	# Build hint — current place material + mouse-button cues (icons, not text).
	var hint := HBoxContainer.new()
	hint.name = "BuildHint"
	hint.anchor_left = 0.5
	hint.anchor_right = 0.5
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = -340.0
	hint.offset_right = 340.0
	hint.offset_top = -46.0
	hint.offset_bottom = -16.0
	hint.alignment = BoxContainer.ALIGNMENT_CENTER
	hint.add_theme_constant_override("separation", 10)
	_hud.add_child(hint)

	_build_material_label = Label.new()
	_build_material_label.add_theme_font_size_override("font_size", 16)
	hint.add_child(_build_material_label)

	hint.add_child(_make_sep_label())
	hint.add_child(_make_mouse_icon(MOUSE_BUTTON_RIGHT))
	hint.add_child(_make_hint_label("Mine"))
	hint.add_child(_make_sep_label())
	hint.add_child(_make_mouse_icon(MOUSE_BUTTON_MIDDLE))
	hint.add_child(_make_hint_label("Place"))
	hint.add_child(_make_sep_label())
	var cycle_key := Label.new()
	cycle_key.text = "R"
	cycle_key.add_theme_font_size_override("font_size", 16)
	cycle_key.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	hint.add_child(cycle_key)
	hint.add_child(_make_hint_label("Cycle"))

	_station_label = Label.new()
	_station_label.add_theme_font_size_override("font_size", 16)
	_station_label.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	hint.add_child(_station_label)

	_refresh_build_hint()


	add_child(_hud)

func _update_hp_bar() -> void:
	if _hp_label == null:
		return
	var bar := ""
	var filled := int((_hp / MAX_HP) * 10.0)
	for i in range(10):
		bar += "█" if i < filled else "░"
	_hp_label.text = "HP %s %.0f/%.0f" % [bar, _hp, MAX_HP]

func _update_aim() -> void:
	var pid := ""
	var item_id := ""
	var tid := ""
	var tspecies := ""
	_aimed_block_hit = false
	_aimed_block_pos = Vector3.ZERO
	_aimed_block_normal = Vector3.UP
	if _camera != null and _alive:
		var viewport := _camera.get_viewport()
		if viewport != null:
			var center := viewport.get_visible_rect().size * 0.5
			var from := _camera.project_ray_origin(center)
			var dir := _camera.project_ray_normal(center)
			var space := _camera.get_world_3d().direct_space_state
			var block_dist := INF

			# Pickup ray (layer 3).
			var to := from + dir * PICKUP_RANGE
			var query := PhysicsRayQueryParameters3D.create(from, to, PICKUP_COLLISION_MASK)
			query.collide_with_areas = false
			query.collide_with_bodies = true
			var hit := space.intersect_ray(query)
			if not hit.is_empty():
				var collider = hit.get("collider")
				if collider != null and collider.has_meta("pickup_id"):
					pid = str(collider.get_meta("pickup_id"))
					item_id = str(collider.get_meta("item_id"))

			# Block ray (terrain layer 2) — mine/build target.
			var bto := from + dir * BUILD_RANGE
			var bquery := PhysicsRayQueryParameters3D.create(from, bto, TERRAIN_COLLISION_MASK)
			bquery.collide_with_areas = false
			bquery.collide_with_bodies = true
			var bhit := space.intersect_ray(bquery)
			if not bhit.is_empty():
				_aimed_block_hit = true
				_aimed_block_pos = (bhit.get("position", Vector3.ZERO) as Vector3) - _scene_offset
				_aimed_block_normal = bhit.get("normal", Vector3.UP)
				block_dist = from.distance_to(_aimed_block_pos + _scene_offset)

			# Tree ray (layer 4) — chop target. Trees are not on the terrain
			# layer, so this is its own ray; a trunk is only accepted when it is
			# not behind the terrain the block ray already hit.
			var tto := from + dir * CHOP_RANGE
			var tquery := PhysicsRayQueryParameters3D.create(from, tto, TREE_COLLISION_MASK)
			tquery.collide_with_areas = false
			tquery.collide_with_bodies = true
			var thit := space.intersect_ray(tquery)
			if not thit.is_empty():
				var tpos: Vector3 = thit.get("position", Vector3.ZERO)
				var tcollider = thit.get("collider")
				if tcollider != null and tcollider.has_meta("tree_id") and from.distance_to(tpos) <= block_dist:
					tid = str(tcollider.get_meta("tree_id"))
					tspecies = str(tcollider.get_meta("species", ""))
	_aimed_pickup_id = pid
	_aimed_item_id = item_id
	_aimed_tree_id = tid
	_aimed_tree_species = tspecies
	_update_aim_hud()

func _update_aim_hud() -> void:
	if _aim_label == null:
		return
	if _aimed_item_id != "":
		_aim_label.text = "Pick up: %s" % _aimed_item_id
		_aim_label.visible = true
	elif _aimed_tree_id != "":
		_aim_label.text = "Chop: %s (axe)" % _aimed_tree_species
		_aim_label.visible = true
	else:
		_aim_label.text = ""
		_aim_label.visible = false

func _refresh_build_hint() -> void:
	if _build_material_label != null:
		var mat := ""
		if voxel_slice != null and voxel_slice.has_method("get_place_material"):
			mat = str(voxel_slice.get_place_material())
		if mat == "":
			mat = "none"
		_build_material_label.text = "Build: %s" % mat
	if _station_label != null:
		var stype := ""
		if station_slice != null and station_slice.has_method("get_place_station_type"):
			stype = str(station_slice.get_place_station_type())
		if stype == "":
			stype = "none"
		_station_label.text = "  ·  Station: %s" % stype


func _cycle_station_type() -> void:
	if station_slice == null or not station_slice.has_method("cycle_station_type"):
		return
	station_slice.cycle_station_type()
	_refresh_build_hint()


func _place_station() -> void:
	if station_slice == null or not station_slice.has_method("try_place_station"):
		return
	var stype := ""
	if station_slice.has_method("get_place_station_type"):
		stype = str(station_slice.get_place_station_type())
	if stype == "":
		return
	# Grid-snapped and overlap-checked by the slice; a refused spot places nothing.
	var target := _station_target()
	var placed: String = station_slice.try_place_station(stype, target)
	_refresh_build_hint()
	# A refused spot says why, on the same label the selection lives on.
	if placed == "" and _station_label != null and station_slice.has_method("placement_blocker"):
		var why: String = station_slice.placement_blocker(stype, station_slice.snap_to_grid(target))
		if why != "":
			_station_label.text += "  (%s)" % why


## Where a station would go: on top of the aimed terrain block when the aimed
## face points up, else at the player's feet.
func _station_target() -> Vector3:
	if _aimed_block_hit and _aimed_block_normal.y > 0.5:
		return _aimed_block_pos + Vector3(0.0, 0.5, 0.0)
	var pos := get_position()
	pos.y -= 0.4   # feet (-0.9) plus the half-height lift the aimed branch uses
	return pos


## Keep the translucent placement ghost on the current target while the preview
## is toggled on (N).
func _update_station_preview() -> void:
	if not _station_preview_on or station_slice == null or not station_slice.has_method("show_preview"):
		return
	# The ghost must not track the view under an open menu or the loading freeze.
	if not world_input_allowed():
		station_slice.hide_preview()
		return
	var stype := str(station_slice.get_place_station_type()) if station_slice.has_method("get_place_station_type") else ""
	if stype == "":
		station_slice.hide_preview()
		return
	station_slice.show_preview(stype, _station_target())


## Ask to tame the nearest creature within TAME_RANGE (Phase 35). The request goes
## on the bus and TamingSlice decides: it owns the fabric rules, the offering
## consumed from the tamer's inventory, the granted flag and the companion
## binding. The search range here is only what the player can reach; the slice
## re-checks it against its own TAME_RANGE, which is the authority.
func _try_tame() -> void:
	if creature_slice == null or not creature_slice.has_method("nearest_creature"):
		return
	var iid := str(creature_slice.nearest_creature(get_position(), TAME_RANGE))
	if iid == "":
		return
	GameBus.tame_requested.emit(iid)


func _make_mouse_icon(button: int) -> Control:
	var icon: Control = MouseIconScript.new()
	icon.button = button
	icon.custom_minimum_size = Vector2(20, 30)
	return icon


func _make_sep_label() -> Label:
	var sep := Label.new()
	sep.text = "·"
	sep.add_theme_font_size_override("font_size", 16)
	sep.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	return sep


func _make_hint_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	return lbl

func _on_place_material_changed(_material: String) -> void:
	_refresh_build_hint()

func _try_pickup_aimed() -> void:
	var pid := _aimed_pickup_id
	if pid == "":
		return
	GameBus.pickup_requested.emit(pid)
	_aimed_pickup_id = ""
	_aimed_item_id = ""
	_update_aim_hud()

# ---------------------------------------------------------------------------
# Pure helpers (headless-testable — no physics frame needed)
# ---------------------------------------------------------------------------

## Resolve a stair step-up as a pure motion plan, mirroring the Callable-injection
## shape `SkeletonRig.compute_foot_targets` uses for terrain sampling.
##
## `blocked(xform, motion)` answers "would this motion collide?" — production
## passes `PhysicsBody3D.test_move`, and the headless suite passes a fake, because
## the suite runs synchronously inside `GameRoot._ready()` with no physics frame
## to collide with (a `move_and_slide()` there is a silent no-op). The physics the
## body actually performs stays in `_move`.
##
## Returns the transform the body should occupy after climbing a rise no taller
## than `step_height` — RISEN by that step and ADVANCED by `horizontal` — or the
## SAME transform when there is nothing to climb or the rise cannot be cleared
## (a taller step is a wall, not a stair, and must not be climbed or jumped). Only
## a position is produced; no velocity is involved, which is what keeps the
## step-up a walk rather than a jump.
static func resolve_step_up(
	blocked: Callable,
	xform: Transform3D,
	horizontal: Vector3,
	step_height: float
) -> Transform3D:
	# Nothing in the way: not a step-up, leave the body where it is.
	if not blocked.call(xform, horizontal):
		return xform
	# Stage 1 — is there headroom to rise by one step?
	var rise := Vector3.UP * step_height
	if blocked.call(xform, rise):
		return xform
	var lifted := xform.translated(rise)
	# Stage 2 — from up there, is the horizontal move clear?
	if blocked.call(lifted, horizontal):
		return xform
	# Both casts clear: take the rise AND the advance. Settling back down onto the
	# new surface is the physics step's job (`floor_snap_length`).
	return lifted.translated(horizontal)
