extends "res://addons/gut/test.gd"

## Tests unitarios para el efecto Smear en impacto de escudo
## en GuardianaMoradita (Goblina con Escudo Pesado).

const GUARDIANA_SCENE: PackedScene = preload("res://Entities/Enemigo_Goblina_Escudo_Pesado/GuardianaMoradita.tscn")

var guardiana: GuardianaMoradita = null


func before_each() -> void:
	guardiana = GUARDIANA_SCENE.instantiate() as GuardianaMoradita
	add_child_autofree(guardiana)
	await get_tree().process_frame


func after_each() -> void:
	if is_instance_valid(guardiana) and not guardiana.is_queued_for_deletion():
		guardiana.free()
	guardiana = null


func test_smear_effect_deforma_personaje_y_escudo_en_bloqueo() -> void:
	# Arrange
	assert_not_null(guardiana.model_root, "Debe tener referencia a model_root")
	assert_not_null(guardiana.escudo_node, "Debe tener referencia a escudo_node")

	var orig_model_scale: Vector3 = guardiana._orig_model_scale
	var orig_escudo_scale: Vector3 = guardiana._orig_escudo_scale

	# Act: aplicar smear de impacto
	guardiana._aplicar_smear_impacto()

	# Assert: Smear activo y modelo/escudo deformados exageradamente
	assert_true(guardiana._is_smear_active, "El efecto smear debe marcarse activo")
	assert_gt(guardiana.escudo_node.scale.x, orig_escudo_scale.x, "El escudo debe estirarse exageradamente en X")
	assert_gt(guardiana.escudo_node.scale.y, orig_escudo_scale.y, "El escudo debe estirarse exageradamente en Y")
	assert_gt(guardiana.model_root.scale.x, orig_model_scale.x, "El cuerpo del personaje debe estirarse en X por el retroceso")
	assert_lt(guardiana.model_root.scale.y, orig_model_scale.y, "El cuerpo del personaje debe aplastarse en Y por el smear frame")


func test_smear_effect_retorno_suave_a_escala_original() -> void:
	# Arrange & Act
	guardiana._aplicar_smear_impacto()
	assert_true(guardiana._is_smear_active, "Debe estar activo al inicio")

	# Esperar ciclo elástico de smear (~0.28s)
	await wait_seconds(0.35)

	# Assert
	assert_false(guardiana._is_smear_active, "El smear debe finalizar")
	assert_almost_eq(guardiana.model_root.scale.x, guardiana._orig_model_scale.x, 0.02, "El modelo debe asentarse en su escala X")
	assert_almost_eq(guardiana.model_root.scale.y, guardiana._orig_model_scale.y, 0.02, "El modelo debe asentarse en su escala Y")
	assert_almost_eq(guardiana.escudo_node.scale.x, guardiana._orig_escudo_scale.x, 0.02, "El escudo debe asentarse en su escala X")
	assert_almost_eq(guardiana.escudo_node.scale.y, guardiana._orig_escudo_scale.y, 0.02, "El escudo debe asentarse en su escala Y")


func test_recibir_golpe_en_escudo_activa_smear() -> void:
	# Arrange
	guardiana.current_state = GuardianaMoradita.State.DEFENDING

	# Act: recibir golpe bloqueado por el escudo
	guardiana.take_damage(1.0, true)

	# Assert: entra en SHIELD_HIT con smear activo
	assert_eq(guardiana.current_state, GuardianaMoradita.State.SHIELD_HIT, "Debe pasar al estado SHIELD_HIT")
	assert_true(guardiana._is_smear_active, "El smear debe activarse al bloquear el impacto")


func test_smear_deshabilitado_no_aplica_deformacion() -> void:
	# Arrange
	guardiana.habilitar_smear_impacto = false
	var orig_model_scale: Vector3 = guardiana.model_root.scale
	var orig_escudo_scale: Vector3 = guardiana.escudo_node.scale

	# Act
	guardiana._aplicar_smear_impacto()

	# Assert
	assert_false(guardiana._is_smear_active, "No debe activarse si está deshabilitado")
	assert_eq(guardiana.model_root.scale, orig_model_scale, "La escala del modelo no debe cambiar")
	assert_eq(guardiana.escudo_node.scale, orig_escudo_scale, "La escala del escudo no debe cambiar")


func test_muerte_resetea_smear_a_escala_original() -> void:
	# Arrange
	guardiana._aplicar_smear_impacto()
	assert_true(guardiana._is_smear_active, "Smear activo antes de morir")

	# Act: aplicar daño letal
	guardiana.take_damage(float(guardiana.health + 10), true)

	# Assert
	assert_false(guardiana._is_smear_active, "Smear debe desactivarse al morir")
	assert_almost_eq(guardiana.model_root.scale.x, guardiana._orig_model_scale.x, 0.01, "Escala modelo restaurada")
