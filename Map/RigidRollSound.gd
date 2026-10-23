extends RigidBody3D

@onready var audio_player: AudioStreamPlayer3D = $ProceduralRoller

var playback: AudioStreamGeneratorPlayback
var sample_rate: float = 44100.0

# Mathematical tracking phases for our different wheels
var phase_wheel_1: float = 0.0
var phase_wheel_2: float = 0.0
var phase_wheel_3: float = 0.0
var phase_squeak: float = 0.0

@export var max_momentum_speed: float = 8.0 
@export var base_frequency: float = 45.0 # The main deep pitch of the wheels

func _ready() -> void:
	audio_player.play()
	playback = audio_player.get_stream_playback() as AudioStreamGeneratorPlayback

func _physics_process(_delta: float) -> void:
	var momentum_speed: float = linear_velocity.length()
	generate_procedural_sound(momentum_speed)

func generate_procedural_sound(speed: float) -> void:
	if not playback:
		return
		
	if speed < 0.1:
		var frames_available = playback.get_frames_available()
		for i in range(frames_available):
			playback.push_frame(Vector2.ZERO)
		return

	var momentum_pct: float = clamp(speed / max_momentum_speed, 0.0, 1.0)
	
	# Speed shifts the rotation pitch up and down dynamically
	var speed_multiplier: float = lerp(0.6, 1.6, momentum_pct)
	var master_volume: float = lerp(0.01, 0.35, momentum_pct)

	var frames_available = playback.get_frames_available()
	for i in range(frames_available):
		
		# WHEEL 1 (Main heavy rumble)
		var inc_1 = (base_frequency * speed_multiplier) / sample_rate
		phase_wheel_1 = fmod(phase_wheel_1 + inc_1, 1.0)
		var w1 = sin(phase_wheel_1 * TAU)
		
		# WHEEL 2 (Slightly different timing to sound uneven and mechanical)
		var inc_2 = ((base_frequency * 1.4) * speed_multiplier) / sample_rate
		phase_wheel_2 = fmod(phase_wheel_2 + inc_2, 1.0)
		var w2 = sin(phase_wheel_2 * TAU) * 0.5
		
		# FLOOR TEXTURE DETENTS (Creates the continuous subtle thumping bumps)
		var inc_3 = ((base_frequency * 4.2) * speed_multiplier) / sample_rate
		phase_wheel_3 = fmod(phase_wheel_3 + inc_3, 1.0)
		# Cubing the wave (pow 3) makes it a sharp physical tap instead of a smooth tone
		var floor_bumps = pow(sin(phase_wheel_3 * TAU), 3) * 0.4
		
		# CHASSIS SQUEAK (High pitch but tiny amplitude, filtered nicely by the LPF)
		var squeak_inc = (1100.0 * speed_multiplier) / sample_rate
		phase_squeak = fmod(phase_squeak + squeak_inc, 1.0)
		# Squeak only opens up periodically based on the main wheel rotation wheel
		var squeak = sin(phase_squeak * TAU) * max(0.0, sin(phase_wheel_1 * TAU)) * 0.04
		
		# Combine everything together into a textured mechanical rolling wave
		var final_signal = (w1 + w2 + floor_bumps + squeak) * master_volume
		
		playback.push_frame(Vector2(final_signal, final_signal))
