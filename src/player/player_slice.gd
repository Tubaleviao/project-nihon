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

const MAX_HP := 100.0

var _body:   CharacterBody3D
var _camera: Camera3D
var _pivot:  Node3D           # horizontal yaw pivot under _body
var _hp:     float = MAX_HP
var _vel:    Vector3 = Vector3.ZERO
var _sync_tick: int = 0
var _alive: bool = true

## Set by game_root after all slices are instantiated.
var creature_slice: Node = null

func _ready() -> void:
	_build_body()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	if not _alive:
		return
	_move(delta)
	_sync_tick += 1
	if _sync_tick >= SYNC_INTERVAL:
		_sync_tick = 0
		_broadcast_state()

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
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Left-click or F key → melee attack the nearest creature in range.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_attack()
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		_try_attack()

func get_position() -> Vector3:
	return _body.global_position if _body else Vector3.ZERO

func get_hp() -> float:
	return _hp

func take_damage(dmg: float) -> void:
	_hp = maxf(_hp - dmg, 0.0)
	_broadcast_state()
	if _hp <= 0.0 and _alive:
		_die()

# ---------------------------------------------------------------------------
# Private
# ---------------------------------------------------------------------------

func _build_body() -> void:
	# Build the scene tree entirely in code so no .tscn file is needed.
	_body = CharacterBody3D.new()
	_body.name = "PlayerBody"
	add_child(_body)

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

func _broadcast_state() -> void:
	var payload := {
		"position": get_position(),
		"hp":       _hp,
		"max_hp":   MAX_HP,
	}
	GameBus.player_state_changed.emit(payload)
	GameBus.player_state_sync_requested.emit(payload)

func _die() -> void:
	_alive = false
	print("PlayerSlice: player died at %s" % get_position())
	GameBus.creature_died.emit("player", get_position(), "")

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
