@tool
class_name ColaVeera
extends Node3D

## Cola para el NPC Veera: gestiona su material y capa visual.

const MATERIAL_DEFECTO: StandardMaterial3D = preload("res://Entities/NPC_Veera/ColaVeera_Mat.tres")

@export var material_cola: StandardMaterial3D = MATERIAL_DEFECTO:
	set(nuevo_material):
		material_cola = nuevo_material
		_aplicar_material()

@export_flags_3d_render var capa_visual: int = 1:
	set(nueva_capa):
		capa_visual = nueva_capa
		_aplicar_capa_visual()


func _ready() -> void:
	_aplicar_material()
	_aplicar_capa_visual()


func _aplicar_material() -> void:
	if material_cola == null:
		return
	_aplicar_material_recursivo(self)


func _aplicar_material_recursivo(nodo: Node) -> void:
	if nodo is MeshInstance3D:
		var mi := nodo as MeshInstance3D
		mi.material_override = material_cola
		if mi.mesh != null and mi.mesh.get_surface_count() > 0:
			mi.set_surface_override_material(0, material_cola)
	for hijo in nodo.get_children():
		_aplicar_material_recursivo(hijo)


func _aplicar_capa_visual() -> void:
	_asignar_capa_visual_recursiva(self, capa_visual)


func _asignar_capa_visual_recursiva(nodo: Node, capa: int) -> void:
	if nodo is VisualInstance3D:
		(nodo as VisualInstance3D).layers = capa
	for hijo in nodo.get_children():
		_asignar_capa_visual_recursiva(hijo, capa)
