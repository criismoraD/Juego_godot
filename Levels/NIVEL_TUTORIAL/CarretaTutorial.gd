@tool
class_name CarretaTutorial
extends Node3D

## Wrapper posicionable para la carreta del tutorial (modelo TEST_/Carreta tutorial).
## Aplica el material con textura a todas las mallas importadas del GLB,
## sin depender del nombre interno del nodo importado.
## Panel de capa visual en el inspector: elige en qué capa va
## (1 = frente nítido, 2 = fondo con desenfoque DOF, 3 = ambas, etc.).
## El nodo raíz queda libre para posicionarlo en el editor.

const MATERIAL_DEFECTO: Material = preload("res://Levels/NIVEL_TUTORIAL/CarretaTutorial_Mat.tres")

@export var material_carreta: StandardMaterial3D:
	set(nuevo_material):
		material_carreta = nuevo_material
		if is_node_ready():
			_aplicar_material()

@export_flags_3d_render var capa_visual: int = 1:
	set(nueva_capa):
		capa_visual = nueva_capa
		if is_node_ready():
			_aplicar_capa_visual(self)

## Excepciones de capa por nombre de hijo (p. ej. {"Model2": 2}).
## Afecta al nodo y a sus hijos.
@export var capa_por_modelo: Dictionary = {}:
	set(nueva_config):
		capa_por_modelo = nueva_config if nueva_config != null else {}
		if is_node_ready():
			_aplicar_capa_visual(self)


func _ready() -> void:
	if material_carreta == null:
		material_carreta = MATERIAL_DEFECTO
	_aplicar_material()
	_aplicar_capa_visual(self)


## Aplica el material configurado a la instancia del modelo.
func aplicar_material() -> void:
	_aplicar_material()


func _aplicar_material() -> void:
	if material_carreta == null:
		return
	_aplicar_a_instancias(self)


func _aplicar_a_instancias(nodo: Node) -> void:
	if nodo is MeshInstance3D:
		_aplicar_material_a_malla(nodo as MeshInstance3D)
	for hijo in nodo.get_children():
		_aplicar_a_instancias(hijo)


## El GLB trae material gris sin textura: se reemplaza siempre por
## la difusa (el modelo tiene UVs).
func _aplicar_material_a_malla(malla_instancia: MeshInstance3D) -> void:
	if material_carreta == null:
		return
	if malla_instancia.mesh == null:
		return
	malla_instancia.material_override = material_carreta
	for si in range(malla_instancia.mesh.get_surface_count()):
		malla_instancia.set_surface_override_material(si, material_carreta)


func _aplicar_capa_visual(nodo: Node, capa_heredada: int = -1) -> void:
	if not is_instance_valid(nodo):
		return
	var capa: int = capa_heredada
	if capa < 0:
		capa = capa_visual
	if nodo != self and capa_por_modelo != null and capa_por_modelo.has(String(nodo.name)):
		capa = int(capa_por_modelo[String(nodo.name)])
	if nodo is VisualInstance3D and not (nodo is Light3D or nodo is Camera3D):
		(nodo as VisualInstance3D).layers = capa
	for hijo in nodo.get_children():
		_aplicar_capa_visual(hijo, capa)
