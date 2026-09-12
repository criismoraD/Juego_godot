extends "res://addons/gut/test.gd"

## Tests unitarios para el MaderoVolador y su expulsión al destruir la Balsa Pirata.
## Cubren cinemática parabólica, rotación multi-eje, impacto en agua y configuración de direcciones.

const SCRIPT_MADERO: Script = preload("res://Entities/Ambiente_Balsa_Pirata/MaderoVolador.gd")
const SCRIPT_BALSA: Script = preload("res://Entities/Ambiente_Balsa_Pirata/BalsaPirata.gd")
const ESCENA_BALSA: PackedScene = preload("res://Entities/Ambiente_Balsa_Pirata/BalsaPirata.tscn")
const MARGEN_FLOAT: float = 0.001


# === TESTS DE INSTANCIACIÓN Y MATERIAL ===
func test_madero_volador_instanciacion_y_material() -> void:
	# Arrange & Act
	var madero: Node3D = SCRIPT_MADERO.new() as Node3D
	add_child_autofree(madero)

	# Assert
	assert_not_null(madero, "MaderoVolador debe instanciarse")
	var modelo: Node3D = madero.find_child("ModeloMadero", true, false) as Node3D
	assert_not_null(modelo, "Debe instanciarse el nodo del modelo 3D")

	var meshes: Array[Node] = modelo.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "El modelo debe contener mallas 3D")
	for m in meshes:
		var mi := m as MeshInstance3D
		if is_instance_valid(mi) and mi.mesh:
			for s in range(mi.mesh.get_surface_count()):
				assert_eq(
					mi.get_surface_override_material(s),
					SCRIPT_MADERO.MATERIAL_MADERO,
					"La superficie " + str(s) + " debe tener asignado MATERIAL_MADERO"
				)


# === TESTS DE CINEMÁTICA Y ROTACIÓN ===
func test_madero_volador_movimiento_parabolico_y_rotacion() -> void:
	# Arrange
	var madero: Node3D = SCRIPT_MADERO.new() as Node3D
	add_child_autofree(madero)
	var pos_inicial := Vector3(0.0, 5.0, 0.0)
	var impulso := Vector3(3.0, 8.0, 0.0)
	madero.lanzar(pos_inicial, impulso, -10.0, 2)

	assert_true(madero.esta_volando(), "El madero debe iniciar en estado volando")
	assert_eq(madero.global_position, pos_inicial, "La posición inicial debe ser la especificada")

	# Act: Simular 0.5 segundos de física
	var delta: float = 0.5
	madero._physics_process(delta)

	# Assert:
	# velocidad.y esperada = 8.0 - gravedad * delta (12.0 * 0.5 = 6.0) -> 2.0
	assert_almost_eq(madero.velocidad.y, 2.0, MARGEN_FLOAT, "La gravedad debe restar a la velocidad Y")
	# pos.x esperada = 0.0 + 3.0 * 0.5 = 1.5
	assert_almost_eq(madero.global_position.x, 1.5, MARGEN_FLOAT, "La posición X debe avanzar linealmente")
	# pos.y esperada = 5.0 + 2.0 * 0.5 = 6.0
	assert_almost_eq(madero.global_position.y, 6.0, MARGEN_FLOAT, "La posición Y debe seguir la parábola")


# === TESTS DE DIRECCIONES Y CONFIGURACIÓN ===
func test_configuracion_maderos_2_derecha_1_izquierda() -> void:
	# Arrange: Verificar las constantes de configuración en BalsaPirata
	var configs: Array[Dictionary] = BalsaPirata.CONFIG_MADEROS_VOLADORES

	# Assert: Deben ser exactamente 3 maderos
	assert_eq(configs.size(), 3, "Deben configurarse exactamente 3 maderos voladores")

	var maderos_derecha: int = 0
	var maderos_izquierda: int = 0

	for cfg in configs:
		var impulso: Vector3 = cfg["impulso"]
		assert_gt(impulso.y, 0.0, "Cada madero debe salir impulsado hacia arriba (impulso Y > 0)")
		if impulso.x > 0.0:
			maderos_derecha += 1
		elif impulso.x < 0.0:
			maderos_izquierda += 1

	assert_eq(maderos_derecha, 2, "Deben salir exactamente 2 maderos hacia la derecha (impulso X > 0)")
	assert_eq(maderos_izquierda, 1, "Debe salir exactamente 1 madero hacia la izquierda (impulso X < 0)")


# === TESTS DE ENTRADA AL AGUA ===
func test_madero_volador_impacto_agua_emite_senal_y_cambia_estado() -> void:
	# Arrange
	var madero: Node3D = SCRIPT_MADERO.new() as Node3D
	add_child_autofree(madero)
	watch_signals(madero)

	# Posicionar justo arriba del agua cayendo
	var nivel_agua: float = -0.3
	madero.lanzar(Vector3(2.0, 0.1, 0.0), Vector3(1.0, -2.0, 0.0), nivel_agua, 2)

	# Act: Paso de simulación que cruza el nivel del agua
	madero._physics_process(0.3)

	# Assert: Debe impactar en agua
	assert_signal_emitted(madero, "cayo_al_agua", "Debe emitirse la señal cayo_al_agua")
	assert_true(madero.esta_sumergido(), "El madero debe transicionar a estado sumergido")
	assert_false(madero.esta_volando(), "El madero ya no debe estar en estado volando")
	assert_almost_eq(madero.global_position.y, nivel_agua, MARGEN_FLOAT, "La posición Y debe clampearse al agua")


# === TESTS DE INTEGRACIÓN CON BALSA PIRATA ===
func test_balsa_pirata_destruir_expulsa_3_maderos() -> void:
	# Arrange
	var balsa := ESCENA_BALSA.instantiate() as BalsaPirata
	add_child_autofree(balsa)

	# Act: Ejecutar destrucción
	balsa.destruir_balsa()

	# Assert: Deben haberse instanciado 3 maderos voladores
	var maderos: Array[Node3D] = balsa.obtener_maderos_lanzados()
	assert_eq(maderos.size(), 3, "La balsa debe haber lanzado 3 maderos voladores")

	for m in maderos:
		assert_not_null(m, "La instancia de madero debe ser válida")
		assert_true(m.esta_volando(), "Cada madero lanzado debe iniciar en vuelo")
		assert_eq(m.capa_visual, balsa.capa_visual, "La capa visual del madero debe coincidir con la balsa")
		# Limpiar autofree
		autofree(m)
