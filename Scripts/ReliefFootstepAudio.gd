class_name ReliefSurfaceAudio
extends AudioStreamPlayer3D

enum SurfaceType {
	CONCRETE,
	TILE,
	LINOLEUM
}

# --- AUDIO PACKS FOR YOUR MATERIALS ---
@export_group("Surface Sound Banks")
## MAT_Concrete_Floor, MAT_Concrete_Board
@export var concrete_sounds: Array[AudioStream] = []
## MAT_Tile_Decon
@export var tile_sounds: Array[AudioStream] = []
## MAT_Linoleum
@export var linoleum_sounds: Array[AudioStream] = []

@export_group("Configuration")
## Path to your SurfaceCheck RayCast3D node
@export var surface_check_path: NodePath = ^"../SurfaceCheck"
@export var bus_name: StringName = &"Foley_Player"

@onready var surface_check: RayCast3D = get_node(surface_check_path) as RayCast3D
@onready var player: ReliefPlayerController = owner as ReliefPlayerController


func _ready() -> void:
	bus = bus_name
	# Connect to the player's physical step signal
	if player:
		player.step_taken.connect(_on_step_taken)
	else:
		push_warning("[ReliefSurfaceAudio] Owner is not ReliefPlayerController!")


func _on_step_taken(is_running: bool) -> void:
	var surface: SurfaceType = _detect_surface()
	var sound_bank: Array[AudioStream] = _get_sound_bank(surface)
	
	if sound_bank.is_empty():
		return
		
	# 1. Pick a random sample from that surface's collection
	stream = sound_bank.pick_random()
	
	# 2. Randomize pitch slightly so no two footsteps sound identical
	pitch_scale = randf_range(0.92, 1.08)
	
	# 3. Dynamic volume: running strikes heavier than stealthy walking
	var base_db: float = -10.0 if is_running else -13.0
	volume_db = base_db + randf_range(-1.0, 1.0)
	
	play()


# ==============================================================================
# SURFACE DETECTION LOGIC
# ==============================================================================

func _detect_surface() -> SurfaceType:
	if not surface_check or not surface_check.is_colliding():
		return SurfaceType.CONCRETE # Default fallback for Shelter Nine
		
	var collider: Object = surface_check.get_collider()
	var mat_name: String = _extract_material_name(collider)
	
	# Match material name against your specified list
	match mat_name:
		"MAT_Tile_Decon":
			return SurfaceType.TILE
			
		"MAT_Concrete_Floor", "MAT_Concrete_Board":
			return SurfaceType.CONCRETE
			
		"MAT_Linoleum":
			return SurfaceType.LINOLEUM
			
		_:
			# Fallback matching if names have suffixes (e.g. MAT_Tile_Decon_01)
			if "Tile" in mat_name:
				return SurfaceType.TILE
			elif "Linoleum" in mat_name:
				return SurfaceType.LINOLEUM
			
			return SurfaceType.CONCRETE


func _extract_material_name(collider: Object) -> String:
	if not collider:
		return ""
		
	var mesh_inst: MeshInstance3D = null
	
	# 1. Check if the collider is a child of the MeshInstance (standard glTF import)
	if collider is Node and collider.get_parent() is MeshInstance3D:
		mesh_inst = collider.get_parent() as MeshInstance3D
		
	# 2. Check if MeshInstance is a child or sibling of the collider
	elif collider is Node:
		mesh_inst = collider.find_child("*MeshInstance3D*", true, false) as MeshInstance3D
		if not mesh_inst and collider.get_parent():
			mesh_inst = collider.get_parent().find_child("*MeshInstance3D*", true, false) as MeshInstance3D
			
	# 3. Handle CSG primitives (if using CSGBox3D floors)
	if collider is CSGShape3D and collider.material:
		return _get_mat_resource_name(collider.material)
		
	# 4. Extract active material from the MeshInstance
	if mesh_inst:
		var mat: Material = mesh_inst.get_active_material(0)
		if mat:
			return _get_mat_resource_name(mat)
			
	return ""


func _get_mat_resource_name(mat: Material) -> String:
	if not mat:
		return ""
	# Check explicit resource_name first
	if not mat.resource_name.is_empty():
		return mat.resource_name
	# Fall back to file name if saved as a .tres (e.g., "MAT_Tile_Decon.tres")
	if not mat.resource_path.is_empty():
		return mat.resource_path.get_file().get_basename()
	return ""


func _get_sound_bank(surface: SurfaceType) -> Array[AudioStream]:
	match surface:
		SurfaceType.TILE:
			return tile_sounds if not tile_sounds.is_empty() else concrete_sounds
		SurfaceType.LINOLEUM:
			return linoleum_sounds if not linoleum_sounds.is_empty() else concrete_sounds
		_:
			return concrete_sounds
