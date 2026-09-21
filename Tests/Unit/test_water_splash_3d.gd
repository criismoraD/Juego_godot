extends "res://addons/gut/test.gd"

## Tests de WaterSplash3D: adaptación 3D del water_splash de GODOT-VFX-LIBRARY.


func test_spawn_configura_emite_y_libera() -> void:
	# Arrange & Act
	var fx := WaterSplash3D.spawn(Vector3(1.0, 2.0, 3.0), 1.0, self)
	await get_tree().process_frame

	# Assert: parámetros del efecto original y emisión activa
	assert_not_null(fx, "spawn debe instanciar el efecto")
	assert_eq(fx.amount, 24, "24 gotas como el original")
	assert_true(fx.one_shot, "Debe ser one-shot")
	assert_true(fx.emitting, "Debe estar emitiendo")
	assert_eq(fx.global_position, Vector3(1.0, 2.0, 3.0), "En el punto pedido")

	# Act: terminar
	fx._al_terminar()

	# Assert: se libera sola
	assert_true(fx.is_queued_for_deletion(), "Debe liberarse sola al terminar")
