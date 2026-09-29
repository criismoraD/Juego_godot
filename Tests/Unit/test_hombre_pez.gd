extends "res://addons/gut/test.gd"

## Test de integración, visualización y animación para HombrePez:
## Verifica la carga de escena, asignación de material con textura HombrePez_D,
## capas visuales, presencia en NivelPueblo y la animación procedural de respiración.

const SCRIPT_HOMBRE_PEZ: GDScript = preload("res://Entities/Ambiente_HombrePez/HombrePez.gd")
const SCENE_HOMBRE_PEZ: PackedScene = preload("res://Entities/Ambiente_HombrePez/HombrePez.tscn")
const MATERIAL_HOMBRE_PEZ: StandardMaterial3D = preload("res://Entities/Ambiente_HombrePez/HombrePez_Mat.tres")
const SCENE_PUEBLO: PackedScene = preload("res://Levels/Nivel_Pueblo/NivelPueblo.tscn")

func test_hombre_pez_instancia_correctamente_con_material_y_capa():
	# Arrange
	var hombre_pez: Node3D = SCENE_HOMBRE_PEZ.instantiate() as Node3D
	add_child_autofree(hombre_pez)
	
	# Act & Assert
	assert_not_null(hombre_pez, "El nodo HombrePez debe instanciarse")
	assert_not_null(hombre_pez.get("material_hombre_pez"), "El material_hombre_pez debe estar asignado")
	assert_eq(hombre_pez.get("capa_visual"), 1, "La capa visual por defecto debe ser 1 (primer plano)")
	
	var meshes: Array[Node] = hombre_pez.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "Debe tener al menos una MeshInstance3D")
	for m in meshes:
		var mi: MeshInstance3D = m as MeshInstance3D
		assert_eq(mi.layers, 1, "Las mallas por defecto deben estar en capa 1")
		assert_eq(mi.material_override, hombre_pez.get("material_hombre_pez"), "El material_override debe ser el material configurado")


func test_hombre_pez_aplica_capa_fondo():
	# Arrange
	var hombre_pez: Node3D = SCENE_HOMBRE_PEZ.instantiate() as Node3D
	hombre_pez.name = "HombrePez fondo"
	add_child_autofree(hombre_pez)
	
	# Act & Assert
	assert_eq(hombre_pez.get("capa_visual"), 2, "Un nodo con 'fondo' en su nombre debe adoptar capa 2")
	var meshes: Array[Node] = hombre_pez.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "Debe tener mallas")
	for m in meshes:
		var mi: MeshInstance3D = m as MeshInstance3D
		assert_eq(mi.layers, 2, "Las mallas deben configurarse con capa 2")


func test_hombre_pez_animacion_respiracion_estira_verticalmente():
	# Arrange
	var hombre_pez: Node3D = SCENE_HOMBRE_PEZ.instantiate() as Node3D
	add_child_autofree(hombre_pez)
	var modelo: Node3D = hombre_pez.get_node_or_null("Model") as Node3D
	assert_not_null(modelo, "Debe existir el nodo Model dentro de HombrePez")
	
	# Act - Simular paso del tiempo para inhalación (pico de respiración)
	hombre_pez.set("previsualizar_en_editor", true)
	# Medio ciclo de respiración: pi / (2 * velocidad_respiracion) = pi / 4 ~ 0.785 s
	var delta_cuarto_ciclo: float = (PI * 0.5) / float(hombre_pez.get("velocidad_respiracion"))
	hombre_pez._process(delta_cuarto_ciclo)
	
	# Assert
	var escala_actual: Vector3 = modelo.scale
	assert_gt(escala_actual.y, 1.0, "La escala Y debe haber aumentado en inhalación (estiramiento superior)")
	assert_gt(escala_actual.x, 1.0, "La escala X debe haber expandido sutilmente el torso")
	assert_gt(escala_actual.z, 1.0, "La escala Z debe haber expandido sutilmente el torso")
	assert_almost_eq(escala_actual.y, 1.0 + float(hombre_pez.get("amplitud_estiramiento_y")), 0.005, "El pico vertical debe coincidir con la amplitud")


func test_hombre_pez_deshabilitar_respiracion_resetea_escala():
	# Arrange
	var hombre_pez: Node3D = SCENE_HOMBRE_PEZ.instantiate() as Node3D
	add_child_autofree(hombre_pez)
	var modelo: Node3D = hombre_pez.get_node_or_null("Model") as Node3D
	hombre_pez.set("previsualizar_en_editor", true)
	hombre_pez._process(0.8)
	
	# Act
	hombre_pez.set("habilitar_respiracion", false)
	
	# Assert
	assert_eq(modelo.scale, Vector3.ONE, "Al deshabilitar la respiración, la escala debe resetearse a Vector3.ONE")


func test_hombre_pez_presente_en_nivel_pueblo():
	# Arrange & Act
	var nivel: Node = SCENE_PUEBLO.instantiate()
	add_child_autofree(nivel)
	
	# Assert
	var hombre_pez_en_nivel: Node = nivel.find_child("HombrePez", true, false)
	assert_not_null(hombre_pez_en_nivel, "Debe existir un nodo 'HombrePez' en el nivel pueblo")
	var meshes: Array[Node] = hombre_pez_en_nivel.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "El hombre pez en el nivel debe contener su malla 3D")
