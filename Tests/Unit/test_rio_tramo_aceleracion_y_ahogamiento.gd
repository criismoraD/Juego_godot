extends "res://addons/gut/test.gd"

## Tests unitarios para el tramo acelerado fluvial, la prevención de caídas de plataformas
## y el sistema de ahogamiento con mini-splash de enemigos caídos al río ('Rio en canoa con paralax').

const SCRIPT_RIO: Script = preload("res://Levels/Rio_En_Canoa_Con_Parallax/Rio_En_Canoa_Con_Parallax.gd")
const SCRIPT_ENEMY_BASE: Script = preload("res://System/Core/EnemyBase.gd")
const ESCENA_CANOA: PackedScene = preload("res://Levels/Rio_En_Canoa_Con_Parallax/CanoaProtagonistaRio.tscn")

var _nivel: RioEnCanoaConParallax = null


func before_each() -> void:
	_nivel = SCRIPT_RIO.new()
	get_tree().root.add_child(_nivel)


func after_each() -> void:
	if is_instance_valid(_nivel):
		if _nivel.get_parent():
			_nivel.get_parent().remove_child(_nivel)
		_nivel.free()
	_nivel = null


func test_canoa_acelera_automaticamente_en_tramo_sin_enemigos() -> void:
	# Arrange
	var canoa: CanoaProtagonistaRio = ESCENA_CANOA.instantiate() as CanoaProtagonistaRio
	_nivel.add_child(canoa)
	canoa.configurar_tramo_aceleracion(60.0, 126.0, 1.8)
	canoa.velocidad_avance = 0.65
	canoa.global_position.x = 80.0

	# Act
	canoa._actualizar_reaccion_enemigos()

	# Assert
	assert_true(canoa.esta_en_tramo_aceleracion(), "La canoa debe estar dentro del tramo de aceleración")
	assert_almost_eq(canoa.get("_velocidad_navegacion"), 1.8, 0.05, "La canoa debe navegar a velocidad acelerada (1.8 m/s)")

	# Cleanup
	canoa.queue_free()


func test_canoa_velocidad_normal_fuera_de_tramo_sin_enemigos() -> void:
	# Arrange
	var canoa: CanoaProtagonistaRio = ESCENA_CANOA.instantiate() as CanoaProtagonistaRio
	_nivel.add_child(canoa)
	canoa.configurar_tramo_aceleracion(60.0, 126.0, 1.8)
	canoa.velocidad_avance = 0.65
	canoa.global_position.x = 30.0

	# Act
	canoa._actualizar_reaccion_enemigos()

	# Assert
	assert_false(canoa.esta_en_tramo_aceleracion(), "La canoa debe estar fuera del tramo de aceleración")
	assert_almost_eq(canoa.get("_velocidad_navegacion"), 0.65, 0.05, "Fuera del tramo debe mantener la velocidad normal (0.65 m/s)")

	# Cleanup
	canoa.queue_free()


func test_canoa_frena_en_tramo_si_detecta_enemigo() -> void:
	# Arrange
	var canoa: CanoaProtagonistaRio = ESCENA_CANOA.instantiate() as CanoaProtagonistaRio
	_nivel.add_child(canoa)
	canoa.configurar_tramo_aceleracion(60.0, 126.0, 1.8)
	canoa.global_position = Vector3(80.0, 0.0, 0.0)

	var enemigo := CharacterBody3D.new()
	enemigo.name = "EnemigoBloqueadorTest"
	enemigo.add_to_group("enemies")
	enemigo.set("health", 10)
	_nivel.add_child(enemigo)
	enemigo.global_position = Vector3(81.0, 0.0, 0.0)  # Dentro del umbral de contacto

	# Act
	canoa._actualizar_reaccion_enemigos()

	# Assert
	assert_true(canoa.esta_detenida_por_enemigo(), "La canoa debe frenar por contacto con el enemigo")
	assert_almost_eq(canoa.get("_velocidad_navegacion"), 0.0, 0.01, "La velocidad debe ser 0.0 al estar bloqueada por un enemigo")

	# Cleanup
	enemigo.queue_free()
	canoa.queue_free()


func test_enemigo_vivo_frena_en_borde_de_plataforma_sin_caer() -> void:
	# Arrange
	var enemigo: EnemyBase = SCRIPT_ENEMY_BASE.new() as EnemyBase
	enemigo.name = "EnemyBaseLedgeTest"
	_nivel.add_child(enemigo)
	enemigo._test_floor_normal_override = Vector3.UP
	enemigo._test_hay_suelo_adelante_override = false  # Simular que adelante hay un precipicio / agua
	enemigo.evitar_caer_plataformas = true
	enemigo.current_state = EnemyBase.State.WALKING
	enemigo.velocity.x = -1.5

	# Act: Ejecutar física con borde detectado
	enemigo._process_walking(0.016)

	# Assert: Debe frenar a 0 y cambiar a SHOOTING en vez de caminar hacia el vacío
	assert_almost_eq(enemigo.velocity.x, 0.0, 0.01, "El enemigo vivo debe detenerse al llegar al borde de la plataforma")
	assert_eq(enemigo.current_state, EnemyBase.State.SHOOTING, "Debe pasar al estado de disparo al llegar al borde")

	# Cleanup
	enemigo.queue_free()


func test_enemigo_en_piso_no_se_ahoga_por_cota_y() -> void:
	# Arrange: Simular el inicio del nivel con un enemigo sobre plataforma a Y = -0.35 (como BaldosaMusgo)
	_nivel._tiempo_nivel_rio = 1.0  # Fin de tiempo de gracia
	var enemigo := CharacterBody3D.new()
	enemigo.name = "EnemigoSobreBaldosa"
	enemigo.add_to_group("enemies")
	_nivel.add_child(enemigo)
	enemigo.global_position = Vector3(85.0, -0.35, 0.0)

	# Act
	_nivel._procesar_enemigos_caidos_al_agua(0.016)

	# Assert: Al no caer de la plataforma (o al tener soporte), no debe considerarse ahogado erróneamente
	# En el caso de CharacterBody3D sin simulación física en test, si Y no superó -0.45 no se ahoga
	assert_false(enemigo.has_meta("ahogado_en_agua"), "Un enemigo a cota de plataforma (-0.35) no debe ahogarse")

	# Cleanup
	enemigo.queue_free()


func test_enemigo_caido_al_agua_se_ahoga_y_genera_mini_splash() -> void:
	# Arrange
	_nivel._tiempo_nivel_rio = 1.0  # Fin de tiempo de gracia
	var enemigo := CharacterBody3D.new()
	enemigo.name = "GoblinCaidoAlAgua"
	enemigo.add_to_group("enemies")
	_nivel.add_child(enemigo)
	enemigo.global_position = Vector3(85.0, -0.55, 0.0)  # Caído bajo el umbral de caída al agua (-0.45)

	# Act
	_nivel._procesar_enemigos_caidos_al_agua(0.016)

	# Assert
	assert_true(enemigo.has_meta("ahogado_en_agua"), "El enemigo debe estar marcado como ahogado")
	assert_false(enemigo.is_in_group("enemies"), "Debe eliminarse inmediatamente del grupo enemies")

	# Verificar que se generó un mini-splash en escena
	var mini_splash: Node3D = null
	for hijo in _nivel.get_children():
		if hijo is Node3D and hijo != enemigo:
			if hijo.has_method("play_splash") or "splash" in hijo.name.to_lower():
				mini_splash = hijo as Node3D
				break
	if not is_instance_valid(mini_splash):
		for hijo in get_tree().root.get_children():
			if hijo is Node3D and hijo != _nivel:
				if hijo.has_method("play_splash") or "splash" in hijo.name.to_lower():
					mini_splash = hijo as Node3D
					break

	assert_not_null(mini_splash, "Debe instanciarse el mini-splash en la escena")
	if is_instance_valid(mini_splash):
		assert_almost_eq(mini_splash.scale.x, _nivel.escala_mini_splash_agua, 0.02, "La escala debe coincidir con la escala_mini_splash_agua (0.18)")
		mini_splash.queue_free()

	# Cleanup
	if is_instance_valid(enemigo):
		enemigo.queue_free()


func test_enemigo_en_agua_no_bloquea_canoa() -> void:
	# Arrange
	var canoa: CanoaProtagonistaRio = ESCENA_CANOA.instantiate() as CanoaProtagonistaRio
	_nivel.add_child(canoa)
	canoa.configurar_tramo_aceleracion(60.0, 126.0, 1.8)
	canoa.global_position = Vector3(80.0, 0.0, 0.0)

	var enemigo := CharacterBody3D.new()
	enemigo.name = "EnemigoSumergido"
	enemigo.add_to_group("enemies")
	_nivel.add_child(enemigo)
	enemigo.global_position = Vector3(81.0, -0.55, 0.0)  # En agua, delante de la canoa

	# Act
	canoa._actualizar_reaccion_enemigos()

	# Assert
	assert_false(canoa.esta_detenida_por_enemigo(), "El enemigo en el agua no debe bloquear la canoa")
	assert_gt(canoa.get("_velocidad_navegacion"), 0.5, "La canoa debe poder avanzar sin atascarse")

	# Cleanup
	enemigo.queue_free()
	canoa.queue_free()
