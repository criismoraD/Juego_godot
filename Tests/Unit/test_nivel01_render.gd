extends "res://addons/gut/test.gd"

var nivel01_script = preload("res://Scripts/Levels/NIVEL01.gd")


func test_calcular_tamano_render_aplica_escala() -> void:
	# Arrange
	var nivel = nivel01_script.new()

	# Act
	var tamano_render: Vector2i = nivel._calcular_tamano_render(Vector2(1920, 1080), 0.95)

	# Assert
	assert_eq(tamano_render, Vector2i(1824, 1026), "Debe escalar el subviewport de fondo")

	nivel.free()


func test_calcular_tamano_render_clampea_escala_baja() -> void:
	# Arrange
	var nivel = nivel01_script.new()

	# Act
	var tamano_render: Vector2i = nivel._calcular_tamano_render(Vector2(1920, 1080), 0.1)

	# Assert
	assert_eq(tamano_render, Vector2i(960, 540), "La escala minima debe ser 50%")

	nivel.free()


func test_configurar_texture_rect_fullscreen_usa_estirado_sin_recorte() -> void:
	# Arrange
	var nivel = nivel01_script.new()
	var rect := TextureRect.new()

	# Act
	nivel._configurar_texture_rect_fullscreen(rect)

	# Assert
	assert_eq(rect.expand_mode, TextureRect.EXPAND_IGNORE_SIZE)
	assert_eq(rect.stretch_mode, TextureRect.STRETCH_SCALE)
	assert_almost_eq(rect.anchor_left, 0.0, 0.001)
	assert_almost_eq(rect.anchor_top, 0.0, 0.001)
	assert_almost_eq(rect.anchor_right, 1.0, 0.001)
	assert_almost_eq(rect.anchor_bottom, 1.0, 0.001)

	rect.free()
	nivel.free()
