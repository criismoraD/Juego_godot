extends "res://addons/gut/test.gd"

var AllyArcherScript = load("res://Entities/Aliada_Arquera/AllyArcher.gd")
var _ally: AllyArcher = null

# Mock para AudioManager
class MockAudioManager extends Node:
	func play_sfx(_name, _boost = 0.0): pass
	func stop_bow_tension(): pass
	func reset_bow_hold(): pass

var _mock_audio_created: bool = false

func before_each():
	_ally = AllyArcherScript.new()
	_agregar_animacion_minima(_ally)

	if not get_tree().root.has_node("AudioManager"):
		var mock_audio = MockAudioManager.new()
		mock_audio.name = "AudioManager"
		get_tree().root.add_child(mock_audio)
		_mock_audio_created = true

	get_tree().root.add_child(_ally)

func after_each():
	if is_instance_valid(_ally):
		if _ally.get_parent():
			_ally.get_parent().remove_child(_ally)
		_ally.free()

	if _mock_audio_created and get_tree().root.has_node("AudioManager"):
		var mock_audio = get_tree().root.get_node("AudioManager")
		get_tree().root.remove_child(mock_audio)
		mock_audio.free()
		_mock_audio_created = false

func _agregar_animacion_minima(ally: AllyArcher) -> void:
	var anim_player := AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	
	var lib := AnimationLibrary.new()
	var anim_levantarse = Animation.new()
	anim_levantarse.length = 1.0
	lib.add_animation("IDLE", Animation.new())
	lib.add_animation("IDE", Animation.new())
	lib.add_animation("IDLE_EXAMINAR", Animation.new())
	lib.add_animation("IDLE_APUNTANDO", Animation.new())
	lib.add_animation("TOMAR_FLECHA", Animation.new())
	lib.add_animation("DISPARAR_FLECHA", Animation.new())
	lib.add_animation("MUERTE_01", Animation.new())
	lib.add_animation("MUERTE_02", Animation.new())
	lib.add_animation("AGACHARSE", Animation.new())
	lib.add_animation("ATERRIZAJE_POST_SALTO_01", Animation.new())
	lib.add_animation("LEVANTARSE", anim_levantarse)
	lib.add_animation("VICTORIA", Animation.new())
	lib.add_animation("ELECTROCUTAR", Animation.new())
	lib.add_animation("DAÑO_01", Animation.new())
	lib.add_animation("DAÑO_02", Animation.new())
	
	anim_player.add_animation_library("", lib)
	ally.add_child(anim_player)
	ally.anim_player = anim_player

	var model := Node3D.new()
	model.name = "ArqueraModel"
	ally.add_child(model)
	ally.model_root = model

	var hitbox := StaticBody3D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 2
	ally.add_child(hitbox)
	ally.hitbox_body = hitbox

func test_inicializacion_vida():
	assert_eq(_ally.vida_maxima, 2, "La vida máxima por defecto debería ser 2")
	assert_eq(_ally.health, 2, "La salud inicial debería coincidir con vida_maxima")

func test_recibir_dano_no_muere():
	_ally.recibir_dano(1)
	assert_eq(_ally.health, 1, "La salud debería reducirse a 1")
	assert_ne(_ally.current_state, _ally.State.DYING, "No debería estar muriendo con salud > 0")

func test_recibir_dano_muere_y_permanece():
	_ally.recibir_dano(2)
	assert_eq(_ally.health, 0, "La salud debería reducirse a 0")
	assert_eq(_ally.current_state, _ally.State.DYING, "El estado debería ser DYING al quedarse sin salud")
	
	# Simular el timer que pasa de DYING a DEAD
	# Llamamos directamente a la transición para evitar esperar en el test
	_ally._cambiar_estado(_ally.State.DEAD)
	assert_eq(_ally.current_state, _ally.State.DEAD, "El estado debería cambiar a DEAD")
	assert_true(is_instance_valid(_ally), "La arquera debería permanecer en la escena (no autodestruirse)")

func test_revivir_desde_muerta():
	# Forzar estado muerto
	_ally.health = 0
	_ally.current_state = _ally.State.DEAD
	_ally.set_process(false)
	if _ally.hitbox_body:
		_ally.hitbox_body.collision_layer = 0

	_ally.revivir()

	assert_eq(_ally.health, _ally.vida_maxima, "La salud debería restablecerse a vida_maxima")
	assert_eq(_ally.current_state, _ally.State.GETTING_UP, "El estado debería cambiar a GETTING_UP")
	assert_true(_ally.is_processing(), "El procesamiento del nodo debería estar activo")
	if _ally.hitbox_body:
		assert_eq(_ally.hitbox_body.collision_layer, 0, "El hitbox debería estar en capa 0 (invulnerable) mientras se levanta")
	_ally._process_getting_up(_ally.state_timer + 0.1)
	assert_eq(_ally.current_state, _ally.State.IDLE, "Debe pasar a IDLE al terminar")
	if _ally.hitbox_body:
		assert_eq(_ally.hitbox_body.collision_layer, 2, "El hitbox debería volver a la capa de colisión 2")

func test_revivir_rotacion_muerte_01():
	# Crear un model_root dummy para testear rotación
	var dummy_model = Node3D.new()
	dummy_model.name = "ArqueraModel"
	_ally.add_child(dummy_model)
	_ally.model_root = dummy_model
	_ally._original_model_y_rot = 0.0
	
	# Forzar muerte con MUERTE_01
	_ally.ultima_muerte_anim = "MUERTE_01"
	_ally.current_state = _ally.State.DEAD
	
	_ally.revivir()
	
	assert_almost_eq(dummy_model.rotation.y, deg_to_rad(90), 0.0001, "El modelo debería estar rotado 90 grados en Y durante GETTING_UP si la muerte fue MUERTE_01")
	
	# Transicionar fuera de GETTING_UP debería restaurar la rotación original
	_ally._cambiar_estado(_ally.State.IDLE)
	await wait_seconds(0.4)
	assert_eq(dummy_model.rotation.y, 0.0, "La rotación debería restaurarse al salir de GETTING_UP")

func test_invulnerable_durante_getting_up():
	_ally.health = 2
	_ally.current_state = _ally.State.GETTING_UP
	_ally.take_damage(1.0)
	assert_eq(_ally.health, 2, "No debería recibir daño durante el estado GETTING_UP")

func test_enemigos_minimos_es_uno():
	assert_eq(_ally.enemigos_minimos, 1, "Las arqueras aliadas deben empezar a disparar con al menos 1 enemigo")


func test_celebracion_victoria_activacion_y_rotacion():
	var dummy_model = Node3D.new()
	dummy_model.name = "ArqueraModel"
	_ally.add_child(dummy_model)
	_ally.model_root = dummy_model
	_ally._original_model_y_rot = 0.0
	_ally.anim_player = _ally.find_child("AnimationPlayer", true, false)

	_ally.celebrar_victoria()

	assert_eq(_ally.current_state, _ally.State.CELEBRATING, "El estado debe cambiar a CELEBRATING")
	assert_gt(_ally._loops_victoria_restantes, 0, "Debe tener loops de victoria asignados")

	# Simular un frame de proceso para verificar rotación de victoria
	_ally._process(0.1)
	assert_gt(dummy_model.rotation.y, 0.0, "El modelo debe rotar suavemente hacia la derecha durante la celebración")


func test_celebracion_victoria_loops_y_retorno_idle():
	_ally.anim_player = _ally.find_child("AnimationPlayer", true, false)
	_ally.celebrar_victoria()
	_ally.state_timer = 2.0

	# Simular avance mientras state_timer > 0
	_ally._process_celebrating(1.0)
	assert_gt(_ally.state_timer, 0.0, "Aún debe quedar tiempo restante de celebración")
	assert_eq(_ally.current_state, _ally.State.CELEBRATING, "Debe permanecer en CELEBRATING")

	# Simular que termina el tiempo total
	_ally._process_celebrating(1.5)
	assert_eq(_ally._loops_victoria_restantes, 0, "Los loops restantes deben ser 0")
	assert_eq(_ally.current_state, _ally.State.IDLE, "Debe volver a IDLE tras completar la celebración")


func test_on_oleada_completada_activa_celebracion():
	_ally.anim_player = _ally.find_child("AnimationPlayer", true, false)
	_ally._on_oleada_completada(1)

	assert_eq(_ally.current_state, _ally.State.CELEBRATING, "El evento de oleada completada debe activar la celebración de victoria")


func test_ataque_suelta_flecha_al_segundo_3():
	_ally.anim_player = _ally.find_child("AnimationPlayer", true, false)
	_ally.tiempo_suelta_flecha = 3.0
	_ally._cambiar_estado(_ally.State.SHOOTING)
	assert_eq(_ally.current_state, _ally.State.SHOOTING, "Debe entrar en estado SHOOTING")
	assert_false(_ally._flecha_soltada, "La flecha no debe haberse soltado al inicio del ataque")

	# Simular 2 segundos de animación (aún no llega al segundo 3)
	_ally._process_shooting(2.0)
	assert_false(_ally._flecha_soltada, "La flecha todavía no debe haberse soltado en t=2.0s")

	# Simular 1 segundo más (t=3.0s, momento exacto de suelta)
	_ally._process_shooting(1.0)
	assert_true(_ally._flecha_soltada, "La flecha debe haberse soltado al alcanzar el segundo 3.0")


func test_oleada_1_no_se_levanta_mantiene_idle():
	# Arrange
	_ally._cambiar_estado(_ally.State.IDLE)
	_ally.health = 2

	# Act
	_ally._on_oleada_iniciada(1)

	# Assert
	assert_eq(_ally.current_state, _ally.State.IDLE, "En la oleada 1 NO debe levantarse, debe mantenerse en IDLE")
	assert_ne(_ally.anim_player.current_animation, "LEVANTARSE", "No debe reproducir LEVANTARSE en la oleada 1")


func test_oleada_posterior_si_esta_viva_no_se_levanta():
	# Arrange
	_ally._cambiar_estado(_ally.State.IDLE)
	_ally.health = 2

	# Act
	_ally._on_oleada_iniciada(2)

	# Assert
	assert_eq(_ally.current_state, _ally.State.IDLE, "En oleadas posteriores, si está viva NO debe levantarse")
	assert_ne(_ally.anim_player.current_animation, "LEVANTARSE", "No debe reproducir LEVANTARSE si está viva")


func test_oleada_posterior_si_esta_celebrando_vuelve_a_idle():
	# Arrange
	_ally._cambiar_estado(_ally.State.CELEBRATING)
	_ally.health = 2

	# Act
	_ally._on_oleada_iniciada(2)

	# Assert
	assert_eq(_ally.current_state, _ally.State.IDLE, "Si estaba celebrando, debe pasar a IDLE al iniciar oleada")
	assert_eq(_ally.anim_player.current_animation, "IDE", "Debe reproducir IDE al pasar a IDLE")


func test_oleada_posterior_revive_si_esta_muerta_dura_3_5_segundos_e_invulnerable():
	# Arrange
	_ally.health = 0
	_ally.current_state = _ally.State.DEAD
	_ally.set_process(false)

	# Act
	_ally._on_oleada_iniciada(2)

	# Assert
	assert_eq(_ally.health, _ally.vida_maxima, "Debe restaurar la vida completa al revivir")
	assert_eq(_ally.current_state, _ally.State.GETTING_UP, "Debe pasar al estado GETTING_UP")
	assert_eq(_ally.anim_player.current_animation, "LEVANTARSE", "Debe reproducir la animación LEVANTARSE")
	assert_almost_eq(_ally.state_timer, 3.5, 0.05, "La secuencia de levantarse debe durar exactamente 3.5 segundos en total")
	assert_almost_eq(_ally.segundos_recortados_levantarse, 8.5, 0.01, "Solo se reproducen los primeros 8.5 segundos del clip")
	assert_almost_eq(_ally.segundos_recortados_levantarse / _ally.duracion_levantarse_total, 8.5 / 3.5, 0.01, "La velocidad debe coincidir con la relación configurada")
	assert_eq(_ally.hitbox_body.collision_layer, 0, "El hitbox debe estar en layer 0 (invulnerable) mientras se levanta")


func test_getting_up_inmunidad_a_dano_y_paralisis():
	# Arrange
	_ally._cambiar_estado(_ally.State.GETTING_UP)
	var vida_previa := _ally.health

	# Act
	_ally.take_damage(5.0)
	_ally.aplicar_paralisis(4.0)

	# Assert
	assert_eq(_ally.health, vida_previa, "No debe recibir daño mientras está en GETTING_UP")
	assert_eq(_ally.paralisis_timer, 0.0, "No debe verse afectada por parálisis mientras está en GETTING_UP")
	assert_eq(_ally.current_state, _ally.State.GETTING_UP, "Debe permanecer en GETTING_UP")


func test_getting_up_parpadeo_transparente_y_restauracion_final():
	# Arrange
	_ally._cambiar_estado(_ally.State.GETTING_UP)
	assert_true(_ally.model_root.visible, "El modelo debe comenzar visible")

	# Act & Assert 1: Parpadeo transparente (visibilidad alternada)
	_ally._process_getting_up(0.085)
	assert_false(_ally.model_root.visible, "Debe alternar a invisible para el parpadeo")

	_ally._process_getting_up(0.085)
	assert_true(_ally.model_root.visible, "Debe alternar a visible en el siguiente ciclo de parpadeo")

	# Act & Assert 2: Al completarse el tiempo pasa a IDLE y se restaura visibilidad y colisión
	_ally._process_getting_up(_ally.state_timer + 0.1)
	assert_eq(_ally.current_state, _ally.State.IDLE, "Debe pasar a IDLE tras levantarse")
	assert_true(_ally.model_root.visible, "El modelo debe quedar visible al terminar")
	assert_eq(_ally.hitbox_body.collision_layer, 2, "El hitbox debe restaurar layer 2 al terminar de levantarse")


func test_no_inicial_no_revive_en_oleada():
	# Arrange
	_ally.es_aliada_inicial = false
	_ally.name = "AliadaInvocadaTemporal"
	_ally.health = 0
	_ally.current_state = _ally.State.DEAD

	# Act
	_ally._on_oleada_iniciada(2)

	# Assert
	assert_eq(_ally.current_state, _ally.State.DEAD, "Una aliada no inicial no debe revivir al comenzar oleada")
	assert_eq(_ally.health, 0, "La salud debe mantenerse en 0")


func test_flecha_al_tensar_arco_tiene_material_celeste():
	var flecha_dummy := Node3D.new()
	flecha_dummy.name = "FLECHA"
	var mesh_inst := MeshInstance3D.new()
	flecha_dummy.add_child(mesh_inst)
	_ally.add_child(flecha_dummy)
	_ally.arrow_node = flecha_dummy

	_ally._aplicar_material_celeste_flecha(flecha_dummy)

	assert_not_null(mesh_inst.material_override, "La malla de la flecha debe tener material_override asignado")
	var mat = mesh_inst.material_override as StandardMaterial3D
	assert_not_null(mat, "El material debe ser StandardMaterial3D")
	assert_eq(mat.albedo_color, Color(0.3, 0.75, 1.0), "El color de la flecha tensada debe ser celeste")
	assert_true(mat.emission_enabled, "Debe tener emisión activada para brillar como el proyectil")
	assert_eq(mat.emission, Color(0.3, 0.75, 1.0), "La emisión debe ser celeste")
	assert_almost_eq(mat.emission_energy_multiplier, 4.0, 0.01, "La energía de emisión debe coincidir con el proyectil")


func test_idle_examinar_ciclo_fuera_de_combate():
	_ally.anim_player = _ally.find_child("AnimationPlayer", true, false)
	_ally._cambiar_estado(_ally.State.IDLE)
	assert_eq(_ally.anim_player.current_animation, "IDE", "Debe iniciar en IDE")
	assert_false(_ally._examinando, "No debe estar examinando inicialmente")

	# Forzar fin del temporizador de examinar
	_ally._tiempo_para_examinar = 0.0
	_ally._process_idle(0.1)

	assert_true(_ally._examinando, "Debe pasar a estado examinando")
	assert_eq(_ally.anim_player.current_animation, "IDLE_EXAMINAR", "Debe reproducir IDLE_EXAMINAR")

	# Simular que termina la animación de examinar
	_ally.state_timer = 0.0
	_ally._process_idle(0.1)

	assert_false(_ally._examinando, "Debe regresar del modo examinar")
	assert_eq(_ally.anim_player.current_animation, "IDE", "Debe volver a la animación IDE")


func test_punto_disparo_manual_personalizado():
	var marker := Marker3D.new()
	marker.name = "PuntoDisparo"
	marker.position = Vector3(0.5, 1.4, 0.2)
	_ally.add_child(marker)
	_ally._spawn_punto_nodo = marker
	_ally.punto_disparo_proyectil = marker

	assert_eq(_ally.punto_disparo_proyectil, marker, "Debe aceptar un nodo de punto de disparo manual")
	assert_eq(_ally.punto_disparo_proyectil.position, Vector3(0.5, 1.4, 0.2), "La posición del punto de disparo debe ser personalizable")


func test_muerte_02_rotacion_90_grados():
	# Arrange
	var dummy_model := Node3D.new()
	dummy_model.name = "ArqueraModel"
	_ally.add_child(dummy_model)
	_ally.model_root = dummy_model
	_ally._original_model_y_rot = 0.0

	# Act: Forzar MUERTE_02 en _on_dying
	_ally.ultima_muerte_anim = "MUERTE_02"
	_ally._cambiar_estado(_ally.State.GETTING_UP)

	# Assert
	assert_almost_eq(_ally.model_root.rotation.y, deg_to_rad(90.0), 0.01, "El modelo debe rotar 90 grados en Y para MUERTE_02")


func test_recarga_escala_flecha_de_0_a_1():
	# Arrange
	var flecha_dummy := Node3D.new()
	flecha_dummy.name = "FLECHA"
	flecha_dummy.scale = Vector3(1.0, 1.0, 1.0)
	_ally.add_child(flecha_dummy)
	_ally.arrow_node = flecha_dummy
	_ally._arrow_base_scale = Vector3(1.0, 1.0, 1.0)

	# Act: Cambiar a RELOADING
	_ally._cambiar_estado(_ally.State.RELOADING)
	# Al inicio debe ser invisible o escala 0
	assert_almost_eq(flecha_dummy.scale.x, 0.0, 0.05, "La flecha debe iniciar en escala 0 al recargar")

	# Simular avance del 50% de la recarga
	_ally._process_reloading(_ally._duracion_reload_actual * 0.5)
	assert_almost_eq(flecha_dummy.scale.x, 0.5, 0.08, "A mitad de la recarga debe escalar aproximadamente al 50%")

	# Simular que completa la recarga
	_ally._process_reloading(_ally._duracion_reload_actual * 0.6)
	assert_almost_eq(flecha_dummy.scale.x, 1.0, 0.05, "Al terminar la recarga debe estar completamente al 100%")


