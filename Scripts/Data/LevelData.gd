class_name LevelData
extends Resource

## Datos de configuración de un nivel del juego.
## Guarda oleadas con enemigos y objetos del escenario.

@export var nivel_numero: int = 1
@export var nombre_nivel: String = ""
@export var oleadas: Array[OleadaData] = []
@export var objetos_escenario: Array[ObjetoData] = []
@export var escena_fondo: String = ""
@export var musica_index: int = -1  ## Índice de AudioManager (-1 = default)


func agregar_oleada() -> OleadaData:
	var nueva := OleadaData.new()
	nueva.numero = oleadas.size() + 1
	oleadas.append(nueva)
	return nueva


func eliminar_oleada(index: int) -> void:
	if index >= 0 and index < oleadas.size():
		oleadas.remove_at(index)
		for i in range(oleadas.size()):
			oleadas[i].numero = i + 1


func agregar_enemigo_a_oleada(
	oleada_idx: int,
	escena_path: String,
	spawn_time: float = 0.0,
	spawn_pos: Vector3 = Vector3.ZERO,
	qty: int = 1,
	escudo: bool = false
) -> void:
	if oleada_idx < 0 or oleada_idx >= oleadas.size():
		return
	oleadas[oleada_idx].agregar_enemigo(escena_path, spawn_time, spawn_pos, qty, escudo)


func agregar_objeto(
	escena_path: String,
	pos: Vector3 = Vector3.ZERO,
	rot: Vector3 = Vector3.ZERO,
	esc: Vector3 = Vector3.ONE
) -> ObjetoData:
	var nuevo := ObjetoData.new(escena_path, pos, rot, esc)
	objetos_escenario.append(nuevo)
	return nuevo


func eliminar_objeto(index: int) -> void:
	if index >= 0 and index < objetos_escenario.size():
		objetos_escenario.remove_at(index)


func obtener_resumen() -> String:
	var resumen := "Nivel %d: %s\n" % [nivel_numero, nombre_nivel]
	resumen += "Oleadas: %d\n" % oleadas.size()
	for oleada in oleadas:
		resumen += "  Oleada %d: %d enemigos\n" % [oleada.numero, oleada.enemigos.size()]
	resumen += "Objetos: %d\n" % objetos_escenario.size()
	resumen += "Fondo: %s\n" % (escena_fondo if escena_fondo != "" else "default")
	return resumen
