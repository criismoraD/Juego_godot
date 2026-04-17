extends "res://addons/gut/test.gd"

var PlayerScript = load("res://Scripts/Characters/Player.gd")
var _player: Player = null

# Mock para AudioManager
class MockAudioManager extends Node:
	func play_sfx(_name, _boost = 0.0): pass
	func stop_bow_tension(): pass
	func reset_bow_hold(): pass

func before_each():
	# Crear instancia del jugador
	_player = PlayerScript.new()

	# Inyectar MockAudioManager si es necesario (o añadir al tree como autoload mock)
	if not get_tree().root.has_node("AudioManager"):
		var mock_audio = MockAudioManager.new()
		mock_audio.name = "AudioManager"
		get_tree().root.add_child(mock_audio)

	# Añadir al tree para que _ready funcione parcialmente (aunque fallará AnimationTree)
	# Pero para tests de lógica pura de recibir_dano, nos interesa evitar crashes
	get_tree().root.add_child(_player)

func after_each():
	_player.free()
	if get_tree().root.has_node("AudioManager"):
		var mock_audio = get_tree().root.get_node("AudioManager")
		get_tree().root.remove_child(mock_audio)
		mock_audio.free()

func test_recibir_dano_reduces_health():
	var initial_health = _player.health
	_player.recibir_dano(1)
	assert_eq(_player.health, initial_health - 1, "La salud debería reducirse en 1")

func test_recibir_dano_invulnerable():
	var initial_health = _player.health
	_player.is_invulnerable = true
	_player.recibir_dano(1)
	assert_eq(_player.health, initial_health, "La salud NO debería reducirse si es invulnerable")

func test_recibir_dano_modo_dios():
	var initial_health = _player.health
	_player.modo_dios = true
	_player.recibir_dano(1)
	assert_eq(_player.health, initial_health, "La salud NO debería reducirse en modo dios")

func test_recibir_dano_is_dead():
	_player.health = 1
	_player.is_dead = true
	_player.recibir_dano(1)
	assert_eq(_player.health, 1, "La salud NO debería reducirse si ya está muerto")

func test_recibir_dano_emits_signal():
	watch_signals(_player)
	_player.recibir_dano(1)
	assert_signal_emitted(_player, "health_changed", "Debería emitirse la señal health_changed")
	assert_signal_emitted_with_parameters(_player, "health_changed", [_player.health])

func test_recibir_dano_cancels_shot():
	_player.current_aim_state = _player.AimState.DRAWING
	_player.recibir_dano(1)
	assert_eq(_player.current_aim_state, _player.AimState.NONE, "El disparo debería cancelarse al recibir daño")
	assert_true(_player.shot_cancelled, "shot_cancelled debería ser true")
