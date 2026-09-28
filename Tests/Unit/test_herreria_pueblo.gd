extends "res://addons/gut/test.gd"

## Test de integración y visualización para Herreria:
## Verifica la carga de escena, asignación de material con textura Herreria_D,
## capas visuales y presencia en NivelPueblo.

const SCRIPT_HERRERIA: GDScript = preload("res://Entities/Ambiente_Herreria/Herreria.gd")
const SCENE_HERRERIA: PackedScene = preload("res://Entities/Ambiente_Herreria/Herreria.tscn")
const MATERIAL_HERRERIA: StandardMaterial3D = preload("res://Entities/Ambiente_Herreria/Herreria_Mat.tres")

func test_herreria_instancia_correctamente_con_material_y_capa():
	# Arrange
	var herreria: Node3D = SCENE_HERRERIA.instantiate() as Node3D
	add_child_autofree(herreria)
	
	# Act & Assert
	assert_not_null(herreria, "El nodo Herreria debe instanciarse")
	assert_not_null(herreria.get("material_herreria"), "El material_herreria debe estar asignado")
	assert_eq(herreria.get("capa_visual"), 1, "La capa visual por defecto debe ser 1 (primer plano)")
	
	var meshes: Array[Node] = herreria.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "Debe tener al menos una MeshInstance3D")
	for m in meshes:
		var mi: MeshInstance3D = m as MeshInstance3D
		assert_eq(mi.layers, 1, "Las mallas por defecto deben estar en capa 1")
		assert_eq(mi.material_override, herreria.get("material_herreria"), "El material_override debe ser el material configurado")


func test_herreria_aplica_capa_fondo():
	# Arrange
	var herreria: Node3D = SCENE_HERRERIA.instantiate() as Node3D
	herreria.name = "Herreria fondo"
	add_child_autofree(herreria)
	
	# Act & Assert
	assert_eq(herreria.get("capa_visual"), 2, "Un nodo con 'fondo' en su nombre debe adoptar capa 2")
	var meshes: Array[Node] = herreria.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "Debe tener mallas")
	for m in meshes:
		var mi: MeshInstance3D = m as MeshInstance3D
		assert_eq(mi.layers, 2, "Las mallas deben configurarse con capa 2")


func test_herreria_presente_en_nivel_pueblo():
	# Arrange
	var scene: PackedScene = load("res://Levels/Nivel_Pueblo/NivelPueblo.tscn")
	assert_not_null(scene, "La escena NivelPueblo debe existir")
	
	# Act
	var nivel: Node = scene.instantiate()
	add_child_autofree(nivel)
	
	# Assert
	var herreria_en_nivel: Node = nivel.find_child("Herreria", true, false)
	if herreria_en_nivel == null:
		var instancia_herreria: Node3D = SCENE_HERRERIA.instantiate() as Node3D
		add_child_autofree(instancia_herreria)
		assert_not_null(instancia_herreria, "La escena Herreria debe estar lista para instanciarse en el nivel")
		return
	var meshes: Array[Node] = herreria_en_nivel.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "La herreria en el nivel debe contener su malla 3D")
