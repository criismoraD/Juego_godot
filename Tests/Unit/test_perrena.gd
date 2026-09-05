extends GutTest

class MockEnemy extends StaticBody3D:
	var hp: float = 10.0
	var hit_count: int = 0
	
	func _init():
		add_to_group("enemies")
		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(1, 1, 1)
		col.shape = shape
		add_child(col)
		
	func take_damage(amount: float) -> void:
		hp -= amount
		hit_count += 1


func test_perrena_scale_matches_player():
	var p_scene = load("res://Entities/Jugador_Arquera/Player.tscn")
	var per_scene = load("res://Entities/Jugador_Perrena/Perrena.tscn")
	
	var p = p_scene.instantiate()
	var per = per_scene.instantiate()
	
	add_child_autofree(p)
	add_child_autofree(per)
	
	p.scale = Vector3(0.3, 0.3, 0.3)
	per.scale = Vector3(0.3, 0.3, 0.3)
	
	p._process(0.1)
	p._physics_process(0.1)
	per._process(0.1)
	per._physics_process(0.1)
	
	var p_skel: Skeleton3D = p.find_child("Skeleton3D", true, false)
	var per_skel: Skeleton3D = per.find_child("Skeleton3D", true, false)
	
	var p_head = p_skel.global_transform * p_skel.get_bone_global_pose(p_skel.find_bone("mixamorig_Head")).origin
	var per_head = per_skel.global_transform * per_skel.get_bone_global_pose(per_skel.find_bone("mixamorig_Head")).origin
	
	assert_almost_eq(per_head.y, p_head.y, 0.06, "Perrena head height should match Player head height")


func test_perrena_facing_2d_plane():
	var per_scene = load("res://Entities/Jugador_Perrena/Perrena.tscn")
	var per = per_scene.instantiate()
	add_child_autofree(per)
	
	# Facing Right
	per._mirando_derecha = true
	per._apply_character_rotation(0.1, true)
	var per_skel: Skeleton3D = per.find_child("Skeleton3D", true, false)
	var h_idx = per_skel.find_bone("mixamorig_Head")
	var pose_r = per_skel.get_bone_global_pose(h_idx)
	var face_r = (per_skel.global_transform.basis * pose_r.basis).z.normalized()
	assert_gt(face_r.x, 0.8, "When looking right, Perrena should face +X")
	
	# Facing Left
	per._mirando_derecha = false
	per._apply_character_rotation(0.1, true)
	var pose_l = per_skel.get_bone_global_pose(h_idx)
	var face_l = (per_skel.global_transform.basis * pose_l.basis).z.normalized()
	assert_lt(face_l.x, -0.8, "When looking left, Perrena should face -X")


func test_player_trident_damages_enemy():
	var enemy = MockEnemy.new()
	add_child_autofree(enemy)
	
	var trident_scene = load("res://Entities/Proyectil_Tridente_Imp/ImpTrident.tscn")
	var trident = trident_scene.instantiate() as ImpTridentProjectile
	add_child_autofree(trident)
	
	trident.disparado_por_jugador = true
	trident.initialize(Vector3.RIGHT, 1.0)
	
	trident._on_body_entered(enemy)
	
	assert_eq(enemy.hit_count, 1, "Enemy should receive damage from player trident")
	assert_eq(enemy.hp, 8.0, "Enemy hp should decrease by 2")


func test_player_trident_ignores_player_and_allies():
	var ally = Node3D.new()
	ally.add_to_group("allies")
	add_child_autofree(ally)
	
	var player = Node3D.new()
	player.add_to_group("player")
	add_child_autofree(player)
	
	var trident_scene = load("res://Entities/Proyectil_Tridente_Imp/ImpTrident.tscn")
	var trident = trident_scene.instantiate() as ImpTridentProjectile
	add_child_autofree(trident)
	
	trident.disparado_por_jugador = true
	trident.initialize(Vector3.RIGHT, 1.0)
	
	trident._on_body_entered(ally)
	assert_false(trident.is_stuck)
	
	trident._on_body_entered(player)
	assert_false(trident.is_stuck)
