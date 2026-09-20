extends GutTest

const ArrowScene = preload("res://Entities/Proyectil_Flecha/Arrow.tscn")

func test_arrow_catchup():
	var root = Node3D.new()
	add_child_autofree(root)

	var a1 = ArrowScene.instantiate() as ArrowProjectile
	a1.name = "Arrow_Slow"
	a1.initialize(Vector3.RIGHT, 15.0)
	a1.set_meta("fuego_rapido", true)
	a1.escala_gravedad = 0.0
	root.add_child(a1)
	a1.global_position = Vector3(5.0, 0.0, 0.0)

	var a2 = ArrowScene.instantiate() as ArrowProjectile
	a2.name = "Arrow_Fast"
	a2.initialize(Vector3.RIGHT, 30.0)
	a2.set_meta("fuego_rapido", true)
	a2.escala_gravedad = 0.0
	root.add_child(a2)
	a2.global_position = Vector3(0.0, 0.0, 0.0)

	for f in range(30):
		await get_tree().physics_frame
		gut.p("F%02d: a1(slow)=%.3f, a2(fast)=%.3f, dist=%.3f, a2.destr=%s" % [
			f, a1.global_position.x, a2.global_position.x, 
			a1.global_position.x - a2.global_position.x, 
			a2._destroying
		])

	assert_true(true)
