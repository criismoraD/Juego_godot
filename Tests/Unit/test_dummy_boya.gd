extends "res://addons/gut/test.gd"

## Test unitario y de integración para DummyBoya en NivelPueblo:
## Verifica la carga de escena, asignación de capa visual de renderizado 3D (Capa 1 = Frente),
## aplicación de material, lógica de flotación boya y presencia en NivelPueblo.

const SCENE_DUMMY: PackedScene = preload("res://Entities/Ambiente_Dummy/Dummy.tscn")
const MATERIAL_DUMMY: Material = preload("res://Entities/Ambiente_Dummy/Dummy_Mat.tres")


func before_all() -> void:
	if gut != null and gut.error_tracker != null:
		gut.error_tracker.treat_engine_errors_as = 0


func test_dummy_instancia_correctamente_con_capa_visual_y_material():
	# Arrange
	var dummy: DummyBoya = SCENE_DUMMY.instantiate() as DummyBoya
	add_child_autofree(dummy)

	# Act & Assert
	assert_not_null(dummy, "El nodo DummyBoya debe instanciarse")
	assert_eq(dummy.capa_visual, 1, "La capa visual por defecto debe ser 1 (Capa Frente)")

	var meshes: Array[Node] = dummy.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "Debe tener al menos una MeshInstance3D")
	for m in meshes:
		var mi: MeshInstance3D = m as MeshInstance3D
		assert_eq(mi.layers, 1, "Las mallas del dummy deben configurarse con capa visual 1")

	# Act: Cambiar capa visual dinámicamente
	dummy.capa_visual = 2
	for m in meshes:
		var mi: MeshInstance3D = m as MeshInstance3D
		assert_eq(mi.layers, 2, "Al cambiar capa_visual a 2, las mallas deben actualizarse a capa 2")


func test_dummy_flotacion_proceso():
	# Arrange
	var dummy: DummyBoya = SCENE_DUMMY.instantiate() as DummyBoya
	add_child_autofree(dummy)
	assert_not_null(dummy.modelo, "Debe existir el nodo Model")

	var pos_inicial_y: float = dummy.modelo.position.y

	# Act
	dummy._process(0.25)

	# Assert
	assert_ne(dummy.modelo.position.y, pos_inicial_y, "El modelo debe moverse con la flotación")

	# Act: Desactivar flotación
	dummy.flotacion_activa = false
	var pos_estatica_y: float = dummy.modelo.position.y
	dummy._process(0.25)
	assert_eq(dummy.modelo.position.y, pos_estatica_y, "Si flotacion_activa es falsa, no debe moverse")


func test_dummy_presente_en_nivel_pueblo():
	# Arrange
	var scene: PackedScene = load("res://Levels/Nivel_Pueblo/NivelPueblo.tscn")
	assert_not_null(scene, "La escena NivelPueblo debe existir")

	# Act
	var nivel: Node = scene.instantiate()
	add_child_autofree(nivel)

	# Assert
	var dummy1: DummyBoya = nivel.find_child("DummyBoya", true, false) as DummyBoya
	var dummy2: DummyBoya = nivel.find_child("DummyBoya2", true, false) as DummyBoya

	assert_not_null(dummy1, "Debe existir 'DummyBoya' en NivelPueblo")
	assert_not_null(dummy2, "Debe existir 'DummyBoya2' en NivelPueblo")

	assert_eq(dummy1.capa_visual, 1, "DummyBoya debe estar en capa visual 1 (Frente)")
	assert_eq(dummy2.capa_visual, 1, "DummyBoya2 debe estar en capa visual 1 (Frente)")

	var meshes1: Array[Node] = dummy1.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes1.size(), 0, "DummyBoya debe tener mallas 3D")
	for m in meshes1:
		var mi: MeshInstance3D = m as MeshInstance3D
		assert_eq(mi.layers, 1, "Las mallas de DummyBoya deben estar en capa 1")

	var meshes2: Array[Node] = dummy2.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes2.size(), 0, "DummyBoya2 debe tener mallas 3D")
	for m in meshes2:
		var mi: MeshInstance3D = m as MeshInstance3D
		assert_eq(mi.layers, 1, "Las mallas de DummyBoya2 deben estar en capa 1")


func test_dummy_detener_y_reanudar_suavemente():
	# Arrange
	var dummy: DummyBoya = SCENE_DUMMY.instantiate() as DummyBoya
	add_child_autofree(dummy)
	assert_false(dummy.esta_detenido(), "Inicialmente no debe estar detenido")
	assert_eq(dummy.obtener_factor_movimiento(), 1.0, "Factor de movimiento inicial debe ser 1.0")

	# Act: Detener suavemente
	dummy.detener_suavemente(0.2)

	# Assert: Debe marcarse como detenido
	assert_true(dummy.esta_detenido(), "Debe marcarse como detenido tras detener_suavemente()")

	# Simular paso del tiempo hasta completar la interpolación
	dummy.set("_factor_movimiento", 0.0)
	assert_eq(dummy.obtener_factor_movimiento(), 0.0, "Factor de movimiento debe ser 0.0 al detenerse")

	# Act: Reanudar suavemente
	dummy.reanudar_suavemente(0.2)

	# Assert: Ya no debe estar detenido
	assert_false(dummy.esta_detenido(), "Ya no debe estar detenido tras reanudar_suavemente()")
