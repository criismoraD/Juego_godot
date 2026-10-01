class_name WaterPlane
extends Node3D

## Plano de agua: selector de capa visual por franja.
## La franja de atrás (fondo, con desenfoque DOF) y la de adelante (frente,
## nítida) se pueden asignar por separado desde el inspector.

@export_flags_3d_render var capa_atras: int = 2:
	set(nueva_capa):
		capa_atras = nueva_capa
		_aplicar_capas()

@export_flags_3d_render var capa_adelante: int = 1:
	set(nueva_capa):
		capa_adelante = nueva_capa
		_aplicar_capas()


func _ready() -> void:
	_aplicar_capas()


func _aplicar_capas() -> void:
	var atras := get_node_or_null("WaterPlane_Atras") as VisualInstance3D
	if is_instance_valid(atras):
		atras.layers = capa_atras
	var adelante := get_node_or_null("WaterPlane_Adelante") as VisualInstance3D
	if is_instance_valid(adelante):
		adelante.layers = capa_adelante
