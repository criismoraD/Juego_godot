extends "res://addons/gut/test.gd"

const IMP_ESCUDO_SCENE: PackedScene = preload("res://Entities/Enemigo_Imp_Escudo/ImpShieldGirl.tscn")

var imp: ImpShieldGirl = null


func before_each():
	imp = IMP_ESCUDO_SCENE.instantiate() as ImpShieldGirl
	imp.posion_drop_chance = 0.0  # Sin drops durante tests
	add_child_autofree(imp)
	await get_tree().process_frame


func after_each():
	if is_instance_valid(imp) and not imp.is_queued_for_deletion():
		imp.free()
	imp = null


func test_flag_impulso_explosivo_existe_y_arranca_falso():
	assert_false(imp.murio_por_explosion, "murio_por_explosion debe iniciar en false")
	assert_false(imp._impulso_explosivo_activo, "_impulso_explosivo_activo debe iniciar en false")


func test_explosion_en_retirada_sin_escudo_aplica_parabola():
	# Arrange: escudo roto, huyendo (retirada), marcada por explosión
	imp._cambiar_estado(ImpShieldGirl.State.FLEEING)
	imp.escudo_vida_actual = 0
	imp.murio_por_explosion = true
	imp.last_hit_position = imp.global_position + Vector3(-1.0, 0.0, 0.0)

	# Act: morir
	imp._cambiar_estado(ImpShieldGirl.State.DYING)

	# Assert: parábola activa con física reactivada y animación normal
	assert_true(imp._impulso_explosivo_activo, "El vuelo parabólico debe activarse al morir en retirada")
	assert_true(imp.is_physics_processing(), "La física del cuerpo debe reactivarse durante el vuelo")
	assert_gt(imp.velocity.x, 0.0, "Debe recibir empuje hacia la derecha")
	assert_gt(imp.velocity.y, 0.0, "Debe elevarse un poco")
	assert_eq(imp.velocity.z, 0.0, "Sin desvío en Z (2.5D)")
	assert_eq(imp.current_state, ImpShieldGirl.State.DYING, "Debe seguir en DYING con su animación de muerte")
	assert_false(imp.murio_por_explosion, "La bandera debe limpiarse tras aplicar el impulso")


func test_explosion_con_escudo_no_aplica_parabola():
	# Arrange: todavía con escudo (la explosión solo rompe el escudo)
	imp.escudo_vida_actual = 3
	imp.murio_por_explosion = true

	# Act: morir desde WALKING (no en retirada)
	imp._cambiar_estado(ImpShieldGirl.State.DYING)

	# Assert: sin impulso, comportamiento normal
	assert_false(imp._impulso_explosivo_activo, "Con escudo no debe haber vuelo parabólico")
	assert_false(imp.is_physics_processing(), "La física debe permanecer desactivada")


func test_explosion_sin_retirada_no_aplica_parabola():
	# Arrange: sin escudo pero muriendo desde WALKING (no en retirada)
	imp.escudo_vida_actual = 0
	imp.murio_por_explosion = true

	# Act
	imp._cambiar_estado(ImpShieldGirl.State.DYING)

	# Assert
	assert_false(imp._impulso_explosivo_activo, "Fuera de retirada no debe haber vuelo parabólico")
	assert_false(imp.is_physics_processing(), "La física debe permanecer desactivada")


# ═══════════════════════════════════════════════════════════════════════════════
# Humo de retirada (mismo efecto que la Lonko al correr)
# ═══════════════════════════════════════════════════════════════════════════════

func test_humo_retirada_existe_y_apagado_por_defecto():
	assert_not_null(imp.humo_retirada, "Debe existir el nodo HumoRetirada")
	if imp.humo_retirada:
		assert_false(imp.humo_retirada.emitting, "El humo debe iniciar apagado")


func test_humo_retirada_emite_solo_corriendo_en_retirada():
	# Corriendo en retirada → emite
	imp._cambiar_estado(ImpShieldGirl.State.FLEEING)
	imp.velocity.x = 1.0
	imp._actualizar_humo_retirada()
	assert_true(imp.humo_retirada.emitting, "Debe emitir humo corriendo en retirada")

	# Defendiendo → no emite
	imp._cambiar_estado(ImpShieldGirl.State.DEFENDING)
	imp._actualizar_humo_retirada()
	assert_false(imp.humo_retirada.emitting, "Defendiendo no debe emitir humo")

	# Retirada pero detenida → no emite
	imp._cambiar_estado(ImpShieldGirl.State.ESCAPING)
	imp.velocity.x = 0.0
	imp._actualizar_humo_retirada()
	assert_false(imp.humo_retirada.emitting, "En retirada pero sin moverse no debe emitir humo")
