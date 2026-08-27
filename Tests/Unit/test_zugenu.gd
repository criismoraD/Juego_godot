extends "res://addons/gut/test.gd"

var ZugenuScript = load("res://Entities/Enemigo_Zugenu/Zugenu.gd")
var ZugenuScene = load("res://Entities/Enemigo_Zugenu/Zugenu.tscn")
var PlayerScript = load("res://Entities/Jugador_Arquera/Player.gd")

var _zugenu: Zugenu = null
var _player = null


func before_each():
	_zugenu = ZugenuScript.new()
	_player = PlayerScript.new()
	_player.add_to_group("player")
	add_child_autofree(_zugenu)
	add_child_autofree(_player)


func test_zugenu_initialization():
	# Assert: Inicialización correcta de stats y configuración
	assert_not_null(_zugenu, "La instancia de Zugenu no debe ser nula")
	assert_eq(_zugenu.cantidad_flechas_rafaga, 5, "Debe disparar 5 flechas por ráfaga como el power-up múltiple")
	assert_eq(_zugenu.intervalo_flechas_rafaga, 0.055, "El intervalo entre flechas de la ráfaga debe ser ~55ms")
	assert_eq(_zugenu.velocidad_flecha, 8.0, "La velocidad de flecha base debe ser 8.0")
	assert_eq(_zugenu.intervalo_disparo, 3.5, "El intervalo entre ráfagas debe ser 3.5s")
	assert_true(_zugenu.is_in_group("enemies"), "Debe pertenecer al grupo enemies")


func test_zugenu_scene_instantiation():
	# Arrange & Act
	var inst = ZugenuScene.instantiate()
	add_child_autofree(inst)

	# Assert
	assert_not_null(inst, "La escena Zugenu.tscn debe instanciarse correctamente")
	assert_true(inst is Zugenu, "Debe ser de tipo Zugenu")
	assert_eq(inst.collision_layer, 4, "Debe estar en la capa de colisión 4 (enemies)")


func test_zugenu_cambio_estados():
	# Arrange
	_zugenu.current_state = EnemyBase.State.WALKING

	# Act & Assert
	_zugenu._change_state(EnemyBase.State.SHOOTING)
	assert_eq(_zugenu.current_state, EnemyBase.State.SHOOTING, "Debe pasar al estado SHOOTING")

	_zugenu._change_state(EnemyBase.State.DYING)
	assert_eq(_zugenu.current_state, EnemyBase.State.DYING, "Debe pasar al estado DYING")


func test_zugenu_dano_y_muerte():
	# Arrange
	_zugenu.health = 2
	_zugenu.current_state = EnemyBase.State.WALKING

	# Act: Aplicar 1 de daño
	_zugenu.take_damage(1.0)

	# Assert
	assert_eq(_zugenu.health, 1, "La vida debe ser 1 tras recibir 1 de daño")
	assert_eq(_zugenu.current_state, EnemyBase.State.WALKING, "Debe seguir caminando si aún tiene vida")

	# Act: Aplicar daño letal
	_zugenu.take_damage(1.0)

	# Assert
	assert_eq(_zugenu.health, 0, "La vida debe ser 0 tras el daño letal")
	assert_eq(_zugenu.current_state, EnemyBase.State.DYING, "Debe pasar a DYING al llegar a 0 de vida")


func test_zugenu_drop_power_up_configuracion():
	# Arrange
	_zugenu.drop_chance_flecha_multiple = 1.0  # Forzar 100% de drop para el test
	_zugenu.municion_drop_jugador = 6

	# Assert
	assert_not_null(_zugenu.power_up_multiple_scene, "Debe tener asignada la escena de PowerUpFlechaMultiple")
	assert_eq(_zugenu.municion_drop_jugador, 6, "El drop de Zugenu debe configurar 6 disparos al jugador")
