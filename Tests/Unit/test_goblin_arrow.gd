extends "res://addons/gut/test.gd"

var goblin_arrow_script = preload("res://Scripts/Projectiles/GoblinArrow.gd")

func test_initialize_sets_direction_and_speed():
	var arrow = goblin_arrow_script.new()
	var shoot_dir = Vector3(1, 1, 0.5)
	var power = 0.5 # Midpoint between 10 and 30 should be 20

	arrow.initialize(shoot_dir, power)

	# Direction should be normalized and Z set to 0
	var expected_dir = Vector3(1, 1, 0).normalized()
	assert_eq(arrow.direction, expected_dir, "Direction should be normalized XY")
	assert_almost_eq(arrow.direction.z, 0.0, 0.001, "Z component should be 0")

	# Speed should be lerped (0.5 power -> 20.0 speed)
	assert_almost_eq(arrow.speed, 20.0, 0.001, "speed should be lerped between 10 and 30")

	# Rotation should match direction
	var expected_angle = atan2(expected_dir.y, expected_dir.x)
	assert_almost_eq(arrow.rotation.z, expected_angle, 0.001, "Rotation should match direction angle")

	arrow.free()

func test_initialize_clamped_power():
	var arrow = goblin_arrow_script.new()

	# Power < 0
	arrow.initialize(Vector3.RIGHT, -1.0)
	assert_eq(arrow.speed, 10.0, "speed should be 10 for power <= 0")

	# Power > 1
	arrow.initialize(Vector3.RIGHT, 2.0)
	assert_eq(arrow.speed, 30.0, "speed should be 30 for power >= 1")

	arrow.free()

func test_initialize_defaults_on_zero_direction():
	var arrow = goblin_arrow_script.new()
	arrow.initialize(Vector3.ZERO)

	assert_eq(arrow.direction, Vector3.LEFT, "Should default to Vector3.LEFT on zero input")

	arrow.free()
