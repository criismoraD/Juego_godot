extends GutTest

const IMPERIO_SCENE: PackedScene = preload("res://Entities/Jugador_ImperioGirl/ImperioGirl.tscn")

func test_all_imperio_anims_facing():
	var imp = IMPERIO_SCENE.instantiate()
	add_child(imp)
	var ap = imp._player_corporal()

	print("\n================== ALL IMPERIO ANIMATIONS FACING ==================")
	for lib_name in ap.get_animation_library_list():
		var lib = ap.get_animation_library(lib_name)
		for anim_name in lib.get_animation_list():
			if anim_name.begins_with("Armature|"):
				continue # skip alias
			var anim = lib.get_animation(anim_name)
			_inspect_anim(anim, anim_name)

	imp.queue_free()
	assert_true(true)

func _inspect_anim(anim: Animation, name: String):
	for i in anim.get_track_count():
		var path = String(anim.track_get_path(i))
		if path.ends_with(":mixamorig_Hips") and anim.track_get_type(i) == Animation.TYPE_ROTATION_3D:
			if anim.track_get_key_count(i) > 0:
				var q: Quaternion = anim.track_get_key_value(i, 0)
				var e = q.get_euler() * (180.0 / PI)
				print("%-30s | Hips Euler: (x=%6.1f, y=%6.1f, z=%6.1f) | Q: (%.2f, %.2f, %.2f, %.2f)" % [
					name, e.x, e.y, e.z, q.x, q.y, q.z, q.w
				])
				return
