extends Node3D


# ============================================================
# INTERACTION SETTINGS
# ============================================================

@export_group("Interaction")

@export var interaction_distance: float = 1.5

# The imported locker may face either local +Z or -Z.
# Toggle this in the Inspector if the front-facing test is reversed.
@export var front_is_positive_z: bool = true


# ============================================================
# DOOR SETTINGS
# ============================================================

@export_group("Door")

@export var door_open_angle: float = 95.0
@export var door_animation_duration: float = 0.85


# ============================================================
# SOUND SETTINGS
# ============================================================

@export_group("Locker Sounds")

@export var opening_sound: AudioStream
@export var closing_sound: AudioStream


# ============================================================
# HIDING CAMERA SETTINGS
# ============================================================

@export_group("Hiding Camera")

@export var hiding_position: Vector3 = Vector3(0.0, 1.45, 0.0)
@export var hiding_rotation: Vector3 = Vector3.ZERO

@export var entering_duration: float = 0.8
@export var exiting_duration: float = 0.7


# ============================================================
# CAMERA LOOK LIMITS
# ============================================================

@export_group("Hidden Camera Movement")

@export var max_look_left_right: float = 45.0
@export var max_look_up: float = 25.0
@export var max_look_down: float = 30.0


# ============================================================
# NODES
# ============================================================

@onready var locker_door: Node3D = (
	$Sketchfab_model/Metal_Locker_fbx/Object_2/RootNode/Locker_Body/Locker_Door
)

# The existing StaticBody3D generated under the door mesh.
@onready var door_collision: StaticBody3D = (
	locker_door.find_child("StaticBody3D", true, false) as StaticBody3D
)

@onready var locker_sfx: AudioStreamPlayer3D = $LockerSFX


# ============================================================
# STATE
# ============================================================

var hidden_player: ReliefPlayerController = null

var player_camera: Camera3D = null

var is_busy: bool = false

var closed_door_rotation: float = 0.0

var original_camera_transform: Transform3D

var original_collision_layer: int = 0
var original_collision_mask: int = 0

var look_yaw: float = 0.0
var look_pitch: float = 0.0


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	closed_door_rotation = locker_door.rotation.z

	if door_collision == null:
		push_error("Locker: Door StaticBody3D was not found.")


# ============================================================
# PLAYER AND RAYCAST
# ============================================================

func _get_player() -> ReliefPlayerController:

	var camera: Camera3D = get_viewport().get_camera_3d()

	if camera == null:
		return null

	return camera.get_parent().get_parent() as ReliefPlayerController


func _get_interaction_ray() -> RayCast3D:

	var camera: Camera3D = get_viewport().get_camera_3d()

	if camera == null:
		return null

	return camera.get_node_or_null("RayCast3D") as RayCast3D


# ============================================================
# CAN THE PLAYER INTERACT?
# ============================================================

func can_interact() -> bool:

	if is_busy:
		return false

	# Ellis is inside this locker.
	# Allow him to exit.
	if hidden_player != null:
		return hidden_player.is_hidden

	var player: ReliefPlayerController = _get_player()

	if player == null:
		return false

	if player.controls_locked:
		return false

	if player.is_hidden:
		return false

	return _is_looking_at_locker()


# ============================================================
# CHECK IF PLAYER IS LOOKING AT THE DOOR
# ============================================================

func _is_looking_at_locker() -> bool:

	var ray: RayCast3D = _get_interaction_ray()

	if ray == null or door_collision == null:
		return false

	if not ray.is_colliding():
		return false

	# Only the door's StaticBody3D is interactable.
	if ray.get_collider() != door_collision:
		return false

	var camera: Camera3D = get_viewport().get_camera_3d()

	if camera == null:
		return false

	# Distance check.
	var distance: float = camera.global_position.distance_to(
		ray.get_collision_point()
	)

	if distance > interaction_distance:
		return false

	# Check the player's position relative to
	# the front of the locker door.
	var door_forward: Vector3 = locker_door.global_basis.z.normalized()

	if not front_is_positive_z:
		door_forward = -door_forward

	var direction_to_player: Vector3 = (
		camera.global_position - locker_door.global_position
	)

	if direction_to_player.length_squared() < 0.0001:
		return false

	direction_to_player = direction_to_player.normalized()

	if door_forward.dot(direction_to_player) < 0.35:
		return false

	return true


# ============================================================
# INTERACT
# ============================================================

func interact() -> void:

	if is_busy:
		return

	# EXIT
	if hidden_player != null:

		if hidden_player.is_hidden:
			_exit_locker()

		return

	# ENTER
	if not can_interact():
		return

	var player: ReliefPlayerController = _get_player()

	if player == null:
		return

	_enter_locker(player)


# ============================================================
# ENTER LOCKER
# ============================================================

func _enter_locker(player: ReliefPlayerController) -> void:

	is_busy = true

	hidden_player = player

	player_camera = player.camera

	original_camera_transform = player_camera.global_transform

	original_collision_layer = player.collision_layer
	original_collision_mask = player.collision_mask

	look_yaw = 0.0
	look_pitch = 0.0

	# Disable movement and normal mouse look.
	player.controls_locked = true

	player.velocity = Vector3.ZERO

	# The body remains outside while the camera
	# moves inside the locker.
	player.collision_layer = 0
	player.collision_mask = 0

	# Open.
	await _animate_door(true)

	# Enter.
	await _move_camera(
		_get_hiding_transform(),
		entering_duration
	)

	# Close.
	await _animate_door(false)

	# Register the hiding state.
	player.is_hidden = true

	# Remember which locker Ellis is hiding in.
	# The raycast uses this to allow exiting.
	player.set_meta("active_locker", self)

	is_busy = false


# ============================================================
# EXIT LOCKER
# ============================================================

func _exit_locker() -> void:

	if hidden_player == null:
		return

	is_busy = true

	# Open.
	await _animate_door(true)

	# Exit.
	await _move_camera(
		original_camera_transform,
		exiting_duration
	)

	# Close.
	await _animate_door(false)

	# Restore collision.
	hidden_player.collision_layer = original_collision_layer
	hidden_player.collision_mask = original_collision_mask

	# Clear the active locker.
	if hidden_player.has_meta("active_locker"):

		if hidden_player.get_meta("active_locker") == self:
			hidden_player.remove_meta("active_locker")

	# Restore gameplay.
	hidden_player.is_hidden = false
	hidden_player.controls_locked = false

	hidden_player = null
	player_camera = null

	is_busy = false


# ============================================================
# HIDING CAMERA TRANSFORM
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

	return Transform3D(
		target_basis,
		to_global(hiding_position)
	)


# ============================================================
# CAMERA MOVEMENT
# ============================================================

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
# DOOR ANIMATION AND SOUNDS
# ============================================================

func _animate_door(opening: bool) -> void:

	var target_rotation: float = closed_door_rotation

	var selected_sound: AudioStream

	if opening:

		target_rotation += deg_to_rad(door_open_angle)
		selected_sound = opening_sound

	else:

		selected_sound = closing_sound

	# Play sound independently.
	if selected_sound != null:

		locker_sfx.stop()
		locker_sfx.stream = selected_sound
		locker_sfx.play()

	# Animate the door.
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

	if is_busy or not hidden_player.is_hidden:
		return

	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	if not event is InputEventMouseMotion:
		return

	var mouse: InputEventMouseMotion = event as InputEventMouseMotion

	var sensitivity: float = hidden_player.mouse_sensitivity

	# Horizontal camera rotation.
	look_yaw -= mouse.relative.x * sensitivity

	look_yaw = clampf(
		look_yaw,
		deg_to_rad(-max_look_left_right),
		deg_to_rad(max_look_left_right)
	)

	# Vertical camera rotation.
	look_pitch -= mouse.relative.y * sensitivity

	look_pitch = clampf(
		look_pitch,
		deg_to_rad(-max_look_down),
		deg_to_rad(max_look_up)
	)

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
# FUTURE MONSTER AI SUPPORT
# ============================================================

func is_occupied() -> bool:

	return hidden_player != null


func get_hidden_player() -> ReliefPlayerController:

	return hidden_player
