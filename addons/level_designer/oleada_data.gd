extends Resource

## Datos de una oleada dentro de un nivel.

@export var numero: int = 1
@export var enemigos: Array = []
@export var tiempo_entre_spawns: float = 3.0
@export var tiempo_entre_oleadas: float = 5.0


func agregar_enemigo(escena_path: String, spawn_time: float = 0.0, spawn_pos: Vector3 = Vector3.ZERO) -> void:
	var nuevo = load("res://addons/level_designer/enemigo_data.gd").new(escena_path, spawn_time, spawn_pos)
	enemigos.append(nuevo)


func eliminar_enemigo(index: int) -> void:
	if index >= 0 and index < enemigos.size():
		enemigos.remove_at(index)


func obtener_nombre_escenas() -> Array[String]:
	var nombres: Array[String] = []
	for enemigo in enemigos:
		var partes: PackedStringArray = enemigo.escena_path.split("/")
		nombres.append(partes[-1].replace(".tscn", "").replace(".glb", ""))
	return nombres
