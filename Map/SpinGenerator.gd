extends Marker3D

@export var rotation_speed: float = 5.0
@onready var generator_running_audio: AudioStreamPlayer3D = $"../GeneratorRunning"

func _process(delta: float) -> void:
	if generator_running_audio and generator_running_audio.playing:
		rotation.z += rotation_speed * delta
