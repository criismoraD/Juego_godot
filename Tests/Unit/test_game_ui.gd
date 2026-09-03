extends "res://addons/gut/test.gd"

var GameUIScript = load("res://UI/GameUI.gd")
var _game_ui = null

# Mock para AudioManager si no está presente
class MockAudioManager extends Node:
	func play_music(_index): pass
	func set_music_volume(_value): pass
	func set_sfx_volume(_value): pass
	func stop_all(): pass

var _mock_audio_created: bool = false

func before_each():
	_game_ui = GameUIScript.new()

	# Inyectar MockAudioManager si es necesario
	if not get_tree().root.has_node("AudioManager"):
		var mock_audio = MockAudioManager.new()
		mock_audio.name = "AudioManager"
		get_tree().root.add_child(mock_audio)
		_mock_audio_created = true

	# Inicializar los nodos que set_modo_minimo usa
	_game_ui.bottom_panel = Control.new()
	_game_ui.toggle_ui_btn = Button.new()

	# Añadirlos como hijos para que sean válidos (aunque set_modo_minimo solo chequea si existen)
	_game_ui.add_child(_game_ui.bottom_panel)
	_game_ui.add_child(_game_ui.toggle_ui_btn)

func after_each():
	if is_instance_valid(_game_ui):
		_game_ui.free()

	if _mock_audio_created and get_tree().root.has_node("AudioManager"):
		var mock_audio = get_tree().root.get_node("AudioManager")
		get_tree().root.remove_child(mock_audio)
		mock_audio.free()
		_mock_audio_created = false

func test_set_modo_minimo_true():
	# Preparar: UI visible por defecto
	_game_ui.bottom_panel.visible = true
	_game_ui.toggle_ui_btn.visible = true

	# Ejecutar
	_game_ui.set_modo_minimo(true)

	# Verificar
	assert_false(_game_ui.bottom_panel.visible, "bottom_panel debería estar oculto en modo mínimo")
	assert_false(_game_ui.toggle_ui_btn.visible, "toggle_ui_btn debería estar oculto en modo mínimo")

func test_set_modo_minimo_false():
	# Preparar: UI oculta
	_game_ui.debug_ui_enabled = true
	_game_ui.bottom_panel.visible = false
	_game_ui.toggle_ui_btn.visible = false

	# Ejecutar
	_game_ui.set_modo_minimo(false)

	# Verificar
	assert_false(_game_ui.bottom_panel.visible, "bottom_panel debería permanecer oculto si no es modo mínimo")
	assert_true(_game_ui.toggle_ui_btn.visible, "toggle_ui_btn debería estar visible si no es modo mínimo")

func test_set_modo_minimo_false_keeps_debug_ui_hidden_by_default():
	# Preparar: debug UI desactivada por defecto
	_game_ui.debug_ui_enabled = false
	_game_ui.bottom_panel.visible = true
	_game_ui.toggle_ui_btn.visible = true

	# Ejecutar
	_game_ui.set_modo_minimo(false)

	# Verificar
	assert_false(_game_ui.bottom_panel.visible, "bottom_panel debe seguir oculto si debug_ui_enabled es false")
	assert_false(_game_ui.toggle_ui_btn.visible, "toggle_ui_btn debe seguir oculto si debug_ui_enabled es false")

func test_set_modo_minimo_null_safe():
	# Liberar los nodos para probar seguridad ante nulos
	_game_ui.bottom_panel.free()
	_game_ui.bottom_panel = null
	_game_ui.toggle_ui_btn.free()
	_game_ui.toggle_ui_btn = null

	# Esto no debería causar crash
	_game_ui.set_modo_minimo(true)
	_game_ui.set_modo_minimo(false)

	assert_true(true, "La función es segura ante nulos")


func test_aplicar_calidad_bajo():
	add_child(_game_ui)
	_game_ui._Aplicar_Calidad(0)
	assert_eq(_game_ui.Indice_Calidad_Actual, 0, "El índice de calidad actual debería ser 0 (Bajo)")
	assert_eq(Engine.max_fps, 30, "Engine.max_fps debería ser 30 para calidad Baja")
	remove_child(_game_ui)


func test_aplicar_calidad_medio():
	add_child(_game_ui)
	_game_ui._Aplicar_Calidad(1)
	assert_eq(_game_ui.Indice_Calidad_Actual, 1, "El índice de calidad actual debería ser 1 (Medio)")
	assert_eq(Engine.max_fps, 60, "Engine.max_fps debería ser 60 para calidad Media")
	remove_child(_game_ui)


func test_aplicar_calidad_alto():
	add_child(_game_ui)
	_game_ui._Aplicar_Calidad(2)
	assert_eq(_game_ui.Indice_Calidad_Actual, 2, "El índice de calidad actual debería ser 2 (Alto)")
	assert_eq(Engine.max_fps, 0, "Engine.max_fps debería ser 0 (Sin límite) para calidad Alta")
	remove_child(_game_ui)


func test_reconstruir_todos_escudos_mantiene_tipo_y_nombre():
	# Arrange
	var main_scene = Node3D.new()
	get_tree().root.add_child(main_scene)
	
	var parent_node = Node3D.new()
	parent_node.name = "ContenedorEscudos"
	main_scene.add_child(parent_node)
	
	# Instanciar escudo base real
	var esc_base_scene = load("res://Entities/Ambiente_Escudo/Escudo.tscn")
	var esc_base = esc_base_scene.instantiate()
	esc_base.name = "EscudoBaseTest"
	parent_node.add_child(esc_base)
	
	# Instanciar escudo enemigo real
	var esc_enem_scene = load("res://Entities/Ambiente_Escudo/Escudo_enemigo.tscn")
	var esc_enem = esc_enem_scene.instantiate()
	esc_enem.name = "EscudoEnemigoTest"
	parent_node.add_child(esc_enem)
	
	# Inicializar GameUI y agregarlo al árbol
	var game_ui = GameUIScript.new()
	main_scene.add_child(game_ui)
	
	# Forzar que transcurran un par de frames para que _ready de los escudos se ejecute
	# y agregue los escudos al grupo "escudos"
	await wait_seconds(0.1)
	
	# Act: Guardar posiciones originales
	game_ui._guardar_posiciones_escudos()
	await wait_seconds(0.1)
	
	# Reconstruir los escudos
	game_ui._reconstruir_todos_escudos()
	await wait_seconds(0.1)
	
	# Assert
	var nuevo_base = parent_node.get_node_or_null("EscudoBaseTest")
	var nuevo_enem = parent_node.get_node_or_null("EscudoEnemigoTest")
	
	assert_not_null(nuevo_base, "El escudo base reconstruido debería existir")
	assert_not_null(nuevo_enem, "El escudo enemigo reconstruido debería existir")
	
	# Verificar que el escudo base no es escudo enemigo, y el enemigo sí lo es
	if nuevo_base:
		assert_false(nuevo_base.get("es_escudo_enemigo"), "El escudo base no debería ser marcado como enemigo")
	if nuevo_enem:
		assert_true(nuevo_enem.get("es_escudo_enemigo"), "El escudo enemigo debería mantener la marca de enemigo")
	
	# Limpieza
	main_scene.free()


func test_reconstruir_escudo_enemigo_destruido():
	# Arrange
	var main_scene = Node3D.new()
	get_tree().root.add_child(main_scene)

	var parent_node = Node3D.new()
	parent_node.name = "ContenedorEscudos"
	main_scene.add_child(parent_node)

	var esc_enem = load("res://Entities/Ambiente_Escudo/Escudo_enemigo.tscn").instantiate()
	esc_enem.name = "EscudoEnemigoTest"
	parent_node.add_child(esc_enem)

	var game_ui = GameUIScript.new()
	main_scene.add_child(game_ui)
	await wait_seconds(0.1)

	# Guardar originales (debe INCLUIR al escudo enemigo) y destruirlo
	game_ui._guardar_posiciones_escudos()
	await wait_seconds(0.05)
	var guardado_enemigo: bool = false
	for data in game_ui.escudos_originales:
		if data["name"] == "EscudoEnemigoTest":
			guardado_enemigo = true
	assert_true(guardado_enemigo, "El escudo enemigo debe guardarse en escudos_originales")

	esc_enem.queue_free()
	await wait_seconds(0.1)

	# Act: reconstruir (como al reiniciar nivel / iniciar oleada)
	game_ui._reconstruir_todos_escudos()
	await wait_seconds(0.1)

	# Assert: el escudo enemigo destruido vuelve, conservando su tipo
	var nuevo_enem = parent_node.get_node_or_null("EscudoEnemigoTest")
	assert_not_null(nuevo_enem, "El escudo enemigo destruido debe reconstruirse")
	if nuevo_enem:
		assert_true(nuevo_enem.get("es_escudo_enemigo"), "El escudo reconstruido debe seguir siendo enemigo")

	# Limpieza
	main_scene.free()


func test_reconstruir_omitir_enemigos_deja_escudo_enemigo_eliminado():
	# Arrange: escudo enemigo y escudo jugador destruidos
	var main_scene = Node3D.new()
	get_tree().root.add_child(main_scene)
	var parent_node = Node3D.new()
	parent_node.name = "ContenedorEscudos"
	main_scene.add_child(parent_node)

	var esc_enem = load("res://Entities/Ambiente_Escudo/Escudo_enemigo.tscn").instantiate()
	esc_enem.name = "EscudoEnemigoTest"
	parent_node.add_child(esc_enem)
	var esc_base = load("res://Entities/Ambiente_Escudo/Escudo.tscn").instantiate()
	esc_base.name = "EscudoBaseTest"
	parent_node.add_child(esc_base)

	var game_ui = GameUIScript.new()
	main_scene.add_child(game_ui)
	await wait_seconds(0.1)

	game_ui._guardar_posiciones_escudos()
	await wait_seconds(0.05)
	esc_enem.queue_free()
	esc_base.queue_free()
	await wait_seconds(0.1)

	# Act: reconstruir omitiendo enemigos (transición a oleada 5)
	game_ui._reconstruir_todos_escudos(true)
	await wait_seconds(0.1)

	# Assert: el escudo enemigo permanece eliminado; el del jugador vuelve
	assert_null(
		parent_node.get_node_or_null("EscudoEnemigoTest"),
		"Desde la oleada 5 el escudo enemigo debe permanecer eliminado"
	)
	assert_not_null(
		parent_node.get_node_or_null("EscudoBaseTest"),
		"El escudo del jugador sí debe reconstruirse"
	)

	# Limpieza
	main_scene.free()


func test_mostrar_cortinilla_debug_crea_overlay() -> void:
	# Arrange
	add_child(_game_ui)

	# Act
	_game_ui.mostrar_cortinilla_debug(0.1)

	# Assert
	var overlay = _game_ui.get_node_or_null("PantallaVictoriaCortinilla")
	assert_not_null(overlay, "Debe crear el nodo overlay de la cortinilla")
	if overlay:
		assert_eq(overlay.layer, 210, "El overlay debe estar en la capa 210")
		var cortinilla = overlay.get_child(0) as TextureRect
		assert_not_null(cortinilla, "Debe contener el TextureRect de la cortinilla")

	await wait_seconds(0.3)
	remove_child(_game_ui)


func test_ejecutar_cambio_oleada_guarda_solicitud() -> void:
	# Arrange
	add_child(_game_ui)
	GameUIScript.oleada_inicial_solicitada = 0

	# Act
	_game_ui._ejecutar_cambio_oleada_debug(3)

	# Assert
	assert_eq(GameUIScript.oleada_inicial_solicitada, 3, "Debe registrar la oleada inicial solicitada al cambiar desde fuera de NIVEL01")
	GameUIScript.oleada_inicial_solicitada = 0
	remove_child(_game_ui)


func test_ejecutar_cambio_oleada_6_guarda_solicitud() -> void:
	# Arrange
	add_child(_game_ui)
	GameUIScript.oleada_inicial_solicitada = 0

	# Act
	_game_ui._ejecutar_cambio_oleada_debug(6)

	# Assert
	assert_eq(GameUIScript.oleada_inicial_solicitada, 6, "Debe registrar oleada 6 al solicitar cambio")
	GameUIScript.oleada_inicial_solicitada = 0
	remove_child(_game_ui)


