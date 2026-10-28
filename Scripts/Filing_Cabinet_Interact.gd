extends Node3D

@export_group("Dragging")
@export var drag_speed: float = 0.1
@export var z_closed: float = 8.0
@export var z_open: float = 40.0

@export_group("Momentum")
@export var coast_damping: float = 3.0
@export var bounce: float = 0.15
@export var max_speed: float = 120.0
@export var velocity_smoothing: float = 25.0

@export_group("Rolling Sound")
@export var full_speed: float = 60.0
@export var min_pitch: float = 0.85
@export var max_pitch: float = 1.25
@export var min_volume_db: float = -35.0
@export var max_volume_db: float = 0.0
@export var sound_attack: float = 18.0
@export var sound_release: float = 10.0

@export_group("Hit Sound")
@export var hit_full_speed: float = 50.0
@export var min_hit_speed: float = 1.0
@export var hit_min_db: float = -30.0
@export var hit_max_db: float = 0.0
@export var open_end_hit_scale: float = 0.6

const MIN_COAST_SPEED: float = 1.5

@onready var rolling: AudioStreamPlayer3D = get_node_or_null("Rolling")
@onready var hit: AudioStreamPlayer3D = get_node_or_null("Hit")

var active_drawer: StaticBody3D = null
var is_dragging: bool = false

var _pending_pull: float = 0.0
var _velocity: float = 0.0
var _sound_level: float = 0.0


func _ready() -> void:
	set_process_input(false)
	set_process(false)
	if rolling == null:
		push_warning("Filing cabinet: no 'Rolling' AudioStreamPlayer3D found as a child of the cabinet root.")
	if hit == null:
		push_warning("Filing cabinet: no 'Hit' AudioStreamPlayer3D found as a child of the cabinet root.")


func start_dragging(drawer: StaticBody3D) -> void:
	if is_dragging:
		return
	active_drawer = drawer
	_velocity = 0.0
	_pending_pull = 0.0
	is_dragging = true
	set_process_input(true)
	set_process(true)


func stop_dragging() -> void:
	if not is_dragging:
		return
	is_dragging = false
	_pending_pull = 0.0
	set_process_input(false)


func _exit_tree() -> void:
	if is_dragging:
		stop_dragging()


func _input(event: InputEvent) -> void:
	if not is_dragging or active_drawer == null:
		return

	var motion := event as InputEventMouseMotion
	if motion == null:
		return

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	_pending_pull += motion.relative.dot(_compute_pull_direction(camera, active_drawer)) * drag_speed


func _process(delta: float) -> void:
	if delta <= 0.0:
		return

	if is_dragging and not Input.is_action_pressed("interact"):
		stop_dragging()

	if active_drawer:
		if is_dragging:
			var wanted: float = _pending_pull
			_pending_pull = 0.0
			var actual: float = _move_drawer(wanted, wanted / delta)
			_velocity = lerpf(_velocity, actual / delta, 1.0 - exp(-velocity_smoothing * delta))
			_velocity = clampf(_velocity, -max_speed, max_speed)
		else:
			_velocity *= exp(-coast_damping * delta)
			if absf(_velocity) < MIN_COAST_SPEED:
				_velocity = 0.0
				active_drawer = null
			else:
				_move_drawer(_velocity * delta, _velocity)

	var target: float = clampf(absf(_velocity) / full_speed, 0.0, 1.0)
	var rate: float = sound_attack if target > _sound_level else sound_release
	_sound_level = lerpf(_sound_level, target, 1.0 - exp(-rate * delta))
	_update_rolling_sound()

	if not is_dragging and active_drawer == null and _sound_level < 0.005:
		_sound_level = 0.0
		set_process(false)


func _move_drawer(amount: float, speed: float) -> float:
	var old_z: float = active_drawer.position.z
	var target_z: float = old_z + amount
	var new_z: float = clampf(target_z, z_closed, z_open)
	active_drawer.position.z = new_z

	if not is_equal_approx(new_z, target_z) and not is_equal_approx(old_z, new_z):
		_play_hit(absf(speed), is_equal_approx(new_z, z_closed))
		if not is_dragging:
			_velocity = -_velocity * bounce

	return new_z - old_z


func _play_hit(speed: float, at_closed_end: bool) -> void:
	if hit == null or speed < min_hit_speed:
		return

	var strength: float = clampf(speed / hit_full_speed, 0.0, 1.0)
	if not at_closed_end:
		strength *= open_end_hit_scale

	hit.volume_db = lerpf(hit_min_db, hit_max_db, pow(strength, 0.6))
	hit.pitch_scale = randf_range(0.95, 1.05)
	hit.play()


func _update_rolling_sound() -> void:
	if rolling == null or rolling.stream == null:
		return

	if _sound_level < 0.01:
		if rolling.playing:
			rolling.stop()
		return

	if not rolling.playing:
		var length: float = rolling.stream.get_length()
		rolling.play(randf() * length if length > 0.0 else 0.0)

	rolling.pitch_scale = lerpf(min_pitch, max_pitch, _sound_level)
	rolling.volume_db = lerpf(min_volume_db, max_volume_db, sqrt(_sound_level))


func _compute_pull_direction(camera: Camera3D, drawer: Node3D) -> Vector2:
	var parent := drawer.get_parent() as Node3D
	var basis_ref: Basis = parent.global_transform.basis if parent else drawer.global_transform.basis
	var axis_world: Vector3 = basis_ref.z.normalized()

	var a: Vector3 = camera.global_transform.basis.inverse() * axis_world

	var side := Vector2(a.x, -a.y)
	var front := Vector2.DOWN if a.z > 0.0 else Vector2.UP

	var k: float = smoothstep(0.5, 0.85, absf(a.z))
	return side * (1.0 - k) + front * k
