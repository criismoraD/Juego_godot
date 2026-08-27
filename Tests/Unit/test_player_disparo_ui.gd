extends "res://addons/gut/test.gd"

var PlayerScript = load("res://Entities/Jugador_Arquera/Player.gd")


func test_flag_bloqueo_ui_desactivado_por_defecto():
	var player := autofree(PlayerScript.new()) as CharacterBody3D
	assert_false(
		player.get("disparo_bloqueado_por_ui"),
		"El bloqueo de disparo por UI debe estar apagado por defecto (niveles normales)"
	)


func test_activar_bandera_en_mapa_debug():
	var player := autofree(PlayerScript.new()) as CharacterBody3D
	player.set("disparo_bloqueado_por_ui", true)
	assert_true(
		player.get("disparo_bloqueado_por_ui"),
		"El mapa debug debe poder activar el bloqueo de disparo por UI"
	)


func test_sin_hover_no_se_considera_clic_sobre_ui():
	var player := autofree(PlayerScript.new()) as CharacterBody3D
	add_child_autofree(player)
	await get_tree().process_frame
	assert_false(
		player._mouse_sobre_control_ui(),
		"Sin control bajo el cursor no debe considerarse clic sobre la UI"
	)


func test_orientacion_movimiento_normal_y_fijacion_al_apuntar():
	var player := autofree(PlayerScript.new()) as CharacterBody3D
	var armature := Node3D.new()
	armature.name = "Armature"
	player.add_child(armature)
	player.armature_node = armature
	player.armature_original_rotation = Vector3.ZERO
	add_child_autofree(player)

	# Movimiento hacia la izquierda sin apuntar (AimState.NONE)
	player.current_aim_state = player.AimState.NONE
	player._mirando_derecha = false
	player._apply_character_rotation(0.016, true)
	assert_almost_eq(armature.rotation.y, PI, 0.01, "La arquera debe voltearse hacia la izquierda al moverse hacia allá")

	# Al tensar el arco con mouse a la derecha, se orienta a la derecha
	player.current_aim_state = player.AimState.DRAWING
	player._mirando_derecha = true
	player._apply_character_rotation(0.016, true)
	assert_almost_eq(armature.rotation.y, 0.0, 0.01, "La arquera debe fijarse hacia la derecha al apuntar a la derecha")

	# Al tensar el arco con mouse a la izquierda, se orienta a la izquierda
	player._mirando_derecha = false
	player._apply_character_rotation(0.016, true)
	assert_almost_eq(armature.rotation.y, PI, 0.01, "La arquera debe fijarse hacia la izquierda al apuntar a la izquierda")


func test_desmontar_escalera_suave_a_plataforma():
	var player := autofree(PlayerScript.new()) as CharacterBody3D
	add_child_autofree(player)
	player.current_move_state = player.MoveState.CLIMBING
	player.velocity.y = 1.0

	player.dismount_ladder_top()

	assert_eq(player.current_move_state, player.MoveState.GROUND, "Debe pasar de inmediato a GROUND sin parpadeo aéreo")
	assert_eq(player.velocity.y, 0.0, "La velocidad vertical debe quedar en cero sobre la plataforma")
	assert_gt(player.ladder_cooldown, 0.0, "Debe activar cooldown para evitar re-montaje inmediato")


func test_agacharse_ajusta_hitbox_y_restaura():
	var player := autofree(PlayerScript.new()) as CharacterBody3D
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.height = 2.0
	col.shape = shape
	col.position.y = 1.0
	player.add_child(col)
	player.collision_shape_node = col
	player.hitbox_altura_original = 2.0
	player.hitbox_pos_y_original = 1.0
	add_child_autofree(player)

	# Agacharse
	player._ajustar_hitbox_agachado(true)
	assert_almost_eq(shape.height, 1.1, 0.01, "La altura de la cápsula debe reducirse al agacharse")
	assert_lt(col.position.y, 1.0, "La posición Y debe descender para mantener contacto con el suelo")

	# Levantarse
	player._ajustar_hitbox_agachado(false)
	assert_almost_eq(shape.height, 2.0, 0.01, "La altura de la cápsula debe restaurarse al levantarse")
	assert_almost_eq(col.position.y, 1.0, 0.01, "La posición Y debe restaurarse")


func test_sonido_impacto_flecha_registrado():
	# Assert
	assert_true(AudioManager.sfx_streams.has("arrow_impact"), "AudioManager debe tener registrado 'arrow_impact'")
	assert_true(AudioManager.sfx_streams.has("shield_hit_arrow"), "AudioManager debe tener registrado 'shield_hit_arrow'")





