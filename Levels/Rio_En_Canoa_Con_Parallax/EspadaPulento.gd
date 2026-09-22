@tool
class_name EspadaPulento
extends Node3D

## Wrapper posicionable para la espada pulento en el nivel del río.
## Aplica el material con textura a todas las mallas importadas del GLB,
## sin depender del nombre interno del nodo importado.

const INDICE_SUPERFICIE_PRINCIPAL: int = 0

@export var material_espada: StandardMaterial3D:
	set(nuevo_material):
		material_espada = nuevo_material
		if is_node_ready():
			_aplicar_material()

@onready var modelo: Node3D = $Model


func _ready() -> void:
	_aplicar_material()


## Aplica el material configurado a la instancia del modelo.
func aplicar_material() -> void:
	_aplicar_material()


func _aplicar_material() -> void:
	if material_espada == null:
		return
	var raiz_modelo: Node = modelo
	if not is_instance_valid(raiz_modelo):
		raiz_modelo = find_child("Model", true, false)
		if raiz_modelo == null:
			return
	_aplicar_a_instancias(raiz_modelo)


func _aplicar_a_instancias(nodo: Node) -> void:
	if nodo is MeshInstance3D:
		var malla_instancia: MeshInstance3D = nodo as MeshInstance3D
		malla_instancia.material_override = material_espada
		if malla_instancia.mesh != null and malla_instancia.mesh.get_surface_count() > INDICE_SUPERFICIE_PRINCIPAL:
			malla_instancia.set_surface_override_material(INDICE_SUPERFICIE_PRINCIPAL, material_espada)
	for hijo in nodo.get_children():
		_aplicar_a_instancias(hijo)
