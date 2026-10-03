extends GutTest

const ESCENA_SUELO: PackedScene = preload("res://Entities/Ambiente_Piso/SueloColision.tscn")


func test_tamano_por_defecto_sincroniza_colision_y_malla() -> void:
	# Arrange
	var suelo: StaticBody3D = ESCENA_SUELO.instantiate()
	add_child(suelo)
	await get_tree().process_frame
	# Act
	var forma: BoxShape3D = (suelo.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
	var malla: BoxMesh = (suelo.get_node("Visual") as MeshInstance3D).mesh as BoxMesh
	# Assert
	assert_eq(forma.size, suelo.tamano)
	assert_eq(malla.size, suelo.tamano)
	suelo.queue_free()


func test_cambiar_tamano_actualiza_colision() -> void:
	# Arrange
	var suelo: StaticBody3D = ESCENA_SUELO.instantiate()
	add_child(suelo)
	await get_tree().process_frame
	# Act
	suelo.tamano = Vector3(10.0, 2.0, 6.0)
	await get_tree().process_frame
	var forma: BoxShape3D = (suelo.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
	# Assert
	assert_eq(forma.size, Vector3(10.0, 2.0, 6.0))
	assert_almost_eq(suelo.obtener_y_superior(), suelo.global_position.y + 1.0, 0.001)
	suelo.queue_free()


func test_tamano_minimo_clampeado() -> void:
	# Arrange
	var suelo: StaticBody3D = ESCENA_SUELO.instantiate()
	add_child(suelo)
	await get_tree().process_frame
	# Act: valores inválidos / cero deben clamparse al mínimo
	suelo.tamano = Vector3.ZERO
	# Assert
	assert_true(suelo.tamano.x >= 0.1)
	assert_true(suelo.tamano.y >= 0.1)
	assert_true(suelo.tamano.z >= 0.1)
	suelo.queue_free()


func test_instancias_no_comparten_forma() -> void:
	# Arrange + Act: dos suelos con distinto tamaño no deben pisarse
	var suelo_a: StaticBody3D = ESCENA_SUELO.instantiate()
	var suelo_b: StaticBody3D = ESCENA_SUELO.instantiate()
	add_child(suelo_a)
	add_child(suelo_b)
	await get_tree().process_frame
	suelo_a.tamano = Vector3(5.0, 1.0, 4.0)
	suelo_b.tamano = Vector3(20.0, 1.0, 4.0)
	await get_tree().process_frame
	var forma_a: BoxShape3D = (suelo_a.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
	var forma_b: BoxShape3D = (suelo_b.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
	# Assert
	assert_eq(forma_a.size.x, 5.0)
	assert_eq(forma_b.size.x, 20.0)
	suelo_a.queue_free()
	suelo_b.queue_free()
