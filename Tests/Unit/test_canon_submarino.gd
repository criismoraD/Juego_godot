extends "res://addons/gut/test.gd"

## Tests del cañón del submarino (montado en la cubierta del SubmarinoRio).

var SubmarinoScene: PackedScene = preload("res://Levels/Rio_En_Canoa_Con_Parallax/SubmarinoRio.tscn")

var _root_test: Node3D = null


func before_each() -> void:
	_root_test = Node3D.new()
	_root_test.name = "RootTestCanonSubmarino"
	get_tree().root.add_child(_root_test)
	get_tree().current_scene = _root_test


func after_each() -> void:
	if is_instance_valid(_root_test):
		_root_test.free()
	for n in get_tree().root.get_children():
		if n is SubmarinoRio:
			n.free()


func _crear_submarino() -> SubmarinoRio:
	var submarino := SubmarinoScene.instantiate() as SubmarinoRio
	assert_not_null(submarino, "Debe instanciar SubmarinoRio")
	submarino.activar_al_entrar_en_camara = false
	_root_test.add_child(submarino)
	return submarino


## 1. El cañón debe existir bajo PivotFlotacion (hereda flotación y emersión)
func test_canon_existe_en_pivot_flotacion() -> void:
	# Arrange & Act
	var submarino := _crear_submarino()

	# Assert
	var canon := submarino.get_node_or_null("PivotFlotacion/CanonModel") as Node3D
	assert_not_null(canon, "Debe existir CanonModel bajo PivotFlotacion")
	assert_eq(canon.get_parent().name, "PivotFlotacion", "El cañón debe colgar de PivotFlotacion")


## 2. El cañón debe usar su textura difusa (_D) como override de superficie
func test_canon_usa_textura_propia() -> void:
	# Arrange & Act
	var submarino := _crear_submarino()
	var canon := submarino.get_node_or_null("PivotFlotacion/CanonModel") as Node3D
	assert_not_null(canon, "Debe existir CanonModel")

	# Assert: alguna malla con override que use la textura del cañón
	var con_textura := false
	for m in canon.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for s in range(mi.mesh.get_surface_count()):
			var mat := mi.get_surface_override_material(s) as StandardMaterial3D
			if mat and mat.albedo_texture and "cañon submarino_D" in mat.albedo_texture.resource_path:
				con_textura = true
				break
	assert_true(con_textura, "El cañón debe usar la textura cañon submarino_D.jpg")


## 3. El cañón debe estar sobre la cubierta (por encima del casco, centrado en Z)
func test_canon_posicionado_sobre_cubierta() -> void:
	# Arrange & Act
	var submarino := _crear_submarino()
	var canon := submarino.get_node_or_null("PivotFlotacion/CanonModel") as Node3D
	assert_not_null(canon, "Debe existir CanonModel")

	# Assert: sobre la cubierta (y ≈ 1.85) y centrado en Z
	assert_gt(canon.position.y, 1.5, "El cañón debe estar sobre la cubierta (y > 1.5)")
	assert_almost_eq(canon.position.z, 0.0, 0.01, "El cañón debe estar centrado en Z")
	assert_gt(canon.scale.x, 1.0, "El cañón debe estar escalado al tamaño del submarino")


func _acortar_secuencia_canon(submarino: SubmarinoRio) -> void:
	submarino.canon_tiempo_apuntado = 0.05
	submarino.canon_pausa_antes_disparo = 0.05
	submarino.canon_duracion_deformacion = 0.1
	submarino.canon_tiempo_regreso = 0.05


func _hay_ult_lonko_en_escena() -> bool:
	for n in get_tree().root.find_children("*", "FlechaElectricaAtaque", true, false):
		if is_instance_valid(n) and not n.is_queued_for_deletion():
			return true
	return false


## 4. Al morir los enemigos, el cañón dispara el ult antes de hundirse
func test_canon_dispara_ult_antes_de_hundirse() -> void:
	# Arrange
	var submarino := _crear_submarino()
	_acortar_secuencia_canon(submarino)
	submarino.canon_disparo_final = true
	for n in get_tree().root.find_children("*", "FlechaElectricaAtaque", true, false):
		n.free()

	# Act: todos los enemigos muertos -> despedida del cañón
	submarino._iniciar_sumersion()

	# Assert: entra a la secuencia en vez de hundirse directo
	assert_eq(submarino.current_state, SubmarinoRio.State.DISPARO_FINAL, "Debe entrar al disparo final del cañón")

	# Act: esperar la secuencia completa (~0.25s configurada)
	await get_tree().create_timer(1.0).timeout

	# Assert: disparó una vez, lanzó el ult de Lonko y luego se hunde normal
	assert_true(submarino._disparo_canon_realizado, "El cañón debe haber disparado su despedida")
	assert_true(_hay_ult_lonko_en_escena(), "Debe existir el ult de Lonko disparado desde el cañón")
	assert_eq(submarino.current_state, SubmarinoRio.State.SUMERGIENDOSE, "Tras disparar debe hundirse normalmente")


## 5. Tras la secuencia, el cañón regresa a su forma original
func test_canon_regresa_a_forma_original() -> void:
	# Arrange
	var submarino := _crear_submarino()
	_acortar_secuencia_canon(submarino)
	submarino.canon_disparo_final = true
	var canon := submarino.get_node_or_null("PivotFlotacion/CanonModel") as Node3D
	assert_not_null(canon, "Debe existir CanonModel")
	var rot_base: Vector3 = canon.rotation
	var escala_base: Vector3 = canon.scale

	# Act
	submarino._iniciar_sumersion()
	await get_tree().create_timer(1.0).timeout

	# Assert: rotación y escala restauradas a la base del editor
	assert_eq(submarino.current_state, SubmarinoRio.State.SUMERGIENDOSE, "Debe haber terminado la secuencia")
	assert_almost_eq((canon.rotation - rot_base).length(), 0.0, 0.05, "El cañón debe volver a su rotación base")
	assert_almost_eq((canon.scale - escala_base).length(), 0.0, 0.05, "El cañón debe volver a su escala base")


## 6. Con el disparo desactivado, se hunde directo como antes
func test_sin_canon_se_hunde_directo() -> void:
	# Arrange
	var submarino := _crear_submarino()
	submarino.canon_disparo_final = false

	# Act
	submarino._iniciar_sumersion()

	# Assert: sin despedida del cañón
	assert_eq(submarino.current_state, SubmarinoRio.State.SUMERGIENDOSE, "Sin cañón debe hundirse directo")
	assert_false(submarino._disparo_canon_realizado, "No debe haber disparo del cañón")


## 7. Al moverse el cañón suena el engranaje
func test_canon_reproduce_engranaje_al_apuntar() -> void:
	# Arrange
	var submarino := _crear_submarino()
	_acortar_secuencia_canon(submarino)
	submarino.canon_disparo_final = true

	# Act: inicia la despedida (eleva el cañón)
	submarino._iniciar_sumersion()

	# Assert: engranaje sonando durante el movimiento
	assert_not_null(_root_test.find_child("SfxCanonEngranaje", true, false), "Al elevar el cañón debe sonar el engranaje")


## 8. La boca deriva de la malla real (calza con la punta aunque se edite el modelo)
func test_boca_canon_calza_con_punta_de_la_malla() -> void:
	# Arrange
	var submarino := _crear_submarino()
	submarino.canon_lado_boca = -1.0
	submarino._actualizar_posicion_boca_canon()
	var canon := submarino.get_node_or_null("PivotFlotacion/CanonModel") as Node3D
	assert_not_null(canon, "Debe existir CanonModel")
	var boca := canon.get_node_or_null("BocaCanon") as Marker3D
	assert_not_null(boca, "Debe existir BocaCanon")
	var malla: MeshInstance3D = null
	for m in canon.find_children("*", "MeshInstance3D", true, false):
		if m is MeshInstance3D and (m as MeshInstance3D).mesh != null:
			malla = m as MeshInstance3D
			break
	assert_not_null(malla, "Debe haber malla del cañón")

	# Act: caja real de la malla en local del cañón
	var aabb: AABB = canon.global_transform.affine_inverse() * (malla.global_transform * malla.mesh.get_aabb())
	var boca_en_canon: Vector3 = canon.global_transform.affine_inverse() * boca.global_position

	# Assert: boca en o más allá de la punta -X, centrada en altura y profundidad
	assert_true(boca_en_canon.x <= aabb.position.x + 0.01, "La boca debe estar en la punta -X de la malla")
	assert_almost_eq(boca_en_canon.y, aabb.get_center().y, 0.01, "La boca debe calzar en altura con la malla")
	assert_almost_eq(boca_en_canon.z, aabb.get_center().z, 0.01, "La boca debe calzar en profundidad con la malla")
