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

func test_default_color_is_orange():
	var arrow = goblin_arrow_script.new()

	assert_eq(arrow.color_proyectil, GoblinArrowProjectile.GOBLIN_ARROW_ORANGE)

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

func test_create_material_reuses_shared_resource_for_same_color():
	# Arrange
	var arrow_a = goblin_arrow_script.new()
	var arrow_b = goblin_arrow_script.new()
	var shared_color := Color(1.0, 0.25, 0.0)
	arrow_a.color_proyectil = shared_color
	arrow_b.color_proyectil = shared_color

	# Act
	arrow_a._create_material()
	arrow_b._create_material()

	# Assert
	assert_same(
		arrow_a.projectile_material,
		arrow_b.projectile_material,
		"Projectiles with same color should reuse the same material resource"
	)

	arrow_a.free()
	arrow_b.free()

func test_trail_resources_are_cached_per_color():
	# Arrange
	var arrow = goblin_arrow_script.new()
	var shared_color := Color(0.8, 0.2, 0.8)

	# Act
	var process_a = arrow._get_shared_trail_process_material(shared_color)
	var process_b = arrow._get_shared_trail_process_material(shared_color)
	var mesh_a = arrow._get_shared_trail_mesh(shared_color)
	var mesh_b = arrow._get_shared_trail_mesh(shared_color)

	# Assert
	assert_same(process_a, process_b, "Trail process material should be reused per color")
	assert_same(mesh_a, mesh_b, "Trail mesh should be reused per color")

	arrow.free()
