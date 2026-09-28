extends "res://addons/gut/test.gd"

## Test unitario y de integración para Zapayo en NivelPueblo:
## Verifica la carga de escena, asignación de material con textura,
## la animación de balanceo pendular por código y su presencia en NivelPueblo.

const SCENE_ZAPAYO: PackedScene = preload("res://Levels/Rio_En_Canoa_Con_Parallax/Zapayo.tscn")
const MATERIAL_ZAPAYO: StandardMaterial3D = preload("res://Levels/Rio_En_Canoa_Con_Parallax/Zapayo_Mat.tres")

func test_zapayo_instancia_correctamente_con_material_y_capa():
	# Arrange
	var zapayo: ZapayoColgante = SCENE_ZAPAYO.instantiate() as ZapayoColgante
	add_child_autofree(zapayo)

	# Act & Assert
	assert_not_null(zapayo, "El nodo Zapayo debe instanciarse")
	assert_not_null(zapayo.material_zapayo, "El material_zapayo debe estar configurado")
	assert_eq(zapayo.capa_visual, 1, "La capa visual por defecto debe ser 1")

	var meshes: Array[Node] = zapayo.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "Debe tener al menos una MeshInstance3D")
	for m in meshes:
		var mi: MeshInstance3D = m as MeshInstance3D
		assert_eq(mi.layers, 1, "Las mallas deben configurarse con la capa visual indicada")
		assert_eq(mi.material_override, zapayo.material_zapayo, "El material_override debe ser el material del zapayo")


func test_zapayo_animacion_balanceo_funciona():
	# Arrange
	var zapayo: ZapayoColgante = SCENE_ZAPAYO.instantiate() as ZapayoColgante
	add_child_autofree(zapayo)
	assert_not_null(zapayo.colgante, "Debe tener el nodo pivote Colgante")

	var rot_inicial: Vector3 = zapayo.colgante.rotation

	# Act
	zapayo._process(0.5)
	var rot_animada: Vector3 = zapayo.colgante.rotation

	# Assert
	assert_ne(rot_animada, rot_inicial, "La rotación del nodo Colgante debe cambiar con el paso del tiempo al estar animado")

	# Test caso inactivo (Early return)
	zapayo.animacion_activa = false
	var rot_fija: Vector3 = zapayo.colgante.rotation
	zapayo._process(0.5)
	assert_eq(zapayo.colgante.rotation, rot_fija, "Si la animación está inactiva no debe rotar")


func test_zapayo_presente_en_nivel_pueblo():
	# Arrange
	var scene: PackedScene = load("res://Levels/Nivel_Pueblo/NivelPueblo.tscn")
	assert_not_null(scene, "La escena NivelPueblo debe existir")

	# Act
	var nivel: Node = scene.instantiate()
	add_child_autofree(nivel)

	# Assert
	var zapayo_en_nivel: Node = nivel.find_child("Zapayo", true, false)
	assert_not_null(zapayo_en_nivel, "Debe existir un nodo 'Zapayo' en NivelPueblo")
	var meshes: Array[Node] = zapayo_en_nivel.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "El Zapayo en el nivel debe contener su malla 3D")
