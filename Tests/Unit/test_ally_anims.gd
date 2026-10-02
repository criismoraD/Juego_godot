extends GutTest

func test_inspect_ally_archer():
	var scene = load("res://Entities/Aliada_Arquera/ALLY_ARCHER.glb")
	var node = scene.instantiate()
	add_child(node)
	
	print("\n================== ALLY_ARCHER.glb ==================")
	var ap = node.find_child("AnimationPlayer", true, false)
	if ap:
		for lib in ap.get_animation_library_list():
			var al = ap.get_animation_library(lib)
			for a in al.get_animation_list():
				print("  Anim: ", a)
	
	node.queue_free()
	assert_true(true)
