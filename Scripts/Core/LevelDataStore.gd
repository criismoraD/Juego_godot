extends Node

## Almacén central de configuraciones de nivel (autoload).
## Carga/guarda Resources .tres de LevelData.

const LEVELS_DIR := "res://Levels/"
const MAX_LEVELS := 30

var niveles: Dictionary = {}  # {int: LevelData}


func _ready() -> void:
	_crear_directorio_si_no_existe()
	_cargar_todos_los_niveles()


func _crear_directorio_si_no_existe() -> void:
	if not DirAccess.dir_exists_absolute(LEVELS_DIR):
		DirAccess.make_dir_recursive_absolute(LEVELS_DIR)


func _cargar_todos_los_niveles() -> void:
	for i: int in range(1, MAX_LEVELS + 1):
		var path: String = _ruta_nivel(i)
		if ResourceLoader.exists(path):
			niveles[i] = load(path)
		else:
			niveles[i] = _crear_nivel_vacio(i)


func _crear_nivel_vacio(numero: int) -> LevelData:
	var data := LevelData.new()
	data.nivel_numero = numero
	data.nombre_nivel = "Nivel %02d" % numero
	return data


func _ruta_nivel(numero: int) -> String:
	return LEVELS_DIR + "level_%02d.tres" % numero


func obtener_nivel(numero: int) -> LevelData:
	if not niveles.has(numero):
		niveles[numero] = _crear_nivel_vacio(numero)
	return niveles[numero]


func guardar_nivel(numero: int) -> Error:
	if not niveles.has(numero):
		return ERR_DOES_NOT_EXIST
	var path: String = _ruta_nivel(numero)
	var resultado: Error = ResourceSaver.save(niveles[numero], path)
	if resultado == OK:
		print("[LevelDataStore] Nivel %d guardado en %s" % [numero, path])
	else:
		push_error("[LevelDataStore] Error guardando nivel %d: %s" % [numero, error_string(resultado)])
	return resultado


func guardar_todos() -> void:
	for numero: int in niveles.keys():
		guardar_nivel(numero)
	print("[LevelDataStore] Todos los niveles guardados")


func eliminar_nivel(numero: int) -> void:
	if niveles.has(numero):
		niveles[numero] = _crear_nivel_vacio(numero)
		var path: String = _ruta_nivel(numero)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func obtener_numeros_con_config() -> Array[int]:
	var con_config: Array[int] = []
	for numero: int in niveles.keys():
		var data: LevelData = niveles[numero]
		if data.oleadas.size() > 0 or data.objetos_escenario.size() > 0:
			con_config.append(numero)
	return con_config
