extends GutTest

## Test unitario para verificar que el casco oxidado y el escudo élfico pesado
## tengan sus materiales y texturas difusas correctamente configuradas tanto en la escena como en runtime.

func test_materiales_y_texturas_existen_y_validos() -> void:
	# Arrange
	var path_casco_mat: String = "res://Levels/Nivel_Interior/MAT_CascoOxidado.tres"
	var path_escudo_mat: String = "res://Levels/Nivel_Interior/MAT_EscudoPesadoElfico.tres"

	# Act
	var mat_casco: StandardMaterial3D = load(path_casco_mat) as StandardMaterial3D
	var mat_escudo: StandardMaterial3D = load(path_escudo_mat) as StandardMaterial3D

	# Assert Casco
	assert_not_null(mat_casco, "El material MAT_CascoOxidado.tres debe existir y cargarse")
	assert_not_null(mat_casco.albedo_texture, "El material del casco debe tener albedo_texture asignada")
	assert_gt(mat_casco.albedo_texture.get_width(), 0, "La textura del casco debe tener dimensiones válidas")
	assert_eq(mat_casco.cull_mode, BaseMaterial3D.CULL_DISABLED, "El casco debe tener cull_mode disabled (doble cara)")

	# Assert Escudo
	assert_not_null(mat_escudo, "El material MAT_EscudoPesadoElfico.tres debe existir y cargarse")
	assert_not_null(mat_escudo.albedo_texture, "El material del escudo debe tener albedo_texture asignada")
	assert_gt(mat_escudo.albedo_texture.get_width(), 0, "La textura del escudo debe tener dimensiones válidas")
	assert_eq(mat_escudo.cull_mode, BaseMaterial3D.CULL_DISABLED, "El escudo debe tener cull_mode disabled (doble cara)")


func test_player_interior_props_tienen_material_override() -> void:
	# Arrange
	var scene: PackedScene = load("res://Levels/Player_Interior.tscn") as PackedScene
	assert_not_null(scene, "La escena Player_Interior.tscn debe existir")

	# Act
	var root: Node = scene.instantiate()
	add_child_autofree(root)

	# Assert EscudoPesadoElfico / ESCUDO_ORNAMENTO2
	var escudo_prop: Node = root.get_node_or_null("ESCUDO_ORNAMENTO2")
	if not escudo_prop:
		escudo_prop = root.get_node_or_null("EscudoPesadoElfico")
	assert_not_null(escudo_prop, "Debe existir un nodo de adorno de escudo en Player_Interior.tscn")

	var escudo_mesh: MeshInstance3D = escudo_prop.find_child("*", true, false) as MeshInstance3D
	if not escudo_mesh and escudo_prop is MeshInstance3D:
		escudo_mesh = escudo_prop as MeshInstance3D
	assert_not_null(escudo_mesh, "Debe existir un MeshInstance3D bajo el adorno de escudo")
	var escudo_mat: StandardMaterial3D = (escudo_mesh.material_override as StandardMaterial3D)
	if not escudo_mat and escudo_mesh.get_surface_override_material_count() > 0:
		escudo_mat = escudo_mesh.get_surface_override_material(0) as StandardMaterial3D
	assert_not_null(escudo_mat, "El mesh del escudo debe tener material asignado en la escena")
	assert_not_null(escudo_mat.albedo_texture, "El material del escudo debe tener textura albedo asignada")


func test_texturizar_modelo_casos_limite() -> void:
	# Arrange
	var nivel := NivelInterior.new()
	add_child_autofree(nivel)
	var dummy_mat: StandardMaterial3D = StandardMaterial3D.new()

	# Act & Assert 1: Nodos nulos o materiales nulos no deben provocar errores
	var dummy_empty := Node3D.new()
	nivel._texturizar_modelo(dummy_empty, null)
	dummy_empty.free()

	# Act & Assert 2: Nodo con MeshInstance3D recibe el material tanto en override como en surface
	var dummy_holder := Node3D.new()
	var dummy_mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	dummy_mi.mesh = box
	dummy_holder.add_child(dummy_mi)
	add_child_autofree(dummy_holder)

	nivel._texturizar_modelo(dummy_holder, dummy_mat)
	assert_eq(dummy_mi.material_override, dummy_mat, "material_override debe asignarse")
	assert_eq(dummy_mi.get_surface_override_material(0), dummy_mat, "surface_override debe asignarse")
