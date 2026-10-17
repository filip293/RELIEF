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
@export var crouch_speed: float = 1.3
@export var breath_held_speed: float = 1.4 # <-- Tense, slow creep
@export var acceleration: float = 8.0
@export var friction: float = 10.0

# --- SENSITIVITY & INPUT TUNING ---
@export_group("Look Sensitivities")
@export var mouse_sensitivity: float = 0.002
## Gamepad look speed in radians per second
@export var gamepad_sensitivity_x: float = 2.6
@export var gamepad_sensitivity_y: float = 2.0
## Stick deadzone to prevent stick drift from hijacking the device focus
@export var gamepad_deadzone: float = 0.18
## Exponent for analog stick precision (1.0 = linear, 2.0 = exponential ramp)
@export var gamepad_curve: float = 1.6

# --- HEAD & CAMERA WEIGHT ---
@export_group("Head & Camera Dynamics")
@export var bob_frequency: float = 2.0
@export var bob_amplitude: float = 0.045
@export var sway_amplitude: float = 0.03
@export var roll_angle: float = 0.025 # Radians to tilt during strafing

# --- NODES ---
@onready var head: Node3D = $Neck
@onready var camera: Camera3D = $Neck/Camera3D
@onready var stamina: ReliefStamina = get_node_or_null("/root/RELIEF/ReliefStamina")

# Internal States
var _bob_timer: float = 0.0
var _step_phase: float = 0.0
var _camera_initial_pos: Vector3
var _target_roll: float = 0.0
var _gamepad_look_vector: Vector2 = Vector2.ZERO


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_camera_initial_pos = camera.position


# ==============================================================================
# INPUT DEVICE ARBITRATION (LAST ACTIVE TAKES PRIORITY)
# ==============================================================================

func _input(event: InputEvent) -> void:
	# 1. Detect Mouse & Keyboard Activity
	if event is InputEventMouseMotion:
		# Threshold prevents optical sensor micro-tremors from hijacking controller
		if event.relative.length_squared() > 1.5:
			current_device = DeviceType.KEYBOARD_MOUSE
			_apply_mouse_look(event.relative)
			
	elif event is InputEventKey or event is InputEventMouseButton:
		if event.is_pressed():
			current_device = DeviceType.KEYBOARD_MOUSE

	# 2. Detect Gamepad Activity
	elif event is InputEventJoypadButton:
		if event.is_pressed():
			current_device = DeviceType.GAMEPAD
			
	elif event is InputEventJoypadMotion:
		if abs(event.axis_value) > gamepad_deadzone:
			current_device = DeviceType.GAMEPAD


func _unhandled_input(event: InputEvent) -> void:
	# Clicking back into the window recaptures mouse
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			current_device = DeviceType.KEYBOARD_MOUSE


# ==============================================================================
# CAMERA & LOOK HANDLING
# ==============================================================================

func _apply_mouse_look(relative_motion: Vector2) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	rotate_y(-relative_motion.x * mouse_sensitivity)
	head.rotate_x(-relative_motion.y * mouse_sensitivity)
	head.rotation.x = clamp(head.rotation.x, deg_to_rad(-82), deg_to_rad(82))


func _process_gamepad_look(delta: float) -> void:
	# Query right stick input via actions or raw axes
	var raw_x: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var raw_y: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	
	# Apply radial deadzone
	var stick_input: Vector2 = Vector2(raw_x, raw_y)
	var stick_len: float = stick_input.length()
	
	if stick_len > gamepad_deadzone:
		# Rescale magnitude to eliminate deadzone jump
		var normalized_len: float = clampf((stick_len - gamepad_deadzone) / (1.0 - gamepad_deadzone), 0.0, 1.0)
		var curved_len: float = pow(normalized_len, gamepad_curve)
		var look_dir: Vector2 = stick_input.normalized() * curved_len
		
		# Rotate body and head
		rotate_y(-look_dir.x * gamepad_sensitivity_x * delta)
		head.rotate_x(-look_dir.y * gamepad_sensitivity_y * delta)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-82), deg_to_rad(82))


# ==============================================================================
# PHYSICS & LOCOMOTION
# ==============================================================================

func _physics_process(delta: float) -> void:
	# Poll analog stick look continuous motion
	if current_device == DeviceType.GAMEPAD:
		_process_gamepad_look(delta)
	
	var input_dir: Vector2 = Input.get_vector(
		"move_left", "move_right", "move_forward", "move_backward", gamepad_deadzone
	)
	# 1. Determine Movement State with Stamina Enforcement
	var is_moving: bool = input_dir.length_squared() > 0.01
	
	# Check breath holding (locks out sprint)
	var is_holding_breath: bool = Input.is_action_pressed("hold_breath") and (stamina.can_hold_breath() if stamina else true)
	
	# Sprint is only possible if NOT holding breath and stamina permits
	var wants_to_sprint: bool = Input.is_action_pressed("sprint") and is_on_floor() and is_moving and not is_holding_breath
	var can_sprint: bool = stamina.can_sprint() if stamina else true
	var is_sprinting: bool = wants_to_sprint and can_sprint

	# Determine Target Speed
	var target_speed: float = walk_speed
	if is_sprinting:
		target_speed = sprint_speed
	elif is_holding_breath:
		target_speed = breath_held_speed # <-- Slow down to a cautious creep
	
	# 2. Movement Direction (Supports WASD and Left Joystick smoothly)
	var move_direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# 3. Acceleration / Friction Inertia
	var horizontal_vel: Vector3 = Vector3(velocity.x, 0, velocity.z)
	if move_direction.length_squared() > 0.01:
		horizontal_vel = horizontal_vel.lerp(move_direction * target_speed, acceleration * delta)
	else:
		horizontal_vel = horizontal_vel.lerp(Vector3.ZERO, friction * delta)
		
	velocity.x = horizontal_vel.x
	velocity.z = horizontal_vel.z
	
	# Gravity
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0
		
	move_and_slide()
	
	# 4. Human Body Sway & Step Detection
	_apply_head_bob(delta, horizontal_vel, is_sprinting)
	_apply_camera_roll(delta, input_dir.x)


func _apply_head_bob(delta: float, h_velocity: Vector3, is_sprinting: bool) -> void:
	var speed: float = h_velocity.length()
	
	if speed > 0.2 and is_on_floor():
		var freq_mult: float = 1.35 if is_sprinting else 1.0
		_bob_timer += delta * speed * (bob_frequency * freq_mult)
		
		# Figure-8 step cycle
		var vertical_dip: float = sin(_bob_timer * 2.0) * bob_amplitude
		var horizontal_sway: float = cos(_bob_timer) * sway_amplitude
		
		camera.position.y = lerp(camera.position.y, _camera_initial_pos.y + vertical_dip, 0.2)
		camera.position.x = lerp(camera.position.x, _camera_initial_pos.x + horizontal_sway, 0.2)
		
		# Trigger step at the bottom of the foot swing
		var current_phase: float = sin(_bob_timer * 2.0)
		if _step_phase > 0.0 and current_phase <= 0.0:
			emit_signal("step_taken", is_sprinting)
			ReliefHaptics.play_footstep(is_sprinting)
		_step_phase = current_phase
	else:
		_bob_timer = 0.0
		camera.position = camera.position.lerp(_camera_initial_pos, 8.0 * delta)


func _apply_camera_roll(delta: float, strafe_input: float) -> void:
	_target_roll = -strafe_input * roll_angle
	camera.rotation.z = lerp(camera.rotation.z, _target_roll, 6.0 * delta)
