extends GutTest

## Test unitario para verificar el sistema modular de partículas de polvo (Ambiente_Polvo)
## inspirado en el efecto de hojas de NIVEL01 y adaptado desde particulas polvo.gif.

func test_textura_spritesheet_polvo_existe() -> void:
	# Arrange & Act
	var polvo_tex: Texture2D = load("res://Entities/Ambiente_Polvo/polvo.png") as Texture2D

	# Assert
	assert_not_null(polvo_tex, "La textura spritesheet polvo.png debe existir en Entities/Ambiente_Polvo/")
	assert_gt(polvo_tex.get_width(), 0, "El ancho de la textura debe ser mayor a cero")
	assert_gt(polvo_tex.get_height(), 0, "El alto de la textura debe ser mayor a cero")
	assert_gt(polvo_tex.get_width(), polvo_tex.get_height(), "Debe ser un spritesheet horizontal (ancho > alto)")


func test_material_polvo_configuracion() -> void:
	# Arrange & Act
	var mat: StandardMaterial3D = load("res://Entities/Ambiente_Polvo/MAT_polvo.tres") as StandardMaterial3D

	# Assert
	assert_not_null(mat, "MAT_polvo.tres debe existir")
	assert_eq(mat.particles_anim_h_frames, 7, "Debe tener 7 frames horizontales al igual que hojas")
	assert_eq(mat.particles_anim_v_frames, 1, "Debe tener 1 frame vertical")
	assert_eq(mat.billboard_mode, BaseMaterial3D.BILLBOARD_PARTICLES, "Debe ser billboard para partículas")
	assert_true(mat.vertex_color_use_as_albedo, "Debe usar color de vértice como albedo para fade in/out")
	assert_eq(mat.blend_mode, BaseMaterial3D.BLEND_MODE_ADD, "Debe usar mezcla aditiva para brillo bokeh")


func test_polvo_plane_escena() -> void:
	# Arrange
	var scene: PackedScene = load("res://Entities/Ambiente_Polvo/PolvoPlane.tscn") as PackedScene
	assert_not_null(scene, "PolvoPlane.tscn debe existir")

	# Act
	var node: GPUParticles3D = scene.instantiate() as GPUParticles3D
	add_child_autofree(node)

	# Assert
	assert_not_null(node, "El nodo raíz debe ser GPUParticles3D")
	assert_gt(node.amount, 0, "Debe emitir partículas")
	assert_not_null(node.process_material, "Debe tener process_material configurado")
	assert_not_null(node.draw_pass_1, "Debe tener draw_pass_1 configurado")

	var proc_mat: ParticleProcessMaterial = node.process_material as ParticleProcessMaterial
	assert_not_null(proc_mat, "El process_material debe ser de tipo ParticleProcessMaterial")
	assert_eq(proc_mat.anim_offset_max, 1.0, "Debe seleccionar aleatoriamente frames de la spritesheet")
	assert_true(proc_mat.turbulence_enabled, "Debe tener turbulencia para movimiento orgánico")


func test_nivel01_instancia_polvo_plane() -> void:
	# Arrange
	var nivel01_scene: PackedScene = load("res://Levels/NIVEL01/NIVEL01.tscn") as PackedScene
	assert_not_null(nivel01_scene, "NIVEL01.tscn debe existir")

	# Act
	var nivel01: Node = nivel01_scene.instantiate()
	add_child_autofree(nivel01)

	# Assert
	var hojas: Node = nivel01.find_child("HojasPlane", true, false)
	var polvo: Node = nivel01.find_child("PolvoPlane", true, false)
	assert_not_null(hojas, "NIVEL01 debe contener HojasPlane")
	assert_not_null(polvo, "NIVEL01 debe contener PolvoPlane instanciado de la misma manera que HojasPlane")


func test_polvo_interior_usa_spritesheet() -> void:
	# Arrange
	var scene: PackedScene = load("res://Levels/Nivel_Interior/PolvoInterior.tscn") as PackedScene
	assert_not_null(scene, "PolvoInterior.tscn debe existir")

	# Act
	var root: Node = scene.instantiate()
	add_child_autofree(root)

	# Assert
	var particles: GPUParticles3D = root.find_child("ParticulasPolvo", true, false) as GPUParticles3D
	assert_not_null(particles, "ParticulasPolvo debe existir en PolvoInterior")
	var mesh: QuadMesh = particles.draw_pass_1 as QuadMesh
	assert_not_null(mesh, "Draw pass debe ser QuadMesh")
	var mat: StandardMaterial3D = mesh.material as StandardMaterial3D
	assert_not_null(mat, "Material de QuadMesh debe existir")
	assert_eq(mat.particles_anim_h_frames, 7, "Polvo interior debe usar los 7 frames de motas del GIF")
