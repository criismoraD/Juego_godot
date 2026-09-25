extends GutTest

## Línea negra 2D (TOON_LINEANEGRA, ancho 20) en el globo y en el canasto que cae:
## - el helper aplica grupo outline_meshes + next_pass negro 20 a mallas sueltas
## - la escena real deja con contorno ModeloGlobo, ModeloGloboDestruido y ModeloCanasta
## - la canasta eyectada al morir conserva el contorno durante la caída.

const SHADER_OUTLINE: Shader = preload("res://System/Shaders/TOON_LINEANEGRA.gdshader")
const GLOBO_SCENE: PackedScene = preload("res://Entities/Enemigo_GloboAerostatico/GloboAerostatico.tscn")
const ANCHO_ESPERADO: float = 20.0
const COLOR_ESPERADO: Color = Color(0, 0, 0, 1)

var GloboScript = load("res://Entities/Enemigo_GloboAerostatico/GloboAerostatico.gd")

var scene_root: Node3D


func before_each() -> void:
	scene_root = Node3D.new()
	add_child(scene_root)


func after_each() -> void:
	if is_instance_valid(scene_root):
		scene_root.queue_free()
	await get_tree().process_frame


func _es_malla_con_contorno_esperado(mi: MeshInstance3D) -> bool:
	if "Sombra" in String(mi.name):
		return false
	if mi.find_parent("GoblinTripulante*") != null:
		return false
	if mi.find_parent("Fuego2D*") != null:
		return false
	return true


func _assert_mi_con_contorno(mi: MeshInstance3D) -> void:
	assert_true(mi.is_in_group("outline_meshes"), "La malla %s debe estar en outline_meshes" % mi.name)
	assert_not_null(mi.mesh, "La malla %s debe tener mesh" % mi.name)
	for i in range(mi.mesh.get_surface_count()):
		var mat: Material = mi.get_active_material(i)
		assert_true(mat is StandardMaterial3D, "El material activo de %s debe ser StandardMaterial3D" % mi.name)
		if not (mat is StandardMaterial3D):
			continue
		var next: Material = (mat as StandardMaterial3D).next_pass
		assert_true(next is ShaderMaterial, "La malla %s debe tener next_pass con shader" % mi.name)
		if not (next is ShaderMaterial):
			continue
		var outline := next as ShaderMaterial
		assert_eq(outline.shader, SHADER_OUTLINE, "El next_pass de %s debe ser TOON_LINEANEGRA" % mi.name)
		assert_eq(outline.get_shader_parameter("outline_width"), ANCHO_ESPERADO, "El ancho debe ser 20.0")
		assert_eq(outline.get_shader_parameter("outline_color"), COLOR_ESPERADO, "El color debe ser negro")


func _mallas_objetivo_en(raiz: Node) -> Array[MeshInstance3D]:
	var lista: Array[MeshInstance3D] = []
	for hijo in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := hijo as MeshInstance3D
		if mi and _es_malla_con_contorno_esperado(mi):
			lista.append(mi)
	return lista


func test_helper_aplica_outline_a_malla_suelta() -> void:
	# Arrange: globo solo-script + portador falso de canasta con una malla
	var globo = GloboScript.new()
	var portador := Node3D.new()
	portador.name = "ModeloCanasta"
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.38, 0.22)
	quad.material = mat
	mi.mesh = quad
	portador.add_child(mi)
	globo.add_child(portador)
	scene_root.add_child(globo)
	await get_tree().process_frame
	globo._modelo_canasta_node = portador

	# Act
	globo.asegurar_contorno_toon()

	# Assert
	_assert_mi_con_contorno(mi)


func test_escena_real_con_contorno_en_globo_y_canasta() -> void:
	# Arrange
	var globo := GLOBO_SCENE.instantiate() as Node3D
	scene_root.add_child(globo)
	await get_tree().process_frame
	await get_tree().process_frame

	# Act
	var raíces: Array[String] = ["ModeloGlobo", "ModeloGloboDestruido", "ModeloCanasta"]
	var total: int = 0
	for nombre in raíces:
		var raiz := globo.find_child(nombre, true, false) as Node3D
		assert_not_null(raiz, "La escena debe contener %s" % nombre)
		if raiz == null:
			continue
		var mallas := _mallas_objetivo_en(raiz)
		assert_gt(mallas.size(), 0, "%s debe tener al menos una malla con contorno esperado" % nombre)
		for mi in mallas:
			_assert_mi_con_contorno(mi)
			total += 1

	# Assert
	assert_gt(total, 0, "Debe haber mallas con contorno en la escena")


func test_canasta_eyectada_conserva_outline_en_caida() -> void:
	# Arrange: globo solo-script + canasta falsa ya con contorno
	var globo = GloboScript.new()
	var portador := Node3D.new()
	portador.name = "ModeloCanasta"
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.38, 0.22)
	quad.material = mat
	mi.mesh = quad
	portador.add_child(mi)
	globo.add_child(portador)
	scene_root.add_child(globo)
	await get_tree().process_frame
	globo._modelo_canasta_node = portador
	globo.asegurar_contorno_toon()
	assert_true(mi.is_in_group("outline_meshes"), "Precondición: la canasta ya tiene contorno")

	# Act: daño letal (3 de vida) → eyecta la canasta al CanastaCaida (sin drops)
	globo.posion_drop_chance = 0.0
	globo.multiple_drop_chance = 0.0
	globo.take_damage(3.0)
	await wait_seconds(0.5)

	# Assert: la malla sigue válida, reparentada al canasto caído y con contorno
	assert_true(is_instance_valid(mi), "La malla de la canasta debe sobrevivir a la eyección")
	assert_not_null(mi.find_parent("CanastaGloboCaida"), "La canasta debe vivir bajo CanastaGloboCaida")
	_assert_mi_con_contorno(mi)

	# Limpieza: el contenedor vive en la escena raíz del árbol, no en scene_root
	var contenedor := mi.find_parent("CanastaGloboCaida")
	if is_instance_valid(contenedor):
		contenedor.queue_free()
