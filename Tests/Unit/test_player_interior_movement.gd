extends GutTest

func test_player_interior_altura_al_caminar_sin_hundimiento() -> void:
	# Arrange
	var escena_nivel: PackedScene = load("res://Levels/Player_Interior.tscn") as PackedScene
	assert_not_null(escena_nivel, "La escena Player_Interior.tscn debe existir")
	var nivel: Node3D = escena_nivel.instantiate() as Node3D
	add_child_autofree(nivel)

	var player: PlayerInterior = nivel.find_child("Player", true, false) as PlayerInterior
	assert_not_null(player, "El nodo Player debe existir en el nivel")

	# Act & Settle
	for f in range(20):
		player._physics_process(1.0 / 60.0)

	var altura_inicial_y: float = player.global_position.y
	assert_lte(player.floor_snap_length, 0.005, "floor_snap_length debe ser mínimo (<= 0.005) para evitar hundimiento y despegue al moverse")

	# Simular caminata en las 4 direcciones y verificar que no se hunda
	var direcciones: Array[String] = ["move_right", "move_forward", "move_left", "move_back"]
	for dir in direcciones:
		Input.action_press(dir)
		for f in range(30):
			player._physics_process(1.0 / 60.0)
			var delta_y: float = absf(player.global_position.y - altura_inicial_y)
			assert_lt(delta_y, 0.010, "La altura Y al caminar en direccion %s no debe variar mas de 10mm (actual: %f)" % [dir, delta_y])
		Input.action_release(dir)


func test_animacion_pies_alineados_en_locomocion() -> void:
	# Arrange
	var scn: PackedScene = load("res://Entities/Jugador_Arquera/Player_Interior.tscn") as PackedScene
	assert_not_null(scn, "Player_Interior.tscn debe existir")
	var player: PlayerInterior = scn.instantiate() as PlayerInterior
	add_child_autofree(player)

	var anim_tree: AnimationTree = player.find_child("AnimationTree", true, false) as AnimationTree
	var skel: Skeleton3D = player.find_child("Skeleton3D", true, false) as Skeleton3D
	assert_not_null(anim_tree, "AnimationTree debe existir")
	assert_not_null(skel, "Skeleton3D debe existir")

	var lfoot: int = skel.find_bone("mixamorig_LeftFoot")
	var rfoot: int = skel.find_bone("mixamorig_RightFoot")
	assert_ne(lfoot, -1, "Hueso mixamorig_LeftFoot debe existir")
	assert_ne(rfoot, -1, "Hueso mixamorig_RightFoot debe existir")

	# Act
	anim_tree.set("parameters/Locomocion/transition_request", "idle")
	for i in range(10):
		anim_tree.advance(0.05)

	var idle_y: float = minf(
		(skel.global_transform * skel.get_bone_global_pose(lfoot).origin).y,
		(skel.global_transform * skel.get_bone_global_pose(rfoot).origin).y
	)

	anim_tree.set("parameters/Locomocion/transition_request", "caminar")
	for i in range(10):
		anim_tree.advance(0.05)

	var walk_y: float = minf(
		(skel.global_transform * skel.get_bone_global_pose(lfoot).origin).y,
		(skel.global_transform * skel.get_bone_global_pose(rfoot).origin).y
	)

	# Assert
	var diff: float = absf(walk_y - idle_y)
	assert_lt(diff, 0.02, "La altura de los pies entre idle y caminar en la animacion no debe diferir sustancialmente")
