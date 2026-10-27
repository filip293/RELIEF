class_name ReliefStamina
extends Node

signal stamina_changed(current: float, max_stamina: float, percent: float)
signal exhaustion_triggered()
signal exhaustion_recovered()

# --- AUDIO SETTINGS (SINGLE SOUND) ---
@export_group("Breathing Audio")
@export var breath_heavy: AudioStream
## Default peak loudness (-9.0 dB is subtle and in the background)
@export var max_volume_db: float = -9.0
## How fast volume adapts (higher = quicker, lower = smoother)
@export var volume_fade_speed: float = 3.0

# --- STAMINA STATS ---
@export_group("Stamina Stats")
@export var max_stamina: float = 100.0
@export var sprint_drain_rate: float = 24.0      # ~4 seconds of full sprint
@export var breath_drain_rate: float = 16.0      # While holding breath
@export var regen_rate_normal: float = 18.0      # Normal recovery rate
@export var regen_rate_exhausted: float = 6.0    # Slower recovery after hitting 0%
@export var recovery_threshold_pct: float = 0.40 # Needs 40% to clear exhaustion penalty

var current_stamina: float
var is_exhausted: bool = false
var is_pushing_jog: bool = false # Set by ReliefPlayerController

@onready var player: ReliefPlayerController = get_node_or_null("/root/RELIEF/Player")

var _breathing_player: AudioStreamPlayer
var _wants_audio: bool = false


func _ready() -> void:
	current_stamina = max_stamina
	emit_signal("stamina_changed", current_stamina, max_stamina, 1.0)
	_setup_audio_player()


func _setup_audio_player() -> void:
	_breathing_player = AudioStreamPlayer.new()
	_breathing_player.name = "HeavyBreathingPlayer"
	_breathing_player.stream = breath_heavy
	_breathing_player.volume_db = -80.0
	_breathing_player.bus = "Master"
	
	# Ensures it loops continuously without cutting off, even if 'loop' isn't set in import settings
	_breathing_player.finished.connect(func():
		if _wants_audio:
			_breathing_player.play()
	)
	add_child(_breathing_player)


func _physics_process(delta: float) -> void:
	if not player:
		return

	var is_moving: bool = player.velocity.length_squared() > 0.1
	var is_holding_sprint: bool = Input.is_action_pressed("sprint") and is_moving and player.is_on_floor()
	var is_holding_breath: bool = Input.is_action_pressed("hold_breath")

	# 1. PUSHING ON ZERO STAMINA (Holding Shift past empty)
	if is_pushing_jog and is_holding_sprint:
		current_stamina = 0.0
		# STRICTLY NO RECOVERY while Shift is held
		_update_breathing_audio(delta)
		return

	# 2. NORMAL SPRINT DRAIN
	if is_holding_sprint and not is_exhausted and current_stamina > 0.0:
		_drain(sprint_drain_rate * delta)
	# 3. BREATH HOLD DRAIN
	elif is_holding_breath and not is_exhausted:
		_drain(breath_drain_rate * delta)
	# 4. RECOVERY
	else:
		var rate: float = regen_rate_exhausted if is_exhausted else regen_rate_normal
		_recover(rate * delta)

	_update_breathing_audio(delta)


func _drain(amount: float) -> void:
	current_stamina = maxf(current_stamina - amount, 0.0)
	var pct: float = current_stamina / max_stamina
	emit_signal("stamina_changed", current_stamina, max_stamina, pct)

	if current_stamina <= 0.0 and not is_exhausted:
		is_exhausted = true
		emit_signal("exhaustion_triggered")
		if Engine.has_singleton("ReliefHaptics") or get_node_or_null("/root/ReliefHaptics"):
			ReliefHaptics.play_exhaustion_jolt()


func _recover(amount: float) -> void:
	if current_stamina < max_stamina:
		current_stamina = minf(current_stamina + amount, max_stamina)
		var pct: float = current_stamina / max_stamina
		emit_signal("stamina_changed", current_stamina, max_stamina, pct)

		if is_exhausted and pct >= recovery_threshold_pct:
			is_exhausted = false
			emit_signal("exhaustion_recovered")


# ==============================================================================
# AUDIO PITCH & VOLUME MODULATION
# ==============================================================================

func _update_breathing_audio(delta: float) -> void:
	if not _breathing_player or not _breathing_player.stream:
		return

	var pct: float = current_stamina / max_stamina
	var target_volume_db: float = -80.0
	var target_pitch: float = 1.0

	if is_pushing_jog:
		# Pushing past empty: locked at full volume, slight panic pitch
		_wants_audio = true
		target_volume_db = max_volume_db
		target_pitch = 1.04

	elif is_exhausted:
		# Recovering after hitting 0%:
		# Breaths slow down in pitch and get softer as stamina reaches 60%
		if pct < 0.60:
			_wants_audio = true
			var recovery_t: float = pct / 0.60 # 0.0 at empty -> 1.0 at recovery point
			# Volume fades from max down by 20 dB (soft whisper)
			target_volume_db = lerpf(max_volume_db, max_volume_db - 20.0, recovery_t)
			# Pitch eases down slightly as lungs recover
			target_pitch = lerpf(1.02, 0.94, recovery_t)
		else:
			_wants_audio = false
			target_volume_db = -80.0

	else:
		# Stamina draining during regular sprint:
		# Starts faint when stamina drops below 35%, builds up to max_volume_db at 0%
		if pct < 0.35:
			_wants_audio = true
			var strain_t: float = (0.35 - pct) / 0.35 # 0.0 at 35% -> 1.0 at 0%
			target_volume_db = lerpf(max_volume_db - 16.0, max_volume_db, strain_t)
			target_pitch = lerpf(0.97, 1.02, strain_t)
		else:
			_wants_audio = false
			target_volume_db = -80.0

	# Smooth pitch transition
	_breathing_player.pitch_scale = lerpf(_breathing_player.pitch_scale, target_pitch, 2.5 * delta)

	# Smooth volume transition (no cutoffs)
	if _wants_audio:
		if not _breathing_player.playing:
			_breathing_player.volume_db = -35.0 # Start near audible so it doesn't pop
			_breathing_player.play()
		_breathing_player.volume_db = lerpf(_breathing_player.volume_db, target_volume_db, volume_fade_speed * delta)
	else:
		# Gently fade down into complete silence before stopping
		_breathing_player.volume_db = lerpf(_breathing_player.volume_db, -80.0, volume_fade_speed * delta)
		if _breathing_player.volume_db <= -65.0 and _breathing_player.playing:
			_breathing_player.stop()


func can_sprint() -> bool:
	return not is_exhausted and current_stamina > 0.0


func can_hold_breath() -> bool:
	return not is_exhausted and current_stamina > 0.0
