extends "res://addons/gut/test.gd"

## Test de regresion para verificar que los modelos de piso importados
## tengan su origen centrado en X=0 y coincidan con la colision.

func test_piso_textura_mejorada_centrado_en_x() -> void:
	# Arrange
	var scene: PackedScene = load("res://Entities/Ambiente_Piso/Piso textura mejorada/Piso textura mejorada.glb")
	assert_not_null(scene, "La escena Piso textura mejorada.glb debe cargar correctamente")
	
	# Act
	var instance: Node3D = scene.instantiate() as Node3D
	add_child_autofree(instance)
	var mesh_node: MeshInstance3D = null
	for child in instance.find_children("*", "MeshInstance3D", true, false):
		mesh_node = child as MeshInstance3D
		break
	
	# Assert
	assert_not_null(mesh_node, "Debe existir un MeshInstance3D dentro del glb")
	assert_almost_eq(mesh_node.position.x, 0.0, 0.001, "El offset local en X de la malla debe ser 0 para coincidir con la colision")
	assert_almost_eq(mesh_node.position.z, 0.0, 0.001, "El offset local en Z de la malla debe ser 0")

func test_piso_textura_tierra_centrado_en_x() -> void:
	# Arrange
	var scene: PackedScene = load("res://Entities/Ambiente_Piso/Piso textura tierra/Piso textura tierra.glb")
	assert_not_null(scene, "La escena Piso textura tierra.glb debe cargar correctamente")
	
	# Act
	var instance: Node3D = scene.instantiate() as Node3D
	add_child_autofree(instance)
	var mesh_node: MeshInstance3D = null
	for child in instance.find_children("*", "MeshInstance3D", true, false):
		mesh_node = child as MeshInstance3D
		break
	
	# Assert
	assert_not_null(mesh_node, "Debe existir un MeshInstance3D dentro del glb")
	assert_almost_eq(mesh_node.position.x, 0.0, 0.001, "El offset local en X de la malla de tierra debe ser 0")
	assert_almost_eq(mesh_node.position.z, 0.0, 0.001, "El offset local en Z de la malla de tierra debe ser 0")
