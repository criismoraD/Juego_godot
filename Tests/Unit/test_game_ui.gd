extends "res://addons/gut/test.gd"

var GameUIScript = load("res://Scripts/UI/GameUI.gd")
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
