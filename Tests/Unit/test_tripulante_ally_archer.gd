extends "res://addons/gut/test.gd"
## Tests unitarios del tripulante arquera aliada de fondo (TripulanteBarcoFondoAllyArcher).
## Cubren inicialización en IDLE, capa visual 2, ciclo de combate estético y casos de borde.

const SCRIPT_TRIPULANTE := preload("res://Entities/Ambiente_Canoa_Aliada/TripulanteBarcoFondoAllyArcher.gd")
const ESCENA_TRIPULANTE := preload("res://Entities/Ambiente_Canoa_Aliada/Tripulante_barco_fondo_ally_archer.tscn")


func test_tripulante_inicia_en_idle() -> void:
	# Arrange
	var tripulante: TripulanteBarcoFondoAllyArcher = SCRIPT_TRIPULANTE.new()
	add_child(tripulante)

	# Act
	var estado: int = tripulante.obtener_estado()
	var en_combate: bool = tripulante.esta_en_combate()

	# Assert
	assert_eq(estado, TripulanteBarcoFondoAllyArcher.EstadoTripulante.IDLE, "El tripulante debe iniciar en estado IDLE")
	assert_false(en_combate, "El tripulante no debe estar en combate al iniciar")

	tripulante.queue_free()


func test_capa_visual_es_dos_por_defecto() -> void:
	# Arrange
	var tripulante: TripulanteBarcoFondoAllyArcher = SCRIPT_TRIPULANTE.new()

	# Act & Assert
	assert_eq(tripulante.capa_visual, 2, "La capa visual por defecto debe ser 2 (Fondo)")

	tripulante.free()


func test_aplicar_capa_visual_en_escena_completa() -> void:
	# Arrange
	var tripulante := ESCENA_TRIPULANTE.instantiate() as TripulanteBarcoFondoAllyArcher
	add_child(tripulante)

	# Act
	var meshes: Array[Node] = tripulante.find_children("*", "VisualInstance3D", true, false)

	# Assert
	assert_gt(meshes.size(), 0, "La escena debe contener elementos visuales")
	for m in meshes:
		var visual := m as VisualInstance3D
		if visual:
			assert_eq(visual.layers, 2, "Cada elemento visual debe pertenecer a la Capa 2 (layers = 2)")

	tripulante.queue_free()


func test_iniciar_y_detener_combate() -> void:
	# Arrange
	var tripulante: TripulanteBarcoFondoAllyArcher = SCRIPT_TRIPULANTE.new()
	add_child(tripulante)

	# Act
	tripulante.iniciar_combate(0.5)

	# Assert
	assert_true(tripulante.esta_en_combate(), "iniciar_combate() debe activar la bandera de combate")

	# Act 2
	tripulante.detener_combate()

	# Assert 2
	assert_false(tripulante.esta_en_combate(), "detener_combate() debe desactivar la bandera de combate")
	assert_eq(tripulante.obtener_estado(), TripulanteBarcoFondoAllyArcher.EstadoTripulante.IDLE, "Debe regresar a IDLE")

	tripulante.queue_free()


func test_delta_cero_o_negativo_no_causa_errores() -> void:
	# Arrange
	var tripulante: TripulanteBarcoFondoAllyArcher = SCRIPT_TRIPULANTE.new()
	add_child(tripulante)

	# Act & Assert
	tripulante._process(0.0)
	tripulante._process(-0.016)
	assert_eq(tripulante.obtener_estado(), TripulanteBarcoFondoAllyArcher.EstadoTripulante.IDLE, "Delta inválido se ignora pacíficamente")

	tripulante.queue_free()


func test_esta_sentada_falso_por_defecto() -> void:
	# Arrange
	var tripulante: TripulanteBarcoFondoAllyArcher = SCRIPT_TRIPULANTE.new()

	# Act & Assert
	assert_false(tripulante.esta_sentada, "esta_sentada debe ser false por defecto")

	tripulante.free()


func test_esta_sentada_activa_animation_tree_y_ciclo() -> void:
	# Arrange
	var tripulante := ESCENA_TRIPULANTE.instantiate() as TripulanteBarcoFondoAllyArcher
	tripulante.esta_sentada = true
	add_child(tripulante)

	# Act
	var anim_tree: AnimationTree = tripulante.find_child("AllyTripulanteAnimTree", true, false) as AnimationTree

	# Assert
	assert_not_null(anim_tree, "Cuando esta_sentada es true, debe inicializar AllyTripulanteAnimTree")
	if anim_tree:
		assert_true(anim_tree.active, "El AnimationTree debe estar activo")
		var blend_idle: float = float(anim_tree.get("parameters/UpperBlend/blend_amount"))
		assert_almost_eq(blend_idle, 0.0, 0.001, "En IDLE el blend_amount debe ser 0.0 (100% pose sentada)")

	# Act 2: Iniciar disparo
	tripulante._iniciar_ciclo_disparo()

	# Assert 2
	if anim_tree:
		var blend_prep: float = float(anim_tree.get("parameters/UpperBlend/blend_amount"))
		assert_almost_eq(blend_prep, 1.0, 0.001, "Al preparar disparo el blend_amount debe ser 1.0")

	tripulante.queue_free()
