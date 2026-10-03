extends "res://addons/gut/test.gd"

## Imperio Girl jugable: al apuntar quieta en suelo usa pose de cuerpo
## completo de perfil (entrada "aim_full"), como las defensoras.
## En movimiento conserva el sistema de Eryn (piernas + torso superpuesto).

const ESCENA_IMPERIO_GIRL: PackedScene = preload("res://Entities/Jugador_ImperioGirl/ImperioGirl.tscn")


func _crear_prota() -> ImperioGirl:
	var prota: ImperioGirl = ESCENA_IMPERIO_GIRL.instantiate() as ImperioGirl
	add_child_autofree(prota)
	await get_tree().process_frame
	await get_tree().process_frame
	return prota


func test_arbol_tiene_entrada_aim_full() -> void:
	# Arrange & Act
	var prota: ImperioGirl = await _crear_prota()

	# Assert
	var root := prota.anim_tree.tree_root as AnimationNodeBlendTree
	assert_not_null(root, "Árbol dinámico construido")
	var nodo := root.get_node("AimFull") as AnimationNodeAnimation
	assert_not_null(nodo, "Entrada AimFull agregada")
	assert_eq(nodo.animation, "Armature|Armature|APUNTAR_IDLE", "Pose completa de apuntado")
	var loco := root.get_node("Locomotion") as AnimationNodeTransition
	assert_not_null(loco, "Nodo Locomotion presente")
	assert_eq(loco.input_count, 5, "Locomotion con 5 entradas")
	assert_eq(loco.get_input_name(4), "aim_full", "Quinta entrada aim_full")


func test_apuntar_quieta_usa_pose_completa() -> void:
	# Arrange: apuntando, en suelo, sin moverse (gameplay congelado para que
	# no revierta el estado; el AnimationTree sigue avanzando solo)
	var prota: ImperioGirl = await _crear_prota()
	prota.set_process(false)
	prota.set_physics_process(false)
	prota.current_move_state = Player.MoveState.GROUND
	prota.current_aim_state = Player.AimState.AIMING

	# Act
	prota.update_locomotion_anim(0.0)
	await get_tree().create_timer(0.4).timeout

	# Assert
	assert_eq(
		prota.anim_tree.get("parameters/Locomotion/current_state"), "aim_full",
		"Quieta apuntando: cuerpo completo de perfil"
	)


func test_apuntar_moviendose_conserva_marcha() -> void:
	# Arrange: apuntando y avanzando (gameplay congelado, árbol activo)
	var prota: ImperioGirl = await _crear_prota()
	prota.set_process(false)
	prota.set_physics_process(false)
	prota.current_move_state = Player.MoveState.GROUND
	prota.current_aim_state = Player.AimState.AIMING

	# Act
	prota.update_locomotion_anim(1.0)
	await get_tree().create_timer(0.4).timeout

	# Assert: piernas en marcha como Eryn (walk_fwd), no pose fija
	assert_eq(
		prota.anim_tree.get("parameters/Locomotion/current_state"), "walk_fwd",
		"En movimiento: marcha con torso superpuesto"
	)
