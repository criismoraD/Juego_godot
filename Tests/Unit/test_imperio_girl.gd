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
	
	# 1. Verificar registro y alias del clip de caminar apuntando
	assert_true(
		girl.anim_player.has_animation("Armature|Armature|APUNTAR_CAMINAR_ADELANTE"),
		"ImperioGirl debe tener registrado el alias Armature|Armature|APUNTAR_CAMINAR_ADELANTE"
	)
	var anim: Animation = girl.anim_player.get_animation("Armature|Armature|APUNTAR_CAMINAR_ADELANTE")
	assert_not_null(anim, "La animacion de apuntar caminando debe existir")
	assert_eq(anim.loop_mode, Animation.LOOP_LINEAR, "La animacion debe tener LOOP_LINEAR activado")
	
	# 2. Verificar detección de clip de aim walk dedicado
	assert_true(girl._tiene_clip_aim_walk_dedicado(), "_tiene_clip_aim_walk_dedicado() debe retornar true")
	
	# 3. Locomocion normal sin apuntar (moverse hacia adelante -> run_fwd)
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
	
	# 4. Apuntando a la derecha y avanzando hacia la derecha (input_dir > 0) -> aim_walk_fwd
	girl.current_aim_state = Player.AimState.AIMING
	girl._mirando_derecha = true
	girl.update_locomotion_anim(1.0)
	assert_eq(
		girl.anim_tree.get("parameters/Locomotion/transition_request"),
		"aim_walk_fwd",
		"Al apuntar y avanzar de frente debe solicitar aim_walk_fwd"
	)
	
	# 5. Apuntando a la derecha y retrocediendo hacia la izquierda (input_dir < 0) -> walk_back
	girl.update_locomotion_anim(-1.0)
	assert_eq(
		girl.anim_tree.get("parameters/Locomotion/transition_request"),
		"walk_back",
		"Al apuntar y retroceder debe solicitar walk_back"
	)
	
	# 6. Apuntando a la izquierda y avanzando hacia la izquierda (input_dir < 0) -> aim_walk_fwd
	girl._mirando_derecha = false
	girl.update_locomotion_anim(-1.0)
	assert_eq(
		girl.anim_tree.get("parameters/Locomotion/transition_request"),
		"aim_walk_fwd",
		"Al apuntar a la izquierda y moverse a la izquierda debe solicitar aim_walk_fwd"
	)
	
	# 7. Apuntando a la izquierda y retrocediendo hacia la derecha (input_dir > 0) -> walk_back
	girl.update_locomotion_anim(1.0)
	assert_eq(
		girl.anim_tree.get("parameters/Locomotion/transition_request"),
		"walk_back",
		"Al apuntar a la izquierda y retroceder a la derecha debe solicitar walk_back"
	)
	
	# 8. Al tensar el arco (DRAWING) y moverse de frente -> aim_walk_fwd
	girl.current_aim_state = Player.AimState.DRAWING
	girl._mirando_derecha = true
	girl.update_locomotion_anim(1.0)
	assert_eq(
		girl.anim_tree.get("parameters/Locomotion/transition_request"),
		"aim_walk_fwd",
		"En estado DRAWING avanzando de frente debe solicitar aim_walk_fwd"
	)
	
	girl.queue_free()

