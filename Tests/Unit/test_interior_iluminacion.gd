extends GutTest

## Test unitario para verificar la iluminación, sombras, máscara y partículas en el nivel interior de la torre.

func test_texturas_mascara_y_polvo_existen() -> void:
	# Arrange & Act
	var mascara: Texture2D = load("res://Levels/Nivel_Interior/LuzMascaraTorre.png") as Texture2D
	var polvo_tex: Texture2D = load("res://Levels/Nivel_Interior/particula_polvo.png") as Texture2D

	# Assert
	assert_not_null(mascara, "La textura de máscara de luz para el interior debe existir y ser válida")
	assert_not_null(polvo_tex, "La textura de partículas de polvo debe existir y ser válida")
	assert_gt(mascara.get_width(), 0, "El ancho de la máscara debe ser mayor a cero")
	assert_gt(polvo_tex.get_width(), 0, "El ancho de la textura de polvo debe ser mayor a cero")


func test_polvo_interior_escena() -> void:
	# Arrange
	var polvo_scene: PackedScene = load("res://Levels/Nivel_Interior/PolvoInterior.tscn") as PackedScene
	assert_not_null(polvo_scene, "La escena PolvoInterior.tscn debe existir")

	# Act
	var polvo_node: Node3D = polvo_scene.instantiate() as Node3D
	add_child_autofree(polvo_node)

	# Assert
	var particles: GPUParticles3D = polvo_node.find_child("ParticulasPolvo", true, false) as GPUParticles3D
	assert_not_null(particles, "El nodo GPUParticles3D debe existir en PolvoInterior")
	assert_gt(particles.amount, 0, "La cantidad de partículas debe ser mayor a cero")
	assert_not_null(particles.draw_pass_1, "Debe tener configurado el draw_pass_1")


func test_interio_tscn_configuracion_iluminacion_y_sombras() -> void:
	for path in ["res://Levels/Player_Interior.tscn"]:
		# Arrange
		var scene: PackedScene = load(path) as PackedScene
		assert_not_null(scene, "La escena %s debe existir" % path)

		# Act
		var root: Node = scene.instantiate()
		add_child_autofree(root)

		# Assert WorldEnvironment
		var world_env: WorldEnvironment = root.find_child("WorldEnvironment", true, false) as WorldEnvironment
		assert_not_null(world_env, "WorldEnvironment debe existir en %s" % path)
		assert_not_null(world_env.environment, "Environment debe estar asignado en WorldEnvironment de %s" % path)
		var env: Environment = world_env.environment
		assert_lte(env.ambient_light_energy, 0.45, "La energía de luz ambiental debe ser controlada para preservar sombras reales en %s" % path)
		assert_gt(env.ambient_light_energy, 0.05, "Debe existir luz ambiental mínima en %s" % path)

		# Assert SpotLight3D con sombras reales y máscara de proyección
		var spot: SpotLight3D = root.find_child("SpotLight3D", true, false) as SpotLight3D
		assert_not_null(spot, "SpotLight3D debe existir en %s" % path)
		assert_true(spot.shadow_enabled, "Las sombras reales deben estar activadas en SpotLight3D de %s" % path)
		assert_not_null(spot.light_projector, "La máscara (projector) debe estar asignada en SpotLight3D de %s" % path)
		assert_gte(spot.light_energy, 0.8, "La energía de la luz debe ser suficiente para iluminar la torre")
		assert_gte(spot.shadow_opacity, 0.9, "La opacidad de sombra debe ser real y nítida (>= 0.9)")
		assert_lte(spot.shadow_blur, 1.2, "El desenfoque de sombra debe ser nítido (<= 1.2)")

		# Assert SpotLight3D2 (luz secundaria de apoyo con máscara)
		var spot2: SpotLight3D = root.find_child("SpotLight3D2", true, false) as SpotLight3D
		assert_not_null(spot2, "SpotLight3D2 debe existir en %s" % path)

		# Assert PolvoInterior
		var polvo: Node = root.find_child("PolvoInterior", true, false)
		assert_not_null(polvo, "El sistema de partículas de polvo debe estar instanciado en %s" % path)


func test_recursos_mascara_oscurecer_interior() -> void:
	# Arrange & Act
	var mask_tex: Texture2D = load("res://Levels/Nivel_Interior/MascaraOscurecerInterior.png") as Texture2D
	var shader: Shader = load("res://Levels/Nivel_Interior/SombraInteriorOverlay.gdshader") as Shader
	var mat: ShaderMaterial = load("res://Levels/Nivel_Interior/MAT_sombra_interior_overlay.tres") as ShaderMaterial

	# Assert
	assert_not_null(mask_tex, "MascaraOscurecerInterior.png debe existir")
	assert_gt(mask_tex.get_width(), 0, "El ancho de la máscara debe ser mayor a cero")
	assert_not_null(shader, "SombraInteriorOverlay.gdshader debe existir")
	assert_not_null(mat, "MAT_sombra_interior_overlay.tres debe existir")
	assert_not_null(mat.shader, "El shader debe estar asignado en el material")
	assert_not_null(mat.get_shader_parameter("mask_texture"), "La textura de la máscara debe estar asignada en el material")


func test_interio_iluminacion_anterior_oculta_para_comparacion() -> void:
	for path in ["res://Levels/Player_Interior.tscn"]:
		# Arrange
		var scene: PackedScene = load(path) as PackedScene
		assert_not_null(scene, "La escena %s debe existir" % path)

		# Act
		var root: Node = scene.instantiate()
		add_child_autofree(root)

		# Assert IluminacionActual visible
		var ilum_act: Node3D = root.find_child("IluminacionActual", true, false) as Node3D
		assert_not_null(ilum_act, "Debe existir el grupo IluminacionActual en %s" % path)
		assert_true(ilum_act.visible, "IluminacionActual debe estar visible por defecto en %s" % path)

		# Assert IluminacionAnterior oculta pero con sombreado real configurado
		var ilum_ant: Node3D = root.find_child("IluminacionAnterior", true, false) as Node3D
		assert_not_null(ilum_ant, "Debe existir el grupo IluminacionAnterior en %s" % path)
		assert_false(ilum_ant.visible, "IluminacionAnterior debe estar OCULTA por defecto en %s" % path)

		var spot_ant: SpotLight3D = ilum_ant.find_child("SpotLight3D_Anterior", true, false) as SpotLight3D
		assert_not_null(spot_ant, "SpotLight3D_Anterior debe existir en IluminacionAnterior de %s" % path)
		assert_true(spot_ant.shadow_enabled, "SpotLight3D_Anterior debe tener sombras habilitadas")
		assert_gte(spot_ant.shadow_opacity, 0.9, "SpotLight3D_Anterior debe tener sombras reales y nítidas (>= 0.9)")
		assert_lte(spot_ant.shadow_blur, 1.0, "SpotLight3D_Anterior debe tener blur bajo (<= 1.0)")

		var antorcha: OmniLight3D = ilum_ant.find_child("LuzAntorcha", true, false) as OmniLight3D
		assert_not_null(antorcha, "LuzAntorcha debe existir en IluminacionAnterior de %s" % path)
		assert_true(antorcha.shadow_enabled, "LuzAntorcha debe tener sombras habilitadas")
		assert_gte(antorcha.shadow_opacity, 0.9, "LuzAntorcha debe tener sombras nítidas (>= 0.9)")

		# Assert CapaMascaraSombra oculta
		var capa_sombra: CanvasLayer = root.find_child("CapaMascaraSombra", true, false) as CanvasLayer
		assert_not_null(capa_sombra, "CapaMascaraSombra debe existir en %s" % path)
		assert_false(capa_sombra.visible, "CapaMascaraSombra debe estar OCULTA por defecto en %s" % path)

		# Assert Environment anterior existe y tiene contraste para sombras
		var env_ant: Environment = load("res://Levels/Nivel_Interior/Interior_Environment_Anterior.tres") as Environment
		assert_not_null(env_ant, "Interior_Environment_Anterior.tres debe existir")
		assert_lte(env_ant.ambient_light_energy, 0.45, "El Environment anterior debe tener luz ambiental controlada (<= 0.45) para proyectar sombras reales")


func test_mascara_desaturacion_bordes() -> void:
	# Arrange & Act
	var mask_tex: Texture2D = load("res://Levels/Nivel_Interior/MascaraDesaturacionBordes.png") as Texture2D
	var shader: Shader = load("res://Levels/Nivel_Interior/DesaturacionBordes.gdshader") as Shader
	var mat: ShaderMaterial = load("res://Levels/Nivel_Interior/MAT_DesaturacionBordes.tres") as ShaderMaterial

	# Assert Recursos
	assert_not_null(mask_tex, "MascaraDesaturacionBordes.png debe existir")
	assert_gt(mask_tex.get_width(), 0, "El ancho de la máscara de desaturación debe ser mayor a cero")
	assert_not_null(shader, "DesaturacionBordes.gdshader debe existir")
	assert_not_null(mat, "MAT_DesaturacionBordes.tres debe existir")
	assert_not_null(mat.shader, "El shader debe estar asignado en MAT_DesaturacionBordes")
	assert_not_null(mat.get_shader_parameter("mask_texture"), "La textura de la máscara debe estar asignada en MAT_DesaturacionBordes")

	# Assert Escenas
	for path in ["res://Levels/Player_Interior.tscn"]:
		var scene: PackedScene = load(path) as PackedScene
		assert_not_null(scene, "La escena %s debe existir" % path)

		var root: Node = scene.instantiate()
		add_child_autofree(root)

		var capa_bordes: CanvasLayer = root.find_child("CapaMascaraBordes", true, false) as CanvasLayer
		assert_not_null(capa_bordes, "CapaMascaraBordes debe existir en %s" % path)
		assert_true(capa_bordes.visible, "CapaMascaraBordes debe estar visible por defecto en %s" % path)

		var rect: ColorRect = capa_bordes.find_child("MascaraDesaturacion", true, false) as ColorRect
		assert_not_null(rect, "MascaraDesaturacion (ColorRect) debe existir en %s" % path)
		assert_eq(rect.mouse_filter, Control.MOUSE_FILTER_IGNORE, "MascaraDesaturacion no debe bloquear clicks de ratón")
		assert_not_null(rect.material, "MascaraDesaturacion debe tener material asignado")



