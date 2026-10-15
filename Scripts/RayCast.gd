extends RayCast3D

@onready var hand_icon: TextureRect = $"../InteractionUI/CenterContainer/HandIcon"


func _ready() -> void:
	hand_icon.hide()


func _physics_process(_delta: float) -> void:
	force_raycast_update()

	var target = get_interactable()

	if target != null:
		hand_icon.show()
	else:
		hand_icon.hide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not event.is_echo():
		check_interaction()


func check_interaction() -> void:
	force_raycast_update()

	var target = get_interactable()

	if target != null:
		target.interact()


func get_interactable() -> Node:
	if not is_colliding():
		return null

	var collider = get_collider()

	if not collider is Node:
		return null

	return find_interactable_root(collider)


func find_interactable_root(node: Node) -> Node:
	var current = node

	while current != null:
		if current.has_method("interact"):
			return current

		current = current.get_parent()

	return null
