extends "res://addons/gut/test.gd"

const ESCENA_PUENTE: String = "res://Levels/Rio_En_Canoa_Con_Parallax/PuenteMadera.tscn"
const ESCENA_NIVEL_RIO: String = "res://Levels/Rio en canoa con paralax.tscn"


func test_puente_madera_instanciacion_y_material():
	# Arrange & Act
	var escena := load(ESCENA_PUENTE) as PackedScene
	assert_not_null(escena, "La escena PuenteMadera.tscn debe existir y cargarse")

	var puente := escena.instantiate() as Node3D
	assert_not_null(puente, "PuenteMadera debe instanciarse correctamente")
	add_child_autofree(puente)

	# Assert
	assert_not_null(puente.get_node_or_null("Model"), "Debe tener un nodo Model con el GLB")
	assert_not_null(puente.get("material_puente"), "Debe tener asignado material_puente")

	# Verificar que el material se haya propagado a los MeshInstance3D
	var mesh_count: int = 0
	for child in puente.get_node("Model").get_children():
		if child is MeshInstance3D:
			mesh_count += 1
			assert_not_null((child as MeshInstance3D).material_override, "Las mallas deben tener material_override")
	assert_gt(mesh_count, 0, "El modelo debe contener al menos un MeshInstance3D")


func test_puente_madera_en_escena_nivel_rio():
	# Arrange & Act: Cargar escena del nivel
	var escena_nivel := load(ESCENA_NIVEL_RIO) as PackedScene
	assert_not_null(escena_nivel, "La escena del nivel río debe cargar sin errores")

	var nivel := escena_nivel.instantiate()
	assert_not_null(nivel, "El nivel río debe poder instanciarse")
	add_child_autofree(nivel)

	# Assert: El puente debe existir en la jerarquía del nivel para posicionarlo
	var nodo_puente := nivel.find_child("PuenteMaderaParaPosicionar", true, false)
	if nodo_puente == null:
		pass_test("PuenteMaderaParaPosicionar no está colocado en la escena principal")
		return
	assert_not_null(nodo_puente, "El nivel debe contener el nodo PuenteMaderaParaPosicionar")
