extends GutTest

const LONKO_SCENE: PackedScene = preload("res://LONKO/Lonko.tscn")

var scene_root: Node3D


func before_each() -> void:
	scene_root = Node3D.new()
	add_child(scene_root)


func after_each() -> void:
	if is_instance_valid(scene_root):
		scene_root.queue_free()
	await get_tree().process_frame


func test_lonko_initial_stats_and_attachments() -> void:
	# Arrange & Act
	var lonko := LONKO_SCENE.instantiate() as Lonko
	scene_root.add_child(lonko)
	await get_tree().process_frame

	# Assert
	assert_not_null(lonko, "La escena de Lonko debe instanciarse correctamente")
	assert_eq(lonko.vida_maxima, 6, "Lonko debe tener 6 de vida máxima")
	assert_eq(lonko.health, 6, "Lonko debe iniciar con 6 de vida")

	var bow = lonko.find_child("ARCO_GOBLING_GIRL", true, false)
	assert_not_null(bow, "Lonko debe tener equipado el arco ARCO_GOBLING_GIRL")

	var flecha_mano = lonko.find_child("FlechaMano", true, false)
	assert_not_null(flecha_mano, "Lonko debe tener el nodo FlechaMano en los attachments")

	lonko.queue_free()
	await get_tree().process_frame


func test_lonko_take_damage_and_death() -> void:
	# Arrange
	var lonko := LONKO_SCENE.instantiate() as Lonko
	scene_root.add_child(lonko)
	await get_tree().process_frame

	# Act: Aplicar daño parcial
	lonko.take_damage(2.0)

	# Assert: Reducción de vida
	assert_eq(lonko.health, 4, "Recibir 2 de daño debe reducir la vida a 4")

	# Act: Daño letal
	lonko.take_damage(4.0)

	# Assert: Muerte
	assert_eq(lonko.health, 0, "Daño letal debe dejar la vida en 0")
	assert_eq(lonko.current_state, Lonko.State.DYING, "El estado debe cambiar a DYING")

	lonko.queue_free()
	await get_tree().process_frame


func test_lonko_tiro_electrico_cada_3() -> void:
	# Arrange
	var lonko := LONKO_SCENE.instantiate() as Lonko
	scene_root.add_child(lonko)
	await get_tree().process_frame
	lonko.cada_cuantos_tiros_electrico = 3

	# Act & Assert: los tiros 1 y 2 son normales, el 3 y el 6 son eléctricos
	assert_false(lonko._es_tiro_electrico(1), "Tiro 1 no debe ser eléctrico")
	assert_false(lonko._es_tiro_electrico(2), "Tiro 2 no debe ser eléctrico")
	assert_true(lonko._es_tiro_electrico(3), "Tiro 3 debe ser eléctrico")
	assert_false(lonko._es_tiro_electrico(4), "Tiro 4 no debe ser eléctrico")
	assert_true(lonko._es_tiro_electrico(6), "Tiro 6 debe ser eléctrico")

	# Boundary: valores inválidos nunca eléctricos
	assert_false(lonko._es_tiro_electrico(0), "Tiro 0 (inválido) no debe ser eléctrico")
	assert_false(lonko._es_tiro_electrico(-3), "Tiro negativo no debe ser eléctrico")

	# Boundary: cada_cuantos_tiros_electrico inválido desactiva el ataque
	lonko.cada_cuantos_tiros_electrico = 0
	assert_false(lonko._es_tiro_electrico(3), "Con cadencia 0 el ataque eléctrico queda desactivado")

	lonko.queue_free()
	await get_tree().process_frame
