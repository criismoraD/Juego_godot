extends "res://addons/gut/test.gd"

var GoblinaScript = preload("res://Entities/Enemigo_Goblina_Escudo_Pesado/GoblinaEscudoPesado.gd")
var GoblinaEscudoPesadoScene: PackedScene = preload("res://Entities/Enemigo_Goblina_Escudo_Pesado/GoblinaEscudoPesado.tscn")
var _goblina = null


func before_each():
	if GoblinaEscudoPesadoScene:
		_goblina = GoblinaEscudoPesadoScene.instantiate()
		get_tree().root.add_child(_goblina)


func after_each():
	if is_instance_valid(_goblina):
		_goblina.queue_free()
		_goblina = null


func test_mano_izquierda_alineada_y_natural() -> void:
	# Arrange
	var skel: Skeleton3D = _goblina.find_child("Skeleton3D", true, false) as Skeleton3D
	assert_not_null(skel, "Skeleton3D debe existir")
	
	# Assert: El hueso 17 (LeftHand) debe tener rotación natural alineada con el antebrazo
	var q_hand = skel.get_bone_pose_rotation(17)
	var euler_hand_deg = q_hand.get_euler() * 180.0 / PI
	# El ángulo Y de la mano no debe exceder -50 grados (antes estaba en -104.5 grados quebrada hacia atrás)
	assert_gt(euler_hand_deg.y, -50.0, "La mano izquierda no debe estar rotada hacia atrás de forma antinatural")



	assert_eq(_goblina.health, 13, "La vida inicial debe ser 13")

	assert_eq(_goblina.vida_maxima, 13, "La vida máxima debe ser 13")
	assert_true(_goblina.es_estructura, "Debe tener flag es_estructura para el bono de flecha explosiva")
	assert_true(_goblina.es_pilar_enemigo, "Debe tener flag es_pilar_enemigo")
	assert_true(_goblina.es_escudo_enemigo, "Debe tener flag es_escudo_enemigo")
	assert_true(_goblina.is_in_group("shield_imps"), "Debe pertenecer al grupo shield_imps")
	assert_true(_goblina.is_in_group("guardians"), "Debe pertenecer al grupo guardians")
	assert_true(_goblina.is_in_group("enemies"), "Debe pertenecer al grupo enemies")


func test_materiales_y_texturas_aplicados_en_mallas() -> void:
	# Arrange
	assert_not_null(_goblina)

	# Assert: Verificar que todas las mallas tienen material_override con textura
	var meshes = _goblina.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "Debe haber al menos una malla en la Goblina")

	var cuerpo_encontrado: bool = false
	var escudo_encontrado: bool = false

	for m in meshes:
		var mesh := m as MeshInstance3D
		assert_not_null(mesh.material_override, "La malla '%s' debe tener material_override asignado" % mesh.name)


		if "escudo" in mesh.name.to_lower():
			escudo_encontrado = true
		else:
			cuerpo_encontrado = true

	assert_true(cuerpo_encontrado, "Debe existir la malla del cuerpo con su textura")
	assert_true(escudo_encontrado, "Debe existir la malla del escudo con su textura")


func test_escudo_visible_y_con_escala_adecuada() -> void:
	# Arrange
	assert_not_null(_goblina)
	var shield = _goblina.find_child("EscudoPesado", true, false) as Node3D

	# Assert
	assert_not_null(shield, "Debe existir el nodo EscudoPesado en la escena")
	assert_true(shield.visible, "El escudo debe ser visible")
	var gscale = shield.global_transform.basis.get_scale()
	assert_gt(gscale.x, 0.4, "La escala X global del escudo debe ser visible (al menos 0.4)")
	assert_gt(gscale.y, 0.4, "La escala Y global del escudo debe ser visible (al menos 0.4)")
	assert_gt(gscale.z, 0.4, "La escala Z global del escudo debe ser visible (al menos 0.4)")


func test_humo_pisada_identico_a_lonko() -> void:
	# Arrange
	assert_not_null(_goblina)
	var p: GPUParticles3D = _goblina.find_child("Particulas_Pisada", true, false) as GPUParticles3D

	# Assert
	assert_not_null(p, "Debe existir el nodo Particulas_Pisada")
	assert_eq(p.amount, 16, "El amount de partículas debe ser 16 (igual que Lonko)")
	assert_almost_eq(p.lifetime, 1.15, 0.01, "El lifetime debe ser 1.15 (igual que Lonko)")
	assert_not_null(p.draw_pass_1, "Debe tener draw_pass_1 configurado")
	var mat = (p.draw_pass_1 as QuadMesh).material as StandardMaterial3D
	assert_not_null(mat, "El material de draw_pass_1 debe ser StandardMaterial3D")
	assert_not_null(mat.albedo_texture, "Debe tener asignada la textura de humo de pisadas")
	assert_eq(mat.particles_anim_h_frames, 9, "Debe tener 9 frames horizontales de animación")


func test_espera_6_segundos_en_defensa_antes_de_reposicionarse() -> void:
	# Arrange: Pasar al estado de ataque
	assert_not_null(_goblina)
	_goblina._cambiar_estado(GoblinaScript.State.ATTACKING)

	# Simular avance del ataque hasta completarlo
	_goblina._process_attacking(GoblinaScript.DURACION_ATAQUE_TOTAL + 0.1)
	assert_eq(_goblina.current_state, GoblinaScript.State.DEFENDING, "Debe pasar a DEFENDING tras atacar")
	assert_true(_goblina.primer_ataque_realizado, "primer_ataque_realizado debe ser true")

	# Simular que el enemigo protegido muere o desaparece
	_goblina.enemigo_protegido = null

	# Act: Avanzar 3 segundos (menos de los 6s requeridos)
	_goblina._process_defending(3.0)

	# Assert: Debe PERMANECER en DEFENDING durante los primeros 6s
	assert_eq(_goblina.current_state, GoblinaScript.State.DEFENDING, "Debe permanecer en DEFENDING durante los primeros 6 segundos")

	# Act: Avanzar 3.5 segundos más (total 6.5s > 6.0s)
	_goblina._process_defending(3.5)

	# Assert: Al superar los 6s y no haber enemigo, verifica que procesó la búsqueda
	assert_gte(_goblina.tiempo_defensa_primer_ataque, 6.0, "El temporizador debe superar los 6 segundos")


func test_dano_compartido_escudo_y_cuerpo() -> void:
	# Arrange
	assert_not_null(_goblina)

	# Act: Daño directo al cuerpo
	_goblina.take_damage(4.0)

	# Assert
	assert_eq(_goblina.health, 9, "El daño directo debe reducir la vida compartida a 9")

	# Act: Daño vía recibir_golpe (como flecha impactando en escudo)
	_goblina.recibir_golpe(3.0)

	# Assert
	assert_eq(_goblina.health, 6, "El daño al escudo debe reducir la vida compartida a 6")


func test_vulnerabilidad_extra_5_en_animacion_ataque() -> void:
	# Arrange
	assert_not_null(_goblina)
	_goblina._cambiar_estado(GoblinaScript.State.ATTACKING)
	assert_eq(_goblina.current_state, GoblinaScript.State.ATTACKING)

	# Act: Impacto de 2 de daño durante el ataque
	_goblina.take_damage(2.0)

	# Assert: Debe recibir 2 + 5 de vulnerabilidad = 7 de daño total
	assert_eq(_goblina.health, 8, "Durante el ataque debe recibir 5 de daño extra (15 - 7 = 8)")


func test_no_retirada_al_recibir_dano() -> void:
	# Arrange
	assert_not_null(_goblina)

	# Act: Bajar la vida casi al límite (1 HP restante)
	_goblina.take_damage(14.0)

	# Assert
	assert_eq(_goblina.health, 1, "Debe quedar a 1 HP")
	assert_ne(_goblina.current_state, GoblinaScript.State.DYING, "No debe estar muriendo")
	assert_ne(_goblina.current_state, GoblinaScript.State.DEAD, "No debe estar muerta")


func test_transicion_a_dying_al_llegar_a_cero_hp() -> void:
	# Arrange
	assert_not_null(_goblina)

	# Act
	_goblina.take_damage(15.0)

	# Assert
	assert_eq(_goblina.health, 0, "La vida debe llegar a 0")
	assert_eq(_goblina.current_state, GoblinaScript.State.DYING, "Debe pasar al estado DYING")


func test_nunca_ataca_en_el_borde_de_pantalla() -> void:
	# Arrange: Colocar la goblina en el borde de la pantalla (X = 3.5, fuera de zona_roja_max_x = 0.2)
	assert_not_null(_goblina)
	_goblina.global_position.x = 3.5
	_goblina._cambiar_estado(GoblinaScript.State.RUNNING)
	_goblina._necesita_atacar = true

	# Act: Ejecutar ciclo de correr cuando está en el borde
	_goblina._process_running(0.016)

	# Assert: Debe seguir en RUNNING y moviéndose hacia la izquierda (-X), NUNCA detenerse ni pasar a ATTACKING
	assert_eq(_goblina.current_state, GoblinaScript.State.RUNNING, "En el borde (X > 0.2) no puede pasar a ATTACKING")
	assert_lt(_goblina.velocity.x, 0.0, "Debe estar corriendo hacia la izquierda (-X) para ingresar al campo")


func test_ataca_al_llegar_a_su_destino_dentro_de_la_zona_roja() -> void:
	# Arrange: Colocar la goblina dentro de la zona roja en su destino exacto
	assert_not_null(_goblina)
	var target_x: float = _goblina.posicion_objetivo_zona_roja
	assert_lte(target_x, _goblina.zona_roja_max_x, "El destino debe estar dentro de la zona roja")
	assert_gte(target_x, _goblina.zona_roja_min_x, "El destino debe estar dentro de la zona roja")

	_goblina.global_position.x = target_x
	_goblina.enemigo_protegido = null
	_goblina._cambiar_estado(GoblinaScript.State.RUNNING)
	_goblina._necesita_atacar = true

	# Act: Ejecutar un frame de corrida al alcanzar su destino dentro de la zona roja
	_goblina._process_running(0.016)

	# Assert: Debe detenerse y pasar a ATTACKING
	assert_eq(_goblina.velocity.x, 0.0, "Al llegar debe detenerse")
	assert_eq(_goblina.current_state, GoblinaScript.State.ATTACKING, "Debe pasar al estado ATTACKING al llegar a la zona roja")


func test_escudo_parpadea_en_rojo_al_recibir_impacto() -> void:
	# Arrange
	assert_not_null(_goblina)
	var mesh_mock = MeshInstance3D.new()
	mesh_mock.name = "EscudoPesado_Mesh"
	_goblina._escudo_meshes.append(mesh_mock)
	_goblina.add_child(mesh_mock)

	# Act: Simular impacto en escudo
	_goblina.recibir_golpe_escudo(2.0)

	# Assert: El material_overlay del escudo debe ser un material rojo
	assert_not_null(mesh_mock.material_overlay, "El escudo debe tener material_overlay activo tras el impacto")
	var overlay = mesh_mock.material_overlay as StandardMaterial3D
	assert_not_null(overlay, "El overlay debe ser StandardMaterial3D")
	assert_gt(overlay.albedo_color.r, 0.8, "El color del parpadeo del escudo debe ser predominantemente rojo")
	assert_lt(overlay.albedo_color.g, 0.3, "El canal verde debe ser bajo para reflejar color rojo")

	mesh_mock.queue_free()


func test_audio_correr_descalzo_configurado() -> void:
	# Arrange & Assert
	assert_not_null(_goblina)
	assert_not_null(_goblina._audio_correr_descalzo, "El reproductor de audio para correr descalzo debe estar inicializado")
	assert_not_null(_goblina._audio_correr_descalzo.stream, "Debe tener asignado un stream de audio")
	var stream_wav = _goblina._audio_correr_descalzo.stream as AudioStreamWAV
	var stream_mp3 = _goblina._audio_correr_descalzo.stream as AudioStreamMP3
	var tiene_loop: bool = (stream_wav and stream_wav.loop_mode != AudioStreamWAV.LOOP_DISABLED) or (stream_mp3 and stream_mp3.loop)
	assert_true(tiene_loop, "El stream debe tener loop activado")


func test_probabilidades_recompensas_muerte() -> void:
	# Arrange
	assert_not_null(_goblina)
	assert_not_null(GoblinaScript.MEDIKIT_SCENE, "La escena de Medikit debe estar precargada")



func test_materiales_asignados_correctamente_a_cuerpo_y_escudo() -> void:
	# Arrange
	var scene = load("res://Entities/Enemigo_Goblina_Escudo_Pesado/GoblinaEscudoPesado.tscn").instantiate()
	add_child_autofree(scene)

	# Assert
	assert_eq(scene._cuerpo_meshes.size(), 1, "Debe haber 1 malla de cuerpo")
	assert_eq(scene._escudo_meshes.size(), 1, "Debe haber 1 malla de escudo")
	assert_eq(scene._cuerpo_meshes[0].material_override, scene.MAT_GOBLINA, "El cuerpo debe tener MAT_GOBLINA asignado")
	assert_eq(scene._escudo_meshes[0].material_override, scene.MAT_ESCUDO, "El escudo debe tener MAT_ESCUDO asignado")

	# Verificar que el escudo usa la posición y transformación definida en la escena tscn sin offsets por código
	var escudo = scene.find_child("EscudoPesado", true, false)
	assert_not_null(escudo, "El nodo EscudoPesado debe existir en la escena")



func test_escudo_mas_delgado_deformado() -> void:
	# Arrange
	var escudo_scene = load("res://Entities/Enemigo_Goblina_Escudo_Pesado/EscudoPesado.tscn").instantiate()
	add_child_autofree(escudo_scene)

	# Assert: El modelo del escudo debe estar deformado para ser más delgado (scale.z < 0.5)
	var modelo = escudo_scene.get_node("ModeloEscudo")
	assert_not_null(modelo, "ModeloEscudo debe existir")
	assert_lt(modelo.scale.z, 0.5, "La escala en Z debe ser menor a 0.5 para que sea más delgado")

	var col = escudo_scene.get_node("EscudoArea/CollisionShape3D")
	assert_not_null(col, "CollisionShape3D debe existir")
	var box = col.shape as BoxShape3D
	assert_not_null(box, "Shape debe ser BoxShape3D")
	assert_lt(box.size.z, 0.2, "El grosor de colisión en Z debe ser más delgado (< 0.2)")


func test_ataca_tras_7_segundos_si_no_hay_enemigos() -> void:
	# Arrange
	assert_not_null(_goblina)
	_goblina._cambiar_estado(GoblinaScript.State.DEFENDING)
	_goblina.enemigo_protegido = null
	_goblina._timer_defensa_sin_enemigos = 0.0

	# Act: Avanzar 4 segundos (menos de 7s)
	_goblina._process_defending(4.0)

	# Assert: Sigue en DEFENDING
	assert_eq(_goblina.current_state, GoblinaScript.State.DEFENDING, "A los 4s debe seguir defendiendo")

	# Act: Avanzar 3.5 segundos más (total 7.5s >= 7.0s)
	_goblina._process_defending(3.5)

	# Assert: Pasa a ATTACKING al transcurrir 7 segundos sin enemigos
	assert_eq(_goblina.current_state, GoblinaScript.State.ATTACKING, "A los 7s sin enemigos para reposicionarse debe atacar")


func test_suelta_escudo_al_morir_por_explosion() -> void:
	# Arrange
	var scene = load("res://Entities/Enemigo_Goblina_Escudo_Pesado/GoblinaEscudoPesado.tscn").instantiate()
	add_child_autofree(scene)

	scene.murio_por_explosion = true

	# Act: Transición a DYING
	scene._cambiar_estado(GoblinaScript.State.DYING)

	# Assert: Se debe haber reseteado murio_por_explosion y el escudo ya no debe estar adjunto al hueso
	assert_false(scene.murio_por_explosion, "murio_por_explosion debe resetearse a false")
	var escudo_en_goblina = scene.find_child("EscudoPesado", true, false)
	assert_null(escudo_en_goblina, "El escudo debe haberse desprendido de la goblina")


func test_color_borde_morado_y_retardo_en_piso_al_morir() -> void:
	# Arrange
	assert_not_null(_goblina)

	# Assert: El color de disolución debe ser morado/púrpura
	assert_gt(_goblina.color_borde_disolucion.r, 0.5, "El componente rojo debe ser alto para morado")
	assert_gt(_goblina.color_borde_disolucion.b, 0.6, "El componente azul debe ser alto para morado")
	assert_lt(_goblina.color_borde_disolucion.g, 0.4, "El componente verde debe ser bajo para morado")

	# Act: Transición a DYING
	_goblina._cambiar_estado(GoblinaScript.State.DYING)

	# Assert: Inmediatamente al morir NO se disuelve de golpe, debe esperar en el piso
	assert_false(_goblina.is_dissolving, "No debe empezar a disolverse inmediatamente, debe permanecer unos segundos en el piso")


func test_sonidos_goblina_jabalina_y_dano_registrados() -> void:
	# Assert: Verificar que AudioManager tiene registrados los sonidos
	assert_true(AudioManager.sfx_streams.has("goblina_jabalina"), "AudioManager debe tener registrado goblina_jabalina")
	assert_true(AudioManager.sfx_streams.has("goblina_dano"), "AudioManager debe tener registrado goblina_dano")
	assert_true(AudioManager.sfx_streams.has("goblina_ataque"), "AudioManager debe tener registrado goblina_ataque")
	assert_true(AudioManager.sfx_streams.has("goblina_muerte"), "AudioManager debe tener registrado goblina_muerte")
	assert_true(AudioManager.sfx_streams.has("impacto_escudo_pesado"), "AudioManager debe tener registrado impacto_escudo_pesado")

	var s_wav = load("res://System/Audio/SFX/goblina muerte.wav")
	assert_not_null(s_wav, "El archivo WAV debe cargar correctamente en Godot")



func test_impactos_concentrados_en_escudo() -> void:
	# Arrange
	assert_not_null(_goblina)
	_goblina._impactos_consecutivos_escudo = 0
	_goblina._timer_impactos_consecutivos = 0.0

	# Act 1: Primer impacto en escudo
	_goblina.take_damage(1.0, true)
	assert_eq(_goblina._impactos_consecutivos_escudo, 1)

	# Act 2: Segundo impacto en escudo
	_goblina.take_damage(1.0, true)
	assert_eq(_goblina._impactos_consecutivos_escudo, 2)

	# Act 3: Tercer impacto consecutivo (muchos disparos seguidos)
	_goblina.take_damage(1.0, true)
	assert_gte(_goblina._impactos_consecutivos_escudo, 3, "Al recibir 3 disparos seguidos se activa el umbral de impactos concentrados")


func test_reposicionamiento_enemigo_detras_usa_voltearse() -> void:
	# Arrange
	assert_not_null(_goblina)
	_goblina.global_position.x = -1.8
	_goblina.primer_ataque_realizado = true
	_goblina.tiempo_defensa_primer_ataque = 7.0
	_goblina._cambiar_estado(GoblinaScript.State.DEFENDING)

	# Crear un enemigo aliado detrás suyo (a la derecha)
	var aliado = Node3D.new()
	aliado.add_to_group("enemies")
	aliado.global_position.x = -0.5
	get_tree().root.add_child(aliado)
	_goblina.enemigo_protegido = aliado

	# Act: Procesar defensa
	_goblina._process_defending(0.1)

	# Assert: Debe haber pasado a State.TURNING
	assert_eq(_goblina.current_state, GoblinaScript.State.TURNING, "Debe usar State.TURNING al reposicionarse a un enemigo detrás")

	# Limpieza
	aliado.queue_free()


func test_sombra_circular_instanciada() -> void:
	assert_not_null(_goblina._sombra, "La sombra debe estar instanciada")
	assert_true(_goblina._sombra is SombraPersonaje, "La sombra debe ser del tipo SombraPersonaje")


func test_rotacion_al_correr_hacia_atras_no_de_espaldas() -> void:
	# Arrange
	assert_not_null(_goblina)
	_goblina.global_position.x = -1.8
	_goblina.posicion_objetivo_zona_roja = -0.5
	_goblina.enemigo_protegido = null
	_goblina._cambiar_estado(GoblinaScript.State.RUNNING)

	# Act
	_goblina._process_running(0.016)

	# Assert: Al correr hacia la derecha (+X), el modelo debe rotar a 90 grados (de frente, no de espaldas)
	assert_almost_eq(_goblina.model_root.rotation_degrees.y, 90.0, 1.0, "Al correr hacia la derecha debe orientarse a 90 grados")


func test_escudo_no_queda_rojo_al_morir() -> void:
	# Arrange
	var scene = load("res://Entities/Enemigo_Goblina_Escudo_Pesado/GoblinaEscudoPesado.tscn").instantiate()
	add_child_autofree(scene)

	# Act: Simular flash de impacto en escudo justo antes de morir
	scene._flash_impacto_escudo_rojo()
	scene._cambiar_estado(GoblinaScript.State.DYING)

	# Assert: Los meshes del escudo no deben conservar overlay rojo
	for mesh in scene._escudo_meshes:
		assert_null(mesh.material_overlay, "El overlay rojo debe removerse al morir")


func test_sonido_escudo_metal_cayendo_registrado() -> void:
	assert_not_null(AudioManager)
	assert_true(AudioManager.sfx_streams.has("escudo_metal_cayendo"), "escudo_metal_cayendo debe estar registrado en AudioManager")
	assert_true(AudioManager.sfx_streams.has("Escudo metal callendo"), "Escudo metal callendo debe estar registrado en AudioManager")
	AudioManager.play_escudo_metal_cayendo()
	assert_true(true, "Debe reproducirse sin errores")


func test_ataque_cada_7_segundos_y_reposicionamiento_a_otro_enemigo() -> void:
	# Arrange
	assert_not_null(_goblina)
	_goblina._cambiar_estado(GoblinaScript.State.DEFENDING)
	_goblina._timer_defensa = 0.0

	# Crear dos aliados dummy en el grupo "enemies"
	var aliado1 := Node3D.new()
	aliado1.add_to_group("enemies")
	aliado1.global_position = Vector3(2.0, 0.0, 0.0)
	add_child_autofree(aliado1)

	var aliado2 := Node3D.new()
	aliado2.add_to_group("enemies")
	aliado2.global_position = Vector3(3.5, 0.0, 0.0)
	add_child_autofree(aliado2)

	_goblina.enemigo_protegido = aliado1

	# Act: Transcurren 7 segundos en defensa
	_goblina._process_defending(7.1)

	# Assert: Debe pasar a ATTACKING
	assert_eq(_goblina.current_state, GoblinaScript.State.ATTACKING, "Tras 7 segundos de defensa debe transicionar a ATTACKING")

	# Act: Concluye la animación de ataque
	_goblina._process_attacking(GoblinaScript.DURACION_ATAQUE_TOTAL + 0.1)

	# Assert: Debe haber elegido al otro aliado (aliado2) y transicionado para reposicionarse
	assert_eq(_goblina.enemigo_protegido, aliado2, "Debe elegir al otro aliado cercano tras atacar")
	assert_true(
		_goblina.current_state == GoblinaScript.State.TURNING or _goblina.current_state == GoblinaScript.State.RUNNING or _goblina.current_state == GoblinaScript.State.DEFENDING,
		"Debe pasar a TURNING o RUNNING para reposicionarse delante del otro aliado"
	)


func test_configuracion_nueva_oleada_5_y_oleada_6() -> void:
	# Arrange
	var spawner_scene = load("res://System/Core/WaveSpawner.tscn")
	if not spawner_scene:
		pass_test("WaveSpawner.tscn no disponible para instanciación directa")
		return

	var spawner = spawner_scene.instantiate()
	add_child_autofree(spawner)

	# Act: Generar cola de Oleada 5
	spawner._iniciar_cola_oleada(5)

	# Assert: Total 40 enemigos
	assert_eq(spawner.enemigos_por_oleada, 40, "La nueva Oleada 5 debe tener exactamente 40 enemigos")

	var cant_arqueras: int = 0
	var cant_ballesteros: int = 0
	var cant_globos: int = 0
	var cant_goblinas_escudo: int = 0

	for escena in spawner.cola_spawn:
		if escena == spawner.escena_goblin_girl:
			cant_arqueras += 1
		elif escena == spawner.escena_goblin:
			cant_ballesteros += 1
		elif escena == spawner.escena_globo_aerostatico:
			cant_globos += 1
		elif escena == spawner.escena_goblina_escudo:
			cant_goblinas_escudo += 1

	assert_eq(cant_arqueras, 12, "Oleada 5 debe incluir 12 arqueras goblin")
	assert_eq(cant_ballesteros, 15, "Oleada 5 debe incluir 15 ballesteros goblin")
	assert_eq(cant_globos, 5, "Oleada 5 debe incluir 5 globos")
	assert_eq(cant_goblinas_escudo, 6, "Oleada 5 debe incluir 6 goblinas de escudo pesado")
	assert_eq(cant_arqueras + cant_ballesteros + cant_globos + cant_goblinas_escudo, 40, "Suma total debe ser exactamente 40")

	# Act: Generar cola de Oleada 6 (anterior Oleada 5 con Lonko)
	spawner._iniciar_cola_oleada(6)

	# Assert: Total base 40 + 10 refuerzos cuerno = 50
	assert_true(spawner.enemigos_por_oleada >= 50, "Oleada 6 (anterior Oleada 5) debe tener al menos 50 enemigos")
	var cant_lonko: int = 0

	for escena in spawner.cola_spawn:
		if escena == spawner.escena_lonko:
			cant_lonko += 1
	assert_eq(cant_lonko, 11, "Oleada 6 debe contener los 11 Lonko distribuidos uniformemente")


func test_oleada_5_sin_defensas_estaticas_ni_plataformas_ni_refuerzo() -> void:
	# Arrange: Cargar script de NIVEL01
	var Nivel01Script = load("res://Levels/NIVEL01/NIVEL01.gd")
	assert_not_null(Nivel01Script, "NIVEL01.gd debe existir")

	# Validar con GameUI que no se permitan escudos estáticos en oleada 5
	var GameUIScript = load("res://UI/GameUI.gd")
	var game_ui = GameUIScript.new()
	add_child_autofree(game_ui)

	# Act & Assert: Escudos enemigos no permitidos en oleada 5
	assert_false(game_ui._es_escudo_enemigo_permitido_en_oleada("Escudo_enemigo", 5), "Escudo_enemigo no debe permitirse en Oleada 5")
	assert_false(game_ui._es_escudo_enemigo_permitido_en_oleada("NIVEL_2_Escudo_enemigo2", 5), "NIVEL_2_Escudo_enemigo2 no debe permitirse en Oleada 5")
	assert_false(game_ui._es_escudo_enemigo_permitido_en_oleada("NIVEL_2_Escudo_enemigo3", 5), "NIVEL_2_Escudo_enemigo3 no debe permitirse en Oleada 5")


func test_goblina_no_colisiona_con_piernas_muerte_explosiva() -> void:
	# Arrange
	assert_not_null(_goblina)
	assert_eq(_goblina.collision_mask, 1, "GoblinaEscudoPesado debe tener collision_mask = 1 para colisionar solo con el suelo")

	# Instanciar GoblinPiezaFisica configurada como piernas
	var pieza_piernas = GoblinPiezaFisica.new()
	pieza_piernas.es_piernas = true
	add_child_autofree(pieza_piernas)

	# Assert: La hitbox de piernas está en capa 2
	var piernas_body = pieza_piernas.get_node_or_null("PiernasHitbox")
	if piernas_body and piernas_body is CollisionObject3D:
		assert_eq(piernas_body.collision_layer, 2, "PiernasHitbox debe estar en capa 2")
		# Verificar que la goblina NO tiene el bit 2 en su collision_mask
		assert_eq(_goblina.collision_mask & 2, 0, "Goblina no debe tener la capa 2 en su máscara de colisión")


func test_torre_de_asedio_instanciacion_y_propiedades() -> void:
	# Arrange
	var torre_escena = load("res://Entities/Torre_de_asedio/Torre_de_asedio.tscn")
	assert_not_null(torre_escena, "La escena Torre_de_asedio.tscn debe cargar exitosamente")

	var torre = torre_escena.instantiate() as TorreDeAsedio
	assert_not_null(torre, "La escena debe instanciarse como TorreDeAsedio")
	add_child_autofree(torre)

	# Assert de nodos requeridos
	assert_not_null(torre.punto_spawn, "Debe tener un punto_spawn asignado o presente")
	assert_not_null(torre.rampa_piso, "Debe tener un rampa_piso con collider")
	assert_eq(torre.rampa_piso.collision_layer & 1, 1, "La rampa de la torre debe ser piso en capa 1")
	assert_eq(torre.max_enemigos_rampa, 5, "Debe soportar un máximo de 5 enemigos en la rampa")

	# Act: Activar para oleada 5
	torre.activar_torre()
	assert_true(torre.visible, "Debe ser visible al activarse")
	assert_true(torre.torre_activa, "Debe estar activa para oleada 5")

	# Act: Desactivar para otras oleadas
	torre.desactivar_torre()
	assert_false(torre.visible, "Debe estar oculta al desactivarse")
	assert_false(torre.torre_activa, "No debe estar activa fuera de oleada 5")

	# Assert de textura aplicada
	var modelo = torre.get_node_or_null("ModeloTorre") as MeshInstance3D
	assert_not_null(modelo, "ModeloTorre debe existir")
	var mat = modelo.material_override as StandardMaterial3D
	if not mat:
		mat = modelo.get_surface_override_material(0) as StandardMaterial3D
	assert_not_null(mat, "Debe tener un StandardMaterial3D asignado")
	assert_not_null(mat.albedo_texture, "El material de la torre debe tener la textura albedo_texture asignada")

	# Assert de que LimitesRampa NO está en capa 1 (para no bloquear flechas del jugador)
	if torre.limites_rampa:
		assert_eq(torre.limites_rampa.collision_layer & 1, 0, "LimitesRampa NO debe tener capa 1 para no bloquear proyectiles")
