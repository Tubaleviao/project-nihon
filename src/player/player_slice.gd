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

const SPEED        := 4.5     # m/s horizontal
const JUMP_FORCE   := 5.0     # m/s vertical
const GRAVITY      := -9.8    # m/s²
const MOUSE_SENS   := 0.002   # radians per pixel
const CAMERA_PITCH_MIN := -80.0
const CAMERA_PITCH_MAX :=  80.0
const SYNC_INTERVAL := 30     # physics ticks between network sync broadcasts
const ATTACK_RANGE := 3.0     # metres — melee interaction radius
const PICKUP_RANGE := 8.0     # metres — how far the player can aim-pick
const PICKUP_COLLISION_MASK := 4   # layer 3 (bit 2) — matches loot pickup bodies
const BUILD_RANGE := 8.0      # metres — how far the player can reach a block
const TERRAIN_COLLISION_MASK := 2  # layer 2 (bit 1) — terrain, for mine/build ray

const MAX_HP := 100.0

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

## HP bar label — updated on every damage/heal event.
var _hp_label: Label = null

## Respawn countdown in seconds; -1 when not respawning.
const RESPAWN_DELAY := 5.0
var _respawn_timer: float = -1.0

## Remote player ghosts (Phase 18). Keyed by peer_id → { "body": Node3D,
## "from": Vector3, "to": Vector3, "t": float }. Each ghost is a simple
## visual-only body (no physics) that interpolates from the previous snapshot
## to the latest one, so remote movement renders smoothly between host ticks.
var _ghosts: Dictionary = {}
const GHOST_INTERP_TIME := 0.1   # seconds to blend between two snapshots

## Set by game_root after all slices are instantiated.
var creature_slice: Node = null
var voxel_slice: Node = null
var station_slice: Node = null
var terrain_slice: Node = null

func _ready() -> void:
	_build_body()
	_build_hud()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	GameBus.block_place_material_changed.connect(_on_place_material_changed)
	GameBus.player_damaged.connect(_on_player_damaged)
	GameBus.remote_player_state.connect(_on_remote_player_state)

func _physics_process(delta: float) -> void:
	if not _alive:
		if _respawn_timer > 0.0:
			_respawn_timer -= delta
			if _respawn_timer <= 0.0:
				_respawn()
		return
	_move(delta)
	_sync_tick += 1
	if _sync_tick >= SYNC_INTERVAL:
		_sync_tick = 0
		_broadcast_state()

func _process(delta: float) -> void:
	_update_aim()
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
	# All world actions below require a captured mouse. While a UI window is
	# open the UI slice keeps the mouse visible, so this guard prevents
	# attacking, mining, or placing through an open menu. ESC (mouse capture
	# toggle) is owned by the UI slice now.
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	# Left-click: pick up an aimed item if there is one, otherwise attack.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _aimed_pickup_id != "":
			_try_pickup_aimed()
		else:
			_try_attack()
	# F key → melee attack the nearest creature in range.
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		_try_attack()
	# Right-click → mine the aimed terrain block.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if _aimed_block_hit:
			GameBus.block_mine_requested.emit(_aimed_block_pos, _aimed_block_normal)
	# Middle-click → place a block against the aimed terrain face.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_MIDDLE:
		if _aimed_block_hit:
			GameBus.block_place_requested.emit(_aimed_block_pos, _aimed_block_normal)
	# R key → cycle the build material.
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		GameBus.block_cycle_material_requested.emit()
	# B key → cycle the station type to place.
	if event is InputEventKey and event.pressed and event.keycode == KEY_B:
		_cycle_station_type()
	# V key → place the selected station at the player's feet.
	if event is InputEventKey and event.pressed and event.keycode == KEY_V:
		_place_station()

func get_position() -> Vector3:
	return _body.global_position if _body else Vector3.ZERO

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
		_body.global_position = pos
		_vel = Vector3.ZERO

func get_hp() -> float:
	return _hp

## Number of remote player ghosts currently tracked.
func get_remote_ghost_count() -> int:
	return _ghosts.size()

## Remote player ghosts — a client renders other players as visual-only bodies
## (no local input, no physics) that interpolate between host snapshots.
func _on_remote_player_state(peer_id: int, position: Vector3) -> void:
	# Never ghost our own local player: the host echoes a client's movement back
	# to every peer (including the originator), and that echo must not spawn a
	# ghost of ourselves.
	if peer_id == multiplayer.get_unique_id():
		return
	if not _ghosts.has(peer_id):
		var body := _make_ghost_body()
		body.position = position
		_ghosts[peer_id] = {
			"body": body,
			"from": position,
			"to":   position,
			"t":    1.0,
		}
		return
	var g: Dictionary = _ghosts[peer_id]
	g["from"] = g["body"].position
	g["to"]   = position
	g["t"]    = 0.0

func _tick_ghosts(delta: float) -> void:
	for peer_id in _ghosts:
		var g: Dictionary = _ghosts[peer_id]
		g["t"] = minf(g["t"] + delta / GHOST_INTERP_TIME, 1.0)
		g["body"].position = g["from"].lerp(g["to"], g["t"])

func _make_ghost_body() -> Node3D:
	var body := Node3D.new()
	body.name = "RemotePlayer"
	var mesh := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.4
	cap.height = 1.8
	mesh.mesh = cap
	mesh.position = Vector3(0.0, 0.9, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.55, 0.90)   # blue — distinct from the local player
	mesh.material_override = mat
	body.add_child(mesh)
	add_child(body)
	return body

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

	# Spawn above the terrain origin so the player lands on the voxel surface.
	_body.global_position = Vector3(16.0, 12.0, 16.0)

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	col.shape   = cap
	col.position = Vector3(0, 0.9, 0)
	_body.add_child(col)

	# Yaw pivot (child of body so it inherits position but NOT rotation from physics).
	_pivot = Node3D.new()
	_pivot.name = "YawPivot"
	_body.add_child(_pivot)

	# Camera arm (controls pitch).
	var cam_arm := Node3D.new()
	cam_arm.name = "CamArm"
	cam_arm.position = Vector3(0, 1.6, 0)   # eye height
	_pivot.add_child(cam_arm)

	_camera = Camera3D.new()
	_camera.name = "PlayerCamera"
	_camera.position = Vector3(0, 0, 0)
	_camera.current  = true
	cam_arm.add_child(_camera)

func _move(delta: float) -> void:
	# Apply gravity.
	if not _body.is_on_floor():
		_vel.y += GRAVITY * delta
	else:
		if _vel.y < 0.0:
			_vel.y = 0.0

	# Jump.
	if Input.is_action_just_pressed("ui_accept") and _body.is_on_floor():
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

	_vel.x = dir.x * SPEED
	_vel.z = dir.z * SPEED

	_body.velocity = _vel
	_body.move_and_slide()
	# Sync velocity after slide so gravity accumulation is correct.
	_vel = _body.velocity

	# Keep the player inside the finite world. The CharacterBody3D's physics
	# body is moved directly so the clamp is authoritative for both the visible
	# avatar and collision, without relying on a wall at the world edge.
	if terrain_slice != null and terrain_slice.has_method("clamp_to_world"):
		_body.global_position = terrain_slice.clamp_to_world(_body.global_position)

func _broadcast_state() -> void:
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
	print("PlayerSlice: player died at %s — respawning in %.0fs" % [get_position(), RESPAWN_DELAY])
	GameBus.player_died.emit(get_position(), killer_id)

func _respawn() -> void:
	_hp = MAX_HP
	_alive = true
	_respawn_timer = -1.0
	# Teleport back to the world spawn point.
	var spawn_pos := Vector3(16.0, 12.0, 16.0)
	spawn_at(spawn_pos)
	_update_hp_bar()
	_broadcast_state()
	GameBus.player_respawned.emit(spawn_pos)
	print("PlayerSlice: player respawned at %s" % spawn_pos)

func _on_player_damaged(dmg: float, attacker_id: String) -> void:
	if not _alive:
		return
	take_damage(dmg, attacker_id)

func _try_attack() -> void:
	if not _alive:
		return
	if creature_slice == null:
		push_warning("PlayerSlice: creature_slice not wired — cannot resolve attack target")
		return
	var target_id: String = creature_slice.nearest_creature(get_position(), ATTACK_RANGE)
	if target_id == "":
		return   # no creature in range
	var creature_id: String = creature_slice.get_instance_creature_id(target_id)
	print("PlayerSlice: attacking %s [%s]" % [creature_id, target_id])
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

	_build_shortcuts_menu()

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
				_aimed_block_pos = bhit.get("position", Vector3.ZERO)
				_aimed_block_normal = bhit.get("normal", Vector3.UP)
	_aimed_pickup_id = pid
	_aimed_item_id = item_id
	_update_aim_hud()

func _update_aim_hud() -> void:
	if _aim_label == null:
		return
	if _aimed_item_id == "":
		_aim_label.text = ""
		_aim_label.visible = false
	else:
		_aim_label.text = "Pick up: %s" % _aimed_item_id
		_aim_label.visible = true

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
	if station_slice == null or not station_slice.has_method("place_station"):
		return
	var stype := ""
	if station_slice.has_method("get_place_station_type"):
		stype = str(station_slice.get_place_station_type())
	if stype == "":
		return
	var pos := get_position()
	pos.y -= 0.9   # sit the marker at the player's feet
	station_slice.place_station(stype, pos)
	_refresh_build_hint()


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


func _build_shortcuts_menu() -> void:
	var panel := PanelContainer.new()
	panel.name = "ShortcutsMenu"
	panel.position = Vector2(12, 12)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.09, 0.55)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Controls"
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	vbox.add_child(title)

	_add_key_row(vbox, "WASD", "Move")
	_add_key_row(vbox, "Space", "Jump")
	_add_mouse_row(vbox, MOUSE_BUTTON_LEFT, "Attack / Pick up")
	_add_mouse_row(vbox, MOUSE_BUTTON_RIGHT, "Mine")
	_add_mouse_row(vbox, MOUSE_BUTTON_MIDDLE, "Place")
	_add_key_row(vbox, "R", "Cycle material")
	_add_key_row(vbox, "B · V", "Station cycle / place")
	_add_key_row(vbox, "I · T · C", "Windows")
	_add_key_row(vbox, "ESC", "Cursor")

	_hud.add_child(panel)
	panel.reset_size()


func _add_mouse_row(box: VBoxContainer, button: int, desc: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(56, 30)
	holder.add_child(_make_mouse_icon(button))
	row.add_child(holder)
	row.add_child(_make_menu_label(desc))
	box.add_child(row)


func _add_key_row(box: VBoxContainer, key: String, desc: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var key_label := Label.new()
	key_label.text = key
	key_label.add_theme_font_size_override("font_size", 15)
	key_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	key_label.custom_minimum_size = Vector2(56, 0)
	row.add_child(key_label)
	row.add_child(_make_menu_label(desc))
	box.add_child(row)


func _make_menu_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 15)
	return lbl

func _on_place_material_changed(_material: String) -> void:
	_refresh_build_hint()

func _try_pickup_aimed() -> void:
	var pid := _aimed_pickup_id
	if pid == "":
		return
	print("PlayerSlice: picking up %s [%s]" % [_aimed_item_id, pid])
	GameBus.pickup_requested.emit(pid)
	_aimed_pickup_id = ""
	_aimed_item_id = ""
	_update_aim_hud()
