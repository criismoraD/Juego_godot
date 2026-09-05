extends GutTest


func test_perrena_scale_matches_defensora():
	# Arrange
	var ally_scene = load("res://Entities/Aliada_Arquera/AllyArcher.tscn")
	var per_scene = load("res://Entities/Jugador_Perrena/Perrena.tscn")

	var ally: Node3D = ally_scene.instantiate() as Node3D
	var per: Node3D = per_scene.instantiate() as Node3D

	add_child_autofree(ally)
	add_child_autofree(per)

	ally.scale = Vector3(0.3, 0.3, 0.3)
	per.scale = Vector3(0.3, 0.3, 0.3)

	# Act
	per._process(0.1)
	per._physics_process(0.1)

	var ally_skel: Skeleton3D = ally.find_child("Skeleton3D", true, false)
	var per_skel: Skeleton3D = per.find_child("Skeleton3D", true, false)

	assert_not_null(ally_skel, "AllyArcher debe tener Skeleton3D")
	assert_not_null(per_skel, "Perrena debe tener Skeleton3D")

	var ally_head = ally_skel.global_transform * ally_skel.get_bone_global_pose(ally_skel.find_bone("mixamorig_Head")).origin
	var per_head = per_skel.global_transform * per_skel.get_bone_global_pose(per_skel.find_bone("mixamorig_Head")).origin

	# Assert: la altura de cabeza de Perrena debe ser proporcional y cercana a la defensora (dentro de 0.15m)
	assert_almost_eq(per_head.y, ally_head.y, 0.15, "Perrena head height debe coincidir con la defensora aliada")


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
	assert_true(anim_p.has_animation("Armature|Armature|DISPARAR"), "Debe tener mapeada la animación DISPARAR")


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

	# Assert: PlataformaOneway debe actualizar player_ref a Perrena dinámicamente
	assert_eq(plat.player_ref, per, "PlataformaOneway debe referenciar a Perrena como jugador activo")
