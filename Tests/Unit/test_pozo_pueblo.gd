extends "res://addons/gut/test.gd"

## Test de integración y visualización para Pozo:
## Verifica la carga de escena, asignación de material con textura Pozo_D,
## capas visuales y presencia en NivelPueblo.

const SCRIPT_POZO: GDScript = preload("res://Entities/Ambiente_Pozo/Pozo.gd")
const SCENE_POZO: PackedScene = preload("res://Entities/Ambiente_Pozo/Pozo.tscn")
const MATERIAL_POZO: StandardMaterial3D = preload("res://Entities/Ambiente_Pozo/Pozo_Mat.tres")

func test_pozo_instancia_correctamente_con_material_y_capa():
	# Arrange
	var pozo: Node3D = SCENE_POZO.instantiate() as Node3D
	add_child_autofree(pozo)
	
	# Act & Assert
	assert_not_null(pozo, "El nodo Pozo debe instanciarse")
	assert_not_null(pozo.get("material_pozo"), "El material_pozo debe estar asignado")
	assert_eq(pozo.get("capa_visual"), 1, "La capa visual por defecto debe ser 1 (primer plano)")
	
	var meshes: Array[Node] = pozo.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "Debe tener al menos una MeshInstance3D")
	for m in meshes:
		var mi: MeshInstance3D = m as MeshInstance3D
		assert_eq(mi.layers, 1, "Las mallas por defecto deben estar en capa 1")
		assert_eq(mi.material_override, pozo.get("material_pozo"), "El material_override debe ser el material configurado")


func test_pozo_aplica_capa_fondo():
	# Arrange
	var pozo: Node3D = SCENE_POZO.instantiate() as Node3D
	pozo.name = "Pozo fondo"
	add_child_autofree(pozo)
	
	# Act & Assert
	assert_eq(pozo.get("capa_visual"), 2, "Un nodo con 'fondo' en su nombre debe adoptar capa 2")
	var meshes: Array[Node] = pozo.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "Debe tener mallas")
	for m in meshes:
		var mi: MeshInstance3D = m as MeshInstance3D
		assert_eq(mi.layers, 2, "Las mallas deben configurarse con capa 2")


func test_pozo_presente_en_nivel_pueblo():
	# Arrange
	var scene: PackedScene = load("res://Levels/Nivel_Pueblo/NivelPueblo.tscn")
	assert_not_null(scene, "La escena NivelPueblo debe existir")
	
	# Act
	var nivel: Node = scene.instantiate()
	add_child_autofree(nivel)
	
	# Assert
	var pozo_en_nivel: Node = nivel.find_child("Pozo", true, false)
	assert_not_null(pozo_en_nivel, "Debe existir un nodo 'Pozo' en el nivel pueblo")
	var meshes: Array[Node] = pozo_en_nivel.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "El pozo en el nivel debe contener su malla 3D")
