@tool
extends StaticBody3D
class_name BarreraDestruyeFlechas

# Dimensiones exportadas
@export var tamano: Vector3 = Vector3(1, 10, 1):
	set(value):
		tamano = value
		_actualizar_tamano()

var collision_shape: CollisionShape3D
var mesh_instance: MeshInstance3D


func _ready():
	# Añadir al grupo para que las flechas aliadas lo detecten
	add_to_group("barrera_destruye_flechas")

	# Layer 3 (Enemies, value 4): para que las flechas del jugador/aliadas (mask 71) colisionen.
	# El player (mask 513) no colisiona con la capa 3.
	collision_layer = 1 << 2  # Capa 3
	collision_mask = 0

	_buscar_componentes()
	_actualizar_tamano()
	_configurar_material()


func _buscar_componentes():
	for child in get_children():
		if child is CollisionShape3D:
			collision_shape = child
			for subchild in child.get_children():
				if subchild is MeshInstance3D:
					mesh_instance = subchild
			break


func _actualizar_tamano():
	if not collision_shape:
		_buscar_componentes()

	if collision_shape and collision_shape.shape is BoxShape3D:
		collision_shape.shape.size = tamano

	if mesh_instance and mesh_instance.mesh is BoxMesh:
		mesh_instance.mesh.size = tamano


func _configurar_material():
	if not mesh_instance:
		_buscar_componentes()

	if mesh_instance:
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.2, 0.6, 1.0, 0.3)  # Celeste semi-transparente
		mat.emission_enabled = true
		mat.emission = Color(0.2, 0.6, 1.0)
		mat.emission_energy_multiplier = 1.0
		mesh_instance.material_override = mat
