extends "res://addons/gut/test.gd"

var AllyBallesteraScript = load("res://Entities/Aliada_Ballestera/AllyBallestera.gd")
var EscudoScript = load("res://Entities/Ambiente_Escudo/Escudo.gd")
var _ballestera: AllyBallestera = null

class MockAudioManager extends Node:
	func play_sfx(_name, _boost = 0.0): pass
	func stop_bow_tension(): pass
	func reset_bow_hold(): pass

var _mock_audio_created: bool = false


func before_each():
	_ballestera = AllyBallesteraScript.new()
	_agregar_animacion_minima(_ballestera)

	if not get_tree().root.has_node("AudioManager"):
		var mock_audio = MockAudioManager.new()
		mock_audio.name = "AudioManager"
		get_tree().root.add_child(mock_audio)
		_mock_audio_created = true

	get_tree().root.add_child(_ballestera)


func after_each():
	if is_instance_valid(_ballestera):
		if _ballestera.get_parent():
			_ballestera.get_parent().remove_child(_ballestera)
		_ballestera.free()

	if _mock_audio_created and get_tree().root.has_node("AudioManager"):
		var mock_audio = get_tree().root.get_node("AudioManager")
		get_tree().root.remove_child(mock_audio)
		mock_audio.free()
		_mock_audio_created = false


func _agregar_animacion_minima(ballestera: AllyBallestera) -> void:
	var anim_player := AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"

	var lib = AnimationLibrary.new()
	lib.add_animation("IDLE", Animation.new())
	lib.add_animation("DISPARO_01", Animation.new())
	lib.add_animation("DISPARO_AGACHADO", Animation.new())
	lib.add_animation("CAMINAR_01", Animation.new())
	lib.add_animation("CAMINAR_ESP", Animation.new())
	lib.add_animation("MUERTE_01", Animation.new())
	lib.add_animation("MUERTE02", Animation.new())

	anim_player.add_animation_library("", lib)
	ballestera.add_child(anim_player)

	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	ballestera.add_child(skeleton)
	ballestera.skeleton = skeleton


func test_inicializacion_vida_4():
	# Arrange & Assert
	assert_eq(_ballestera.vida_maxima, 4, "La vida máxima de la ballestera debe ser 4")
	assert_eq(_ballestera.health, 4, "La salud inicial debe ser 4")


func test_recibir_dano():
	# Act
	_ballestera.recibir_dano(1)
	# Assert
	assert_eq(_ballestera.health, 3, "La salud debería reducirse a 3")
	assert_ne(_ballestera.current_state, _ballestera.State.DYING, "No debe morir con 3 de vida")


func test_recibir_dano_mortal():
	# Act
	_ballestera.recibir_dano(4)
	# Assert
	assert_eq(_ballestera.health, 0, "La salud debería llegar a 0")
	assert_eq(_ballestera.current_state, _ballestera.State.DYING, "Debería entrar en estado DYING")


func test_ciclo_5_disparos_de_pie_y_5_agachada():
	# Fase inicial de pie
	assert_false(_ballestera.fase_agachada, "Debe iniciar en fase de pie")

	# Simular 5 disparos de pie
	for i in range(5):
		_ballestera._disparar()

	# Tras 5 disparos de pie, debe pasar a fase agachada
	assert_true(_ballestera.fase_agachada, "Tras 5 disparos de pie debe cambiar a fase agachada")

	# Simular 5 disparos agachada
	for i in range(5):
		_ballestera._disparar()

	# Tras 5 disparos agachada, debe volver a fase de pie
	assert_false(_ballestera.fase_agachada, "Tras 5 disparos agachada debe volver a fase de pie")


func test_escudo_metalico_reflejo():
	# Arrange
	var escudo = EscudoScript.new()
	add_child_autofree(escudo)

	# Act
	escudo.activar_modo_metalico(2)

	# Assert
	assert_true(escudo.es_reflejante(), "El escudo debe ser reflejante en modo metálico")
	assert_eq(escudo.aguante_metalico, 2, "Debe tener 2 de aguante metálico")

	# Act: recibir impacto reflejo
	escudo.recibir_golpe_reflejo(null)
	assert_eq(escudo.aguante_metalico, 1, "Debe descontar 1 de aguante metálico")
	assert_true(escudo.es_reflejante(), "Sigue reflejante con 1 de aguante")

	# Act: segundo impacto reflejo
	escudo.recibir_golpe_reflejo(null)
	assert_false(escudo.es_reflejante(), "Debe salir de modo reflejante al llegar a 0")


func test_no_beneficio_power_ups_municion():
	# Act
	_ballestera.agregar_flechas_explosivas(3)
	_ballestera.agregar_flechas_multiples(2)
	# Assert
	assert_false("flechas_explosivas" in _ballestera and _ballestera.flechas_explosivas > 0, "No debe acumular flechas explosivas")


func test_registro_grupo_allies():
	# Assert
	assert_true(_ballestera.is_in_group("allies"), "La ballestera debe estar en el grupo 'allies'")
	assert_true(AllyArcher.active_allies_cache.has(_ballestera), "La ballestera debe estar en active_allies_cache")


func test_prioridad_enemigos():
	# Arrange
	var enemigo_comun = Node3D.new()
	enemigo_comun.name = "EnemigoGeneral"
	enemigo_comun.add_to_group("enemies")
	get_tree().root.add_child(enemigo_comun)
	enemigo_comun.global_position = Vector3(5, 0, 0)

	var imp_prioritario = Node3D.new()
	imp_prioritario.name = "ImpEnemigo"
	imp_prioritario.add_to_group("enemies")
	get_tree().root.add_child(imp_prioritario)
	imp_prioritario.global_position = Vector3(8, 0, 0)

	# Act
	var objetivo = _ballestera._obtener_objetivo_prioritario()

	# Assert
	assert_not_null(objetivo, "Debe encontrar un objetivo")
	assert_eq(objetivo, imp_prioritario, "Debe priorizar al Imp sobre el enemigo general aunque esté más lejos")

	enemigo_comun.queue_free()
	imp_prioritario.queue_free()


func test_apuntado_torso_rotacion_hueso():
	# Arrange: enemigo a la derecha en el suelo
	var enemigo = Node3D.new()
	enemigo.name = "ImpTest"
	enemigo.add_to_group("enemies")
	get_tree().root.add_child(enemigo)
	enemigo.global_position = Vector3(6.0, 0.0, 0.0)
	_ballestera.global_position = Vector3(0.0, 0.0, 0.0)

	# Act: ejecutar apuntado
	_ballestera.objetivo_actual = enemigo
	_ballestera._actualizar_apuntado_torso(0.5)

	# Assert: con invertir_pitch = true, _current_pitch debe ser negativo para compensar hacia abajo la pose base
	assert_lt(_ballestera._current_pitch, 0.0, "El pitch debe inclinarse negativamente (invertido) para apuntar hacia abajo al objetivo")

	enemigo.queue_free()


func test_celebracion_victoria_loops_y_rotacion():
	# Act: activar victoria
	_ballestera.celebrar_victoria()

	# Assert: estado y conteo de loops
	assert_eq(_ballestera.current_state, _ballestera.State.CELEBRATING, "Debe entrar en estado CELEBRATING")
	assert_gte(_ballestera._loops_victoria_restantes, 3, "Debe inicializar con al menos 3 repeticiones")

	# Simular iteraciones de loops de celebración
	while _ballestera._loops_victoria_restantes > 1:
		_ballestera.state_timer = 0.0
		_ballestera._process_celebrating(0.01)
		assert_eq(_ballestera.current_state, _ballestera.State.CELEBRATING, "Debe mantenerse celebrando mientras queden loops")

	# Último loop: debe regresar directamente a AIMING (sin pasar por IDLE)
	_ballestera.state_timer = 0.0
	_ballestera._process_celebrating(0.01)
	assert_eq(_ballestera.current_state, _ballestera.State.AIMING, "Tras completar los loops debe pasar directamente a AIMING")
