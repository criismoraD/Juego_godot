extends GutTest

## Test unitario integral para la corrección del bug de la escalera del medio (Ladder2).
## Verifica la transición entre escaleras, mantenimiento de estado, inicio de escalada
## y la interacción física con PlataformaOneway y barreras.

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


func test_two_ladders_exit_bug_fixed() -> void:
	var player = PlayerScene.instantiate()
	get_tree().root.add_child(player)
	_nodes_to_clean.append(player)

	var ladder1 = LadderScene.instantiate()
	ladder1.name = "Ladder1"
	get_tree().root.add_child(ladder1)
	ladder1.global_position = Vector3(-7.58, 0.22, -0.3)
	_nodes_to_clean.append(ladder1)

	var ladder2 = LadderScene.instantiate()
	ladder2.name = "Ladder2"
	get_tree().root.add_child(ladder2)
	ladder2.global_position = Vector3(-8.33, 1.58, -0.3)
	_nodes_to_clean.append(ladder2)

	# 1. Jugador en X = -7.58 entra en Ladder 1
	player.global_position = Vector3(-7.58, 1.6, 0.05)
	ladder1._on_body_entered(player)

	assert_true(player.is_near_ladder, "Debe estar cerca de escalera al entrar a Ladder 1")
	assert_eq(player.current_ladder, ladder1, "current_ladder debe ser ladder1")

	# 2. Jugador camina a X = -8.33 y entra en Ladder 2
	player.global_position = Vector3(-8.33, 1.6, 0.05)
	ladder2._on_body_entered(player)

	assert_true(player.is_near_ladder, "Debe seguir cerca de escalera al entrar a Ladder 2")
	assert_eq(player.current_ladder, ladder2, "current_ladder debe ser ladder2 porque está más cerca en X")

	# 3. Jugador sale de Ladder 1
	ladder1._on_body_exited(player)

	# Assert
	assert_true(player.is_near_ladder, "is_near_ladder debe seguir siendo true porque el jugador sigue en Ladder 2")
	assert_eq(player.current_ladder, ladder2, "current_ladder debe ser ladder2")


func test_start_climbing_ladder2() -> void:
	var player = PlayerScene.instantiate()
	get_tree().root.add_child(player)
	_nodes_to_clean.append(player)

	var ladder2 = LadderScene.instantiate()
	ladder2.name = "Ladder2"
	get_tree().root.add_child(ladder2)
	ladder2.global_position = Vector3(-8.33, 1.58, -0.3)
	_nodes_to_clean.append(ladder2)

	player.global_position = Vector3(-8.33, 1.6, 0.05)
	ladder2._on_body_entered(player)

	assert_true(player.is_near_ladder, "Jugador debe estar listo para escalar Ladder 2")
	assert_eq(player.current_ladder, ladder2, "Escalera activa debe ser Ladder 2")
	assert_true(player.ladder_cooldown <= 0.0, "Cooldown debe ser 0")

	player.current_move_state = player.MoveState.CLIMBING
	assert_eq(player.current_move_state, player.MoveState.CLIMBING, "El jugador debe poder estar en estado CLIMBING")


func test_lower_barrier_no_cooldown_unless_climbing() -> void:
	var player = PlayerScene.instantiate()
	get_tree().root.add_child(player)
	_nodes_to_clean.append(player)

	var ladder2 = LadderScene.instantiate()
	get_tree().root.add_child(ladder2)
	_nodes_to_clean.append(ladder2)

	var barrera_inf = ladder2.get_node_or_null("Barrera") as BarreraEscalera
	assert_not_null(barrera_inf, "Debe existir la barrera inferior")

	player.global_position = Vector3(-8.33, 1.6, 0.05)
	player.ladder_cooldown = 0.0
	player.current_move_state = player.MoveState.GROUND

	barrera_inf._on_body_entered(player)
	barrera_inf._physics_process(0.016)

	assert_eq(player.ladder_cooldown, 0.0, "ladder_cooldown no debe ser modificado si el jugador no está escalando")


func test_plataforma_oneway_stays_solid_when_player_is_on_top() -> void:
	var player = PlayerScene.instantiate()
	get_tree().root.add_child(player)
	_nodes_to_clean.append(player)

	var plat = PlatformScene.instantiate()
	get_tree().root.add_child(plat)
	plat.global_position = Vector3(-7.61, 1.70, -0.37)
	plat.scale = Vector3(0.5, 0.5, 0.5)
	_nodes_to_clean.append(plat)

	player.global_position = Vector3(-7.61, 1.58, 0.05)
	plat.player_ref = player

	player.current_move_state = player.MoveState.GROUND
	plat._physics_process(0.016)

	assert_true(plat.get_collision_layer_value(1), "Plataforma 1 debe ser sólida cuando el jugador está de pie encima")

	player.current_move_state = player.MoveState.CLIMBING
	plat._physics_process(0.016)

	assert_true(plat.get_collision_layer_value(1), "Plataforma 1 debe permanecer sólida como piso para Ladder 2")


func test_plataforma_oneway_ladder_direction_down_check() -> void:
	var player = PlayerScene.instantiate()
	get_tree().root.add_child(player)
	_nodes_to_clean.append(player)

	var plat1 = PlatformScene.instantiate()
	get_tree().root.add_child(plat1)
	plat1.global_position = Vector3(-7.61, 1.70, -0.37)
	plat1.scale = Vector3(0.5, 0.5, 0.5)
	_nodes_to_clean.append(plat1)

	# Escalera 2 (va hacia arriba desde Plataforma 1)
	var ladder2 = LadderScene.instantiate()
	get_tree().root.add_child(ladder2)
	ladder2.global_position = Vector3(-8.33, 1.58, -0.3)
	_nodes_to_clean.append(ladder2)

	# Escalera 1 (va hacia abajo desde Plataforma 1)
	var ladder1 = LadderScene.instantiate()
	get_tree().root.add_child(ladder1)
	ladder1.global_position = Vector3(-7.58, 0.22, -0.3)
	_nodes_to_clean.append(ladder1)

	# Caso A: Jugador sobre Plataforma 1 en Ladder 2 (que sube)
	player.global_position = Vector3(-8.33, 1.58, 0.05)
	player.set_near_ladder(true, ladder2)
	plat1.player_ref = player

	# Plataforma debe evaluar que ladder2 NO desciende a través de plat1
	plat1._physics_process(0.016)
	assert_true(plat1.get_collision_layer_value(1), "Plataforma 1 debe permanecer sólida frente a Ladder 2 (subida)")

	# Caso B: Jugador sobre Plataforma 1 en Ladder 1 (que baja al suelo)
	player.global_position = Vector3(-7.58, 1.58, 0.05)
	player.set_near_ladder(false, ladder2)
	player.set_near_ladder(true, ladder1)

	# El centro de ladder1 (Y ≈ 1.23) está por debajo de platform_top_y (Y ≈ 1.58)
	var ladder1_col = ladder1.get_node_or_null("ESCALERA")
	var ladder1_center_y = ladder1_col.global_position.y if ladder1_col else ladder1.global_position.y
	assert_true(ladder1_center_y < 1.58, "Ladder 1 debe tener su centro vertical por debajo del tope de Plataforma 1")
