extends Resource

## Datos de una oleada dentro de un nivel.

@export var numero: int = 1
@export var enemigos: Array = []
@export var tiempo_entre_spawns: float = 3.0
@export var tiempo_entre_oleadas: float = 5.0


func agregar_enemigo(escena_path: String, probabilidad: float = 0.0) -> void:
	var nuevo = load("res://addons/level_designer/enemigo_data.gd").new()
	nuevo.escena_path = escena_path
	nuevo.probabilidad = probabilidad
	enemigos.append(nuevo)
	_normalizar_probabilidades()


func eliminar_enemigo(index: int) -> void:
	if index >= 0 and index < enemigos.size():
		enemigos.remove_at(index)
		_normalizar_probabilidades()


func set_probabilidad(index: int, valor: float) -> void:
	if index >= 0 and index < enemigos.size():
		enemigos[index].probabilidad = clampf(valor, 0.0, 1.0)
		_normalizar_probabilidades()


func _normalizar_probabilidades() -> void:
	if enemigos.is_empty():
		return
	var total: float = 0.0
	for enemigo in enemigos:
		total += enemigo.probabilidad
	if total > 0.0:
		for enemigo in enemigos:
			enemigo.probabilidad /= total
	else:
		var partes: float = 1.0 / enemigos.size()
		for enemigo in enemigos:
			enemigo.probabilidad = partes


func obtener_nombre_escenas() -> Array[String]:
	var nombres: Array[String] = []
	for enemigo in enemigos:
		var partes: PackedStringArray = enemigo.escena_path.split("/")
		nombres.append(partes[-1].replace(".tscn", "").replace(".glb", ""))
	return nombres
