extends Node3D

@export var required_keycard_id: StringName = &"security_card"
@export var linked_door: Node3D

@export var light_display: MeshInstance3D

@export var flash_duration: float = 0.45

@onready var accepted_sound: AudioStreamPlayer3D = $Accepted
@onready var rejected_sound: AudioStreamPlayer3D = $Rejected

var display_material: StandardMaterial3D
var flash_tween: Tween

const IDLE_COLOR = Color(0.04, 0.12, 0.06)
const ACCEPTED_COLOR = Color(0.1, 1.0, 0.2)
const REJECTED_COLOR = Color(1.0, 0.05, 0.05)


func _ready() -> void:
	setup_display()


func setup_display() -> void:
	if light_display == null:
		push_error("KeycardReader: Light Display is not assigned!")
		return

	display_material = StandardMaterial3D.new()

	display_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	display_material.emission_enabled = true
	display_material.emission_energy_multiplier = 2.0

	light_display.material_override = display_material

	set_display_color(IDLE_COLOR)


func interact() -> void:
	if Globals.has_item(required_keycard_id):
		access_granted()
	else:
		access_denied()


func access_granted() -> void:
	flash_display(ACCEPTED_COLOR)

	if accepted_sound.stream != null:
		accepted_sound.play()

	print("ACCESS GRANTED: ", required_keycard_id)

	if is_instance_valid(linked_door):
		if linked_door.has_method("open_from_keycard"):
			linked_door.call("open_from_keycard")
		else:
			push_warning("Linked door needs open_from_keycard().")


func access_denied() -> void:
	flash_display(REJECTED_COLOR)

	if rejected_sound.stream != null:
		rejected_sound.play()

	print("ACCESS DENIED: ", required_keycard_id)


func set_display_color(color: Color) -> void:
	if display_material == null:
		return

	display_material.albedo_color = color
	display_material.emission = color


func flash_display(color: Color) -> void:
	if flash_tween and flash_tween.is_running():
		flash_tween.kill()

	set_display_color(color)

	flash_tween = create_tween()

	flash_tween.tween_interval(flash_duration)

	flash_tween.tween_callback(
		func(): set_display_color(IDLE_COLOR)
	)
