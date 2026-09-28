extends "res://addons/gut/test.gd"

## Test unitario y de integración para ChozaAzulina en NivelPueblo:
## Verifica la carga de escena, asignación de material con textura choza azulina_D,
## capas visuales (primer plano capa 1 y fondo desenfocado capa 2) y su presencia en NivelPueblo.

const SCENE_CHOZA: PackedScene = preload("res://Levels/Rio_En_Canoa_Con_Parallax/ChozaAzulina.tscn")
const MATERIAL_CHOZA: StandardMaterial3D = preload("res://Levels/Rio_En_Canoa_Con_Parallax/ChozaAzulina_Mat.tres")

func test_choza_azulina_instancia_correctamente_con_material_y_capa() -> void:
	# Arrange
	var choza: Node3D = SCENE_CHOZA.instantiate() as Node3D
	add_child_autofree(choza)

	# Act & Assert
	assert_not_null(choza, "El nodo ChozaAzulina debe instanciarse")
	assert_not_null(choza.get("material_naufragio"), "El material debe estar configurado en la choza")
	assert_eq(choza.get("capa_visual"), 1, "La capa visual por defecto debe ser 1 (primer plano)")

	var meshes: Array[Node] = choza.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "Debe tener al menos una MeshInstance3D")
	for m in meshes:
		var mi: MeshInstance3D = m as MeshInstance3D
		assert_eq(mi.layers, 1, "Las mallas por defecto deben estar en capa 1")
		assert_eq(mi.material_override, choza.get("material_naufragio"), "El material_override debe ser el material configurado")


func test_choza_azulina_aplica_capa_fondo() -> void:
	# Arrange
	var choza: Node3D = SCENE_CHOZA.instantiate() as Node3D
	choza.name = "ChozaAzulina fondo"
	add_child_autofree(choza)

	# Act & Assert
	assert_eq(choza.get("capa_visual"), 2, "Un nodo con 'fondo' en su nombre debe adoptar capa 2")
	var meshes: Array[Node] = choza.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "Debe tener mallas")
	for m in meshes:
		var mi: MeshInstance3D = m as MeshInstance3D
		assert_eq(mi.layers, 2, "Las mallas deben configurarse con capa 2")


func test_choza_azulina_presente_en_nivel_pueblo() -> void:
	# Arrange
	var scene: PackedScene = load("res://Levels/Nivel_Pueblo/NivelPueblo.tscn")
	assert_not_null(scene, "La escena NivelPueblo debe existir")

	# Act
	var nivel: Node = scene.instantiate()
	add_child_autofree(nivel)

	# Assert
	var choza_en_nivel: Node = nivel.find_child("ChozaAzulina", true, false)
	assert_not_null(choza_en_nivel, "Debe existir un nodo 'ChozaAzulina' en NivelPueblo")
	assert_eq(choza_en_nivel.get("capa_visual"), 2, "ChozaAzulina en el nivel debe estar en capa 2 (fondo difuminado)")
	var meshes: Array[Node] = choza_en_nivel.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "ChozaAzulina en el nivel debe contener su malla 3D")
	for m in meshes:
		var mi := m as MeshInstance3D
		assert_eq(mi.layers, 2, "Las mallas de ChozaAzulina deben tener layer = 2 para renderizarse en el fondo DOF")

	var choza2_en_nivel: Node = nivel.find_child("ChozaAzulina2", true, false)
	assert_not_null(choza2_en_nivel, "Debe existir un nodo 'ChozaAzulina2' en NivelPueblo")
	var meshes2: Array[Node] = choza2_en_nivel.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes2.size(), 0, "ChozaAzulina2 en el nivel debe contener su malla 3D")
