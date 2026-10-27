class_name ReliefPlayerController
extends CharacterBody3D

signal step_taken(is_running: bool)
signal device_changed(new_device: DeviceType)

enum DeviceType {
	KEYBOARD_MOUSE,
	GAMEPAD
}

# --- ACTIVE INPUT STATE ---
var current_device: DeviceType = DeviceType.KEYBOARD_MOUSE:
	set(value):
		if current_device != value:
			current_device = value
			emit_signal("device_changed", current_device)

# --- SPEED & MOMENTUM ---
@export_group("Speeds & Physics")
@export var walk_speed: float = 2.4
@export var sprint_speed: float = 4.0
## The speed you run at when stamina is 0 but you refuse to let go of Shift
@export var exhausted_jog_speed: float = 2.8
@export var crouch_speed: float = 1.3
@export var breath_held_speed: float = 1.4
@export var acceleration: float = 8.0
@export var friction: float = 10.0

# --- SENSITIVITY & INPUT TUNING ---
@export_group("Look Sensitivities")
@export var mouse_sensitivity: float = 0.002
@export var gamepad_sensitivity_x: float = 2.6
@export var gamepad_sensitivity_y: float = 2.0
@export var gamepad_deadzone: float = 0.18
@export var gamepad_curve: float = 1.6

# --- HEAD & CAMERA WEIGHT ---
@export_group("Head & Camera Dynamics")
@export var bob_frequency: float = 2.0
@export var bob_amplitude: float = 0.045
@export var sway_amplitude: float = 0.03
@export var roll_angle: float = 0.025

# --- NODES ---
@onready var head: Node3D = $Neck
@onready var camera: Camera3D = $Neck/Camera3D
@onready var stamina: ReliefStamina = get_node_or_null("/root/RELIEF/ReliefStamina")

# Internal States
var _bob_timer: float = 0.0
var _step_phase: float = 0.0
var _camera_initial_pos: Vector3
var _target_roll: float = 0.0
var _is_pushing_jog: bool = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_camera_initial_pos = camera.position


# ==============================================================================
# INPUT DEVICE ARBITRATION
# ==============================================================================

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if event.relative.length_squared() > 1.5:
			current_device = DeviceType.KEYBOARD_MOUSE
			_apply_mouse_look(event.relative)
	elif event is InputEventKey or event is InputEventMouseButton:
		if event.is_pressed():
			current_device = DeviceType.KEYBOARD_MOUSE
	elif event is InputEventJoypadButton:
		if event.is_pressed():
			current_device = DeviceType.GAMEPAD
	elif event is InputEventJoypadMotion:
		if abs(event.axis_value) > gamepad_deadzone:
			current_device = DeviceType.GAMEPAD


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			current_device = DeviceType.KEYBOARD_MOUSE


# ==============================================================================
# CAMERA LOOK
# ==============================================================================

func _apply_mouse_look(relative_motion: Vector2) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	rotate_y(-relative_motion.x * mouse_sensitivity)
	head.rotate_x(-relative_motion.y * mouse_sensitivity)
	head.rotation.x = clamp(head.rotation.x, deg_to_rad(-82), deg_to_rad(82))


func _process_gamepad_look(delta: float) -> void:
	var raw_x: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var raw_y: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	var stick_input: Vector2 = Vector2(raw_x, raw_y)
	var stick_len: float = stick_input.length()
	
	if stick_len > gamepad_deadzone:
		var normalized_len: float = clampf((stick_len - gamepad_deadzone) / (1.0 - gamepad_deadzone), 0.0, 1.0)
		var curved_len: float = pow(normalized_len, gamepad_curve)
		var look_dir: Vector2 = stick_input.normalized() * curved_len
		
		rotate_y(-look_dir.x * gamepad_sensitivity_x * delta)
		head.rotate_x(-look_dir.y * gamepad_sensitivity_y * delta)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-82), deg_to_rad(82))


# ==============================================================================
# PHYSICS & LOCOMOTION
# ==============================================================================

func _physics_process(delta: float) -> void:
	if current_device == DeviceType.GAMEPAD:
		_process_gamepad_look(delta)
	
	var input_dir: Vector2 = Input.get_vector(
		"move_left", "move_right", "move_forward", "move_backward", gamepad_deadzone
	)
	var is_moving: bool = input_dir.length_squared() > 0.01
	var shift_held: bool = Input.is_action_pressed("sprint")
	var is_holding_breath: bool = Input.is_action_pressed("hold_breath") and (stamina.can_hold_breath() if stamina else true)

	var can_sprint: bool = stamina.can_sprint() if stamina else true
	var is_normal_sprint: bool = shift_held and is_moving and is_on_floor() and not is_holding_breath and can_sprint

	# If stamina emptied (or exhausted), but player is still holding Shift while moving:
	if shift_held and is_moving and is_on_floor() and not is_holding_breath and not can_sprint:
		_is_pushing_jog = true
	else:
		_is_pushing_jog = false

	# Feed state to stamina
	if stamina:
		stamina.is_pushing_jog = _is_pushing_jog

	# Select current speed
	var target_speed: float = walk_speed
	if is_normal_sprint:
		target_speed = sprint_speed
	elif _is_pushing_jog:
		target_speed = exhausted_jog_speed # 3.1 m/s (faster than 2.4 walk, no time limit)
	elif is_holding_breath:
		target_speed = breath_held_speed

	# Movement & Inertia
	var move_direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var horizontal_vel: Vector3 = Vector3(velocity.x, 0, velocity.z)
	
	if move_direction.length_squared() > 0.01:
		horizontal_vel = horizontal_vel.lerp(move_direction * target_speed, acceleration * delta)
	else:
		horizontal_vel = horizontal_vel.lerp(Vector3.ZERO, friction * delta)
		
	velocity.x = horizontal_vel.x
	velocity.z = horizontal_vel.z
	
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0
		
	move_and_slide()
	
	# Push RigidBodies
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider is RigidBody3D:
			var push_dir = -collision.get_normal()
			var push_force = 3.0
			var contact_point = collision.get_position()
			collider.apply_impulse(push_dir * push_force, contact_point - collider.global_position)

	# Camera & Head Bob
	var is_running_active: bool = is_normal_sprint or _is_pushing_jog
	_apply_head_bob(delta, horizontal_vel, is_running_active)
	_apply_camera_roll(delta, input_dir.x)


func _apply_head_bob(delta: float, h_velocity: Vector3, is_running: bool) -> void:
	var speed: float = h_velocity.length()
	
	if speed > 0.2 and is_on_floor():
		var freq_mult: float = 1.35 if is_running else 1.0
		_bob_timer += delta * speed * (bob_frequency * freq_mult)
		
		var vertical_dip: float = sin(_bob_timer * 2.0) * bob_amplitude
		var horizontal_sway: float = cos(_bob_timer) * sway_amplitude
		
		camera.position.y = lerp(camera.position.y, _camera_initial_pos.y + vertical_dip, 0.2)
		camera.position.x = lerp(camera.position.x, _camera_initial_pos.x + horizontal_sway, 0.2)
		
		var current_phase: float = sin(_bob_timer * 2.0)
		if _step_phase > 0.0 and current_phase <= 0.0:
			emit_signal("step_taken", is_running)
			if Engine.has_singleton("ReliefHaptics") or get_node_or_null("/root/ReliefHaptics"):
				ReliefHaptics.play_footstep(is_running)
		_step_phase = current_phase
	else:
		_bob_timer = 0.0
		camera.position = camera.position.lerp(_camera_initial_pos, 8.0 * delta)


func _apply_camera_roll(delta: float, strafe_input: float) -> void:
	_target_roll = -strafe_input * roll_angle
	camera.rotation.z = lerp(camera.rotation.z, _target_roll, 6.0 * delta)
