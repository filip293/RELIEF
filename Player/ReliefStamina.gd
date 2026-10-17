class_name ReliefStamina
extends Node

signal stamina_changed(current: float, max_stamina: float, percent: float)
signal exhaustion_triggered()
signal exhaustion_recovered()

@export_group("Stamina Stats")
@export var max_stamina: float = 100.0
@export var sprint_drain_rate: float = 24.0      # ~4 seconds of full sprint
@export var breath_drain_rate: float = 16.0      # ~6 seconds of holding breath
@export var regen_rate_walking: float = 7.0
@export var regen_rate_idle: float = 14.0

@export var recovery_threshold_pct: float = 0.30

var current_stamina: float
var is_exhausted: bool = false

@onready var player: ReliefPlayerController = $/root/RELIEF/Player


func _ready() -> void:
	current_stamina = max_stamina
	emit_signal("stamina_changed", current_stamina, max_stamina, 1.0)


func _physics_process(delta: float) -> void:
	if not player:
		return

	var is_moving: bool = player.velocity.length_squared() > 0.1
	var is_holding_sprint: bool = Input.is_action_pressed("sprint") and is_moving and player.is_on_floor()
	var is_holding_breath: bool = Input.is_action_pressed("hold_breath")

	# --- ACTIVE SPRINT DRAIN ---
	if is_holding_sprint and not is_exhausted:
		_drain(sprint_drain_rate * delta)

	# --- HOLDING BREATH DRAIN ---
	elif is_holding_breath and not is_exhausted:
		_drain(breath_drain_rate * delta)

	# --- RECOVERY ---
	else:
		var rate: float = regen_rate_idle if not is_moving else regen_rate_walking
		_recover(rate * delta)


func _drain(amount: float) -> void:
	current_stamina = max(current_stamina - amount, 0.0)
	var pct: float = current_stamina / max_stamina
	emit_signal("stamina_changed", current_stamina, max_stamina, pct)

	if current_stamina <= 0.0 and not is_exhausted:
		is_exhausted = true
		emit_signal("exhaustion_triggered")


func _recover(amount: float) -> void:
	if current_stamina < max_stamina:
		current_stamina = min(current_stamina + amount, max_stamina)
		var pct: float = current_stamina / max_stamina
		emit_signal("stamina_changed", current_stamina, max_stamina, pct)

		# Unlock sprint only when lungs have caught up to threshold
		if is_exhausted and pct >= recovery_threshold_pct:
			is_exhausted = false
			emit_signal("exhaustion_recovered")


## The single authority on whether sprinting is allowed
func can_sprint() -> bool:
	return not is_exhausted and current_stamina > 0.0
