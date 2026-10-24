extends RigidBody3D

@onready var roller_audio: AudioStreamPlayer3D = $ProceduralRoller

@export var min_speed_threshold: float = 0.05
@export var max_speed: float = 4.0
@export var min_pitch: float = 0.4
@export var max_pitch: float = 1.0

func _physics_process(delta: float) -> void:
	var current_speed = linear_velocity.length()
	
	if current_speed > min_speed_threshold:
		if not roller_audio.playing:
			roller_audio.play()
		
		var speed_factor = clamp(current_speed / max_speed, 0.0, 1.0)
		
		roller_audio.pitch_scale = lerp(min_pitch, max_pitch, speed_factor)
		
		if speed_factor > 0.0:
			roller_audio.volume_db = linear_to_db(speed_factor)
		else:
			roller_audio.volume_db = -80.0
			
	else:
		if roller_audio.playing:
			roller_audio.stop()
