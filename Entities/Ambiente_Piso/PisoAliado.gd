@tool
class_name PisoAliado
extends Node3D

## Wrapper posicionable para el piso aliado (franja de fondo).
## Panel de capa visual en el inspector: elige en qué capa va
## (1 = frente nítido, 2 = fondo con desenfoque DOF, 3 = ambas, etc.).
## El nodo raíz queda libre para posicionarlo en el editor.

@export_flags_3d_render var capa_visual: int = 2:
	set(nueva_capa):
		capa_visual = nueva_capa
		if is_node_ready():
			_aplicar_capa_visual(self)


func _ready() -> void:
	_aplicar_capa_visual(self)


func _aplicar_capa_visual(nodo: Node) -> void:
	if not is_instance_valid(nodo):
		return
	if nodo is VisualInstance3D and not (nodo is Light3D or nodo is Camera3D):
		(nodo as VisualInstance3D).layers = capa_visual
	for hijo in nodo.get_children():
		_aplicar_capa_visual(hijo)
