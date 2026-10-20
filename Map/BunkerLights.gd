extends Node3D

@export var emergency_lights_node_path: NodePath

@onready var no_power_lights_parent: Node = get_node_or_null(emergency_lights_node_path)

func _ready() -> void:
	await get_tree().create_timer(50.0).timeout
	trigger_blackout_sequence()

func trigger_blackout_sequence() -> void:
	$"../PowerGenerator/GeneratorRunning".stop()
	$"../PowerGenerator/GeneratorDead".play()
	for child in get_children():
		var anim_player = _find_animation_player(child)
		if anim_player and anim_player.has_animation("TurnOff"):
			anim_player.play("TurnOff")

		var light_node = _find_light_3d(child)
		if light_node:
			light_node.visible = false
			light_node.shadow_enabled = false

	await get_tree().create_timer(5.0).timeout
	
	if no_power_lights_parent:
		for child in no_power_lights_parent.get_children():
			var anim_player = _find_animation_player(child)
			if anim_player and anim_player.has_animation("LightsOn"):
				anim_player.play("LightsOn")
			
			var emergency_light = _find_light_3d(child)
			if emergency_light:
				emergency_light.visible = true

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		if child is AnimationPlayer:
			return child
		var found = _find_animation_player(child)
		if found:
			return found
	return null

func _find_light_3d(node: Node) -> Light3D:
	if node is Light3D:
		return node
	for child in node.get_children():
		if child is Light3D:
			return child
		var found = _find_light_3d(child)
		if found:
			return found
	return null
