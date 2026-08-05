extends "res://addons/gut/test.gd"

class TestableGoblin extends "res://Entities/Enemigo_Goblin/Goblin.gd":
	# Evitar dependencias de inicialización de AudioManager u otros Singletons en test
	func _on_state_dying():
		collision_layer = 0
		collision_mask = 0
		set_physics_process(false)

func test_rotation_on_flat_ground():
	var goblin = TestableGoblin.new()
	goblin._test_floor_normal_override = Vector3.UP # (0, 1, 0)
	
	# Inicializar variables necesarias
	goblin.health = 10
	
	# Cambiar a estado de muerte
	goblin._change_state(goblin.State.DYING)
	
	assert_eq(goblin.rotation.z, 0.0, "Should have 0 rotation on flat ground")
	goblin.free()

func test_rotation_on_ramp_up_right():
	var goblin = TestableGoblin.new()
	# Rampa subiendo a la derecha (normal inclinada arriba a la izquierda, N.x < 0)
	goblin._test_floor_normal_override = Vector3(-0.707, 0.707, 0).normalized()
	goblin.health = 10
	
	goblin._change_state(goblin.State.DYING)
	
	# theta = atan2(-N.x, N.y) = atan2(-(-0.707), 0.707) = PI/4 (45 grados)
	assert_almost_eq(goblin.rotation.z, PI / 4.0, 0.01, "Should align with the ramp going up right")
	goblin.free()

func test_rotation_on_ramp_up_left():
	var goblin = TestableGoblin.new()
	# Rampa subiendo a la izquierda (normal inclinada arriba a la derecha, N.x > 0)
	goblin._test_floor_normal_override = Vector3(0.707, 0.707, 0).normalized()
	goblin.health = 10
	
	goblin._change_state(goblin.State.DYING)
	
	# theta = atan2(-N.x, N.y) = atan2(-0.707, 0.707) = -PI/4 (-45 grados)
	assert_almost_eq(goblin.rotation.z, -PI / 4.0, 0.01, "Should align with the ramp going up left")
	goblin.free()
