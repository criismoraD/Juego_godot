extends GutTest

func test_ally_archer_climb():
	var scene = load("res://Entities/Aliada_Arquera/AllyArcher.tscn")
	var archer = scene.instantiate()
	add_child(archer)
	
	print("\n================== ALLY ARCHER CLIMB FACING ==================")
	var ap: AnimationPlayer = archer.anim_player
	ap.play("SUBIR_ESCALERAS")
	ap.seek(0.1, true)
	
	var skel: Skeleton3D = archer.find_child("Skeleton3D", true, false)
	var head = skel.global_transform * skel.get_bone_global_pose(skel.find_bone("mixamorig_Head"))
	var spine = skel.global_transform * skel.get_bone_global_pose(skel.find_bone("mixamorig_Spine"))
	var hips = skel.global_transform * skel.get_bone_global_pose(skel.find_bone("mixamorig_Hips"))
	
	print("AllyArcher SUBIR_ESCALERAS:")
	print("  Hips Front (Z):  %s" % hips.basis.z)
	print("  Spine Front (Z): %s" % spine.basis.z)
	print("  Head Front (Z):  %s" % head.basis.z)
	
	archer.queue_free()
	assert_true(true)
