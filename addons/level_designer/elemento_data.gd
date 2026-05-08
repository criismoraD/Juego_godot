extends Resource

## Datos de un elemento estático del escenario (obstáculos, decoración, etc.)

@export var escena_path: String = ""
@export var posicion: Vector3 = Vector3.ZERO
@export var rotacion: Vector3 = Vector3.ZERO
@export var escala: Vector3 = Vector3.ONE

func _init(path: String = "", pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO, esc: Vector3 = Vector3.ONE) -> void:
	escena_path = path
	posicion = pos
	rotacion = rot
	escala = esc
