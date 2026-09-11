extends "res://addons/gut/test.gd"
## Tests unitarios de la balsa pirata flotante (Entities/Ambiente_Balsa_Pirata).
## Cubren el cálculo matemático de oscilación, ciclo de vida, navegación en X y emisión de señales.

const SCRIPT_BALSA := preload("res://Entities/Ambiente_Balsa_Pirata/BalsaPirata.gd")
const ESCENA_BALSA := preload("res://Entities/Ambiente_Balsa_Pirata/BalsaPirata.tscn")
const MARGEN_FLOAT: float = 0.0001
const TIEMPO_CUARTO_DE_CICLO: float = 0.25


func _crear_balsa_determinista() -> BalsaPirata:
	var balsa: BalsaPirata = SCRIPT_BALSA.new()
	balsa.fase_flotacion = 0.0
	balsa.fase_balanceo = 0.0
	balsa.fase_cabeceo = 0.0
	balsa.fase_deriva_x = 0.0
	balsa.fase_deriva_z = 0.0
	balsa.fase_guinada = 0.0
	balsa._inicializar_fases()
	return balsa


# === PRUEBAS DE FLOTACIÓN (HAPPY PATH) ===
func test_en_tiempo_cero_desplazamiento_es_nulo() -> void:
	# Arrange
	var balsa := _crear_balsa_determinista()

	# Act
	var desplazamiento: Vector3 = balsa.calcular_desplazamiento(0.0)

	# Assert
	assert_almost_eq(desplazamiento.x, 0.0, MARGEN_FLOAT, "La deriva en X debe partir en 0")
	assert_almost_eq(desplazamiento.y, 0.0, MARGEN_FLOAT, "La flotación en Y debe partir en 0")
	assert_almost_eq(desplazamiento.z, 0.0, MARGEN_FLOAT, "La deriva en Z debe partir en 0")

	balsa.free()


func test_flotacion_alcanza_amplitud_en_cuarto_ciclo() -> void:
	# Arrange
	var balsa := _crear_balsa_determinista()
	balsa.amplitud_flotacion = 0.4
	balsa.frecuencia_flotacion = 1.0

	# Act
	var desplazamiento: Vector3 = balsa.calcular_desplazamiento(TIEMPO_CUARTO_DE_CICLO)

	# Assert
	assert_almost_eq(desplazamiento.y, 0.4, MARGEN_FLOAT, "En 1/4 de ciclo la flotación llega a +amplitud")

	balsa.free()


func test_rotacion_alcanza_amplitud_balanceo() -> void:
	# Arrange
	var balsa := _crear_balsa_determinista()
	balsa.amplitud_balanceo = 4.0
	balsa.frecuencia_balanceo = 1.0

	# Act
	var rotacion: Vector3 = balsa.calcular_rotacion_grados(TIEMPO_CUARTO_DE_CICLO)

	# Assert
	assert_almost_eq(rotacion.z, 4.0, MARGEN_FLOAT, "El balanceo en Z llega a su amplitud máxima")

	balsa.free()


# === PRUEBAS DE NAVEGACIÓN HORIZONTAL ===
func test_navegar_hacia_x_inicia_navegacion() -> void:
	# Arrange
	var balsa := _crear_balsa_determinista()
	balsa.fijar_posicion_base(Vector3(14.0, 0.0, 0.0))

	# Act
	balsa.navegar_hacia_x(5.0, 2.0)

	# Assert
	assert_true(balsa.esta_navegando(), "La balsa debe estar en estado navegando")

	balsa.free()


func test_navegar_hacia_x_desplaza_hacia_izquierda() -> void:
	# Arrange
	var balsa := _crear_balsa_determinista()
	balsa.fijar_posicion_base(Vector3(14.0, 0.0, 0.0))
	balsa.navegar_hacia_x(5.0, 2.0)

	# Act: Simular un paso de 1 segundo a velocidad 2.0 hacia la izquierda
	balsa._actualizar_navegacion(1.0)

	# Assert: Debe haberse desplazado de 14.0 a 12.0
	assert_almost_eq(balsa.obtener_posicion_base().x, 12.0, MARGEN_FLOAT, "La balsa debe avanzar hacia la izquierda")
	assert_true(balsa.esta_navegando(), "Aún debe continuar navegando hacia el destino 5.0")

	balsa.free()


func test_llegada_a_destino_emite_senal_y_detiene_navegacion() -> void:
	# Arrange
	var balsa := _crear_balsa_determinista()
	balsa.fijar_posicion_base(Vector3(6.0, 0.0, 0.0))
	balsa.navegar_hacia_x(5.0, 2.0)
	watch_signals(balsa)

	# Act: Simular paso que sobrepase o alcance el destino
	balsa._actualizar_navegacion(1.0)

	# Assert
	assert_almost_eq(balsa.obtener_posicion_base().x, 5.0, MARGEN_FLOAT, "La posición debe clampearse exactamente al destino")
	assert_false(balsa.esta_navegando(), "La balsa debe detener la traslación al llegar")
	assert_signal_emitted(balsa, "destino_alcanzado", "Debe emitirse la señal destino_alcanzado")

	balsa.free()


# === PRUEBAS DE CONDICIONES DE BORDE ===
func test_navegar_hacia_misma_posicion_alcanza_inmediatamente() -> void:
	# Arrange
	var balsa := _crear_balsa_determinista()
	balsa.fijar_posicion_base(Vector3(5.0, 0.0, 0.0))
	balsa.navegar_hacia_x(5.0, 2.0)
	watch_signals(balsa)

	# Act
	balsa._actualizar_navegacion(0.016)

	# Assert
	assert_false(balsa.esta_navegando())
	assert_signal_emitted(balsa, "destino_alcanzado")

	balsa.free()


func test_instanciar_escena_balsa_pirata() -> void:
	# Arrange & Act
	var balsa := ESCENA_BALSA.instantiate() as BalsaPirata

	# Assert
	assert_not_null(balsa, "La escena BalsaPirata.tscn debe instanciar una BalsaPirata")
	assert_true(balsa is BalsaPirata, "La raíz debe ser de clase BalsaPirata")
	assert_not_null(balsa.get_node_or_null("BalsaPirataModel"), "Debe contener el modelo como hijo")

	balsa.free()
