extends CharacterBody3D

const SPEED := 2.8
const ACCEL := 9.0          # lower = heavier start
const DECEL := 13.0         # lower = longer stop
const MOUSE_SENS := 0.0025
const LOOK_SMOOTH := 33.0   # lower = floatier camera
const STRIDE := 0.25         # lower = slower steps
const BOB_Y := 0.03         # up/down amount
const BOB_X := 0.02         # side sway amount

@onready var neck: Node3D = $Neck
@onready var camera: Camera3D = $Neck/Camera3D

var target_yaw := 0.0
var target_pitch := 0.0
var bob_time := 0.0
var bob_blend := 0.0

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

	# Head bob (fades in and out smoothly)
	var speed := Vector2(velocity.x, velocity.z).length()
	var moving := is_on_floor() and speed > 0.2
	bob_blend = move_toward(bob_blend, 1.0 if moving else 0.0, delta * 4.0)
	bob_time += delta * speed * STRIDE
	var phase := bob_time * TAU
	camera.position.y = sin(phase * 2.0) * BOB_Y * bob_blend
	camera.position.x = sin(phase) * BOB_X * bob_blend
