extends "res://addons/gut/test.gd"

var PowerUpFlechaMultipleScript = load("res://Entities/Item_Flecha_Multiple/PowerUpFlechaMultiple.gd")
var PowerUpFlechaExplosivaScript = load("res://Entities/Item_Flecha_Explosiva/PowerUpFlechaExplosiva.gd")
var PlayerScript = load("res://Entities/Jugador_Arquera/Player.gd")
var AllyArcherScript = load("res://Entities/Aliada_Arquera/AllyArcher.gd")

var _power_up = null
var _player = null


func before_each():
	_power_up = PowerUpFlechaMultipleScript.new()
	_player = PlayerScript.new()
	_player.flechas_explosivas = 0
	_player.flechas_multiples = 0
	_player.add_to_group("player")
	add_child_autofree(_power_up)
	add_child_autofree(_player)


func test_power_up_initialization():
	# Assert
	assert_not_null(_power_up, "El power-up de flecha múltiple debe instanciarse correctamente")
	assert_eq(_power_up.municion_a_otorgar_jugador, 6, "Por defecto debe otorgar 6 flechas al jugador")
	assert_eq(_power_up.municion_a_otorgar_aliadas, 3, "Debe otorgar 3 flechas a cada aliada")
	assert_eq(_power_up.tiempo_en_pantalla, 3.0, "El tiempo de auto-consumo debe ser de 3.0 segundos")
	assert_eq(_power_up.velocidad_rotacion_y, 3.0, "La velocidad de rotación continua debe ser de 3.0 rad/s")


func test_power_up_consumo_jugador():
	# Arrange
	_player.flechas_multiples = 0

	# Act: Consumir el power-up
	_power_up._auto_consumir()

	# Assert
	assert_eq(_player.flechas_multiples, 6, "El jugador debe tener 6 flechas múltiples tras el consumo")


func test_reemplazo_mutuo_flecha_explosiva_reemplaza_multiple():
	# Arrange: Jugador tiene flechas múltiples
	_player.flechas_multiples = 5
	_player.flechas_explosivas = 0

	# Act: Jugador obtiene flechas explosivas
	_player.agregar_flechas_explosivas(10)

	# Assert: Las múltiples se resetean a 0 y las explosivas quedan en 10
	assert_eq(_player.flechas_multiples, 0, "Al obtener flechas explosivas, las flechas múltiples deben ser 0")
	assert_eq(_player.flechas_explosivas, 10, "El jugador debe tener 10 flechas explosivas")


func test_reemplazo_mutuo_flecha_multiple_reemplaza_explosiva():
	# Arrange: Jugador tiene flechas explosivas
	_player.flechas_explosivas = 8
	_player.flechas_multiples = 0

	# Act: Jugador obtiene flechas múltiples
	_player.agregar_flechas_multiples(6)

	# Assert: Las explosivas se resetean a 0 y las múltiples quedan en 6
	assert_eq(_player.flechas_explosivas, 0, "Al obtener flechas múltiples, las flechas explosivas deben ser 0")
	assert_eq(_player.flechas_multiples, 6, "El jugador debe tener 6 flechas múltiples")


func test_power_up_distribucion_aliadas():
	# Arrange
	var aliada_1 = AllyArcherScript.new()
	var aliada_2 = AllyArcherScript.new()
	aliada_1.flechas_multiples = 0
	aliada_2.flechas_multiples = 0
	aliada_1.add_to_group("allies")
	aliada_2.add_to_group("allies")
	add_child_autofree(aliada_1)
	add_child_autofree(aliada_2)

	# Act
	_power_up._auto_consumir()

	# Assert
	assert_eq(aliada_1.flechas_multiples, 3, "La aliada 1 debe recibir 3 flechas múltiples")
	assert_eq(aliada_2.flechas_multiples, 3, "La aliada 2 debe recibir 3 flechas múltiples")


func test_reemplazo_mutuo_aliadas():
	# Arrange
	var aliada = AllyArcherScript.new()
	aliada.flechas_explosivas = 5
	aliada.flechas_multiples = 0
	add_child_autofree(aliada)

	# Act: Aliada recibe múltiples
	aliada.agregar_flechas_multiples(3)

	# Assert
	assert_eq(aliada.flechas_explosivas, 0, "Aliada: flechas explosivas deben resetearse a 0")
	assert_eq(aliada.flechas_multiples, 3, "Aliada: flechas múltiples deben ser 3")

	# Act: Aliada recibe explosivas
	aliada.agregar_flechas_explosivas(5)

	# Assert
	assert_eq(aliada.flechas_multiples, 0, "Aliada: flechas múltiples deben resetearse a 0")
	assert_eq(aliada.flechas_explosivas, 5, "Aliada: flechas explosivas deben ser 5")
