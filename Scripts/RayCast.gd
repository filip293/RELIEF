extends RayCast3D

@onready var hand_icon: TextureRect = $"../InteractionUI/CenterContainer/HandIcon"

@onready var player: ReliefPlayerController = (
	get_node("../../..") as ReliefPlayerController
)


func _ready() -> void:
	hand_icon.hide()


func _physics_process(_delta: float) -> void:

	force_raycast_update()

	var target: Node = get_interactable()

	hand_icon.visible = target != null


func _unhandled_input(event: InputEvent) -> void:

	if event.is_action_pressed("interact") and not event.is_echo():

		check_interaction()


func check_interaction() -> void:

	force_raycast_update()

	var target: Node = get_interactable()

	if target != null:

		target.interact()

		get_viewport().set_input_as_handled()


# ============================================================
# FIND INTERACTABLE OBJECT
# ============================================================

func get_interactable() -> Node:

	# If Ellis is hiding, prioritize his current locker.
	# The camera cannot necessarily see the door from inside.

	if player != null:

		if player.is_hidden:

			if player.has_meta("active_locker"):

				var active_locker: Node = (
					player.get_meta("active_locker") as Node
				)

				if is_instance_valid(active_locker):

					if _can_interact_with(active_locker):
						return active_locker

			return null

		# Prevent interactions during cinematics
		# and locker entry/exit transitions.
		if player.controls_locked:
			return null

	if not is_colliding():
		return null

	var collider: Object = get_collider()

	if not collider is Node:
		return null

	var target: Node = find_interactable_root(collider as Node)

	if not _can_interact_with(target):
		return null

	return target


# ============================================================
# CHECK WHETHER INTERACTION IS ALLOWED
# ============================================================

func _can_interact_with(target: Node) -> bool:

	if target == null:
		return false

	# Lockers can restrict interaction based on
	# distance, direction, or whether they're occupied.

	if target.has_method("can_interact"):
		return bool(target.can_interact())

	# Existing bunker doors don't have can_interact().
	# They continue working exactly as before.
	return true


# ============================================================
# FIND INTERACTION SCRIPT ON PARENT NODE
# ============================================================

func find_interactable_root(node: Node) -> Node:

	var current: Node = node

	while current != null:

		if current.has_method("interact"):
			return current

		current = current.get_parent()

	return null
