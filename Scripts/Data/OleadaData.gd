class_name OleadaData
extends Resource

## Datos de una oleada dentro de un nivel.

@export var numero: int = 1
@export var enemigos: Array[EnemigoData] = []
@export var tiempo_entre_spawns: float = 3.0
@export var tiempo_entre_oleadas: float = 5.0


func agregar_enemigo(
	escena_path: String,
	spawn_time: float = 0.0,
	spawn_pos: Vector3 = Vector3.ZERO,
	qty: int = 1,
	escudo: bool = false
) -> EnemigoData:
	var nuevo := EnemigoData.new(escena_path, spawn_time, spawn_pos, qty, escudo)
	enemigos.append(nuevo)
	return nuevo


func eliminar_enemigo(index: int) -> void:
	if index >= 0 and index < enemigos.size():
		enemigos.remove_at(index)


func obtener_nombres_escenas() -> Array[String]:
	var nombres: Array[String] = []
	for enemigo in enemigos:
		nombres.append(enemigo.obtener_nombre())
	return nombres


func obtener_total_enemigos() -> int:
	var total: int = 0
	for enemigo in enemigos:
		total += enemigo.quantity
	return total
