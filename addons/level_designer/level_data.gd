extends Resource

## Datos de configuración de un nivel del juego.
## Guarda oleadas con enemigos y sus probabilidades, elementos del escenario y fondo.

@export var nivel_numero: int = 1
@export var nombre_nivel: String = ""
@export var oleadas: Array = []
@export var elementos_escenario: Array = []  # Array of ElementoData
@export var escena_fondo: String = ""  # Ruta de la escena de fondo
@export var escena_fondo_3d: String = ""  # Ruta del SubViewport de fondo
@export var musica_index: int = -1  # Índice de AudioManager (-1 = default)


func agregar_oleada():
	var nueva = load("res://addons/level_designer/oleada_data.gd").new()
	nueva.numero = oleadas.size() + 1
	oleadas.append(nueva)
	return nueva


func eliminar_oleada(index: int) -> void:
	if index >= 0 and index < oleadas.size():
		oleadas.remove_at(index)
		# Renumerar
		for i in range(oleadas.size()):
			oleadas[i].numero = i + 1


func agregar_enemigo_a_oleada(oleada_idx: int, escena_path: String, spawn_time: float = 0.0, spawn_pos: Vector3 = Vector3.ZERO) -> void:
	if oleada_idx < 0 or oleada_idx >= oleadas.size():
		return
	oleadas[oleada_idx].agregar_enemigo(escena_path, spawn_time, spawn_pos)


func agregar_elemento(escena_path: String, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO, esc: Vector3 = Vector3.ONE) -> void:
	var nuevo = load("res://addons/level_designer/elemento_data.gd").new(escena_path, pos, rot, esc)
	elementos_escenario.append(nuevo)


func eliminar_elemento(index: int) -> void:
	if index >= 0 and index < elementos_escenario.size():
		elementos_escenario.remove_at(index)


func obtener_resumen() -> String:
	var resumen := "Nivel %d: %s\n" % [nivel_numero, nombre_nivel]
	resumen += "Oleadas: %d\n" % oleadas.size()
	for oleada in oleadas:
		resumen += "  Oleada %d: %d enemigos\n" % [oleada.numero, oleada.enemigos.size()]
	resumen += "Elementos: %d\n" % elementos_escenario.size()
	resumen += "Fondo: %s\n" % (escena_fondo if escena_fondo != "" else "default")
	return resumen
