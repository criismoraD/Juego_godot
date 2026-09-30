extends "res://addons/gut/test.gd"

## Tests unitarios del eje del misil submarino respecto a la protagonista.
## El misil debe caer sobre el eje de la canoa (alcanzable por las flechas) y
## su hitbox debe permanecer sobre el cuerpo durante todo el giro de caída:
## si la colisión orbita fuera del modelo, en parte del giro no se le puede
## hacer daño.

const ESCENA_MISIL: PackedScene = preload("res://Entities/Proyectil_Misil_Submarino/MisilSubmarino.tscn")
const MARGEN_FLOAT: float = 0.05


func _crear_misil() -> MisilSubmarino:
	var misil: MisilSubmarino = ESCENA_MISIL.instantiate() as MisilSubmarino
	add_child_autofree(misil)
	return misil


func test_colision_centrada_en_el_pivote() -> void:
	# Arrange & Act
	var misil: MisilSubmarino = _crear_misil()

	# Assert
	var colision: CollisionShape3D = misil.find_child("CollisionShape3D", true, false) as CollisionShape3D
	assert_not_null(colision, "Debe existir CollisionShape3D")
	assert_almost_eq(colision.position.x, 0.0, MARGEN_FLOAT, "Hitbox centrada en X")
	assert_almost_eq(colision.position.y, 0.0, MARGEN_FLOAT, "Hitbox centrada en Y")
	assert_almost_eq(colision.position.z, 0.0, MARGEN_FLOAT, "Hitbox centrada en Z")


func test_hitbox_no_orbita_durante_el_giro_de_caida() -> void:
	# Arrange
	var misil: MisilSubmarino = _crear_misil()
	misil.global_position = Vector3(10.0, 8.0, 3.5)
	var colision: CollisionShape3D = misil.find_child("CollisionShape3D", true, false) as CollisionShape3D

	# Act: girar como en Fase.CAIDA y medir el peor desvío (con frames para
	# propagar las transformadas globales como en juego)
	var max_desvio: float = 0.0
	for i in range(12):
		misil.rotation.y += TAU / 12.0
		misil.rotation.z += TAU / 18.0
		await get_tree().process_frame
		var centro: Vector3 = colision.global_transform.origin
		max_desvio = maxf(max_desvio, Vector2(centro.x - 10.0, centro.z - 3.5).length())

	# Assert: la hitbox no debe salir del cuerpo en ningún punto del giro
	assert_lt(max_desvio, 0.1, "La hitbox debe permanecer sobre el eje durante todo el giro")


func test_caida_sigue_el_eje_de_la_canoa() -> void:
	# Arrange: canoa (eje de la protagonista) en X=10, Z=3.5
	var misil: MisilSubmarino = _crear_misil()
	var canoa := Node3D.new()
	add_child_autofree(canoa)
	canoa.global_position = Vector3(10.0, 0.0, 3.5)
	misil.fijar_objetivo_canoa(canoa, 0.3, 0.3)

	# Act
	misil.iniciar_caida()

	# Assert: cae sobre el eje X/Z de la canoa
	assert_almost_eq(misil.global_position.x, 10.3, MARGEN_FLOAT, "X sobre el eje de la canoa")
	assert_almost_eq(misil.global_position.z, 3.5, MARGEN_FLOAT, "Z sobre el eje de la canoa")

	# Act: la canoa avanza y el misil la sigue en el mismo eje
	canoa.global_position.x = 12.0
	misil._physics_process(0.1)

	# Assert
	assert_almost_eq(misil.global_position.x, 12.3, MARGEN_FLOAT, "Sigue el eje X de la canoa")
	assert_almost_eq(misil.global_position.z, 3.5, MARGEN_FLOAT, "Mantiene el eje Z de la canoa")


func test_misil_recibe_dano_y_muere() -> void:
	# Arrange
	var misil: MisilSubmarino = _crear_misil()

	# Act: impacto de flecha (1 de vida)
	misil.take_damage(1.0)

	# Assert
	assert_true(misil._muerto, "El misil debe morir con 1 de daño")
	assert_eq(misil.fase, MisilSubmarino.Fase.IMPACTADO, "Debe quedar en fase IMPACTADO")
