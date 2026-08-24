extends "res://addons/gut/test.gd"

const IMP_ESTANDARTE_SCENE: PackedScene = preload("res://Entities/Enemigo_Imp_Estandarte/ImpEnemyEstandarte.tscn")


func test_flash_rojo_no_deja_material_override_permanente():
	# Arrange: el imp embajador recibe un golpe (flash rojo)
	var imp = IMP_ESTANDARTE_SCENE.instantiate()
	add_child_autofree(imp)
	await get_tree().process_frame

	var mallas := imp._cached_mesh_instances
	assert_gt(mallas.size(), 0, "El imp debe tener mallas cacheadas")

	# Act: flash de daño + restauración (0.08 s)
	imp._flash_red()
	await wait_seconds(0.2)

	# Assert: NINGUNA malla debe quedarse con el material rojo del flash
	# (antes, las mallas GLB sin overrides quedaban teñidas/ocultas para siempre)
	for mesh in mallas:
		if is_instance_valid(mesh):
			assert_ne(
				mesh.material_override, imp._red_flash_material,
				"El material rojo del flash no debe permanecer tras restaurar (%s)" % mesh.name
			)


func test_imp_embajador_sobrevive_un_disparo():
	# Arrange: el embajador tiene 6 HP; un disparo NO debe matarlo ni ocultarlo
	var imp = IMP_ESTANDARTE_SCENE.instantiate()
	add_child_autofree(imp)
	await get_tree().process_frame

	# Act
	imp.take_damage(1.0)
	await wait_seconds(0.15)

	# Assert
	assert_eq(imp.health, 5, "Un disparo debe dejar al imp en 5 HP (no desaparecer)")
	assert_false(imp.is_queued_for_deletion(), "El imp no debe liberarse")
	assert_true(imp.visible, "El imp debe seguir visible tras el impacto")
