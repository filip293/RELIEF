extends CharacterBody3D

const SPEED := 2.1
const ACCEL := 9.0          # lower = heavier start
const DECEL := 13.0         # lower = longer stop
const MOUSE_SENS := 0.0025
const LOOK_SMOOTH := 33.0   # lower = floatier camera
const STRIDE := 0.25        # lower = slower steps
const BOB_Y := 0.04         # up/down amount
const BOB_X := 0.02         # side sway amount

@export_category("Footsteps")
@export var footstep_sounds: Array[AudioStream] = []
@export var footstep_pitch_min := 0.9
@export var footstep_pitch_max := 1.1

@onready var neck: Node3D = $Neck
@onready var camera: Camera3D = $Neck/Camera3D
@onready var footstep_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

var target_yaw := 0.0
var target_pitch := 0.0
var bob_time := 0.0
var bob_blend := 0.0
var is_left_step := false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	target_yaw = rotation.y
	target_pitch = neck.rotation.x

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		target_yaw -= event.relative.x * MOUSE_SENS
		target_pitch = clampf(target_pitch - event.relative.y * MOUSE_SENS, deg_to_rad(-85), deg_to_rad(85))

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	var input_dir := Input.get_vector("Left", "Right", "Forward", "Back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var horizontal := Vector3(velocity.x, 0, velocity.z)
	var rate := ACCEL if direction != Vector3.ZERO else DECEL
	horizontal = horizontal.move_toward(direction * SPEED, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()

func _process(delta: float) -> void:
	# Smoothed mouse look
	var t := 1.0 - exp(-LOOK_SMOOTH * delta)
	rotation.y = lerp_angle(rotation.y, target_yaw, t)
	neck.rotation.x = lerp(neck.rotation.x, target_pitch, t)

	# Head bob & Phase-synced Footstep logic
	var speed := Vector2(velocity.x, velocity.z).length()
	var moving := is_on_floor() and speed > 0.2
	bob_blend = move_toward(bob_blend, 1.0 if moving else 0.0, delta * 4.0)

	if moving:
		# Step logic synced to trigger twice per full head bob cycle (2.0 instead of 4.0)
		var prev_step := floori((bob_time - 0.125) * 2.0)
		bob_time += delta * speed * STRIDE
		var curr_step := floori((bob_time - 0.125) * 2.0)
		
		if curr_step > prev_step:
			_play_footstep()
	else:
		bob_time += delta * speed * STRIDE

	var phase := bob_time * TAU
	camera.position.y = sin(phase * 2.0) * BOB_Y * bob_blend
	camera.position.x = sin(phase) * BOB_X * bob_blend

func _play_footstep() -> void:
	if footstep_player and not footstep_sounds.is_empty():
		is_left_step = not is_left_step
		
		# Shift the single player's local X position left or right to alternate spatial panning
		footstep_player.position.x = -0.3 if is_left_step else 0.3
		
		footstep_player.stream = footstep_sounds[randi() % footstep_sounds.size()]
		footstep_player.pitch_scale = randf_range(footstep_pitch_min, footstep_pitch_max)
		footstep_player.play()
