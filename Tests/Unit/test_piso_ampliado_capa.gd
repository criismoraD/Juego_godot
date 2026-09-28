extends "res://addons/gut/test.gd"

## Test para verificar que solo el nodo "piso ampliado" esté en la Capa 2 (fondo DOF),
## y que los demás pisos normales permanezcan en la capa frontal (capa 1).

func test_solo_piso_ampliado_esta_en_capa_2_en_nivel_pueblo():
	# Arrange
	var scene: PackedScene = load("res://Levels/Nivel_Pueblo/NivelPueblo.tscn")
	assert_not_null(scene, "La escena NivelPueblo debe cargar")
	
	# Act
	var nivel: Node = scene.instantiate()
	add_child_autofree(nivel)
	
	var piso_ampliado: Node = nivel.find_child("piso ampliado", true, false)
	assert_not_null(piso_ampliado, "Debe existir el nodo 'piso ampliado' en NivelPueblo")
	
	# Assert: piso ampliado debe tener layers = 2 en todas sus mallas
	var mallas_ampliado: Array[Node] = piso_ampliado.find_children("*", "MeshInstance3D", true, false)
	assert_gt(mallas_ampliado.size(), 0, "piso ampliado debe tener al menos una MeshInstance3D")
	for m in mallas_ampliado:
		var mesh_instance := m as MeshInstance3D
		assert_eq(mesh_instance.layers, 2, "La malla de piso ampliado debe estar en la capa 2 (fondo DOF)")
	
	# Assert: los otros pisos normales (que no son ampliado) NO deben estar en capa 2
	var otros_pisos: Array[Node] = nivel.find_children("Piso textura mejorada*", "Node3D", true, false)
	assert_gt(otros_pisos.size(), 0, "Deben existir otros pisos normales")
	for otro in otros_pisos:
		if "ampliado" in otro.name.to_lower():
			continue
		var mallas_otro: Array[Node] = otro.find_children("*", "MeshInstance3D", true, false)
		for m in mallas_otro:
			var mesh_instance := m as MeshInstance3D
			assert_ne(mesh_instance.layers, 2, "El piso normal '%s' NO debe estar en capa 2" % otro.name)
