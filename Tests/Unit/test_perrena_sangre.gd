extends "res://addons/gut/test.gd"

## Tests unitarios para el efecto de sangre de impacto y muerte en Perrena.

const DEFENSORA_SCENE := preload("res://Entities/Defensora_Perrena/DefensoraPerrena.tscn")
const BLOOD_NORMAL_SCENE := preload("res://VFX/Scenes/BloodSplashNormal.tscn")
const BLOOD_NO_LETAL_SCENE := preload("res://VFX/Scenes/BloodSplashNoLetal.tscn")

var _root_test: Node3D = null


func before_each() -> void:
	_root_test = Node3D.new()
	_root_test.name = "RootTestSangrePerrena"
	get_tree().root.add_child(_root_test)
	get_tree().current_scene = _root_test


func after_each() -> void:
	if is_instance_valid(_root_test):
		_root_test.free()
	for n in get_tree().root.get_children():
		if n is DefensoraPerrena or n is BloodSplash2D:
			n.free()


func test_dano_no_letal_genera_splash_sangre_no_letal() -> void:
	# Arrange
	var defensora: DefensoraPerrena = DEFENSORA_SCENE.instantiate() as DefensoraPerrena
	_root_test.add_child(defensora)
	defensora.global_position = Vector3(10.0, 0.0, 0.0)
	var golpe_pos := Vector3(10.0, 1.2, 0.0)
	var golpe_dir := Vector3(-1.0, 0.0, 0.0)

	# Act: Recibe 1 punto de daño no letal (de 3 iniciales pasa a 2)
	defensora.take_damage(1.0, golpe_pos, golpe_dir)

	# Assert
	assert_eq(defensora.health, 2, "La salud debe decrementar a 2")
	assert_eq(defensora.last_hit_position, golpe_pos, "Debe registrar la posición de impacto")
	assert_eq(defensora.last_hit_direction, golpe_dir, "Debe registrar la dirección de impacto")

	var splashes := []
	for child in _root_test.get_children():
		if child.name.begins_with("BloodSplashNoLetal") or (child is BloodSplash2D and child.name != "BloodSplashNormal"):
			splashes.append(child)

	assert_gt(splashes.size(), 0, "Debe instanciarse el splash de sangre no letal en la escena")
	var splash = splashes[0] as BloodSplash2D
	assert_eq(splash.global_position, golpe_pos, "El splash debe posicionarse en golpe_pos")
	# Como BloodSplashNoLetal tiene base_faces_left = true, viajar hacia la izquierda (X < 0) no requiere flip_h
	assert_false(splash.flip_h, "El splash no debe voltearse porque su textura base ya apunta a la izquierda")


func test_dano_letal_genera_splash_sangre_normal_y_estado_dying() -> void:
	# Arrange
	var defensora: DefensoraPerrena = DEFENSORA_SCENE.instantiate() as DefensoraPerrena
	_root_test.add_child(defensora)
	defensora.global_position = Vector3(5.0, 0.0, 0.0)
	var golpe_pos := Vector3(5.0, 1.0, 0.0)
	var golpe_dir := Vector3(1.0, 0.0, 0.0)

	# Act: Recibe daño letal (3 puntos)
	defensora.take_damage(3.0, golpe_pos, golpe_dir)

	# Assert
	assert_lte(defensora.health, 0, "La salud debe ser 0 o menor")
	assert_eq(defensora.current_state, DefensoraPerrena.State.DYING, "Debe pasar al estado DYING")

	var lethal_splashes := []
	for child in _root_test.get_children():
		if child.name.begins_with("BloodSplashNormal") or (child is BloodSplash2D and "Normal" in child.name):
			lethal_splashes.append(child)

	assert_gt(lethal_splashes.size(), 0, "Debe instanciarse el splash de sangre normal de muerte en la escena")
	var splash = lethal_splashes[0] as BloodSplash2D
	assert_eq(splash.global_position, golpe_pos, "El splash de muerte debe posicionarse en golpe_pos")
	assert_false(splash.flip_h, "El splash de muerte no debe voltearse si la dirección es hacia la derecha")


func test_perrena_inmune_no_recibe_dano_ni_sangra() -> void:
	# Arrange
	var defensora: DefensoraPerrena = DEFENSORA_SCENE.instantiate() as DefensoraPerrena
	_root_test.add_child(defensora)
	defensora.es_inmune = true
	var golpe_pos := Vector3(2.0, 1.0, 0.0)

	# Act
	defensora.take_damage(1.0, golpe_pos, Vector3.LEFT)

	# Assert
	assert_eq(defensora.health, 3, "No debe perder vida si es inmune")
	var splashes := []
	for child in _root_test.get_children():
		if child is BloodSplash2D:
			splashes.append(child)
	assert_eq(splashes.size(), 0, "No debe spawnear ningún splash si es inmune")


func test_recibir_dano_propaga_parametros_a_take_damage() -> void:
	# Arrange
	var defensora: DefensoraPerrena = DEFENSORA_SCENE.instantiate() as DefensoraPerrena
	_root_test.add_child(defensora)
	var golpe_pos := Vector3(3.0, 0.5, 0.0)
	var golpe_dir := Vector3.LEFT

	# Act
	defensora.recibir_dano(1, golpe_pos, golpe_dir)

	# Assert
	assert_eq(defensora.health, 2, "recibir_dano debe descontar 1 de vida")
	assert_eq(defensora.last_hit_position, golpe_pos, "last_hit_position debe quedar almacenada")
	assert_eq(defensora.last_hit_direction, golpe_dir, "last_hit_direction debe quedar almacenada")
