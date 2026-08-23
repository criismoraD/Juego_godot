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
	assert_gte(expl._obtener_radio_dano(), 2.2, "Explosion shape radius should be at least 2.2m")
	assert_eq(expl.escala_vfx, Vector3(0.22, 0.22, 0.22), "Explosion VFX scale should be 0.22")
	assert_eq(expl.tamano_ceniza, Vector2(1.43, 1.43), "Ash decal size should be 1.43m")


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
			assert_eq(quad.size, Vector2(1.43, 1.43), "El tamaño de la malla de ceniza debe ser 1.43x1.43")
		rastro_ceniza.queue_free()

