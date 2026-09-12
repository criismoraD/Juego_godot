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


func test_asegurar_materiales_no_sobrescribe_material_tripulantes() -> void:
	# Arrange & Act
	var balsa := ESCENA_BALSA.instantiate() as BalsaPirata
	add_child_autofree(balsa)

	# Assert
	var tripulante := balsa.get_node_or_null("Tripulante1") as Node3D
	assert_not_null(tripulante, "Tripulante1 debe existir en la balsa")

	var meshes_tripulante: Array[Node] = tripulante.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes_tripulante.size(), 0, "El tripulante debe tener mallas 3D")
	for m in meshes_tripulante:
		var mi := m as MeshInstance3D
		if mi and mi.mesh:
			for s in range(mi.mesh.get_surface_count()):
				var mat_override := mi.get_surface_override_material(s)
				assert_ne(
					mat_override,
					BalsaPirata.MAT_BALSA,
					"El tripulante NO debe tener la textura de la balsa asignada en la superficie " + str(s)
				)


func test_destruir_balsa_detiene_movimiento_y_marca_destruida() -> void:
	# Arrange
	var balsa := ESCENA_BALSA.instantiate() as BalsaPirata
	add_child_autofree(balsa)
	balsa.navegar_hacia_x(10.0, 2.0)
	watch_signals(balsa)

	# Act
	balsa.destruir_balsa()

	# Assert
	assert_true(balsa.esta_destruida(), "La balsa debe reportar esta_destruida = true")
	assert_false(balsa.esta_flotando(), "La flotación estándar debe haberse detenido")
	assert_false(balsa.esta_navegando(), "La navegación horizontal debe haberse detenido")
	assert_signal_emitted(balsa, "balsa_destruida", "Debe emitirse la señal balsa_destruida")


func test_destruir_balsa_mata_a_todos_los_tripulantes() -> void:
	# Arrange
	var balsa := ESCENA_BALSA.instantiate() as BalsaPirata
	add_child_autofree(balsa)

	var tripulantes := balsa.find_children("*", "TripulanteBarcoFondoGoblinGirl", true, false)
	assert_gt(tripulantes.size(), 0, "La balsa debe tener tripulantes goblins")
	for t in tripulantes:
		assert_false((t as TripulanteBarcoFondoGoblinGirl).esta_muerta(), "Tripulante debe iniciar viva")

	# Act
	balsa.destruir_balsa()

	# Assert
	for t in tripulantes:
		var trip := t as TripulanteBarcoFondoGoblinGirl
		assert_true(trip.esta_muerta(), "Todos los tripulantes deben estar muertos tras destruir_balsa")
		assert_false(trip.esta_en_combate(), "Los tripulantes no deben continuar en combate")


func test_destruir_balsa_sustituye_modelo_por_destruido() -> void:
	# Arrange
	var balsa := ESCENA_BALSA.instantiate() as BalsaPirata
	add_child_autofree(balsa)

	# Act
	balsa.destruir_balsa()

	# Assert
	var modelo_nuevo := balsa.find_child("BalsaPirataModel", true, false) as Node3D
	assert_not_null(modelo_nuevo, "Debe existir un nuevo modelo BalsaPirataModel")

	var meshes := modelo_nuevo.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "El modelo destruido debe contener mallas 3D")
	for m in meshes:
		var mi := m as MeshInstance3D
		if is_instance_valid(mi) and mi.mesh:
			for s in range(mi.mesh.get_surface_count()):
				assert_eq(
					mi.get_surface_override_material(s),
					BalsaPirata.MAT_BALSA_DESTRUIDA,
					"El modelo destruido debe tener MAT_BALSA_DESTRUIDA asignado"
				)


func test_destruir_balsa_es_idempotente() -> void:
	# Arrange
	var balsa := ESCENA_BALSA.instantiate() as BalsaPirata
	add_child_autofree(balsa)
	watch_signals(balsa)

	# Act: Llamar dos veces
	balsa.destruir_balsa()
	balsa.destruir_balsa()

	# Assert
	assert_true(balsa.esta_destruida())
	assert_signal_emit_count(balsa, "balsa_destruida", 1, "La señal no debe duplicarse")

