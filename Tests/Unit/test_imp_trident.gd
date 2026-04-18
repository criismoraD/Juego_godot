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
