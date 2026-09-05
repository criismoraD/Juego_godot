extends GutTest

## Tests de verificación para la escalada de escaleras y desembarque en plataformas One-Way.
## Comprueba que el jugador sube a través de la plataforma, que esta se vuelve sólida al llegar
## a la superficie, y que el jugador puede desembarcar y caminar sobre ella sin caerse.

var PlayerScene = load("res://Entities/Jugador_Arquera/Player.tscn")
var LadderScene = load("res://Entities/Ambiente_Escalera/ESCALERA.tscn")
var PlatformScene = load("res://Entities/Ambiente_Plataforma_Oneway/PlataformaOneway.tscn")

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
	Input.action_release("move_forward")
	Input.action_release("ui_up")
	Input.action_release("move_right")
	Input.action_release("move_left")
	Input.action_release("move_back")
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


func test_climb_through_oneway_platform_and_walk_on_top() -> void:
	# Arrange
	var plat1 = PlatformScene.instantiate()
	plat1.scale = Vector3(0.5, 0.5, 0.5)
	get_tree().root.add_child(plat1)
	plat1.global_position = Vector3(-7.617247, 1.7013383, -0.37669206)
	_nodes_to_clean.append(plat1)

	var ladder1 = LadderScene.instantiate()
	plat1.add_child(ladder1)
	ladder1.transform = Transform3D(Transform3D.IDENTITY.basis.scaled(Vector3(2, 2, 2)), Vector3(0.06970596, -2.9612694, 0.1503278))

	var player = PlayerScene.instantiate()
	get_tree().root.add_child(player)
	_nodes_to_clean.append(player)

	player.global_position = Vector3(-7.58, 1.0, 0.05)
	player.velocity = Vector3.ZERO
	ladder1._on_body_entered(player)
	plat1.player_ref = player

	await get_tree().process_frame

	var col_shape = plat1.collision_shape
	var half_h = (col_shape.shape.size.y * col_shape.global_transform.basis.get_scale().y) / 2.0
	var platform_top_y = col_shape.global_position.y + half_h

	# Act: Iniciar escalada hacia arriba
	Input.action_press("move_forward")
	Input.action_press("ui_up")
	player.current_move_state = player.MoveState.CLIMBING
	player.velocity = Vector3.ZERO

	# Simular ascenso durante 85 frames
	for f in range(85):
		await get_tree().physics_frame

	# Assert 1: Tras subir, los pies del jugador superaron la superficie de la plataforma
	assert_gt(player.global_position.y, platform_top_y - 0.05, "Los pies del jugador deben haber alcanzado la superficie")
	# Assert 2: La plataforma debe ser sólida bajo los pies del jugador
	assert_true(plat1.get_collision_layer_value(1), "La plataforma debe tener activa la capa de colisión 1")

	# Act 2: Desembarcar hacia la derecha caminando sobre la plataforma
	Input.action_release("move_forward")
	Input.action_release("ui_up")
	Input.action_press("move_right")

	# Simular 90 frames adicionales para caminar a la derecha fuera de la escalera
	for f in range(90):
		await get_tree().physics_frame

	Input.action_release("move_right")

	# Assert 3: El jugador debe estar en el suelo (GROUND) y apoyado en la plataforma
	assert_eq(player.current_move_state, player.MoveState.GROUND, "El estado del jugador debe ser GROUND")
	assert_true(player.is_on_floor(), "El jugador debe estar sobre el piso de la plataforma")
	assert_almost_eq(player.global_position.y, platform_top_y, 0.1, "La posición Y del jugador debe coincidir con la superficie de la plataforma")
	assert_false(player.is_near_ladder, "El jugador debe haberse alejado de la escalera sobre la plataforma")
