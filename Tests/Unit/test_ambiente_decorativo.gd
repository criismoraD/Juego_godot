extends GutTest

func test_arboleda_visibilidad_en_camara_frente() -> void:
	# Arrange
	var escena: PackedScene = load("res://Levels/NIVEL01/NIVEL01.tscn")
	var nivel: Node = escena.instantiate()
	add_child(nivel)

	# Act
	var arboleda: VisualInstance3D = nivel.get_node_or_null("Arboleda") as VisualInstance3D
	var arboleda2: VisualInstance3D = nivel.get_node_or_null("Arboleda2") as VisualInstance3D
	var camara_frente: Camera3D = nivel.find_child("CamaraFrente", true, false) as Camera3D

	# Assert
	assert_not_null(arboleda, "Arboleda debe existir en NIVEL01")
	assert_not_null(arboleda2, "Arboleda2 debe existir en NIVEL01")
	assert_not_null(camara_frente, "CamaraFrente debe existir en NIVEL01")

	var mascara_frente: int = camara_frente.cull_mask
	assert_true((arboleda.layers & mascara_frente) != 0, "Arboleda debe ser visible para CamaraFrente (capa 1 incluida)")
	assert_true((arboleda2.layers & mascara_frente) != 0, "Arboleda2 debe ser visible para CamaraFrente (capa 1 incluida)")

	nivel.queue_free()


func test_escudo_capas_y_profundidad() -> void:
	# Arrange
	var escena: PackedScene = load("res://Levels/NIVEL01/NIVEL01.tscn")
	var nivel: Node = escena.instantiate()
	add_child(nivel)

	var camara_frente: Camera3D = nivel.find_child("CamaraFrente", true, false) as Camera3D
	assert_not_null(camara_frente, "CamaraFrente debe existir")
	var mascara_frente: int = camara_frente.cull_mask

	# Act & Assert
	var nombres_escudos: Array[String] = ["EscudoDestruible3", "EscudoDestruible4", "EscudoDestruible5", "EscudoDestruible6"]
	for nombre_escudo in nombres_escudos:
		var escudo: Node3D = nivel.get_node_or_null(nombre_escudo) as Node3D
		assert_not_null(escudo, "Escudo %s debe existir en el nivel" % nombre_escudo)
		if escudo:
			var mallas: Array[MeshInstance3D] = []
			_recolectar_mallas(escudo, mallas)
			assert_gt(mallas.size(), 0, "Escudo %s debe tener al menos una malla 3D" % nombre_escudo)
			for mi in mallas:
				assert_eq(mi.layers, 1, "Malla %s del escudo %s debe estar en capa 1" % [mi.name, nombre_escudo])
				assert_true((mi.layers & mascara_frente) != 0, "Malla %s debe ser visible para CamaraFrente" % mi.name)

	nivel.queue_free()


func test_pez_visibilidad_y_prioridad_render() -> void:
	# Arrange
	var escena: PackedScene = load("res://Levels/NIVEL01/NIVEL01.tscn")
	var nivel: Node = escena.instantiate()
	add_child(nivel)

	var pez: Pez = nivel.get_node_or_null("Pez") as Pez
	var pez2: Pez = nivel.get_node_or_null("Pez2") as Pez
	var camara_frente: Camera3D = nivel.find_child("CamaraFrente", true, false) as Camera3D

	# Act & Assert
	assert_not_null(pez, "Pez debe existir en NIVEL01")
	assert_not_null(pez2, "Pez2 debe existir en NIVEL01")
	assert_not_null(camara_frente, "CamaraFrente debe existir")

	var pez_mesh: MeshInstance3D = pez.get_node_or_null("PezMesh") as MeshInstance3D
	assert_not_null(pez_mesh, "PezMesh debe existir")

	var mat: Material = pez_mesh.mesh.surface_get_material(0)
	assert_not_null(mat, "Material del pez debe existir")
	assert_eq(mat.render_priority, 1, "Pez debe tener render_priority = 1 para dibujarse sobre el agua")

	assert_true((pez_mesh.layers & camara_frente.cull_mask) != 0, "PezMesh debe ser visible para CamaraFrente")

	# Verificar que inician dentro del rango visible del río
	assert_between(pez.position.x, pez.limite_x_min, pez.limite_x_max, "Pez debe iniciar dentro de límites visibles")
	assert_between(pez2.position.x, pez2.limite_x_min, pez2.limite_x_max, "Pez2 debe iniciar dentro de límites visibles")

	nivel.queue_free()


func test_piso_optimizacion_y_materiales() -> void:
	# Arrange
	var scn: PackedScene = load("res://Entities/Ambiente_Piso/PISO.glb") as PackedScene
	assert_not_null(scn, "PISO.glb debe existir y poder cargarse")
	var instancia: Node3D = scn.instantiate() as Node3D
	add_child(instancia)

	# Act
	var mesh_instance: MeshInstance3D = instancia.find_child("*", true, false) as MeshInstance3D
	assert_not_null(mesh_instance, "PISO debe contener un MeshInstance3D")
	var mesh: Mesh = mesh_instance.mesh if mesh_instance else null
	assert_not_null(mesh, "MeshInstance3D debe contener una Mesh valida")

	# Assert
	if mesh:
		var arrays: Array = mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var tris: int = indices.size() / 3 if indices.size() > 0 else vertices.size() / 3

		assert_lt(tris, 20000, "El piso debe estar optimizado a menos de 20,000 triangulos (actual: %d)" % tris)
		assert_gt(tris, 1000, "El piso debe tener suficiente detalle geometrico")

		var mat: Material = mesh.surface_get_material(0)
		assert_not_null(mat, "El piso debe tener material asignado")
		if mat is StandardMaterial3D:
			var std_mat: StandardMaterial3D = mat as StandardMaterial3D
			assert_not_null(std_mat.albedo_texture, "El material del piso debe tener textura de albedo")
			assert_true(std_mat.normal_enabled, "El material del piso debe tener normal map activo")
			assert_not_null(std_mat.normal_texture, "El material del piso debe tener textura de normal asignada")

	instancia.queue_free()


func _recolectar_mallas(nodo: Node, lista: Array[MeshInstance3D]) -> void:
	if nodo is MeshInstance3D:
		lista.append(nodo as MeshInstance3D)
	for hijo in nodo.get_children():
		_recolectar_mallas(hijo, lista)


func test_mandoble_2d_configuracion_en_nivel01() -> void:
	# Arrange
	var escena: PackedScene = load("res://Levels/NIVEL01/NIVEL01.tscn")
	var nivel: Node = escena.instantiate()
	add_child(nivel)

	# Act
	var mandoble: Sprite3D = nivel.get_node_or_null("Mandoble2D") as Sprite3D
	var camara_frente: Camera3D = nivel.find_child("CamaraFrente", true, false) as Camera3D

	# Assert
	assert_not_null(mandoble, "El nodo Mandoble2D debe existir como hijo en NIVEL01")
	assert_not_null(camara_frente, "CamaraFrente debe existir en NIVEL01")
	if mandoble:
		assert_not_null(mandoble.texture, "Mandoble2D debe tener una textura asignada")
		if mandoble.texture:
			assert_true(mandoble.texture.resource_path.contains("Mandoble 2D.png"), "La textura de Mandoble2D debe ser Mandoble 2D.png")
		var mascara_frente: int = camara_frente.cull_mask if camara_frente else 1
		assert_true((mandoble.layers & mascara_frente) != 0, "Mandoble2D debe ser visible para CamaraFrente")
		assert_true(mandoble.visible, "Mandoble2D debe estar visible en la escena")

	nivel.queue_free()
