extends "res://addons/gut/test.gd"

## Tests del Pirata Goblin: variante del Imp con asset propio.
## Verifica instanciación, herencia de comportamiento, alias de animaciones,
## material con su textura y spawn forzado id 13 para el panel debug.

const PIRATA_SCENE: PackedScene = preload("res://Entities/Enemigo_Pirata_Goblin/PirataGoblin.tscn")

var _root_test: Node3D = null


func before_each() -> void:
	_root_test = Node3D.new()
	_root_test.name = "RootTestPirata"
	get_tree().root.add_child(_root_test)


func after_each() -> void:
	if is_instance_valid(_root_test):
		_root_test.free()
	for n in get_tree().root.get_children():
		if n is PirataGoblin:
			n.free()


func _crear_pirata() -> PirataGoblin:
	var pirata := PIRATA_SCENE.instantiate() as PirataGoblin
	assert_not_null(pirata, "Debe instanciar PirataGoblin")
	_root_test.add_child(pirata)
	await get_tree().process_frame
	return pirata


func test_instanciar_es_variante_del_imp() -> void:
	# Arrange & Act
	var pirata := await _crear_pirata()

	# Assert: hereda todo lo del Imp
	assert_true(pirata is ImpEnemy, "PirataGoblin debe ser un ImpEnemy")
	assert_true(pirata is EnemyBase, "Debe ser un EnemyBase")
	assert_true(pirata.is_in_group("enemies"), "Debe estar en el grupo de enemigos")
	assert_eq(pirata.vida_maxima, 1, "Misma vida frágil del Imp (1)")
	assert_not_null(pirata.find_child("ImpModel", true, false), "Modelo presente (nodo compat ImpModel)")
	assert_not_null(pirata.find_child("CollisionShape3D", true, false), "Debe tener colisión")


func test_animaciones_con_alias_del_imp() -> void:
	# Arrange & Act
	var pirata := await _crear_pirata()

	# Assert: cada nombre del Imp resuelve a una animación real del pirata
	assert_not_null(pirata.anim_player, "Debe resolver AnimationPlayer")
	var esperados := {
		"CAMINAR": "Strut Walking",
		"CORRER": "Correr",
		"IDLE": "Idle",
		"LANZAR01": "Ataque arrojar",
		"LANZAR2": "Disparo",
		"IMP_MUERTE01": "Muerte 1",
		"IMP_MUERTE02": "Muerte 2",
	}
	for alias in esperados:
		assert_true(pirata.anim_player.has_animation(alias), "Alias registrado: " + alias)
		assert_almost_eq(
			pirata.anim_player.get_animation(alias).length,
			pirata.anim_player.get_animation(esperados[alias]).length,
			0.001, "El alias comparte el clip: " + alias
		)
	for alias in ["CAMINAR", "CORRER", "IDLE"]:
		assert_eq(
			pirata.anim_player.get_animation(alias).loop_mode, Animation.LOOP_LINEAR,
			"Movimiento en loop: " + alias
		)


func test_material_con_textura_pirata() -> void:
	# Arrange & Act
	var pirata := await _crear_pirata()

	# Assert: material propio con su difuso (no el del Imp)
	var con_textura := false
	for m in pirata.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi == null:
			continue
		var mat: Material = mi.material_override
		if mat == null and mi.mesh and mi.mesh.get_surface_count() > 0:
			mat = mi.mesh.surface_get_material(0)
		if mat is StandardMaterial3D:
			var std := mat as StandardMaterial3D
			if std.albedo_texture and "PirataGoblin_D" in std.albedo_texture.resource_path:
				con_textura = true
				break
	assert_true(con_textura, "Alguna malla debe usar la textura PirataGoblin_D")


func test_ciclo_caminar_y_disparo_heredado() -> void:
	# Arrange
	var pirata := await _crear_pirata()

	# Act: entrar a tiro y saltar la pausa IDLE para forzar el lanzamiento
	pirata._on_state_shooting()
	pirata.is_idle_pause = false
	pirata._process_shooting(0.05)

	# Assert: entra al ciclo de lanzamiento heredado sin romperse
	assert_true(pirata.is_throwing, "Debe entrar al lanzamiento del Imp")
	assert_gt(pirata.throw_anim_duration, 0.0, "La animación aliaseada debe tener duración")


func test_disparo_gira_modelo_y_demas_anims_restauran_base() -> void:
	# Arrange
	var pirata := await _crear_pirata()
	var modelo := pirata.get_node_or_null("ImpModel") as Node3D
	assert_not_null(modelo, "Debe existir el nodo ImpModel")
	var yaw_base: float = modelo.rotation.y
	pirata.grados_extra_disparo = 90.0

	# Act: reproducir el disparo (alias LANZAR2 -> "Disparo")
	pirata._play_animation("LANZAR2")

	# Assert: solo el disparo aplica el giro extra
	assert_almost_eq(modelo.rotation.y, yaw_base + deg_to_rad(90.0), 0.001, "LANZAR2 debe girar el modelo 90° extra")

	# Act & Assert: cualquier otra animación restaura la base intacta
	pirata._play_animation("LANZAR01")
	assert_almost_eq(modelo.rotation.y, yaw_base, 0.001, "LANZAR01 no debe girar el modelo")
	pirata._play_animation("LANZAR2")
	pirata._play_animation("IDLE")
	assert_almost_eq(modelo.rotation.y, yaw_base, 0.001, "IDLE debe restaurar la orientación base")
	pirata._play_animation("LANZAR2")
	pirata._play_animation("CAMINAR")
	assert_almost_eq(modelo.rotation.y, yaw_base, 0.001, "CAMINAR debe mantener la base sin girar")


func test_pirata_dispara_espada_en_vez_de_tridente() -> void:
	# Arrange & Act
	var pirata := await _crear_pirata()

	# Assert: el proyectil configurado es la espada pirata
	assert_not_null(pirata.imp_arrow_scene, "Debe tener escena de proyectil configurada")
	var espada := (pirata.imp_arrow_scene as PackedScene).instantiate() as EspadaPirataProjectile
	assert_not_null(espada, "El proyectil del pirata debe instanciar EspadaPirata")
	assert_true(espada is ImpTridentProjectile, "La espada debe ser compatible con el pool/cast del tridente del Imp")
	espada.free()


func test_pirata_usa_sonido_lanzar_espada_al_atacar() -> void:
	# Arrange & Act
	var pirata := await _crear_pirata()

	# Assert: el ataque suena a espada, no a tridente
	assert_eq(pirata.sfx_lanzamiento, "lanzar_espada_pirata", "El pirata debe lanzar con sonido de espada")
	assert_true(ResourceLoader.exists("res://Entities/Enemigo_Pirata_Goblin/Audio/lanzar espada pirata.mp3"), "Debe existir el audio de lanzar espada")


func test_pistola_usa_sonido_disparo_propio() -> void:
	# Arrange
	var am := get_tree().root.get_node_or_null("AudioManager")
	assert_not_null(am, "Debe existir el AudioManager autoload en tests")

	# Assert: clave registrada con el mp3 de la pistola
	assert_true(am.sfx_streams.has("disparo_pistola_pirata_gob"), "AudioManager debe registrar el disparo de pistola pirata")
	assert_true(ResourceLoader.exists("res://Entities/Enemigo_Pirata_Goblin/Audio/disparo pistola pirata gob.mp3"), "Debe existir el audio del pistoletazo")


func test_espada_gira_todo_el_trayecto() -> void:
	# Arrange: espada en vuelo ascendente
	var pirata := await _crear_pirata()
	var espada := (pirata.imp_arrow_scene as PackedScene).instantiate() as EspadaPirataProjectile
	_root_test.add_child(espada)
	espada.global_position = Vector3(0.0, 5.0, 0.0)
	espada.initialize(Vector3(-1.0, 0.5, 0.0).normalized(), 1.0)
	var modelo := espada.get_node_or_null("EspadaModel") as Node3D
	assert_not_null(modelo, "Debe existir el nodo EspadaModel")

	# Act: 10 frames subiendo (direction.y > 0)
	var z0: float = modelo.rotation.z
	for i in range(10):
		espada._physics_process(0.016)
	var giro_subiendo: float = absf(modelo.rotation.z - z0)

	# Assert: giro continuo en subida (16 rad/s * 0.16s ≈ 2.56 rad)
	assert_gt(giro_subiendo, 1.5, "Subiendo la espada debe girar continuamente")

	# Act: 20 frames cayendo (direction.y negativa)
	espada.global_position = Vector3(0.0, 50.0, 0.0)
	espada.direction = Vector3(-1.0, -0.5, 0.0).normalized()
	var giro_cayendo: float = 0.0
	var z_prev: float = modelo.rotation.z
	for i in range(20):
		espada._physics_process(0.016)
		giro_cayendo += absf(angle_difference(modelo.rotation.z, z_prev))
		z_prev = modelo.rotation.z

	# Assert: debe seguir girando todo el trayecto de caída sin detenerse (~5.12 rad)
	assert_gt(giro_cayendo, 4.0, "Cayendo la espada debe seguir girando todo el trayecto")


func test_espada_cae_clavada_con_punta_y_filo() -> void:
	# Arrange: espada lanzada hacia abajo y a la izquierda
	var pirata := await _crear_pirata()
	var espada := (pirata.imp_arrow_scene as PackedScene).instantiate() as EspadaPirataProjectile
	_root_test.add_child(espada)
	espada.global_position = Vector3(0.0, 5.0, 0.0)
	var dir_lanzamiento := Vector3(-1.0, -1.0, 0.0).normalized()
	espada.initialize(dir_lanzamiento, 1.0)
	var modelo := espada.get_node_or_null("EspadaModel") as Node3D
	assert_not_null(modelo, "Debe existir el nodo EspadaModel")

	# Simular suelo estático (canoa o terreno)
	var suelo := StaticBody3D.new()
	suelo.name = "SueloTest"
	_root_test.add_child(suelo)

	# Act: la espada impacta y se clava en la superficie
	espada._stick_to_surface(suelo)

	# Assert: queda clavada
	assert_true(espada.is_stuck, "La espada debe quedar marcada como clavada (is_stuck)")

	# Assert: la punta (local -X) debe apuntar en la dirección del impacto
	var punta_mundo: Vector3 = modelo.basis * Vector3(-1, 0, 0)
	assert_gt(punta_mundo.dot(dir_lanzamiento), 0.95, "La punta (-X) debe apuntar en la dirección de la caída")

	# Assert: el filo de la hoja (local -Y) debe apuntar hacia abajo (hacia el suelo/corte)
	var filo_mundo: Vector3 = modelo.basis * Vector3(0, -1, 0)
	assert_lt(filo_mundo.y, 0.0, "El filo de la hoja (-Y) debe apuntar hacia abajo")

	# Assert: la empuñadura (local +X) debe apuntar hacia arriba/afuera de la superficie
	var empunadura_mundo: Vector3 = modelo.basis * Vector3(1, 0, 0)
	assert_gt(empunadura_mundo.y, 0.0, "La empuñadura (+X) debe quedar hacia arriba")


func _contar_proyectiles() -> Dictionary:
	var cuenta := {"bala": 0, "espada": 0}
	for n in get_tree().root.find_children("*", "Area3D", true, false):
		if n is BalaCanonProjectile:
			cuenta["bala"] += 1
		elif n is EspadaPirataProjectile:
			cuenta["espada"] += 1
	return cuenta


func _crear_jugador_falso() -> Node3D:
	var player := Node3D.new()
	player.name = "PlayerFalsoPirata"
	player.add_to_group("player")
	get_tree().root.add_child(player)
	return player


func _liberar_jugador_falso(player: Node) -> void:
	if is_instance_valid(player):
		player.remove_from_group("player")
		player.free()


func test_disparo_pistola_lanza_bala_canon_recta() -> void:
	# Arrange: pirata + jugadora a la izquierda
	var pirata := await _crear_pirata()
	var player := _crear_jugador_falso()
	player.global_position = pirata.global_position + Vector3(-5.0, 0.0, 0.0)
	pirata.player_ref = player
	var antes: Dictionary = _contar_proyectiles()

	# Act: ataque Disparo (LANZAR2 = pistola pirata)
	pirata.current_throw_anim = "LANZAR2"
	pirata._throw_projectile()

	# Assert: aparece una bala de cañón y ninguna espada extra
	var despues: Dictionary = _contar_proyectiles()
	assert_eq(despues["bala"], antes["bala"] + 1, "Disparo debe lanzar una bala de cañón")
	assert_eq(despues["espada"], antes["espada"], "Disparo no debe arrojar espadas")

	# Act & Assert: la bala vuela en línea recta (direction.y no decae)
	var bala := _ultima_bala()
	assert_not_null(bala, "Debe existir la bala disparada")
	var dy0: float = bala.direction.y
	for i in range(5):
		bala._physics_process(0.016)
	assert_almost_eq(bala.direction.y, dy0, 0.001, "La bala debe volar en línea recta, sin parábola")

	_liberar_jugador_falso(player)


func test_arrojar_lanza_espada_no_bala() -> void:
	# Arrange: pirata + jugadora a la izquierda
	var pirata := await _crear_pirata()
	var player := _crear_jugador_falso()
	player.global_position = pirata.global_position + Vector3(-5.0, 0.0, 0.0)
	pirata.player_ref = player
	var antes: Dictionary = _contar_proyectiles()

	# Act: ataque arrojar (LANZAR01 = espada)
	pirata.current_throw_anim = "LANZAR01"
	pirata._throw_projectile()

	# Assert: aparece una espada y ninguna bala extra
	var despues: Dictionary = _contar_proyectiles()
	assert_eq(despues["espada"], antes["espada"] + 1, "Arrojar debe lanzar la espada")
	assert_eq(despues["bala"], antes["bala"], "Arrojar no debe disparar balas")

	_liberar_jugador_falso(player)


func _ultima_bala() -> BalaCanonProjectile:
	var ultima: BalaCanonProjectile = null
	for n in get_tree().root.find_children("*", "Area3D", true, false):
		if n is BalaCanonProjectile:
			ultima = n as BalaCanonProjectile
	return ultima


func test_pistola_fijada_a_mano_izquierda_y_oculta() -> void:
	# Arrange & Act
	var pirata := await _crear_pirata()
	var pistola := pirata._buscar_pistola()

	# Assert: existe, cuelga del hueso de la mano izquierda y nace oculta
	assert_not_null(pistola, "Debe existir la pistola colocada en el editor")
	var attach := pistola.get_parent()
	assert_true(attach is BoneAttachment3D, "La pistola debe seguir a la mano vía BoneAttachment3D")
	var skel := pirata.find_child("Skeleton3D", true, false) as Skeleton3D
	assert_not_null(skel, "Debe existir el esqueleto")
	var nombre_hueso: String = skel.get_bone_name((attach as BoneAttachment3D).bone_idx)
	assert_true("LeftHand" in nombre_hueso, "La pistola debe ir en la mano izquierda, no en: " + nombre_hueso)
	assert_false(pistola.visible, "La pistola nace oculta")


func test_pistola_solo_visible_en_disparo() -> void:
	# Arrange
	var pirata := await _crear_pirata()
	var pistola := pirata._buscar_pistola()
	assert_not_null(pistola, "Debe existir la pistola")
	pirata.throw_anim_duration = 5.0

	# Act & Assert: al iniciar el Disparo aún está en funda
	pirata._play_animation("LANZAR2")
	pirata.is_throwing = true
	pirata.current_throw_anim = "LANZAR2"
	pirata.throw_anim_timer = 0.0
	pirata._process(0.016)
	assert_false(pistola.visible, "Al iniciar el Disparo la pistola sigue en funda")

	# Act & Assert: desde su frame sale de la funda
	pirata.throw_anim_timer = 1.0
	pirata._process(0.016)
	assert_true(pistola.visible, "Desde el frame 0.9 la pistola debe verse")

	# Act & Assert: otras animaciones la ocultan
	pirata._play_animation("LANZAR01")
	assert_false(pistola.visible, "La pistola debe ocultarse al arrojar la espada")
	pirata._play_animation("IDLE")
	assert_false(pistola.visible, "La pistola debe ocultarse en IDLE")
	pirata._play_animation("IMP_MUERTE01")
	assert_false(pistola.visible, "La pistola debe ocultarse al morir")


func test_pistola_con_textura_propia() -> void:
	# Arrange & Act
	var pirata := await _crear_pirata()
	var pistola := pirata._buscar_pistola()
	assert_not_null(pistola, "Debe existir la pistola")

	# Assert: alguna malla con el material de la pistola
	var con_material := false
	for m in pistola.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).material_override == PirataGoblin.MAT_PISTOLA:
			con_material = true
			break
	assert_true(con_material, "La pistola debe usar MAT_PISTOLA_PIRATA")


func test_disparo_apunta_hacia_el_jugador() -> void:
	# Arrange: pirata en throw de Disparo, sin compensación, jugador ficticio a +Z
	var pirata := await _crear_pirata()
	var modelo := pirata.get_node_or_null("ImpModel") as Node3D
	assert_not_null(modelo, "Debe existir el nodo ImpModel")
	pirata.grados_extra_disparo = 0.0
	pirata.suavizado_aim_disparo = 1000.0
	var player_falso := Node3D.new()
	player_falso.name = "PlayerFalsoAim"
	player_falso.add_to_group("player")
	get_tree().root.add_child(player_falso)
	player_falso.global_position = pirata.global_position + Vector3(0.0, 0.0, 5.0)

	# Act: forzar fase de disparo LANZAR2 durante varios frames
	pirata.is_throwing = true
	pirata.current_throw_anim = "LANZAR2"
	await get_tree().process_frame
	await get_tree().process_frame

	# Assert: el yaw de mundo del modelo mira hacia +Z -> atan2(0, -5) = PI
	var yaw_mundo: float = wrapf(modelo.global_rotation.y, -PI, PI)
	assert_almost_eq(absf(yaw_mundo), PI, 0.05, "Durante Disparo el modelo debe apuntar al jugador")

	# Cleanup: el jugador falso no debe fugarse a otros tests
	player_falso.remove_from_group("player")
	player_falso.free()


func test_attachment_de_escena_es_usado_y_valido() -> void:
	# Arrange & Act
	var pirata := await _crear_pirata()
	var skel := pirata.find_child("Skeleton3D", true, false) as Skeleton3D
	assert_not_null(skel, "Debe existir el esqueleto")

	# Assert: el PistolaAttachment de la escena se usa y apunta a un hueso válido
	var attach := pirata._buscar_attachment_pistola(skel)
	assert_not_null(attach, "Debe existir PistolaAttachment en la escena")
	assert_true(attach.bone_idx >= 0 and attach.bone_idx < skel.get_bone_count(), "El attachment debe apuntar a un hueso válido")


func test_disparo_genera_vfx_reducido_en_punta() -> void:
	# Arrange: pirata + jugadora a la izquierda (fogonazo VFXHit_01 reducido)
	var pirata := await _crear_pirata()
	var player := _crear_jugador_falso()
	player.global_position = pirata.global_position + Vector3(-5.0, 0.0, 0.0)
	pirata.player_ref = player
	var pistola := pirata._buscar_pistola()
	assert_not_null(pistola, "Debe existir la pistola")
	assert_lte(pirata.escala_vfx_impacto, 2.0, "Fogonazo visible sin tapar al pirata")
	var antes: int = _contar_vfx_impacto()

	# Act: pistoletazo
	pirata.current_throw_anim = "LANZAR2"
	pirata._throw_projectile()

	# Assert: nace un impacto reducido junto a la punta
	assert_eq(_contar_vfx_impacto(), antes + 1, "El pistoletazo debe generar VFXHit_01")
	var vfx := _ultimo_vfx_impacto()
	assert_not_null(vfx, "Debe existir el impacto generado")
	assert_lte(vfx.scale.x, 2.0, "El efecto debe ser version contenida")
	for n in vfx.find_children("*", "GPUParticles3D", true, false):
		var gpu := n as GPUParticles3D
		assert_true(gpu.local_coords, "Coordenadas locales para que la escala aplique: " + (n as Node).name)
		var pm := gpu.process_material as ParticleProcessMaterial
		if pm:
			assert_lt(absf(pm.initial_velocity_max), 1.0, "Velocidades reducidas a version diminuta: " + (n as Node).name)
	var punta: Vector3 = pistola.to_global(pirata.punta_pistola_local)
	assert_lt(vfx.global_position.distance_to(punta), 0.5, "El efecto debe nacer en la punta de la pistola")

	# Cleanup
	if is_instance_valid(vfx):
		vfx.queue_free()
	_liberar_jugador_falso(player)


func test_humo_disparo_flipbook_y_autodestruccion() -> void:
	# Arrange & Act: humo Smoke VFX 2 (fondo transparente, sin cuadrados)
	var humo := HumoDisparoPirata.new()
	_root_test.add_child(humo)
	await get_tree().process_frame

	# Assert: 13 cuadros 64x64, sin loop, sin material que tape
	assert_not_null(humo.sprite_frames, "Debe construir sus SpriteFrames")
	assert_true(humo.sprite_frames.has_animation("humo"), "Debe tener animación humo")
	assert_eq(humo.sprite_frames.get_frame_count("humo"), 13, "Smoke VFX 2 trae 13 cuadros")
	assert_false(humo.sprite_frames.get_animation_loop("humo"), "Un solo disparo: sin loop")
	assert_null(humo.material_override, "Sin material: evita cuadrados blancos/negros")

	# Act & Assert: al terminar se libera solo (13 cuadros a 24fps ≈ 0.54s)
	await get_tree().create_timer(1.5).timeout
	assert_false(is_instance_valid(humo) and humo.is_inside_tree(), "El humo debe liberarse al terminar")


func test_disparo_genera_humo_en_punta_de_pistola() -> void:
	# Arrange: pirata + jugadora a la izquierda
	var pirata := await _crear_pirata()
	var player := _crear_jugador_falso()
	player.global_position = pirata.global_position + Vector3(-5.0, 0.0, 0.0)
	pirata.player_ref = player
	var pistola := pirata._buscar_pistola()
	assert_not_null(pistola, "Debe existir la pistola")
	var humos_antes: int = _contar_humos_disparo()

	# Act: pistoletazo
	pirata.current_throw_anim = "LANZAR2"
	pirata._throw_projectile()

	# Assert: nace un humo junto a la punta de la pistola
	assert_eq(_contar_humos_disparo(), humos_antes + 1, "El pistoletazo debe generar el humo")
	var humo := _ultimo_humo_disparo()
	assert_not_null(humo, "Debe existir el humo generado")
	var punta: Vector3 = pistola.to_global(pirata.punta_pistola_local)
	assert_lt(humo.global_position.distance_to(punta), 0.5, "El humo debe nacer en la punta de la pistola")

	_liberar_jugador_falso(player)


func _contar_humos_disparo() -> int:
	var total := 0
	for n in get_tree().root.find_children("*", "AnimatedSprite3D", true, false):
		if n is HumoDisparoPirata:
			total += 1
	return total


func _ultimo_humo_disparo() -> HumoDisparoPirata:
	var ultimo: HumoDisparoPirata = null
	for n in get_tree().root.find_children("*", "AnimatedSprite3D", true, false):
		if n is HumoDisparoPirata:
			ultimo = n as HumoDisparoPirata
	return ultimo


func _contar_vfx_impacto() -> int:
	var total := 0
	for n in get_tree().root.find_children("*", "Node3D", true, false):
		if n is VFXImpactBB:
			total += 1
	return total


func _ultimo_vfx_impacto() -> VFXImpactBB:
	var ultimo: VFXImpactBB = null
	for n in get_tree().root.find_children("*", "Node3D", true, false):
		if n is VFXImpactBB:
			ultimo = n as VFXImpactBB
	return ultimo


func test_forzar_pistola_visible_debug() -> void:
	# Arrange
	var pirata := await _crear_pirata()
	var pistola := pirata._buscar_pistola()
	assert_not_null(pistola, "Debe existir la pistola")

	# Act: forzar visibilidad fuera de timing
	pirata.forzar_pistola_visible = true
	pirata._play_animation("IDLE")
	pirata._process(0.016)

	# Assert: se muestra aunque no sea Disparo
	assert_true(pistola.visible, "Forzada debe verse incluso en IDLE")
	pirata.forzar_pistola_visible = false


func test_pistola_escala_visible_en_mano() -> void:
	# Arrange: la pistola nativa mide ~1.0m pero cuelga de un esqueleto con
	# Armature a escala 0.01 bajo un CharacterBody a 0.8 (factor 0.008).
	# Una escala local 0.01 la dejaba en 0.08mm (invisible en camara).
	var pirata := await _crear_pirata()
	await get_tree().process_frame
	var pistola := pirata._buscar_pistola()
	assert_not_null(pistola, "Debe existir la pistola")

	# Act: tamano mundial = AABB local de la malla * escala global acumulada
	var escala_global: Vector3 = pistola.global_transform.basis.get_scale()
	var largo_mundo_max: float = 0.0
	for m in pistola.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var mundo: Vector3 = mi.mesh.get_aabb().size * escala_global
		largo_mundo_max = maxf(largo_mundo_max, mundo.x)
		largo_mundo_max = maxf(largo_mundo_max, mundo.y)
		largo_mundo_max = maxf(largo_mundo_max, mundo.z)

	# Assert: legible en camara (15cm-60cm) sin superar al goblin (~56cm)
	assert_gt(largo_mundo_max, 0.15, "La pistola debe medir mas de 15cm en el mundo")
	assert_lt(largo_mundo_max, 0.60, "La pistola no debe superar el tamano del goblin")


func _limpiar_estelas() -> void:
	for n in get_tree().get_nodes_in_group("estela_espada"):
		if is_instance_valid(n):
			n.free()


func test_espada_deja_estela_morada_sutil() -> void:
	# Arrange: espada en vuelo
	_limpiar_estelas()
	var pirata := await _crear_pirata()
	var espada := (pirata.imp_arrow_scene as PackedScene).instantiate() as EspadaPirataProjectile
	_root_test.add_child(espada)
	espada.global_position = Vector3(0.0, 5.0, 0.0)
	espada.initialize(Vector3(1.0, 0.3, 0.0).normalized(), 1.0)

	# Act: 6 frames en vuelo
	for i in range(6):
		espada._physics_process(0.016)

	# Assert: fantasmas con la forma (malla) en morado transparente y sutil
	var fantasmas := get_tree().get_nodes_in_group("estela_espada")
	assert_gt(fantasmas.size(), 0, "Volando debe dejar estela")
	var mat := (fantasmas[0] as MeshInstance3D).material_override as StandardMaterial3D
	assert_not_null(mat, "El fantasma debe tener material propio")
	assert_almost_eq(mat.albedo_color.r, 0.6, 0.05, "Tono morado R")
	assert_almost_eq(mat.albedo_color.g, 0.2, 0.05, "Tono morado G")
	assert_almost_eq(mat.albedo_color.b, 1.0, 0.05, "Tono morado B")
	assert_lte(mat.albedo_color.a, 0.35, "Transparente y sutil")

	# Cleanup
	_limpiar_estelas()
	espada.free()


func test_estela_se_detiene_al_clavar() -> void:
	# Arrange: espada en vuelo con estela activa
	_limpiar_estelas()
	var pirata := await _crear_pirata()
	var espada := (pirata.imp_arrow_scene as PackedScene).instantiate() as EspadaPirataProjectile
	_root_test.add_child(espada)
	espada.global_position = Vector3(0.0, 5.0, 0.0)
	espada.initialize(Vector3(1.0, 0.0, 0.0).normalized(), 1.0)
	for i in range(6):
		espada._physics_process(0.016)
	var antes: int = get_tree().get_nodes_in_group("estela_espada").size()
	assert_gt(antes, 0, "Debe haber estela en vuelo")

	# Act: se clava y sigue pasando el tiempo sin moverse
	espada.is_stuck = true
	for i in range(6):
		espada._physics_process(0.016)

	# Assert: no nacen más fantasmas (los viejos siguen su fade sin tiempo real)
	assert_eq(get_tree().get_nodes_in_group("estela_espada").size(), antes, "Clavada no debe generar más estela")

	# Cleanup
	_limpiar_estelas()
	espada.free()


func test_espada_cae_mas_lento_con_factor_gravedad() -> void:
	# Arrange: dos espadas iguales, una con gravedad completa y otra reducida
	var pirata := await _crear_pirata()
	var rapida := (pirata.imp_arrow_scene as PackedScene).instantiate() as EspadaPirataProjectile
	var lenta := (pirata.imp_arrow_scene as PackedScene).instantiate() as EspadaPirataProjectile
	_root_test.add_child(rapida)
	_root_test.add_child(lenta)
	rapida.factor_gravedad = 1.0
	assert_almost_eq(lenta.factor_gravedad, 0.6, 0.001, "La espada debe caer con gravedad reducida por defecto")
	rapida.global_position = Vector3(0.0, 5.0, 0.0)
	lenta.global_position = Vector3(0.0, 5.0, 0.0)
	rapida.initialize(Vector3(1.0, -0.2, 0.0).normalized(), 1.0)
	lenta.initialize(Vector3(1.0, -0.2, 0.0).normalized(), 1.0)

	# Act: 40 frames de caída
	for i in range(40):
		rapida._physics_process(0.016)
		lenta._physics_process(0.016)

	# Assert: la de gravedad reducida permanece más tiempo en el aire (más alta)
	assert_gt(lenta.global_position.y, rapida.global_position.y, "Con factor 0.6 debe caer más lento")

	# Cleanup
	rapida.free()
	lenta.free()


func test_pirata_cadencia_mas_baja_que_imp() -> void:
	# Arrange & Act
	var pirata := await _crear_pirata()

	# Assert: pausas mínimas garantizadas (respeta ajustes mayores del editor)
	assert_gte(pirata.pausa_idle_min, 2.0, "Pausa mínima al menos 2.0s")
	assert_gte(pirata.pausa_idle_max, 3.5, "Pausa máxima al menos 3.5s")


func test_pirata_en_submarino_siempre_usa_animacion_correr() -> void:
	# Arrange: pirata con va_a_correr = false explícito
	var pirata := await _crear_pirata()
	pirata.va_a_correr = false
	pirata.esta_en_submarino = true

	# Act: intentar reproducir CAMINAR o ejecutar _on_state_walking
	pirata._on_state_walking()

	# Assert: debe haber ejecutado Correr (alias CORRER)
	assert_eq(pirata.anim_player.current_animation, "CORRER", "En submarino debe usar CORRER en vez de Strut Walking")

	# Act 2: llamar directamente _play_animation("CAMINAR")
	pirata._play_animation("CAMINAR")

	# Assert 2: se redirige a CORRER
	assert_eq(pirata.anim_player.current_animation, "CORRER", "Llamar CAMINAR debe redirigirse a CORRER")


func test_pirata_en_arbol_submarino_detecta_submarino_y_corre() -> void:
	# Arrange: pirata dentro de un nodo SubmarinoRio
	var pirata := await _crear_pirata()
	pirata.va_a_correr = false
	pirata.esta_en_submarino = false
	var submarino_dummy := Node3D.new()
	submarino_dummy.name = "SubmarinoRio"
	_root_test.add_child(submarino_dummy)
	pirata.reparent(submarino_dummy)

	# Act: verificar detección y caminar
	assert_true(pirata.es_en_submarino(), "Debe detectar que su ancestro es un submarino")
	pirata._on_state_walking()

	# Assert: corre automáticamente
	assert_eq(pirata.anim_player.current_animation, "CORRER", "Por ser hijo de submarino debe correr")
	submarino_dummy.free()


func test_pirata_al_morir_no_se_vuelve_blanco() -> void:
	# Arrange: pirata configurado sobre el submarino
	var pirata := await _crear_pirata()
	pirata.esta_en_submarino = true
	var malla_cuerpo: MeshInstance3D = pirata.find_child("Piratiña", true, false) as MeshInstance3D
	assert_not_null(malla_cuerpo, "Debe existir la malla del cuerpo Piratiña")
	assert_eq(malla_cuerpo.material_override, PirataGoblin.MAT_PIRATA, "Malla debe nacer con MAT_PIRATA")

	# Act: recibir daño letal
	pirata.take_damage(1.0)

	# Assert (Durante animación de muerte): entra en estado DYING con animación correspondiente
	assert_eq(pirata.current_state, EnemyBase.State.DYING, "Estado debe ser DYING")
	var anim_actual: String = pirata.anim_player.current_animation
	assert_true(
		anim_actual in ["IMP_MUERTE01", "IMP_MUERTE02", "Muerte 1", "Muerte 2"],
		"Debe estar reproduciendo animación de muerte, no: " + anim_actual
	)
	assert_eq(malla_cuerpo.material_override, PirataGoblin.MAT_PIRATA, "Durante la animación de muerte debe conservar MAT_PIRATA")

	# Act: esperar a que la animación de muerte termine e inicie la disolución
	await get_tree().create_timer(3.0).timeout

	# Assert (Durante disolución): la malla debe tener ShaderMaterial con la textura del pirata asignada (no null/blanco)
	assert_true(malla_cuerpo.material_override is ShaderMaterial, "Al disolverse debe usar ShaderMaterial de disolución")
	var sm := malla_cuerpo.material_override as ShaderMaterial
	var tex_disolucion = sm.get_shader_parameter("albedo_texture")
	assert_not_null(tex_disolucion, "La textura del ShaderMaterial NO debe ser null (evita que se vuelva blanco)")
	assert_true(tex_disolucion is Texture2D, "El parámetro albedo_texture debe ser una Texture2D válida")
	assert_true("PirataGoblin_D" in (tex_disolucion as Texture2D).resource_path, "Debe conservar la textura PirataGoblin_D al disolverse")
	assert_eq(sm.get_shader_parameter("glow_color"), pirata.color_borde_disolucion, "El borde de disolución debe usar el color configurado del pirata")


