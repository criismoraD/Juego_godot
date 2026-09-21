extends GutTest

## Test unitario para el Shader de Estela de Viento (Wind Strip Shader)
## y su integración con el impulso (tecla Z) en la canoa del río.

const SHADER_PATH: String = "res://System/Shaders/wind_strip.gdshader"

func test_cargar_shader_estela_viento() -> void:
	# Arrange & Act
	var shader: Shader = load(SHADER_PATH) as Shader

	# Assert
	assert_not_null(shader, "El shader wind_strip.gdshader debe compilar y cargar sin errores")
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	assert_not_null(mat, "El ShaderMaterial debe inicializarse correctamente con el shader")

func test_tubetrail_mesh_curva_campana() -> void:
	# Arrange: Crear TubeTrailMesh con longitud unitaria y curva acampanada
	var mesh: TubeTrailMesh = TubeTrailMesh.new()
	mesh.radius = 0.03
	mesh.sections = 32
	mesh.section_length = 1.0 / 32.0  # Longitud total unitaria = 1.0 metro
	mesh.section_rings = 4

	var curva: Curve = Curve.new()
	curva.add_point(Vector2(0.0, 0.0))
	curva.add_point(Vector2(0.5, 1.0))
	curva.add_point(Vector2(1.0, 0.0))
	mesh.curve = curva

	# Act
	var long_total: float = float(mesh.sections) * mesh.section_length

	# Assert
	assert_almost_eq(long_total, 1.0, 0.001, "La longitud total del TubeTrailMesh debe ser 1.0 (unitaria)")
	assert_not_null(mesh.curve, "El TubeTrailMesh debe tener su curva acampanada configurada")
	assert_eq(mesh.curve.point_count, 3, "La curva acampanada debe tener 3 puntos clave (0 -> 1 -> 0)")


func test_instanciar_efecto_viento_canoa() -> void:
	# Arrange
	var packed: PackedScene = load("res://Levels/Rio_En_Canoa_Con_Parallax/EfectoVientoCanoa.tscn")
	assert_not_null(packed, "EfectoVientoCanoa.tscn debe cargar")
	var efecto: EfectoVientoCanoa = packed.instantiate() as EfectoVientoCanoa
	assert_not_null(efecto, "EfectoVientoCanoa debe instanciarse")

	# Act
	add_child_autofree(efecto)

	# Assert
	assert_false(efecto.visible, "Por defecto el efecto debe iniciar oculto/inactivo")
	assert_false(efecto.esta_activo(), "esta_activo() debe ser false inicialmente")
	assert_gt(efecto.obtener_estelas().size(), 0, "Debe generar estelas por defecto")


func test_configuracion_estelas_y_parametros_instancia() -> void:
	# Arrange & Act
	var efecto: EfectoVientoCanoa = EfectoVientoCanoa.new()
	add_child_autofree(efecto)

	# Assert
	var estelas: Array[MeshInstance3D] = efecto.obtener_estelas()
	assert_eq(estelas.size(), 7, "Debe contar con 7 estelas distribuidas alrededor de la canoa")

	for mi in estelas:
		assert_not_null(mi.mesh, "Cada estela debe tener un mesh asignado")
		assert_true(mi.mesh is TubeTrailMesh, "El mesh debe ser de tipo TubeTrailMesh")
		var trail: TubeTrailMesh = mi.mesh as TubeTrailMesh
		var long_total: float = float(trail.sections) * trail.section_length
		assert_almost_eq(long_total, 1.0, 0.001, "Cada TubeTrailMesh debe tener longitud unitaria 1.0")
		assert_not_null(trail.curve, "Cada TubeTrailMesh debe poseer curva acampanada")
		assert_gt(mi.custom_aabb.size.x, 20.0, "custom_aabb debe ser suficientemente amplio para evitar pop-out fuera de cámara")
		assert_not_null(mi.material_override, "Cada estela debe tener el ShaderMaterial asignado")


func test_activacion_y_desactivacion_suave() -> void:
	# Arrange
	var efecto: EfectoVientoCanoa = EfectoVientoCanoa.new()
	efecto.duracion_transicion = 0.05
	add_child_autofree(efecto)

	# Act: Activar
	efecto.set_activo(true)

	# Assert
	assert_true(efecto.visible, "Al activar debe hacerse visible inmediatamente")
	assert_true(efecto.esta_activo(), "esta_activo() debe ser true")

	# Act: Desactivar
	efecto.set_activo(false)
	assert_false(efecto.esta_activo(), "esta_activo() debe ser false")


func test_canoa_protagonista_contiene_efecto_viento() -> void:
	# Arrange
	var packed: PackedScene = load("res://Levels/Rio_En_Canoa_Con_Parallax/CanoaProtagonistaRio.tscn")
	assert_not_null(packed, "CanoaProtagonistaRio.tscn debe cargar")
	var canoa: CanoaProtagonistaRio = packed.instantiate() as CanoaProtagonistaRio
	assert_not_null(canoa, "CanoaProtagonistaRio debe instanciarse")

	# Act
	add_child_autofree(canoa)

	# Assert
	var efecto: EfectoVientoCanoa = canoa.obtener_efecto_viento()
	assert_not_null(efecto, "La canoa debe contener el componente EfectoVientoCanoa")
	assert_false(canoa.esta_efecto_viento_activo(), "El efecto de viento debe estar inicialmente inactivo")

	# Act: Activar viento desde la canoa
	canoa.set_efecto_viento_activo(true)
	assert_true(canoa.esta_efecto_viento_activo(), "El efecto debe activarse al solicitarlo")

	# Act: Desactivar viento desde la canoa
	canoa.set_efecto_viento_activo(false)
	assert_false(canoa.esta_efecto_viento_activo(), "El efecto debe desactivarse al solicitarlo")


func test_aceleracion_z_nivel_rio_activa_efecto_viento() -> void:
	# Arrange
	var packed: PackedScene = load("res://Levels/Rio en canoa con paralax.tscn")
	assert_not_null(packed, "La escena del nivel río debe cargar")
	var nivel: RioEnCanoaConParallax = packed.instantiate() as RioEnCanoaConParallax
	assert_not_null(nivel, "RioEnCanoaConParallax debe instanciarse")
	add_child_autofree(nivel)

	var canoa: CanoaProtagonistaRio = nivel.obtener_canoa() as CanoaProtagonistaRio
	assert_not_null(canoa, "La canoa de la protagonista debe existir en el nivel")

	# Assert inicial
	assert_false(nivel.esta_acelerando_debug(), "Inicialmente no debe estar acelerando")
	assert_false(canoa.esta_efecto_viento_activo(), "El efecto de viento no debe estar activo al iniciar")

	# Act: Presionar Z (activar aceleración rápida)
	nivel.set_aceleracion_debug(true)

	# Assert: Canoa acelera y activa el efecto de estelas de viento
	assert_true(nivel.esta_acelerando_debug(), "El nivel debe reportar aceleración activa")
	assert_true(canoa.esta_efecto_viento_activo(), "El efecto de estelas de viento debe activarse al acelerar con Z")
	var efecto: EfectoVientoCanoa = canoa.obtener_efecto_viento()
	assert_not_null(efecto, "El nodo EfectoVientoCanoa debe estar disponible")
	assert_true(efecto.visible, "El nodo de estelas debe hacerse visible")

	# Act: Soltar Z (desactivar aceleración rápida)
	nivel.set_aceleracion_debug(false)

	# Assert: Canoa vuelve a velocidad normal y apaga el efecto de viento
	assert_false(nivel.esta_acelerando_debug(), "El nivel no debe reportar aceleración activa tras soltar Z")
	assert_false(canoa.esta_efecto_viento_activo(), "El efecto de estelas debe desactivarse al soltar Z")



