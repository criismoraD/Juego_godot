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
	assert_eq(_power_up.municion_a_otorgar_jugador, 10, "Por defecto debe otorgar 10 flechas al jugador")
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


func test_drop_de_goblin_otorga_solo_5_al_jugador():
	# Arrange: drop garantizado y escena limpia de otros power-ups
	var goblin = GoblinScript.new()
	goblin.drop_chance_flecha_explosiva = 1.0
	add_child_autofree(goblin)
	assert_eq(goblin.municion_drop_jugador, 5, "El Goblin debe configurar 5 como excepción")
	_limpiar_powerups_previos()

	# Act
	goblin._drop_power_up()
	await get_tree().process_frame

	# Assert: el ítem dropeado por el Goblin queda configurado con 5
	var item_goblin := _buscar_item_dropeado()
	assert_not_null(item_goblin, "El Goblin debe dropear el power-up")
	if item_goblin:
		assert_eq(int(item_goblin.municion_a_otorgar_jugador), 5, "El drop del Goblin debe sumar solo 5 al contador")
		item_goblin.free()


func test_drop_por_defecto_lonko_y_otros_otorgan_10():
	# Arrange: Lonko con drop garantizado
	var lonko = LonkoScript.new()
	lonko.drop_chance_flecha_explosiva = 1.0
	add_child_autofree(lonko)
	_limpiar_powerups_previos()

	# Act
	lonko._drop_power_up()
	await get_tree().process_frame

	# Assert: sin configuración especial, el ítem mantiene las 10 por defecto
	var item_lonko := _buscar_item_dropeado()
	assert_not_null(item_lonko, "La Lonko debe dropear el power-up")
	if item_lonko:
		assert_eq(int(item_lonko.municion_a_otorgar_jugador), 10, "Los drops que no son del Goblin deben sumar 10")
		item_lonko.free()


## Elimina power-ups residuales para que las búsquedas de drops sean exactas.
func _limpiar_powerups_previos() -> void:
	for it in get_tree().root.find_children("*", "Area3D", true, false):
		if it is PowerUpFlechaExplosiva and it != _power_up:
			it.free()
	await get_tree().process_frame


## Busca un PowerUpFlechaExplosiva distinto de la instancia base del before_each.
func _buscar_item_dropeado() -> Node:
	for it in get_tree().root.find_children("*", "Area3D", true, false):
		if it is PowerUpFlechaExplosiva and it != _power_up:
			return it
	return null

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
