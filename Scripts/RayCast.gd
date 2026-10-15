extends RayCast3D

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		check_interaction()

func check_interaction() -> void:
	if is_colliding():
		var collider = get_collider()
		
		# Find the target door root node from the hit collider
		var door = find_door_root(collider)
		if door and door.has_method("interact"):
			door.interact()

func find_door_root(node: Node) -> Node:
	var current = node
	while current != null:
		if current.has_method("interact"):
			return current
		current = current.get_parent()
	return null
