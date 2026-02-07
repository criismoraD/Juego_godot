@tool
extends StaticBody3D

@export var size: Vector3 = Vector3(20, 1, 20):
	set(value):
		size = value
		if is_inside_tree():
			_update_floor()

@export var floor_material: Material:
	set(value):
		floor_material = value
		if is_inside_tree():
			_update_floor()

var _mesh_instance: MeshInstance3D
var _collision_shape: CollisionShape3D

func _ready():
	_setup_nodes()
	_update_floor()

func _setup_nodes():
	if not has_node("MeshInstance3D"):
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "MeshInstance3D"
		add_child(_mesh_instance)
		# Ensure visible in editor for tool scripts if creating dynamically, 
		# though usually better to have them in scene. 
		# Setting owner is required for them to be saved if this script was constructing the scene in editor time explicitly to persist.
		# For runtime/tool visualization, add_child is enough, but they won't be saved in the tscn unless owner is set.
		# However, since we want this to be "parametric" at runtime/editor time, regenerating the mesh resource is fine.
	else:
		_mesh_instance = get_node("MeshInstance3D")

	if not has_node("CollisionShape3D"):
		_collision_shape = CollisionShape3D.new()
		_collision_shape.name = "CollisionShape3D"
		add_child(_collision_shape)
	else:
		_collision_shape = get_node("CollisionShape3D")

func _update_floor():
	if _mesh_instance:
		var box_mesh = BoxMesh.new()
		box_mesh.size = size
		if floor_material:
			box_mesh.material = floor_material
		else:
			# Material gris por defecto
			var default_material = StandardMaterial3D.new()
			default_material.albedo_color = Color(0.5, 0.5, 0.5, 1.0) # Gris
			box_mesh.material = default_material
		_mesh_instance.mesh = box_mesh
	
	if _collision_shape:
		var box_shape = BoxShape3D.new()
		box_shape.size = size
		_collision_shape.shape = box_shape
