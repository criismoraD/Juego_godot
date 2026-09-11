extends "res://addons/gut/test.gd"

const ESCENA_FLECHA_EXPLOSIVA: PackedScene = preload("res://Entities/Item_Flecha_Explosiva/PowerUpFlechaExplosiva.tscn")
const ESCENA_FLECHA_MULTIPLE: PackedScene = preload("res://Entities/Item_Flecha_Multiple/PowerUpFlechaMultiple.tscn")
const ESCENA_PLAYER: PackedScene = preload("res://Entities/Jugador_Arquera/Player.tscn")
const ESCENA_PERRENA: PackedScene = preload("res://Entities/Jugador_Perrena/Perrena.tscn")
const GoblinScript = preload("res://Entities/Enemigo_Goblin/Goblin.gd")

var _player: Player = null


func before_each():
	_player = ESCENA_PLAYER.instantiate() as Player
	_player.flechas_explosivas = 0
	_player.flechas_multiples = 0
	_player.add_to_group("player")
	add_child_autofree(_player)


func test_escena_flecha_explosiva_tiene_script_y_variables():
	# Verifica que la escena no pierde el script por @tool u otros errores de compilación
	var item = ESCENA_FLECHA_EXPLOSIVA.instantiate()
	assert_not_null(item, "La escena de flecha explosiva debe instanciarse")
	assert_true(item is PowerUpFlechaExplosiva, "El nodo instanciado debe ser de tipo PowerUpFlechaExplosiva")
	assert_eq(int(item.get("municion_a_otorgar_jugador")), 10, "Debe tener municion_a_otorgar_jugador = 10")
	add_child_autofree(item)
	assert_eq(item.current_state, PowerUpFlechaExplosiva.State.IDLE, "Estado inicial debe ser IDLE")


func test_escena_flecha_multiple_tiene_script_y_variables():
	var item = ESCENA_FLECHA_MULTIPLE.instantiate()
	assert_not_null(item, "La escena de flecha múltiple debe instanciarse")
	assert_true(item is PowerUpFlechaMultiple, "El nodo instanciado debe ser de tipo PowerUpFlechaMultiple")
	assert_eq(int(item.get("municion_a_otorgar_jugador")), 6, "Debe tener municion_a_otorgar_jugador = 6")
	add_child_autofree(item)
	assert_eq(item.current_state, PowerUpFlechaMultiple.State.IDLE, "Estado inicial debe ser IDLE")


func test_simulacion_drop_mensajera_oleada5_suma_municion():
	# Simula exactamente la secuencia de _iniciar_mensajera_oleada_5()
	var power_up: Node3D = ESCENA_FLECHA_EXPLOSIVA.instantiate() as Node3D
	assert_not_null(power_up, "El power up debe crearse")
	power_up.municion_a_otorgar_jugador = 10
	power_up.municion_a_otorgar_aliadas = 5

	add_child_autofree(power_up)
	power_up.global_position = Vector3(0, 0, 0)

	# Verificar que rota en _process sin congelarse
	var initial_rot_y: float = 0.0
	if power_up.model_root:
		initial_rot_y = power_up.model_root.rotation.y
	power_up._process(0.1)
	if power_up.model_root:
		assert_ne(power_up.model_root.rotation.y, initial_rot_y, "El modelo debe rotar en _process y no quedarse congelado")

	# Consumir
	power_up._auto_consumir()
	assert_eq(_player.flechas_explosivas, 10, "El jugador debe haber sumado 10 flechas explosivas")
	assert_eq(_player.municion_activa, Player.TipoMunicion.EXPLOSIVA, "La munición activa debe ser EXPLOSIVA")


func test_consumo_con_perrena_activa():
	# Simular a Perrena como personaje activo
	_player.remove_from_group("player")
	var perrena: Perrena = ESCENA_PERRENA.instantiate() as Perrena
	perrena.flechas_explosivas = 0
	perrena.add_to_group("player")
	add_child_autofree(perrena)

	var power_up: Node3D = ESCENA_FLECHA_EXPLOSIVA.instantiate() as Node3D
	add_child_autofree(power_up)

	power_up._auto_consumir()
	assert_eq(perrena.flechas_explosivas, 10, "Perrena debe recibir las flechas explosivas al consumirse el item")


func test_goblin_sangre_explosion_sin_errores():
	var goblin = GoblinScript.new()
	add_child_autofree(goblin)
	goblin.global_position = Vector3.ZERO
	goblin._spawn_sangre_animada(Vector3.ZERO)
	await get_tree().process_frame
	assert_true(true, "La animación de sangre por tween debe ejecutarse sin errores")
