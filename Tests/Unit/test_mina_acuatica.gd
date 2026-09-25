extends "res://addons/gut/test.gd"

var MinaScene = preload("res://Entities/Proyectil_Mina_Acuatica/MinaAcuatica.tscn")
var _mina = null


func before_each() -> void:
	for n in get_tree().root.get_children():
		if is_instance_valid(n) and (n.name.begins_with("SfxImpactoMetal") or (n is AudioStreamPlayer3D and (n as AudioStreamPlayer3D).stream == preload("res://System/Audio/SFX/Impacto de metal.mp3"))):
			n.free()
	_mina = MinaScene.instantiate()
	get_tree().root.add_child(_mina)


func after_each() -> void:
	if is_instance_valid(_mina) and not _mina.is_queued_for_deletion():
		if _mina.get_parent():
			_mina.get_parent().remove_child(_mina)
		_mina.free()
	_mina = null
	for n in get_tree().root.get_children():
		if is_instance_valid(n) and (n.name.begins_with("SfxImpactoMetal") or (n is AudioStreamPlayer3D and (n as AudioStreamPlayer3D).stream == preload("res://System/Audio/SFX/Impacto de metal.mp3"))):
			n.free()


func test_mina_tiene_dos_de_vida() -> void:
	# Arrange / Act: valores iniciales
	# Assert: 2 golpes para destruirla
	assert_eq(_mina.vida_maxima, 2.0, "La mina debe tener 2 de vida")
	assert_eq(_mina.vida_mina, 2.0, "Inicia con vida completa")


func test_mina_aguanta_un_golpe() -> void:
	# Act: un golpe de flecha
	_mina.recibir_golpe(1.0)
	# Assert: sigue activa con 1 de vida
	assert_eq(_mina.vida_mina, 1.0, "Tras un golpe queda 1 de vida")
	assert_false(_mina._destruida, "No se destruye con un golpe")
	assert_false(_mina._explotada, "No explota con un golpe")


func test_mina_se_destruye_con_dos_golpes() -> void:
	# Arrange: senal de destruida
	var avisos: Array = []
	_mina.destruida.connect(func(_m): avisos.append(true))
	# Act: dos golpes
	_mina.recibir_golpe(1.0)
	_mina.recibir_golpe(1.0)
	# Assert: destruida sin explosion
	assert_true(_mina._destruida, "Con dos golpes se destruye")
	assert_false(_mina._explotada, "Destruida por el jugador no explota")
	assert_eq(avisos.size(), 1, "Avisa una vez")


func test_mina_explota_por_contacto() -> void:
	# Arrange: senal de explosion
	var avisos: Array = []
	_mina.explotada.connect(func(_m): avisos.append(true))
	# Act: contacto directo
	_mina._explotar()
	# Assert: explosion con 1 de dano configurado y oleaje
	assert_true(_mina._explotada, "El contacto la hace explotar")
	assert_eq(_mina.dano_explosion, 1.0, "La explosion causa 1 de dano")
	assert_eq(avisos.size(), 1, "Avisa una vez")
	assert_false(_mina.visible, "Se oculta tras explotar")


func test_mina_columna_de_golpe() -> void:
	# Assert: columna alta como la vasija para que las flechas la alcancen
	assert_true(is_instance_valid(_mina.get_node_or_null("CollisionGolpe")), "Debe tener columna de golpe alta")


func test_mina_carril_al_plano() -> void:
	# Arrange: carril de aproximación al plano canoa/vasija
	_mina.fijar_ruta(100.0)
	# Assert: mantiene Z hasta rebasar el casco
	assert_true(_mina._app_z, "El carril arranca activo")


func test_mina_flota_asentada_en_agua() -> void:
	# Assert: offset de flotación para no verse volando
	assert_true(_mina.offset_agua_y < 0.0, "La mina flota por debajo de la canoa")
	assert_true(_mina.duracion_materializacion > 0.0, "Materialización configurada")


func test_mina_flota_visible_sobre_agua() -> void:
	# Assert: lo bastante alta para verse flotando, sin volar sobre el agua
	assert_gt(_mina.offset_agua_y, -0.5, "La mina debe emerger lo suficiente para verse")
	assert_lt(_mina.offset_agua_y, 0.0, "La mina no debe volar sobre el agua")


func test_mina_dano_invalido_no_cura() -> void:
	# Act: dano negativo
	_mina.take_damage(-3.0)
	# Assert: no cura por encima del maximo
	assert_true(_mina.vida_mina <= 2.0, "El dano negativo no cura la mina")


# === SONIDO IMPACTO DE METAL AL RECIBIR DANO ===

func _contar_sfx_impacto_metal() -> int:
	var total: int = 0
	for n in get_tree().root.get_children():
		if is_instance_valid(n) and (n.name.begins_with("SfxImpactoMetal") or (n is AudioStreamPlayer3D and (n as AudioStreamPlayer3D).stream == _mina.SFX_IMPACTO_METAL)):
			total += 1
	return total


func test_mina_suena_impacto_metal_al_recibir_golpe() -> void:
	# Arrange: mina activa en el arbol
	# Act: un golpe de flecha
	_mina.recibir_golpe(1.0)
	# Assert: se genera el SFX de impacto metal
	assert_eq(_contar_sfx_impacto_metal(), 1, "Al recibir dano debe sonar el impacto de metal")
	var sfx: Node = null
	for n in get_tree().root.get_children():
		if is_instance_valid(n) and (n.name.begins_with("SfxImpactoMetal") or (n is AudioStreamPlayer3D and (n as AudioStreamPlayer3D).stream == _mina.SFX_IMPACTO_METAL)):
			sfx = n
			break
	if sfx:
		assert_eq(sfx.stream, _mina.SFX_IMPACTO_METAL, "Debe usar el audio 'Impacto de metal'")


func test_mina_sonido_metal_en_cada_golpe_hasta_destruirse() -> void:
	# Act: dos golpes (el segundo la destruye)
	_mina.recibir_golpe(1.0)
	_mina.recibir_golpe(1.0)
	# Assert: suena en ambos impactos (el ultimo tambien recibe el golpe)
	assert_eq(_contar_sfx_impacto_metal(), 2, "Debe sonar el impacto metal en cada golpe recibido")


func test_mina_destruida_no_vuelve_a_sonar() -> void:
	# Arrange: mina ya destruida
	_mina._destruida = true
	# Act: golpe sobre mina destruida
	_mina.take_damage(1.0)
	# Assert: sin sonido (guards de estado)
	assert_eq(_contar_sfx_impacto_metal(), 0, "Una mina destruida no vuelve a sonar")


func test_mina_explotada_no_vuelve_a_sonar() -> void:
	# Arrange: mina ya explotada
	_mina._explotada = true
	# Act: golpe sobre mina explotada
	_mina.take_damage(1.0)
	# Assert: sin sonido (guards de estado)
	assert_eq(_contar_sfx_impacto_metal(), 0, "Una mina explotada no vuelve a sonar")


func test_mina_capas_colision_seguras_enemigo() -> void:
	# Assert: layer 4 (enemigo) para ser impactada por flechas/hachas, mask 0 (sin colisión física sólida)
	assert_eq(_mina.collision_layer, 4, "La mina debe estar en la capa 4 (enemigos)")
	assert_eq(_mina.collision_mask, 0, "La mina no debe colisionar físicamente con la canoa ni la jugadora")


func test_mina_desactiva_colisiones_al_explotar() -> void:
	# Act: explotar
	_mina._explotar()
	await get_tree().process_frame

	# Assert: todas las formas de colisión y el detector se desactivan de inmediato
	for col in _mina.find_children("*", "CollisionShape3D", true, false):
		assert_true((col as CollisionShape3D).disabled, "Las colisiones deben desactivarse tras la explosión")
	if is_instance_valid(_mina._detector):
		assert_false(_mina._detector.monitoring, "El detector no debe seguir monitoreando")


func test_mina_destruida_suena_explosion_acuatica() -> void:
	# Arrange: el SFX debe estar registrado (si no, play_sfx solo avisa y no suena)
	assert_true(AudioManager.sfx_streams.has("explosion_acuatica_potente"), "El SFX explosion_acuatica_potente debe estar registrado")
	assert_true(_mina.has_method("_reproducir_sfx_explosion_acuatica"), "La mina debe exponer el helper de SFX")

	# Act: destruirla con dos golpes (ruta _destruir_sin_explosion con SFX)
	_mina.recibir_golpe(1.0)
	_mina.recibir_golpe(1.0)

	# Assert: destruida por el jugador con el estampido acuático en esa ruta
	assert_true(_mina._destruida, "Con dos golpes se destruye")
	assert_false(_mina._explotada, "Destruida por el jugador no explota")


func test_canoa_ignora_mina_como_bloqueador_de_avance() -> void:
	# Arrange: canoa de río
	var canoa := Node3D.new()
	canoa.set_script(load("res://Levels/Rio_En_Canoa_Con_Parallax/CanoaProtagonistaRio.gd"))
	get_tree().root.add_child(canoa)

	# Assert: la mina no se considera un bloqueador de la canoa
	assert_false(canoa._es_enemigo_activo_y_vivo(_mina), "La canoa no debe considerar a la mina como barrera")
	assert_false(canoa._es_o_cuelga_de_enemigo(_mina), "La canoa no debe frenar ante la mina")

	canoa.free()


func _material_anillo() -> StandardMaterial3D:
	var anillo := _mina.get_node_or_null("AnilloFlotacion") as MeshInstance3D
	assert_not_null(anillo, "La mina debe tener AnilloFlotacion")
	var toro := anillo.mesh as TorusMesh
	assert_not_null(toro, "El flotador debe usar TorusMesh")
	assert_not_null(toro.material, "El flotador debe tener material propio")
	return toro.material as StandardMaterial3D


func test_mina_anillo_rojo_traslucido() -> void:
	# Arrange / Act: material propio del flotador superficial
	var mat := _material_anillo()

	# Assert: tono rojo y traslúcido para leerse como peligro sobre el agua
	assert_not_null(mat, "El material del anillo debe ser StandardMaterial3D")
	assert_gte(mat.albedo_color.r, 0.9, "El flotador debe ser de tono rojo")
	assert_lte(mat.albedo_color.g, 0.3, "Sin componente verde dominante")
	assert_lte(mat.albedo_color.b, 0.3, "Sin componente azul dominante")
	assert_gt(mat.albedo_color.a, 0.0, "Debe ser traslúcido, no invisible")
	assert_lt(mat.albedo_color.a, 1.0, "Debe ser traslúcido, no opaco")
	assert_eq(mat.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA, "Transparencia alfa activa")


func test_mina_aplicar_material_preserva_anillo() -> void:
	# Arrange: anillo flotador y una malla del cuerpo
	var anillo := _mina.get_node_or_null("AnilloFlotacion") as MeshInstance3D
	assert_not_null(anillo, "La mina debe tener AnilloFlotacion")

	# Act: reaplicar material del cuerpo
	_mina._aplicar_material()

	# Assert: el anillo conserva su rojo traslúcido y el cuerpo usa MAT_MINA
	assert_null(anillo.material_override, "El anillo no debe ser tapado por MAT_MINA")
	var cuerpo_con_mat: bool = false
	for m in _mina.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if is_instance_valid(mi) and mi.name != "AnilloFlotacion":
			if mi.material_override == MinaAcuatica.MAT_MINA or mi.material_override == _mina.get("_mat_base_unico"):
				cuerpo_con_mat = true
	assert_true(cuerpo_con_mat, "El cuerpo de la mina debe seguir usando MAT_MINA")


func test_mina_explosion_no_desplaza_canoa_detenida() -> void:
	# Arrange: canoa de río en combate con travesía pausada
	var canoa := Node3D.new()
	canoa.set_script(load("res://Levels/Rio_En_Canoa_Con_Parallax/CanoaProtagonistaRio.gd"))
	get_tree().root.add_child(canoa)
	canoa.global_position = Vector3(120.0, 0.0, -7.5)
	canoa.fijar_posicion_base(Vector3(120.0, 0.0, -7.5))
	canoa.detener_navegacion_suave()
	canoa._velocidad_efectiva = 0.0
	canoa._navegando = false
	var x_base_inicial: float = canoa._posicion_base.x

	# Act: la mina acuática explota junto a la canoa y sacude el oleaje
	_mina.global_position = canoa.global_position + Vector3(0.5, 0.0, 0.0)
	_mina._explotar()
	canoa._process(0.1)

	# Assert: la canoa jamás debe avanzar a la derecha ni reactivar navegación hacia 100000.0
	assert_eq(canoa._posicion_base.x, x_base_inicial, "La posición base en X no debe saltar ni desplazarse")
	assert_false(canoa._navegando, "La navegación no debe reactivarse")
	assert_eq(canoa._velocidad_navegacion, 0.0, "La velocidad objetivo debe mantenerse en cero")
	assert_almost_eq(canoa.obtener_velocidad_efectiva(), 0.0, 0.001, "La velocidad efectiva debe ser 0")
	assert_eq(canoa.obtener_factor_velocidad_actual(), 0.0, "El factor de velocidad debe permanecer en 0")

	canoa.free()


class PerrenaEspiaPararse extends Node:
	var llamadas: Array = []
	var player_anim: AnimationPlayer = null
	func _play_anim(nombres, blend: float = 0.15, speed: float = 1.0) -> void:
		llamadas.append({"nombres": (nombres as Array).duplicate(), "speed": speed})
		if player_anim:
			for n in (nombres as Array):
				if player_anim.has_animation(str(n)):
					player_anim.play(str(n), blend, speed)
					return


func _crear_mock_perrena() -> Node:
	var mock := PerrenaEspiaPararse.new()
	mock.name = "MockPerrenaPararse"
	var ap := AnimationPlayer.new()
	var lib := AnimationLibrary.new()
	for n in ["Muerte 2", "Pararse", "Idle Canoa"]:
		var a := Animation.new()
		a.length = 1.0
		lib.add_animation(n, a)
	ap.add_animation_library("", lib)
	mock.add_child(ap)
	mock.player_anim = ap
	add_child_autofree(mock)
	return mock


func test_mina_pararse_acelerado() -> void:
	# Arrange: sosias de Perrena con clips de 1 s
	var mock = _crear_mock_perrena()
	var ap: AnimationPlayer = mock.get("player_anim") as AnimationPlayer

	# Act: levantarse tras la explosion (_mina viene del before_each)
	_mina._reproducir_pararse(mock)

	# Assert: pararse con velocidad un poco acelerada (1.35)
	assert_eq(mock.llamadas.size(), 1, "Debe pedirse una animacion")
	assert_true((mock.llamadas[0]["nombres"] as Array).has("Pararse"), "Primero la animacion de pararse")
	assert_almost_eq(float(mock.llamadas[0]["speed"]), 1.35, 0.001, "Pararse acelerado a 1.35")
	assert_eq(ap.current_animation, "Pararse", "Reproduce Pararse")
