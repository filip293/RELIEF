extends Node

signal inventory_changed
signal item_acquired(item_name: String)

# Stores all collected items.
var collected_items: Dictionary = {}


func _ready() -> void:
	# Ellis starts with a flashlight.
	# Remove this line later when we make the flashlight collectible.
	add_item(&"flashlight", "Flashlight", "Equipment", false)


# ============================================================
# ADD ITEM
# ============================================================

func add_item(
	item_id: StringName,
	item_name: String,
	category: String = "Keycard",
	show_notification: bool = true
) -> bool:

	if item_id == &"":
		push_warning("Cannot add an item without an ID.")
		return false

	# Prevent collecting the same unique item twice.
	if collected_items.has(item_id):
		return false

	collected_items[item_id] = {
		"name": item_name,
		"category": category
	}

	inventory_changed.emit()

	if show_notification:
		item_acquired.emit(item_name)

	print("Collected item: ", item_name)

	return true


# ============================================================
# CHECK ITEM
# ============================================================

func has_item(item_id: StringName) -> bool:
	return collected_items.has(item_id)


# ============================================================
# GET INVENTORY
# ============================================================

func get_items() -> Array[Dictionary]:

	var items: Array[Dictionary] = []

	for item in collected_items.values():
		items.append(item)

	return items


# ============================================================
# RESET INVENTORY
# ============================================================

func reset_inventory() -> void:

	collected_items.clear()

	add_item(&"flashlight", "Flashlight", "Equipment", false)

	inventory_changed.emit()
