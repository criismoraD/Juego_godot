extends "res://addons/gut/test.gd"

## Tests unitarios para PlanoDesenfoqueFondo.
## Verifica la instanciación de la capa plana 2D/3D de desenfoque,
## actualización dinámica del grado de desenfoque en el ShaderMaterial,
## dimensiones del QuadMesh, seguimiento horizontal de la cámara y
## su integración en el escenario 'Rio en canoa con paralax'.

const SCENE_PLANO_DESENFOQUE: PackedScene = preload("res://Levels/Rio_En_Canoa_Con_Parallax/PlanoDesenfoqueFondo.tscn")
const SCENE_RIO_USUARIO: String = "res://Levels/Rio en canoa con paralax.tscn"
const SHADER_DESENFOQUE: Shader = preload("res://System/Shaders/desenfoque_fondo_plano.gdshader")


func test_instanciacion_plano_desenfoque() -> void:
	# Arrange & Act
	var plano: PlanoDesenfoqueFondo = SCENE_PLANO_DESENFOQUE.instantiate() as PlanoDesenfoqueFondo
	assert_not_null(plano, "La escena PlanoDesenfoqueFondo debe instanciarse")
	add_child_autofree(plano)

	# Assert
	assert_not_null(plano.mesh, "Debe poseer una malla asignada")
	assert_true(plano.mesh is QuadMesh, "La malla debe ser un QuadMesh plano")
	assert_not_null(plano.material_override, "Debe poseer un material_override asignado")
	assert_true(plano.material_override is ShaderMaterial, "El material debe ser un ShaderMaterial")

	var mat := plano.material_override as ShaderMaterial
	assert_eq(mat.shader, SHADER_DESENFOQUE, "El shader asignado debe ser desenfoque_fondo_plano.gdshader")


func test_grado_desenfoque_y_parametros_shader() -> void:
	# Arrange
	var plano: PlanoDesenfoqueFondo = SCENE_PLANO_DESENFOQUE.instantiate() as PlanoDesenfoqueFondo
	add_child_autofree(plano)
	var mat := plano.obtener_material_desenfoque()
	assert_not_null(mat, "Debe retornar el ShaderMaterial activo")

	# Act & Assert: Modificar grado_desenfoque
	plano.grado_desenfoque = 6.5
	assert_almost_eq(float(mat.get_shader_parameter("desenfoque")), 6.5, 0.01, "Shader debe recibir desenfoque 6.5")

	# Act & Assert: Modificar opacidad
	plano.opacidad = 0.75
	assert_almost_eq(float(mat.get_shader_parameter("opacidad")), 0.75, 0.01, "Shader debe recibir opacidad 0.75")

	# Act & Assert: Modificar tinte de color atmosférico
	var nuevo_tinte := Color(0.95, 0.85, 0.75, 0.9)
	plano.tinte = nuevo_tinte
	assert_eq(mat.get_shader_parameter("tinte"), nuevo_tinte, "Shader debe recibir tinte personalizado")

	# Act & Assert: Modificar desvanecimiento inferior
	plano.desvanecer_borde_inferior = 0.2
	assert_almost_eq(float(mat.get_shader_parameter("desvanecer_borde_inferior")), 0.2, 0.01, "Shader debe recibir desvanecer_borde_inferior")

	# Act & Assert: Función pública fijar_grado_desenfoque
	plano.fijar_grado_desenfoque(4.2)
	assert_almost_eq(plano.grado_desenfoque, 4.2, 0.01)
	assert_almost_eq(float(mat.get_shader_parameter("desenfoque")), 4.2, 0.01)


func test_dimensiones_plano_y_malla() -> void:
	# Arrange
	var plano: PlanoDesenfoqueFondo = SCENE_PLANO_DESENFOQUE.instantiate() as PlanoDesenfoqueFondo
	add_child_autofree(plano)

	# Act: Cambiar tamaño
	var nuevo_tamano := Vector2(320.0, 110.0)
	plano.tamano = nuevo_tamano

	# Assert
	var qmesh := plano.mesh as QuadMesh
	assert_not_null(qmesh)
	assert_almost_eq(qmesh.size.x, nuevo_tamano.x, 0.01, "El ancho del QuadMesh debe actualizarse")
	assert_almost_eq(qmesh.size.y, nuevo_tamano.y, 0.01, "El alto del QuadMesh debe actualizarse")


func test_seguimiento_camara_en_x() -> void:
	# Arrange
	var plano: PlanoDesenfoqueFondo = SCENE_PLANO_DESENFOQUE.instantiate() as PlanoDesenfoqueFondo
	add_child_autofree(plano)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 3.0, 40.0)
	add_child_autofree(cam)

	plano.global_position = Vector3(0.0, 18.0, -48.0)
	plano.fijar_camara(cam)

	# Act: La cámara avanza hacia la derecha junto con la canoa
	cam.global_position.x = 45.0
	plano._process(0.016)

	# Assert: El plano debe haber acompañado a la cámara a X = 45.0
	assert_almost_eq(plano.global_position.x, 45.0, 0.01, "El plano debe seguir horizontalmente a la cámara")


func test_presencia_y_posicion_en_escena_usuario() -> void:
	# Arrange & Act: Comprobar la escena principal 'Rio en canoa con paralax.tscn'
	var packed := load(SCENE_RIO_USUARIO) as PackedScene
	assert_not_null(packed)
	var nivel: Node3D = packed.instantiate() as Node3D
	assert_not_null(nivel)
	add_child_autofree(nivel)

	# Assert: Nodo presente
	var plano: PlanoDesenfoqueFondo = nivel.find_child("PlanoDesenfoqueFondo", true, false) as PlanoDesenfoqueFondo
	assert_not_null(plano, "PlanoDesenfoqueFondo debe existir en la escena del usuario")

	# Assert: Profundidad Z correcta (detrás de la canoa en Z=-7.5 y delante de la cordillera/fondo en Z=-54 a -100)
	var canoa: Node3D = nivel.find_child("CanoaProtagonistaRio", true, false) as Node3D
	assert_not_null(canoa)
	assert_lt(plano.position.z, canoa.position.z, "El plano de desenfoque debe estar DETRÁS de la canoa")
	assert_gt(plano.position.z, -105.0, "El plano de desenfoque debe estar DELANTE del fondo más lejano")


func test_planos_desenfoque_no_invaden_primer_plano() -> void:
	# Arrange & Act: Asegurar que ningún plano de desenfoque quede en Z > -25 en la escena del usuario
	var packed := load(SCENE_RIO_USUARIO) as PackedScene
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)

	var planos: Array[Node] = nivel.find_children("*", "PlanoDesenfoqueFondo", true, false)
	for p in planos:
		var plano_nodo: PlanoDesenfoqueFondo = p as PlanoDesenfoqueFondo
		if plano_nodo:
			assert_lt(plano_nodo.position.z, -25.0, "El plano de desenfoque '%s' debe estar detrás del primer plano (Z < -25)" % plano_nodo.name)

