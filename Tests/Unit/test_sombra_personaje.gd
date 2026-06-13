extends GutTest
## Test unitario para el componente SombraPersonaje.
## Verifica instanciación, valores por defecto, creación de hijos y API pública.


var sombra: SombraPersonaje


func before_each():
	sombra = SombraPersonaje.new()


func after_each():
	if is_instance_valid(sombra) and sombra.is_inside_tree():
		sombra.queue_free()
		await get_tree().process_frame


func test_instanciacion_correcta():
	# Arrange & Act — ya creado en before_each
	# Assert
	assert_not_null(sombra, "SombraPersonaje debe instanciarse correctamente")
	assert_true(sombra is Node3D, "Debe extender Node3D")


func test_valores_por_defecto():
	# Assert — validar defaults críticos
	assert_almost_eq(sombra.opacidad, 1.0, 0.01, "Opacidad default = 1.0")
	assert_eq(sombra.tamano, Vector2(0.6, 0.6), "Tamaño default = (0.6, 0.6)")
	assert_almost_eq(sombra.suavizado, 0.8, 0.01, "Suavizado default = 0.8")
	assert_true(sombra.escala_por_altura, "Escala por altura activa por defecto")
	assert_almost_eq(sombra.altura_max_desvanecimiento, 0.2, 0.01)
	assert_almost_eq(sombra.escala_minima, 0.5, 0.01)
	assert_eq(sombra.mascara_colision, 65, "Máscara default = 65 (capas 1 y 7)")


func test_crea_mesh_y_raycast_en_ready():
	# Arrange
	var parent = Node3D.new()
	add_child(parent)

	# Act
	parent.add_child(sombra)
	await get_tree().process_frame

	# Assert
	var mesh_encontrado := false
	var ray_encontrado := false
	for child in sombra.get_children():
		if child is MeshInstance3D:
			mesh_encontrado = true
			assert_true(child.top_level, "MeshInstance3D debe ser top_level")
			assert_eq(
				child.cast_shadow,
				GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
				"Sombra no debe proyectar sombra real"
			)
		if child is RayCast3D:
			ray_encontrado = true
			assert_true(child.top_level, "RayCast3D debe ser top_level")
			assert_true(child.enabled, "RayCast3D debe estar habilitado")

	assert_true(mesh_encontrado, "Debe crear MeshInstance3D hijo")
	assert_true(ray_encontrado, "Debe crear RayCast3D hijo")

	parent.queue_free()
	await get_tree().process_frame


func test_mesh_usa_quad():
	# Arrange
	var parent = Node3D.new()
	add_child(parent)
	parent.add_child(sombra)
	await get_tree().process_frame

	# Assert
	for child in sombra.get_children():
		if child is MeshInstance3D:
			assert_true(child.mesh is QuadMesh, "Mesh debe ser QuadMesh")
			var quad = child.mesh as QuadMesh
			assert_eq(quad.size, sombra.tamano, "QuadMesh size debe coincidir con tamano")

	parent.queue_free()
	await get_tree().process_frame


func test_set_tamano_runtime():
	# Arrange
	var parent = Node3D.new()
	add_child(parent)
	parent.add_child(sombra)
	await get_tree().process_frame

	# Act
	var nuevo := Vector2(1.2, 0.6)
	sombra.set_tamano(nuevo)

	# Assert
	assert_eq(sombra.tamano, nuevo, "Tamaño debe actualizarse")

	parent.queue_free()
	await get_tree().process_frame


func test_set_opacidad_runtime():
	# Arrange
	var parent = Node3D.new()
	add_child(parent)
	parent.add_child(sombra)
	await get_tree().process_frame

	# Act
	sombra.set_opacidad(0.8)

	# Assert
	assert_almost_eq(sombra.opacidad, 0.8, 0.01, "Opacidad debe actualizarse")

	parent.queue_free()
	await get_tree().process_frame


func test_sombra_invisible_sin_colision():
	# Arrange — sin suelo debajo, el raycast no colisiona
	var parent = Node3D.new()
	parent.global_position = Vector3(0, 100, 0)  # Muy alto, sin suelo
	add_child(parent)
	parent.add_child(sombra)
	await get_tree().process_frame
	await get_tree().process_frame

	# Assert — la mesh debe ocultarse
	for child in sombra.get_children():
		if child is MeshInstance3D:
			assert_false(child.visible, "Sombra invisible sin suelo detectado")

	parent.queue_free()
	await get_tree().process_frame


func test_opacidad_negativa_clampeada():
	# Arrange — valor límite
	sombra.opacidad = -0.5

	# Assert — el shader clampeará pero el componente acepta el valor
	assert_true(sombra.opacidad < 0.0, "Acepta valores negativos (shader clampeará)")


func test_tamano_cero():
	# Arrange — edge case
	var parent = Node3D.new()
	add_child(parent)
	parent.add_child(sombra)
	await get_tree().process_frame

	# Act — no debe crashear
	sombra.set_tamano(Vector2.ZERO)

	# Assert
	assert_eq(sombra.tamano, Vector2.ZERO, "Acepta tamaño cero sin crash")

	parent.queue_free()
	await get_tree().process_frame
