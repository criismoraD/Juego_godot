extends GutTest


func test_perrena_paridad_escala_vida_y_agachado_con_eryn():
	# Arrange: Perrena debe ser identica a la protagonista Eryn (segundo player)
	var eryn_scene = load("res://Entities/Jugador_Arquera/Player.tscn")
	var per_scene = load("res://Entities/Jugador_Perrena/Perrena.tscn")

	var eryn: Node3D = eryn_scene.instantiate() as Node3D
	var per: Node3D = per_scene.instantiate() as Node3D

	add_child_autofree(eryn)
	add_child_autofree(per)

	# Eryn solo como referencia estatica (sin fisica propia en el test)
	eryn.set_physics_process(false)
	eryn.set_process(false)

	# Act
	per._process(0.1)
	per._physics_process(0.1)

	# Assert: misma vida
	assert_eq(per.get("vida_maxima"), eryn.get("vida_maxima"), "Perrena debe tener la misma vida maxima que Eryn")
	assert_eq(per.get("vida_maxima"), 4, "Ambas tienen 4 de vida")

	# Assert: mismo tamano de modelo y capsula (el arco queda del mismo tamano)
	var eryn_model: Node3D = eryn.find_child("ArqueraModel", true, false)
	var per_model: Node3D = per.find_child("PerrenaModel", true, false)
	assert_not_null(eryn_model, "Eryn debe tener ArqueraModel")
	assert_not_null(per_model, "Perrena debe tener PerrenaModel")
	assert_almost_eq(per_model.scale.x, eryn_model.scale.x, 0.01, "Perrena debe tener la misma escala de modelo que Eryn")

	# Assert: la via visual del agachado (ATERRIZAJE congelado) existe mapeada
	var anim_p: AnimationPlayer = per.find_child("AnimationPlayer", true, false)
	assert_not_null(anim_p, "Perrena debe tener AnimationPlayer")
	assert_true(anim_p.has_animation("Armature|Armature|ATERRIZAJE"), "Debe tener mapeada la animacion de agachado/aterrizaje")


func test_perrena_facing_2d_plane():
	# Arrange
	var per_scene = load("res://Entities/Jugador_Perrena/Perrena.tscn")
	var per = per_scene.instantiate()
	add_child_autofree(per)

	# Act & Assert: Facing Right
	per._mirando_derecha = true
	per._apply_character_rotation(0.1, true)
	var per_skel: Skeleton3D = per.find_child("Skeleton3D", true, false)
	var h_idx = per_skel.find_bone("mixamorig_Head")
	var pose_r = per_skel.get_bone_global_pose(h_idx)
	var face_r = (per_skel.global_transform.basis * pose_r.basis).z.normalized()
	assert_gt(face_r.x, 0.8, "When looking right, Perrena should face +X")

	# Act & Assert: Facing Left
	per._mirando_derecha = false
	per._apply_character_rotation(0.1, true)
	var pose_l = per_skel.get_bone_global_pose(h_idx)
	var face_l = (per_skel.global_transform.basis * pose_l.basis).z.normalized()
	assert_lt(face_l.x, -0.8, "When looking left, Perrena should face -X")


func test_perrena_bow_and_arrow_equipped():
	# Arrange
	var per_scene = load("res://Entities/Jugador_Perrena/Perrena.tscn")
	var per = per_scene.instantiate()
	add_child_autofree(per)

	# Act
	per._ready()

	# Assert
	var arco = per.find_child("ARCO_ANIMADO", true, false)
	assert_not_null(arco, "Perrena debe tener ARCO_ANIMADO instanciado en mano izquierda")

	var flecha = per.find_child("FLECHA", true, false)
	assert_not_null(flecha, "Perrena debe tener FLECHA instanciada en mano derecha")

	var spawn_exp = per.find_child("SpawnPosition_FlechaExplosiva", true, false)
	assert_not_null(spawn_exp, "Perrena debe tener Marker3D SpawnPosition_FlechaExplosiva")


func test_perrena_disparo_anim_mapping():
	# Arrange
	var per_scene = load("res://Entities/Jugador_Perrena/Perrena.tscn")
	var per = per_scene.instantiate()
	add_child_autofree(per)

	# Act
	per._ready()
	var anim_p: AnimationPlayer = per.find_child("AnimationPlayer", true, false)
	assert_not_null(anim_p, "Perrena debe tener AnimationPlayer")

	# Assert: El clip 'Armature|Armature|DISPARAR' debe existir y coincidir con 'Disparo arco'
	assert_true(anim_p.has_animation("Armature|Armature|DISPARAR"), "Debe tener mapeada la animacion DISPARAR")


func test_plataforma_oneway_tracks_perrena():
	# Arrange
	var plataforma_scene = load("res://Entities/Ambiente_Plataforma_Oneway/PlataformaOneway.tscn")
	var per_scene = load("res://Entities/Jugador_Perrena/Perrena.tscn")

	var plat = plataforma_scene.instantiate() as PlataformaOneway
	var per = per_scene.instantiate() as CharacterBody3D

	add_child_autofree(plat)
	add_child_autofree(per)

	# Act: Simular cambio de personaje a Perrena
	per.add_to_group("player")
	plat._physics_process(0.016)

	# Assert: PlataformaOneway debe actualizar player_ref a Perrena dinamicamente
	assert_eq(plat.player_ref, per, "PlataformaOneway debe referenciar a Perrena como jugador activo")


func test_swap_aparcado_sin_input_ni_grupo():	# Arrange: dos personajes y GameUI sin entrar al arbol
	var GameUIScript = load("res://UI/GameUI.gd")
	var ui = GameUIScript.new()
	var eryn := Node3D.new()
	var perrena := Node3D.new()
	add_child_autofree(eryn)
	add_child_autofree(perrena)
	eryn.add_to_group("player")
	ui._desactivar_personaje(eryn)
	ui._activar_personaje(perrena)
	assert_false(eryn.is_in_group("player"), "La aparcada sale del grupo player")
	assert_false(eryn.is_processing_unhandled_input(), "La aparcada no recibe input (no duplica acciones)")
	assert_true(perrena.is_in_group("player"), "La activa entra al grupo player")
	assert_true(perrena.is_processing_unhandled_input(), "La activa recibe input")
	assert_true(perrena.visible, "La activa queda visible")
	ui.free()


func test_perrena_paridad_colision_con_eryn():
	# Arrange: ambas instanciadas reales (con _ready ejecutado)
	var eryn_scene = load("res://Entities/Jugador_Arquera/Player.tscn")
	var per_scene = load("res://Entities/Jugador_Perrena/Perrena.tscn")
	var eryn := eryn_scene.instantiate() as CharacterBody3D
	var per := per_scene.instantiate() as CharacterBody3D
	add_child_autofree(eryn)
	add_child_autofree(per)
	await get_tree().process_frame

	# Assert: idéntica capa y máscara; la capa 2 (defensoras) excluida en ambas
	assert_eq(per.collision_layer, eryn.collision_layer, "Perrena debe tener la misma capa de colisión que Eryn")
	assert_eq(per.collision_mask, eryn.collision_mask, "Perrena debe tener la misma máscara de colisión que Eryn")
	assert_eq(per.collision_mask & 2, 0, "Perrena no debe colisionar con la capa 2 de defensoras")
	assert_ne(per.collision_mask & 1, 0, "Perrena debe seguir colisionando con el mundo (capa 1)")


func test_perrena_atraviesa_defensoras_y_escudos_aliados():
	# Arrange: Perrena + ballestera + escudo aliado reales
	var per_scene = load("res://Entities/Jugador_Perrena/Perrena.tscn")
	var bal_scene = load("res://Entities/Aliada_Ballestera/AllyBallestera.tscn")
	var esc_scene = load("res://Entities/Ambiente_Escudo/Escudo.tscn")
	var per := per_scene.instantiate() as CharacterBody3D
	var bal := bal_scene.instantiate() as Node3D
	var esc := esc_scene.instantiate() as StaticBody3D
	add_child_autofree(per)
	add_child_autofree(bal)
	add_child_autofree(esc)
	await get_tree().process_frame

	# Assert: ni la hitbox de la defensora ni el escudo aliado frenan a Perrena
	var capa_hitbox: int = bal.hitbox_body.collision_layer
	assert_eq(capa_hitbox, 2, "La hitbox de la defensora vive en la capa 2")
	assert_eq(per.collision_mask & (1 << (capa_hitbox - 1)), 0, "La defensora no debe frenar a Perrena")
	assert_eq(esc.collision_layer, 2, "El escudo aliado queda en capa 2")
	assert_eq(per.collision_mask & (1 << (esc.collision_layer - 1)), 0, "El escudo aliado no debe frenar a Perrena")


func test_aparcado_desactiva_colision_y_reactivar_restaura():
	# Arrange: Perrena real en el árbol
	var per_scene = load("res://Entities/Jugador_Perrena/Perrena.tscn")
	var per := per_scene.instantiate() as CharacterBody3D
	add_child_autofree(per)
	await get_tree().process_frame
	var forma := per.find_child("CollisionShape3D", true, false) as CollisionShape3D
	assert_not_null(forma, "Perrena debe tener CollisionShape3D")

	# Act: aparcar (como GameUI al cambiar de personaje)
	Player.configurar_colision_aparcado(per, true)
	await get_tree().process_frame

	# Assert: sin colisión (no es un muro invisible)
	assert_eq(per.collision_layer, 0, "Aparcada: capa 0 para no bloquear")
	assert_true(forma.disabled, "Aparcada: CollisionShape desactivado")

	# Act: reactivar
	Player.configurar_colision_aparcado(per, false)
	await get_tree().process_frame

	# Assert: colisión de jugadora restaurada
	assert_eq(per.collision_layer, 1, "Reactivada: vuelve a la capa 1 de jugador")
	assert_false(forma.disabled, "Reactivada: CollisionShape habilitado")


func test_perrena_arco_en_escena_sigue_manos():
	# Arrange: escena real (los attachments ya vienen en el .tscn, editables a mano)
	var per_scene = load("res://Entities/Jugador_Perrena/Perrena.tscn")
	var per = per_scene.instantiate()
	add_child_autofree(per)
	await get_tree().process_frame

	# Assert: attachments bajo el esqueleto, sin duplicados del código de runtime
	var skel: Skeleton3D = per.find_child("Skeleton3D", true, false)
	assert_not_null(skel, "Perrena debe tener Skeleton3D")
	var arcos = skel.find_children("BoneAttach_Arco", false, false)
	assert_eq(arcos.size(), 1, "Debe haber un solo BoneAttach_Arco (sin duplicados)")
	var att := skel.get_node_or_null("BoneAttach_Arco") as BoneAttachment3D
	assert_not_null(att, "BoneAttach_Arco debe existir bajo el Skeleton3D")
	assert_eq(att.bone_idx, skel.find_bone("mixamorig_LeftHand"), "El arco debe seguir la mano izquierda")
	assert_not_null(att.get_node_or_null("ARCO_ANIMADO"), "ARCO_ANIMADO debe existir para ubicarlo a mano en el editor")
	var att_f := skel.get_node_or_null("BoneAttach_Flecha") as BoneAttachment3D
	assert_not_null(att_f, "BoneAttach_Flecha debe existir bajo el Skeleton3D")
	assert_eq(att_f.bone_idx, skel.find_bone("mixamorig_RightHand"), "La flecha debe seguir la mano derecha")


func test_perrena_resuelve_todas_las_anims_del_arbol():
	# Arrange: los nombres que el AnimationTree dinámico del Player pide
	var requeridas := [
		"Armature|Armature|IDLE",
		"Armature|Armature|CAMINAR_ADELANTE",
		"Armature|Armature|CAMINAR_ATRAS",
		"Armature|Armature|CORRER_ADELANTE",
		"Armature|Armature|APUNTAR_IDLE",
		"Armature|Armature|DISPARAR",
		"Armature|Armature|TOMAR_FLECHA",
		"Armature|Armature|CAER_SALTAR",
		"Armature|Armature|ATERRIZAJE",
		"Armature|Armature|SUBIR_ESCALERA",
		"Armature|Armature|MUERTE",
		"Armature|Armature|HIT",
	]
	var per_scene = load("res://Entities/Jugador_Perrena/Perrena.tscn")
	var per = per_scene.instantiate()
	add_child_autofree(per)
	await get_tree().process_frame

	# Assert: cada nombre resuelve (nativo o alias en su librería); si falta, queda estática
	var anim_p: AnimationPlayer = per.find_child("AnimationPlayer", true, false)
	assert_not_null(anim_p, "Perrena debe tener AnimationPlayer")
	for nombre in requeridas:
		assert_true(anim_p.has_animation(nombre), "Debe resolver '%s' (sin esto el árbol no anima)" % nombre)
