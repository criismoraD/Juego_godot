extends "res://addons/gut/test.gd"

const PROJECTILE_POOL_REF = preload("res://Scripts/Core/ProjectilePool.gd")

var goblin_arrow_scene: PackedScene = preload("res://Scenes/Projectiles/GoblinArrow.tscn")
var goblin_girl_arrow_scene: PackedScene = preload("res://Scenes/Projectiles/GoblinGirlArrow.tscn")


func after_each() -> void:
	PROJECTILE_POOL_REF.clear_all()


func test_release_reuses_same_projectile_instance() -> void:
	# Arrange
	var arrow_a = PROJECTILE_POOL_REF.acquire(goblin_arrow_scene)
	arrow_a.initialize(Vector3.LEFT, 0.5)
	PROJECTILE_POOL_REF.activate(arrow_a, get_tree().root, Vector3(1.0, 2.0, 0.0))

	# Act
	PROJECTILE_POOL_REF.release(arrow_a)
	var arrow_b = PROJECTILE_POOL_REF.acquire(goblin_arrow_scene)

	# Assert
	assert_same(arrow_a, arrow_b, "Pool should reuse the released projectile instance")
	assert_false(arrow_b.is_inside_tree(), "Reused projectile should stay off-tree until activation")

	PROJECTILE_POOL_REF.release(arrow_b)


func test_activate_restores_reused_projectile_state() -> void:
	# Arrange
	var arrow = PROJECTILE_POOL_REF.acquire(goblin_arrow_scene)
	arrow.initialize(Vector3.LEFT, 0.0)
	PROJECTILE_POOL_REF.activate(arrow, get_tree().root, Vector3.ZERO)
	PROJECTILE_POOL_REF.release(arrow)

	# Act
	var reused_arrow = PROJECTILE_POOL_REF.acquire(goblin_arrow_scene)
	reused_arrow.initialize(Vector3.RIGHT, 1.0)
	PROJECTILE_POOL_REF.activate(reused_arrow, get_tree().root, Vector3(3.0, 4.0, 0.0))

	# Assert
	assert_true(reused_arrow.visible, "Reused projectile should become visible on activation")
	assert_true(reused_arrow.monitorable, "Reused projectile should become monitorable on activation")
	assert_false(reused_arrow.is_stuck, "Reused projectile should not remain stuck")
	assert_eq(reused_arrow.global_position, Vector3(3.0, 4.0, 0.0))

	PROJECTILE_POOL_REF.release(reused_arrow)


func test_reused_arrow_updates_visual_resources_for_new_color() -> void:
	# Arrange
	var arrow = PROJECTILE_POOL_REF.acquire(goblin_girl_arrow_scene)
	arrow.color_proyectil = Color(0.8, 0.2, 0.8)
	arrow.initialize(Vector3.LEFT)
	PROJECTILE_POOL_REF.activate(arrow, get_tree().root, Vector3.ZERO)
	PROJECTILE_POOL_REF.release(arrow)

	# Act
	var reused_arrow = PROJECTILE_POOL_REF.acquire(goblin_girl_arrow_scene)
	var new_color := Color(1.0, 0.06, 0.03, 1.0)
	reused_arrow.color_proyectil = new_color
	reused_arrow.initialize(Vector3.LEFT)
	PROJECTILE_POOL_REF.activate(reused_arrow, get_tree().root, Vector3.ZERO)

	# Assert
	assert_eq(reused_arrow.projectile_material.albedo_color, new_color)
	assert_not_null(reused_arrow.trail_particles.process_material)
	assert_not_null(reused_arrow.trail_particles.draw_pass_1)
	assert_true(reused_arrow.trail_particles.emitting)

	PROJECTILE_POOL_REF.release(reused_arrow)


func test_reused_projectile_does_not_keep_previous_shooter_scale() -> void:
	# Arrange
	var banner_arrow = PROJECTILE_POOL_REF.acquire(goblin_girl_arrow_scene)
	banner_arrow.scale = Vector3(1.8, 1.8, 1.8)
	banner_arrow.initialize(Vector3.LEFT)
	PROJECTILE_POOL_REF.activate(banner_arrow, get_tree().root, Vector3.ZERO)
	PROJECTILE_POOL_REF.release(banner_arrow)

	# Act
	var normal_arrow = PROJECTILE_POOL_REF.acquire(goblin_girl_arrow_scene)
	normal_arrow.scale = Vector3.ONE
	normal_arrow.initialize(Vector3.LEFT)
	PROJECTILE_POOL_REF.activate(normal_arrow, get_tree().root, Vector3.ZERO)

	# Assert
	assert_same(banner_arrow, normal_arrow, "The same pooled instance should be reused")
	assert_eq(normal_arrow.scale, Vector3.ONE, "Projectile scale should be owned by each shooter")

	PROJECTILE_POOL_REF.release(normal_arrow)
