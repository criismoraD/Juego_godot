extends "res://addons/gut/test.gd"

## Pruebas unitarias para verificar la permanencia y reactivación del contorno
## Toon (TOON_LINEANEGRA) al continuar tras Game Over o recargar escenas.

const RUTA_SHADER_OUTLINE: String = "res://System/Shaders/TOON_LINEANEGRA.gdshader"


func before_each() -> void:
	# Asegurar estado base antes de cada prueba
	ShaderGlobals.asegurar_outline_global(true)
	ShaderGlobals.asegurar_outline_proyectiles(true)
	GameUI.continuar_desde_oleada = 0


func after_each() -> void:
	# Limpieza posterior
	ShaderGlobals.asegurar_outline_global(true)
	ShaderGlobals.asegurar_outline_proyectiles(true)
	GameUI.continuar_desde_oleada = 0


func test_asegurar_outline_global_y_proyectiles_activan_global_parameters() -> void:
	# Arrange
	ShaderGlobals.asegurar_outline_global(false)
	ShaderGlobals.asegurar_outline_proyectiles(false)
	assert_false(
		ShaderGlobals.es_outline_global_activo(),
		"El parámetro global debe estar inicialmente en false para el test"
	)
	assert_false(
		ShaderGlobals.es_outline_proyectiles_activo(),
		"El parámetro de proyectiles debe estar inicialmente en false para el test"
	)

	# Act
	ShaderGlobals.asegurar_outline_global(true)
	ShaderGlobals.asegurar_outline_proyectiles(true)

	# Assert
	assert_true(
		ShaderGlobals.es_outline_global_activo(),
		"ShaderGlobals.asegurar_outline_global(true) debe activar Toon_LineaNegra_Activo"
	)
	assert_true(
		ShaderGlobals.es_outline_proyectiles_activo(),
		"ShaderGlobals.asegurar_outline_proyectiles(true) debe activar Toon_Proyectiles_Enemigos_Activo"
	)


func test_aplicar_toggle_outline_global_fuerza_outline_sin_boton() -> void:
	# Arrange
	var ui: GameUI = GameUI.new()
	add_child_autofree(ui)
	ui.outline_btn = null
	ui.outlines_enabled = true
	ShaderGlobals.asegurar_outline_global(false)

	# Act
	ui._aplicar_toggle_outline_global()

	# Assert
	assert_true(
		ShaderGlobals.es_outline_global_activo(),
		"_aplicar_toggle_outline_global debe activar el shader global incluso si outline_btn es null"
	)


func test_aplicar_toggle_outline_proyectiles_fuerza_proyectiles_sin_boton() -> void:
	# Arrange
	var ui: GameUI = GameUI.new()
	add_child_autofree(ui)
	ui.outline_proy_btn = null
	ui.outline_proy_enabled = true
	ShaderGlobals.asegurar_outline_proyectiles(false)

	# Act
	ui._aplicar_toggle_outline_proyectiles()

	# Assert
	assert_true(
		ShaderGlobals.es_outline_proyectiles_activo(),
		"_aplicar_toggle_outline_proyectiles debe activar shader global de proyectiles incluso si outline_proy_btn es null"
	)


func test_aplicar_shader_outline_en_material_aplica_ancho_y_color() -> void:
	# Arrange
	var ui: GameUI = GameUI.new()
	add_child_autofree(ui)
	var shader: Shader = load(RUTA_SHADER_OUTLINE) as Shader
	assert_not_null(shader, "El shader de contorno debe existir")

	var mat_base: StandardMaterial3D = StandardMaterial3D.new()
	var mat_outline: ShaderMaterial = ShaderMaterial.new()
	mat_outline.shader = shader
	mat_base.next_pass = mat_outline

	# Act - Habilitar
	ui._aplicar_shader_outline_en_material(mat_base, shader, true)

	# Assert
	assert_eq(
		float(mat_outline.get_shader_parameter("outline_width")),
		GameUI.OUTLINE_WIDTH_RUNTIME,
		"outline_width debe ser igual a OUTLINE_WIDTH_RUNTIME (20.0) cuando está habilitado"
	)
	assert_eq(
		mat_outline.get_shader_parameter("outline_color"),
		Color(0, 0, 0, 1),
		"outline_color debe ser negro opaco cuando está habilitado"
	)

	# Act - Deshabilitar
	ui._aplicar_shader_outline_en_material(mat_base, shader, false)

	# Assert
	assert_eq(
		float(mat_outline.get_shader_parameter("outline_width")),
		0.0,
		"outline_width debe ser 0.0 cuando está deshabilitado"
	)


func test_game_over_continue_preserva_outline_global_y_asigna_oleada() -> void:
	# Arrange
	UIGameOver.ultima_oleada_jugada = 5
	ShaderGlobals.asegurar_outline_global(false)
	ShaderGlobals.asegurar_outline_proyectiles(false)

	# Act: Simular lógica de pulsar continuar en UIGameOver
	GameUI.continuar_desde_oleada = UIGameOver.ultima_oleada_jugada
	ShaderGlobals.asegurar_outline_global(true)
	ShaderGlobals.asegurar_outline_proyectiles(true)

	# Assert
	assert_eq(GameUI.continuar_desde_oleada, 5, "GameUI.continuar_desde_oleada debe retener la oleada 5")
	assert_true(
		ShaderGlobals.es_outline_global_activo(),
		"El outline global debe quedar activo tras continuar de Game Over"
	)
	assert_true(
		ShaderGlobals.es_outline_proyectiles_activo(),
		"El outline de proyectiles debe quedar activo tras continuar de Game Over"
	)


func test_refresco_outline_recarga_cache_y_mantiene_global_activo() -> void:
	# Arrange: Simular recarga con CACHE_MODE_REPLACE
	var shader_outline := ResourceLoader.load(
		RUTA_SHADER_OUTLINE, "Shader", ResourceLoader.CACHE_MODE_REPLACE
	)
	assert_not_null(shader_outline, "El shader recargado con CACHE_MODE_REPLACE no debe ser nulo")

	# Act: Aseguramiento post-recarga tal como hacen los niveles
	ShaderGlobals.asegurar_outline_global(true)
	ShaderGlobals.asegurar_outline_proyectiles(true)

	# Assert
	assert_true(
		ShaderGlobals.es_outline_global_activo(),
		"Toon_LineaNegra_Activo debe ser true tras recarga y reaseguramiento"
	)
	assert_true(
		ShaderGlobals.es_outline_proyectiles_activo(),
		"Toon_Proyectiles_Enemigos_Activo debe ser true tras recarga y reaseguramiento"
	)
