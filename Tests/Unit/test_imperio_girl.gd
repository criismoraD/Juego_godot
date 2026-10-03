extends GutTest

const IMPERIO_GIRL_SCENE: PackedScene = preload("res://Entities/Jugador_ImperioGirl/ImperioGirl.tscn")
const MAT_IMPERIO_GIRL: Material = preload("res://Entities/Jugador_ImperioGirl/IMPERIO_GIRL_MAT.tres")

func test_imperio_girl_instantiation_and_class():
	var girl = IMPERIO_GIRL_SCENE.instantiate()
	assert_not_null(girl, "ImperioGirl should instantiate")
	assert_true(girl is Player, "ImperioGirl should inherit from Player")
	assert_true(girl is CharacterBody3D, "ImperioGirl should be CharacterBody3D")
	girl.free()

func test_imperio_girl_ready_and_equipment():
	var girl = IMPERIO_GIRL_SCENE.instantiate()
	add_child(girl)
	
	# Verify AnimationTree and AnimationPlayer
	assert_not_null(girl.anim_tree, "AnimationTree must exist")
	assert_not_null(girl.anim_player, "AnimationPlayer must be resolved")
	
	# Verify Animations mapped
	assert_true(girl.anim_player.has_animation("Armature|Armature|IDLE"), "Must have IDLE")
	assert_true(girl.anim_player.has_animation("Armature|Armature|CAMINAR_ADELANTE"), "Must have CAMINAR_ADELANTE")
	assert_true(girl.anim_player.has_animation("Armature|Armature|CORRER_ADELANTE"), "Must have CORRER_ADELANTE")
	assert_true(girl.anim_player.has_animation("Armature|Armature|DISPARAR"), "Must have DISPARAR")
	assert_true(girl.anim_player.has_animation("Armature|Armature|CAER_SALTAR"), "Must have CAER_SALTAR")
	assert_true(girl.anim_player.has_animation("Armature|Armature|SUBIR_ESCALERA"), "Must have SUBIR_ESCALERA")
	assert_true(girl.anim_player.has_animation("Armature|Armature|MUERTE"), "Must have MUERTE")
	assert_true(girl.anim_player.has_animation("Armature|Armature|HIT"), "Must have HIT")
	
	# Verify Bow and Arrow equipment
	assert_not_null(girl.bow_node, "Bow node must be attached")
	assert_not_null(girl.arrow_node, "Arrow node must be attached")
	assert_not_null(girl.spawn_flecha_explosiva, "Marker for explosive arrow must exist")
	
	# Verify Material Override
	var mesh = girl.find_child("Imperio Girl", true, false) as MeshInstance3D
	assert_not_null(mesh, "Imperio Girl MeshInstance3D must exist")
	if mesh:
		assert_eq(mesh.material_override, MAT_IMPERIO_GIRL, "Material override should be applied")
	
	# Verify Health
	assert_eq(girl.vida_maxima, 4, "Vida maxima should be 4")
	assert_eq(girl.health, 4, "Health should start at 4")
	
	girl.queue_free()

func test_imperio_girl_damage_and_signals():
	var girl = IMPERIO_GIRL_SCENE.instantiate()
	add_child(girl)
	watch_signals(girl)
	
	girl.take_damage(1)
	assert_signal_emitted(girl, "health_changed", "Should emit health_changed on damage")
	assert_eq(girl.health, 3, "Health should decrease to 3")
	
	girl.queue_free()

func test_imperio_girl_disparo_y_municion():
	var girl = IMPERIO_GIRL_SCENE.instantiate()
	add_child(girl)
	watch_signals(girl)
	
	# Verificar munición especial
	girl.agregar_flechas_explosivas(3)
	assert_signal_emitted(girl, "flechas_explosivas_changed")
	assert_eq(girl.flechas_explosivas, 3)
	
	girl.agregar_flechas_multiples(2)
	assert_signal_emitted(girl, "flechas_multiples_changed")
	assert_eq(girl.flechas_multiples, 2)
	
	# Cambiar tipo munición
	girl.municion_activa = Player.TipoMunicion.EXPLOSIVA
	assert_eq(girl.municion_activa, Player.TipoMunicion.EXPLOSIVA)
	
	girl.queue_free()

func test_imperio_girl_movement_and_climbing():
	var girl = IMPERIO_GIRL_SCENE.instantiate()
	add_child(girl)
	
	# Estado inicial
	assert_eq(girl.current_move_state, Player.MoveState.GROUND)
	
	# Simular salto / aire
	girl.current_move_state = Player.MoveState.AIR
	assert_eq(girl.current_move_state, Player.MoveState.AIR)
	
	# Simular agacharse
	girl.current_move_state = Player.MoveState.CROUCHING
	assert_eq(girl.current_move_state, Player.MoveState.CROUCHING)
	
	# Simular escalar
	girl.current_move_state = Player.MoveState.CLIMBING
	assert_eq(girl.current_move_state, Player.MoveState.CLIMBING)
	
	girl.queue_free()

func test_imperio_girl_aim_walk_forward_animation():
	var girl = IMPERIO_GIRL_SCENE.instantiate()
	add_child(girl)
	
	# 1. Verificar registro de clips clave
	assert_true(
		girl.anim_player.has_animation("Armature|Armature|CAMINAR_ADELANTE"),
		"ImperioGirl debe tener registrado CAMINAR_ADELANTE"
	)
	assert_true(
		girl.anim_player.has_animation("Armature|Armature|CAMINAR_ATRAS"),
		"ImperioGirl debe tener generado y registrado CAMINAR_ATRAS para retroceder"
	)
	var anim_atras: Animation = girl.anim_player.get_animation("Armature|Armature|CAMINAR_ATRAS")
	assert_not_null(anim_atras, "La animacion de retroceder debe existir")
	assert_eq(anim_atras.loop_mode, Animation.LOOP_LINEAR, "CAMINAR_ATRAS debe tener LOOP_LINEAR activado")
	
	# Verificar que TOMAR_FLECHA es una pose de tensar/apuntar y NO la suelta de flecha
	assert_true(
		girl.anim_player.has_animation("Armature|Armature|TOMAR_FLECHA"),
		"Debe tener registrado TOMAR_FLECHA"
	)
	assert_true(
		girl.anim_player.has_animation("Armature|Armature|APUNTAR_IDLE"),
		"Debe tener registrado APUNTAR_IDLE"
	)
	
	# 2. Locomocion normal sin apuntar (moverse hacia adelante -> run_fwd)
	girl.current_aim_state = Player.AimState.NONE
	girl.update_locomotion_anim(1.0)
	assert_eq(
		girl.anim_tree.get("parameters/Locomotion/transition_request"),
		"run_fwd",
		"Sin apuntar debe solicitar run_fwd al moverse"
	)
	
	# Sin moverse -> idle
	girl.update_locomotion_anim(0.0)
	assert_eq(
		girl.anim_tree.get("parameters/Locomotion/transition_request"),
		"idle",
		"Sin input debe solicitar idle"
	)
	
	# 3. Paridad con Eryn: Apuntando a la derecha y avanzando hacia la derecha (input_dir > 0) -> walk_fwd
	girl.current_aim_state = Player.AimState.AIMING
	girl._mirando_derecha = true
	girl.update_locomotion_anim(1.0)
	assert_eq(
		girl.anim_tree.get("parameters/Locomotion/transition_request"),
		"walk_fwd",
		"Al apuntar y avanzar de frente debe solicitar walk_fwd igual que Eryn"
	)
	
	# 4. Paridad con Eryn: Apuntando a la derecha y retrocediendo hacia la izquierda (input_dir < 0) -> walk_back
	girl.update_locomotion_anim(-1.0)
	assert_eq(
		girl.anim_tree.get("parameters/Locomotion/transition_request"),
		"walk_back",
		"Al apuntar y retroceder debe solicitar walk_back igual que Eryn"
	)
	
	# 5. Paridad con Eryn: Apuntando a la izquierda y avanzando hacia la izquierda (input_dir < 0) -> walk_fwd
	girl._mirando_derecha = false
	girl.update_locomotion_anim(-1.0)
	assert_eq(
		girl.anim_tree.get("parameters/Locomotion/transition_request"),
		"walk_fwd",
		"Al apuntar a la izquierda y moverse a la izquierda debe solicitar walk_fwd"
	)
	
	# 6. Paridad con Eryn: Apuntando a la izquierda y retrocediendo hacia la derecha (input_dir > 0) -> walk_back
	girl.update_locomotion_anim(1.0)
	assert_eq(
		girl.anim_tree.get("parameters/Locomotion/transition_request"),
		"walk_back",
		"Al apuntar a la izquierda y retroceder a la derecha debe solicitar walk_back"
	)
	
	# 7. Al tensar el arco (DRAWING) y moverse de frente -> walk_fwd
	girl.current_aim_state = Player.AimState.DRAWING
	girl._mirando_derecha = true
	girl.update_locomotion_anim(1.0)
	assert_eq(
		girl.anim_tree.get("parameters/Locomotion/transition_request"),
		"walk_fwd",
		"En estado DRAWING avanzando de frente debe solicitar walk_fwd"
	)
	
	# 8. Al tensar el arco (DRAWING) y retroceder -> walk_back
	girl.update_locomotion_anim(-1.0)
	assert_eq(
		girl.anim_tree.get("parameters/Locomotion/transition_request"),
		"walk_back",
		"En estado DRAWING retrocediendo debe solicitar walk_back"
	)
	
	girl.queue_free()


func test_imperio_girl_escalera_y_apuntado_paridad():
	var girl = IMPERIO_GIRL_SCENE.instantiate()
	add_child(girl)
	
	# 1. Rotación de escalera para orientarse de cara a los peldaños / espalda a cámara (180 deg idéntico a la protagonista)
	assert_almost_eq(girl.rotacion_personaje_escalera, 180.0, 0.1, "Debe ser 180 deg igual a la protagonista")
	
	# 2. Al entrar a la escalera sin apuntar, debe adoptar la rotación hacia la pared
	girl.current_move_state = Player.MoveState.CLIMBING
	girl.current_aim_state = Player.AimState.NONE
	girl._apply_character_rotation(0.016, true)
	var ang_escalera: float = rad_to_deg(girl.armature_node.rotation.y)
	assert_almost_eq(ang_escalera, 180.0 - 0.5, 1.0, "El armature debe rotar hacia los peldaños")
	
	# 3. Al apuntar en la escalera, debe voltearse de perfil hacia la derecha/izquierda
	girl.current_aim_state = Player.AimState.AIMING
	girl._mirando_derecha = true
	girl._apply_character_rotation(0.016, true)
	var ang_apuntar_der: float = rad_to_deg(girl.armature_node.rotation.y)
	assert_almost_eq(ang_apuntar_der, rad_to_deg(girl.armature_original_rotation.y), 1.0, "Debe mirar de perfil a la derecha al apuntar")
	
	girl._mirando_derecha = false
	girl._apply_character_rotation(0.016, true)
	var ang_apuntar_izq: float = rad_to_deg(girl.armature_node.rotation.y)
	assert_almost_eq(ang_apuntar_izq, rad_to_deg(girl.armature_original_rotation.y + PI), 1.0, "Debe mirar de perfil a la izquierda al apuntar")
	
	girl.queue_free()


func test_imperio_girl_modos_de_loop_en_animaciones():
	var girl = IMPERIO_GIRL_SCENE.instantiate()
	add_child(girl)

	# Loops continuos
	for anim_loop in [
		"Armature|Armature|IDLE",
		"Armature|Armature|CAMINAR_ADELANTE",
		"Armature|Armature|CAMINAR_ATRAS",
		"Armature|Armature|CORRER_ADELANTE",
		"Armature|Armature|APUNTAR_IDLE",
		"Armature|Armature|SUBIR_ESCALERA",
		"Armature|Armature|CAER_SALTAR"
	]:
		assert_true(girl.anim_player.has_animation(anim_loop), "Debe tener %s" % anim_loop)
		var a: Animation = girl.anim_player.get_animation(anim_loop)
		if a:
			assert_eq(a.loop_mode, Animation.LOOP_LINEAR, "%s debe tener loop activado" % anim_loop)

	# One-shots (no deben loopear)
	for anim_oneshot in [
		"Armature|Armature|DISPARAR",
		"Armature|Armature|ATERRIZAJE",
		"Armature|Armature|HIT",
		"Armature|Armature|MUERTE"
	]:
		assert_true(girl.anim_player.has_animation(anim_oneshot), "Debe tener %s" % anim_oneshot)
		var a: Animation = girl.anim_player.get_animation(anim_oneshot)
		if a:
			assert_eq(a.loop_mode, Animation.LOOP_NONE, "%s debe ser one-shot (LOOP_NONE)" % anim_oneshot)

	girl.queue_free()


