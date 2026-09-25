extends "res://addons/gut/test.gd"

## Tests unitarios para la reacciÃ³n de la canoa ante la presencia y contacto con enemigos.
## Valida que la canoa reduzca su velocidad al 50% al acercarse a enemigos en el cauce,
## se detenga por completo al hacer contacto fÃ­sico/geomÃ©trico evitando traspasarlos,
## y reanude la navegaciÃ³n automÃ¡ticamente cuando el enemigo sea eliminado.

const SCENE_CANOA_PATH: String = "res://Levels/Rio_En_Canoa_Con_Parallax/CanoaProtagonistaRio.tscn"
const MARGEN_FLOAT: float = 0.02


class DummyEnemigo extends CharacterBody3D:
	var health: int = 2
	var current_state: int = 0
	var is_dead: bool = false
	var is_dying: bool = false
	var is_dissolving: bool = false
	var _dormida_por_camara: bool = false
	var _dormido_por_camara: bool = false
	var _en_pantalla: bool = true

	func esta_en_pantalla_o_rango_camara() -> bool:
		return _en_pantalla



func after_each() -> void:
	# Asegurar aislamiento estricto retirando los nodos del Ã¡rbol inmediatamente entre tests
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
	assert_false(canoa.esta_detenida_por_enemigo(), "No debe estar detenida aÃºn")


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
	# Arrange: Canoa rapida avanzando hacia un enemigo ubicado en X = 5.0
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

	# Assert: La posiciÃ³n de la canoa no debe superar jamÃ¡s X = 5.0 - distancia_contacto_enemigos
	var max_x_permitida: float = 5.0 - canoa.distancia_contacto_enemigos
	assert_true(canoa.obtener_posicion_base().x <= max_x_permitida + MARGEN_FLOAT, "La canoa jamÃ¡s debe sobrepasar la barrera de contacto del enemigo")
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

	# Assert: La canoa reanuda su marcha automÃ¡ticamente
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


func test_freno_corrige_sobrepaso_sin_salto() -> void:
	# Arrange: canoa quieta 1.9 m más allá de la línea (enemigo en X=5, línea en 2.6)
	var canoa_scene := load(SCENE_CANOA_PATH) as PackedScene
	var canoa: CanoaProtagonistaRio = canoa_scene.instantiate() as CanoaProtagonistaRio
	add_child_autofree(canoa)
	canoa.fijar_posicion_base(Vector3(4.5, 0.0, 0.0))
	canoa._velocidad_navegacion = 0.0
	canoa._velocidad_efectiva = 0.0

	var enemigo := DummyEnemigo.new()
	enemigo.name = "EnemigoSobrepaso"
	enemigo.health = 2
	add_child_autofree(enemigo)
	enemigo.add_to_group("enemies")
	enemigo.global_position = Vector3(5.0, 0.0, 0.0)

	# Act: un frame de freno
	canoa._process(0.1)

	# Assert: retrocede de forma continua, sin teleport a la línea (2.6)
	var x_tras_un_frame: float = canoa.obtener_posicion_base().x
	assert_lt(x_tras_un_frame, 4.5, "Debe retroceder hacia la línea")
	assert_gt(x_tras_un_frame, 2.6, "Sin salto: no debe plantarse en la línea de golpe")

	# Act: dejar converger
	for _i in range(30):
		canoa._process(0.1)

	# Assert: converge a la línea sin traspasarla
	assert_lte(canoa.obtener_posicion_base().x, 2.6 + MARGEN_FLOAT, "Debe converger a la línea de contacto")
	assert_true(canoa.esta_detenida_por_enemigo(), "Sigue detenida por contacto")


func test_enemigo_dormido_por_camara_no_bloquea_canoa() -> void:
	# Arrange: Enemigo dentro del rango de contacto (2m adelante) pero dormido por cámara
	var canoa_scene := load(SCENE_CANOA_PATH) as PackedScene
	var canoa: CanoaProtagonistaRio = canoa_scene.instantiate() as CanoaProtagonistaRio
	add_child_autofree(canoa)
	canoa.global_position = Vector3(0.0, 0.0, 0.0)
	canoa.iniciar_travesia(1.0)

	var enemigo := DummyEnemigo.new()
	enemigo.name = "EnemigoDormido"
	enemigo.health = 2
	enemigo._dormida_por_camara = true
	add_child_autofree(enemigo)
	enemigo.add_to_group("enemies")
	enemigo.global_position = Vector3(2.0, 0.0, 0.0)

	# Act
	canoa._process(0.1)

	# Assert: El enemigo dormido no debe detener ni ralentizar la canoa
	assert_false(canoa.esta_detenida_por_enemigo(), "Enemigo dormido no debe detener la canoa")
	assert_false(canoa.esta_en_presencia_de_enemigo(), "Enemigo dormido no debe alterar presencia")
	assert_almost_eq(canoa.obtener_factor_velocidad_actual(), 1.0, MARGEN_FLOAT, "Factor debe ser 1.0")


func test_enemigo_fuera_de_pantalla_no_bloquea_canoa() -> void:
	# Arrange: Enemigo dentro del rango de contacto (2m adelante) pero fuera de encuadre de cámara
	var canoa_scene := load(SCENE_CANOA_PATH) as PackedScene
	var canoa: CanoaProtagonistaRio = canoa_scene.instantiate() as CanoaProtagonistaRio
	add_child_autofree(canoa)
	canoa.global_position = Vector3(0.0, 0.0, 0.0)
	canoa.iniciar_travesia(1.0)

	var enemigo := DummyEnemigo.new()
	enemigo.name = "EnemigoOffscreen"
	enemigo.health = 2
	enemigo._en_pantalla = false
	add_child_autofree(enemigo)
	enemigo.add_to_group("enemies")
	enemigo.global_position = Vector3(2.0, 0.0, 0.0)

	# Act
	canoa._process(0.1)

	# Assert: El enemigo fuera de pantalla no debe detener la canoa
	assert_false(canoa.esta_detenida_por_enemigo(), "Enemigo fuera de pantalla no debe detener la canoa")
	assert_false(canoa.esta_en_presencia_de_enemigo(), "Enemigo fuera de pantalla no debe alterar presencia")
	assert_almost_eq(canoa.obtener_factor_velocidad_actual(), 1.0, MARGEN_FLOAT, "Factor debe ser 1.0")


func test_tramo_acelerado_activa_viento_sin_enemigos() -> void:
	# Arrange: canoa dentro del tramo (x=100) sin enemigos
	var canoa_scene := load(SCENE_CANOA_PATH) as PackedScene
	var canoa: CanoaProtagonistaRio = canoa_scene.instantiate() as CanoaProtagonistaRio
	add_child_autofree(canoa)
	canoa.global_position = Vector3(100.0, 0.0, 0.0)
	canoa.iniciar_travesia(1.0)

	# Act
	canoa._process(0.1)

	# Assert: acelera a 1.8 con viento activo
	assert_almost_eq(float(canoa.get("_velocidad_navegacion")), 1.8, MARGEN_FLOAT, "En tramo sin enemigos debe acelerar a 1.8")
	assert_true(canoa.esta_efecto_viento_activo(), "El viento debe activarse al acelerar sin enemigos")


func test_viento_se_apaga_con_enemigos_cerca() -> void:
	# Arrange: canoa en tramo + enemigo en presencia (4m)
	var canoa_scene := load(SCENE_CANOA_PATH) as PackedScene
	var canoa: CanoaProtagonistaRio = canoa_scene.instantiate() as CanoaProtagonistaRio
	add_child_autofree(canoa)
	canoa.global_position = Vector3(100.0, 0.0, 0.0)
	canoa.iniciar_travesia(1.0)
	canoa._process(0.1)
	assert_true(canoa.esta_efecto_viento_activo(), "Precondición: viento activo sin enemigos")

	var enemigo := DummyEnemigo.new()
	enemigo.name = "EnemigoViento"
	enemigo.health = 2
	add_child_autofree(enemigo)
	enemigo.add_to_group("enemies")
	enemigo.global_position = Vector3(104.0, 0.0, 0.0)

	# Act
	canoa._process(0.1)

	# Assert: sin aceleración y sin viento
	assert_false(canoa.esta_efecto_viento_activo(), "Con enemigos cerca el viento debe apagarse")


func test_viento_manual_debug_no_lo_pisa_el_automatismo() -> void:
	# Arrange: canoa fuera del tramo, viento manual activado (debug Z)
	var canoa_scene := load(SCENE_CANOA_PATH) as PackedScene
	var canoa: CanoaProtagonistaRio = canoa_scene.instantiate() as CanoaProtagonistaRio
	add_child_autofree(canoa)
	canoa.global_position = Vector3(0.0, 0.0, 0.0)
	canoa.iniciar_travesia(1.0)
	canoa._process(0.1)
	assert_false(canoa.esta_efecto_viento_activo(), "Fuera del tramo no hay viento automático")

	# Act: control manual y proceso
	canoa.set_efecto_viento_activo(true)
	canoa._process(0.1)

	# Assert: el manual se mantiene
	assert_true(canoa.esta_efecto_viento_activo(), "El viento manual no debe apagarlo el automatismo")

	# Act: soltar el manual
	canoa.set_efecto_viento_activo(false)
	canoa._process(0.1)

	# Assert
	assert_false(canoa.esta_efecto_viento_activo(), "Al soltar el manual el viento debe apagarse")

