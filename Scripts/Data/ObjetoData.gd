class_name ObjetoData
extends Resource

## Datos de un objeto 3D del escenario (plataformas, escaleras, decoración, etc.)

@export var escena_path: String = ""
@export var nombre: String = ""
@export var posicion: Vector3 = Vector3.ZERO
@export var rotacion: Vector3 = Vector3.ZERO
@export var escala: Vector3 = Vector3.ONE


func _init(
	path: String = "",
	pos: Vector3 = Vector3.ZERO,
	rot: Vector3 = Vector3.ZERO,
	esc: Vector3 = Vector3.ONE
) -> void:
	escena_path = path
	posicion = pos
	rotacion = rot
	escala = esc
	if path != "":
		var partes: PackedStringArray = path.split("/")
		nombre = partes[-1].replace(".tscn", "").replace(".glb", "")


func obtener_nombre() -> String:
	if nombre != "":
		return nombre
	var partes: PackedStringArray = escena_path.split("/")
	return partes[-1].replace(".tscn", "").replace(".glb", "")
