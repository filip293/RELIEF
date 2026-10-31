extends Node3D

# ============================================================
# SETTINGS
# ============================================================

@export_group("Interaction")

@export var interaction_distance: float = 2.0
@export var interact_action: StringName = &"interact"


@export_group("Door Animation")

@export var door_open_angle: float = 95.0
@export var door_animation_duration: float = 0.85


@export_group("Hiding Camera")

# Position relative to the locker scene root.
# Adjust in Inspector to position the camera inside the locker.

@export var hiding_position: Vector3 = Vector3(0.0, 1.45, 0.0)

@export var hiding_rotation: Vector3 = Vector3.ZERO

@export var entering_duration: float = 0.8
@export var exiting_duration: float = 0.7


@export_group("Hidden Camera Movement")

@export var max_look_left_right: float = 45.0

@export var max_look_up: float = 25.0

@export var max_look_down: float = 30.0


@export_group("Locker Sounds")

@export var opening_sound: AudioStream
@export var closing_sound: AudioStream

@onready var locker_sfx: AudioStreamPlayer3D = $LockerSFX


# ============================================================
# NODES
# ============================================================

@onready var locker_body: Node3D = (
	$Sketchfab_model/Metal_Locker_fbx/Object_2/RootNode/Locker_Body
)

@onready var locker_door: Node3D = (
	$Sketchfab_model/Metal_Locker_fbx/Object_2/RootNode/Locker_Body/Locker_Door
)




# ============================================================
# VARIABLES
# ============================================================

var hidden_player: ReliefPlayerController = null

var player_camera: Camera3D = null

var is_busy: bool = false

var original_camera_transform: Transform3D

var original_collision_layer: int = 0
var original_collision_mask: int = 0

var closed_door_rotation: float = 0.0

var look_yaw: float = 0.0
var look_pitch: float = 0.0


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	closed_door_rotation = locker_door.rotation.z

	if not InputMap.has_action(interact_action):
		push_warning("Locker: Input action 'interact' does not exist.")


# ============================================================
# FIND PLAYER AND EXISTING RAYCAST
# ============================================================

func _get_player() -> ReliefPlayerController:

	var camera: Camera3D = get_viewport().get_camera_3d()

	if camera == null:
		return null

	# Your player structure:
	# Player -> Neck -> Camera3D

	var player: ReliefPlayerController = (
		camera.get_parent().get_parent() as ReliefPlayerController
	)

	return player


func _get_interaction_ray() -> RayCast3D:

	var camera: Camera3D = get_viewport().get_camera_3d()

	if camera == null:
		return null

	# Find the existing camera raycast.
	var rays: Array[Node] = camera.find_children(
		"*",
		"RayCast3D",
		true,
		false
	)

	if rays.is_empty():
		return null

	return rays[0] as RayCast3D


# ============================================================
# CHECK IF PLAYER IS LOOKING AT THIS LOCKER
# ============================================================

func _is_looking_at_locker() -> bool:

	var ray: RayCast3D = _get_interaction_ray()

	if ray == null:
		return false

	# Update collision immediately.
	ray.force_raycast_update()

	if not ray.is_colliding():
		return false

	var hit: Object = ray.get_collider()

	if not hit is Node:
		return false

	# The StaticBody3D is nested inside the locker mesh.
	# We check whether the ray hit any descendant
	# of this locker's body.

	if not locker_body.is_ancestor_of(hit as Node):
		return false

	# Make sure the player is close enough.

	var camera: Camera3D = get_viewport().get_camera_3d()

	var distance: float = camera.global_position.distance_to(
		ray.get_collision_point()
	)

	return distance <= interaction_distance


# ============================================================
# INTERACTION
# ============================================================

func _unhandled_input(event: InputEvent) -> void:

	if is_busy:
		return

	if not event.is_action_pressed(interact_action):
		return

	if event is InputEventKey and event.echo:
		return

	# --------------------------------------------------------
	# PLAYER IS ALREADY HIDING
	# --------------------------------------------------------

	if hidden_player != null:

		_exit_locker()

		get_viewport().set_input_as_handled()

		return

	# --------------------------------------------------------
	# PLAYER WANTS TO ENTER
	# --------------------------------------------------------

	var player: ReliefPlayerController = _get_player()

	if player == null:
		return

	if player.controls_locked:
		return

	if player.is_hidden:
		return

	if not _is_looking_at_locker():
		return

	_enter_locker(player)

	get_viewport().set_input_as_handled()


# ============================================================
# ENTER LOCKER
# ============================================================

func _enter_locker(player: ReliefPlayerController) -> void:

	is_busy = true

	hidden_player = player

	player_camera = player.camera

	# Remember the camera's position before hiding.
	original_camera_transform = player_camera.global_transform

	# Remember collision settings.
	original_collision_layer = player.collision_layer
	original_collision_mask = player.collision_mask

	# Reset hidden camera rotation.
	look_yaw = 0.0
	look_pitch = 0.0

	# Disable player movement and normal camera look.
	player.controls_locked = true

	player.velocity = Vector3.ZERO

	# Player body stays in its original position.
	# Disable collision while hiding.
	player.collision_layer = 0
	player.collision_mask = 0


	# Open locker.
	await _animate_door(true)

	# Move camera inside.
	await _move_camera(
		_get_hiding_transform(),
		entering_duration
	)

	# Close locker.
	await _animate_door(false)

	# Tell future monster AI that Ellis is hidden.
	player.is_hidden = true

	is_busy = false


# ============================================================
# EXIT LOCKER
# ============================================================

func _exit_locker() -> void:

	if hidden_player == null:
		return

	is_busy = true


	# Open the door.
	await _animate_door(true)

	# Move the camera back outside.
	await _move_camera(
		original_camera_transform,
		exiting_duration
	)

	# Close the door.
	await _animate_door(false)

	# Restore collisions.
	hidden_player.collision_layer = original_collision_layer
	hidden_player.collision_mask = original_collision_mask

	# Restore normal gameplay.
	hidden_player.is_hidden = false
	hidden_player.controls_locked = false

	hidden_player = null
	player_camera = null

	is_busy = false


# ============================================================
# CAMERA POSITION
# ============================================================

func _get_hiding_transform() -> Transform3D:

	var rotation_radians: Vector3 = Vector3(
		deg_to_rad(hiding_rotation.x),
		deg_to_rad(hiding_rotation.y),
		deg_to_rad(hiding_rotation.z)
	)

	var locker_basis: Basis = global_transform.basis.orthonormalized()

	var target_basis: Basis = (
		locker_basis * Basis.from_euler(rotation_radians)
	)

	var target_position: Vector3 = to_global(hiding_position)

	return Transform3D(
		target_basis,
		target_position
	)


func _move_camera(
	target: Transform3D,
	duration: float
) -> void:

	var tween: Tween = create_tween()

	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		player_camera,
		"global_transform",
		target,
		duration
	)

	await tween.finished


# ============================================================
# DOOR ANIMATION
# ============================================================

func _animate_door(opening: bool) -> void:

	var target_rotation: float = closed_door_rotation

	# Select the correct sound.
	var selected_sound: AudioStream

	if opening:

		target_rotation += deg_to_rad(door_open_angle)

		selected_sound = opening_sound

	else:

		selected_sound = closing_sound

	# Play the sound independently of the animation.
	if selected_sound != null:

		locker_sfx.stop()
		locker_sfx.stream = selected_sound
		locker_sfx.play()

	# Animate the door at its original speed.
	var tween: Tween = create_tween()

	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		locker_door,
		"rotation:z",
		target_rotation,
		door_animation_duration
	)

	await tween.finished


# ============================================================
# LOOK AROUND WHILE HIDING
# ============================================================

func _input(event: InputEvent) -> void:

	if hidden_player == null:
		return

	if is_busy:
		return

	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	if not event is InputEventMouseMotion:
		return

	var mouse: InputEventMouseMotion = event as InputEventMouseMotion

	var sensitivity: float = hidden_player.mouse_sensitivity

	# Horizontal look.
	look_yaw -= mouse.relative.x * sensitivity

	look_yaw = clampf(
		look_yaw,
		deg_to_rad(-max_look_left_right),
		deg_to_rad(max_look_left_right)
	)

	# Vertical look.
	look_pitch -= mouse.relative.y * sensitivity

	look_pitch = clampf(
		look_pitch,
		deg_to_rad(-max_look_down),
		deg_to_rad(max_look_up)
	)

	# Apply the limited camera rotation.
	var base_transform: Transform3D = _get_hiding_transform()

	var look_rotation: Basis = Basis.from_euler(
		Vector3(
			look_pitch,
			look_yaw,
			0.0
		)
	)

	player_camera.global_transform = Transform3D(
		base_transform.basis * look_rotation,
		base_transform.origin
	)


# ============================================================
# MONSTER AI SUPPORT
# ============================================================

func is_occupied() -> bool:

	return hidden_player != null


func get_hidden_player() -> ReliefPlayerController:

	return hidden_player
