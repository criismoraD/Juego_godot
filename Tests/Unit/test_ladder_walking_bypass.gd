extends GutTest

## Tests de verificación para evitar que la jugadora se quede pegada
## en la escalera con la animación de caminar al desplazarse presionando W o S.

var PlayerScene = load("res://Entities/Jugador_Arquera/Player.tscn")
var LadderScene = load("res://Entities/Ambiente_Escalera/ESCALERA.tscn")

class MockAudioManager extends Node:
	func play_sfx(_name, _boost = 0.0): pass
	func stop_bow_tension(): pass
	func reset_bow_hold(): pass

var _mock_audio_created: bool = false
var _nodes_to_clean: Array[Node] = []


func before_each() -> void:
	if not get_tree().root.has_node("AudioManager"):
		var mock_audio = MockAudioManager.new()
		mock_audio.name = "AudioManager"
		get_tree().root.add_child(mock_audio)
		_mock_audio_created = true


func after_each() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_forward")
	Input.action_release("move_back")
	Input.action_release("ui_up")
	Input.action_release("ui_down")

	for n in _nodes_to_clean:
		if is_instance_valid(n):
			if n.get_parent():
				n.get_parent().remove_child(n)
			n.free()
	_nodes_to_clean.clear()

	if _mock_audio_created and get_tree().root.has_node("AudioManager"):
		var mock_audio = get_tree().root.get_node("AudioManager")
		get_tree().root.remove_child(mock_audio)
		mock_audio.free()
		_mock_audio_created = false


func _crear_suelo(y_top: float = 0.0) -> StaticBody3D:
	var suelo := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30.0, 1.0, 4.0)
	col.shape = box
	suelo.position = Vector3(0.0, y_top - 0.5, 0.0)
	suelo.add_child(col)
	get_tree().root.add_child(suelo)
	_nodes_to_clean.append(suelo)
	return suelo


func _crear_jugadora_en_piso(x_init: float) -> Node:
	_crear_suelo(0.0)
	var player = PlayerScene.instantiate()
	get_tree().root.add_child(player)
	_nodes_to_clean.append(player)
	player.global_position = Vector3(x_init, 0.0, 0.0)
	for i in range(30):
		await get_tree().physics_frame
		if player.is_on_floor():
			break
	return player


func test_caminar_presionando_arriba_no_se_queda_pegada_en_escalera() -> void:
	# Arrange
	var player = await _crear_jugadora_en_piso(-1.0)
	assert_true(player.is_on_floor(), "Precondición: debe estar en el suelo")

	var ladder = LadderScene.instantiate()
	get_tree().root.add_child(ladder)
	_nodes_to_clean.append(ladder)
	ladder.global_position = Vector3(0.0, 0.5, 0.0)

	# Simular que entra al área de la escalera
	ladder._on_body_entered(player)
	assert_true(player.is_near_ladder, "Precondición: debe detectar la escalera")

	# Act: caminar hacia la derecha mientras se mantiene presionado arriba (W)
	Input.action_press("move_right")
	Input.action_press("move_forward")

	for f in range(20):
		await get_tree().physics_frame

	# Assert: no debe engancharse en CLIMBING, debe mantenerse en GROUND y avanzar
	assert_eq(player.current_move_state, player.MoveState.GROUND, "Debe permanecer en GROUND caminando, no engancharse en CLIMBING")
	assert_gt(player.velocity.x, 0.0, "La velocidad horizontal debe ser positiva hacia la derecha")
	assert_gt(player.global_position.x, -0.9, "Debe haber avanzado hacia la derecha sin trabarse")


func test_caminar_presionando_abajo_no_se_engancha_en_escalera() -> void:
	# Arrange
	var player = await _crear_jugadora_en_piso(-1.0)
	assert_true(player.is_on_floor(), "Precondición: debe estar en el suelo")

	var ladder = LadderScene.instantiate()
	get_tree().root.add_child(ladder)
	_nodes_to_clean.append(ladder)
	ladder.global_position = Vector3(0.0, 0.5, 0.0)

	ladder._on_body_entered(player)
	assert_true(player.is_near_ladder, "Precondición: debe detectar la escalera")

	# Act: caminar hacia la derecha mientras se mantiene presionado abajo (S)
	Input.action_press("move_right")
	Input.action_press("move_back")

	for f in range(20):
		await get_tree().physics_frame

	# Assert: jamás debe quedar bloqueada en CLIMBING
	assert_ne(player.current_move_state, player.MoveState.CLIMBING, "No debe estar en estado CLIMBING al pasar caminando")


func test_quieta_al_pie_presionando_arriba_si_inicia_escalada() -> void:
	# Arrange
	var player = await _crear_jugadora_en_piso(0.0)
	var ladder = LadderScene.instantiate()
	get_tree().root.add_child(ladder)
	_nodes_to_clean.append(ladder)
	ladder.global_position = Vector3(0.0, 0.5, 0.0)

	ladder._on_body_entered(player)
	assert_true(player.is_near_ladder, "Precondición: cerca de la escalera")

	# Act: quieta sin input horizontal, solo presionar arriba (W)
	Input.action_press("move_forward")
	for f in range(5):
		await get_tree().physics_frame

	# Assert: inicia escalada correctamente
	assert_eq(player.current_move_state, player.MoveState.CLIMBING, "Sin moverse de lado, presionar W debe iniciar CLIMBING")
