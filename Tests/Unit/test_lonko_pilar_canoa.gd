extends GutTest

const LONKO_SCENE: PackedScene = preload("res://Entities/Enemigo_Lonko/Lonko.tscn")
const ARROW_SCENE: PackedScene = preload("res://Entities/Proyectil_Flecha/Arrow.tscn")
const RIO_SCRIPT = preload("res://Levels/Rio_En_Canoa_Con_Parallax/Rio_En_Canoa_Con_Parallax.gd")

func test_flecha_jugador_desde_canoa_impacta_pilar_lonko():
	# Arrange
	var root := Node3D.new()
	add_child_autofree(root)

	# Mock de jugador en la canoa en Z = -7.5
	var mock_player := Node3D.new()
	mock_player.name = "MockPlayer"
	mock_player.add_to_group("player")
	root.add_child(mock_player)
	mock_player.global_position = Vector3(85.0, 0.5, -7.5)

	# Instanciar Lonko en la posición de Rio
	var lonko: Lonko = LONKO_SCENE.instantiate() as Lonko
	root.add_child(lonko)
	lonko.global_position = Vector3(97.158424, 0.059270263, -7.201269)
	await get_tree().process_frame

	# Act: Forzar activación y despliegue del pilar
	lonko._iniciar_secuencia_pilar()
	await get_tree().process_frame

	var pilar = lonko._instancia_pilar
	assert_not_null(pilar, "El pilar debe estar instanciado")
	var pilar_body = pilar.find_child("PilarBody", true, false) as PilarLonkoBody
	assert_not_null(pilar_body, "PilarBody debe existir")

	# Completar subida del pilar
	pilar.global_position = lonko._base_pos_pilar
	pilar_body.force_update_transform()
	await get_tree().physics_frame

	var vida_inicial = pilar_body.vida_pilar
	var col = pilar_body.find_child("CollisionShape3D", true, false) as CollisionShape3D
	assert_not_null(col, "CollisionShape3D debe existir en PilarBody")

	# Disparar flecha desde posición del jugador hacia el pilar a la profundidad de la canoa (Z = -7.5)
	var flecha = ARROW_SCENE.instantiate() as ArrowProjectile
	flecha.tipo_dueño = ArrowProjectile.TipoFlecha.JUGADOR
	root.add_child(flecha)
	flecha.global_position = Vector3(90.0, col.global_position.y, -7.5)
	flecha.initialize(Vector3.RIGHT, 40.0)

	for i in range(30):
		await get_tree().physics_frame
		if flecha.is_stuck or flecha._destroying:
			break

	# Assert
	assert_lt(pilar_body.vida_pilar, vida_inicial, "El pilar debe haber recibido daño de la flecha disparada desde la canoa")


func test_pilar_no_se_ahoga_en_nivel_rio():
	# Arrange: Nivel río con su sistema de escaneo de entidades caídas al agua
	var nivel_rio: Node3D = Node3D.new()
	nivel_rio.set_script(RIO_SCRIPT)
	nivel_rio.name = "Rio en canoa con paralax"
	add_child_autofree(nivel_rio)

	# Instanciar Lonko en el nivel
	var lonko: Lonko = LONKO_SCENE.instantiate() as Lonko
	nivel_rio.add_child(lonko)
	lonko.global_position = Vector3(97.158424, 0.059270263, -7.201269)
	await get_tree().process_frame

	# Act: Iniciar secuencia pilar (el pilar nace sumergido bajo el agua a Y = -3.14)
	lonko._iniciar_secuencia_pilar()
	await get_tree().process_frame

	var pilar = lonko._instancia_pilar
	assert_not_null(pilar, "El pilar debe estar instanciado")
	var pilar_body = pilar.find_child("PilarBody", true, false) as PilarLonkoBody
	assert_not_null(pilar_body, "PilarBody debe existir")

	# Simular el proceso de escaneo de agua del nivel del río
	nivel_rio.call("_procesar_enemigos_caidos_al_agua", 0.016)
	await get_tree().physics_frame

	# Assert: PilarBody NO debe haberse marcado como ahogado ni liberado ni deshabilitado
	assert_true(is_instance_valid(pilar_body), "PilarBody debe seguir existiendo y no haber sido eliminado por el agua")
	assert_false(pilar_body.has_meta("ahogado_en_agua"), "PilarBody no debe estar marcado como ahogado")
	assert_eq(pilar_body.collision_layer, 2, "PilarBody debe conservar su collision_layer intacto")
	var col = pilar_body.find_child("CollisionShape3D", true, false) as CollisionShape3D
	assert_false(col.disabled, "El colisionador de PilarBody debe permanecer habilitado")
