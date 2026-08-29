extends Node
## SceneManager - Singleton para gestión de transiciones asíncronas fluidas.
##
## Uso:
##   SceneManager.change_scene("res://Levels/NIVEL01/NIVEL01.tscn")

signal scene_load_started(path: String)
signal scene_load_progress(progress: float)
signal scene_load_completed(path: String)

var loading_screen_scene: PackedScene = preload("res://UI/LoadingScreen.tscn")

var _current_loading_screen: CanvasLayer = null
var _loading_path: String = ""
var _is_loading: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Cambia a una nueva escena utilizando la pantalla de carga asíncrona
func change_scene(target_path: String, _extra_prewarms: Array = []) -> void:
	if _is_loading:
		push_warning("[SceneManager] Ya hay una carga en progreso hacia: " + _loading_path)
		return

	_is_loading = true
	_loading_path = target_path

	# 1. Instanciar y mostrar pantalla de carga
	if loading_screen_scene:
		_current_loading_screen = loading_screen_scene.instantiate() as CanvasLayer
		if _current_loading_screen:
			get_tree().root.add_child(_current_loading_screen)
			if _current_loading_screen.has_method("fade_in"):
				_current_loading_screen.fade_in(0.3)

	scene_load_started.emit(target_path)

	# 2. Iniciar carga en hilo asíncrono (use_sub_threads = false para evitar deadlocks de sub-recursos en Godot 4)
	var err := ResourceLoader.load_threaded_request(target_path, "", false)
	if err != OK:
		push_error("[SceneManager] Error al iniciar carga asíncrona de: " + target_path)
		_finalizar_carga_fallida(target_path)
		return

	# 3. Monitorear progreso
	_monitorear_carga_async(target_path)


func _monitorear_carga_async(target_path: String) -> void:
	var progress_array: Array = []
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.THREAD_LOAD_IN_PROGRESS
	var max_wait_time: float = 6.0
	var elapsed: float = 0.0

	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		status = ResourceLoader.load_threaded_get_status(target_path, progress_array)
		var progress: float = progress_array[0] if progress_array.size() > 0 else 0.0

		if is_instance_valid(_current_loading_screen):
			_current_loading_screen.set_progress(progress * 0.95)
			_current_loading_screen.set_status_text("Cargando escenario y dependencias...")

		scene_load_progress.emit(progress * 0.95)
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if elapsed > max_wait_time:
			push_warning("[SceneManager] Tiempo límite de carga asíncrona alcanzado. Forzando carga directa.")
			break

	if status != ResourceLoader.THREAD_LOAD_LOADED:
		push_error("[SceneManager] Falló o expiró la carga asíncrona: " + target_path)
		_finalizar_carga_fallida(target_path)
		return

	var packed_scene := ResourceLoader.load_threaded_get(target_path) as PackedScene
	if not packed_scene:
		push_error("[SceneManager] Recurso cargado no es PackedScene: " + target_path)
		_finalizar_carga_fallida(target_path)
		return

	# 4. Completar progreso al 100%
	if is_instance_valid(_current_loading_screen):
		_current_loading_screen.set_progress(1.0)
		_current_loading_screen.set_status_text("¡Listo!")
	scene_load_progress.emit(1.0)

	# Pausa breve para que se aprecie la barra llena
	await get_tree().create_timer(0.12, false, false, true).timeout

	# 5. Cambiar a la nueva escena
	get_tree().change_scene_to_packed(packed_scene)
	scene_load_completed.emit(target_path)

	# 6. Desvanecer la pantalla de carga suavemente para revelar el juego sin bloquear inputs
	if is_instance_valid(_current_loading_screen):
		if _current_loading_screen.has_method("fade_out"):
			_current_loading_screen.fade_out(0.35)
		else:
			_current_loading_screen.queue_free()
		_current_loading_screen = null

	_is_loading = false
	_loading_path = ""


func _finalizar_carga_fallida(target_path: String) -> void:
	if is_instance_valid(_current_loading_screen):
		_current_loading_screen.queue_free()
		_current_loading_screen = null
	_is_loading = false
	_loading_path = ""
	get_tree().change_scene_to_file(target_path)