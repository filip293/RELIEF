extends Node

@onready var player: ReliefPlayerController = get_parent()
@onready var camera: Camera3D = $"../Neck/Camera3D"

# --- SETTINGS ---
@export_group("Opening Sequence")
@export var wait_before_standing: float = 15.0

@export_group("Sitting Position")
@export var sitting_offset: Vector3 = Vector3(0.7, -0.35, 0)
@export var sitting_look_down: float = -20.0
@export var sitting_look_side: float = 0.0

@export_group("Idle Camera Movement")
@export var breathing_strength: float = 0.006
@export var breathing_speed: float = 1.4
@export var idle_pitch_strength: float = 0.8
@export var idle_yaw_strength: float = 1.0

@export_group("Seated Look Limits")
@export var max_look_left_right: float = 50.0
@export var max_look_up: float = 20.0
@export var max_look_down: float = 25.0

var mouse_yaw: float = 0.0
var mouse_pitch: float = 0.0


# --- INTERNAL VARIABLES ---
var standing_position: Vector3
var standing_rotation: Vector3

var sitting_position: Vector3
var sitting_rotation: Vector3

var idle_timer: float = 0.0
var is_waiting: bool = false


func _ready() -> void:
	# Disable movement and mouse look.
	player.controls_locked = true

	# Let the Player initialize its camera first.
	await get_tree().process_frame

	# Remember the normal standing position.
	standing_position = camera.position
	standing_rotation = camera.rotation_degrees

	# Set the seated camera position.
	sitting_position = standing_position + sitting_offset

	sitting_rotation = standing_rotation + Vector3(
		sitting_look_down,
		sitting_look_side,
		0.0
	)

	camera.position = sitting_position
	camera.rotation_degrees = sitting_rotation

	# Begin subtle idle movement.
	is_waiting = true

	# Wait for the opening radio conversation.
	await get_tree().create_timer(wait_before_standing).timeout

	# Stop idle movement before the animation.
	is_waiting = false

	# Start standing sequence.
	await stand_up()

	# Enable movement and mouse look.
	player.controls_locked = false

func _input(event: InputEvent) -> void:
	if not is_waiting:
		return

	if event is InputEventMouseMotion:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			return

		var sensitivity: float = player.mouse_sensitivity

		# Horizontal movement.
		mouse_yaw -= rad_to_deg(
			event.screen_relative.x * sensitivity
		)

		# Vertical movement.
		mouse_pitch -= rad_to_deg(
			event.screen_relative.y * sensitivity
		)

		# Prevent looking too far left or right.
		mouse_yaw = clampf(
			mouse_yaw,
			-max_look_left_right,
			max_look_left_right
		)

		# Prevent looking too far up or down.
		mouse_pitch = clampf(
			mouse_pitch,
			-max_look_down,
			max_look_up
		)
# ==============================================================================
# SUBTLE IDLE CAMERA MOVEMENT
# ==============================================================================

func _process(delta: float) -> void:
	if not is_waiting:
		return

	idle_timer += delta

	# Very subtle vertical breathing movement.
	var breathing: float = sin(
		idle_timer * breathing_speed
	) * breathing_strength

	# Small natural head movements.
	var pitch_movement: float = sin(
		idle_timer * 0.8
	) * idle_pitch_strength

	var yaw_movement: float = sin(
		idle_timer * 0.5
	) * idle_yaw_strength

	# Apply the movements.
	camera.position = sitting_position + Vector3(
		0.0,
		breathing,
		0.0
	)

	camera.rotation_degrees = sitting_rotation + Vector3(
		mouse_pitch + pitch_movement,
		mouse_yaw + yaw_movement,
		0.0
)

# ==============================================================================
# STANDING ANIMATION
# ==============================================================================

func stand_up() -> void:

	# STEP 1: Slowly look away from the control panel.
	var pan: Tween = create_tween()

	pan.set_trans(Tween.TRANS_SINE)
	pan.set_ease(Tween.EASE_IN_OUT)

	pan.tween_property(
		camera,
		"rotation_degrees",
		standing_rotation + Vector3(-3.0, 8.0, 0.0),
		1.5
	)

	await pan.finished

# Play the chair creak as Ellis begins standing.
	var chair_creak: AudioStreamPlayer3D = (
		get_tree().get_first_node_in_group("opening_chair_creak")
		as AudioStreamPlayer3D
)

	if chair_creak != null and chair_creak.stream != null:
		chair_creak.play()
			# Stop after 2 seconds.
		get_tree().create_timer(2.0).timeout.connect(chair_creak.stop)

# STEP 2: Slowly stand up.
	var stand: Tween = create_tween()

	stand.set_parallel(true)
	stand.set_trans(Tween.TRANS_SINE)
	stand.set_ease(Tween.EASE_IN_OUT)

	# Slowly raise the camera.
	stand.tween_property(
		camera,
		"position",
		standing_position,
		2.8
	)

	# Return the camera to its normal local rotation.
	stand.tween_property(
		camera,
		"rotation_degrees",
		standing_rotation,
		2.8
	)

	# Turn Ellis's entire body 70 degrees left.
	stand.tween_property(
		player,
		"rotation_degrees:y",
		player.rotation_degrees.y + 70.0,
		2.8
	)

	await stand.finished
