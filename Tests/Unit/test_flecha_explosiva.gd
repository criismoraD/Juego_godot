extends "res://addons/gut/test.gd"

var ArrowScript = load("res://System/Core/Arrow.gd")
var PilarLonkoBodyScript = load("res://Entities/Enemigo_Lonko/PilarLonkoBody.gd")
var EscudoScript = load("res://Entities/Ambiente_Escudo/Escudo.gd")

var _arrow: ArrowProjectile = null

func before_each():
	_arrow = ArrowScript.new()
	_arrow.es_explosiva = true
	_arrow.dano_base_explosiva = 3.0
	_arrow.bono_dano_estructuras = 6.0
	_arrow.radio_explosion = 4.84
	add_child_autofree(_arrow)

func test_arrow_explosiva_initialization():
	# Assert
	assert_true(_arrow.es_explosiva, "La flecha debe ser reconocida como explosiva")
	assert_eq(_arrow.dano_base_explosiva, 3.0, "El daño base explosivo debe ser 3.0")
	assert_eq(_arrow.bono_dano_estructuras, 6.0, "El bono de daño contra estructuras debe ser 6.0")
	assert_eq(_arrow.radio_explosion, 4.84, "El radio de explosión debe ser 4.84m")

func test_dano_pilar_dos_flechas_destruyen_15hp():
	# Arrange: Pilar de 15 HP
	var pilar = PilarLonkoBodyScript.new()
	pilar.vida_maxima = 15.0
	pilar.vida_pilar = 15.0
	add_child_autofree(pilar)

	# Assert inicial
	assert_eq(pilar.vida_maxima, 15.0, "La vida máxima del pilar debe ser 15.0 HP")
	assert_eq(pilar.vida_pilar, 15.0, "La vida inicial del pilar debe ser 15.0 HP")

	# Act: Primer impacto con flecha explosiva (3 base + 6 bono = 9 daño)
	var dano_infligido = _arrow.dano_base_explosiva + _arrow.bono_dano_estructuras
	pilar.take_damage(dano_infligido)

	# Assert 1er tiro
	assert_eq(pilar.vida_pilar, 6.0, "Tras el primer tiro (9 daño), la vida del pilar debe ser 6.0 HP")

	# Act: Segundo impacto con flecha explosiva (9 daño adicional)
	pilar.take_damage(dano_infligido)

	# Assert 2do tiro
	assert_true(pilar.vida_pilar <= 0.0, "Tras el segundo tiro, el pilar debe tener vida 0 (destruido con 2 flechazos)")

func test_dano_escudo_recibir_golpe_ampliado():
	# Arrange
	var escudo = EscudoScript.new()
	escudo.golpes_para_destruir = 3
	escudo.golpes_recibidos = 0
	add_child_autofree(escudo)

	# Act: Impacto de flecha explosiva con 10 de fuerza a estructura
	escudo.recibir_golpe(10)

	# Assert
	assert_gte(escudo.golpes_recibidos, 3, "Un impacto de flecha explosiva debe infligir suficiente daño para superar el umbral de rotura")


func test_flecha_explosiva_no_dana_escudos_aliados():
	# Arrange: Escudo aliado (es_escudo_enemigo = false)
	var escudo_aliado = EscudoScript.new()
	escudo_aliado.es_escudo_enemigo = false
	escudo_aliado.golpes_para_destruir = 3
	escudo_aliado.golpes_recibidos = 0
	escudo_aliado.add_to_group("escudos")
	add_child_autofree(escudo_aliado)

	# Posicionar flecha en el mismo punto
	_arrow.global_position = escudo_aliado.global_position

	# Act: Ejecutar explosión
	_arrow._explotar(escudo_aliado)

	# Assert: El escudo aliado no debe recibir daño
	assert_eq(escudo_aliado.golpes_recibidos, 0, "El escudo aliado NO debe recibir daño de la flecha explosiva aliada")


func test_explosion_scene_collider_radius_and_vfx():
	# Arrange
	var explosion_scene: PackedScene = preload("res://Entities/Flecha_Explosiva/ExplosionFlechaExplosiva.tscn")
	var expl = explosion_scene.instantiate() as ExplosionFlechaExplosiva
	add_child_autofree(expl)

	# Assert
	assert_not_null(expl.collision_shape, "Explosion scene must have a CollisionShape3D")
	assert_eq(expl.dano_base, 3.0, "Explosion base damage should default to 3.0")
	assert_eq(expl.bono_dano_estructuras, 6.0, "Explosion structure bonus should default to 6.0")
	assert_gte(expl._obtener_radio_dano(), 0.7, "Explosion shape radius should be at least 0.7m")
	assert_eq(expl.escala_vfx, Vector3(0.22, 0.22, 0.22), "Explosion VFX scale should be 0.22")
	assert_eq(expl.tamano_ceniza, Vector2(1.4, 1.4), "Ash decal size should be 1.4m")


func test_rastro_ceniza_generacion():
	# Arrange
	var explosion_scene: PackedScene = preload("res://Entities/Flecha_Explosiva/ExplosionFlechaExplosiva.tscn")
	var expl = explosion_scene.instantiate() as ExplosionFlechaExplosiva
	expl.position = Vector3(5.0, 0.0, 0.0)
	add_child_autofree(expl)

	# Act
	var rastro_ceniza = get_tree().root.find_child("RastroCenizaExplosion", true, false)
	if not rastro_ceniza and get_tree().current_scene:
		rastro_ceniza = get_tree().current_scene.find_child("RastroCenizaExplosion", true, false)

	# Assert
	assert_not_null(rastro_ceniza, "Debe haberse generado el nodo de RastroCenizaExplosion")
	if rastro_ceniza:
		assert_true(rastro_ceniza is MeshInstance3D, "El rastro de ceniza debe ser un MeshInstance3D")
		var mesh_inst := rastro_ceniza as MeshInstance3D
		assert_true(mesh_inst.mesh is QuadMesh, "La malla de ceniza debe ser un QuadMesh")
		if mesh_inst.mesh is QuadMesh:
			var quad := mesh_inst.mesh as QuadMesh
			assert_eq(quad.size, Vector2(1.4, 1.4), "El tamaño de la malla de ceniza debe ser 1.4x1.4")
		rastro_ceniza.queue_free()


func test_flecha_explosiva_scene_instantiation():
	# Arrange
	var scene_path = "res://Entities/Flecha_Explosiva/FlechaExplosiva.tscn"
	var scene = load(scene_path) as PackedScene
	assert_not_null(scene, "La escena FlechaExplosiva.tscn debe existir y cargarse")

	# Act
	var flecha = scene.instantiate() as ArrowProjectile
	add_child_autofree(flecha)

	# Assert
	assert_not_null(flecha, "Debe instanciarse correctamente como ArrowProjectile")
	assert_true(flecha.es_explosiva, "es_explosiva debe ser true en la escena")
	assert_eq(flecha.dano_base_explosiva, 3.0, "El daño base debe ser 3.0")
	assert_eq(flecha.bono_dano_estructuras, 6.0, "El bono contra estructuras debe ser 6.0")
	assert_eq(flecha.radio_explosion, 4.84, "El radio de explosión debe ser 4.84m")

	# Verificar nodos hijos esenciales
	var collision = flecha.get_node_or_null("CollisionShape3D")
	var modelo = flecha.get_node_or_null("Flecha_Explosiva2")
	if not modelo:
		modelo = flecha.get_node_or_null("FLECHA")
	var red_light = flecha.get_node_or_null("RedTipLight")
	var red_mesh = flecha.get_node_or_null("RedTipMesh")
	var trail = flecha.get_node_or_null("TrailParticles")

	assert_not_null(collision, "Debe tener CollisionShape3D")
	assert_not_null(modelo, "Debe tener el modelo 3D de la flecha")
	assert_not_null(red_light, "Debe tener RedTipLight")
	assert_not_null(red_mesh, "Debe tener RedTipMesh con esfera incandescente")
	assert_not_null(trail, "Debe tener TrailParticles")


func test_player_preloads_explosive_arrow_scene():
	var player_script = load("res://Entities/Jugador_Arquera/Player.gd")
	var player = player_script.new()
	assert_not_null(player.explosive_arrow_scene, "Player debe tener preloaded explosive_arrow_scene")
	player.free()


func test_ally_preloads_explosive_arrow_scene():
	var ally_script = load("res://Entities/Aliada_Arquera/AllyArcher.gd")
	var ally = ally_script.new()
	assert_not_null(ally.explosive_arrow_scene, "AllyArcher debe tener preloaded explosive_arrow_scene")
	ally.free()


func test_player_swaps_visual_arrow_with_ammo():
	# Arrange
	var player_script = load("res://Entities/Jugador_Arquera/Player.gd")
	var player = player_script.new()
	var dummy_arrow = Node3D.new()
	dummy_arrow.name = "FLECHA"
	var dummy_exp = Node3D.new()
	dummy_exp.name = "FLECHA_EXPLOSIVA_VISUAL"
	player.arrow_node = dummy_arrow
	player.explosive_arrow_node = dummy_exp
	player.add_child(dummy_arrow)
	player.add_child(dummy_exp)
	add_child_autofree(player)

	# Act 1: Con munición explosiva (flechas_explosivas = 5)
	player.flechas_explosivas = 5
	player._mostrar_flecha_visual(1.0)

	# Assert 1: Debe verse la flecha explosiva y ocultarse la normal
	assert_true(player.explosive_arrow_node.visible, "La flecha explosiva visual debe estar visible con munición > 0")
	assert_false(player.arrow_node.visible, "La flecha normal debe estar oculta con munición explosiva")

	# Act 2: Sin munición explosiva (flechas_explosivas = 0)
	player.flechas_explosivas = 0
	player._mostrar_flecha_visual(1.0)

	# Assert 2: Debe verse la flecha normal y ocultarse la explosiva
	assert_true(player.arrow_node.visible, "La flecha normal debe estar visible cuando flechas_explosivas == 0")
	assert_false(player.explosive_arrow_node.visible, "La flecha explosiva visual debe estar oculta cuando flechas_explosivas == 0")

	# Act 3: Ocultar flecha
	player._ocultar_flecha_visual()
	assert_false(player.arrow_node.visible, "Ambas flechas deben quedar ocultas")
	assert_false(player.explosive_arrow_node.visible, "Ambas flechas deben quedar ocultas")


func test_player_scene_finds_flecha_explosiva2():
	# Arrange & Act
	var scene = load("res://Entities/Jugador_Arquera/Player.tscn") as PackedScene
	assert_not_null(scene, "Player.tscn debe existir")
	var player = scene.instantiate()
	add_child_autofree(player)

	# Assert
	assert_not_null(player.explosive_arrow_node, "Player.tscn debe vincular explosive_arrow_node")
	assert_true("Flecha" in player.explosive_arrow_node.name, "Debe vincular el nodo de flecha explosiva")
	assert_false(player.explosive_arrow_node.visible, "Debe iniciar oculta")
	assert_false(player.arrow_node.visible, "Debe iniciar oculta")

	# Act: Cargar con munición
	player.flechas_explosivas = 5
	player._mostrar_flecha_visual(1.0)

	# Assert: FlechaExplosiva visible, FLECHA normal oculta
	assert_true(player.explosive_arrow_node.visible, "FlechaExplosiva debe hacerse visible al cargar con municion")
	assert_false(player.arrow_node.visible, "FLECHA debe permanecer oculta con municion")


func test_ally_scene_finds_flecha_explosiva():
	# Arrange & Act
	var scene = load("res://Entities/Aliada_Arquera/AllyArcher.tscn") as PackedScene
	assert_not_null(scene, "AllyArcher.tscn debe existir")
	var ally = scene.instantiate()
	add_child_autofree(ally)

	# Assert
	assert_not_null(ally.explosive_arrow_node, "AllyArcher.tscn debe vincular explosive_arrow_node")
	assert_true("Flecha" in ally.explosive_arrow_node.name, "Debe vincular el nodo de flecha explosiva")
	assert_false(ally.explosive_arrow_node.visible, "Debe iniciar oculta")

	# Act: Cargar con munición
	ally.flechas_explosivas = 5
	ally._mostrar_flecha()

	# Assert: FlechaExplosiva visible, FLECHA normal oculta
	assert_true(ally.explosive_arrow_node.visible, "FlechaExplosiva debe hacerse visible al cargar con municion")
	assert_false(ally.arrow_node.visible, "FLECHA debe permanecer oculta con municion")


func test_ally_disparar_spawns_explosive_projectile():
	# Arrange
	var scene = load("res://Entities/Aliada_Arquera/AllyArcher.tscn") as PackedScene
	var ally = scene.instantiate()
	add_child_autofree(ally)
	ally.flechas_explosivas = 1

	# Act
	var initial_child_count = get_tree().root.get_child_count()
	ally._disparar()

	# Assert
	assert_eq(ally.flechas_explosivas, 0, "Debe haber consumido 1 flecha explosiva")
	var new_child_count = get_tree().root.get_child_count()
	assert_gt(new_child_count, initial_child_count, "Debe haber instanciado un proyectil en el árbol")

	var spawned_arrow = get_tree().root.get_child(new_child_count - 1)
	assert_not_null(spawned_arrow, "El proyectil debe existir")
	assert_true(spawned_arrow.es_explosiva, "El proyectil disparado debe ser explosivo")
	assert_not_null(spawned_arrow.get_node_or_null("RedTipLight"), "El proyectil debe tener RedTipLight")
	spawned_arrow.queue_free()

