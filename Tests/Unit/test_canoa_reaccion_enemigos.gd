extends "res://addons/gut/test.gd"

## Tests unitarios para la reacción de la canoa ante la presencia y contacto con enemigos.
## Valida que la canoa reduzca su velocidad al 50% al acercarse a enemigos en el cauce,
## se detenga por completo al hacer contacto físico/geométrico evitando traspasarlos,
## y reanude la navegación automáticamente cuando el enemigo sea eliminado.

const SCENE_CANOA_PATH: String = "res://Levels/Rio_En_Canoa_Con_Parallax/CanoaProtagonistaRio.tscn"
const MARGEN_FLOAT: float = 0.02


class DummyEnemigo extends CharacterBody3D:
	var health: int = 2
	var current_state: int = 0
	var is_dead: bool = false
	var is_dying: bool = false
	var is_dissolving: bool = false


func after_each() -> void:
	# Asegurar aislamiento estricto retirando los nodos del árbol inmediatamente entre tests
	if get_tree() != null:
		for n in get_tree().get_nodes_in_group("enemies"):
			n.remove_from_group("enemies")
			if n.get_parent():
				n.get_parent().remove_child(n)
			n.queue_free()
		for n in get_tree().get_nodes_in_group("enemigos"):
			n.remove_from_group("enemigos")
			if n.get_parent():
				n.get_parent().remove_child(n)
			n.queue_free()
		for n in get_tree().get_nodes_in_group("canoas_aliadas"):
			n.remove_from_group("canoas_aliadas")
			if n.get_parent():
				n.get_parent().remove_child(n)
			n.queue_free()


func test_canoa_navega_a_velocidad_normal_sin_enemigos() -> void:
	# Arrange
	var canoa_scene := load(SCENE_CANOA_PATH) as PackedScene
	var canoa: CanoaProtagonistaRio = canoa_scene.instantiate() as CanoaProtagonistaRio
	add_child_autofree(canoa)
	canoa.global_position = Vector3(0.0, 0.0, 0.0)
	canoa.iniciar_travesia(1.0)

	# Act
	canoa._process(0.1)

	# Assert
	assert_almost_eq(canoa.obtener_factor_velocidad_actual(), 1.0, MARGEN_FLOAT, "Factor debe ser 1.0 sin enemigos")
	assert_false(canoa.esta_detenida_por_enemigo(), "No debe estar detenida")
	assert_false(canoa.esta_en_presencia_de_enemigo(), "No debe estar en modo presencia")


func test_canoa_desacelera_ante_presencia_de_enemigo() -> void:
	# Arrange: Canoa en el origen y enemigo a 6m adelante en el cauce
	var canoa_scene := load(SCENE_CANOA_PATH) as PackedScene
	var canoa: CanoaProtagonistaRio = canoa_scene.instantiate() as CanoaProtagonistaRio
	add_child_autofree(canoa)
	canoa.global_position = Vector3(0.0, 0.0, 0.0)
	canoa.iniciar_travesia(1.0)

	var enemigo := DummyEnemigo.new()
	enemigo.name = "EnemigoPresencia"
	enemigo.health = 2
	add_child_autofree(enemigo)
	enemigo.add_to_group("enemies")
	enemigo.global_position = Vector3(6.0, 0.0, 0.0)

	# Act
	canoa._process(0.1)

	# Assert
	assert_almost_eq(canoa.obtener_factor_velocidad_actual(), canoa.factor_velocidad_presencia, MARGEN_FLOAT, "Factor debe reducirse al valor de presencia (0.5)")
	assert_true(canoa.esta_en_presencia_de_enemigo(), "Debe marcar presencia activa")
	assert_false(canoa.esta_detenida_por_enemigo(), "No debe estar detenida aún")


func test_canoa_se_detiene_por_completo_ante_contacto_con_enemigo() -> void:
	# Arrange: Canoa en el origen y enemigo a 2m adelante (distancia < distancia_contacto_enemigos = 2.4m)
	var canoa_scene := load(SCENE_CANOA_PATH) as PackedScene
	var canoa: CanoaProtagonistaRio = canoa_scene.instantiate() as CanoaProtagonistaRio
	add_child_autofree(canoa)
	canoa.global_position = Vector3(0.0, 0.0, 0.0)
	canoa.iniciar_travesia(1.0)

	var enemigo := DummyEnemigo.new()
	enemigo.name = "EnemigoContacto"
	enemigo.health = 2
	add_child_autofree(enemigo)
	enemigo.add_to_group("enemies")
	enemigo.global_position = Vector3(2.0, 0.0, 0.0)

	# Act
	canoa._process(0.1)

	# Assert
	assert_almost_eq(canoa.obtener_factor_velocidad_actual(), 0.0, MARGEN_FLOAT, "Factor debe ser 0.0 en contacto")
	assert_true(canoa.esta_detenida_por_enemigo(), "Debe marcarse como detenida por enemigo")
	assert_eq(canoa.obtener_enemigo_bloqueando(), enemigo, "El enemigo bloqueador debe ser el detectado")


func test_canoa_no_traspasa_enemigo_al_avanzar() -> void:
	# Arrange: Canoa rápida avanzando hacia un enemigo ubicado en X = 5.0
	var canoa_scene := load(SCENE_CANOA_PATH) as PackedScene
	var canoa: CanoaProtagonistaRio = canoa_scene.instantiate() as CanoaProtagonistaRio
	add_child_autofree(canoa)
	canoa.global_position = Vector3(0.0, 0.0, 0.0)
	canoa.iniciar_travesia(3.0)

	var enemigo := DummyEnemigo.new()
	enemigo.name = "EnemigoBarrera"
	enemigo.health = 2
	add_child_autofree(enemigo)
	enemigo.add_to_group("enemies")
	enemigo.global_position = Vector3(5.0, 0.0, 0.0)
	# Act: Simular avance de varios frames
	for _i in range(30):
		canoa._process(0.1)

	# Assert: La posición de la canoa no debe superar jamás X = 5.0 - distancia_contacto_enemigos
	var max_x_permitida: float = 5.0 - canoa.distancia_contacto_enemigos
	assert_true(canoa.obtener_posicion_base().x <= max_x_permitida + MARGEN_FLOAT, "La canoa jamás debe sobrepasar la barrera de contacto del enemigo")
	assert_true(canoa.esta_detenida_por_enemigo(), "La canoa debe quedar en estado detenida")


func test_canoa_reanuda_marcha_al_morir_enemigo() -> void:
	# Arrange: Canoa detenida por un enemigo a 2m
	var canoa_scene := load(SCENE_CANOA_PATH) as PackedScene
	var canoa: CanoaProtagonistaRio = canoa_scene.instantiate() as CanoaProtagonistaRio
	add_child_autofree(canoa)
	canoa.global_position = Vector3(0.0, 0.0, 0.0)
	canoa.iniciar_travesia(1.0)

	var enemigo := DummyEnemigo.new()
	enemigo.name = "EnemigoMortal"
	enemigo.health = 2
	add_child_autofree(enemigo)
	enemigo.add_to_group("enemies")
	enemigo.global_position = Vector3(2.0, 0.0, 0.0)

	canoa._process(0.1)
	assert_true(canoa.esta_detenida_por_enemigo(), "Debe estar detenida inicialmente")

	# Act: El enemigo muere (vida en 0)
	enemigo.health = 0
	canoa._process(0.1)

	# Assert: La canoa reanuda su marcha automáticamente
	assert_false(canoa.esta_detenida_por_enemigo(), "No debe estar detenida tras la muerte del enemigo")
	assert_almost_eq(canoa.obtener_factor_velocidad_actual(), 1.0, MARGEN_FLOAT, "Factor debe restaurarse a 1.0")


func test_enemigo_fuera_de_profundidad_z_no_afecta_canoa() -> void:
	# Arrange: Enemigo adelante en X pero muy alejado en Z (fuera del cauce)
	var canoa_scene := load(SCENE_CANOA_PATH) as PackedScene
	var canoa: CanoaProtagonistaRio = canoa_scene.instantiate() as CanoaProtagonistaRio
	add_child_autofree(canoa)
	canoa.global_position = Vector3(0.0, 0.0, 0.0)
	canoa.iniciar_travesia(1.0)

	var enemigo := DummyEnemigo.new()
	enemigo.name = "EnemigoFondo"
	enemigo.health = 2
	add_child_autofree(enemigo)
	enemigo.add_to_group("enemies")
	enemigo.global_position = Vector3(2.0, 0.0, -15.0)  # Z muy lejos

	# Act
	canoa._process(0.1)

	# Assert
	assert_almost_eq(canoa.obtener_factor_velocidad_actual(), 1.0, MARGEN_FLOAT, "Enemigo fuera de Z no debe frenar la canoa")
	assert_false(canoa.esta_detenida_por_enemigo(), "No debe detenerse")
