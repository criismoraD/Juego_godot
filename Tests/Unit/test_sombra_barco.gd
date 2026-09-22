extends "res://addons/gut/test.gd"

## Tests de la sombra del barco (máscara de sombra sobre el Naufragio del río).

const ESCENA_RIO_PATH: String = "res://Levels/Rio en canoa con paralax.tscn"


func test_sombra_barco_en_nivel_rio() -> void:
	# Arrange & Act
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	assert_not_null(packed, "La escena del río debe cargar")
	var nivel: Node3D = packed.instantiate() as Node3D
	assert_not_null(nivel, "La escena debe instanciarse")
	add_child_autofree(nivel)

	# Assert: nodo posicionable como las demás sombras del nivel
	var sombra := nivel.find_child("Sombra Barco", true, false) as MeshInstance3D
	assert_not_null(sombra, "Debe existir Sombra Barco en el nivel")
	assert_true(sombra.mesh is QuadMesh, "Debe ser un quad como SombraArco")
	var mat := sombra.material_override as StandardMaterial3D
	assert_not_null(mat, "Debe tener material propio")
	assert_not_null(mat.albedo_texture, "El material debe usar una textura")
	assert_true("mascara barco" in mat.albedo_texture.resource_path, "Debe usar TEST_/mascara barco.png")

	# Assert: junto al Naufragio (barco varado, x ≈ 64.8)
	assert_gt(sombra.global_position.x, 55.0, "La sombra debe estar en la zona del barco")
	assert_lt(sombra.global_position.x, 75.0, "La sombra debe estar en la zona del barco")
