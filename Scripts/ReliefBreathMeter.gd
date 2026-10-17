class_name ReliefBreathMeter
extends Control

@onready var label: Label = $Label
## Standalone Civil-Defence Breath / Stamina Indicator for Relief

@export_group("Layout & Sizing")
@export var total_segments: int = 20
@export var segment_width: float = 8.0
@export var segment_height: float = 10.0
@export var segment_gap: float = 3.0
@export var margin_from_corner: Vector2 = Vector2(32, 32)

@export_group("Colors")
@export var active_color: Color = Color("ff9922")              # Bright Amber
@export var inactive_color: Color = Color(0.20, 0.12, 0.04, 0.4) # Dim background tick
@export var critical_color: Color = Color(1.0, 0.25, 0.15)     # Warning Red/Amber

@export_group("Behavior")
## If true, stays faint when full and brightens only when breathing/sprinting
@export var dynamic_opacity: bool = true
@export var idle_alpha: float = 0.25
@export var active_alpha: float = 0.85

var fill_percent: float = 1.0:
	set(value):
		fill_percent = clampf(value, 0.0, 1.0)
		queue_redraw()

var _is_critical: bool = false
var _blink_timer: float = 0.0

func _ready() -> void:
	# Create the vintage technical header label
	label.text = "LUNG CAPACITY"
	label.position = Vector2(0, -22)
	label.add_theme_color_override("font_color", active_color)
	label.add_theme_font_size_override("font_size", 16)
	
	modulate.a = idle_alpha if dynamic_opacity else active_alpha
	
	# Auto-hook into player stamina if present
	var stamina = get_tree().get_first_node_in_group("player_stamina") as ReliefStamina
	if not stamina:
		stamina = owner.find_child("Stamina", true, false) as ReliefStamina
	if stamina:
		stamina.stamina_changed.connect(_on_stamina_changed)


func _process(delta: float) -> void:
	# Blink warning when Ellis is about to gasp for air (< 18%)
	if _is_critical:
		_blink_timer += delta * 20.0
		var blink_alpha = (sin(_blink_timer) + 1.0) * 0.5
		label.modulate.a = lerp(0.3, 1.0, blink_alpha)
	else:
		label.modulate.a = 1.0


func _on_stamina_changed(_current: float, _max: float, percent: float) -> void:
	fill_percent = percent
	_is_critical = percent <= 0.18
	
	# Smoothly reveal UI when sprinting/holding breath, fade when full
	if dynamic_opacity:
		var target_alpha = active_alpha if percent < 0.98 else idle_alpha
		modulate.a = move_toward(modulate.a, target_alpha, 0.08)


func _draw() -> void:
	var active_count: int = int(round(fill_percent * total_segments))
	var current_active_color: Color = critical_color if _is_critical else active_color
	
	for i in range(total_segments):
		var x_pos: float = i * (segment_width + segment_gap)
		var rect: Rect2 = Rect2(Vector2(x_pos, 0), Vector2(segment_width, segment_height))
		
		if i < active_count:
			draw_rect(rect, current_active_color)
		else:
			draw_rect(rect, inactive_color)


func _get_minimum_size() -> Vector2:
	return Vector2(total_segments * (segment_width + segment_gap), segment_height)
