class_name Bracero
extends Node3D

@export_category("Sombra Proyectada")
@export var sombra_opacidad: float = 1.0
## Tamaño de la sombra elíptica (proyectada hacia abajo alargando el eje Y de la sombra)
@export var sombra_tamano: Vector2 = Vector2(0.8, 1.4)
@export var sombra_suavizado: float = 0.8
## Desplazamiento de proyección hacia abajo/atrás en Z
@export var sombra_offset_z: float = 0.35

var sombra: SombraPersonaje = null


func _ready() -> void:
	if has_node("SombraPersonaje"):
		sombra = $SombraPersonaje as SombraPersonaje
	else:
		sombra = SombraPersonaje.new()
		sombra.name = "SombraPersonaje"
		add_child(sombra)

	if sombra:
		sombra.opacidad = sombra_opacidad
		sombra.tamano = sombra_tamano
		sombra.suavizado = sombra_suavizado
		sombra.offset_z = sombra_offset_z
