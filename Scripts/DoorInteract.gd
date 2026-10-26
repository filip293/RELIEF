extends Node3D

@onready var anim_player: AnimationPlayer = $OpenClose
@onready var door_open_sound: AudioStreamPlayer3D = $DoorOpen
@onready var door_close_sound: AudioStreamPlayer3D = $DoorClose

var is_open: bool = false

func interact() -> void:
	if anim_player.is_playing():
		return

	if is_open:
		anim_player.play("Close")
		is_open = false
	else:
		anim_player.play("Open")
		is_open = true
