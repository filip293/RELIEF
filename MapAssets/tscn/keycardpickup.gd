extends Node3D

@export_group("Keycard Information")
@export var item_id: StringName = &"voss_keycard"
@export var item_name: String = "Voss's Office Keycard"

var collected: bool = false


func _ready() -> void:

	# Remove the keycard if Ellis already collected it.
	if Globals.has_item(item_id):
		queue_free()


# ============================================================
# INTERACTION CHECK
# ============================================================

func can_interact() -> bool:

	if collected:
		return false

	if Globals.has_item(item_id):
		return false

	return true


# ============================================================
# PICK UP KEYCARD
# ============================================================

func interact() -> void:

	if not can_interact():
		return

	if Globals.add_item(item_id, item_name, "Keycard"):
		collected = true

		print("Picked up keycard: ", item_name)

		queue_free()
