class_name ReliefStamina
extends Node

signal stamina_changed(current: float, max_stamina: float, percent: float)
signal exhaustion_triggered()
signal exhaustion_recovered()

enum BreathState {
	CALM,       # > 60% Stamina (Silent or very faint)
	LIGHT,      # 30% - 60% Stamina (Light panting)
	HEAVY,      # < 30% Stamina (Deep, ragged chest breathing)
	HEAVING     # 0% Stamina / Exhausted (Desperate, choking gasps for air)
}

# --- AUDIO SLOTS ---
@export_group("Breathing Audio Streams")
@export var breath_light: AudioStream
@export var breath_heavy: AudioStream
@export var breath_heaving: AudioStream

# --- STAMINA STATS ---
@export_group("Stamina Stats")
@export var max_stamina: float = 100.0
@export var sprint_drain_rate: float = 24.0      # ~4 seconds of full sprint
@export var breath_drain_rate: float = 16.0      # ~6 seconds of holding breath
@export var regen_rate_walking: float = 14.0
@export var regen_rate_idle: float = 26.0
@export var recovery_threshold_pct: float = 0.25 # Must recover to 25% before sprinting again

var current_stamina: float
var is_exhausted: bool = false
var current_breath_state: BreathState = BreathState.CALM

@onready var player: ReliefPlayerController = get_node_or_null("/root/RELIEF/Player")
var breathing_audio: AudioStreamPlayer3D


func _ready() -> void:
	current_stamina = max_stamina
	emit_signal("stamina_changed", current_stamina, max_stamina, 1.0)
	
	# Hook to the Breathing node inside Player
	if player:
		breathing_audio = player.get_node_or_null("Breathing") as AudioStreamPlayer3D
		if breathing_audio:
			breathing_audio.finished.connect(_on_breath_cycle_finished)
		else:
			push_warning("[ReliefStamina] Could not find 'Breathing' AudioStreamPlayer3D under Player!")


func _physics_process(delta: float) -> void:
	if not player:
		return

	var is_moving: bool = player.velocity.length_squared() > 0.1
	var is_holding_sprint: bool = Input.is_action_pressed("sprint") and is_moving and player.is_on_floor()
	var is_holding_breath: bool = Input.is_action_pressed("hold_breath")

	# --- ACTIVE DRAIN ---
	if is_holding_sprint and not is_exhausted:
		_drain(sprint_drain_rate * delta)
	elif is_holding_breath and not is_exhausted:
		_drain(breath_drain_rate * delta)
	# --- RECOVERY ---
	else:
		var rate: float = regen_rate_idle if not is_moving else regen_rate_walking
		_recover(rate * delta)
	
	# Update the breathing intensity state
	_update_breath_state()
	
func can_hold_breath() -> bool:
	return not is_exhausted and current_stamina > 0.0

func _update_breath_state() -> void:
	var pct: float = current_stamina / max_stamina
	var previous_state: BreathState = current_breath_state

	if is_exhausted:
		current_breath_state = BreathState.HEAVING
	elif pct <= 0.30:
		current_breath_state = BreathState.HEAVY
	elif pct <= 0.60:
		current_breath_state = BreathState.LIGHT
	else:
		current_breath_state = BreathState.CALM

	# If we just exited CALM state and nothing is currently playing, start breathing immediately
	if previous_state == BreathState.CALM and current_breath_state != BreathState.CALM:
		if breathing_audio and not breathing_audio.playing:
			_play_next_breath()


func _on_breath_cycle_finished() -> void:
	# Called as soon as one breath completes
	if current_breath_state != BreathState.CALM:
		_play_next_breath()


func _play_next_breath() -> void:
	if not breathing_audio:
		return

	var stream_to_play: AudioStream = null
	var target_volume_db: float = 0.0

	match current_breath_state:
		BreathState.LIGHT:
			stream_to_play = breath_light
			target_volume_db = -6.0
		BreathState.HEAVY:
			stream_to_play = breath_heavy if breath_heavy else breath_light
			target_volume_db = -2.0
		BreathState.HEAVING:
			stream_to_play = breath_heaving if breath_heaving else breath_heavy
			target_volume_db = +2.0 # Loud panic gasps
	
	
	if stream_to_play:
		breathing_audio.stream = stream_to_play
		breathing_audio.volume_db = target_volume_db
		# Micro-pitch shift so breaths feel human and un-robotic
		breathing_audio.pitch_scale = randf_range(0.96, 1.04)
		breathing_audio.play()
		# Inside _play_next_breath():
		if current_breath_state == BreathState.HEAVY:
			ReliefHaptics.play_heartbeat(0.4)
		elif current_breath_state == BreathState.HEAVING:
			ReliefHaptics.play_heartbeat(1.0) # Maximum panicked pulse

func _drain(amount: float) -> void:
	current_stamina = max(current_stamina - amount, 0.0)
	var pct: float = current_stamina / max_stamina
	emit_signal("stamina_changed", current_stamina, max_stamina, pct)

# Inside _drain() when stamina hits 0:
	if current_stamina <= 0.0 and not is_exhausted:
		is_exhausted = true
		emit_signal("exhaustion_triggered")
		_play_next_breath()
		# --- HAPTICS ---
		if ReliefHaptics: # Or $Haptics if placed in tree
			ReliefHaptics.play_exhaustion_jolt()
		


func _recover(amount: float) -> void:
	if current_stamina < max_stamina:
		current_stamina = min(current_stamina + amount, max_stamina)
		var pct: float = current_stamina / max_stamina
		emit_signal("stamina_changed", current_stamina, max_stamina, pct)

		if is_exhausted and pct >= recovery_threshold_pct:
			is_exhausted = false
			emit_signal("exhaustion_recovered")


func can_sprint() -> bool:
	return not is_exhausted and current_stamina > 0.0
