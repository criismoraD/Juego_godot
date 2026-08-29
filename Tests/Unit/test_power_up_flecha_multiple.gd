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


func test_almacenamiento_reserva_y_cambio_municion_con_r():
	# Arrange: Jugador tiene flechas múltiples
	_player.flechas_multiples = 5
	_player.flechas_explosivas = 0
	_player.municion_activa = Player.TipoMunicion.MULTIPLE

	# Act: Jugador obtiene flechas explosivas
	_player.agregar_flechas_explosivas(10)

	# Assert: Las múltiples se conservan almacenadas (5) y las explosivas quedan en 10 (activas)
	assert_eq(_player.flechas_multiples, 5, "Al obtener flechas explosivas, las múltiples se conservan almacenadas")
	assert_eq(_player.flechas_explosivas, 10, "El jugador debe tener 10 flechas explosivas")
	assert_eq(_player.municion_activa, Player.TipoMunicion.EXPLOSIVA, "La munición activa pasa a ser explosiva")

	# Act: Cambiar munición con tecla R (ciclo: EXPLOSIVA -> MULTIPLE -> NORMAL -> EXPLOSIVA)
	_player.cambiar_tipo_municion()
	assert_eq(_player.municion_activa, Player.TipoMunicion.MULTIPLE, "Al presionar R cambia a MULTIPLE")

	_player.cambiar_tipo_municion()
	assert_eq(_player.municion_activa, Player.TipoMunicion.NORMAL, "Al presionar R cambia a NORMAL")

	_player.cambiar_tipo_municion()
	assert_eq(_player.municion_activa, Player.TipoMunicion.EXPLOSIVA, "Al presionar R vuelve a ciclar a EXPLOSIVA")


func _crear_aliada_mock() -> Node:
	var aliada = AllyArcherScript.new()
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	var lib := AnimationLibrary.new()
	lib.add_animation("Armature|Armature|IDLE", Animation.new())
	lib.add_animation("Armature|Armature|DISPARAR", Animation.new())
	lib.add_animation("Armature|Armature|CELEBRACION", Animation.new())
	lib.add_animation("Armature|Armature|ELECTROCUTADA", Animation.new())
	ap.add_animation_library("", lib)
	aliada.add_child(ap)
	return aliada


func test_power_up_distribucion_aliadas():
	# Arrange
	var aliada_1 = _crear_aliada_mock()
	var aliada_2 = _crear_aliada_mock()
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


func test_almacenamiento_municion_aliadas():
	# Arrange
	var aliada = _crear_aliada_mock()
	aliada.flechas_explosivas = 5
	aliada.flechas_multiples = 0
	add_child_autofree(aliada)

	# Act: Aliada recibe múltiples
	aliada.agregar_flechas_multiples(3)

	# Assert: Ambas municiones se almacenan en reserva
	assert_eq(aliada.flechas_explosivas, 5, "Aliada: flechas explosivas deben conservarse en 5")
	assert_eq(aliada.flechas_multiples, 3, "Aliada: flechas múltiples deben ser 3")

	# Act: Aliada recibe explosivas adicionales
	aliada.agregar_flechas_explosivas(5)

	# Assert: Se acumulan las explosivas y se conservan las múltiples
	assert_eq(aliada.flechas_multiples, 3, "Aliada: flechas múltiples deben conservarse en 3")
	assert_eq(aliada.flechas_explosivas, 10, "Aliada: flechas explosivas deben ser 10 (5 previas + 5 nuevas)")
