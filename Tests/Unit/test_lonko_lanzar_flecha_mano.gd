extends GutTest

## Tests: Lonko lanza la flecha real de la mano (FlechaMano) en vez de
## instanciar un proyectil nuevo aparte (regresión del disparo).

const LONKO_SCENE: PackedScene = preload("res://Entities/Enemigo_Lonko/Lonko.tscn")

var scene_root: Node3D


func before_each() -> void:
	scene_root = Node3D.new()
	add_child(scene_root)


func after_each() -> void:
	if is_instance_valid(scene_root):
		scene_root.queue_free()
	await get_tree().process_frame


func _crear_lonko() -> Lonko:
	var lonko := LONKO_SCENE.instantiate() as Lonko
	scene_root.add_child(lonko)
	await get_tree().process_frame
	# Garantizar la referencia a la flecha en mano (como hace _configurar_flecha_mano)
	if not lonko.flecha_visual_mano or not is_instance_valid(lonko.flecha_visual_mano):
		lonko.flecha_visual_mano = lonko.find_child("FlechaMano", true, false)
	return lonko


func test_lanzar_flecha_mano_reparenta_y_activa_proyectil() -> void:
	# Arrange
	var lonko := await _crear_lonko()
	var flecha_original: Node3D = lonko.flecha_visual_mano
	assert_not_null(flecha_original, "Precondición: FlechaMano debe existir")
	var pos_global_antes: Vector3 = flecha_original.global_position

	# Act
	var arrow: Node3D = lonko._lanzar_flecha_mano()

	# Assert: la flecha lanzada es el MISMO nodo de la mano
	assert_eq(arrow, flecha_original, "Debe lanzarse el nodo FlechaMano real")
	assert_true(
		arrow.is_in_group("enemy_projectiles"),
		"La flecha lanzada debe estar en el grupo enemy_projectiles"
	)
	assert_false(arrow.get("en_mano"), "La flecha lanzada no debe seguir en modo 'en mano'")
	assert_true(arrow.is_physics_processing(), "La flecha lanzada debe tener física activa")
	assert_true(arrow.visible, "La flecha lanzada debe ser visible")
	assert_not_null(
		arrow.find_child("FLECHA_ARQUERA_ENEMIGA", true, false),
		"La flecha lanzada debe conservar su modelo 3D FLECHA_ARQUERA_ENEMIGA"
	)
	assert_almost_eq(
		arrow.global_position.x, pos_global_antes.x, 0.05,
		"El reparent debe conservar la posición global (X)"
	)
	assert_almost_eq(
		arrow.global_position.y, pos_global_antes.y, 0.05,
		"El reparent debe conservar la posición global (Y)"
	)

	lonko.queue_free()
	await get_tree().process_frame


func test_lanzar_flecha_mano_genera_reemplazo_oculto_en_la_mano() -> void:
	# Arrange
	var lonko := await _crear_lonko()
	var flecha_original: Node3D = lonko.flecha_visual_mano
	var hueso_mano: Node = flecha_original.get_parent()

	# Act
	var _arrow: Node3D = lonko._lanzar_flecha_mano()

	# Assert: hay una nueva flecha oculta en el hueso para el próximo ciclo
	var reemplazo: Node3D = lonko.flecha_visual_mano
	assert_not_null(reemplazo, "Debe generarse una nueva flecha en mano")
	assert_false(reemplazo == flecha_original, "El reemplazo no debe ser la flecha lanzada")
	assert_eq(reemplazo.get_parent(), hueso_mano, "El reemplazo debe colgar del mismo hueso")
	assert_eq(reemplazo.name, "FlechaMano", "El reemplazo debe conservar el nombre FlechaMano")
	assert_false(reemplazo.visible, "El reemplazo debe estar oculto hasta la próxima RECARGA")
	assert_true(reemplazo.get("en_mano"), "El reemplazo debe seguir en modo 'en mano' (sin física)")

	lonko.queue_free()
	await get_tree().process_frame


func test_disparar_proyectil_usa_flecha_mano_y_no_instancia_otra() -> void:
	# Arrange
	var lonko := await _crear_lonko()
	lonko.cada_cuantos_tiros_electrico = 3
	var flecha_original: Node3D = lonko.flecha_visual_mano
	var hueso_mano: Node = flecha_original.get_parent()

	# Act: primer tiro (no eléctrico)
	lonko._has_released_arrow = false
	lonko._disparar_proyectil()

	# Assert
	assert_true(lonko._has_released_arrow, "El flag de flecha liberada debe activarse")
	assert_false(
		flecha_original.get_parent() == hueso_mano,
		"La flecha original ya no debe colgar del hueso de la mano"
	)
	assert_true(
		flecha_original.is_in_group("enemy_projectiles"),
		"El proyectil que vuela debe ser la flecha de la mano original"
	)
	assert_true(
		lonko.flecha_visual_mano != null and lonko.flecha_visual_mano != flecha_original,
		"Debe quedar una nueva flecha (distinta) preparada en la mano"
	)

	lonko.queue_free()
	await get_tree().process_frame


func test_lanzar_flecha_mano_sin_flecha_no_falla() -> void:
	# Arrange: caso límite sin referencia a flecha
	var lonko := await _crear_lonko()
	lonko.flecha_visual_mano = null

	# Act
	var arrow: Node3D = lonko._lanzar_flecha_mano()

	# Assert: retorno seguro sin errores
	assert_null(arrow, "Sin flecha en mano debe devolver null de forma segura")

	# Caso límite: nodo fuera del árbol
	lonko.flecha_visual_mano = Node3D.new()
	assert_null(lonko._lanzar_flecha_mano(), "Nodo fuera del árbol debe devolver null de forma segura")
	lonko.flecha_visual_mano.queue_free()

	lonko.queue_free()
	await get_tree().process_frame
