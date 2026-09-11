extends "res://addons/gut/test.gd"
## Tests de integración y composición para el sistema de embarcaciones y tripulantes de fondo.
## Verifica que ambas naves tengan 4 tripulantes, que sus velocidades se hayan reducido al 50%
## y que la señal/método de combate active a la tripulación.

const ESCENA_CANOA := preload("res://Entities/Ambiente_Canoa_Aliada/CanoaAliada.tscn")
const ESCENA_BALSA := preload("res://Entities/Ambiente_Balsa_Pirata/BalsaPirata.tscn")
const SCRIPT_CONTROLADOR := preload("res://System/Ambiente/ControladorTrayectoriaEmbarcaciones.gd")


func test_canoa_contiene_cuatro_tripulantes_aliadas() -> void:
	# Arrange & Act
	var canoa := ESCENA_CANOA.instantiate() as CanoaAliada
	add_child(canoa)

	var tripulantes: Array[Node] = canoa.find_children("*", "TripulanteBarcoFondoAllyArcher", true, false)

	# Assert
	assert_eq(tripulantes.size(), 4, "La canoa aliada debe contar con exactamente 4 tripulantes arqueras")

	canoa.queue_free()


func test_balsa_contiene_cuatro_tripulantes_goblins() -> void:
	# Arrange & Act
	var balsa := ESCENA_BALSA.instantiate() as BalsaPirata
	add_child(balsa)

	var tripulantes: Array[Node] = balsa.find_children("*", "TripulanteBarcoFondoGoblinGirl", true, false)

	# Assert
	assert_eq(tripulantes.size(), 4, "La balsa pirata debe contar con exactamente 4 tripulantes arqueras goblin")

	balsa.queue_free()


func test_iniciar_combate_tripulacion_activa_todas_las_aliadas() -> void:
	# Arrange
	var canoa := ESCENA_CANOA.instantiate() as CanoaAliada
	add_child(canoa)

	# Act
	canoa.iniciar_combate_tripulacion()

	# Assert
	var tripulantes: Array[Node] = canoa.find_children("*", "TripulanteBarcoFondoAllyArcher", true, false)
	for t in tripulantes:
		var tripulante := t as TripulanteBarcoFondoAllyArcher
		assert_true(tripulante.esta_en_combate(), "Cada tripulante aliada debe pasar a estado de combate")

	canoa.queue_free()


func test_iniciar_combate_tripulacion_activa_todas_las_goblins() -> void:
	# Arrange
	var balsa := ESCENA_BALSA.instantiate() as BalsaPirata
	add_child(balsa)

	# Act
	balsa.iniciar_combate_tripulacion()

	# Assert
	var tripulantes: Array[Node] = balsa.find_children("*", "TripulanteBarcoFondoGoblinGirl", true, false)
	for t in tripulantes:
		var tripulante := t as TripulanteBarcoFondoGoblinGirl
		assert_true(tripulante.esta_en_combate(), "Cada tripulante goblin debe pasar a estado de combate")

	balsa.queue_free()


func test_velocidades_reducidas_al_doble_de_lento() -> void:
	# Arrange & Act
	var controlador: ControladorTrayectoriaEmbarcaciones = SCRIPT_CONTROLADOR.new()

	# Assert
	assert_almost_eq(controlador.velocidad_canoa, 0.8, 0.001, "La velocidad de la canoa debe ser 0.8 m/s (50% de 1.6)")
	assert_almost_eq(controlador.velocidad_balsa, 0.7, 0.001, "La velocidad de la balsa debe ser 0.7 m/s (50% de 1.4)")

	controlador.free()


func test_canoa_tripulantes_3_y_4_estan_sentadas_y_1_y_2_de_pie() -> void:
	# Arrange & Act
	var canoa := ESCENA_CANOA.instantiate() as CanoaAliada
	add_child(canoa)

	var t1: TripulanteBarcoFondoAllyArcher = canoa.find_child("Tripulante1", true, false) as TripulanteBarcoFondoAllyArcher
	var t2: TripulanteBarcoFondoAllyArcher = canoa.find_child("Tripulante2", true, false) as TripulanteBarcoFondoAllyArcher
	var t3: TripulanteBarcoFondoAllyArcher = canoa.find_child("Tripulante3", true, false) as TripulanteBarcoFondoAllyArcher
	var t4: TripulanteBarcoFondoAllyArcher = canoa.find_child("Tripulante4", true, false) as TripulanteBarcoFondoAllyArcher

	# Assert
	assert_not_null(t1, "Debe existir Tripulante1")
	assert_not_null(t2, "Debe existir Tripulante2")
	assert_not_null(t3, "Debe existir Tripulante3")
	assert_not_null(t4, "Debe existir Tripulante4")

	if t1 and t2 and t3 and t4:
		assert_false(t1.esta_sentada, "Tripulante1 en canoa debe estar de pie (esta_sentada == false)")
		assert_false(t2.esta_sentada, "Tripulante2 en canoa debe estar de pie (esta_sentada == false)")
		assert_true(t3.esta_sentada, "Tripulante3 en canoa debe atacar sentada (esta_sentada == true)")
		assert_true(t4.esta_sentada, "Tripulante4 en canoa debe atacar sentada (esta_sentada == true)")

	canoa.queue_free()


func test_balsa_tripulantes_1_y_2_estan_sentadas_y_3_y_4_de_pie() -> void:
	# Arrange & Act
	var balsa := ESCENA_BALSA.instantiate() as BalsaPirata
	add_child(balsa)

	var t1: TripulanteBarcoFondoGoblinGirl = balsa.find_child("Tripulante1", true, false) as TripulanteBarcoFondoGoblinGirl
	var t2: TripulanteBarcoFondoGoblinGirl = balsa.find_child("Tripulante2", true, false) as TripulanteBarcoFondoGoblinGirl
	var t3: TripulanteBarcoFondoGoblinGirl = balsa.find_child("Tripulante3", true, false) as TripulanteBarcoFondoGoblinGirl
	var t4: TripulanteBarcoFondoGoblinGirl = balsa.find_child("Tripulante4", true, false) as TripulanteBarcoFondoGoblinGirl

	# Assert
	assert_not_null(t1, "Debe existir Tripulante1 en balsa")
	assert_not_null(t2, "Debe existir Tripulante2 en balsa")
	assert_not_null(t3, "Debe existir Tripulante3 en balsa")
	assert_not_null(t4, "Debe existir Tripulante4 en balsa")

	if t1 and t2 and t3 and t4:
		assert_true(t1.esta_sentada, "Tripulante1 en balsa debe atacar sentada/agachada (esta_sentada == true)")
		assert_true(t2.esta_sentada, "Tripulante2 en balsa debe atacar sentada/agachada (esta_sentada == true)")
		assert_false(t3.esta_sentada, "Tripulante3 en balsa debe estar de pie (esta_sentada == false)")
		assert_false(t4.esta_sentada, "Tripulante4 en balsa debe estar de pie (esta_sentada == false)")

	balsa.queue_free()
