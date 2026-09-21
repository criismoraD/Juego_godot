extends GutTest

## Tests de la flecha en mano de GoblinGirl:
## la pose afinada en el editor (FlechaMano bajo BoneAttachment3D2) debe ser la
## fuente de verdad y NO pisada por offset_flecha_mano (0,0,0) durante el disparo.

const GOBLIN_GIRL_SCENE: PackedScene = preload("res://Entities/Enemigo_Goblin_Girl/GoblinGirl.tscn")

var scene_root: Node3D


func before_each() -> void:
	scene_root = Node3D.new()
	add_child(scene_root)


func after_each() -> void:
	if is_instance_valid(scene_root):
		scene_root.queue_free()
	await get_tree().process_frame


func test_pose_base_flecha_capturada_del_editor() -> void:
	# Arrange & Act
	var goblin := GOBLIN_GIRL_SCENE.instantiate() as GoblinGirl
	scene_root.add_child(goblin)
	await get_tree().process_frame

	# Assert: la flecha en mano existe y su pose base fue capturada
	assert_not_null(goblin.flecha_visual_mano, "GoblinGirl debe tener FlechaMano de la escena")
	assert_true(
		goblin._pose_base_flecha_mano != Transform3D.IDENTITY,
		"La pose base debe capturarse del nodo colocado en el editor"
	)
	assert_true(
		goblin._pose_base_flecha_mano == goblin.flecha_visual_mano.transform,
		"La pose base debe coincidir con el transform local afinado en la escena"
	)

	goblin.queue_free()
	await get_tree().process_frame


func test_animacion_disparo_no_pisa_la_pose_de_la_flecha() -> void:
	# Arrange
	var goblin := GOBLIN_GIRL_SCENE.instantiate() as GoblinGirl
	scene_root.add_child(goblin)
	await get_tree().process_frame
	var origen_esperado: Vector3 = goblin._pose_base_flecha_mano.origin
	assert_false(
		origen_esperado.is_zero_approx(),
		"Precondición: la flecha afinada en editor no debe estar en el origen del hueso"
	)

	# Act: forzar rama "else" (fuera de fase de tensión) de la animación de disparo
	goblin.en_animacion_disparo = true
	goblin.anim_timer = 0.0
	goblin._actualizar_flecha_mano_durante_animacion()

	# Assert: la posición se restaura a la pose base, nunca a offset_flecha_mano (0,0,0)
	assert_eq(
		goblin.flecha_visual_mano.position,
		origen_esperado,
		"La animación debe restaurar la pose base del editor, no (0,0,0)"
	)

	goblin.queue_free()
	await get_tree().process_frame


func test_tiradora_fija_pasa_a_tiro_sin_bucle_caminata() -> void:
	# Arrange: arquera apostada (velocidad 0, como las del río)
	var goblin := GOBLIN_GIRL_SCENE.instantiate() as GoblinGirl
	scene_root.add_child(goblin)
	await get_tree().process_frame
	goblin.velocidad_caminar = 0.0
	goblin.target_walk_distance = 0.0
	goblin.walked_distance = 0.0
	goblin._change_state(EnemyBase.State.WALKING)

	# Act: procesar caminata sin poder avanzar
	goblin._process_walking(0.016)

	# Assert: a tiro directo, quieta, sin bucle de caminata
	assert_eq(goblin.current_state, EnemyBase.State.SHOOTING, "La tiradora fija debe pasar a SHOOTING")
	assert_eq(goblin.velocity.x, 0.0, "Debe estar detenida")

	goblin.queue_free()
	await get_tree().process_frame


func test_tiro_bloqueado_queda_en_guardia_quieta() -> void:
	# Arrange: en tiro pero sin permiso de atacar
	var goblin := GOBLIN_GIRL_SCENE.instantiate() as GoblinGirl
	scene_root.add_child(goblin)
	await get_tree().process_frame
	goblin._change_state(EnemyBase.State.DYING)

	# Act: ciclo de tiro bloqueado
	goblin._process_shooting(0.016)

	# Assert: guardia quieta congelada, no caminando en el sitio
	assert_true(String(goblin.anim_player.current_animation).contains("CAMINA"), "Bloqueada debe quedar quieta, no caminando")

	goblin.queue_free()
	await get_tree().process_frame


func test_rio_espera_dormida_y_activa_en_cuadro() -> void:
	# Arrange: versión del río, fuera de cámara (sin cámara en headless)
	var goblin := GOBLIN_GIRL_SCENE.instantiate() as GoblinGirl
	goblin.activar_al_entrar_en_camara = true
	scene_root.add_child(goblin)
	await get_tree().process_frame

	# Assert: dormida, quieta y sin física ni proceso hasta entrar en cuadro
	assert_true(goblin._dormida_por_camara, "Debe esperar dormida fuera de cámara")
	assert_false(goblin.is_physics_processing(), "Dormida no debe desplazarse")
	assert_false(goblin.is_processing(), "Dormida no debe procesar ni sonar")

	# Act: entra en el cuadro de la cámara
	goblin._activar_por_camara()

	# Assert: activa con su ciclo normal
	assert_false(goblin._dormida_por_camara, "Debe activarse al entrar en cuadro")
	assert_true(goblin.is_physics_processing(), "Activa debe correr física")
	assert_true(goblin.is_processing(), "Activa debe procesar")

	goblin.queue_free()
	await get_tree().process_frame


func test_rio_recibir_dano_despierta() -> void:
	# Arrange: dormida fuera de cámara
	var goblin := GOBLIN_GIRL_SCENE.instantiate() as GoblinGirl
	goblin.activar_al_entrar_en_camara = true
	scene_root.add_child(goblin)
	await get_tree().process_frame
	var vida_antes: int = goblin.health
	assert_true(goblin._dormida_por_camara, "Precondición: dormida")

	# Act: la alcanzan antes de entrar en cuadro
	goblin.take_damage(1.0)

	# Assert: despierta y aplica el daño
	assert_false(goblin._dormida_por_camara, "Recibir daño la despierta")
	assert_eq(goblin.health, vida_antes - 1, "Aplica el daño normalmente")

	goblin.queue_free()
	await get_tree().process_frame
