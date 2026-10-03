extends "res://addons/gut/test.gd"

## Tests unitarios para la capa de partículas ChispasPlane (chispas y ascuas incandescentes).
## Valida la instanciación, selectores de velocidad y brillo, presets de color,
## capa visual y comportamiento ante valores límite.

const SCRIPT_CHISPAS: Script = preload("res://Entities/Ambiente_Chispas/ChispasPlane.gd")
const MARGEN_FLOAT: float = 0.001


# ═══════════════════════════════════════════════════════════════════════════════
# TESTS DE INSTANCIACIÓN Y VALORES POR DEFECTO
# ═══════════════════════════════════════════════════════════════════════════════

func test_instanciacion_y_valores_por_defecto() -> void:
	# Arrange & Act
	var chispas = SCRIPT_CHISPAS.new()
	add_child_autofree(chispas)

	# Assert
	assert_not_null(chispas, "El nodo ChispasPlane debe instanciarse")
	assert_almost_eq(chispas.velocidad, 1.0, MARGEN_FLOAT, "Velocidad por defecto debe ser 1.0")
	assert_almost_eq(chispas.brillo, 3.5, MARGEN_FLOAT, "Brillo por defecto debe ser 3.5")
	assert_eq(chispas.preset_velocidad, SCRIPT_CHISPAS.VelocidadPreset.MEDIA)
	assert_eq(chispas.preset_brillo, SCRIPT_CHISPAS.BrilloPreset.INTENSO)
	assert_eq(chispas.preset_color, SCRIPT_CHISPAS.ColorPreset.FUEGO_NARANJA)
	assert_eq(chispas.capa_visual, 2, "Por defecto capa visual 2 (Fondo DOF del tutorial)")
	assert_eq(chispas.layers, 2, "layers del GPUParticles3D debe sincronizarse con capa_visual")
	assert_eq(chispas.amount, 120, "Cantidad por defecto de 120 chispas")
	assert_not_null(chispas.process_material, "Debe tener un ParticleProcessMaterial asignado")
	assert_not_null(chispas.draw_pass_1, "Debe tener un QuadMesh asignado en draw_pass_1")


func test_validacion_textura_y_material_alpha() -> void:
	# Arrange & Act
	var mat = SCRIPT_CHISPAS.MATERIAL_BASE_DEFECTO as StandardMaterial3D
	assert_not_null(mat, "El material base debe existir y ser StandardMaterial3D")
	var tex = mat.albedo_texture as Texture2D
	assert_not_null(tex, "El material debe tener albedo_texture asignada")

	var img: Image = tex.get_image()
	assert_not_null(img, "La imagen de textura debe ser valida")

	# Assert de compatibilidad con SubViewport transparente y ausencia de fondos negros:
	# 1. El material debe usar transparencia Alpha y Blend Mode Normal (Mix = 0)
	assert_eq(mat.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA, "Debe tener transparencia ALPHA")
	assert_eq(mat.blend_mode, BaseMaterial3D.BLEND_MODE_MIX, "Debe ser BLEND_MODE_MIX para no generar artefactos negros en SubViewport")
	assert_eq(mat.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "Debe ser UNSHADED para brillar incandescentemente")
	assert_true(mat.vertex_color_use_as_albedo, "Debe usar el vertex color para tintar con el gradiente de fuego")

	# 2. La textura debe ser RGBA8 con esquinas transparentes (alpha = 0) y centro solido (alpha > 0.8)
	assert_eq(img.get_format(), Image.FORMAT_RGBA8, "La textura debe tener canal alfa nativo RGBA8")
	var pixel_esquina: Color = img.get_pixel(0, 0)
	var pixel_centro: Color = img.get_pixel(img.get_width() / 2, img.get_height() / 2)
	assert_almost_eq(pixel_esquina.a, 0.0, MARGEN_FLOAT, "Las esquinas deben ser 100% transparentes")
	assert_true(pixel_centro.a >= 0.8, "El centro de la chispa debe tener alta opacidad")
	# El RGB de la textura debe ser blanco puro para modular con el color de fuego sin oscurecer
	assert_almost_eq(pixel_centro.r, 1.0, MARGEN_FLOAT, "El color base de la textura debe ser blanco para modulacion")
	assert_almost_eq(pixel_centro.g, 1.0, MARGEN_FLOAT, "El color base de la textura debe ser blanco para modulacion")
	assert_almost_eq(pixel_centro.b, 1.0, MARGEN_FLOAT, "El color base de la textura debe ser blanco para modulacion")


# ═══════════════════════════════════════════════════════════════════════════════
# TESTS DEL SELECTOR DE VELOCIDAD
# ═══════════════════════════════════════════════════════════════════════════════

func test_selector_velocidad_escala_gravedad_y_velocidad_inicial() -> void:
	# Arrange
	var chispas = SCRIPT_CHISPAS.new()
	add_child_autofree(chispas)

	# Act 1: Velocidad normal 1.0
	chispas.velocidad = 1.0
	var mat_proc = chispas.process_material as ParticleProcessMaterial
	var grav_1: float = mat_proc.gravity.y
	var vel_1: float = mat_proc.initial_velocity_max

	# Act 2: Doble de velocidad (2.0)
	chispas.velocidad = 2.0
	var grav_2: float = mat_proc.gravity.y
	var vel_2: float = mat_proc.initial_velocity_max

	# Assert: gravedad (hacia abajo, más negativa) y velocidad inicial deben duplicarse
	assert_almost_eq(grav_2, grav_1 * 2.0, MARGEN_FLOAT, "La gravedad debe escalar con la velocidad")
	assert_almost_eq(vel_2, vel_1 * 2.0, MARGEN_FLOAT, "La velocidad inicial debe escalar con la velocidad")


func test_presets_de_velocidad() -> void:
	# Arrange
	var chispas = SCRIPT_CHISPAS.new()
	add_child_autofree(chispas)

	# Act & Assert - LENTA_FLOTANTE
	chispas.preset_velocidad = SCRIPT_CHISPAS.VelocidadPreset.LENTA_FLOTANTE
	assert_almost_eq(chispas.velocidad, 0.5, MARGEN_FLOAT, "LENTA_FLOTANTE debe ser 0.5")

	# Act & Assert - RAPIDA
	chispas.preset_velocidad = SCRIPT_CHISPAS.VelocidadPreset.RAPIDA
	assert_almost_eq(chispas.velocidad, 1.8, MARGEN_FLOAT, "RAPIDA debe ser 1.8")

	# Act & Assert - TORMENTA_ASCUAS
	chispas.preset_velocidad = SCRIPT_CHISPAS.VelocidadPreset.TORMENTA_ASCUAS
	assert_almost_eq(chispas.velocidad, 2.8, MARGEN_FLOAT, "TORMENTA_ASCUAS debe ser 2.8")

	# Act & Assert - PERSONALIZADA
	chispas.establecer_velocidad(1.4)
	assert_eq(chispas.preset_velocidad, SCRIPT_CHISPAS.VelocidadPreset.PERSONALIZADA)
	assert_almost_eq(chispas.velocidad, 1.4, MARGEN_FLOAT)


# ═══════════════════════════════════════════════════════════════════════════════
# TESTS DEL SELECTOR DE BRILLO
# ═══════════════════════════════════════════════════════════════════════════════

func test_selector_brillo_afecta_gradiente_hdr() -> void:
	# Arrange
	var chispas = SCRIPT_CHISPAS.new()
	add_child_autofree(chispas)

	# Act 1: Brillo tenue (1.0)
	chispas.brillo = 1.0
	var mat_proc = chispas.process_material as ParticleProcessMaterial
	var grad_tex = mat_proc.color_ramp as GradientTexture1D
	var col_1: Color = grad_tex.gradient.colors[1]

	# Act 2: Brillo intenso (4.0)
	chispas.brillo = 4.0
	mat_proc = chispas.process_material as ParticleProcessMaterial
	grad_tex = mat_proc.color_ramp as GradientTexture1D
	var col_2: Color = grad_tex.gradient.colors[1]

	# Assert: El valor RGB del punto más brillante debe ser proporcionalmente superior
	assert_true(col_2.r > col_1.r * 2.0, "El canal R debe ser mucho más intenso con brillo HDR alto")


func test_presets_de_brillo() -> void:
	# Arrange
	var chispas = SCRIPT_CHISPAS.new()
	add_child_autofree(chispas)

	# Act & Assert - TENUE
	chispas.preset_brillo = SCRIPT_CHISPAS.BrilloPreset.TENUE
	assert_almost_eq(chispas.brillo, 1.2, MARGEN_FLOAT)

	# Act & Assert - MEDIO
	chispas.preset_brillo = SCRIPT_CHISPAS.BrilloPreset.MEDIO
	assert_almost_eq(chispas.brillo, 2.5, MARGEN_FLOAT)

	# Act & Assert - INCANDESCENTE_HDR
	chispas.preset_brillo = SCRIPT_CHISPAS.BrilloPreset.INCANDESCENTE_HDR
	assert_almost_eq(chispas.brillo, 7.0, MARGEN_FLOAT)

	# Act & Assert - PERSONALIZADO
	chispas.establecer_brillo(5.5)
	assert_eq(chispas.preset_brillo, SCRIPT_CHISPAS.BrilloPreset.PERSONALIZADO)
	assert_almost_eq(chispas.brillo, 5.5, MARGEN_FLOAT)


# ═══════════════════════════════════════════════════════════════════════════════
# TESTS DE PRESETS DE COLOR Y CAPA VISUAL
# ═══════════════════════════════════════════════════════════════════════════════

func test_presets_de_color() -> void:
	# Arrange
	var chispas = SCRIPT_CHISPAS.new()
	add_child_autofree(chispas)

	# Act & Assert - ASCUAS_DORADAS
	chispas.preset_color = SCRIPT_CHISPAS.ColorPreset.ASCUAS_DORADAS
	assert_almost_eq(chispas.color_base.g, 0.82, MARGEN_FLOAT)

	# Act & Assert - BRASAS_ROJAS
	chispas.preset_color = SCRIPT_CHISPAS.ColorPreset.BRASAS_ROJAS
	assert_almost_eq(chispas.color_base.r, 1.0, MARGEN_FLOAT)
	assert_almost_eq(chispas.color_base.g, 0.25, MARGEN_FLOAT)

	# Act & Assert - FUEGO_AZUL
	chispas.preset_color = SCRIPT_CHISPAS.ColorPreset.FUEGO_AZUL
	assert_almost_eq(chispas.color_base.b, 1.0, MARGEN_FLOAT)

	# Act & Assert - PERSONALIZADO
	var col_custom := Color(0.9, 0.1, 0.8)
	chispas.establecer_color(col_custom)
	assert_eq(chispas.preset_color, SCRIPT_CHISPAS.ColorPreset.PERSONALIZADO)
	assert_eq(chispas.color_base, col_custom)


func test_selector_capa_visual() -> void:
	# Arrange
	var chispas = SCRIPT_CHISPAS.new()
	add_child_autofree(chispas)

	# Act & Assert: Capa 1
	chispas.establecer_capa_visual(1)
	assert_eq(chispas.capa_visual, 1)
	assert_eq(chispas.layers, 1)

	# Act & Assert: Capa 2
	chispas.establecer_capa_visual(2)
	assert_eq(chispas.capa_visual, 2)
	assert_eq(chispas.layers, 2)


# ═══════════════════════════════════════════════════════════════════════════════
# TESTS DE VALORES LÍMITE Y ENTRADAS EXTREMAS
# ═══════════════════════════════════════════════════════════════════════════════

func test_valores_limite_y_entradas_extremas() -> void:
	# Arrange
	var chispas = SCRIPT_CHISPAS.new()
	add_child_autofree(chispas)

	# Act & Assert: Velocidad negativa debe clamplear a mínimo positivo seguro
	chispas.establecer_velocidad(-5.0)
	assert_true(chispas.velocidad >= 0.05, "La velocidad debe mantenerse positiva")

	# Act & Assert: Brillo negativo debe clamplear a mínimo positivo seguro
	chispas.establecer_brillo(-10.0)
	assert_true(chispas.brillo >= 0.1, "El brillo debe mantenerse positivo")

	# Act & Assert: Cambiar cantidad de chispas
	chispas.cantidad_chispas = 250
	assert_eq(chispas.amount, 250)
