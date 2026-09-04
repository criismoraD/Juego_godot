extends GutTest

## Test unitario para verificar la división del WaterPlane en 2 capas (2/3 atrás, 1/3 adelante)
## y la preservación del degradado y continuidad de ondas.

const WATER_PLANE_SCENE_PATH: String = "res://Entities/Ambiente_Agua/WaterPlane.tscn"

var _water_plane: Node3D = null


func before_each() -> void:
	var packed := load(WATER_PLANE_SCENE_PATH) as PackedScene
	assert_not_null(packed, "La escena WaterPlane.tscn debe existir y cargarse correctamente")
	_water_plane = packed.instantiate() as Node3D
	add_child_autofree(_water_plane)


func test_water_plane_estructura_hijos():
	# Arrange & Act
	var atras: MeshInstance3D = _water_plane.get_node_or_null("WaterPlane_Atras") as MeshInstance3D
	var adelante: MeshInstance3D = _water_plane.get_node_or_null("WaterPlane_Adelante") as MeshInstance3D

	# Assert
	assert_not_null(atras, "Debe existir el nodo hijo WaterPlane_Atras")
	assert_not_null(adelante, "Debe existir el nodo hijo WaterPlane_Adelante")


func test_water_plane_capas_renderizado():
	# Arrange
	var atras: MeshInstance3D = _water_plane.get_node_or_null("WaterPlane_Atras") as MeshInstance3D
	var adelante: MeshInstance3D = _water_plane.get_node_or_null("WaterPlane_Adelante") as MeshInstance3D

	# Assert: Capa 2 (posterior / fondo) y Capa 1 (frontal)
	assert_eq(atras.layers, 2, "WaterPlane_Atras debe estar asignado a la Capa 2 (posterior)")
	assert_eq(adelante.layers, 1, "WaterPlane_Adelante debe estar asignado a la Capa 1 (frontal)")


func test_water_plane_dimensiones_proporciones_2_3_y_1_3():
	# Arrange
	var atras: MeshInstance3D = _water_plane.get_node_or_null("WaterPlane_Atras") as MeshInstance3D
	var adelante: MeshInstance3D = _water_plane.get_node_or_null("WaterPlane_Adelante") as MeshInstance3D

	var mesh_atras: PlaneMesh = atras.mesh as PlaneMesh
	var mesh_adelante: PlaneMesh = adelante.mesh as PlaneMesh

	# Assert
	assert_not_null(mesh_atras, "WaterPlane_Atras debe tener un PlaneMesh asignado")
	assert_not_null(mesh_adelante, "WaterPlane_Adelante debe tener un PlaneMesh asignado")

	assert_almost_eq(mesh_atras.size.x, 30.0, 0.01, "El ancho X de la parte trasera debe ser 30.0")
	assert_almost_eq(mesh_adelante.size.x, 30.0, 0.01, "El ancho X de la parte delantera debe ser 30.0")

	# Proporción 2/3 (33.333s) y 1/3 (16.667s) de 50.0 total
	assert_almost_eq(mesh_atras.size.y, 50.0 * (2.0 / 3.0), 0.01, "La parte trasera debe ocupar 2/3 de la profundidad (33.333)")
	assert_almost_eq(mesh_adelante.size.y, 50.0 * (1.0 / 3.0), 0.01, "La parte delantera debe ocupar 1/3 de la profundidad (16.667)")
	assert_almost_eq(mesh_atras.size.y + mesh_adelante.size.y, 50.0, 0.01, "La suma de profundidades debe ser exactamente 50.0")


func test_water_plane_continuidad_geometrica_en_z():
	# Arrange
	var atras: MeshInstance3D = _water_plane.get_node_or_null("WaterPlane_Atras") as MeshInstance3D
	var adelante: MeshInstance3D = _water_plane.get_node_or_null("WaterPlane_Adelante") as MeshInstance3D
	var mesh_atras: PlaneMesh = atras.mesh as PlaneMesh
	var mesh_adelante: PlaneMesh = adelante.mesh as PlaneMesh

	# Act: Límites en Z de cada pieza
	var atras_z_min: float = mesh_atras.center_offset.z - (mesh_atras.size.y / 2.0)
	var atras_z_max: float = mesh_atras.center_offset.z + (mesh_atras.size.y / 2.0)

	var adelante_z_min: float = mesh_adelante.center_offset.z - (mesh_adelante.size.y / 2.0)
	var adelante_z_max: float = mesh_adelante.center_offset.z + (mesh_adelante.size.y / 2.0)

	# Assert
	assert_almost_eq(atras_z_min, -25.0, 0.01, "El borde posterior total debe iniciar en Z = -25.0")
	assert_almost_eq(adelante_z_max, 25.0, 0.01, "El borde frontal total debe terminar en Z = +25.0")
	assert_almost_eq(atras_z_max, adelante_z_min, 0.01, "Ambas piezas deben unirse perfectamente sin hueco en Z = +8.333")


func test_water_plane_degradado_y_uvs_continuas():
	# Arrange
	var atras: MeshInstance3D = _water_plane.get_node_or_null("WaterPlane_Atras") as MeshInstance3D
	var adelante: MeshInstance3D = _water_plane.get_node_or_null("WaterPlane_Adelante") as MeshInstance3D

	var mat_atras: ShaderMaterial = atras.get_surface_override_material(0) as ShaderMaterial
	var mat_adelante: ShaderMaterial = adelante.get_surface_override_material(0) as ShaderMaterial

	# Assert: Materiales válidos
	assert_not_null(mat_atras, "WaterPlane_Atras debe tener ShaderMaterial asignado")
	assert_not_null(mat_adelante, "WaterPlane_Adelante debe tener ShaderMaterial asignado")

	# Assert: Degradado en Z preservado idéntico en ambos
	var z_min_atras: float = mat_atras.get_shader_parameter("z_min")
	var z_max_atras: float = mat_atras.get_shader_parameter("z_max")
	var z_min_adelante: float = mat_adelante.get_shader_parameter("z_min")
	var z_max_adelante: float = mat_adelante.get_shader_parameter("z_max")

	assert_almost_eq(z_min_atras, -22.0, 0.01, "El degradado z_min en atrás debe ser -22.0")
	assert_almost_eq(z_max_atras, 10.0, 0.01, "El degradado z_max en atrás debe ser 10.0")
	assert_almost_eq(z_min_adelante, -22.0, 0.01, "El degradado z_min en adelante debe ser -22.0")
	assert_almost_eq(z_max_adelante, 10.0, 0.01, "El degradado z_max en adelante debe ser 10.0")

	# Assert: Mapeo de UVs continuo para que no haya salto en ondas ni espuma
	var uv_scale_atras: Vector2 = mat_atras.get_shader_parameter("uv_scale")
	var uv_offset_atras: Vector2 = mat_atras.get_shader_parameter("uv_offset")
	var uv_scale_adelante: Vector2 = mat_adelante.get_shader_parameter("uv_scale")
	var uv_offset_adelante: Vector2 = mat_adelante.get_shader_parameter("uv_offset")

	assert_almost_eq(uv_scale_atras.y, 2.0 / 3.0, 0.01, "UV scale Y de la parte trasera debe ser 2/3")
	assert_almost_eq(uv_offset_atras.y, 0.0, 0.01, "UV offset Y de la parte trasera debe iniciar en 0.0")

	assert_almost_eq(uv_scale_adelante.y, 1.0 / 3.0, 0.01, "UV scale Y de la parte delantera debe ser 1/3")
	assert_almost_eq(uv_offset_adelante.y, 2.0 / 3.0, 0.01, "UV offset Y de la parte delantera debe iniciar en 2/3")
