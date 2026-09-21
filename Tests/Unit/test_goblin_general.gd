extends "res://addons/gut/test.gd"

const GoblinGeneralScript = preload("res://Entities/Enemigo_Goblin_General/GoblinGeneral.gd")
const GOBLIN_GENERAL_SCENE: PackedScene = preload("res://Entities/Enemigo_Goblin_General/GoblinGeneral.tscn")
const GOBLIN_GIRL_SCENE: PackedScene = preload("res://Entities/Enemigo_Goblin_Girl/GoblinGirl.tscn")
const ARROW_SCENE: PackedScene = preload("res://Entities/Proyectil_Flecha/Arrow.tscn")
const GoblinGirlArrowProjectile = preload("res://Entities/Proyectil_Flecha_Goblin_Girl/GoblinGirlArrow.gd")


func test_tracking_mira_hacia_arriba_siguiendo_jugador() -> void:
	# Arrange
	var general = GOBLIN_GENERAL_SCENE.instantiate() as GoblinGeneralScript
	add_child_autofree(general)
	general.global_position = Vector3(0, 0, 0)
	await get_tree().process_frame

	var mock_player = Node3D.new()
	add_child_autofree(mock_player)
	mock_player.add_to_group("player")
	mock_player.global_position = Vector3(-8.0, 5.0, 0.0)
	general.player_ref = mock_player
	general.current_state = GoblinGeneralScript.State.SHOOTING

	# Act: Simular actualización de apuntado de torso
	for i: int in range(10):
		general._actualizar_apuntado_torso(0.1)

	# Assert
	assert_gt(general._aim_weight, 0.5, "El peso de apuntado debe incrementarse suavemente")
	assert_lt(general._current_pitch, 0.0, "El pitch debe ser negativo para inclinar el torso hacia arriba hacia el jugador")

	var override_pose1: Transform3D = general.skeleton.get_bone_global_pose_override(general.spine1_bone_idx)
	var override_pose2: Transform3D = general.skeleton.get_bone_global_pose_override(general.spine2_bone_idx)
	assert_ne(override_pose1, Transform3D.IDENTITY, "Override de Spine1 debe estar activo con curvatura")
	assert_ne(override_pose2, Transform3D.IDENTITY, "Override de Spine2 debe estar activo con curvatura")


func test_flechas_mismo_color_y_tamano_que_goblin_girl() -> void:
	# Arrange
	var general = GOBLIN_GENERAL_SCENE.instantiate() as GoblinGeneralScript
	var girl = GOBLIN_GIRL_SCENE.instantiate() as GoblinGirl
	add_child_autofree(general)
	add_child_autofree(girl)
	await get_tree().process_frame

	# Act & Assert: Escala configurada coincide con la escala global de Goblin Girl
	assert_almost_eq(general.escala_flecha_disparo.x, girl.escala_original_global_flecha_mano.x, 0.01,
		"La escala X de la flecha de Goblin General debe coincidir con la de Goblin Girl")
	assert_almost_eq(general.escala_flecha_disparo.y, girl.escala_original_global_flecha_mano.y, 0.01,
		"La escala Y de la flecha de Goblin General debe coincidir con la de Goblin Girl")
	assert_almost_eq(general.escala_flecha_disparo.z, girl.escala_original_global_flecha_mano.z, 0.01,
		"La escala Z de la flecha de Goblin General debe coincidir con la de Goblin Girl")

	# Lanzar una flecha y verificar color y escala aplicados
	general._instanciar_y_lanzar_flecha(Vector3.ZERO, Vector3.LEFT, 1.0)
	var spawned_arrow = get_tree().root.find_child("GoblinGirlArrow", true, false)
	if spawned_arrow:
		assert_eq(spawned_arrow.color_proyectil, GoblinGirlArrowProjectile.GOBLIN_GIRL_ARROW_MAGENTA,
			"El color de la flecha del General debe ser el magenta/rosado de Goblin Girl")
		assert_almost_eq(spawned_arrow.scale.x, general.escala_flecha_disparo.x, 0.001,
			"La escala del proyectil instanciado debe coincidir con escala_flecha_disparo")


func test_distancia_caminar_igual_a_goblin_ballestero() -> void:
	# Arrange
	var general = GOBLIN_GENERAL_SCENE.instantiate() as GoblinGeneralScript
	var goblin_ballestero_scene: PackedScene = preload("res://Entities/Enemigo_Goblin/Goblin.tscn")
	var goblin = goblin_ballestero_scene.instantiate() as Goblin
	add_child_autofree(general)
	add_child_autofree(goblin)
	await get_tree().process_frame

	# Act & Assert
	assert_eq(general.distancia_minima_caminar, goblin.distancia_minima_caminar,
		"Distancia mínima de caminata debe coincidir con el Goblin Ballestero (3.0)")
	assert_eq(general.distancia_maxima_caminar, goblin.distancia_maxima_caminar,
		"Distancia máxima de caminata debe coincidir con el Goblin Ballestero (9.0)")


func test_velocidad_correr_mayor_que_goblin_girl() -> void:
	# Arrange
	var general = GOBLIN_GENERAL_SCENE.instantiate() as GoblinGeneralScript
	var girl = GOBLIN_GIRL_SCENE.instantiate() as GoblinGirl
	add_child_autofree(general)
	add_child_autofree(girl)

	# Act & Assert
	assert_gt(general.velocidad_correr, girl.velocidad_caminar,
		"Goblin General debe entrar corriendo a mayor velocidad que Goblin Girl")
	assert_gt(general.velocidad_correr, 1.5,
		"La velocidad de carrera del General debe ser ágil (> 1.5)")


func test_iniciar_y_terminar_rodar() -> void:
	# Arrange
	var general = GOBLIN_GENERAL_SCENE.instantiate() as GoblinGeneralScript
	add_child_autofree(general)
	await get_tree().process_frame

	# Act - Iniciar rodar
	general._iniciar_rodar()

	# Assert
	assert_true(general.esta_rodando, "El flag esta_rodando debe ser true")
	if general.anim_player:
		assert_eq(general.anim_player.current_animation, "Rodar", "Debe reproducir animación 'Rodar'")

	# Act - Terminar rodar
	general._terminar_rodar()

	# Assert
	assert_false(general.esta_rodando, "El flag esta_rodando debe ser false al terminar")
	if general.anim_player:
		assert_eq(general.anim_player.current_animation, "Correr", "Debe volver a la animación 'Correr'")


func test_flecha_normal_es_repelida_durante_rodar() -> void:
	# Arrange
	var general = GOBLIN_GENERAL_SCENE.instantiate() as GoblinGeneralScript
	add_child_autofree(general)
	await get_tree().process_frame

	var arrow = ARROW_SCENE.instantiate() as ArrowProjectile
	add_child_autofree(arrow)
	arrow.tipo_dueño = ArrowProjectile.TipoFlecha.JUGADOR

	var hp_inicial: int = general.health

	# Act: Goblin General rueda y recibe flecha normal
	general.esta_rodando = true
	var fue_repelida: bool = general.manejar_impacto_aura(arrow)

	# Simular intento de daño directo por flecha normal mientras rueda
	general.take_damage(1.0)

	# Assert
	assert_false(fue_repelida, "Las flechas normales no rebotan sino que atraviesan sin daño mientras rueda")
	assert_eq(general.health, hp_inicial, "Goblin General NO debe recibir daño de flechas normales mientras rueda")
	assert_ne(general.current_state, GoblinGeneralScript.State.DYING, "No debe morir por flecha normal rodando")


func test_flecha_cargada_impacta_y_mata_durante_rodar() -> void:
	# Arrange
	var general = GOBLIN_GENERAL_SCENE.instantiate() as GoblinGeneralScript
	add_child_autofree(general)
	await get_tree().process_frame

	var arrow = ARROW_SCENE.instantiate() as ArrowProjectile
	add_child_autofree(arrow)
	arrow.tipo_dueño = ArrowProjectile.TipoFlecha.JUGADOR
	arrow.set_meta("sobrecarga_max", true)

	# Act: Goblin General rueda y recibe flecha cargada
	general.esta_rodando = true
	var fue_repelida: bool = general.manejar_impacto_aura(arrow)

	# La flecha cargada causa 2.0 de daño al penetrar
	general.take_damage(2.0)

	# Assert
	assert_false(fue_repelida, "La flecha con sobrecarga máxima NO debe ser repelida mientras rueda")
	assert_lte(general.health, 0, "La flecha cargada debe reducir la vida a 0 o menos")
	assert_eq(general.current_state, GoblinGeneralScript.State.DYING, "Goblin General debe morir al ser impactado por flecha cargada rodando")


func test_flecha_explosiva_impacta_durante_rodar() -> void:
	# Arrange
	var general = GOBLIN_GENERAL_SCENE.instantiate() as GoblinGeneralScript
	add_child_autofree(general)
	await get_tree().process_frame

	var arrow = ARROW_SCENE.instantiate() as ArrowProjectile
	add_child_autofree(arrow)
	arrow.tipo_dueño = ArrowProjectile.TipoFlecha.JUGADOR
	arrow.es_explosiva = true

	# Act: Goblin General rueda y la flecha explosiva entra en contacto
	general.esta_rodando = true
	var fue_repelida: bool = general.manejar_impacto_aura(arrow)

	# La explosión causa 3.0 de daño y marca murio_por_explosion
	general.murio_por_explosion = true
	general.take_damage(3.0)

	# Assert
	assert_false(fue_repelida, "La flecha explosiva NO debe ser repelida mientras rueda")
	assert_lte(general.health, 0, "La flecha explosiva debe eliminar al Goblin General")
	assert_eq(general.current_state, GoblinGeneralScript.State.DYING, "Debe pasar al estado DYING por la explosión")


func test_vida_maxima_es_uno() -> void:
	# Arrange
	var general = GOBLIN_GENERAL_SCENE.instantiate() as GoblinGeneralScript
	add_child_autofree(general)
	await get_tree().process_frame

	# Assert
	assert_eq(general.vida_maxima, 1, "Goblin General debe tener 1 de vida máxima")
	assert_eq(general.health, 1, "Goblin General debe iniciar con 1 de vida")


func test_flecha_normal_impacta_cuando_no_rueda() -> void:
	# Arrange
	var general = GOBLIN_GENERAL_SCENE.instantiate() as GoblinGeneralScript
	add_child_autofree(general)
	await get_tree().process_frame

	var arrow = ARROW_SCENE.instantiate() as ArrowProjectile
	add_child_autofree(arrow)
	arrow.tipo_dueño = ArrowProjectile.TipoFlecha.JUGADOR

	assert_eq(general.health, 1, "Debe tener 1 de vida")

	# Act: Goblin General de pie (no rodando)
	general.esta_rodando = false
	var fue_repelida: bool = general.manejar_impacto_aura(arrow)
	general.take_damage(1.0)

	# Assert
	assert_false(fue_repelida, "Fuera de la voltereta, las flechas normales no se repelen")
	assert_eq(general.health, 0, "Debe quedar en 0 de vida con un solo impacto")
	assert_eq(general.current_state, GoblinGeneralScript.State.DYING, "Debe morir tras 1 impacto")


func test_ciclo_disparos_normales_y_activacion_ult() -> void:
	# Arrange
	var general = GOBLIN_GENERAL_SCENE.instantiate() as GoblinGeneralScript
	add_child_autofree(general)
	await get_tree().process_frame

	general.contador_disparos = 0

	# Act & Assert - Disparo 1 (Normal)
	general._on_state_shooting()
	assert_false(general.en_animacion_ult, "Disparo 1 debe ser normal, no Ult")
	if general.anim_player:
		assert_eq(general.anim_player.current_animation, "disparo", "Animación debe ser 'disparo'")
	general.anim_timer = general.tiempo_disparo_normal + 0.01
	general._process_shooting(0.01)
	assert_eq(general.contador_disparos, 1, "Contador de disparos debe ser 1 tras el 1er disparo")

	# Act & Assert - Disparo 2 (Normal)
	general._on_state_shooting()
	assert_false(general.en_animacion_ult, "Disparo 2 debe ser normal")
	general.anim_timer = general.tiempo_disparo_normal + 0.01
	general._process_shooting(0.01)
	assert_eq(general.contador_disparos, 2, "Contador de disparos debe ser 2")

	# Act & Assert - Disparo 3 (Normal)
	general._on_state_shooting()
	assert_false(general.en_animacion_ult, "Disparo 3 debe ser normal")
	general.anim_timer = general.tiempo_disparo_normal + 0.01
	general._process_shooting(0.01)
	assert_eq(general.contador_disparos, 3, "Contador de disparos debe ser 3")

	# Act & Assert - Disparo 4 (Normal)
	general._on_state_shooting()
	assert_false(general.en_animacion_ult, "Disparo 4 debe ser normal")
	general.anim_timer = general.tiempo_disparo_normal + 0.01
	general._process_shooting(0.01)
	assert_eq(general.contador_disparos, 4, "Contador de disparos debe ser 4")

	# Act & Assert - Disparo 5 (Normal)
	general._on_state_shooting()
	assert_false(general.en_animacion_ult, "Disparo 5 debe ser normal")
	general.anim_timer = general.tiempo_disparo_normal + 0.01
	general._process_shooting(0.01)
	assert_eq(general.contador_disparos, 5, "Contador de disparos debe ser 5")

	# Act & Assert - Disparo 6 (ULTIMATE!)
	general._on_state_shooting()
	assert_true(general.en_animacion_ult, "Disparo 6 DEBE ser el ataque definitivo (Ult)")
	if general.anim_player:
		assert_eq(general.anim_player.current_animation, "Ult", "Animación del 6º disparo debe ser 'Ult'")
	general.anim_timer = general.tiempo_disparo_ult + 0.01
	general._process_shooting(0.01)
	assert_eq(general.contador_disparos, 0, "El contador de disparos debe reiniciarse a 0 tras ejecutar el Ult")


func test_ult_disparo_normal_y_bufo_arqueras_cercanas() -> void:
	# Arrange
	var general = GOBLIN_GENERAL_SCENE.instantiate() as GoblinGeneralScript
	add_child_autofree(general)
	general.global_position = Vector3(0.0, 0.0, 0.0)

	var arquera_cercana = GOBLIN_GIRL_SCENE.instantiate() as GoblinGirl
	add_child_autofree(arquera_cercana)
	arquera_cercana.global_position = Vector3(5.0, 0.0, 0.0)

	var arquera_lejana = GOBLIN_GIRL_SCENE.instantiate() as GoblinGirl
	add_child_autofree(arquera_lejana)
	arquera_lejana.global_position = Vector3(50.0, 0.0, 0.0)

	var mock_player = Node3D.new()
	add_child_autofree(mock_player)
	mock_player.add_to_group("player")
	mock_player.global_position = Vector3(-8.0, 3.0, 0.0)
	general.player_ref = mock_player
	await get_tree().process_frame

	var flechas_antes: int = 0
	for c in get_tree().root.get_children():
		if c is GoblinGirlArrowProjectile:
			flechas_antes += 1

	# Act: Disparar Ult
	general._disparar_ult()

	# Assert 1: Disparo normal (exactamente 1 flecha)
	var flechas_despues: int = 0
	for c in get_tree().root.get_children():
		if c is GoblinGirlArrowProjectile:
			flechas_despues += 1

	assert_eq(flechas_despues - flechas_antes, 1, "El Ult debe ser un disparo normal (1 sola flecha)")

	# Assert 2: Arquera cercana bufeada con frenesí (3x velocidad por 10s)
	assert_true(arquera_cercana.buff_frenesi_activo, "La arquera goblin cercana debe recibir el buff de frenesí")
	assert_almost_eq(arquera_cercana.buff_frenesi_timer, 10.0, 0.1, "La duración del buff debe ser de 10 segundos")
	assert_almost_eq(arquera_cercana.multiplicador_frenesi, 3.0, 0.01, "La cadencia debe triplicarse")

	# Assert 3: Arquera fuera de radio no recibe el buff
	assert_false(arquera_lejana.buff_frenesi_activo, "La arquera lejana no debe ser afectada por el Ult")


func test_goblin_girl_buff_frenesi_efectos_visuales_y_expiracion() -> void:
	# Arrange
	var girl = GOBLIN_GIRL_SCENE.instantiate() as GoblinGirl
	add_child_autofree(girl)
	await get_tree().process_frame

	# Act: Aplicar frenesí
	girl.aplicar_buff_frenesi(10.0, 3.0)
	await get_tree().process_frame

	# Assert 1: Aura y barra creadas y visibles
	assert_true(girl.buff_frenesi_activo, "Buff debe estar activo")
	assert_not_null(girl._aura_frenesi_node, "Debe instanciarse el nodo de aura de frenesí")
	assert_true(girl._aura_frenesi_node.visible, "El aura debe ser visible")
	assert_almost_eq(girl._aura_frenesi_node.scale.x, 0.24, 0.01, "El aura debe tener escala reducida (0.24)")

	assert_not_null(girl._canvas_frenesi, "Debe instanciarse el CanvasLayer de la barra circular")
	assert_not_null(girl._barra_frenesi_control, "Debe instanciarse el Control BarraCircularFuegoRapido")
	assert_true(girl._barra_frenesi_control.visible, "El control circular debe ser visible")

	# Act 2: Procesar 5 segundos
	girl._actualizar_buff_frenesi(5.0)
	assert_almost_eq(girl.buff_frenesi_timer, 5.0, 0.05, "Debe restar el tiempo correctamente")
	assert_almost_eq(girl._barra_frenesi_control.progress, 0.5, 0.05, "Progreso de barra debe ser 50%")

	# Act 3: Expirar el buff (otros 5.1 segundos)
	girl._actualizar_buff_frenesi(5.1)
	assert_false(girl.buff_frenesi_activo, "El buff debe expirar tras 10 segundos")
	assert_almost_eq(girl.multiplicador_frenesi, 1.0, 0.01, "El multiplicador de velocidad debe regresar a 1.0")
	assert_false(girl._aura_frenesi_node.visible, "El aura debe ocultarse al expirar")
	assert_false(girl._barra_frenesi_control.visible, "La barra circular debe ocultarse al expirar")


func test_sincronizacion_tensado_cuerda_arco() -> void:
	# Arrange
	var general = GOBLIN_GENERAL_SCENE.instantiate() as GoblinGeneralScript
	add_child_autofree(general)
	await get_tree().process_frame

	# Act: Iniciar ciclo de disparo
	general.contador_disparos = 0
	general._on_state_shooting()

	# Assert 1: Al inicio el arco está en reposo, flecha oculta
	assert_false(general.ha_iniciado_tensado, "No debe iniciar tensado en t=0.0")
	assert_false(general.has_fired_this_cycle, "No debe haber disparado al inicio")
	if general.flecha_visual_mano:
		assert_false(general.flecha_visual_mano.visible, "Flecha de mano debe estar oculta antes del tensado")

	# Act 2: Avanzar antes de tiempo_inicio_tensa_normal (ej. 0.40s < 0.55s)
	general._process_shooting(0.40)
	assert_false(general.ha_iniciado_tensado, "A los 0.40s aún no debe haber iniciado tensado")

	# Act 3: Avanzar justo al inicio del tensado (0.55s)
	general._process_shooting(0.16) # timer = 0.56s >= 0.55s
	assert_true(general.ha_iniciado_tensado, "A los 0.56s ya debe haber iniciado el tensado del arco")
	if general.flecha_visual_mano:
		assert_true(general.flecha_visual_mano.visible, "Flecha de mano debe ser visible durante el tensado")

	# Act 4: Avanzar hasta el disparo (1.052s)
	general._process_shooting(0.50) # timer = 1.06s >= 1.052s
	assert_true(general.has_fired_this_cycle, "Debe haberse disparado la flecha al alcanzar el tiempo de disparo (1.052s)")
	if general.flecha_visual_mano:
		assert_false(general.flecha_visual_mano.visible, "Flecha de mano debe ocultarse tras el disparo")


func test_ult_flecha_visible_toda_la_ventana_frame_a_frame() -> void:
	# Arrange: ciclo Ult simulado como en juego (deltas de 1/60)
	var general = GOBLIN_GENERAL_SCENE.instantiate() as GoblinGeneralScript
	add_child_autofree(general)
	await get_tree().process_frame
	general.contador_disparos = 5
	general._on_state_shooting()
	assert_true(general.en_animacion_ult, "Precondición: debe estar en Ult")
	assert_not_null(general.flecha_visual_mano, "Precondición: debe existir FlechaMano")

	# Act: avanzar 4 segundos frame a frame (cubre tensado 3.17, hold 3.40 y suelta 3.70)
	var muestras_dentro: int = 0
	var ocultas_dentro: int = 0
	var vistas_fuera: int = 0
	for i in range(240):
		general._process_shooting(1.0 / 60.0)
		var t: float = general.anim_timer
		if t >= general.tiempo_inicio_tensa_ult and t < general.tiempo_disparo_ult:
			muestras_dentro += 1
			if not general.flecha_visual_mano.visible:
				ocultas_dentro += 1
		elif t < general.tiempo_inicio_tensa_ult and general.flecha_visual_mano.visible:
			vistas_fuera += 1

	# Assert
	assert_gt(muestras_dentro, 20, "Debe haber suficientes muestras dentro de la ventana de tensado del Ult")
	assert_eq(ocultas_dentro, 0, "La flecha debe verse en TODA la ventana de tensado del Ult (3.17-3.70s)")
	assert_eq(vistas_fuera, 0, "La flecha no debe verse antes de que la mano tome la cuerda")
	assert_true(general.has_fired_this_cycle, "El Ult debe haber disparado al pasar los 3.70s")
	assert_false(general.flecha_visual_mano.visible, "Tras la suelta la flecha de mano debe ocultarse")


func test_drop_fuego_rapido_al_morir() -> void:
	# Arrange
	var general = GOBLIN_GENERAL_SCENE.instantiate() as GoblinGeneralScript
	add_child_autofree(general)
	await get_tree().process_frame

	# Assert 1: Configuración de probabilidad 5% y escena asignada
	assert_almost_eq(general.probabilidad_drop_fuego_rapido, 0.05, 0.001, "La probabilidad de drop debe ser 5% (0.05)")
	assert_not_null(general.power_up_fuego_rapido_scene, "Debe tener asignada la escena de PowerUpFuegoRapido")

	# Act: Forzar probabilidad al 100% para verificar instanciación al morir
	general.probabilidad_drop_fuego_rapido = 1.0
	general._dropear_power_up()

	# Assert 2: PowerUp fue añadido a la escena
	var power_up = get_tree().root.find_child("PowerUpFuegoRapido", true, false)
	assert_not_null(power_up, "El power up de Fuego Rápido debe haberse instanciado en la escena")

	# Act 3: Intentar segundo drop no debe duplicarlo
	var count_antes: int = get_tree().root.find_children("*", "PowerUpFuegoRapido", true, false).size()
	general._dropear_power_up()
	var count_despues: int = get_tree().root.find_children("*", "PowerUpFuegoRapido", true, false).size()
	assert_eq(count_antes, count_despues, "No debe dropear más de una vez por muerte")

	if power_up:
		power_up.queue_free()


func test_arco_anclado_a_mano_derecha() -> void:
	# Arrange
	var general = GOBLIN_GENERAL_SCENE.instantiate() as GoblinGeneralScript
	add_child_autofree(general)
	await get_tree().process_frame

	var b_arco := general.find_child("BoneAttachmentArco", true, false) as BoneAttachment3D
	var b_flecha := general.find_child("BoneAttachmentFlecha", true, false) as BoneAttachment3D

	# Assert: verificar que el arco está en la mano derecha y la flecha en la izquierda
	assert_not_null(b_arco, "BoneAttachmentArco debe existir")
	assert_not_null(b_flecha, "BoneAttachmentFlecha debe existir")

	assert_eq(b_arco.bone_name, "mixamorig_RightHand", "El arco debe estar anclado a mixamorig_RightHand (mano derecha)")
	assert_eq(b_arco.bone_idx, 44, "El índice del hueso de mano derecha debe ser 44")

	assert_eq(b_flecha.bone_name, "mixamorig_LeftHand", "La flecha de mano debe estar anclada a mixamorig_LeftHand (mano izquierda que tensa la cuerda)")
	assert_eq(b_flecha.bone_idx, 17, "El índice del hueso de mano izquierda debe ser 17")

	# Act & Assert: verificar que el arco acompaña a la mano derecha durante la animación
	var ap := general.anim_player as AnimationPlayer
	var skel := general.skeleton as Skeleton3D

	if ap and skel:
		ap.play("disparo")
		ap.seek(0.5, true)
		skel.force_update_all_bone_transforms()
		await get_tree().process_frame

		var rh_world: Vector3 = skel.global_transform * skel.get_bone_global_pose(44).origin
		var bow_node := general.find_child("ARCO_GOBLING_GIRL", true, false) as Node3D
		assert_not_null(bow_node, "ARCO_GOBLING_GIRL debe existir bajo BoneAttachmentArco")

		var bow_world: Vector3 = bow_node.global_position
		var dist: float = (bow_world - rh_world).length()
		assert_lt(dist, 0.2, "El arco debe permanecer en la mano derecha durante la animación")


func test_muerte_explosiva_suelta_arco() -> void:
	# Arrange
	var general = GOBLIN_GENERAL_SCENE.instantiate() as GoblinGeneralScript
	add_child_autofree(general)
	general.murio_por_explosion = true

	# Act: daño letal con explosiva marcada
	general.take_damage(99.0)

	# Assert: el arco sale volando en contenedor físico
	var piezas := get_tree().root.find_children("*", "GoblinPiezaFisica", true, false)
	assert_false(piezas.is_empty(), "El arco sale volando al morir por explosiva")
	for p in piezas:
		(p as Node).queue_free()


func test_rodando_atraviesa_sin_dano_y_dice_fallaste() -> void:
	# Arrange
	var general = GOBLIN_GENERAL_SCENE.instantiate() as GoblinGeneralScript
	add_child_autofree(general)
	general.esta_rodando = true
	var flecha := ARROW_SCENE.instantiate()
	add_child_autofree(flecha)

	# Act
	var resultado: bool = general.manejar_impacto_aura(flecha)

	# Assert: pasa de largo marcada y avisa en blanco
	assert_false(resultado, "Rodando no repele: deja pasar")
	assert_true(flecha.has_meta("atravesar_rodando"), "Marca la flecha para atravesar")
	var carteles := get_tree().root.find_children("*", "Label3D", true, false)
	var visto := false
	for c in carteles:
		if (c as Label3D).text == tr("Fallaste"):
			visto = true
		(c as Node).queue_free()
	assert_true(visto, "Muestra Fallaste en blanco")



func test_muerte_explosiva_deja_charco() -> void:
	var general = GOBLIN_GENERAL_SCENE.instantiate() as GoblinGeneralScript
	add_child_autofree(general)
	general.murio_por_explosion = true
	general.take_damage(99.0)
	var charcos := get_tree().root.find_children("ManchaSangreSuelo", "", true, false)
	assert_false(charcos.is_empty(), "Mancha de sangre del Imp al morir por explosiva")
	for c in charcos:
		(c as Node).queue_free()


func test_sincronizacion_tensado_cuerda_arco_ult() -> void:
	# Arrange
	var general = GOBLIN_GENERAL_SCENE.instantiate() as GoblinGeneralScript
	add_child_autofree(general)
	await get_tree().process_frame

	# Act: Iniciar ciclo que corresponde al Ult (6º disparo)
	general.contador_disparos = 5
	general._on_state_shooting()

	# Assert 1: Entra en animación Ult, tensado no iniciado, flecha oculta
	assert_true(general.en_animacion_ult, "El 6º disparo debe activar en_animacion_ult")
	assert_false(general.ha_iniciado_tensado, "No debe haber iniciado tensado en t=0.0")
	assert_false(general.has_fired_this_cycle, "No debe haber disparado al inicio")
	if general.flecha_visual_mano:
		assert_false(general.flecha_visual_mano.visible, "Flecha de mano debe estar oculta antes del tensado")

	# Act 2: Durante el grito de guerra / carga del Ult (ej. 3.10s < 3.17s), aún no tensa
	general._process_shooting(3.10)
	assert_false(general.ha_iniciado_tensado, "A los 3.10s aún no debe haber iniciado tensado (está en grito de guerra)")
	assert_false(general.has_fired_this_cycle, "No debe disparar al inicio ni mitad de la animación")

	# Act 3: La mano toma la cuerda e inicia el gesto rápido de tensado (3.20s >= 3.17s)
	general._process_shooting(0.10) # timer = 3.20s >= 3.17s
	assert_true(general.ha_iniciado_tensado, "A los 3.20s ya debe haber iniciado el tensado del arco")
	if general.flecha_visual_mano:
		assert_true(general.flecha_visual_mano.visible, "Flecha de mano debe ser visible durante el tensado")
		var meshes = general.flecha_visual_mano.find_children("*", "MeshInstance3D", true, false)
		if not meshes.is_empty():
			var mi = meshes[0] as MeshInstance3D
			assert_not_null(mi.material_override, "La flecha de mano debe tener material_override asignado")
			var mat = mi.material_override as StandardMaterial3D
			assert_eq(mat.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "Debe ser unshaded como la flecha disparada")
			assert_eq(mat.albedo_color, GoblinGirlArrowProjectile.GOBLIN_GIRL_ARROW_MAGENTA, "Debe tener el mismo color magenta que el proyectil disparado")

	# Act 4: La cuerda llega a tope con la mano (3.40s) y se mantiene durante el apuntado
	general._process_shooting(0.25) # timer = 3.45s >= 3.40s
	assert_false(general.has_fired_this_cycle, "A los 3.45s aún no debe haber disparado (está apuntando a máxima tensión)")
	if general.flecha_visual_mano:
		assert_true(general.flecha_visual_mano.visible, "Flecha de mano debe seguir visible mientras apunta")
	if general.bow_anim_player and "TENSAR" in str(general.bow_anim_player.current_animation):
		assert_false(general.bow_anim_player.is_playing(), "La cuerda debe quedar en espera a máxima tensión sin seguir moviéndose")

	# Act 5: Suelta del Ult a máxima tensión (3.70s)
	general._process_shooting(0.30) # timer = 3.75s >= 3.70s
	assert_true(general.has_fired_this_cycle, "Debe haberse disparado la flecha al alcanzar el frame de suelta (3.70s)")
	if general.flecha_visual_mano:
		assert_false(general.flecha_visual_mano.visible, "Flecha de mano debe ocultarse tras el disparo del Ult")


func test_recuperacion_post_ult_sin_congelado() -> void:
	# Arrange
	var general = GOBLIN_GENERAL_SCENE.instantiate() as GoblinGeneralScript
	add_child_autofree(general)
	await get_tree().process_frame

	general.contador_disparos = 5
	general._on_state_shooting()
	assert_true(general.en_animacion_ult, "Debe estar en Ult")
	assert_almost_eq(general.pausa_recuperacion_post_ult, 0.6, 0.01, "La recuperación post-Ult debe ser breve (0.6s, sin congelado de 1.5s)")
	assert_almost_eq(general.shoot_timer, 0.6, 0.01, "El shoot_timer del Ult debe inicializarse a 0.6 segundos")

	# Act 1: Disparar el Ult para que el contador se reinicie
	general.anim_timer = general.tiempo_disparo_ult + 0.01
	general._process_shooting(0.01)
	assert_eq(general.contador_disparos, 0, "El contador debe reiniciarse al disparar el Ult")

	var duracion_ult: float = general._get_animation_duration("Ult")
	assert_gt(duracion_ult, 0.0, "La duración de la animación Ult debe ser positiva")

	# Act 2: Avanzar hasta que termine el follow-through natural de la animación
	general.anim_timer = duracion_ult
	general._process_shooting(0.01)

	# Assert 1: Sin seek+pause forzado; el timer descuenta la recuperación
	assert_almost_eq(general.shoot_timer, 0.59, 0.02, "shoot_timer debe descontar tiempo durante la recuperación")
	assert_true(general.en_animacion_ult, "Aún no debe reiniciar ciclo porque no terminó la recuperación")

	# Act 3: Completar la recuperación (0.7s más, total 0.71s > 0.6s)
	# Con el congelado anterior de 1.5s seguiría parado aquí; ahora ya retomó el ritmo.
	general._process_shooting(0.70)
	assert_false(general.en_animacion_ult, "Tras la breve recuperación debe retomar el ciclo de disparo normal")
	assert_eq(general.contador_disparos, 0, "El contador de disparos debe seguir reiniciado")
	if general.anim_player:
		assert_eq(general.anim_player.current_animation, "disparo", "Debe enlazar suave con la animación de disparo normal")

