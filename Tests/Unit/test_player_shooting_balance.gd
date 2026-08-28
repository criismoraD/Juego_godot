extends "res://addons/gut/test.gd"

var PlayerScript = load("res://Entities/Jugador_Arquera/Player.gd")
var _player = null


func before_each():
	_player = PlayerScript.new()
	add_child_autofree(_player)


func test_shooting_parameters_defaults():
	# Assert: Comprobar que los parámetros de disparo evitan el exploit de spam de francotirador
	assert_gt(_player.duracion_carga, 0.5, "duracion_carga debe ser mayor a 0.5s para requerir carga real")
	assert_gte(_player.tiempo_tensar, 0.15, "tiempo_tensar debe ser al menos 0.15s")
	assert_gte(_player.cadencia_disparo, 0.15, "cadencia_disparo debe tener al menos 0.15s de cooldown")


func test_cooldown_bloquea_disparo_inmediato():
	# Arrange
	_player._cooldown_disparo_timer = 0.2
	_player.current_aim_state = _player.AimState.NONE

	# Act: Simular un clic mientras el cooldown está activo
	# El cooldown debe permanecer activo y no pasar a DRAWING
	assert_gt(_player._cooldown_disparo_timer, 0.0, "El cooldown debe estar activo")
	assert_eq(_player.current_aim_state, _player.AimState.NONE, "No debe iniciar tensado durante cooldown")


func test_quick_release_produces_low_power():
	# Arrange: Disparo rápido sin cargar (suelta durante DRAWING)
	_player.current_aim_state = _player.AimState.DRAWING
	_player.state_timer = 0.05
	_player.charge_time = 0.0

	# Act: Ejecutar start_shooting
	_player.start_shooting()

	# Assert: La potencia debe ser baja (no francotirador al 100%)
	assert_lt(_player.last_charge_power, 0.3, "Un clic rápido sin cargar debe tener potencia baja (< 30%)")
	assert_gt(_player._cooldown_disparo_timer, 0.0, "Debe iniciar el cooldown tras disparar")
