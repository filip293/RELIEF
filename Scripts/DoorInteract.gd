extends Node3D

@export var auto_close_delay: float = 5.0

@onready var anim_player: AnimationPlayer = $OpenClose
@onready var door_open_sound: AudioStreamPlayer3D = $DoorOpen
@onready var door_close_sound: AudioStreamPlayer3D = $DoorClose
@onready var auto_close_timer: Timer = $AutoCloseTimer
@onready var inside_marker: Marker3D = $InsideMarker

var is_open: bool = false
var is_moving: bool = false
var is_locked: bool = true


func _ready() -> void:
	auto_close_timer.one_shot = true
	auto_close_timer.timeout.connect(_on_auto_close_timer_timeout)


# Called by the keycard reader.
func open_from_keycard() -> void:
	if is_moving:
		return

	if is_open:
		auto_close_timer.start(auto_close_delay)
		return

	open_door()


# Called when the player presses E on the door.
func interact() -> void:
	if is_moving:
		return

	# Only allow direct interaction from inside the room.
	if not player_is_inside():
		return

	if is_open:
		close_door()
	else:
		open_door()


func open_door() -> void:
	if is_moving or is_open:
		return

	is_moving = true
	is_locked = false

	anim_player.play("Open")

	if door_open_sound.stream != null:
		door_open_sound.play()

	await anim_player.animation_finished

	is_open = true
	is_moving = false

	auto_close_timer.start(auto_close_delay)


func close_door() -> void:
	if is_moving or not is_open:
		return

	auto_close_timer.stop()
	is_moving = true

	anim_player.play("Close")

	await anim_player.animation_finished

	is_open = false
	is_moving = false
	is_locked = true


func _on_auto_close_timer_timeout() -> void:
	if is_open and not is_moving:
		close_door()


func player_is_inside() -> bool:
	var player: Node3D = (
		get_tree().get_first_node_in_group("player") as Node3D
	)

	if player == null:
		return false

	var inside_direction: Vector3 = (
		inside_marker.global_position - global_position
	)

	var player_direction: Vector3 = (
		player.global_position - global_position
	)

	if inside_direction.length_squared() < 0.01:
		return false

	return player_direction.dot(inside_direction) > 0.0
