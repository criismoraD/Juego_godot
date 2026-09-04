extends "res://addons/gut/test.gd"

const IMP_ESTANDARTE_SCENE: PackedScene = preload("res://Entities/Enemigo_Imp_Estandarte/ImpEnemyEstandarte.tscn")


func test_flash_rojo_no_deja_material_override_permanente():
	# Arrange: el imp embajador recibe un golpe (flash rojo)
	var imp = IMP_ESTANDARTE_SCENE.instantiate()
	add_child_autofree(imp)
	await get_tree().process_frame

	var mallas: Array = imp._cached_mesh_instances
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
	assert_eq(imp.health, 7, "Un disparo debe dejar al imp en 7 HP (no desaparecer)")
	assert_false(imp.is_queued_for_deletion(), "El imp no debe liberarse")
	assert_true(imp.visible, "El imp debe seguir visible tras el impacto")


func test_imp_embajador_drop_100_porciento_disparo_multiple():
	# Arrange
	var imp = IMP_ESTANDARTE_SCENE.instantiate()
	add_child_autofree(imp)
	await get_tree().process_frame

	assert_eq(imp.probabilidad_drop_multiple, 1.0, "La probabilidad de drop debe ser 100% (1.0)")
	assert_not_null(imp.power_up_multiple_scene, "Debe tener asignada la escena de PowerUpFlechaMultiple")

	# Act: Ejecutar muerte
	imp._on_state_dying()
	await get_tree().process_frame

	# Assert: Buscar el item de disparo múltiple instanciado en la escena
	var power_up: Node = null
	var root = get_tree().current_scene if get_tree().current_scene else get_tree().root
	for child in root.get_children():
		if child is PowerUpFlechaMultiple or child.is_in_group("power_ups_flecha_multiple") or child.name.contains("PowerUp"):
			power_up = child
			break

	assert_not_null(power_up, "Debe instanciar el item de disparo múltiple al morir")
	if is_instance_valid(power_up):
		power_up.queue_free()


func test_imp_embajador_deja_charco_sangre_al_morir():
	# Arrange
	var imp = IMP_ESTANDARTE_SCENE.instantiate()
	add_child_autofree(imp)
	await get_tree().process_frame

	# Act: muerte (como por flecha explosiva)
	imp._on_state_dying()
	await get_tree().process_frame

	# Assert: charco de sangre en el suelo
	var manchas := get_tree().root.find_children("ManchaSangreSuelo", "MeshInstance3D", true, false)
	assert_gt(manchas.size(), 0, "El imp embajador debe dejar charco de sangre al morir")
	for m in manchas:
		if is_instance_valid(m):
			m.queue_free()
