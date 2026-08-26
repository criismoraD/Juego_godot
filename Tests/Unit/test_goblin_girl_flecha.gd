extends GutTest

## Tests de la flecha en mano de GoblinGirl:
## la pose afinada en el editor (FlechaMano bajo BoneAttachment3D2) debe ser la
## fuente de verdad y NO pisada por offset_flecha_mano (0,0,0) durante el disparo.

const GOBLIN_GIRL_SCENE: PackedScene = preload("res://Entities/Enemigo_Goblin_Girl/GoblinGirl.tscn")

var scene_root: Node3D


func before_each() -> void:
	scene_root = Node3D.new()
	add_child(scene_root)


func after_each() -> void:
	if is_instance_valid(scene_root):
		scene_root.queue_free()
	await get_tree().process_frame


func test_pose_base_flecha_capturada_del_editor() -> void:
	# Arrange & Act
	var goblin := GOBLIN_GIRL_SCENE.instantiate() as GoblinGirl
	scene_root.add_child(goblin)
	await get_tree().process_frame

	# Assert: la flecha en mano existe y su pose base fue capturada
	assert_not_null(goblin.flecha_visual_mano, "GoblinGirl debe tener FlechaMano de la escena")
	assert_true(
		goblin._pose_base_flecha_mano != Transform3D.IDENTITY,
		"La pose base debe capturarse del nodo colocado en el editor"
	)
	assert_true(
		goblin._pose_base_flecha_mano == goblin.flecha_visual_mano.transform,
		"La pose base debe coincidir con el transform local afinado en la escena"
	)

	goblin.queue_free()
	await get_tree().process_frame


func test_animacion_disparo_no_pisa_la_pose_de_la_flecha() -> void:
	# Arrange
	var goblin := GOBLIN_GIRL_SCENE.instantiate() as GoblinGirl
	scene_root.add_child(goblin)
	await get_tree().process_frame
	var origen_esperado: Vector3 = goblin._pose_base_flecha_mano.origin
	assert_false(
		origen_esperado.is_zero_approx(),
		"Precondición: la flecha afinada en editor no debe estar en el origen del hueso"
	)

	# Act: forzar rama "else" (fuera de fase de tensión) de la animación de disparo
	goblin.en_animacion_disparo = true
	goblin.anim_timer = 0.0
	goblin._actualizar_flecha_mano_durante_animacion()

	# Assert: la posición se restaura a la pose base, nunca a offset_flecha_mano (0,0,0)
	assert_eq(
		goblin.flecha_visual_mano.position,
		origen_esperado,
		"La animación debe restaurar la pose base del editor, no (0,0,0)"
	)

	goblin.queue_free()
	await get_tree().process_frame
