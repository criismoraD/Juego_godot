extends "res://addons/gut/test.gd"

const ESCENA_TUTORIAL: String = "res://Levels/NIVEL_TUTORIAL/NIVEL_TUTORIAL.tscn"


func test_tutorial_contiene_puente_tutorial():
	# Arrange & Act
	var escena := load(ESCENA_TUTORIAL) as PackedScene
	assert_not_null(escena, "NIVEL_TUTORIAL.tscn debe cargar sin errores")
	var nivel := escena.instantiate()
	assert_not_null(nivel, "El nivel tutorial debe instanciarse")
	add_child_autofree(nivel)

	# Assert
	var puente := nivel.find_child("PuenteTutorial", true, false)
	assert_not_null(puente, "Debe existir el nodo PuenteTutorial (modelo TEST_/Puente)")
	assert_not_null(puente.get_node_or_null("Model"), "PuenteTutorial debe tener hijo Model con el GLB")
	assert_not_null(puente.get_node_or_null("Model6"), "PuenteTutorial debe tener el tramo Model6")

	# Assert: Model6 queda en la capa 2 (fondo con DOF) vía capa_por_modelo
	var capas: Dictionary = puente.get("capa_por_modelo") as Dictionary
	assert_not_null(capas, "PuenteTutorial debe exponer capa_por_modelo")
	assert_true(capas.has("Model6"), "capa_por_modelo debe incluir Model6")
	assert_eq(int(capas["Model6"]), 2, "Model6 debe ir en la capa 2")

	# Assert: el puente genera colisión de tablero transitable en capa 1 (jugador)
	var piso := puente.find_child("PisoPuente", true, false)
	assert_not_null(piso, "PuenteTutorial debe generar el StaticBody PisoPuente en _ready")
	assert_true(piso is StaticBody3D, "PisoPuente debe ser StaticBody3D")
	assert_eq((piso as StaticBody3D).collision_layer & 1, 1, "PisoPuente debe colisionar en capa 1 (jugador)")
	assert_not_null((piso as StaticBody3D).get_node_or_null("CollisionShape3D"), "PisoPuente debe tener CollisionShape3D")


func test_tutorial_contiene_arbalesta_con_textura():
	# Arrange & Act
	var escena := load(ESCENA_TUTORIAL) as PackedScene
	assert_not_null(escena, "NIVEL_TUTORIAL.tscn debe cargar sin errores")
	var nivel := escena.instantiate()
	add_child_autofree(nivel)

	# Assert
	var arbalesta := nivel.find_child("ArbalestaTutorial", true, false)
	assert_not_null(arbalesta, "Debe existir el nodo ArbalestaTutorial (modelo Levels/NIVEL_TUTORIAL)")
	assert_not_null(arbalesta.get_node_or_null("Model"), "ArbalestaTutorial debe tener hijo Model con el GLB")
	var mat: Material = arbalesta.get("material_arbalesta") as Material
	assert_not_null(mat, "ArbalestaTutorial debe tener asignado material_arbalesta con su textura")


func test_tutorial_contiene_carreta_con_texturas():
	# Arrange & Act
	var escena := load(ESCENA_TUTORIAL) as PackedScene
	assert_not_null(escena, "NIVEL_TUTORIAL.tscn debe cargar sin errores")
	var nivel := escena.instantiate()
	add_child_autofree(nivel)

	# Assert
	var carreta := nivel.find_child("CarretaTutorial", true, false)
	assert_not_null(carreta, "Debe existir el nodo CarretaTutorial (modelo Levels/NIVEL_TUTORIAL)")
	assert_not_null(carreta.get_node_or_null("Model"), "CarretaTutorial debe tener hijo Model con el GLB")
	var mat: Material = carreta.get("material_carreta") as Material
	assert_not_null(mat, "CarretaTutorial debe tener asignado material_carreta con sus texturas")


func test_tutorial_camara_seguidora_configurada():
	# Arrange & Act
	var escena := load(ESCENA_TUTORIAL) as PackedScene
	var nivel := escena.instantiate()
	add_child_autofree(nivel)

	# Assert: nodos de cámara necesarios para el seguimiento estilo pueblo
	assert_not_null(nivel.find_child("CamaraFrente", true, false), "Debe existir CamaraFrente")
	assert_not_null(nivel.find_child("CamaraMedio", true, false), "Debe existir CamaraMedio")
	assert_not_null(nivel.find_child("CamaraFondoDOF", true, false), "Debe existir CamaraFondoDOF")

	# Assert: el script expone el seguimiento activo y límites coherentes
	assert_true(bool(nivel.get("seguimiento_camara_activo")), "seguimiento_camara_activo debe estar activo por defecto")
	var min_x: float = float(nivel.get("limite_camara_min_x"))
	var max_x: float = float(nivel.get("limite_camara_max_x"))
	assert_lt(min_x, max_x, "El límite mínimo debe ser menor que el máximo")
	assert_lte(min_x, -3.0, "El mínimo debe hacer partir la cámara en -3.0 o más a la derecha")
	assert_gte(max_x, 12.0, "El máximo debe permitir avanzar más lejos (recorrido extendido)")
	assert_almost_eq(min_x, -3.0, 0.001, "El plano inicial debe ser exactamente -3.0")
	assert_true(nivel.has_method("_actualizar_camara_seguidora"), "Debe existir _actualizar_camara_seguidora(delta)")
	assert_true(nivel.has_method("_fijar_plano_inicial_camara"), "Debe existir _fijar_plano_inicial_camara() para el primer frame")


func test_tutorial_sin_mascaras_de_recorte_en_camara():
	# Arrange & Act
	var escena := load(ESCENA_TUTORIAL) as PackedScene
	var nivel := escena.instantiate()
	add_child_autofree(nivel)

	# Assert: sin overlays de máscara pegados a la vista (pantalla completa)
	assert_null(nivel.find_child("SombraFalsaRect", true, false), "SombraFalsaRect debe estar eliminada del tutorial")
	assert_null(nivel.find_child("MascaraOleada6", true, false), "MascaraOleada6 no debe existir en el tutorial")
	assert_null(nivel.find_child("CAPA001", true, false), "CAPA001 (filtro/máscara pegado a la cámara de Nivel 1) debe eliminarse del tutorial")
	assert_null(nivel.find_child("CAPA002", true, false), "CAPA002 debe eliminarse del tutorial")
	assert_false(nivel.has_method("_actualizar_mascara_oleada6"), "El subsistema de máscara de oleada 6 debe estar eliminado")
	assert_false(nivel.has_method("_mostrar_mascara_oleada6"), "No debe existir _mostrar_mascara_oleada6")
	assert_false(nivel.has_method("_ocultar_mascara_oleada6"), "No debe existir _ocultar_mascara_oleada6")
