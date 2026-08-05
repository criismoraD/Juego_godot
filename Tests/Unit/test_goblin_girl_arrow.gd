extends "res://addons/gut/test.gd"

var goblin_girl_arrow_script = preload("res://Entities/Proyectil_Flecha_Goblin_Girl/GoblinGirlArrow.gd")


func test_initialize_sets_direction_and_scales_velocity() -> void:
	# Arrange
	var arrow = goblin_girl_arrow_script.new()
	var shoot_dir := Vector3(1.0, 1.0, 0.5)
	var potencia := 0.5

	# Act
	arrow.initialize(shoot_dir, potencia)

	# Assert
	var expected_dir := Vector3(1.0, 1.0, 0.0).normalized()
	assert_eq(arrow.direction, expected_dir, "Direction should be normalized in the XY plane")
	assert_almost_eq(arrow.velocidad, 5.0, 0.001, "Velocity should be scaled by potencia")
	assert_almost_eq(arrow.rotation.z, atan2(expected_dir.y, expected_dir.x), 0.001)

	arrow.free()


func test_initialize_does_not_accumulate_velocity_between_reuses() -> void:
	# Arrange
	var arrow = goblin_girl_arrow_script.new()

	# Act
	arrow.initialize(Vector3.LEFT, 2.0)
	arrow.initialize(Vector3.LEFT, 2.0)

	# Assert
	assert_almost_eq(arrow.velocidad, 20.0, 0.001, "Velocity should be based on the base value every shot")

	arrow.free()


func test_default_color_is_magenta() -> void:
	# Arrange
	var arrow = goblin_girl_arrow_script.new()

	# Assert
	assert_eq(arrow.color_proyectil, GoblinGirlArrowProjectile.GOBLIN_GIRL_ARROW_MAGENTA)

	arrow.free()


func test_initialize_defaults_on_zero_direction() -> void:
	# Arrange
	var arrow = goblin_girl_arrow_script.new()

	# Act
	arrow.initialize(Vector3.ZERO)

	# Assert
	assert_eq(arrow.direction, Vector3.LEFT, "Zero input should default to Vector3.LEFT")

	arrow.free()


func test_visual_resources_are_cached_per_color() -> void:
	# Arrange
	var arrow = goblin_girl_arrow_script.new()
	var shared_color := Color(0.8, 0.2, 0.8)

	# Act
	var material_a = arrow._get_shared_projectile_material(shared_color)
	var material_b = arrow._get_shared_projectile_material(shared_color)
	var process_a = arrow._get_shared_trail_process_material(shared_color)
	var process_b = arrow._get_shared_trail_process_material(shared_color)
	var mesh_a = arrow._get_shared_trail_mesh(shared_color)
	var mesh_b = arrow._get_shared_trail_mesh(shared_color)

	# Assert
	assert_same(material_a, material_b, "Projectile material should be reused per color")
	assert_same(process_a, process_b, "Trail process material should be reused per color")
	assert_same(mesh_a, mesh_b, "Trail mesh should be reused per color")

	arrow.free()
