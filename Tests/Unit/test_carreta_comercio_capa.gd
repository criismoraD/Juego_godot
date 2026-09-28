extends "res://addons/gut/test.gd"

## Test de asignación de capa visual para CarretaComercio:
## Verifica que CarretaComercio fondo esté en la capa visual 2 (fondo DOF difuminado)
## y que la CarretaComercio frontal permanezca en la capa visual 1 (nítida).

const SCRIPT_CARRETA: GDScript = preload("res://Entities/Ambiente_CarretaComercio/CarretaComercio.gd")
const SCENE_CARRETA: PackedScene = preload("res://Entities/Ambiente_CarretaComercio/CarretaComercio.tscn")

func test_carreta_comercio_capa_por_defecto_es_1():
	# Arrange
	var carreta := SCENE_CARRETA.instantiate() as CarretaComercio
	add_child_autofree(carreta)
	
	# Assert
	assert_eq(carreta.capa_visual, 1, "La capa visual por defecto debe ser 1 (primer plano)")
	var meshes: Array[Node] = carreta.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "Debe tener al menos una MeshInstance3D")
	for m in meshes:
		var mi := m as MeshInstance3D
		assert_eq(mi.layers, 1, "Las mallas por defecto deben estar en capa 1")


func test_carreta_comercio_con_nombre_fondo_asigna_capa_2():
	# Arrange
	var carreta := SCENE_CARRETA.instantiate() as CarretaComercio
	carreta.name = "CarretaComercio fondo"
	add_child_autofree(carreta)
	
	# Assert
	assert_eq(carreta.capa_visual, 2, "Un nodo con 'fondo' en el nombre debe pasar a capa 2")
	var meshes: Array[Node] = carreta.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "Debe tener mallas")
	for m in meshes:
		var mi := m as MeshInstance3D
		assert_eq(mi.layers, 2, "Las mallas de la carreta de fondo deben estar en capa 2")


func test_nivel_pueblo_carreta_fondo_en_capa_2_y_frontal_en_capa_1():
	# Arrange
	var scene: PackedScene = load("res://Levels/Nivel_Pueblo/NivelPueblo.tscn")
	assert_not_null(scene, "La escena NivelPueblo debe cargar")
	
	# Act
	var nivel: Node = scene.instantiate()
	add_child_autofree(nivel)
	
	var carreta_frontal: Node = nivel.find_child("CarretaComercio", true, false)
	var carreta_fondo: Node = nivel.find_child("CarretaComercio fondo", true, false)
	
	# Assert Carreta Fondo
	assert_not_null(carreta_fondo, "Debe existir 'CarretaComercio fondo' en NivelPueblo")
	var meshes_fondo: Array[Node] = carreta_fondo.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes_fondo.size(), 0, "Carreta fondo debe tener mallas")
	for m in meshes_fondo:
		var mi := m as MeshInstance3D
		assert_eq(mi.layers, 2, "Mallas de CarretaComercio fondo deben tener layers = 2 (difuminado)")
		
	# Assert Carreta Frontal
	assert_not_null(carreta_frontal, "Debe existir 'CarretaComercio' frontal en NivelPueblo")
	var meshes_frontal: Array[Node] = carreta_frontal.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes_frontal.size(), 0, "Carreta frontal debe tener mallas")
	for m in meshes_frontal:
		var mi := m as MeshInstance3D
		assert_eq(mi.layers, 1, "Mallas de CarretaComercio frontal deben tener layers = 1 (nítido)")
