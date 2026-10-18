extends Node3D

@export var door_node: Node3D
@export var open_angle := 90.0
@export var opening_time := 1.2

@onready var open_sound: AudioStreamPlayer3D = $Open
@onready var close_sound: AudioStreamPlayer3D = $Close

var is_open := false
var is_moving := false
var closed_angle := 0.0


func _ready() -> void:
	if door_node:
		closed_angle = door_node.rotation_degrees.y


func interact() -> void:
	if is_moving or door_node == null:
		return

	is_moving = true
	is_open = not is_open

	var target_angle := closed_angle + (open_angle if is_open else 0.0)

	if is_open:
		open_sound.play()
	else:
		close_sound.play(0.5)

	var tween = create_tween()
	tween.tween_property(
		door_node,
		"rotation_degrees:y",
		target_angle,
		opening_time
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await tween.finished
	is_moving = false
