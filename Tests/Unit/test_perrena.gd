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

	# Paridad de TAMANO VISUAL con Eryn (no del numero de escala): el GLB de Perrena viene ~2x mas pequeno y necesita 6.0 (Eryn usa 3.1). Medido en headless, altura mundo ~= 1.09x. Bajarla a 3.1 la deja diminuta: no tocar.
	var eryn_model: Node3D = eryn.find_child("ArqueraModel", true, false)
	var per_model: Node3D = per.find_child("PerrenaModel", true, false)
	assert_not_null(eryn_model, "Eryn debe tener ArqueraModel")
	assert_not_null(per_model, "Perrena debe tener PerrenaModel")
	assert_almost_eq(per_model.scale.x, 6.0, 0.01, "PerrenaModel debe mantener escala 6.0 (tamano visual correcto, verificado en juego)")

	# Assert: la via visual del agachado (ATERRIZAJE congelado) existe mapeada
	var anim_p: AnimationPlayer = Perrena._player_corporal_en(per)
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
	# Regresion: FLECHA debe ser la flecha (FLECHA.fbx: una malla), no un
	# personaje (PROTA.glb trae Skeleton3D y AnimationPlayer propios).
	assert_null(flecha.find_child("Skeleton3D", true, false), "FLECHA no debe contener un esqueleto de personaje")
	assert_null(flecha.find_child("AnimationPlayer", true, false), "FLECHA no debe contener animaciones de personaje")
	assert_not_null(flecha.find_child("Arrow 32 inch", true, false), "FLECHA debe contener la malla de la flecha")

	var spawn_exp = per.find_child("SpawnPosition_FlechaExplosiva", true, false)
	assert_not_null(spawn_exp, "Perrena debe tener Marker3D SpawnPosition_FlechaExplosiva")


func test_perrena_disparo_anim_mapping():
	# Arrange
	var per_scene = load("res://Entities/Jugador_Perrena/Perrena.tscn")
	var per = per_scene.instantiate()
	add_child_autofree(per)

	# Act
	per._ready()
	var anim_p: AnimationPlayer = Perrena._player_corporal_en(per)
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
	var arcos = skel.find_children("BoneAttach_Arco", "", false, false)
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
	var anim_p: AnimationPlayer = Perrena._player_corporal_en(per)
	assert_not_null(anim_p, "Perrena debe tener AnimationPlayer")
	for nombre in requeridas:
		assert_true(anim_p.has_animation(nombre), "Debe resolver '%s' (sin esto el árbol no anima)" % nombre)


func test_perrena_arbol_usa_base_del_animation_player():
	# Arrange: el árbol resuelve tracks desde su root_node; si no coincide con
	# la base del player, no mueve ningún hueso y Perrena se desplaza estática
	var per_scene = load("res://Entities/Jugador_Perrena/Perrena.tscn")
	var per = per_scene.instantiate()
	add_child_autofree(per)
	await get_tree().process_frame

	# Assert
	var tree: AnimationTree = per.find_child("AnimationTree", true, false)
	var anim_p: AnimationPlayer = Perrena._player_corporal_en(per)
	assert_not_null(tree, "Perrena debe tener AnimationTree")
	assert_not_null(anim_p, "Perrena debe tener AnimationPlayer")
	var base_jugador: Node = anim_p.get_node_or_null(anim_p.root_node)
	assert_not_null(base_jugador, "La base del player debe resolverse")
	# root_node del AnimationTree es relativo al propio tree (igual que
	# anim_player), no al CharacterBody: resolver desde tree.
	var base_arbol: Node = tree.get_node_or_null(tree.root_node)
	assert_eq(base_arbol, base_jugador, "El árbol debe usar la base del player (si no, Perrena se mueve estática)")


func test_perrena_arbol_usa_player_corporal_no_arco():
	# Regresión: bajo Perrena hay 3 AnimationPlayers (arco, flecha y corporal).
	# find_child() a ciegas devolvía el del arco y el árbol no resolvía ninguna
	# animación corporal: Perrena quedaba estática en el juego.
	var per_scene = load("res://Entities/Jugador_Perrena/Perrena.tscn")
	var per = per_scene.instantiate()
	add_child_autofree(per)
	await get_tree().process_frame

	var tree: AnimationTree = per.find_child("AnimationTree", true, false)
	assert_not_null(tree, "Perrena debe tener AnimationTree")
	var tree_player: AnimationPlayer = tree.get_node_or_null(tree.anim_player) as AnimationPlayer
	assert_not_null(tree_player, "El anim_player del árbol debe resolverse")
	assert_eq(tree_player, Perrena._player_corporal_en(per), "El árbol debe usar el player corporal")
	assert_false("BoneAttach" in String(tree_player.get_path()), "El player del árbol no debe ser el del arco/flecha")
	assert_true(tree_player.has_animation("Idle"), "El player del árbol debe tener los clips corporales")
	assert_true(tree_player.has_animation("Armature|Armature|SUBIR_ESCALERA"), "Debe resolver SUBIR_ESCALERA (escalera)")


func test_perrena_escaleras_muestra_espaldas_como_eryn():
	# La Escaleras nativa del GLB mira de perfil (+X); el alias hornea un
	# giro +90 Y de mundo para trepar de espaldas (-Z) como la protagonista.
	var per_scene = load("res://Entities/Jugador_Perrena/Perrena.tscn")
	var per = per_scene.instantiate()
	add_child_autofree(per)
	await get_tree().process_frame

	var tree: AnimationTree = per.find_child("AnimationTree", true, false)
	var anim_p: AnimationPlayer = Perrena._player_corporal_en(per)
	assert_not_null(tree, "Perrena debe tener AnimationTree")
	assert_not_null(anim_p, "Perrena debe tener AnimationPlayer")
	# Condiciones reales de trepe: el yaw del Armature en escalera forma parte
	# de la orientacion final (sin esto mediria con yaw de suelo y saldria girado 180).
	per.current_move_state = Perrena.MoveState.CLIMBING
	per.current_aim_state = Perrena.AimState.NONE
	per._mirando_derecha = true
	per._apply_character_rotation(0.1, true)
	var estaba: bool = tree.active
	tree.active = false
	anim_p.play("Armature|Armature|SUBIR_ESCALERA")
	anim_p.seek(0.3, true)
	var skel: Skeleton3D = per.find_child("Skeleton3D", true, false)
	var idx: int = skel.find_bone("mixamorig_Head")
	assert_ne(idx, -1, "Debe existir el hueso de la cabeza")
	var frente: Vector3 = (skel.global_transform.basis * skel.get_bone_global_pose(idx).basis).z.normalized()
	tree.active = estaba
	assert_lt(frente.z, -0.6, "Trepar debe mostrar la espalda (-Z como Eryn), fue %s" % frente)
	assert_lt(absf(frente.x), 0.5, "No debe trepar de perfil, fue %s" % frente)


func test_perrena_outline_igual_que_eryn() -> void:
	# La línea negra sale del next_pass TOON_LINEANEGRA: Perrena la traía a
	# 5.0 frente a 20.0 de Eryn y se veía sin contorno.
	var mat_per := load("res://Entities/Jugador_Perrena/PERRENA_MAT.tres") as StandardMaterial3D
	var mat_eryn := load("res://Entities/Jugador_Arquera/ARQUERA_MATERIAL.tres") as StandardMaterial3D
	assert_not_null(mat_per, "Debe existir el material de Perrena")
	assert_not_null(mat_eryn, "Debe existir el material de Eryn")
	var out_per := mat_per.next_pass as ShaderMaterial
	var out_eryn := mat_eryn.next_pass as ShaderMaterial
	assert_not_null(out_per, "Perrena debe tener passe de contorno")
	assert_not_null(out_eryn, "Eryn debe tener passe de contorno")
	assert_eq(out_per.get_shader_parameter("outline_width"), out_eryn.get_shader_parameter("outline_width"), "Mismo grosor de contorno que Eryn")
