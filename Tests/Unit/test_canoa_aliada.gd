extends "res://addons/gut/test.gd"
## Tests unitarios de la canoa aliada flotante (Entities/Ambiente_Canoa_Aliada).
## Cubren el "happy path" de la flotación, condiciones de frontera y entradas inválidas.

const SCRIPT_CANOA := preload("res://Entities/Ambiente_Canoa_Aliada/CanoaAliada.gd")
const ESCENA_CANOA := preload("res://Entities/Ambiente_Canoa_Aliada/CanoaAliada.tscn")
const MARGEN_FLOAT: float = 0.0001
const TIEMPO_CUARTO_DE_CICLO: float = 0.25  ## Con frecuencia 1 Hz equivale a sin(PI/2) = 1


func _crear_canoa_determinista() -> CanoaAliada:
	var canoa: CanoaAliada = SCRIPT_CANOA.new()
	canoa.fase_flotacion = 0.0
	canoa.fase_balanceo = 0.0
	canoa.fase_cabeceo = 0.0
	canoa.fase_deriva_x = 0.0
	canoa.fase_deriva_z = 0.0
	canoa.fase_guinada = 0.0
	canoa._inicializar_fases()
	return canoa


# === HAPPY PATH ===
func test_en_tiempo_cero_no_hay_desplazamiento() -> void:
	# Arrange
	var canoa := _crear_canoa_determinista()

	# Act
	var desplazamiento: Vector3 = canoa.calcular_desplazamiento(0.0)

	# Assert
	assert_almost_eq(desplazamiento.x, 0.0, MARGEN_FLOAT, "La deriva en X parte de 0")
	assert_almost_eq(desplazamiento.y, 0.0, MARGEN_FLOAT, "La flotación en Y parte de 0")
	assert_almost_eq(desplazamiento.z, 0.0, MARGEN_FLOAT, "La deriva en Z parte de 0")

	canoa.free()


func test_flotacion_alcanza_amplitud_en_cuarto_de_ciclo() -> void:
	# Arrange
	var canoa := _crear_canoa_determinista()
	canoa.amplitud_flotacion = 0.5
	canoa.frecuencia_flotacion = 1.0

	# Act
	var desplazamiento: Vector3 = canoa.calcular_desplazamiento(TIEMPO_CUARTO_DE_CICLO)

	# Assert
	assert_almost_eq(desplazamiento.y, 0.5, MARGEN_FLOAT, "En 1/4 de ciclo la flotación llega a +amplitud")

	canoa.free()


func test_flotacion_invierte_signo_en_medio_ciclo() -> void:
	# Arrange
	var canoa := _crear_canoa_determinista()
	canoa.amplitud_flotacion = 0.5
	canoa.frecuencia_flotacion = 1.0

	# Act
	var desplazamiento: Vector3 = canoa.calcular_desplazamiento(0.5)

	# Assert
	assert_almost_eq(desplazamiento.y, -0.5, MARGEN_FLOAT, "En 1/2 ciclo la canoa baja a -amplitud")

	canoa.free()


func test_rotacion_aplica_las_tres_amplitudes_sobre_la_base() -> void:
	# Arrange
	var canoa := _crear_canoa_determinista()
	canoa.amplitud_cabeceo = 10.0
	canoa.frecuencia_cabeceo = 1.0
	canoa.amplitud_guinada = 20.0
	canoa.frecuencia_guinada = 1.0
	canoa.amplitud_balanceo = 30.0
	canoa.frecuencia_balanceo = 1.0
	canoa._rotacion_base = Vector3(1.0, 2.0, 3.0)

	# Act
	var rotacion: Vector3 = canoa.calcular_rotacion_grados(TIEMPO_CUARTO_DE_CICLO)

	# Assert
	assert_almost_eq(rotacion.x, 11.0, MARGEN_FLOAT, "El cabeceo suma su amplitud a la base")
	assert_almost_eq(rotacion.y, 22.0, MARGEN_FLOAT, "La guinada suma su amplitud a la base")
	assert_almost_eq(rotacion.z, 33.0, MARGEN_FLOAT, "El balanceo suma su amplitud a la base")

	canoa.free()


# === CONDICIONES DE FRONTERA ===
func test_tiempo_negativo_es_simetrico() -> void:
	# Arrange
	var canoa := _crear_canoa_determinista()
	canoa.amplitud_flotacion = 0.4
	canoa.frecuencia_flotacion = 2.0

	# Act
	var positivo: Vector3 = canoa.calcular_desplazamiento(0.125)
	var negativo: Vector3 = canoa.calcular_desplazamiento(-0.125)

	# Assert
	assert_almost_eq(negativo.y, -positivo.y, MARGEN_FLOAT, "La onda sinusoidal es impar respecto al tiempo")

	canoa.free()


func test_desplazamiento_queda_acotado_por_la_amplitud() -> void:
	# Arrange
	var canoa := _crear_canoa_determinista()
	canoa.amplitud_flotacion = 0.08

	# Act
	var maxima_flotacion: float = 0.0
	for i in range(0, 64):
		var t: float = i * 0.137
		var desplazamiento: Vector3 = canoa.calcular_desplazamiento(t)
		maxima_flotacion = maxf(maxima_flotacion, absf(desplazamiento.y))

	# Assert
	assert_true(
		maxima_flotacion <= canoa.amplitud_flotacion + MARGEN_FLOAT,
		"La flotación nunca debe exceder la amplitud configurada (máx=%f)" % maxima_flotacion
	)

	canoa.free()


# === ENTRADAS INVÁLIDAS / CASOS EXTREMOS ===
func test_amplitudes_en_cero_producen_movimiento_nulo() -> void:
	# Arrange
	var canoa := _crear_canoa_determinista()
	canoa.amplitud_flotacion = 0.0
	canoa.amplitud_balanceo = 0.0
	canoa.amplitud_cabeceo = 0.0
	canoa.amplitud_deriva_x = 0.0
	canoa.amplitud_deriva_z = 0.0
	canoa.amplitud_guinada = 0.0

	# Act
	var desplazamiento: Vector3 = canoa.calcular_desplazamiento(3.75)
	var rotacion: Vector3 = canoa.calcular_rotacion_grados(3.75)

	# Assert
	assert_almost_eq(desplazamiento.length(), 0.0, MARGEN_FLOAT, "Sin amplitudes no hay desplazamiento")
	assert_almost_eq(rotacion.length(), 0.0, MARGEN_FLOAT, "Sin amplitudes no hay rotación")

	canoa.free()


func test_delta_no_positivo_no_avanza_el_tiempo() -> void:
	# Arrange
	var canoa := _crear_canoa_determinista()
	add_child_autofree(canoa)

	# Act
	canoa._process(0.0)
	canoa._process(-1.0)

	# Assert
	assert_almost_eq(canoa._tiempo, 0.0, MARGEN_FLOAT, "Un delta inválido no debe acumularse")


func test_resolver_fase_respeta_el_valor_configurado() -> void:
	# Arrange
	var canoa := _crear_canoa_determinista()
	add_child_autofree(canoa)

	# Act
	var fase: float = canoa._resolver_fase(1.25)

	# Assert
	assert_almost_eq(fase, 1.25, MARGEN_FLOAT, "Una fase explícita debe conservarse tal cual")


func test_resolver_fase_genera_valor_aleatorio_en_rango() -> void:
	# Arrange
	var canoa := _crear_canoa_determinista()
	add_child_autofree(canoa)

	# Act
	var fase: float = canoa._resolver_fase(CanoaAliada.FASE_ALEATORIA)

	# Assert
	assert_true(fase >= 0.0 and fase < TAU, "La fase aleatoria debe estar en [0, TAU)")


# === COMPORTAMIENTO / ESTADO ===
func test_flotar_activa_procesamiento() -> void:
	# Arrange
	var canoa := _crear_canoa_determinista()
	canoa.flotar_al_iniciar = false
	add_child_autofree(canoa)
	assert_false(canoa.esta_flotando(), "No debe flotar si flotar_al_iniciar es false")

	# Act
	canoa.flotar()

	# Assert
	assert_true(canoa.esta_flotando(), "flotar() debe activar la flotación")
	assert_true(canoa.is_processing(), "flotar() debe habilitar _process")


func test_detener_restaura_la_transformada_base() -> void:
	# Arrange
	var canoa := _crear_canoa_determinista()
	canoa.position = Vector3(5.0, -0.26, 3.95)
	canoa.rotation_degrees = Vector3(0.0, 15.0, 0.0)
	add_child_autofree(canoa)
	canoa._process(0.5)

	# Act
	canoa.detener()

	# Assert
	assert_almost_eq(canoa.position.x, 5.0, MARGEN_FLOAT, "X debe volver a la base")
	assert_almost_eq(canoa.position.y, -0.26, MARGEN_FLOAT, "Y debe volver a la base")
	assert_almost_eq(canoa.position.z, 3.95, MARGEN_FLOAT, "Z debe volver a la base")
	assert_almost_eq(canoa.rotation_degrees.y, 15.0, MARGEN_FLOAT, "La rotación debe volver a la base")
	assert_false(canoa.esta_flotando(), "detener() debe desactivar la flotación")


func test_reiniciar_vuelve_el_tiempo_a_cero() -> void:
	# Arrange
	var canoa := _crear_canoa_determinista()
	add_child_autofree(canoa)
	canoa._process(1.25)
	assert_gt(canoa._tiempo, 0.0)

	# Act
	canoa.reiniciar()

	# Assert
	assert_almost_eq(canoa._tiempo, 0.0, MARGEN_FLOAT, "reiniciar() debe poner el tiempo a 0")


# === ESCENA ===
func test_escena_canoa_tiene_script_y_modelo() -> void:
	# Arrange & Act
	var canoa := ESCENA_CANOA.instantiate() as CanoaAliada
	add_child_autofree(canoa)

	# Assert
	assert_not_null(canoa, "La escena debe instanciar una CanoaAliada")
	assert_true(canoa is CanoaAliada, "La raíz de la escena debe ser de tipo CanoaAliada")
	assert_not_null(canoa.get_node_or_null("CanoaAliadaModel"), "Debe contener el modelo GLB como hijo")
	assert_true(canoa.esta_flotando(), "Por defecto la canoa flota al iniciar")
