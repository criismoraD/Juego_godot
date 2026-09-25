extends "res://addons/gut/test.gd"

## Tests unitarios para la restricción de ataque de la Gárgola en el nivel río:
## No puede atacar ni procesar combate ni disparar proyectiles desde fuera de pantalla.

const GARGOLA_SCENE := preload("res://Entities/Enemigo_Gargola/Gargola.tscn")

var _root_test: Node3D = null
var _camara_test: Camera3D = null


func before_each() -> void:
	_root_test = Node3D.new()
	_root_test.name = "RootTestGargolaRio"
	get_tree().root.add_child(_root_test)
	get_tree().current_scene = _root_test

	_camara_test = Camera3D.new()
	_camara_test.name = "CamaraPrincipal"
	_camara_test.current = true
	_root_test.add_child(_camara_test)
	_camara_test.global_position = Vector3(0.0, 3.0, 30.0)


func after_each() -> void:
	if is_instance_valid(_root_test):
		_root_test.free()
	for n in get_tree().root.get_children():
		if n is Gargola or n is Camera3D:
			n.free()


func test_gargola_fuera_de_camara_no_puede_atacar() -> void:
	# Arrange
	var gargola: Gargola = GARGOLA_SCENE.instantiate() as Gargola
	_root_test.add_child(gargola)
	gargola.solo_atacar_en_pantalla = true
	gargola.global_position = Vector3(25.0, 4.0, 0.0)
	gargola.set("_camara_cache_pantalla", _camara_test)

	# Act & Assert
	assert_false(gargola.esta_en_pantalla_o_rango_camara(), "Gárgola a 25m debe considerarse fuera de pantalla")
	assert_false(gargola.puede_atacar(), "Gárgola fuera de pantalla no debe poder atacar")


func test_gargola_en_vuelo_fuera_de_pantalla_no_entra_a_shooting_al_cumplir_walk_distance() -> void:
	# Arrange
	var gargola: Gargola = GARGOLA_SCENE.instantiate() as Gargola
	_root_test.add_child(gargola)
	gargola.solo_atacar_en_pantalla = true
	gargola.global_position = Vector3(20.0, 4.0, 0.0)
	gargola.set("_camara_cache_pantalla", _camara_test)
	gargola.target_walk_distance = 0.0
	gargola.walked_distance = 5.0
	assert_eq(int(gargola.current_state), int(EnemyBase.State.WALKING), "Inicia en WALKING")

	# Act
	gargola._procesar_vuelo(0.1)

	# Assert: Permanece en vuelo y no entra a SHOOTING
	assert_eq(int(gargola.current_state), int(EnemyBase.State.WALKING), "No debe cambiar a SHOOTING estando fuera de pantalla")


func test_gargola_en_combate_fuera_de_pantalla_cancela_ataque_y_vuelve_a_vuelo() -> void:
	# Arrange: Gárgola forzada a SHOOTING pero fuera del encuadre
	var gargola: Gargola = GARGOLA_SCENE.instantiate() as Gargola
	_root_test.add_child(gargola)
	gargola.solo_atacar_en_pantalla = true
	gargola.global_position = Vector3(25.0, 4.0, 0.0)
	gargola.set("_camara_cache_pantalla", _camara_test)
	gargola.current_state = EnemyBase.State.SHOOTING
	gargola.fase_combate = Gargola.FaseCombate.CARGA

	# Act
	gargola._procesar_combate(0.1)

	# Assert: Debe revertirse inmediatamente a WALKING con fase reseteada a IDLE
	assert_eq(int(gargola.current_state), int(EnemyBase.State.WALKING), "Debe regresar a WALKING")
	assert_eq(int(gargola.fase_combate), int(Gargola.FaseCombate.IDLE), "La fase de combate debe resetearse a IDLE")


func test_gargola_fuera_de_pantalla_bloquea_disparo_proyectil() -> void:
	# Arrange
	var gargola: Gargola = GARGOLA_SCENE.instantiate() as Gargola
	_root_test.add_child(gargola)
	gargola.solo_atacar_en_pantalla = true
	gargola.global_position = Vector3(30.0, 4.0, 0.0)
	gargola.set("_camara_cache_pantalla", _camara_test)

	# Act
	gargola._disparar_proyectiles()

	# Assert: Ningún proyectil debe spawnearse
	var proyectiles := []
	for child in get_tree().root.get_children():
		if child.name.begins_with("GargolaProjectile"):
			proyectiles.append(child)
	for child in _root_test.get_children():
		if child.name.begins_with("GargolaProjectile"):
			proyectiles.append(child)
	assert_eq(proyectiles.size(), 0, "No debe disparar proyectiles fuera de pantalla")


func test_gargola_dentro_de_pantalla_si_puede_atacar() -> void:
	# Arrange
	var gargola: Gargola = GARGOLA_SCENE.instantiate() as Gargola
	_root_test.add_child(gargola)
	gargola.solo_atacar_en_pantalla = true
	gargola.global_position = Vector3(2.0, 4.0, 0.0)
	gargola.set("_camara_cache_pantalla", _camara_test)
	gargola.target_walk_distance = 0.0
	gargola.walked_distance = 1.0

	# Act
	gargola._procesar_vuelo(0.1)

	# Assert
	assert_true(gargola.esta_en_pantalla_o_rango_camara(), "En X=2 con cámara en 0 está en pantalla")
	assert_true(gargola.puede_atacar(), "Debe poder atacar dentro de pantalla")
	assert_eq(int(gargola.current_state), int(EnemyBase.State.SHOOTING), "Pasa a SHOOTING al cumplir distancia dentro de pantalla")


func test_gargola_se_inclina_hacia_abajo_al_atacar_objetivo_inferior() -> void:
	# Arrange
	var gargola: Gargola = GARGOLA_SCENE.instantiate() as Gargola
	_root_test.add_child(gargola)
	gargola.global_position = Vector3(5.0, 4.0, 0.0)

	var target_dummy := Node3D.new()
	target_dummy.name = "PlayerDummy"
	target_dummy.add_to_group("player")
	_root_test.add_child(target_dummy)
	target_dummy.global_position = Vector3(0.0, 0.5, 0.0) # Objetivo abajo y al frente
	gargola.player_ref = target_dummy

	gargola.current_state = EnemyBase.State.SHOOTING
	gargola.fase_combate = Gargola.FaseCombate.CARGA

	# Act: Varios pasos de delta para que la inclinación suave alcance su ángulo
	for i in range(10):
		gargola._actualizar_inclinacion(0.1)

	# Assert
	assert_gt(gargola.inclinacion_actual_rad, 0.0, "La inclinación debe ser positiva (cabeza apuntando hacia abajo)")
	assert_gt(gargola.rotation.z, 0.0, "rotation.z debe reflejar la inclinación hacia abajo")
	assert_lte(rad_to_deg(gargola.inclinacion_actual_rad), gargola.inclinacion_max_grados + 0.1, "No debe exceder el ángulo máximo permitido")


func test_gargola_recupera_inclinacion_horizontal_al_volver_a_vuelo() -> void:
	# Arrange: Gárgola previamente inclinada
	var gargola: Gargola = GARGOLA_SCENE.instantiate() as Gargola
	_root_test.add_child(gargola)
	gargola.inclinacion_actual_rad = deg_to_rad(20.0)
	gargola.rotation.z = deg_to_rad(20.0)
	gargola.current_state = EnemyBase.State.WALKING
	gargola.fase_combate = Gargola.FaseCombate.IDLE

	# Act: Varios pasos de delta para recuperación
	for i in range(15):
		gargola._actualizar_inclinacion(0.1)

	# Assert
	assert_almost_eq(gargola.inclinacion_actual_rad, 0.0, 0.01, "Debe regresar a 0 (horizontal) durante el vuelo")
	assert_almost_eq(gargola.rotation.z, 0.0, 0.01, "rotation.z debe regresar a 0 en vuelo")


func test_gargola_sin_objetivo_debajo_no_se_inclina() -> void:
	# Arrange: Objetivo arriba de la gárgola
	var gargola: Gargola = GARGOLA_SCENE.instantiate() as Gargola
	_root_test.add_child(gargola)
	gargola.global_position = Vector3(5.0, 3.0, 0.0)

	var target_dummy := Node3D.new()
	target_dummy.name = "PlayerDummyArriba"
	target_dummy.add_to_group("player")
	_root_test.add_child(target_dummy)
	target_dummy.global_position = Vector3(0.0, 5.0, 0.0) # Objetivo arriba
	gargola.player_ref = target_dummy

	gargola.current_state = EnemyBase.State.SHOOTING
	gargola.fase_combate = Gargola.FaseCombate.CARGA

	# Act
	for i in range(10):
		gargola._actualizar_inclinacion(0.1)

	# Assert
	assert_eq(gargola.inclinacion_actual_rad, 0.0, "No debe inclinarse hacia abajo si el objetivo está arriba")
	assert_eq(gargola.rotation.z, 0.0, "rotation.z debe permanecer horizontal")
