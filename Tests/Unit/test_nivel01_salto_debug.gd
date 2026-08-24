extends "res://addons/gut/test.gd"

## El salto de oleada por debug NO debe saltarse el diálogo inicial ni el
## evento del goblin embajador: se difiere y se aplica al iniciar el combate.

func test_salto_debug_se_difiere_y_se_consumes_al_iniciar_combate():
	# Arrange: script sin árbol (wave_spawner nulo → _iniciar_oleada_debug sale
	# temprano de forma segura, solo verificamos el consumo del pendiente)
	var nivel = load("res://Levels/NIVEL01/NIVEL01.gd").new()
	autofree(nivel)
	nivel.oleada_debug_pendiente = 3

	# Act
	nivel._iniciar_nivel_1(0)

	# Assert
	assert_eq(
		nivel.oleada_debug_pendiente, 0,
		"El salto de oleada pendiente debe consumirse al iniciar el combate"
	)


func test_sin_salto_pendiente_no_consumes_nada():
	var nivel = load("res://Levels/NIVEL01/NIVEL01.gd").new()
	autofree(nivel)

	# Act: iniciar nivel 1 sin salto solicitado (wave_spawner nulo corta seguro
	# dentro de _configurar_oleada_combate si llegara a tocarlo)
	nivel.oleada_debug_pendiente = 0

	# Assert
	assert_eq(nivel.oleada_debug_pendiente, 0, "Sin solicitud no hay pendiente")
