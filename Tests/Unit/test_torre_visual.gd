extends GutTest

const SCENE_NIVEL01 := "res://Levels/NIVEL01/NIVEL01.tscn"
const MAT_TORRE := "res://Entities/Ambiente_Torre/TORRE_M.tres"


func test_torre_material_sin_especular_rim() -> void:
	# Arrange & Act
	var mat: StandardMaterial3D = load(MAT_TORRE) as StandardMaterial3D
	assert_not_null(mat, "TORRE_M.tres debe existir y cargar")

	# Assert: Modo especular desactivado para evitar brillos blanquecinos en las fracturas de la torre
	assert_eq(mat.specular_mode, BaseMaterial3D.SPECULAR_DISABLED, "specular_mode debe ser SPECULAR_DISABLED (2)")
	assert_eq(mat.metallic_specular, 0.0, "metallic_specular debe ser 0.0")


func test_nivel01_camara_dof_cubre_toda_la_torre() -> void:
	# Arrange & Act
	var packed := load(SCENE_NIVEL01) as PackedScene
	assert_not_null(packed)
	var nivel: Node = packed.instantiate()
	add_child_autofree(nivel)

	var cam_fondo: Camera3D = nivel.find_child("CamaraFondoDOF", true, false) as Camera3D
	assert_not_null(cam_fondo, "CamaraFondoDOF debe existir")
	assert_not_null(cam_fondo.attributes, "CamaraFondoDOF debe tener CameraAttributes")

	var attrs: CameraAttributesPractical = cam_fondo.attributes as CameraAttributesPractical
	assert_not_null(attrs)

	# Assert: El inicio del DOF far debe ser mayor a la profundidad máxima de la torre (~46.2m)
	assert_gte(attrs.dof_blur_far_distance, 50.0, "dof_blur_far_distance debe ser >= 50.0 para no desenfocar la parte rota de la torre")


func test_nivel01_subviewports_sin_msaa_resolve_fringes() -> void:
	# Arrange & Act
	var packed := load(SCENE_NIVEL01) as PackedScene
	var nivel: Node = packed.instantiate()
	add_child_autofree(nivel)

	var vp_medio: SubViewport = nivel.find_child("SubViewportMedio3D", true, false) as SubViewport
	var vp_frente: SubViewport = nivel.find_child("SubViewportFrente3D", true, false) as SubViewport

	assert_not_null(vp_medio)
	assert_not_null(vp_frente)

	# Assert: MSAA 3D debe estar en 0 (desactivado) en capas transparentes superpuestas para evitar bordes blancos
	assert_eq(vp_medio.msaa_3d, Viewport.MSAA_DISABLED, "SubViewportMedio3D no debe usar MSAA 3D")
	assert_eq(vp_frente.msaa_3d, Viewport.MSAA_DISABLED, "SubViewportFrente3D no debe usar MSAA 3D")
