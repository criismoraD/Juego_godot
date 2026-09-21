extends "res://addons/gut/test.gd"

## Tests unitarios para el impacto de flechas en la canoa y superficies móviles.
## Valida que al impactar el suelo o superficie de la canoa, la flecha se emparenta
## a ella y acompaña sus desplazamientos y balanceos en vez de quedarse estática en el mundo.

const ARROW_SCENE_PATH: String = "res://Entities/Proyectil_Flecha/Arrow.tscn"
const GOBLIN_ARROW_PATH: String = "res://Entities/Proyectil_Flecha_Goblin/GoblinArrow.tscn"
const MARGEN_FLOAT: float = 0.01


func test_flecha_se_emparenta_a_superficie_al_impactar() -> void:
	# Arrange
	var suelo := StaticBody3D.new()
	suelo.name = "SueloCanoa"
	add_child_autofree(suelo)
	suelo.global_position = Vector3(10.0, 0.0, 0.0)

	var arrow_scene := load(ARROW_SCENE_PATH) as PackedScene
	var flecha: Area3D = arrow_scene.instantiate() as Area3D
	add_child_autofree(flecha)
	flecha.global_position = Vector3(11.5, 0.2, 0.0)

	# Act: La flecha impacta contra el suelo de la canoa
	flecha._stick_to_surface(suelo)
	await wait_physics_frames(2)

	# Assert: Queda clavada y emparentada al suelo
	assert_true(flecha.is_stuck, "La flecha debe marcar is_stuck = true")
	assert_eq(flecha.get_parent(), suelo, "La flecha debe emparentarse al suelo impactado")
	assert_almost_eq(flecha.global_position.x, 11.5, MARGEN_FLOAT, "Debe preservar su posición X inicial de impacto")
	assert_almost_eq(flecha.global_position.y, 0.2, MARGEN_FLOAT, "Debe preservar su posición Y inicial de impacto")

	# Act 2: La canoa avanza y se eleva sobre el agua
	var pos_inicial_flecha: Vector3 = flecha.global_position
	suelo.global_position += Vector3(3.0, 0.15, 0.0)

	# Assert 2: La flecha se desplaza junto con la canoa manteniendo la ilusión
	var pos_final_flecha: Vector3 = flecha.global_position
	assert_almost_eq(pos_final_flecha.x - pos_inicial_flecha.x, 3.0, MARGEN_FLOAT, "La flecha debe avanzar 3m con la canoa")
	assert_almost_eq(pos_final_flecha.y - pos_inicial_flecha.y, 0.15, MARGEN_FLOAT, "La flecha debe oscilar en Y con la canoa")

	# Act 3: Al balancearse / rotar la superficie, la flecha permanece rígidamente fijada a su posición local
	var local_pos_antes: Vector3 = flecha.position
	suelo.rotation_degrees.z += 10.0
	assert_almost_eq(flecha.position.x, local_pos_antes.x, MARGEN_FLOAT, "La posición local X no cambia al balancearse la canoa")
	assert_almost_eq(flecha.position.y, local_pos_antes.y, MARGEN_FLOAT, "La posición local Y no cambia al balancearse la canoa")


func test_flecha_en_canoa_real_protagonista() -> void:
	# Arrange: Instanciar canoa protagonista con su suelo físico
	var canoa_scene := load("res://Levels/Rio_En_Canoa_Con_Parallax/CanoaProtagonistaRio.tscn") as PackedScene
	var canoa: CanoaProtagonistaRio = canoa_scene.instantiate() as CanoaProtagonistaRio
	add_child_autofree(canoa)
	canoa.global_position = Vector3(0.0, 0.0, 0.0)

	var suelo_canoa: StaticBody3D = canoa.find_child("SueloCanoa", true, false) as StaticBody3D
	assert_not_null(suelo_canoa, "La canoa debe tener su nodo SueloCanoa")

	var arrow_scene := load(ARROW_SCENE_PATH) as PackedScene
	var flecha: Area3D = arrow_scene.instantiate() as Area3D
	add_child_autofree(flecha)
	flecha.global_position = suelo_canoa.global_position + Vector3(0.3, 0.1, 0.0)

	# Act: La flecha impacta en el suelo de la canoa
	flecha._on_body_entered(suelo_canoa)
	await wait_physics_frames(2)

	# Assert
	assert_true(flecha.is_stuck, "Debe quedar clavada en la canoa")
	assert_eq(flecha.get_parent(), suelo_canoa, "Debe ser hija de SueloCanoa")

	var offset_x_local: float = flecha.position.x

	# Act 2: Mover la canoa
	canoa.global_position.x += 4.0

	# Assert 2: El offset local no cambia, la flecha viaja perfectamente anclada a la madera
	assert_almost_eq(flecha.position.x, offset_x_local, MARGEN_FLOAT, "La posición local en la canoa no debe variar")


func test_flecha_enemiga_tambien_se_emparenta_a_la_canoa() -> void:
	# Arrange
	var suelo := StaticBody3D.new()
	suelo.name = "SueloCanoa"
	add_child_autofree(suelo)
	suelo.global_position = Vector3(5.0, 0.0, 0.0)

	var goblin_arrow_scene := load(GOBLIN_ARROW_PATH) as PackedScene
	var flecha_enemiga: Area3D = goblin_arrow_scene.instantiate() as Area3D
	add_child_autofree(flecha_enemiga)
	flecha_enemiga.global_position = Vector3(5.2, 0.1, 0.0)

	# Act
	flecha_enemiga._on_body_entered(suelo)
	await wait_physics_frames(2)

	# Assert
	assert_true(flecha_enemiga.is_stuck, "La flecha enemiga debe quedar clavada")
	assert_eq(flecha_enemiga.get_parent(), suelo, "La flecha enemiga debe emparentarse a la superficie")

	# Act 2: Mover el suelo
	suelo.global_position.x += 2.5

	# Assert 2
	assert_almost_eq(flecha_enemiga.global_position.x, 7.7, MARGEN_FLOAT, "La flecha enemiga debe desplazarse junto al suelo")
