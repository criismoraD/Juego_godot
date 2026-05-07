extends Resource

## Datos de un enemigo dentro de una oleada.

@export var escena_path: String = ""
@export var probabilidad: float = 0.0
@export var nombre: String = ""


func _init(path: String = "", prob: float = 0.0) -> void:
	escena_path = path
	probabilidad = prob
	if path != "":
		var partes: PackedStringArray = path.split("/")
		nombre = partes[-1].replace(".tscn", "").replace(".glb", "")


func obtener_nombre() -> String:
	if nombre != "":
		return nombre
	var partes: PackedStringArray = escena_path.split("/")
	return partes[-1].replace(".tscn", "").replace(".glb", "")
