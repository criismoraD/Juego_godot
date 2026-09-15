extends "res://addons/gut/test.gd"

## Tests unitarios para el efecto de fuego 2D animado (Fuego2D),
## opción de difuminado (shader bokeh), posicionamiento manual e integración en el nivel del río.

const FUEGO_SCENE_PATH: String = "res://Levels/Rio_En_Canoa_Con_Parallax/Fuego2D.tscn"
const BRACERO_SCENE_PATH: String = "res://Levels/Rio_En_Canoa_Con_Parallax/BraceroPilar.tscn"
const RIO_ESCENA_USUARIO_PATH: String = "res://Levels/Rio en canoa con paralax.tscn"
const RIO_ESCENA_CANONICA_PATH: String = "res://Levels/Rio_En_Canoa_Con_Parallax/Rio_En_Canoa_Con_Parallax.tscn"
const Fuego2DScript: Script = preload("res://Levels/Rio_En_Canoa_Con_Parallax/Fuego2D.gd")
const BraceroPilarScript: Script = preload("res://Levels/Rio_En_Canoa_Con_Parallax/BraceroPilar.gd")
const MARGEN_FLOAT: float = 0.01


# === TESTS DE INSTANCIACIÓN Y ESTRUCTURA ===
func test_instanciacion_fuego_2d() -> void:
	# Arrange & Act
	var packed := load(FUEGO_SCENE_PATH) as PackedScene
	assert_not_null(packed, "La escena Fuego2D debe cargar correctamente")

	var fuego: AnimatedSprite3D = packed.instantiate() as AnimatedSprite3D
	assert_not_null(fuego, "La escena Fuego2D debe instanciarse")
	add_child_autofree(fuego)

	# Assert
	assert_true(fuego is AnimatedSprite3D, "Fuego2D debe heredar de AnimatedSprite3D")
	assert_not_null(fuego.call("obtener_luz"), "Fuego2D debe contener un nodo OmniLight3D como luz")


func test_configuracion_visual_y_frames() -> void:
	# Arrange & Act
	var packed := load(FUEGO_SCENE_PATH) as PackedScene
	var fuego: AnimatedSprite3D = packed.instantiate() as AnimatedSprite3D
	add_child_autofree(fuego)

	# Assert
	assert_eq(fuego.billboard, BaseMaterial3D.BILLBOARD_ENABLED, "Debe tener billboard activado para orientación fluida a cámara")
	assert_false(fuego.shaded, "El fuego no debe recibir sombras (shaded = false) para emitir luz propia")
	assert_almost_eq(fuego.offset.y, 74.0, MARGEN_FLOAT, "El offset vertical debe centrar la base de la llama en el origen")

	var sf: SpriteFrames = fuego.sprite_frames
	assert_not_null(sf, "Debe poseer un recurso SpriteFrames generado")
	assert_true(sf.has_animation(&"fuego"), "Debe contener la animación 'fuego'")
	assert_eq(sf.get_frame_count(&"fuego"), 12, "Debe contener exactamente los 12 cuadros de animación alineados")
	assert_almost_eq(sf.get_animation_speed(&"fuego"), 14.0, MARGEN_FLOAT, "La velocidad debe ser 14 FPS para máxima fluidez")
	assert_true(sf.get_animation_loop(&"fuego"), "La animación debe estar en bucle continuo")


func test_luz_calida_y_parametros() -> void:
	# Arrange
	var packed := load(FUEGO_SCENE_PATH) as PackedScene
	var fuego: AnimatedSprite3D = packed.instantiate() as AnimatedSprite3D
	add_child_autofree(fuego)

	# Act
	var luz: OmniLight3D = fuego.call("obtener_luz") as OmniLight3D

	# Assert
	assert_not_null(luz, "Debe existir la luz del fuego")
	assert_true(luz.visible, "La luz debe estar activa por defecto")
	assert_almost_eq(luz.light_color.r, 1.0, MARGEN_FLOAT, "Color rojo cálido")
	assert_gt(luz.light_color.g, 0.5, "Color verde para tonalidad dorada")
	assert_lt(luz.light_color.b, 0.5, "Color azul bajo para mantener tono fuego")
	assert_almost_eq(luz.omni_range, 3.5, MARGEN_FLOAT, "El alcance debe ser de pequeña luz (3.5m)")
	assert_almost_eq(luz.position.y, 0.45, MARGEN_FLOAT, "La luz debe ubicarse dentro del volumen de la llama")


func test_activar_desactivar_fuego() -> void:
	# Arrange
	var packed := load(FUEGO_SCENE_PATH) as PackedScene
	var fuego: AnimatedSprite3D = packed.instantiate() as AnimatedSprite3D
	add_child_autofree(fuego)

	# Act: Desactivar fuego
	fuego.call("set_fuego_activo", false)

	# Assert
	assert_false(fuego.visible, "El sprite no debe ser visible al desactivarse")
	assert_false(bool(fuego.get("luz_activa")), "La luz debe estar inactiva al desactivarse")
	var luz: OmniLight3D = fuego.call("obtener_luz") as OmniLight3D
	assert_false(luz.visible, "El nodo OmniLight3D debe ocultarse")

	# Act: Reactivar fuego
	fuego.call("set_fuego_activo", true)

	# Assert
	assert_true(fuego.visible, "El sprite debe volver a ser visible")
	assert_true(bool(fuego.get("luz_activa")), "La luz debe reactivarse")
	assert_true(luz.visible, "El nodo OmniLight3D debe volver a encenderse")


func test_difuminado_propiedad_y_shader() -> void:
	# Arrange
	var packed := load(FUEGO_SCENE_PATH) as PackedScene
	var fuego: AnimatedSprite3D = packed.instantiate() as AnimatedSprite3D
	add_child_autofree(fuego)

	# Assert inicial: difuminado = 0 por defecto (nítido)
	assert_almost_eq(float(fuego.get("difuminado")), 0.0, MARGEN_FLOAT, "Difuminado inicia en 0.0 (nítido)")
	assert_null(fuego.material_override, "material_override debe ser null cuando difuminado es 0")
	assert_false(bool(fuego.call("tiene_difuminado_activo")), "No debe estar activo el difuminado con 0.0")

	# Act: Aplicar difuminado
	fuego.set("difuminado", 2.5)

	# Assert: ShaderMaterial activo con el blur configurado
	assert_not_null(fuego.material_override, "material_override debe asignarse cuando difuminado > 0")
	assert_true(fuego.material_override is ShaderMaterial, "material_override debe ser ShaderMaterial")
	var mat := fuego.material_override as ShaderMaterial
	assert_almost_eq(float(mat.get_shader_parameter("blur_amount")), 2.5, MARGEN_FLOAT, "blur_amount debe coincidir")
	assert_true(bool(fuego.call("tiene_difuminado_activo")), "tiene_difuminado_activo debe ser true")

	# Act: Volver a poner difuminado en 0
	fuego.set("difuminado", 0.0)

	# Assert: Vuelve a ser null (renderizado nativo nítido)
	assert_null(fuego.material_override, "material_override debe regresar a null")
	assert_false(bool(fuego.call("tiene_difuminado_activo")), "tiene_difuminado_activo debe ser false")


func test_presencia_en_escenas_nivel_rio() -> void:
	# Arrange & Act: Comprobar que ambas escenas del río contienen un nodo independiente 'Fuego2D'
	var packed_usuario := load(RIO_ESCENA_USUARIO_PATH) as PackedScene
	assert_not_null(packed_usuario, "La escena de usuario del río debe cargar")
	var escena_usuario: Node = packed_usuario.instantiate()
	add_child_autofree(escena_usuario)

	var fuego_usuario: Node = escena_usuario.find_child("Fuego2D", true, false)
	assert_not_null(fuego_usuario, "La escena de usuario 'Rio en canoa con paralax' debe contener un nodo Fuego2D en el árbol")

	var packed_canon := load(RIO_ESCENA_CANONICA_PATH) as PackedScene
	assert_not_null(packed_canon, "La escena canónica del río debe cargar")
	var escena_canon: Node = packed_canon.instantiate()
	add_child_autofree(escena_canon)

	var fuego_canon: Node = escena_canon.find_child("Fuego2D", true, false)
	assert_not_null(fuego_canon, "La escena canónica debe contener un nodo Fuego2D en el árbol")


func test_bracero_pilar_soporta_fuego_manual() -> void:
	# Arrange
	var packed_bracero := load(BRACERO_SCENE_PATH) as PackedScene
	var bracero: Node3D = packed_bracero.instantiate() as Node3D
	add_child_autofree(bracero)

	# Assert inicial: BraceroPilar ya no fuerza un fuego hijo embebido oculto
	assert_null(bracero.call("obtener_fuego"), "BraceroPilar sin fuego hijo retorna null de forma segura")

	# Act: El usuario coloca un Fuego2D manualmente como hijo
	var packed_fuego := load(FUEGO_SCENE_PATH) as PackedScene
	var fuego: AnimatedSprite3D = packed_fuego.instantiate() as AnimatedSprite3D
	fuego.name = "Fuego2D"
	fuego.position = Vector3(0.0, 0.98, 0.0)
	bracero.add_child(fuego)

	# Assert: El bracero detecta el fuego manual y puede controlarlo
	assert_not_null(bracero.call("obtener_fuego"), "BraceroPilar reconoce el Fuego2D posicionado manualmente")
	bracero.set("fuego_activo", false)
	assert_false(fuego.visible, "El bracero apaga el fuego hijo correctamente")
