extends Node

## Centralized Gamepad Haptics & Vibration Manager for Relief

@export var enabled: bool = true
@export_range(0.0, 1.0) var master_intensity: float = 1.0
@export var default_device: int = 0

var _is_pulsing_heartbeat: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# ==============================================================================
# CORE VIBRATION API
# ==============================================================================

## Starts raw vibration on the gamepad
func rumble(weak_high_freq: float, strong_low_freq: float, duration: float = 0.1, device: int = -1) -> void:
	if not enabled or master_intensity <= 0.0:
		return
	if Input.get_connected_joypads().is_empty():
		return
		
	var dev_id: int = default_device if device < 0 else device
	var weak: float = clampf(weak_high_freq * master_intensity, 0.0, 1.0)
	var strong: float = clampf(strong_low_freq * master_intensity, 0.0, 1.0)
	
	Input.start_joy_vibration(dev_id, weak, strong, duration)


func stop(device: int = -1) -> void:
	var dev_id: int = default_device if device < 0 else device
	Input.stop_joy_vibration(dev_id)


# ==============================================================================
# TACTILE HORROR PRESETS
# ==============================================================================

## Simulates the physical double-thud of a cardiac cycle ("Lub-Dub")
## urgency: 0.0 (calm) to 1.0 (near heart failure / exhaustion)
func play_heartbeat(urgency: float = 0.0) -> void:
	if not enabled or _is_pulsing_heartbeat:
		return
	_is_pulsing_heartbeat = true
	
	# Scale forces based on panic level
	var strong_1: float = lerp(0.25, 0.60, urgency)
	var strong_2: float = lerp(0.40, 0.90, urgency)
	
	# First beat: "Lub"
	rumble(0.1, strong_1, 0.07)
	await get_tree().create_timer(0.09).timeout
	
	# Second beat: "Dub" (heavier contraction)
	rumble(0.2, strong_2, 0.11)
	
	_is_pulsing_heartbeat = false


## Tactile feedback for heavy boot steps (only on sprint to avoid fatigue)
func play_footstep(is_running: bool) -> void:
	if not is_running:
		return # Keep walking pure audio; save rumble for desperate sprints
	# Short, sharp low-frequency thump
	rumble(0.05, 0.28, 0.06)


## Mechanical toggle click for heavy industrial toggle switches / flashlight
func play_switch_click() -> void:
	# Crisp high-frequency snap
	rumble(0.35, 0.0, 0.04)


## Violent jolt when Ellis runs completely out of air
func play_exhaustion_jolt() -> void:
	# Heavy dual-motor stutter
	rumble(0.8, 1.0, 0.35)


## Continuous low-frequency rumble (diesel generator / drill breaking vault)
func play_tremor(intensity: float = 0.5, duration: float = 1.0) -> void:
	rumble(0.1 * intensity, 0.8 * intensity, duration)
