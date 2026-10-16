class_name ReliefFlashlight
extends Node3D

@export_group("Inertia & Weight")
## How fast the light tracks the camera (lower = heavier feel)
@export var follow_speed: float = 12.0
## Sway amount when moving the camera
@export var sway_amount: float = 0.04

@export_group("Light Settings")
@export var tungsten_color: Color = Color("ffe4a0") # Warm incandescent bulb
@export var flicker_on_step_chance: float = 0.15

@onready var light: SpotLight3D = $SpotLight3D
@onready var click_audio: AudioStreamPlayer = $AudioStreamPlayer
@onready var camera: Camera3D = get_parent() as Camera3D

var _is_on: bool = false
var _target_transform: Transform3D

func _ready() -> void:
	# Ensure it's detached from camera transform updates so it can lag smoothly
	top_level = true
	global_transform = camera.global_transform
	
	# Configure 1974 Tungsten Bulb Profile
	light.light_color = tungsten_color
	light.spot_angle = 34.0
	light.spot_attenuation = 1.3
	light.shadow_enabled = true
	light.shadow_blur = 1.8
	light.volumetric_fog_energy = 4.5 # Cuts through the bunker dust
	light.visible = _is_on
	
	# Listen to player footsteps for filament shock
	var player = owner as ReliefPlayerController
	if player:
		player.step_taken.connect(_on_step_taken)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("flashlight"):
		toggle_flashlight()

func _process(delta: float) -> void:
	# Smooth lag behind camera (creates physical weight)
	_target_transform = camera.global_transform
	global_transform = global_transform.interpolate_with(_target_transform, follow_speed * delta)

func toggle_flashlight() -> void:
	_is_on = !_is_on
	light.visible = _is_on
	
	# Play tactile toggle click
	if click_audio:
		click_audio.pitch_scale = randf_range(0.95, 1.05)
		click_audio.play()

func _on_step_taken(is_running: bool) -> void:
	if not _is_on:
		return
		
	# Heavy boot strikes make the incandescent bulb filament micro-flicker
	var chance = flicker_on_step_chance * (2.5 if is_running else 1.0)
	if randf() < chance:
		_filament_flicker()

func _filament_flicker() -> void:
	light.light_energy = 0.2
	await get_tree().create_timer(randf_range(0.04, 0.08)).timeout
	light.light_energy = 1.0
