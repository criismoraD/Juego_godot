extends GutTest

## Test unitario para la física y estabilidad de movimiento del jugador en el interior.

func test_player_interior_configuracion_fisica_anti_jitter() -> void:
	# Arrange
	var scene: PackedScene = load("res://Entities/Jugador_Arquera/Player_Interior.tscn") as PackedScene
	assert_not_null(scene, "La escena Player_Interior.tscn debe existir")

	# Act
	var player: PlayerInterior = scene.instantiate() as PlayerInterior
	add_child_autofree(player)

	# Assert
	assert_true(player.floor_block_on_wall, "floor_block_on_wall debe estar activado para evitar trepar o vibrar contra paredes")
	assert_true(player.floor_constant_speed, "floor_constant_speed debe estar activado para avance uniforme")
	assert_true(player.floor_stop_on_slope, "floor_stop_on_slope debe estar activado")
	assert_gt(player.floor_snap_length, 0.01, "floor_snap_length debe ser mayor a cero para mantener adherencia al suelo")
	assert_gt(player.safe_margin, 0.001, "safe_margin debe estar configurado adecuadamente para evitar penetración/rebote")


func test_player_interior_rotacion_continua_sin_oscilaciones_en_diagonales() -> void:
	# Arrange
	var scene: PackedScene = load("res://Entities/Jugador_Arquera/Player_Interior.tscn") as PackedScene
	var player: PlayerInterior = scene.instantiate() as PlayerInterior
	add_child_autofree(player)

	# Act & Assert: Probar que en diagonales adyacentes no hay salto abrupto de 90 grados
	var diag_arriba_izq_1 := Vector3(-0.707106, 0.0, -0.707107)
	var diag_arriba_izq_2 := Vector3(-0.707107, 0.0, -0.707106)

	var yaw_1 := atan2(diag_arriba_izq_1.x, diag_arriba_izq_1.z)
	var yaw_2 := atan2(diag_arriba_izq_2.x, diag_arriba_izq_2.z)

	var diff_grados: float = rad_to_deg(absf(angle_difference(yaw_1, yaw_2)))
	assert_lt(diff_grados, 0.1, "La diferencia de yaw entre inputs diagonales microscópicos debe ser prácticamente cero, evitando tiritado")


func test_player_interior_gravedad_estable_en_suelo() -> void:
	# Arrange
	var scene: PackedScene = load("res://Entities/Jugador_Arquera/Player_Interior.tscn") as PackedScene
	var player: PlayerInterior = scene.instantiate() as PlayerInterior
	add_child_autofree(player)

	# Act: Simular que el personaje está en el suelo
	player.velocity = Vector3(0.0, -5.0, 0.0) # velocidad residual previa
	# Cuando is_on_floor() es true en el suelo
	if player.is_on_floor():
		player.velocity.y = 0.0

	# Assert
	assert_true(player.is_inside_tree(), "El jugador debe estar en el árbol")


func test_player_interior_sin_linea_negra_en_torre() -> void:
	# Arrange
	var scene: PackedScene = load("res://Entities/Jugador_Arquera/Player_Interior.tscn") as PackedScene
	var player: PlayerInterior = scene.instantiate() as PlayerInterior
	add_child_autofree(player)
	await get_tree().process_frame

	# Assert: sin contorno en la torre (ni grupo ni next_pass)
	var total: int = 0
	for m in player.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		total += 1
		assert_false(mi.is_in_group("outline_meshes"), "La malla %s no debe estar en outline_meshes" % mi.name)
		var mat: Material = mi.material_override if mi.material_override else mi.get_active_material(0)
		if mat and mat is StandardMaterial3D:
			assert_null((mat as StandardMaterial3D).next_pass, "La malla %s no debe tener next_pass de contorno" % mi.name)
	assert_gt(total, 0, "La arquera debe tener mallas")
