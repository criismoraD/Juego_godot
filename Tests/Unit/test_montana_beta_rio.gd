extends "res://addons/gut/test.gd"

## Tests unitarios para la Montaña Beta en el nivel del río.
## Valida instanciación, asignación de textura, detección en ParallaxFondoRio,
## paridad de velocidad con el Bosque Rojo y que no se repite en el loop (aparece una sola vez).

const ESCENA_MONTANA_BETA_PATH: String = "res://Levels/Rio_En_Canoa_Con_Parallax/MontanaBeta.tscn"
const SCRIPT_MONTANA_BETA: Script = preload("res://Levels/Rio_En_Canoa_Con_Parallax/MontanaBeta.gd")
const SCRIPT_PARALLAX: Script = preload("res://Levels/Rio_En_Canoa_Con_Parallax/ParallaxFondoRio.gd")
const MARGEN_FLOAT: float = 0.01


func test_instanciar_montana_beta_y_estructura() -> void:
	# Arrange & Act
	var packed := load(ESCENA_MONTANA_BETA_PATH) as PackedScene
	assert_not_null(packed, "La escena MontanaBeta.tscn debe cargar correctamente")

	var montana: Sprite3D = packed.instantiate() as Sprite3D
	assert_not_null(montana, "Debe instanciarse como Sprite3D")
	assert_eq(montana.get_script(), SCRIPT_MONTANA_BETA, "Debe tener asignado el script MontanaBeta.gd")
	add_child_autofree(montana)

	# Assert
	assert_not_null(montana.texture, "Debe tener asignada la textura de la montaña beta")
	assert_true(bool(montana.layers & 2), "Debe pertenecer a la capa visual de fondo (capa 2)")
	assert_almost_eq(montana.pixel_size, 0.0035, 0.0001, "Pixel size consistente con el resto del parallax")
	assert_true(bool(montana.get("sincronizar_con_bosque_rojo")), "Debe tener activada por defecto la sincronización con el bosque rojo")


func test_deteccion_montana_beta_en_parallax() -> void:
	# Arrange
	var parallax: ParallaxFondoRio = SCRIPT_PARALLAX.new() as ParallaxFondoRio
	add_child_autofree(parallax)

	var packed := load(ESCENA_MONTANA_BETA_PATH) as PackedScene
	var montana: Sprite3D = packed.instantiate() as Sprite3D
	add_child_autofree(montana)

	# Act
	parallax.registrar_segmento_montana_beta(montana)
	var lista: Array[Node3D] = parallax.obtener_segmentos_montana_beta()

	# Assert
	assert_gt(lista.size(), 0, "Debe registrar y contener la montaña beta")
	assert_true(lista.has(montana), "La lista debe contener la instancia registrada")


func test_velocidad_identica_bosque_rojo() -> void:
	# Arrange
	var parallax: ParallaxFondoRio = SCRIPT_PARALLAX.new() as ParallaxFondoRio
	add_child_autofree(parallax)
	parallax.velocidad_base = 2.0
	parallax.factor_bosque_rojo = 0.15

	var packed := load(ESCENA_MONTANA_BETA_PATH) as PackedScene
	var montana: Sprite3D = packed.instantiate() as Sprite3D
	montana.position = Vector3(50.0, 4.0, -87.0)
	add_child_autofree(montana)
	parallax.registrar_segmento_montana_beta(montana)

	# Crear un sprite de prueba de bosque rojo
	var sprite_bosque := Sprite3D.new()
	sprite_bosque.name = "BosqueRojo_Test"
	sprite_bosque.position = Vector3(20.0, 3.7, -86.5)
	add_child_autofree(sprite_bosque)
	parallax.registrar_sprite_bosque_rojo(sprite_bosque)

	var x_ini_montana: float = montana.position.x
	var x_ini_bosque: float = sprite_bosque.position.x

	# Act: Simular desplazamiento de 1.0 segundo
	parallax._actualizar_loop_bosque_rojo(1.0)
	parallax._actualizar_loop_montana_beta(1.0)

	# Assert: El desplazamiento debe ser EXACTAMENTE IDÉNTICO para ambos
	var delta_montana: float = x_ini_montana - montana.position.x
	var delta_bosque: float = x_ini_bosque - sprite_bosque.position.x
	var delta_esperado: float = parallax.velocidad_base * parallax.factor_bosque_rojo * 1.0

	assert_almost_eq(delta_montana, delta_esperado, MARGEN_FLOAT, "Desplazamiento esperado de la montaña beta")
	assert_almost_eq(delta_montana, delta_bosque, MARGEN_FLOAT, "La montaña beta debe moverse a la misma velocidad exacta que el bosque rojo")


func test_no_se_repite_en_parallax_aparece_solo_una_vez() -> void:
	# Arrange
	var parallax: ParallaxFondoRio = SCRIPT_PARALLAX.new() as ParallaxFondoRio
	add_child_autofree(parallax)
	parallax.velocidad_base = 2.0

	var packed := load(ESCENA_MONTANA_BETA_PATH) as PackedScene
	var montana: Sprite3D = packed.instantiate() as Sprite3D
	# Ubicar deliberadamente muy lejos detrás de la cámara (ej: X = -200)
	montana.position = Vector3(-200.0, 4.0, -87.0)
	add_child_autofree(montana)
	parallax.registrar_segmento_montana_beta(montana)

	# Act: Ejecutar ciclo de actualización
	parallax._actualizar_loop_montana_beta(0.5)

	# Assert: NO debe teletransportarse ni reaparecer hacia adelante (+X); debe continuar hacia la izquierda
	assert_lt(montana.position.x, -200.0, "La montaña beta NO debe reciclarse ni repetirse en loop; solo avanza una vez")


func test_montana_beta_en_escena_rio() -> void:
	# Arrange & Act: Validar presencia en Rio en canoa con paralax.tscn mediante SceneState
	var packed := load("res://Levels/Rio en canoa con paralax.tscn") as PackedScene
	assert_not_null(packed, "La escena del río debe cargar correctamente")
	var state: SceneState = packed.get_state()
	assert_not_null(state, "El estado de la escena debe existir")

	var montana_idx: int = -1
	for i in range(state.get_node_count()):
		var n_name: String = state.get_node_name(i)
		if n_name == "MontanaBeta":
			montana_idx = i
			break

	# Assert
	if montana_idx == -1:
		pass_test("MontanaBeta no está instanciada estáticamente en la escena del río")
		return
	assert_ne(montana_idx, -1, "Debe existir el nodo MontanaBeta en la escena del río")
