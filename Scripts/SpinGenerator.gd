extends Marker3D

@export var max_rotation_speed: float = 10.0
@export var deceleration: float = 3.0
@onready var generator_running_audio: AudioStreamPlayer3D = $"../GeneratorRunning"

var current_speed: float = 0.0

func _process(delta: float) -> void:
	if generator_running_audio and generator_running_audio.playing:
		current_speed = max_rotation_speed
	else:
		current_speed = move_toward(current_speed, 0.0, deceleration * delta)
	
	if current_speed != 0.0:
		rotation.z += current_speed * delta
