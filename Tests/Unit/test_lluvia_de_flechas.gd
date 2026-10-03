extends "res://addons/gut/test.gd"

## Tests unitarios para el efecto decorativo de Lluvia de Flechas (LluviaDeFlechas y FlechaDecorativa).
## Verifica los selectores de frecuencia, color, capa visual y profundidad Z,
## la balística parabólica estilo Goblin Morada y el object pooling.

const SCRIPT_LLUVIA: Script = preload("res://Entities/Ambiente_Lluvia_Flechas/LluviaDeFlechas.gd")
const SCRIPT_FLECHA: Script = preload("res://Entities/Ambiente_Lluvia_Flechas/FlechaDecorativa.gd")
const MARGEN_FLOAT: float = 0.001


# ═══════════════════════════════════════════════════════════════════════════════
# TESTS DE INSTANCIACIÓN Y VALORES POR DEFECTO
# ═══════════════════════════════════════════════════════════════════════════════

func test_instanciacion_y_valores_por_defecto() -> void:
	# Arrange & Act
	var lluvia = SCRIPT_LLUVIA.new()
	lluvia.disparar_al_iniciar = false
	add_child_autofree(lluvia)

	# Assert
	assert_not_null(lluvia, "La lluvia de flechas debe instanciarse")
	assert_eq(lluvia.flechas_por_rafaga, 15, "Debe tener 15 flechas por ráfaga por defecto")
	assert_eq(lluvia.preset_color, SCRIPT_LLUVIA.ColorPreset.GOBLIN_MORADA, "Preset Goblin Morada por defecto")
	assert_almost_eq(lluvia.color_flechas.r, 1.0, MARGEN_FLOAT)
	assert_almost_eq(lluvia.color_flechas.g, 0.38, MARGEN_FLOAT)
	assert_almost_eq(lluvia.color_flechas.b, 0.72, MARGEN_FLOAT)
	assert_eq(lluvia.modo_frecuencia, SCRIPT_LLUVIA.FrecuenciaModo.MEDIA, "Frecuencia MEDIA por defecto")
	assert_almost_eq(lluvia.intervalo_segundos, 3.5, MARGEN_FLOAT)
	assert_eq(lluvia.plano_profundidad, SCRIPT_LLUVIA.PlanoProfundidad.FONDO_MEDIO, "Fondo medio por defecto")
	assert_almost_eq(lluvia.profundidad_z_personalizada, -8.0, MARGEN_FLOAT)
	assert_eq(lluvia.capa_visual_render, 1, "Capa visual 1 por defecto")
	assert_true(lluvia.obtener_tamano_pool() >= 45, "Pool preinstanciado de al menos 45 flechas")


# ═══════════════════════════════════════════════════════════════════════════════
# TESTS DE SELECTORES (FRECUENCIA, COLOR, CAPAS)
# ═══════════════════════════════════════════════════════════════════════════════

func test_selector_frecuencia_presets() -> void:
	# Arrange
	var lluvia = SCRIPT_LLUVIA.new()
	lluvia.disparar_al_iniciar = false
	add_child_autofree(lluvia)

	# Act & Assert - LENTA
	lluvia.modo_frecuencia = SCRIPT_LLUVIA.FrecuenciaModo.LENTA
	assert_almost_eq(lluvia.intervalo_segundos, 6.0, MARGEN_FLOAT, "LENTA debe fijar 6.0s")

	# Act & Assert - RAPIDA
	lluvia.modo_frecuencia = SCRIPT_LLUVIA.FrecuenciaModo.RAPIDA
	assert_almost_eq(lluvia.intervalo_segundos, 1.8, MARGEN_FLOAT, "RAPIDA debe fijar 1.8s")

	# Act & Assert - CONTINUA
	lluvia.modo_frecuencia = SCRIPT_LLUVIA.FrecuenciaModo.CONTINUA
	assert_almost_eq(lluvia.intervalo_segundos, 0.8, MARGEN_FLOAT, "CONTINUA debe fijar 0.8s")

	# Act & Assert - PERSONALIZADA
	lluvia.establecer_frecuencia_segundos(4.2)
	assert_eq(lluvia.modo_frecuencia, SCRIPT_LLUVIA.FrecuenciaModo.PERSONALIZADA)
	assert_almost_eq(lluvia.intervalo_segundos, 4.2, MARGEN_FLOAT)


func test_selector_color_presets() -> void:
	# Arrange
	var lluvia = SCRIPT_LLUVIA.new()
	lluvia.disparar_al_iniciar = false
	add_child_autofree(lluvia)

	# Act & Assert - VERDE VENENO
	lluvia.preset_color = SCRIPT_LLUVIA.ColorPreset.VERDE_VENENO
	assert_almost_eq(lluvia.color_flechas.g, 1.0, MARGEN_FLOAT)

	# Act & Assert - ROJO FUEGO
	lluvia.preset_color = SCRIPT_LLUVIA.ColorPreset.ROJO_FUEGO
	assert_almost_eq(lluvia.color_flechas.r, 1.0, MARGEN_FLOAT)

	# Act & Assert - DORADO IMPERIO
	lluvia.preset_color = SCRIPT_LLUVIA.ColorPreset.DORADO_IMPERIO
	assert_almost_eq(lluvia.color_flechas.r, 1.0, MARGEN_FLOAT)

	# Act & Assert - PERSONALIZADO
	var color_custom := Color(0.25, 0.5, 0.75, 1.0)
	lluvia.establecer_color(color_custom)
	assert_eq(lluvia.preset_color, SCRIPT_LLUVIA.ColorPreset.PERSONALIZADO)
	assert_eq(lluvia.color_flechas, color_custom)


func test_selector_capa_visual_y_profundidad_z() -> void:
	# Arrange
	var lluvia = SCRIPT_LLUVIA.new()
	lluvia.disparar_al_iniciar = false
	add_child_autofree(lluvia)

	# Act & Assert - Capa visual render (ej. Capa 2 para fondo DOF de tutorial)
	lluvia.establecer_capa_visual(2)
	assert_eq(lluvia.capa_visual_render, 2, "Debe actualizar capa_visual_render a 2")

	# Act & Assert - Preset FONDO LEJANO
	lluvia.plano_profundidad = SCRIPT_LLUVIA.PlanoProfundidad.FONDO_LEJANO
	assert_almost_eq(lluvia.profundidad_z_personalizada, -16.0, MARGEN_FLOAT)

	# Act & Assert - Preset FONDO CERCANO
	lluvia.plano_profundidad = SCRIPT_LLUVIA.PlanoProfundidad.FONDO_CERCANO
	assert_almost_eq(lluvia.profundidad_z_personalizada, -3.5, MARGEN_FLOAT)

	# Act & Assert - Profundidad Z personalizada
	lluvia.establecer_profundidad_z(-12.5)
	assert_eq(lluvia.plano_profundidad, SCRIPT_LLUVIA.PlanoProfundidad.PERSONALIZADO)
	assert_almost_eq(lluvia.profundidad_z_personalizada, -12.5, MARGEN_FLOAT)


# ═══════════════════════════════════════════════════════════════════════════════
# TESTS DE RÁFAGA Y OBJECT POOLING
# ═══════════════════════════════════════════════════════════════════════════════

func test_disparar_rafaga_salva_inmediata() -> void:
	# Arrange
	var lluvia = SCRIPT_LLUVIA.new()
	lluvia.disparar_al_iniciar = false
	lluvia.cadencia_entre_flechas = 0.0  # Salva instantánea
	lluvia.flechas_por_rafaga = 15
	lluvia.variacion_flechas_rafaga = 0
	lluvia.reproducir_sfx = false
	add_child_autofree(lluvia)

	watch_signals(lluvia)

	# Act
	lluvia.disparar_rafaga(15)

	# Assert
	assert_signal_emitted(lluvia, "rafaga_iniciada")
	assert_signal_emitted(lluvia, "rafaga_completada")
	assert_eq(lluvia.obtener_flechas_activas(), 15, "Deben haber 15 flechas activas en vuelo")

	# Limpieza / Detener
	lluvia.detener_lluvia()
	assert_eq(lluvia.obtener_flechas_activas(), 0, "Al detener, todas las flechas regresan al pool")


func test_detener_y_reanudar_lluvia() -> void:
	# Arrange
	var lluvia = SCRIPT_LLUVIA.new()
	lluvia.disparar_al_iniciar = false
	lluvia.cadencia_entre_flechas = 0.0
	lluvia.reproducir_sfx = false
	add_child_autofree(lluvia)

	# Act 1: Disparar y luego detener
	lluvia.disparar_rafaga(10)
	assert_eq(lluvia.obtener_flechas_activas(), 10)
	lluvia.detener_lluvia()
	assert_eq(lluvia.obtener_flechas_activas(), 0, "Pool debe recuperar todas las flechas al detener")

	# Act 2: Reanudar
	lluvia.reanudar_lluvia()
	# Simular avance del temporizador de reanudación
	lluvia._process(0.25)
	assert_true(lluvia.obtener_flechas_activas() > 0, "Reanudar debe volver a disparar ráfagas")


# ═══════════════════════════════════════════════════════════════════════════════
# TESTS DE BALÍSTICA PARABÓLICA DE FLECHADECORATIVA
# ═══════════════════════════════════════════════════════════════════════════════

func test_flecha_decorativa_movimiento_parabolico() -> void:
	# Arrange
	var flecha = SCRIPT_FLECHA.new()
	add_child_autofree(flecha)

	var mat := StandardMaterial3D.new()
	var mat_proc := ParticleProcessMaterial.new()
	var mesh := SphereMesh.new()

	var pos_ini := Vector3(10.0, 5.0, -8.0)
	var dir_ini := Vector3(-1.0, 0.5, 0.0)
	var vel := 10.0
	var grav := 1.0

	# Act
	flecha.lanzar(
		pos_ini, dir_ini, vel, grav, 5.0, -10.0, false, 1.0,
		mat, mat_proc, mesh, 1, false
	)

	# Assert inicial
	assert_true(flecha.esta_activa)
	assert_false(flecha.esta_clavada)
	assert_almost_eq(flecha.global_position.x, 10.0, MARGEN_FLOAT)
	assert_almost_eq(flecha.global_position.y, 5.0, MARGEN_FLOAT)
	assert_almost_eq(flecha.global_position.z, -8.0, MARGEN_FLOAT)

	# Simular delta = 0.1s
	flecha._process(0.1)

	# Assert balística:
	# X avanza en la dirección negativa
	assert_true(flecha.global_position.x < 10.0, "La flecha debe avanzar horizontalmente hacia la izquierda")
	# Z se mantiene en el plano de fondo fijo
	assert_almost_eq(flecha.global_position.z, -8.0, MARGEN_FLOAT, "El plano Z debe preservarse fijo")
	# Rotación Z debe calcularse según atan2(dir.y, dir.x)
	var ang_esperado: float = atan2(flecha.direccion.y, flecha.direccion.x)
	assert_almost_eq(flecha.rotation.z, ang_esperado, MARGEN_FLOAT, "Rotación tangente a la parábola")


func test_flecha_decorativa_impacto_suelo_y_clavar() -> void:
	# Arrange
	var flecha = SCRIPT_FLECHA.new()
	add_child_autofree(flecha)

	var mat := StandardMaterial3D.new()
	var mat_proc := ParticleProcessMaterial.new()
	var mesh := SphereMesh.new()

	# Inicia justo encima del suelo configurado en Y = 0.0
	flecha.lanzar(
		Vector3(0.0, 0.05, -5.0), Vector3(-1.0, -1.0, 0.0), 10.0, 1.0,
		5.0, 0.0, true, 1.5,
		mat, mat_proc, mesh, 1, false
	)

	# Act: procesar frame que cruza el suelo (Y pasa a <= 0.0)
	flecha._process(0.1)

	# Assert
	assert_true(flecha.esta_clavada, "La flecha debe clavarse al tocar la cota del suelo")
	assert_true(flecha.esta_activa, "Sigue activa mientras permanece clavada")


func test_entradas_limite_y_valores_extremos() -> void:
	# Arrange
	var lluvia = SCRIPT_LLUVIA.new()
	lluvia.disparar_al_iniciar = false
	lluvia.cadencia_entre_flechas = 0.0
	lluvia.reproducir_sfx = false
	add_child_autofree(lluvia)

	# Act: disparar con cantidad negativa (debe usar fallback seguro > 0)
	lluvia.disparar_rafaga(-5)
	assert_true(lluvia.obtener_flechas_activas() > 0, "Cantidad negativa debe clamplear a flechas_por_rafaga")

	lluvia.detener_lluvia()

	# Frecuencia mínima
	lluvia.establecer_frecuencia_segundos(-10.0)
	assert_true(lluvia.intervalo_segundos >= 0.1, "Intervalo debe mantenerse positivo")
