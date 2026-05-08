extends Resource

## Datos de un enemigo dentro de una oleada.

@export var escena_path: String = ""
@export var nombre: String = ""

# Propiedades para el nuevo Spawner Data-Driven
@export var spawn_position: Vector3 = Vector3.ZERO
@export var spawn_time: float = 0.0
@export var quantity: int = 1


func _init(path: String = "", s_time: float = 0.0, s_pos: Vector3 = Vector3.ZERO) -> void:
	escena_path = path
	spawn_time = s_time
	spawn_position = s_pos
	if path != "":
		var partes: PackedStringArray = path.split("/")
		nombre = partes[-1].replace(".tscn", "").replace(".glb", "")


func obtener_nombre() -> String:
	if nombre != "":
		return nombre
	var partes: PackedStringArray = escena_path.split("/")
	return partes[-1].replace(".tscn", "").replace(".glb", "")
