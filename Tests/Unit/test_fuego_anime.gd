extends "res://addons/gut/test.gd"

## Tests del efecto Fuego Anime: escena configurable con shader spatial,
## texturas procedurales y luz cálida.

const ESCENA_FUEGO: PackedScene = preload("res://VFX/Scenes/FuegoAnime.tscn")


func _crear_fuego() -> FuegoAnime:
	var fuego: FuegoAnime = ESCENA_FUEGO.instantiate() as FuegoAnime
	add_child_autofree(fuego)
	return fuego


func test_instancia_con_material_y_texturas() -> void:
	# Arrange & Act
	var fuego: FuegoAnime = _crear_fuego()

	# Assert
	var mat := fuego.material_override as ShaderMaterial
	assert_not_null(mat, "Material del shader creado")
	assert_eq(fuego.velocidad, 0.5, "Velocidad por defecto")
	assert_eq(mat.get_shader_parameter("velocidad"), 0.5, "Parámetro propagado")
	assert_not_null(mat.get_shader_parameter("draw_tex"), "Silueta procedural")
	assert_not_null(mat.get_shader_parameter("noise_tex"), "Ruido procedural")
	assert_not_null(mat.get_shader_parameter("normal_tex"), "Normal procedural")
	assert_not_null(mat.get_shader_parameter("mask_tex"), "Máscara procedural")
	assert_not_null(fuego.obtener_luz(), "Luz cálida presente")


func test_exports_color_tamano_luz() -> void:
	# Arrange
	var fuego: FuegoAnime = _crear_fuego()
	var mat := fuego.material_override as ShaderMaterial

	# Act
	fuego.respiracion_llama = false
	fuego.color_exterior_a = Color.BLUE
	fuego.velocidad = 1.5
	fuego.escala = 2.0
	fuego.opacidad = 0.5
	fuego.color_luz = Color.GREEN
	fuego.radio_luz = 6.0

	# Assert
	assert_eq(mat.get_shader_parameter("color_exterior_a"), Color.BLUE, "Color exterior")
	assert_eq(mat.get_shader_parameter("velocidad"), 1.5, "Velocidad")
	assert_eq(mat.get_shader_parameter("opacidad"), 0.5, "Opacidad")
	assert_eq(fuego.scale, Vector3(2.0, 2.0, 2.0), "Tamaño aplicado")
	assert_eq(fuego.obtener_luz().light_color, Color.GREEN, "Color de luz")
	assert_eq(fuego.obtener_luz().omni_range, 6.0, "Radio de luz")


func test_apagado_oculta_llama_y_luz() -> void:
	# Arrange
	var fuego: FuegoAnime = _crear_fuego()

	# Act
	fuego.set_fuego_activo(false)

	# Assert
	assert_false(fuego.visible, "Llama oculta")
	assert_false(fuego.obtener_luz().visible, "Luz apagada")
