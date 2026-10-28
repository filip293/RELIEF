extends StaticBody3D

@onready var cabinet: Node3D = owner

func interact() -> void:
	if cabinet and cabinet.has_method("start_dragging"):
		cabinet.start_dragging(self)
