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
@export var es_pacifista: bool = false  ## Si true, el nivel se completa sin matar enemigos
@export var tiempo_limite: float = 0.0  ## Tiempo límite en segundos (0 = sin límite)
@export var dificultad: int = 1  ## 1=Fácil, 2=Normal, 3=Difícil


func _validate_property(property: Dictionary) -> void:
	# Validación básica de datos
	if property.name == "nivel_numero":
		if nivel_numero < 1 or nivel_numero > 30:
			property.usage = PROPERTY_USAGE_NONE
	if property.name == "dificultad":
		if dificultad < 1 or dificultad > 3:
			property.usage = PROPERTY_USAGE_NONE


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


func validar_datos() -> bool:
	## Valida que los datos del nivel sean correctos
	if nivel_numero < 1 or nivel_numero > 30:
		push_error("[LevelData] nivel_numero inválido: %d" % nivel_numero)
		return false
	
	if dificultad < 1 or dificultad > 3:
		push_error("[LevelData] dificultad inválida: %d" % dificultad)
		return false
	
	for i in range(oleadas.size()):
		var oleada = oleadas[i]
		if oleada.numero != i + 1:
			push_warning("[LevelData] Oleada %d tiene número incorrecto: %d" % [i, oleada.numero])
			oleada.numero = i + 1
		
		if oleada.tiempo_entre_spawns <= 0:
			push_warning("[LevelData] Oleada %d tiene tiempo_entre_spawns inválido: %.2f" % [i, oleada.tiempo_entre_spawns])
		
		if oleada.tiempo_entre_oleadas < 0:
			push_warning("[LevelData] Oleada %d tiene tiempo_entre_oleadas negativo: %.2f" % [i, oleada.tiempo_entre_oleadas])
	
	return true


func obtener_total_enemigos() -> int:
	var total := 0
	for oleada in oleadas:
		total += oleada.obtener_total_enemigos()
	return total


func obtener_duracion_estimada() -> float:
	## Calcula duración estimada del nivel en segundos
	var duracion := 0.0
	for oleada in oleadas:
		duracion += oleada.tiempo_entre_oleadas
		if oleada.enemigos.size() > 0:
			duracion += oleada.tiempo_entre_spawns * oleada.obtener_total_enemigos()
	return duracion
