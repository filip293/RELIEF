extends RigidBody3D

@onready var kick_sound: AudioStreamPlayer3D = $Kick

@export_group("Audio Settings")
@export var min_velocity_threshold: float = 0.25  # Lowered since damping kills speed instantly on contact
@export var max_velocity_threshold: float = 8.0   
@export var cooldown_time: float = 0.15           

var _can_play: bool = true
var _last_speed: float = 0.0

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _physics_process(_delta: float) -> void:
	# Track speed continuously so we know how fast we were moving *right before* an impact
	_last_speed = linear_velocity.length()

func _on_body_entered(_body: Node) -> void:
	if not _can_play:
		return

	# Use _last_speed captured right before the physics engine clamped velocity on impact
	if _last_speed >= min_velocity_threshold:
		_play_impact_sound(_last_speed)

func _play_impact_sound(speed: float) -> void:
	var t = inverse_lerp(min_velocity_threshold, max_velocity_threshold, speed)
	t = clamp(t, 0.0, 1.0)
	
	kick_sound.volume_db = lerp(-25.0, 3.0, t)
	kick_sound.pitch_scale = lerp(0.85, 1.25, t)
	
	kick_sound.play()
	
	_can_play = false
	await get_tree().create_timer(cooldown_time).timeout
	_can_play = true
