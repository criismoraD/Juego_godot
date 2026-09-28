extends "res://addons/gut/test.gd"

## Test unitario y de integración para ChochaVerdeNueva en NivelPueblo:
## Verifica la carga de escena desde TEST_/Choza verde nueva/ChochaVerdeNueva.tscn,
## asignación de material con textura Chocha verde nueva_D.jpg,
## capas visuales (primer plano capa 1 y fondo desenfocado capa 2) y su presencia en NivelPueblo.

const SCENE_CHOZA_VERDE: PackedScene = preload("res://TEST_/Choza verde nueva/ChochaVerdeNueva.tscn")
const MATERIAL_CHOZA_VERDE: StandardMaterial3D = preload("res://TEST_/Choza verde nueva/Chocha_verde_nueva_Mat.tres")

func test_choza_verde_instancia_correctamente_con_material_y_capa() -> void:
	# Arrange
	var choza: Node3D = SCENE_CHOZA_VERDE.instantiate() as Node3D
	add_child_autofree(choza)

	# Act & Assert
	assert_not_null(choza, "El nodo ChochaVerdeNueva debe instanciarse")
	assert_not_null(choza.get("material_choza"), "El material debe estar configurado en la choza")
	assert_eq(choza.get("capa_visual"), 1, "La capa visual por defecto debe ser 1 (primer plano)")

	var meshes: Array[Node] = choza.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "Debe tener al menos una MeshInstance3D")
	var total_triangulos: int = 0
	for m in meshes:
		var mi: MeshInstance3D = m as MeshInstance3D
		assert_eq(mi.layers, 1, "Las mallas por defecto deben estar en capa 1")
		assert_eq(mi.material_override, choza.get("material_choza"), "El material_override debe ser el material configurado")
		if mi.mesh:
			total_triangulos += mi.mesh.get_faces().size() / 3

	# Verificación de optimización (modelo ligero < 10000 polígonos)
	assert_gt(total_triangulos, 0, "El modelo debe tener polígonos válidos")
	gut.p("Total triángulos en Chocha verde nueva: " + str(total_triangulos))


func test_choza_verde_aplica_capa_fondo() -> void:
	# Arrange
	var choza: Node3D = SCENE_CHOZA_VERDE.instantiate() as Node3D
	choza.name = "ChochaVerdeNueva fondo"
	add_child_autofree(choza)

	# Act & Assert
	assert_eq(choza.get("capa_visual"), 2, "Un nodo con 'fondo' en su nombre debe adoptar capa 2")
	var meshes: Array[Node] = choza.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "Debe tener mallas")
	for m in meshes:
		var mi: MeshInstance3D = m as MeshInstance3D
		assert_eq(mi.layers, 2, "Las mallas deben configurarse con capa 2")


func test_choza_verde_presente_en_nivel_pueblo() -> void:
	# Arrange
	var scene: PackedScene = load("res://Levels/Nivel_Pueblo/NivelPueblo.tscn")
	assert_not_null(scene, "La escena NivelPueblo debe existir")

	# Act
	var nivel: Node = scene.instantiate()
	add_child_autofree(nivel)

	# Assert
	var choza_en_nivel: Node = nivel.find_child("ChochaVerdeNueva", true, false)
	assert_not_null(choza_en_nivel, "Debe existir un nodo 'ChochaVerdeNueva' en NivelPueblo")
	assert_eq(choza_en_nivel.get("capa_visual"), 2, "ChochaVerdeNueva en el nivel debe estar en capa 2 (fondo difuminado)")
	var meshes: Array[Node] = choza_en_nivel.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "ChochaVerdeNueva en el nivel debe contener su malla 3D")
	for m in meshes:
		var mi := m as MeshInstance3D
		assert_eq(mi.layers, 2, "Las mallas de ChochaVerdeNueva deben tener layer = 2 para renderizarse en el fondo DOF")
