extends "res://addons/gut/test.gd"

## Test de integración y visualización para CampamentoMercenario:
## Verifica la carga de escena, asignación de material con textura Campamento mercenario_D,
## capas visuales y presencia en NivelPueblo.

const SCRIPT_CAMPAMENTO: GDScript = preload("res://Entities/Ambiente_CampamentoMercenario/CampamentoMercenario.gd")
const SCENE_CAMPAMENTO: PackedScene = preload("res://Entities/Ambiente_CampamentoMercenario/CampamentoMercenario.tscn")
const MATERIAL_CAMPAMENTO: StandardMaterial3D = preload("res://Entities/Ambiente_CampamentoMercenario/CampamentoMercenario_Mat.tres")

func test_campamento_mercenario_instancia_correctamente_con_material_y_capa():
	# Arrange
	var campamento: Node3D = SCENE_CAMPAMENTO.instantiate() as Node3D
	add_child_autofree(campamento)
	
	# Act & Assert
	assert_not_null(campamento, "El nodo CampamentoMercenario debe instanciarse")
	assert_not_null(campamento.get("material_campamento"), "El material_campamento debe estar asignado")
	assert_eq(campamento.get("capa_visual"), 1, "La capa visual por defecto debe ser 1 (primer plano)")
	
	var meshes: Array[Node] = campamento.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "Debe tener al menos una MeshInstance3D")
	for m in meshes:
		var mi: MeshInstance3D = m as MeshInstance3D
		assert_eq(mi.layers, 1, "Las mallas por defecto deben estar en capa 1")
		assert_eq(mi.material_override, campamento.get("material_campamento"), "El material_override debe ser el material configurado")


func test_campamento_mercenario_aplica_capa_fondo():
	# Arrange
	var campamento: Node3D = SCENE_CAMPAMENTO.instantiate() as Node3D
	campamento.name = "CampamentoMercenario fondo"
	add_child_autofree(campamento)
	
	# Act & Assert
	assert_eq(campamento.get("capa_visual"), 2, "Un nodo con 'fondo' en su nombre debe adoptar capa 2")
	var meshes: Array[Node] = campamento.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "Debe tener mallas")
	for m in meshes:
		var mi: MeshInstance3D = m as MeshInstance3D
		assert_eq(mi.layers, 2, "Las mallas deben configurarse con capa 2")


func test_campamento_mercenario_presente_en_nivel_pueblo():
	# Arrange
	var scene: PackedScene = load("res://Levels/Nivel_Pueblo/NivelPueblo.tscn")
	assert_not_null(scene, "La escena NivelPueblo debe existir")
	
	# Act
	var nivel: Node = scene.instantiate()
	add_child_autofree(nivel)
	
	# Assert
	var campamento_en_nivel: Node = nivel.find_child("CampamentoMercenario", true, false)
	assert_not_null(campamento_en_nivel, "Debe existir un nodo 'CampamentoMercenario' en el nivel pueblo")
	var meshes: Array[Node] = campamento_en_nivel.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "El campamento mercenario en el nivel debe contener su malla 3D")
