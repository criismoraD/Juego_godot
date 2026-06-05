extends "res://addons/gut/test.gd"

var imp_trident_script = preload("res://Scripts/Projectiles/ImpTrident.gd")

func test_create_material():
	var trident = imp_trident_script.new()
	# Call the method manually since it's called in _ready
	trident._create_material()

	var mat = trident.projectile_material
	assert_not_null(mat, "projectile_material should be created")
	assert_true(mat is StandardMaterial3D, "projectile_material should be a StandardMaterial3D")

	assert_eq(mat.albedo_color, trident.color_proyectil, "albedo_color should match color_proyectil")
	assert_true(mat.emission_enabled, "emission_enabled should be true")
	assert_eq(mat.emission, trident.color_proyectil, "emission should match color_proyectil")

	trident.free()

func test_create_material_reuses_shared_resource_for_same_color():
	# Arrange
	var trident_a = imp_trident_script.new()
	var trident_b = imp_trident_script.new()
	var shared_color := Color(1.0, 0.15, 0.05)
	trident_a.color_proyectil = shared_color
	trident_b.color_proyectil = shared_color

	# Act
	trident_a._create_material()
	trident_b._create_material()

	# Assert
	assert_same(
		trident_a.projectile_material,
		trident_b.projectile_material,
		"Tridents with same color should reuse the same material resource"
	)

	trident_a.free()
	trident_b.free()
