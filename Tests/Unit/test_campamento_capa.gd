extends "res://addons/gut/test.gd"

## Test de asignacion de capa visual para Campamento:
## Verifica que Campamento asigne la capa visual 2 (fondo DOF difuminado por distancia)
## a todas sus mallas hijas.

func test_campamento_capa_visual_por_defecto_es_2():
	# Arrange
	var scene: PackedScene = load("res://Entities/Ambiente_Campamento/Campamento.tscn")
	assert_not_null(scene, "La escena Campamento.tscn debe cargar")
	
	# Act
	var campamento: Campamento = scene.instantiate() as Campamento
	add_child_autofree(campamento)
	
	# Assert
	assert_eq(campamento.capa_visual, 2, "La propiedad capa_visual debe ser 2 por defecto")
	var meshes: Array[Node] = campamento.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "Campamento debe tener al menos una MeshInstance3D")
	for m in meshes:
		var mesh_instance := m as MeshInstance3D
		assert_eq(mesh_instance.layers, 2, "Cada MeshInstance3D en Campamento debe tener layers = 2")

func test_campamento_en_nivel_pueblo_esta_en_capa_2():
	# Arrange
	var scene: PackedScene = load("res://Levels/Nivel_Pueblo/NivelPueblo.tscn")
	assert_not_null(scene, "La escena NivelPueblo debe cargar")
	
	# Act
	var nivel: Node = scene.instantiate()
	add_child_autofree(nivel)
	var campamento: Node = nivel.find_child("Campamento", true, false)
	
	# Assert
	assert_not_null(campamento, "Debe existir el nodo Campamento en NivelPueblo")
	var meshes: Array[Node] = campamento.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "El campamento en NivelPueblo debe tener mallas")
	for m in meshes:
		var mesh_instance := m as MeshInstance3D
		assert_eq(mesh_instance.layers, 2, "Las mallas del campamento en NivelPueblo deben estar en la capa 2")
