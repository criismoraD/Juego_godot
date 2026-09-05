extends GutTest

const LONKO_SCENE: PackedScene = preload("res://Entities/Enemigo_Lonko/Lonko.tscn")

var scene_root: Node3D


func before_each() -> void:
	scene_root = Node3D.new()
	add_child(scene_root)


func after_each() -> void:
	if is_instance_valid(scene_root):
		scene_root.queue_free()
	await get_tree().process_frame


func test_lonko_initial_stats_and_attachments() -> void:
	# Arrange & Act
	var lonko := LONKO_SCENE.instantiate() as Lonko
	scene_root.add_child(lonko)
	await get_tree().process_frame

	# Assert
	assert_not_null(lonko, "La escena de Lonko debe instanciarse correctamente")
	assert_eq(lonko.vida_maxima, 6, "Lonko debe tener 6 de vida máxima")
	assert_eq(lonko.health, 6, "Lonko debe iniciar con 6 de vida")

	var bow = lonko.find_child("ARCO_GOBLING_GIRL", true, false)
	assert_not_null(bow, "Lonko debe tener equipado el arco ARCO_GOBLING_GIRL")

	var flecha_mano = lonko.find_child("FlechaMano", true, false)
	assert_not_null(flecha_mano, "Lonko debe tener el nodo FlechaMano en los attachments")

	lonko.queue_free()
	await get_tree().process_frame


func test_lonko_take_damage_and_death() -> void:
	# Arrange
	var lonko := LONKO_SCENE.instantiate() as Lonko
	scene_root.add_child(lonko)
	await get_tree().process_frame

	# Act: Aplicar daño parcial
	lonko.take_damage(2.0)

	# Assert: Reducción de vida
	assert_eq(lonko.health, 4, "Recibir 2 de daño debe reducir la vida a 4")

	# Act: Daño letal
	lonko.take_damage(4.0)

	# Assert: Muerte
	assert_eq(lonko.health, 0, "Daño letal debe dejar la vida en 0")
	assert_eq(lonko.current_state, Lonko.State.DYING, "El estado debe cambiar a DYING")

	lonko.queue_free()
	await get_tree().process_frame


func test_lonko_yaw_objetivo_segun_estado() -> void:
	# Arrange
	var lonko := LONKO_SCENE.instantiate() as Lonko
	scene_root.add_child(lonko)
	await get_tree().process_frame

	# Assert: estado base mira a la izquierda
	assert_eq(lonko._obtener_yaw_objetivo_grados(), -90.0, "Yaw base debe ser -90 (izquierda)")

	# Act: activar la secuencia del pilar (mayor prioridad)
	lonko._girando_hacia_fondo = true

	# Assert: durante el pilar debe mirar al fondo
	assert_eq(
		lonko._obtener_yaw_objetivo_grados(),
		180.0,
		"Durante el pilar debe mirar al fondo"
	)

	lonko.queue_free()
	await get_tree().process_frame


func test_lonko_flags_yaw_se_apagan_al_morir() -> void:
	# Arrange
	var lonko := LONKO_SCENE.instantiate() as Lonko
	scene_root.add_child(lonko)
	await get_tree().process_frame
	lonko._girando_hacia_fondo = true

	# Act: daño letal durante la secuencia del pilar
	lonko.take_damage(999.0)

	# Assert: muerte limpia el flag para no morir mirando al fondo
	assert_eq(lonko.current_state, Lonko.State.DYING, "Daño letal debe dejar el estado en DYING")
	assert_false(lonko._girando_hacia_fondo, "El giro hacia el fondo debe apagarse al morir")

	lonko.queue_free()
	await get_tree().process_frame


func test_lonko_modelo_mantiene_escala_positiva() -> void:
	# Arrange
	var lonko := LONKO_SCENE.instantiate() as Lonko
	scene_root.add_child(lonko)
	await get_tree().process_frame
	var escala_original_x: float = lonko._escala_original_modelo.x

	# Act: aplicar comprobación de espejo idle
	lonko._aplicar_espejo_idle()

	# Assert: escala X siempre positiva y sin alteración
	assert_gt(lonko._lonko_modelo.scale.x, 0.0, "La escala X debe mantenerse positiva")
	assert_eq(lonko._lonko_modelo.scale.x, escala_original_x, "La magnitud de escala X original se conserva")

	lonko.queue_free()
	await get_tree().process_frame



func test_lonko_debe_rastrear_jugador_gate() -> void:
	# Arrange
	var lonko := LONKO_SCENE.instantiate() as Lonko
	scene_root.add_child(lonko)
	await get_tree().process_frame

	# Assert: caminando no rastrea
	assert_false(lonko._debe_rastrear_jugador(), "En WALKING no debe rastrear")

	# Act & Assert: disparo normal rastrea
	lonko.current_state = Lonko.State.SHOOTING
	lonko.rastrear_jugador = true
	lonko._is_invulnerable = false
	assert_true(lonko._debe_rastrear_jugador(), "En SHOOTING con tracking activo debe rastrear")

	# Act & Assert (regresión del bug del especial): apuntar arriba gana a la invulnerabilidad
	lonko._is_invulnerable = true
	lonko._apuntar_arriba = true
	assert_true(
		lonko._debe_rastrear_jugador(),
		"Con _apuntar_arriba debe rastrear aunque esté invulnerable (apuntado al cielo)"
	)

	# Boundary: el daño interrumpe incluso el apuntado al cielo
	lonko._is_taking_damage = true
	assert_false(lonko._debe_rastrear_jugador(), "Recibiendo daño no debe rastrear")
	lonko._is_taking_damage = false
	assert_true(lonko._debe_rastrear_jugador(), "Tras recuperar control vuelve a rastrear al cielo")

	# Boundary: debug override tiene máxima prioridad
	lonko.current_state = Lonko.State.WALKING
	lonko.debug_tracking_override = true
	assert_true(lonko._debe_rastrear_jugador(), "El override de debug fuerza el tracking")

	# Boundary: sin tracking de jugador no rastrea
	lonko.debug_tracking_override = false
	lonko._apuntar_arriba = false
	lonko._is_invulnerable = false
	lonko.rastrear_jugador = false
	lonko.current_state = Lonko.State.SHOOTING
	assert_false(lonko._debe_rastrear_jugador(), "Sin rastrear_jugador no debe rastrear")

	lonko.queue_free()
	await get_tree().process_frame


func test_lonko_tiro_electrico_cada_3() -> void:
	# Arrange
	var lonko := LONKO_SCENE.instantiate() as Lonko
	scene_root.add_child(lonko)
	await get_tree().process_frame
	lonko.cada_cuantos_tiros_electrico = 3

	# Act & Assert: los tiros 1 y 2 son normales, el 3 y el 6 son eléctricos
	assert_false(lonko._es_tiro_electrico(1), "Tiro 1 no debe ser eléctrico")
	assert_false(lonko._es_tiro_electrico(2), "Tiro 2 no debe ser eléctrico")
	assert_true(lonko._es_tiro_electrico(3), "Tiro 3 debe ser eléctrico")
	assert_false(lonko._es_tiro_electrico(4), "Tiro 4 no debe ser eléctrico")
	assert_true(lonko._es_tiro_electrico(6), "Tiro 6 debe ser eléctrico")

	# Boundary: valores inválidos nunca eléctricos
	assert_false(lonko._es_tiro_electrico(0), "Tiro 0 (inválido) no debe ser eléctrico")
	assert_false(lonko._es_tiro_electrico(-3), "Tiro negativo no debe ser eléctrico")

	# Boundary: cada_cuantos_tiros_electrico inválido desactiva el ataque
	lonko.cada_cuantos_tiros_electrico = 0
	assert_false(lonko._es_tiro_electrico(3), "Con cadencia 0 el ataque eléctrico queda desactivado")

	lonko.queue_free()
	await get_tree().process_frame


func test_humo_pisadas_usa_spritesheet_smokefx() -> void:
	# Arrange
	var lonko := LONKO_SCENE.instantiate() as Lonko
	scene_root.add_child(lonko)
	await get_tree().process_frame

	# Act
	var particulas := lonko.find_child("Particulas_Pisada", true, false) as GPUParticles3D

	# Assert: el humo usa el spritesheet SmokeFX Lite 9x1
	assert_not_null(particulas, "Lonko debe tener el nodo Particulas_Pisada")
	if particulas:
		var quad := particulas.draw_pass_1 as QuadMesh
		assert_not_null(quad, "El draw pass debe ser un QuadMesh")
		if quad and quad.material is StandardMaterial3D:
			var mat := quad.material as StandardMaterial3D
			assert_eq(mat.particles_anim_h_frames, 9, "El spritesheet debe tener 9 cuadros horizontales")
			assert_eq(mat.particles_anim_v_frames, 1, "El spritesheet debe tener 1 fila vertical")
			assert_false(mat.particles_anim_loop, "La animación del humo no debe iterar")

	lonko.queue_free()
	await get_tree().process_frame


func test_lonko_offset_z_pilar_posiciona_en_primer_plano() -> void:
	# Arrange
	var lonko := LONKO_SCENE.instantiate() as Lonko
	scene_root.add_child(lonko)
	lonko.global_position = Vector3(2.0, 0.2, 0.0)
	await get_tree().process_frame

	# Assert: valor por defecto de offset_z_pilar
	assert_eq(lonko.offset_z_pilar, 0.45, "offset_z_pilar por defecto debe ser 0.45 para emerger en primer plano")

	# Act: Iniciar secuencia del pilar
	lonko._iniciar_secuencia_pilar()
	await get_tree().process_frame

	# Assert: _base_pos_pilar.z debe estar desplazada en Z frontal
	assert_almost_eq(lonko._base_pos_pilar.z, 0.45, 0.01, "La posición base Z debe incorporar offset_z_pilar")
	assert_not_null(lonko._instancia_pilar, "El pilar debe haberse instanciado")
	if lonko._instancia_pilar:
		assert_almost_eq(
			lonko._instancia_pilar.global_position.z,
			0.45,
			0.01,
			"La instancia del pilar debe situarse en Z = 0.45 (primer plano)"
		)

	lonko.queue_free()
	await get_tree().process_frame


func test_lonko_y_pilar_colisiones_profundidad_2_5d() -> void:
	# Arrange
	var lonko := LONKO_SCENE.instantiate() as Lonko
	scene_root.add_child(lonko)
	await get_tree().process_frame

	# Assert 1: Lonko tiene BoxShape3D con profundidad amplia en Z
	var col_lonko := lonko.find_child("CollisionShape3D", true, false) as CollisionShape3D
	assert_not_null(col_lonko, "Lonko debe poseer CollisionShape3D")
	if col_lonko and col_lonko.shape is BoxShape3D:
		var box := col_lonko.shape as BoxShape3D
		assert_gt(box.size.z, 1.5, "La profundidad Z del colisionador de Lonko debe ser >= 1.5m para garantizar impactos en 2.5D")

	# Assert 2: PilarLonko tiene colisionador que abarca holgadamente el plano Z = 0.05
	var pilar_scene := load("res://Entities/Enemigo_Lonko/PilarLonko.tscn").instantiate() as Node3D
	scene_root.add_child(pilar_scene)
	pilar_scene.scale = Vector3(3.0, 3.0, 3.0)
	pilar_scene.global_position = Vector3(0.0, 0.0, 0.45)
	await get_tree().process_frame

	var pilar_body := pilar_scene.find_child("PilarBody", true, false) as StaticBody3D
	assert_not_null(pilar_body, "PilarLonko debe contener PilarBody")
	if pilar_body:
		var pcol := pilar_body.find_child("CollisionShape3D", true, false) as CollisionShape3D
		assert_not_null(pcol, "PilarBody debe contener CollisionShape3D")
		if pcol and pcol.shape is BoxShape3D:
			var pbox := pcol.shape as BoxShape3D
			var global_depth_z: float = pbox.size.z * pilar_scene.scale.z
			assert_gt(global_depth_z, 2.0, "La profundidad Z escalada del pilar debe ser >= 2.0m")

	pilar_scene.queue_free()
	lonko.queue_free()
	await get_tree().process_frame

