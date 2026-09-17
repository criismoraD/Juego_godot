@tool
class_name CuerdaPirata
extends Node3D

## Cuerda pirata posicionable para el nivel del rio.
## Wrapper sobre un Sprite3D: el nodo raiz queda libre para
## mover/rotar/escalar en el editor, el hijo "Visual" solo
## aplica escala base. Estatica, sin logica automatica.

const ALTURA_PIVOTE_DEFAULT: float = 0.0

@export_category("Cuerda Pirata")
@export var pixel_size: float = 0.005:
	set(nuevo_valor):
		pixel_size = nuevo_valor
		if is_node_ready():
			_aplicar_pixel_size()
@export var escala_base: Vector3 = Vector3.ONE:
	set(nuevo_valor):
		escala_base = nuevo_valor
		if is_node_ready():
			_aplicar_escala_base()
@export var altura_pivote: float = ALTURA_PIVOTE_DEFAULT:
	set(nuevo_valor):
		altura_pivote = nuevo_valor
		if is_node_ready():
			_aplicar_altura_pivote()

@onready var visual: Node3D = $Visual
@onready var sprite: Sprite3D = $Visual/Cuerda


func _ready() -> void:
	_aplicar_pixel_size()
	_aplicar_escala_base()
	_aplicar_altura_pivote()


func _aplicar_pixel_size() -> void:
	if not is_instance_valid(sprite):
		return
	sprite.pixel_size = pixel_size


func _aplicar_escala_base() -> void:
	if not is_instance_valid(visual):
		return
	visual.scale = escala_base


func _aplicar_altura_pivote() -> void:
	if not is_instance_valid(sprite):
		return
	sprite.position.y = altura_pivote
