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
	_game_ui.bottom_panel.visible = false
	_game_ui.toggle_ui_btn.visible = false

	# Ejecutar
	_game_ui.set_modo_minimo(false)

	# Verificar
	assert_true(_game_ui.bottom_panel.visible, "bottom_panel debería estar visible si no es modo mínimo")
	assert_true(_game_ui.toggle_ui_btn.visible, "toggle_ui_btn debería estar visible si no es modo mínimo")

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
