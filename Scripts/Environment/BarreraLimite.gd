@tool
extends StaticBody3D
class_name BarreraLimite

# Dimensiones exportadas
@export var tamano: Vector3 = Vector3(1, 10, 1):
	set(value):
		tamano = value
		_actualizar_tamano()

@export var solo_jugador: bool = true  # Solo colisiona con el jugador

var collision_shape: CollisionShape3D
var mesh_instance: MeshInstance3D


func _ready():
	if solo_jugador:
		# Layer 10: layer exclusivo para barreras (evita colisión con proyectiles)
		collision_layer = 1 << 9
		collision_mask = 0

	_buscar_componentes()
	_actualizar_tamano()


func _buscar_componentes():
	for child in get_children():
		if child is CollisionShape3D:
			collision_shape = child
			# Intentar encontrar mesh dentro
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
