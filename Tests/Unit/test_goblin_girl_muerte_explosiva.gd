extends "res://addons/gut/test.gd"

const GIRL_SCENE: PackedScene = preload("res://Entities/Enemigo_Goblin_Girl/GoblinGirl.tscn")

var girl: GoblinGirl = null


func before_each():
	girl = GIRL_SCENE.instantiate() as GoblinGirl
	add_child_autofree(girl)
	await get_tree().process_frame


func after_each():
	if is_instance_valid(girl) and not girl.is_queued_for_deletion():
		girl.free()
	girl = null


func test_flag_impulso_explosivo_existe_y_arranca_falso():
	assert_false(girl.murio_por_explosion, "murio_por_explosion debe iniciar en false")
	assert_false(girl._impulso_explosivo_activo, "_impulso_explosivo_activo debe iniciar en false")


func test_muerte_explosiva_aplica_parabola_y_mantiene_disolucion_normal():
	# Arrange
	girl.murio_por_explosion = true
	girl.last_hit_position = girl.global_position + Vector3(-1.0, 0.0, 0.0)

	# Act
	girl._on_state_dying()

	# Assert: impulso activo (salto + empuje a la derecha) con física reactivada
	assert_true(girl._impulso_explosivo_activo, "El vuelo parabólico debe activarse")
	assert_true(girl.is_physics_processing(), "La física del cuerpo debe reactivarse durante el vuelo")
	assert_gt(girl.velocity.x, 0.0, "Debe recibir empuje hacia la derecha")
	assert_gt(girl.velocity.y, 0.0, "Debe elevarse un poco")
	assert_eq(girl.velocity.z, 0.0, "Sin desvío en Z (2.5D)")
	# La bandera se limpia para que _die() use la disolución normal (no borrado instantáneo)
	assert_false(girl.murio_por_explosion, "La bandera debe limpiarse tras aplicar el impulso")


func test_muerte_normal_sin_impulso():
	# Act
	girl._on_state_dying()

	# Assert: la muerte normal mantiene el comportamiento de EnemyBase
	assert_false(girl._impulso_explosivo_activo, "Sin explosión no hay vuelo parabólico")
	assert_false(girl.is_physics_processing(), "La física debe permanecer desactivada (muerte en sitio)")
