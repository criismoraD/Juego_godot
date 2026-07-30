extends "res://addons/gut/test.gd"

var nivel01_scene_path: String = "res://Levels/NIVEL01/NIVEL01.tscn"


func test_escudos_oleada_2_ocultos_inicialmente() -> void:
	# Arrange
	var nivel = load(nivel01_scene_path).instantiate()
	add_child_autofree(nivel)

	# Assert
	assert_not_null(nivel.escudo_enemigo2, "NIVEL_2_Escudo_enemigo2 debe existir en la escena")
	assert_not_null(nivel.escudo_enemigo3, "NIVEL_2_Escudo_enemigo3 debe existir en la escena")

	if nivel.escudo_enemigo2:
		assert_false(nivel.escudo_enemigo2.visible, "NIVEL_2_Escudo_enemigo2 debe estar oculto al inicio")
	if nivel.escudo_enemigo3:
		assert_false(nivel.escudo_enemigo3.visible, "NIVEL_2_Escudo_enemigo3 debe estar oculto al inicio")


func test_escudos_oleada_2_visibles_unicamente_en_oleada_2() -> void:
	# Arrange
	var nivel = load(nivel01_scene_path).instantiate()
	add_child_autofree(nivel)

	# Act & Assert - Oleada 2 (Visibles)
	nivel._configurar_oleada_combate(25, 2)
	if nivel.escudo_enemigo2:
		assert_true(nivel.escudo_enemigo2.visible, "NIVEL_2_Escudo_enemigo2 debe ser visible en la oleada 2")
	if nivel.escudo_enemigo3:
		assert_true(nivel.escudo_enemigo3.visible, "NIVEL_2_Escudo_enemigo3 debe ser visible en la oleada 2")

	# Act & Assert - Oleada 3 (Ocultos)
	nivel._configurar_oleada_combate(25, 3)
	if nivel.escudo_enemigo2:
		assert_false(nivel.escudo_enemigo2.visible, "NIVEL_2_Escudo_enemigo2 debe estar oculto en la oleada 3")
	if nivel.escudo_enemigo3:
		assert_false(nivel.escudo_enemigo3.visible, "NIVEL_2_Escudo_enemigo3 debe estar oculto en la oleada 3")

	# Act & Assert - Oleada 4 (Ocultos)
	nivel._configurar_oleada_combate(27, 4)
	if nivel.escudo_enemigo2:
		assert_false(nivel.escudo_enemigo2.visible, "NIVEL_2_Escudo_enemigo2 debe estar oculto en la oleada 4")
	if nivel.escudo_enemigo3:
		assert_false(nivel.escudo_enemigo3.visible, "NIVEL_2_Escudo_enemigo3 debe estar oculto en la oleada 4")
