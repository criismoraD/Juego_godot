extends "res://addons/gut/test.gd"

var PowerUpFlechaExplosivaScript = load("res://Entities/Item_Flecha_Explosiva/PowerUpFlechaExplosiva.gd")
var PlayerScript = load("res://Entities/Jugador_Arquera/Player.gd")
var AllyArcherScript = load("res://Entities/Aliada_Arquera/AllyArcher.gd")
var LonkoScript = load("res://Entities/Enemigo_Lonko/Lonko.gd")
var GoblinScript = load("res://Entities/Enemigo_Goblin/Goblin.gd")

var _power_up = null
var _player = null

func before_each():
	_power_up = PowerUpFlechaExplosivaScript.new()
	_player = PlayerScript.new()
	_player.flechas_explosivas = 0
	_player.add_to_group("player")
	add_child_autofree(_power_up)
	add_child_autofree(_player)

func test_power_up_initialization():
	# Assert
	assert_not_null(_power_up, "El power-up de flecha explosiva debe instanciarse correctamente")
	assert_eq(_power_up.municion_a_otorgar_jugador, 10, "Debe otorgar 10 flechas al jugador")
	assert_eq(_power_up.municion_a_otorgar_aliadas, 5, "Debe otorgar 5 flechas a cada aliada")
	assert_eq(_power_up.tiempo_en_pantalla, 3.0, "El tiempo de auto-consumo debe ser de 3.0 segundos")
	assert_eq(_power_up.velocidad_rotacion_y, 3.0, "La velocidad de rotación continua debe ser de 3.0 rad/s")

func test_power_up_consumo_jugador():
	# Arrange
	_player.flechas_explosivas = 0

	# Act: Consumir el power-up
	_power_up._auto_consumir()

	# Assert
	assert_eq(_player.flechas_explosivas, 10, "El jugador debe tener 10 flechas explosivas acumuladas tras el consumo")

	# Act: Consumir un segundo power-up (acumulación)
	_power_up.current_state = PowerUpFlechaExplosiva.State.IDLE
	_power_up._auto_consumir()
	assert_eq(_player.flechas_explosivas, 20, "Las flechas explosivas deben acumularse (+10 -> 20)")

func test_power_up_distribucion_aliadas():
	# Arrange
	var aliada_1 = AllyArcherScript.new()
	var aliada_2 = AllyArcherScript.new()
	aliada_1.flechas_explosivas = 0
	aliada_2.flechas_explosivas = 0
	aliada_1.add_to_group("allies")
	aliada_2.add_to_group("allies")
	add_child_autofree(aliada_1)
	add_child_autofree(aliada_2)

	# Act
	_power_up._auto_consumir()

	# Assert
	assert_eq(aliada_1.flechas_explosivas, 5, "La aliada 1 debe recibir 5 flechas explosivas")
	assert_eq(aliada_2.flechas_explosivas, 5, "La aliada 2 debe recibir 5 flechas explosivas")

func test_probabilidades_drop_lonko_y_goblin():
	# Arrange
	var lonko = LonkoScript.new()
	var goblin = GoblinScript.new()
	add_child_autofree(lonko)
	add_child_autofree(goblin)

	# Assert
	assert_eq(lonko.drop_chance_flecha_explosiva, 0.30, "La Arquera Lonko debe tener 30% de probabilidad de drop")
	assert_eq(goblin.drop_chance_flecha_explosiva, 0.05, "El Goblin Ballestero debe tener 5% de probabilidad de drop")
	assert_not_null(lonko.power_up_explosivo_scene, "Lonko debe tener asignada la escena del power-up")
	assert_not_null(goblin.flecha_explosiva_powerup_scene, "Goblin debe tener asignada la escena del power-up")
