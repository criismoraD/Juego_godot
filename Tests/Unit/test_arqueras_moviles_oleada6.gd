extends "res://addons/gut/test.gd"

## Las arqueras móviles del evento de oleada 6 deben ser dañables con 2 de vida,
## como las defensoras regulares de piso.

var ArqueraScene: PackedScene = load("res://Entities/Aliada_Arquera/AllyArcher.tscn")

var _arquera: AllyArcher = null
var _mock_audio_created: bool = false


class MockAudioManager extends Node:
	func play_sfx(_nombre: String, _boost: float = 0.0, _pitch: float = 0.0) -> void:
		pass


func before_each() -> void:
	if not get_tree().root.has_node("AudioManager"):
		var mock_audio := MockAudioManager.new()
		mock_audio.name = "AudioManager"
		get_tree().root.add_child(mock_audio)
		_mock_audio_created = true


func after_each() -> void:
	for ally in AllyArcher.active_allies_cache.duplicate():
		AllyArcher.active_allies_cache.erase(ally)
	if is_instance_valid(_arquera):
		_arquera.free()
		_arquera = null
	if _mock_audio_created and get_tree().root.has_node("AudioManager"):
		var mock_audio: Node = get_tree().root.get_node("AudioManager")
		get_tree().root.remove_child(mock_audio)
		mock_audio.free()
		_mock_audio_created = false


func _crear_arquera_movil_estilo_oleada6() -> AllyArcher:
	var arquera := ArqueraScene.instantiate() as AllyArcher
	get_tree().root.add_child(arquera)
	arquera.scale = Vector3(0.3, 0.3, 0.3)
	arquera.global_position = Vector3(-12.8, 0.185, 0.0)
	# Igual que _desplegar_arquera_movil_oleada_6 de los niveles
	arquera.es_movil = true
	arquera.vida_maxima = 2
	arquera.health = 2
	if arquera.hitbox_body and is_instance_valid(arquera.hitbox_body):
		arquera.hitbox_body.collision_layer = 2
	await get_tree().process_frame
	await get_tree().process_frame
	return arquera


func test_arquera_movil_tiene_hitbox_activa_y_2_de_vida() -> void:
	# Arrange
	_arquera = await _crear_arquera_movil_estilo_oleada6()

	# Assert
	assert_eq(_arquera.vida_maxima, 2, "La arquera móvil tiene máximo 2 como las de piso")
	assert_eq(_arquera.health, 2, "La arquera móvil entra con 2 de vida")
	assert_true(is_instance_valid(_arquera.hitbox_body), "Debe tener hitbox para ser dañable")
	assert_eq(_arquera.hitbox_body.collision_layer, 2, "La hitbox debe estar activa (capa 2)")


func test_arquera_movil_aguanta_1_disparo_y_muere_con_2() -> void:
	# Arrange
	_arquera = await _crear_arquera_movil_estilo_oleada6()

	# Act: primer disparo
	_arquera.recibir_dano(1)

	# Assert: sigue viva con 1 de vida
	assert_eq(_arquera.health, 1, "Tras 1 disparo queda con 1 de vida")
	assert_ne(_arquera.current_state, _arquera.State.DYING, "No debe morir con 1 disparo")
	assert_ne(_arquera.current_state, _arquera.State.DEAD, "No debe estar muerta con 1 disparo")

	# Act: segundo disparo
	_arquera.recibir_dano(1)

	# Assert: muere con 2 disparos como las defensoras de piso
	assert_eq(_arquera.health, 0, "Tras 2 disparos queda con 0 de vida")
	assert_eq(_arquera.current_state, _arquera.State.DYING, "Debe entrar en DYING con 2 disparos")


func test_arquera_movil_humo_igual_ballestera_al_correr() -> void:
	# Arrange: arquera móvil corriendo con la animación CORRER
	_arquera = await _crear_arquera_movil_estilo_oleada6()
	_arquera._play_anim("CORRER", 0.05, 1.0)
	await get_tree().process_frame

	# Act: simular carrera hacia la derecha
	_arquera._prev_pos_x = _arquera.global_position.x - 1.0
	_arquera._particulas_pisada_emitir()

	# Assert: humo activo con la malla normal
	assert_true(_arquera._particulas_pisada.emitting, "El humo debe emitir con CORRER")
	assert_eq(_arquera._particulas_pisada.draw_pass_1, _arquera._malla_humo_der, "A la derecha usa la malla normal")

	# Act: simular carrera hacia la izquierda
	_arquera._prev_pos_x = _arquera.global_position.x + 1.0
	_arquera._particulas_pisada_emitir()

	# Assert: humo volteado como la ballestera
	assert_true(_arquera._particulas_pisada.emitting, "El humo debe seguir emitiendo a la izquierda")
	assert_eq(_arquera._particulas_pisada.draw_pass_1, _arquera._malla_humo_izq, "A la izquierda usa la malla volteada")


func test_rotacion_espalda_en_escalera_no_se_pisa_en_despliegue() -> void:
	# Arrange: arquera móvil trepando (espalda a cámara, igual que la ballestera)
	_arquera = await _crear_arquera_movil_estilo_oleada6()
	_arquera.en_despliegue = true
	_arquera.model_root.rotation.y = 0.0

	# Act: el actualizador de rotación del _process no debe pisarla
	_arquera._actualizar_rotacion_modelo(0.05)

	# Assert
	assert_almost_eq(_arquera.model_root.rotation.y, 0.0, 0.001, "La espalda a cámara se conserva al trepar")


func test_iniciar_no_pisa_correr_en_despliegue() -> void:
	# Arrange: móvil entrando con CORRER (el _iniciar diferido lo pisaba con IDLE)
	_arquera = await _crear_arquera_movil_estilo_oleada6()
	_arquera.en_despliegue = true
	_arquera._play_anim("CORRER", 0.05, 1.0)
	await get_tree().process_frame
	assert_eq(_arquera.anim_player.current_animation, "CORRER", "Precondición: suena CORRER")

	# Act: lo que el deferred del _ready hacía al final del frame
	_arquera._iniciar()

	# Assert: sigue corriendo
	assert_eq(_arquera.anim_player.current_animation, "CORRER", "El _iniciar no debe pisar CORRER en despliegue")


func test_arquera_movil_muere_desintegrandose_sin_cadaver() -> void:
	# Arrange: como las ballesteras móviles del item de refuerzo
	_arquera = await _crear_arquera_movil_estilo_oleada6()

	# Act: 2 disparos letales
	_arquera.recibir_dano(1)
	_arquera.recibir_dano(1)
	await get_tree().process_frame

	# Assert: arranca desintegración celeste con partículas
	var particulas: Node = null
	var raiz: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	for child in raiz.get_children():
		if is_instance_valid(child) and child.name == "ParticulasMuerteCeleste":
			particulas = child
			break
	assert_not_null(particulas, "Debe generar partículas celestes de desintegración")

	# Act: esperar la disolución completa (1.0s)
	await get_tree().create_timer(1.3).timeout

	# Assert: desaparece sin dejar cadáver
	assert_false(is_instance_valid(_arquera), "La arquera móvil debe liberarse al desintegrarse")
