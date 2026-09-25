extends "res://addons/gut/test.gd"

## La bailarina decorativa del fondo debe animarse sola (caso: "Baile").
## Imprime la lista real de animaciones del GLB importado para diagnosticar
## diferencias de nombre ("Baile" vs "Armature|Baile").

const ESCENA_POSANDO_PATH: String = "res://Levels/Rio_En_Canoa_Con_Parallax/AzulinaPosando.tscn"


func _crear_bailarina(pose: String) -> AzulinaPosando:
	var packed := load(ESCENA_POSANDO_PATH) as PackedScene
	assert_not_null(packed, "AzulinaPosando.tscn debe cargar")
	var bailarina := packed.instantiate() as AzulinaPosando
	assert_not_null(bailarina, "Debe instanciarse la bailarina")
	bailarina.set("animacion_pose", pose)
	add_child_autofree(bailarina)
	return bailarina


func test_bailarina_baile_se_anima() -> void:
	# Arrange
	var bailarina := _crear_bailarina("Baile")

	# Act: dar frames al arranque (con reintentos incluidos)
	await wait_frames(10)

	# Diagnóstico: lista real tal como la ve el juego
	var player := bailarina.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert_not_null(player, "El modelo trae su AnimationPlayer")
	print("[TEST AzulinaPosando] animaciones: " + str(player.get_animation_list()))
	print("[TEST AzulinaPosando] actual='" + player.current_animation + "' sonando=" + str(player.is_playing()) + " pos=" + str(player.current_animation_position))

	# Assert: bailando, no congelada en la pose inicial
	assert_true(player.is_playing(), "La bailarina debe estar sonando, no congelada")
	var pos_inicial: float = player.current_animation_position
	await wait_frames(10)
	assert_gt(player.current_animation_position, pos_inicial, "La animación debe avanzar entre frames")


func test_bailarina_pose_por_defecto_se_anima() -> void:
	# Arrange & Act
	var bailarina := _crear_bailarina("Pose sexy")
	await wait_frames(10)

	# Assert
	var player := bailarina.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert_not_null(player, "El modelo trae su AnimationPlayer")
	assert_true(player.is_playing(), "La pose decorativa debe sonar en loop")


func test_bailarina_sin_outline() -> void:
	# Arrange & Act
	var bailarina := _crear_bailarina("Baile")
	await wait_frames(5)

	# Assert
	var mat: Material = bailarina._obtener_material_sin_outline()
	assert_not_null(mat, "Debe tener un material asignado")
	assert_null(mat.next_pass, "El material no debe tener next_pass (sin linea de contorno/outline)")

	for m in bailarina.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		assert_false(mi.is_in_group("outline_meshes"), "No debe pertenecer al grupo outline_meshes")
		if mi.material_override != null:
			assert_null(mi.material_override.next_pass, "El material_override no debe tener outline en next_pass")


func test_baile_loop_mode_linear_para_bailes() -> void:
	# Arrange & Act
	var bailarina := _crear_bailarina("Baile")
	await wait_frames(10)

	# Assert
	var player := bailarina.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert_not_null(player, "Debe tener AnimationPlayer")
	assert_true(player.has_animation(bailarina._nombre_loop), "Debe tener la animacion de loop creada")
	var anim := player.get_animation(bailarina._nombre_loop)
	assert_not_null(anim, "Debe existir la animacion de loop")
	assert_eq(anim.loop_mode, Animation.LOOP_LINEAR, "Las animaciones de baile deben usar LOOP_LINEAR para un bucle continuo sin congelarse")

