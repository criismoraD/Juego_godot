@tool
class_name PuenteMadera
extends Node3D

## Wrapper posicionable para el puente de madera en el nivel del río.
## Aplica el material con textura a todas las mallas importadas del GLB,
## sin depender del nombre interno del nodo importado.
## El nodo raíz queda libre para posicionarlo en el editor.

const INDICE_SUPERFICIE_PRINCIPAL: int = 0

@export var material_puente: StandardMaterial3D:
	set(nuevo_material):
		material_puente = nuevo_material
		if is_node_ready():
			_aplicar_material()

@export_flags_3d_render var capa_visual: int = 1:
	set(nueva_capa):
		capa_visual = nueva_capa
		if is_node_ready():
			_aplicar_capa_visual(self)

@onready var modelo: Node3D = $Model


func _ready() -> void:
	_aplicar_material()
	_aplicar_capa_visual(self)


## Aplica el material configurado a la instancia del modelo.
func aplicar_material() -> void:
	_aplicar_material()


func _aplicar_material() -> void:
	if material_puente == null:
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
		malla_instancia.material_override = material_puente
		if malla_instancia.mesh != null and malla_instancia.mesh.get_surface_count() > INDICE_SUPERFICIE_PRINCIPAL:
			malla_instancia.set_surface_override_material(INDICE_SUPERFICIE_PRINCIPAL, material_puente)
	for hijo in nodo.get_children():
		_aplicar_a_instancias(hijo)


func _aplicar_capa_visual(nodo: Node) -> void:
	if not is_instance_valid(nodo):
		return
	if nodo is VisualInstance3D and not (nodo is Light3D or nodo is Camera3D):
		(nodo as VisualInstance3D).layers = capa_visual
	for hijo in nodo.get_children():
		_aplicar_capa_visual(hijo)
