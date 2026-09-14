extends GutTest

func test_inspeccionar_protagonista_en_canoa() -> void:
	var packed: PackedScene = load("res://Levels/Rio en canoa con paralax.tscn")
	assert_not_null(packed)
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)
	
	var canoa: Node3D = nivel.find_child("CanoaProtagonistaRio", true, false) as Node3D
	assert_not_null(canoa, "CanoaProtagonistaRio debe existir")
	gut.p("Canoa position: " + str(canoa.position) + " global: " + str(canoa.global_position))
	
	var prota: Node3D = canoa.find_child("Protagonista", true, false) as Node3D
	assert_not_null(prota, "Protagonista debe existir en Canoa")
	gut.p("Prota visible: " + str(prota.visible) + " pos: " + str(prota.position) + " global: " + str(prota.global_position) + " scale: " + str(prota.scale))
	
	var acomp: Node3D = canoa.find_child("Acompanante", true, false) as Node3D
	assert_not_null(acomp, "Acompanante debe existir")
	gut.p("Acompanante visible: " + str(acomp.visible) + " pos: " + str(acomp.position) + " global: " + str(acomp.global_position) + " scale: " + str(acomp.scale))

	# Simular 60 frames de física y proceso

	for i in range(60):
		if nivel.has_method("_process"):
			nivel._process(0.016)
		if canoa.has_method("_process"):
			canoa._process(0.016)
		if prota.has_method("_physics_process"):
			prota._physics_process(0.016)
	
	gut.p("DESPUES DE 60 FRAMES:")
	gut.p("Prota global: " + str(prota.global_position) + " local: " + str(prota.position))
	gut.p("Acompanante global: " + str(acomp.global_position) + " local: " + str(acomp.position))
	gut.p("Canoa global: " + str(canoa.global_position))

	# Assert: Ambas deben tener exactamente la misma escala relativa e igualar el porte visual de Nivel 1
	var prota_escala_mundo: Vector3 = prota.global_transform.basis.get_scale()
	var acomp_escala_mundo: Vector3 = acomp.global_transform.basis.get_scale()
	assert_almost_eq(prota.scale.x, acomp.scale.x, 0.001, "La escala local X de ambas en la canoa debe ser igual")
	assert_almost_eq(prota.scale.y, acomp.scale.y, 0.001, "La escala local Y de ambas en la canoa debe ser igual")
	assert_almost_eq(prota.scale.z, acomp.scale.z, 0.001, "La escala local Z de ambas en la canoa debe ser igual")
	assert_almost_eq(prota_escala_mundo.x, 0.356, 0.01, "Protagonista escala mundo debe ser 0.356 compensada para Nivel 1")
	assert_almost_eq(acomp_escala_mundo.x, 0.356, 0.01, "Acompañante escala mundo debe ser 0.356 compensada para Nivel 1")

	# Assert: La protagonista debe permanecer visible y dentro de la canoa en el río
	assert_true(prota.visible, "La protagonista debe ser visible")
	assert_almost_eq(prota.global_position.z, canoa.global_position.z, 0.2, "La protagonista debe estar en el plano Z de la canoa")
	assert_gt(prota.global_position.y, canoa.global_position.y - 0.2, "La protagonista no debe caer por debajo de la canoa")
	assert_almost_eq(prota.position.z, 0.0, 0.1, "La posición local Z de la protagonista dentro de la canoa debe ser ~0")


func test_disparo_flechas_avanzadas_en_canoa() -> void:
	# Arrange
	var packed: PackedScene = load("res://Levels/Rio en canoa con paralax.tscn")
	assert_not_null(packed)
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)

	var canoa: Node3D = nivel.find_child("CanoaProtagonistaRio", true, false) as Node3D
	assert_not_null(canoa, "Canoa debe existir")
	var camara: Camera3D = nivel.find_child("CamaraPrincipal", true, false) as Camera3D
	assert_not_null(camara, "CamaraPrincipal debe existir")

	# Simular que la canoa ya navegó mucho más allá del límite antiguo (X = 55.0), por ej. X = 80.0
	canoa.global_position.x = 80.0
	if nivel.has_method("_process"):
		nivel._process(0.016)

	var arrow_scene: PackedScene = load("res://Entities/Proyectil_Flecha/Arrow.tscn")
	assert_not_null(arrow_scene, "Arrow.tscn debe cargar")
	var flecha: ArrowProjectile = arrow_scene.instantiate() as ArrowProjectile
	add_child_autofree(flecha)
	flecha.global_position = canoa.global_position + Vector3(0.5, 0.5, 0.0)
	flecha.initialize(Vector3.RIGHT, 25.0)

	# Act: Simular 10 frames de física
	for i in range(10):
		flecha._physics_process(0.016)

	# Assert: La flecha NO debe destruirse en X > 55.0 mientras esté visible en la cámara
	assert_false(flecha.is_queued_for_deletion(), "La flecha no debe ser destruida prematuramente al superar X = 55")
	assert_gt(flecha.global_position.x, 82.0, "La flecha debe avanzar correctamente hacia la derecha")


func test_medir_altura_pixeles_nivel1_vs_rio() -> void:
	# 1. Medir en NIVEL01
	var packed_n1 := load("res://Levels/NIVEL01/NIVEL01.tscn") as PackedScene
	var n1: Node3D = packed_n1.instantiate() as Node3D
	add_child_autofree(n1)
	var cam_n1: Camera3D = n1.find_child("CamaraFrente", true, false) as Camera3D
	if not cam_n1:
		cam_n1 = n1.find_child("PRESPECTIVA", true, false) as Camera3D
	var player_n1: Node3D = n1.find_child("Player", true, false) as Node3D
	var ally_n1: Node3D = n1.find_child("AllyArcher", true, false) as Node3D
	
	var p_feet_n1: Vector2 = cam_n1.unproject_position(player_n1.global_position)
	var p_head_n1: Vector2 = cam_n1.unproject_position(player_n1.global_position + Vector3(0, 1.8, 0))
	var player_h_n1: float = absf(p_feet_n1.y - p_head_n1.y)

	var a_feet_n1: Vector2 = cam_n1.unproject_position(ally_n1.global_position)
	var a_head_n1: Vector2 = cam_n1.unproject_position(ally_n1.global_position + Vector3(0, 1.8, 0))
	var ally_h_n1: float = absf(a_feet_n1.y - a_head_n1.y)

	gut.p("=== NIVEL 01 ===")
	gut.p("Player global_pos: " + str(player_n1.global_position) + " scale: " + str(player_n1.scale) + " screen_h: " + str(player_h_n1))
	gut.p("Ally global_pos: " + str(ally_n1.global_position) + " scale: " + str(ally_n1.scale) + " screen_h: " + str(ally_h_n1))

	# 2. Medir en Rio
	var packed_rio := load("res://Levels/Rio en canoa con paralax.tscn") as PackedScene
	var n_rio: Node3D = packed_rio.instantiate() as Node3D
	add_child_autofree(n_rio)
	var cam_rio: Camera3D = n_rio.find_child("CamaraPrincipal", true, false) as Camera3D
	var canoa: Node3D = n_rio.find_child("CanoaProtagonistaRio", true, false) as Node3D
	var prota_rio: Node3D = canoa.find_child("Protagonista", true, false) as Node3D
	var acomp_rio: Node3D = canoa.find_child("Acompanante", true, false) as Node3D

	var altura_mundo_prota: float = 1.8 * (prota_rio.global_transform.basis.get_scale().y / 0.3)
	var p_feet_rio: Vector2 = cam_rio.unproject_position(prota_rio.global_position)
	var p_head_rio: Vector2 = cam_rio.unproject_position(prota_rio.global_position + Vector3(0, altura_mundo_prota, 0))
	var prota_h_rio: float = absf(p_feet_rio.y - p_head_rio.y)

	var altura_mundo_acomp: float = 1.8 * (acomp_rio.global_transform.basis.get_scale().y / 0.3)
	var a_feet_rio: Vector2 = cam_rio.unproject_position(acomp_rio.global_position)
	var a_head_rio: Vector2 = cam_rio.unproject_position(acomp_rio.global_position + Vector3(0, altura_mundo_acomp, 0))
	var acomp_h_rio: float = absf(a_feet_rio.y - a_head_rio.y)

	gut.p("=== RIO EN CANOA ===")
	gut.p("Canoa global_pos: " + str(canoa.global_position) + " scale: " + str(canoa.scale))
	gut.p("Prota global_pos: " + str(prota_rio.global_position) + " local_scale: " + str(prota_rio.scale) + " screen_h: " + str(prota_h_rio))
	gut.p("Acomp global_pos: " + str(acomp_rio.global_position) + " local_scale: " + str(acomp_rio.scale) + " screen_h: " + str(acomp_h_rio))
	gut.p("Ratio Player N1 / Prota Rio: " + str(player_h_n1 / prota_h_rio if prota_h_rio > 0 else 0.0))

	# Assert: El tamaño en pantalla de la protagonista y acompañante en la canoa debe igualar a Nivel 1 (dentro de un 1.5%)
	assert_almost_eq(prota_h_rio, player_h_n1, 3.5, "La altura en pantalla de la protagonista debe igualar a la de Nivel 1")
	assert_almost_eq(acomp_h_rio, ally_h_n1, 3.5, "La altura en pantalla de la acompañante debe igualar a la de Nivel 1")


