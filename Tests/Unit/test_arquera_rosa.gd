extends "res://addons/gut/test.gd"

var ArqueraRosaScript = load("res://Entities/Enemigo_Arquera_Rosa/ArqueraRosa.gd")
var ArrowScript = load("res://System/Core/Arrow.gd")
var RosaArrowScript = load("res://Entities/Proyectil_Flecha_Arquera_Rosa/RosaArrow.gd")

class MockFlechaNormal extends "res://System/Core/Arrow.gd":
	func _init():
		es_explosiva = false

class MockFlechaExplosiva extends "res://System/Core/Arrow.gd":
	func _init():
		es_explosiva = true


func test_arquera_rosa_initialization():
	# Arrange & Act
	var arquera = ArqueraRosaScript.new()
	add_child_autofree(arquera)

	# Assert
	assert_not_null(arquera, "ArqueraRosa debe instanciarse correctamente")
	assert_eq(arquera.aura_vida, 4, "El aura rosada debe iniciar con 4 de vida")
	assert_eq(arquera.cantidad_flechas_rafaga, 5, "Debe disparar ráfagas de 5 flechas múltiples")
	assert_eq(arquera.drop_chance_flecha_multiple, 1.0, "El drop de flecha múltiple debe ser del 100%")
	assert_gte(arquera.tiempo_tensa_arco, 3.0, "Debe completar la animación de tensado antes de soltar la ráfaga")


func test_aura_repels_normal_arrows_up_to_4_hits():
	# Arrange
	var arquera = ArqueraRosaScript.new()
	add_child_autofree(arquera)
	var flecha = MockFlechaNormal.new()
	add_child_autofree(flecha)

	# Act & Assert: Impacto 1
	var repelido_1 = arquera.manejar_impacto_aura(flecha)
	assert_true(repelido_1, "Impacto 1: la flecha normal debe ser repelida")
	assert_eq(arquera.aura_vida, 3, "El aura debe tener 3 de vida restante")

	# Act & Assert: Impacto 2
	var repelido_2 = arquera.manejar_impacto_aura(flecha)
	assert_true(repelido_2, "Impacto 2: la flecha normal debe ser repelida")
	assert_eq(arquera.aura_vida, 2, "El aura debe tener 2 de vida restante")

	# Act & Assert: Impacto 3
	var repelido_3 = arquera.manejar_impacto_aura(flecha)
	assert_true(repelido_3, "Impacto 3: la flecha normal debe ser repelida")
	assert_eq(arquera.aura_vida, 1, "El aura debe tener 1 de vida restante")

	# Act & Assert: Impacto 4 (quiebre del aura)
	var repelido_4 = arquera.manejar_impacto_aura(flecha)
	assert_true(repelido_4, "Impacto 4: absorbe el último impacto y se rompe")
	assert_eq(arquera.aura_vida, 0, "El aura debe quedar en 0")

	# Act & Assert: Impacto 5 (sin aura activa)
	var repelido_5 = arquera.manejar_impacto_aura(flecha)
	assert_false(repelido_5, "Impacto 5: sin aura activa, el proyectil NO es repelido y daña a la arquera")


func test_aura_penetrated_immediately_by_explosive_arrow():
	# Arrange
	var arquera = ArqueraRosaScript.new()
	add_child_autofree(arquera)
	var flecha_explosiva = MockFlechaExplosiva.new()
	add_child_autofree(flecha_explosiva)

	# Act: Impacto con flecha explosiva
	var repelido = arquera.manejar_impacto_aura(flecha_explosiva)

	# Assert
	assert_false(repelido, "La flecha explosiva no debe ser repelida por el aura")
	assert_eq(arquera.aura_vida, 0, "La flecha explosiva debe quebrar el aura instantáneamente")


func test_drop_power_up_flecha_multiple_al_morir():
	# Arrange
	var arquera = ArqueraRosaScript.new()
	add_child_autofree(arquera)

	# Act
	arquera._dropear_power_up_multiple()

	# Assert: Debe haberse añadido un pickup de flecha múltiple
	var pickups = get_tree().get_nodes_in_group("power_ups_flecha_multiple")
	assert_gt(pickups.size(), 0, "Debe existir al menos un power up de flecha múltiple instanciado")


func test_iniciar_reposicionamiento_activa_caminata():
	# Arrange
	var arquera = ArqueraRosaScript.new()
	arquera.global_position = Vector3(0.0, 0.0, 0.0)
	add_child_autofree(arquera)

	# Act
	arquera._iniciar_reposicionamiento()

	# Assert
	assert_true(arquera.esta_reposicionando, "Debe activar la bandera de reposicionamiento")
	assert_eq(arquera.current_state, arquera.State.WALKING, "Debe pasar al estado WALKING para avanzar")
	assert_gt(arquera.distancia_reposicion_objetivo, 0.0, "La distancia objetivo debe ser mayor a 0")


func test_rosa_arrow_matches_player_model_and_pink_color():
	# Arrange & Act
	var rosa_arrow = RosaArrowScript.new()
	add_child_autofree(rosa_arrow)

	# Assert
	assert_not_null(rosa_arrow, "RosaArrow debe instanciarse")
	assert_eq(rosa_arrow.color_proyectil, Color(1.0, 0.25, 0.75), "El color del proyectil debe ser rosado")
