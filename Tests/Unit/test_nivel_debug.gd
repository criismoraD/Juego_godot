extends "res://addons/gut/test.gd"

var debug_level_script = preload("res://Levels/NIVEL_DEBUG/NIVEL_DEBUG.gd")


func test_calcular_tamano_render_debug() -> void:
	# Arrange
	var nivel = debug_level_script.new()

	# Act
	var tamano_render: Vector2i = nivel._calcular_tamano_render(Vector2(1920, 1080), 0.95)

	# Assert
	assert_eq(tamano_render, Vector2i(1824, 1026), "Debe calcular el tamano de render de forma identica")

	nivel.free()
