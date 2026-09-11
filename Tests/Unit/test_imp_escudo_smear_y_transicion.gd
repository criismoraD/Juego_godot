extends "res://addons/gut/test.gd"

## Tests unitarios para el efecto Smear en impacto de escudo
## y transiciones suaves (frames intermedios) entre bloqueo y caminar en ImpShieldGirl.

const IMP_ESCUDO_SCENE: PackedScene = preload("res://Entities/Enemigo_Imp_Escudo/ImpShieldGirl.tscn")

var imp: ImpShieldGirl = null


func before_each():
	imp = IMP_ESCUDO_SCENE.instantiate() as ImpShieldGirl
	imp.posion_drop_chance = 0.0
	add_child_autofree(imp)
	await get_tree().process_frame


func after_each():
	if is_instance_valid(imp) and not imp.is_queued_for_deletion():
		imp.free()
	imp = null


func test_smear_effect_deforma_personaje_y_escudo_en_bloqueo():
	# Arrange
	assert_not_null(imp.model_root, "Debe tener referencia a model_root")
	assert_not_null(imp.escudo_node, "Debe tener referencia a escudo_node")

	var orig_model_scale: Vector3 = imp._orig_model_scale
	var orig_escudo_scale: Vector3 = imp._orig_escudo_scale

	# Act: aplicar smear de impacto
	imp._aplicar_smear_impacto()

	# Assert: Smear activo y modelo/escudo deformados exageradamente
	assert_true(imp._is_smear_active, "El efecto smear debe marcarse activo")
	assert_gt(imp.escudo_node.scale.x, orig_escudo_scale.x, "El escudo debe estirarse exageradamente en X")
	assert_gt(imp.escudo_node.scale.y, orig_escudo_scale.y, "El escudo debe estirarse exageradamente en Y")
	assert_gt(imp.model_root.scale.x, orig_model_scale.x, "El cuerpo del personaje debe estirarse en X por el retroceso")
	assert_lt(imp.model_root.scale.y, orig_model_scale.y, "El cuerpo del personaje debe aplastarse en Y por el smear frame")


func test_smear_effect_retorno_suave_a_escala_original():
	# Arrange & Act
	imp._aplicar_smear_impacto()
	assert_true(imp._is_smear_active, "Debe estar activo al inicio")

	# Esperar ciclo elástico de smear (~0.28s)
	await wait_seconds(0.35)

	# Assert
	assert_false(imp._is_smear_active, "El smear debe finalizar")
	assert_almost_eq(imp.model_root.scale.x, imp._orig_model_scale.x, 0.02, "El modelo debe asentarse en su escala X")
	assert_almost_eq(imp.model_root.scale.y, imp._orig_model_scale.y, 0.02, "El modelo debe asentarse en su escala Y")
	assert_almost_eq(imp.escudo_node.scale.x, imp._orig_escudo_scale.x, 0.02, "El escudo debe asentarse en su escala X")
	assert_almost_eq(imp.escudo_node.scale.y, imp._orig_escudo_scale.y, 0.02, "El escudo debe asentarse en su escala Y")


func test_transicion_de_bloqueo_a_caminar_con_frames_intermedios():
	# Arrange
	imp.current_state = ImpShieldGirl.State.WALKING
	assert_gt(imp.transicion_blend_caminar, 0.2, "Debe tener tiempo de crossfade para generar frames intermedios")

	# Act: recibir daño con escudo intacto
	imp.take_damage(1.0)

	# Assert: entra en SHIELD_HIT con smear activo
	assert_eq(imp.current_state, ImpShieldGirl.State.SHIELD_HIT, "Debe pasar al estado SHIELD_HIT")
	assert_true(imp._is_smear_active, "El smear debe activarse al bloquear el impacto")


func test_smear_deshabilitado_no_aplica_deformacion():
	# Arrange
	imp.habilitar_smear_impacto = false
	var orig_model_scale: Vector3 = imp.model_root.scale
	var orig_escudo_scale: Vector3 = imp.escudo_node.scale

	# Act
	imp._aplicar_smear_impacto()

	# Assert
	assert_false(imp._is_smear_active, "No debe activarse si está deshabilitado")
	assert_eq(imp.model_root.scale, orig_model_scale, "La escala del modelo no debe cambiar")
	assert_eq(imp.escudo_node.scale, orig_escudo_scale, "La escala del escudo no debe cambiar")
